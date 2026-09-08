# LingoPane 开发进度

> 最后更新：2026-09-08（Asia/Shanghai）  
> 当前分支：`main`  
> 基线提交：`b4b5273`  
> 产品依据：`/Users/evan/Documents/Obsidian Vault/个人项目/LingoPane/prd/1.功能面板设计.md`

## 1. 当前结论

LingoPane 已完成一套可编译、可启动的原生 macOS Swift MVP 骨架。当前实现使用 SwiftUI 构建内容界面，使用 AppKit 管理菜单栏、Popover、工具窗口和真正的浮动 `NSPanel`，并使用 Carbon 注册系统级 `⌥ Space` 快捷键。

主链路已在代码层打通：

```text
菜单栏输入 / 全局快捷键
        ↓
Accessibility 读取选区
        ↓
本地语言与内容类型分类
        ↓
异步分析服务（真实 Fast/Deep Analyze；--preview 使用 Mock）
        ↓
中文 / 英文单词 / 英文句子 Panel
        ↓
Pin、复制、发音、详情、历史
```

当前仍属于 MVP 开发阶段：UI、窗口系统与本地数据链路已建立，Deep Analyze 与缓存已接入，正式 .app 可构建并做本地 ad-hoc 签名；真实服务、跨应用端到端和视觉验收仍未完成。

## 2. 已完成并验证

### 工程与构建

- [x] Swift Package 名称和可执行 Target 已改为 `LingoPane`。
- [x] 最低系统版本为 macOS 14。
- [x] 仅使用 SwiftUI、AppKit、ApplicationServices、Carbon、AVFoundation 等系统框架。
- [x] `swift build` 通过，无编译错误。
- [x] `swift test` 通过：8 项测试、0 失败。
- [x] `swift run LingoPane --preview` 可以成功启动并保持运行；检查后通过 `Ctrl-C` 主动停止。

最近一次验证命令：

```bash
cd /Users/zhiyu/Desktop/coding/LingoPane
swift build
swift test
swift run LingoPane --preview
```

### 应用框架

- [x] 菜单栏常驻入口，应用使用 `.accessory` activation policy，不默认占用 Dock。
- [x] 菜单栏左键打开原生 `NSPopover` 快捷输入。
- [x] 菜单栏右键提供设置、翻译历史、整理 Panel、显示/隐藏全部 Panel、退出。
- [x] 全局 `⌥ Space` 快捷键注册。
- [x] Accessibility API 读取其他 App 的当前选中文字。
- [x] 无选区或无权限时回退到菜单栏手动输入，并提供系统设置入口。

### Panel 系统

- [x] 使用 `NSPanel`，层级为 `.floating`，支持全屏辅助显示和加入当前 Space。
- [x] Panel 出现在鼠标附近，并钳制在屏幕可见区域内。
- [x] 临时 Panel 默认唯一；已有 Panel 被 Pin 后，新查询会创建新的临时 Panel。
- [x] Panel 可拖动、Pin/取消 Pin、关闭、显示/隐藏。
- [x] 已 Pin Panel 可按创建时间在主屏右上角向下排列。
- [x] 点击外部关闭临时 Panel，并已接入“失焦关闭”设置。
- [x] Esc 层级：固定的语法说明 → 展开详情 → 临时 Panel。
- [x] 按用户最新截图改为中性透明磨砂玻璃：原生 behind-window blur、反光细边、24pt 圆角、轻阴影；支持降低透明度与增强对比度。

### 三类功能 Panel

- [x] 中文内容 Panel：自然表达、最多 2 条替代表达、差异标签、关键词映射、表达说明、双语例句。
- [x] 英文单词/短语 Panel：原词、IPA、发音、词性、核心释义、语境释义、搭配、词形、双语例句。
- [x] 英文句子 Panel：原句、翻译、句子主干、主要从句、语法点、翻译说明。
- [x] 句子语法标注支持 240ms Hover、点击固定、键盘焦点和 Esc 关闭。
- [x] 可见语法标注在模型初始化时执行“原文连续子串 + 字符范围”校验；不合法标注会被过滤。
- [x] Header 可手动切换内容类型，切换时会用强制分类重新分析，不再被本地分类覆盖。

### 通用能力

