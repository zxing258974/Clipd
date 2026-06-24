import AppKit

/// 应用委托:启动组合根。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 单元测试以本 app 为 host:测试运行时不启动 UI / 监听,避免干扰真实剪贴板。
        guard !isRunningTests else { return }

        // 双保险:即便 Info.plist 漏配 LSUIElement,也强制无 Dock 图标。
        NSApp.setActivationPolicy(.accessory)

        do {
            let coordinator = try AppCoordinator()
            coordinator.start()
            self.coordinator = coordinator
        } catch {
            presentFatalError(error)
        }
    }

    private func presentFatalError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Clipd 启动失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }

    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
