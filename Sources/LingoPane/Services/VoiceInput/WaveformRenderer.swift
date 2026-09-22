import AppKit
import Foundation

/// Rolling waveform state shown in the menu bar while the voice hotkey is held.
enum WaveformLevels {
    static let barCount = 14
    static let decayPerFrame: Float = 0.86

    /// Appends a new raw level, decaying the previous peak so the bars fall
    /// smoothly between microphone buffers, and trims to a fixed ring size.
    static func append(raw: Float, to levels: inout [Float]) {
        let clamped = Swift.min(Swift.max(raw, 0), 1)
        let decayed = Swift.max(clamped, (levels.last ?? 0) * decayPerFrame)
        levels.append(decayed)
        if levels.count > barCount { levels.removeFirst(levels.count - barCount) }
    }

    /// Gentle idle animation shown while speech-to-text is running.
    static func idleLevels(at time: TimeInterval) -> [Float] {
        (0..<barCount).map { index in
            let wave = sin(time * 6 + Double(index) * 0.8)
            return Float(0.16 + 0.12 * wave)
        }
    }
}

/// Draws audio levels as a template image sized for the macOS menu bar.
enum WaveformRenderer {
    static let defaultSize = NSSize(width: 66, height: 18)

    static func image(levels: [Float], size: NSSize = defaultSize) -> NSImage {
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(size.width * scale)),
            pixelsHigh: max(1, Int(size.height * scale)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSImage(size: size)
        }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(levels: levels, size: size)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        // Template rendering keeps the waveform legible in light and dark
        // menu bars, matching the previous SF Symbol icon.
        image.isTemplate = true
        return image
    }

    private static func draw(levels: [Float], size: NSSize) {
        let count = Swift.max(levels.count, 1)
        let slot = size.width / CGFloat(count)
        let lineWidth = Swift.min(3.2, slot * 0.55)
        let maxHeight = size.height - 2
        NSColor.black.set()

        for (index, raw) in levels.enumerated() {
            let clamped = CGFloat(Swift.min(Swift.max(raw, 0), 1))
            let height = Swift.max(2, clamped * maxHeight)
            let x = (CGFloat(index) + 0.5) * slot
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: x, y: (size.height - height) / 2))
            path.line(to: NSPoint(x: x, y: (size.height + height) / 2))
            path.stroke()
        }
    }
}
