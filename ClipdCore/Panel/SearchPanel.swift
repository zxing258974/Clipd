import AppKit

/// 历史搜索浮动面板。
///
/// 关键配置:`.nonactivatingPanel` + `canBecomeKey=true` —— 面板可取得键盘焦点
/// 供搜索输入,但**不激活本 App、不夺走前台 App 的活跃态**,从而让粘贴回写无需
/// 处理"还原焦点"的异步竞态。`.canJoinAllSpaces`/`.fullScreenAuxiliary` 让它能覆盖全屏 App。
public final class SearchPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 440),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    /// Esc 关闭。
    public override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
