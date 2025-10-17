import Foundation
import MemoryKit
import OSClient

// MARK: - Resource Cache Adapter

/// ResourceCacheAdapter provides a bridge between legacy ResourceNameCache
/// and the new MemoryKit-based SubstationMemoryManager, ensuring backward
/// compatibility while providing enhanced features.
@MainActor
final class ResourceCacheAdapter {

    // MARK: - Properties

    private let memoryManager: SubstationMemoryManager

    // MARK: - Synchronous Read Cache (for rendering)

    private var syncFlavorCache: [String: String] = [:]
    private var syncImageCache: [String: String] = [:]
    private var syncServerCache: [String: String] = [:]
    private var syncNetworkCache: [String: String] = [:]
    private var syncSubnetCache: [String: String] = [:]
    private var syncSecurityGroupCache: [String: String] = [:]

    // MARK: - Initialization

    init(memoryManager: SubstationMemoryManager) {
        self.memoryManager = memoryManager
        Logger.shared.logInfo("ResourceCacheAdapter initialized with MemoryKit integration")
    }

    // MARK: - Legacy ResourceNameCache Compatibility

    /// Set flavor name (legacy compatibility)
    func setFlavorName(_ id: String, name: String) async {
        syncFlavorCache[id] = name
        await memoryManager.setFlavorName(name, forId: id)
    }

    /// Set image name (legacy compatibility)
    func setImageName(_ id: String, name: String) async {
        syncImageCache[id] = name
        await memoryManager.setImageName(name, forId: id)
    }

    /// Set server name (legacy compatibility)
    func setServerName(_ id: String, name: String) async {
        syncServerCache[id] = name
        await memoryManager.setServerName(name, forId: id)
    }

    /// Set network name (legacy compatibility)
    func setNetworkName(_ id: String, name: String) async {
        syncNetworkCache[id] = name
        await memoryManager.setNetworkName(name, forId: id)
    }

    /// Set subnet name (legacy compatibility)
    func setSubnetName(_ id: String, name: String) async {
        syncSubnetCache[id] = name
        await memoryManager.setSubnetName(name, forId: id)
    }

    /// Set security group name (legacy compatibility)
    func setSecurityGroupName(_ id: String, name: String) async {
        syncSecurityGroupCache[id] = name
        await memoryManager.setSecurityGroupName(name, forId: id)
    }

    /// Get flavor name (legacy compatibility)
    func getFlavorName(_ id: String) async -> String? {
        return await memoryManager.getFlavorName(forId: id)
    }

    /// Get image name (legacy compatibility)
    func getImageName(_ id: String) async -> String? {
        return await memoryManager.getImageName(forId: id)
    }

    /// Get server name (legacy compatibility)
    func getServerName(_ id: String) async -> String? {
        return await memoryManager.getServerName(forId: id)
    }

    /// Get network name (legacy compatibility)
    func getNetworkName(_ id: String) async -> String? {
        return await memoryManager.getNetworkName(forId: id)
    }

    /// Get subnet name (legacy compatibility)
    func getSubnetName(_ id: String) async -> String? {
        return await memoryManager.getSubnetName(forId: id)
    }

    /// Get security group name (legacy compatibility)
    func getSecurityGroupName(_ id: String) async -> String? {
        return await memoryManager.getSecurityGroupName(forId: id)
    }

    /// Clear all cached names (legacy compatibility)
    func clear() async {
        syncFlavorCache.removeAll()
        syncImageCache.removeAll()
        syncServerCache.removeAll()
        syncNetworkCache.removeAll()
        syncSubnetCache.removeAll()
        syncSecurityGroupCache.removeAll()
        await memoryManager.clearResourceNameCache()
        Logger.shared.logInfo("ResourceCacheAdapter cleared all resource names")
    }

    // MARK: - Synchronous Read Methods (for rendering performance)

    /// Get flavor name synchronously (reads from local cache)
    func getFlavorNameSync(_ id: String) -> String? {
        return syncFlavorCache[id]
    }

    /// Get image name synchronously (reads from local cache)
    func getImageNameSync(_ id: String) -> String? {
        return syncImageCache[id]
    }

    /// Get server name synchronously (reads from local cache)
    func getServerNameSync(_ id: String) -> String? {
        return syncServerCache[id]
    }

    /// Get network name synchronously (reads from local cache)
    func getNetworkNameSync(_ id: String) -> String? {
        return syncNetworkCache[id]
    }

    /// Get subnet name synchronously (reads from local cache)
    func getSubnetNameSync(_ id: String) -> String? {
        return syncSubnetCache[id]
    }

    /// Get security group name synchronously (reads from local cache)
    func getSecurityGroupNameSync(_ id: String) -> String? {
        return syncSecurityGroupCache[id]
    }

    // MARK: - Enhanced Operations

    /// Batch store multiple resource names
    func batchStoreResourceNames(_ resources: [(id: String, name: String, type: ResourceType)]) async {
        for resource in resources {
            await memoryManager.setResourceName(resource.name, forId: resource.id, resourceType: resource.type.rawValue)
        }
        Logger.shared.logInfo("ResourceCacheAdapter batch stored \(resources.count) resource names")
    }

    /// Batch retrieve multiple resource names
    func batchRetrieveResourceNames(for ids: [String], type: ResourceType) async -> [String: String] {
        var results: [String: String] = [:]

        for id in ids {
            if let name = await memoryManager.getResourceName(forId: id, resourceType: type.rawValue) {
                results[id] = name
            }
        }

        Logger.shared.logDebug("ResourceCacheAdapter batch retrieved \(results.count)/\(ids.count) \(type.rawValue) names")
        return results
    }

