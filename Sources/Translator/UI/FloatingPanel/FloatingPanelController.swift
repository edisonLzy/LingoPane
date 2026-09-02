import SwiftUI
import AppKit

/// 自定义悬浮毛玻璃 Panel（支持输入焦点与跨 App 独立悬浮）
final class CustomFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 悬浮毛玻璃 Panel 控制器（遵循 PRD 第 6 节规范：光标就近弹出、非侵入式、失焦/Esc 自动关闭）
@MainActor
public final class FloatingPanelController: NSWindowController, NSWindowDelegate {
    public static let shared = FloatingPanelController()

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var appState: AppState?

    private init() {
        // 创建无标题栏、透明且不随 App 失焦隐藏的 CustomFloatingPanel
        let panel = CustomFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false // 核心修复：确保其他应用活跃时不会被系统隐藏
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 在鼠标光标附近展示悬浮浮窗
    public func showNearMouse(with state: AppState) {
        self.appState = state
        guard let panel = window else { return }

        let rootView = FloatingPanelView(state: state) { [weak self] in
            self?.closePanel()
        }
        panel.contentView = NSHostingView(rootView: rootView)

        // 计算就近弹出位置（遵循 PRD 6.1）
        let mouseLocation = NSEvent.mouseLocation
        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 480

        // 默认置于鼠标右下方偏离 12pt 处
        var originX = mouseLocation.x + 12
        var originY = mouseLocation.y - panelHeight - 12

        // 获取鼠标所在屏幕边界做越界钳制
        if let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            if originX + panelWidth > visibleFrame.maxX {
                originX = mouseLocation.x - panelWidth - 12
            }
            if originY < visibleFrame.minY {
                originY = mouseLocation.y + 16
            }
        }

        panel.setFrame(NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight), display: true)
        panel.orderFrontRegardless()

        installEventMonitors()
    }

    public func closePanel() {
        removeEventMonitors()
        window?.orderOut(nil)
    }

    // MARK: - 点击外部或按 Esc 自动退出（PRD 6.1）
    private func installEventMonitors() {
        removeEventMonitors()

        // 监听全局鼠标点击（点击浮窗外自动隐退）
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.window, window.isVisible else { return }
            let clickLocation = NSEvent.mouseLocation
            if !NSPointInRect(clickLocation, window.frame) {
                self.closePanel()
            }
        }

        // 监听键盘 Esc 按键
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // 53 = Esc
                self?.closePanel()
                return nil
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
            globalMonitor = nil
        }
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
    }
}
