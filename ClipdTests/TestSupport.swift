import AppKit
import Foundation

/// 测试辅助。
enum TestSupport {
    /// 生成指定尺寸的有效 PNG 数据(未绘制内容,像素为零,但格式合法)。
    static func makePNG(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    /// 创建一个唯一的临时目录。
    static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipdTest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
