import SwiftUI
import AppKit

/// 单张剪贴板卡片(240 宽,撑满墙高),按内容类型分版式 + 选中序号角标。
struct ClipCardView: View {
    let item: ClipItem
    let isSelected: Bool
    let thumbnailURL: URL?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardWidth: CGFloat = 240

    var body: some View {
        let theme = ClipTheme(scheme: scheme)
        let p = CardPresenter.present(item)
        VStack(spacing: 0) {
            header(p)
            bodyView(p, theme)
            footer(p, theme)
        }
        .frame(width: cardWidth)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.cardFill))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? ClipTheme.accent : theme.cardBorder, lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.28 : 0.10), radius: isSelected ? 14 : 5, y: isSelected ? 8 : 3)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel(p))
        .accessibilityHint("双击或按回车粘贴")
    }

    // MARK: header

    private func header(_ p: CardPresentation) -> some View {
        HStack(spacing: 8) {
            appIcon(p)
            Text(p.appName).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 4)
            if item.isPinned {
                Circle().fill(ClipTheme.accent).frame(width: 6, height: 6)
            }
            Text(p.relativeTime).font(.system(size: 11)).foregroundStyle(.tertiary).fixedSize()
        }
        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)
    }

    @ViewBuilder private func appIcon(_ p: CardPresentation) -> some View {
        if let icon = AppIconCache.icon(forBundleID: item.appBundleID) {
            Image(nsImage: icon).resizable().frame(width: 20, height: 20)
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(p.tagColor)
                .frame(width: 20, height: 20)
                .overlay(Text(String(p.appName.prefix(1))).font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
        }
    }

    // MARK: body(按类型)

    @ViewBuilder private func bodyView(_ p: CardPresentation, _ theme: ClipTheme) -> some View {
        Group {
            switch p.kind {
            case .text: textBody(p)
            case .code: codeBody(p, theme)
            case .link: linkBody(p, theme)
            case .image: imageBody(p)
            case .color: colorBody(p)
            case .file: fileBody(p)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func textBody(_ p: CardPresentation) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(p.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
            if !p.body.isEmpty {
                Text(p.body).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(6)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
    }

    private func codeBody(_ p: CardPresentation, _ theme: ClipTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.title).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
            Text(p.body)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(theme.codeText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(theme.inset))
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12).padding(.bottom, 10)
    }

    private func linkBody(_ p: CardPresentation, _ theme: ClipTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "link").font(.system(size: 11)).foregroundStyle(.secondary)
                Text(p.domain)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(theme.pill))
            }
            Text(p.title).font(.system(size: 13, weight: .semibold)).lineLimit(4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12).padding(.top, 12)
    }

    @ViewBuilder private func imageBody(_ p: CardPresentation) -> some View {
        if let url = thumbnailURL, let img = ThumbnailCache.shared.image(forPath: url.path) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit) // 完整显示整张图,不裁切
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(Color.primary.opacity(0.04))
        } else {
            CardPresenter.gradient(seed: p.appName)
        }
    }

    private func colorBody(_ p: CardPresentation) -> some View {
        ZStack {
            (p.swatch ?? Color.gray)
            VStack {
                Spacer()
                Text(p.hex)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.28)))
                    .padding(.bottom, 14)
            }
        }
    }

    private func fileBody(_ p: CardPresentation) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.fill").font(.system(size: 44)).foregroundStyle(.secondary)
            Text(p.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }

    // MARK: footer

    private func footer(_ p: CardPresentation, _ theme: ClipTheme) -> some View {
        HStack(spacing: 6) {
            Circle().fill(p.tagColor).frame(width: 7, height: 7)
            Text(p.tag).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(p.meta).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .overlay(alignment: .top) { Rectangle().fill(theme.hairline).frame(height: 1) }
    }

    private func accessibilityLabel(_ p: CardPresentation) -> String {
        let pin = item.isPinned ? ",已固定" : ""
        switch p.kind {
        case .image: return "图片,来自 \(p.appName)\(pin)"
        case .color: return "颜色 \(p.hex),来自 \(p.appName)\(pin)"
        case .link: return "链接 \(p.domain),来自 \(p.appName)\(pin)"
        default: return "\(p.tag):\(p.title),来自 \(p.appName)\(pin)"
        }
    }
}
