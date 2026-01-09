import Foundation
import MemoryKit
import OSClient
import struct OSClient.Port

// MARK: - OpenStack Resource Cache

/// OpenStackResourceCache provides MemoryKit-backed storage for all OpenStack resources
/// with synchronous accessors for rendering performance. This replaces the legacy
/// array-based caching in TUI with proper memory management.
@MainActor
final class OpenStackResourceCache {

    // MARK: - Properties

    private let memoryManager: SubstationMemoryManager

    // MARK: - Synchronous Read Caches (for rendering performance)

    private var syncServers: [Server] = []
    private var syncServerGroups: [ServerGroup] = []
    private var syncNetworks: [Network] = []
    private var syncVolumes: [Volume] = []
    private var syncImages: [Image] = []
    private var syncVolumeTypes: [VolumeType] = []
    private var syncPorts: [Port] = []
    private var syncRouters: [Router] = []
    private var syncFloatingIPs: [FloatingIP] = []
    private var syncFlavors: [Flavor] = []
    private var syncSubnets: [Subnet] = []
    private var syncSecurityGroups: [SecurityGroup] = []
    private var syncKeyPairs: [KeyPair] = []
    private var syncQoSPolicies: [QoSPolicy] = []
    private var syncAvailabilityZones: [String] = []
    private var syncSecrets: [Secret] = []
    private var syncLoadBalancers: [LoadBalancer] = []
    private var syncClusters: [Cluster] = []
    private var syncClusterTemplates: [ClusterTemplate] = []
    private var syncNodegroups: [Nodegroup] = []
    private var syncSwiftContainers: [SwiftContainer] = []
    private var syncSwiftContainersCacheTime: Date = Date.distantPast
    private var syncSwiftObjectsByContainer: [String: [SwiftObject]] = [:]
    private var syncSwiftObjectsCacheTime: [String: Date] = [:]
    private var syncVolumeSnapshots: [VolumeSnapshot] = []
    private var syncVolumeBackups: [VolumeBackup] = []

    // Quota caches (optional types)
    private var syncComputeQuotas: ComputeQuotaSet?
    private var syncNetworkQuotas: NetworkQuotaSet?
    private var syncVolumeQuotas: VolumeQuotaSet?
    private var syncComputeLimits: ComputeQuotaSet?

    // Flavor recommendations
    private var syncFlavorRecommendations: [WorkloadType: [FlavorRecommendation]] = [:]
    private var lastRecommendationsRefresh: Date = Date.distantPast

    // MARK: - Initialization

    init(memoryManager: SubstationMemoryManager) {
        self.memoryManager = memoryManager
        Logger.shared.logInfo("OpenStackResourceCache initialized with MemoryKit integration")
    }

    // MARK: - Synchronous Getters (for rendering)

    var servers: [Server] { syncServers }
    var serverGroups: [ServerGroup] { syncServerGroups }
    var networks: [Network] { syncNetworks }
    var volumes: [Volume] { syncVolumes }
    var images: [Image] { syncImages }
    var volumeTypes: [VolumeType] { syncVolumeTypes }
    var ports: [Port] { syncPorts }
    var routers: [Router] { syncRouters }
    var floatingIPs: [FloatingIP] { syncFloatingIPs }
    var flavors: [Flavor] { syncFlavors }
    var subnets: [Subnet] { syncSubnets }
    var securityGroups: [SecurityGroup] { syncSecurityGroups }
    var keyPairs: [KeyPair] { syncKeyPairs }
    var qosPolicies: [QoSPolicy] { syncQoSPolicies }
    var availabilityZones: [String] { syncAvailabilityZones }
    var secrets: [Secret] { syncSecrets }
    var loadBalancers: [LoadBalancer] { syncLoadBalancers }
    var clusters: [Cluster] { syncClusters }
    var clusterTemplates: [ClusterTemplate] { syncClusterTemplates }
    var nodegroups: [Nodegroup] { syncNodegroups }
    var swiftContainers: [SwiftContainer] { syncSwiftContainers }
    var swiftObjectsByContainer: [String: [SwiftObject]] { syncSwiftObjectsByContainer }
    var volumeSnapshots: [VolumeSnapshot] { syncVolumeSnapshots }
    var volumeBackups: [VolumeBackup] { syncVolumeBackups }

    var computeQuotas: ComputeQuotaSet? { syncComputeQuotas }
    var networkQuotas: NetworkQuotaSet? { syncNetworkQuotas }
    var volumeQuotas: VolumeQuotaSet? { syncVolumeQuotas }
    var computeLimits: ComputeQuotaSet? { syncComputeLimits }

