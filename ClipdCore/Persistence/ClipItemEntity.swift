import Foundation
import SwiftData

/// SwiftData 持久化实体。
///
/// 这是实现细节,**绝不离开 `@ModelActor`**;出口处统一转成 `ClipItem`(Sendable)。
@Model
final class ClipItemEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var createdAt: Date
    var lastUsedAt: Date
    var isPinned: Bool

    var previewText: String?
    /// 已规范化为小写的搜索文本(配合内存 `contains` 匹配)。
    var searchText: String
    /// 去重指纹(负载的 SHA256)。
    var contentHash: String

    var appBundleID: String?
    var appName: String?
    var byteSize: Int

    /// "inline" | "file"
    var storageRaw: String
    @Attribute(.externalStorage) var inlineData: Data?
    var filePath: String?
    var thumbnailPath: String?

    init(id: UUID = UUID(), draft: ClipItemDraft) {
        self.id = id
        self.kindRaw = draft.kind.rawValue
        self.createdAt = draft.createdAt
        self.lastUsedAt = draft.createdAt
        self.isPinned = false
        self.previewText = draft.previewText
        self.searchText = draft.searchText
        self.contentHash = draft.contentHash
        self.appBundleID = draft.appBundleID
        self.appName = draft.appName
        self.byteSize = draft.byteSize
        self.thumbnailPath = draft.thumbnailPath
        switch draft.payloadRef {
        case .inline(let data):
            self.storageRaw = "inline"
            self.inlineData = data
            self.filePath = nil
        case .file(let relativePath):
            self.storageRaw = "file"
            self.inlineData = nil
            self.filePath = relativePath
        }
    }

    /// 转成跨线程安全的领域快照(不读取负载字节)。
    func toClipItem() -> ClipItem {
        ClipItem(
            id: id,
            kind: ClipKind(rawValue: kindRaw) ?? .text,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            isPinned: isPinned,
            previewText: previewText,
            searchText: searchText,
            appBundleID: appBundleID,
            appName: appName,
            byteSize: byteSize,
            thumbnailPath: thumbnailPath
        )
    }

    /// 该行引用的所有 blob 相对路径(原件 + 缩略图),供删除/裁剪时清理文件。
    var blobPaths: [String] {
        [filePath, thumbnailPath].compactMap { $0 }
    }

    /// 还原负载位置。
    func payloadRef() -> PayloadRef? {
        if storageRaw == "inline" {
            guard let data = inlineData else { return nil }
            return .inline(data)
        } else {
            guard let path = filePath else { return nil }
            return .file(relativePath: path)
        }
    }
}
