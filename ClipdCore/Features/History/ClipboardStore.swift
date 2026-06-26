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
    /// 是否正在展示选中项的大图预览(空格开/关)。
    public var isPreviewing = false
    /// 是否正在新建标签(面板内输入覆盖层开/关)。
    public var isCreatingTag = false
    /// "新建标签"输入框内容。
    public var newTagDraft = ""
    /// 当前筛选(全部/已固定/文本/链接/图片/颜色/文件,或某个标签)。
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
    /// "新建标签"流程中记录的目标条目。
    @ObservationIgnored private var pendingTagItemID: UUID?

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

    /// 当前历史中出现过的全部标签(并集,排序),用于渲染标签 pills。
    public var allTags: [String] {
        Array(Set(items.flatMap(\.tags))).sorted()
    }

    /// 每次展示面板前调用:清空上次搜索词、复位筛选、请求搜索框重新获焦。
    public func prepareForPresentation() {
        if !searchText.isEmpty { searchText = "" }
        filter = .all
        selectedID = nil // 每次打开默认选中第一个(随后 runQuery 置为 visible.first)
        isPreviewing = false // 每次打开都从卡片墙开始,而非上次的预览态
        isCreatingTag = false
        newTagDraft = ""
        pendingTagItemID = nil
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

    /// 切换预览:无选中项时不开;已开则关。
    public func togglePreview() {
        if isPreviewing { isPreviewing = false; return }
        guard selectedItem != nil else { return }
        isPreviewing = true
    }

    public func closePreview() { isPreviewing = false }

    // MARK: 标签

    /// 在条目上添加/移除某标签。
    public func toggleTag(_ tag: String, on item: ClipItem) async {
        var tags = Set(item.tags)
        if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
        try? await repository.setTags(Array(tags), id: item.id)
        await reload()
    }

    /// 打开"新建标签"输入(记录目标条目;关掉预览以免叠层)。
    public func beginCreatingTag(for item: ClipItem) {
        pendingTagItemID = item.id
        newTagDraft = ""
        isPreviewing = false
        isCreatingTag = true
    }

    /// 取消"新建标签"输入。
    public func cancelNewTag() {
        isCreatingTag = false
        newTagDraft = ""
        pendingTagItemID = nil
        focusToken &+= 1 // 关闭后焦点回到搜索框
    }

    /// 提交"新建标签":把输入加入目标条目的标签集合。
    public func commitNewTag() async {
        let name = newTagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let id = pendingTagItemID,
              let item = items.first(where: { $0.id == id }) else {
            cancelNewTag(); return
        }
        var tags = Set(item.tags)
        tags.insert(name)
        try? await repository.setTags(Array(tags), id: id)
        cancelNewTag()
        await reload()
    }

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

    // MARK: 预览全量加载(懒加载,仅在预览时调用)

    /// 加载条目全文(预览用)。文本/代码/链接/文件走此路径;读不到时回退 `previewText`。
    /// 文件 I/O 放到后台,避免阻塞主线程。
    public func fullText(for item: ClipItem) async -> String {
        guard let ref = try? await repository.payloadRef(for: item.id) else {
            return item.previewText ?? ""
        }
        switch ref {
        case .inline(let data):
            return String(data: data, encoding: .utf8) ?? (item.previewText ?? "")
        case .file(let path):
            let blobStore = self.blobStore
            let data = await Task.detached { try? blobStore.read(relativePath: path) }.value
            if let data, let text = String(data: data, encoding: .utf8) { return text }
            return item.previewText ?? ""
        }
    }

    /// 图片原图的绝对 URL(预览用;非图片或非落盘返回 nil)。
    public func fullImageURL(for item: ClipItem) async -> URL? {
        guard item.kind == .image,
              case .file(let path)? = try? await repository.payloadRef(for: item.id)
        else { return nil }
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
        // 标签筛选下,若该标签已不存在(最后一条带它的记录被删/取消标签),回退到全部。
        if case .tag(let name) = filter, !allTags.contains(name) { filter = .all }
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
