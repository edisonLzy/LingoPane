import SwiftUI
import AppKit

/// 原生应用代理（在应用启动时注册全局快捷键 ⌥ Space）
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 注册全局快捷键 ⌥ Space (Option + Space)
        HotKeyManager.shared.register {
            Task { @MainActor in
                AppState.shared.triggerSelectionTranslation()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }
}

/// 窗口透明度与物理特性配置器（让 Liquid Glass 能够透视桌面背景）
public struct WindowConfigurator: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
                window.hasShadow = true
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}

@main
struct TranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState.shared

    var body: some Scene {
        // 主应用独立浮窗
        WindowGroup {
            MainTranslatorView(state: appState)
                .background(WindowConfigurator())
                .preferredColorScheme(appState.settings.isLightMode ? .light : .dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 600)

        // 状态栏常驻图标与快捷交互浮窗 (MenuBarExtra)
        MenuBarExtra("AI 翻译", systemImage: "character.bubble.fill") {
            MainTranslatorView(state: appState)
                .preferredColorScheme(appState.settings.isLightMode ? .light : .dark)
                .frame(width: 440, height: 580)
        }
        .menuBarExtraStyle(.window)
    }
}
