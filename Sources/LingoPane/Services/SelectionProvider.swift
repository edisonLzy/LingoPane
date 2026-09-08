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

    public private(set) var selectionAnchor: NSPoint?

    public func selectedText() -> String? {
        selectionAnchor = nil
        guard isAccessibilityGranted else { return nil }

        // Capture the app once, before any asynchronous model or panel work can
        // change focus. Querying the system-wide AXFocusedApplication is less
        // reliable for Chromium/Electron processes and can return cannotComplete.
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let targetPID = frontmostApplication?.processIdentifier
        let applicationElement = targetPID.map(AXUIElementCreateApplication)
        if let applicationElement {
            var focusedElement: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                applicationElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedElement
            ) == .success,
            let focusedElement {
                var current: AXUIElement? = (focusedElement as! AXUIElement)
                for _ in 0..<8 {
                    guard let candidate = current else { break }
                    if let selected = accessibilitySelection(from: candidate) {
                        return selected
                    }
                    var parentValue: CFTypeRef?
                    guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parentValue) == .success,
                          let parentValue else { break }
                    current = (parentValue as! AXUIElement)
                }
            }
        }

        // Some browsers and Electron apps don't expose a web-page selection on
        // the focused accessibility element. Copying is the most compatible
        // fallback; preserve the user's clipboard exactly as it was.
        if let selected = copiedSelection(applicationElement: applicationElement, targetPID: targetPID) {
            selectionAnchor = NSEvent.mouseLocation
            return selected
        }
        return nil
    }

    private func accessibilitySelection(from element: AXUIElement) -> String? {
        var selectedValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedValue) == .success,
           let selected = normalized(selectedValue as? String) {
            updateAnchor(for: element, rangeAttribute: kAXSelectedTextRangeAttribute as CFString,
                         boundsAttribute: kAXBoundsForRangeParameterizedAttribute as CFString)
            return selected
        }

        // Web content commonly represents selections with opaque text markers
        // instead of the standard AXSelectedText/AXSelectedTextRange pair.
        let markerRangeAttribute = "AXSelectedTextMarkerRange" as CFString
        var markerRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, markerRangeAttribute, &markerRange) == .success,
              let markerRange else { return nil }

        var markerText: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, "AXStringForTextMarkerRange" as CFString, markerRange, &markerText
        ) == .success,
        let selected = normalized(markerText as? String) else { return nil }

        updateAnchor(for: element, range: markerRange,
                     boundsAttribute: "AXBoundsForTextMarkerRange" as CFString)
        return selected
    }

    private func updateAnchor(
        for element: AXUIElement,
        rangeAttribute: CFString,
        boundsAttribute: CFString
    ) {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, rangeAttribute, &rangeValue) == .success,
              let rangeValue else { return }
        updateAnchor(for: element, range: rangeValue, boundsAttribute: boundsAttribute)
    }

    private func updateAnchor(for element: AXUIElement, range: CFTypeRef, boundsAttribute: CFString) {
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, boundsAttribute, range, &boundsValue
        ) == .success,
        let boundsValue, CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return }
        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect),
              rect.width > 0, rect.height > 0,
              let primary = NSScreen.screens.first else { return }
        selectionAnchor = NSPoint(x: rect.minX, y: primary.frame.maxY - rect.maxY)
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func copiedSelection(applicationElement: AXUIElement?, targetPID: pid_t?) -> String? {
        if let applicationElement,
           let selected = capturePasteboardText(after: { performCopyMenuAction(in: applicationElement) }) {
            return selected
        }
        return capturePasteboardText(after: { postCopyShortcut(to: targetPID) })
    }

    private func capturePasteboardText(after action: () -> Bool) -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { source in
            let copy = NSPasteboardItem()
            for type in source.types {
                if let data = source.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []
        let initialChangeCount = pasteboard.changeCount
        guard action() else { return nil }

        let deadline = Date().addingTimeInterval(0.4)
        while pasteboard.changeCount == initialChangeCount && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
        }
        guard pasteboard.changeCount != initialChangeCount else { return nil }
        let actionChangeCount = pasteboard.changeCount
        let selected = normalized(pasteboard.string(forType: .string))

        // Do not overwrite a clipboard update made by a clipboard manager,
        // screenshot tool, or the user after the copy action completed.
        if pasteboard.changeCount == actionChangeCount {
            restorePasteboard(snapshot)
        }
        return selected
    }

    private func postCopyShortcut(to targetPID: pid_t?) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        if let targetPID {
            keyDown.postToPid(targetPID)
            keyUp.postToPid(targetPID)
        } else {
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
        return true
    }

    private func performCopyMenuAction(in application: AXUIElement) -> Bool {
        var menuBarValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application, kAXMenuBarAttribute as CFString, &menuBarValue
        ) == .success,
        let menuBarValue else { return false }
        guard let item = findCopyMenuItem(in: menuBarValue as! AXUIElement, depth: 0) else { return false }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    private func findCopyMenuItem(in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth <= 5 else { return nil }
        var identifierValue: CFTypeRef?
        var titleValue: CFTypeRef?
        var commandValue: CFTypeRef?
        var enabledValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifierValue)
        _ = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        _ = AXUIElementCopyAttributeValue(element, "AXMenuItemCmdChar" as CFString, &commandValue)
        _ = AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledValue)
        let identifier = identifierValue as? String
        let title = titleValue as? String
        let command = commandValue as? String
        let enabled = enabledValue as? Bool ?? true
        let copyTitles: Set<String> = ["Copy", "复制", "拷贝", "複製", "拷貝"]
        if enabled && (identifier == "copy:" || (command?.uppercased() == "C" && title.map(copyTitles.contains) == true)) {
            return element
        }

        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &childrenValue
        ) == .success,
        let children = childrenValue as? [AXUIElement] else { return nil }
        for child in children {
            if let match = findCopyMenuItem(in: child, depth: depth + 1) { return match }
        }
        return nil
    }

    private func restorePasteboard(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}
