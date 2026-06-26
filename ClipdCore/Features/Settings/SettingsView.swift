import SwiftUI
import AppKit
import KeyboardShortcuts

/// 设置窗口:System Settings 风格的分组表单。三个标签:通用 / 外观 / 快捷键。
/// 键与 `UserDefaultsSettings.Keys` / `ClipTheme` / `PanelRootView` 保持一致。
struct SettingsView: View {
    @AppStorage("clipd.retentionDays") private var retentionDays = 7
    @AppStorage("clipd.maxItems") private var maxItems = 1000
    @AppStorage("clipd.accentHex") private var accentHex = "#0A84FF"
    @AppStorage("clipd.appearance") private var appearance = "system"
    @AppStorage("clipd.showMenuBarIcon") private var showMenuBarIcon = true
    @State private var launchAtLogin = LoginItem.isEnabled

    private let accents: [(name: String, hex: String)] = [
        ("蓝", "#0A84FF"), ("靛", "#5E5CE6"), ("紫", "#BF5AF2"),
        ("红", "#FF375F"), ("橙", "#FF9F0A"), ("绿", "#30D158"),
    ]

    var body: some View {
        TabView {
            general.tabItem { Label("通用", systemImage: "gearshape") }
            appearanceTab.tabItem { Label("外观", systemImage: "paintbrush") }
            shortcuts.tabItem { Label("快捷键", systemImage: "command") }
        }
        .frame(width: 480, height: 360)
    }

    // MARK: 通用

    private var general: some View {
        Form {
            Section("历史") {
                Stepper(value: $retentionDays, in: 0...365) {
                    settingRow("保留时长", retentionDays <= 0 ? "永久" : "\(retentionDays) 天")
                }
                Stepper(value: $maxItems, in: 50...5000, step: 50) {
                    settingRow("最多保留", "\(maxItems) 条")
                }
            }
            Section("启动") {
                Toggle("开机时自动启动 Clipd", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in LoginItem.set(on) }
            }
            Section("菜单栏") {
                Toggle("在菜单栏显示 Clipd 图标", isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { _, _ in
                        NotificationCenter.default.post(name: .clipdMenuBarIconVisibilityChanged, object: nil)
                    }
                if !showMenuBarIcon {
                    Text("图标已隐藏。仍可用快捷键(默认 ⌘⇧C)唤起面板;在面板里点齿轮可重新打开本设置。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Text("超过保留时长或条数的未固定记录会自动清除;已固定项永久保留。时长按最后使用时间计算,期限内再次复制会续期。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("退出 Clipd") { NSApplication.shared.terminate(nil) }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: 外观

    private var appearanceTab: some View {
        Form {
            Section("界面外观") {
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Section("强调色") {
                HStack(spacing: 16) {
                    ForEach(accents, id: \.hex) { accent in
                        accentSwatch(name: accent.name, hex: accent.hex)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }
        }
        .formStyle(.grouped)
    }

    private func accentSwatch(name: String, hex: String) -> some View {
        let selected = accentHex == hex
        return Button {
            accentHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? .blue)
                .frame(width: 26, height: 26)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .overlay {
                    Circle().strokeBorder(Color.primary.opacity(selected ? 0.5 : 0), lineWidth: 2).padding(-3)
                }
        }
        .buttonStyle(.plain)
        .help(name)
    }

    // MARK: 快捷键

    private var shortcuts: some View {
        Form {
            Section("唤起面板") {
                KeyboardShortcuts.Recorder("快捷键", name: .togglePanel)
            }
            Section("面板内按键") {
                keyRow("← →", "切换卡片")
                keyRow("⌘← / ⌘→", "跳到首张 / 末张")
                keyRow("⏎ / 双击", "粘贴选中")
                keyRow("⌘⌫", "删除选中")
                keyRow("⌘P", "固定 / 取消固定")
                keyRow("esc", "关闭面板")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: 复用行

    private func settingRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func keyRow(_ key: String, _ desc: String) -> some View {
        HStack {
            Text(desc)
            Spacer()
            Text(key)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
        }
    }
}
