import Carbon
import AppKit

/// Registers a global hotkey (Cmd+Shift+2) using the Carbon EventHotKey API.
/// Does NOT require Accessibility permission — works purely at the Carbon event layer.
@MainActor
final class HotkeyManager {

    var onFire: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // We need a way to route the C callback back to this Swift object.
    // Store a raw pointer in a static so the C callback can reach it.
    private static var shared: HotkeyManager?

    func register() {
        HotkeyManager.shared = self

        // Install event handler on the application event target
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in
                // Route to main thread; Carbon callbacks are on the main thread already
                // when using NSApplicationMain, but be explicit.
                DispatchQueue.main.async {
                    HotkeyManager.shared?.onFire?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard status == noErr else {
            NSLog("SnapMark: Failed to install hotkey event handler: \(status)")
            return
        }

        // Cmd+Shift+2 — keyCode 19 is '2' on US layout
        let hotKeyID = EventHotKeyID(signature: 0x534D_4832, id: 1) // 'SMH2'
        let regStatus = RegisterEventHotKey(
            19,                            // keyCode for '2'
            UInt32(cmdKey | shiftKey),     // Cmd + Shift
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus != noErr {
            NSLog("SnapMark: Failed to register hotkey: \(regStatus)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        HotkeyManager.shared = nil
    }
}
