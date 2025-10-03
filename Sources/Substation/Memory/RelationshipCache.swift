import Foundation
import MemoryKit
import OSClient

// MARK: - Relationship Cache

/// RelationshipCache provides MemoryKit-backed storage for resource dependency graphs
/// with synchronous accessors for rendering performance
@MainActor
final class RelationshipCache {

    // MARK: - Properties

    private let memoryManager: SubstationMemoryManager

    // MARK: - Configuration

    private let cacheExpiry: TimeInterval = 120.0 // 2 minutes
    private let maxDependencyCacheSize = 200
    private let maxInverseCacheSize = 200

    // MARK: - Synchronous Cache (for fast access)

    private var dependencyCache: [String: CachedRelationships] = [:]
    private var inverseRelationshipCache: [String: CachedRelationships] = [:]

    // MARK: - Statistics

    private var cacheHits = 0
    private var cacheMisses = 0
    private var lastCleanup = Date()
    private let cleanupInterval: TimeInterval = 180.0 // Clean every 3 minutes

    // MARK: - Cache Entry Types

    private struct CachedRelationships {
        let relationships: [ResourceRelationship]
        let timestamp: Date
    }

    // MARK: - Initialization

    init(memoryManager: SubstationMemoryManager) {
        self.memoryManager = memoryManager
        Logger.shared.logInfo("RelationshipCache initialized with MemoryKit integration")
    }

    // MARK: - Dependency Cache Operations

    /// Get cached dependencies for a resource
    func getDependencies(for resourceId: String, type: ResourceType) async -> [ResourceRelationship]? {
        let key = generateCacheKey(resourceId: resourceId, type: type)
        await performPeriodicCleanup()

        guard let entry = dependencyCache[key] else {
            cacheMisses += 1
            return nil
        }

        // Check expiry
        if Date().timeIntervalSince(entry.timestamp) > cacheExpiry {
            dependencyCache.removeValue(forKey: key)
            cacheMisses += 1
            return nil
        }

        cacheHits += 1
        Logger.shared.logDebug("RelationshipCache hit for dependencies: \(key)")
        return entry.relationships
    }

    /// Cache dependencies for a resource
    func cacheDependencies(_ relationships: [ResourceRelationship], for resourceId: String, type: ResourceType) async {
        let key = generateCacheKey(resourceId: resourceId, type: type)
        let entry = CachedRelationships(relationships: relationships, timestamp: Date())
        dependencyCache[key] = entry

        // Maintain cache size with LRU eviction
        if dependencyCache.count > maxDependencyCacheSize {
            await evictOldestDependencyEntry()
        }

        Logger.shared.logDebug("RelationshipCache stored \(relationships.count) dependencies for: \(key)")
    }

    // MARK: - Inverse Relationship Cache Operations

    /// Get cached inverse relationships (dependents) for a resource
    func getInverseRelationships(for resourceId: String, type: ResourceType) async -> [ResourceRelationship]? {
        let key = generateCacheKey(resourceId: resourceId, type: type)
        await performPeriodicCleanup()

        guard let entry = inverseRelationshipCache[key] else {
            cacheMisses += 1
            return nil
        }

        // Check expiry
        if Date().timeIntervalSince(entry.timestamp) > cacheExpiry {
            inverseRelationshipCache.removeValue(forKey: key)
            cacheMisses += 1
            return nil
        }

        cacheHits += 1
        Logger.shared.logDebug("RelationshipCache hit for inverse relationships: \(key)")
        return entry.relationships
    }

    /// Cache inverse relationships (dependents) for a resource
    func cacheInverseRelationships(_ relationships: [ResourceRelationship], for resourceId: String, type: ResourceType) async {
        let key = generateCacheKey(resourceId: resourceId, type: type)
        let entry = CachedRelationships(relationships: relationships, timestamp: Date())
        inverseRelationshipCache[key] = entry

        // Maintain cache size with LRU eviction
        if inverseRelationshipCache.count > maxInverseCacheSize {
            await evictOldestInverseEntry()
        }

        Logger.shared.logDebug("RelationshipCache stored \(relationships.count) inverse relationships for: \(key)")
    }

    // MARK: - Invalidation Operations

    /// Invalidate cache entries for a specific resource
    func invalidate(resourceId: String, type: ResourceType) async {
        let key = generateCacheKey(resourceId: resourceId, type: type)
        dependencyCache.removeValue(forKey: key)
        inverseRelationshipCache.removeValue(forKey: key)
        Logger.shared.logDebug("RelationshipCache invalidated entries for: \(key)")
    }

