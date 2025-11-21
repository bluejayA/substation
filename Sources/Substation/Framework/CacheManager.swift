import Foundation
import MemoryKit
import OSClient
import struct OSClient.Port

// MARK: - CacheManager

/// Manages all resource caching backed by MemoryKit.
/// Provides computed property accessors and cache invalidation for OpenStack resources.
///
/// This class centralizes all cached resource access, providing a clean interface
/// between the TUI layer and the underlying MemoryKit-backed storage.
@MainActor
final class CacheManager {

    // MARK: - Dependencies

    private let memoryContainer: SubstationMemoryContainer

    /// The underlying resource cache from MemoryKit
    internal var resourceCache: OpenStackResourceCache {
        return memoryContainer.openStackResourceCache
    }

    /// Resource name cache for display name lookups
    internal let resourceNameCache: ResourceNameCache

    // MARK: - Navigation State Reference

    /// Reference to Swift navigation state for container-specific object caching
    internal weak var swiftNavState: SwiftNavigationState?

    // MARK: - Initialization

    /// Initialize the CacheManager with required dependencies.
    ///
    /// - Parameters:
    ///   - memoryContainer: The SubstationMemoryContainer providing MemoryKit integration
    ///   - resourceNameCache: Cache for resource name lookups
    init(memoryContainer: SubstationMemoryContainer, resourceNameCache: ResourceNameCache) {
        self.memoryContainer = memoryContainer
        self.resourceNameCache = resourceNameCache
        Logger.shared.logInfo("CacheManager initialized with MemoryKit integration")
    }

    // MARK: - Cached Compute Resources

    /// Cached servers from OpenStack compute service
    internal var cachedServers: [Server] {
        get { resourceCache.servers }
        set { Task { await resourceCache.setServers(newValue) } }
    }

    /// Cached server groups from OpenStack compute service
    internal var cachedServerGroups: [ServerGroup] {
        get { resourceCache.serverGroups }
        set { Task { await resourceCache.setServerGroups(newValue) } }
    }

    /// Cached flavors from OpenStack compute service
    internal var cachedFlavors: [Flavor] {
        get { resourceCache.flavors }
        set { Task { await resourceCache.setFlavors(newValue) } }
    }

    /// Cached key pairs from OpenStack compute service
    internal var cachedKeyPairs: [KeyPair] {
        get { resourceCache.keyPairs }
        set { Task { await resourceCache.setKeyPairs(newValue) } }
    }

    /// Cached availability zones from OpenStack compute service
    internal var cachedAvailabilityZones: [String] {
        get { resourceCache.availabilityZones }
        set { Task { await resourceCache.setAvailabilityZones(newValue) } }
    }

    // MARK: - Cached Network Resources

    /// Cached networks from OpenStack network service
    internal var cachedNetworks: [Network] {
        get { resourceCache.networks }
        set { Task { await resourceCache.setNetworks(newValue) } }
    }

    /// Cached ports from OpenStack network service
    internal var cachedPorts: [Port] {
        get { resourceCache.ports }
        set { Task { await resourceCache.setPorts(newValue) } }
    }

    /// Cached routers from OpenStack network service
    internal var cachedRouters: [Router] {
        get { resourceCache.routers }
        set { Task { await resourceCache.setRouters(newValue) } }
    }

    /// Cached floating IPs from OpenStack network service
    internal var cachedFloatingIPs: [FloatingIP] {
        get { resourceCache.floatingIPs }
        set { Task { await resourceCache.setFloatingIPs(newValue) } }
    }

    /// Cached subnets from OpenStack network service
    internal var cachedSubnets: [Subnet] {
        get { resourceCache.subnets }
        set { Task { await resourceCache.setSubnets(newValue) } }
    }

    /// Cached security groups from OpenStack network service
    internal var cachedSecurityGroups: [SecurityGroup] {
        get { resourceCache.securityGroups }
        set { Task { await resourceCache.setSecurityGroups(newValue) } }
    }

    /// Cached QoS policies from OpenStack network service
    internal var cachedQoSPolicies: [QoSPolicy] {
        get { resourceCache.qosPolicies }
        set { Task { await resourceCache.setQoSPolicies(newValue) } }
    }

    // MARK: - Cached Block Storage Resources

    /// Cached volumes from OpenStack block storage service
    internal var cachedVolumes: [Volume] {
        get { resourceCache.volumes }
        set { Task { await resourceCache.setVolumes(newValue) } }
    }

