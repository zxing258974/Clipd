import SwiftUI

/// 顶部搜索框。焦点由父视图通过 `FocusState` 绑定驱动。
struct SearchField: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14, weight: .medium))
            TextField("搜索剪贴板历史…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused(focus)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
