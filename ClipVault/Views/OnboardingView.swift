import SwiftUI

/// Onboarding wizard for first-time ClipVault users.
/// Guides users through: Welcome → Permissions → Hotkey → Complete
struct OnboardingView: View {

    // MARK: - Environment

    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var currentStep: OnboardingStep = .welcome
    @State private var accessibilityGranted = false
    @State private var hotkeyPracticed = false
    @State private var checkingPermission = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator
                .padding(.top, 20)
                .padding(.horizontal, 32)

            // Content area with scroll support
            ScrollView {
                stepContent
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 520, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            checkAccessibilityPermission()
        }
    }

    // MARK: - Progress Indicator

    @ViewBuilder
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)

                if step != .complete {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 60)
                }
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeContent
        case .permissions:
            permissionsContent
        case .hotkey:
            hotkeyContent
        case .complete:
            completeContent
        }
    }

    // MARK: - Welcome Step

    @ViewBuilder
    private var welcomeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome to EdaBoard")
                .font(.title)
                .fontWeight(.bold)

            Text("Your clipboard history, always at your fingertips.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "clock.arrow.circlepath", text: "Automatically saves your clipboard history")
                FeatureRow(icon: "magnifyingglass", text: "Search through past copies instantly")
                FeatureRow(icon: "keyboard", text: "Quick access with a global hotkey")
                FeatureRow(icon: "pin.fill", text: "Pin important items to keep them forever")
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Permissions Step

    @ViewBuilder
    private var permissionsContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(accessibilityGranted ? .green : .orange)

            Text("Permissions Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("EdaBoard needs Accessibility permission to use the global hotkey and paste items to other apps.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Permission status
            HStack(spacing: 12) {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(accessibilityGranted ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(accessibilityGranted ? "Permission granted" : "Permission required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !accessibilityGranted {
                    Button("Grant Access") {
                        requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            if !accessibilityGranted {
                VStack(spacing: 10) {
                    Button("Open System Settings") {
                        PermissionManager.shared.openPrivacySettings()
                    }
                    .buttonStyle(.link)

                    Text("After granting permission, click \"Check Again\" to continue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Check Again") {
                        checkAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(checkingPermission)
                }
            }
        }
    }

    // MARK: - Hotkey Step

    @ViewBuilder
    private var hotkeyContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "command.square.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Your Global Hotkey")
                .font(.title2)
                .fontWeight(.bold)

            Text("Press this shortcut anytime to access your clipboard history.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Hotkey display
            HStack(spacing: 6) {
                KeyCapView(key: "⌘")
                Text("+")
                    .font(.body)
                    .foregroundStyle(.secondary)
                KeyCapView(key: "⇧")
                Text("+")
                    .font(.body)
                    .foregroundStyle(.secondary)
                KeyCapView(key: "V")
            }
            .padding(.vertical, 12)

            // Practice prompt
            VStack(spacing: 8) {
                Text("Try it now!")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if hotkeyPracticed {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Great! You've got it.")
                            .foregroundStyle(.green)
                    }
                    .font(.callout)
                } else {
                    Text("Press ⌘⇧V to show EdaBoard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            if !hotkeyPracticed {
                Button("Skip Practice") {
                    hotkeyPracticed = true
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyPressed)) { _ in
            withAnimation {
                hotkeyPracticed = true
            }
        }
    }

    // MARK: - Complete Step

    @ViewBuilder
    private var completeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("EdaBoard is now running in your menu bar. Copy anything and it will be saved to your history.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                TipRow(shortcut: "⌘⇧V", action: "Show/hide EdaBoard")
                TipRow(shortcut: "⌘1-9", action: "Quick paste items 1-9")
                TipRow(shortcut: "⌘P", action: "Pin/unpin selected item")
                TipRow(shortcut: "↑↓ + ↩", action: "Navigate and paste")
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private var navigationButtons: some View {
        HStack {
            // Back button
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation {
                        goBack()
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // Next/Finish button
            Button(nextButtonTitle) {
                withAnimation {
                    goNext()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isNextDisabled)
        }
    }

    // MARK: - Computed Properties

    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Get Started"
        case .permissions:
            return "Continue"
        case .hotkey:
            return "Continue"
        case .complete:
            return "Start Using EdaBoard"
        }
    }

    private var isNextDisabled: Bool {
        switch currentStep {
        case .permissions:
            return !accessibilityGranted
        default:
            return false
        }
    }

    // MARK: - Actions

    private func goNext() {
        switch currentStep {
        case .welcome:
            currentStep = .permissions
        case .permissions:
            currentStep = .hotkey
        case .hotkey:
            currentStep = .complete
        case .complete:
            completeOnboarding()
        }
    }

    private func goBack() {
        switch currentStep {
        case .permissions:
            currentStep = .welcome
        case .hotkey:
            currentStep = .permissions
        case .complete:
            currentStep = .hotkey
        default:
            break
        }
    }

    private func checkAccessibilityPermission() {
        checkingPermission = true
        accessibilityGranted = PermissionManager.shared.isAccessibilityGranted()
        checkingPermission = false
    }

    private func requestAccessibilityPermission() {
        PermissionManager.shared.requestAccessibility()
        // Check again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkAccessibilityPermission()
        }
    }

    private func completeOnboarding() {
        settingsManager.hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permissions = 1
    case hotkey = 2
    case complete = 3
}

// MARK: - Supporting Views

/// Displays a feature with an icon and description
private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 24)

            Text(text)
                .font(.body)
        }
    }
}

/// Displays a keyboard key cap style
private struct KeyCapView: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.title2)
            .fontWeight(.medium)
            .frame(minWidth: 36, minHeight: 36)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
}

/// Displays a keyboard shortcut tip
private struct TipRow: View {
    let shortcut: String
    let action: String

    var body: some View {
        HStack {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.tint)
                .frame(width: 80, alignment: .leading)

            Text(action)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView()
        .environmentObject(SettingsManager.shared)
}