    /// Cached volume types from OpenStack block storage service
    internal var cachedVolumeTypes: [VolumeType] {
        get { resourceCache.volumeTypes }
        set { Task { await resourceCache.setVolumeTypes(newValue) } }
    }

    /// Cached volume snapshots from OpenStack block storage service
    internal var cachedVolumeSnapshots: [VolumeSnapshot] {
        get { resourceCache.volumeSnapshots }
        set { Task { await resourceCache.setVolumeSnapshots(newValue) } }
    }

    /// Cached volume backups from OpenStack block storage service
    internal var cachedVolumeBackups: [VolumeBackup] {
        get { resourceCache.volumeBackups }
        set { Task { await resourceCache.setVolumeBackups(newValue) } }
    }

    // MARK: - Cached Image Resources

    /// Cached images from OpenStack image service
    internal var cachedImages: [Image] {
        get { resourceCache.images }
        set { Task { await resourceCache.setImages(newValue) } }
    }

    // MARK: - Cached Key Management Resources

    /// Cached secrets from OpenStack key management service
    internal var cachedSecrets: [Secret] {
        get { resourceCache.secrets }
        set { Task { await resourceCache.setSecrets(newValue) } }
    }

    // MARK: - Cached Load Balancer Resources

    /// Cached load balancers from OpenStack load balancer service
    internal var cachedLoadBalancers: [LoadBalancer] {
        get { resourceCache.loadBalancers }
        set { Task { await resourceCache.setLoadBalancers(newValue) } }
    }

    // MARK: - Cached Object Storage Resources

    /// Cached Swift containers from OpenStack object storage service
    internal var cachedSwiftContainers: [SwiftContainer] {
        get { resourceCache.swiftContainers }
        set { Task { await resourceCache.setSwiftContainers(newValue) } }
    }

    /// Cached Swift objects for the current container.
    /// Uses navigation state to determine which container's objects to return.
    internal var cachedSwiftObjects: [SwiftObject]? {
        get {
            // Use navigation state instead of selectedResource to avoid race conditions
            guard let containerName = swiftNavState?.currentContainer else {
                return nil
            }
            return resourceCache.getSwiftObjects(forContainer: containerName)
        }
        set {
            // Use navigation state instead of selectedResource
            guard let containerName = swiftNavState?.currentContainer,
                  let objects = newValue else {
                return
            }
            Task { await resourceCache.setSwiftObjects(objects, forContainer: containerName) }
        }
    }

    // MARK: - Cached Flavor Recommendations

    /// Cached flavor recommendations for all workload types
    internal var cachedFlavorRecommendations: [WorkloadType: [FlavorRecommendation]] {
        get { resourceCache.flavorRecommendations }
        set { Task { await resourceCache.setFlavorRecommendations(newValue) } }
    }

    /// Timestamp of last recommendations refresh
    internal var lastRecommendationsRefresh: Date {
        resourceCache.recommendationsRefreshTime
    }

    // MARK: - Cached Quota Data

    /// Cached compute quotas from OpenStack compute service
    internal var cachedComputeQuotas: ComputeQuotaSet? {
        get { resourceCache.computeQuotas }
        set { Task { await resourceCache.setComputeQuotas(newValue) } }
    }

    /// Cached network quotas from OpenStack network service
    internal var cachedNetworkQuotas: NetworkQuotaSet? {
        get { resourceCache.networkQuotas }
        set { Task { await resourceCache.setNetworkQuotas(newValue) } }
    }

    /// Cached volume quotas from OpenStack block storage service
    internal var cachedVolumeQuotas: VolumeQuotaSet? {
        get { resourceCache.volumeQuotas }
        set { Task { await resourceCache.setVolumeQuotas(newValue) } }
    }

    /// Cached compute limits from OpenStack compute service
    internal var cachedComputeLimits: ComputeQuotaSet? {
        get { resourceCache.computeLimits }
        set { Task { await resourceCache.setComputeLimits(newValue) } }
    }

    // MARK: - Cache Operations

    /// Clear all caches.
    /// This will reset all cached resources to their empty states.
    func clearAllCaches() async {
        await resourceCache.clearAll()
        await resourceNameCache.clearAsync()
        Logger.shared.logInfo("CacheManager cleared all caches")
    }

    /// Get cache statistics for monitoring and debugging.
    ///
    /// - Returns: Statistics about cached resources
    func getCacheStatistics() async -> OpenStackCacheStatistics {
        return await resourceCache.getCacheStatistics()
    }
}
