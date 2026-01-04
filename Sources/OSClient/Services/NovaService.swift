import Foundation

// MARK: - Nova (Compute) Service

public actor NovaService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "compute"
    private let cacheManager: OpenStackCacheManager
    private let invalidationManager: IntelligentCacheInvalidation
    private let logger: any OpenStackClientLogger

    public init(core: OpenStackClientCore, logger: any OpenStackClientLogger) {
        self.core = core
        self.logger = logger
        self.cacheManager = OpenStackCacheManager(
            maxCacheSize: 4500, // Increased for compute resource density
            maxMemoryUsage: 35 * 1024 * 1024, // 35MB optimized for compute service
            logger: logger
        )
        self.invalidationManager = IntelligentCacheInvalidation(
            cacheManager: cacheManager,
            logger: logger
        )
    }

    // MARK: - Server Operations

    /// List servers with optional pagination and intelligent caching
    public func listServers(options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> ServerListResponse {
        let cacheKey = "nova_server_list_\(options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&"))"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: ServerListResponse.self,
                resourceType: .serverList
            ) {
                logger.logInfo("Nova service cache hit - server list", context: [
                    "serverCount": cached.servers.count
                ])
                return cached
            }
        }

        logger.logInfo("Nova service API call - listing servers", context: [
            "forceRefresh": forceRefresh
        ])

        var path = "/servers/detail"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        // Fetch servers
        let response: ServerListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        // Cache the full response
        await cacheManager.store(
            response,
            forKey: cacheKey,
            resourceType: .serverList
        )

        // Cache individual servers for quick access
        for server in response.servers {
            await cacheManager.store(
                server,
                forKey: "nova_server_\(server.id)",
                resourceType: .server
            )

            // Log flavor information for debugging
            if let flavor = server.flavor {
                logger.logDebug("Server '\(server.name ?? server.id)' flavor: id=\(flavor.id), name=\(flavor.name ?? "nil"), originalName=\(flavor.originalName ?? "nil"), vcpus=\(flavor.vcpus?.description ?? "nil"), ram=\(flavor.ram?.description ?? "nil"), disk=\(flavor.disk?.description ?? "nil")", context: [:])
            } else {
                logger.logInfo("Server '\(server.name ?? server.id)' has nil flavor field - this may indicate a deleted flavor or API issue", context: [:])
            }
        }

        return response
    }

    /// Get detailed information about a server with intelligent caching
    public func getServer(id: String, forceRefresh: Bool = false) async throws -> Server {
        let cacheKey = "nova_server_\(id)"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: Server.self,
                resourceType: .server
            ) {
                logger.logInfo("Nova service cache hit - server detail", context: [
                    "serverId": id
                ])
                return cached
            }
        }

        logger.logInfo("Nova service API call - getting server", context: [
            "serverId": id,
            "forceRefresh": forceRefresh
        ])

        // Fetch server details
        let response: ServerDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/servers/\(id)",
            expected: 200
        )

        // Cache the server
        await cacheManager.store(
            response.server,
            forKey: cacheKey,
            resourceType: .server
        )

        return response.server
    }

    /// Create a new server with intelligent cache invalidation
    ///
    /// Creates a server using the Nova API. If a server group is specified,
    /// it is passed via os:scheduler_hints as required by the OpenStack API.
    ///
    /// - Parameter request: The server creation request parameters
    /// - Returns: The created server
    /// - Throws: API errors if creation fails
    public func createServer(request: CreateServerRequest) async throws -> Server {
        // Build the request body - serverGroup must go in os:scheduler_hints, not in server
        var requestBody: [String: Any] = [:]

        // Encode the server request (without serverGroup)
        let serverData = try SharedResources.jsonEncoder.encode(request)
        guard var serverDict = try JSONSerialization.jsonObject(with: serverData) as? [String: Any] else {
            throw OpenStackError.configurationError("Failed to encode server request as dictionary")
        }

        // Remove server_group from server object if present (it goes in scheduler_hints)
        serverDict.removeValue(forKey: "server_group")
        requestBody["server"] = serverDict

        // Add scheduler hints if server group is specified
        if let serverGroup = request.serverGroup {
            requestBody["os:scheduler_hints"] = ["group": serverGroup]
        }

        let requestData = try JSONSerialization.data(withJSONObject: requestBody)
        let response: ServerDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/servers",
            body: requestData,
            expected: 202
        )

        let server = response.server

        // Cache the new server
        await cacheManager.store(
            server,
            forKey: "nova_server_\(server.id)",
            resourceType: .server
        )

        // Intelligent invalidation for server creation
        await invalidationManager.invalidateForOperation(
            .create,
            resourceType: .server,
            resourceId: server.id
        )

        logger.logInfo("Nova service - server created with cache update", context: [
            "serverId": server.id,
            "serverName": server.name
        ])

        return server
    }

    /// Delete a server with intelligent cache invalidation
    public func deleteServer(id: String) async throws {
        do {
            try await core.requestVoid(
                service: serviceName,
                method: "DELETE",
                path: "/servers/\(id)",
                expected: 204
            )
        } catch let error as OpenStackError {
            // Invalidate cache even on 404 - server doesn't exist (idempotent delete)
            if case .httpError(404, _) = error {
                await invalidationManager.invalidateForOperation(
                    .delete,
                    resourceType: .server,
                    resourceId: id
                )
                logger.logInfo("Nova service - server already deleted, cache invalidated", context: [
                    "serverId": id
                ])
                return // Treat 404 as success
            }
            throw error
        }

        // Intelligent invalidation for successful deletion
        await invalidationManager.invalidateForOperation(
            .delete,
            resourceType: .server,
            resourceId: id
        )

        logger.logInfo("Nova service - server deleted with cache invalidation", context: [
            "serverId": id
        ])
    }

    /// Start a server with delayed cache invalidation
    public func startServer(id: String) async throws {
        let action = ServerStartAction()
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(id)/action",
            body: requestData,
            expected: 202
        )

        await invalidationManager.scheduleInvalidation(
            for: .server,
            resourceId: id,
            delay: 3.0
        )

        logger.logInfo("Nova service - server start initiated", context: [
            "serverId": id
        ])
    }

    /// Stop a server with delayed cache invalidation
    public func stopServer(id: String) async throws {
        let action = ServerStopAction()
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(id)/action",
            body: requestData,
            expected: 202
        )

        await invalidationManager.scheduleInvalidation(
            for: .server,
            resourceId: id,
            delay: 3.0
        )

        logger.logInfo("Nova service - server stop initiated", context: [
            "serverId": id
        ])
    }

    /// Reboot a server with delayed cache invalidation
    public func rebootServer(id: String, type: RebootType = .soft) async throws {
        let action = ["reboot": ["type": type.rawValue]]
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(id)/action",
            body: requestData,
            expected: 202
        )

        await invalidationManager.scheduleInvalidation(
            for: .server,
            resourceId: id,
            delay: type == .hard ? 15.0 : 8.0
        )

        logger.logInfo("Nova service - server reboot initiated", context: [
            "serverId": id,
            "rebootType": type == .hard ? "hard" : "soft"
        ])
    }

    /// Resize a server
    public func resizeServer(id: String, flavorRef: String) async throws {
        let action = ["resize": ["flavorRef": flavorRef]]
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(id)/action",
            body: requestData,
            expected: 202
        )
    }

    /// Confirm resize operation
    public func confirmResize(id: String) async throws {
        let action = ServerConfirmResizeAction()
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(id)/action",
            body: requestData,
            expected: 204
        )
    }

    /// Revert resize operation
    public func revertResize(id: String) async throws {
        let action = ServerRevertResizeAction()
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(id)/action",
            body: requestData,
            expected: 202
        )
    }

    /// Get server console output
    public func getConsoleOutput(id: String, length: Int? = nil) async throws -> String {
        let action = ServerGetConsoleOutputAction(length: length)

        let requestData = try SharedResources.jsonEncoder.encode(action)
        let response: ConsoleOutputResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/servers/\(id)/action",
            body: requestData,
            expected: 200
        )
        return response.output
    }

    /// Get remote console URL for server
    public func getRemoteConsole(id: String, protocol: String = "vnc", type: String = "novnc") async throws -> RemoteConsole {
        let request = RemoteConsoleRequest(protocol: `protocol`, type: type)

        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: RemoteConsoleResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/servers/\(id)/remote-consoles",
            body: requestData,
            headers: ["OpenStack-API-Version": "compute 2.6"],
            expected: 200
        )
        return response.remoteConsole
    }

    // MARK: - Flavor Operations

    /// List available flavors with extended caching
    public func listFlavors(includePublic: Bool = true, options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> [Flavor] {
        let cacheKey = "nova_flavor_list"

        // Try extended caching first (flavors rarely change)
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [Flavor].self,
                resourceType: .flavorList
            ) {
                logger.logInfo("Nova service cache hit - flavor list", context: [
                    "flavorCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Nova service API call - listing flavors", context: [
            "forceRefresh": forceRefresh
        ])

        var queryItems = options.queryItems
        if !includePublic {
            queryItems.append(URLQueryItem(name: "is_public", value: "false"))
        }

        var path = "/flavors/detail"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: FlavorListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        let flavors = response.flavors

        // Cache with extended TTL for flavors (they change rarely)
        await cacheManager.store(
            flavors,
            forKey: cacheKey,
            resourceType: .flavorList,
            customTTL: 1800.0 // 30 minutes for flavors
        )

        // Cache individual flavors
        for flavor in flavors {
            await cacheManager.store(
                flavor,
                forKey: "nova_flavor_\(flavor.id)",
                resourceType: .flavor,
                customTTL: 1800.0
            )
        }

        return flavors
    }

    /// Get flavor details with extended caching
    public func getFlavor(id: String, forceRefresh: Bool = false) async throws -> Flavor {
        let cacheKey = "nova_flavor_\(id)"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: Flavor.self,
                resourceType: .flavor
            ) {
                logger.logInfo("Nova service cache hit - flavor detail", context: [
                    "flavorId": id
                ])
                return cached
            }
        }

        logger.logInfo("Nova service API call - getting flavor", context: [
            "flavorId": id
        ])

        let response: FlavorDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/flavors/\(id)",
            expected: 200
        )

        let flavor = response.flavor

        await cacheManager.store(
            flavor,
            forKey: cacheKey,
            resourceType: .flavor,
            customTTL: 1800.0 // 30 minutes
        )

        return flavor
    }

    // MARK: - Key Pair Operations

    /// List key pairs with caching
    public func listKeyPairs(forceRefresh: Bool = false) async throws -> [KeyPair] {
        let cacheKey = "nova_keypair_list"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [KeyPair].self,
                resourceType: .keypairList
            ) {
                logger.logInfo("Nova service cache hit - keypair list", context: [
                    "keypairCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Nova service API call - listing keypairs", context: [:])

        let response: KeyPairListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/os-keypairs",
            expected: 200
        )

        let keypairs = response.keypairs.map { $0.keypair }

        await cacheManager.store(
            keypairs,
            forKey: cacheKey,
            resourceType: .keypairList,
            customTTL: 900.0 // 15 minutes for keypairs
        )

        return keypairs
    }

    /// Create a key pair with cache invalidation
    public func createKeyPair(name: String, publicKey: String? = nil) async throws -> KeyPair {
        // Build request data manually to properly handle nil publicKey
        let requestData: Data
        if let publicKey = publicKey, !publicKey.isEmpty {
            // Importing a key - include public_key field
            let request = CreateKeyPairRequest(name: name, publicKey: publicKey)
            requestData = try SharedResources.jsonEncoder.encode(CreateKeyPairWrapper(keypair: request))
        } else {
            // Generating a key - omit public_key field entirely by building JSON manually
            let keypairDict: [String: Any] = ["name": name]
            let wrapper: [String: Any] = ["keypair": keypairDict]
            requestData = try JSONSerialization.data(withJSONObject: wrapper)
        }
        let response: KeyPairDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/os-keypairs",
            body: requestData,
            expected: 201
        )

        let keypair = response.keypair

        // Invalidate the keypair list
        await invalidationManager.invalidateForOperation(
            .create,
            resourceType: .keypair,
            resourceId: keypair.name
        )

        logger.logInfo("Nova service - keypair created", context: [
            "keypairName": keypair.name
        ])

        return keypair
    }

    /// Delete a key pair with cache invalidation
    public func deleteKeyPair(name: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/os-keypairs/\(name)",
            expected: 202
        )

        await invalidationManager.invalidateForOperation(
            .delete,
            resourceType: .keypair,
            resourceId: name
        )

        logger.logInfo("Nova service - keypair deleted", context: [
            "keypairName": name
        ])
    }

    // MARK: - Server Group Operations

    /// List server groups with caching
    public func listServerGroups(forceRefresh: Bool = false) async throws -> [ServerGroup] {
        let cacheKey = "nova_server_group_list"

        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [ServerGroup].self,
                resourceType: .serverGroupList
            ) {
                logger.logInfo("Nova service cache hit - server group list", context: [
                    "groupCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Nova service API call - listing server groups", context: [:])

        let response: ServerGroupListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/os-server-groups",
            expected: 200
        )

        let serverGroups = response.serverGroups

        await cacheManager.store(
            serverGroups,
            forKey: cacheKey,
            resourceType: .serverGroupList,
            customTTL: 600.0 // 10 minutes for server groups
        )

        return serverGroups
    }

    /// Create a server group
    public func createServerGroup(name: String, policy: String) async throws -> ServerGroup {
        let request = CreateServerGroupRequest(name: name, policy: policy)
        let requestData = try SharedResources.jsonEncoder.encode(["server_group": request])
        let response: ServerGroupDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/os-server-groups",
            body: requestData,
            expected: 200
        )
        return response.serverGroup
    }

    /// Delete a server group
    public func deleteServerGroup(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/os-server-groups/\(id)",
            expected: 204
        )
    }

    // MARK: - Quota Operations

    /// Get compute quotas for project
    public func getQuotas(projectId: String) async throws -> QuotaSet {
        let response: QuotaResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/os-quota-sets/\(projectId)",
            expected: 200
        )
        return response.quotaSet
    }

    // MARK: - Server Security Group Operations

    /// Add security group to server
    public func addSecurityGroupToServer(serverId: String, securityGroupName: String) async throws {
        let action = AddSecurityGroupAction(name: securityGroupName)
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(serverId)/action",
            body: requestData,
            expected: 202
        )
    }

    /// Remove security group from server
    public func removeSecurityGroupFromServer(serverId: String, securityGroupName: String) async throws {
        let action = RemoveSecurityGroupAction(name: securityGroupName)
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(serverId)/action",
            body: requestData,
            expected: 202
        )
    }

    /// Get server security groups
    public func getServerSecurityGroups(serverId: String) async throws -> [SecurityGroup] {
        let response: ServerSecurityGroupsResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/servers/\(serverId)/os-security-groups",
            expected: 200
        )
        return response.securityGroups
    }

    // MARK: - Server Network Interface Operations

    /// Attach port to server
    public func attachPortToServer(serverId: String, portId: String) async throws -> InterfaceAttachment {
        let request = AttachInterfaceRequest(portId: portId)
        let requestData = try SharedResources.jsonEncoder.encode(["interfaceAttachment": request])
        let response: InterfaceAttachmentResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/servers/\(serverId)/os-interface",
            body: requestData,
            expected: 200
        )
        return response.interfaceAttachment
    }

    /// Detach port from server
    public func detachPortFromServer(serverId: String, portId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/servers/\(serverId)/os-interface/\(portId)",
            expected: 202
        )
    }

    /// Attach network to server (creates new port)
    public func attachNetworkToServer(serverId: String, networkId: String, fixedIps: [InterfaceFixedIP]? = nil) async throws -> InterfaceAttachment {
        let request = AttachInterfaceRequest(netId: networkId, fixedIps: fixedIps)
        let requestData = try SharedResources.jsonEncoder.encode(["interfaceAttachment": request])
        let response: InterfaceAttachmentResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/servers/\(serverId)/os-interface",
            body: requestData,
            expected: 200
        )
        return response.interfaceAttachment
    }

    /// List server network interfaces
    public func listServerInterfaces(serverId: String) async throws -> [InterfaceAttachment] {
        let response: InterfaceAttachmentsResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/servers/\(serverId)/os-interface",
            expected: 200
        )
        return response.interfaceAttachments
    }

    // MARK: - Volume Attachment Operations

    /// Attach volume to server
    public func attachVolume(serverId: String, volumeId: String, device: String? = nil) async throws {
        var attachRequest: [String: Any] = [
            "volumeId": volumeId
        ]
        if let device = device {
            attachRequest["device"] = device
        }

        let requestData = try JSONSerialization.data(withJSONObject: ["volumeAttachment": attachRequest])
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/servers/\(serverId)/os-volume_attachments",
            body: requestData,
            expected: 200
        )
    }

    /// Detach volume from server
    public func detachVolume(serverId: String, volumeId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/servers/\(serverId)/os-volume_attachments/\(volumeId)",
            expected: 202
        )
    }

    // MARK: - Server Image Operations

    /// Create server snapshot/image
    public func createServerSnapshot(serverId: String, name: String, metadata: [String: String]? = nil) async throws -> String {
        let action = CreateNovaImageAction(name: name, metadata: metadata)
        let requestData = try SharedResources.jsonEncoder.encode(action)

        let _ = try await core.requestRaw(
            service: serviceName,
            method: "POST",
            path: "/servers/\(serverId)/action",
            body: requestData,
            headers: ["Content-Type": "application/json"],
            expected: 202
        )

        // For snapshot creation, the image ID is typically returned in the response or via polling
        // For now, we'll return a success indicator and let the caller poll for the image
        return "snapshot_creation_initiated"
    }

    // MARK: - Availability Zone Operations

    /// List availability zones
    public func listAvailabilityZones() async throws -> [AvailabilityZone] {
        let response: AvailabilityZoneListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/os-availability-zone",
            expected: 200
        )
        return response.availabilityZoneInfo
    }

    // MARK: - Cache Management

    /// Clear all Nova service caches
    public func clearCache() async {
        await cacheManager.clearResourceType(.server)
        await cacheManager.clearResourceType(.serverList)
        await cacheManager.clearResourceType(.flavor)
        await cacheManager.clearResourceType(.flavorList)
        await cacheManager.clearResourceType(.serverGroup)
        await cacheManager.clearResourceType(.serverGroupList)
        await cacheManager.clearResourceType(.keypair)
        await cacheManager.clearResourceType(.keypairList)

        logger.logInfo("Nova service - cleared all caches", context: [:])
    }

    /// Get cache statistics
    public func getCacheStats() async -> AdvancedCacheStats {
        return await cacheManager.getAdvancedStats()
    }

    // MARK: - Batch Operations with Smart Caching

    /// Batch load multiple servers with intelligent caching
    public func batchLoadServers(ids: [String], forceRefresh: Bool = false) async throws -> [Server] {
        var servers: [Server] = []
        var uncachedIds: [String] = []

        // First pass: get from cache
        if !forceRefresh {
            for id in ids {
                if let cached = await cacheManager.retrieve(
                    forKey: "nova_server_\(id)",
                    as: Server.self,
                    resourceType: .server
                ) {
                    servers.append(cached)
                } else {
                    uncachedIds.append(id)
                }
            }
        } else {
            uncachedIds = ids
        }

        // Second pass: fetch uncached servers
        if !uncachedIds.isEmpty {
            logger.logInfo("Nova service batch API calls", context: [
                "requestedCount": ids.count,
                "cachedCount": servers.count,
                "uncachedCount": uncachedIds.count
            ])

            for id in uncachedIds {
                do {
                    let server = try await getServer(id: id, forceRefresh: true)
                    servers.append(server)
                } catch {
                    logger.logError("Failed to fetch server in batch operation", context: [
                        "serverId": id,
                        "error": error.localizedDescription
                    ])
                    // Continue with other servers
                }
            }
        }

        return servers
    }

    /// Prefetch commonly accessed resources
    public func prefetchCommonResources() async {
        logger.logInfo("Nova service - prefetching common resources", context: [:])

        // Prefetch flavors (most commonly accessed and stable)
        Task {
            do {
                _ = try await listFlavors()
                logger.logInfo("Nova service - flavors prefetched", context: [:])
            } catch {
                logger.logError("Failed to prefetch flavors", context: [
                    "error": error.localizedDescription
                ])
            }
        }

        // Prefetch keypairs
        Task {
            do {
                _ = try await listKeyPairs()
                logger.logInfo("Nova service - keypairs prefetched", context: [:])
            } catch {
                logger.logError("Failed to prefetch keypairs", context: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
}

// MARK: - Enums

public enum RebootType: String, Codable, CaseIterable, Sendable {
    case soft = "SOFT"
    case hard = "HARD"
}

// MARK: - Request Models

public struct CreateServerRequest: Codable, Sendable {
    public let name: String
    public let imageRef: String?
    public let flavorRef: String
    public let metadata: [String: String]?
    public let personality: [PersonalityFile]?
    public let securityGroups: [SecurityGroupRef]?
    public let userData: String?
    public let availabilityZone: String?
    public let networks: [NetworkRequest]?
    public let keyName: String?
    public let adminPass: String?
    public let minCount: Int?
    public let maxCount: Int?
    public let returnReservationId: Bool?
    public let serverGroup: String?
    public let blockDeviceMapping: [BlockDeviceMapping]?

    enum CodingKeys: String, CodingKey {
        case name
        case imageRef = "imageRef"
        case flavorRef
        case metadata
        case personality
        case securityGroups = "security_groups"
        case userData = "user_data"
        case availabilityZone = "availability_zone"
        case networks
        case keyName = "key_name"
        case adminPass = "adminPass"
        case minCount = "min_count"
        case maxCount = "max_count"
        case returnReservationId = "return_reservation_id"
        case serverGroup = "server_group"
        case blockDeviceMapping = "block_device_mapping_v2"
    }

    public init(
        name: String,
        imageRef: String? = nil,
        flavorRef: String,
        metadata: [String: String]? = nil,
        personality: [PersonalityFile]? = nil,
        securityGroups: [SecurityGroupRef]? = nil,
        userData: String? = nil,
        availabilityZone: String? = nil,
        networks: [NetworkRequest]? = nil,
        keyName: String? = nil,
        adminPass: String? = nil,
        minCount: Int? = nil,
        maxCount: Int? = nil,
        returnReservationId: Bool? = nil,
        serverGroup: String? = nil,
        blockDeviceMapping: [BlockDeviceMapping]? = nil
    ) {
        self.name = name
        self.imageRef = imageRef
        self.flavorRef = flavorRef
        self.metadata = metadata
        self.personality = personality
        self.securityGroups = securityGroups
        self.userData = userData
        self.availabilityZone = availabilityZone
        self.networks = networks
        self.keyName = keyName
        self.adminPass = adminPass
        self.minCount = minCount
        self.maxCount = maxCount
        self.returnReservationId = returnReservationId
        self.serverGroup = serverGroup
        self.blockDeviceMapping = blockDeviceMapping
    }
}

public struct BlockDeviceMapping: Codable, Sendable {
    public let sourceType: String
    public let destinationType: String
    public let bootIndex: Int
    public let uuid: String
    public let volumeSize: Int?
    public let deleteOnTermination: Bool?

    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case destinationType = "destination_type"
        case bootIndex = "boot_index"
        case uuid
        case volumeSize = "volume_size"
        case deleteOnTermination = "delete_on_termination"
    }

    public init(
        sourceType: String,
        destinationType: String,
        bootIndex: Int,
        uuid: String,
        volumeSize: Int? = nil,
        deleteOnTermination: Bool? = nil
    ) {
        self.sourceType = sourceType
        self.destinationType = destinationType
        self.bootIndex = bootIndex
        self.uuid = uuid
        self.volumeSize = volumeSize
        self.deleteOnTermination = deleteOnTermination
    }
}

public struct PersonalityFile: Codable, Sendable {
    public let path: String
    public let contents: String

    public init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }
}

public struct NetworkRequest: Codable, Sendable {
    public let uuid: String?
    public let port: String?
    public let fixedIp: String?

    enum CodingKeys: String, CodingKey {
        case uuid
        case port
        case fixedIp = "fixed_ip"
    }

    public init(uuid: String? = nil, port: String? = nil, fixedIp: String? = nil) {
        self.uuid = uuid
        self.port = port
        self.fixedIp = fixedIp
    }
}

public struct CreateServerGroupRequest: Codable, Sendable {
    public let name: String
    public let policy: String

    public init(name: String, policy: String) {
        self.name = name
        self.policy = policy
    }
}

// MARK: - Response Models

public struct ServerListResponse: Codable, Sendable {
    public let servers: [Server]
}

public struct ServerDetailResponse: Codable, Sendable {
    public let server: Server
}

public struct FlavorListResponse: Codable, Sendable {
    public let flavors: [Flavor]
}

public struct FlavorDetailResponse: Codable, Sendable {
    public let flavor: Flavor
}


public struct KeyPairListResponse: Codable, Sendable {
    public let keypairs: [KeyPairWrapper]
}

public struct KeyPairWrapper: Codable, Sendable {
    public let keypair: KeyPair
}

public struct KeyPairDetailResponse: Codable, Sendable {
    public let keypair: KeyPair
}

public struct ServerGroupListResponse: Codable, Sendable {
    public let serverGroups: [ServerGroup]

    enum CodingKeys: String, CodingKey {
        case serverGroups = "server_groups"
    }
}

public struct ServerGroupDetailResponse: Codable, Sendable {
    public let serverGroup: ServerGroup

    enum CodingKeys: String, CodingKey {
        case serverGroup = "server_group"
    }
}

public struct QuotaResponse: Codable, Sendable {
    public let quotaSet: QuotaSet

    enum CodingKeys: String, CodingKey {
        case quotaSet = "quota_set"
    }
}

public struct ConsoleOutputResponse: Codable, Sendable {
    public let output: String
}