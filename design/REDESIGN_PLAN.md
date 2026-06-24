# Clipd 面板按设计稿重做 — 实施计划

设计稿源:`design/Clipboard.dc.html`(+ `support.js` 逻辑、`screenshots/`)。这是用户在 claude.ai/design 做的完整交互稿,作为面板的"北极星"。本文件把设计 → 现有 SwiftUI 代码的映射、分类规则、分阶段任务固化下来,供后续会话直接执行(无需重读 600 行 HTML)。

## 设计要点(从 Clipboard.dc.html 提炼)

- **底部栏**:贴底、铺满宽度、**高 474px**、顶部圆角 18、半透明玻璃(深色 `rgba(28,28,34,.72)`/浅色 `rgba(246,246,249,.78)` + blur40 saturate180)、上边框 1px、`box-shadow:0 -20px 60px`。滑入动画已实现。
- **支持浅/深主题**(token 表见设计稿 `tokens()`,约 386–393 行 dark / 376–382 行 light)+ **6 个强调色**(#0A84FF 蓝默认 / #5E5CE6 / #BF5AF2 / #FF375F / #FF9F0A / #30D158)。原生侧建议**跟随系统外观**。
- **顶部 header**:左 `剪贴板` 标题(17 粗)+ `{n} 项`;中 **筛选 pills**(横向滚动,active=强调色)`全部/已固定/文本/链接/图片/颜色/文件`;右 **搜索框**(220 宽,⌕+输入+清除×);最右 **设置齿轮**(32×32)。
- **卡片墙**:横向滚动,gap 14,卡片**宽 240**、**高度撑满墙**(align stretch,不是固定高)、圆角 14。hover 上浮 4px。
- **卡片 = header + body(按类型) + footer**:
  - header:App 图标 chip(20,圆角6)+ App 名(省略号)+ 固定圆点(强调色)+ 相对时间。
  - footer:类型标签(色点 + 文字)+ meta(右,次要)。
  - **body 按 kind 分版式**:
    - text/richtext:标题(14 粗,2 行)+ 正文(13 次要,5 行)。
    - code:文件名(等宽)+ 代码块(inset 底、等宽、绿/蓝代码色、pre-wrap、撑满)。
    - link:渐变头图(84 高)+ 域名 pill + 标题(2 行)。
    - image:缩略图填充 + 底部渐变遮罩 + 标题。
    - color:整块色块 + hex 标签 chip(等宽,毛玻璃底)。
    - file:白色文档图标(角标 + 扩展名)+ 文件名 + 大小。
  - **选中态**:2px 强调色描边 + **左上角序号角标**(强调色方块,显示 1/2/3…)+ 阴影抬起。
- **footer 提示条**(可开关):`⏎ 粘贴 / 空格 预览 / ← → 切换 / ⌫ 删除 / ⌘F 搜索` + 右侧 `当前/总数`。
- **Quick Look(空格)**:scrim+blur 蒙层 + 680 宽面板,大图展示该项,底部按钮 `粘贴/复制/固定/删除`。
- **粘贴 toast**:`已粘贴 "X" 到 <App>` + ✓,1.7s 自动消失。
- **设置(齿轮)**:740×540 模态,红绿灯标题栏,4 标签:
  - 通用:开关(开机自启/纯文本粘贴/自动去重/粘贴音效/菜单栏图标/iCloud 同步)+ 历史保留(最近 30 天)。
  - 外观:浅/深分段 + 6 强调色样本。
  - 收藏夹:pinboards 列表(工作/设计/代码/灵感 + 计数)+ 新建。
  - 快捷键:快捷键列表。
- **快捷键**(support.js `onKey`):← →/↑↓/Tab 切换;⏎ 粘贴;空格 Quick Look;⌫/Del 删除;⌘F 或 `/` 聚焦搜索;1-9 快速选;Esc 清搜索/关闭;面板关闭时 ⌥⌘V/Esc 重开。

## 现有代码映射 & 可复用项(已核实)

- 面板/定位/滑入:`ClipdCore/Panel/PanelController.swift`(`panelHeight` 改 360→**474**;新增按键 delete/pin/space/⌘F/数字 — 注意本地监听需把 `command` 修饰位也传进 `handleKeyDown`,目前只传了 keyCode)。
- 窗口:`SearchPanel.swift`(borderless 非激活,已就绪)。
- 根视图:`Features/History/PanelRootView.swift`(重写 header:标题+计数+pills+搜索+齿轮;footer 加 `当前/总数`)。
- 卡片:`Features/History/ClipCardView.swift`(重写为 240 宽、撑满高、按 kind 分版式、序号角标、App 图标、相对时间、meta)。
- 列表:`Features/History/HistoryStripView.swift`(改用 `visibleItems`,传入 index 给角标;单击选中/双击粘贴已就绪)。
- 数据源:`Features/History/ClipboardStore.swift`(加 `filter: ClipFilter` + `visibleItems`(按分类过滤)+ 导航改为基于 visibleItems + `deleteSelected()/togglePinSelected()`;`togglePin/delete` 已存在)。
- **固定**:`isPinned`/`setPinned`/`togglePin` **后端全就绪**,直接接 UI 即可。
- 类型:`ClipKind` 已有 `text/rtf/html/image/fileURL`;`HistoryQuery` 已支持 `kinds/pinnedOnly`。
- 设置:已有 `Features/Settings/SettingsView.swift`(通用 + 快捷键雏形),按设计扩成 4 标签。

## 内容分类(纯 UI 层,新增 `ClipItemPresentation.swift`)

从 `ClipItem`(kind + previewText + appName)派生**展示 kind**,不动数据模型:
- `image` → image;`fileURL` → file;`rtf/html` → text(富文本暂按文本)。
- `text`:
  - 命中 `^#([0-9a-fA-F]{3}|{6}|{8})$` → **color**(解析 hex 出色块 + RGB meta)。
  - 无空格/换行且 `http(s)://` 或 `^[\w.-]+\.[a-z]{2,}(/.*)?$` → **link**(取 host 作域名)。
  - 多行且含代码 token(`{ } ; => function const let def class import func return`)或来自代码类 App → **code**。
  - 否则 → **text**。
- meta:text=`{n} 字符`;link=`网页链接`;image=`ByteCountFormatter(byteSize)`;color=`RGB r · g · b`;code=`代码`;file=大小。
- 相对时间:`刚刚/<n>分钟前/<n>小时前/昨天/<n>天前`(基于 lastUsedAt)。
- App 图标:`NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` → `icon(forFile:)`,用 `@MainActor` NSCache 缓存;无 bundleID 回退"首字母 + 颜色"chip。
- 标签色(KIND):文本#0A84FF 富文本#5E5CE6 代码#30D158 链接#64D2FF 图片#FF375F 颜色#FF9F0A 文件#98989D。

## 分阶段(建议)

- **P1(核心视觉,最高优先)**:主题 token(浅/深自适应 + 蓝强调)、栏高 474、header(标题+计数+pills+搜索+齿轮)、卡片按 kind 重做(text/link/color/code/image)+ App 图标 + 相对时间 + meta + 选中描边/序号角标、filter pills 接 store、footer(提示+当前/总数)、空状态、撑满高卡片。键位补:⌫ 删除、P 固定。**齿轮先开现有 SettingsView**。
- **P2**:Quick Look(空格,带 粘贴/复制/固定/删除)+ 粘贴 toast。
- **P3**:设置页重做成 4 标签(通用开关持久化、外观浅/深+强调色选择并落到主题、快捷键列表用 KeyboardShortcuts.Recorder)。
- **P4**:收藏夹(pinboards)= 新建 `TagEntity` 多对多;源头捕获真正的 code/file(fileURL bookmark)/richtext 类型;⌘F/空格/数字键位补全(需把修饰键传入面板键处理)。

## 验证
每阶段:`xcodegen generate`(若加文件)→ `xcodebuild ... test`(36 测试不应回归)→ 真机 ⌘⇧C 肉眼核对设计稿/截图(`design/screenshots/`)。注意签名已用 Apple Development 证书(勿回 ad-hoc),辅助功能授权稳定。
