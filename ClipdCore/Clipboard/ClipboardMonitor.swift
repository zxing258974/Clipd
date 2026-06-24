import AppKit

/// 剪贴板轮询监听。
///
/// macOS 无剪贴板变更通知 API,只能轮询 `NSPasteboard.changeCount`。
/// 关键细节:Timer 注册到 `.common` runloop mode(否则菜单/拖拽的 `.eventTracking`
/// 期间停跳、漏捕获);读取做 TOCTOU 收尾;隐私/自身写回在读取负载前预判。
@MainActor
public final class ClipboardMonitor {
    /// 捕获到新内容时回调(已排除自身写回与隐私命中)。
    public var onChange: ((RawPasteboardSnapshot) -> Void)?

    private let pasteboard: NSPasteboard
    private let privacyFilter: PrivacyFilter
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var lastChangeCount: Int

    public init(
        pasteboard: NSPasteboard = .general,
        privacyFilter: PrivacyFilter = PrivacyFilter(),
        pollInterval: TimeInterval = 0.5
    ) {
        self.pasteboard = pasteboard
        self.privacyFilter = privacyFilter
        self.pollInterval = pollInterval
        // 基线:忽略启动前剪贴板里已有的内容。
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        stop()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkForChanges()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 粘贴回写后由 `PasteService` 调用:跳过该 changeCount(防回环双保险)。
    public func ignoreChangeCount(_ count: Int) {
        lastChangeCount = max(lastChangeCount, count)
    }

    func checkForChanges() {
        let snapshotCount = pasteboard.changeCount
        guard snapshotCount != lastChangeCount else { return }

        // 仅读类型元数据(不取负载),用于 marker / 隐私预判。
        let allTypes = Set((pasteboard.pasteboardItems ?? []).flatMap { item in
            item.types.map(\.rawValue)
        })

        // 自身写回:含 appMarker -> 跳过。
        if allTypes.contains(PasteboardMarker.appMarker.rawValue) {
            lastChangeCount = snapshotCount
            return
        }

        // 隐私:命中标记 -> 不读取负载(密码字节不进内存)。
        let privacyMarkers = Set(allTypes.filter { $0.hasPrefix("org.nspasteboard.") })
        if privacyFilter.rejection(forMarkers: privacyMarkers) != nil {
            lastChangeCount = snapshotCount
            return
        }

        // 读取负载:文本 + 图片(MVP)。
        let text = pasteboard.string(forType: .string)
        var imageData: Data?
        var imageExt: String?
        if let png = pasteboard.data(forType: .png) {
            imageData = png
            imageExt = "png"
        } else if let tiff = pasteboard.data(forType: .tiff) {
            imageData = tiff
            imageExt = "tiff"
        }

        // TOCTOU 收尾:读取期间 changeCount 变化 -> 丢弃、不推进、下次重试。
        guard pasteboard.changeCount == snapshotCount else { return }
        lastChangeCount = snapshotCount

        let hasText = !(text?.isEmpty ?? true)
        guard hasText || imageData != nil else { return }

        let source = NSWorkspace.shared.frontmostApplication
        onChange?(RawPasteboardSnapshot(
            changeCount: snapshotCount,
            isSelfWrite: false,
            privacyMarkers: privacyMarkers,
            text: hasText ? text : nil,
            imageData: imageData,
            imageExt: imageExt,
            sourceBundleID: source?.bundleIdentifier,
            sourceAppName: source?.localizedName
        ))
    }
}
