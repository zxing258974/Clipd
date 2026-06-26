import SwiftUI
import AppKit

/// 空格预览:覆盖在面板之上的 Quick Look 风格大图预览。
///
/// 不新建窗口、不改变键盘焦点 —— 仅是面板内的一层 overlay,
/// 故 ←→ 切换选中、⏎ 粘贴、esc/空格 关闭都仍由 `PanelController` 的本地按键监听处理。
/// 内容按类型懒加载:文本/代码/链接/文件读全文,图片取原图(非缩略图)。
struct PreviewOverlayView: View {
    @Bindable var store: ClipboardStore
    let theme: ClipTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fullText = ""
    @State private var fullImage: NSImage?
    @State private var isLoading = false

    private let maxCardWidth: CGFloat = 760

    var body: some View {
        ZStack {
            // 背景遮罩:点击关闭。
            Rectangle()
                .fill(Color.black.opacity(theme.isDark ? 0.55 : 0.32))
                .contentShape(Rectangle())
                .onTapGesture { store.closePreview() }

            if let item = store.selectedItem {
                detailCard(item)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 22)
            }
        }
        .task(id: store.selectedID) { await load() }
    }

    // MARK: 详情卡

    private func detailCard(_ item: ClipItem) -> some View {
        let p = CardPresenter.present(item)
        return VStack(spacing: 0) {
            header(item, p)
            theme.hairline.frame(height: 1)
            body(item, p)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            theme.hairline.frame(height: 1)
            footer(p)
        }
        .frame(maxWidth: maxCardWidth, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(theme.barTint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.32), radius: 28, y: 12)
    }

    private func header(_ item: ClipItem, _ p: CardPresentation) -> some View {
        HStack(spacing: 10) {
            Circle().fill(p.tagColor).frame(width: 8, height: 8)
            Text(p.tag).font(.system(size: 13, weight: .semibold))
            Text(p.appName).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            if item.isPinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(ClipTheme.accent)
            }
            Spacer(minLength: 8)
            Text(metaLine(item, p)).font(.system(size: 12)).foregroundStyle(.tertiary).lineLimit(1)
            Button { store.closePreview() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭预览")
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
    }

    // MARK: body(按类型)

    @ViewBuilder private func body(_ item: ClipItem, _ p: CardPresentation) -> some View {
        switch p.kind {
        case .text: textBody(monospaced: false)
        case .code: textBody(monospaced: true)
        case .link: linkBody(p)
        case .image: imageBody
        case .color: colorBody(p)
        case .file: fileBody(p)
        }
    }

    private func textBody(monospaced: Bool) -> some View {
        ScrollView([.vertical, .horizontal]) {
            Text(fullText.isEmpty ? " " : fullText)
                .font(.system(size: monospaced ? 13 : 14, design: monospaced ? .monospaced : .default))
                .foregroundStyle(monospaced ? theme.codeText : Color.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }

    private func linkBody(_ p: CardPresentation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill").font(.system(size: 22)).foregroundStyle(p.tagColor)
                Text(p.domain).font(.system(size: 18, weight: .semibold))
            }
            Text(fullText.isEmpty ? p.title : fullText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    @ViewBuilder private var imageBody: some View {
        ZStack {
            Color.primary.opacity(0.04)
            if let image = fullImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo").font(.system(size: 44)).foregroundStyle(.tertiary)
            }
        }
    }

    private func colorBody(_ p: CardPresentation) -> some View {
        ZStack {
            (p.swatch ?? Color.gray)
            VStack(spacing: 8) {
                Text(p.hex)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(p.meta)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.28)))
        }
    }

    private func fileBody(_ p: CardPresentation) -> some View {
        let paths = (fullText.isEmpty ? p.title : fullText)
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill").font(.system(size: 22)).foregroundStyle(p.tagColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName(path)).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Text(path).font(.system(size: 11)).foregroundStyle(.tertiary)
                                .textSelection(.enabled).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    // MARK: footer

    private func footer(_ p: CardPresentation) -> some View {
        HStack(spacing: 18) {
            hint("⏎", "粘贴")
            hint("← →", "切换")
            hint("空格 / esc", "关闭")
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(theme.kbd))
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    // MARK: 加载与辅助

    private func load() async {
        guard let item = store.selectedItem else { return }
        fullImage = nil
        fullText = ""
        let kind = ClipClassifier.cardKind(for: item)
        if kind == .image {
            isLoading = true
            defer { isLoading = false }
            guard let url = await store.fullImageURL(for: item) else { return }
            let data = await Task.detached { try? Data(contentsOf: url) }.value
            // 选中项可能在加载期间已切换,丢弃过期结果。
            guard store.selectedID == item.id, let data else { return }
            fullImage = NSImage(data: data)
        } else if kind != .color {
            let text = await store.fullText(for: item)
            guard store.selectedID == item.id else { return }
            fullText = text
        }
    }

    private func metaLine(_ item: ClipItem, _ p: CardPresentation) -> String {
        var detail = p.meta
        if p.kind == .image, let image = fullImage, let rep = image.representations.first {
            detail = "\(rep.pixelsWide) × \(rep.pixelsHigh) · \(p.meta)"
        } else if p.kind == .text || p.kind == .code, !fullText.isEmpty {
            detail = "\(fullText.count) 字符"
        }
        return "\(p.relativeTime) · \(detail)"
    }

    private func fileName(_ path: String) -> String {
        (URL(string: path) ?? URL(fileURLWithPath: path)).lastPathComponent
    }
}
