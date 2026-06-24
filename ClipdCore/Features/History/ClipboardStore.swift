import Foundation

/// 面板的 UI 数据源(`@Observable`,主线程隔离)。
///
/// 负责加载历史、去抖搜索、键盘选择导航、固定/删除。删除时清理对应 blob 文件。
@MainActor
@Observable
public final class ClipboardStore {
    public private(set) var items: [ClipItem] = []
    /// 当前键盘选中项。
    public var selectedID: UUID?
    /// 搜索词(变化触发去抖查询)。
    public var searchText: String = "" {
        didSet { if oldValue != searchText { scheduleSearch() } }
    }

    @ObservationIgnored private let repository: ClipItemRepository
    @ObservationIgnored private let blobStore: BlobStoring
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    public init(repository: ClipItemRepository, blobStore: BlobStoring) {
        self.repository = repository
        self.blobStore = blobStore
    }

    public var selectedItem: ClipItem? {
        guard let id = selectedID else { return items.first }
        return items.first { $0.id == id } ?? items.first
    }

    public func reload() async {
        await runQuery()
    }

    public func moveSelectionDown() { move(by: 1) }
    public func moveSelectionUp() { move(by: -1) }

    public func togglePin(_ item: ClipItem) async {
        try? await repository.setPinned(id: item.id, !item.isPinned)
        await reload()
    }

    public func delete(_ item: ClipItem) async {
        let removed = (try? await repository.delete(ids: [item.id])) ?? []
        for path in removed {
            try? blobStore.delete(relativePath: path)
        }
        await reload()
    }

    /// 图片缩略图的绝对 URL(供行渲染)。
    public func thumbnailURL(for item: ClipItem) -> URL? {
        guard let path = item.thumbnailPath else { return nil }
        return blobStore.url(forRelativePath: path)
    }

    // MARK: 私有

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await self?.runQuery()
        }
    }

    private func runQuery() async {
        let query = HistoryQuery(searchText: searchText.isEmpty ? nil : searchText, limit: 200)
        let result = (try? await repository.fetch(query)) ?? []
        items = result
        if selectedID == nil || !result.contains(where: { $0.id == selectedID }) {
            selectedID = result.first?.id
        }
    }

    private func move(by delta: Int) {
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedID } ?? 0
        let next = min(max(current + delta, 0), items.count - 1)
        selectedID = items[next].id
    }
}
