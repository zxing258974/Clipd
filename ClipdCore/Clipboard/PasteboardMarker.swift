import AppKit

/// 自身写回标记。
///
/// `PasteService` 每次把历史条目写回 `NSPasteboard` 时都附加此类型(空 Data);
/// `ClipboardMonitor` 见到它即跳过本次变化,避免"镜像副本"回环。
public enum PasteboardMarker {
    public static let appMarker = NSPasteboard.PasteboardType("com.zhangxing.Clipd.internal")
}
