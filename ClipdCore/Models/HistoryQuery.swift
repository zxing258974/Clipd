import Foundation

/// 历史查询条件。
///
/// 搜索与类型过滤在内存中完成(规避 macOS 14 SwiftData `#Predicate`
/// 对大小写/可选链支持不稳的问题);历史条数受上限约束,内存过滤开销可忽略。
public struct HistoryQuery: Sendable {
    /// 搜索词(调用方无需关心大小写,内部按小写匹配)。
    public var searchText: String?
    /// 类型过滤;nil 表示不限。
    public var kinds: Set<ClipKind>?
    /// 仅返回已固定项。
    public var pinnedOnly: Bool
    public var limit: Int
    public var offset: Int

    public init(
        searchText: String? = nil,
        kinds: Set<ClipKind>? = nil,
        pinnedOnly: Bool = false,
        limit: Int = 200,
        offset: Int = 0
    ) {
        self.searchText = searchText
        self.kinds = kinds
        self.pinnedOnly = pinnedOnly
        self.limit = limit
        self.offset = offset
    }
}
