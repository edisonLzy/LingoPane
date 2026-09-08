import AppKit
import SwiftUI

final class LingoFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class FloatingPanelCoordinator: NSObject, NSWindowDelegate {
    public static let shared = FloatingPanelCoordinator()

    private final class Entry {
        let window: LingoFloatingPanel
        let model: PanelViewModel
        let createdAt = Date()

        init(window: LingoFloatingPanel, model: PanelViewModel) {
            self.window = window
            self.model = model
        }
    }

    private var entries: [Entry] = []
    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?

    private override init() {
        super.init()
        installMonitors()
    }

    @discardableResult
    public func presentLoading(
        source: String,
        classification: Classification,
        near point: NSPoint
    ) -> PanelViewModel {
        if let temporary = entries.first(where: { !$0.model.isPinned }) {
            temporary.model.start(source: source, classification: classification)
            temporary.model.windowAnchor = point
            position(temporary.window, near: point)
            temporary.window.orderFrontRegardless()
            return temporary.model
        }

        let model = PanelViewModel(source: source, classification: classification)
        model.windowAnchor = point
        let width = min(max(UserDefaults.standard.double(forKey: "panelWidth"), 360), 480)
        let effectiveWidth = width == 360 ? 400 : width
        let window = LingoFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: effectiveWidth, height: 500),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self

        let entry = Entry(window: window, model: model)
        entries.append(entry)
        model.closeAction = { [weak self, weak model] in
            guard let model else { return }
            self?.close(model: model)
        }
        model.pinAction = { [weak model] in model?.isPinned.toggle() }
        model.switchKindAction = { [weak model] kind in
            guard let model else { return }
            let language: Language = kind == .chinese ? .chinese : .english
            let override = Classification(language: language, kind: kind)
            model.classification = override
            AppState.shared.translate(model.source, near: model.windowAnchor, classificationOverride: override)
        }

        window.contentView = NSHostingView(rootView: PanelView(model: model))
        position(window, near: point)
        window.orderFrontRegardless()
        return model
    }

    public func close(model: PanelViewModel) {
        guard let index = entries.firstIndex(where: { $0.model.id == model.id }) else { return }
        let entry = entries.remove(at: index)
        entry.window.orderOut(nil)
        entry.window.contentView = nil
    }

    public func hideAll() {
        entries.forEach { $0.window.orderOut(nil) }
    }

    public func showAll() {
        entries.forEach { $0.window.orderFrontRegardless() }
    }

    public func arrangePinnedPanels() {
        let pinned = entries
            .filter { $0.model.isPinned && $0.window.isVisible }
            .sorted { $0.createdAt > $1.createdAt }
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let spacing: CGFloat = 12
        var x = visible.maxX
        var y = visible.maxY
        var columnWidth: CGFloat = 0

        for entry in pinned {
            let size = entry.window.frame.size
            if y - size.height < visible.minY {
                x -= columnWidth + spacing
                y = visible.maxY
                columnWidth = 0
            }
            let origin = NSPoint(x: x - size.width, y: y - size.height)
            entry.window.setFrameOrigin(origin)
            y -= size.height + spacing
            columnWidth = max(columnWidth, size.width)
        }
    }

    public func visiblePanelCount() -> Int { entries.filter(\.window.isVisible).count }

    private func position(_ window: NSWindow, near point: NSPoint) {
        let size = window.frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        var origin = NSPoint(x: point.x + 12, y: point.y - size.height - 12)
        if origin.x + size.width > visible.maxX { origin.x = point.x - size.width - 12 }
        if origin.y < visible.minY { origin.y = point.y + 16 }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        window.setFrameOrigin(origin)
    }

    private func installMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let defaults = UserDefaults.standard
                let shouldClose = defaults.object(forKey: "closeTemporaryOnBlur") == nil
                    || defaults.bool(forKey: "closeTemporaryOnBlur")
                guard shouldClose else { return }
                let point = NSEvent.mouseLocation
                self.entries
                    .filter { !$0.model.isPinned && $0.window.isVisible && !$0.window.frame.contains(point) }
                    .forEach { self.close(model: $0.model) }
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in
                guard let model = self?.entries.first(where: { $0.window.isKeyWindow })?.model else { return }
                model.handleEscape()
            }
            return nil
        }
    }
}
