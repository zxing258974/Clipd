import XCTest
import SwiftData
@testable import Clipd

final class RepositoryTests: XCTestCase {

    private func makeRepo() throws -> SwiftDataClipItemRepository {
        let container = try ModelContainerFactory.make(inMemory: true)
        return SwiftDataClipItemRepository(modelContainer: container)
    }

    private func textDraft(
        _ text: String,
        hash: String? = nil,
        at date: Date = Date()
    ) -> ClipItemDraft {
        ClipItemDraft(
            kind: .text,
            createdAt: date,
            previewText: text,
            searchText: text.lowercased(),
            contentHash: hash ?? text,
            appBundleID: nil,
            appName: nil,
            byteSize: text.utf8.count,
            payloadRef: .inline(Data(text.utf8)),
            thumbnailPath: nil
        )
    }

    func testInsertAndFetch() async throws {
        let repo = try makeRepo()
        _ = try await repo.insert(textDraft("Hello"))
        let items = try await repo.fetch(HistoryQuery())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.previewText, "Hello")
        let total = try await repo.count()
        XCTAssertEqual(total, 1)
    }

    func testFetchSortsPinnedFirstThenRecency() async throws {
        let repo = try makeRepo()
        let base = Date(timeIntervalSince1970: 1_000_000)
        _ = try await repo.insert(textDraft("old", at: base))
        let mid = try await repo.insert(textDraft("mid", at: base.addingTimeInterval(10)))
        _ = try await repo.insert(textDraft("new", at: base.addingTimeInterval(20)))

        // 固定最旧的一条 -> 应被顶到最前。
        let oldID = try await repo.findID(byHash: "old")
        try await repo.setPinned(id: try XCTUnwrap(oldID), true)
        _ = mid

        let items = try await repo.fetch(HistoryQuery())
        XCTAssertEqual(items.map(\.previewText), ["old", "new", "mid"])
    }

    func testDedupFindByHashAndTouchMovesToTop() async throws {
        let repo = try makeRepo()
        let base = Date(timeIntervalSince1970: 2_000_000)
        _ = try await repo.insert(textDraft("a", hash: "h-a", at: base))
        _ = try await repo.insert(textDraft("b", hash: "h-b", at: base.addingTimeInterval(10)))

        // 再次复制 "a":命中已存在 -> touch 置顶,不新增。
        let existing = try await repo.findID(byHash: "h-a")
        XCTAssertNotNil(existing)
        try await repo.touch(id: try XCTUnwrap(existing), lastUsedAt: base.addingTimeInterval(99))

        let items = try await repo.fetch(HistoryQuery())
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.previewText, "a")
    }

    func testSearchFilterInMemory() async throws {
        let repo = try makeRepo()
        _ = try await repo.insert(textDraft("Swift Concurrency"))
        _ = try await repo.insert(textDraft("clipboard manager"))

        let hits = try await repo.fetch(HistoryQuery(searchText: "SWIFT"))
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.previewText, "Swift Concurrency")
    }

    func testTrimUnpinnedKeepsPinnedAndReturnsBlobPaths() async throws {
        let repo = try makeRepo()
        let base = Date(timeIntervalSince1970: 3_000_000)

        // 一条带 blob 路径的"图片"草稿(最旧),应在裁剪时被删并返回其路径。
        let imageDraft = ClipItemDraft(
            kind: .image, createdAt: base, previewText: "图片",
            searchText: "图片", contentHash: "img", appBundleID: nil, appName: nil,
            byteSize: 1024, payloadRef: .file(relativePath: "2026/06/x.png"),
            thumbnailPath: "2026/06/x_thumb.png"
        )
        _ = try await repo.insert(imageDraft)
        for i in 1...4 {
            _ = try await repo.insert(textDraft("t\(i)", at: base.addingTimeInterval(Double(i))))
        }
        // 固定最旧的图片项 -> 它不应被裁剪。
        let imgID = try await repo.findID(byHash: "img")
        try await repo.setPinned(id: try XCTUnwrap(imgID), true)

        // 5 条里 4 条未固定,裁剪到 2 条未固定 -> 删 2 条最旧未固定文本。
        let removed = try await repo.trimUnpinned(maxItems: 2)
        XCTAssertTrue(removed.isEmpty, "被删的是纯文本(无 blob),不应返回路径")

        let remaining = try await repo.fetch(HistoryQuery())
        // 固定图片 + 2 条最新未固定文本 = 3
        XCTAssertEqual(remaining.count, 3)
        XCTAssertTrue(remaining.contains { $0.previewText == "图片" }, "固定项必须保留")
    }

    func testDeleteReturnsBlobPaths() async throws {
        let repo = try makeRepo()
        let imageDraft = ClipItemDraft(
            kind: .image, createdAt: Date(), previewText: "p",
            searchText: "p", contentHash: "img2", appBundleID: nil, appName: nil,
            byteSize: 2048, payloadRef: .file(relativePath: "2026/06/y.png"),
            thumbnailPath: "2026/06/y_thumb.png"
        )
        let item = try await repo.insert(imageDraft)
        let removed = try await repo.delete(ids: [item.id])
        XCTAssertEqual(Set(removed), ["2026/06/y.png", "2026/06/y_thumb.png"])
        let total = try await repo.count()
        XCTAssertEqual(total, 0)
    }

    func testPayloadRefRoundTrip() async throws {
        let repo = try makeRepo()
        let item = try await repo.insert(textDraft("payload", hash: "p1"))
        let ref = try await repo.payloadRef(for: item.id)
        guard case .inline(let data) = ref else {
            return XCTFail("应为 inline")
        }
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "payload")
    }

    func testReferencedBlobPaths() async throws {
        let repo = try makeRepo()
        let imageDraft = ClipItemDraft(
            kind: .image, createdAt: Date(), previewText: "p",
            searchText: "p", contentHash: "img3", appBundleID: nil, appName: nil,
            byteSize: 10, payloadRef: .file(relativePath: "a/b.png"),
            thumbnailPath: "a/b_thumb.png"
        )
        _ = try await repo.insert(imageDraft)
        _ = try await repo.insert(textDraft("just text"))
        let refs = try await repo.referencedBlobPaths()
        XCTAssertEqual(refs, ["a/b.png", "a/b_thumb.png"])
    }

    func testDeleteExpiredExemptsPinned() async throws {
        let repo = try makeRepo()
        let base = Date(timeIntervalSince1970: 1_000_000)
        _ = try await repo.insert(textDraft("old", hash: "old", at: base))
        let pinned = try await repo.insert(textDraft("pinnedOld", hash: "pin", at: base))
        try await repo.setPinned(id: pinned.id, true)
        _ = try await repo.insert(textDraft("recent", hash: "recent", at: base.addingTimeInterval(100_000)))

        let cutoff = base.addingTimeInterval(50_000)
        let removed = try await repo.deleteExpired(lastUsedBefore: cutoff)
        XCTAssertTrue(removed.isEmpty, "被删的是无 blob 的旧文本")

        let items = try await repo.fetch(HistoryQuery())
        XCTAssertEqual(Set(items.compactMap(\.previewText)), ["pinnedOld", "recent"])
    }

    func testDeleteExpiredReturnsBlobsOfExpiredImages() async throws {
        let repo = try makeRepo()
        let base = Date(timeIntervalSince1970: 2_000_000)
        let imageDraft = ClipItemDraft(
            kind: .image, createdAt: base, previewText: nil, searchText: "x",
            contentHash: "img", appBundleID: nil, appName: nil, byteSize: 10,
            payloadRef: .file(relativePath: "b/y.png"), thumbnailPath: "b/y_thumb.png"
        )
        _ = try await repo.insert(imageDraft)
        let removed = try await repo.deleteExpired(lastUsedBefore: base.addingTimeInterval(10))
        XCTAssertEqual(Set(removed), ["b/y.png", "b/y_thumb.png"])
        let count = try await repo.count()
        XCTAssertEqual(count, 0)
    }

    func testSetTagsDeduplicatesTrimsAndSorts() async throws {
        let repo = try makeRepo()
        let item = try await repo.insert(textDraft("hi", hash: "t1"))
        try await repo.setTags(["  work ", "ideas", "work", ""], id: item.id)
        let items = try await repo.fetch(HistoryQuery())
        XCTAssertEqual(items.first?.tags, ["ideas", "work"])
    }
}
