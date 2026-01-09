import SwiftUI
import AppKit

/// View for displaying a favicon for a URL.
/// Fetches the favicon asynchronously and caches it.
struct FaviconView: View {

    // MARK: - Properties

    let urlString: String
    let size: CGFloat

    // MARK: - State

    @State private var faviconImage: NSImage?
    @State private var isLoading = false

    // MARK: - Body

    var body: some View {
        Group {
            if let image = faviconImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                // Fallback to link icon
                Image(systemName: "link")
                    .font(.system(size: size * 0.6))
                    .foregroundStyle(.cyan)
                    .frame(width: size, height: size)
            }
        }
        .task {
            await loadFavicon()
        }
    }

    // MARK: - Private Methods

    private func loadFavicon() async {
        guard !isLoading, faviconImage == nil else { return }
        isLoading = true

        // Try to get favicon URL
        guard let url = URL(string: urlString),
              let host = url.host else {
            isLoading = false
            return
        }

        // Try Google's favicon service first (reliable, cached)
        let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")

        if let faviconURL = faviconURL {
            do {
                let (data, _) = try await URLSession.shared.data(from: faviconURL)
                if let image = NSImage(data: data) {
                    await MainActor.run {
                        self.faviconImage = image
                    }
                }
            } catch {
                // Silently fail - just show the link icon
            }
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FaviconView(urlString: "https://apple.com", size: 16)
        FaviconView(urlString: "https://github.com", size: 24)
        FaviconView(urlString: "https://invalid-url", size: 16)
    }
    .padding()
}
