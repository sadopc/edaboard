import SwiftUI

/// Main popover view for ClipVault displayed from the menubar.
/// Contains search bar, clipboard list, and footer controls.
struct MenuBarView: View {

    // MARK: - Environment

    @EnvironmentObject var viewModel: ClipboardViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var showingClearConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchSection

            Divider()

            // Clipboard list
            ClipboardListView(onDismiss: dismissPopover)
                .environmentObject(viewModel)

            Divider()

            // Footer controls
            footerSection
        }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Clear History?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task {
                    await viewModel.clearHistory()
                }
            }
        } message: {
            Text("This will remove all unpinned clipboard history. Pinned items will be preserved.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var searchSection: some View {
        SearchBar(text: $viewModel.searchText)
            .padding(8)
    }

    @ViewBuilder
    private var footerSection: some View {
        HStack {
            // Item count
            Text(itemCountText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Clear history button
            Button {
                showingClearConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear History")
            .disabled(!viewModel.hasItems)

            // Settings button - use SettingsLink for proper Settings scene integration
            SettingsLink {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")

            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit EdaBoard")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var itemCountText: String {
        let total = viewModel.allItems.count
        let pinned = viewModel.pinnedItems.count

        if viewModel.searchText.isEmpty {
            if pinned > 0 {
                return "\(total) items (\(pinned) pinned)"
            } else {
                return "\(total) items"
            }
        } else {
            return "\(total) results"
        }
    }

    // MARK: - Actions

    private func dismissPopover() {
        dismiss()
    }

}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(ClipboardViewModel())
}