    var flavorRecommendations: [WorkloadType: [FlavorRecommendation]] { syncFlavorRecommendations }
    var recommendationsRefreshTime: Date { lastRecommendationsRefresh }

    func setRecommendationsRefreshTime(_ date: Date) {
        lastRecommendationsRefresh = date
    }

    // MARK: - Async Setters (for data updates)

    func setServers(_ servers: [Server]) async {
        syncServers = servers

        Logger.shared.logDebug("OpenStackResourceCache cached \(servers.count) servers")
    }

    func setServerGroups(_ serverGroups: [ServerGroup]) async {
        syncServerGroups = serverGroups

        Logger.shared.logDebug("OpenStackResourceCache cached \(serverGroups.count) server groups")
    }

    func setNetworks(_ networks: [Network]) async {
        syncNetworks = networks

        Logger.shared.logDebug("OpenStackResourceCache cached \(networks.count) networks")
    }

    func setVolumes(_ volumes: [Volume]) async {
        syncVolumes = volumes

        Logger.shared.logDebug("OpenStackResourceCache cached \(volumes.count) volumes")
    }

    func setImages(_ images: [Image]) async {
        syncImages = images

        Logger.shared.logDebug("OpenStackResourceCache cached \(images.count) images")
    }

    func setVolumeTypes(_ volumeTypes: [VolumeType]) async {
        syncVolumeTypes = volumeTypes

        Logger.shared.logDebug("OpenStackResourceCache cached \(volumeTypes.count) volume types")
    }

    func setPorts(_ ports: [Port]) async {
        syncPorts = ports

        Logger.shared.logDebug("OpenStackResourceCache cached \(ports.count) ports")
    }

    func setRouters(_ routers: [Router]) async {
        syncRouters = routers

        Logger.shared.logDebug("OpenStackResourceCache cached \(routers.count) routers")
    }

    func setFloatingIPs(_ floatingIPs: [FloatingIP]) async {
        syncFloatingIPs = floatingIPs

        Logger.shared.logDebug("OpenStackResourceCache cached \(floatingIPs.count) floating IPs")
    }

    func setFlavors(_ flavors: [Flavor]) async {
        syncFlavors = flavors

        Logger.shared.logDebug("OpenStackResourceCache cached \(flavors.count) flavors")
    }

    func setSubnets(_ subnets: [Subnet]) async {
        syncSubnets = subnets

        Logger.shared.logDebug("OpenStackResourceCache cached \(subnets.count) subnets")
    }

    func setSecurityGroups(_ securityGroups: [SecurityGroup]) async {
        syncSecurityGroups = securityGroups

        Logger.shared.logDebug("OpenStackResourceCache cached \(securityGroups.count) security groups")
    }

    func setKeyPairs(_ keyPairs: [KeyPair]) async {
        syncKeyPairs = keyPairs

        Logger.shared.logDebug("OpenStackResourceCache cached \(keyPairs.count) key pairs")
    }

    func setQoSPolicies(_ qosPolicies: [QoSPolicy]) async {
        syncQoSPolicies = qosPolicies

        Logger.shared.logDebug("OpenStackResourceCache cached \(qosPolicies.count) QoS policies")
    }

    func setAvailabilityZones(_ zones: [String]) async {
        syncAvailabilityZones = zones
        Logger.shared.logDebug("OpenStackResourceCache cached \(zones.count) availability zones")
    }

    func setSecrets(_ secrets: [Secret]) async {
        syncSecrets = secrets

        Logger.shared.logDebug("OpenStackResourceCache cached \(secrets.count) secrets")
    }

    func setLoadBalancers(_ loadBalancers: [LoadBalancer]) async {
        syncLoadBalancers = loadBalancers

        Logger.shared.logDebug("OpenStackResourceCache cached \(loadBalancers.count) load balancers")
    }

    func setClusters(_ clusters: [Cluster]) async {
        syncClusters = clusters

        Logger.shared.logDebug("OpenStackResourceCache cached \(clusters.count) clusters")
    }

    func setClusterTemplates(_ templates: [ClusterTemplate]) async {
        syncClusterTemplates = templates

        Logger.shared.logDebug("OpenStackResourceCache cached \(templates.count) cluster templates")
    }

    func setNodegroups(_ nodegroups: [Nodegroup]) async {
        syncNodegroups = nodegroups

        Logger.shared.logDebug("OpenStackResourceCache cached \(nodegroups.count) nodegroups")
    }

