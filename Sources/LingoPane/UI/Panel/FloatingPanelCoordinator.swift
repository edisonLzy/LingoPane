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
    private var localMouseMonitor: Any?
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
        let effectiveWidth = min(max(UserDefaults.standard.object(forKey: "panelWidth") as? Double ?? 400, 360), 480)
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
        window.hasShadow = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.delegate = self

        let entry = Entry(window: window, model: model)
        entries.append(entry)
        model.closeAction = { [weak self, weak model] in
            guard let model else { return }
            self?.close(model: model)
        }
        model.resizeAction = { [weak window, weak model] height in
            guard let window, let model else { return }
            let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
            let newHeight = min(model.isCollapsed ? 78 : max(height, 180), min(560, visible.height))
            guard abs(window.frame.height - newHeight) > 1 else { return }
            var frame = window.frame
            frame.origin.y += frame.height - newHeight
            frame.size.height = newHeight
            frame.origin.y = max(visible.minY, min(frame.origin.y, visible.maxY - newHeight))
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                window.setFrame(frame, display: true)
            } else {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.22
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(frame, display: true)
                }
            }
        }
        model.pinAction = { [weak self, weak model] in
            guard let self, let model else { return }
            if !model.isPinned && self.entries.filter({ $0.model.isPinned }).count >= 8 {
                model.notice = "最多固定 8 个 Panel，请先取消固定或关闭一个。"
                return
            }
            model.notice = nil
            model.isPinned.toggle()
            if !model.isPinned {
                model.isCollapsed = false
                self.entries.filter { !$0.model.isPinned && $0.model.id != model.id }.forEach { self.close(model: $0.model) }
            }
        }
        model.switchKindAction = { [weak model] kind in
            guard let model else { return }
            let language: Language = kind == .chinese ? .chinese : .english
            let override = Classification(language: language, kind: kind)
            model.classification = override
            AppState.shared.translate(model.source, near: model.windowAnchor, classificationOverride: override, scene: model.scene, target: model)
        }

        window.contentView = NSHostingView(rootView: PanelView(model: model))
        position(window, near: point)
        window.orderFrontRegardless()
        return model
    }

    public func close(model: PanelViewModel) {
        guard let index = entries.firstIndex(where: { $0.model.id == model.id }) else { return }
        model.cancelAction?()
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
            .filter { $0.model.isPinned && $0.window.isVisible && $0.window.isOnActiveSpace }
            .sorted { $0.createdAt > $1.createdAt }
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frames = PanelArrangement.frames(sizes: pinned.map { $0.window.frame.size }, in: visible)
        if frames == nil {
            pinned.forEach { $0.model.isCollapsed = true }
            frames = PanelArrangement.frames(sizes: pinned.map { NSSize(width: $0.window.frame.width, height: 78) }, in: visible)
            pinned.forEach { $0.model.notice = "已整理 \(pinned.count) 个 Panel；空间不足，已折叠为标题态。" }
        }
        guard let frames else { return }
        for (entry, frame) in zip(pinned, frames) {
            entry.window.setFrame(frame, display: true)
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

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let windowNumber = event.windowNumber
            Task { @MainActor in
                guard let self else { return }
                let defaults = UserDefaults.standard
                guard defaults.object(forKey: "closeTemporaryOnBlur") == nil || defaults.bool(forKey: "closeTemporaryOnBlur") else { return }
                self.entries.filter { !$0.model.isPinned && $0.window.windowNumber != windowNumber }
                    .forEach { self.close(model: $0.model) }
            }
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard event.keyCode == 53,
                      let model = self?.entries.first(where: { $0.window.isKeyWindow && $0.window == event.window })?.model else { return false }
                model.handleEscape()
                return true
            }
            return handled ? nil : event
        }
    }
}