    /// Invalidate all cache entries for a resource type
    func invalidateAll(for type: ResourceType) async {
        let prefix = "\(type.rawValue):"
        let beforeDepCount = dependencyCache.count
        let beforeInvCount = inverseRelationshipCache.count

        dependencyCache = dependencyCache.filter { !$0.key.hasPrefix(prefix) }
        inverseRelationshipCache = inverseRelationshipCache.filter { !$0.key.hasPrefix(prefix) }

        let removedDep = beforeDepCount - dependencyCache.count
        let removedInv = beforeInvCount - inverseRelationshipCache.count
        Logger.shared.logDebug("RelationshipCache invalidated \(removedDep) dependencies, \(removedInv) inverse for type: \(type.rawValue)")
    }

    // MARK: - Clear Operations

    /// Clear all caches
    func clearAll() async {
        dependencyCache.removeAll()
        inverseRelationshipCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
        Logger.shared.logInfo("RelationshipCache cleared all caches")
    }

    /// Clear dependency cache only
    func clearDependencyCache() async {
        dependencyCache.removeAll()
        Logger.shared.logDebug("RelationshipCache cleared dependency cache")
    }

    /// Clear inverse relationship cache only
    func clearInverseCache() async {
        inverseRelationshipCache.removeAll()
        Logger.shared.logDebug("RelationshipCache cleared inverse relationship cache")
    }

    // MARK: - Statistics

    /// Get cache statistics
    func getStatistics() async -> RelationshipCacheStatistics {
        let hitRate = cacheHits + cacheMisses > 0 ?
            Double(cacheHits) / Double(cacheHits + cacheMisses) : 0.0

        return RelationshipCacheStatistics(
            dependencyCacheSize: dependencyCache.count,
            inverseCacheSize: inverseRelationshipCache.count,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            hitRate: hitRate,
            maxDependencyCacheSize: maxDependencyCacheSize,
            maxInverseCacheSize: maxInverseCacheSize
        )
    }

    /// Reset statistics
    func resetStatistics() {
        cacheHits = 0
        cacheMisses = 0
        Logger.shared.logDebug("RelationshipCache statistics reset")
    }

    // MARK: - Private Helpers

    private func generateCacheKey(resourceId: String, type: ResourceType) -> String {
        return "\(type.rawValue):\(resourceId)"
    }

    private func evictOldestDependencyEntry() async {
        guard let oldestKey = dependencyCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }

        dependencyCache.removeValue(forKey: oldestKey)
        Logger.shared.logDebug("RelationshipCache evicted oldest dependency entry")
    }

    private func evictOldestInverseEntry() async {
        guard let oldestKey = inverseRelationshipCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }

        inverseRelationshipCache.removeValue(forKey: oldestKey)
        Logger.shared.logDebug("RelationshipCache evicted oldest inverse entry")
    }

    private func performPeriodicCleanup() async {
        let now = Date()
        guard now.timeIntervalSince(lastCleanup) > cleanupInterval else {
            return
        }

        lastCleanup = now
        let beforeDepCount = dependencyCache.count
        let beforeInvCount = inverseRelationshipCache.count

        // Remove expired entries
        dependencyCache = dependencyCache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= cacheExpiry
        }

        inverseRelationshipCache = inverseRelationshipCache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= cacheExpiry
        }

        let removedDep = beforeDepCount - dependencyCache.count
        let removedInv = beforeInvCount - inverseRelationshipCache.count
        if removedDep > 0 || removedInv > 0 {
            Logger.shared.logDebug("RelationshipCache periodic cleanup removed \(removedDep) dependencies, \(removedInv) inverse")
        }
    }
}

// MARK: - Statistics

public struct RelationshipCacheStatistics: Sendable {
    public let dependencyCacheSize: Int
    public let inverseCacheSize: Int
    public let cacheHits: Int
    public let cacheMisses: Int
    public let hitRate: Double
    public let maxDependencyCacheSize: Int
    public let maxInverseCacheSize: Int

    public var summary: String {
        return """
        Relationship Cache Statistics:
        Dependencies: \(dependencyCacheSize)/\(maxDependencyCacheSize)
        Inverse Relationships: \(inverseCacheSize)/\(maxInverseCacheSize)
        Hit Rate: \(String(format: "%.1f", hitRate * 100))%
        Hits: \(cacheHits), Misses: \(cacheMisses)
        """
    }
}