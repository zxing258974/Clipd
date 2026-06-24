import Foundation

/// 应用数据目录解析。
///
/// 所有数据落在 `~/Library/Application Support/Clipd/` 下:
/// - `Storage.sqlite`:SwiftData 数据库
/// - `blobs/`:图片/大文件原件
public enum AppPaths {
    public static let folderName = "Clipd"

    /// `~/Library/Application Support/Clipd/`(不存在则创建)。
    public static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// SwiftData 数据库文件 URL。
    public static func storeURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("Storage.sqlite")
    }

    /// blobs 根目录(不存在则创建)。
    public static func blobsRootURL() throws -> URL {
        let dir = try applicationSupportDirectory().appendingPathComponent("blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
