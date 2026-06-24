import Foundation

/// 剪贴板历史数据访问接口(Repository 模式)。
///
/// 唯一接触 SwiftData 的边界。对外只收发 `Sendable` 值类型,`@Model` 实体不外漏。
/// 负载文件的实际读写由调用方借助 `BlobStoring` 完成:本接口的 `delete`/`trimUnpinned`
/// 返回需清理的 blob 相对路径,而非自行删除文件(保持职责单一,亦便于 `@ModelActor`)。
public protocol ClipItemRepository: Sendable {
    /// 插入新条目,返回其快照。
    func insert(_ draft: ClipItemDraft) async throws -> ClipItem

    /// 按条件查询(搜索/类型/固定过滤在内存完成)。结果:固定项置顶,其余按 `lastUsedAt` 降序。
    func fetch(_ query: HistoryQuery) async throws -> [ClipItem]

    /// 按去重指纹查已存在条目的 id(用于"再次复制置顶")。
    func findID(byHash hash: String) async throws -> UUID?

    /// 更新 `lastUsedAt`(置顶)。
    func touch(id: UUID, lastUsedAt: Date) async throws

    /// 设置/取消固定。
    func setPinned(id: UUID, _ pinned: Bool) async throws

    /// 取负载位置(粘贴时懒加载用)。
    func payloadRef(for id: UUID) async throws -> PayloadRef?

    /// 删除指定条目,返回它们引用的 blob 相对路径(供调用方清理文件)。
    func delete(ids: [UUID]) async throws -> [String]

    /// 将未固定条目裁剪至 `maxItems`(删除最旧的多余项),返回被删项引用的 blob 路径。
    func trimUnpinned(maxItems: Int) async throws -> [String]

    /// 当前所有被引用的 blob 相对路径(供启动孤儿扫描)。
    func referencedBlobPaths() async throws -> Set<String>

    /// 删除 `lastUsedAt` 早于 cutoff 的未固定条目(时间淘汰),返回被删项引用的 blob 路径。
    func deleteExpired(lastUsedBefore cutoff: Date) async throws -> [String]

    /// 条目总数。
    func count() async throws -> Int
}
