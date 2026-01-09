import SwiftUI
import CoreData

/// View for displaying pinned clipboard items in a dedicated section.
/// Shows pinned items with visual distinction from regular history.
struct PinnedSectionView: View {

    // MARK: - Properties

    let pinnedItems: [ClipboardItem]
    let selectedItem: ClipboardItem?
    let onPaste: (ClipboardItem) -> Void
    let onPin: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void

    // MARK: - Body

    var body: some View {
        if !pinnedItems.isEmpty {
            Section {
                ForEach(pinnedItems, id: \.objectID) { item in
                    ClipboardItemRow(
                        item: item,
                        isSelected: selectedItem == item,
                        index: nil, // Pinned items don't show quick paste numbers
                        onPaste: { onPaste(item) },
                        onPin: { onPin(item) },
                        onDelete: { onDelete(item) }
                    )
                    .id(item.objectID)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            } header: {
                pinnedHeader
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var pinnedHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: "pin.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("Pinned")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(pinnedItems.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        PinnedSectionView(
            pinnedItems: [],
            selectedItem: nil,
            onPaste: { _ in },
            onPin: { _ in },
            onDelete: { _ in }
        )
    }
    .listStyle(.plain)
    .frame(width: 320, height: 200)
}
