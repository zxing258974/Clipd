import AppKit

/// 把历史条目写回 `NSPasteboard`,并附加 `appMarker`(防回环)。
@MainActor
public enum PasteboardWriter {
    /// 写回并返回写入后的 changeCount(供 Monitor 忽略,防回环双保险)。
    @discardableResult
    public static func write(kind: ClipKind, data: Data, imageExt: String?) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // 文件:写回为 file URL(粘的是文件引用,不是路径文本)。marker 放在首个 item。
        if kind == .fileURL {
            let urls = String(decoding: data, as: UTF8.self)
                .split(separator: "\n").compactMap { URL(string: String($0)) }
            if !urls.isEmpty {
                let items = urls.enumerated().map { index, url -> NSPasteboardItem in
                    let pbItem = NSPasteboardItem()
                    pbItem.setString(url.absoluteString, forType: .fileURL)
                    if index == 0 { pbItem.setData(Data(), forType: PasteboardMarker.appMarker) }
                    return pbItem
                }
                pasteboard.writeObjects(items)
                return pasteboard.changeCount
            }
        }

        let item = NSPasteboardItem()
        switch kind {
        case .image:
            let type: NSPasteboard.PasteboardType = (imageExt?.lowercased() == "tiff") ? .tiff : .png
            item.setData(data, forType: type)
        default:
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
