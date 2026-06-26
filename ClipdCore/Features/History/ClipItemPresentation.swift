import SwiftUI
import AppKit

// MARK: - 筛选

/// 顶部筛选 pills。内置类型 + 动态标签 `.tag`。
public enum ClipFilter: Hashable, Sendable {
    case all, pinned, text, links, images, colors, files
    case tag(String)

    /// 内置筛选(不含动态标签),用于固定顺序渲染 pills。
    public static let builtins: [ClipFilter] = [.all, .pinned, .text, .links, .images, .colors, .files]

    var label: String {
        switch self {
        case .all: "全部"
        case .pinned: "已固定"
        case .text: "文本"
        case .links: "链接"
        case .images: "图片"
        case .colors: "颜色"
        case .files: "文件"
        case .tag(let name): name
        }
    }

    /// 是否为标签筛选(UI 用以区分样式)。
    var isTag: Bool { if case .tag = self { return true } else { return false } }
}

// MARK: - 展示类型(由内容派生,不改数据模型)

enum CardKind { case text, code, link, image, color, file }

struct CardPresentation {
    let kind: CardKind
    let appName: String
    let relativeTime: String
    let tag: String
    let tagColor: Color
    let meta: String
    let title: String
    let body: String
    let domain: String
    let hex: String
    let swatch: Color?
}

// MARK: - 分类器

enum ClipClassifier {
    static func cardKind(for item: ClipItem) -> CardKind {
        switch item.kind {
        case .image: return .image
        case .fileURL: return .file
        case .rtf, .html: return .text
        case .text:
            let t = (item.previewText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if isHexColor(t) { return .color }
            if isLink(t) { return .link }
            if isCode(t, appName: item.appName) { return .code }
            return .text
        }
    }

    static func isHexColor(_ s: String) -> Bool {
        s.range(of: "^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$", options: .regularExpression) != nil
    }

    static func isLink(_ s: String) -> Bool {
        guard !s.isEmpty, !s.contains(" "), !s.contains("\n") else { return false }
        if s.hasPrefix("http://") || s.hasPrefix("https://") { return true }
        return s.range(of: "^[\\w.-]+\\.[a-zA-Z]{2,}(/.*)?$", options: .regularExpression) != nil
    }

    static func isCode(_ s: String, appName: String?) -> Bool {
        guard s.contains("\n") else { return false }
        let editors = ["code", "xcode", "terminal", "iterm", "sublime", "intellij", "pycharm", "webstorm", "nova"]
        if let a = appName?.lowercased(), editors.contains(where: { a.contains($0) }) { return true }
        let tokens = ["{", "}", ";", "=>", "func ", "function ", "const ", "let ", "var ", "def ", "class ", "import ", "return ", "</", "/>"]
        return tokens.contains { s.contains($0) }
    }

    static func matches(_ item: ClipItem, filter: ClipFilter) -> Bool {
        switch filter {
        case .all: return true
        case .pinned: return item.isPinned
        case .text: let k = cardKind(for: item); return k == .text || k == .code
        case .links: return cardKind(for: item) == .link
        case .images: return cardKind(for: item) == .image
        case .colors: return cardKind(for: item) == .color
        case .files: return cardKind(for: item) == .file
        case .tag(let name): return item.tags.contains(name)
        }
    }
}

// MARK: - 展示构建

enum CardPresenter {
    static func present(_ item: ClipItem, now: Date = Date()) -> CardPresentation {
        let kind = ClipClassifier.cardKind(for: item)
        let raw = (item.previewText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let app = (item.appName?.isEmpty == false) ? item.appName! : (kind == .image ? "截图" : "剪贴板")
        let time = relativeTime(item.lastUsedAt, now: now)
        let (tag, tagColor) = tagInfo(kind)

        switch kind {
        case .color:
            return CardPresentation(kind: kind, appName: app, relativeTime: time, tag: tag, tagColor: tagColor,
                                    meta: rgbMeta(raw), title: raw.uppercased(), body: "", domain: "",
                                    hex: raw.uppercased(), swatch: Color(hex: raw))
        case .link:
            return CardPresentation(kind: kind, appName: app, relativeTime: time, tag: tag, tagColor: tagColor,
                                    meta: "网页链接", title: stripScheme(raw), body: "", domain: domain(of: raw),
                                    hex: "", swatch: nil)
        case .code:
            return CardPresentation(kind: kind, appName: app, relativeTime: time, tag: tag, tagColor: tagColor,
                                    meta: "代码", title: firstLine(raw), body: raw, domain: "", hex: "", swatch: nil)
        case .image:
            return CardPresentation(kind: kind, appName: app, relativeTime: time, tag: tag, tagColor: tagColor,
                                    meta: sizeMeta(item.byteSize), title: "图片", body: "", domain: "", hex: "", swatch: nil)
        case .file:
            return CardPresentation(kind: kind, appName: app, relativeTime: time, tag: tag, tagColor: tagColor,
                                    meta: sizeMeta(item.byteSize), title: raw.isEmpty ? "文件" : firstLine(raw),
                                    body: "", domain: "", hex: "", swatch: nil)
        case .text:
            let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let title = lines.first ?? ""
            let body = lines.count > 1 ? lines.dropFirst().joined(separator: "\n") : ""
            return CardPresentation(kind: kind, appName: app, relativeTime: time, tag: tag, tagColor: tagColor,
                                    meta: "\(raw.count) 字符", title: title.isEmpty ? "(空白)" : title,
                                    body: body, domain: "", hex: "", swatch: nil)
        }
    }

    // MARK: 辅助

    static func tagInfo(_ kind: CardKind) -> (String, Color) {
        switch kind {
        case .text: ("文本", Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255))
        case .code: ("代码", Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255))
        case .link: ("链接", Color(red: 100 / 255, green: 210 / 255, blue: 255 / 255))
        case .image: ("图片", Color(red: 255 / 255, green: 55 / 255, blue: 95 / 255))
        case .color: ("颜色", Color(red: 255 / 255, green: 159 / 255, blue: 10 / 255))
        case .file: ("文件", Color(red: 152 / 255, green: 152 / 255, blue: 157 / 255))
        }
    }

