import SwiftUI

public struct SettingsView: View {
    @ObservedObject var state: AppState
    @AppStorage("closeTemporaryOnBlur") private var closeTemporaryOnBlur = true
    @AppStorage("showSentenceSkeleton") private var showSentenceSkeleton = true
    @AppStorage("expandGrammarByDefault") private var expandGrammarByDefault = false
    @AppStorage("panelWidth") private var panelWidth = 400.0
    @AppStorage("speechLocale") private var speechLocale = "en-US"
    @AppStorage("provider") private var provider = "MiniMax"
    @AppStorage("model") private var model = "MiniMax-M2.1"
    @AppStorage("baseURL") private var baseURL = "https://api.minimax.chat/v1"
    @AppStorage("saveHistory") private var saveHistory = true
    @AppStorage("historyRetention") private var historyRetention = 90
    @State private var apiKey = ""
    @State private var connectionStatus: String?

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        Form {
            Section("通用") {
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
                    Text("OpenAI-compatible").tag("OpenAI-compatible")
                }
                TextField("模型", text: $model)
                TextField("Base URL", text: $baseURL)
                SecureField("API Key", text: $apiKey)
                HStack {
                    Button("测试连接") {
                        connectionStatus = apiKey.isEmpty ? "当前使用离线演示服务" : "连接配置已记录，网络服务待接入"
                    }
                    if let connectionStatus {
                        Text(connectionStatus).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("隐私") {
                Toggle("保存本地历史", isOn: $saveHistory)
                Picker("保留期限", selection: $historyRetention) {
                    Text("30 天").tag(30)
                    Text("90 天").tag(90)
                    Text("永久").tag(0)
                }
                .disabled(!saveHistory)
                Button("清空历史", role: .destructive) { state.clearHistory() }
                    .disabled(state.history.isEmpty)
            }
        }
        .formStyle(.grouped)
        .padding(10)
        .frame(width: 520, height: 590)
    }
}
