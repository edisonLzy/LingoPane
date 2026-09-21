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
    @AppStorage("saveHistory") private var saveHistory = true
    @State private var apiKey = ""
    @State private var connectionStatus: String?
    @State private var testing = false
    @State private var vaultPath = HistoryStore.configuredPath
    @State private var vaultStatus: String?
    @State private var hotKeyShortcut = HotKeyPreferences.current
    @State private var hotKeyStatus: String?
    @State private var showingClearHistoryConfirmation = false

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        Form {
            Section("通用") {
                Toggle("登录时启动", isOn: Binding(get: { loginItem.enabled }, set: { loginItem.setEnabled($0) }))
                if let message = loginItem.message { Text(message).font(.caption) }
                LabeledContent("全局快捷键") {
                    HStack(spacing: 8) {
                        HotKeyRecorderView(
                            shortcut: $hotKeyShortcut,
                            onCommit: { shortcut in
                                let accepted = HotKeyManager.shared.updateShortcut(shortcut)
                                hotKeyStatus = accepted ? "快捷键已更新" : nil
                                return accepted
                            },
                            onFailure: { hotKeyStatus = "该快捷键已被系统或其他应用占用" }
                        )
                        .frame(width: 150, height: 26)
                        Button("恢复默认") {
                            guard HotKeyManager.shared.updateShortcut(.default) else {
                                hotKeyStatus = "默认快捷键当前不可用"
                                return
                            }
                            hotKeyShortcut = .default
                            hotKeyStatus = "已恢复为 ⌥Space"
                        }
                        .controlSize(.small)
                    }
                }
                Text("点击快捷键按钮后直接按下新的组合键；至少需要一个修饰键。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let hotKeyStatus { Text(hotKeyStatus).font(.caption).foregroundStyle(.secondary) }
                Toggle("失焦关闭临时 Panel", isOn: $closeTemporaryOnBlur)
                HStack {
                    LabeledContent("辅助功能权限") {
                        Text(SelectionProvider.shared.isAccessibilityGranted ? "已授权" : "未授权")
                            .foregroundStyle(SelectionProvider.shared.isAccessibilityGranted ? .green : .orange)
                    }
                    Button("打开系统设置") { SelectionProvider.shared.openAccessibilitySettings() }
                }
            }

            Section("显示与学习") {
                Toggle("默认显示句子主干", isOn: $showSentenceSkeleton)
                Toggle("默认展开语法详情", isOn: $expandGrammarByDefault)
                LabeledContent("Panel 宽度") {
                    HStack {
                        Slider(value: $panelWidth, in: 360...480, step: 10).frame(width: 190)
                        Text("\(Int(panelWidth)) pt").monospacedDigit().frame(width: 54, alignment: .trailing)
                    }
                }
                Picker("英文发音", selection: $speechLocale) {
                    Text("美式英语").tag("en-US")
                    Text("英式英语").tag("en-GB")
                }
            }

            Section("模型") {
                Picker("服务商", selection: $provider) {
                    Text("MiniMax").tag("MiniMax")
                    Text("Ollama（本地）").tag("Ollama")
                    Text("OpenAI-compatible").tag("OpenAI-compatible")
                }
                .onChange(of: provider) { _, newProvider in
                    guard newProvider == ModelProvider.ollama.rawValue else { return }
                    baseURL = "http://127.0.0.1:11434"
                    if model.hasPrefix("MiniMax-") { model = "qwen3.5:4b" }
                    connectionStatus = "请先在终端运行 ollama pull \(model)"
                }
                TextField("模型", text: $model)
                TextField("Base URL", text: $baseURL)
                if provider == ModelProvider.ollama.rawValue {
                    Text("本地 Ollama 无需 API Key；翻译和学习分析均使用结构化输出并关闭思考。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    SecureField("API Key", text: $apiKey)
                }
                HStack {
                    if provider != ModelProvider.ollama.rawValue {
                        Button("保存 API Key") {
                            do {
                                try APIKeyStore.save(apiKey)
                                connectionStatus = apiKey.isEmpty ? "API Key 已删除" : "API Key 已保存到 Keychain"
                            } catch { connectionStatus = error.localizedDescription }
                        }
                    }
                    Button(testing ? "测试中…" : "测试连接") {
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
                                connectionStatus = "连接成功；API Key 需单独保存"
                            } catch { connectionStatus = error.localizedDescription }
                        }
                    }
                    .disabled(testing)
                    if let connectionStatus {
                        Text(connectionStatus).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("应用更新") {
                Button(updates.checking ? "检查中…" : "检查更新") { Task { await updates.check() } }
                    .disabled(updates.checking)
                if let message = updates.message { Text(message).font(.caption) }
                if let url = updates.releaseURL { Link("查看版本并下载", destination: url) }
            }

            Section("翻译历史与 Vault") {
                Toggle("保存翻译历史到 Vault", isOn: $saveHistory)
                VStack(alignment: .leading, spacing: 8) {
                    Text("LingoPane 存储目录").font(.subheadline).fontWeight(.medium)
                    HStack {
                        TextField("Vault 中的存储目录", text: $vaultPath)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .font(.system(.caption, design: .monospaced))
                            .onSubmit { applyVaultPath() }
                        Button("选择…") { chooseVaultFolder() }
                        Button("应用") { applyVaultPath() }
                            .disabled(vaultPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    HStack {
                        Text("知识项写入 Items，每日遇见记录写入 Daily。旧版 JSON 历史不会导入。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("在 Finder 中显示") { revealVaultFolder() }
                            .buttonStyle(.link)
                            .controlSize(.small)
                    }
                }
                .disabled(!saveHistory)
                if let vaultStatus { Text(vaultStatus).font(.caption).foregroundStyle(.secondary) }

                HStack {
                    Button("从 Vault 重新载入") {
                        state.reloadHistory()
                        vaultStatus = "已载入 \(state.history.count) 个知识项"
                    }
                    Button("清空 Vault 历史", role: .destructive) {
                        showingClearHistoryConfirmation = true
                    }
                        .disabled(state.history.isEmpty)
                }
                .disabled(!saveHistory)

                Button("清空翻译缓存") { Task { await AnalysisCache.shared.clear() } }
                Text("翻译内容会发送至配置的模型服务；分析缓存仅保存在本机，保留 7 天、最多 200 项。").font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            vaultPath = HistoryStore.configuredPath
            hotKeyShortcut = HotKeyPreferences.current
            do { apiKey = try APIKeyStore.read() }
            catch { connectionStatus = error.localizedDescription }
        }
        .formStyle(.grouped)
        .padding(10)
        .frame(width: 620, height: 700)
        .alert("清空 Vault 历史？", isPresented: $showingClearHistoryConfirmation) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) { state.clearHistory() }
        } message: {
            Text("LingoPane 创建的知识项与每日日志将移到废纸篓，包括其中的“我的笔记”内容。")
        }
    }

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
