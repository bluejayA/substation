import Foundation
import MemoryKit

/// OpenStack-specific cache manager that extends MemoryKit with resource types and intelligent invalidation
public actor OpenStackCacheManager {
    // MARK: - Configuration

    private let multiLevelCache: MultiLevelCacheManager<String, Data>
    private let logger: any OpenStackClientLogger

    // Track keys by resource type for efficient type-based operations
    private var keysByResourceType: [ResourceType: Set<String>] = [:]

    // Helper to get all tracked keys
    private func getAllTrackedKeys() -> [String] {
        return keysByResourceType.values.reduce(into: []) { result, keySet in
            result.append(contentsOf: keySet)
        }
    }

    // MARK: - OpenStack Resource Types

    public enum ResourceType: String, CaseIterable, Sendable {
        case server = "server"
        case serverDetail = "server_detail"
        case serverList = "server_list"
        case flavor = "flavor"
        case flavorList = "flavor_list"
        case image = "image"
        case imageList = "image_list"
        case network = "network"
        case networkList = "network_list"
        case subnet = "subnet"
        case subnetList = "subnet_list"
        case port = "port"
        case portList = "port_list"
        case router = "router"
        case routerList = "router_list"
        case securityGroup = "security_group"
        case securityGroupList = "security_group_list"
        case addressGroup = "address_group"
        case addressGroupList = "address_group_list"
        case volume = "volume"
        case volumeList = "volume_list"
        case volumeType = "volume_type"
        case volumeTypeList = "volume_type_list"
        case volumeSnapshot = "volume_snapshot"
        case volumeSnapshotList = "volume_snapshot_list"
        case floatingIP = "floating_ip"
        case floatingIPList = "floating_ip_list"
        case keypair = "keypair"
        case keypairList = "keypair_list"
        case serverGroup = "server_group"
        case serverGroupList = "server_group_list"
        case objectStorage = "object_storage"
        case objectStorageList = "object_storage_list"
        case authentication = "auth_token"
        case serviceEndpoints = "service_endpoints"
        case quotas = "quotas"

        /// Get the default TTL for this resource type
        public var defaultTTL: TimeInterval {
            switch self {
            case .authentication:
                return 3600.0 // 1 hour for auth tokens
            case .serviceEndpoints, .quotas:
                return 1800.0 // 30 minutes for semi-static data
            case .flavor, .flavorList, .volumeType, .volumeTypeList:
                return 900.0 // 15 minutes for relatively static resources
            case .keypair, .keypairList, .serverGroup, .serverGroupList, .image, .imageList, .network, .networkList, .subnet, .subnetList, .router, .routerList, .securityGroup, .securityGroupList, .addressGroup, .addressGroupList:
                return 300.0 // 5 minutes for moderately static resources
            case .volumeSnapshot, .volumeSnapshotList, .objectStorage, .objectStorageList:
                return 180.0 // 3 minutes for snapshots and object storage
            case .server, .serverDetail, .serverList, .port, .portList, .volume, .volumeList, .floatingIP, .floatingIPList:
                return 120.0 // 2 minutes for frequently changing resources
            }
        }

        /// Check if this is a list resource
        public var isList: Bool {
            return rawValue.hasSuffix("_list")
        }

        /// Get the corresponding single resource type for a list
        public var singleResourceType: ResourceType? {
            guard isList else { return nil }
            let singleName = String(rawValue.dropLast(5)) // Remove "_list"
            return ResourceType(rawValue: singleName)
        }
    }

    // MARK: - Initialization

    /// Initialize the OpenStack cache manager with configurable parameters.
    ///
    /// - Parameters:
    ///   - maxCacheSize: Maximum number of cache entries (default: 4000)
    ///   - maxMemoryUsage: Maximum memory usage in bytes (default: 80 MB)
    ///   - cacheIdentifier: Optional identifier for consistent cache filenames (e.g., cloud name).
    ///     When provided, cache files use hash-based naming enabling reuse across restarts.
    ///   - logger: Logger instance for cache operations
    public init(
        maxCacheSize: Int = 4000, // Increased for OpenStack resource density
        maxMemoryUsage: Int = 80 * 1024 * 1024, // 80 MB optimized for OpenStack data
        cacheIdentifier: String? = nil,
        logger: any OpenStackClientLogger
    ) {
        let config = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: maxCacheSize / 5,         // 20% in L1 for hot data
            l1MaxMemory: maxMemoryUsage / 4,     // 25% in L1 memory
            l2MaxSize: maxCacheSize / 2,         // 50% in L2 compressed
            l2MaxMemory: maxMemoryUsage / 2,     // 50% in L2 memory
            l3MaxSize: maxCacheSize * 5,         // 500% on disk
            defaultTTL: 300.0,
            enableCompression: true,
            enableMetrics: true,
            cacheIdentifier: cacheIdentifier
        )

        let memoryKitLogger = MemoryKitLoggerAdapter(openStackLogger: logger)
        self.multiLevelCache = MultiLevelCacheManager(configuration: config, logger: memoryKitLogger)
        self.logger = logger

        // Background tasks are NOT auto-started to reduce CPU overhead
        // The cache works perfectly without background tasks - they only provide
        // periodic cleanup which happens naturally during normal operations
    }

    // MARK: - Helper Methods

    /// Map OpenStack resource types to cache priorities
    private func getPriorityForResourceType(_ resourceType: ResourceType) -> MultiLevelCacheManager<String, Data>.CachePriority {
        switch resourceType {
        case .authentication, .serviceEndpoints:
            return .critical
        case .server, .serverDetail, .floatingIP, .volume:
            return .high
        case .network, .subnet, .port, .router, .securityGroup, .addressGroup, .image, .flavor:
            return .normal
        case .serverList, .networkList, .volumeList, .quotas, .volumeSnapshot, .objectStorage, .objectStorageList:
            return .low
        default:
            return .normal
        }
    }

    // MARK: - OpenStack-Specific Cache Operations

    /// Store data in cache with automatic resource type detection and TTL assignment
    public func store<T: Codable>(
        _ data: T,
        forKey key: String,
        resourceType: ResourceType,
        customTTL: TimeInterval? = nil
    ) async {
        do {
            let jsonData = try JSONEncoder().encode(data)
            let ttl = customTTL ?? resourceType.defaultTTL

            let priority = getPriorityForResourceType(resourceType)
            await multiLevelCache.store(jsonData, forKey: key, priority: priority, customTTL: ttl)

            // Track the key by resource type
            if keysByResourceType[resourceType] == nil {
                keysByResourceType[resourceType] = Set<String>()
            }
            keysByResourceType[resourceType]?.insert(key)

            logger.logInfo("Cached OpenStack data", context: [
                "key": key,
                "resourceType": resourceType.rawValue,
                "size": jsonData.count,
                "ttl": ttl
            ])

        } catch {
            logger.logError("Failed to encode data for cache", context: [
                "key": key,
                "error": error.localizedDescription
            ])
        }
    }

    /// Retrieve data from cache with automatic type conversion
    public func retrieve<T: Codable>(
        forKey key: String,
        as type: T.Type,
        resourceType: ResourceType
    ) async -> T? {
        guard let jsonData = await multiLevelCache.retrieve(forKey: key, as: Data.self) else {
            return nil
        }

        do {
            let decoded = try JSONDecoder().decode(type, from: jsonData)

            logger.logDebug("OpenStack cache hit", context: [
                "key": key,
                "resourceType": resourceType.rawValue
            ])

            return decoded
        } catch {
            logger.logError("Failed to decode cached OpenStack data", context: [
                "key": key,
                "error": error.localizedDescription
            ])
            // Remove corrupted data
            await multiLevelCache.remove(forKey: key)
            return nil
        }
    }

    /// Remove specific entry from cache
    public func removeEntry(forKey key: String) async {
        await multiLevelCache.remove(forKey: key)

        // Remove from tracking
        for resourceType in ResourceType.allCases {
            keysByResourceType[resourceType]?.remove(key)
        }

        logger.logInfo("Removed OpenStack cache entry", context: ["key": key])
    }

    /// Clear all entries of a specific resource type
    public func clearResourceType(_ resourceType: ResourceType) async {
        let keysToRemove = keysByResourceType[resourceType] ?? Set<String>()

        for key in keysToRemove {
            await multiLevelCache.remove(forKey: key)
        }

        // Clear the tracking for this resource type
        keysByResourceType[resourceType] = nil

        logger.logInfo("Cleared OpenStack cache for resource type", context: [
            "resourceType": resourceType.rawValue,
            "entriesRemoved": keysToRemove.count
        ])
    }

    /// Clear all cached data
    public func clearAll() async {
        await multiLevelCache.clearAll()
        // Clear all tracking
        keysByResourceType.removeAll()

        logger.logInfo("Cleared all OpenStack cache entries", context: [:])
    }

    // MARK: - Intelligent Invalidation

    /// Invalidate cache entries based on OpenStack resource relationships
    public func invalidateRelated(to resourceType: ResourceType, resourceId: String? = nil) async {
        var keysToInvalidate: Set<String> = []

        // Define relationships between OpenStack resource types
        switch resourceType {
        case .server:
            // When a server changes, invalidate server lists and potentially network resources
            keysToInvalidate.insert("server_list")
            if let serverId = resourceId {
                keysToInvalidate.insert("server_\(serverId)")
            }

        case .serverList:
            // When server list is invalidated, clear all server entries
            let allKeys = getAllTrackedKeys()
            let serverKeys = allKeys.filter { $0.hasPrefix("server_") && !$0.hasPrefix("server_list") }
            keysToInvalidate.formUnion(serverKeys)

        case .network:
            // Network changes affect ports, subnets, routers
            keysToInvalidate.insert("network_list")
            keysToInvalidate.insert("port_list")
            keysToInvalidate.insert("subnet_list")
            if let networkId = resourceId {
                keysToInvalidate.insert("network_\(networkId)")
                let allKeys = getAllTrackedKeys()
                let relatedKeys = allKeys.filter { key in
                    key.hasPrefix("port_") || key.hasPrefix("subnet_")
                }
                keysToInvalidate.formUnion(relatedKeys)
            }

        case .volume:
            keysToInvalidate.insert("volume_list")
            if let volumeId = resourceId {
                keysToInvalidate.insert("volume_\(volumeId)")
            }

        case .floatingIP:
            keysToInvalidate.insert("floating_ip_list")
            keysToInvalidate.insert("port_list") // FloatingIPs affect ports

        case .securityGroup:
            keysToInvalidate.insert("security_group_list")
            keysToInvalidate.insert("server_list") // Security groups affect servers
            keysToInvalidate.insert("port_list") // And ports

        default:
            // For other resources, just invalidate their list counterparts
            if !resourceType.isList {
                let listType = resourceType.rawValue + "_list"
                keysToInvalidate.insert(listType)
            }
        }

        // Remove the identified keys
        for key in keysToInvalidate {
            await multiLevelCache.remove(forKey: key)
        }

        if !keysToInvalidate.isEmpty {
            logger.logInfo("Invalidated related OpenStack cache entries", context: [
                "resourceType": resourceType.rawValue,
                "resourceId": resourceId ?? "all",
                "invalidatedKeys": Array(keysToInvalidate)
            ])
        }
    }

    // MARK: - Statistics and Monitoring

    /// Get comprehensive OpenStack cache statistics
    public func getAdvancedStats() async -> AdvancedCacheStats {
        let stats = await multiLevelCache.getStatistics()
        let hitRate = stats.overallHitRate
        let count = stats.l1Stats.entries + stats.l2Stats.entries + stats.l3Stats.entries
        let memoryUsage = stats.l1Stats.memoryUsage + stats.l2Stats.memoryUsage + stats.l3Stats.memoryUsage
        let hitCount = stats.l1Stats.hitCount + stats.l2Stats.hitCount + stats.l3Stats.hitCount
        let missCount = stats.totalMisses

        // Resource type breakdown (simplified since we don't have getAllKeys)
        var resourceStats: [ResourceType: ResourceTypeStats] = [:]
        let allKeys: [String] = [] // TODO: Implement getAllKeys equivalent

        for resourceType in ResourceType.allCases {
            let entries = allKeys.filter { $0.contains(resourceType.rawValue) }
            resourceStats[resourceType] = ResourceTypeStats(
                entryCount: entries.count,
                totalSize: 0, // Simplified - would need detailed tracking
                avgAge: 0,    // Simplified - would need detailed tracking
                avgAccessCount: 0 // Simplified - would need detailed tracking
            )
        }

        return AdvancedCacheStats(
            entryCount: count,
            totalSize: memoryUsage,
            hitRate: hitRate,
            hitCount: hitCount,
            missCount: missCount,
            memoryUtilization: 0.5, // Simplified - MultiLevelCache would need to expose this
            cacheUtilization: 0.5,  // Simplified - MultiLevelCache would need to expose this
            resourceStats: resourceStats,
            oldestEntryAge: 0, // Simplified - MultiLevelCache would need to expose this
            averageEntryAge: 0  // Simplified - MultiLevelCache would need to expose this
        )
    }

    /// Get basic cache statistics for compatibility
    public func getCacheStats() async -> CacheStats {
        let stats = await multiLevelCache.getStatistics()
        let hitRate = stats.overallHitRate
        let count = stats.l1Stats.entries + stats.l2Stats.entries + stats.l3Stats.entries
        let memoryUsage = stats.l1Stats.memoryUsage + stats.l2Stats.memoryUsage + stats.l3Stats.memoryUsage

        return CacheStats(
            entryCount: count,
            totalSize: memoryUsage,
            hitRate: hitRate
        )
    }
}

