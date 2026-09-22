import AppKit
import SwiftUI

@MainActor
public final class StatusBarController: NSObject {
    public static let shared = StatusBarController()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var state: AppState?

    private override init() {
        super.init()
    }

    public func configure(state: AppState) {
        self.state = state
        if let button = statusItem.button {
            restoreIdleIcon()
            button.target = self
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 430)
        popover.contentViewController = NSHostingController(rootView: QuickInputView(state: state))
    }

    // MARK: - Voice input waveform

    private var voiceVisualizationActive = false

    /// Swaps the menu bar icon for a waveform while the voice hotkey is held.
    public func beginVoiceVisualization() {
        voiceVisualizationActive = true
        statusItem.length = WaveformRenderer.defaultSize.width
        applyWaveform(WaveformRenderer.image(levels: Array(repeating: 0.05, count: WaveformLevels.barCount)))
    }

    public func updateVoiceLevels(_ levels: [Float]) {
        guard voiceVisualizationActive else { return }
        applyWaveform(WaveformRenderer.image(levels: levels))
    }

    public func endVoiceVisualization() {
        guard voiceVisualizationActive else { return }
        voiceVisualizationActive = false
        statusItem.length = NSStatusItem.squareLength
        restoreIdleIcon()
    }

    private func applyWaveform(_ image: NSImage) {
        guard let button = statusItem.button else { return }
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
    }

    private func restoreIdleIcon() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "LingoPane")
        button.imagePosition = .imageOnly
        button.title = ""
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    public func showPopover() {
        guard let button = statusItem.button else { return }
        if let state {
            popover.contentViewController = NSHostingController(rootView: QuickInputView(state: state))
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    public func closePopover() {
        popover.performClose(nil)
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "翻译历史", action: #selector(showHistory), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "整理所有 Panel", action: #selector(arrangePanels), keyEquivalent: "")
        menu.addItem(withTitle: "显示所有 Panel", action: #selector(showPanels), keyEquivalent: "")
        menu.addItem(withTitle: "隐藏全部 Panel", action: #selector(hidePanels), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 LingoPane", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    @objc private func showSettings() {
        guard let state else { return }
        SettingsWindowCoordinator.shared.show(state: state)
    }

    @objc private func showHistory() {
        guard let state else { return }
        HistoryWindowCoordinator.shared.show(state: state)
    }

    @objc private func arrangePanels() { FloatingPanelCoordinator.shared.arrangePinnedPanels() }
    @objc private func showPanels() { FloatingPanelCoordinator.shared.showAll() }
    @objc private func hidePanels() { FloatingPanelCoordinator.shared.hideAll() }
    @objc private func quit() { NSApp.terminate(nil) }
}

@MainActor
public final class SettingsWindowCoordinator {
    public static let shared = SettingsWindowCoordinator()
    public func show(state: AppState) {
        HistoryWindowCoordinator.shared.show(state: state, page: .settings)
    }
}

@MainActor
public final class HistoryWindowCoordinator: NSObject, NSWindowDelegate {
    public static let shared = HistoryWindowCoordinator()
    private var window: NSWindow?
    private let navigation = LibraryNavigation()

    public func show(state: AppState, page: LibraryPage = .history) {
        navigation.page = page
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "LingoPane"
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 1000, height: 680)
        window.contentView = NSHostingView(rootView: HistoryView(state: state, navigation: navigation))
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) { window = nil }
}
