import Foundation

/// 大负载(图片/大文本/缩略图)落盘存取接口。
///
/// 数据库只存相对路径,字节落在 `blobs/yyyy/MM/<uuid>.<ext>`,
/// 规避 Maccy 内联 blob 导致的 SQLite 膨胀/内存问题。
public protocol BlobStoring: Sendable {
    /// 写入并返回相对 `rootURL` 的路径(如 `2026/06/UUID.png`)。
    func write(_ data: Data, ext: String) throws -> String
    func read(relativePath: String) throws -> Data
    /// 删除;文件不存在视为成功(幂等)。
    func delete(relativePath: String) throws
    func url(forRelativePath path: String) -> URL
    var rootURL: URL { get }
}

/// 基于文件系统的实现。仅持有 `rootURL`(Sendable);`FileManager.default` 内联使用。
public struct FileBlobStore: BlobStoring {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func write(_ data: Data, ext: String) throws -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        let subdir = String(format: "%04d/%02d", comps.year ?? 0, comps.month ?? 0)
        let fileName = "\(UUID().uuidString).\(ext)"
        let relativePath = "\(subdir)/\(fileName)"

        let dirURL = rootURL.appendingPathComponent(subdir, isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        try data.write(to: rootURL.appendingPathComponent(relativePath), options: .atomic)
        return relativePath
    }

    public func read(relativePath: String) throws -> Data {
        try Data(contentsOf: url(forRelativePath: relativePath))
    }

    public func delete(relativePath: String) throws {
        let fileURL = url(forRelativePath: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public func url(forRelativePath path: String) -> URL {
        rootURL.appendingPathComponent(path)
    }
}
