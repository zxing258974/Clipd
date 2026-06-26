import SwiftUI

/// 面板内"新建标签"输入覆盖层。
///
/// 焦点交给内部 TextField;<kbd>esc</kbd>(取消)/<kbd>⏎</kbd>(提交)由 `PanelController`
/// 的本地按键监听接管,其余按键留给文本框正常编辑。面板自身保持 key,故不会触发失焦自动关闭。
struct NewTagOverlayView: View {
    @Bindable var store: ClipboardStore
    let theme: ClipTheme

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(theme.isDark ? 0.55 : 0.32))
                .contentShape(Rectangle())
                .onTapGesture { store.cancelNewTag() }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "tag").foregroundStyle(ClipTheme.accent)
                    Text("新建标签").font(.system(size: 15, weight: .semibold))
                }
                TextField("标签名", text: $store.newTagDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($focused)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(Capsule().fill(theme.searchBg))
                    .onSubmit { Task { await store.commitNewTag() } }
                HStack(spacing: 14) {
                    hint("⏎", "添加")
                    hint("esc", "取消")
                    Spacer()
                }
            }
            .padding(20)
            .frame(width: 320)
            .background(.ultraThinMaterial)
            .background(theme.barTint)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.32), radius: 28, y: 12)
        }
        .task { focused = true }
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
}
