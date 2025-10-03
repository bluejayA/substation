import Foundation
import OSClient

extension Network: FormSelectableItem, FormSelectorItem {
    var sortKey: String {
        return name ?? id
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Search in name
        if let name = name, name.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in ID
        if id.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in status
        if let status = status, status.lowercased().contains(lowercaseQuery) {
            return true
        }

        return false
    }
}
