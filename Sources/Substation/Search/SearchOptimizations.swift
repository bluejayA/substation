import Foundation
import OSClient

// MARK: - Search Performance Optimizations

/// Performance optimization techniques for the search system to achieve <500ms response times
actor SearchOptimizations {

    // MARK: - Query Optimization

    /// Optimizes search queries for maximum performance
    static func optimizeQuery(_ query: SearchQuery) -> SearchQuery {
        let optimizedPagination: SearchPagination
        let optimizedFuzzySearch: Bool
        let optimizedSearchResourceTypes: [SearchResourceType]
        let optimizedIncludeRelationships: Bool

        // Limit search scope for very short queries to prevent overwhelming results
        if query.text.count < 3 {
            optimizedPagination = SearchPagination(
                offset: query.pagination.offset,
                limit: min(50, query.pagination.limit)
            )
        } else {
            optimizedPagination = query.pagination
        }

        // Enable fuzzy search only for longer queries to avoid performance impact
        if query.text.count > 5 {
            optimizedFuzzySearch = true
        } else {
            optimizedFuzzySearch = false
        }

        // Optimize resource type filtering - if many types selected, remove filter to use broader search
        if query.resourceTypes.count > 8 {
            optimizedSearchResourceTypes = []
        } else {
            optimizedSearchResourceTypes = query.resourceTypes
        }

        // Limit relationship inclusion for large result sets
        if query.pagination.limit > 100 {
            optimizedIncludeRelationships = false
        } else {
            optimizedIncludeRelationships = query.includeRelationships
        }

        return SearchQuery(
            text: query.text,
            filters: query.filters,
            resourceTypes: optimizedSearchResourceTypes,
            sorting: query.sorting,
            pagination: optimizedPagination,
            fuzzySearch: optimizedFuzzySearch,
            includeRelationships: optimizedIncludeRelationships
        )
    }

    // MARK: - Index Optimization

    /// Pre-computes commonly searched terms for instant responses
    actor PrecomputedSearchCache {
        private var precomputedSearches: [String: SearchResults] = [:]
        private let maxPrecomputedCache = 20

        static let shared = PrecomputedSearchCache()

        private init() {}

        func precomputeCommonSearches() async {
            let commonTerms = [
                "server", "active", "error", "network", "volume", "image",
                "running", "stopped", "available", "in-use", "public", "private"
            ]

            for term in commonTerms.prefix(maxPrecomputedCache) {
                let query = SearchQuery(
                    text: term,
                    filters: [],
                    resourceTypes: [],
                    sorting: .relevance,
                    pagination: SearchPagination(offset: 0, limit: 20),
                    fuzzySearch: false,
                    includeRelationships: false
                )

                do {
                    let results = try await SearchEngine.shared.search(query)
                    precomputedSearches[term] = results
                } catch {
                    Logger.shared.logError("Failed to precompute search for '\(term)': \(error)")
                }
            }

            Logger.shared.logInfo("SearchOptimizations - Precomputed \(precomputedSearches.count) common searches")
        }

        func getPrecomputedSearch(for query: String) -> SearchResults? {
            return precomputedSearches[query.lowercased()]
        }

        func clear() {
            precomputedSearches.removeAll()
        }
    }

    // MARK: - Result Processing Optimization

    /// Processes search results with performance optimizations
    static func optimizeResults(_ results: [SearchResult], for query: SearchQuery) -> [SearchResult] {
        var optimized = results

        // Sort by relevance score first for better user experience
        optimized.sort { $0.relevanceScore > $1.relevanceScore }

        // Apply early truncation for better response times
        if optimized.count > query.pagination.limit * 2 {
            optimized = Array(optimized.prefix(query.pagination.limit * 2))
        }

        // Remove duplicate results more efficiently
        optimized = removeDuplicates(optimized)

        // Apply final pagination
        let startIndex = query.pagination.offset
        let endIndex = min(startIndex + query.pagination.limit, optimized.count)

        if startIndex < optimized.count {
            optimized = Array(optimized[startIndex..<endIndex])
        } else {
            optimized = []
        }

        return optimized
    }

    private static func removeDuplicates(_ results: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>()
        var unique: [SearchResult] = []

        for result in results {
            let key = "\(result.resourceType.rawValue):\(result.resourceId)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(result)
            }
        }

        return unique
    }

    // MARK: - Memory Optimization

    /// Manages memory usage for large search operations
    actor MemoryManager {
        private var memoryPressureThreshold: Int64 = 75_000_000 // 75MB
        private var currentMemoryUsage: Int64 = 0

        var memoryUsage: Int64 { currentMemoryUsage }

        func trackMemoryUsage(_ bytes: Int64) {
            currentMemoryUsage += bytes

            if currentMemoryUsage > memoryPressureThreshold {
                Logger.shared.logWarning("SearchOptimizations - High memory usage detected: \(currentMemoryUsage / 1_000_000)MB")
                Task {
                    await triggerMemoryCleanup()
                }
            }
        }

        private func triggerMemoryCleanup() async {
            // Clear precomputed searches if memory pressure is high
            if currentMemoryUsage > memoryPressureThreshold * 2 {
                await PrecomputedSearchCache.shared.clear()
                Logger.shared.logInfo("SearchOptimizations - Cleared precomputed searches due to memory pressure")
            }

            // Force garbage collection hint (cross-platform)
            #if canImport(Darwin)
            autoreleasepool {
                // This block will be cleaned up immediately on Apple platforms
            }
            #endif

            currentMemoryUsage = 0
        }
    }

    static let memoryManager = MemoryManager()

    // MARK: - Concurrent Search Optimization

    /// Performs concurrent searches across different resource types for better performance
    static func performConcurrentSearch(_ query: SearchQuery) async throws -> [SearchResult] {
        let searchEngine = SearchEngine.shared

        // If specific resource types are requested, search them concurrently
        if !query.resourceTypes.isEmpty {
            return try await performTypedConcurrentSearch(query, searchEngine: searchEngine)
        }

        // Otherwise, perform the standard search
        let results = try await searchEngine.search(query)
        return results.items
    }

    private static func performTypedConcurrentSearch(_ query: SearchQuery, searchEngine: SearchEngine) async throws -> [SearchResult] {
        var allResults: [SearchResult] = []

        // Create individual queries for each resource type
        let typeQueries = query.resourceTypes.map { resourceType in
            SearchQuery(
                text: query.text,
                filters: query.filters,
                resourceTypes: [resourceType],
                sorting: query.sorting,
                pagination: SearchPagination(offset: 0, limit: query.pagination.limit / query.resourceTypes.count + 10),
                fuzzySearch: query.fuzzySearch,
                includeRelationships: query.includeRelationships
            )
        }

        // Execute searches concurrently
        try await withThrowingTaskGroup(of: [SearchResult].self) { group in
            for typeQuery in typeQueries {
                group.addTask {
                    let results = try await searchEngine.search(typeQuery)
                    return results.items
                }
            }

            for try await results in group {
                allResults.append(contentsOf: results)
            }
        }

        return optimizeResults(allResults, for: query)
    }

    // MARK: - Search Analytics for Optimization

    actor SearchAnalytics {
        private var searchTimes: [TimeInterval] = []
        private var slowQueries: [(String, TimeInterval)] = []
        private let maxAnalyticsEntries = 100

        static let shared = SearchAnalytics()

        private init() {}

        func recordSearchTime(_ time: TimeInterval, for query: String) {
            searchTimes.append(time)

            // Track slow queries (>500ms)
            if time > 0.5 {
                slowQueries.append((query, time))
                Logger.shared.logWarning("SearchOptimizations - Slow query detected: '\(query)' took \(Int(time * 1000))ms")
            }

            // Maintain limits
            if searchTimes.count > maxAnalyticsEntries {
                searchTimes.removeFirst(searchTimes.count - maxAnalyticsEntries)
            }

            if slowQueries.count > maxAnalyticsEntries {
                slowQueries.removeFirst(slowQueries.count - maxAnalyticsEntries)
            }
        }

        func getAverageSearchTime() -> TimeInterval {
            guard !searchTimes.isEmpty else { return 0 }
            return searchTimes.reduce(0, +) / Double(searchTimes.count)
        }

        func getSlowQueryPercentage() -> Double {
            guard !searchTimes.isEmpty else { return 0 }
            return Double(slowQueries.count) / Double(searchTimes.count) * 100
        }

        func generatePerformanceReport() async -> String {
            let avgTime = getAverageSearchTime()
            let slowPercentage = getSlowQueryPercentage()
            let memoryUsage = await memoryManager.memoryUsage

            return """
            Search Performance Report:
            - Average search time: \(String(format: "%.0f", avgTime * 1000))ms
            - Slow queries (>500ms): \(String(format: "%.1f", slowPercentage))%
            - Total searches analyzed: \(searchTimes.count)
            - Memory usage: \(memoryUsage / 1_000_000)MB
            """
        }
    }

    // MARK: - Initialization

    static func initialize() async {
        Logger.shared.logInfo("SearchOptimizations - Initializing performance optimizations")

        // Precompute common searches
        await PrecomputedSearchCache.shared.precomputeCommonSearches()

        // Set up memory monitoring
        Task {
            while true {
                try await Task.sleep(for: .seconds(30))
                let memoryUsage = await memoryManager.memoryUsage
                if memoryUsage > 0 {
                    Logger.shared.logDebug("SearchOptimizations - Current memory usage: \(memoryUsage / 1_000_000)MB")
                }
            }
        }
    }
}

