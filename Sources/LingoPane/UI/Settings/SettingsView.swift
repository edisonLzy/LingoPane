import AppKit
import SwiftUI

public struct SettingsView: View {
    @StateObject private var loginItem = LoginItemService()
    @StateObject private var updates = UpdateService()
    @ObservedObject var state: AppState

    @AppStorage("closeTemporaryOnBlur") private var closeTemporaryOnBlur = true
    @AppStorage("showSentenceSkeleton") private var showSentenceSkeleton = true
    @AppStorage("expandGrammarByDefault") private var expandGrammarByDefault = false
    @AppStorage("panelWidth") private var panelWidth = 400.0
    @AppStorage("speechLocale") private var speechLocale = "en-US"
    @AppStorage("provider") private var provider = "MiniMax"
    @AppStorage("model") private var model = "MiniMax-M2.1"
    @AppStorage("baseURL") private var baseURL = "https://api.minimaxi.com/v1"
    @AppStorage("sttModel") private var sttModel = SpeechToTextConfiguration.defaultModel
    @AppStorage("saveHistory") private var saveHistory = true

    @State private var apiKey = ""
    @State private var connectionStatus: String?
    @State private var testing = false
    @State private var vaultPath = HistoryStore.configuredPath
    @State private var vaultStatus: String?
    @State private var hotKeyShortcut = HotKeyPreferences.current
    @State private var hotKeyStatus: String?
    @State private var voiceShortcut = VoiceHotKeyPreferences.current
    @State private var voiceHotKeyStatus: String?
    @State private var showingClearHistoryConfirmation = false

