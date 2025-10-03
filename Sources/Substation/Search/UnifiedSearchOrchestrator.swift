import Foundation
import OSClient

// MARK: - Unified Search Orchestrator

public actor UnifiedSearchOrchestrator {
    private let serviceAdapters: [any ServiceDataAdapter]
    private let searchCache: SearchIndexCache
    private let resultRankingEngine: ResultRankingEngine
    private let logger = Logger.shared

    // Performance tracking
    private var searchMetrics: [String: ServiceSearchMetrics] = [:]
    private var totalSearchCount: Int = 0
    private var averageSearchTime: TimeInterval = 0.0

    init(
        novaService: NovaService,
        neutronService: NeutronService,
        cinderService: CinderService,
        glanceService: GlanceService,
        keystoneService: KeystoneService,
        searchCache: SearchIndexCache
    ) {
        self.serviceAdapters = [
            NovaServiceAdapter(novaService: novaService),
            NeutronServiceAdapter(neutronService: neutronService),
            CinderServiceAdapter(cinderService: cinderService),
            GlanceServiceAdapter(glanceService: glanceService),
            KeystoneServiceAdapter(keystoneService: keystoneService)
        ]

        self.searchCache = searchCache
        self.resultRankingEngine = ResultRankingEngine()
    }

    // MARK: - Global Search Operations

    public func globalSearch(_ query: GlobalSearchQuery) async throws -> UnifiedSearchResults {
        let startTime = Date().timeIntervalSinceReferenceDate
        totalSearchCount += 1

        // Check cache first
        if let cachedResults = await searchCache.getCachedResults(for: query.toSearchQuery()) {
            logger.logInfo("UnifiedSearchOrchestrator - Cache hit for query: \(query.text)")
            return createUnifiedResults(
                query: query,
                serviceResults: [],
                aggregatedItems: cachedResults.items,
                totalCount: cachedResults.totalCount,
                searchTime: Date().timeIntervalSinceReferenceDate - startTime,
                cacheHitRate: 1.0
            )
        }

        logger.logInfo("UnifiedSearchOrchestrator - Starting global search for: \(query.text)")

        // Determine which services to search based on resource types
        let servicesToSearch = determineServicesToSearch(for: query)
        var serviceResults: [ServiceSearchResults] = []
        var searchMetrics: [ServiceSearchMetrics] = []

        if query.parallelSearchEnabled && servicesToSearch.count > 1 {
            // Parallel search across services
            (serviceResults, searchMetrics) = await performParallelSearch(
                query: query.toSearchQuery(),
                services: servicesToSearch,
                maxResultsPerService: query.maxResultsPerService
            )
        } else {
            // Sequential search
            (serviceResults, searchMetrics) = await performSequentialSearch(
                query: query.toSearchQuery(),
                services: servicesToSearch,
                maxResultsPerService: query.maxResultsPerService
            )
        }

        // Aggregate and rank results
        let aggregatedResults = aggregateResults(from: serviceResults)
        let rankedResults = await resultRankingEngine.rankResults(
            aggregatedResults,
            query: query.toSearchQuery(),
            context: SearchContext(
                currentView: nil,
                selectedResourceId: nil,
                selectedResourceType: nil,
                userPreferences: SearchPreferences()
            )
        )

        let totalTime = Date().timeIntervalSinceReferenceDate - startTime
        averageSearchTime = (averageSearchTime * Double(totalSearchCount - 1) + totalTime) / Double(totalSearchCount)

        // Cache successful results
        let searchResults = SearchResults(
            query: query.toSearchQuery(),
            items: rankedResults,
            totalCount: rankedResults.count,
            searchTime: totalTime
        )
        await searchCache.cacheResults(searchResults, for: query.toSearchQuery())

        let cacheHitRate = calculateCacheHitRate(serviceResults)

        logger.logInfo("UnifiedSearchOrchestrator - Global search completed in \(totalTime)s, found \(rankedResults.count) results")

        return createUnifiedResults(
            query: query,
            serviceResults: serviceResults,
            aggregatedItems: rankedResults,
            totalCount: rankedResults.count,
            searchTime: totalTime,
            serviceMetrics: query.includeServiceMetrics ? searchMetrics : [],
            cacheHitRate: cacheHitRate
        )
    }

    public func getSearchAnalytics() async -> SearchAnalytics {
        let _ = searchMetrics.values.reduce(0) { $0 + $1.resultCount }
        let successRate = calculateSuccessRate()
        let mostSearchedTypes = extractMostSearchedTypes()
        let cacheHitRate = await calculateOverallCacheHitRate()

        return SearchAnalytics(
            totalSearches: totalSearchCount,
            averageSearchTime: averageSearchTime,
            mostSearchedTerms: [:], // Would need to track search terms
            mostFilteredTypes: mostSearchedTypes,
            searchSuccessRate: successRate,
            cacheHitRate: cacheHitRate
        )
    }

    public func clearSearchCache() async {
        await searchCache.clearAll()
        logger.logInfo("UnifiedSearchOrchestrator - Search cache cleared")
    }

    public func getServiceHealth() async -> [String: Bool] {
        var health: [String: Bool] = [:]

        for adapter in serviceAdapters {
            do {
                // Try a simple test query to check service health
                let testQuery = SearchQuery(
                    text: "",
                    resourceTypes: Array(adapter.supportedResourceTypes.prefix(1)),
                    pagination: SearchPagination(offset: 0, limit: 1)
                )
                _ = try await adapter.search(testQuery)
                health[adapter.serviceName] = true
            } catch {
                health[adapter.serviceName] = false
                logger.logError("UnifiedSearchOrchestrator - Service health check failed for \(adapter.serviceName): \(error)")
            }
        }

        return health
    }

    // MARK: - Cross-Service Resource Operations

    public func getResourceRelationships(_ resourceId: String, type: SearchResourceType) async throws -> [CrossServiceRelationship] {
        var allRelationships: [CrossServiceRelationship] = []

        for adapter in serviceAdapters {
            if adapter.supportedResourceTypes.contains(type) {
                do {
                    let relationships = try await adapter.getResourceRelationships(resourceId, type: type)
                    allRelationships.append(contentsOf: relationships)
                } catch {
                    logger.logError("UnifiedSearchOrchestrator - Failed to get relationships from \(adapter.serviceName): \(error)")
                }
            }
        }

        return allRelationships
    }

    public func getResourceById(_ id: String, type: SearchResourceType) async throws -> Any? {
        for adapter in serviceAdapters {
            if adapter.supportedResourceTypes.contains(type) {
                do {
                    if let resource = try await adapter.getResourceById(id, type: type) {
                        return resource
                    }
                } catch {
                    logger.logError("UnifiedSearchOrchestrator - Failed to get resource from \(adapter.serviceName): \(error)")
                }
            }
        }
        return nil
    }

    // MARK: - Private Helper Methods

    private func determineServicesToSearch(for query: GlobalSearchQuery) -> [any ServiceDataAdapter] {
        // If no resource types specified, search all services
        guard !query.resourceTypes.isEmpty else {
            return serviceAdapters
        }

        // Filter services based on supported resource types
        return serviceAdapters.filter { adapter in
            !Set(adapter.supportedResourceTypes).isDisjoint(with: Set(query.resourceTypes))
        }
    }

    private func performParallelSearch(
        query: SearchQuery,
        services: [any ServiceDataAdapter],
        maxResultsPerService: Int
    ) async -> ([ServiceSearchResults], [ServiceSearchMetrics]) {
        let results = await withTaskGroup(of: (ServiceSearchResults, ServiceSearchMetrics).self) { group in
            for service in services {
                group.addTask {
                    await self.searchSingleService(service, query: query, maxResults: maxResultsPerService)
                }
            }

            var serviceResults: [ServiceSearchResults] = []
            var serviceMetrics: [ServiceSearchMetrics] = []

            for await (result, metric) in group {
                serviceResults.append(result)
                serviceMetrics.append(metric)
            }

            return (serviceResults, serviceMetrics)
        }

        return results
    }

    private func performSequentialSearch(
        query: SearchQuery,
        services: [any ServiceDataAdapter],
        maxResultsPerService: Int
    ) async -> ([ServiceSearchResults], [ServiceSearchMetrics]) {
        var serviceResults: [ServiceSearchResults] = []
        var serviceMetrics: [ServiceSearchMetrics] = []

        for service in services {
            let (result, metric) = await searchSingleService(service, query: query, maxResults: maxResultsPerService)
            serviceResults.append(result)
            serviceMetrics.append(metric)
        }

        return (serviceResults, serviceMetrics)
    }

    private func searchSingleService(
        _ adapter: any ServiceDataAdapter,
        query: SearchQuery,
        maxResults: Int
    ) async -> (ServiceSearchResults, ServiceSearchMetrics) {
        let startTime = Date().timeIntervalSinceReferenceDate

        do {
            let limitedQuery = SearchQuery(
                text: query.text,
                filters: query.filters,
                resourceTypes: query.resourceTypes,
                sorting: query.sorting,
                pagination: SearchPagination(offset: 0, limit: maxResults),
                fuzzySearch: query.fuzzySearch,
                includeRelationships: query.includeRelationships
            )

            let results = try await adapter.search(limitedQuery)
            let searchTime = Date().timeIntervalSinceReferenceDate - startTime

            let serviceResult = ServiceSearchResults(
                serviceName: adapter.serviceName,
                items: results,
                totalCount: results.count,
                searchTime: searchTime,
                cacheHit: false
            )

            let serviceMetric = ServiceSearchMetrics(
                serviceName: adapter.serviceName,
                searchTime: searchTime,
                resultCount: results.count,
                cacheHit: false,
                memoryUsage: 0, // Would need actual memory tracking
                indexSize: 0    // Would need actual index size tracking
            )

            // Store metrics for analytics
            searchMetrics[adapter.serviceName] = serviceMetric

            return (serviceResult, serviceMetric)

        } catch {
            let searchTime = Date().timeIntervalSinceReferenceDate - startTime
            logger.logError("UnifiedSearchOrchestrator - Search failed for \(adapter.serviceName): \(error)")

            let serviceResult = ServiceSearchResults(
                serviceName: adapter.serviceName,
                items: [],
                totalCount: 0,
                searchTime: searchTime,
                error: error.localizedDescription,
                cacheHit: false
            )

            let serviceMetric = ServiceSearchMetrics(
                serviceName: adapter.serviceName,
                searchTime: searchTime,
                resultCount: 0,
                cacheHit: false,
                error: error.localizedDescription
            )

            return (serviceResult, serviceMetric)
        }
    }

    private func aggregateResults(from serviceResults: [ServiceSearchResults]) -> [SearchResult] {
        var allResults: [SearchResult] = []

        for serviceResult in serviceResults where serviceResult.isSuccessful {
            allResults.append(contentsOf: serviceResult.items)
        }

        return allResults
    }

    private func calculateCacheHitRate(_ serviceResults: [ServiceSearchResults]) -> Double {
        let totalServices = serviceResults.count
        guard totalServices > 0 else { return 0.0 }

        let cacheHits = serviceResults.filter { $0.cacheHit }.count
        return Double(cacheHits) / Double(totalServices)
    }

    private func calculateSuccessRate() -> Double {
        let totalMetrics = searchMetrics.count
        guard totalMetrics > 0 else { return 1.0 }

        let successfulSearches = searchMetrics.values.filter { $0.error == nil }.count
        return Double(successfulSearches) / Double(totalMetrics)
    }

    private func extractMostSearchedTypes() -> [SearchResourceType: Int] {
        // This would require tracking search patterns over time
        // For now, return empty dictionary
        return [:]
    }

    private func calculateOverallCacheHitRate() async -> Double {
        let stats = await searchCache.getStatistics()
        let total = stats.cacheHits + stats.cacheMisses
        guard total > 0 else { return 0.0 }
        return Double(stats.cacheHits) / Double(total)
    }

    private func createUnifiedResults(
        query: GlobalSearchQuery,
        serviceResults: [ServiceSearchResults],
        aggregatedItems: [SearchResult],
        totalCount: Int,
        searchTime: TimeInterval,
        serviceMetrics: [ServiceSearchMetrics] = [],
        cacheHitRate: Double = 0.0
    ) -> UnifiedSearchResults {
        return UnifiedSearchResults(
            query: query,
            serviceResults: serviceResults,
            aggregatedItems: aggregatedItems,
            totalCount: totalCount,
            searchTime: searchTime,
            serviceMetrics: serviceMetrics,
            cacheHitRate: cacheHitRate
        )
    }
}

