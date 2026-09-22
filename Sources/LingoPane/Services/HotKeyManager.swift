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

/// Preferences for the push-to-talk voice input shortcut (hold to record).
enum VoiceHotKeyPreferences {
    private static let keyCodeKey = "voiceHotKey.keyCode"
    private static let modifiersKey = "voiceHotKey.modifiers"
    private static let labelKey = "voiceHotKey.label"

    static let defaultShortcut = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifierFlags: NSEvent.ModifierFlags.option.rawValue,
        keyLabel: "V"
    )

    static var current: HotKeyShortcut {
        guard UserDefaults.standard.object(forKey: keyCodeKey) != nil else { return defaultShortcut }
        return HotKeyShortcut(
            keyCode: UInt32(UserDefaults.standard.integer(forKey: keyCodeKey)),
            modifierFlags: UInt(UserDefaults.standard.integer(forKey: modifiersKey)),
            keyLabel: UserDefaults.standard.string(forKey: labelKey) ?? "V"
        )
    }

    static func save(_ shortcut: HotKeyShortcut) {
        UserDefaults.standard.set(Int(shortcut.keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(shortcut.modifierFlags), forKey: modifiersKey)
        UserDefaults.standard.set(shortcut.keyLabel, forKey: labelKey)
    }
}

/// Shared Carbon event handler for every registered hotkey. It resolves the
/// `EventHotKeyID` of the event so `HotKeyManager` can route press/release
/// to the matching registration.
private func lingoPaneHotKeyEventHandler(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let event else { return noErr }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return noErr }
    let kind = UInt32(GetEventKind(event))
    Task { @MainActor in
        manager.dispatch(hotKeyID: hotKeyID.id, kind: kind)
    }
    return noErr
}

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()

    public enum Kind: UInt32 {
        case translation = 1
        case voice = 2
    }

    private final class Registration {
        var shortcut: HotKeyShortcut
        var onPress: (() -> Void)?
        var onRelease: (() -> Void)?
        var hotKey: EventHotKeyRef?

        init(shortcut: HotKeyShortcut, onPress: (() -> Void)?, onRelease: (() -> Void)?) {
            self.shortcut = shortcut
            self.onPress = onPress
            self.onRelease = onRelease
        }
    }

    private var registrations: [UInt32: Registration] = [:]
    private var pressHandler: EventHandlerRef?
    private var releaseHandler: EventHandlerRef?

    private init() {}

    /// Registers the selection-translation shortcut (press-only semantics).
    @discardableResult
    public func register(action: @escaping () -> Void) -> Bool {
        register(id: .translation, shortcut: HotKeyPreferences.current, onPress: action, onRelease: nil)
    }

    /// Registers the push-to-talk voice shortcut: press starts recording,
    /// release stops it and triggers speech-to-text.
    @discardableResult
    public func registerVoice(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> Bool {
        register(id: .voice, shortcut: VoiceHotKeyPreferences.current, onPress: onPress, onRelease: onRelease)
    }

    @discardableResult
    public func updateShortcut(_ shortcut: HotKeyShortcut) -> Bool {
        update(id: .translation, shortcut: shortcut, save: HotKeyPreferences.save)
    }

    @discardableResult
    public func updateVoiceShortcut(_ shortcut: HotKeyShortcut) -> Bool {
        update(id: .voice, shortcut: shortcut, save: VoiceHotKeyPreferences.save)
    }

    public func unregister() {
        for id in Array(registrations.keys) { removeRegistration(id: id) }
        if let pressHandler { RemoveEventHandler(pressHandler) }
        if let releaseHandler { RemoveEventHandler(releaseHandler) }
        pressHandler = nil
        releaseHandler = nil
    }

    // MARK: - Registration plumbing

    private func register(id: Kind, shortcut: HotKeyShortcut, onPress: (() -> Void)?, onRelease: (() -> Void)?) -> Bool {
        removeRegistration(id: id.rawValue)
        guard installHandlers() == noErr else { return false }
        let registration = Registration(shortcut: shortcut, onPress: onPress, onRelease: onRelease)
        registrations[id.rawValue] = registration
        guard install(id: id.rawValue, shortcut: shortcut) == noErr else {
            registrations[id.rawValue] = nil
            return false
        }
        return true
    }

    private func update(id: Kind, shortcut: HotKeyShortcut, save: (HotKeyShortcut) -> Void) -> Bool {
        guard let registration = registrations[id.rawValue] else { return false }
        let previous = registration.shortcut
        if let hotKey = registration.hotKey {
            UnregisterEventHotKey(hotKey)
            registration.hotKey = nil
        }
        if install(id: id.rawValue, shortcut: shortcut) == noErr {
            registration.shortcut = shortcut
            save(shortcut)
            return true
        }
        _ = install(id: id.rawValue, shortcut: previous)
        return false
    }

    /// Installs one shared handler per Carbon event kind. Both handlers use
    /// the same function, which resolves the hotkey id and hops to the main
    /// actor before running user callbacks.
    private func installHandlers() -> OSStatus {
        if pressHandler != nil, releaseHandler != nil { return noErr }
        if let pressHandler { RemoveEventHandler(pressHandler) }
        if let releaseHandler { RemoveEventHandler(releaseHandler) }
        pressHandler = nil
        releaseHandler = nil

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        var pressed = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pressStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            lingoPaneHotKeyEventHandler,
            1,
            &pressed,
            pointer,
            &pressHandler
        )
        guard pressStatus == noErr else {
            pressHandler = nil
            return pressStatus
        }

        var released = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyReleased)
        )
        let releaseStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            lingoPaneHotKeyEventHandler,
            1,
            &released,
            pointer,
            &releaseHandler
        )
        if releaseStatus != noErr {
            RemoveEventHandler(pressHandler)
            pressHandler = nil
            releaseHandler = nil
            return releaseStatus
        }
        return noErr
    }

    private func install(id: UInt32, shortcut: HotKeyShortcut) -> OSStatus {
        let identifier = EventHotKeyID(signature: OSType(0x4C50414E), id: id) // LPAN
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr { registrations[id]?.hotKey = hotKeyRef }
        return status
    }

    private func removeRegistration(id: UInt32) {
        guard let registration = registrations[id] else { return }
        if let hotKey = registration.hotKey { UnregisterEventHotKey(hotKey) }
        registrations[id] = nil
    }

    fileprivate func dispatch(hotKeyID: UInt32, kind: UInt32) {
        guard let registration = registrations[hotKeyID] else { return }
        switch kind {
        case UInt32(kEventHotKeyPressed): registration.onPress?()
        case UInt32(kEventHotKeyReleased): registration.onRelease?()
        default: break
        }
    }
}
