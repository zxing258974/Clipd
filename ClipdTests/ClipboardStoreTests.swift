import XCTest
import SwiftData
@testable import Clipd

@MainActor
final class ClipboardStoreTests: XCTestCase {

    private func makeStore() throws -> (ClipboardStore, SwiftDataClipItemRepository, FileBlobStore) {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repo = SwiftDataClipItemRepository(modelContainer: container)
        let blob = FileBlobStore(rootURL: TestSupport.tempDir())
        return (ClipboardStore(repository: repo, blobStore: blob), repo, blob)
    }

    private func textDraft(_ text: String, preview: String? = nil, hash: String, at date: Date = Date()) -> ClipItemDraft {
        ClipItemDraft(
            kind: .text, createdAt: date, previewText: preview ?? text,
            searchText: text.lowercased(), contentHash: hash, appBundleID: nil,
            appName: nil, byteSize: text.utf8.count,
            payloadRef: .inline(Data(text.utf8)), thumbnailPath: nil
        )
    }

    func testTogglePreviewRequiresSelection() throws {
        let (store, _, _) = try makeStore()
        store.togglePreview() // 无内容 -> 无选中 -> 不应开启
        XCTAssertFalse(store.isPreviewing)
    }

    func testTogglePreviewOpensAndCloses() async throws {
        let (store, repo, _) = try makeStore()
        _ = try await repo.insert(textDraft("hello", hash: "h1"))
        await store.reload()
        XCTAssertNotNil(store.selectedItem)

        store.togglePreview()
        XCTAssertTrue(store.isPreviewing)
        store.togglePreview()
        XCTAssertFalse(store.isPreviewing)
    }

    func testPrepareForPresentationResetsPreview() async throws {
        let (store, repo, _) = try makeStore()
        _ = try await repo.insert(textDraft("hi", hash: "h2"))
        await store.reload()
        store.togglePreview()
        XCTAssertTrue(store.isPreviewing)

        store.prepareForPresentation()
        XCTAssertFalse(store.isPreviewing)
    }

    func testFullTextLoadsCompletePayloadBeyondPreviewCap() async throws {
        let (store, repo, _) = try makeStore()
        let long = String(repeating: "A", count: 1200)
        // previewText 仅截断 100 字符,但全文负载是完整 1200。
        _ = try await repo.insert(textDraft(long, preview: String(long.prefix(100)), hash: "h3"))
        await store.reload()
        let item = try XCTUnwrap(store.selectedItem)

        let full = await store.fullText(for: item)
        XCTAssertEqual(full.count, 1200)
    }

    func testFullImageURLNilForText() async throws {
        let (store, repo, _) = try makeStore()
        _ = try await repo.insert(textDraft("just text", hash: "h4"))
        await store.reload()
        let item = try XCTUnwrap(store.selectedItem)

        let url = await store.fullImageURL(for: item)
        XCTAssertNil(url)
    }

    func testFullImageURLPointsAtBlobForImage() async throws {
        let (store, repo, blob) = try makeStore()
        let png = TestSupport.makePNG(width: 8, height: 8)
        let path = try blob.write(png, ext: "png")
        let draft = ClipItemDraft(
            kind: .image, createdAt: Date(), previewText: nil, searchText: "img",
            contentHash: "img-h", appBundleID: nil, appName: nil, byteSize: png.count,
            payloadRef: .file(relativePath: path), thumbnailPath: nil
        )
        _ = try await repo.insert(draft)
        await store.reload()
        let item = try XCTUnwrap(store.selectedItem)

        let url = await store.fullImageURL(for: item)
        XCTAssertEqual(url?.path, blob.url(forRelativePath: path).path)
    }

    /// 粘贴会 touch 选中项的 lastUsedAt(见 PasteService);此处验证置顶后的可见结果:
    /// 重新打开时该项排到最前,并成为默认选中。
    func testTouchedItemFloatsToFirstAndIsSelectedOnReopen() async throws {
        let (store, repo, _) = try makeStore()
        let base = Date(timeIntervalSince1970: 5_000_000)
        let older = try await repo.insert(textDraft("A", hash: "a", at: base))
        _ = try await repo.insert(textDraft("B", hash: "b", at: base.addingTimeInterval(10)))
        await store.reload()
        XCTAssertEqual(store.visibleItems.first?.previewText, "B")
        XCTAssertEqual(store.selectedItem?.previewText, "B")

        // 模拟"粘贴较旧的 A":置顶。
        try await repo.touch(id: older.id, lastUsedAt: base.addingTimeInterval(99))
        store.prepareForPresentation()
        await store.reload()

        XCTAssertEqual(store.visibleItems.first?.previewText, "A")
        XCTAssertEqual(store.selectedItem?.previewText, "A")
    }
}
