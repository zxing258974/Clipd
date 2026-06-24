import KeyboardShortcuts

public extension KeyboardShortcuts.Name {
    /// 唤起/收起历史面板,默认 ⌘⇧C(可在设置页自定义)。
    nonisolated(unsafe) static let togglePanel = Self("togglePanel", default: .init(.c, modifiers: [.command, .shift]))
}
