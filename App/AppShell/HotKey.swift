import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut (FR-35: ⌥⌘F opens search). Carbon's hot-key API needs no permission.
@MainActor
final class HotKey {
    struct Combo: Equatable {
        var keyCode: UInt32
        var modifiers: UInt32 // Carbon flags

        static let defaultSearch = Combo(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(optionKey | cmdKey))

        init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }

        init?(storage: String) {
            let parts = storage.split(separator: ":").compactMap { UInt32($0) }
            guard parts.count == 2 else { return nil }
            self.init(keyCode: parts[0], modifiers: parts[1])
        }

        /// From a key press in the shortcut recorder. Needs ⌘, ⌥ or ⌃ so it can't swallow typing.
        init?(event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var carbon: UInt32 = 0
            if flags.contains(.command) { carbon |= UInt32(cmdKey) }
            if flags.contains(.option) { carbon |= UInt32(optionKey) }
            if flags.contains(.control) { carbon |= UInt32(controlKey) }
            if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
            guard carbon & UInt32(cmdKey | optionKey | controlKey) != 0 else { return nil }
            self.init(keyCode: UInt32(event.keyCode), modifiers: carbon)
            label = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        }

        var storage: String { "\(keyCode):\(modifiers)" }
        private var label: String?

        /// "⌥ ⌘ F"
        var display: String {
            var symbols = ""
            if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
            if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
            if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
            if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
            return symbols + (label ?? Self.keyName(keyCode))
        }

        static func == (a: Combo, b: Combo) -> Bool { a.keyCode == b.keyCode && a.modifiers == b.modifiers }

        /// The letter or digit on a key, for display.
        static func keyName(_ code: UInt32) -> String {
            let names: [Int: String] = [kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
                kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K",
                kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q",
                kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W",
                kVK_ANSI_X: "X", kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z", kVK_Space: "Space"]
            return names[Int(code)] ?? "Key \(code)"
        }
    }

    var action: (() -> Void)?
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func register(_ combo: Combo) {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
                guard let context else { return noErr }
                let hotKey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async { MainActor.assumeIsolated { hotKey.action?() } }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        RegisterEventHotKey(combo.keyCode, combo.modifiers, EventHotKeyID(signature: OSType(0x464C_4248), id: 1),
                            GetApplicationEventTarget(), 0, &reference)
    }
}
