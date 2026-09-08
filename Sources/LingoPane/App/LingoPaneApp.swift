import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let state = AppState.shared
        StatusBarController.shared.configure(state: state)
        HotKeyManager.shared.register {
            AppState.shared.triggerSelectionTranslation()
        }

        if CommandLine.arguments.contains("--preview-multi") {
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

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }
}

@main
struct LingoPaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(state: AppState.shared)
        }
    }
}
