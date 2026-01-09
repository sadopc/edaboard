import SwiftUI
import CoreData

/// Row view for displaying a single clipboard item in the history list.
/// Shows type icon, preview text, timestamp, and pin indicator.
struct ClipboardItemRow: View {

    // MARK: - Properties

    @ObservedObject var item: ClipboardItem
    let isSelected: Bool
    let index: Int?
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    // MARK: - State

    @State private var isHovering = false
    @State private var showImagePreview = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            // Quick paste number (1-9)
            if let index = index, index < 9 {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            } else {
                Spacer()
                    .frame(width: 16)
            }

            // Content type icon
            contentTypeIcon

            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                // Preview text or image thumbnail
                previewContent

                // Timestamp and source app
                metadataRow
            }

            Spacer()

            // Pin indicator
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(backgroundForState)
        .contentShape(Rectangle())
        .onTapGesture {
            onPaste()
        }
        .onHover { hovering in
            isHovering = hovering
            // Show image preview after a short delay on hover
            if hovering && item.contentTypeEnum == .image {
                // Delay before showing preview
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if isHovering {
                        showImagePreview = true
                    }
                }
            } else {
                showImagePreview = false
            }
        }
        .popover(isPresented: $showImagePreview, arrowEdge: .trailing) {
            ImagePreviewView(item: item)
                .padding(8)
        }
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentTypeIcon: some View {
        Image(systemName: item.contentTypeEnum.systemImage)
            .font(.system(size: 14))
            .foregroundStyle(iconColor)
            .frame(width: 20, height: 20)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.contentTypeEnum {
        case .image:
            // Show thumbnail for images using lazy-loading ThumbnailView
            ThumbnailView(item: item, size: 40)

        case .fileReference:
            // Show file name for file references
            HStack(spacing: 4) {
                if let fileName = item.fileName, !fileName.isEmpty {
                    Text(fileName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text(item.previewText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

        case .url:
            // Show URL with favicon and link styling
            HStack(spacing: 6) {
                if let urlString = item.urlString {
                    FaviconView(urlString: urlString, size: 16)
                    Text(urlString)
                        .font(.body)
                        .foregroundStyle(.cyan)
                        .lineLimit(2)
                } else {
                    Text(item.previewText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }

        default:
            // Show text preview
            Text(item.previewText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 4) {
            // Timestamp
            Text(item.formattedTimestamp)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Source app (if available)
            if let sourceApp = item.sourceAppName, !sourceApp.isEmpty {
                Text("·")
                    .foregroundStyle(.secondary)
                Text(sourceApp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onPaste()
        } label: {
            Label("Paste", systemImage: "doc.on.doc")
        }

        Button {
            onPin()
        } label: {
            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Computed Properties

    private var backgroundForState: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovering {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
        return Color.clear
    }

    private var iconColor: Color {
        switch item.contentTypeEnum {
        case .plainText:
            return .secondary
        case .richText:
            return .blue
        case .html:
            return .orange
        case .image:
            return .green
        case .fileReference:
            return .purple
        case .url:
            return .cyan
        }
    }
}

