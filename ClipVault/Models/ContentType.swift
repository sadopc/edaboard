import Foundation
import AppKit

/// Represents the type of content stored in a clipboard item.
/// Maps to NSPasteboard types for content extraction and display.
enum ContentType: String, Codable, CaseIterable, Sendable {
    case plainText = "plainText"
    case richText = "richText"
    case html = "html"
    case image = "image"
    case fileReference = "fileReference"
    case url = "url"

    /// User-facing display name for the content type
    var displayName: String {
        switch self {
        case .plainText: return "Text"
        case .richText: return "Rich Text"
        case .html: return "HTML"
        case .image: return "Image"
        case .fileReference: return "File"
        case .url: return "URL"
        }
    }

    /// SF Symbol name for the content type icon
    var systemImage: String {
        switch self {
        case .plainText: return "doc.text"
        case .richText: return "doc.richtext"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .fileReference: return "doc"
        case .url: return "link"
        }
    }

    /// Determines ContentType from NSPasteboard types.
    /// Priority order: image > file > URL > rich text > HTML > plain text
    static func from(pasteboardTypes: [NSPasteboard.PasteboardType]) -> ContentType {
        // Check for image types first (highest priority for visual content)
        if pasteboardTypes.contains(where: { $0 == .tiff || $0 == .png }) {
            return .image
        }

        // Check for file references
        if pasteboardTypes.contains(.fileURL) {
            return .fileReference
        }

        // Check for URLs (web links)
        if pasteboardTypes.contains(.URL) {
            return .url
        }

        // Check for rich text formats
        if pasteboardTypes.contains(.rtf) {
            return .richText
        }

        // Check for HTML content
        if pasteboardTypes.contains(.html) {
            return .html
        }

        // Default to plain text
        return .plainText
    }
}
