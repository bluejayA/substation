import Foundation
import OSClient
import struct OSClient.Port

// MARK: - Search Engine Core

actor SearchEngine {
    private var searchIndex = SearchIndex()
    private var relationshipMapper = ResourceRelationshipMapper()
    private let performanceTracker = SearchPerformanceTracker()
    private var searchIndexCache: SearchIndexCache?

    private var isIndexing = false
    private var lastIndexUpdate = Date.distantPast
    private let indexUpdateInterval: TimeInterval = 30.0 // 30 seconds

    nonisolated static let shared = SearchEngine()

    private init() {}

    // MARK: - Initialization

    func setSearchIndexCache(_ cache: SearchIndexCache) {
        self.searchIndexCache = cache
        Logger.shared.logInfo("SearchEngine - SearchIndexCache configured")
    }

    // MARK: - Public Search Interface

    func search(_ query: SearchQuery) async throws -> SearchResults {
        let startTime = Date().timeIntervalSinceReferenceDate
        let operationId = UUID().uuidString

        Logger.shared.logInfo("SearchEngine - Starting search query: '\(query.text)' (\(operationId))")

        defer {
            let duration = Date().timeIntervalSinceReferenceDate - startTime
            performanceTracker.recordSearchOperation(
                query: query.text,
                duration: duration,
                resultCount: 0,
                operationId: operationId
            )
        }

        // Check cache first (if available)
        if let cache = searchIndexCache {
            if let cachedResults = await cache.getCachedResults(for: query) {
                Logger.shared.logDebug("SearchEngine - Returning cached results for query: '\(query.text)'")
                return cachedResults
            }
        }

        // Perform search
        let results = try await performSearch(query)

        // Cache results (if cache available)
        if let cache = searchIndexCache {
            await cache.cacheResults(results, for: query)
        }

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        Logger.shared.logInfo("SearchEngine - Search completed in \(String(format: "%.1f", duration * 1000))ms, \(results.items.count) results")

        return results
    }

    func updateIndex(with resources: SearchableResources) async {
        guard !isIndexing else {
            Logger.shared.logDebug("SearchEngine - Index update already in progress, skipping")
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastIndexUpdate) >= indexUpdateInterval else {
            Logger.shared.logDebug("SearchEngine - Index updated recently, skipping")
            return
        }

        isIndexing = true
        lastIndexUpdate = now

        let startTime = Date().timeIntervalSinceReferenceDate

        await searchIndex.updateIndex(with: resources)
        await relationshipMapper.updateRelationships(with: resources)

        // Invalidate cache when index updates (if cache available)
        if let cache = searchIndexCache {
            await cache.invalidateSearchCache()
        }

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        Logger.shared.logInfo("SearchEngine - Index updated in \(String(format: "%.1f", duration * 1000))ms")

        isIndexing = false
    }

    func getRelationships(for resourceId: String, type: SearchResourceType) async -> [ResourceRelationship] {
        return await relationshipMapper.getRelationships(for: resourceId, type: type)
    }

    func getSuggestions(for partialQuery: String, limit: Int = 10) async -> [SearchSuggestion] {
        return await searchIndex.getSuggestions(for: partialQuery, limit: limit)
    }

    func getSearchStats() async -> SearchEngineStats {
        let indexStats = await searchIndex.getStats()

        // Get cache stats if available, otherwise use defaults
        let cacheHitRate: Double
        if let cache = searchIndexCache {
            let cacheStats = await cache.getStatistics()
            cacheHitRate = cacheStats.hitRate
        } else {
            cacheHitRate = 0.0
        }

        let performanceStats = performanceTracker.getStats()

        return SearchEngineStats(
            indexedResourceCount: indexStats.totalResources,
            cacheHitRate: cacheHitRate,
            averageSearchTime: performanceStats.averageSearchTime,
            isIndexing: isIndexing,
            lastIndexUpdate: lastIndexUpdate
        )
    }

    // MARK: - Private Implementation

    private func performSearch(_ query: SearchQuery) async throws -> SearchResults {
        var results: [SearchResult] = []

        // Full-text search
        if !query.text.isEmpty {
            let textResults = await searchIndex.searchText(query.text, fuzzy: query.fuzzySearch)
            results.append(contentsOf: textResults)
        }

        // Apply filters
        if !query.filters.isEmpty {
            results = applyFilters(results, filters: query.filters)
        }

        // Apply resource type filters
        if !query.resourceTypes.isEmpty {
            results = results.filter { query.resourceTypes.contains($0.resourceType) }
        }

        // Sort results
        results = sortResults(results, by: query.sorting)

        // Apply pagination
        var paginatedResults = applyPagination(results, pagination: query.pagination)

        // Enrich with relationships if requested
        if query.includeRelationships {
            for i in 0..<paginatedResults.count {
                paginatedResults[i].relationships = await relationshipMapper.getRelationships(
                    for: paginatedResults[i].resourceId,
                    type: paginatedResults[i].resourceType
                )
            }
        }

        return SearchResults(
            query: query,
            items: paginatedResults,
            totalCount: results.count,
            searchTime: 0, // Will be set by caller
            suggestions: []
        )
    }

    private func applyFilters(_ results: [SearchResult], filters: [SearchFilter]) -> [SearchResult] {
        var filteredResults = results

        for filter in filters {
            filteredResults = filteredResults.filter { result in
                switch filter.type {
                case .status(let statuses):
                    return statuses.contains { status in
                        result.status?.lowercased().contains(status.lowercased()) == true
                    }

                case .dateRange(let from, let to):
                    guard let createdAt = result.createdAt else { return false }
                    return createdAt >= from && createdAt <= to

                case .ipAddress(let ipPattern):
                    return result.ipAddresses.contains { ip in
                        ip.contains(ipPattern) || ipMatches(ip: ip, pattern: ipPattern)
                    }

                case .metadata(let key, let value, let op):
                    return matchesMetadata(result: result, key: key, value: value, operator: op)

                case .tags(let tags):
                    return tags.contains { tag in
                        result.tags.contains(tag)
                    }

                case .resourceType(let types):
                    return types.contains(result.resourceType)
                }
            }
        }

        return filteredResults
    }

    private func sortResults(_ results: [SearchResult], by sorting: SearchSorting) -> [SearchResult] {
        switch sorting {
        case .relevance:
            return results.sorted { $0.relevanceScore > $1.relevanceScore }
        case .name(let direction):
            return results.sorted {
                let nameA = $0.name ?? ""
                let nameB = $1.name ?? ""
                return direction == .ascending ? nameA < nameB : nameA > nameB
            }
        case .createdAt(let direction):
            return results.sorted {
                let dateA = $0.createdAt ?? Date.distantPast
                let dateB = $1.createdAt ?? Date.distantPast
                return direction == .ascending ? dateA < dateB : dateA > dateB
            }
        case .resourceType:
            return results.sorted { $0.resourceType.rawValue < $1.resourceType.rawValue }
        }
    }

    private func applyPagination(_ results: [SearchResult], pagination: SearchPagination) -> [SearchResult] {
        let startIndex = pagination.offset
        let endIndex = min(startIndex + pagination.limit, results.count)

        guard startIndex < results.count else { return [] }

        return Array(results[startIndex..<endIndex])
    }

    private func ipMatches(ip: String, pattern: String) -> Bool {
        // Support CIDR notation and wildcards
        if pattern.contains("/") {
            return isIpInCIDR(ip: ip, cidr: pattern)
        }

        if pattern.contains("*") {
            let regexPattern = pattern.replacingOccurrences(of: "*", with: ".*")
            return ip.range(of: regexPattern, options: .regularExpression) != nil
        }

        return ip.contains(pattern)
    }

    private func isIpInCIDR(ip: String, cidr: String) -> Bool {
        // Simplified CIDR matching - in production would use proper IP parsing
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

        // Simple prefix matching for demonstration
        let bytesToCheck = prefixLength / 8
        for i in 0..<min(bytesToCheck, 4) {
            if ipComponents[i] != networkComponents[i] {
                return false
            }
        }

        return true
    }

    private func matchesMetadata(result: SearchResult, key: String, value: String, operator filterOperator: FilterOperator) -> Bool {
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
}

// MARK: - Search Performance Tracker

private class SearchPerformanceTracker {
    private var searchOperations: [SearchOperation] = []
    private let maxOperations = 100

    private struct SearchOperation {
        let query: String
        let duration: TimeInterval
        let resultCount: Int
        let timestamp: Date
        let operationId: String
    }

    func recordSearchOperation(query: String, duration: TimeInterval, resultCount: Int, operationId: String) {
        let operation = SearchOperation(
            query: query,
            duration: duration,
            resultCount: resultCount,
            timestamp: Date(),
            operationId: operationId
        )

        searchOperations.append(operation)

        if searchOperations.count > maxOperations {
            searchOperations.removeFirst(searchOperations.count - maxOperations)
        }

        if duration > 0.5 { // Log slow queries
            Logger.shared.logWarning("SearchEngine - Slow search query '\(query)' took \(String(format: "%.1f", duration * 1000))ms")
        }
    }

    func getStats() -> SearchPerformanceStats {
        guard !searchOperations.isEmpty else {
            return SearchPerformanceStats(
                averageSearchTime: 0,
                totalSearches: 0,
                slowSearchCount: 0
            )
        }

        let totalDuration = searchOperations.reduce(0) { $0 + $1.duration }
        let averageTime = totalDuration / Double(searchOperations.count)
        let slowSearches = searchOperations.filter { $0.duration > 0.5 }.count

        return SearchPerformanceStats(
            averageSearchTime: averageTime,
            totalSearches: searchOperations.count,
            slowSearchCount: slowSearches
        )
    }
}


// MARK: - Supporting Types

struct SearchEngineStats {
    let indexedResourceCount: Int
    let cacheHitRate: Double
    let averageSearchTime: TimeInterval
    let isIndexing: Bool
    let lastIndexUpdate: Date
}

struct SearchPerformanceStats {
    let averageSearchTime: TimeInterval
    let totalSearches: Int
    let slowSearchCount: Int
}

struct SearchCacheStats {
    let hitRate: Double
    let cacheSize: Int
    let maxCacheSize: Int
}