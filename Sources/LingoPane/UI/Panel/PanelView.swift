import SwiftUI

public struct PanelView: View {
    @ObservedObject var model: PanelViewModel

    public init(model: PanelViewModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            PanelBackground()
            VStack(spacing: 0) {
                header
                Divider().overlay(LingoPalette.divider)
                ScrollView {
                    VStack(spacing: 0) {
                        sourceSection
                        Divider().overlay(LingoPalette.divider)
                        phaseContent
                    }
                }
                .scrollIndicators(.never)
                footer
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .foregroundStyle(LingoPalette.text)
        .font(.system(size: 13))
        .padding(18)
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
            .fixedSize()
            .accessibilityLabel("切换内容类型")

            Spacer()

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
                Text(model.source)
                    .font(.system(size: 14))
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if model.classification.language == .english {
                    LingoIconButton(systemName: "play.fill", label: "播放英文原文") {
                        SpeechService.shared.toggle(model.source)
                    }
                }
                LingoIconButton(systemName: "doc.on.doc", label: "复制原文") {
                    AppState.shared.copy(model.source)
                }
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .loading:
            LoadingResultView()
        case .failed(let failure):
            FailureResultView(failure: failure, retry: model.retryAction)
        case .ready(let result):
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
            Label("已安全校验", systemImage: "checkmark.circle.fill")
            Spacer()
            Text("LingoPane")
        }
        .font(.system(size: 9))
        .foregroundStyle(LingoPalette.tertiary)
        .padding(.horizontal, 15)
        .frame(height: 31)
        .overlay(alignment: .top) { Divider().overlay(LingoPalette.divider) }
    }
}

