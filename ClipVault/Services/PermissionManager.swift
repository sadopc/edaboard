import Foundation
import AppKit
import ApplicationServices
import UserNotifications

/// Represents pasteboard access behavior (macOS 26+)
enum PasteboardAccessBehavior: Sendable {
    case allowed
    case denied
    case askEveryTime
    case unknown
}

/// Status of all required permissions
struct PermissionStatus: Sendable {
    let accessibility: Bool
    let pasteboard: PasteboardAccessBehavior
}

/// Protocol for checking and requesting system permissions
@MainActor
protocol PermissionManaging {
    func isAccessibilityGranted() -> Bool
    func pasteboardAccessBehavior() -> PasteboardAccessBehavior
    func requestAccessibility()
    func openPrivacySettings()
}

/// Manages Accessibility and TCC permissions for ClipVault
@MainActor
final class PermissionManager: PermissionManaging {

    static let shared = PermissionManager()

    /// Timer for monitoring permission changes
    private var monitorTimer: Timer?

    /// Last known permission status for change detection
    private var lastAccessibilityStatus = false

    private init() {
        lastAccessibilityStatus = isAccessibilityGranted()
    }

    // MARK: - Permission Monitoring

    /// Start monitoring for permission changes
    func startMonitoring(interval: TimeInterval = 2.0) {
        guard monitorTimer == nil else { return }

        lastAccessibilityStatus = isAccessibilityGranted()

        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissionChanges()
            }
        }
    }

    /// Stop monitoring for permission changes
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    /// Check for permission changes and notify if changed
    private func checkPermissionChanges() {
        let currentStatus = isAccessibilityGranted()

        if currentStatus != lastAccessibilityStatus {
            lastAccessibilityStatus = currentStatus

            // Post notification about permission change
            NotificationCenter.default.post(
                name: .accessibilityPermissionChanged,
                object: nil,
                userInfo: ["granted": currentStatus]
            )

            // Show user notification if permission was revoked
            if !currentStatus {
                showPermissionRevokedNotification()
            }
        }
    }

    /// Show a notification that permission was revoked
    private func showPermissionRevokedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "EdaBoard"
        content.body = "Accessibility permission was revoked. EdaBoard needs this permission to paste items. Click to re-enable."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "accessibility-revoked",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Accessibility Permission

    /// Checks if Accessibility permission is currently granted
    func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Requests Accessibility permission by prompting the user
    /// This opens System Settings to Privacy & Security > Accessibility
    func requestAccessibility() {
        // Build the options dictionary without using the global constant directly
        // kAXTrustedCheckOptionPrompt value is "AXTrustedCheckOptionPrompt"
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Pasteboard Access (macOS 26+)

    /// Checks the pasteboard access behavior for this app
    func pasteboardAccessBehavior() -> PasteboardAccessBehavior {
        // macOS 26+ introduces pasteboard TCC
        // For now, we assume allowed since we're targeting direct distribution
        // In a future update, we'll use the actual TCC APIs when available

        let pasteboard = NSPasteboard.general

        // Try to detect if we can access the pasteboard
        // If types is nil, we might be denied
        if pasteboard.types == nil {
            return .denied
        }

        return .allowed
    }

    // MARK: - System Settings

    /// Opens Privacy & Security settings in System Settings
    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens the Privacy & Security > Automation pane
    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Convenience

    /// Checks all required permissions and returns overall status
    func checkAllPermissions() -> PermissionStatus {
        PermissionStatus(
            accessibility: isAccessibilityGranted(),
            pasteboard: pasteboardAccessBehavior()
        )
    }

    /// Returns true if all required permissions are granted
    var allPermissionsGranted: Bool {
        let status = checkAllPermissions()
        return status.accessibility && status.pasteboard == .allowed
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when Accessibility permission status changes
    static let accessibilityPermissionChanged = Notification.Name("ClipVault.accessibilityPermissionChanged")
}
