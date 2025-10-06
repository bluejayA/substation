import Foundation
import OSClient

enum ResizeMode {
    case selectFlavor
    case confirmOrRevert
}

enum ResizeAction {
    case confirmResize
    case revertResize
}

struct ServerResizeForm {
    var selectedServer: Server?
    var availableFlavors: [Flavor] = []
    var currentFlavor: Flavor?
    var selectedFlavorIndex: Int = 0
    var pendingFlavorSelection: String? = nil
    var isLoading: Bool = false
    var errorMessage: String?
    var mode: ResizeMode = .selectFlavor
    var selectedAction: ResizeAction = .confirmResize

    init() {
        self.selectedFlavorIndex = 0
        self.pendingFlavorSelection = nil
        self.isLoading = false
        self.errorMessage = nil
        self.mode = .selectFlavor
        self.selectedAction = .confirmResize
    }

    mutating func reset() {
        selectedFlavorIndex = 0
        pendingFlavorSelection = nil
        isLoading = false
        errorMessage = nil
        mode = .selectFlavor
        selectedAction = .confirmResize
    }

    // Get current flavor information for top display
    func getCurrentFlavor() -> Flavor? {
        return currentFlavor
    }

    // Get all available flavors for management (sorted alphabetically by name)
    // Excludes the current flavor from the list
    func getAvailableFlavors() -> [Flavor] {
        let sorted = availableFlavors.sorted {
            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }

        // Filter out current flavor if it exists
        if let currentFlavorId = currentFlavor?.id {
            return sorted.filter { $0.id != currentFlavorId }
        }

        return sorted
    }

    // Toggle flavor selection
    mutating func toggleFlavorSelection(_ flavorID: String) {
        if pendingFlavorSelection == flavorID {
            pendingFlavorSelection = nil
        } else {
            pendingFlavorSelection = flavorID
        }
    }

    // Check if a flavor is selected for change
    func isFlavorSelected(_ flavorID: String) -> Bool {
        return pendingFlavorSelection == flavorID
    }

    // Check if this is the current flavor
    func isCurrentFlavor(_ flavorID: String) -> Bool {
        return currentFlavor?.id == flavorID
    }

    // Check if there are pending changes
    func hasPendingChanges() -> Bool {
        return pendingFlavorSelection != nil
    }

    // Get the selected flavor for resize
    func getSelectedFlavor() -> Flavor? {
        guard let selectedID = pendingFlavorSelection else { return nil }
        return availableFlavors.first { $0.id == selectedID }
    }

    // Toggle between confirm and revert actions
    mutating func toggleAction() {
        selectedAction = (selectedAction == .confirmResize) ? .revertResize : .confirmResize
    }

    // Check if server is in VERIFY_RESIZE state
    func isInVerifyResizeState() -> Bool {
        return selectedServer?.status == .verify
    }
}