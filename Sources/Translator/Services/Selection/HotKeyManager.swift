import Foundation
import Carbon
import AppKit

/// 全局热键监听器（使用 Carbon EventDispatcherTarget 实现系统级全局 ⌥ Space 与 ⌥ D 监听）
@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefSpace: EventHotKeyRef?
    private var hotKeyRefD: EventHotKeyRef?
    private var onHotKeyPressed: (() -> Void)?

    private init() {}

    /// 注册全局热键 (⌥ Space 与 ⌥ D 作为双保险快捷键)
    public func register(handler: @escaping () -> Void) {
        self.onHotKeyPressed = handler

        // 1. 安装系统级全局 Carbon Event Handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(), // 关键：使用全局分发器，确保后台无焦点时也能捕获
            { (_, inEvent, inUserData) -> OSStatus in
                guard let inUserData = inUserData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(inUserData).takeUnretainedValue()
                Task { @MainActor in
                    print("[HotKeyManager] 全局热键触发！")
                    manager.onHotKeyPressed?()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        if handlerStatus != noErr {
            print("[HotKeyManager] InstallEventHandler failed: \(handlerStatus)")
        }

        // 2. 注册 ⌥ Space (Option + Space: keyCode 49, modifier optionKey)
        let hotKeyIDSpace = EventHotKeyID(signature: OSType(0x5452414E), id: 1) // 'TRAN', 1
        let statusSpace = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyIDSpace,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRefSpace
        )
        print("[HotKeyManager] Register ⌥ Space status: \(statusSpace)")

        // 3. 注册 ⌥ D (Option + D: keyCode 2, modifier optionKey) 作为双保险备选
        let hotKeyIDD = EventHotKeyID(signature: OSType(0x5452414E), id: 2) // 'TRAN', 2
        let statusD = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(optionKey),
            hotKeyIDD,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRefD
        )
        print("[HotKeyManager] Register ⌥ D status: \(statusD)")
    }

    public func unregister() {
        if let ref = hotKeyRefSpace {
            UnregisterEventHotKey(ref)
            self.hotKeyRefSpace = nil
        }
        if let ref = hotKeyRefD {
            UnregisterEventHotKey(ref)
            self.hotKeyRefD = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}
