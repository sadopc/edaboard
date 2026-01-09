import Foundation
import AppKit
import CoreGraphics
import ImageIO

extension Data {

    /// Creates an NSImage from the data
    func toNSImage() -> NSImage? {
        return NSImage(data: self)
    }

    /// Creates a CGImage from the data using ImageIO (faster than NSImage)
    func toCGImage() -> CGImage? {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Gets image dimensions without loading the full image into memory
    func imageDimensions() -> CGSize? {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [CFString: Any] else {
            return nil
        }

        guard let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    /// Generates a thumbnail from image data using CGImageSource (fast)
    /// - Parameters:
    ///   - maxSize: Maximum dimension (width or height) of the thumbnail
    ///   - quality: JPEG compression quality (0.0 to 1.0)
    /// - Returns: JPEG data of the thumbnail, or nil if generation fails
    func generateThumbnail(maxSize: CGFloat, quality: CGFloat = Constants.thumbnailQuality) -> Data? {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return thumbnail.jpegData(compressionQuality: quality)
    }

    /// Detects if the data is PNG format
    var isPNG: Bool {
        guard count >= 8 else { return false }
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        return self.prefix(8).elementsEqual(pngSignature)
    }

    /// Detects if the data is TIFF format
    var isTIFF: Bool {
        guard count >= 4 else { return false }
        let bytes = [UInt8](self.prefix(4))
        // Little-endian TIFF
        if bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00 {
            return true
        }
        // Big-endian TIFF
        if bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A {
            return true
        }
        return false
    }

    /// Detects if the data is JPEG format
    var isJPEG: Bool {
        guard count >= 2 else { return false }
        let bytes = [UInt8](self.prefix(2))
        return bytes[0] == 0xFF && bytes[1] == 0xD8
    }

    /// Returns the appropriate file extension for the image data
    var imageFileExtension: String {
        if isPNG { return "png" }
        if isTIFF { return "tiff" }
        if isJPEG { return "jpg" }
        return "dat"
    }
}

extension CGImage {

    /// Converts CGImage to JPEG data
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]

        CGImageDestinationAddImage(destination, self, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }

    /// Converts CGImage to PNG data
    func pngData() -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, self, nil)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }
}
