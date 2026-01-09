import Foundation
import CoreGraphics
import ImageIO

/// Errors that can occur during image processing
enum ImageProcessorError: Error {
    case invalidImageData
    case thumbnailGenerationFailed
    case saveFailed(underlying: Error)
    case imageTooLarge(size: Int, max: Int)
}

/// Actor for generating thumbnails and managing image file storage.
/// Uses CGImageSource for efficient thumbnail generation (40x faster than NSImage).
actor ImageProcessor {

    static let shared = ImageProcessor()

    private let fileManager = FileManager.default

    private init() {
        // Ensure directories exist on initialization
        Task {
            try? await ensureDirectoriesExist()
        }
    }

    // MARK: - Directory Management

    private func ensureDirectoriesExist() throws {
        try ClipboardItem.ensureDirectoriesExist()
    }

    // MARK: - Thumbnail Generation

    /// Generate thumbnail from image data using CGImageSource (fast)
    /// - Parameters:
    ///   - data: Original image data
    ///   - maxSize: Maximum dimension (width or height) of the thumbnail
    /// - Returns: JPEG data of the thumbnail, or nil if generation fails
    func generateThumbnail(from data: Data, maxSize: CGFloat = Constants.thumbnailMaxSize) async -> Data? {
        return data.generateThumbnail(maxSize: maxSize, quality: Constants.thumbnailQuality)
    }

    // MARK: - File Operations

    /// Save full image to disk
    /// - Parameters:
    ///   - data: Image data to save
    ///   - id: UUID for the clipboard item
    /// - Returns: Relative path to the saved image
    func saveFullImage(_ data: Data, id: UUID) async throws -> String {
        // Check size limit
        if data.count > Constants.maxImageSize {
            throw ImageProcessorError.imageTooLarge(size: data.count, max: Constants.maxImageSize)
        }

        try ensureDirectoriesExist()

        let filename = "\(id.uuidString).\(data.imageFileExtension)"
        let url = ClipboardItem.imagesDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url)
            return filename
        } catch {
            throw ImageProcessorError.saveFailed(underlying: error)
        }
    }

    /// Save thumbnail to disk
    /// - Parameters:
    ///   - data: Thumbnail image data (JPEG)
    ///   - id: UUID for the clipboard item
    /// - Returns: Relative path to the saved thumbnail
    func saveThumbnail(_ data: Data, id: UUID) async throws -> String {
        try ensureDirectoriesExist()

        let filename = "\(id.uuidString).jpg"
        let url = ClipboardItem.thumbnailsDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url)
            return filename
        } catch {
            throw ImageProcessorError.saveFailed(underlying: error)
        }
    }

    /// Load thumbnail data from path
    /// - Parameter path: Relative path to thumbnail file
    /// - Returns: Image data, or nil if not found
    func loadThumbnail(path: String) async -> Data? {
        let url = ClipboardItem.thumbnailsDirectory.appendingPathComponent(path)
        return try? Data(contentsOf: url)
    }

    /// Load full image data from path
    /// - Parameter path: Relative path to image file
    /// - Returns: Image data, or nil if not found
    func loadFullImage(path: String) async -> Data? {
        let url = ClipboardItem.imagesDirectory.appendingPathComponent(path)
        return try? Data(contentsOf: url)
    }

    /// Delete image files for an item
    /// - Parameters:
    ///   - thumbnailPath: Relative path to thumbnail, or nil
    ///   - fullImagePath: Relative path to full image, or nil
    func deleteImages(thumbnailPath: String?, fullImagePath: String?) async {
        if let thumbnailPath = thumbnailPath {
            let url = ClipboardItem.thumbnailsDirectory.appendingPathComponent(thumbnailPath)
            try? fileManager.removeItem(at: url)
        }

        if let fullImagePath = fullImagePath {
            let url = ClipboardItem.imagesDirectory.appendingPathComponent(fullImagePath)
            try? fileManager.removeItem(at: url)
        }
    }

    /// Calculate image dimensions without loading full image into memory
    /// - Parameter data: Image data
    /// - Returns: Image dimensions, or nil if data is invalid
    func imageDimensions(from data: Data) async -> CGSize? {
        return data.imageDimensions()
    }

    // MARK: - Batch Operations

    /// Delete all orphaned image files not referenced by any ClipboardItem
    func cleanupOrphanedImages(validPaths: Set<String>) async {
        await cleanupDirectory(ClipboardItem.thumbnailsDirectory, validPaths: validPaths)
        await cleanupDirectory(ClipboardItem.imagesDirectory, validPaths: validPaths)
    }

    private func cleanupDirectory(_ directory: URL, validPaths: Set<String>) async {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return
        }

        for filename in contents {
            if !validPaths.contains(filename) {
                let url = directory.appendingPathComponent(filename)
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// Get total size of stored images in bytes
    func totalStorageSize() async -> Int64 {
        var total: Int64 = 0

        for directory in [ClipboardItem.thumbnailsDirectory, ClipboardItem.imagesDirectory] {
            if let contents = try? fileManager.contentsOfDirectory(atPath: directory.path) {
                for filename in contents {
                    let url = directory.appendingPathComponent(filename)
                    if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                       let size = attributes[.size] as? Int64 {
                        total += size
                    }
                }
            }
        }

        return total
    }
}
