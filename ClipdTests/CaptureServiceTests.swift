import XCTest
@testable import Clipd

@MainActor
final class CaptureServiceTests: XCTestCase {

    private var blobRoot: URL!

    override func setUpWithError() throws {
        blobRoot = TestSupport.tempDir()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: blobRoot)
    }

    private func makeStack(
        maxItems: Int = 999,
        storeConcealedMasked: Bool = false
    ) throws -> (CaptureService, SwiftDataClipItemRepository, FileBlobStore) {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repo = SwiftDataClipItemRepository(modelContainer: container)
        let blob = FileBlobStore(rootURL: blobRoot)
        let trimming = TrimmingService(repository: repo, blobStore: blob)
        let service = CaptureService(
            repository: repo,
            blobStore: blob,
            thumbnailer: ThumbnailService(),
            privacyFilter: PrivacyFilter(storeConcealedMasked: storeConcealedMasked),
            trimming: trimming,
            settings: DefaultSettings(maxItems: maxItems)
        )
        return (service, repo, blob)
    }

    private func textSnapshot(_ text: String, count: Int = 1) -> RawPasteboardSnapshot {
        RawPasteboardSnapshot(changeCount: count, text: text)
    }

    func testCapturesText() async throws {
        let (service, repo, _) = try makeStack()
        let outcome = await service.handle(textSnapshot("hello world"))
        XCTAssertEqual(outcome, .captured)

        let items = try await repo.fetch(HistoryQuery())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.kind, .text)
        XCTAssertEqual(items.first?.previewText, "hello world")
    }

    func testSkipsSelfWriteMarker() async throws {
        let (service, repo, _) = try makeStack()
        let outcome = await service.handle(RawPasteboardSnapshot(changeCount: 1, isSelfWrite: true, text: "x"))
        XCTAssertEqual(outcome, .skipped(.selfWrite))

        let count = try await repo.count()
        XCTAssertEqual(count, 0)
    }

    func testSkipsConcealed() async throws {
        let (service, repo, _) = try makeStack()
        let snapshot = RawPasteboardSnapshot(
            changeCount: 1,
            privacyMarkers: [PrivacyFilter.concealedType],
            text: "secret-password"
        )
        let outcome = await service.handle(snapshot)
        XCTAssertEqual(outcome, .skipped(.concealed))

        let count = try await repo.count()
        XCTAssertEqual(count, 0)
    }

    func testDedupTouchesInsteadOfInsert() async throws {
        let (service, repo, _) = try makeStack()
        let first = await service.handle(textSnapshot("same", count: 1))
        XCTAssertEqual(first, .captured)
        let second = await service.handle(textSnapshot("same", count: 2))
        XCTAssertEqual(second, .deduped)

        let count = try await repo.count()
        XCTAssertEqual(count, 1)
    }

    func testNoteSelfWritePreventsCapture() async throws {
        let (service, repo, _) = try makeStack()
        let text = "pasted-back-content"
        service.noteSelfWrite(hash: CaptureService.contentHash(Data(text.utf8)))
        let outcome = await service.handle(textSnapshot(text))
        XCTAssertEqual(outcome, .skipped(.selfWrite))

        let count = try await repo.count()
        XCTAssertEqual(count, 0)
    }

    func testCapturesImageToBlobWithThumbnail() async throws {
        let (service, repo, blob) = try makeStack()
        let png = TestSupport.makePNG(width: 300, height: 200)
        let snapshot = RawPasteboardSnapshot(
            changeCount: 1, imageData: png, imageExt: "png", sourceAppName: "Preview"
        )
        let outcome = await service.handle(snapshot)
        XCTAssertEqual(outcome, .captured)

        let items = try await repo.fetch(HistoryQuery())
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.kind, .image)

        let thumbPath = try XCTUnwrap(item.thumbnailPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: blob.url(forRelativePath: thumbPath).path))

        // 图片负载必须落盘(.file),而非内联。
        let ref = try await repo.payloadRef(for: item.id)
        guard case .file(let path)? = ref else {
            return XCTFail("图片负载应为 .file")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: blob.url(forRelativePath: path).path))
    }

    func testTrimCapsHistoryAfterInsert() async throws {
        let (service, repo, _) = try makeStack(maxItems: 3)
        for i in 1...6 {
            _ = await service.handle(textSnapshot("t\(i)", count: i))
        }
        let count = try await repo.count()
        XCTAssertEqual(count, 3)
    }

    func testEmptySnapshotSkipped() async throws {
        let (service, repo, _) = try makeStack()
        let outcome = await service.handle(RawPasteboardSnapshot(changeCount: 1))
        XCTAssertEqual(outcome, .skipped(.empty))

        let count = try await repo.count()
        XCTAssertEqual(count, 0)
    }
}
