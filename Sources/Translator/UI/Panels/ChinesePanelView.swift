import SwiftUI

/// 规范 4：中文词句面板（中文原文 + 双场景地道英文直出 + 发音与复制即时动效）
public struct ChinesePanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    public let data: ChineseAnalysis
    public let onCopy: (String) -> Void

    @State private var copiedTextID: String? = nil
    @State private var hoveredCardID: String? = nil

    public init(data: ChineseAnalysis, onCopy: @escaping (String) -> Void) {
        self.data = data
        self.onCopy = onCopy
    }

    public var body: some View {
        VStack(spacing: 12) {
            // 选中的中文原文
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)

                    Text("中文原文")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }

                Text(data.sourceText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 25/255, green: 25/255, blue: 30/255))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .concentricGlassCard()

            // 4.1 双场景地道英文直出（自然日常沟通 vs 正式书面设计）
            VStack(spacing: 10) {
                ForEach(data.translations) { item in
                    let isSpeaking = SpeechService.shared.isSpeaking(text: item.text)
                    let isCopied = copiedTextID == item.text
                    let isCardHover = hoveredCardID == item.id

                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(item.tag)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background {
                                    Capsule()
                                        .fill(Color(red: 0.16, green: 0.59, blue: 1.00).opacity(0.15))
                                        .overlay {
                                            Capsule()
                                                .strokeBorder(Color(red: 0.16, green: 0.59, blue: 1.00).opacity(0.30), lineWidth: 0.8)
                                        }
                                }

                            Spacer()

                            HStack(spacing: 6) {
                                // 朗读按钮
                                LiquidPillButton(
                                    isActive: isSpeaking,
                                    action: {
                                        SpeechService.shared.speak(item.text, language: "en-US")
                                    }
                                ) {
                                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color(red: 0.16, green: 0.59, blue: 1.00))
                                        .symbolEffect(.bounce, value: isSpeaking)
                                }
                                .help("朗读地道发音")

                                // 复制按钮（带成功瞬时变换动画）
                                LiquidPillButton(
                                    isActive: isCopied,
                                    action: {
                                        onCopy(item.text)
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                            copiedTextID = item.text
                                        }
                                        Task {
                                            try? await Task.sleep(nanoseconds: 1_800_000_000)
                                            withAnimation {
                                                if copiedTextID == item.text {
                                                    copiedTextID = nil
                                                }
                                            }
                                        }
                                    }
                                ) {
                                    HStack(spacing: 3) {
                                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(isCopied ? Color.green : Color.secondary)
                                            .symbolEffect(.bounce, value: isCopied)

                                        if isCopied {
                                            Text("已复制")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundStyle(Color.green)
                                                .transition(.opacity.combined(with: .scale))
                                        }
                                    }
                                }
                                .help("一键复制到剪贴板")
                            }
                        }

                        Text(item.text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(colorScheme == .dark ? .white : Color(red: 25/255, green: 25/255, blue: 30/255))
                            .lineSpacing(3)
                    }
                    .padding(13)
                    .concentricGlassCard(isHighlighted: isCardHover)
                    .onHover { h in
                        hoveredCardID = h ? item.id : nil
                    }
                }
            }
        }
    }
}
