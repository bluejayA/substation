import Foundation
import OSClient

extension KeyPair: FormSelectableItem, FormSelectorItem {
    public var id: String {
        return name ?? fingerprint ?? "unknown"
    }

    var sortKey: String {
        return name ?? "unknown"
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Search in name
        if let name = name, name.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in fingerprint
        if let fingerprint = fingerprint, fingerprint.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in type
        if let type = type, type.lowercased().contains(lowercaseQuery) {
            return true
        }

        return false
    }
}
