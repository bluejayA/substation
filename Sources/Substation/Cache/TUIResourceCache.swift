import Foundation
import OSClient
import struct OSClient.Port

/// Centralized cache accessor for TUI resources
/// Provides a clean interface to OpenStackResourceCache
@MainActor
final class TUIResourceCache {
    private let resourceCache: OpenStackResourceCache

    init(resourceCache: OpenStackResourceCache) {
        self.resourceCache = resourceCache
    }

    // MARK: - Resource Accessors

    var servers: [Server] {
        get { resourceCache.servers }
        set { Task { await resourceCache.setServers(newValue) } }
    }

    var serverGroups: [ServerGroup] {
        get { resourceCache.serverGroups }
        set { Task { await resourceCache.setServerGroups(newValue) } }
    }

    var networks: [Network] {
        get { resourceCache.networks }
        set { Task { await resourceCache.setNetworks(newValue) } }
    }

    var volumes: [Volume] {
        get { resourceCache.volumes }
        set { Task { await resourceCache.setVolumes(newValue) } }
    }

    var images: [Image] {
        get { resourceCache.images }
        set { Task { await resourceCache.setImages(newValue) } }
    }

    var volumeTypes: [VolumeType] {
        get { resourceCache.volumeTypes }
        set { Task { await resourceCache.setVolumeTypes(newValue) } }
    }

    var ports: [Port] {
        get { resourceCache.ports }
        set { Task { await resourceCache.setPorts(newValue) } }
    }

    var routers: [Router] {
        get { resourceCache.routers }
        set { Task { await resourceCache.setRouters(newValue) } }
    }

    var floatingIPs: [FloatingIP] {
        get { resourceCache.floatingIPs }
        set { Task { await resourceCache.setFloatingIPs(newValue) } }
    }

    var flavors: [Flavor] {
        get { resourceCache.flavors }
        set { Task { await resourceCache.setFlavors(newValue) } }
    }

    var subnets: [Subnet] {
        get { resourceCache.subnets }
        set { Task { await resourceCache.setSubnets(newValue) } }
    }

    var securityGroups: [SecurityGroup] {
        get { resourceCache.securityGroups }
        set { Task { await resourceCache.setSecurityGroups(newValue) } }
    }

    var keyPairs: [KeyPair] {
        get { resourceCache.keyPairs }
        set { Task { await resourceCache.setKeyPairs(newValue) } }
    }

    var qosPolicies: [QoSPolicy] {
        get { resourceCache.qosPolicies }
        set { Task { await resourceCache.setQoSPolicies(newValue) } }
    }

    var availabilityZones: [String] {
        get { resourceCache.availabilityZones }
        set { Task { await resourceCache.setAvailabilityZones(newValue) } }
    }

    var secrets: [Secret] {
        get { resourceCache.secrets }
        set { Task { await resourceCache.setSecrets(newValue) } }
    }

    var barbicanContainers: [BarbicanContainer] {
        get { resourceCache.barbicanContainers }
        set { Task { await resourceCache.setBarbicanContainers(newValue) } }
    }

    var loadBalancers: [LoadBalancer] {
        get { resourceCache.loadBalancers }
        set { Task { await resourceCache.setLoadBalancers(newValue) } }
    }

    var swiftContainers: [SwiftContainer] {
        get { resourceCache.swiftContainers }
        set { Task { await resourceCache.setSwiftContainers(newValue) } }
    }

    var swiftObjectsByContainer: [String: [SwiftObject]] {
        return resourceCache.swiftObjectsByContainer
    }

    func getSwiftObjects(forContainer containerName: String) -> [SwiftObject]? {
        return resourceCache.getSwiftObjects(forContainer: containerName)
    }

    func setSwiftObjects(_ objects: [SwiftObject], forContainer containerName: String) async {
        await resourceCache.setSwiftObjects(objects, forContainer: containerName)
    }

    var volumeSnapshots: [VolumeSnapshot] {
        get { resourceCache.volumeSnapshots }
        set { Task { await resourceCache.setVolumeSnapshots(newValue) } }
    }

    var volumeBackups: [VolumeBackup] {
        get { resourceCache.volumeBackups }
        set { Task { await resourceCache.setVolumeBackups(newValue) } }
    }

    // MARK: - Flavor Recommendations

    var flavorRecommendations: [WorkloadType: [FlavorRecommendation]] {
        get { resourceCache.flavorRecommendations }
        set { Task { await resourceCache.setFlavorRecommendations(newValue) } }
    }

    var recommendationsRefreshTime: Date {
        resourceCache.recommendationsRefreshTime
    }

    // MARK: - Quota Data

    var computeQuotas: ComputeQuotaSet? {
        get { resourceCache.computeQuotas }
        set { Task { await resourceCache.setComputeQuotas(newValue) } }
    }

    var networkQuotas: NetworkQuotaSet? {
        get { resourceCache.networkQuotas }
        set { Task { await resourceCache.setNetworkQuotas(newValue) } }
    }

    var volumeQuotas: VolumeQuotaSet? {
        get { resourceCache.volumeQuotas }
        set { Task { await resourceCache.setVolumeQuotas(newValue) } }
    }

    var computeLimits: ComputeQuotaSet? {
        get { resourceCache.computeLimits }
        set { Task { await resourceCache.setComputeLimits(newValue) } }
    }

    // MARK: - Cache Operations

    func clearAll() async {
        await resourceCache.clearAll()
    }
}