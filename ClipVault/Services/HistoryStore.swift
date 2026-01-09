import Foundation
@preconcurrency import CoreData

/// Errors that can occur during history store operations
enum HistoryStoreError: Error {
    case itemNotFound(UUID)
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case migrationRequired
}

/// Content extracted from clipboard for saving
struct ClipboardContent: Sendable {
    let types: [String]
    let textContent: String?
    let rtfData: Data?
    let htmlContent: String?
    let imageData: Data?
    let fileURLs: [URL]?
    let urlContent: URL?
    let sourceAppBundleId: String?
    let sourceAppName: String?
    let capturedAt: Date
    let contentHash: String
}

/// Actor for persisting and querying clipboard history using Core Data.
actor HistoryStore {

    static let shared = HistoryStore()

    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    /// View context for main-thread UI operations
    nonisolated private var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    private init() {
        container = NSPersistentContainer(name: "ClipVault")

        // Enable lightweight migration
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        // Set the store URL to Application Support
        let storeURL = ClipboardItem.appSupportDirectory.appendingPathComponent("ClipVault.sqlite")
        description?.url = storeURL

        // Create directories if needed
        try? FileManager.default.createDirectory(
            at: ClipboardItem.appSupportDirectory,
            withIntermediateDirectories: true
        )

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }

        // Configure view context for main thread
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save Operations

    /// Save new clipboard content
    /// - Parameter content: The clipboard content to save
    func save(_ content: ClipboardContent) async throws {
        // Process image data outside of Core Data perform block
        var thumbnailPath: String?
        var fullImagePath: String?
        let itemId = UUID()

        let contentType = Self.determineContentType(from: content)

        // Handle image saving before Core Data transaction
        if contentType == .image, let imageData = content.imageData {
            do {
                // Generate and save thumbnail
                if let thumbnailData = await ImageProcessor.shared.generateThumbnail(from: imageData) {
                    thumbnailPath = try await ImageProcessor.shared.saveThumbnail(thumbnailData, id: itemId)
                }

                // Save full image (unless too large)
                if imageData.count <= Constants.maxImageSize {
                    fullImagePath = try await ImageProcessor.shared.saveFullImage(imageData, id: itemId)
                }
            } catch {
                // Log but don't fail - we can still save the item without images
                print("Warning: Failed to save image files: \(error)")
            }
        }

        try await context.perform { [content, thumbnailPath, fullImagePath, itemId] in
            let item = ClipboardItem(context: self.context)

            item.id = itemId
            item.timestamp = content.capturedAt
            item.contentHash = content.contentHash
            item.sourceAppBundleId = content.sourceAppBundleId
            item.sourceAppName = content.sourceAppName
            item.isPinned = false

            // Determine content type and set appropriate fields
            let contentType = Self.determineContentType(from: content)
            item.contentType = contentType.rawValue

            switch contentType {
            case .image:
                item.textContent = nil
                item.dataSize = Int64(content.imageData?.count ?? 0)
                item.thumbnailPath = thumbnailPath
                item.fullImagePath = fullImagePath

            case .fileReference:
                if let urls = content.fileURLs, let firstURL = urls.first {
                    item.fileURLString = firstURL.absoluteString
                    item.fileName = firstURL.lastPathComponent
                    item.textContent = urls.map { $0.lastPathComponent }.joined(separator: ", ")
                }
                item.dataSize = 0

            case .url:
                if let url = content.urlContent {
                    item.urlString = url.absoluteString
                    item.textContent = url.absoluteString
                }
                item.dataSize = Int64(item.textContent?.data(using: .utf8)?.count ?? 0)

            case .richText:
                item.rtfData = content.rtfData
                item.textContent = content.textContent
                item.plainTextContent = content.textContent
                item.dataSize = Int64(content.rtfData?.count ?? 0)

            case .html:
                item.htmlContent = content.htmlContent
                item.textContent = content.textContent
                item.plainTextContent = content.textContent
                item.dataSize = Int64(content.htmlContent?.data(using: .utf8)?.count ?? 0)

            case .plainText:
                item.textContent = content.textContent
                item.dataSize = Int64(content.textContent?.data(using: .utf8)?.count ?? 0)
            }

            try self.context.save()
        }
    }

    private static func determineContentType(from content: ClipboardContent) -> ContentType {
        if content.imageData != nil {
            return .image
        }
        if content.fileURLs != nil && !(content.fileURLs?.isEmpty ?? true) {
            return .fileReference
        }
        if content.urlContent != nil {
            return .url
        }
        if content.rtfData != nil {
            return .richText
        }
        if content.htmlContent != nil {
            return .html
        }
        return .plainText
    }

    // MARK: - Fetch Operations (Main Actor - for UI)

    /// Fetch recent unpinned items (MainActor isolated for UI use)
    @MainActor
    func fetchRecentForUI(limit: Int) throws -> [ClipboardItem] {
        let request = ClipboardItem.recentItems(limit: limit)
        do {
            return try viewContext.fetch(request)
        } catch {
            throw HistoryStoreError.fetchFailed(underlying: error)
        }
    }

    /// Fetch all pinned items (MainActor isolated for UI use)
    @MainActor
    func fetchPinnedForUI() throws -> [ClipboardItem] {
        let request = ClipboardItem.pinnedItems()
        do {
            return try viewContext.fetch(request)
        } catch {
            throw HistoryStoreError.fetchFailed(underlying: error)
        }
    }

    /// Search items by text content (MainActor isolated for UI use)
    @MainActor
    func searchForUI(query: String) throws -> [ClipboardItem] {
        let request = ClipboardItem.search(query: query)
        do {
            return try viewContext.fetch(request)
        } catch {
            throw HistoryStoreError.fetchFailed(underlying: error)
        }
    }

    // MARK: - Fetch Operations (Background)

    /// Fetch recent unpinned items
    func fetchRecent(limit: Int) async throws -> [ClipboardItem] {
        return try await context.perform {
            let request = ClipboardItem.recentItems(limit: limit)
            do {
                return try self.context.fetch(request)
            } catch {
                throw HistoryStoreError.fetchFailed(underlying: error)
            }
        }
    }

    /// Fetch all pinned items
    func fetchPinned() async throws -> [ClipboardItem] {
        return try await context.perform {
            let request = ClipboardItem.pinnedItems()
            do {
                return try self.context.fetch(request)
            } catch {
                throw HistoryStoreError.fetchFailed(underlying: error)
            }
        }
    }

    /// Search items by text content
    func search(query: String) async throws -> [ClipboardItem] {
        return try await context.perform {
            let request = ClipboardItem.search(query: query)
            do {
                return try self.context.fetch(request)
            } catch {
                throw HistoryStoreError.fetchFailed(underlying: error)
            }
        }
    }

    // MARK: - Delete Operations

    /// Delete a single item by its object ID
    func delete(objectID: NSManagedObjectID) async throws {
        // Get paths before deletion
        let (thumbnailPath, fullImagePath) = try await context.perform {
            guard let item = try? self.context.existingObject(with: objectID) as? ClipboardItem else {
                throw HistoryStoreError.itemNotFound(UUID())
            }
            let thumbPath = item.thumbnailPath
            let imagePath = item.fullImagePath
            self.context.delete(item)
            try self.context.save()
            return (thumbPath, imagePath)
        }

        // Delete associated image files
        await ImageProcessor.shared.deleteImages(
            thumbnailPath: thumbnailPath,
            fullImagePath: fullImagePath
        )
    }

    /// Delete all unpinned items (clear history)
    func clearHistory() async throws {
        // Collect paths first
        let paths: [(String?, String?)] = try await context.perform {
            let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
            request.predicate = NSPredicate(format: "isPinned == NO")

            let items = try self.context.fetch(request)
            let pathPairs = items.map { ($0.thumbnailPath, $0.fullImagePath) }

            for item in items {
                self.context.delete(item)
            }

            try self.context.save()
            return pathPairs
        }

        // Delete image files
        for (thumbnailPath, fullImagePath) in paths {
            await ImageProcessor.shared.deleteImages(
                thumbnailPath: thumbnailPath,
                fullImagePath: fullImagePath
            )
        }
    }

    // MARK: - Pin Operations

    /// Toggle pin status for an item by object ID
    func togglePin(objectID: NSManagedObjectID) async throws {
        try await context.perform {
            guard let item = try? self.context.existingObject(with: objectID) as? ClipboardItem else {
                throw HistoryStoreError.itemNotFound(UUID())
            }
            item.isPinned = !item.isPinned
            try self.context.save()
        }
    }

    // MARK: - Duplicate Detection

    /// Check if a duplicate exists within the detection window
    func isDuplicate(hash: String) async -> Bool {
        await context.perform {
            let cutoff = Date().addingTimeInterval(-Constants.duplicateDetectionWindow)
            let request = ClipboardItem.findByHash(hash, after: cutoff)

            do {
                let count = try self.context.count(for: request)
                return count > 0
            } catch {
                return false
            }
        }
    }

    // MARK: - Count Operations

    /// Count of unpinned items
    func unpinnedCount() async throws -> Int {
        return try await context.perform {
            let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
            request.predicate = NSPredicate(format: "isPinned == NO")

            do {
                return try self.context.count(for: request)
            } catch {
                throw HistoryStoreError.fetchFailed(underlying: error)
            }
        }
    }

    // MARK: - Limit Enforcement

    /// Enforce history limit by evicting oldest unpinned items
    func enforceLimit(_ limit: Int) async throws {
        // Get paths of items to delete
        let paths: [(String?, String?)] = try await context.perform {
            let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
            request.predicate = NSPredicate(format: "isPinned == NO")

            let count = try self.context.count(for: request)
            guard count > limit else { return [] }

            let toDelete = count - limit
            let oldestRequest = ClipboardItem.oldestUnpinned(count: toDelete)
            let oldestItems = try self.context.fetch(oldestRequest)

            let pathPairs = oldestItems.map { ($0.thumbnailPath, $0.fullImagePath) }

            for item in oldestItems {
                self.context.delete(item)
            }

            try self.context.save()
            return pathPairs
        }

        // Delete image files
        for (thumbnailPath, fullImagePath) in paths {
            await ImageProcessor.shared.deleteImages(
                thumbnailPath: thumbnailPath,
                fullImagePath: fullImagePath
            )
        }
    }

    // MARK: - Export

    /// Export history as JSON data
    func exportHistory() async throws -> Data {
        return try await context.perform {
            let request = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

            let items = try self.context.fetch(request)

            let exportData = items.map { item -> [String: Any] in
                var dict: [String: Any] = [
                    "id": item.id?.uuidString ?? "",
                    "timestamp": item.timestamp?.timeIntervalSince1970 ?? 0,
                    "contentType": item.contentType ?? "",
                    "isPinned": item.isPinned,
                    "dataSize": item.dataSize
                ]

                if let text = item.textContent {
                    dict["textContent"] = text
                }
                if let source = item.sourceAppName {
                    dict["sourceApp"] = source
                }

                return dict
            }

            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        }
    }
}
