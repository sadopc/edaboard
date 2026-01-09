import SwiftUI
import AppKit

/// Main Settings view containing all settings tabs
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        TabView {
            GeneralSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            HotkeySettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }

            PrivacySettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            DataSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 400)
        .alert("Status", isPresented: .constant(viewModel.statusMessage != nil)) {
            Button("OK") {
                viewModel.clearStatus()
            }
        } message: {
            Text(viewModel.statusMessage ?? "")
        }
    }
}

// MARK: - General Settings Tab

/// Settings for history limit, polling interval, and startup behavior
struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("History") {
                Picker("Maximum Items", selection: Binding(
                    get: { viewModel.settings.historyLimit },
                    set: { viewModel.settings.historyLimit = $0 }
                )) {
                    ForEach(SettingsViewModel.historyLimitPresets, id: \.self) { limit in
                        Text("\(limit) items").tag(limit)
                    }
                }
                .help("Maximum number of clipboard items to keep in history")

                Stepper(
                    value: Binding(
                        get: { viewModel.settings.historyLimit },
                        set: { viewModel.settings.historyLimit = $0 }
                    ),
                    in: Constants.minHistoryLimit...Constants.maxHistoryLimit,
                    step: 10
                ) {
                    Text("Custom: \(viewModel.settings.historyLimit) items")
                }
            }

            Section("Performance") {
                Picker("Clipboard Check Interval", selection: Binding(
                    get: { viewModel.settings.pollingInterval },
                    set: { viewModel.settings.pollingInterval = $0 }
                )) {
                    ForEach(SettingsViewModel.pollingIntervalOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .help("How often EdaBoard checks for clipboard changes")

                Text("Lower values detect copies faster but use more CPU")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Start EdaBoard at Login", isOn: Binding(
                    get: { viewModel.settings.startAtLogin },
                    set: { viewModel.settings.startAtLogin = $0 }
                ))
                .help("Automatically launch EdaBoard when you log in")
            }

            Section("Feedback") {
                Toggle("Play Sound Effects", isOn: Binding(
                    get: { viewModel.settings.soundEffectsEnabled },
                    set: { viewModel.settings.soundEffectsEnabled = $0 }
                ))
                .help("Play sounds when pasting items")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Hotkey Settings Tab

/// Settings for global hotkey customization
struct HotkeySettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var pendingKeyCode: UInt32?
    @State private var pendingModifiers: UInt32?

    var body: some View {
        Form {
            Section("Global Hotkey") {
                HStack {
                    Text("Current Hotkey:")
                    Spacer()
                    Text(viewModel.hotkeyDisplayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                HStack {
                    Button(viewModel.isRecordingHotkey ? "Press keys..." : "Record New Hotkey") {
                        viewModel.isRecordingHotkey.toggle()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Reset to Default") {
                        viewModel.resetHotkeyToDefault()
                    }
                    .buttonStyle(.borderless)
                }

                if viewModel.isRecordingHotkey {
                    HotkeyRecorderView { keyCode, modifiers in
                        viewModel.setHotkey(keyCode: keyCode, modifiers: modifiers)
                    }
                    .frame(height: 44)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Section("Hotkey Tips") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Use ⌘⇧V (Cmd+Shift+V) to avoid conflicts", systemImage: "lightbulb")
                    Label("Avoid system shortcuts like ⌘C, ⌘V, ⌘Q", systemImage: "exclamationmark.triangle")
                    Label("Accessibility permission required for global hotkeys", systemImage: "lock.shield")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// Inline hotkey recorder view
struct HotkeyRecorderView: View {
    let onRecord: (UInt32, UInt32) -> Void

    var body: some View {
        HStack {
            Image(systemName: "keyboard")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Press your desired key combination...")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .background(KeyEventCatcher(onKeyEvent: onRecord))
    }
}

/// NSViewRepresentable to catch key events
struct KeyEventCatcher: NSViewRepresentable {
    let onKeyEvent: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKeyEvent = onKeyEvent
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.onKeyEvent = onKeyEvent
    }
}

/// Custom NSView for capturing key events
class KeyCatcherView: NSView {
    var onKeyEvent: ((UInt32, UInt32) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let modifiers = UInt32(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)

        // Require at least one modifier key
        let hasModifier = event.modifierFlags.contains(.command) ||
                          event.modifierFlags.contains(.option) ||
                          event.modifierFlags.contains(.control) ||
                          event.modifierFlags.contains(.shift)

        if hasModifier {
            onKeyEvent?(keyCode, modifiers)
        }
    }
}

// MARK: - Privacy Settings Tab

/// Settings for ignored apps and sensitive content filtering
struct PrivacySettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Content Filtering") {
                Toggle("Filter Sensitive Content", isOn: Binding(
                    get: { viewModel.settings.filterSensitiveContent },
                    set: { viewModel.settings.filterSensitiveContent = $0 }
                ))
                .help("Automatically exclude passwords and auto-generated content")

                VStack(alignment: .leading, spacing: 4) {
                    Text("When enabled, EdaBoard ignores:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Label("Password manager entries", systemImage: "key")
                        Label("Auto-generated content", systemImage: "wand.and.stars")
                        Label("Temporary clipboard data", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Ignored Applications") {
                Text("Clipboard content from these apps will not be saved:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List {
                    ForEach(viewModel.settings.ignoredAppBundleIds, id: \.self) { bundleId in
                        HStack {
                            Text(bundleId)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                viewModel.removeIgnoredApp(bundleId)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .onDelete(perform: viewModel.removeIgnoredApps)
                }
                .frame(height: 100)

                HStack {
                    TextField("Bundle ID (e.g., com.apple.Notes)", text: $viewModel.newIgnoredAppBundleId)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        viewModel.addIgnoredApp()
                    }
                    .disabled(viewModel.newIgnoredAppBundleId.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Data Settings Tab

/// Settings for history management (clear, export)
struct DataSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showClearConfirmation = false
    @State private var exportDocument: ExportDocument?
    @State private var isExporting = false

    var body: some View {
        Form {
            Section("History Management") {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All History")
                    }
                }
                .confirmationDialog(
                    "Clear All History?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear All (Keep Pinned)", role: .destructive) {
                        Task {
                            await viewModel.clearAllHistory()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will delete all unpinned clipboard items. Pinned items will be preserved.")
                }

                Text("Pinned items will be preserved when clearing history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Export") {
                Button {
                    Task {
                        if let data = await viewModel.exportHistory() {
                            await MainActor.run {
                                exportDocument = ExportDocument(data: data)
                                isExporting = true
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export History...")
                    }
                }
                .disabled(viewModel.isProcessing)
                .fileExporter(
                    isPresented: $isExporting,
                    document: exportDocument ?? ExportDocument(data: Data()),
                    contentType: .json,
                    defaultFilename: "clipvault-history-\(formattedDate()).json"
                ) { result in
                    switch result {
                    case .success:
                        viewModel.statusMessage = "History exported successfully"
                    case .failure(let error):
                        viewModel.statusMessage = "Export failed: \(error.localizedDescription)"
                    }
                    exportDocument = nil
                }

                Text("Export your clipboard history as JSON for backup or analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Reset") {
                Button(role: .destructive) {
                    viewModel.resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset All Settings")
                    }
                }

                Text("This will reset all settings to their default values")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

/// FileDocument for exporting history
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    private var exportData: Data

    init(data: Data) {
        self.exportData = data
    }

    init(configuration: ReadConfiguration) throws {
        self.exportData = Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: exportData)
    }
}

// MARK: - About Settings Tab

/// About tab with app information
struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 4) {
                Text("EdaBoard")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("A native macOS clipboard manager")
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                HStack {
                    Text("Keyboard Shortcuts:")
                        .fontWeight(.medium)
                    Spacer()
                }

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                    GridRow {
                        Text("⌘⇧V")
                            .font(.system(.body, design: .monospaced))
                        Text("Show/Hide EdaBoard")
                    }
                    GridRow {
                        Text("⌘1-9")
                            .font(.system(.body, design: .monospaced))
                        Text("Quick paste items 1-9")
                    }
                    GridRow {
                        Text("↑↓")
                            .font(.system(.body, design: .monospaced))
                        Text("Navigate history")
                    }
                    GridRow {
                        Text("↩")
                            .font(.system(.body, design: .monospaced))
                        Text("Paste selected item")
                    }
                    GridRow {
                        Text("⌥↩")
                            .font(.system(.body, design: .monospaced))
                        Text("Paste as plain text")
                    }
                    GridRow {
                        Text("⌘P")
                            .font(.system(.body, design: .monospaced))
                        Text("Pin/unpin item")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - UTType Extension

import UniformTypeIdentifiers

extension UTType {
    static var json: UTType {
        UTType(filenameExtension: "json") ?? .data
    }
}
