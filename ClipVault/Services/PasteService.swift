import Foundation
import AppKit
import CoreData
import ApplicationServices

/// Errors that can occur during paste operations
enum PasteError: Error {
    case accessibilityRequired
    case noFrontmostApp
    case pasteFailed
    case itemContentMissing
}

/// Service for pasting clipboard content to the frontmost application.
/// Handles copying content back to system clipboard and simulating Cmd+V.
@MainActor
final class PasteService {

    // MARK: - Singleton

    static let shared = PasteService()

    // MARK: - Properties

    private let pasteboard = NSPasteboard.general

    /// Delay before simulating paste (to allow focus to return)
    private let pasteDelay: TimeInterval = 0.05

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Paste clipboard item to frontmost app
    /// - Parameters:
    ///   - item: The clipboard item to paste
    ///   - asPlainText: If true, paste as plain text (strip formatting)
    func paste(_ item: ClipboardItem, asPlainText: Bool = false) async throws {
        // Copy to clipboard first
        try await copyToClipboard(item, asPlainText: asPlainText)

        // Small delay to ensure clipboard is updated
        try await Task.sleep(for: .milliseconds(Int(pasteDelay * 1000)))

        // Simulate Cmd+V
        try await simulatePaste()

        // Play sound effect
        SoundService.shared.playPasteSound()
    }

    /// Copy item back to system clipboard (for paste)
    func copyToClipboard(_ item: ClipboardItem, asPlainText: Bool = false) async throws {
        pasteboard.clearContents()

        let contentType = item.contentTypeEnum

        switch contentType {
        case .plainText:
            guard let text = item.textContent else {
                throw PasteError.itemContentMissing
            }
            pasteboard.setString(text, forType: .string)

        case .richText:
            if asPlainText {
                if let text = item.plainTextContent ?? item.textContent {
                    pasteboard.setString(text, forType: .string)
                } else {
                    throw PasteError.itemContentMissing
                }
            } else {
                // Paste RTF data if available
                if let rtfData = item.rtfData {
                    pasteboard.setData(rtfData, forType: .rtf)
                }
                // Also set plain text as fallback
                if let text = item.textContent {
                    pasteboard.setString(text, forType: .string)
                }
            }

        case .html:
            if asPlainText {
                if let text = item.plainTextContent ?? item.textContent {
                    pasteboard.setString(text, forType: .string)
                } else {
                    throw PasteError.itemContentMissing
                }
            } else {
                // Paste HTML if available
                if let html = item.htmlContent {
                    pasteboard.setString(html, forType: .html)
                }
                // Also set plain text as fallback
                if let text = item.textContent {
                    pasteboard.setString(text, forType: .string)
                }
            }

        case .image:
            guard let imagePath = item.fullImagePath,
                  let imageURL = item.fullImageURL else {
                throw PasteError.itemContentMissing
            }

            // Load image data from file
            guard let imageData = try? Data(contentsOf: imageURL) else {
                throw PasteError.itemContentMissing
            }

            // Determine image type from extension
            let ext = (imagePath as NSString).pathExtension.lowercased()
            if ext == "png" {
                pasteboard.setData(imageData, forType: .png)
            } else {
                pasteboard.setData(imageData, forType: .tiff)
            }

        case .fileReference:
            guard let urlString = item.fileURLString,
                  let url = URL(string: urlString) else {
                throw PasteError.itemContentMissing
            }
            pasteboard.writeObjects([url as NSURL])

        case .url:
            guard let urlString = item.urlString,
                  let url = URL(string: urlString) else {
                throw PasteError.itemContentMissing
            }
            pasteboard.setString(urlString, forType: .string)
            pasteboard.writeObjects([url as NSURL])
        }
    }

    /// Simulate Cmd+V keystroke to paste
    func simulatePaste() async throws {
        // Check accessibility permission
        guard PermissionManager.shared.isAccessibilityGranted() else {
            throw PasteError.accessibilityRequired
        }

        // Get frontmost app to ensure we have somewhere to paste
        guard NSWorkspace.shared.frontmostApplication != nil else {
            throw PasteError.noFrontmostApp
        }

        // Create key down event for V
        let vKeyCode: CGKeyCode = 9

        // Create source
        let source = CGEventSource(stateID: .combinedSessionState)

        // Create key down event with Cmd modifier
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            throw PasteError.pasteFailed
        }
        keyDown.flags = .maskCommand

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            throw PasteError.pasteFailed
        }
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Copy text to clipboard without pasting
    func copyText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copy image data to clipboard without pasting
    func copyImage(_ data: Data, type: NSPasteboard.PasteboardType = .png) {
        pasteboard.clearContents()
        pasteboard.setData(data, forType: type)
    }

    /// Copy URL to clipboard without pasting
    func copyURL(_ url: URL) {
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        pasteboard.writeObjects([url as NSURL])
    }

    // MARK: - Utility Methods

    /// Check if paste simulation is available (accessibility permission granted)
    func canSimulatePaste() -> Bool {
        return PermissionManager.shared.isAccessibilityGranted()
    }

    /// Get the frontmost application name
    func frontmostAppName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
