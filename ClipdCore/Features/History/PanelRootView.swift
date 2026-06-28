import SwiftUI

/// 底部卡片栏根视图:顶栏(标题/计数 + 筛选 pills + 搜索 + 设置)+ 卡片墙 + 底部提示。
struct PanelRootView: View {
    @Bindable var store: ClipboardStore
    var onChoose: (ClipItem) -> Void
    var onCopy: (ClipItem) -> Void
    var onOpenSettings: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("clipd.appearance") private var appearance = "system"
    @FocusState private var searchFocused: Bool

    private var topCorners: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0, topTrailingRadius: 18, style: .continuous)
    }

    var body: some View {
        let effectiveScheme: ColorScheme = appearance == "light" ? .light : (appearance == "dark" ? .dark : scheme)
        let theme = ClipTheme(scheme: effectiveScheme)
        VStack(spacing: 0) {
            header(theme)
            theme.hairline.frame(height: 1)
            content(theme)
            theme.hairline.frame(height: 1)
            footer(theme)
        }
        .background(theme.barTint)
        .background(.ultraThinMaterial)
        .overlay {
            if store.isPreviewing {
                PreviewOverlayView(store: store, theme: theme)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .overlay {
            if store.isCreatingTag {
                NewTagOverlayView(store: store, theme: theme)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .clipShape(topCorners)
        .overlay(topCorners.strokeBorder(theme.hairline, lineWidth: 1))
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: store.isPreviewing)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: store.isCreatingTag)
        .task { await store.reload() }
        .preferredColorScheme(appearance == "light" ? .light : (appearance == "dark" ? .dark : nil))
    }

    // MARK: 顶栏

    private func header(_ theme: ClipTheme) -> some View {
        HStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("剪贴板").font(.system(size: 17, weight: .bold))
                Text("\(store.visibleItems.count) 项").font(.system(size: 13)).foregroundStyle(.tertiary)
            }
            .fixedSize()

            pills(theme)
            searchField(theme)
            gearButton(theme)
        }
        .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 12)
    }

    private func pills(_ theme: ClipTheme) -> some View {
        let filters = ClipFilter.builtins + store.allTags.map { ClipFilter.tag($0) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(filters, id: \.self) { filter in
                    pillButton(filter, theme)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private func pillButton(_ filter: ClipFilter, _ theme: ClipTheme) -> some View {
        let active = store.filter == filter
        return Button { store.setFilter(filter) } label: {
            HStack(spacing: 4) {
                if filter.isTag { Image(systemName: "tag.fill").font(.system(size: 9)) }
                Text(filter.label).font(.system(size: 13, weight: active ? .semibold : .regular))
            }
            .foregroundStyle(active ? Color.white : Color.secondary)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(active ? ClipTheme.accent : theme.pill))
        }
        .buttonStyle(.plain)
    }

    private func searchField(_ theme: ClipTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.tertiary)
            TextField("搜索剪贴板…", text: $store.searchText)
                .textFieldStyle(.plain).font(.system(size: 13)).focused($searchFocused)
                .onSubmit { searchFocused = false } // 回车确认搜索 -> 退回导航模式(此时再回车才粘贴)
            if !store.searchText.isEmpty {
                Button { store.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).frame(width: 220, height: 32)
        .background(Capsule().fill(theme.searchBg))
    }

    private func gearButton(_ theme: ClipTheme) -> some View {
        Button { onOpenSettings() } label: {
            Image(systemName: "gearshape").font(.system(size: 15)).foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(theme.pill))
        }
        .buttonStyle(.plain)
    }

    // MARK: 内容

    @ViewBuilder private func content(_ theme: ClipTheme) -> some View {
        if store.visibleItems.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: store.searchText.isEmpty && store.filter == .all ? "clipboard" : "magnifyingglass")
                    .font(.system(size: 34)).foregroundStyle(.tertiary)
                Text(emptyText).font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HistoryStripView(store: store, onChoose: onChoose, onCopy: onCopy)
        }
    }

    private var emptyText: String {
        if !store.searchText.isEmpty { return "没有匹配的剪贴板内容" }
        if case .tag = store.filter { return "该标签下暂无内容" }
        if store.filter != .all { return "该分类下暂无内容" }
        return "暂无剪贴板历史"
    }

    // MARK: 底栏

    private func footer(_ theme: ClipTheme) -> some View {
        HStack(spacing: 18) {
            hint("⏎", "粘贴", theme)
            hint("空格", "预览", theme)
            hint("← →", "切换", theme)
            hint("⌘⌫", "删除", theme)
            hint("⌘P", "固定", theme)
            hint("esc", "关闭", theme)
            Spacer()
            Text(positionLabel).font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22).padding(.vertical, 10)
    }

    private var positionLabel: String {
        let vis = store.visibleItems
        guard !vis.isEmpty else { return "0 / 0" }
        let pos = (vis.firstIndex { $0.id == store.selectedID } ?? 0) + 1
        return "\(pos) / \(vis.count)"
    }

    private func hint(_ key: String, _ label: String, _ theme: ClipTheme) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(theme.kbd))
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}
