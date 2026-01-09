import Foundation
import Combine
import ServiceManagement

/// Protocol for managing app settings via UserDefaults
@MainActor
protocol SettingsManaging: ObservableObject {
    var historyLimit: Int { get set }
    var globalHotkeyKeyCode: UInt32 { get set }
    var globalHotkeyModifiers: UInt32 { get set }
    var startAtLogin: Bool { get set }
    var soundEffectsEnabled: Bool { get set }
    var pollingInterval: TimeInterval { get set }
    var ignoredAppBundleIds: [String] { get set }
    var filterSensitiveContent: Bool { get set }
    var hasCompletedOnboarding: Bool { get set }

    func resetToDefaults()
    func exportSettings() -> Data
    func importSettings(from data: Data) throws
}

/// UserDefaults-backed settings manager for ClipVault
@MainActor
final class SettingsManager: ObservableObject, SettingsManaging {

    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Published Properties

    @Published var historyLimit: Int {
        didSet {
            let clamped = min(max(historyLimit, Constants.minHistoryLimit), Constants.maxHistoryLimit)
            if clamped != historyLimit {
                historyLimit = clamped
            }
            defaults.set(historyLimit, forKey: Constants.UserDefaultsKeys.historyLimit)
        }
    }

    @Published var globalHotkeyKeyCode: UInt32 {
        didSet {
            defaults.set(Int(globalHotkeyKeyCode), forKey: Constants.UserDefaultsKeys.globalHotkeyKeyCode)
        }
    }

    @Published var globalHotkeyModifiers: UInt32 {
        didSet {
            defaults.set(Int(globalHotkeyModifiers), forKey: Constants.UserDefaultsKeys.globalHotkeyModifiers)
        }
    }

    @Published var startAtLogin: Bool {
        didSet {
            defaults.set(startAtLogin, forKey: Constants.UserDefaultsKeys.startAtLogin)
            updateLoginItem()
        }
    }

    @Published var soundEffectsEnabled: Bool {
        didSet {
            defaults.set(soundEffectsEnabled, forKey: Constants.UserDefaultsKeys.soundEffectsEnabled)
        }
    }

    @Published var pollingInterval: TimeInterval {
        didSet {
            defaults.set(pollingInterval, forKey: Constants.UserDefaultsKeys.pollingInterval)
        }
    }

    @Published var ignoredAppBundleIds: [String] {
        didSet {
            defaults.set(ignoredAppBundleIds, forKey: Constants.UserDefaultsKeys.ignoredAppBundleIds)
        }
    }

    @Published var filterSensitiveContent: Bool {
        didSet {
            defaults.set(filterSensitiveContent, forKey: Constants.UserDefaultsKeys.filterSensitiveContent)
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)
        }
    }

    // MARK: - Initialization

    private init() {
        // Load values from UserDefaults or use defaults
        // Note: We must initialize all properties before accessing self
        let loadedHistoryLimit = defaults.object(forKey: Constants.UserDefaultsKeys.historyLimit) as? Int
            ?? Constants.defaultHistoryLimit

        var loadedKeyCode = UInt32(defaults.integer(forKey: Constants.UserDefaultsKeys.globalHotkeyKeyCode))
        if loadedKeyCode == 0 {
            loadedKeyCode = Constants.defaultHotkeyKeyCode
        }

        var loadedModifiers = UInt32(defaults.integer(forKey: Constants.UserDefaultsKeys.globalHotkeyModifiers))
        if loadedModifiers == 0 {
            loadedModifiers = Constants.defaultHotkeyModifiers
        }

        let loadedStartAtLogin = defaults.bool(forKey: Constants.UserDefaultsKeys.startAtLogin)
        let loadedSoundEffects = defaults.object(forKey: Constants.UserDefaultsKeys.soundEffectsEnabled) as? Bool ?? true

        let loadedPollingInterval = defaults.object(forKey: Constants.UserDefaultsKeys.pollingInterval) as? TimeInterval
            ?? Constants.defaultPollingInterval

        let loadedIgnoredApps = defaults.stringArray(forKey: Constants.UserDefaultsKeys.ignoredAppBundleIds) ?? []
        let loadedFilterSensitive = defaults.object(forKey: Constants.UserDefaultsKeys.filterSensitiveContent) as? Bool ?? true
        let loadedOnboarding = defaults.bool(forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)

        // Now assign all properties
        self.historyLimit = loadedHistoryLimit
        self.globalHotkeyKeyCode = loadedKeyCode
        self.globalHotkeyModifiers = loadedModifiers
        self.startAtLogin = loadedStartAtLogin
        self.soundEffectsEnabled = loadedSoundEffects
        self.pollingInterval = loadedPollingInterval
        self.ignoredAppBundleIds = loadedIgnoredApps
        self.filterSensitiveContent = loadedFilterSensitive
        self.hasCompletedOnboarding = loadedOnboarding
    }

    // MARK: - Public Methods

    func resetToDefaults() {
        historyLimit = Constants.defaultHistoryLimit
        globalHotkeyKeyCode = Constants.defaultHotkeyKeyCode
        globalHotkeyModifiers = Constants.defaultHotkeyModifiers
        startAtLogin = false
        soundEffectsEnabled = true
        pollingInterval = Constants.defaultPollingInterval
        ignoredAppBundleIds = []
        filterSensitiveContent = true
        // Note: hasCompletedOnboarding is NOT reset
    }

    func exportSettings() -> Data {
        let settings: [String: Any] = [
            "historyLimit": historyLimit,
            "globalHotkeyKeyCode": globalHotkeyKeyCode,
            "globalHotkeyModifiers": globalHotkeyModifiers,
            "startAtLogin": startAtLogin,
            "soundEffectsEnabled": soundEffectsEnabled,
            "pollingInterval": pollingInterval,
            "ignoredAppBundleIds": ignoredAppBundleIds,
            "filterSensitiveContent": filterSensitiveContent
        ]

        return (try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)) ?? Data()
    }

    func importSettings(from data: Data) throws {
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SettingsError.invalidFormat
        }

        if let value = settings["historyLimit"] as? Int {
            historyLimit = value
        }
        if let value = settings["globalHotkeyKeyCode"] as? UInt32 {
            globalHotkeyKeyCode = value
        }
        if let value = settings["globalHotkeyModifiers"] as? UInt32 {
            globalHotkeyModifiers = value
        }
        if let value = settings["startAtLogin"] as? Bool {
            startAtLogin = value
        }
        if let value = settings["soundEffectsEnabled"] as? Bool {
            soundEffectsEnabled = value
        }
        if let value = settings["pollingInterval"] as? TimeInterval {
            pollingInterval = value
        }
        if let value = settings["ignoredAppBundleIds"] as? [String] {
            ignoredAppBundleIds = value
        }
        if let value = settings["filterSensitiveContent"] as? Bool {
            filterSensitiveContent = value
        }
    }

    // MARK: - Private Methods

    private func updateLoginItem() {
        do {
            if startAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Log error but don't crash - login item management is non-critical
            print("Failed to update login item: \(error)")
        }
    }
}

// MARK: - Errors

enum SettingsError: Error {
    case invalidFormat
}
