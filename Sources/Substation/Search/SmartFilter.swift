import Foundation
import OSClient
import struct OSClient.Port

// MARK: - Smart Filter System

actor SmartFilter {
    private var activeFilters: [SearchFilter] = []
    private var filterSuggestions: FilterSuggestionEngine = FilterSuggestionEngine()
    private var dynamicFilters: DynamicFilterManager = DynamicFilterManager()

    // MARK: - Filter Management

    func addFilter(_ filter: SearchFilter) {
        // Remove existing filter of the same type if exists
        removeFilter(ofType: type(of: filter.type))

        activeFilters.append(filter)
        Logger.shared.logDebug("SmartFilter - Added filter: \(filter.description)")
    }

    func removeFilter(_ filterId: String) {
        activeFilters.removeAll { $0.id == filterId }
        Logger.shared.logDebug("SmartFilter - Removed filter: \(filterId)")
    }

    func removeFilter(ofType filterType: FilterType.Type) {
        activeFilters.removeAll { type(of: $0.type) == filterType }
    }

    func clearAllFilters() {
        activeFilters.removeAll()
        Logger.shared.logDebug("SmartFilter - Cleared all filters")
    }

    func getActiveFilters() -> [SearchFilter] {
        return activeFilters
    }

    // MARK: - Dynamic Filter Suggestions

    func getFilterSuggestions(
        for resources: SearchableResources,
        currentQuery: String? = nil
    ) async -> [FilterSuggestion] {
        return await filterSuggestions.generateSuggestions(
            from: resources,
            currentQuery: currentQuery,
            activeFilters: activeFilters
        )
    }

    func getQuickFilters(for resourceType: SearchResourceType) async -> [QuickFilter] {
        return await dynamicFilters.getQuickFilters(for: resourceType)
    }

    // MARK: - Filter Application

    func applyFilters(to results: [SearchResult]) -> [SearchResult] {
        guard !activeFilters.isEmpty else { return results }

        let startTime = Date().timeIntervalSinceReferenceDate
        var filteredResults = results

        for filter in activeFilters {
            filteredResults = applyFilter(filter, to: filteredResults)
        }

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        Logger.shared.logDebug("SmartFilter - Applied \(activeFilters.count) filters in \(String(format: "%.1f", duration * 1000))ms")

        return filteredResults
    }

    func validateFilter(_ filter: SearchFilter) -> FilterValidationResult {
        switch filter.type {
        case .status(let statuses):
            return validateStatusFilter(statuses)

        case .dateRange(let from, let to):
            return validateDateRangeFilter(from: from, to: to)

        case .ipAddress(let pattern):
            return validateIPFilter(pattern)

        case .metadata(let key, let value, let op):
            return validateMetadataFilter(key: key, value: value, operator: op)

        case .tags(let tags):
            return validateTagsFilter(tags)

        case .resourceType(let types):
            return validateSearchResourceTypeFilter(types)
        }
    }

    // MARK: - Private Filter Application

    private func applyFilter(_ filter: SearchFilter, to results: [SearchResult]) -> [SearchResult] {
        return results.filter { result in
            switch filter.type {
            case .status(let statuses):
                return matchesStatusFilter(result, statuses: statuses)

            case .dateRange(let from, let to):
                return matchesDateRangeFilter(result, from: from, to: to)

            case .ipAddress(let pattern):
                return matchesIPFilter(result, pattern: pattern)

            case .metadata(let key, let value, let op):
                return matchesMetadataFilter(result, key: key, value: value, operator: op)

            case .tags(let tags):
                return matchesTagsFilter(result, tags: tags)

            case .resourceType(let types):
                return types.contains(result.resourceType)
            }
        }
    }

    private func matchesStatusFilter(_ result: SearchResult, statuses: [String]) -> Bool {
        guard let resultStatus = result.status else { return false }
        return statuses.contains { status in
            resultStatus.lowercased().contains(status.lowercased())
        }
    }

    private func matchesDateRangeFilter(_ result: SearchResult, from: Date, to: Date) -> Bool {
        guard let createdAt = result.createdAt else { return false }
        return createdAt >= from && createdAt <= to
    }

    private func matchesIPFilter(_ result: SearchResult, pattern: String) -> Bool {
        return result.ipAddresses.contains { ip in
            matchesIPPattern(ip: ip, pattern: pattern)
        }
    }

    private func matchesMetadataFilter(_ result: SearchResult, key: String, value: String, operator filterOperator: FilterOperator) -> Bool {
        guard let metadataValue = result.metadata[key] else { return false }

        switch filterOperator {
        case .equals:
            return metadataValue.lowercased() == value.lowercased()
        case .contains:
            return metadataValue.lowercased().contains(value.lowercased())
        case .startsWith:
            return metadataValue.lowercased().hasPrefix(value.lowercased())
        case .endsWith:
            return metadataValue.lowercased().hasSuffix(value.lowercased())
        }
    }

    private func matchesTagsFilter(_ result: SearchResult, tags: [String]) -> Bool {
        return tags.contains { tag in
            result.tags.contains { resultTag in
                resultTag.lowercased().contains(tag.lowercased())
            }
        }
    }

    private func matchesIPPattern(ip: String, pattern: String) -> Bool {
        if pattern.contains("/") {
            return isIPInCIDR(ip: ip, cidr: pattern)
        }

        if pattern.contains("*") {
            let regexPattern = pattern.replacingOccurrences(of: "*", with: ".*")
            return ip.range(of: regexPattern, options: .regularExpression) != nil
        }

        return ip.contains(pattern)
    }

    private func isIPInCIDR(ip: String, cidr: String) -> Bool {
        let components = cidr.components(separatedBy: "/")
        guard components.count == 2,
              let prefixLength = Int(components[1]) else {
            return false
        }

        let networkIP = components[0]
        let ipComponents = ip.components(separatedBy: ".")
        let networkComponents = networkIP.components(separatedBy: ".")

        guard ipComponents.count == 4, networkComponents.count == 4 else {
            return false
        }

        let bytesToCheck = prefixLength / 8
        for i in 0..<min(bytesToCheck, 4) {
            if ipComponents[i] != networkComponents[i] {
                return false
            }
        }

        return true
    }

    // MARK: - Filter Validation

    private func validateStatusFilter(_ statuses: [String]) -> FilterValidationResult {
        guard !statuses.isEmpty else {
            return FilterValidationResult(isValid: false, errors: ["Status filter cannot be empty"])
        }

        let validStatuses = ["active", "build", "error", "shutoff", "suspended", "paused"]
        let invalidStatuses = statuses.filter { status in
            !validStatuses.contains { $0.lowercased() == status.lowercased() }
        }

        if !invalidStatuses.isEmpty {
            return FilterValidationResult(
                isValid: false,
                errors: ["Invalid statuses: \(invalidStatuses.joined(separator: ", "))"]
            )
        }

        return FilterValidationResult(isValid: true, errors: [])
    }

    private func validateDateRangeFilter(from: Date, to: Date) -> FilterValidationResult {
        if from > to {
            return FilterValidationResult(
                isValid: false,
                errors: ["Start date must be before end date"]
            )
        }

        let now = Date()
        if from > now {
            return FilterValidationResult(
                isValid: false,
                errors: ["Start date cannot be in the future"]
            )
        }

        return FilterValidationResult(isValid: true, errors: [])
    }

    private func validateIPFilter(_ pattern: String) -> FilterValidationResult {
        if pattern.isEmpty {
            return FilterValidationResult(
                isValid: false,
                errors: ["IP pattern cannot be empty"]
            )
        }

        // Validate CIDR notation
        if pattern.contains("/") {
            let components = pattern.components(separatedBy: "/")
            guard components.count == 2,
                  let prefixLength = Int(components[1]),
                  prefixLength >= 0 && prefixLength <= 32 else {
                return FilterValidationResult(
                    isValid: false,
                    errors: ["Invalid CIDR notation"]
                )
            }

            if !components[0].isValidIPAddress {
                return FilterValidationResult(
                    isValid: false,
                    errors: ["Invalid IP address in CIDR notation"]
                )
            }
        }

        return FilterValidationResult(isValid: true, errors: [])
    }

    private func validateMetadataFilter(key: String, value: String, operator filterOperator: FilterOperator) -> FilterValidationResult {
        if key.isEmpty {
            return FilterValidationResult(
                isValid: false,
                errors: ["Metadata key cannot be empty"]
            )
        }

        if value.isEmpty {
            return FilterValidationResult(
                isValid: false,
                errors: ["Metadata value cannot be empty"]
            )
        }

        return FilterValidationResult(isValid: true, errors: [])
    }

    private func validateTagsFilter(_ tags: [String]) -> FilterValidationResult {
        if tags.isEmpty {
            return FilterValidationResult(
                isValid: false,
                errors: ["Tags filter cannot be empty"]
            )
        }

        let emptyTags = tags.filter { $0.isEmpty }
        if !emptyTags.isEmpty {
            return FilterValidationResult(
                isValid: false,
                errors: ["Tags cannot be empty"]
            )
        }

        return FilterValidationResult(isValid: true, errors: [])
    }

    private func validateSearchResourceTypeFilter(_ types: [SearchResourceType]) -> FilterValidationResult {
        if types.isEmpty {
            return FilterValidationResult(
                isValid: false,
                errors: ["Resource type filter cannot be empty"]
            )
        }

        return FilterValidationResult(isValid: true, errors: [])
    }
}

