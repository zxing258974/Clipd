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

        // 选中条目 → 粘贴回前台 App。
        panel.onChoose = { [weak self] item in
            Task { await self?.pasteService.paste(item) }
        }

        panel.installStatusItem()
        hotkeys.registerDefaults()
        monitor.start()

        // 启动维护:清理过期记录 + 未引用的孤儿 blob。
        Task { [weak self] in
            guard let self else { return }
            await self.trimming.evictExpired(retentionDays: self.settings.retentionDays)
            await self.trimming.sweepOrphanBlobs()
        }

        // 每小时清理一次过期记录(读取实时设置)。
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.trimming.evictExpired(retentionDays: self.settings.retentionDays) }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.evictionTimer = timer
    }
}
