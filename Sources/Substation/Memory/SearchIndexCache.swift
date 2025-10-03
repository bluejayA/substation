import Foundation
import MemoryKit
import OSClient

// MARK: - Search Index Cache

/// SearchIndexCache provides MemoryKit-backed storage for all search indexes
/// with memory-aware caching and automatic eviction policies
@MainActor
final class SearchIndexCache {

    // MARK: - Properties

    private let memoryManager: SubstationMemoryManager

    // MARK: - Configuration

    private let searchCacheExpiry: TimeInterval = 60.0 // 1 minute
    private let maxSearchCacheSize = 100 // Increased from 50 for better hit rate
    private let maxSuggestionCacheSize = 50

    // MARK: - Synchronous Cache (for fast access)

    private var searchResultsCache: [String: SearchCacheEntry] = [:]
    private var suggestionCache: [String: SuggestionCacheEntry] = [:]

    // MARK: - Statistics

    private var cacheHits = 0
    private var cacheMisses = 0
    private var lastCleanup = Date()
    private let cleanupInterval: TimeInterval = 120.0 // Clean every 2 minutes

    // MARK: - Cache Entry Types

    private struct SearchCacheEntry {
        let results: SearchResults
        let timestamp: Date
        let queryHash: String
    }

    private struct SuggestionCacheEntry {
        let suggestions: [SearchSuggestion]
        let timestamp: Date
    }

    // MARK: - Initialization

    init(memoryManager: SubstationMemoryManager) {
        self.memoryManager = memoryManager
        Logger.shared.logInfo("SearchIndexCache initialized with MemoryKit integration")
    }

    // MARK: - Search Results Cache

    /// Get cached search results
    func getCachedResults(for query: SearchQuery) async -> SearchResults? {
        let key = generateCacheKey(for: query)

        // Check if cleanup is needed
        await performPeriodicCleanup()

        guard let entry = searchResultsCache[key] else {
            cacheMisses += 1
            return nil
        }

        // Check expiry
        if Date().timeIntervalSince(entry.timestamp) > searchCacheExpiry {
            searchResultsCache.removeValue(forKey: key)
            cacheMisses += 1
            return nil
        }

        cacheHits += 1
        Logger.shared.logDebug("SearchIndexCache hit for query: \(query.text)")
        return entry.results
    }

    /// Cache search results
    func cacheResults(_ results: SearchResults, for query: SearchQuery) async {
        let key = generateCacheKey(for: query)
        let queryHash = hashQuery(query)
        let entry = SearchCacheEntry(results: results, timestamp: Date(), queryHash: queryHash)

        searchResultsCache[key] = entry

        // Store in MemoryKit for persistence
        await memoryManager.storeSearchResults(results, forQuery: query.text)

        // Maintain cache size with LRU eviction
        if searchResultsCache.count > maxSearchCacheSize {
            await evictOldestSearchEntry()
        }

        Logger.shared.logDebug("SearchIndexCache stored results for query: \(query.text) (\(results.items.count) items)")
    }

    /// Invalidate all cached search results
    func invalidateSearchCache() async {
        searchResultsCache.removeAll()
        Logger.shared.logInfo("SearchIndexCache invalidated all search results")
    }

    /// Invalidate cache entries matching a filter
    func invalidateCache(matching filter: (SearchQuery) -> Bool) async {
        // Note: We'd need to store queries to implement this properly
        // For now, just clear all
        await invalidateSearchCache()
    }

    // MARK: - Suggestion Cache

    /// Get cached suggestions
    func getCachedSuggestions(for partialQuery: String) async -> [SearchSuggestion]? {
        let key = partialQuery.lowercased()

        guard let entry = suggestionCache[key] else {
            return nil
        }

        // Check expiry
        if Date().timeIntervalSince(entry.timestamp) > searchCacheExpiry {
            suggestionCache.removeValue(forKey: key)
            return nil
        }

        return entry.suggestions
    }

