import Foundation
import KeyboardShortcuts

/// 全局热键管理。封装 `KeyboardShortcuts`,把"唤起面板"快捷键回调出去。
///
/// 用 `onKeyUp`(而非 onKeyDown),避免热键自身的 keyDown 漏进刚获焦的搜索框。
/// 与系统/他 App 冲突时 `RegisterEventHotKey` 静默失败 —— 设置页(阶段3)提供
/// `KeyboardShortcuts.Recorder` 让用户改键。
@MainActor
public final class HotkeyManager {
    public var onTogglePanel: (() -> Void)?

    public init() {}

    public func registerDefaults() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            MainActor.assumeIsolated {
                self?.onTogglePanel?()
            }
        }
    }
}
