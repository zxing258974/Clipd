import AppKit

/// 把历史条目写回 `NSPasteboard`,并附加 `appMarker`(防回环)。
@MainActor
public enum PasteboardWriter {
    /// 写回并返回写入后的 changeCount(供 Monitor 忽略,防回环双保险)。
    @discardableResult
    public static func write(kind: ClipKind, data: Data, imageExt: String?) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let item = NSPasteboardItem()
        switch kind {
        case .image:
            let type: NSPasteboard.PasteboardType = (imageExt?.lowercased() == "tiff") ? .tiff : .png
            item.setData(data, forType: type)
        case .text, .rtf, .html, .fileURL:
            if let string = String(data: data, encoding: .utf8) {
                item.setString(string, forType: .string)
            } else {
                item.setData(data, forType: .string)
            }
        }
        // 自身写回标记:Monitor 见到即跳过。
        item.setData(Data(), forType: PasteboardMarker.appMarker)

        pasteboard.writeObjects([item])
        return pasteboard.changeCount
    }
}
