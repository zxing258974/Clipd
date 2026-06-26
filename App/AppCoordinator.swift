import AppKit

/// 组合根:构造并串联所有子系统,定义启动顺序。
@MainActor
final class AppCoordinator {
    private let settings: SettingsProviding
    private let repository: SwiftDataClipItemRepository
    private let blobStore: FileBlobStore
    private let privacyFilter: PrivacyFilter
    private let thumbnailer: ThumbnailService
    private let trimming: TrimmingService
    private let capture: CaptureService
    private let monitor: ClipboardMonitor
    private let permissions: PermissionsService
    private let pasteService: PasteService
    private let store: ClipboardStore
    private let panel: PanelController
    private let hotkeys: HotkeyManager
    private var evictionTimer: Timer?
    private var accessibilityObserver: NSObjectProtocol?
    private var isAccessibilityAlertShowing = false

    init() throws {
        let settings = UserDefaultsSettings()
        self.settings = settings

        let container = try ModelContainerFactory.make()
        let repository = SwiftDataClipItemRepository(modelContainer: container)
        let blobStore = FileBlobStore(rootURL: try AppPaths.blobsRootURL())
        let privacyFilter = PrivacyFilter(storeConcealedMasked: settings.storeConcealedMasked)
        let thumbnailer = ThumbnailService()
        let trimming = TrimmingService(repository: repository, blobStore: blobStore)
        let permissions = PermissionsService()

        let capture = CaptureService(
            repository: repository,
            blobStore: blobStore,
            thumbnailer: thumbnailer,
            privacyFilter: privacyFilter,
            trimming: trimming,
            settings: settings
        )
        let monitor = ClipboardMonitor(privacyFilter: privacyFilter, pollInterval: settings.pollInterval)
        let pasteService = PasteService(
            repository: repository,
            blobStore: blobStore,
            capture: capture,
            monitor: monitor,
            permissions: permissions
        )
        let store = ClipboardStore(repository: repository, blobStore: blobStore)
        let panel = PanelController(store: store)

        self.repository = repository
        self.blobStore = blobStore
        self.privacyFilter = privacyFilter
        self.thumbnailer = thumbnailer
        self.trimming = trimming
        self.permissions = permissions
        self.capture = capture
        self.monitor = monitor
        self.pasteService = pasteService
        self.store = store
        self.panel = panel
        self.hotkeys = HotkeyManager()
    }

    func start() {
        // 捕获:剪贴板变化 → 入库 → 刷新面板数据。
        monitor.onChange = { [weak self] snapshot in
            guard let self else { return }
            Task {
                _ = await self.capture.handle(snapshot)
                await self.store.reload()
            }
        }

        // 热键唤起面板。
        hotkeys.onTogglePanel = { [weak self] in
            self?.panel.toggle()
        }

        // 选中条目 → 还原焦点并粘贴回前台 App。
        panel.onChoose = { [weak self] item in
            guard let self else { return }
            let pid = self.panel.previousApp?.processIdentifier
            Task { [weak self] in await self?.pasteService.paste(item, reactivatingPID: pid) }
        }

        // 右键"复制" → 仅写回剪贴板(不模拟粘贴)。
        panel.onCopy = { [weak self] item in
            Task { [weak self] in await self?.pasteService.copy(item) }
        }

        // 缺辅助功能权限(只复制未自动粘贴)时弹窗引导授权。
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: .clipdPasteNeedsAccessibility, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.presentAccessibilityAlert() }
        }

        panel.installStatusItem()
        hotkeys.registerDefaults()
        monitor.start()

        // 首次启动若未授予辅助功能权限,主动弹系统授权框(注册当前运行的二进制,
        // 确保系统列表里的条目就是正在运行的这个 Clipd)。
        permissions.refresh()
        if !permissions.accessibilityGranted {
            permissions.requestAccessibilityPrompt()
        }

        // 启动维护:清理过期记录 + 超额条数 + 未引用的孤儿 blob。
        Task { [weak self] in
            guard let self else { return }
            await self.trimming.evictExpired(retentionDays: self.settings.retentionDays)
            await self.trimming.trim(maxItems: self.settings.maxItems)
            await self.trimming.sweepOrphanBlobs()
        }

        // 每小时清理一次:过期记录 + 超额条数(读取实时设置,使设置页下调即便无新复制也能生效)。
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task {
                    await self.trimming.evictExpired(retentionDays: self.settings.retentionDays)
                    await self.trimming.trim(maxItems: self.settings.maxItems)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.evictionTimer = timer
    }

    /// 提示用户开启辅助功能权限(自动粘贴所需)。一次只弹一个。
    private func presentAccessibilityAlert() {
        guard !isAccessibilityAlertShowing else { return }
        isAccessibilityAlertShowing = true
        defer { isAccessibilityAlertShowing = false }

        let alert = NSAlert()
        alert.messageText = "需要「辅助功能」权限才能自动粘贴"
        alert.informativeText = """
        内容已复制到剪贴板,可手动按 ⌘V 粘贴。
        要让 Clipd 双击即自动粘贴,请在「系统设置 → 隐私与安全性 → 辅助功能」开启 Clipd,然后完全退出并重新打开 Clipd。

        若已开启仍提示无权限:在该列表用「–」移除旧的 Clipd,再点下面「去开启…」让系统重新添加当前这个 Clipd,勾选后重启。
        """
        alert.addButton(withTitle: "去开启…")
        alert.addButton(withTitle: "稍后")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            permissions.requestAccessibilityPrompt()
            permissions.openAccessibilitySettings()
        }
    }
}