- [x] 复制原文、主结果或释义到系统剪贴板。
- [x] AVSpeechSynthesizer 英文发音，支持设置 en-US / en-GB。
- [x] 本地历史保存、去重、最多 100 条、搜索、方向筛选、重新打开和删除。
- [x] 设置窗口包含快捷键、辅助功能权限、Panel 宽度、语法展开、发音、模型配置和隐私项。
- [x] 内容超过 500 个 Unicode 字符时不截断，保留原文并显示错误状态。
- [x] 加载骨架和可恢复错误视图已实现。

## 3. 测试覆盖

文件：`Tests/LingoPaneTests/LingoPaneTests.swift`

- [x] 中文内容自动路由。
- [x] 英文单词自动路由。
- [x] 较短英文短语自动路由。
- [x] 英文句子自动路由。
- [x] 语法标注连续子串和字符范围校验。

当前测试只覆盖纯逻辑层。窗口生命周期、菜单栏事件、Accessibility、快捷键以及 SwiftUI 交互尚未建立自动化 UI 测试。

## 4. 代码结构

```text
Package.swift
Sources/LingoPane/
├── App/
│   ├── AppState.swift                 # 翻译调度、历史、复制、选区入口
│   └── LingoPaneApp.swift             # App 生命周期与启动入口
├── Models/
│   └── TranslationModels.swift        # 三类 Panel 的领域模型与范围校验
├── Services/
│   ├── HotKeyManager.swift            # Carbon 全局快捷键
│   ├── LocalClassifier.swift          # 本地语言/内容类型识别
│   ├── SelectionProvider.swift        # Accessibility 选区读取
│   ├── SpeechService.swift            # 系统 TTS
│   └── TranslationService.swift       # 服务协议与 Mock 实现
└── UI/
    ├── Design/PanelStyle.swift        # 红色材质、控件、布局原语
    ├── History/HistoryView.swift      # 历史窗口
    ├── MenuBar/
    │   ├── QuickInputView.swift       # 菜单栏输入 Popover
    │   └── StatusBarController.swift  # 左右键菜单与工具窗口
    ├── Panel/
    │   ├── FloatingPanelCoordinator.swift
    │   ├── PanelView.swift
    │   └── PanelViewModel.swift
    └── Settings/SettingsView.swift
Tests/LingoPaneTests/
└── LingoPaneTests.swift
```

## 5. 尚未完成

### P0：达到可真实使用

- [x] 接入真实 MiniMax / OpenAI-compatible Fast Analyze 与按需 Deep Analyze 请求（待真实密钥验收）。
- [x] Fast/Deep JSON Schema、结构化解码、错误映射、可选字段逐项降级；Deep 失败保留基础结果。
- [x] 使用 Keychain 保存 API Key；设置页提供保存/删除和真实连接测试。
- [x] 实现 45 秒超时、鉴权/限流/网络错误映射、取消与手动重试；关闭和替换 Panel 查询取消旧请求。
- [x] 本地 Fast/Deep 分级持久缓存，按原文/分类/场景/模型/配置隔离，7 天、200 项，支持清空。
- [ ] 创建正式 `.app` Bundle、`Info.plist`、Bundle ID、图标、权限说明、entitlements 和签名流程。
- [ ] 在至少 TextEdit、Safari、Chrome、Obsidian、VS Code 中手工验证真实划词链路。
- [ ] 对原生 Panel 做截图级视觉 QA，目前只完成编译和进程启动验证。

### P1：补齐 PRD 的窗口与学习细节

- [x] 从 Accessibility 选区范围获取屏幕坐标，失败回退鼠标（跨应用待验收）。
- [x] Panel 内容自适应高度，上限 560pt；长原文独立滚动（视觉待验收）。
- [x] 已 Pin Panel 标题态折叠/展开。
- [x] 最多 8 个 Pin Panel，上限提示；取消 Pin 时保持临时 Panel 唯一。
- [ ] “一键整理”补齐多列溢出、数量提示、多屏和多个 Space 边界测试。
- [x] 中文四种场景切换与重新生成状态，固定 Panel 原位刷新。
- [x] 英文单词易混词模块接入 Deep（最多 2 个）；真实内容质量仍待验收。
- [ ] 已实现更多结构与 Deep 独立重试；原句行内嵌套标注和二级结构层次仍需完善。
- [ ] 把“默认显示句子主干”“默认展开语法”等设置全部加入 UI/状态自动化测试。
- [x] 历史按期限清理；关闭保存后不再记录；关闭保存时清空仍可持久化。

