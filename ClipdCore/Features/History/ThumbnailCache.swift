import AppKit

/// 进程级缩略图缓存。
///
/// 缩略图按 blob 不可变,故无需失效逻辑:同一路径只解码一次,后续命中直接返回,
/// 避免横向滚动 / 选中态重渲染时在主线程反复读盘解码导致掉帧。
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    func image(forPath path: String) -> NSImage? {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
