import SwiftUI

/// 主翻译面板视图（Apple 官方 Liquid Glass 风格高品质原生交互）
public struct MainTranslatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var state: AppState

    @FocusState private var isInputFocused: Bool

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        ZStack {
            // 背景渐变微光与物理透镜模糊底色
            backgroundGlow

            VStack(spacing: 0) {
                // 顶部控制条：状态指示灯、标题、预设与设置
                headerBar

                // 输入区：自适应搜索框与快捷测试药丸
                inputSection
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()
                    .opacity(0.12)
                    .padding(.horizontal, 16)

                // 核心解析呈现面板（自适应切换 Word / Sentence / Chinese）
                ScrollView {
                    VStack(spacing: 12) {
                        contentBody
                            .id(state.currentResultID)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)),
                                removal: .opacity
                            ))
                    }
                    .padding(16)
                }
                .animation(.spring(response: 0.36, dampingFraction: 0.82), value: state.currentResultID)
            }

            // 悬浮 Toast 气泡
            if let toast = state.toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                        .padding(.bottom, 24)
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: state.toastMessage)
            }
        }
        .frame(minWidth: 430, maxWidth: 540, minHeight: 500, maxHeight: 680)
        .liquidGlass(cornerRadius: 22)
        .sheet(isPresented: $state.showSettings) {
            SettingsView(settings: state.settings) {
                state.reloadService()
            }
        }
        .onAppear {
            isInputFocused = true
            if state.inputText.isEmpty {
                state.loadPreset("symmetric")
            }
        }
    }

    // MARK: - 顶栏
    private var headerBar: some View {
        HStack(spacing: 8) {
            // 模式指示灯与标题
            HStack(spacing: 7) {
                Circle()
                    .fill(statusIndicatorColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusIndicatorColor.opacity(0.7), radius: 4)
                    .scaleEffect(state.currentResultID.starts(with: "loading") ? 1.3 : 1.0)
                    .animation(
                        state.currentResultID.starts(with: "loading")
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: state.currentResultID
                    )

                Text(panelTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 25/255, green: 25/255, blue: 30/255))
            }

            Spacer()

            // 快捷样本菜单
            Menu {
                Button("📖 单词: symmetric (对称的)") { state.loadPreset("symmetric") }
                Button("📖 单词: volcano (火山)") { state.loadPreset("volcano") }
                Button("📖 单词: deciduous (落叶性的)") { state.loadPreset("deciduous") }
                Divider()
                Button("🔍 句子: 火山锥体拔地而起 (cone)") {
                    state.loadPreset("The volcanic cone rises gracefully up to slightly more than 12,000 feet.")
                }
                Button("🔍 句子: 稀有日本鬣羚 (serow)") {
                    state.loadPreset("The Japanese serow is a rare and protected species of goat-antelope that roams secretively through dense forests.")
                }
                Divider()
                Button("🇨🇳 中文: 兜底方案 (双场景直出)") {
                    state.loadPreset("这个方案可以先作为一个兜底方案。")
                }
                Button("🇨🇳 中文: 富士山活火山") {
                    state.loadPreset("富士山是日本最著名的活火山。")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                    Text("预设")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4))
                }
            }
            .menuStyle(.borderlessButton)
            .help("快速预设测试示例")

            // 设置按钮
            LiquidPillButton(action: {
                state.showSettings = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
            .help("设置与 API 配置")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - 输入区
    private var inputSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isInputFocused ? Color.accentColor : Color.secondary)

                TextField("输入英文单词、长难句或中文自动解析...", text: $state.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .focused($isInputFocused)
                    .onSubmit {
                        state.processInput(state.inputText)
                    }

                if !state.inputText.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            state.inputText = ""
                            state.currentResult = .idle
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .concentricGlassCard(cornerRadius: 13, isHighlighted: isInputFocused)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isInputFocused)

            // 快捷快速预设药丸
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    SampleChip(title: "symmetric", text: "symmetric", state: state)
                    SampleChip(title: "volcano", text: "volcano", state: state)
                    SampleChip(title: "火山锥句法", text: "The volcanic cone rises gracefully up to slightly more than 12,000 feet.", state: state)
                    SampleChip(title: "鬣羚从句", text: "The Japanese serow is a rare and protected species of goat-antelope that roams secretively through dense forests.", state: state)
                    SampleChip(title: "兜底方案 (中译英)", text: "这个方案可以先作为一个兜底方案。", state: state)
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - 主内容区
    @ViewBuilder
    private var contentBody: some View {
        switch state.currentResult {
        case .idle:
            VStack(spacing: 10) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("输入英文单词、长难句或中文，智能自动解析")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)

        case .loading(let query):
            // 优雅的 Liquid Glass 骨架屏与微光流体扫描动画
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在智能分析 “\(query)”...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.top, 4)

                // 模拟骨架卡片 1
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3))
                        .frame(width: 140, height: 18)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2))
                        .frame(width: 220, height: 12)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .concentricGlassCard()
                .liquidShimmer()

                // 模拟骨架卡片 2
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2))
                        .frame(width: 180, height: 12)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .concentricGlassCard()
                .liquidShimmer()
            }
            .frame(maxWidth: .infinity, minHeight: 200)

        case .success:
            if state.currentPRDResult != nil {
                FloatingPanelView(state: state, onClose: {})
            }

        case .error(let errorMsg):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
                Text("分析发生异常")
                    .font(.system(size: 13, weight: .bold))
                Text(errorMsg)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    // MARK: - 辅助计算属性
    private var statusIndicatorColor: Color {
        switch state.currentResult {
        case .success:
            if let res = state.currentPRDResult {
                switch res.source.contentType {
                case .word: return Color(red: 0.16, green: 0.59, blue: 1.00)
                case .sentence: return Color(red: 1.00, green: 0.62, blue: 0.04)
                case .phrase: return Color(red: 0.19, green: 0.82, blue: 0.35)
                }
            }
            return Color.accentColor
        case .loading: return Color(red: 0.75, green: 0.35, blue: 0.95)
        case .error: return Color.red
        case .idle: return Color.secondary
        }
    }

    private var panelTitle: String {
        switch state.currentResult {
        case .success:
            if let res = state.currentPRDResult {
                switch res.source.contentType {
                case .word: return "单词释义"
                case .sentence: return "句子结构与翻译"
                case .phrase: return "短语表达"
                }
            }
            return "AI 翻译"
        case .loading: return "AI 深度解析中"
        case .error: return "分析失败"
        case .idle: return "AI 翻译"
        }
    }

    private var backgroundGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 41/255, green: 151/255, blue: 255/255).opacity(colorScheme == .dark ? 0.09 : 0.06),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )
        }
    }
}

private struct SampleChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let text: String
    let state: AppState

    @State private var isHovered = false

    var body: some View {
        Button {
            state.loadPreset(text)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(
                    isHovered
                        ? (colorScheme == .dark ? .white : .black)
                        : (colorScheme == .dark ? Color.white.opacity(0.75) : Color(red: 70/255, green: 70/255, blue: 75/255))
                )
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background {
                    Capsule()
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(isHovered ? 0.18 : 0.08)
                                : Color.white.opacity(isHovered ? 0.85 : 0.60)
                        )
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(isHovered ? 0.4 : 0.15), lineWidth: 0.6)
                        }
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isHovered)
        .onHover { h in
            isHovered = h
        }
    }
}
