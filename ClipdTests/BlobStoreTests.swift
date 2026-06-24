import XCTest
@testable import Clipd

final class BlobStoreTests: XCTestCase {

    private var tempRoot: URL!
    private var store: FileBlobStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipdBlobTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        store = FileBlobStore(rootURL: tempRoot)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testWriteReturnsDatedRelativePathAndCreatesFile() throws {
        let data = Data("hello blob".utf8)
        let rel = try store.write(data, ext: "png")
        // 形如 yyyy/MM/UUID.png
        XCTAssertTrue(rel.hasSuffix(".png"))
        XCTAssertEqual(rel.split(separator: "/").count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(forRelativePath: rel).path))
    }

    func testReadRoundTrip() throws {
        let data = Data([0x1, 0x2, 0x3, 0x4])
        let rel = try store.write(data, ext: "bin")
        XCTAssertEqual(try store.read(relativePath: rel), data)
    }

    func testDeleteIsIdempotent() throws {
        let rel = try store.write(Data("x".utf8), ext: "txt")
        try store.delete(relativePath: rel)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(forRelativePath: rel).path))
        // 再删不报错
        XCTAssertNoThrow(try store.delete(relativePath: rel))
    }

    func testReadMissingThrows() {
        XCTAssertThrowsError(try store.read(relativePath: "nope/missing.bin"))
    }
}
