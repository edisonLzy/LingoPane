import SwiftUI

/// 主界面视图（提供与 HTML 原型 100% 对齐的场景控制器与 Liquid Glass 体验）
public struct MainTranslatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var state: AppState

    @State private var selectedScenario: String = "sentence"

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        ZStack {
            // 背景渐变微光与物理透镜模糊底色 (模拟 macOS 桌面流体微光)
            backgroundGlow

            VStack(spacing: 16) {
                // 1. 顶部场景快速切换导航栏 (完全还原 HTML 原型 .scenario-nav)
                scenarioNavBar
                    .padding(.top, 14)

                // 2. 核心 Liquid Glass 悬浮面板呈现
                FloatingPanelView(state: state) {
                    // standalone 模式下无需强行关闭窗口
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.16),
                    radius: 28,
                    x: 0,
                    y: 14
                )

                // 3. 底部提示栏 (对应 HTML 原型底部使用提示)
                HStack(spacing: 6) {
                    Text("💡")
                        .font(.system(size: 11))
                    Text("提示：在任意 App 中选中文本后按")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Text("⌥ Space")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.white)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
                        }
                    Text("可就近弹出浮窗")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.45))
                }
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.6), lineWidth: 0.6)
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
        }
        .frame(minWidth: 460, maxWidth: 500, minHeight: 560, maxHeight: 660)
        .sheet(isPresented: $state.showSettings) {
            SettingsView(settings: state.settings) {
                state.reloadService()
            }
        }
        .onAppear {
            if state.inputText.isEmpty {
                loadScenario("sentence")
            }
        }
    }

    // MARK: - 场景切换导航 (scenario-nav)
    private var scenarioNavBar: some View {
        HStack(spacing: 6) {
            ScenarioButton(
                title: "长难句拓扑",
                isActive: selectedScenario == "sentence"
            ) {
                loadScenario("sentence")
            }

            ScenarioButton(
                title: "英文单词",
                isActive: selectedScenario == "word"
            ) {
                loadScenario("word")
            }

            ScenarioButton(
                title: "中文转地道英文",
                isActive: selectedScenario == "chinese"
            ) {
                loadScenario("chinese")
            }

            ScenarioButton(
                title: "未选中文本",
                isActive: selectedScenario == "empty"
            ) {
                loadScenario("empty")
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.35))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.6), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }

    private func loadScenario(_ type: String) {
        selectedScenario = type
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            switch type {
            case "sentence":
                state.loadPreset("The feature that we discussed yesterday has been implemented.")
            case "word":
                state.loadPreset("architecture")
            case "chinese":
                state.loadPreset("这个方案可以先作为一个兜底方案。")
            case "empty":
                state.inputText = ""
                state.currentResult = .idle
                state.currentPRDResult = nil
            default:
                break
            }
        }
    }

    private var backgroundGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 118/255, green: 153/255, blue: 255/255).opacity(colorScheme == .dark ? 0.18 : 0.12),
                    Color(red: 255/255, green: 126/255, blue: 167/255).opacity(colorScheme == .dark ? 0.10 : 0.08),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
    }
}

/// 场景按钮组件 (.scenario-btn)
private struct ScenarioButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? (colorScheme == .dark ? Color.black : Color(red: 17/255, green: 17/255, blue: 17/255))
                        : (colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 35/255, green: 35/255, blue: 40/255))
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.92) : Color.white.opacity(0.95))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
