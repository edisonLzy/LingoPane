import SwiftUI

/// 设置面板视图（配置 MiniMax API Key、模型、自定义 Host）
public struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @Bindable var settings: SettingsManager
    let onReload: () -> Void

    @State private var isTesting = false
    @State private var testResult: String? = nil

    public init(settings: SettingsManager, onReload: @escaping () -> Void) {
        self.settings = settings
        self.onReload = onReload
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 顶栏
            HStack {
                Text("设置与模型配置")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider().opacity(0.2)

            // MiniMax / OpenAI 协议配置
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MiniMax API Key")
                        .font(.system(size: 12, weight: .semibold))

                    SecureField("输入你的 MiniMax API Key (如 ey...)", text: $settings.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                    Text("若未填入 API Key，应用将无缝使用内置高质量离线演示数据。")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Host")
                        .font(.system(size: 12, weight: .semibold))

                    TextField("api.minimax.cn", text: $settings.host)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                    Text("国内为 api.minimax.cn，海外为 api.minimax.chat。亦可指向任何 OpenAI 兼容服务器。")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("模型 (Model)")
                        .font(.system(size: 12, weight: .semibold))

                    TextField("MiniMax-M3", text: $settings.model)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                    HStack(spacing: 8) {
                        QuickModelChip(title: "MiniMax-M3", current: $settings.model)
                        QuickModelChip(title: "MiniMax-Text-01", current: $settings.model)
                        QuickModelChip(title: "gpt-4o-mini", current: $settings.model)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .concentricGlassCard()

            // 测试连通性与保存
            HStack {
                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 4) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "network")
                        }
                        Text(isTesting ? "测试中..." : "测试 API 连接")
                    }
                }
                .disabled(isTesting || !settings.hasValidAPIKey)

                Spacer()

                Button("完成") {
                    onReload()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            if let result = testResult {
                Text(result)
                    .font(.system(size: 11))
                    .foregroundStyle(result.contains("成功") ? Color.green : Color.red)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(width: 420)
        .liquidGlass()
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let config = OpenAIConfiguration(
            token: settings.apiKey,
            host: settings.host,
            basePath: settings.basePath
        )
        let client = OpenAIClient(configuration: config)

        Task {
            do {
                let req = ChatCompletionRequest(
                    model: settings.model,
                    messages: [
                        ChatMessage(role: "user", content: "Hello, reply with 1 word: OK")
                    ],
                    responseFormat: nil
                )
                let resp = try await client.chats(query: req)
                let reply = resp.choices.first?.message.content ?? ""
                await MainActor.run {
                    self.isTesting = false
                    self.testResult = "连接成功！模型响应: \(reply.prefix(30))"
                }
            } catch {
                await MainActor.run {
                    self.isTesting = false
                    self.testResult = "连接失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct QuickModelChip: View {
    let title: String
    @Binding var current: String

    var body: some View {
        Button {
            current = title
        } label: {
            Text(title)
                .font(.system(size: 10, weight: current == title ? .bold : .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    Capsule()
                        .fill(current == title ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                }
        }
        .buttonStyle(.plain)
    }
}
