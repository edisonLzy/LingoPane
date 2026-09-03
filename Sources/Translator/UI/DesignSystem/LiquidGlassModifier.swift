import SwiftUI
import AppKit

/// 原生 AppKit 物理毛玻璃底层（实现真正透过窗口看到桌面的高保真模糊）
public struct GlassBackingView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// 官方 Liquid Glass 终极材质修饰符（严格还原 prototype 中 52px 模糊饱和度与微倒角高光）
public struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var cornerRadius: CGFloat = 22

    public init(cornerRadius: CGFloat = 22) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // 1. 系统底层物理折射模糊 (backdrop-filter: blur(52px) saturate(210%))
                    GlassBackingView(
                        material: colorScheme == .dark ? .hudWindow : .popover,
                        blendingMode: .behindWindow
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                    // 2. 液体色泽底膜 (var(--glass-panel))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? Color(red: 10/255, green: 12/255, blue: 20/255).opacity(0.68)
                                : Color.white.opacity(0.55)
                        )

                    // 3. 顶部物理微倒角高光（Inner Bevel: inset 0 1.5px 1.5px 0 rgba(255,255,255,0.95)）
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: colorScheme == .dark ? Color.white.opacity(0.70) : Color.white.opacity(0.95), location: 0.0),
                                    .init(color: colorScheme == .dark ? Color.white.opacity(0.25) : Color.white.opacity(0.65), location: 0.15),
                                    .init(color: colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.30), location: 0.8),
                                    .init(color: colorScheme == .dark ? Color.black.opacity(0.20) : Color.black.opacity(0.05), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )

                    // 4. 环境光自顶向下自然微光
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.14 : 0.45), location: 0.0),
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.03 : 0.08), location: 0.22),
                            .init(color: Color.clear, location: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.15),
                radius: 32,
                x: 0,
                y: 16
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

/// 同心微透结果卡片（严格还原 .result-glass-card 与 .collapsible-box）
public struct ConcentricGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var cornerRadius: CGFloat = 14
    public var isHighlighted: Bool = false
    public var opacity: Double = 0.50

    public init(cornerRadius: CGFloat = 14, isHighlighted: Bool = false, opacity: Double = 0.50) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.opacity = opacity
    }

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(isHighlighted ? 0.15 : 0.08)
                                : Color.white.opacity(isHighlighted ? 0.72 : opacity)
                        )
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                    // 顶部微高光
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), location: 0.0),
                            .init(color: Color.clear, location: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isHighlighted
                            ? Color.accentColor.opacity(0.8)
                            : (colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.75)),
                        lineWidth: isHighlighted ? 1.4 : 0.8
                    )
            }
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}

/// 骨架屏扫描动态流光 (Shimmer)
public struct LiquidShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    public init() {}

    public func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.white.opacity(0.35), location: 0.48),
                            .init(color: Color.white.opacity(0.55), location: 0.5),
                            .init(color: Color.white.opacity(0.35), location: 0.52),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + (geo.size.width * 2) * phase)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 1.6)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}

public extension View {
    func liquidGlass(cornerRadius: CGFloat = 22) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }

    func concentricGlassCard(cornerRadius: CGFloat = 14, isHighlighted: Bool = false, opacity: Double = 0.50) -> some View {
        modifier(ConcentricGlassCardModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted, opacity: opacity))
    }

    func liquidShimmer() -> some View {
        modifier(LiquidShimmerModifier())
    }
}
