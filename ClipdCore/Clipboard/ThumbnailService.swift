import Foundation
import ImageIO
import AppKit
import UniformTypeIdentifiers

/// 图片缩略图生成。
///
/// 用 ImageIO `CGImageSourceCreateThumbnailAtIndex` 直接降采样解码,
/// **绝不** `NSImage(data:)` 全解码(大截图会令内存飙升数百 MB)。
public struct ThumbnailService: Sendable {
    public let maxPixel: Int

    public init(maxPixel: Int = 256) {
        self.maxPixel = maxPixel
    }

    /// 生成 PNG 缩略图数据;失败返回 nil。
    public func makeThumbnailPNG(from imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }
}
