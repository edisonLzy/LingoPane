import SwiftUI

/// 悬浮毛玻璃 Panel 核心视图（严格遵循 PRD 第 6 节与翻译优先原则）
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
                // 顶栏：语种指示与关闭按钮
                headerBar

                // 核心内容展示区（最大高度 520px，内部平滑滚动）
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        contentBody
                    }
                    .padding(14)
                }
            }

            // 悬浮 Toast 气泡
            if let toast = state.toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: toast)
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 420)
        .frame(minHeight: 240, maxHeight: 520)
        .liquidGlass(cornerRadius: 18)
    }

    // MARK: - 顶栏
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.16, green: 0.59, blue: 1.00))
                    .frame(width: 7, height: 7)

                if let res = state.currentPRDResult {
                    Text("\(res.source.language.title) → \(res.source.language == .en ? "中文" : "English")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("AI 翻译与语法理解")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("关闭浮窗 (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - 核心内容体
    @ViewBuilder
    private var contentBody: some View {
        if !state.isAccessibilityGranted && state.inputText.isEmpty {
            // 13.1 辅助功能权限指引
            permissionGuideView
        } else if case .loading(let query) = state.currentResult {
            // 骨架微光流体加载
            loadingView(query: query)
        } else if case .error(let msg) = state.currentResult {
            errorView(message: msg)
        } else if let result = state.currentPRDResult {
            // 按照语种和内容类型渲染
            mainResultView(result: result)
        } else {
            // 13.2 空选区手动输入兜底
            emptyInputFallbackView
        }
    }

    // MARK: - 主结果区 (PRD 2.1 翻译优先原则)
    @ViewBuilder
    private func mainResultView(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. 原文卡片 + 发音按键
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.source.text)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? .white : Color(red: 25/255, green: 25/255, blue: 30/255))
                        .lineSpacing(3)
                        .textSelection(.enabled)

                    if let ipa = result.pronunciation?.ipa, !ipa.isEmpty {
                        Text(ipa)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.accentColor.opacity(0.85))
                    }
                }

                Spacer()

                // 朗读原句按键
                let speakText = result.pronunciation?.speakText ?? result.source.text
                let isSpeaking = SpeechService.shared.isSpeaking(text: speakText)
                LiquidPillButton(
                    isActive: isSpeaking,
                    action: {
                        SpeechService.shared.speak(speakText, language: result.pronunciation?.locale)
                    }
                ) {
                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.bounce, value: isSpeaking)
                }
                .help("朗读发音")
            }
            .padding(12)
            .concentricGlassCard()

            // 2. 翻译卡片 + 一键复制 (PRD 2.1 核心首屏)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("翻译")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    Spacer()

                    LiquidPillButton(action: {
                        state.copyToClipboard(result.translation.text)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("复制")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                }

                Text(result.translation.text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 30/255, green: 30/255, blue: 35/255))
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
            .padding(12)
            .concentricGlassCard()

            // 3. 展开控制与详细解析 (PRD 2.1 语法、例句、搭配默认收起，用户主动点击后再展示)
            detailExpansionSection(result: result)
        }
    }

    // MARK: - 详细解析展开区 (单词模式 / 句子模式 / 中译英模式)
    @ViewBuilder
    private func detailExpansionSection(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 展开/收起按钮
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    isShowingDeepAnalysis.toggle()
                    if isShowingDeepAnalysis && result.sentenceAnalysis?.clauses == nil {
                        // 触发 Deep Analyze 按需请求
                        state.performDeepAnalyze()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isShowingDeepAnalysis ? "chevron.up.circle.fill" : "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)

                    Text(expansionButtonTitle(for: result.source.contentType))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 60/255, green: 60/255, blue: 65/255))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(isShowingDeepAnalysis ? 180 : 0))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isShowingDeepAnalysis {
                VStack(alignment: .leading, spacing: 10) {
                    if result.source.contentType == .word, let wordData = result.wordAnalysis {
                        // 单词详细：用法、搭配、例句
                        wordDetailsView(wordData: wordData)
                    } else if result.source.contentType == .sentence, let sentenceData = result.sentenceAnalysis {
                        // 句子详细：主干、彩线下划线与从句方框标注、语法点
                        sentenceDetailsView(sourceText: result.source.text, sentenceData: sentenceData)
                    }

                    // 备选自然表达 (适用于中译英或句子)
                    if let alts = result.translation.alternatives, !alts.isEmpty {
                        alternativesView(alternatives: alts, tone: result.translation.tone)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .concentricGlassCard()
    }

    private func expansionButtonTitle(for type: ContentType) -> String {
        switch type {
        case .word: return isShowingDeepAnalysis ? "收起搭配与例句" : "查看搭配和例句"
        case .sentence: return isShowingDeepAnalysis ? "收起句子结构解析" : "查看句子结构与语法"
        case .phrase: return isShowingDeepAnalysis ? "收起用法分析" : "查看用法说明"
        }
    }

    // MARK: - 单词详细内容
    private func wordDetailsView(wordData: WordAnalysisData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 词性
            HStack(spacing: 6) {
                ForEach(wordData.partOfSpeech, id: \.self) { pos in
                    Text(pos)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule().fill(Color.accentColor.opacity(0.15))
                        }
                }
            }

            // 释义与用法
            ForEach(wordData.meanings) { m in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle().fill(Color.secondary).frame(width: 4, height: 4)
                    Text(m.text)
                        .font(.system(size: 12))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                    if let usage = m.usage {
                        Text("(\(usage))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 搭配
            if let collocations = wordData.collocations, !collocations.isEmpty {
                Divider().opacity(0.15)
                Text("常见搭配")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)

                ForEach(collocations) { c in
                    HStack {
                        Text(c.text)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        Text(c.meaning)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 例句
            if let examples = wordData.examples, !examples.isEmpty {
                Divider().opacity(0.15)
                Text("语境例句")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)

                ForEach(examples) { ex in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.source)
                            .font(.system(size: 11, weight: .medium))
                        Text(ex.translation)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - 句子结构与语法详细
    private func sentenceDetailsView(sourceText: String, sentenceData: SentenceAnalysisData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // PRD 6.5: 句子主干
            VStack(alignment: .leading, spacing: 3) {
                Text("句子主干 (Skeleton)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                Text(sentenceData.skeleton)
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 20/255, green: 20/255, blue: 25/255))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.1))
                    }
            }

            // PRD 7 节：句子结构彩线与方框可视化交互
            VStack(alignment: .leading, spacing: 4) {
                Text("结构标注 (悬停或点击 Pin 固定说明)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)

                InteractiveGrammarTextView(
                    originalText: sourceText,
                    chunks: sentenceData.chunks,
                    clauses: sentenceData.clauses
                )
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                }
            }

            // 语法点与时态语态 (PRD 10.3)
            if let points = sentenceData.grammarPoints, !points.isEmpty {
                Divider().opacity(0.15)
                Text("语法点与时态")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)

                ForEach(points) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 1.00, green: 0.62, blue: 0.04))
                        Text(p.explanation)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 备选自然表达 (PRD 4 场景三)
    private func alternativesView(alternatives: [String], tone: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().opacity(0.15)
            HStack {
                Text("更自然的表达")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)

                if let tone = tone {
                    Text("(\(tone))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                }
            }

            ForEach(alternatives, id: \.self) { alt in
                HStack {
                    Text(alt)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    LiquidPillButton(action: {
                        state.copyToClipboard(alt)
                    }) {
                        Image(systemName: "doc.on.doc").font(.system(size: 9))
                    }
                }
                .padding(6)
                .background {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05))
                }
            }
        }
    }

    // MARK: - 辅助功能权限引导 (PRD 13.1)
    private var permissionGuideView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor)

            Text("需要开启辅助功能权限")
                .font(.system(size: 14, weight: .bold))

            Text("为了在其他 App (VS Code、Safari 等) 中通过 ⌥ Space 读取划选文字，请在系统设置中允许本应用访问。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button("打开系统设置") {
                SelectionProvider.shared.promptForAccessibilityPermissions()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 空选区手动输入兜底 (PRD 13.2)
    private var emptyInputFallbackView: some View {
        VStack(spacing: 12) {
            Text("未检测到选中文本")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("请在任意应用中选中文本并按 ⌥ Space，或直接在此输入：")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                TextField("输入单词或句子...", text: $state.inputText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        state.processInput(state.inputText)
                    }

                Button("翻译") {
                    state.processInput(state.inputText)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(8)
            .concentricGlassCard(cornerRadius: 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    private func loadingView(query: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在智能分析 “\(query)”...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .frame(height: 60)
                .liquidShimmer()
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("翻译暂时失败")
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
}
