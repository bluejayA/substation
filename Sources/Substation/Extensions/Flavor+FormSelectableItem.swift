import Foundation
import OSClient

// MARK: - Flavor + FormSelectableItem

extension Flavor: FormSelectableItem, FormSelectorItem {
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

        // Search in resource specs (e.g., "4cpu", "8gb", "16")
        let vcpuString = "\(vcpus)cpu"
        let ramString = "\(ram / 1024)gb"
        let diskString = "\(disk)gb"

        if vcpuString.contains(lowercaseQuery) ||
           ramString.contains(lowercaseQuery) ||
           diskString.contains(lowercaseQuery) {
            return true
        }

        return false
    }
}

// MARK: - FlavorRecommendation + FormSelectableItem

extension FlavorRecommendation: FormSelectableItem {
    public var id: String {
        recommendedFlavor.id
    }

    public var sortKey: String {
        return recommendedFlavor.name ?? recommendedFlavor.id
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Search in recommended flavor
        if recommendedFlavor.matchesSearch(query) {
            return true
        }

        // Search in reasoning text
        if reasoning.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in scenario name (extracted from reasoning)
        if let scenarioRange = reasoning.range(of: "SCENARIO: "),
           let lineEndRange = reasoning.range(of: "\n", range: scenarioRange.upperBound..<reasoning.endIndex) {
            let scenarioName = String(reasoning[scenarioRange.upperBound..<lineEndRange.lowerBound])
            if scenarioName.lowercased().contains(lowercaseQuery) {
                return true
            }
        }

        return false
    }
}
