import Foundation

/// 一次剪贴板读取的原始快照(Sendable),由 `ClipboardMonitor` 产出、`CaptureService` 消费。
///
/// MVP 关注文本与图片两类负载;富文本/文件在阶段 2 扩展。
public struct RawPasteboardSnapshot: Sendable {
    public let changeCount: Int
    /// 含 `appMarker` —— 我们自己写回的内容。
    public let isSelfWrite: Bool
    /// `org.nspasteboard.*` 隐私标记集合。
    public let privacyMarkers: Set<String>
    public let text: String?
    public let imageData: Data?
    /// 图片扩展名("png" | "tiff")。
    public let imageExt: String?
    /// 复制的文件(Finder)的 file URL 绝对串;非文件为空。
    public let fileURLs: [String]
    public let sourceBundleID: String?
    public let sourceAppName: String?

    public init(
        changeCount: Int,
        isSelfWrite: Bool = false,
        privacyMarkers: Set<String> = [],
        text: String? = nil,
        imageData: Data? = nil,
        imageExt: String? = nil,
        fileURLs: [String] = [],
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.changeCount = changeCount
        self.isSelfWrite = isSelfWrite
        self.privacyMarkers = privacyMarkers
        self.text = text
        self.imageData = imageData
        self.imageExt = imageExt
        self.fileURLs = fileURLs
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
    }
}
