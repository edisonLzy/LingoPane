import SwiftUI

/// 规范 2：英语单词面板（解析、音标、发音动效、词根演化、释义 + 丝滑折叠同义词与例句）
public struct EnglishWordPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    public let data: WordAnalysis

    @State private var isExpanded: Bool = false
    @State private var hoveredSynonym: String? = nil

    public init(data: WordAnalysis) {
        self.data = data
    }

    public var body: some View {
        VStack(spacing: 12) {
            // 2.1 默认呈现项：单词、音标、发音、词根、不同词性含义
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(data.word)
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .foregroundStyle(colorScheme == .dark ? .white : Color(red: 25/255, green: 25/255, blue: 30/255))

                        Text(data.phonetic)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00).opacity(0.85))
                    }

                    Spacer()

                    // 发音按键（带发音中的状态与声波呼吸动效）
                    let isSpeaking = SpeechService.shared.isSpeaking(text: data.word)
                    LiquidPillButton(
                        isActive: isSpeaking,
                        action: {
                            SpeechService.shared.speak(data.word, language: "en-US")
                        }
                    ) {
                        HStack(spacing: 4) {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))
                                .symbolEffect(.bounce, value: isSpeaking)
                        }
                    }
                    .help("朗读单词发音")
                }

                // 词根卡片 (Etymology)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("词根溯源")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))

                        Text(data.root)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 50/255, green: 50/255, blue: 55/255))
                            .lineSpacing(3)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.4), lineWidth: 0.5)
                        }
                }

                // 不同词性下的释义列表
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(data.meanings) { meaning in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(meaning.pos)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color(red: 0.16, green: 0.59, blue: 1.00).opacity(0.18))
                                }

                            Text(meaning.def)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 30/255, green: 30/255, blue: 35/255))
                                .lineSpacing(2)
                        }
                    }
                }
            }
            .padding(14)
            .concentricGlassCard()

            // 2.2 可展开项：同义词辨析与双语例句（丝滑 Spring 展开动效）
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))

                        Text("同义词与例句")
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

                        // 同义词
                        if !data.synonyms.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("同义词辨析")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.secondary)

                                WrappingHStack(horizontalSpacing: 6, verticalSpacing: 6) {
                                    ForEach(data.synonyms, id: \.self) { syn in
                                        let isHover = hoveredSynonym == syn
                                        Text(syn)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color(red: 35/255, green: 35/255, blue: 40/255))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 4)
                                            .background {
                                                Capsule()
                                                    .fill(
                                                        isHover
                                                            ? Color.accentColor.opacity(0.25)
                                                            : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                                                    )
                                                    .overlay {
                                                        Capsule().strokeBorder(Color.white.opacity(isHover ? 0.4 : 0.1), lineWidth: 0.8)
                                                    }
                                            }
                                            .scaleEffect(isHover ? 1.05 : 1.0)
                                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHover)
                                            .onHover { h in
                                                hoveredSynonym = h ? syn : nil
                                            }
                                    }
                                }
                            }
                        }

                        // 例句
                        if !data.examples.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("语境例句")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.secondary)

                                ForEach(data.examples) { ex in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ex.en)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 25/255, green: 25/255, blue: 30/255))
                                            .lineSpacing(2)

                                        Text(ex.cn)
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color(red: 110/255, green: 110/255, blue: 115/255))
                                            .lineSpacing(2)
                                    }
                                    .padding(.vertical, 3)
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
