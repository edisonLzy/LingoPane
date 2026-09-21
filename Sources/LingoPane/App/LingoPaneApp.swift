import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let idx = CommandLine.arguments.firstIndex(of: "--render-library"), idx + 1 < CommandLine.arguments.count {
            let outPath = CommandLine.arguments[idx + 1]
            let state = AppState.shared
            state.reloadHistory()
            let hosting = NSHostingView(rootView: HistoryView(state: state, navigation: LibraryNavigation()).frame(width: 1120, height: 740))
            hosting.frame = NSRect(x: 0, y: 0, width: 1120, height: 740)
            hosting.layoutSubtreeIfNeeded()
            if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: outPath))
                }
            }
            exit(0)
        }

        if let idx = CommandLine.arguments.firstIndex(of: "--render-settings"), idx + 1 < CommandLine.arguments.count {
            let outPath = CommandLine.arguments[idx + 1]
            let state = AppState.shared
            state.reloadHistory()
            let nav = LibraryNavigation()
            nav.page = .settings
            let hosting = NSHostingView(rootView: HistoryView(state: state, navigation: nav).frame(width: 1120, height: 740))
            hosting.frame = NSRect(x: 0, y: 0, width: 1120, height: 740)
            hosting.layoutSubtreeIfNeeded()
            if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: outPath))
                }
            }
            exit(0)
        }

        NSApp.setActivationPolicy(.accessory)
        let state = AppState.shared
        StatusBarController.shared.configure(state: state)
        HotKeyManager.shared.register {
            AppState.shared.triggerSelectionTranslation()
        }

        let isPreview = CommandLine.arguments.contains { $0.hasPrefix("--preview") }
        if !isPreview && !UserDefaults.standard.bool(forKey: "hasShownInitialLaunchUI") {
            UserDefaults.standard.set(true, forKey: "hasShownInitialLaunchUI")
            DispatchQueue.main.async {
                StatusBarController.shared.showPopover()
            }
        }

        if CommandLine.arguments.contains("--preview-library") {
            DispatchQueue.main.async {
                HistoryWindowCoordinator.shared.show(state: state)
            }
        } else if CommandLine.arguments.contains("--preview-multi") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                let samples: [(String, NSPoint)] = [
                    ("The feature that we discussed yesterday has been implemented.", NSPoint(x: 90, y: 900)),
                    ("architecture", NSPoint(x: 550, y: 900)),
                    ("我们可以先把这个作为兜底方案。", NSPoint(x: 1_010, y: 900))
                ]
                for (text, anchor) in samples {
                    let classification = state.classifier.classify(text)
                    let model = FloatingPanelCoordinator.shared.presentLoading(
                        source: text,
                        classification: classification,
                        near: anchor
                    )
                    model.isPinned = true
                    state.translate(text, near: anchor, target: model)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    FloatingPanelCoordinator.shared.arrangePinnedPanels()
                }
            }
        } else if CommandLine.arguments.contains("--preview-word") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                state.translate("architecture")
            }
        } else if CommandLine.arguments.contains("--preview-chinese") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                state.translate("我们可以先把这个作为兜底方案。")
            }
        } else if CommandLine.arguments.contains("--preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                state.translate("The feature that we discussed yesterday has been implemented.")
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StatusBarController.shared.showPopover()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }
}

@main
struct LingoPaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let settingsNavigation: LibraryNavigation = {
        let navigation = LibraryNavigation()
        navigation.page = .settings
        return navigation
    }()

    var body: some Scene {
        Settings {
            HistoryView(state: AppState.shared, navigation: settingsNavigation)
        }
    }
}
