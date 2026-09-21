import AppKit
import Carbon
import SwiftUI

struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var shortcut: HotKeyShortcut
    let onCommit: (HotKeyShortcut) -> Bool
    let onFailure: () -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        button.setButtonType(.momentaryPushIn)
        button.target = button
        button.action = #selector(RecorderButton.beginRecording)
        button.setAccessibilityLabel("录制全局快捷键")
        button.setAccessibilityHelp("按下后输入新的全局快捷键组合")
        button.onShortcut = { candidate in
            if onCommit(candidate) {
                shortcut = candidate
                return true
            }
            onFailure()
            return false
        }
        button.shortcut = shortcut
        button.title = shortcut.displayName
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        button.shortcut = shortcut
        if !button.isRecording { button.title = shortcut.displayName }
    }
}

final class RecorderButton: NSButton {
    var shortcut: HotKeyShortcut = .default
    var onShortcut: ((HotKeyShortcut) -> Bool)?
    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    @objc func beginRecording() {
        isRecording = true
        title = "请按新快捷键…"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            finishRecording()
            return
        }
        guard let candidate = HotKeyShortcut.from(event: event) else {
            NSSound.beep()
            title = "需要至少一个修饰键"
            return
        }
        if onShortcut?(candidate) == true {
            shortcut = candidate
            finishRecording()
        } else {
            NSSound.beep()
            title = "快捷键已被占用"
        }
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result && isRecording {
            isRecording = false
            title = shortcut.displayName
        }
        return result
    }

    private func finishRecording() {
        isRecording = false
        title = shortcut.displayName
        window?.makeFirstResponder(nil)
    }
}
