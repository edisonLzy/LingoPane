import SwiftUI

public struct PanelView: View {
    @ObservedObject var model: PanelViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    public init(model: PanelViewModel) {
        self.model = model
    }

    private var phaseKey: String {
        switch model.phase {
        case .loading:
            "loading"
        case .streaming:
            "streaming"
        case .failed(let failure):
            "failed:" + (failure.errorDescription ?? "unknown")
        case .ready(let result):
            "ready:" + result.id.uuidString
        }
    }

    public var body: some View {
        ZStack {
            PanelBackground()
            VStack(spacing: 0) {
                header
                if !model.isCollapsed {
                Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
                ScrollView {
                    VStack(spacing: 0) {
                        sourceSection
                        Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
                        phaseContent
                        if let notice = model.notice {
                            PanelSection { Text(notice).foregroundStyle(.orange) }
                        }
                        if model.isExpanded {
                            if model.deepLoading {
                                PanelSection { ProgressView("正在分析学习详情…") }
                            } else if let error = model.deepFailure {
                                PanelSection {
                                    Text(error).foregroundStyle(.orange)
                                    Button("重试学习分析") { model.deepAction?() }
                                }
                            }
                        }
                    }
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: PanelContentHeight.self, value: proxy.size.height)
                    })
                }
                .scrollIndicators(.never)
                footer
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LingoPalette.cornerRadius, style: .continuous))
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.975, anchor: .top)
        .environment(\.colorScheme, .dark)
        .tint(LingoPalette.accent)
        .foregroundStyle(LingoPalette.text)
        .font(.system(size: 13))
        .padding(18)
        .animation(reduceMotion ? nil : LingoMotion.standard, value: model.activeAnnotationID)
        .animation(reduceMotion ? nil : LingoMotion.standard, value: phaseKey)
        .task {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(LingoMotion.reveal) { hasAppeared = true }
            }
        }
        .onPreferenceChange(PanelContentHeight.self) { height in
            Task { @MainActor in model.resizeAction?(height + 110) }
        }
        .onChange(of: model.isCollapsed) { _, collapsed in
            model.resizeAction?(collapsed ? 78 : 400)
        }
        .onChange(of: model.isExpanded) { _, expanded in
            if expanded { model.deepAction?() }
            else { model.resetAnnotations() }
        }
        .onExitCommand { model.handleEscape() }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Menu {
                Button("中文内容") { model.switchKindAction?(.chinese) }
                Button("英文单词/短语") { model.switchKindAction?(.word) }
                Button("英文句子") { model.switchKindAction?(.sentence) }
            } label: {
                HStack(spacing: 5) {
                    Text("\(model.classification.language.title) · \(model.classification.kind.shortTitle)")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(LingoPalette.text)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("切换内容类型")

            Spacer()

            if model.isPinned {
                LingoIconButton(systemName: model.isCollapsed ? "chevron.down" : "chevron.up",
                    label: model.isCollapsed ? "展开 Panel" : "折叠 Panel") { model.isCollapsed.toggle() }
            }
            LingoIconButton(
                systemName: model.isPinned ? "pin.fill" : "pin",
                label: model.isPinned ? "取消固定 Panel" : "固定 Panel"
            ) { model.pinAction?() }

            Menu {
                Button("重新生成", systemImage: "arrow.clockwise") { model.retryAction?() }
                Divider()
                Button("复制原文", systemImage: "doc.on.doc") { AppState.shared.copy(model.source) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 27, height: 25)
                    .foregroundStyle(LingoPalette.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("更多操作")

            LingoIconButton(systemName: "xmark", label: "关闭 Panel") { model.closeAction?() }
        }
        .padding(.leading, 15)
        .padding(.trailing, 8)
        .frame(height: 42)
    }

    private var sourceSection: some View {
        PanelSection(model.classification.language == .chinese ? "原文" : "原句") {
            HStack(alignment: .top, spacing: 10) {
                AnnotatedSentenceView(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                if model.classification.language == .english {
                    LingoIconButton(systemName: "play.fill", label: "播放英文原文") {
                        SpeechService.shared.toggle(model.source)
                    }
                }
                LingoIconButton(systemName: "doc.on.doc", label: "复制原文") {
                    AppState.shared.copy(model.source)
                }
            }
            if model.isExpanded,
               let annotation = model.result?.annotations.first(where: { $0.id == model.activeAnnotationID && $0.isValid(in: model.source) }) {
                AnnotationCard(annotation: annotation, pinned: model.pinnedAnnotationID == annotation.id)
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .loading:
            LoadingResultView(message: model.isReasoning ? "模型正在思考…" : "正在生成主译文…")
                .transition(.opacity)
        case .failed(let failure):
            FailureResultView(failure: failure, retry: model.retryAction)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .streaming(let result), .ready(let result):
            switch result.kind {
            case .chinese:
                ChineseResultView(result: result, model: model)
            case .word:
                WordResultView(result: result, model: model)
            case .sentence:
                SentenceResultView(result: result, model: model)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(model.deepReady ? "学习分析已完成" : "翻译与学习")
            Spacer()
            Text("LingoPane")
        }
        .font(.system(size: 10))
        .foregroundStyle(LingoPalette.tertiary)
        .padding(.horizontal, 15)
        .frame(height: 31)
        .overlay(alignment: .top) { Rectangle().fill(LingoPalette.divider).frame(height: 0.5) }
    }
}

private struct LoadingResultView: View {
    let message: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        PanelSection("基础分析中") {
            VStack(alignment: .leading, spacing: 9) {
                skeleton(width: 240, opacity: 0.13)
                skeleton(width: 190, opacity: 0.10)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(LingoPalette.secondary)
            }
            .padding(.vertical, 3)
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }

    private func skeleton(width: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: width, height: 12)
            .overlay {
                if !reduceMotion {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.16), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 70)
                    .offset(x: shimmerOffset * (width + 70))
                }
            }
            .clipShape(Capsule())
    }
}

private struct FailureResultView: View {
    let failure: PanelFailure
    let retry: (() -> Void)?

    var body: some View {
        PanelSection {
            VStack(alignment: .leading, spacing: 10) {
                Label(failure.errorDescription ?? "发生错误", systemImage: iconName)
                    .font(.system(size: 13, weight: .semibold))
                Text(explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(LingoPalette.secondary)
                HStack {
                    if failure == .accessibilityPermission {
                        Button("打开系统设置") { SelectionProvider.shared.openAccessibilitySettings() }
                    } else if retry != nil {
                        Button("重试") { retry?() }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 5)
        }
    }

    private var iconName: String {
        failure == .accessibilityPermission ? "hand.raised.fill" : "exclamationmark.triangle.fill"
    }

    private var explanation: String {
        switch failure {
        case .accessibilityPermission: "授权后，LingoPane 才能读取其他 App 中当前选中的文字。"
        case .networkTimeout: "原文仍然保留，可以稍后重试。"
        case .authentication: "请在设置中检查模型服务和 API Key。"
        case .overlong: "不会自动截断原文，请缩短后重试。"
        case .grammarUnavailable: "基础翻译仍然可用，可以单独重试句子结构。"
        case .noSelection: "请选中文字，或从菜单栏手动输入。"
        case .message(let message): message
        }
    }
}

private struct PrimaryResultBlock: View {
    let title: String
    let text: String
    let speakable: Bool

    var body: some View {
        PanelSection(title) {
            HStack(alignment: .top, spacing: 8) {
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .offset(y: 4)))
                if speakable {
                    LingoIconButton(systemName: "play.fill", label: "播放英文结果") {
                        SpeechService.shared.toggle(text)
                    }
                }
                LingoIconButton(systemName: "doc.on.doc", label: "复制结果") {
                    AppState.shared.copy(text)
                }
            }
        }
    }
}

private struct DisclosureRow: View {
    let title: String
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if isExpanded {
                // Remove detail content before the panel frame contracts. Keeping the
                // outgoing view in an animated transition makes it overlap the rows above.
                isExpanded = false
            } else {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    isExpanded = true
                }
            }
        } label: {
            HStack {
                Text(isExpanded ? "收起\(title)" : "查看\(title)")
                Spacer()
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(LingoPalette.text)
            .padding(.horizontal, 15)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Rectangle().fill(LingoPalette.divider).frame(height: 0.5) }
    }
}

