import SwiftUI

/// Apple 官方 Liquid Glass 风格流体微胶囊按钮（支持活跃脉冲与丝滑触控弹簧）
public struct LiquidPillButton<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    public var isActive: Bool = false
    public let action: () -> Void
    public let content: () -> Content

    public init(
        isActive: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isActive = isActive
        self.action = action
        self.content = content
    }

    public var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            ZStack {
                Capsule()
                    .fill(
                        colorScheme == .dark
                            ? (isHovered ? Color.white.opacity(0.24) : Color.white.opacity(isActive ? 0.22 : 0.13))
                            : (isHovered ? Color.white.opacity(0.85) : Color.white.opacity(isActive ? 0.75 : 0.58))
                    )
                    .background(.ultraThinMaterial, in: Capsule())

                if isHovered || isActive {
                    // 顶部反光流体层
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.45),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: colorScheme == .dark ? Color.white.opacity(isHovered ? 0.65 : 0.38) : Color.white.opacity(0.95), location: 0.0),
                            .init(color: colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.40), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? (isHovered ? 0.35 : 0.18) : (isHovered ? 0.12 : 0.05)),
            radius: isHovered ? 6 : 3,
            y: isHovered ? 3 : 1
        )
        .scaleEffect(isPressed ? 0.94 : (isHovered ? 1.04 : 1.0))
        .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isHovered)
        .animation(.spring(response: 0.16, dampingFraction: 0.75), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
