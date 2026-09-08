import AppKit
import SwiftUI

public enum LingoPalette {
    public static let panelTint = Color(red: 0.49, green: 0.06, blue: 0.08)
    public static let panelStrong = Color(red: 0.36, green: 0.025, blue: 0.045)
    public static let text = Color.white.opacity(0.97)
    public static let secondary = Color.white.opacity(0.66)
    public static let tertiary = Color.white.opacity(0.46)
    public static let divider = Color.white.opacity(0.12)
    public static let surface = Color.white.opacity(0.07)
    public static let surfaceHover = Color.white.opacity(0.12)
    public static let accent = Color(red: 1.0, green: 0.68, blue: 0.60)
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
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct PanelBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            VisualEffectView()
            LinearGradient(
                colors: [LingoPalette.panelTint.opacity(0.91), LingoPalette.panelStrong.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 0.75)
        }
        .shadow(color: Color.black.opacity(0.34), radius: 24, y: 14)
    }
}

public struct LingoIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

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
                    .font(.system(size: 10, weight: .medium))
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
