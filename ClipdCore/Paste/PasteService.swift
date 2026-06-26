import AppKit
import CoreGraphics

/// 把选中的历史条目写回剪贴板并模拟 ⌘V 粘贴到前台 App。
///
/// 流程:懒加载负载 → 写回(带 marker)→ 登记防回环 → 校验权限 →
/// 模拟 ⌘V。缺权限时降级为"只复制"(内容已在剪贴板,用户手动 ⌘V)。
///
/// 面板为**非激活**窗口:隐藏后前台 App 自动恢复焦点,无需处理激活竞态。
@MainActor
public final class PasteService {
    private let repository: ClipItemRepository
    private let blobStore: BlobStoring
    private let capture: CaptureService
    private let monitor: ClipboardMonitor
    private let permissions: PermissionsService

    public init(
        repository: ClipItemRepository,
        blobStore: BlobStoring,
        capture: CaptureService,
        monitor: ClipboardMonitor,
        permissions: PermissionsService
    ) {
        self.repository = repository
        self.blobStore = blobStore
        self.capture = capture
        self.monitor = monitor
        self.permissions = permissions
    }

    public func paste(_ item: ClipItem, reactivatingPID pid: pid_t? = nil) async {
        // 写回剪贴板(含防回环与置顶);失败则中止。
        guard await writeToPasteboard(item) else { return }

        // 校验权限;缺失则降级为"只复制"并发通知引导授权。
        permissions.refresh()
        guard permissions.accessibilityGranted else {
            NotificationCenter.default.post(name: .clipdPasteNeedsAccessibility, object: nil)
            return
        }

        // 还原前台 App 焦点,待其窗口重新成为 key 后再模拟 ⌘V
        // (面板隐藏后焦点恢复是异步的,过早 post 会落空或粘到别处)。
        if let pid, let app = NSRunningApplication(processIdentifier: pid), app != .current {
            app.activate()
        }
        try? await Task.sleep(for: .milliseconds(120))
        simulatePaste()
    }

    /// 仅把条目写回系统剪贴板(不模拟 ⌘V、不需要辅助功能权限)。供右键"复制"使用。
    public func copy(_ item: ClipItem) async {
        _ = await writeToPasteboard(item)
    }

    /// 懒加载负载 → 写回剪贴板(带 marker)→ 防回环登记 → 置顶。成功返回 true。
    /// 直接更新 `lastUsedAt`,不经监听管线,故无回环之虞。
    private func writeToPasteboard(_ item: ClipItem) async -> Bool {
        guard let ref = try? await repository.payloadRef(for: item.id) else { return false }
        let data: Data
        var imageExt: String?
        switch ref {
        case .inline(let inlineData):
            data = inlineData
        case .file(let path):
            guard let fileData = try? blobStore.read(relativePath: path) else { return false }
            data = fileData
            imageExt = (path as NSString).pathExtension
        }

        let newChangeCount = PasteboardWriter.write(kind: item.kind, data: data, imageExt: imageExt)
        capture.noteSelfWrite(hash: CaptureService.contentHash(data))
        monitor.ignoreChangeCount(newChangeCount)
        try? await repository.touch(id: item.id, lastUsedAt: Date())
        return true
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = KeyCodeMapper.pasteKeyCode()

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
