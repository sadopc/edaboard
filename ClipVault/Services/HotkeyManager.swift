import Foundation
import Carbon.HIToolbox
import AppKit

/// Errors that can occur during hotkey operations
enum HotkeyError: Error {
    case registrationFailed
    case accessibilityPermissionRequired
    case hotkeyInUse(by: String)
}

/// Manager for global keyboard shortcuts using Carbon API.
/// Requires Accessibility permission for operation.
@MainActor
final class HotkeyManager {

    // MARK: - Singleton

    static let shared = HotkeyManager()

    // MARK: - Properties

    /// Callback when hotkey is pressed
    var onHotkeyPressed: (() -> Void)?

    /// Current registration status
    private(set) var isRegistered = false

    /// The registered hotkey reference
    private var hotkeyRef: EventHotKeyRef?

    /// The event handler reference
    private var eventHandler: EventHandlerRef?

    /// Current key code
    private var currentKeyCode: UInt32 = 0

    /// Current modifiers
    private var currentModifiers: UInt32 = 0

    // MARK: - Hotkey Signature

    /// Unique signature for our hotkey
    private let hotkeySignature: OSType = {
        // "CLPV" as OSType
        let c = UInt32(UInt8(ascii: "C")) << 24
        let l = UInt32(UInt8(ascii: "L")) << 16
        let p = UInt32(UInt8(ascii: "P")) << 8
        let v = UInt32(UInt8(ascii: "V"))
        return OSType(c | l | p | v)
    }()

    /// Hotkey ID
    private let hotkeyID: UInt32 = 1

    // MARK: - Initialization

    private init() {}

    // deinit not needed - singleton lives for app lifetime
    // unregister() is called explicitly in applicationWillTerminate

    // MARK: - Public Methods

    /// Register global hotkey with specified key code and modifiers
    func register(keyCode: UInt32, modifiers: UInt32) throws {
        // Unregister existing hotkey first
        unregister()

        // Check accessibility permission
        guard PermissionManager.shared.isAccessibilityGranted() else {
            throw HotkeyError.accessibilityPermissionRequired
        }

        // Install event handler if not already installed
        if eventHandler == nil {
            try installEventHandler()
        }

        // Convert modifiers to Carbon format
        let carbonModifiers = convertToCarbonModifiers(modifiers)

        // Create hotkey ID
        let hotkeyIDStruct = EventHotKeyID(signature: hotkeySignature, id: hotkeyID)

        // Register the hotkey
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotkeyIDStruct,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard status == noErr else {
            throw HotkeyError.registrationFailed
        }

        currentKeyCode = keyCode
        currentModifiers = modifiers
        isRegistered = true
    }

