import SwiftUI
import Combine

/// ViewModel for settings management with bindings to SettingsManager.
/// Provides reactive state management for the settings UI.
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties (Local State)

    /// New app bundle ID being added to ignored list
    @Published var newIgnoredAppBundleId: String = ""

    /// Whether the clear history confirmation dialog is shown
    @Published var showClearConfirmation = false

    /// Whether the export file dialog is shown
    @Published var showExportDialog = false

    /// Status message for user feedback
    @Published var statusMessage: String?

    /// Whether an operation is in progress
    @Published var isProcessing = false

    /// Current hotkey display string
    @Published var hotkeyDisplayString: String = ""

    /// Whether hotkey recording is active
    @Published var isRecordingHotkey = false

    // MARK: - Private Properties

    private let settingsManager: SettingsManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Reference to settings manager for bindings
    var settings: SettingsManager { settingsManager }

    /// Formatted polling interval for display
    var pollingIntervalDisplay: String {
        let interval = settingsManager.pollingInterval
        return String(format: "%.1f seconds", interval)
    }

    /// Available polling interval options
    static let pollingIntervalOptions: [(label: String, value: TimeInterval)] = [
        ("0.25s (Fast)", 0.25),
        ("0.5s (Default)", 0.5),
        ("1.0s (Battery Saver)", 1.0),
        ("2.0s (Low Power)", 2.0)
    ]

    /// Available history limit presets
    static let historyLimitPresets: [Int] = [50, 100, 250, 500, 1000]

    // MARK: - Initialization

    init(settingsManager: SettingsManager = SettingsManager.shared) {
        self.settingsManager = settingsManager
        updateHotkeyDisplay()

        // Forward SettingsManager's objectWillChange to update UI when any setting changes
        settingsManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe settings changes to update hotkey display
        settingsManager.$globalHotkeyKeyCode
            .sink { [weak self] _ in self?.updateHotkeyDisplay() }
            .store(in: &cancellables)

        settingsManager.$globalHotkeyModifiers
            .sink { [weak self] _ in self?.updateHotkeyDisplay() }
            .store(in: &cancellables)
    }

    // MARK: - Ignored Apps Management

    /// Add a new app bundle ID to the ignored list
    func addIgnoredApp() {
        let bundleId = newIgnoredAppBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleId.isEmpty else { return }
        guard !settingsManager.ignoredAppBundleIds.contains(bundleId) else {
            statusMessage = "App already in ignored list"
            return
        }

        settingsManager.ignoredAppBundleIds.append(bundleId)
        newIgnoredAppBundleId = ""
        statusMessage = "Added \(bundleId) to ignored apps"
    }

    /// Remove an app bundle ID from the ignored list
    func removeIgnoredApp(_ bundleId: String) {
        settingsManager.ignoredAppBundleIds.removeAll { $0 == bundleId }
        statusMessage = "Removed \(bundleId) from ignored apps"
    }

    /// Remove ignored apps at specified offsets
    func removeIgnoredApps(at offsets: IndexSet) {
        settingsManager.ignoredAppBundleIds.remove(atOffsets: offsets)
    }

    // MARK: - History Management

    /// Clear all clipboard history (with confirmation)
    func clearAllHistory() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await HistoryStore.shared.clearHistory()
            statusMessage = "History cleared successfully"
        } catch {
            statusMessage = "Failed to clear history: \(error.localizedDescription)"
        }
    }

    /// Export history to a file
    func exportHistory() async -> Data? {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let data = try await HistoryStore.shared.exportHistory()
            statusMessage = "History exported successfully"
            return data
        } catch {
            statusMessage = "Failed to export history: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Hotkey Management

    /// Update the hotkey display string based on current settings
    func updateHotkeyDisplay() {
        let modifiers = settingsManager.globalHotkeyModifiers
        let keyCode = settingsManager.globalHotkeyKeyCode

        var parts: [String] = []

        // Check modifier flags
        if modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 {
            parts.append("⌃")
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 {
            parts.append("⌘")
        }

        // Map key code to character
        let keyChar = Self.keyCodeToString(keyCode)
        parts.append(keyChar)

        hotkeyDisplayString = parts.joined()
    }

    /// Set a new hotkey
    func setHotkey(keyCode: UInt32, modifiers: UInt32) {
        // Unregister old hotkey
        HotkeyManager.shared.unregister()

        // Update settings
        settingsManager.globalHotkeyKeyCode = keyCode
        settingsManager.globalHotkeyModifiers = modifiers

        // Register new hotkey
        do {
            try HotkeyManager.shared.register(keyCode: keyCode, modifiers: modifiers)
            statusMessage = "Hotkey updated successfully"
        } catch {
            statusMessage = "Failed to register hotkey: \(error.localizedDescription)"
        }

        updateHotkeyDisplay()
        isRecordingHotkey = false
    }

    /// Reset hotkey to default (Cmd+Shift+V)
    func resetHotkeyToDefault() {
        setHotkey(
            keyCode: Constants.defaultHotkeyKeyCode,
            modifiers: Constants.defaultHotkeyModifiers
        )
    }

    /// Convert key code to display string
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        // Common key codes
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H",
            5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            10: "§", 11: "B", 12: "Q", 13: "W", 14: "E",
            15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
            25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I",
            35: "P", 36: "↩", 37: "L", 38: "J", 39: "'",
            40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "⎋",
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
            // Arrow keys
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]

        return keyMap[keyCode] ?? "Key\(keyCode)"
    }

    // MARK: - Settings Reset

    /// Reset all settings to defaults
    func resetToDefaults() {
        settingsManager.resetToDefaults()
        resetHotkeyToDefault()
        statusMessage = "Settings reset to defaults"
    }

    // MARK: - Status Management

    /// Clear status message
    func clearStatus() {
        statusMessage = nil
    }
}
