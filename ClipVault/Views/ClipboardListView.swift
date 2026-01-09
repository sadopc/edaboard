import SwiftUI
import CoreData

/// List view for displaying clipboard history with keyboard navigation and quick paste support.
/// Supports arrow keys for navigation, Enter to paste, and Cmd+1-9 for quick paste.
struct ClipboardListView: View {

    // MARK: - Environment

    @EnvironmentObject var viewModel: ClipboardViewModel

    // MARK: - Properties

    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.hasItems {
                itemsList
            } else {
                EmptyStateView()
            }
        }
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var itemsList: some View {
        ScrollViewReader { proxy in
            List {
                // Pinned items section (using dedicated component)
                PinnedSectionView(
                    pinnedItems: viewModel.filteredPinnedItems,
                    selectedItem: viewModel.selectedItem,
                    onPaste: { item in
                        Task {
                            await viewModel.paste(item)
                            onDismiss()
                        }
                    },
                    onPin: { item in
                        Task {
                            await viewModel.togglePin(item)
                        }
                    },
                    onDelete: { item in
                        Task {
                            await viewModel.delete(item)
                        }
                    }
                )

                // Regular items section
                Section {
                    ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.objectID) { index, item in
                        itemRow(for: item, index: index)
                    }
                } header: {
                    if !viewModel.filteredPinnedItems.isEmpty {
                        historyHeader
                    }
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.automatic)
            .onChange(of: viewModel.selectedItem) { _, newValue in
                if let item = newValue {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(item.objectID, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historyHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("History")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.filteredItems.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func itemRow(for item: ClipboardItem, index: Int?) -> some View {
        ClipboardItemRow(
            item: item,
            isSelected: viewModel.selectedItem == item,
            index: index,
            onPaste: {
                Task {
                    await viewModel.paste(item)
                    onDismiss()
                }
            },
            onPin: {
                Task {
                    await viewModel.togglePin(item)
                }
            },
            onDelete: {
                Task {
                    await viewModel.delete(item)
                }
            }
        )
        .id(item.objectID)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
    }

    // MARK: - Keyboard Handling

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .upArrow:
            viewModel.selectPrevious()
            return .handled

        case .downArrow:
            viewModel.selectNext()
            return .handled

        case .return:
            if viewModel.selectedItem != nil {
                Task {
                    // Check if Option is held for plain text paste
                    let asPlainText = keyPress.modifiers.contains(.option)
                    await viewModel.pasteSelected(asPlainText: asPlainText)
                    onDismiss()
                }
                return .handled
            }
            return .ignored

        case .escape:
            onDismiss()
            return .handled

        default:
            // Handle Cmd+1-9 for quick paste
            if keyPress.modifiers.contains(.command) {
                if let number = quickPasteNumber(from: keyPress) {
                    if let item = viewModel.item(at: number - 1) {
                        Task {
                            await viewModel.paste(item)
                            onDismiss()
                        }
                        return .handled
                    }
                }
            }

            // Handle Cmd+P for pin
            if keyPress.modifiers.contains(.command) && keyPress.characters == "p" {
                if let item = viewModel.selectedItem {
                    Task {
                        await viewModel.togglePin(item)
                    }
                    return .handled
                }
            }

            return .ignored
        }
    }

    private func quickPasteNumber(from keyPress: KeyPress) -> Int? {
        let numberKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        if let index = numberKeys.firstIndex(of: keyPress.characters) {
            return index + 1
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    ClipboardListView(onDismiss: {})
        .environmentObject(ClipboardViewModel())
        .frame(width: 320, height: 400)
}
