// Sources/Substation/Modules/Magnum/Extensions/ClusterTemplate+FormSelectableItem.swift
import Foundation
import OSClient

/// Extension to make ClusterTemplate conform to FormSelectableItem and FormSelectorItem
///
/// This enables cluster templates to be used in form selectors for cluster creation.
extension ClusterTemplate: FormSelectableItem, FormSelectorItem {
    /// Unique identifier for form selection
    public var id: String {
        return uuid
    }

    /// Sort key for ordering templates
    var sortKey: String {
        return displayName
    }

    /// Check if template matches a search query
    ///
    /// - Parameter query: The search query string
    /// - Returns: true if the template matches the query
    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Search in name
        if let name = name, name.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in COE (Container Orchestration Engine)
        if coe.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in UUID
        if uuid.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in image ID
        if imageId.lowercased().contains(lowercaseQuery) {
            return true
        }

        return false
    }
}