// MARK: - Filter Suggestion Engine

private actor FilterSuggestionEngine {

    func generateSuggestions(
        from resources: SearchableResources,
        currentQuery: String?,
        activeFilters: [SearchFilter]
    ) async -> [FilterSuggestion] {
        var suggestions: [FilterSuggestion] = []

        // Status suggestions
        let statusSuggestions = generateStatusSuggestions(from: resources, activeFilters: activeFilters)
        suggestions.append(contentsOf: statusSuggestions)

        // Resource type suggestions
        let typeSuggestions = generateSearchResourceTypeSuggestions(from: resources, activeFilters: activeFilters)
        suggestions.append(contentsOf: typeSuggestions)

        // Date range suggestions
        let dateSuggestions = generateDateRangeSuggestions(from: resources, activeFilters: activeFilters)
        suggestions.append(contentsOf: dateSuggestions)

        // Metadata suggestions
        let metadataSuggestions = generateMetadataSuggestions(from: resources, activeFilters: activeFilters)
        suggestions.append(contentsOf: metadataSuggestions)

        return suggestions.sorted { $0.relevance > $1.relevance }
    }

    private func generateStatusSuggestions(from resources: SearchableResources, activeFilters: [SearchFilter]) -> [FilterSuggestion] {
        // Skip if status filter already active
        if activeFilters.contains(where: { filter in
            if case .status = filter.type { return true }
            return false
        }) {
            return []
        }

        var statusCounts: [String: Int] = [:]

        // Count server statuses
        for server in resources.servers {
            if let status = server.status?.rawValue {
                statusCounts[status.lowercased()] = (statusCounts[status.lowercased()] ?? 0) + 1
            }
        }

        // Count volume statuses
        for volume in resources.volumes {
            if let status = volume.status {
                statusCounts[status.lowercased()] = (statusCounts[status.lowercased()] ?? 0) + 1
            }
        }

        var suggestions: [FilterSuggestion] = []

        for (status, count) in statusCounts {
            if count > 0 {
                suggestions.append(FilterSuggestion(
                    title: "Status: \(status.capitalized)",
                    description: "\(count) resources with status '\(status)'",
                    filterType: .status([status]),
                    relevance: Double(count) / 100.0
                ))
            }
        }

        return suggestions
    }

    private func generateSearchResourceTypeSuggestions(from resources: SearchableResources, activeFilters: [SearchFilter]) -> [FilterSuggestion] {
        var suggestions: [FilterSuggestion] = []

        let resourceCounts = [
            (SearchResourceType.server, resources.servers.count),
            (SearchResourceType.network, resources.networks.count),
            (SearchResourceType.volume, resources.volumes.count),
            (SearchResourceType.image, resources.images.count),
            (SearchResourceType.flavor, resources.flavors.count),
            (SearchResourceType.securityGroup, resources.securityGroups.count)
        ]

        for (type, count) in resourceCounts {
            if count > 0 {
                suggestions.append(FilterSuggestion(
                    title: "Type: \(type.displayName)",
                    description: "\(count) \(type.displayName.lowercased()) resources",
                    filterType: .resourceType([type]),
                    relevance: Double(count) / 1000.0
                ))
            }
        }

        return suggestions
    }

    private func generateDateRangeSuggestions(from resources: SearchableResources, activeFilters: [SearchFilter]) -> [FilterSuggestion] {
        // Skip if date range filter already active
        if activeFilters.contains(where: { filter in
            if case .dateRange = filter.type { return true }
            return false
        }) {
            return []
        }

        var suggestions: [FilterSuggestion] = []
        let now = Date()

        // Last 24 hours
        let last24Hours = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        suggestions.append(FilterSuggestion(
            title: "Last 24 hours",
            description: "Resources created in the last 24 hours",
            filterType: .dateRange(from: last24Hours, to: now),
            relevance: 0.8
        ))

        // Last 7 days
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        suggestions.append(FilterSuggestion(
            title: "Last 7 days",
            description: "Resources created in the last week",
            filterType: .dateRange(from: lastWeek, to: now),
            relevance: 0.7
        ))

        // Last 30 days
        let lastMonth = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        suggestions.append(FilterSuggestion(
            title: "Last 30 days",
            description: "Resources created in the last month",
            filterType: .dateRange(from: lastMonth, to: now),
            relevance: 0.6
        ))

        return suggestions
    }

    private func generateMetadataSuggestions(from resources: SearchableResources, activeFilters: [SearchFilter]) -> [FilterSuggestion] {
        var metadataKeys: Set<String> = []

        // Collect common metadata keys
        for server in resources.servers {
            if let metadata = server.metadata {
                metadataKeys.formUnion(metadata.keys)
            }
        }

        for volume in resources.volumes {
            if let metadata = volume.metadata {
                metadataKeys.formUnion(metadata.keys)
            }
        }

        var suggestions: [FilterSuggestion] = []

        for key in metadataKeys.prefix(5) { // Limit to top 5 metadata keys
            suggestions.append(FilterSuggestion(
                title: "Has metadata: \(key)",
                description: "Resources with '\(key)' metadata",
                filterType: .metadata(key: key, value: "", operator: .contains),
                relevance: 0.4
            ))
        }

        return suggestions
    }
}

