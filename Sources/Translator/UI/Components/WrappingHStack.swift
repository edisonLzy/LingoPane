import SwiftUI

/// 自适应换行流式布局容器（Flow Layout）
public struct WrappingHStack: Layout {
    public var alignment: HorizontalAlignment
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat

    public init(
        alignment: HorizontalAlignment = .leading,
        horizontalSpacing: CGFloat = 4,
        verticalSpacing: CGFloat = 8
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 350
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > width, lineWidth > 0 {
                totalHeight += lineHeight + verticalSpacing
                lineWidth = size.width + horizontalSpacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + horizontalSpacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        totalHeight += lineHeight
        return CGSize(width: width, height: totalHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
