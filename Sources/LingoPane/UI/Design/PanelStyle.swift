import AppKit
import SwiftUI

public enum LingoPalette {
    public static let cornerRadius: CGFloat = 24
    public static let text = Color.white.opacity(0.97)
    public static let secondary = Color.white.opacity(0.78)
    public static let tertiary = Color.white.opacity(0.62)
    public static let divider = Color.white.opacity(0.09)
    public static let surface = Color.white.opacity(0.055)
    public static let surfaceHover = Color.white.opacity(0.12)
    public static let accent = Color(red: 0.72, green: 0.88, blue: 1.0)
}

public enum LingoMotion {
    public static let quick = Animation.easeOut(duration: 0.14)
    public static let standard = Animation.spring(response: 0.28, dampingFraction: 0.86)
    public static let reveal = Animation.spring(response: 0.34, dampingFraction: 0.88)
}

public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

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
        view.appearance = NSAppearance(named: .darkAqua)
        view.wantsLayer = true
        view.layer?.cornerRadius = LingoPalette.cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Native behind-window frost, with a restrained reflective rim.
/// Uses public macOS 14 APIs and honors the system transparency/contrast preferences.
public struct PanelBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    public init() {}

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: LingoPalette.cornerRadius, style: .continuous)
    }

    public var body: some View {
        ZStack {
            if reduceTransparency {
                Color(white: 0.13)
            } else {
                VisualEffectView()
                // Keep the material exposed so actual desktop colors remain visible.
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.09), location: 0),
                        .init(color: .white.opacity(0.015), location: 0.32),
                        .init(color: .black.opacity(0.10), location: 1)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(stops: [
                    .init(color: .white.opacity(0.65), location: 0),
                    .init(color: .white.opacity(0.18), location: 0.27),
                    .init(color: .white.opacity(0.07), location: 0.48),
                    .init(color: Color(red: 0.68, green: 0.85, blue: 0.95).opacity(0.30), location: 0.73),
                    .init(color: .white.opacity(0.46), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: contrast == .increased ? 1.5 : 0.8
            )
        }
        .overlay {
            shape.inset(by: 1.4)
                .strokeBorder(.white.opacity(contrast == .increased ? 0.25 : 0.055), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}

public struct LingoIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(systemName: String, label: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 27, height: 25)
                .contentShape(Rectangle())
        }
        .buttonStyle(PanelIconButtonStyle())
        .background(hovered ? LingoPalette.surfaceHover : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .scaleEffect(hovered && !reduceMotion ? 1.06 : 1)
        .animation(reduceMotion ? nil : LingoMotion.quick, value: hovered)
        .onHover { hovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct PanelIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LingoPalette.secondary)
            .background(configuration.isPressed ? LingoPalette.surfaceHover : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

public struct PanelSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LingoPalette.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }
}

public struct FlowLayout: Layout {
    public var spacing: CGFloat = 5

    public init(spacing: CGFloat = 5) {
        self.spacing = spacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? 360
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var points: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), points)
    }
}
