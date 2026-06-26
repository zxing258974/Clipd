import SwiftUI

/// 横向卡片墙。选中卡片随键盘导航滚动居中;单击选中、双击粘贴。
struct HistoryStripView: View {
    let store: ClipboardStore
    var onChoose: (ClipItem) -> Void
    var onCopy: (ClipItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(store.visibleItems) { item in
                        ClipCardView(
                            item: item,
                            isSelected: item.id == store.selectedID,
                            thumbnailURL: store.thumbnailURL(for: item)
                        )
                        .id(item.id)
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture(count: 2).onEnded { onChoose(item) })
                        .simultaneousGesture(TapGesture(count: 1).onEnded { store.selectedID = item.id })
                        .contextMenu {
                            Button { onCopy(item) } label: { Label("复制", systemImage: "doc.on.doc") }
                            Button(role: .destructive) {
                                Task { await store.delete(item) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .frame(maxHeight: .infinity)
            }
            .onChange(of: store.selectedID) { _, newValue in
                guard let id = newValue else { return }
                if reduceMotion {
                    proxy.scrollTo(id, anchor: .center)
                } else {
                    withAnimation(.easeOut(duration: 0.14)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
