import Foundation

/// 面板的 UI 数据源(`@Observable`,主线程隔离)。
///
/// 负责加载历史、去抖搜索、筛选、键盘选择导航、固定/删除。删除时清理对应 blob 文件。
@MainActor
@Observable
public final class ClipboardStore {
    public private(set) var items: [ClipItem] = []
    /// 当前键盘选中项。
    public var selectedID: UUID?
    /// 当前筛选(全部/已固定/文本/链接/图片/颜色/文件)。
    public private(set) var filter: ClipFilter = .all
    /// 每次展示面板自增,驱动搜索框重新获焦。
    public private(set) var focusToken: Int = 0
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

    /// 经筛选后的可见条目(搜索已在 fetch 应用,这里再叠加类型/固定筛选)。
    public var visibleItems: [ClipItem] {
        items.filter { ClipClassifier.matches($0, filter: filter) }
    }

    public var selectedItem: ClipItem? {
        let visible = visibleItems
        guard let id = selectedID else { return visible.first }
        return visible.first { $0.id == id } ?? visible.first
    }

    /// 每次展示面板前调用:清空上次搜索词、复位筛选、请求搜索框重新获焦。
    public func prepareForPresentation() {
        if !searchText.isEmpty { searchText = "" }
        filter = .all
        focusToken &+= 1
    }

    public func reload() async {
        await runQuery()
    }

    public func setFilter(_ newFilter: ClipFilter) {
        filter = newFilter
        let visible = visibleItems
        if selectedID == nil || !visible.contains(where: { $0.id == selectedID }) {
            selectedID = visible.first?.id
        }
    }

    public func moveSelectionDown() { move(by: 1) }
    public func moveSelectionUp() { move(by: -1) }
    /// 跳到第一个 / 最后一个可见项(随后由列表自动滚动到位)。
    public func selectFirst() { selectedID = visibleItems.first?.id }
    public func selectLast() { selectedID = visibleItems.last?.id }

    public func togglePin(_ item: ClipItem) async {
        try? await repository.setPinned(id: item.id, !item.isPinned)
        await reload()
    }

    public func togglePinSelected() async {
        guard let item = selectedItem else { return }
        await togglePin(item)
    }

    public func delete(_ item: ClipItem) async {
        let removed = (try? await repository.delete(ids: [item.id])) ?? []
        for path in removed {
            try? blobStore.delete(relativePath: path)
        }
        await reload()
    }

    public func deleteSelected() async {
        guard let item = selectedItem else { return }
        let priorIndex = visibleItems.firstIndex { $0.id == item.id }
        await delete(item) // 内部 reload
        let visible = visibleItems
        if let priorIndex, !visible.isEmpty {
            selectedID = visible[min(priorIndex, visible.count - 1)].id
        }
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
        items = (try? await repository.fetch(query)) ?? []
        let visible = visibleItems
        if selectedID == nil || !visible.contains(where: { $0.id == selectedID }) {
            selectedID = visible.first?.id
        }
    }

    private func move(by delta: Int) {
        let visible = visibleItems
        guard !visible.isEmpty else { return }
        let current = visible.firstIndex { $0.id == selectedID } ?? 0
        let next = min(max(current + delta, 0), visible.count - 1)
        selectedID = visible[next].id
    }
}
