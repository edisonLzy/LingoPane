# LingoPane 开发进度

> 最后更新：2026-09-08（Asia/Shanghai）  
> 当前分支：`main`  
> 基线提交：`b4b5273`  
> 产品依据：`/Users/zhiyu/Desktop/个人/obsidian-vault/个人项目/LingoPane/prd/1.功能面板设计.md`

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
异步分析服务（当前为 Mock）
        ↓
中文 / 英文单词 / 英文句子 Panel
        ↓
Pin、复制、发音、详情、历史
```

当前仍属于 MVP 开发阶段：UI、窗口系统与本地数据链路已建立，真实大模型翻译、正式 `.app` 打包签名以及跨应用端到端测试尚未完成。

## 2. 已完成并验证

### 工程与构建

- [x] Swift Package 名称和可执行 Target 已改为 `LingoPane`。
- [x] 最低系统版本为 macOS 14。
- [x] 仅使用 SwiftUI、AppKit、ApplicationServices、Carbon、AVFoundation 等系统框架。
- [x] `swift build` 通过，无编译错误。
- [x] `swift test` 通过：4 项测试、0 失败。
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
- [x] 深红色半透明材质、细描边、低对比辅助文字和 macOS 系统图标已落到 SwiftUI Design System。

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

- [ ] 接入真实 MiniMax / OpenAI-compatible Fast Analyze 与 Deep Analyze 请求。
- [ ] 为模型返回定义稳定的 JSON Schema，并实现结构化解码、错误映射和降级。
- [ ] 使用 Keychain 保存 API Key；当前设置页中的 API Key 仅存在于当前视图内存。
- [ ] 实现请求超时、鉴权失败、网络失败、取消与重试的真实服务层行为。
- [ ] 增加本地 Fast/Deep 分级缓存，避免相同内容重复请求。
- [ ] 创建正式 `.app` Bundle、`Info.plist`、Bundle ID、图标、权限说明、entitlements 和签名流程。
- [ ] 在至少 TextEdit、Safari、Chrome、Obsidian、VS Code 中手工验证真实划词链路。
- [ ] 对原生 Panel 做截图级视觉 QA，目前只完成编译和进程启动验证。

### P1：补齐 PRD 的窗口与学习细节

- [ ] 从 Accessibility 选区范围获取屏幕坐标；当前 Panel 使用鼠标位置作为锚点。
- [ ] 将 Panel 高度改为内容自适应，且严格限制在 560pt 内；当前窗口固定为 500pt。
- [ ] 已 Pin Panel 的标题态折叠/展开。
- [ ] 限制最多 8 个 Pin Panel，并在达到上限时显示明确提示。
- [ ] “一键整理”补齐多列溢出、数量提示、多屏和多个 Space 边界测试。
- [ ] 中文场景切换（通用、技术沟通、正式邮件、口语）及重新生成状态。
- [ ] 英文单词的易混词模块与更多真实样例。
- [ ] 英文句子的二级结构、“更多结构”和 Deep Analyze 单独重试。
- [ ] 把“默认显示句子主干”“默认展开语法”等设置全部加入 UI/状态自动化测试。
- [ ] 按设置中的保留期限清理历史；当前只支持最多 100 条和手动清空。

### P2：产品化

- [ ] 登录时启动、应用更新、诊断日志与隐私说明。
- [ ] VoiceOver 完整走查、Reduce Motion、键盘 Tab 顺序和对比度审计。
- [ ] 性能指标：热键到骨架、Fast Analyze 首屏、缓存命中耗时。
- [ ] 崩溃恢复和异常退出后的数据一致性验证。

## 6. 已知问题与接手注意事项

1. 当前翻译数据来自 `MockTranslationService`。只有 PRD 中的示例文本会得到完整、真实感较高的内容；其他文本返回占位式演示结果。
2. SwiftPM 可执行文件没有正式 App Bundle ID，因此本轮无法通过桌面自动化工具按应用名称捕获窗口；正式 `.app` 打包后再进行 UI 自动化。
3. `SettingsView` 展示了 provider、model、Base URL 和 API Key，但尚未连接真实网络服务。
4. Panel 宽度设置仅影响新创建的 Panel，不会即时调整已经显示的窗口。
5. 旧仓库中的 `Sources/Translator`、旧测试、旧 HTML 和旧图片在本次开发开始前已经处于删除状态。不要直接执行 `git checkout -- .` 或恢复整棵旧目录；如需借鉴，只使用 `git show HEAD:<path>` 只读查看。
6. 当前新实现全部位于 `Sources/LingoPane`，旧删除项与新文件会同时出现在 `git status` 中，这是当前工作树的预期状态。
7. `docs/qa-comparison.html` 和 `docs/reference-panel.png` 是先前留下的 Web 交互稿视觉对照材料，不参与 Swift 编译。
8. 仓库当前缺少新的 `README.md`；旧 README 已处于删除状态，正式打包前应基于本文件重新创建。

## 7. 建议下一位 Agent 的起点

按以下顺序推进，可以最少返工：

1. 新建 `Services/Networking` 和 `Services/Keychain`，先完成 OpenAI-compatible Fast Analyze。
2. 为服务层添加 URLProtocol Stub 测试，覆盖成功、超时、401、无效 JSON 和任务取消。
3. 将网络结果映射到现有 `TranslationResult`，保留 `MockTranslationService` 作为开发/预览模式。
4. 增加 `.app` 打包脚本与 Info.plist，再进行原生 UI 截图和端到端划词验收。
5. 最后补齐 Deep Analyze、缓存与 Pin Panel 的 P1 行为。

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
