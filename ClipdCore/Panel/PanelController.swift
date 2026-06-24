import AppKit
import SwiftUI

/// 菜单栏状态项 + 搜索面板的协调者。
///
/// 替代纯 `MenuBarExtra`:对面板的键盘焦点、显示位置、生命周期有完全控制。
/// 键盘导航用本地事件监听(搜索框获焦时仍能拦截 ↑↓↩︎⎋);失焦自动隐藏。
@MainActor
public final class PanelController: NSObject {
    private let store: ClipboardStore
    private let panel: SearchPanel
    private var statusItem: NSStatusItem?
    private var localKeyMonitor: Any?

    /// 选中条目执行(由 AppCoordinator 注入:粘贴回前台 App)。
    public var onChoose: ((ClipItem) -> Void)?
    /// 面板显示前记录的前台 App(粘贴目标)。
    public private(set) var previousApp: NSRunningApplication?

    public init(store: ClipboardStore) {
        self.store = store
        self.panel = SearchPanel()
        super.init()
        let root = PanelRootView(store: store) { [weak self] item in
            self?.choose(item)
        }
        panel.contentView = NSHostingView(rootView: root)
        panel.delegate = self
    }

    // MARK: 状态栏

    public func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipd")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Clipd 剪贴板历史(⌘⇧V)"
            button.target = self
            button.action = #selector(statusButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusButtonClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            presentContextMenu()
        } else {
            toggle()
        }
    }

    private func presentContextMenu() {
        let menu = NSMenu()
        let show = NSMenuItem(title: "显示剪贴板历史", action: #selector(menuShow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 Clipd",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // 复位,使左键下次仍为 toggle
    }

    @objc private func menuShow() { toggle() }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: 显隐

    public func toggle() {
        panel.isVisible ? hide() : show()
    }

    public func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        Task { await store.reload() }
    }

    public func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    private func choose(_ item: ClipItem) {
        hide()
        onChoose?(item)
    }

    // MARK: 定位

    private func positionPanel() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.08
        )
        panel.setFrameOrigin(origin)
    }

    // MARK: 键盘

    private func installKeyMonitor() {
        removeKeyMonitor()
        // 只把 keyCode(Sendable)送进主 actor,NSEvent 本身不跨界。
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                self?.handleKeyDown(keyCode: event.keyCode) ?? false
            }
            return handled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    /// 返回 true 表示已处理(吞掉该事件,不传给搜索框)。
    private func handleKeyDown(keyCode: UInt16) -> Bool {
        switch keyCode {
        case 125: // ↓
            store.moveSelectionDown()
            return true
        case 126: // ↑
            store.moveSelectionUp()
            return true
        case 36, 76: // ↩︎ / enter
            if let item = store.selectedItem { choose(item) }
            return true
        case 53: // ⎋
            hide()
            return true
        default:
            return false
        }
    }
}

// MARK: - NSWindowDelegate

extension PanelController: NSWindowDelegate {
    /// 失焦(切到别的 App / 点击别处)自动隐藏。
    public func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
