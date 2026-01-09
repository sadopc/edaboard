import SwiftUI
import CoreData

@main
struct ClipVaultApp: App {

    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var viewModel = ClipboardViewModel()

    /// Application delegate for handling app lifecycle events
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Ensure required directories exist
        try? ClipboardItem.ensureDirectoriesExist()
    }

    var body: some Scene {
        MenuBarExtra("EdaBoard", systemImage: "doc.on.clipboard") {
            MenuBarView()
                .environmentObject(viewModel)
                .environmentObject(settingsManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settingsManager)
        }
    }
}

// MARK: - App Delegate

/// Handles app lifecycle events and service initialization
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Reference to status item for showing/hiding popover via hotkey
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[ClipVault] Application launching...")

        // Start clipboard monitoring
        Task {
            let interval = await MainActor.run { SettingsManager.shared.pollingInterval }
            print("[ClipVault] Starting monitoring with interval: \(interval)")
            await ClipboardMonitor.shared.startMonitoring(interval: interval)
        }

        // Listen to clipboard content stream and save to history
        Task {
            print("[ClipVault] Creating content stream...")
            let stream = await ClipboardMonitor.shared.makeContentStream()
            print("[ClipVault] Listening for clipboard content...")
            for await content in stream {
                print("[ClipVault] Received content from stream")
                await handleNewContent(content)
            }
            print("[ClipVault] Stream ended")
        }

        // Register global hotkey
        registerGlobalHotkey()

        // Show onboarding if first launch
        Task { @MainActor in
            if !SettingsManager.shared.hasCompletedOnboarding {
                showOnboardingWindow()
            }
        }
    }

    /// Shows the onboarding window for first-time users
    @MainActor
    private func showOnboardingWindow() {
        let onboardingView = OnboardingView()
            .environmentObject(SettingsManager.shared)

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to EdaBoard"
        window.styleMask = NSWindow.StyleMask([.titled, .closable])
        window.setContentSize(NSSize(width: 520, height: 520))
        window.center()
        window.makeKeyAndOrderFront(nil as Any?)
        NSApp.activate(ignoringOtherApps: true)

        // Store reference to keep window alive
        onboardingWindow = window
    }

    /// Reference to onboarding window
    var onboardingWindow: NSWindow?

    func applicationWillTerminate(_ notification: Notification) {
        // Stop monitoring
        Task {
            await ClipboardMonitor.shared.stopMonitoring()
        }

        // Unregister hotkey
        HotkeyManager.shared.unregister()
    }

    // MARK: - Hotkey Registration

    @MainActor
    private func registerGlobalHotkey() {
        let settings = SettingsManager.shared

        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.togglePopover()
        }

        do {
            try HotkeyManager.shared.register(
                keyCode: settings.globalHotkeyKeyCode,
                modifiers: settings.globalHotkeyModifiers
            )
        } catch {
            print("Failed to register hotkey: \(error)")
            // Show notification to user about permission requirement
            if case HotkeyError.accessibilityPermissionRequired = error {
                showAccessibilityPermissionAlert()
            }
        }
    }

    @MainActor
    private func togglePopover() {
        // Post notification to toggle the MenuBarExtra popover
        // SwiftUI MenuBarExtra doesn't have direct API for this,
        // so we use the status bar button approach
        if let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength).button {
            // This is a workaround - we'll click the status bar button
            button.performClick(nil)
        }

        // Alternative: Use NSApp to activate and show
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showAccessibilityPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "EdaBoard needs Accessibility permission to use global hotkeys. Please grant permission in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                PermissionManager.shared.openPrivacySettings()
            }
        }
    }

    private func handleNewContent(_ content: ClipboardContent) async {
        print("[ClipVault] Handling new content - hash: \(content.contentHash)")

        // Check for duplicates
        let isDuplicate = await HistoryStore.shared.isDuplicate(hash: content.contentHash)
        guard !isDuplicate else {
            print("[ClipVault] Skipping duplicate content")
            return
        }

        print("[ClipVault] Saving to history store...")
        do {
            // Handle image content
            if let imageData = content.imageData {
                let itemId = UUID()

                // Generate and save thumbnail
                if let thumbnailData = await ImageProcessor.shared.generateThumbnail(from: imageData) {
                    _ = try? await ImageProcessor.shared.saveThumbnail(thumbnailData, id: itemId)
                }

                // Save full image if within size limit
                if imageData.count <= Constants.maxImageSize {
                    _ = try? await ImageProcessor.shared.saveFullImage(imageData, id: itemId)
                }
            }

            // Save to history store (discarding the result since ClipboardItem is not Sendable)
            try await HistoryStore.shared.save(content)
            print("[ClipVault] Successfully saved to history store")

            // Enforce history limit
            let limit = await MainActor.run { SettingsManager.shared.historyLimit }
            try await HistoryStore.shared.enforceLimit(limit)

        } catch {
            print("[ClipVault] Failed to save clipboard content: \(error)")
        }
    }
}

// MARK: - Placeholder Views (to be replaced in Phase 3)

/// Temporary placeholder for MenuBarView
struct MenuBarPlaceholderView: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("ClipVault")
                .font(.headline)

            Text("Clipboard monitoring active")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Quit ClipVault") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding()
        .frame(width: Constants.popoverWidth, height: 180)
    }
}

/// Temporary placeholder for SettingsView
struct SettingsPlaceholderView: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("General") {
                Stepper(
                    "History Limit: \(settings.historyLimit)",
                    value: $settings.historyLimit,
                    in: Constants.minHistoryLimit...Constants.maxHistoryLimit,
                    step: 10
                )

                Toggle("Sound Effects", isOn: $settings.soundEffectsEnabled)
                Toggle("Start at Login", isOn: $settings.startAtLogin)
                Toggle("Filter Sensitive Content", isOn: $settings.filterSensitiveContent)
            }

            Section("About") {
                Text("ClipVault - Phase 2 Complete")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}
