import SwiftUI

/// 句子成分彩线下划线标注交互组件（支持平滑 Hover 气泡浮窗与色彩高亮）
public struct SyntaxAnnotatedTextView: View {
    public let spans: [SyntaxSpan]
    @State private var hoveredSpanID: String? = nil

    public init(spans: [SyntaxSpan]) {
        self.spans = spans
    }

    public var body: some View {
        WrappingHStack(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 10) {
            ForEach(spans) { span in
                SpanItemView(
                    span: span,
                    isHovered: hoveredSpanID == span.id,
                    onHover: { hovering in
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                            hoveredSpanID = hovering ? span.id : nil
                        }
                    }
                )
            }
        }
    }
}

/// 单个语法片段视图
private struct SpanItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    let span: SyntaxSpan
    let isHovered: Bool
    let onHover: (Bool) -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            // 悬停浮现的成分名称 Liquid Glass 胶囊标签
            ZStack {
                if isHovered && span.role != .other {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(span.role.color)
                            .frame(width: 5, height: 5)

                        Text(span.displayLabel)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(Color(red: 18/255, green: 22/255, blue: 32/255).opacity(0.92))
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.8
                                    )
                            }
                            .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.88).combined(with: .opacity).combined(with: .offset(y: 4)),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }
            .frame(height: 18) // 固高占位防止页面上下抖动

            // 文本内容与动态彩色下划线
            VStack(spacing: 3) {
                Text(span.text)
                    .font(.system(size: 13, weight: isHovered ? .semibold : .medium))
                    .foregroundStyle(
                        isHovered
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : (colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 35/255, green: 35/255, blue: 40/255))
                    )
                    .padding(.horizontal, 3)

                if span.role != .other {
                    Rectangle()
                        .fill(span.role.color)
                        .frame(height: isHovered ? span.role.underlineHeight + 0.8 : span.role.underlineHeight)
                        .shadow(color: isHovered ? span.role.color.opacity(0.6) : .clear, radius: 3, y: 1)
                        .cornerRadius(1)
                } else {
                    Color.clear.frame(height: 2)
                }
            }
            .padding(.vertical, 2)
            .background {
                if isHovered && span.role != .other {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(span.role.color.opacity(colorScheme == .dark ? 0.20 : 0.15))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(span.role.color.opacity(0.35), lineWidth: 0.8)
                        }
                }
            }
            .scaleEffect(isHovered && span.role != .other ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                onHover(hovering)
            }
        }
    }
}
