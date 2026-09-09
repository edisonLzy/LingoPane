# LingoPane

macOS 14+ 菜单栏翻译工具，融合原生 Apple 设计与 AI 智能分析。

![Platform](https://img.shields.io/badge/Platform-macOS%2014+-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 功能特点

### 智能翻译面板
- **三类内容自动识别**：中文表达、英文单词/短语、英文句子
- **Fast Analyze**：快速返回主译文、词义、IPA、句子主干
- **Deep Analyze**：按需展开学习详情，包含搭配、词形、易混词、双语例句等
- **行内语法标注**：Hover 查看、点击固定、键盘焦点支持

### 优雅界面
- **Liquid Glass 磨砂玻璃**：macOS 14 原生 NSVisualEffectView + 反光边缘
- **流畅动效**：首次出现缩放淡入、结果加载切换、展开/折叠弹簧动画
- **无障碍支持**：Reduce Motion 尊重、系统对比度适配

### 高效操作
- **全局快捷键**：`⌥ Space` 快速划词翻译
- **Pin 面板**：固定结果不消失，支持多面板排列
- **翻译历史**：本地保存、按期限自动清理、搜索筛选
- **一键发音**：英文 TTS，支持 en-US / en-GB

### 数据安全
- **API Key 加密存储**：macOS Keychain 保护
- **性能日志**：仅记录类别和耗时，不含原文或密钥
- **透明磨砂玻璃**：尊重系统辅助功能偏好

## 系统要求

- macOS 14 (Sonoma) 或更高版本
- 已配置云端 OpenAI-compatible API，或在本机运行 Ollama

## 快速开始

### 构建项目

```bash
swift build
```

### 运行应用

```bash
# 真实翻译服务（需在设置中配置 API Key）
swift run LingoPane

# 离线演示模式
swift run LingoPane --preview
```

### 运行测试

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

### 构建独立应用

```bash
# 生成 dist/LingoPane.app（默认 ad-hoc 签名）
./scripts/build-app.sh

# 指定签名身份
SIGNING_IDENTITY="Apple Development: Your Name" ./scripts/build-app.sh
```

### 自动构建与发布

- Pull Request 到 `main` 时会自动运行测试。
- 代码推送到 `main` 且测试通过后，会构建支持 Apple Silicon 与 Intel 的 Universal 2 应用并进行 ad-hoc 签名，随后把 ZIP 安装包和 SHA-256 校验文件发布到 GitHub Releases。
- 自动发布会基于 `Info.plist` 中的主/次版本与 Actions 运行编号生成版本号（如 `v0.2.15`）；同一次运行重试时会更新原 Release，而不会重复创建。
- 也可以在仓库的 **Actions → CI and Release → Run workflow** 中手动触发当前 `main` 的构建发布。

自动发布的产物未经 Apple Developer ID 签名或公证，首次打开时可能需要在 Finder 中右键选择“打开”。如需公开分发，建议后续配置 Developer ID 证书和 notarization secrets。

## 配置说明

### 首次设置

1. 点击菜单栏图标打开设置
2. 填写 OpenAI-compatible 服务的 Base URL（以 `/v1` 结尾）
3. 选择或填写模型名称
4. 输入 API Key，点击「保存 API Key」

使用 Ollama 时，在“服务商”中选择“Ollama（本地）”即可，无需填写 API Key。默认地址为
`http://127.0.0.1:11434`；请确保 Ollama 已启动并已下载所选模型，例如：

```bash
ollama pull qwen3.5:4b
```

### 推荐配置

| 服务 | Base URL | 模型示例 |
|------|----------|----------|
| MiniMax | `https://api.minimaxi.com/v1` | `abab6.5s-chat` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o` |
| Ollama（本地） | `http://127.0.0.1:11434` | `qwen3.5:4b` |

### 连接测试

点击「测试连接」使用当前配置发送一次 hello 翻译请求，会消耗少量模型额度，不会自动保存密钥。

## 使用方式

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌥ Space` | 全局划词翻译 |
| `Esc` | 关闭临时面板 |
| `Tab` / `Shift+Tab` | 切换标注焦点 |
| `Return` / `Space` | 固定/取消标注 |

### 面板操作

- **左键点击菜单栏**：打开快捷输入
- **右键点击菜单栏**：设置、历史、整理面板、退出
- **拖动面板标题栏**：移动位置
- **点击 Pin 图标**：固定/取消固定
- **点击展开箭头**：查看学习详情

### 面板类型

| 内容类型 | 显示信息 |
|----------|----------|
| 中文 | 自然表达、替代表达、差异标签、关键词映射、表达说明、双语例句 |
| 英文单词 | 原词、IPA、发音、词性、核心释义、语境释义、搭配、词形、双语例句 |
| 英文句子 | 原句、翻译、句子主干、主要从句、语法点、翻译说明 |

## 项目结构

```
LingoPane/
├── Sources/LingoPane/
│   ├── App/                    # 应用入口与状态管理
│   │   ├── AppState.swift     # 翻译调度、历史、复制
│   │   └── LingoPaneApp.swift # 生命周期与启动
│   ├── Models/                 # 领域模型
│   │   └── TranslationModels.swift
│   ├── Services/               # 核心服务
│   │   ├── HotKeyManager.swift      # Carbon 全局快捷键
│   │   ├── LocalClassifier.swift    # 本地语言/类型识别
│   │   ├── SelectionProvider.swift  # Accessibility 选区读取
│   │   ├── SpeechService.swift      # 系统 TTS
│   │   ├── TranslationService.swift # 服务协议
│   │   └── Networking/
│   │       ├── OpenAITranslationService.swift
│   │       └── AnalysisCache.swift
│   ├── UI/
│   │   ├── Design/PanelStyle.swift    # 玻璃样式与控件
│   │   ├── Panel/                     # 浮动面板
│   │   ├── MenuBar/                   # 菜单栏控制
│   │   ├── History/                   # 历史窗口
│   │   └── Settings/                  # 设置窗口
│   └── Services/Storage/             # 持久化存储
├── Resources/
│   ├── AppIcon.icns           # 应用图标
│   ├── Info.plist
│   └── LingoPane.entitlements
├── docs/
│   └── schemas/fast-analyze.schema.json
└── scripts/
    └── build-app.sh
```

## 技术细节

### 缓存策略

- **Fast/Deep 分级缓存**：按原文、分类、场景、模型隔离
- **保留期限**：7 天
- **最大条目**：200 项
- **历史保留**：默认 90 天，最多 100 条

### 网络配置

- 请求超时：45 秒
- 自动取消：关闭面板、替换查询、发送新请求
- 错误恢复：失败可重试，学习层异常不影响主译文

### 数据存储

| 数据 | 存储位置 |
|------|----------|
| API Key | macOS Keychain |
| 设置 | UserDefaults |
| 历史/缓存 | `~/Library/Application Support/LingoPane/` |

## 相关文档

- [开发进度](docs/progress.md)
- [Fast Analyze Schema](docs/schemas/fast-analyze.schema.json)
- [MiniMax API 文档](https://platform.minimaxi.com/docs/api-reference/text-chat-openai)

## 致谢

基于 Swift 6 / SwiftUI / AppKit 构建，使用 Apple 原生框架：
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) - 登录启动
- [NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview) - 磨砂玻璃
- [Carbon HotKey](https://developer.apple.com/documentation/Carbon) - 全局快捷键
- [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfoundation/avspeechsynthesizer) - 发音
