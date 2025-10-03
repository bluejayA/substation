import Foundation
import MemoryKit

/// Data manager for network-related operations with MemoryKit integration
public actor NetworkDataManager {
    private let neutronService: NeutronService
    private let logger: any OpenStackClientLogger
    private let memoryManager: MemoryManager

    public init(neutronService: NeutronService, logger: any OpenStackClientLogger, memoryManager: MemoryManager) {
        self.neutronService = neutronService
        self.logger = logger
        self.memoryManager = memoryManager
    }

    // MARK: - Network Operations

    /// List all networks with caching
    public func listNetworks(forceRefresh: Bool = false) async throws -> [Network] {
        let cacheKey = "network_list"

        if !forceRefresh {
            if let cachedNetworks = await memoryManager.retrieve(forKey: cacheKey, as: [Network].self) {
                return cachedNetworks
            }
        }

        let networks = try await neutronService.listNetworks()
        await memoryManager.store(networks, forKey:cacheKey)

        for network in networks {
            await memoryManager.store(network, forKey:"network_\(network.id)")
        }

        return networks
    }

    /// List all subnets
    public func listSubnets() async throws -> [Subnet] {
        let cacheKey = "subnet_list"

        if let cachedSubnets = await memoryManager.retrieve(forKey: cacheKey, as: [Subnet].self) {
            return cachedSubnets
        }

        let subnets = try await neutronService.listSubnets()
        await memoryManager.store(subnets, forKey:cacheKey)

        for subnet in subnets {
            await memoryManager.store(subnet, forKey:"subnet_\(subnet.id)")
        }

        return subnets
    }

    /// List all ports
    public func listPorts() async throws -> [Port] {
        let cacheKey = "port_list"

        if let cachedPorts = await memoryManager.retrieve(forKey: cacheKey, as: [Port].self) {
            return cachedPorts
        }

        let ports = try await neutronService.listPorts()
        await memoryManager.store(ports, forKey:cacheKey)

        for port in ports {
            await memoryManager.store(port, forKey:"port_\(port.id)")
        }
        return ports
    }

    /// List all floating IPs
    public func listFloatingIPs() async throws -> [FloatingIP] {
        let cacheKey = "floating_ip_list"

        if let cachedFloatingIPs = await memoryManager.retrieve(forKey: cacheKey, as: [FloatingIP].self) {
            return cachedFloatingIPs
        }

        let floatingIPs = try await neutronService.listFloatingIPs()
        await memoryManager.store(floatingIPs, forKey:cacheKey)

        for fip in floatingIPs {
            await memoryManager.store(fip, forKey:"floating_ip_\(fip.id)")
        }
        return floatingIPs
    }

    /// List all security groups
    public func listSecurityGroups() async throws -> [SecurityGroup] {
        let cacheKey = "security_group_list"

        if let cachedSecurityGroups = await memoryManager.retrieve(forKey: cacheKey, as: [SecurityGroup].self) {
            return cachedSecurityGroups
        }

        let securityGroups = try await neutronService.listSecurityGroups()
        await memoryManager.store(securityGroups, forKey:cacheKey)

        for sg in securityGroups {
            await memoryManager.store(sg, forKey:"security_group_\(sg.id)")
        }

        return securityGroups
    }

    /// List all routers
    public func listRouters() async throws -> [Router] {
        let cacheKey = "router_list"

        if let cachedRouters = await memoryManager.retrieve(forKey: cacheKey, as: [Router].self) {
            return cachedRouters
        }

        let routers = try await neutronService.listRouters()
        await memoryManager.store(routers, forKey:cacheKey)

        for router in routers {
            await memoryManager.store(router, forKey:"router_\(router.id)")
        }

        return routers
    }

    /// Create a new network
    public func createNetwork(request: CreateNetworkRequest) async throws -> Network {
        let network = try await neutronService.createNetwork(request: request)
        await memoryManager.store(network, forKey:"network_\(network.id)")
        await memoryManager.clearKey( "network_list")
        return network
    }

    /// Create a new subnet
    public func createSubnet(request: CreateSubnetRequest) async throws -> Subnet {
        let subnet = try await neutronService.createSubnet(request: request)
        await memoryManager.store(subnet, forKey:"subnet_\(subnet.id)")
        await memoryManager.clearKey( "subnet_list")
        return subnet
    }

    /// Delete a network
    public func deleteNetwork(id: String) async throws {
        try await neutronService.deleteNetwork(id: id)
        await memoryManager.clearKey( "network_\(id)")
        await memoryManager.clearKey( "network_list")
    }

    // MARK: - Cache Management

    /// Clear all cached data
    public func clearCache() async {
        await memoryManager.clearAll()
    }

    /// Get memory usage statistics
    public func getMemoryStats() async -> MemoryMetrics {
        return await memoryManager.getMetrics()
    }

    /// Handle memory pressure by clearing cache
    public func handleMemoryPressure() async {
        await clearCache()
    }
}