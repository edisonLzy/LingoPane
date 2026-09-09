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
    @AppStorage("historyRetention") private var historyRetention = 90
    @State private var apiKey = ""
    @State private var connectionStatus: String?
    @State private var testing = false

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        Form {
            Section("通用") {
                Toggle("登录时启动", isOn: Binding(get: { loginItem.enabled }, set: { loginItem.setEnabled($0) }))
                if let message = loginItem.message { Text(message).font(.caption) }
                LabeledContent("全局快捷键") { Text("⌥ Space").monospaced() }
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
                    Text("本地 Ollama 无需 API Key；默认翻译关闭思考，展开学习分析时启用。")
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

            Section("隐私") {
                Toggle("保存本地历史", isOn: $saveHistory)
                Picker("保留期限", selection: $historyRetention) {
                    Text("30 天").tag(30)
                    Text("90 天").tag(90)
                    Text("永久").tag(0)
                }
                .disabled(!saveHistory)
                .onChange(of: historyRetention) { _, _ in state.pruneHistory() }
                Button("清空翻译缓存") { Task { await AnalysisCache.shared.clear() } }
                Text("翻译内容会发送至配置的模型服务；分析缓存仅保存在本机，保留 7 天、最多 200 项。").font(.caption).foregroundStyle(.secondary)
                Button("清空历史", role: .destructive) { state.clearHistory() }
                    .disabled(state.history.isEmpty)
            }
        }
        .onAppear {
            do { apiKey = try APIKeyStore.read() }
            catch { connectionStatus = error.localizedDescription }
        }
        .formStyle(.grouped)
        .padding(10)
        .frame(width: 520, height: 590)
    }
}
