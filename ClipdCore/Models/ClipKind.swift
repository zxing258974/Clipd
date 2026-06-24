import Foundation

/// 一条剪贴板内容的语义类型。
///
/// 当一次复制包含多种表示(如浏览器复制同时带 html/rtf/plain text)时,
/// 按 `fileURL > image > rtf > html > text` 的优先级选出最有意义的一种作为 `ClipKind`,
/// 但搜索文本仍尽量取纯文本表示。
public enum ClipKind: String, Sendable, Codable, CaseIterable {
    case text
    case rtf
    case html
    case image
    case fileURL
}
