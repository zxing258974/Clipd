import Foundation

/// UI 与服务层通用的剪贴板条目快照(不可变值类型)。
///
/// 这是 `ClipItemEntity`(SwiftData `@Model`)读出后转换的 `Sendable` 投影,
/// 用于跨线程传递与列表渲染。**故意不携带负载字节**:列表只需要
/// `previewText` 与 `thumbnailPath`;真正的负载在粘贴时经
/// `ClipItemRepository.payloadRef(for:)` 懒加载。
public struct ClipItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: ClipKind
    public let createdAt: Date
    public var lastUsedAt: Date
    public var isPinned: Bool
    public let previewText: String?
    public let searchText: String
    public let appBundleID: String?
    public let appName: String?
    public let byteSize: Int
    /// 图片缩略图的 blobs 相对路径(非图片为 nil)。
    public let thumbnailPath: String?
    /// 用户自定义标签(可为空)。
    public let tags: [String]

    public init(
        id: UUID,
        kind: ClipKind,
        createdAt: Date,
        lastUsedAt: Date,
        isPinned: Bool,
        previewText: String?,
        searchText: String,
        appBundleID: String?,
        appName: String?,
        byteSize: Int,
        thumbnailPath: String?,
        tags: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.previewText = previewText
        self.searchText = searchText
        self.appBundleID = appBundleID
        self.appName = appName
        self.byteSize = byteSize
        self.thumbnailPath = thumbnailPath
        self.tags = tags
    }
}
