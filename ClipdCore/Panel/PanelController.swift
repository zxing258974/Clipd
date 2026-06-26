import AppKit
import SwiftUI
import KeyboardShortcuts

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
    private var defaultsObserver: Any?
    private var isApplyingIconVisibility = false
    private let panelHeight: CGFloat = 400
    private var lastShownAt: Date?
    private var settingsWindow: NSWindow?

    /// 选中条目执行(由 AppCoordinator 注入:粘贴回前台 App)。
    public var onChoose: ((ClipItem) -> Void)?
    /// 面板显示前记录的前台 App(粘贴目标)。
    public private(set) var previousApp: NSRunningApplication?

    public init(store: ClipboardStore) {
        self.store = store
        self.panel = SearchPanel()
        super.init()
        let root = PanelRootView(
            store: store,
            onChoose: { [weak self] item in self?.choose(item) },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        panel.contentView = NSHostingView(rootView: root)
        panel.delegate = self
    }

    // MARK: 状态栏

    public func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.makeMenuBarIcon()
            let hint = KeyboardShortcuts.Name.togglePanel.shortcut.map { " (\($0))" } ?? ""
            button.toolTip = "Clipd 剪贴板历史\(hint)"
            button.target = self
            button.action = #selector(statusButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        updateStatusItemVisibility()
        // 仅监听设置页发出的专属通知。不要监听全局 `UserDefaults.didChangeNotification`:
        // 设置 `NSStatusItem.isVisible` 会让 AppKit 把状态写回 UserDefaults 并同步触发该通知,
        // 从而递归回到本方法直至爆栈(已由崩溃日志确认)。
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: .clipdMenuBarIconVisibilityChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateStatusItemVisibility() }
        }
    }

    /// 按设置显隐菜单栏图标。隐藏时保留 `NSStatusItem`(仅 `isVisible=false`),便于随时再显示。
    /// `isApplyingIconVisibility` 防重入:即便将来再有同步回调也不会递归。
    private func updateStatusItemVisibility() {
        guard !isApplyingIconVisibility else { return }
        isApplyingIconVisibility = true
        defer { isApplyingIconVisibility = false }
        let show = UserDefaults.standard.object(forKey: UserDefaultsSettings.Keys.showMenuBarIcon) as? Bool ?? true
        if statusItem?.isVisible != show { statusItem?.isVisible = show }
    }

    /// 菜单栏图标:与 App 图标同款剪贴板造型的单色模板图(随菜单栏明暗自动着色、保持清晰)。
    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let w = rect.width, h = rect.height
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // 剪贴板板(描边)
            let boardW = w * 0.60, boardH = h * 0.80
            let board = NSRect(x: (w - boardW) / 2, y: (h - boardH) / 2 - h * 0.02, width: boardW, height: boardH)
            let boardPath = NSBezierPath(roundedRect: board, xRadius: boardW * 0.2, yRadius: boardW * 0.2)
            boardPath.lineWidth = max(1.2, w * 0.08)
            boardPath.stroke()

            // 顶部夹子(填充)
            let clipW = boardW * 0.44, clipH = boardH * 0.17
            let clip = NSRect(x: board.midX - clipW / 2, y: board.maxY - clipH * 0.55, width: clipW, height: clipH)
            NSBezierPath(roundedRect: clip, xRadius: clipH * 0.45, yRadius: clipH * 0.45).fill()

            // 两行内容
            let lineH = max(1.0, h * 0.06)
            let lineX = board.minX + boardW * 0.23
            for (index, frac) in [0.50, 0.34].enumerated() {
                let lineW = boardW * (index == 1 ? 0.34 : 0.52)
                let lineRect = NSRect(x: lineX, y: board.minY + boardH * frac, width: lineW, height: lineH)
                NSBezierPath(roundedRect: lineRect, xRadius: lineH / 2, yRadius: lineH / 2).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
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
        hide()
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Clipd 设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: 显隐

    public func toggle() {
        panel.isVisible ? hide() : show()
    }

    public func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        lastShownAt = Date()
        store.prepareForPresentation()
        guard let visible = activeScreenVisibleFrame() else {
            panel.makeKeyAndOrderFront(nil)
            installKeyMonitor()
            Task { await store.reload() }
            return
        }
        // 贴屏幕底部、铺满整屏宽度(Paste 风格)。
        let finalFrame = NSRect(x: visible.minX, y: visible.minY, width: visible.width, height: panelHeight)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(finalFrame, display: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            // 从底部滑入。
            panel.setFrame(finalFrame.offsetBy(dx: 0, dy: -panelHeight), display: false)
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                panel.animator().setFrame(finalFrame, display: true)
            }
        }
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

    /// 光标所在屏幕的可见区域(避开菜单栏/Dock)。
    private func activeScreenVisibleFrame() -> NSRect? {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        return screen?.visibleFrame
    }

    // MARK: 键盘

    private func installKeyMonitor() {
        removeKeyMonitor()
        // 只把 keyCode(Sendable)送进主 actor,NSEvent 本身不跨界。
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let code = event.keyCode
            let command = event.modifierFlags.contains(.command)
            let handled = MainActor.assumeIsolated {
                self?.handleKeyDown(keyCode: code, command: command) ?? false
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
    /// 方向/回车/Esc 始终拦截做卡片导航;⌘⌫ 删除、⌘P 固定(纯 ⌫/P 留给搜索框输入)。
    private func handleKeyDown(keyCode: UInt16, command: Bool) -> Bool {
        switch (keyCode, command) {
        case (123, true): // ⌘← :跳到第一个
            store.selectFirst()
            return true
        case (124, true): // ⌘→ :跳到最后一个
            store.selectLast()
            return true
        case (124, _), (125, _): // → / ↓ :下一张(更旧)
            store.moveSelectionDown()
            return true
        case (123, _), (126, _): // ← / ↑ :上一张(更新)
            store.moveSelectionUp()
            return true
        case (49, false): // 空格 :预览开/关(搜索框有内容时留给输入空格)
            if store.isPreviewing { store.closePreview(); return true }
            guard store.searchText.isEmpty else { return false }
            store.togglePreview()
            return true
        case (36, _), (76, _): // ↩︎ / enter :粘贴
            if let item = store.selectedItem { choose(item) }
            return true
        case (51, true): // ⌘⌫ :删除选中
            Task { await store.deleteSelected() }
            return true
        case (35, true): // ⌘P :固定/取消固定
            Task { await store.togglePinSelected() }
            return true
        case (53, _): // ⎋ :先关预览,否则关面板
            if store.isPreviewing { store.closePreview() } else { hide() }
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
        // 滑入瞬间可能发生的 resignKey(动画 / 输入法候选窗等)不应误关闭面板。
        if let shownAt = lastShownAt, Date().timeIntervalSince(shownAt) < 0.35 { return }
        hide()
    }
}
