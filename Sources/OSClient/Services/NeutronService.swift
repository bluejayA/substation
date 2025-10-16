import Foundation

// MARK: - Neutron (Network) Service

public actor NeutronService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "network"
    private let cacheManager: OpenStackCacheManager
    private let invalidationManager: IntelligentCacheInvalidation
    private let logger: any OpenStackClientLogger

    public init(core: OpenStackClientCore, logger: any OpenStackClientLogger) {
        self.core = core
        self.logger = logger
        self.cacheManager = OpenStackCacheManager(
            maxCacheSize: 5000, // Increased for network resource density
            maxMemoryUsage: 40 * 1024 * 1024, // 40MB optimized for network service
            logger: logger
        )
        self.invalidationManager = IntelligentCacheInvalidation(
            cacheManager: cacheManager,
            logger: logger
        )
    }

    // MARK: - Network Operations

    /// List networks with intelligent caching
    public func listNetworks(options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> [Network] {
        let cacheKey = "neutron_network_list"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [Network].self,
                resourceType: .networkList
            ) {
                logger.logInfo("Neutron service cache hit - network list", context: [
                    "networkCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - listing networks", context: [
            "forceRefresh": forceRefresh
        ])

        var path = "/v2.0/networks"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        // Fetch networks
        let response: NetworkListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        // Cache with extended TTL for networks
        await cacheManager.store(
            response.networks,
            forKey: cacheKey,
            resourceType: .networkList,
            customTTL: 600.0 // 10 minutes for networks
        )

        // Cache individual networks
        for network in response.networks {
            await cacheManager.store(
                network,
                forKey: "neutron_network_\(network.id)",
                resourceType: .network,
                customTTL: 600.0
            )
        }

        return response.networks
    }

    /// Get network details with caching
    public func getNetwork(id: String, forceRefresh: Bool = false) async throws -> Network {
        let cacheKey = "neutron_network_\(id)"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: Network.self,
                resourceType: .network
            ) {
                logger.logInfo("Neutron service cache hit - network detail", context: [
                    "networkId": id
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - getting network", context: [
            "networkId": id
        ])

        let response: NetworkDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2.0/networks/\(id)",
            expected: 200
        )

        await cacheManager.store(
            response.network,
            forKey: cacheKey,
            resourceType: .network,
            customTTL: 600.0
        )

        return response.network
    }

    /// Create a network with cache invalidation
    public func createNetwork(request: CreateNetworkRequest) async throws -> Network {
        let requestData = try SharedResources.jsonEncoder.encode(["network": request])
        let response: NetworkDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2.0/networks",
            body: requestData,
            expected: 201
        )

        let network = response.network

        // Cache the new network
        await cacheManager.store(
            network,
            forKey: "neutron_network_\(network.id)",
            resourceType: .network,
            customTTL: 600.0
        )

        // Invalidate network list
        await invalidationManager.invalidateForOperation(
            .create,
            resourceType: .network,
            resourceId: network.id
        )

        logger.logInfo("Neutron service - network created", context: [
            "networkId": network.id,
            "networkName": network.name
        ])

        return network
    }

    /// Update a network
    public func updateNetwork(id: String, request: UpdateNetworkRequest) async throws -> Network {
        let requestData = try SharedResources.jsonEncoder.encode(["network": request])
        let response: NetworkDetailResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v2.0/networks/\(id)",
            body: requestData,
            expected: 200
        )
        return response.network
    }

    /// Delete a network with cache invalidation
    public func deleteNetwork(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2.0/networks/\(id)",
            expected: 204
        )

        await invalidationManager.invalidateForOperation(
            .delete,
            resourceType: .network,
            resourceId: id
        )

        logger.logInfo("Neutron service - network deleted", context: [
            "networkId": id
        ])
    }

    // MARK: - Subnet Operations

    /// List subnets with caching
    public func listSubnets(networkId: String? = nil, options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> [Subnet] {
        let cacheKey = networkId != nil ? "neutron_subnet_list_\(networkId!)" : "neutron_subnet_list"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [Subnet].self,
                resourceType: .subnetList
            ) {
                logger.logInfo("Neutron service cache hit - subnet list", context: [
                    "subnetCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - listing subnets", context: [:])

        var queryItems = options.queryItems
        if let networkId = networkId {
            queryItems.append(URLQueryItem(name: "network_id", value: networkId))
        }

        var path = "/v2.0/subnets"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: SubnetListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        await cacheManager.store(
            response.subnets,
            forKey: cacheKey,
            resourceType: .subnetList,
            customTTL: 480.0 // 8 minutes for subnets
        )

        // Cache individual subnets
        for subnet in response.subnets {
            await cacheManager.store(
                subnet,
                forKey: "neutron_subnet_\(subnet.id)",
                resourceType: .subnet,
                customTTL: 480.0
            )
        }

        return response.subnets
    }

    /// Get subnet details with caching
    public func getSubnet(id: String, forceRefresh: Bool = false) async throws -> Subnet {
        let cacheKey = "neutron_subnet_\(id)"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: Subnet.self,
                resourceType: .subnet
            ) {
                logger.logInfo("Neutron service cache hit - subnet detail", context: [
                    "subnetId": id
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - getting subnet", context: [
            "subnetId": id
        ])

        let response: SubnetDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2.0/subnets/\(id)",
            expected: 200
        )

        await cacheManager.store(
            response.subnet,
            forKey: cacheKey,
            resourceType: .subnet,
            customTTL: 480.0
        )

        return response.subnet
    }

    /// Create a subnet with cache invalidation
    public func createSubnet(request: CreateSubnetRequest) async throws -> Subnet {
        let requestData = try SharedResources.jsonEncoder.encode(["subnet": request])

        // Debug: Log the request payload
        if let jsonString = String(data: requestData, encoding: .utf8) {
            logger.logDebug("Creating subnet with payload", context: ["payload": jsonString])
        }

        let response: SubnetDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2.0/subnets",
            body: requestData,
            expected: 201
        )

        let subnet = response.subnet

        await cacheManager.store(
            subnet,
            forKey: "neutron_subnet_\(subnet.id)",
            resourceType: .subnet,
            customTTL: 480.0
        )

        await invalidationManager.invalidateForOperation(
            .create,
            resourceType: .subnet,
            resourceId: subnet.id
        )

        logger.logInfo("Neutron service - subnet created", context: [
            "subnetId": subnet.id,
            "networkId": subnet.networkId
        ])

        return subnet
    }

    /// Update a subnet
    public func updateSubnet(id: String, request: UpdateSubnetRequest) async throws -> Subnet {
        let requestData = try SharedResources.jsonEncoder.encode(["subnet": request])
        let response: SubnetDetailResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v2.0/subnets/\(id)",
            body: requestData,
            expected: 200
        )
        return response.subnet
    }

    /// Delete a subnet
    public func deleteSubnet(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2.0/subnets/\(id)",
            expected: 204
        )
    }

    // MARK: - Port Operations

    /// List ports with shorter caching (ports change more frequently)
    public func listPorts(networkId: String? = nil, deviceId: String? = nil, options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> [Port] {
        var cacheKey = "neutron_port_list"
        if let networkId = networkId {
            cacheKey += "_network_\(networkId)"
        }
        if let deviceId = deviceId {
            cacheKey += "_device_\(deviceId)"
        }

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [Port].self,
                resourceType: .portList
            ) {
                logger.logInfo("Neutron service cache hit - port list", context: [
                    "portCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - listing ports", context: [:])

        var queryItems = options.queryItems
        if let networkId = networkId {
            queryItems.append(URLQueryItem(name: "network_id", value: networkId))
        }
        if let deviceId = deviceId {
            queryItems.append(URLQueryItem(name: "device_id", value: deviceId))
        }

        var path = "/v2.0/ports"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: PortListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        // Shorter TTL for ports as they change more frequently
        await cacheManager.store(
            response.ports,
            forKey: cacheKey,
            resourceType: .portList,
            customTTL: 120.0 // 2 minutes for ports
        )

        // Cache individual ports
        for port in response.ports {
            await cacheManager.store(
                port,
                forKey: "neutron_port_\(port.id)",
                resourceType: .port,
                customTTL: 120.0
            )
        }

        return response.ports
    }

    /// Get port details with caching
    public func getPort(id: String, forceRefresh: Bool = false) async throws -> Port {
        let cacheKey = "neutron_port_\(id)"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: Port.self,
                resourceType: .port
            ) {
                logger.logInfo("Neutron service cache hit - port detail", context: [
                    "portId": id
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - getting port", context: [
            "portId": id
        ])

        let response: PortDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2.0/ports/\(id)",
            expected: 200
        )

        await cacheManager.store(
            response.port,
            forKey: cacheKey,
            resourceType: .port,
            customTTL: 120.0
        )

        return response.port
    }

    /// Create a port
    public func createPort(request: CreatePortRequest) async throws -> Port {
        let requestData = try SharedResources.jsonEncoder.encode(["port": request])
        let response: PortDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2.0/ports",
            body: requestData,
            expected: 201
        )
        return response.port
    }

    /// Update a port
    public func updatePort(id: String, request: UpdatePortRequest) async throws -> Port {
        let requestData = try SharedResources.jsonEncoder.encode(["port": request])
        let response: PortDetailResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v2.0/ports/\(id)",
            body: requestData,
            expected: 200
        )
        return response.port
    }

    /// Delete a port
    public func deletePort(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2.0/ports/\(id)",
            expected: 204
        )
    }

    // MARK: - Router Operations

    /// List routers with caching
    public func listRouters(options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> [Router] {
        let cacheKey = "neutron_router_list"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [Router].self,
                resourceType: .routerList
            ) {
                logger.logInfo("Neutron service cache hit - router list", context: [
                    "routerCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - listing routers", context: [:])

        var path = "/v2.0/routers"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        // Fetch routers
        let response: RouterListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        var routers = response.routers

        // Fetch detailed router info to populate with more metadata
        for i in 0..<routers.count {
            do {
                let detailedRouter = try await getRouter(id: routers[i].id)
                routers[i] = detailedRouter
            } catch {
                // Keep the basic router info if detailed fetch fails
            }
        }

        await cacheManager.store(
            routers,
            forKey: cacheKey,
            resourceType: .routerList,
            customTTL: 360.0 // 6 minutes for routers
        )

        logger.logInfo("Router list loaded", context: [
            "routerCount": routers.count
        ])

        return routers
    }

    /// Get router details with caching
    public func getRouter(id: String, forceRefresh: Bool = false) async throws -> Router {
        let cacheKey = "neutron_router_\(id)"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: Router.self,
                resourceType: .router
            ) {
                logger.logInfo("Neutron service cache hit - router detail", context: [
                    "routerId": id
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - getting router", context: [
            "routerId": id
        ])

        // Fetch router details
        let response: RouterDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2.0/routers/\(id)",
            expected: 200
        )

        var router = response.router

        // Fetch and populate router interfaces
        do {
            let interfaces = try await fetchRouterInterfaces(routerId: id)
            router.interfaces = interfaces
        } catch {
            logger.logError("Failed to fetch router interfaces for router \(id): \(error)", context: [:])
            router.interfaces = []
        }

        await cacheManager.store(
            router,
            forKey: cacheKey,
            resourceType: .router,
            customTTL: 360.0
        )

        return router
    }

    /// Fetch router interfaces by querying ports attached to the router
    private func fetchRouterInterfaces(routerId: String) async throws -> [RouterInterface] {
        // Query ports where device_id matches the router ID
        let ports = try await listPorts(deviceId: routerId)

        // Filter for ALL router-related ports (not just router_interface)
        // Includes: network:router_interface, network:router_gateway, network:router_interface_distributed
        let interfaces = ports
            .filter { port in
                guard let deviceOwner = port.deviceOwner else { return false }
                // Include any port owned by a router component
                return deviceOwner.hasPrefix("network:router_interface") ||
                       deviceOwner.hasPrefix("network:router_gateway") ||
                       deviceOwner == "network:router_interface_distributed"
            }
            .compactMap { port -> RouterInterface? in
                // Get subnet ID and IP address from fixedIps
                guard let fixedIp = port.fixedIps?.first else { return nil }

                return RouterInterface(
                    subnetId: fixedIp.subnetId,
                    portId: port.id,
                    ipAddress: fixedIp.ipAddress
                )
            }

        logger.logInfo("Fetched router interfaces", context: [
            "routerId": routerId,
            "totalPorts": ports.count,
            "interfaceCount": interfaces.count
        ])

        return interfaces
    }

    /// Create a router
    public func createRouter(request: CreateRouterRequest) async throws -> Router {
        let requestData = try SharedResources.jsonEncoder.encode(["router": request])
        let response: RouterDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2.0/routers",
            body: requestData,
            expected: 201
        )
        return response.router
    }

    /// Update a router
    public func updateRouter(id: String, request: UpdateRouterRequest) async throws -> Router {
        let requestData = try SharedResources.jsonEncoder.encode(["router": request])
        let response: RouterDetailResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v2.0/routers/\(id)",
            body: requestData,
            expected: 200
        )
        return response.router
    }

    /// Delete a router
    public func deleteRouter(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2.0/routers/\(id)",
            expected: 204
        )
    }

    /// Add interface to router
    public func addRouterInterface(routerId: String, subnetId: String? = nil, portId: String? = nil) async throws -> RouterInterface {
        var request: [String: String] = [:]
        if let subnetId = subnetId {
            request["subnet_id"] = subnetId
        }
        if let portId = portId {
            request["port_id"] = portId
        }

        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: RouterInterfaceResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v2.0/routers/\(routerId)/add_router_interface",
            body: requestData,
            expected: 200
        )
        return response.interface
    }

    /// Remove interface from router
    public func removeRouterInterface(routerId: String, subnetId: String? = nil, portId: String? = nil) async throws {
        var request: [String: String] = [:]
        if let subnetId = subnetId {
            request["subnet_id"] = subnetId
        }
        if let portId = portId {
            request["port_id"] = portId
        }

        let requestData = try SharedResources.jsonEncoder.encode(request)
        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/v2.0/routers/\(routerId)/remove_router_interface",
            body: requestData,
            expected: 200
        )
    }

    // MARK: - Security Group Operations

    /// List security groups with caching
    public func listSecurityGroups(options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> [SecurityGroup] {
        let cacheKey = "neutron_security_group_list"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [SecurityGroup].self,
                resourceType: .securityGroupList
            ) {
                logger.logInfo("Neutron service cache hit - security group list", context: [
                    "securityGroupCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - listing security groups", context: [:])

        var path = "/v2.0/security-groups"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: SecurityGroupListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        await cacheManager.store(
            response.securityGroups,
            forKey: cacheKey,
            resourceType: .securityGroupList,
            customTTL: 300.0 // 5 minutes for security groups
        )

        return response.securityGroups
    }

    /// Get security group details
    public func getSecurityGroup(id: String) async throws -> SecurityGroup {
        let response: SecurityGroupDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2.0/security-groups/\(id)",
            expected: 200
        )
        return response.securityGroup
    }

    /// Create a security group
    public func createSecurityGroup(request: CreateSecurityGroupRequest) async throws -> SecurityGroup {
        let requestData = try SharedResources.jsonEncoder.encode(["security_group": request])
        let response: SecurityGroupDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2.0/security-groups",
            body: requestData,
            expected: 201
        )
        return response.securityGroup
    }

    /// Delete a security group
    public func deleteSecurityGroup(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2.0/security-groups/\(id)",
            expected: 204
        )
    }

    // MARK: - Security Group Rule Operations

    /// List security group rules
    public func listSecurityGroupRules(securityGroupId: String? = nil, options: PaginationOptions = PaginationOptions()) async throws -> [SecurityGroupRule] {
        var queryItems = options.queryItems
        if let securityGroupId = securityGroupId {
            queryItems.append(URLQueryItem(name: "security_group_id", value: securityGroupId))
        }

        var path = "/v2.0/security-group-rules"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: SecurityGroupRuleListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.securityGroupRules
    }

    /// Create a security group rule
    public func createSecurityGroupRule(request: CreateSecurityGroupRuleRequest) async throws -> SecurityGroupRule {
        let requestData = try SharedResources.jsonEncoder.encode(["security_group_rule": request])
        let response: SecurityGroupRuleDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2.0/security-group-rules",
            body: requestData,
            expected: 201
        )
        return response.securityGroupRule
    }

    /// Delete a security group rule
    public func deleteSecurityGroupRule(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2.0/security-group-rules/\(id)",
            expected: 204
        )
    }

    // MARK: - Floating IP Operations

    /// List floating IPs with shorter caching (they change frequently)
    public func listFloatingIPs(options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> [FloatingIP] {
        let cacheKey = "neutron_floating_ip_list"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [FloatingIP].self,
                resourceType: .floatingIPList
            ) {
                logger.logInfo("Neutron service cache hit - floating IP list", context: [
                    "floatingIPCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Neutron service API call - listing floating IPs", context: [:])

        var path = "/v2.0/floatingips"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: FloatingIPListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        // Short TTL for floating IPs as they're frequently associated/disassociated
        await cacheManager.store(
            response.floatingips,
            forKey: cacheKey,
            resourceType: .floatingIPList,
            customTTL: 90.0 // 1.5 minutes for floating IPs
        )

        return response.floatingips
    }

    /// Get floating IP details
    public func getFloatingIP(id: String) async throws -> FloatingIP {
        let response: FloatingIPDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2.0/floatingips/\(id)",
            expected: 200
        )
        return response.floatingip
    }

    /// Create a floating IP
    public func createFloatingIP(networkID: String, portID: String? = nil, subnetID: String? = nil, description: String? = nil) async throws -> FloatingIP {
        let request = CreateFloatingIPRequest(
            floatingNetworkId: networkID,
            portId: portID,
            subnetId: subnetID,
            description: description
        )

        let requestData = try SharedResources.jsonEncoder.encode(FloatingIPWrapper(floatingip: request))
        let response: FloatingIPDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2.0/floatingips",
            body: requestData,
            expected: 201
        )
        return response.floatingip
    }

    /// Update floating IP (associate/disassociate) with cache invalidation
    public func updateFloatingIP(id: String, portID: String? = nil, fixedIP: String? = nil) async throws -> FloatingIP {
        let request = UpdateFloatingIPRequest(portId: portID, fixedIpAddress: fixedIP)

        let requestData = try SharedResources.jsonEncoder.encode(FloatingIPWrapper(floatingip: request))
        let response: FloatingIPDetailResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v2.0/floatingips/\(id)",
            body: requestData,
            expected: 200
        )

        // Invalidate floating IP and port caches
        await invalidationManager.invalidateForOperation(
            portID != nil ? .associateFloatingIP : .disassociateFloatingIP,
            resourceType: .floatingIP,
            resourceId: id
        )

        logger.logInfo("Neutron service - floating IP updated", context: [
            "floatingIPId": id,
            "portId": portID,
            "operation": portID != nil ? "associate" : "disassociate"
        ])

        return response.floatingip
    }

    /// Delete a floating IP
    public func deleteFloatingIP(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2.0/floatingips/\(id)",
            expected: 204
        )
    }

    // MARK: - Quota Operations

    /// Get network quotas for project
    public func getQuotas(projectId: String) async throws -> NetworkQuotaSet {
        let response: NetworkQuotaResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2.0/quotas/\(projectId)",
            expected: 200
        )
        return response.quota
    }

    // MARK: - Cache Management

    /// Clear all Neutron service caches
    public func clearCache() async {
        await cacheManager.clearResourceType(.network)
        await cacheManager.clearResourceType(.networkList)
        await cacheManager.clearResourceType(.subnet)
        await cacheManager.clearResourceType(.subnetList)
        await cacheManager.clearResourceType(.port)
        await cacheManager.clearResourceType(.portList)
        await cacheManager.clearResourceType(.router)
        await cacheManager.clearResourceType(.routerList)
        await cacheManager.clearResourceType(.floatingIP)
        await cacheManager.clearResourceType(.floatingIPList)
        await cacheManager.clearResourceType(.securityGroup)
        await cacheManager.clearResourceType(.securityGroupList)

        logger.logInfo("Neutron service - cleared all caches", context: [:])
    }

    /// Get cache statistics
    public func getCacheStats() async -> AdvancedCacheStats {
        return await cacheManager.getAdvancedStats()
    }

    // MARK: - Topology Caching Optimization

    /// Load full network topology with smart caching
    /// This method optimizes for the common use case of loading all network resources
    public func loadNetworkTopology(forceRefresh: Bool = false) async throws -> NetworkTopology {
        logger.logInfo("Neutron service - loading network topology", context: [
            "forceRefresh": forceRefresh
        ])

        // Load networks, subnets, and routers in parallel for better performance
        async let networksTask = listNetworks(forceRefresh: forceRefresh)
        async let subnetsTask = listSubnets(forceRefresh: forceRefresh)
        async let routersTask = listRouters(forceRefresh: forceRefresh)

        let networks = try await networksTask
        let subnets = try await subnetsTask
        let routers = try await routersTask

        return NetworkTopology(
            networks: networks,
            subnets: subnets,
            routers: routers
        )
    }

    /// Prefetch network topology for better responsiveness
    public func prefetchNetworkTopology() async {
        logger.logInfo("Neutron service - prefetching network topology", context: [:])

        // Prefetch in background
        Task {
            do {
                _ = try await loadNetworkTopology()
                logger.logInfo("Neutron service - topology prefetched", context: [:])
            } catch {
                logger.logError("Failed to prefetch network topology", context: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
}

// MARK: - Response Models

public struct NetworkListResponse: Codable, Sendable {
    public let networks: [Network]
}

public struct NetworkDetailResponse: Codable, Sendable {
    public let network: Network
}

public struct SubnetListResponse: Codable, Sendable {
    public let subnets: [Subnet]
}

public struct SubnetDetailResponse: Codable, Sendable {
    public let subnet: Subnet
}

public struct PortListResponse: Codable, Sendable {
    public let ports: [Port]
}

public struct PortDetailResponse: Codable, Sendable {
    public let port: Port
}

public struct RouterListResponse: Codable, Sendable {
    public let routers: [Router]
}

public struct RouterDetailResponse: Codable, Sendable {
    public let router: Router
}

public struct RouterInterfaceResponse: Codable, Sendable {
    public let interface: RouterInterface

    enum CodingKeys: String, CodingKey {
        case interface = "router_interface"
    }
}

public struct SecurityGroupListResponse: Codable, Sendable {
    public let securityGroups: [SecurityGroup]

    enum CodingKeys: String, CodingKey {
        case securityGroups = "security_groups"
    }
}

public struct SecurityGroupDetailResponse: Codable, Sendable {
    public let securityGroup: SecurityGroup

    enum CodingKeys: String, CodingKey {
        case securityGroup = "security_group"
    }
}

public struct SecurityGroupRuleListResponse: Codable, Sendable {
    public let securityGroupRules: [SecurityGroupRule]

    enum CodingKeys: String, CodingKey {
        case securityGroupRules = "security_group_rules"
    }
}

public struct SecurityGroupRuleDetailResponse: Codable, Sendable {
    public let securityGroupRule: SecurityGroupRule

    enum CodingKeys: String, CodingKey {
        case securityGroupRule = "security_group_rule"
    }
}

public struct FloatingIPListResponse: Codable, Sendable {
    public let floatingips: [FloatingIP]
}

public struct FloatingIPDetailResponse: Codable, Sendable {
    public let floatingip: FloatingIP
}

public struct NetworkQuotaResponse: Codable, Sendable {
    public let quota: NetworkQuotaSet

    enum CodingKeys: String, CodingKey {
        case quota
    }
}

// MARK: - Network Topology Helper

/// Represents a complete network topology snapshot
public struct NetworkTopology: Sendable {
    public let networks: [Network]
    public let subnets: [Subnet]
    public let routers: [Router]

    public init(networks: [Network], subnets: [Subnet], routers: [Router]) {
        self.networks = networks
        self.subnets = subnets
        self.routers = routers
    }

    /// Get subnets for a specific network
    public func subnets(for networkId: String) -> [Subnet] {
        return subnets.filter { $0.networkId == networkId }
    }

    /// Get total resource count
    public var totalResourceCount: Int {
        return networks.count + subnets.count + routers.count
    }
}