// MARK: - Dynamic Filter Manager

private actor DynamicFilterManager {

    func getQuickFilters(for resourceType: SearchResourceType) async -> [QuickFilter] {
        switch resourceType {
        case .server:
            return getServerQuickFilters()
        case .network:
            return getNetworkQuickFilters()
        case .volume:
            return getVolumeQuickFilters()
        case .image:
            return getImageQuickFilters()
        default:
            return getGenericQuickFilters()
        }
    }

    private func getServerQuickFilters() -> [QuickFilter] {
        return [
            QuickFilter(
                name: "Active Servers",
                description: "Show only active servers",
                filter: SearchFilter(type: .status(["active"]))
            ),
            QuickFilter(
                name: "Error Servers",
                description: "Show servers with errors",
                filter: SearchFilter(type: .status(["error"]))
            ),
            QuickFilter(
                name: "Building Servers",
                description: "Show servers currently building",
                filter: SearchFilter(type: .status(["build"]))
            )
        ]
    }

    private func getNetworkQuickFilters() -> [QuickFilter] {
        return [
            QuickFilter(
                name: "Active Networks",
                description: "Show only active networks",
                filter: SearchFilter(type: .status(["active"]))
            ),
            QuickFilter(
                name: "External Networks",
                description: "Show external networks",
                filter: SearchFilter(type: .metadata(key: "router:external", value: "true", operator: .equals))
            )
        ]
    }

    private func getVolumeQuickFilters() -> [QuickFilter] {
        return [
            QuickFilter(
                name: "Available Volumes",
                description: "Show available volumes",
                filter: SearchFilter(type: .status(["available"]))
            ),
            QuickFilter(
                name: "In-Use Volumes",
                description: "Show volumes currently in use",
                filter: SearchFilter(type: .status(["in-use"]))
            ),
            QuickFilter(
                name: "Boot Volumes",
                description: "Show bootable volumes",
                filter: SearchFilter(type: .metadata(key: "bootable", value: "true", operator: .equals))
            )
        ]
    }

    private func getImageQuickFilters() -> [QuickFilter] {
        return [
            QuickFilter(
                name: "Active Images",
                description: "Show active images",
                filter: SearchFilter(type: .status(["active"]))
            ),
            QuickFilter(
                name: "Public Images",
                description: "Show public images",
                filter: SearchFilter(type: .metadata(key: "visibility", value: "public", operator: .equals))
            )
        ]
    }

    private func getGenericQuickFilters() -> [QuickFilter] {
        let now = Date()
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        return [
            QuickFilter(
                name: "Recent",
                description: "Show resources from last 7 days",
                filter: SearchFilter(type: .dateRange(from: lastWeek, to: now))
            )
        ]
    }
}

// MARK: - Supporting Types

struct FilterSuggestion {
    let title: String
    let description: String
    let filterType: FilterType
    let relevance: Double
}

struct QuickFilter {
    let name: String
    let description: String
    let filter: SearchFilter
}

struct FilterValidationResult {
    let isValid: Bool
    let errors: [String]

    static let valid = FilterValidationResult(isValid: true, errors: [])

    static func invalid(_ errors: [String]) -> FilterValidationResult {
        return FilterValidationResult(isValid: false, errors: errors)
    }
}

