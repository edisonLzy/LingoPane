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

/// Apple 官方 Liquid Glass 终极材质修饰符（融合物理折射、微光渐变与深度投影）
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
                    // 1. 系统底层折射模糊
                    GlassBackingView(
                        material: colorScheme == .dark ? .hudWindow : .popover,
                        blendingMode: .behindWindow
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                    // 2. 液体色泽薄膜
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? Color(red: 12/255, green: 16/255, blue: 26/255).opacity(0.65)
                                : Color.white.opacity(0.70)
                        )

                    // 3. 顶部物理环境光折射（Ambient Specular Sheen）
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.40), location: 0.0),
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10), location: 0.25),
                            .init(color: Color.clear, location: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .overlay {
                // 4. 精细镜面边缘高光（Specular Rim Highlight）
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.55) : Color.white.opacity(0.95), location: 0.0),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.45), location: 0.2),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.15), location: 0.8),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.04), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
            }
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.65) : Color(red: 18/255, green: 38/255, blue: 75/255).opacity(0.16),
                radius: colorScheme == .dark ? 35 : 24,
                x: 0,
                y: colorScheme == .dark ? 18 : 12
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.40) : Color.black.opacity(0.06),
                radius: 4,
                x: 0,
                y: 1
            )
    }
}

/// 同心圆角微透卡片（遵循 Apple HIG 同心曲率原则）
public struct ConcentricGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var cornerRadius: CGFloat = 16
    public var isHighlighted: Bool = false

    public init(cornerRadius: CGFloat = 16, isHighlighted: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
    }

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(isHighlighted ? 0.12 : 0.07)
                                : Color.white.opacity(isHighlighted ? 0.75 : 0.58)
                        )
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                    // 微光高反差边缘
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25), location: 0.0),
                            .init(color: Color.clear, location: 0.4)
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
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark ? Color.white.opacity(isHighlighted ? 0.38 : 0.22) : Color.white.opacity(0.90), location: 0.0),
                                .init(color: colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isHighlighted ? 1.2 : 0.8
                    )
            }
    }
}

/// 流体微光扫描动画修饰符（用于 Loading / 骨架屏态）
public struct LiquidShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    public func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.25), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .offset(x: phase * width * 1.8)
                    .blendMode(.plusLighter)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

public extension View {
    func liquidGlass(cornerRadius: CGFloat = 22) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }

    func concentricGlassCard(cornerRadius: CGFloat = 16, isHighlighted: Bool = false) -> some View {
        modifier(ConcentricGlassCardModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }

    func liquidShimmer() -> some View {
        modifier(LiquidShimmerModifier())
    }
}
