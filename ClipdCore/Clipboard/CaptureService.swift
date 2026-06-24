import Foundation
import CryptoKit

/// 一次捕获的结果(便于测试与日志)。
public enum CaptureOutcome: Sendable, Equatable {
    case captured
    case deduped
    case skipped(RejectReason)
}

/// 捕获编排:把 监听快照 → 过滤 → 去重/防回环 → 落盘/缩略图 → 入库 → 裁剪 串起来。
///
/// `@MainActor` 隔离轻量状态与入口;哈希、缩略图、磁盘 I/O 经 `Task.detached` 在后台执行,
/// 不阻塞主线程与轮询。
@MainActor
public final class CaptureService {
    private let repository: ClipItemRepository
    private let blobStore: BlobStoring
    private let thumbnailer: ThumbnailService
    private let privacyFilter: PrivacyFilter
    private let trimming: TrimmingService
    private let settings: SettingsProviding
    private let now: @Sendable () -> Date

    /// 文本/RTF 小于此字节数内联进库,否则落盘。
    private let inlineTextLimit: Int

    /// 防回环兜底:记录最近一次自身写回的内容指纹。
    private var lastSelfWriteHash: String?

    public init(
        repository: ClipItemRepository,
        blobStore: BlobStoring,
        thumbnailer: ThumbnailService = ThumbnailService(),
        privacyFilter: PrivacyFilter = PrivacyFilter(),
        trimming: TrimmingService,
        settings: SettingsProviding = DefaultSettings(),
        inlineTextLimit: Int = 8 * 1024,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.blobStore = blobStore
        self.thumbnailer = thumbnailer
        self.privacyFilter = privacyFilter
        self.trimming = trimming
        self.settings = settings
        self.inlineTextLimit = inlineTextLimit
        self.now = now
    }

    /// 由 `PasteService` 写回前调用:登记自身写入指纹,防止被自己的轮询再次捕获。
    public func noteSelfWrite(hash: String) {
        lastSelfWriteHash = hash
    }

    /// 处理一次剪贴板快照。
    @discardableResult
    public func handle(_ snapshot: RawPasteboardSnapshot) async -> CaptureOutcome {
        // 1. 自身写回(marker)。
        if snapshot.isSelfWrite { return .skipped(.selfWrite) }

        // 2. 隐私标记。
        if let reason = privacyFilter.rejection(forMarkers: snapshot.privacyMarkers) {
            return .skipped(reason)
        }

        // 3. 确定类型与负载。
        guard let payload = makePayload(from: snapshot) else { return .skipped(.empty) }

        // 4. 去重指纹 + 防回环兜底。
        let hash = Self.contentHash(payload.bytes)
        if hash == lastSelfWriteHash { return .skipped(.selfWrite) }

        // 5. 去重:已存在则置顶,不新增。
        if let existingID = try? await repository.findID(byHash: hash) {
            try? await repository.touch(id: existingID, lastUsedAt: payload.date)
            return .deduped
        }

        // 6. 落盘/缩略图(后台)。
        let blobStore = self.blobStore
        let thumbnailer = self.thumbnailer
        let inlineLimit = self.inlineTextLimit
        let prepared = await Task.detached {
            try? Self.prepareStorage(payload: payload,
                                     blobStore: blobStore,
                                     thumbnailer: thumbnailer,
                                     inlineLimit: inlineLimit)
        }.value
        guard let prepared else { return .skipped(.empty) }

        // 7. 入库 + 裁剪。
        let draft = ClipItemDraft(
            kind: payload.kind,
            createdAt: payload.date,
            previewText: payload.previewText,
            searchText: payload.searchText,
            contentHash: hash,
            appBundleID: snapshot.sourceBundleID,
            appName: snapshot.sourceAppName,
            byteSize: payload.byteSize,
            payloadRef: prepared.payloadRef,
            thumbnailPath: prepared.thumbnailPath
        )
        do {
            _ = try await repository.insert(draft)
        } catch {
            return .skipped(.empty)
        }
        await trimming.trim(maxItems: settings.maxItems)
        return .captured
    }

    // MARK: 私有

    private struct Payload: Sendable {
        let kind: ClipKind
        let bytes: Data
        let ext: String?
        let previewText: String?
        let searchText: String
        let date: Date
        /// 展示用大小(图片=图片字节,文件=文件实际大小,文本=字节数)。
        let byteSize: Int
    }

    private struct PreparedStorage: Sendable {
        let payloadRef: PayloadRef
        let thumbnailPath: String?
    }

    private func makePayload(from snapshot: RawPasteboardSnapshot) -> Payload? {
        let timestamp = now()
        // 优先级:文件 > 图片 > 文本。文件优先可避免把 Finder 文件的图标当成图片。
        if !snapshot.fileURLs.isEmpty {
            let names = snapshot.fileURLs.compactMap { URL(string: $0)?.lastPathComponent }.joined(separator: ", ")
            let joined = snapshot.fileURLs.joined(separator: "\n")
            var totalSize = 0
            for urlString in snapshot.fileURLs {
                if let url = URL(string: urlString),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int {
                    totalSize += size
                }
            }
            return Payload(
                kind: .fileURL,
                bytes: Data(joined.utf8),
                ext: nil,
                previewText: names.isEmpty ? "文件" : names,
                searchText: (names + " " + joined).lowercased(),
                date: timestamp,
                byteSize: totalSize
            )
        }
        if let imageData = snapshot.imageData, !imageData.isEmpty {
            let appName = snapshot.sourceAppName ?? "图片"
            return Payload(
                kind: .image,
                bytes: imageData,
                ext: snapshot.imageExt ?? "png",
                previewText: nil,
                searchText: "\(appName) 图片".lowercased(),
                date: timestamp,
                byteSize: imageData.count
            )
        }
        if let text = snapshot.text, !text.isEmpty {
            let data = Data(text.utf8)
            return Payload(
                kind: .text,
                bytes: data,
                ext: nil,
                previewText: String(text.prefix(500)),
                searchText: text.lowercased(),
                date: timestamp,
                byteSize: data.count
            )
        }
        return nil
    }

    private nonisolated static func prepareStorage(
        payload: Payload,
        blobStore: BlobStoring,
        thumbnailer: ThumbnailService,
        inlineLimit: Int
    ) throws -> PreparedStorage {
        switch payload.kind {
        case .image:
            let path = try blobStore.write(payload.bytes, ext: payload.ext ?? "png")
            var thumbnailPath: String?
            if let thumb = thumbnailer.makeThumbnailPNG(from: payload.bytes) {
                thumbnailPath = try? blobStore.write(thumb, ext: "png")
            }
            return PreparedStorage(payloadRef: .file(relativePath: path), thumbnailPath: thumbnailPath)
        case .text, .rtf, .html, .fileURL:
            if payload.bytes.count <= inlineLimit {
                return PreparedStorage(payloadRef: .inline(payload.bytes), thumbnailPath: nil)
            } else {
                let path = try blobStore.write(payload.bytes, ext: "txt")
                return PreparedStorage(payloadRef: .file(relativePath: path), thumbnailPath: nil)
            }
        }
    }

    /// 负载内容的 SHA256 十六进制串。internal 以便测试复用。
    nonisolated static func contentHash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
