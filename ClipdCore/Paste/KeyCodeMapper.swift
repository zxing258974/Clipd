import CoreGraphics
import Sauce

/// 键盘布局感知的键码映射。
///
/// `CGEvent` 需要物理键码,而 "v" 在 Dvorak/AZERTY 等布局下物理位置不同;
/// 硬编码 0x09 会粘错键。Sauce 查询当前输入源得到正确的 "v" 键码。
@MainActor
public enum KeyCodeMapper {
    public static func pasteKeyCode() -> CGKeyCode {
        Sauce.shared.keyCode(for: .v)
    }
}
