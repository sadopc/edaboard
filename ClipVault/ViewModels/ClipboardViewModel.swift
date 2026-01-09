import SwiftUI
import CoreData

/// ViewModel for managing clipboard history display and interactions.
/// Uses @MainActor for UI thread safety and integrates with ClipboardMonitor and HistoryStore.
@MainActor
final class ClipboardViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current clipboard items (unpinned, sorted by timestamp descending)
    @Published private(set) var items: [ClipboardItem] = []

    /// Pinned clipboard items (sorted by timestamp descending)
    @Published private(set) var pinnedItems: [ClipboardItem] = []

    /// Currently selected item (for keyboard navigation)
    @Published var selectedItem: ClipboardItem?

    /// Search query text
    @Published var searchText: String = ""

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error message to display
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var monitoringTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Items filtered by search text
    var filteredItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { item in
            item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    /// Filtered pinned items by search text
    var filteredPinnedItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return pinnedItems }
        return pinnedItems.filter { item in
            item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    /// All items combined (pinned first, then regular)
    var allItems: [ClipboardItem] {
        filteredPinnedItems + filteredItems
    }

    /// Check if there are any items to display
    var hasItems: Bool {
        !allItems.isEmpty
    }

    // MARK: - Initialization

    init() {
        Task {
            await loadItems()
            startMonitoring()
        }
    }

    deinit {
        monitoringTask?.cancel()
    }

    // MARK: - Public Methods

    /// Load items from the history store
    func loadItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let limit = SettingsManager.shared.historyLimit
            // Use MainActor-isolated methods for UI fetching
            items = try HistoryStore.shared.fetchRecentForUI(limit: limit)
            pinnedItems = try HistoryStore.shared.fetchPinnedForUI()
        } catch {
            errorMessage = "Failed to load clipboard history: \(error.localizedDescription)"
        }
    }

    /// Refresh items from the history store
    func refresh() async {
        await loadItems()
    }

    /// Select the next item in the list (for keyboard navigation)
    func selectNext() {
        let allItems = self.allItems
        guard !allItems.isEmpty else { return }

        if let current = selectedItem,
           let currentIndex = allItems.firstIndex(of: current) {
            let nextIndex = min(currentIndex + 1, allItems.count - 1)
            selectedItem = allItems[nextIndex]
        } else {
            selectedItem = allItems.first
        }
    }

    /// Select the previous item in the list (for keyboard navigation)
    func selectPrevious() {
        let allItems = self.allItems
        guard !allItems.isEmpty else { return }

        if let current = selectedItem,
           let currentIndex = allItems.firstIndex(of: current) {
            let previousIndex = max(currentIndex - 1, 0)
            selectedItem = allItems[previousIndex]
        } else {
            selectedItem = allItems.last
        }
    }

    /// Select item by index (for Cmd+1-9 quick paste)
    func selectItem(at index: Int) {
        let allItems = self.allItems
        guard index >= 0 && index < allItems.count else { return }
        selectedItem = allItems[index]
    }

    /// Get item at index (for Cmd+1-9 quick paste)
    func item(at index: Int) -> ClipboardItem? {
        let allItems = self.allItems
        guard index >= 0 && index < allItems.count else { return nil }
        return allItems[index]
    }

    /// Paste the specified item
    func paste(_ item: ClipboardItem, asPlainText: Bool = false) async {
        do {
            try await PasteService.shared.paste(item, asPlainText: asPlainText)
        } catch {
            errorMessage = "Failed to paste: \(error.localizedDescription)"
        }
    }

    /// Paste the currently selected item
    func pasteSelected(asPlainText: Bool = false) async {
        guard let item = selectedItem else { return }
        await paste(item, asPlainText: asPlainText)
    }

    /// Toggle pin status for an item
    func togglePin(_ item: ClipboardItem) async {
        do {
            try await HistoryStore.shared.togglePin(objectID: item.objectID)
            await loadItems()
        } catch {
            errorMessage = "Failed to toggle pin: \(error.localizedDescription)"
        }
    }

    /// Delete an item
    func delete(_ item: ClipboardItem) async {
        do {
            try await HistoryStore.shared.delete(objectID: item.objectID)
            await loadItems()
        } catch {
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
        }
    }

    /// Clear all history (unpinned items only)
    func clearHistory() async {
        do {
            try await HistoryStore.shared.clearHistory()
            await loadItems()
        } catch {
            errorMessage = "Failed to clear history: \(error.localizedDescription)"
        }
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Start listening for Core Data changes to refresh the UI
    private func startMonitoring() {
        // Listen for Core Data changes via NotificationCenter
        // The AppDelegate handles saving via ClipboardMonitor, we just refresh when data changes
        monitoringTask = Task {
            let notifications = NotificationCenter.default.notifications(
                named: .NSManagedObjectContextDidSave,
                object: nil
            )
            for await _ in notifications {
                print("[ClipVault] Core Data changed, reloading items...")
                await loadItems()
            }
        }
    }
}
