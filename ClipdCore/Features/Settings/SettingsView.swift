import SwiftUI
import KeyboardShortcuts

/// 设置窗口:快捷键自定义 + 历史保留策略。
struct SettingsView: View {
    // 键与 `UserDefaultsSettings.Keys` 保持一致。
    @AppStorage("clipd.retentionDays") private var retentionDays: Int = 7
    @AppStorage("clipd.maxItems") private var maxItems: Int = 999

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
            shortcutsTab
                .tabItem { Label("快捷键", systemImage: "command") }
        }
        .frame(width: 460, height: 260)
    }

    private var shortcutsTab: some View {
        Form {
            KeyboardShortcuts.Recorder("唤起历史面板:", name: .togglePanel)
            Text("点击右侧录制新快捷键(默认 ⌘⇧C)。若与其他 App 冲突,改成别的组合即可。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var generalTab: some View {
        Form {
            Stepper(value: $retentionDays, in: 0...365) {
                Text(retentionDays <= 0 ? "保留时长:永久" : "保留时长:\(retentionDays) 天")
            }
            Stepper(value: $maxItems, in: 50...5000, step: 50) {
                Text("最多保留:\(maxItems) 条")
            }
            Text("超过保留时长或条数的未固定记录会被自动清除;已固定项永久保留。时长按最后使用时间计算,期限内再次复制会自动续期。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }
}
