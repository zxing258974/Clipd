import SwiftUI

/// 历史列表。选中项随键盘导航滚动到可见区域;点击即选用。
struct HistoryListView: View {
    let store: ClipboardStore
    var onChoose: (ClipItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(store.items) { item in
                        ClipRowView(
                            item: item,
                            isSelected: item.id == store.selectedID,
                            thumbnailURL: store.thumbnailURL(for: item)
                        )
                        .id(item.id)
                        .onTapGesture { onChoose(item) }
                    }
                }
                .padding(8)
            }
            .onChange(of: store.selectedID) { _, newValue in
                guard let id = newValue else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}
