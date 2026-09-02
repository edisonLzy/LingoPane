import SwiftUI

/// 规范 3：英语句子面板（彩线成分分析、Hover 标签、极简色标、中文译文 + 丝滑折叠核心词汇）
public struct EnglishSentencePanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    public let data: SentenceAnalysis

    @State private var isExpanded: Bool = false
    @State private var hoveredKeywordID: String? = nil

    public init(data: SentenceAnalysis) {
        self.data = data
    }

    public var body: some View {
        VStack(spacing: 12) {
            // 3.1 默认呈现项：彩线成分原句、发音、极简色标指南与中文译文
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    // 3.1.1 句子成分彩线下划线标注与 Hover 浮窗
                    SyntaxAnnotatedTextView(spans: data.syntaxSpans)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 朗读原句按键（带发音中的状态与声波呼吸动效）
                    let isSpeaking = SpeechService.shared.isSpeaking(text: data.original)
                    LiquidPillButton(
                        isActive: isSpeaking,
                        action: {
                            SpeechService.shared.speak(data.original, language: "en-US")
                        }
                    ) {
                        Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))
                            .symbolEffect(.bounce, value: isSpeaking)
                    }
                    .help("朗读整句")
                }

                // 极简语法色标指南
                HStack(spacing: 12) {
                    ColorTagView(color: SyntaxRole.subject.color, title: "主语")
                    ColorTagView(color: SyntaxRole.predicate.color, title: "谓语")
                    ColorTagView(color: SyntaxRole.object.color, title: "宾/表语")
                    ColorTagView(color: SyntaxRole.adverbial.color, title: "状语")
                    ColorTagView(color: SyntaxRole.clause.color, title: "从句")
                }
                .padding(.top, 2)

                Divider().opacity(0.15)

                // 中文译文
                Text(data.translation)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 25/255, green: 25/255, blue: 30/255))
                    .lineSpacing(4)
            }
            .padding(14)
            .concentricGlassCard()

            // 3.2 可展开项：重点单词与重点短语
            if !data.keyWords.isEmpty || !data.keyPhrases.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))

                            Text("重点单词与短语")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color(red: 70/255, green: 70/255, blue: 75/255))

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            Divider().opacity(0.15)

                            // 核心词汇
                            if !data.keyWords.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("核心词汇")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.secondary)

                                    ForEach(data.keyWords) { kw in
                                        let isHover = hoveredKeywordID == kw.id
                                        HStack(alignment: .firstTextBaseline) {
                                            HStack(spacing: 5) {
                                                Text(kw.word)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(colorScheme == .dark ? .white : .black)

                                                Text(kw.pos)
                                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(Color.secondary)
                                            }

                                            Spacer()

                                            Text(kw.def)
                                                .font(.system(size: 11, weight: .regular))
                                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color(red: 60/255, green: 60/255, blue: 65/255))
                                        }
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 6)
                                        .background {
                                            if isHover {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4))
                                            }
                                        }
                                        .onHover { h in
                                            hoveredKeywordID = h ? kw.id : nil
                                        }
                                    }
                                }
                            }

                            // 关键短语搭配
                            if !data.keyPhrases.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("关键短语搭配")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.secondary)

                                    ForEach(data.keyPhrases) { kp in
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(kp.phrase)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))

                                            Spacer()

                                            Text(kp.def)
                                                .font(.system(size: 11, weight: .regular))
                                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color(red: 60/255, green: 60/255, blue: 65/255))
                                        }
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 6)
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(12)
                .concentricGlassCard()
            }
        }
    }
}

private struct ColorTagView: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 8, height: 2.5)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
    }
}