    func setSwiftContainers(_ containers: [SwiftContainer]) async {
        syncSwiftContainers = containers
        syncSwiftContainersCacheTime = Date()

        Logger.shared.logDebug("OpenStackResourceCache cached \(containers.count) Swift containers")
    }

    /// Get the cache timestamp for the container list.
    ///
    /// - Returns: The date when containers were last cached
    func getSwiftContainersCacheTime() -> Date {
        return syncSwiftContainersCacheTime
    }

    /// Check if the container list cache is fresh.
    ///
    /// - Parameter maxAge: Maximum age in seconds for cache to be considered fresh
    /// - Returns: true if cache exists and is within maxAge
    func isSwiftContainersCacheFresh(maxAge: TimeInterval) -> Bool {
        return Date().timeIntervalSince(syncSwiftContainersCacheTime) < maxAge
    }

    func setSwiftObjects(_ objects: [SwiftObject], forContainer containerName: String) async {
        syncSwiftObjectsByContainer[containerName] = objects
        syncSwiftObjectsCacheTime[containerName] = Date()
        Logger.shared.logDebug("OpenStackResourceCache cached \(objects.count) Swift objects for container '\(containerName)'")
    }

    func getSwiftObjects(forContainer containerName: String) -> [SwiftObject]? {
        return syncSwiftObjectsByContainer[containerName]
    }

    /// Get the cache timestamp for a container's objects.
    ///
    /// - Parameter containerName: Name of the container
    /// - Returns: The date when objects were last cached, or nil if not cached
    func getSwiftObjectsCacheTime(forContainer containerName: String) -> Date? {
        return syncSwiftObjectsCacheTime[containerName]
    }

    /// Check if the cache for a container is fresh.
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - maxAge: Maximum age in seconds for cache to be considered fresh
    /// - Returns: true if cache exists and is within maxAge
    func isSwiftObjectsCacheFresh(forContainer containerName: String, maxAge: TimeInterval) -> Bool {
        guard let cacheTime = syncSwiftObjectsCacheTime[containerName] else {
            return false
        }
        return Date().timeIntervalSince(cacheTime) < maxAge
    }

    /// Clear cached Swift objects for a specific container.
    ///
    /// This removes the cached objects for the specified container from the cache.
    /// Used when navigating away from a container to ensure fresh data on re-entry.
    ///
    /// - Parameter containerName: Name of the container to clear objects for
    func clearSwiftObjects(forContainer containerName: String) {
        syncSwiftObjectsByContainer.removeValue(forKey: containerName)
        syncSwiftObjectsCacheTime.removeValue(forKey: containerName)
        Logger.shared.logDebug("OpenStackResourceCache cleared Swift objects for container '\(containerName)'")
    }

    /// Add objects to the cache for a container (optimistic update after upload).
    ///
    /// - Parameters:
    ///   - objects: Objects to add
    ///   - containerName: Name of the container
    func addSwiftObjects(_ objects: [SwiftObject], forContainer containerName: String) async {
        var existing = syncSwiftObjectsByContainer[containerName] ?? []
        existing.append(contentsOf: objects)
        syncSwiftObjectsByContainer[containerName] = existing
        syncSwiftObjectsCacheTime[containerName] = Date()
        Logger.shared.logDebug("OpenStackResourceCache added \(objects.count) Swift objects to container '\(containerName)' (total: \(existing.count))")
    }

    /// Remove objects from the cache for a container (optimistic update after delete).
    ///
    /// - Parameters:
    ///   - objectNames: Names of objects to remove
    ///   - containerName: Name of the container
    func removeSwiftObjects(withNames objectNames: Set<String>, forContainer containerName: String) async {
        guard var existing = syncSwiftObjectsByContainer[containerName] else { return }
        let originalCount = existing.count
        existing.removeAll { object in
            guard let name = object.name else { return false }
            return objectNames.contains(name)
        }
        syncSwiftObjectsByContainer[containerName] = existing
        syncSwiftObjectsCacheTime[containerName] = Date()
        Logger.shared.logDebug("OpenStackResourceCache removed \(originalCount - existing.count) Swift objects from container '\(containerName)' (remaining: \(existing.count))")
    }

    /// Remove a single object from the cache for a container (optimistic update after delete).
    ///
    /// - Parameters:
    ///   - objectName: Name of the object to remove
    ///   - containerName: Name of the container
    func removeSwiftObject(withName objectName: String, forContainer containerName: String) async {
        await removeSwiftObjects(withNames: [objectName], forContainer: containerName)
    }

