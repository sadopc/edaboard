import Foundation
import CoreData

/// Extension for ClipboardItem Core Data entity providing computed properties
/// and convenience methods for display and manipulation.
extension ClipboardItem {

    /// Preview text for display in list views (first 100 characters)
    var previewText: String {
        guard let text = textContent, !text.isEmpty else {
            return contentTypeEnum.displayName
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 100 {
            return trimmed
        }
        return String(trimmed.prefix(100)) + "…"
    }

    /// Formatted timestamp for display (relative format: "2 min ago")
    var formattedTimestamp: String {
        guard let date = timestamp else { return "" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// ContentType enum value derived from stored string
    var contentTypeEnum: ContentType {
        guard let typeString = contentType else { return .plainText }
        return ContentType(rawValue: typeString) ?? .plainText
    }

    /// Full thumbnail URL if path exists
    var thumbnailURL: URL? {
        guard let path = thumbnailPath, !path.isEmpty else { return nil }
        return ClipboardItem.thumbnailsDirectory.appendingPathComponent(path)
    }

    /// Full image URL if path exists
    var fullImageURL: URL? {
        guard let path = fullImagePath, !path.isEmpty else { return nil }
        return ClipboardItem.imagesDirectory.appendingPathComponent(path)
    }

    /// Base Application Support directory for ClipVault
    static var appSupportDirectory: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ClipVault", isDirectory: true)
    }

    /// Directory for storing thumbnails
    static var thumbnailsDirectory: URL {
        appSupportDirectory.appendingPathComponent("thumbnails", isDirectory: true)
    }

    /// Directory for storing full images
    static var imagesDirectory: URL {
        appSupportDirectory.appendingPathComponent("images", isDirectory: true)
    }

    /// Ensures all required directories exist
    static func ensureDirectoriesExist() throws {
        let fileManager = FileManager.default
        let directories = [appSupportDirectory, thumbnailsDirectory, imagesDirectory]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
}

// MARK: - Fetch Requests

extension ClipboardItem {

    /// Fetch recent unpinned items sorted by timestamp descending
    static func recentItems(limit: Int) -> NSFetchRequest<ClipboardItem> {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.predicate = NSPredicate(format: "isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        return request
    }

    /// Fetch all pinned items sorted by timestamp descending
    static func pinnedItems() -> NSFetchRequest<ClipboardItem> {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.predicate = NSPredicate(format: "isPinned == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }

    /// Search items by text content (case-insensitive)
    static func search(query: String) -> NSFetchRequest<ClipboardItem> {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.predicate = NSPredicate(format: "textContent CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }

    /// Find item by content hash for duplicate detection
    static func findByHash(_ hash: String, after date: Date) -> NSFetchRequest<ClipboardItem> {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.predicate = NSPredicate(
            format: "contentHash == %@ AND timestamp > %@",
            hash, date as NSDate
        )
        request.fetchLimit = 1
        return request
    }

    /// Fetch oldest unpinned items for eviction
    static func oldestUnpinned(count: Int) -> NSFetchRequest<ClipboardItem> {
        let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        request.predicate = NSPredicate(format: "isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        request.fetchLimit = count
        return request
    }
}