private struct LoadingResultView: View {
    var body: some View {
        PanelSection("基础分析中") {
            VStack(alignment: .leading, spacing: 9) {
                Capsule().fill(Color.white.opacity(0.13)).frame(width: 240, height: 12)
                Capsule().fill(Color.white.opacity(0.10)).frame(width: 190, height: 12)
                Text("正在生成主译文…")
                    .font(.system(size: 11))
                    .foregroundStyle(LingoPalette.secondary)
            }
            .padding(.vertical, 3)
        }
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

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
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
        .overlay(alignment: .top) { Divider().overlay(LingoPalette.divider) }
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
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func detailLists(result: TranslationResult) -> some View {
        if !result.keywordMappings.isEmpty {
            Divider().overlay(LingoPalette.divider)
            PanelSection("关键词映射") {
                ForEach(result.keywordMappings) { mapping in
                    HStack {
                        Text(mapping.source).foregroundStyle(LingoPalette.secondary)
                        Image(systemName: "arrow.right").foregroundStyle(LingoPalette.tertiary)
                        Text(mapping.target).fontWeight(.medium)
                    }
                }
            }
        }
        if let example = result.examples.first {
            Divider().overlay(LingoPalette.divider)
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
                if !result.wordForms.isEmpty {
                    Divider().overlay(LingoPalette.divider)
                    PanelSection("词形变化") {
                        ForEach(result.wordForms, id: \.self) { Text($0) }
                    }
                }
                if let example = result.examples.first {
                    Divider().overlay(LingoPalette.divider)
                    PanelSection("双语例句") {
                        Text(example.english).fontWeight(.medium)
                        Text(example.chinese).foregroundStyle(LingoPalette.secondary)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

private struct SentenceResultView: View {
    let result: TranslationResult
    @ObservedObject var model: PanelViewModel
    @AppStorage("showSentenceSkeleton") private var showSentenceSkeleton = true
    @State private var hoveredID: UUID?
    @State private var hoverTask: Task<Void, Never>?
    @FocusState private var focusedID: UUID?

    private var activeID: UUID? { model.pinnedAnnotationID ?? focusedID ?? hoveredID }

    var body: some View {
        if !result.annotations.isEmpty {
            PanelSection("句子标注") {
                FlowLayout(spacing: 5) {
                    ForEach(result.annotations) { annotation in
                        annotationButton(annotation)
                    }
                }
                if let annotation = result.annotations.first(where: { $0.id == activeID }) {
                    annotationCard(annotation)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }

        PrimaryResultBlock(title: "翻译", text: result.primaryResult, speakable: false)

        if showSentenceSkeleton, let skeleton = result.sentenceSkeleton {
            Divider().overlay(LingoPalette.divider)
            PanelSection("句子主干") {
                Text(skeleton).font(.system(size: 12, weight: .medium))
            }
        }

        DisclosureRow(title: "句子结构", isExpanded: $model.isExpanded)
        if model.isExpanded {
            VStack(spacing: 0) {
                if !result.clauses.isEmpty {
                    PanelSection("主要结构") {
                        ForEach(result.clauses) { clause in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(clause.type).font(.system(size: 10, weight: .semibold)).foregroundStyle(LingoPalette.accent)
                                Text(clause.text).fontWeight(.medium)
                                Text(clause.explanation).font(.system(size: 10)).foregroundStyle(LingoPalette.secondary)
                            }
                            .padding(.bottom, 5)
                        }
                    }
                }
                if !result.grammarPoints.isEmpty {
                    Divider().overlay(LingoPalette.divider)
                    PanelSection("重点语法与搭配") {
                        ForEach(result.grammarPoints.prefix(3), id: \.self) { point in
                            Label(point, systemImage: "smallcircle.filled.circle")
                                .font(.system(size: 11))
                        }
                    }
                }
                if let note = result.translationNote {
                    Divider().overlay(LingoPalette.divider)
                    PanelSection("翻译说明") {
                        Text(note).foregroundStyle(LingoPalette.secondary)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func annotationButton(_ annotation: GrammarAnnotation) -> some View {
        Button {
            model.pinnedAnnotationID = model.pinnedAnnotationID == annotation.id ? nil : annotation.id
        } label: {
            Text(annotation.text)
                .font(.system(size: 13))
                .underline(annotation.role != .clause, color: roleColor(annotation.role))
                .padding(.horizontal, annotation.role == .clause ? 5 : 1)
                .padding(.vertical, 4)
                .background(annotation.role == .clause ? roleColor(.clause).opacity(0.14) : Color.clear)
                .overlay {
                    if annotation.role == .clause {
                        RoundedRectangle(cornerRadius: 5).stroke(roleColor(.clause).opacity(0.6), lineWidth: 0.7)
                    }
                }
        }
        .buttonStyle(.plain)
        .focused($focusedID, equals: annotation.id)
        .onHover { isHovering in
            hoverTask?.cancel()
            if isHovering {
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 240_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { hoveredID = annotation.id }
                }
            } else if model.pinnedAnnotationID != annotation.id {
                hoveredID = nil
            }
        }
        .accessibilityLabel("\(annotation.role.title)：\(annotation.text)")
        .accessibilityHint(annotation.explanation)
    }

    private func annotationCard(_ annotation: GrammarAnnotation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(annotation.role.title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(roleColor(annotation.role))
                Spacer()
                Text(model.pinnedAnnotationID == annotation.id ? "已固定" : "点击固定")
                    .font(.system(size: 9))
                    .foregroundStyle(LingoPalette.tertiary)
            }
            Text(annotation.text).font(.system(size: 11, weight: .semibold))
            Text(annotation.explanation).font(.system(size: 10)).foregroundStyle(LingoPalette.secondary)
            if let modifies = annotation.modifies {
                Text("修饰：\(modifies)").font(.system(size: 9)).foregroundStyle(LingoPalette.tertiary)
            }
        }
        .padding(9)
        .background(LingoPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func roleColor(_ role: GrammarRole) -> Color {
        switch role {
        case .subject: .cyan
        case .predicate: .orange
        case .object: .green
        case .complement: .purple
        case .modifier, .adverbial: Color.white.opacity(0.65)
        case .clause: Color(red: 0.76, green: 0.53, blue: 1.0)
        }
    }
}
