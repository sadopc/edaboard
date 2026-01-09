import Foundation
import AppKit

/// Service for playing sound effects in ClipVault.
/// All sound effects are configurable via SettingsManager.
@MainActor
final class SoundService {

    // MARK: - Singleton

    static let shared = SoundService()

    // MARK: - Sound Types

    enum Sound {
        case paste
        case copy
        case pin
        case delete

        /// System sound name for each action
        var systemSoundName: String {
            switch self {
            case .paste:
                return "Pop"
            case .copy:
                return "Tink"
            case .pin:
                return "Purr"
            case .delete:
                return "Funk"
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Play a sound effect if sound effects are enabled
    func play(_ sound: Sound) {
        guard SettingsManager.shared.soundEffectsEnabled else { return }

        if let systemSound = NSSound(named: sound.systemSoundName) {
            systemSound.play()
        }
    }

    /// Play the paste sound effect
    func playPasteSound() {
        play(.paste)
    }

    /// Play the copy sound effect
    func playCopySound() {
        play(.copy)
    }

    /// Play the pin sound effect
    func playPinSound() {
        play(.pin)
    }

    /// Play the delete sound effect
    func playDeleteSound() {
        play(.delete)
    }
}
