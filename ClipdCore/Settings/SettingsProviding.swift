import Foundation

/// 运行期偏好读取接口。
public protocol SettingsProviding: Sendable {
    /// 历史条数上限(仅约束未固定项)。
    var maxItems: Int { get }
    /// 历史保留天数;`<= 0` 表示不按时间淘汰(永久保留)。按 `lastUsedAt` 计。
    var retentionDays: Int { get }
    /// 剪贴板轮询间隔(秒)。
    var pollInterval: TimeInterval { get }
    /// 命中 ConcealedType 时是否仍存储(遮蔽显示)。默认 false=完全不存。
    var storeConcealedMasked: Bool { get }
    /// 是否在菜单栏显示图标。默认 true;关闭后仍可用快捷键唤起。
    var showMenuBarIcon: Bool { get }
}

/// 常量实现(测试/默认用)。
public struct DefaultSettings: SettingsProviding {
    public var maxItems: Int
    public var retentionDays: Int
    public var pollInterval: TimeInterval
    public var storeConcealedMasked: Bool
    public var showMenuBarIcon: Bool

    public init(
        maxItems: Int = 1000,
        retentionDays: Int = 7,
        pollInterval: TimeInterval = 0.5,
        storeConcealedMasked: Bool = false,
        showMenuBarIcon: Bool = true
    ) {
        self.maxItems = maxItems
        self.retentionDays = retentionDays
        self.pollInterval = pollInterval
        self.storeConcealedMasked = storeConcealedMasked
        self.showMenuBarIcon = showMenuBarIcon
    }
}

/// UserDefaults 后端:内联读取 `.standard`,实时反映设置页改动(无非 Sendable 存储)。
public struct UserDefaultsSettings: SettingsProviding {
    /// 与设置页 `@AppStorage` 的键保持一致。
    public enum Keys {
        public static let maxItems = "clipd.maxItems"
        public static let retentionDays = "clipd.retentionDays"
        public static let pollInterval = "clipd.pollInterval"
        public static let storeConcealedMasked = "clipd.storeConcealedMasked"
        public static let showMenuBarIcon = "clipd.showMenuBarIcon"
    }

    public init() {}

    public var maxItems: Int {
        UserDefaults.standard.object(forKey: Keys.maxItems) as? Int ?? 1000
    }
    public var retentionDays: Int {
        UserDefaults.standard.object(forKey: Keys.retentionDays) as? Int ?? 7
    }
    public var pollInterval: TimeInterval {
        UserDefaults.standard.object(forKey: Keys.pollInterval) as? TimeInterval ?? 0.5
    }
    public var storeConcealedMasked: Bool {
        UserDefaults.standard.object(forKey: Keys.storeConcealedMasked) as? Bool ?? false
    }
    public var showMenuBarIcon: Bool {
        UserDefaults.standard.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
    }
}
