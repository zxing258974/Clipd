import ServiceManagement

/// 开机自启(macOS 13+ ServiceManagement)。非沙盒应用直接注册主程序为登录项。
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Clipd: 切换开机自启失败 - \(error.localizedDescription)")
        }
    }
}