    /// Unregister current hotkey
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }

        isRegistered = false
        currentKeyCode = 0
        currentModifiers = 0
    }

    /// Check if current hotkey conflicts with system shortcuts
    func checkForConflicts() -> [String] {
        return Self.checkForConflicts(keyCode: currentKeyCode, modifiers: currentModifiers)
    }

    /// Check if a specific hotkey conflicts with system shortcuts
    static func checkForConflicts(keyCode: UInt32, modifiers: UInt32) -> [String] {
        var conflicts: [String] = []

        // Convert modifiers to normalized form for comparison
        let hasCmd = modifiers & 0x100000 != 0 || modifiers == Constants.defaultHotkeyModifiers
        let hasShift = modifiers & 0x20000 != 0 || modifiers == Constants.defaultHotkeyModifiers
        let hasOption = modifiers & 0x80000 != 0
        let hasControl = modifiers & 0x40000 != 0

        // Common system shortcuts to check against
        // Format: (name, keyCode, cmd, shift, option, control)
        let systemShortcuts: [(String, UInt32, Bool, Bool, Bool, Bool)] = [
            ("Paste", 9, true, false, false, false),                    // Cmd+V
            ("Undo", 6, true, false, false, false),                     // Cmd+Z
            ("Cut", 7, true, false, false, false),                      // Cmd+X
            ("Copy", 8, true, false, false, false),                     // Cmd+C
            ("Select All", 0, true, false, false, false),               // Cmd+A
            ("Save", 1, true, false, false, false),                     // Cmd+S
            ("Quit", 12, true, false, false, false),                    // Cmd+Q
            ("Hide", 4, true, false, false, false),                     // Cmd+H
            ("New Window", 45, true, false, false, false),              // Cmd+N
            ("Open", 31, true, false, false, false),                    // Cmd+O
            ("Print", 35, true, false, false, false),                   // Cmd+P
            ("Find", 3, true, false, false, false),                     // Cmd+F
            ("Close Window", 13, true, false, false, false),            // Cmd+W
            ("Minimize", 46, true, false, false, false),                // Cmd+M
            ("Spotlight", 49, true, false, false, false),               // Cmd+Space
            ("Screenshot", 21, true, true, false, false),               // Cmd+Shift+4
            ("Screenshot (Full)", 19, true, true, false, false),        // Cmd+Shift+3
            ("Force Quit", 12, true, true, false, false),               // Cmd+Shift+Q
            ("Mission Control", 126, false, false, false, true),        // Ctrl+Up
            ("App Windows", 125, false, false, false, true),            // Ctrl+Down
        ]

        for (name, shortcutKey, cmd, shift, option, control) in systemShortcuts {
            if keyCode == shortcutKey &&
               hasCmd == cmd &&
               hasShift == shift &&
               hasOption == option &&
               hasControl == control {
                conflicts.append(name)
            }
        }

        return conflicts
    }

    /// Check if a hotkey would be valid to register
    static func isValidHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // At least one modifier must be present
        let hasCmd = modifiers & 0x100000 != 0 || modifiers == Constants.defaultHotkeyModifiers
        let hasShift = modifiers & 0x20000 != 0 || modifiers == Constants.defaultHotkeyModifiers
        let hasOption = modifiers & 0x80000 != 0
        let hasControl = modifiers & 0x40000 != 0

        let hasModifier = hasCmd || hasShift || hasOption || hasControl

        // Check for conflicts
        let conflicts = checkForConflicts(keyCode: keyCode, modifiers: modifiers)

        return hasModifier && conflicts.isEmpty
    }

    /// Get human-readable description of current hotkey
    func currentHotkeyDescription() -> String {
        guard isRegistered else { return "Not registered" }
        return describeHotkey(keyCode: currentKeyCode, modifiers: currentModifiers)
    }

    // MARK: - Private Methods

    private func installEventHandler() throws {
        var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]

        // Store self reference for callback
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(event)
            },
            1,
            &eventTypes,
            selfPointer,
            &eventHandler
        )

        guard status == noErr else {
            throw HotkeyError.registrationFailed
        }
    }

    private func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }

        var hotkeyIDStruct = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyIDStruct
        )

        guard status == noErr else { return status }

        // Check if this is our hotkey
        if hotkeyIDStruct.signature == hotkeySignature && hotkeyIDStruct.id == hotkeyID {
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyPressed?()
                // Post notification for onboarding practice detection
                NotificationCenter.default.post(name: .hotkeyPressed, object: nil)
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    private func convertToCarbonModifiers(_ cocoaModifiers: UInt32) -> UInt32 {
        var carbonModifiers: UInt32 = 0

        // Convert from Cocoa NSEvent modifier flags to Carbon modifiers
        // Cmd = 0x100000 (Cocoa) -> cmdKey = 0x100 (Carbon)
        // Shift = 0x20000 (Cocoa) -> shiftKey = 0x200 (Carbon)
        // Option = 0x80000 (Cocoa) -> optionKey = 0x800 (Carbon)
        // Control = 0x40000 (Cocoa) -> controlKey = 0x1000 (Carbon)

        if cocoaModifiers & 0x100000 != 0 { // Command
            carbonModifiers |= UInt32(cmdKey)
        }
        if cocoaModifiers & 0x20000 != 0 { // Shift
            carbonModifiers |= UInt32(shiftKey)
        }
        if cocoaModifiers & 0x80000 != 0 { // Option
            carbonModifiers |= UInt32(optionKey)
        }
        if cocoaModifiers & 0x40000 != 0 { // Control
            carbonModifiers |= UInt32(controlKey)
        }

        // Also handle the combined modifier format from Constants (0x100108)
        // This is the format: Cmd(0x100000) + Shift(0x100) + something
        // Let's also handle a simplified format
        if cocoaModifiers == Constants.defaultHotkeyModifiers {
            carbonModifiers = UInt32(cmdKey) | UInt32(shiftKey)
        }

        return carbonModifiers
    }

    private func describeHotkey(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []

        // Check modifiers (using Cocoa format)
        if modifiers & 0x100000 != 0 || modifiers == Constants.defaultHotkeyModifiers {
            parts.append("⌘")
        }
        if modifiers & 0x20000 != 0 || modifiers == Constants.defaultHotkeyModifiers {
            parts.append("⇧")
        }
        if modifiers & 0x80000 != 0 {
            parts.append("⌥")
        }
        if modifiers & 0x40000 != 0 {
            parts.append("⌃")
        }

        // Convert key code to character
        let keyChar = keyCodeToString(keyCode)
        parts.append(keyChar)

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        // Common key codes
        let keyCodes: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'",
            40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
            111: "F12", 113: "F15", 118: "F4", 119: "F2", 120: "F1",
            121: "F15", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]

        return keyCodes[keyCode] ?? "?"
    }
}

// MARK: - Default Hotkey Constants

extension HotkeyManager {
    /// Default hotkey: Cmd+Shift+V
    static let defaultKeyCode: UInt32 = 9  // V key
    static let defaultModifiers: UInt32 = 0x100108  // Cmd + Shift
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the global hotkey is pressed
    static let hotkeyPressed = Notification.Name("ClipVault.hotkeyPressed")
}
