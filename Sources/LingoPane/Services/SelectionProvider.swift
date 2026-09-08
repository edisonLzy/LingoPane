import AppKit
import ApplicationServices

@MainActor
public final class SelectionProvider {
    public static let shared = SelectionProvider()
    private init() {}

    public var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    public func requestAccessibilityPermission() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    public func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    public func selectedText() -> String? {
        guard isAccessibilityGranted else { return nil }

        let system = AXUIElementCreateSystemWide()
        var focusedApplication: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApplication
        ) == .success,
        let application = focusedApplication else { return nil }

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success,
        let element = focusedElement else { return nil }

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success,
        let selected = selectedValue as? String else { return nil }

        let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
