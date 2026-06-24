import Foundation
import SwiftData

/// 创建 SwiftData `ModelContainer`。
///
/// 生产环境落盘到 `Application Support/Clipd/Storage.sqlite`;
/// 测试环境使用内存容器。
public enum ModelContainerFactory {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([ClipItemEntity.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let url = try AppPaths.storeURL()
            configuration = ModelConfiguration(schema: schema, url: url)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