// MARK: - Result Ranking Engine

private actor ResultRankingEngine {
    func rankResults(
        _ results: [SearchResult],
        query: SearchQuery,
        context: SearchContext
    ) async -> [SearchResult] {
        guard !results.isEmpty else { return results }

        var rankedResults = results

        // Calculate enhanced relevance scores
        for i in rankedResults.indices {
            rankedResults[i].relevanceScore = await calculateEnhancedRelevanceScore(
                rankedResults[i],
                query: query,
                context: context
            )
        }

        // Sort by relevance score (highest first)
        rankedResults.sort { $0.relevanceScore > $1.relevanceScore }

        // Apply secondary sorting based on query sorting preference
        switch query.sorting {
        case .relevance:
            break // Already sorted by relevance
        case .name(let direction):
            rankedResults = applySortingByName(rankedResults, direction: direction)
        case .createdAt(let direction):
            rankedResults = applySortingByDate(rankedResults, direction: direction)
        case .resourceType:
            rankedResults = applySortingByResourceType(rankedResults)
        }

        return rankedResults
    }

    private func calculateEnhancedRelevanceScore(
        _ result: SearchResult,
        query: SearchQuery,
        context: SearchContext
    ) async -> Double {
        var score = result.relevanceScore

        // Boost score based on resource type preferences
        if let selectedType = context.selectedResourceType,
           result.resourceType == selectedType {
            score += 5.0
        }

        // Boost recent resources
        if let createdAt = result.createdAt {
            let daysSinceCreation = Date().timeIntervalSince(createdAt) / (24 * 3600)
            if daysSinceCreation < 7 {
                score += 2.0
            } else if daysSinceCreation < 30 {
                score += 1.0
            }
        }

        // Boost resources with recent updates
        if let updatedAt = result.updatedAt {
            let daysSinceUpdate = Date().timeIntervalSince(updatedAt) / (24 * 3600)
            if daysSinceUpdate < 1 {
                score += 3.0
            } else if daysSinceUpdate < 7 {
                score += 1.5
            }
        }

        // Boost based on status (running/active resources)
        if let status = result.status?.lowercased() {
            switch status {
            case "active", "running", "up":
                score += 2.0
            case "error", "failed", "down":
                score -= 1.0
            default:
                break
            }
        }

        return max(0, score)
    }

    private func applySortingByName(_ results: [SearchResult], direction: SortDirection) -> [SearchResult] {
        return results.sorted { lhs, rhs in
            let lhsName = lhs.name ?? lhs.resourceId
            let rhsName = rhs.name ?? rhs.resourceId

            switch direction {
            case .ascending:
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            case .descending:
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedDescending
            }
        }
    }

    private func applySortingByDate(_ results: [SearchResult], direction: SortDirection) -> [SearchResult] {
        return results.sorted { lhs, rhs in
            let lhsDate = lhs.createdAt ?? Date.distantPast
            let rhsDate = rhs.createdAt ?? Date.distantPast

            switch direction {
            case .ascending:
                return lhsDate < rhsDate
            case .descending:
                return lhsDate > rhsDate
            }
        }
    }

    private func applySortingByResourceType(_ results: [SearchResult]) -> [SearchResult] {
        return results.sorted { lhs, rhs in
            return lhs.resourceType.displayName.localizedCaseInsensitiveCompare(rhs.resourceType.displayName) == .orderedAscending
        }
    }
}