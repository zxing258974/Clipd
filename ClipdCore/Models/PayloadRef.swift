import Foundation

/// 一条剪贴板内容的负载存放位置。
///
/// - `inline`:小负载(短文本/小 RTF)直接存进数据库。
/// - `file`:大负载(图片/大文本/文件)落盘到 blobs 目录,数据库只存相对路径。
public enum PayloadRef: Hashable, Sendable {
    case inline(Data)
    case file(relativePath: String)
}
