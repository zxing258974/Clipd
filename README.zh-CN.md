# Clipd

[English](README.md) · **中文**

一款快速、原生的 macOS 剪贴板历史管理工具。Clipd 常驻菜单栏,记录你复制过的一切,并用一个快捷键随时取回。

## 功能

- **菜单栏应用** —— 无 Dock 图标。用全局快捷键(默认 <kbd>⌘⇧C</kbd>,可自定义)从屏幕底部唤起卡片栏。
- **全类型捕获** —— 纯文本、富文本、代码、链接、颜色(hex)、图片、文件,每种类型有专属卡片版式。
- **键盘优先**
  - <kbd>←</kbd> <kbd>→</kbd> 切换选中 · <kbd>⌘←</kbd> / <kbd>⌘→</kbd> 跳到首张 / 末张
  - <kbd>⏎</kbd> 或双击 粘贴到前台 App
  - <kbd>⌘⌫</kbd> 删除 · <kbd>⌘P</kbd> 固定 / 取消 · <kbd>esc</kbd> 关闭
- **搜索与筛选** —— 输入即搜;按 全部 / 已固定 / 文本 / 链接 / 图片 / 颜色 / 文件 筛选。
- **固定收藏** —— 已固定项永久保留,不受清理影响。
- **自动清理** —— 保留最近 *N* 天(默认 7)且最多 *N* 条(默认 1000);固定项永不删除。
- **尊重隐私** —— 识别密码管理器使用的 `org.nspasteboard.*` 标记;机密 / 临时 / 自动生成的内容一律不存储。所有数据只留在你的 Mac 上。
- **浅色与深色** —— 跟随系统外观,并可选强调色。
- **高效存储** —— 文本存入本地 SwiftData;图片落盘并只在库内保留小缩略图,数据库保持轻量。

## 环境要求

- macOS 14(Sonoma)及以上
- Xcode 16 及以上(Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) —— `brew install xcodegen`

## 构建与运行

```bash
xcodegen generate          # 由 project.yml 生成 Clipd.xcodeproj
open Clipd.xcodeproj        # 在 Xcode 里运行(⌘R)
```

或使用命令行:

```bash
xcodebuild -project Clipd.xcodeproj -scheme Clipd -configuration Release build
xcodebuild -project Clipd.xcodeproj -scheme Clipd -destination 'platform=macOS' test
```

> 生成的 `Clipd.xcodeproj` 不纳入版本库 —— `project.yml` 才是源真相。拉取更新后请重跑 `xcodegen generate`。

### 代码签名

仓库默认使用 ad‑hoc 签名,任何人都能在本机构建,无需 Apple 账号。若希望辅助功能授权在重新编译后不失效,把你自己的签名身份写入 `Config/Local.xcconfig`(已被 .gitignore 忽略):

```
DEVELOPMENT_TEAM = XXXXXXXXXX
CODE_SIGN_IDENTITY = Apple Development: you@example.com (XXXXXXXXXX)
```

## 首次使用

1. 启动 Clipd —— 菜单栏出现剪贴板图标。
2. 复制一段文本或图片,即被记入历史。
3. 按 <kbd>⌘⇧C</kbd> 打开卡片栏;输入即搜,<kbd>←</kbd> <kbd>→</kbd> 选择,<kbd>⏎</kbd> 或双击粘贴。
4. 如需自动粘贴,在 **系统设置 → 隐私与安全性 → 辅助功能** 中授权 Clipd。未授权时降级为"只复制"(由你手动按 <kbd>⌘V</kbd>)。

## 架构

```
App/                  @main 入口、AppDelegate、AppCoordinator(组合根)
ClipdCore/
  Models/             Sendable 领域类型
  Persistence/        SwiftData @Model + @ModelActor 仓储
  Storage/            落盘 blob 存储、路径
  Clipboard/          轮询监听、隐私过滤、捕获、缩略图、裁剪
  Paste/              剪贴板写回、键码映射、粘贴服务
  Hotkeys/            全局热键
  Permissions/        辅助功能权限
  Panel/              NSPanel + 菜单栏状态项
  Features/           SwiftUI 卡片栏与设置页
ClipdTests/           单元测试
```

面向 Swift 6 严格并发设计:领域类型为 `Sendable`,所有 SwiftData 访问隔离在 `@ModelActor`,UI 与剪贴板代码运行在主 actor。

## 技术栈

Swift 6(严格并发)· SwiftUI + AppKit · SwiftData · macOS 14+。
依赖:[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 与 [Sauce](https://github.com/Clipy/Sauce)(均为 MIT)。

## 隐私

Clipd 捕获的所有内容仅存储在本机 `~/Library/Application Support/Clipd/` 下,不会离开你的设备。被其他 App(如密码管理器)标记为机密/临时/自动生成的内容会被跳过,因此不会记录密码。

## 许可证

基于 MIT 许可证发布 —— 见 [LICENSE](LICENSE)。
