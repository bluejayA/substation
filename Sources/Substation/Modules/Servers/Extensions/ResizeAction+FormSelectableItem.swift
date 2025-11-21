import Foundation

// MARK: - ResizeAction + FormSelectableItem

extension ResizeAction: FormSelectableItem {
    var id: String {
        switch self {
        case .confirmResize:
            return "confirm"
        case .revertResize:
            return "revert"
        }
    }

    var sortKey: String {
        return id
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return name.lowercased().contains(lowercaseQuery) ||
               description.lowercased().contains(lowercaseQuery)
    }

    var name: String {
        switch self {
        case .confirmResize:
            return "Confirm Resize"
        case .revertResize:
            return "Revert Resize"
        }
    }

    var description: String {
        switch self {
        case .confirmResize:
            return "Accept the new server size"
        case .revertResize:
            return "Return to the original server size"
        }
    }
}
