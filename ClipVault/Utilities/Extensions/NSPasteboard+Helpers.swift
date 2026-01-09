import AppKit
import Foundation

extension NSPasteboard {

    /// Checks if the pasteboard contains any of the specified types
    func contains(types: [NSPasteboard.PasteboardType]) -> Bool {
        guard let availableTypes = self.types else { return false }
        return types.contains { availableTypes.contains($0) }
    }

    /// Checks if the pasteboard contains sensitive content that should be filtered
    func containsSensitiveContent() -> Bool {
        guard let types = self.types else { return false }

        for type in types {
            if Constants.sensitiveTypes.contains(type.rawValue) {
                return true
            }
        }
        return false
    }

    /// Extracts plain text content from the pasteboard
    func extractPlainText() -> String? {
        return string(forType: .string)
    }

    /// Extracts RTF data from the pasteboard
    func extractRTFData() -> Data? {
        return data(forType: .rtf)
    }

    /// Extracts HTML content from the pasteboard
    func extractHTMLContent() -> String? {
        return string(forType: .html)
    }

    /// Extracts image data from the pasteboard (prefers PNG, falls back to TIFF)
    func extractImageData() -> Data? {
        // Try PNG first (smaller, lossless)
        if let pngData = data(forType: .png) {
            return pngData
        }

        // Fall back to TIFF
        if let tiffData = data(forType: .tiff) {
            return tiffData
        }

        return nil
    }

    /// Extracts file URLs from the pasteboard
    func extractFileURLs() -> [URL]? {
        guard let urls = readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return nil
        }

        // Filter to only file URLs
        let fileURLs = urls.filter { $0.isFileURL }
        return fileURLs.isEmpty ? nil : fileURLs
    }

    /// Extracts a single URL from the pasteboard (for web links)
    func extractURL() -> URL? {
        // Try to get URL directly
        if let urlString = string(forType: .URL), let url = URL(string: urlString) {
            return url
        }

        // Try from plain text if it looks like a URL
        if let text = string(forType: .string),
           let url = URL(string: text),
           url.scheme != nil {
            return url
        }

        return nil
    }

    /// Gets the bundle ID of the app that owns the current pasteboard content
    func sourceAppBundleId() -> String? {
        // The owning app's bundle ID is not directly available from NSPasteboard
        // We need to use NSRunningApplication to find the frontmost app
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    /// Gets the name of the app that owns the current pasteboard content
    func sourceAppName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    /// Determines the primary content type from available pasteboard types
    func primaryContentType() -> ContentType {
        guard let types = self.types else { return .plainText }
        return ContentType.from(pasteboardTypes: types)
    }

    /// Writes text content to the pasteboard
    func writeText(_ text: String) {
        clearContents()
        setString(text, forType: .string)
    }

    /// Writes image data to the pasteboard
    func writeImage(_ data: Data) {
        clearContents()
        setData(data, forType: .tiff)
    }

    /// Writes file URLs to the pasteboard
    func writeFileURLs(_ urls: [URL]) {
        clearContents()
        writeObjects(urls as [NSPasteboardWriting])
    }

    /// Writes RTF data to the pasteboard with plain text fallback
    func writeRTF(_ rtfData: Data, plainText: String?) {
        clearContents()
        setData(rtfData, forType: .rtf)
        if let plainText = plainText {
            setString(plainText, forType: .string)
        }
    }

    /// Writes HTML content to the pasteboard with plain text fallback
    func writeHTML(_ html: String, plainText: String?) {
        clearContents()
        setString(html, forType: .html)
        if let plainText = plainText {
            setString(plainText, forType: .string)
        }
    }

    /// Writes URL to the pasteboard
    func writeURL(_ url: URL) {
        clearContents()
        setString(url.absoluteString, forType: .URL)
        setString(url.absoluteString, forType: .string)
    }
}