// MARK: - Performance Extension for SearchEngine

extension SearchEngine {
    /// High-performance search with optimizations enabled
    func performanceSearch(_ query: SearchQuery) async throws -> SearchResults {
        let startTime = Date().timeIntervalSinceReferenceDate

        // Check for precomputed results first
        if let precomputed = await SearchOptimizations.PrecomputedSearchCache.shared.getPrecomputedSearch(for: query.text) {
            Logger.shared.logDebug("SearchEngine - Using precomputed results for '\(query.text)'")
            await SearchOptimizations.SearchAnalytics.shared.recordSearchTime(0.001, for: query.text) // Near-instant
            return precomputed
        }

        // Optimize the query
        let optimizedQuery = SearchOptimizations.optimizeQuery(query)

        // Perform the search with optimizations
        var results: SearchResults

        if !optimizedQuery.resourceTypes.isEmpty && optimizedQuery.resourceTypes.count > 1 {
            // Use concurrent search for multiple resource types
            let searchResults = try await SearchOptimizations.performConcurrentSearch(optimizedQuery)
            results = SearchResults(
                query: optimizedQuery,
                items: searchResults,
                totalCount: searchResults.count,
                searchTime: 0,
                suggestions: []
            )
        } else {
            // Use standard search
            results = try await search(optimizedQuery)
        }

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        // Create new results with updated search time
        results = SearchResults(
            query: results.query,
            items: results.items,
            totalCount: results.totalCount,
            searchTime: duration,
            suggestions: results.suggestions
        )

        // Record analytics
        await SearchOptimizations.SearchAnalytics.shared.recordSearchTime(duration, for: query.text)

        // Track memory usage
        let estimatedMemory = Int64(results.items.count * 512) // Rough estimate
        await SearchOptimizations.memoryManager.trackMemoryUsage(estimatedMemory)

        return results
    }
}