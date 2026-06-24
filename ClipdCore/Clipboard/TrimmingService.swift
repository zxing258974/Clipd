import Foundation

/// 历史裁剪与孤儿文件清理。
///
/// `trim` 仅删除未固定条目;删除条目的同时清理其 blob 文件。
/// `sweepOrphanBlobs` 在启动时清理数据库已不引用的残留文件(防崩溃中断导致的孤儿)。
public struct TrimmingService: Sendable {
    private let repository: ClipItemRepository
    private let blobStore: BlobStoring

    public init(repository: ClipItemRepository, blobStore: BlobStoring) {
        self.repository = repository
        self.blobStore = blobStore
    }

    /// 将未固定条目裁剪至上限,并删除被裁条目引用的 blob 文件。
    public func trim(maxItems: Int) async {
        let removed = (try? await repository.trimUnpinned(maxItems: maxItems)) ?? []
        for path in removed {
            try? blobStore.delete(relativePath: path)
        }
    }

    /// 时间淘汰:删除 `lastUsedAt` 早于 `retentionDays` 天前的未固定条目(固定项豁免),
    /// 并清理其 blob 文件。`retentionDays <= 0` 表示不按时间淘汰。
    public func evictExpired(retentionDays: Int, now: Date = Date()) async {
        guard retentionDays > 0 else { return }
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * Self.secondsPerDay)
        let removed = (try? await repository.deleteExpired(lastUsedBefore: cutoff)) ?? []
        for path in removed {
            try? blobStore.delete(relativePath: path)
        }
    }

    private static let secondsPerDay: Double = 86_400

    /// 删除 blobs 目录下数据库未引用的文件。
    public func sweepOrphanBlobs() async {
        guard let referenced = try? await repository.referencedBlobPaths() else { return }
        let root = blobStore.rootURL
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return }

        // 先取出全部 URL(NSEnumerator 的迭代器在 async 上下文不可用)。
        let urls = enumerator.allObjects.compactMap { $0 as? URL }
        let rootPath = root.standardizedFileURL.path
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }

            var relative = url.standardizedFileURL.path
            if relative.hasPrefix(rootPath) {
                relative.removeFirst(rootPath.count)
                if relative.hasPrefix("/") { relative.removeFirst() }
            }
            if !referenced.contains(relative) {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