    private let ink = Color(red: 0.22, green: 0.21, blue: 0.19)
    private let accent = Color(red: 0.38, green: 0.46, blue: 0.34)

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 26) {
                generalSection
                displaySection
                modelSection
                vaultSection
                aboutSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 36)
            .frame(maxWidth: 680)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            vaultPath = HistoryStore.configuredPath
            hotKeyShortcut = HotKeyPreferences.current
            voiceShortcut = VoiceHotKeyPreferences.current
            do { apiKey = try APIKeyStore.read() }
            catch { connectionStatus = error.localizedDescription }
        }
        .alert("清空 Vault 历史？", isPresented: $showingClearHistoryConfirmation) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) { state.clearHistory() }
        } message: {
            Text("LingoPane 创建的知识项与每日日志将移到废纸篓，包括其中的“我的笔记”内容。")
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(spacing: 20) {
            SettingCard("系统与启动", icon: "macwindow") {
                SettingRow("登录时自动启动", subtitle: "Mac 开机登录时自动在后台启动 LingoPane") {
                    Toggle("", isOn: Binding(get: { loginItem.enabled }, set: { loginItem.setEnabled($0) }))
                        .labelsHidden()
                        .tint(accent)
                }
                if let message = loginItem.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }

                Divider().opacity(0.2).padding(.horizontal, 14)

                SettingRow("失焦自动收起", subtitle: "点击外部窗口时收起未锁定的临时翻译面板") {
                    Toggle("", isOn: $closeTemporaryOnBlur)
                        .labelsHidden()
                        .tint(accent)
                }
            }

            SettingCard("全局快捷键", icon: "keyboard") {
                SettingRow("划词翻译快捷键", subtitle: "选中屏幕上任何文本后按下触发翻译") {
                    HStack(spacing: 8) {
                        HotKeyRecorderView(
                            shortcut: $hotKeyShortcut,
                            onCommit: { shortcut in
                                guard shortcut != voiceShortcut else {
                                    hotKeyStatus = "不能与语音输入快捷键相同"
                                    return false
                                }
                                let accepted = HotKeyManager.shared.updateShortcut(shortcut)
                                hotKeyStatus = accepted ? "快捷键已生效" : nil
                                return accepted
                            },
                            onFailure: { hotKeyStatus = "快捷键已被系统或其他应用占用" }
                        )
                        .frame(width: 140, height: 26)

                        Button("默认") {
                            guard HotKeyManager.shared.updateShortcut(.default) else {
                                hotKeyStatus = "默认快捷键不可用"
                                return
                            }
                            hotKeyShortcut = .default
                            hotKeyStatus = "已恢复为 ⌥Space"
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }
                if let hotKeyStatus {
                    Text(hotKeyStatus)
                        .font(.caption)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }
            }

            SettingCard("语音输入", icon: "mic") {
                SettingRow("语音输入快捷键", subtitle: "按住开始录音、菜单栏显示声波，松开后识别为文字（默认 ⌥V）") {
                    HStack(spacing: 8) {
                        HotKeyRecorderView(
                            shortcut: $voiceShortcut,
                            onCommit: { shortcut in
                                guard shortcut != hotKeyShortcut else {
                                    voiceHotKeyStatus = "不能与划词翻译快捷键相同"
                                    return false
                                }
                                let accepted = HotKeyManager.shared.updateVoiceShortcut(shortcut)
                                voiceHotKeyStatus = accepted ? "快捷键已生效" : nil
                                return accepted
                            },
                            onFailure: { voiceHotKeyStatus = "快捷键已被系统或其他应用占用" }
                        )
                        .frame(width: 140, height: 26)

                        Button("默认") {
                            guard HotKeyManager.shared.updateVoiceShortcut(VoiceHotKeyPreferences.defaultShortcut) else {
                                voiceHotKeyStatus = "默认快捷键不可用"
                                return
                            }
                            voiceShortcut = VoiceHotKeyPreferences.defaultShortcut
                            voiceHotKeyStatus = "已恢复为 ⌥V"
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }
                if let voiceHotKeyStatus {
                    Text(voiceHotKeyStatus)
                        .font(.caption)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 14)
                }

                Divider().opacity(0.2).padding(.horizontal, 14)

                SettingRow("识别模型 (STT)", subtitle: "需支持音频输入的模型，本地 Ollama 推荐 gemma4:e2b（7.2GB）") {
                    VStack(alignment: .trailing, spacing: 3) {
                        TextField("例如 gemma4:e2b", text: $sttModel)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ink.opacity(0.12), lineWidth: 0.8))
                            .frame(width: 220)
                        Text("地址复用上方 Base URL · ollama pull \(sttModel.isEmpty ? SpeechToTextConfiguration.defaultModel : sttModel)")
                            .font(.caption)
                            .foregroundStyle(ink.opacity(0.5))
                    }
                }

                Divider().opacity(0.2).padding(.horizontal, 14)
                Text("🎙 录音只保留在内存中，识别完成后即释放，不会写入本地文件；单次录音最长 29 秒。")
                    .font(.caption)
                    .foregroundStyle(ink.opacity(0.55))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }

            SettingCard("权限状态", icon: "lock.shield") {
                SettingRow("辅助功能权限", subtitle: "需要读取光标选中的文本内容") {
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(SelectionProvider.shared.isAccessibilityGranted ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(SelectionProvider.shared.isAccessibilityGranted ? "已授权" : "未授权")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(SelectionProvider.shared.isAccessibilityGranted ? .green : .orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (SelectionProvider.shared.isAccessibilityGranted ? Color.green : Color.orange).opacity(0.1),
                            in: Capsule()
                        )

                        Button("打开系统设置") {
                            SelectionProvider.shared.openAccessibilitySettings()
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(spacing: 20) {
            SettingCard("分析与排版", icon: "text.alignleft") {
                SettingRow("默认显示句子主干", subtitle: "英文长难句自动高亮主谓宾核心骨架") {
                    Toggle("", isOn: $showSentenceSkeleton)
                        .labelsHidden()
                        .tint(accent)
                }

                Divider().opacity(0.2).padding(.horizontal, 14)

                SettingRow("默认展开语法详情", subtitle: "在弹窗中默认展开从句及语法成分分析") {
                    Toggle("", isOn: $expandGrammarByDefault)
                        .labelsHidden()
                        .tint(accent)
                }

                Divider().opacity(0.2).padding(.horizontal, 14)

                SettingRow("英文发音口音", subtitle: "朗读词句时使用的发音地区库") {
                    Picker("", selection: $speechLocale) {
                        Text("美式英语 (en-US)").tag("en-US")
                        Text("英式英语 (en-GB)").tag("en-GB")
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }

            SettingCard("面板外观", icon: "slider.horizontal.below.rectangle") {
                SettingRow("浮动面板宽度", subtitle: "设置划词翻译浮窗的默认宽度") {
                    HStack(spacing: 8) {
                        Slider(value: $panelWidth, in: 360...480, step: 10)
                            .frame(width: 160)
                        Text("\(Int(panelWidth)) pt")
                            .monospacedDigit()
                            .font(.system(size: 12.5, weight: .medium))
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        VStack(spacing: 20) {
            SettingCard("服务商与配置", icon: "cpu") {
                SettingRow("AI 服务商", subtitle: "选择后端翻译大模型驱动") {
                    Picker("", selection: $provider) {
                        Text("MiniMax").tag("MiniMax")
                        Text("Ollama（本地）").tag("Ollama")
                        Text("OpenAI-compatible").tag("OpenAI-compatible")
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: provider) { _, newProvider in
                        guard newProvider == ModelProvider.ollama.rawValue else { return }
                        baseURL = "http://127.0.0.1:11434"
                        if model.hasPrefix("MiniMax-") { model = "qwen3.5:4b" }
                        connectionStatus = "请确保本地运行: ollama pull \(model)"
                    }
                }

                Divider().opacity(0.2).padding(.horizontal, 14)

                SettingRow("模型标识 (Model)", subtitle: "用于请求的具体模型名称") {
                    TextField("例如 MiniMax-M2.1", text: $model)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ink.opacity(0.12), lineWidth: 0.8))
                        .frame(width: 220)
                }

                Divider().opacity(0.2).padding(.horizontal, 14)

                SettingRow("接口 Base URL", subtitle: "API 服务的基础访问地址") {
                    TextField("https://...", text: $baseURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ink.opacity(0.12), lineWidth: 0.8))
                        .frame(width: 220)
                }

                if provider != ModelProvider.ollama.rawValue {
                    Divider().opacity(0.2).padding(.horizontal, 14)

                    SettingRow("API Key", subtitle: "加密保存在 macOS 系统的 Keychain 中") {
                        HStack(spacing: 6) {
                            SecureField("输入 API Key", text: $apiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ink.opacity(0.12), lineWidth: 0.8))
                                .frame(width: 170)

                            Button("保存") {
                                do {
                                    try APIKeyStore.save(apiKey)
                                    connectionStatus = apiKey.isEmpty ? "API Key 已移除" : "已安全保存到 Keychain"
                                } catch { connectionStatus = error.localizedDescription }
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Divider().opacity(0.2).padding(.horizontal, 14)
                    Text("💡 本地 Ollama 无需配置 API Key；模型分析使用本地 JSON 结构化输出。")
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.55))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
            }

            SettingCard("连接测试", icon: "antenna.radiowaves.left.and.right") {
                SettingRow("连通性检查", subtitle: connectionStatus ?? "发起一次轻量请求以验证配置是否有效") {
                    Button(testing ? "正在测试…" : "测试连接") {
                        testing = true
                        connectionStatus = nil
                        let config = ModelConfiguration(
                            baseURL: baseURL,
                            model: model,
                            apiKey: apiKey,
                            provider: ModelProvider(rawValue: provider) ?? .openAICompatible
                        )
                        Task {
                            defer { testing = false }
                            do {
                                _ = try await OpenAITranslationService(configuration: config).analyze(
                                    "hello", classification: Classification(language: .english, kind: .word))
                                connectionStatus = "连接成功！模型响应正常"
                            } catch { connectionStatus = "测试失败: \(error.localizedDescription)" }
                        }
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(testing)
                }
            }
        }
    }

    // MARK: - Vault Section

    private var vaultSection: some View {
        VStack(spacing: 20) {
            SettingCard("Vault 知识沉淀", icon: "folder") {
                SettingRow("保存翻译历史到 Vault", subtitle: "将词句卡片自动沉淀为本地 Markdown 知识档案") {
                    Toggle("", isOn: $saveHistory)
                        .labelsHidden()
                        .tint(accent)
                }

                if saveHistory {
                    Divider().opacity(0.2).padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("存储目录")
                            .font(.system(size: 13, weight: .medium))

                        HStack(spacing: 8) {
                            TextField("Vault 目录路径", text: $vaultPath)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ink.opacity(0.12), lineWidth: 0.8))

                            Button("选择…") { chooseVaultFolder() }
                                .controlSize(.small)
                                .buttonStyle(.bordered)

                            Button("应用") { applyVaultPath() }
                                .controlSize(.small)
                                .buttonStyle(.bordered)
                                .disabled(vaultPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("在 Finder 打开") { revealVaultFolder() }
                                .controlSize(.small)
                                .buttonStyle(.bordered)
                        }

                        if let vaultStatus {
                            Text(vaultStatus)
                                .font(.caption)
                                .foregroundStyle(accent)
                        }

                        Text("知识项写入 Items/，每日遇见写入 Daily/。兼容 Obsidian 等笔记工具。")
                            .font(.caption)
                            .foregroundStyle(ink.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }

            SettingCard("数据清理", icon: "trash") {
                SettingRow("缓存与重载", subtitle: "管理本地网络分析缓存与历史项") {
                    HStack(spacing: 8) {
                        Button("从 Vault 重新载入") {
                            state.reloadHistory()
                            vaultStatus = "已载入 \(state.history.count) 个知识项"
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)

                        Button("清空翻译缓存") {
                            Task { await AnalysisCache.shared.clear() }
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }

                Divider().opacity(0.2).padding(.horizontal, 14)

                SettingRow("危险操作", subtitle: "将 Vault 中 LingoPane 创建的内容移至废纸篓") {
                    Button("清空 Vault 历史", role: .destructive) {
                        showingClearHistoryConfirmation = true
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .disabled(state.history.isEmpty)
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 20) {
            SettingCard("关于 LingoPane", icon: "sparkles") {
                HStack(spacing: 16) {
                    Image(systemName: "character.bubble.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("LingoPane")
                            .font(.system(size: 16, weight: .semibold))
                        Text("原生极简的 macOS 划词翻译与长难句解析伴侣")
                            .font(.caption)
                            .foregroundStyle(ink.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)

                Divider().opacity(0.2).padding(.horizontal, 14)

                SettingRow("软件版本与更新", subtitle: updates.message ?? "检查是否有新版本可用") {
                    HStack(spacing: 8) {
                        Button(updates.checking ? "正在检查…" : "检查更新") {
                            Task { await updates.check() }
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                        .disabled(updates.checking)

                        if let url = updates.releaseURL {
                            Link("前往下载", destination: url)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - File Operations

    private func chooseVaultFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择 LingoPane 的 Vault 存储目录"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        let current = URL(fileURLWithPath: NSString(string: vaultPath).expandingTildeInPath, isDirectory: true)
        if FileManager.default.fileExists(atPath: current.path) { panel.directoryURL = current }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vaultPath = url.path
        applyVaultPath()
    }

    private func applyVaultPath() {
        let path = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: expanded, isDirectory: true),
                withIntermediateDirectories: true
            )
            state.configureVaultPath(path)
            vaultPath = HistoryStore.configuredPath
            vaultStatus = "路径已应用，载入 \(state.history.count) 个知识项"
        } catch {
            vaultStatus = "无法使用该目录：\(error.localizedDescription)"
        }
    }

    private func revealVaultFolder() {
        let url = URL(
            fileURLWithPath: NSString(string: vaultPath).expandingTildeInPath,
            isDirectory: true
        )
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Setting Layout Components

private struct SettingCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(_ title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    private static var hairline: Color { Color(red: 0.22, green: 0.21, blue: 0.19) }

    // Flat grouping: no card plate. The eyebrow label plus the hairline dividers
    // between rows carry the structure, so the list reads as one continuous page
    // instead of stacked boxes on top of it.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.38, green: 0.46, blue: 0.34))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Self.hairline.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 2)

            VStack(spacing: 0) {
                content
            }
        }
    }
}

private struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.22, green: 0.21, blue: 0.19))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.22, green: 0.21, blue: 0.19).opacity(0.50))
                        .lineLimit(2)
                }
            }
            Spacer()
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