    static func relativeTime(_ date: Date, now: Date) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 60 { return "刚刚" }
        if s < 3600 { return "\(Int(s / 60)) 分钟前" }
        if s < 86400 { return "\(Int(s / 3600)) 小时前" }
        if s < 172_800 { return "昨天" }
        return "\(Int(s / 86400)) 天前"
    }

    static func sizeMeta(_ bytes: Int) -> String {
        bytes > 0 ? ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) : "图片"
    }

    static func rgbMeta(_ hex: String) -> String {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count >= 6, let v = UInt64(s.prefix(6), radix: 16) else { return "颜色" }
        return "RGB \((v >> 16) & 0xFF) · \((v >> 8) & 0xFF) · \(v & 0xFF)"
    }

    static func domain(of url: String) -> String {
        var s = url
        if let r = s.range(of: "://") { s = String(s[r.upperBound...]) }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        return s
    }

    static func stripScheme(_ url: String) -> String {
        if let r = url.range(of: "://") { return String(url[r.upperBound...]) }
        return url
    }

    static func firstLine(_ s: String) -> String { String(s.split(separator: "\n").first ?? "") }

    /// 由种子串生成确定性渐变(链接头图 / 图片占位)。
    static func gradient(seed: String) -> LinearGradient {
        var h = 5381
        for b in seed.utf8 { h = (h &* 33) &+ Int(b) }
        let hue1 = Double(abs(h) % 360) / 360
        let hue2 = (hue1 + 0.13).truncatingRemainder(dividingBy: 1)
        return LinearGradient(
            colors: [Color(hue: hue1, saturation: 0.62, brightness: 0.82),
                     Color(hue: hue2, saturation: 0.58, brightness: 0.68)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - hex → Color

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255; b = Double(v & 0xFF) / 255; a = 1
        } else {
            r = Double((v >> 24) & 0xFF) / 255; g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255; a = Double(v & 0xFF) / 255
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - App 图标缓存

@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(forBundleID id: String?) -> NSImage? {
        guard let id, !id.isEmpty else { return nil }
        if let cached = cache[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[id] = icon
        return icon
    }
}
