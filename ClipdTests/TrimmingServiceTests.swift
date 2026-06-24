import XCTest
@testable import Clipd

final class TrimmingServiceTests: XCTestCase {

    private func imageDraft(hash: String, at date: Date, blob: FileBlobStore) throws -> ClipItemDraft {
        let rel = try blob.write(Data("img-\(hash)".utf8), ext: "png")
        return ClipItemDraft(
            kind: .image, createdAt: date, previewText: nil, searchText: "x",
            contentHash: hash, appBundleID: nil, appName: nil, byteSize: 8,
            payloadRef: .file(relativePath: rel), thumbnailPath: nil
        )
    }

    private func textDraft(hash: String, at date: Date) -> ClipItemDraft {
        ClipItemDraft(
            kind: .text, createdAt: date, previewText: "t", searchText: "t",
            contentHash: hash, appBundleID: nil, appName: nil, byteSize: 1,
            payloadRef: .inline(Data("t".utf8)), thumbnailPath: nil
        )
    }

    func testTrimDeletesOldestUnpinnedAndItsBlob() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repo = SwiftDataClipItemRepository(modelContainer: container)
        let blobRoot = TestSupport.tempDir()
        defer { try? FileManager.default.removeItem(at: blobRoot) }
        let blob = FileBlobStore(rootURL: blobRoot)

        // 最旧:一张图片(带 blob)。
        let oldestImage = try imageDraft(hash: "img", at: Date(timeIntervalSince1970: 1), blob: blob)
        let imageRel: String
        if case .file(let p) = oldestImage.payloadRef { imageRel = p } else { imageRel = "" }
        _ = try await repo.insert(oldestImage)
        // 3 条更新的文本。
        for i in 1...3 {
            _ = try await repo.insert(textDraft(hash: "t\(i)", at: Date(timeIntervalSince1970: TimeInterval(1 + i))))
        }

        let trimming = TrimmingService(repository: repo, blobStore: blob)
        await trimming.trim(maxItems: 2) // 4 条未固定 -> 删最旧 2 条(含图片)

        let count = try await repo.count()
        XCTAssertEqual(count, 2)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: blob.url(forRelativePath: imageRel).path),
            "被裁图片的 blob 应被清理"
        )
    }

    func testSweepOrphanBlobsRemovesUnreferencedFiles() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repo = SwiftDataClipItemRepository(modelContainer: container)
        let blobRoot = TestSupport.tempDir()
        defer { try? FileManager.default.removeItem(at: blobRoot) }
        let blob = FileBlobStore(rootURL: blobRoot)

        let referenced = try blob.write(Data("keep".utf8), ext: "png")
        let orphan = try blob.write(Data("orphan".utf8), ext: "png")
        let draft = ClipItemDraft(
            kind: .image, createdAt: Date(), previewText: nil, searchText: "x",
            contentHash: "h", appBundleID: nil, appName: nil, byteSize: 4,
            payloadRef: .file(relativePath: referenced), thumbnailPath: nil
        )
        _ = try await repo.insert(draft)

        let trimming = TrimmingService(repository: repo, blobStore: blob)
        await trimming.sweepOrphanBlobs()

        XCTAssertTrue(FileManager.default.fileExists(atPath: blob.url(forRelativePath: referenced).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: blob.url(forRelativePath: orphan).path))
    }

    func testEvictExpiredRemovesOldUnpinnedAndDeletesBlob() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repo = SwiftDataClipItemRepository(modelContainer: container)
        let blobRoot = TestSupport.tempDir()
        defer { try? FileManager.default.removeItem(at: blobRoot) }
        let blob = FileBlobStore(rootURL: blobRoot)
        let now = Date(timeIntervalSince1970: 10_000_000)
        let day = 86_400.0

        // 10 天前的图片(带 blob)→ 应被淘汰。
        let rel = try blob.write(Data("old".utf8), ext: "png")
        let oldImage = ClipItemDraft(
            kind: .image, createdAt: now.addingTimeInterval(-10 * day), previewText: nil,
            searchText: "x", contentHash: "old", appBundleID: nil, appName: nil, byteSize: 3,
            payloadRef: .file(relativePath: rel), thumbnailPath: nil
        )
        _ = try await repo.insert(oldImage)
        // 1 天前的文本 → 应保留。
        _ = try await repo.insert(textDraft(hash: "recent", at: now.addingTimeInterval(-1 * day)))

        let trimming = TrimmingService(repository: repo, blobStore: blob)
        await trimming.evictExpired(retentionDays: 7, now: now)

        let count = try await repo.count()
        XCTAssertEqual(count, 1, "仅保留 7 天内的记录")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: blob.url(forRelativePath: rel).path),
            "过期图片的 blob 应被清理"
        )
    }

    func testEvictExpiredDisabledWhenRetentionZero() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repo = SwiftDataClipItemRepository(modelContainer: container)
        let blobRoot = TestSupport.tempDir()
        defer { try? FileManager.default.removeItem(at: blobRoot) }
        let blob = FileBlobStore(rootURL: blobRoot)
        let now = Date(timeIntervalSince1970: 10_000_000)

        _ = try await repo.insert(textDraft(hash: "veryold", at: now.addingTimeInterval(-100 * 86_400)))
        let trimming = TrimmingService(repository: repo, blobStore: blob)
        await trimming.evictExpired(retentionDays: 0, now: now)

        let count = try await repo.count()
        XCTAssertEqual(count, 1, "retentionDays<=0 表示不按时间淘汰")
    }
}