    /// Preload resource names from OpenStack resources
    func preloadFromResources(_ servers: [Server]) async {
        let mappings = servers.compactMap { server -> (id: String, name: String, type: ResourceType)? in
            guard let name = server.name else { return nil }
            return (id: server.id, name: name, type: .server)
        }
        await batchStoreResourceNames(mappings)
    }

    func preloadFromResources(_ networks: [Network]) async {
        let mappings = networks.compactMap { network -> (id: String, name: String, type: ResourceType)? in
            guard let name = network.name else { return nil }
            return (id: network.id, name: name, type: .network)
        }
        await batchStoreResourceNames(mappings)
    }

    func preloadFromResources(_ volumes: [Volume]) async {
        let mappings = volumes.compactMap { volume -> (id: String, name: String, type: ResourceType)? in
            guard let name = volume.name else { return nil }
            return (id: volume.id, name: name, type: .volume)
        }
        await batchStoreResourceNames(mappings)
    }

    func preloadFromResources(_ images: [Image]) async {
        let mappings = images.compactMap { image -> (id: String, name: String, type: ResourceType)? in
            guard let name = image.name else { return nil }
            return (id: image.id, name: name, type: .image)
        }
        await batchStoreResourceNames(mappings)
    }

    func preloadFromResources(_ flavors: [Flavor]) async {
        let mappings = flavors.compactMap { flavor -> (id: String, name: String, type: ResourceType)? in
            guard let name = flavor.name else { return nil }
            return (id: flavor.id, name: name, type: .flavor)
        }
        await batchStoreResourceNames(mappings)
    }

    func preloadFromResources(_ subnets: [Subnet]) async {
        let mappings = subnets.compactMap { subnet -> (id: String, name: String, type: ResourceType)? in
            guard let name = subnet.name else { return nil }
            return (id: subnet.id, name: name, type: .subnet)
        }
        await batchStoreResourceNames(mappings)
    }

    func preloadFromResources(_ securityGroups: [SecurityGroup]) async {
        let mappings = securityGroups.compactMap { sg -> (id: String, name: String, type: ResourceType)? in
            guard let name = sg.name else { return nil }
            return (id: sg.id, name: name, type: .securityGroup)
        }
        await batchStoreResourceNames(mappings)
    }

    // MARK: - Statistics and Monitoring

    /// Get cache statistics for resource names
    func getStatistics() async -> ResourceCacheStatistics {
        let cacheStats = await memoryManager.getCacheStatistics()
        return ResourceCacheStatistics(
            totalEntries: cacheStats.resourceNameCache.currentSize,
            hitRate: cacheStats.resourceNameCache.hitRate,
            hitCount: cacheStats.resourceNameCache.hitCount,
            missCount: cacheStats.resourceNameCache.misses,
            evictionCount: cacheStats.resourceNameCache.evictions
        )
    }

    /// Get cache hit rate for monitoring
    func getCacheHitRate() async -> Double {
        let stats = await getStatistics()
        return stats.hitRate
    }
}

// MARK: - Supporting Types

public enum ResourceType: String, CaseIterable, Sendable {
    case server = "server"
    case network = "network"
    case subnet = "subnet"
    case volume = "volume"
    case image = "image"
    case flavor = "flavor"
    case securityGroup = "securityGroup"
    case keyPair = "keyPair"
    case router = "router"
    case port = "port"
    case floatingIP = "floatingIP"
}

public struct ResourceCacheStatistics: Sendable {
    public let totalEntries: Int
    public let hitRate: Double
    public let hitCount: Int
    public let missCount: Int
    public let evictionCount: Int

    public var summary: String {
        return """
        Resource Cache Statistics:
        Total Entries: \(totalEntries)
        Hit Rate: \(String(format: "%.1f", hitRate * 100))%
        Hits: \(hitCount), Misses: \(missCount)
        Evictions: \(evictionCount)
        """
    }
}

// MARK: - Extensions for OpenStack Integration

extension ResourceCacheAdapter {
    /// Resolve resource name with fallback to ID
    func resolveResourceName(id: String, type: ResourceType, fallbackToId: Bool = true) async -> String {
        if let cachedName = await memoryManager.getResourceName(forId: id, resourceType: type.rawValue) {
            return cachedName
        }

        if fallbackToId {
            Logger.shared.logDebug("ResourceCacheAdapter using ID as fallback for \(type.rawValue): \(id)")
            return id
        }

        return "Unknown"
    }

    /// Get display name for any OpenStack resource
    func getDisplayName(for resource: Any) async -> String {
        switch resource {
        case let server as Server:
            return await resolveResourceName(id: server.id, type: .server)
        case let network as Network:
            return await resolveResourceName(id: network.id, type: .network)
        case let volume as Volume:
            return await resolveResourceName(id: volume.id, type: .volume)
        case let image as Image:
            return await resolveResourceName(id: image.id, type: .image)
        case let flavor as Flavor:
            return await resolveResourceName(id: flavor.id, type: .flavor)
        case let subnet as Subnet:
            return await resolveResourceName(id: subnet.id, type: .subnet)
        case let sg as SecurityGroup:
            return await resolveResourceName(id: sg.id, type: .securityGroup)
        default:
            Logger.shared.logWarning("ResourceCacheAdapter: Unknown resource type for display name")
            return "Unknown Resource"
        }
    }
}