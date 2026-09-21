import AppKit
import Carbon
import Foundation

public struct HotKeyShortcut: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifierFlags: UInt
    public let keyLabel: String

    public init(keyCode: UInt32, modifierFlags: UInt, keyLabel: String) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.keyLabel = keyLabel
    }

    public static let `default` = HotKeyShortcut(
        keyCode: UInt32(kVK_Space),
        modifierFlags: NSEvent.ModifierFlags.option.rawValue,
        keyLabel: "Space"
    )

    public var displayName: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var value = ""
        if flags.contains(.control) { value += "⌃" }
        if flags.contains(.option) { value += "⌥" }
        if flags.contains(.shift) { value += "⇧" }
        if flags.contains(.command) { value += "⌘" }
        return value + keyLabel
    }

    var carbonModifiers: UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var value: UInt32 = 0
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        return value
    }

    static func from(event: NSEvent) -> HotKeyShortcut? {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !flags.isEmpty else { return nil }
        return HotKeyShortcut(
            keyCode: UInt32(event.keyCode),
            modifierFlags: flags.rawValue,
            keyLabel: keyLabel(for: event)
        )
    }

    private static func keyLabel(for event: NSEvent) -> String {
        let special: [UInt16: String] = [
            UInt16(kVK_Space): "Space",
            UInt16(kVK_Return): "↩",
            UInt16(kVK_Tab): "⇥",
            UInt16(kVK_Delete): "⌫",
            UInt16(kVK_ForwardDelete): "⌦",
            UInt16(kVK_Home): "↖",
            UInt16(kVK_End): "↘",
            UInt16(kVK_PageUp): "⇞",
            UInt16(kVK_PageDown): "⇟",
            UInt16(kVK_LeftArrow): "←",
            UInt16(kVK_RightArrow): "→",
            UInt16(kVK_UpArrow): "↑",
            UInt16(kVK_DownArrow): "↓",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
            UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
            UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12"
        ]
        if let label = special[event.keyCode] { return label }
        let characters = event.charactersIgnoringModifiers?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        return characters.isEmpty ? "Key \(event.keyCode)" : characters
    }
}

enum HotKeyPreferences {
    private static let keyCodeKey = "globalHotKey.keyCode"
    private static let modifiersKey = "globalHotKey.modifiers"
    private static let labelKey = "globalHotKey.label"

    static var current: HotKeyShortcut {
        guard UserDefaults.standard.object(forKey: keyCodeKey) != nil else { return .default }
        return HotKeyShortcut(
            keyCode: UInt32(UserDefaults.standard.integer(forKey: keyCodeKey)),
            modifierFlags: UInt(UserDefaults.standard.integer(forKey: modifiersKey)),
            keyLabel: UserDefaults.standard.string(forKey: labelKey) ?? "Key"
        )
    }

    static func save(_ shortcut: HotKeyShortcut) {
        UserDefaults.standard.set(Int(shortcut.keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(shortcut.modifierFlags), forKey: modifiersKey)
        UserDefaults.standard.set(shortcut.keyLabel, forKey: labelKey)
    }
}

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var action: (() -> Void)?

    private init() {}

    @discardableResult
    public func register(action: @escaping () -> Void) -> Bool {
        removeRegistration()
        self.action = action
        return install(HotKeyPreferences.current) == noErr
    }

    @discardableResult
    public func updateShortcut(_ shortcut: HotKeyShortcut) -> Bool {
        let previous = HotKeyPreferences.current
        removeRegistration()
        let status = install(shortcut)
        if status == noErr {
            HotKeyPreferences.save(shortcut)
            return true
        }
        removeRegistration()
        _ = install(previous)
        return false
    }

    public func unregister() {
        removeRegistration()
        action = nil
    }

    private func install(_ shortcut: HotKeyShortcut) -> OSStatus {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in manager.action?() }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
        guard handlerStatus == noErr else { return handlerStatus }

        let identifier = EventHotKeyID(signature: OSType(0x4C50414E), id: 1) // LPAN
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetEventDispatcherTarget(),
            0,
            &hotKey
        )
        if status != noErr { removeRegistration() }
        return status
    }

    private func removeRegistration() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil
        eventHandler = nil
    }
}