    func setVolumeSnapshots(_ snapshots: [VolumeSnapshot]) async {
        syncVolumeSnapshots = snapshots
    }

    func setVolumeBackups(_ backups: [VolumeBackup]) async {
        syncVolumeBackups = backups
        Logger.shared.logDebug("OpenStackResourceCache cached \(backups.count) volume backups")
    }

    // MARK: - Quota Setters

    func setComputeQuotas(_ quotas: ComputeQuotaSet?) async {
        syncComputeQuotas = quotas
        Logger.shared.logDebug("OpenStackResourceCache cached compute quotas")
    }

    func setNetworkQuotas(_ quotas: NetworkQuotaSet?) async {
        syncNetworkQuotas = quotas
        Logger.shared.logDebug("OpenStackResourceCache cached network quotas")
    }

    func setVolumeQuotas(_ quotas: VolumeQuotaSet?) async {
        syncVolumeQuotas = quotas
        Logger.shared.logDebug("OpenStackResourceCache cached volume quotas")
    }

    func setComputeLimits(_ limits: ComputeQuotaSet?) async {
        syncComputeLimits = limits
        Logger.shared.logDebug("OpenStackResourceCache cached compute limits")
    }

    // MARK: - Flavor Recommendations

    func setFlavorRecommendations(_ recommendations: [WorkloadType: [FlavorRecommendation]]) async {
        syncFlavorRecommendations = recommendations
        lastRecommendationsRefresh = Date()
        Logger.shared.logDebug("OpenStackResourceCache cached \(recommendations.count) workload type recommendations")
    }

    // MARK: - Clear Operations

    func clearAll() async {
        syncServers.removeAll()
        syncServerGroups.removeAll()
        syncNetworks.removeAll()
        syncVolumes.removeAll()
        syncImages.removeAll()
        syncVolumeTypes.removeAll()
        syncPorts.removeAll()
        syncRouters.removeAll()
        syncFloatingIPs.removeAll()
        syncFlavors.removeAll()
        syncSubnets.removeAll()
        syncSecurityGroups.removeAll()
        syncKeyPairs.removeAll()
        syncQoSPolicies.removeAll()
        syncAvailabilityZones.removeAll()
        syncSecrets.removeAll()
        syncLoadBalancers.removeAll()
        syncClusters.removeAll()
        syncClusterTemplates.removeAll()
        syncNodegroups.removeAll()
        syncSwiftContainers.removeAll()
        syncSwiftObjectsByContainer.removeAll()
        syncSwiftObjectsCacheTime.removeAll()
        syncVolumeSnapshots.removeAll()
        syncVolumeBackups.removeAll()
        syncComputeQuotas = nil
        syncNetworkQuotas = nil
        syncVolumeQuotas = nil
        syncComputeLimits = nil
        syncFlavorRecommendations.removeAll()

        await memoryManager.clearAllCaches()
        Logger.shared.logInfo("OpenStackResourceCache cleared all caches")
    }

    // MARK: - Statistics

    func getCacheStatistics() async -> OpenStackCacheStatistics {
        let stats = await memoryManager.getCacheStatistics()
        let totalCount = syncServers.count + syncNetworks.count + syncVolumes.count +
                        syncImages.count + syncFlavors.count + syncPorts.count
        return OpenStackCacheStatistics(
            serverCount: syncServers.count,
            networkCount: syncNetworks.count,
            volumeCount: syncVolumes.count,
            imageCount: syncImages.count,
            flavorCount: syncFlavors.count,
            portCount: syncPorts.count,
            totalResourceCount: totalCount,
            memoryKitStats: stats
        )
    }
}

// MARK: - Statistics

public struct OpenStackCacheStatistics: Sendable {
    public let serverCount: Int
    public let networkCount: Int
    public let volumeCount: Int
    public let imageCount: Int
    public let flavorCount: Int
    public let portCount: Int
    public let totalResourceCount: Int
    public let memoryKitStats: SubstationCacheStatistics

    public var summary: String {
        return """
        OpenStack Resource Cache Statistics:
        Servers: \(serverCount)
        Networks: \(networkCount)
        Volumes: \(volumeCount)
        Images: \(imageCount)
        Flavors: \(flavorCount)
        Ports: \(portCount)
        Total Resources: \(totalResourceCount)
        System Health: \(memoryKitStats.systemHealth.overallHealth.description)
        """
    }
}