// MARK: - OpenStack-Specific Statistics Types

public struct AdvancedCacheStats: Sendable {
    public let entryCount: Int
    public let totalSize: Int
    public let hitRate: Double
    public let hitCount: Int
    public let missCount: Int
    public let memoryUtilization: Double
    public let cacheUtilization: Double
    public let resourceStats: [OpenStackCacheManager.ResourceType: ResourceTypeStats]
    public let oldestEntryAge: TimeInterval
    public let averageEntryAge: TimeInterval

    public var description: String {
        let hitRatePercent = String(format: "%.1f", hitRate * 100)
        let memoryPercent = String(format: "%.1f", memoryUtilization * 100)
        let cachePercent = String(format: "%.1f", cacheUtilization * 100)

        return """
        Advanced OpenStack Cache Stats:
        Entries: \(entryCount), Size: \(totalSize) bytes
        Hit Rate: \(hitRatePercent)% (\(hitCount)/\(hitCount + missCount))
        Utilization: Memory \(memoryPercent)%, Cache \(cachePercent)%
        Avg Age: \(String(format: "%.1f", averageEntryAge))s, Oldest: \(String(format: "%.1f", oldestEntryAge))s
        """
    }
}

public struct ResourceTypeStats: Sendable {
    public let entryCount: Int
    public let totalSize: Int
    public let avgAge: Double
    public let avgAccessCount: Double

    public var description: String {
        return "Entries: \(entryCount), Size: \(totalSize)b, Age: \(String(format: "%.1f", avgAge))s, Access: \(String(format: "%.1f", avgAccessCount))"
    }
}

public struct CacheStats: Sendable {
    public let entryCount: Int
    public let totalSize: Int
    public let hitRate: Double
}