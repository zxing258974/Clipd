import SwiftUI
import AppKit

/// 历史列表中的一行:类型图标 / 图片缩略图 + 预览 + 来源 App + 固定标记。
struct ClipRowView: View {
    let item: ClipItem
    let isSelected: Bool
    let thumbnailURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)
                HStack(spacing: 5) {
                    Text(kindLabel)
                    if let app = item.appName, !app.isEmpty {
                        Text("· \(app)").lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    @ViewBuilder private var iconView: some View {
        if item.kind == .image, let url = thumbnailURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(.white.opacity(0.12))
                )
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: kindSymbol)
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var primaryText: String {
        switch item.kind {
        case .image:
            return "图片"
        default:
            let trimmed = item.previewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "(空白)" : trimmed
        }
    }

    private var kindLabel: String {
        switch item.kind {
        case .image: return "图片"
        case .fileURL: return "文件"
        case .rtf, .html: return "富文本"
        case .text: return "文本"
        }
    }

    private var kindSymbol: String {
        switch item.kind {
        case .image: return "photo"
        case .fileURL: return "doc"
        case .rtf, .html: return "doc.richtext"
        case .text: return "text.alignleft"
        }
    }
}
