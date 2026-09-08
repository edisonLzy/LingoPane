# LingoPane

macOS 14+ 原生菜单栏翻译工具，使用 Swift 6 / SwiftUI / AppKit。

```sh
swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
swift run LingoPane
```

菜单栏右键打开设置，填写 OpenAI-compatible 服务的 Base URL（以 /v1 结尾）、模型和 API Key，点击「保存 API Key」。
「测试连接」使用当前填写的配置发送一次 hello 翻译请求，会消耗少量模型额度，不自动保存密钥。
MiniMax 国内默认端点为 https://api.minimaxi.com/v1，模型名称请按账号实际可用模型填写。
API Key 保存在 macOS Keychain，其他设置及可选翻译历史保存在本机 UserDefaults。

正常启动调用真实服务；未配置密钥时显示设置提示。离线演示使用：

```sh
swift run LingoPane --preview
```

Fast Analyze 当前返回主译文、词义、IPA 和句子主干。学习字段异常不影响有效主译文。
网络请求超时为 45 秒；失败可通过 Panel 重试，替换查询或关闭 Panel 会取消旧请求。
展开学习详情会按需调用 Deep Analyze；学习层失败保留主译文并可单独重试。Fast/Deep 分级缓存保留 7 天、最多 200 项，可在设置中清空。

使用 `scripts/build-app.sh` 生成 `dist/LingoPane.app`。默认使用本地 ad-hoc 签名；设置 `SIGNING_IDENTITY` 可选择签名身份。分发公证、图标和跨应用验收仍在推进。

返回契约见 [Fast Analyze Schema](docs/schemas/fast-analyze.schema.json)，详细计划见 [开发进度](docs/progress.md)。
接口依据：[MiniMax 官方文档](https://platform.minimaxi.com/docs/api-reference/text-chat-openai)。

登录启动使用 [Apple SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)。版本检查使用项目 GitHub Release；[GitHub API 依据](https://docs.github.com/en/rest/releases)。性能日志可在 Console 中筛选 subsystem `com.lingopane.app`，不会记录翻译文本或密钥。
