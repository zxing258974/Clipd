import AppKit

/// 底部浮动卡片栏(Paste 风格)。
///
/// 无边框、铺满屏幕宽度、贴底部边缘。`.nonactivatingPanel` + `canBecomeKey=true`:
/// 可取得键盘焦点供搜索,但不激活本 App、不夺走前台 App 的活跃态,从而粘贴回写
/// 无需处理"还原焦点"的异步竞态。背景透明,圆角与材质由 SwiftUI 根视图绘制。
public final class SearchPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
    }

    /// Esc 关闭。
    public override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
