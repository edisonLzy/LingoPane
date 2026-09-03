import SwiftUI

/// 交互式语法拓扑标注组件（遵循最新 Liquid Glass 视觉规范：精准彩线下划线、从句虚线框与置顶锁定卡片）
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
        VStack(alignment: .leading, spacing: 8) {
            // 句子标注主体区 (支持分词下划线与从句胶囊)
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

            // 悬停/点击交互提示
            HStack(spacing: 4) {
                Text("💡")
                    .font(.system(size: 10))
                Text("悬停或点击带标注成分可锁定语法卡片")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.secondary.opacity(0.85))
            }
            .padding(.top, 2)

            // 浮动 / 固定卡片 (严格还原 .syntax-popover)
            if let activeChunk = pinnedChunk ?? activeHoveredChunk {
                GrammarPopoverCard(
                    chunk: activeChunk,
                    isPinned: pinnedChunk?.id == activeChunk.id,
                    onClosePin: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                            pinnedChunk = nil
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity).combined(with: .offset(y: 4)),
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
            // 200ms 防误触触发
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: 200_000_000)
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
                pinnedChunk = nil
            } else {
                pinnedChunk = chunk
            }
        }
    }
}

/// 单个语法成分 Token 渲染
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
                .font(.system(size: 15, weight: isPinned || isHovered ? .semibold : .medium))
                .foregroundStyle(
                    isPinned || isHovered
                        ? (colorScheme == .dark ? Color.white : Color(red: 15/255, green: 15/255, blue: 18/255))
                        : (colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 28/255, green: 28/255, blue: 30/255))
                )
                .padding(.horizontal, isClause ? 6 : 2)
                .padding(.vertical, isClause ? 2.5 : 1)
                .background {
                    if isClause {
                        // 从句虚线胶囊外框与浅紫微光
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(red: 191/255, green: 90/255, blue: 242/255).opacity(colorScheme == .dark ? 0.16 : 0.08))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(
                                        Color(red: 191/255, green: 90/255, blue: 242/255).opacity(isHovered || isPinned ? 0.9 : 0.6),
                                        style: StrokeStyle(lineWidth: 1.2, dash: [3, 2])
                                    )
                            }
                    } else if isHovered || isPinned {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.65))
                    }
                }

            if !isClause {
                if chunk.role == .adverbial {
                    // 状语：灰色虚线下划线
                    DashedLine()
                        .stroke(color, style: StrokeStyle(lineWidth: 2.0, dash: [3, 2]))
                        .frame(height: 2)
                } else {
                    // 主谓宾补：彩色实线下划线 (带圆角线帽)
                    Capsule()
                        .fill(color)
                        .frame(height: isPinned || isHovered ? 2.8 : 2.5)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { h in onHover(h) }
        .onTapGesture { onTap() }
    }

    private func roleColor(_ role: GrammarRole) -> Color {
        switch role {
        case .subject: return Color(red: 10/255, green: 132/255, blue: 255/255) // #0a84ff 蓝
        case .predicate: return Color(red: 255/255, green: 159/255, blue: 10/255) // #ff9f0a 橙
        case .object: return Color(red: 48/255, green: 209/255, blue: 88/255) // #30d158 绿
        case .clause: return Color(red: 191/255, green: 90/255, blue: 242/255) // #bf5af2 紫
        case .complement: return Color(red: 191/255, green: 90/255, blue: 242/255)
        case .adverbial: return Color(red: 142/255, green: 142/255, blue: 147/255) // 灰
        case .modifier: return Color(red: 10/255, green: 132/255, blue: 255/255)
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

/// 严格对应 HTML 原型 .syntax-popover 的卡片
private struct GrammarPopoverCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let chunk: GrammarChunk
    let isPinned: Bool
    let onClosePin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 顶栏：角色名称 + 状态
            HStack {
                Text(chunk.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(roleAccentColor(chunk.role))
                    .textCase(.uppercase)

                Spacer()

                Text(isPinned ? "(已锁定)" : "Hover")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(isPinned ? roleAccentColor(chunk.role) : Color.secondary.opacity(0.8))

                if isPinned {
                    Button(action: onClosePin) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                    .help("取消锁定 (Esc)")
                }
            }

            // 说明正文
            if let desc = chunk.explanation, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 45/255, green: 45/255, blue: 50/255))
                    .lineSpacing(2.5)
                    .textSelection(.enabled)
            } else {
                Text(chunk.text)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .textSelection(.enabled)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color(red: 22/255, green: 25/255, blue: 36/255).opacity(0.94)
                        : Color.white.opacity(0.94)
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isPinned ? Color(red: 10/255, green: 132/255, blue: 255/255) : (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)),
                    lineWidth: isPinned ? 1.5 : 0.6
                )
        }
        .shadow(
            color: isPinned
                ? Color(red: 10/255, green: 132/255, blue: 255/255).opacity(0.24)
                : Color.black.opacity(0.14),
            radius: isPinned ? 14 : 10,
            x: 0,
            y: 4
        )
    }

    private func roleAccentColor(_ role: GrammarRole) -> Color {
        switch role {
        case .subject: return Color(red: 10/255, green: 132/255, blue: 255/255)
        case .predicate: return Color(red: 255/255, green: 159/255, blue: 10/255)
        case .object: return Color(red: 48/255, green: 209/255, blue: 88/255)
        case .clause: return Color(red: 191/255, green: 90/255, blue: 242/255)
        default: return Color.accentColor
        }
    }
}
