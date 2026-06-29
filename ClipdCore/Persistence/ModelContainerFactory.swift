import Foundation
import SwiftData

/// 创建 SwiftData `ModelContainer`。
///
/// 生产环境落盘到 `Application Support/Clipd/Storage.sqlite`;
/// 测试环境使用内存容器。
public enum ModelContainerFactory {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([ClipItemEntity.self])
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: config)
        }
        let url = try AppPaths.storeURL()
        let config = ModelConfiguration(schema: schema, url: url)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // 旧库无法打开/迁移(如早期开发版写入的不兼容数据)——移走损坏库后以全新库启动,
            // 确保 App 始终可用(代价是历史清空;剪贴板历史可再生)。
            moveAsideStore(at: url)
            return try ModelContainer(for: schema, configurations: config)
        }
    }

    /// 把无法打开的库文件改名备份(含 -wal/-shm),让下次以全新库启动。
    private static func moveAsideStore(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            guard fm.fileExists(atPath: file.path) else { continue }
            let backup = URL(fileURLWithPath: file.path + ".corrupt")
            try? fm.removeItem(at: backup)
            try? fm.moveItem(at: file, to: backup)
        }
    }
}
