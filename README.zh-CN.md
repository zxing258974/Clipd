# Clipd

[English](README.md) · **中文**

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-1f6feb)
![Swift](https://img.shields.io/badge/Swift-6-f05138?logo=swift&logoColor=white)
![License](https://img.shields.io/github/license/zxing258974/Clipd?color=brightgreen)
![Stars](https://img.shields.io/github/stars/zxing258974/Clipd?style=social)

一款快速、原生的 macOS 剪贴板历史管理工具。Clipd 常驻菜单栏,记录你复制过的一切,并用一个快捷键随时取回。

## 功能

- **菜单栏应用** —— 无 Dock 图标。用全局快捷键(默认 <kbd>⌘⇧C</kbd>,可自定义)从屏幕底部唤起卡片栏。也可隐藏菜单栏图标,只用快捷键唤起。
- **全类型捕获** —— 纯文本、代码、链接、颜色(hex)、图片、文件,每种类型有专属卡片版式。
- **键盘优先**
  - <kbd>←</kbd> <kbd>→</kbd> 切换选中 · <kbd>⌘←</kbd> / <kbd>⌘→</kbd> 跳到首张 / 末张
  - <kbd>空格</kbd> 预览选中项(Quick Look 风格)
  - <kbd>⏎</kbd> 或双击 粘贴到前台 App —— 粘贴过的条目会回到最前
  - <kbd>⌘⌫</kbd> 删除 · <kbd>⌘P</kbd> 固定 / 取消 · <kbd>esc</kbd> 关闭
- **搜索与筛选** —— 输入即搜;按 全部 / 已固定 / 文本 / 链接 / 图片 / 颜色 / 文件 筛选。
- **固定收藏** —— 已固定项永久保留,不受清理影响。
- **标签与快捷操作** —— 右击卡片可复制、删除或打标签;可随手新建标签,并按任意标签筛选。
- **自动清理** —— 保留最近 *N* 天(默认 7)且最多 *N* 条(默认 1000);固定项永不删除。
- **尊重隐私** —— 识别密码管理器使用的 `org.nspasteboard.*` 标记;机密 / 临时 / 自动生成的内容一律不存储。所有数据只留在你的 Mac 上。
- **浅色与深色** —— 跟随系统外观,并可选强调色。
- **高效存储** —— 文本存入本地 SwiftData;图片落盘并只在库内保留小缩略图,数据库保持轻量。

## 安装(下载的构建版)

从 [Releases](https://github.com/zxing258974/Clipd/releases) 页下载最新的 `.dmg`。构建版用开发者证书签名但**未公证**,macOS Gatekeeper 会在首次启动时拦截。打开 DMG,把 **Clipd** 拖到 **应用程序**,然后执行一次以清除隔离标记:

```bash
xattr -dr com.apple.quarantine /Applications/Clipd.app
```

(或右键 App →「打开」→「打开」。)从源码构建则无此限制。

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
3. 按 <kbd>⌘⇧C</kbd> 打开卡片栏;输入即搜,<kbd>←</kbd> <kbd>→</kbd> 选择,<kbd>空格</kbd> 预览,<kbd>⏎</kbd> 或双击粘贴。右击卡片可复制、删除或打标签。
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

## 路线图

- [x] 捕获文本、图片、链接、颜色、代码、文件
- [x] 底部卡片栏:搜索、类型筛选、固定
- [x] 空格预览选中项(Quick Look 风格)
- [x] 粘贴过的条目回到最前(最近使用)
- [x] 按时间与条数清理;尊重隐私标记
- [x] 设置:保留时长、开机自启、外观、强调色、快捷键、隐藏菜单栏图标
- [x] 右键卡片复制或删除
- [x] 标签:新建、打标签、按标签筛选

### 未来想法

- [ ] 保留富文本 / HTML 格式(目前仅存纯文本)
- [ ] <kbd>⌘1</kbd>–<kbd>⌘9</kbd> 快速粘贴最近的某一条

## 参与贡献

欢迎提 issue 与 PR。

```bash
brew install xcodegen
xcodegen generate && open Clipd.xcodeproj
```

运行测试:`xcodebuild -project Clipd.xcodeproj -scheme Clipd -destination 'platform=macOS' test`。

## 许可证

基于 MIT 许可证发布 —— 见 [LICENSE](LICENSE)。