private struct ChineseResultView: View {
    let result: TranslationResult
    @ObservedObject var model: PanelViewModel

    private var activeText: String {
        guard let selected = model.selectedAlternativeID,
              let alternative = result.alternatives.first(where: { $0.id == selected }) else {
            return result.primaryResult
        }
        return alternative.text
    }

    var body: some View {
        PanelSection {
            Picker("表达场景", selection: Binding(get: { model.scene }, set: { model.sceneAction?($0) })) {
                ForEach(ExpressionScene.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
        PrimaryResultBlock(title: "自然表达", text: activeText, speakable: true)
        DisclosureRow(title: "其他表达与说明", isExpanded: $model.isExpanded)
        if model.isExpanded {
            VStack(spacing: 0) {
                PanelSection("替代表达") {
                    VStack(spacing: 7) {
                        ForEach(result.alternatives) { alternative in
                            Button {
                                model.selectedAlternativeID = alternative.id
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(alternative.label)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(LingoPalette.accent)
                                        Spacer()
                                        if model.selectedAlternativeID == alternative.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                    Text(alternative.text).font(.system(size: 13, weight: .medium))
                                    Text(alternative.note).font(.system(size: 10)).foregroundStyle(LingoPalette.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(9)
                                .background(LingoPalette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                detailLists(result: result)
            }
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .identity
                )
            )
        }
    }

    @ViewBuilder
    private func detailLists(result: TranslationResult) -> some View {
        if !result.expressionNotes.isEmpty {
            PanelSection("表达说明") {
                ForEach(Array(result.expressionNotes.prefix(3)), id: \.self) { Text($0) }
            }
        }
        if !result.keywordMappings.isEmpty {
            Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
            PanelSection("关键词映射") {
                ForEach(result.keywordMappings.prefix(3)) { mapping in
                    HStack {
                        Text(mapping.source).foregroundStyle(LingoPalette.secondary)
                        Image(systemName: "arrow.right").foregroundStyle(LingoPalette.tertiary)
                        Text(mapping.target).fontWeight(.medium)
                    }
                }
            }
        }
        if let example = result.examples.first {
            Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
            PanelSection("双语例句") {
                Text(example.english).fontWeight(.medium)
                Text(example.chinese).foregroundStyle(LingoPalette.secondary)
            }
        }
    }
}

private struct WordResultView: View {
    let result: TranslationResult
    @ObservedObject var model: PanelViewModel

    var body: some View {
        if let ipa = result.ipa {
            PanelSection { Text(ipa).foregroundStyle(LingoPalette.secondary) }
        }
        PanelSection("核心释义") {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(result.primaryResult)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LingoIconButton(systemName: "doc.on.doc", label: "复制释义") {
                        AppState.shared.copy(result.primaryResult)
                    }
                }
                ForEach(result.meanings.prefix(3)) { meaning in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(meaning.partOfSpeech)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(LingoPalette.accent)
                        Text(meaning.meaning)
                    }
                }
                if let context = result.contextMeaning {
                    Text(context).font(.system(size: 10)).foregroundStyle(LingoPalette.secondary)
                }
            }
        }
        DisclosureRow(title: "搭配、词形与例句", isExpanded: $model.isExpanded)
        if model.isExpanded {
            VStack(spacing: 0) {
                if !result.collocations.isEmpty {
                    PanelSection("常见搭配") {
                        ForEach(result.collocations.prefix(3)) { item in
                            HStack {
                                Text(item.phrase).fontWeight(.medium)
                                Spacer()
                                Text(item.meaning).foregroundStyle(LingoPalette.secondary)
                            }
                        }
                    }
                }
                if let words = result.confusingWords, !words.isEmpty {
                    PanelSection("易混词") {
                        ForEach(words.prefix(2)) { word in
                            Text(word.phrase).fontWeight(.medium)
                            Text(word.meaning).foregroundStyle(LingoPalette.secondary)
                        }
                    }
                }
                if !result.wordForms.isEmpty {
                    Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
                    PanelSection("词形变化") {
                        ForEach(result.wordForms, id: \.self) { Text($0) }
                    }
                }
                if let example = result.examples.first {
                    Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
                    PanelSection("双语例句") {
                        Text(example.english).fontWeight(.medium)
                        Text(example.chinese).foregroundStyle(LingoPalette.secondary)
                    }
                }
            }
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .identity
                )
            )
        }
    }
}

private struct SentenceResultView: View {
    let result: TranslationResult
    @ObservedObject var model: PanelViewModel
    @AppStorage("showSentenceSkeleton") private var showSentenceSkeleton = true
    private var layout: AnnotationLayout { AnnotationLayout(source: result.source, annotations: result.annotations) }

    var body: some View {
        PrimaryResultBlock(title: "翻译", text: result.primaryResult, speakable: false)

        if showSentenceSkeleton, let skeleton = result.sentenceSkeleton {
            Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
            PanelSection("句子主干") {
                Text(skeleton).font(.system(size: 12, weight: .medium))
            }
        }

        DisclosureRow(title: "句子结构", isExpanded: $model.isExpanded)
        if model.isExpanded {
            VStack(spacing: 0) {
                if !result.clauses.isEmpty {
                    PanelSection("主要结构") {
                        ForEach(model.showNestedStructures ? result.clauses : Array(result.clauses.prefix(2))) { clause in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(clause.type).font(.system(size: 10, weight: .semibold)).foregroundStyle(LingoPalette.accent)
                                Text(clause.text).fontWeight(.medium)
                                Text(clause.explanation).font(.system(size: 10)).foregroundStyle(LingoPalette.secondary)
                            }
                            .padding(.bottom, 5)
                        }
                    }
                }
                if result.clauses.count > 2 || layout.hasNested {
                    Button(model.showNestedStructures ? "收起更多结构" : "更多结构") {
                        model.resetAnnotations()
                        model.showNestedStructures.toggle()
                    }
                        .padding(10)
                }
                if !result.grammarPoints.isEmpty {
                    Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
                    PanelSection("重点语法与搭配") {
                        ForEach(result.grammarPoints.prefix(3), id: \.self) { point in
                            Label(point, systemImage: "smallcircle.filled.circle")
                                .font(.system(size: 11))
                        }
                    }
                }
                if let note = result.translationNote {
                    Rectangle().fill(LingoPalette.divider).frame(height: 0.5)
                    PanelSection("翻译说明") {
                        Text(note).foregroundStyle(LingoPalette.secondary)
                    }
                }
            }
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .identity
                )
            )
        }
    }

}

private struct AnnotationCard: View {
    let annotation: GrammarAnnotation
    let pinned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(annotation.role.title).fontWeight(.semibold)
                    .foregroundStyle(Color(nsColor: AnnotationTextView.color(annotation.role)))
                Spacer()
                Text(pinned ? "已固定 · Esc 关闭" : "点击或 Return 固定").font(.caption2)
            }
            Text(annotation.text).fontWeight(.medium)
            Text(annotation.explanation).foregroundStyle(LingoPalette.secondary)
            if let modifies = annotation.modifies {
                Text("修饰：" + modifies).foregroundStyle(LingoPalette.secondary)
            }
        }
        .font(.system(size: 12))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LingoPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        .accessibilityElement(children: .combine)
    }
}

private struct PanelContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
