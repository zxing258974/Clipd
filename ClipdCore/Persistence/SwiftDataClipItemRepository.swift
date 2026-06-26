import Foundation
import SwiftData

/// `ClipItemRepository` 的 SwiftData 实现。
///
/// `@ModelActor` 提供独立 `ModelContext` 与串行执行器:所有数据库操作在该 actor 内
/// 串行进行,天然线程安全且不阻塞主线程渲染。actor 隔离的同步方法用于满足协议的
/// `async` 要求(跨 actor 访问自动变为 async)。
@ModelActor
actor SwiftDataClipItemRepository: ClipItemRepository {

    // MARK: 写入

    func insert(_ draft: ClipItemDraft) throws -> ClipItem {
        let entity = ClipItemEntity(draft: draft)
        modelContext.insert(entity)
        try modelContext.save()
        return entity.toClipItem()
    }

    func touch(id: UUID, lastUsedAt: Date) throws {
        guard let entity = try entity(id: id) else { return }
        entity.lastUsedAt = lastUsedAt
        try modelContext.save()
    }

    func setPinned(id: UUID, _ pinned: Bool) throws {
        guard let entity = try entity(id: id) else { return }
        entity.isPinned = pinned
        try modelContext.save()
    }

    func setTags(_ tags: [String], id: UUID) throws {
        guard let entity = try entity(id: id) else { return }
        // 去重 + 去空白 + 稳定排序,保证展示顺序确定。
        entity.tags = Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })).sorted()
        try modelContext.save()
    }

    // MARK: 读取

    func fetch(_ query: HistoryQuery) throws -> [ClipItem] {
        // 全量取出后在内存过滤/排序/分页:历史受上限约束(默认 999),开销可忽略,
        // 且规避 macOS 14 SwiftData `#Predicate` 的大小写/可选链不稳问题。
        let entities = try modelContext.fetch(FetchDescriptor<ClipItemEntity>())
        var items = entities.map { $0.toClipItem() }

        if let term = query.searchText?.lowercased(), !term.isEmpty {
            items = items.filter { $0.searchText.contains(term) }
        }
        if let kinds = query.kinds {
            items = items.filter { kinds.contains($0.kind) }
        }
        if query.pinnedOnly {
            items = items.filter { $0.isPinned }
        }

        // 固定项置顶,其余按 lastUsedAt 降序(避免对 Bool 用 SortDescriptor)。
        items.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.lastUsedAt > rhs.lastUsedAt
        }

        let start = min(query.offset, items.count)
        let end = min(start + query.limit, items.count)
        return Array(items[start..<end])
    }

    func findID(byHash hash: String) throws -> UUID? {
        var descriptor = FetchDescriptor<ClipItemEntity>(
            predicate: #Predicate { $0.contentHash == hash }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.id
    }

    func payloadRef(for id: UUID) throws -> PayloadRef? {
        try entity(id: id)?.payloadRef()
    }

    func referencedBlobPaths() throws -> Set<String> {
        let entities = try modelContext.fetch(FetchDescriptor<ClipItemEntity>())
        return Set(entities.flatMap { $0.blobPaths })
    }

    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<ClipItemEntity>())
    }

    // MARK: 删除 / 裁剪

    func delete(ids: [UUID]) throws -> [String] {
        var blobPaths: [String] = []
        for id in ids {
            guard let entity = try entity(id: id) else { continue }
            blobPaths.append(contentsOf: entity.blobPaths)
            modelContext.delete(entity)
        }
        try modelContext.save()
        return blobPaths
    }

    func trimUnpinned(maxItems: Int) throws -> [String] {
        var descriptor = FetchDescriptor<ClipItemEntity>(
            predicate: #Predicate { $0.isPinned == false },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)] // 最旧在前
        )
        descriptor.includePendingChanges = true
        let unpinned = try modelContext.fetch(descriptor)
        guard unpinned.count > maxItems else { return [] }

        let excess = unpinned.prefix(unpinned.count - maxItems)
        var blobPaths: [String] = []
        for entity in excess {
            blobPaths.append(contentsOf: entity.blobPaths)
            modelContext.delete(entity)
        }
        try modelContext.save()
        return blobPaths
    }

    func deleteExpired(lastUsedBefore cutoff: Date) throws -> [String] {
        // 全量取出后内存过滤(与 fetch 一致,规避 #Predicate 的 Date/Bool 组合不稳)。
        let all = try modelContext.fetch(FetchDescriptor<ClipItemEntity>())
        let expired = all.filter { !$0.isPinned && $0.lastUsedAt < cutoff }
        var blobPaths: [String] = []
        for entity in expired {
            blobPaths.append(contentsOf: entity.blobPaths)
            modelContext.delete(entity)
        }
        try modelContext.save()
        return blobPaths
    }

    // MARK: 私有

    private func entity(id: UUID) throws -> ClipItemEntity? {
        var descriptor = FetchDescriptor<ClipItemEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
