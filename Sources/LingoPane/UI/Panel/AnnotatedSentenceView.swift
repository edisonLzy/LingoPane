import AppKit
import SwiftUI

struct AnnotatedSentenceView: NSViewRepresentable {
    @ObservedObject var model: PanelViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let text = AnnotationTextView(frame: .zero)
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 1, height: 3)
        text.textContainer?.lineFragmentPadding = 0
        text.isHorizontallyResizable = false
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        scroll.documentView = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let text = scroll.documentView as? AnnotationTextView else { return }
        text.model = model
        text.configure(source: model.source,
            annotations: model.isExpanded ? model.result?.annotations ?? [] : [],
            includeNested: model.showNestedStructures)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let text = nsView.documentView as? AnnotationTextView,
              let container = text.textContainer, let manager = text.layoutManager else { return nil }
        let width = max(100, proposal.width ?? 270)
        container.containerSize = CGSize(width: width - 4, height: .greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        let height = ceil(manager.usedRect(for: container).height) + 8
        text.setFrameSize(CGSize(width: width, height: max(height, 24)))
        return CGSize(width: width, height: min(model.isExpanded ? 144 : 88, max(24, height)))
    }
}

@MainActor
final class AnnotationTextView: NSTextView {
    weak var model: PanelViewModel?
    private var layout = AnnotationLayout(source: "", annotations: [])
    private var visible: [GrammarAnnotation] = []
    private var includeNested = false
    private var tracking: NSTrackingArea?
    private var focusedIndex: Int?
    private var lastHover: UUID?
    private var signature = ""

    func configure(source: String, annotations: [GrammarAnnotation], includeNested: Bool) {
        let newSignature = source + annotations.map { $0.id.uuidString }.joined() + String(includeNested)
        guard signature != newSignature else { return }
        signature = newSignature
        layout = AnnotationLayout(source: source, annotations: annotations)
        self.includeNested = includeNested
        visible = layout.visible(includeNested: includeNested)
        focusedIndex = nil
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let attributed = NSMutableAttributedString(string: source, attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ])
        // A single original string preserves whitespace, punctuation and nested overlaps.
        for annotation in visible.sorted(by: { $0.end - $0.start > $1.end - $1.start }) {
            guard let range = layout.nativeRange(of: annotation) else { continue }
            if annotation.role == .clause {
                attributed.addAttribute(.backgroundColor, value: Self.color(.clause).withAlphaComponent(0.18), range: range)
            } else {
                let style = annotation.role == .modifier || annotation.role == .adverbial
                    ? NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDash.rawValue
                    : NSUnderlineStyle.single.rawValue
                attributed.addAttributes([.underlineStyle: style, .underlineColor: Self.color(annotation.role)], range: range)
            }
            attributed.addAttribute(.toolTip, value: annotation.role.title + "：" + annotation.explanation, range: range)
        }
        textStorage?.setAttributedString(attributed)
        setAccessibilityLabel(visible.isEmpty ? "原文" : "原句与语法标注")
        setAccessibilityHelp("Tab 遍历语法标注，Return 或空格固定说明，Escape 关闭说明。")
        setAccessibilityCustomActions(visible.map { annotation in
            NSAccessibilityCustomAction(name: annotation.role.title + "：" + annotation.text) { [weak self] in
                MainActor.assumeIsolated {
                    self?.model?.toggleAnnotation(annotation.id)
                    return true
                }
            }
        })
        needsDisplay = true
        invalidateIntrinsicContentSize()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        if let tracking { addTrackingArea(tracking) }
    }

    override func mouseMoved(with event: NSEvent) {
        let annotation = annotation(at: convert(event.locationInWindow, from: nil))
        guard lastHover != annotation?.id else { return }
        lastHover = annotation?.id
        model?.hoverAnnotation(annotation?.id)
    }

    override func mouseExited(with event: NSEvent) {
        lastHover = nil
        model?.hoverAnnotation(nil)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard selectedRange().length == 0,
              let annotation = annotation(at: convert(event.locationInWindow, from: nil)) else { return }
        model?.toggleAnnotation(annotation.id)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted, !visible.isEmpty {
            focusedIndex = 0
            model?.focusAnnotation(visible[0].id)
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        model?.focusAnnotation(nil)
        focusedIndex = nil
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48, !visible.isEmpty {
            let next = (focusedIndex ?? -1) + (event.modifierFlags.contains(.shift) ? -1 : 1)
            if visible.indices.contains(next) {
                focusedIndex = next
                let annotation = visible[next]
                model?.focusAnnotation(annotation.id)
                if let range = layout.nativeRange(of: annotation) {
                    setSelectedRange(range)
                    scrollRangeToVisible(range)
                }
            } else if event.modifierFlags.contains(.shift) {
                window?.selectPreviousKeyView(self)
            } else {
                window?.selectNextKeyView(self)
            }
            return
        }
        if (event.keyCode == 36 || event.keyCode == 49), !event.modifierFlags.contains(.command),
           let focusedIndex, visible.indices.contains(focusedIndex) {
            model?.toggleAnnotation(visible[focusedIndex].id)
            return
        }
        if event.keyCode == 53 { model?.handleEscape(); return }
        super.keyDown(with: event)
    }

    private func annotation(at point: NSPoint) -> GrammarAnnotation? {
        guard let manager = layoutManager, let container = textContainer, manager.numberOfGlyphs > 0 else { return nil }
        let local = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = manager.glyphIndex(for: local, in: container)
        guard glyph < manager.numberOfGlyphs,
              manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container).insetBy(dx: -2, dy: -3).contains(local) else { return nil }
        return layout.annotation(atUTF16: manager.characterIndexForGlyph(at: glyph), includeNested: includeNested)
    }

    static func color(_ role: GrammarRole) -> NSColor {
        switch role {
        case .subject: NSColor(calibratedRed: 0.42, green: 0.83, blue: 1, alpha: 1)
        case .predicate: NSColor(calibratedRed: 1, green: 0.74, blue: 0.42, alpha: 1)
        case .object: NSColor(calibratedRed: 0.5, green: 0.91, blue: 0.64, alpha: 1)
        case .complement, .clause: NSColor(calibratedRed: 0.83, green: 0.7, blue: 1, alpha: 1)
        case .modifier, .adverbial: .init(white: 0.85, alpha: 1)
        }
    }
}
