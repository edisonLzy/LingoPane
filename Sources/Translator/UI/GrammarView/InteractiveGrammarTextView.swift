import SwiftUI

/// 交互式语法结构标注组件（遵循 PRD 第 7 节规范：彩线下划线、从句方框、Hover 浮现与 Click to Pin 固定）
public struct InteractiveGrammarTextView: View {
    @Environment(\.colorScheme) private var colorScheme
    public let originalText: String
    public let chunks: [GrammarChunk]
    public let clauses: [Clause]?

    @State private var hoveredChunkID: String? = nil
    @State private var pinnedChunk: GrammarChunk? = nil
    @State private var hoverTask: Task<Void, Never>? = nil

    public init(
        originalText: String,
        chunks: [GrammarChunk],
        clauses: [Clause]? = nil
    ) {
        self.originalText = originalText
        self.chunks = chunks
        self.clauses = clauses
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 句子标注主体区
            WrappingHStack(horizontalSpacing: 4, verticalSpacing: 8) {
                ForEach(chunks) { chunk in
                    ChunkBadgeView(
                        chunk: chunk,
                        isHovered: hoveredChunkID == chunk.id,
                        isPinned: pinnedChunk?.id == chunk.id,
                        onHover: { hovering in
                            handleHover(chunk: chunk, isHovering: hovering)
                        },
                        onTap: {
                            handleTap(chunk: chunk)
                        }
                    )
                }
            }

            // 固定 (Pin) 或 悬停 (Hover) 的语法详细卡片
            if let activeChunk = pinnedChunk ?? activeHoveredChunk {
                GrammarExplanationCard(
                    chunk: activeChunk,
                    isPinned: pinnedChunk?.id == activeChunk.id,
                    onClosePin: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                            pinnedChunk = nil
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .offset(y: 4)),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.78), value: pinnedChunk?.id)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: hoveredChunkID)
    }

    private var activeHoveredChunk: GrammarChunk? {
        guard let id = hoveredChunkID else { return nil }
        return chunks.first { $0.id == id }
    }

    private func handleHover(chunk: GrammarChunk, isHovering: Bool) {
        hoverTask?.cancel()
        if isHovering {
            // PRD 7.3: Hover 延迟约 200~300ms 显示，防误触
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.hoveredChunkID = chunk.id
                    }
                }
            }
        } else {
            hoveredChunkID = nil
        }
    }

    private func handleTap(chunk: GrammarChunk) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
            if pinnedChunk?.id == chunk.id {
                pinnedChunk = nil // 再次点击取消固定
            } else {
                pinnedChunk = chunk // 点击固定 (Click to Pin)
            }
        }
    }
}

/// 单个成分片段渲染（含下划线与从句方框）
private struct ChunkBadgeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let chunk: GrammarChunk
    let isHovered: Bool
    let isPinned: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void

    var body: some View {
        let isClause = chunk.role == .clause
        let color = roleColor(chunk.role)

        VStack(spacing: 2) {
            Text(chunk.text)
                .font(.system(size: 13, weight: isPinned || isHovered ? .semibold : .medium))
                .foregroundStyle(
                    isPinned || isHovered
                        ? (colorScheme == .dark ? Color.white : Color.black)
                        : (colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 25/255, green: 25/255, blue: 30/255))
                )
                .padding(.horizontal, isClause ? 6 : 2)
                .padding(.vertical, isClause ? 3 : 1)
                .background {
                    if isClause {
                        // PRD 7.1 从句范围：使用方框或半透明背景
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color.opacity(colorScheme == .dark ? (isHovered || isPinned ? 0.25 : 0.14) : 0.12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(color.opacity(isHovered || isPinned ? 0.7 : 0.4), lineWidth: 1)
                            }
                    } else if isHovered || isPinned {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    }
                }

            if !isClause {
                // PRD 7.2 下划线规范
                if chunk.role == .adverbial {
                    // 状语：灰色虚线下划线
                    DashedLine()
                        .stroke(color, style: StrokeStyle(lineWidth: 1.8, dash: [3, 2]))
                        .frame(height: 2)
                } else {
                    // 主谓宾补：彩色实线下划线
                    Rectangle()
                        .fill(color)
                        .frame(height: isPinned || isHovered ? 2.8 : 2.2)
                        .cornerRadius(1)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { h in onHover(h) }
        .onTapGesture { onTap() }
    }

    private func roleColor(_ role: GrammarRole) -> Color {
        switch role {
        case .subject: return Color(red: 0.16, green: 0.59, blue: 1.00) // 蓝色实线
        case .predicate: return Color(red: 1.00, green: 0.62, blue: 0.04) // 橙色实线
        case .object: return Color(red: 0.19, green: 0.82, blue: 0.35) // 绿色实线
        case .complement: return Color(red: 0.75, green: 0.35, blue: 0.95) // 紫色实线
        case .adverbial: return Color(red: 0.56, green: 0.56, blue: 0.58) // 灰色虚线
        case .clause: return Color(red: 0.16, green: 0.59, blue: 1.00) // 从句框色
        case .modifier: return Color(red: 0.4, green: 0.7, blue: 0.9)
        }
    }
}

/// 虚线下划线 Shape
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

/// 悬停或固定时的语法说明卡片（遵循 PRD 7.3: 支持点击 Pin 固定并选中文本复制）
private struct GrammarExplanationCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let chunk: GrammarChunk
    let isPinned: Bool
    let onClosePin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)

                    Text(chunk.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    if isPinned {
                        Text("已固定")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background {
                                Capsule().fill(Color.secondary.opacity(0.15))
                            }
                    }
                }

                Spacer()

                if isPinned {
                    Button(action: onClosePin) {
                        Image(systemName: "pin.slash.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("取消固定 (Esc)")
                }
            }

            Text(chunk.text)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(colorScheme == .dark ? .white : .black)
                .textSelection(.enabled)

            if let explanation = chunk.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.75) : Color(red: 60/255, green: 60/255, blue: 65/255))
                    .lineSpacing(2)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 18/255, green: 22/255, blue: 32/255).opacity(0.92) : Color.white.opacity(0.85))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isPinned ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
    }
}