### P2：产品化

- [ ] 登录时启动、应用更新、诊断日志与隐私说明。
- [ ] VoiceOver 完整走查、Reduce Motion、键盘 Tab 顺序和对比度审计。
- [ ] 性能指标：热键到骨架、Fast Analyze 首屏、缓存命中耗时。
- [ ] 崩溃恢复和异常退出后的数据一致性验证。

## 6. 已知问题与接手注意事项

1. 正常启动使用真实 OpenAI-compatible Fast Analyze，需在设置中配置并保存 API Key；仅 `--preview` 使用 Mock。Fast 返回主译文、词义、IPA、主干，展开后按需执行 Deep Analyze。
2. SwiftPM 可执行文件没有正式 App Bundle ID，因此本轮无法通过桌面自动化工具按应用名称捕获窗口；正式 `.app` 打包后再进行 UI 自动化。
3. 设置已连接网络服务，修改模型和 Base URL 在下次请求生效；测试连接使用当前填写密钥，不自动保存。
4. Panel 宽度设置仅影响新创建的 Panel，不会即时调整已经显示的窗口。
5. 旧仓库中的 `Sources/Translator`、旧测试、旧 HTML 和旧图片在本次开发开始前已经处于删除状态。不要直接执行 `git checkout -- .` 或恢复整棵旧目录；如需借鉴，只使用 `git show HEAD:<path>` 只读查看。
6. 当前实现全部位于 `Sources/LingoPane`；本次接手时工作树干净，旧删除状态已不适用。
7. `docs/qa-comparison.html` 和 `docs/reference-panel.png` 是先前留下的 Web 交互稿视觉对照材料，不参与 Swift 编译。
8. 已新增 README，包含启动、配置、演示模式与当前限制。

## 7. 建议下一位 Agent 的起点

按以下顺序推进，可以最少返工：

1. 在设置中配置真实模型和 API Key，验收三类 Fast Analyze 输入及 Keychain 保存/删除。
2. 验收 Deep 学习层与单独重试，补充 UI 及 AppState 并发回归。
3. 完善原句行内标注、键盘 Esc 层级与布局视觉验收。
4. 增加 `.app` 打包脚本与 Info.plist，再进行原生 UI 截图和端到端划词验收。
5. 补齐 Pin Panel 等 P1 行为。

## 8. 完成定义

只有满足以下条件才能将 LingoPane MVP 标记为完成：

- [ ] 真实中英文输入能够通过配置的模型服务返回结果。
- [ ] 三类输入均自动路由到正确 Panel，主译文、复制和发音可用。
- [ ] 学习层失败不影响基础翻译。
- [ ] 全局快捷键在目标 App 集合中通过端到端验证。
- [ ] 临时、Pin、拖动、Esc、一键整理行为符合 PRD。
- [ ] 语法标注全部通过原文连续范围校验。
- [ ] 正式 `.app` 可构建、启动、授权并通过基础回归测试。
- [ ] `swift build`、`swift test` 和 UI 验收均通过。

## 9. 本轮续实现（2026-09-08）

- 新增 Networking/OpenAITranslationService.swift：真实 Fast Analyze、HTTPS 配置校验、Chat Completions 请求、结构化解码与安全错误提示。
- 新增 Keychain/APIKeyStore.swift：密钥读取、更新、删除；密钥不写入 UserDefaults。
- Fast v1 返回契约见 `docs/schemas/fast-analyze.schema.json`。兼容性考虑通过提示约束 JSON，未依赖服务商 strict schema 功能；主结果严格校验，可选学习字段逐项降级。
- AppState 默认真实服务，预览显式 Mock；请求标识阻止旧请求覆盖新结果，关闭 Panel 取消请求，修复并发 isWorking 清理。
- 新增 URLProtocol 测试：成功、学习字段降级、401、超时、断网、无效 JSON、任务取消及配置校验。
- 未进行真实密钥调用、Keychain 交互验收或 UI/跨应用验收；Deep Analyze、缓存和打包仍未完成。

