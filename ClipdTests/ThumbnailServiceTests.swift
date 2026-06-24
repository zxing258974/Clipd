import XCTest
import AppKit
@testable import Clipd

final class ThumbnailServiceTests: XCTestCase {

    func testThumbnailDownsamplesToMaxPixel() throws {
        let source = TestSupport.makePNG(width: 400, height: 300)
        let thumbData = try XCTUnwrap(ThumbnailService(maxPixel: 100).makeThumbnailPNG(from: source))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: thumbData))
        XCTAssertLessThanOrEqual(max(rep.pixelsWide, rep.pixelsHigh), 100)
        // 缩略图应明显小于原图字节。
        XCTAssertLessThan(thumbData.count, source.count)
    }

    func testThumbnailKeepsAspectRatio() throws {
        let source = TestSupport.makePNG(width: 400, height: 200)
        let thumbData = try XCTUnwrap(ThumbnailService(maxPixel: 100).makeThumbnailPNG(from: source))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: thumbData))
        XCTAssertEqual(rep.pixelsWide, 100)
        XCTAssertEqual(rep.pixelsHigh, 50)
    }

    func testInvalidDataReturnsNil() {
        XCTAssertNil(ThumbnailService().makeThumbnailPNG(from: Data([0x00, 0x01, 0x02, 0x03])))
    }
}
