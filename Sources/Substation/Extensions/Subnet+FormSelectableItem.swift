import Foundation
import OSClient

extension Subnet: FormSelectableItem, FormSelectorItem {
    var sortKey: String {
        return name ?? id
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        if let name = name, name.lowercased().contains(lowercaseQuery) {
            return true
        }

        if id.lowercased().contains(lowercaseQuery) {
            return true
        }

        if cidr.lowercased().contains(lowercaseQuery) {
            return true
        }

        return false
    }
}