本轮验证：`swift build` 通过；`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过（8 项、0 失败）。
本机默认 Command Line Tools 缺少 XCTest，测试需使用上述 Xcode 工具链命令。

## 10. 全功能目标推进（2026-09-08）

本节中的“已实现”表示代码已落地，不等于全量产品验收通过。全功能目标仍进行中，图标在功能完成后设计。

- Deep 学习层、独立重试、四种表达场景、Fast/Deep 持久缓存已接入。
- Panel 自适应高度、固定折叠、数量上限、当前 Space 排列与溢出折叠已实现。
- 历史保留期限、保存开关语义、发音暂停/继续、Return/Shift+Return 已补齐。
- 登录启动通过 SMAppService 实现；更新通过 GitHub 最新 Release 检查并提供下载页面，尚未发布 Release 或验证真实更新安装。
- OSLog 性能事件只记录类别和耗时，不记录原文、密钥或请求响应。
- `scripts/build-app.sh` 生成 `dist/LingoPane.app`，带 Info.plist、Bundle ID、entitlements；支持 SIGNING_IDENTITY，默认 ad-hoc。尚未 Developer ID 签名/公证。
- .app 已启动且进程存活；CUA 读取窗口超时，视觉 QA 未通过也未判失败。

仍需完成/验证：
1. 原句连续行内标注（当前独立标注区域）、嵌套二级结构、键盘说明卡 Esc 焦点处理。
2. 更多 UI 状态测试、VoiceOver、对比度和 Reduce Motion 完整走查。
3. 真实密钥请求、Keychain 系统交互、TextEdit/Safari/Chrome/Obsidian/VS Code 划词链路。
4. 多显示器、Space、极小屏幕整理溢出与自适应高度视觉验收。
5. 历史/缓存异常退出与损坏恢复测试；登录启动与更新端到端验收。
6. Apple Dock 图标设计、.icns 接入、最终打包回归与完整完成审计。

本批最终测试：Xcode 工具链下 13 项测试、0 失败，覆盖网络错误、取消、Deep 范围过滤、缓存持久化/过期/清空、历史期限、Panel 状态重置及多列布局边界。仍不能以这些逻辑测试替代真机 UI 验收。

## 11. 玻璃样式与行内标注（2026-09-08）

用户最新要求优先于旧 PRD 的暗红色方案：参考透明磨砂玻璃截图，现已去除红色覆盖层。
- `PanelStyle.swift` 使用 macOS 14 原生 NSVisualEffectView 背景模糊，叠加极轻明暗渐变与反光边缘；并非 macOS 26 专用 NSGlassEffectView。
- Panel 强制正确的 Dark Aqua 外观，移除重复菜单箭头，修复浅色系统下标题/菜单图标发黑；辅助文字对比度提升。
- 原句改为单一完整 attributed string，保留标点、换行及空格，支持 Unicode 字符范围转 UTF-16。原文内部滚动；标注只在学习展开后显示。
- 一级/嵌套从句基于有效包含范围区分；更多结构显示二级标注；Hover/点击/Tab/Return/Space 使用同一说明状态，Esc 不会被原有焦点立即重新打开。
- 历史和缓存使用双份原子快照、递增版本；损坏一份或中途退出可恢复最新完整数据，清空后不会从旧备份恢复记录。
- Xcode 工具链 18 项测试通过；release .app 打包与签名验证通过。
- CUA 再次返回 timeoutReached，未取得新版实际窗口截图；图二风格的真机视觉验收仍待完成。
- Apple 材质依据：https://developer.apple.com/design/human-interface-guidelines/materials

全功能目标仍进行中，真实密钥/跨应用/VoiceOver/更新与登录启动端到端验收、极端布局边界和最终图标仍未完成。

## 12. 功能面板动效（2026-09-08）

- Panel 首次出现使用轻微缩放淡入，结果加载完成或发生错误时进行短时淡入切换。
- 展开、折叠和窗口高度变化采用短弹簧或缓入缓出动画，说明卡柔和浮现。
- 加载骨架使用低对比度扫光；图标按钮悬停时轻微放大。
- 系统开启“减少动态效果”后，上述非必要动画均停用。
