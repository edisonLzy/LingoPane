import Foundation
import AppKit
import ApplicationServices

/// 跨应用划词文本提取器（遵循 PRD 3.1 #3, #4, #5 & 12 节规范）
@MainActor
public final class SelectionProvider {
    public static let shared = SelectionProvider()

    private init() {}

    /// 检查是否拥有辅助功能权限 (Accessibility Permissions)
    public var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// 打开 macOS 系统设置对应的辅助功能隐私页面
    public func promptForAccessibilityPermissions() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options: NSDictionary = [promptKey: true]
        _ = AXIsProcessTrustedWithOptions(options)

        // 同时打开系统设置页面
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 获取当前任意活跃应用中选中的文本 (优先 Accessibility API，失败走 ⌘C 兜底)
    public func getSelectedText() async -> String? {
        // 1. 优先尝试 Accessibility API 抓取
        if let axText = getSelectedTextViaAccessibility(), !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return axText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. 兜底方案：模拟 ⌘C 并保护性还原用户剪贴板
        return await simulateCopyAndFetchText()
    }

    // MARK: - 1. 原生 Accessibility API 抓取
    private func getSelectedTextViaAccessibility() -> String? {
        guard isAccessibilityGranted else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success, let app = focusedApp else { return nil }

        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard elementResult == .success, let element = focusedElement else { return nil }

        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        if textResult == .success, let text = selectedTextValue as? String {
            return text
        }

        return nil
    }

    // MARK: - 2. 模拟 ⌘C 复制兜底 (并恢复剪贴板)
    private func simulateCopyAndFetchText() async -> String? {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        // 暂存原剪贴板内容以备后续恢复
        let savedItems: [(NSPasteboard.PasteboardType, Data)] = pasteboard.pasteboardItems?.flatMap { item in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        } ?? []

        // 发送虚拟 Command + C 键盘事件
        let source = CGEventSource(stateID: .hidSystemState)
        let cKeyCode: CGKeyCode = 0x08 // 'C' key

        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false) else {
            return nil
        }

        cmdDown.flags = .maskCommand
        cmdUp.flags = .maskCommand

        cmdDown.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)

        // 等待剪贴板变化 (最多轮询 120ms)
        var capturedText: String? = nil
        for _ in 0..<12 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            if pasteboard.changeCount != initialChangeCount {
                if let str = pasteboard.string(forType: .string), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    capturedText = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }

        // 恢复用户原本的剪贴板内容，做到完全无感
        if !savedItems.isEmpty {
            pasteboard.clearContents()
            for (type, data) in savedItems {
                pasteboard.setData(data, forType: type)
            }
        }

        return capturedText
    }
}
