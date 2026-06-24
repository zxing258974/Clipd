import SwiftUI

/// 面板根视图:搜索框 + 历史列表 + 底部快捷键提示。
struct PanelRootView: View {
    @Bindable var store: ClipboardStore
    var onChoose: (ClipItem) -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $store.searchText, focus: $searchFocused)
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 360)
        .background(.ultraThinMaterial)
        .task {
            searchFocused = true
            await store.reload()
        }
    }

    @ViewBuilder private var content: some View {
        if store.items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: store.searchText.isEmpty ? "clipboard" : "magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundStyle(.tertiary)
                Text(store.searchText.isEmpty ? "暂无剪贴板历史" : "无匹配结果")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HistoryListView(store: store, onChoose: onChoose)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            hint("↑↓", "选择")
            hint("⏎", "粘贴")
            hint("esc", "关闭")
            Spacer()
            Text("\(store.items.count) 条")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
            Text(label)
        }
    }
}
