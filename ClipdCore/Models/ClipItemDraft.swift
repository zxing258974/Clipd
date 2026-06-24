import Foundation

/// 写入用的草稿(尚未分配 id 与 lastUsedAt)。
///
/// 由 `CaptureService` 组装:它已完成隐私过滤、去重哈希、缩略图生成与大负载落盘,
/// 因此 `payloadRef` 与 `thumbnailPath` 在此已确定。
public struct ClipItemDraft: Sendable {
    public let kind: ClipKind
    public let createdAt: Date
    public let previewText: String?
    public let searchText: String
    public let contentHash: String
    public let appBundleID: String?
    public let appName: String?
    public let byteSize: Int
    public let payloadRef: PayloadRef
    public let thumbnailPath: String?

    public init(
        kind: ClipKind,
        createdAt: Date,
        previewText: String?,
        searchText: String,
        contentHash: String,
        appBundleID: String?,
        appName: String?,
        byteSize: Int,
        payloadRef: PayloadRef,
        thumbnailPath: String?
    ) {
        self.kind = kind
        self.createdAt = createdAt
        self.previewText = previewText
        self.searchText = searchText
        self.contentHash = contentHash
        self.appBundleID = appBundleID
        self.appName = appName
        self.byteSize = byteSize
        self.payloadRef = payloadRef
        self.thumbnailPath = thumbnailPath
    }
}