    /// Cache suggestions
    func cacheSuggestions(_ suggestions: [SearchSuggestion], for partialQuery: String) async {
        let key = partialQuery.lowercased()
        let entry = SuggestionCacheEntry(suggestions: suggestions, timestamp: Date())

        suggestionCache[key] = entry

        // Maintain cache size
        if suggestionCache.count > maxSuggestionCacheSize {
            let oldestKey = suggestionCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let key = oldestKey {
                suggestionCache.removeValue(forKey: key)
            }
        }

        Logger.shared.logDebug("SearchIndexCache stored \(suggestions.count) suggestions for: \(partialQuery)")
    }

    /// Invalidate all cached suggestions
    func invalidateSuggestionCache() async {
        suggestionCache.removeAll()
        Logger.shared.logInfo("SearchIndexCache invalidated all suggestions")
    }

    // MARK: - Statistics

    /// Get cache statistics
    func getStatistics() async -> SearchIndexCacheStatistics {
        let hitRate = cacheHits + cacheMisses > 0 ?
            Double(cacheHits) / Double(cacheHits + cacheMisses) : 0.0

        return SearchIndexCacheStatistics(
            searchCacheSize: searchResultsCache.count,
            suggestionCacheSize: suggestionCache.count,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            hitRate: hitRate,
            maxSearchCacheSize: maxSearchCacheSize,
            maxSuggestionCacheSize: maxSuggestionCacheSize
        )
    }

    /// Reset statistics
    func resetStatistics() {
        cacheHits = 0
        cacheMisses = 0
        Logger.shared.logDebug("SearchIndexCache statistics reset")
    }

    // MARK: - Clear Operations

    /// Clear all caches
    func clearAll() async {
        searchResultsCache.removeAll()
        suggestionCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
        Logger.shared.logInfo("SearchIndexCache cleared all caches")
    }

    // MARK: - Private Helpers

    private func generateCacheKey(for query: SearchQuery) -> String {
        var components: [String] = [query.text.lowercased()]

        if !query.resourceTypes.isEmpty {
            components.append(query.resourceTypes.map { $0.rawValue }.sorted().joined(separator: ","))
        }

        if query.fuzzySearch {
            components.append("fuzzy")
        }

        // Note: SearchQuery doesn't have caseSensitive, removed

        return components.joined(separator: "|")
    }

    private func hashQuery(_ query: SearchQuery) -> String {
        let key = generateCacheKey(for: query)
        return String(key.hashValue)
    }

    private func evictOldestSearchEntry() async {
        guard let oldestKey = searchResultsCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }

        searchResultsCache.removeValue(forKey: oldestKey)
        Logger.shared.logDebug("SearchIndexCache evicted oldest search entry")
    }

    private func performPeriodicCleanup() async {
        let now = Date()
        guard now.timeIntervalSince(lastCleanup) > cleanupInterval else {
            return
        }

        lastCleanup = now
        let beforeCount = searchResultsCache.count

        // Remove expired entries
        searchResultsCache = searchResultsCache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= searchCacheExpiry
        }

        suggestionCache = suggestionCache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= searchCacheExpiry
        }

        let removed = beforeCount - searchResultsCache.count
        if removed > 0 {
            Logger.shared.logDebug("SearchIndexCache periodic cleanup removed \(removed) expired entries")
        }
    }
}

// MARK: - Statistics

public struct SearchIndexCacheStatistics: Sendable {
    public let searchCacheSize: Int
    public let suggestionCacheSize: Int
    public let cacheHits: Int
    public let cacheMisses: Int
    public let hitRate: Double
    public let maxSearchCacheSize: Int
    public let maxSuggestionCacheSize: Int

    public var summary: String {
        return """
        Search Cache Statistics:
        Search Results: \(searchCacheSize)/\(maxSearchCacheSize)
        Suggestions: \(suggestionCacheSize)/\(maxSuggestionCacheSize)
        Hit Rate: \(String(format: "%.1f", hitRate * 100))%
        Hits: \(cacheHits), Misses: \(cacheMisses)
        """
    }
}

// MARK: - SearchQuery Extension

extension SearchQuery {
    var cacheKey: String {
        var components: [String] = [text.lowercased()]

        if !resourceTypes.isEmpty {
            components.append(resourceTypes.map { $0.rawValue }.sorted().joined(separator: ","))
        }

        if fuzzySearch {
            components.append("fuzzy")
        }

        return components.joined(separator: "|")
    }
}