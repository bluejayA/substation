import Foundation
import OSClient

// MARK: - QoSPolicy FormSelectorItem Conformance

extension QoSPolicy: FormSelectableItem, FormSelectorItem {
    public var sortKey: String { name ?? id }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return (name?.lowercased().contains(lowercaseQuery) ?? false) ||
               id.lowercased().contains(lowercaseQuery)
    }
}
