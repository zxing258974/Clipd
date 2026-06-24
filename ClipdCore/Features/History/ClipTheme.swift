import SwiftUI

/// 面板配色 token,按系统外观(浅/深)自适应。文本色用语义色(.primary/.secondary/.tertiary)。
struct ClipTheme {
    let scheme: ColorScheme
    var isDark: Bool { scheme == .dark }

    /// 强调色,可在设置页自定义(存于 UserDefaults;默认蓝 #0A84FF)。
    static var accent: Color {
        Color(hex: UserDefaults.standard.string(forKey: "clipd.accentHex") ?? "")
            ?? Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    }

    /// 叠加在毛玻璃之上的栏体着色(深色暗、浅色亮)。
    var barTint: Color { isDark ? Color(red: 30 / 255, green: 30 / 255, blue: 36 / 255).opacity(0.5)
                                 : Color.white.opacity(0.45) }
    var cardFill: Color { isDark ? Color(red: 72 / 255, green: 72 / 255, blue: 82 / 255).opacity(0.5)
                                  : Color.white.opacity(0.9) }
    var cardBorder: Color { isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.07) }
    var pill: Color { isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.05) }
    var searchBg: Color { isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06) }
    var inset: Color { isDark ? Color.black.opacity(0.28) : Color.black.opacity(0.05) }
    var kbd: Color { isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.1) }
    var codeText: Color { isDark ? Color(red: 126 / 255, green: 231 / 255, blue: 135 / 255)
                                  : Color(red: 11 / 255, green: 110 / 255, blue: 158 / 255) }
    var hairline: Color { isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
}
