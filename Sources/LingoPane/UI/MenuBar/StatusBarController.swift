import AppKit
import SwiftUI

@MainActor
public final class StatusBarController: NSObject {
    public static let shared = StatusBarController()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var state: AppState?

    private override init() {
        super.init()
    }

    public func configure(state: AppState) {
        self.state = state
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "LingoPane")
            button.imagePosition = .imageLeading
            button.title = "LingoPane"
            button.target = self
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 430)
        popover.contentViewController = NSHostingController(rootView: QuickInputView(state: state))
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
public final class SettingsWindowCoordinator: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowCoordinator()
    private var window: NSWindow?

    public func show(state: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 590),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LingoPane 设置"
        window.contentView = NSHostingView(rootView: SettingsView(state: state))
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) { window = nil }
}

@MainActor
public final class HistoryWindowCoordinator: NSObject, NSWindowDelegate {
    public static let shared = HistoryWindowCoordinator()
    private var window: NSWindow?

    public func show(state: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 470),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "翻译历史"
        window.contentView = NSHostingView(rootView: HistoryView(state: state))
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) { window = nil }
}
