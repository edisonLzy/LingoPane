import Foundation

enum PanelArrangement {
    static func frames(sizes: [CGSize], in visible: CGRect) -> [CGRect]? {
        var x = visible.maxX
        var y = visible.maxY
        var columnWidth: CGFloat = 0
        var result: [CGRect] = []
        for size in sizes {
            guard size.width <= visible.width, size.height <= visible.height else { return nil }
            if y - size.height < visible.minY {
                x -= columnWidth + 12
                y = visible.maxY
                columnWidth = 0
            }
            guard x - size.width >= visible.minX else { return nil }
            result.append(CGRect(x: x - size.width, y: y - size.height, width: size.width, height: size.height))
            y -= size.height + 12
            columnWidth = max(columnWidth, size.width)
        }
        return result
    }
}
