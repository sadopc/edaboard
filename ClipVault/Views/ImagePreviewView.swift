import SwiftUI
import AppKit

/// View for displaying a full-size image preview on hover or detail view.
/// Uses lazy loading to avoid memory issues with large images.
struct ImagePreviewView: View {

    // MARK: - Properties

    let item: ClipboardItem

    /// Maximum size for the preview
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    // MARK: - State

    @State private var nsImage: NSImage?
    @State private var isLoading = true
    @State private var loadError = false

    // MARK: - Initialization

    init(item: ClipboardItem, maxWidth: CGFloat = 400, maxHeight: CGFloat = 300) {
        self.item = item
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if loadError {
                errorView
            } else if let image = nsImage {
                imageView(image)
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .task {
            await loadImage()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 80)
    }

    private var errorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Failed to load image")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120, height: 80)
    }

    private var placeholderView: some View {
        VStack {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No image data")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 80)
    }

    private func imageView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .cornerRadius(8)
            .shadow(radius: 4)
    }

    // MARK: - Image Loading

    private func loadImage() async {
        isLoading = true
        loadError = false

        // Try to load full image first, fall back to thumbnail
        if let fullImageURL = item.fullImageURL {
            if let image = await loadImageFromURL(fullImageURL) {
                nsImage = image
                isLoading = false
                return
            }
        }

        // Fall back to thumbnail
        if let thumbnailURL = item.thumbnailURL {
            if let image = await loadImageFromURL(thumbnailURL) {
                nsImage = image
                isLoading = false
                return
            }
        }

        // Could not load any image
        isLoading = false
        loadError = true
    }

    private func loadImageFromURL(_ url: URL) async -> NSImage? {
        return await Task.detached(priority: .userInitiated) {
            guard let image = NSImage(contentsOf: url) else {
                return nil
            }
            return image
        }.value
    }
}

// MARK: - Thumbnail View

/// A smaller view showing just the thumbnail for list items
struct ThumbnailView: View {

    let item: ClipboardItem
    let size: CGFloat

    @State private var nsImage: NSImage?

    init(item: ClipboardItem, size: CGFloat = 40) {
        self.item = item
        self.size = size
    }

    var body: some View {
        Group {
            if let image = nsImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(4)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let thumbnailURL = item.thumbnailURL else { return }

        nsImage = await Task.detached(priority: .userInitiated) {
            return NSImage(contentsOf: thumbnailURL)
        }.value
    }
}

// MARK: - Preview Provider

#Preview("Image Preview") {
    ImagePreviewView(
        item: ClipboardItem(),
        maxWidth: 300,
        maxHeight: 200
    )
    .padding()
}

#Preview("Thumbnail") {
    ThumbnailView(
        item: ClipboardItem(),
        size: 40
    )
    .padding()
}
