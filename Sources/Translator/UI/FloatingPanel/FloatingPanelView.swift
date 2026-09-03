import SwiftUI

/// 悬浮毛玻璃 Panel 核心视图（严格 1:1 复刻 HTML 原型 Liquid Glass 质感与交互体系）
public struct FloatingPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var state: AppState
    let onClose: () -> Void

    @State private var isShowingDeepAnalysis: Bool = false

    public init(state: AppState, onClose: @escaping () -> Void) {
        self.state = state
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 1. 顶栏：拖拽手柄、语言药丸徽标与右上角轻量控制按钮
                headerBar

                // 2. 核心内容呈现区（最大高度 480px，内部平滑滚动，间距 13px）
                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
                        contentBody
                    }
                    .padding(16)
                }
            }

            // 3. 悬浮 Toast 微气泡
            if let toast = state.toastMessage {
                VStack {
                    Spacer()
                    ToastCapsuleView(message: toast)
                        .padding(.bottom, 16)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                }
                .animation(.spring(response: 0.24, dampingFraction: 0.75), value: state.toastMessage)
            }
        }
        .frame(width: 420)
        .frame(minHeight: 220, maxHeight: 520)
        .liquidGlass(cornerRadius: 22)
    }

    // MARK: - 1. 顶栏 (panel-drag-handle)
    private var headerBar: some View {
        HStack {
            // 语言徽标 (lang-badge: English → 简体中文 ▾)
            HStack(spacing: 4) {
                Text(langBadgeTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color(red: 44/255, green: 44/255, blue: 46/255))

                Text("▾")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.55))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.8), lineWidth: 0.5)
            }

            Spacer()

            // 右侧轻量操作按键组 (panel-icon-btn: 🔊, ⚙, ✕)
            HStack(spacing: 4) {
                // 朗读按键
                let speakText = currentSpeakText
                let isSpeaking = SpeechService.shared.isSpeaking(text: speakText)
                Button {
                    if !speakText.isEmpty {
                        SpeechService.shared.speak(speakText, language: currentSpeakLocale)
                    }
                } label: {
                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.system(size: 12))
                        .foregroundStyle(isSpeaking ? Color(red: 10/255, green: 132/255, blue: 255/255) : Color.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .symbolEffect(.bounce, value: isSpeaking)
                }
                .buttonStyle(PlainHoverButtonStyle())
                .help("朗读原句 / 译文")

                // 设置按键
                Button {
                    state.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainHoverButtonStyle())
                .help("偏好设置...")

                // 关闭按键
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainHoverButtonStyle())
                .help("关闭 (Esc)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(colorScheme == .dark ? 0.15 : 0.40)
        }
    }

    private var langBadgeTitle: String {
        if let res = state.currentPRDResult {
            if res.source.language == .en {
                return "English → 简体中文"
            } else {
                return "中文 → English"
            }
        }
        return "AI 翻译与语法助手"
    }

    private var currentSpeakText: String {
        if let res = state.currentPRDResult {
            return res.pronunciation?.speakText ?? res.source.text
        }
        return state.inputText
    }

    private var currentSpeakLocale: String? {
        state.currentPRDResult?.pronunciation?.locale
    }

    // MARK: - 2. 主体插槽渲染
    @ViewBuilder
    private var contentBody: some View {
        if !state.isAccessibilityGranted && state.inputText.isEmpty {
            permissionGuideView
        } else if case .loading(let query) = state.currentResult {
            loadingShimmerView(query: query)
        } else if case .error(let msg) = state.currentResult {
            errorView(message: msg)
        } else if let result = state.currentPRDResult {
            switch result.source.contentType {
            case .word:
                wordScenarioView(result: result)
            case .sentence:
                if result.source.language == .zh {
                    chineseScenarioView(result: result)
                } else {
                    sentenceScenarioView(result: result)
                }
            case .phrase:
                if result.source.language == .zh {
                    chineseScenarioView(result: result)
                } else {
                    sentenceScenarioView(result: result)
                }
            }
        } else {
            emptyInputScenarioView
        }
    }

    // MARK: - 3. 长难句拓扑场景 (Sentence Scenario)
    @ViewBuilder
    private func sentenceScenarioView(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            // 3.1 原文与语法标注 (syntax-wrapper)
            if let sentenceData = result.sentenceAnalysis {
                InteractiveGrammarTextView(
                    originalText: result.source.text,
                    chunks: sentenceData.chunks,
                    clauses: sentenceData.clauses
                )
            } else {
                Text(result.source.text)
                    .font(.system(size: 16, weight: .semibold))
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }

            // 3.2 翻译卡片 (result-glass-card)
            VStack(alignment: .leading, spacing: 8) {
                Text(result.translation.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color(red: 28/255, green: 28/255, blue: 30/255))
                    .lineSpacing(4)
                    .textSelection(.enabled)

                HStack {
                    Spacer()
                    PillButton(title: "📋 复制译文") {
                        state.copyToClipboard(result.translation.text)
                    }
                }
            }
            .padding(14)
            .concentricGlassCard(cornerRadius: 14)

            // 3.3 句子主干与深层结构可折叠卡片 (collapsible-box)
            if let sentenceData = result.sentenceAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isShowingDeepAnalysis.toggle()
                            if isShowingDeepAnalysis && sentenceData.clauses == nil {
                                state.performDeepAnalyze()
                            }
                        }
                    } label: {
                        HStack {
                            HStack(spacing: 5) {
                                Text("📐")
                                    .font(.system(size: 11))
                                Text("句子主干与深层结构")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 58/255, green: 58/255, blue: 60/255))
                            }

                            Spacer()

                            Text(isShowingDeepAnalysis ? "收起解析 ▴" : "展开详细解析 ▾")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(red: 0/255, green: 113/255, blue: 227/255))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 展开的内容
                    if isShowingDeepAnalysis {
                        VStack(alignment: .leading, spacing: 10) {
                            Divider().opacity(0.12)

                            // 句子骨干抽取 (Skeleton)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("句子骨干抽取 (Skeleton)：")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondary)

                                Text(sentenceData.skeleton)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 17/255, green: 17/255, blue: 17/255))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.70))
                                    }
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .fill(Color(red: 0/255, green: 113/255, blue: 227/255))
                                            .frame(width: 3.5)
                                    }
                            }

                            // 成分拆解与关系
                            VStack(alignment: .leading, spacing: 5) {
                                Text("成分拆解与关系：")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.secondary)

                                ForEach(sentenceData.chunks) { chunk in
                                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                                        Text("•")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.secondary)
                                        Text(chunk.text)
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundStyle(colorScheme == .dark ? .white : Color(red: 17/255, green: 17/255, blue: 17/255))
                                        Text(":")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(Color.secondary)
                                        Text(chunk.explanation ?? chunk.label)
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 55/255, green: 55/255, blue: 60/255))
                                    }
                                }

                                if let points = sentenceData.grammarPoints {
                                    ForEach(points) { point in
                                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                                            Text("•")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.secondary)
                                            Text(point.name)
                                                .font(.system(size: 11.5, weight: .bold))
                                                .foregroundStyle(Color(red: 255/255, green: 159/255, blue: 10/255))
                                            Text(":")
                                                .font(.system(size: 11.5))
                                                .foregroundStyle(Color.secondary)
                                            Text(point.explanation)
                                                .font(.system(size: 11.5))
                                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 55/255, green: 55/255, blue: 60/255))
                                        }
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(12)
                .concentricGlassCard(cornerRadius: 12, opacity: 0.38)
            }
        }
    }

    // MARK: - 4. 英文单词场景 (Word Scenario)
    @ViewBuilder
    private func wordScenarioView(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            // 4.1 单词标题与音标 (syntax-wrapper)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(result.wordAnalysis?.lemma ?? result.source.text)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white : Color(red: 17/255, green: 24/255, blue: 39/255))

                    Spacer()

                    if let ipa = result.pronunciation?.ipa, !ipa.isEmpty {
                        Text(ipa)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                    }
                }

                if let pos = result.wordAnalysis?.partOfSpeech, !pos.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(pos, id: \.self) { p in
                            Text(p)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color(red: 55/255, green: 65/255, blue: 81/255))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.05))
                                }
                        }
                    }
                }
            }

            // 4.2 释义结果卡片 (result-glass-card)
            VStack(alignment: .leading, spacing: 8) {
                Text(result.translation.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 28/255, green: 28/255, blue: 30/255))
                    .lineSpacing(3)
                    .textSelection(.enabled)

                HStack {
                    Spacer()
                    PillButton(title: "复制单词") {
                        state.copyToClipboard(result.source.text)
                    }
                    PillButton(title: "复制释义") {
                        state.copyToClipboard(result.translation.text)
                    }
                }
            }
            .padding(14)
            .concentricGlassCard(cornerRadius: 14)

            // 4.3 工程搭配与经典例句 (collapsible-box open)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Text("💡")
                        .font(.system(size: 11))
                    Text("工程搭配与经典例句")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 58/255, green: 58/255, blue: 60/255))
                }

                Divider().opacity(0.12)

                // 搭配列表
                if let collocations = result.wordAnalysis?.collocations, !collocations.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(collocations) { c in
                            HStack(spacing: 6) {
                                Text(c.text)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 17/255, green: 17/255, blue: 17/255))
                                Text("—")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                                Text(c.meaning)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }

                // 例句卡片
                if let examples = result.wordAnalysis?.examples, !examples.isEmpty {
                    ForEach(examples) { ex in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\"\(ex.source)\"")
                                .font(.system(size: 12, weight: .regular))
                                .italic()
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color(red: 31/255, green: 41/255, blue: 55/255))
                            Text(ex.translation)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.5))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.8), lineWidth: 0.6)
                        }
                    }
                }
            }
            .padding(12)
            .concentricGlassCard(cornerRadius: 12, opacity: 0.38)
        }
    }

    // MARK: - 5. 中文转地道英文场景 (Chinese Scenario)
    @ViewBuilder
    private func chineseScenarioView(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            // 5.1 原文
            Text(result.source.text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? .white : Color(red: 31/255, green: 41/255, blue: 55/255))
                .padding(.vertical, 2)
                .textSelection(.enabled)

            // 5.2 核心地道英文表达卡片
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(result.translation.text)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 10/255, green: 132/255, blue: 255/255))
                        .lineSpacing(3)
                        .textSelection(.enabled)

                    Spacer()

                    Button {
                        SpeechService.shared.speak(result.translation.text, language: "en-US")
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 10/255, green: 132/255, blue: 255/255))
                    }
                    .buttonStyle(PlainHoverButtonStyle())
                }

                HStack {
                    Spacer()
                    PillButton(title: "📋 复制地道表达") {
                        state.copyToClipboard(result.translation.text)
                    }
                }
            }
            .padding(14)
            .concentricGlassCard(cornerRadius: 14)

            // 5.3 语境对比与替代表达
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Text("✨")
                        .font(.system(size: 11))
                    Text("语境对比与替代表达")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 58/255, green: 58/255, blue: 60/255))
                }

                Divider().opacity(0.12)

                VStack(alignment: .leading, spacing: 6) {
                    if let alts = result.translation.alternatives, !alts.isEmpty {
                        ForEach(Array(alts.enumerated()), id: \.offset) { index, alt in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(index + 1). \(alt)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 17/255, green: 24/255, blue: 39/255))

                                Text("更加正式，适用于技术方案 RFC 文档或向管理层汇报。")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }

                    // 表达剖析
                    VStack(alignment: .leading, spacing: 3) {
                        Divider().opacity(0.10)
                        HStack(alignment: .top, spacing: 4) {
                            Text("表达剖析：")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(colorScheme == .dark ? .white : Color(red: 31/255, green: 41/255, blue: 55/255))
                            Text("技术语境下的“兜底方案”对应 fallback；“先…”在此语境自然采用 for now，较 firstly 更显地道。")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                                .lineSpacing(2)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .concentricGlassCard(cornerRadius: 12, opacity: 0.38)
        }
    }

    // MARK: - 6. 未选中文本场景 (Empty Selection Scenario)
    private var emptyInputScenarioView: some View {
        VStack(spacing: 8) {
            Text("📭")
                .font(.system(size: 32))

            Text("未检测到选中文本")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? .white : Color(red: 17/255, green: 24/255, blue: 39/255))

            Text("请在任意应用中选中文本后按 ⌥ Space，或直接在此处输入进行中英互译：")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)

            HStack {
                TextField("输入或粘贴长句/单词...", text: $state.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        state.processInput(state.inputText)
                    }

                Button("立即查询") {
                    state.processInput(state.inputText)
                }
                .buttonStyle(PillActionButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .concentricGlassCard(cornerRadius: 12, opacity: 0.70)
            .padding(.top, 6)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 骨架屏加载与错误状态
    private func loadingShimmerView(query: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在智能分析 “\(query)”...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.12))
                .frame(height: 70)
                .liquidShimmer()

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .frame(height: 50)
                .liquidShimmer()
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("分析暂不可用")
                .font(.system(size: 13, weight: .bold))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                state.processInput(state.inputText)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    private var permissionGuideView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor)

            Text("需要开启辅助功能权限")
                .font(.system(size: 14, weight: .bold))

            Text("为了在其他 App 中通过 ⌥ Space 读取划选文字，请在系统设置中允许本应用访问。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("打开系统设置") {
                SelectionProvider.shared.promptForAccessibilityPermissions()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - HTML 原型同款微组件 (pill-btn, toast-box)

/// 复制药丸轻按钮 (.pill-btn)
private struct PillButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0/255, green: 113/255, blue: 227/255))
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(red: 0/255, green: 113/255, blue: 227/255).opacity(isHovered ? 0.18 : 0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color(red: 0/255, green: 113/255, blue: 227/255).opacity(0.20), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isHovered)
        .onHover { h in isHovered = h }
    }
}

/// 蓝色主操作药丸按钮
private struct PillActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4.5)
            .background {
                Capsule().fill(Color(red: 0/255, green: 113/255, blue: 227/255))
            }
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

/// 鼠标微悬浮纯文本按钮样式
private struct PlainHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.black.opacity(0.12) : Color.clear)
            }
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

/// 严格还原 HTML 原型 .toast-box
private struct ToastCapsuleView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Color(red: 18/255, green: 19/255, blue: 26/255).opacity(0.88))
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.28), radius: 10, y: 4)
    }
}
