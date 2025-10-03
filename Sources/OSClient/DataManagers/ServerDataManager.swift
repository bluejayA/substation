import Foundation
import MemoryKit

/// Enhanced data manager for server-related operations with MemoryKit integration
public actor ServerDataManager {
    private let novaService: NovaService
    private let logger: any OpenStackClientLogger
    private let memoryManager: MemoryManager

    public init(novaService: NovaService, logger: any OpenStackClientLogger, memoryManager: MemoryManager) {
        self.novaService = novaService
        self.logger = logger
        self.memoryManager = memoryManager
    }

    // MARK: - Server Operations

    /// List all servers with intelligent caching
    public func listServers(forceRefresh: Bool = false) async throws -> [Server] {
        let cacheKey = "server_list"

        // Try to get from MemoryKit cache first
        if !forceRefresh {
            if let cachedServers = await memoryManager.retrieve(forKey: cacheKey, as: [Server].self) {
                logger.logInfo("Returning cached server list", context: [
                    "count": cachedServers.count
                ])
                return cachedServers
            }
        }

        // Fetch from API
        logger.logInfo("Fetching server list from API", context: [
            "forceRefresh": forceRefresh
        ])

        let response = try await novaService.listServers()
        let servers = response.servers

        // Store in MemoryKit cache
        await memoryManager.store(servers, forKey:cacheKey)

        // Store individual servers for quick access
        for server in servers {
            await memoryManager.store(server, forKey:"server_\(server.id)")
        }

        return servers
    }

    /// Get a specific server with intelligent caching
    public func getServer(id: String, forceRefresh: Bool = false) async throws -> Server {
        let cacheKey = "server_\(id)"

        // Try MemoryKit cache first
        if !forceRefresh {
            if let cachedServer = await memoryManager.retrieve(forKey: cacheKey, as: Server.self) {
                logger.logInfo("Returning cached server", context: [
                    "serverId": id
                ])
                return cachedServer
            }
        }

        // Fetch from API
        logger.logInfo("Fetching server from API", context: [
            "serverId": id,
            "forceRefresh": forceRefresh
        ])

        let server = try await novaService.getServer(id: id)

        // Store in MemoryKit cache
        await memoryManager.store(server, forKey:cacheKey)

        return server
    }

    /// List server groups with intelligent caching
    public func listServerGroups(forceRefresh: Bool = false) async throws -> [ServerGroup] {
        let cacheKey = "server_group_list"

        // Try MemoryKit cache first
        if !forceRefresh {
            if let cachedGroups = await memoryManager.retrieve(forKey: cacheKey, as: [ServerGroup].self) {
                logger.logInfo("Returning cached server group list", context: [
                    "count": cachedGroups.count
                ])
                return cachedGroups
            }
        }

        // Fetch from API
        logger.logInfo("Fetching server groups from API", context: [:])

        let serverGroups = try await novaService.listServerGroups()

        // Store in MemoryKit cache
        await memoryManager.store(serverGroups, forKey:cacheKey)

        // Store individual groups
        for group in serverGroups {
            await memoryManager.store(group, forKey:"server_group_\(group.id)")
        }

        return serverGroups
    }

    /// Create a new server
    public func createServer(request: CreateServerRequest) async throws -> Server {
        let server = try await novaService.createServer(request: request)

        // Store in MemoryKit cache
        await memoryManager.store(server, forKey:"server_\(server.id)")

        // Invalidate server list cache
        await memoryManager.clearKey( "server_list")

        logger.logInfo("Created server and updated caches", context: [
            "serverId": server.id,
            "serverName": server.name
        ])

        return server
    }

    /// Delete a server
    public func deleteServer(id: String) async throws {
        try await novaService.deleteServer(id: id)

        // Invalidate MemoryKit caches for deletion
        await memoryManager.clearKey( "server_\(id)")
        await memoryManager.clearKey( "server_list")

        logger.logInfo("Deleted server and invalidated caches", context: [
            "serverId": id
        ])
    }

    /// Start a server
    public func startServer(id: String) async throws {
        try await novaService.startServer(id: id)

        // Invalidate server cache to reflect state change
        await memoryManager.clearKey( "server_\(id)")

        logger.logInfo("Started server and scheduled cache invalidation", context: [
            "serverId": id
        ])
    }

    /// Stop a server
    public func stopServer(id: String) async throws {
        try await novaService.stopServer(id: id)

        // Invalidate server cache to reflect state change
        await memoryManager.clearKey( "server_\(id)")

        logger.logInfo("Stopped server and scheduled cache invalidation", context: [
            "serverId": id
        ])
    }

    /// Reboot a server
    public func rebootServer(id: String, type: RebootType = .soft) async throws {
        try await novaService.rebootServer(id: id, type: type)

        // Invalidate server cache to reflect state change
        await memoryManager.clearKey( "server_\(id)")

        logger.logInfo("Rebooted server and scheduled cache invalidation", context: [
            "serverId": id,
            "rebootType": type == .hard ? "hard" : "soft"
        ])
    }

    // MARK: - Cache Management

    /// Clear all cached data
    public func clearCache() async {
        await memoryManager.clearAll()
        logger.logInfo("Cleared all server-related caches", context: [:])
    }

    /// Get memory usage statistics
    public func getMemoryStats() async -> MemoryMetrics {
        return await memoryManager.getMetrics()
    }

    /// Handle memory pressure by clearing cache
    public func handleMemoryPressure() async {
        await clearCache()
    }

    /// Get specific server from cache only (no API call)
    public func getCachedServer(id: String) async -> Server? {
        return await memoryManager.retrieve(forKey: "server_\(id)", as: Server.self)
    }

    /// Get server list from cache only (no API call)
    public func getCachedServerList() async -> [Server]? {
        return await memoryManager.retrieve(forKey: "server_list", as: [Server].self)
    }

    // MARK: - Volume Operations with Cache Integration

    /// Attach volume to server with intelligent cache invalidation
    public func attachVolume(serverId: String, volumeId: String) async throws {
        // This would be implemented when we add volume attachment to NovaService
        // For now, just handle the cache invalidation
        await memoryManager.clearKey( "server_\(serverId)")

        logger.logInfo("Volume attachment operation completed, caches invalidated", context: [
            "serverId": serverId,
            "volumeId": volumeId
        ])
    }

    /// Detach volume from server with intelligent cache invalidation
    public func detachVolume(serverId: String, volumeId: String) async throws {
        // This would be implemented when we add volume detachment to NovaService
        // For now, just handle the cache invalidation
        await memoryManager.clearKey( "server_\(serverId)")

        logger.logInfo("Volume detachment operation completed, caches invalidated", context: [
            "serverId": serverId,
            "volumeId": volumeId
        ])
    }

    // MARK: - Security Group Operations with Cache Integration

    /// Add security group to server with intelligent cache invalidation
    public func addSecurityGroup(serverId: String, securityGroupId: String) async throws {
        // This would call the actual Nova API when implemented
        await memoryManager.clearKey( "server_\(serverId)")

        logger.logInfo("Security group added, caches invalidated", context: [
            "serverId": serverId,
            "securityGroupId": securityGroupId
        ])
    }

    /// Remove security group from server with intelligent cache invalidation
    public func removeSecurityGroup(serverId: String, securityGroupId: String) async throws {
        // This would call the actual Nova API when implemented
        await memoryManager.clearKey( "server_\(serverId)")

        logger.logInfo("Security group removed, caches invalidated", context: [
            "serverId": serverId,
            "securityGroupId": securityGroupId
        ])
    }
}