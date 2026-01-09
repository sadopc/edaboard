import Foundation
import AppKit
import CommonCrypto

/// Errors that can occur during clipboard monitoring
enum ClipboardMonitorError: Error {
    case accessDenied
    case pasteboardUnavailable
    case contentTooLarge
}

/// Actor for monitoring system clipboard changes and extracting content.
/// Uses timer-based polling with NSPasteboard.changeCount comparison.
actor ClipboardMonitor {

    static let shared = ClipboardMonitor()

    private var lastChangeCount = 0
    private var monitorTask: Task<Void, Never>?
    private var streamContinuation: AsyncStream<ClipboardContent>.Continuation?

    private let pasteboard = NSPasteboard.general

    private(set) var isMonitoring = false

    private init() {}

    // MARK: - Monitoring Control

    /// Start monitoring clipboard at specified interval
    func startMonitoring(interval: TimeInterval = Constants.defaultPollingInterval) {
        guard !isMonitoring else {
            print("[ClipVault] Already monitoring clipboard")
            return
        }

        isMonitoring = true
        lastChangeCount = pasteboard.changeCount
        print("[ClipVault] Starting clipboard monitoring with interval: \(interval)s, initial changeCount: \(lastChangeCount)")

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))

                guard !Task.isCancelled else { break }

                if let self = self, let content = await self.checkForChanges() {
                    print("[ClipVault] New content detected: \(content.textContent?.prefix(50) ?? "no text")")
                    await self.yieldContent(content)
                }
            }
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
        streamContinuation?.finish()
    }

    /// Check for changes immediately (manual trigger)
    func checkNow() async -> ClipboardContent? {
        return await checkForChanges()
    }

    // MARK: - Content Stream

    /// Stream of new clipboard content - must be called from an async context
    func makeContentStream() -> AsyncStream<ClipboardContent> {
        // Store continuation in a local variable for the closure
        let (stream, continuation) = AsyncStream.makeStream(of: ClipboardContent.self)

        // Store the continuation for yielding content
        self.streamContinuation = continuation

        // Handle termination
        continuation.onTermination = { @Sendable [weak self] _ in
            Task {
                await self?.stopMonitoring()
            }
        }

        return stream
    }

    private func yieldContent(_ content: ClipboardContent) {
        streamContinuation?.yield(content)
    }

    // MARK: - Private Methods

    private func checkForChanges() async -> ClipboardContent? {
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else {
            return nil
        }

        print("[ClipVault] Clipboard changed: \(lastChangeCount) -> \(currentCount)")
        lastChangeCount = currentCount

        // Check for sensitive content (if filtering is enabled)
        if await shouldFilterSensitiveContent() && pasteboard.containsSensitiveContent() {
            print("[ClipVault] Filtered: sensitive content")
            return nil
        }

        // Check if source app is ignored
        if let bundleId = pasteboard.sourceAppBundleId(),
           await isAppIgnored(bundleId) {
            print("[ClipVault] Filtered: ignored app \(bundleId)")
            return nil
        }

        let content = extractContent()
        if content == nil {
            print("[ClipVault] extractContent returned nil - types: \(pasteboard.types?.map { $0.rawValue } ?? [])")
        }
        return content
    }

    private func isAppIgnored(_ bundleId: String) async -> Bool {
        await MainActor.run {
            SettingsManager.shared.ignoredAppBundleIds.contains(bundleId)
        }
    }

    private func shouldFilterSensitiveContent() async -> Bool {
        await MainActor.run {
            SettingsManager.shared.filterSensitiveContent
        }
    }

    private func extractContent() -> ClipboardContent? {
        guard let types = pasteboard.types else {
            return nil
        }

        let textContent = pasteboard.extractPlainText()
        let rtfData = pasteboard.extractRTFData()
        let htmlContent = pasteboard.extractHTMLContent()
        let imageData = pasteboard.extractImageData()
        let fileURLs = pasteboard.extractFileURLs()
        let urlContent = pasteboard.extractURL()

        // Calculate content hash for duplicate detection
        let hash = calculateHash(
            textContent: textContent,
            imageData: imageData,
            fileURLs: fileURLs
        )

        // Skip if empty
        if textContent == nil && imageData == nil && fileURLs == nil && urlContent == nil {
            return nil
        }

        return ClipboardContent(
            types: types.map { $0.rawValue },
            textContent: textContent,
            rtfData: rtfData,
            htmlContent: htmlContent,
            imageData: imageData,
            fileURLs: fileURLs,
            urlContent: urlContent,
            sourceAppBundleId: pasteboard.sourceAppBundleId(),
            sourceAppName: pasteboard.sourceAppName(),
            capturedAt: Date(),
            contentHash: hash
        )
    }

    private func calculateHash(
        textContent: String?,
        imageData: Data?,
        fileURLs: [URL]?
    ) -> String {
        var dataToHash = Data()

        if let text = textContent {
            if let textData = text.data(using: .utf8) {
                dataToHash.append(textData)
            }
        }

        if let image = imageData {
            // For large images, just hash a sample
            if image.count > 1024 * 1024 {
                dataToHash.append(image.prefix(1024))
                dataToHash.append(image.suffix(1024))
            } else {
                dataToHash.append(image)
            }
        }

        if let urls = fileURLs {
            let urlString = urls.map { $0.absoluteString }.joined()
            if let urlData = urlString.data(using: .utf8) {
                dataToHash.append(urlData)
            }
        }

        return dataToHash.sha256Hash
    }

    // MARK: - Source App Detection

    /// Get information about the app that owns the current clipboard content
    func sourceAppInfo() -> (bundleId: String?, name: String?) {
        return (pasteboard.sourceAppBundleId(), pasteboard.sourceAppName())
    }
}
