import XCTest
@testable import Clipd

/// 冒烟测试:验证测试 target 能链接并访问 Clipd 模块。
final class SmokeTests: XCTestCase {
    func testClipKindCases() {
        XCTAssertEqual(ClipKind.allCases.count, 5)
        XCTAssertEqual(ClipKind.text.rawValue, "text")
        XCTAssertEqual(ClipKind.fileURL.rawValue, "fileURL")
    }
}
