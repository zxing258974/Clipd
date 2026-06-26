import AppKit
import ApplicationServices

public extension Notification.Name {
    /// 缺少辅助功能权限、粘贴降级为"只复制"时发出。
    static let clipdPasteNeedsAccessibility = Notification.Name("clipd.pasteNeedsAccessibility")
    /// 用户在设置页切换"菜单栏显示图标"时发出(仅此一处,避免监听全局 UserDefaults 变化引发回环)。
    static let clipdMenuBarIconVisibilityChanged = Notification.Name("clipd.menuBarIconVisibilityChanged")
}

/// 辅助功能(Accessibility)权限的检测与引导。
///
/// `AXIsProcessTrusted()` 静默检查(无弹窗),每次粘贴前/启动时调用;
/// `requestAccessibilityPrompt()` 仅在用户显式操作时调用(否则刷屏弹窗)。
@MainActor
@Observable
public final class PermissionsService {
    public private(set) var accessibilityGranted: Bool

    public init() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    /// 静默刷新当前状态。
    public func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    /// 触发系统授权弹窗。仅可由用户显式手势调用。
    @discardableResult
    public func requestAccessibilityPrompt() -> Bool {
        // kAXTrustedCheckOptionPrompt 的字面量值;直接引用该 C 全局 var 在 Swift 6 下非并发安全。
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = trusted
        return trusted
    }

    /// 打开"系统设置 → 隐私与安全性 → 辅助功能"。
    public func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
