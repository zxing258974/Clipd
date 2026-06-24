import SwiftUI

/// 应用入口。
///
/// 不使用 `WindowGroup`(那会创建主窗口);仅提供 `Settings` 场景。
/// 菜单栏图标与生命周期由 `AppDelegate` 接管。LSUIElement=YES 保证无 Dock 图标。
@main
struct ClipdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
