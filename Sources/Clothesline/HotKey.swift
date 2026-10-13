import AppKit
import Carbon

/// Carbon global hot key: no Accessibility permission is needed.
final class HotKey {
    private var reference: EventHotKeyRef?
    private static var action: (() -> Void)?
    private static var installed = false

    init?(action: @escaping () -> Void) {
        Self.action = action
        if !Self.installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                     eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { HotKey.action?() }
                return noErr
            }, 1, &spec, nil, nil)
            Self.installed = true
        }
        let id = EventHotKeyID(signature: 0x434C_4F54, id: 1) // CLOT
        let modifiers = UInt32(controlKey | optionKey)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_T), modifiers,
                                        id, GetApplicationEventTarget(), 0, &reference)
        guard result == noErr, reference != nil else { return nil }
    }
    deinit { if let reference { UnregisterEventHotKey(reference) } }
}
