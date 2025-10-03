import Foundation

/// Intelligent cache invalidation system that understands OpenStack resource relationships
/// and provides sophisticated invalidation strategies based on resource interdependencies
public actor IntelligentCacheInvalidation {
    private let cacheManager: OpenStackCacheManager
    private let logger: any OpenStackClientLogger

    // Resource dependency graph - defines which resources affect others
    private let resourceDependencies: [OpenStackCacheManager.ResourceType: Set<OpenStackCacheManager.ResourceType>] = [
        .server: [.serverList, .port, .portList, .floatingIP, .floatingIPList],
        .serverList: [.server],
        .network: [.networkList, .subnet, .subnetList, .port, .portList, .router, .routerList],
        .networkList: [.network, .subnet, .port, .router],
        .subnet: [.subnetList, .port, .portList, .network, .networkList],
        .subnetList: [.subnet, .port, .network],
        .port: [.portList, .server, .serverList, .floatingIP, .floatingIPList, .network, .networkList],
        .portList: [.port, .server, .floatingIP],
        .router: [.routerList, .subnet, .subnetList, .floatingIP, .floatingIPList],
        .routerList: [.router, .subnet, .floatingIP],
        .floatingIP: [.floatingIPList, .server, .serverList, .port, .portList],
        .floatingIPList: [.floatingIP, .server, .port],
        .securityGroup: [.securityGroupList, .server, .serverList, .port, .portList],
        .securityGroupList: [.securityGroup, .server, .port],
        .volume: [.volumeList, .server, .serverList],
        .volumeList: [.volume, .server],
        .volumeSnapshot: [.volumeSnapshotList, .volume, .volumeList],
        .volumeSnapshotList: [.volumeSnapshot, .volume],
        .serverGroup: [.serverGroupList, .server, .serverList],
        .serverGroupList: [.serverGroup, .server]
    ]

    // Time-based invalidation rules - some resources should be invalidated after certain operations
    private let timeBasedInvalidation: [OpenStackCacheManager.ResourceType: TimeInterval] = [
        .authentication: 0, // Immediate invalidation for auth
        .server: 5.0, // Server state changes need quick propagation
        .floatingIP: 3.0, // Floating IP associations change quickly
        .port: 5.0, // Port states affect connectivity
        .volume: 10.0 // Volume operations take time to reflect
    ]

    public init(cacheManager: OpenStackCacheManager, logger: any OpenStackClientLogger) {
        self.cacheManager = cacheManager
        self.logger = logger
    }

    // MARK: - Operation-Based Invalidation

    /// Invalidate cache entries based on the operation being performed
    public func invalidateForOperation(
        _ operation: CacheInvalidationOperation,
        resourceType: OpenStackCacheManager.ResourceType,
        resourceId: String? = nil
    ) async {
        logger.logInfo("Processing cache invalidation", context: [
            "operation": operation.rawValue,
            "resourceType": resourceType.rawValue,
            "resourceId": resourceId ?? "all"
        ])

        switch operation {
        case .create:
            await invalidateForCreate(resourceType: resourceType, resourceId: resourceId)
        case .update:
            await invalidateForUpdate(resourceType: resourceType, resourceId: resourceId)
        case .delete:
            await invalidateForDelete(resourceType: resourceType, resourceId: resourceId)
        case .list:
            await invalidateForList(resourceType: resourceType)
        case .associateFloatingIP:
            await invalidateForFloatingIPOperation(resourceId: resourceId)
        case .disassociateFloatingIP:
            await invalidateForFloatingIPOperation(resourceId: resourceId)
        case .attachVolume:
            await invalidateForVolumeAttachment(resourceId: resourceId)
        case .detachVolume:
            await invalidateForVolumeAttachment(resourceId: resourceId)
        case .addSecurityGroup:
            await invalidateForSecurityGroupOperation(resourceId: resourceId)
        case .removeSecurityGroup:
            await invalidateForSecurityGroupOperation(resourceId: resourceId)
        case .serverStateChange:
            await invalidateForServerStateChange(resourceId: resourceId)
        }
    }

    // MARK: - Smart Batch Invalidation

    /// Perform batch invalidation for multiple related operations
    public func batchInvalidate(_ operations: [(CacheInvalidationOperation, OpenStackCacheManager.ResourceType, String?)]) async {
        var allInvalidatedKeys: Set<String> = []

        for (operation, resourceType, resourceId) in operations {
            let keysToInvalidate = await getKeysToInvalidate(
                for: operation,
                resourceType: resourceType,
                resourceId: resourceId
            )
            allInvalidatedKeys.formUnion(keysToInvalidate)
        }

        // Remove duplicates and perform single invalidation
        for key in allInvalidatedKeys {
            await cacheManager.removeEntry(forKey: key)
        }

        logger.logInfo("Batch cache invalidation completed", context: [
            "operationsCount": operations.count,
            "keysInvalidated": allInvalidatedKeys.count,
            "keys": Array(allInvalidatedKeys)
        ])
    }

    // MARK: - Time-Based Invalidation

    /// Schedule time-based invalidation for resources that need delayed cache clearing
    public func scheduleInvalidation(
        for resourceType: OpenStackCacheManager.ResourceType,
        resourceId: String? = nil,
        delay: TimeInterval? = nil
    ) {
        let invalidationDelay = delay ?? timeBasedInvalidation[resourceType] ?? 0

        if invalidationDelay > 0 {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(invalidationDelay * 1_000_000_000))
                await invalidateForOperation(.update, resourceType: resourceType, resourceId: resourceId)
            }

            logger.logInfo("Scheduled delayed cache invalidation", context: [
                "resourceType": resourceType.rawValue,
                "resourceId": resourceId ?? "all",
                "delay": invalidationDelay
            ])
        }
    }

    // MARK: - Conditional Invalidation

    /// Invalidate cache only if certain conditions are met
    public func conditionalInvalidate(
        resourceType: OpenStackCacheManager.ResourceType,
        resourceId: String? = nil,
        condition: @escaping () -> Bool
    ) async {
        guard condition() else {
            logger.logInfo("Conditional invalidation skipped", context: [
                "resourceType": resourceType.rawValue,
                "resourceId": resourceId ?? "all"
            ])
            return
        }

        await invalidateForOperation(.update, resourceType: resourceType, resourceId: resourceId)
    }

    // MARK: - Private Implementation

    private func invalidateForCreate(resourceType: OpenStackCacheManager.ResourceType, resourceId: String?) async {
        // Creating a resource always invalidates the list and related resources
        await invalidateResourceAndDependencies(resourceType)

        // For specific creation scenarios
        switch resourceType {
        case .server:
            // New server might affect available resources
            await cacheManager.clearResourceType(.flavor)
            await cacheManager.clearResourceType(.image)
        case .floatingIP:
            // New floating IP affects availability
            await cacheManager.clearResourceType(.network)
            await cacheManager.clearResourceType(.port)
        default:
            break
        }
    }

    private func invalidateForUpdate(resourceType: OpenStackCacheManager.ResourceType, resourceId: String?) async {
        // Updates affect the specific resource and its list
        if let resourceId = resourceId {
            let cacheKey = "\(resourceType.rawValue)_\(resourceId)"
            await cacheManager.removeEntry(forKey: cacheKey)
        }

        // Always invalidate the list
        let listKey = "\(resourceType.rawValue)_list"
        await cacheManager.removeEntry(forKey: listKey)

        // Invalidate dependent resources
        await invalidateResourceAndDependencies(resourceType)
    }

    private func invalidateForDelete(resourceType: OpenStackCacheManager.ResourceType, resourceId: String?) async {
        // Delete operations are the most impactful
        if let resourceId = resourceId {
            let cacheKey = "\(resourceType.rawValue)_\(resourceId)"
            await cacheManager.removeEntry(forKey: cacheKey)
        }

        // Clear the list
        await cacheManager.clearResourceType(resourceType)

        // Clear all dependent resources
        await invalidateResourceAndDependencies(resourceType)

        // For critical deletions, clear related lists entirely
        switch resourceType {
        case .server:
            await cacheManager.clearResourceType(.port)
            await cacheManager.clearResourceType(.floatingIP)
        case .network:
            await cacheManager.clearResourceType(.subnet)
            await cacheManager.clearResourceType(.port)
            await cacheManager.clearResourceType(.router)
        case .volume:
            await cacheManager.clearResourceType(.server) // Servers might reference this volume
        default:
            break
        }
    }

    private func invalidateForList(resourceType: OpenStackCacheManager.ResourceType) async {
        // List operations only invalidate the list cache
        await cacheManager.clearResourceType(resourceType)
    }

    private func invalidateForFloatingIPOperation(resourceId: String?) async {
        // Floating IP operations affect multiple resources
        await cacheManager.clearResourceType(.floatingIP)
        await cacheManager.clearResourceType(.server)
        await cacheManager.clearResourceType(.port)
    }

    private func invalidateForVolumeAttachment(resourceId: String?) async {
        // Volume attachment affects servers and volumes
        await cacheManager.clearResourceType(.volume)
        await cacheManager.clearResourceType(.server)
    }

    private func invalidateForSecurityGroupOperation(resourceId: String?) async {
        // Security group changes affect servers and ports
        await cacheManager.clearResourceType(.securityGroup)
        await cacheManager.clearResourceType(.server)
        await cacheManager.clearResourceType(.port)
    }

    private func invalidateForServerStateChange(resourceId: String?) async {
        // Server state changes should immediately invalidate server cache
        if let resourceId = resourceId {
            let cacheKey = "server_\(resourceId)"
            await cacheManager.removeEntry(forKey: cacheKey)
        }
        await cacheManager.clearResourceType(.serverList)
    }

    private func invalidateResourceAndDependencies(_ resourceType: OpenStackCacheManager.ResourceType) async {
        // Get all dependent resource types
        let dependencies = resourceDependencies[resourceType] ?? []

        // Clear the main resource
        await cacheManager.clearResourceType(resourceType)

        // Clear all dependent resources
        for dependency in dependencies {
            await cacheManager.clearResourceType(dependency)
        }
    }

    private func getKeysToInvalidate(
        for operation: CacheInvalidationOperation,
        resourceType: OpenStackCacheManager.ResourceType,
        resourceId: String?
    ) async -> Set<String> {
        var keys: Set<String> = []

        // Add the specific resource key if we have an ID
        if let resourceId = resourceId {
            keys.insert("\(resourceType.rawValue)_\(resourceId)")
        }

        // Add the list key
        keys.insert("\(resourceType.rawValue)_list")

        // Add dependent resource keys
        let dependencies = resourceDependencies[resourceType] ?? []
        for dependency in dependencies {
            keys.insert("\(dependency.rawValue)_list")
        }

        return keys
    }
}

// MARK: - Cache Invalidation Operation Types

public enum CacheInvalidationOperation: String, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case list = "list"
    case associateFloatingIP = "associate_floating_ip"
    case disassociateFloatingIP = "disassociate_floating_ip"
    case attachVolume = "attach_volume"
    case detachVolume = "detach_volume"
    case addSecurityGroup = "add_security_group"
    case removeSecurityGroup = "remove_security_group"
    case serverStateChange = "server_state_change"

    /// Get the impact level of this operation on cache
    public var impactLevel: CacheInvalidationImpact {
        switch self {
        case .list:
            return .low
        case .update, .associateFloatingIP, .disassociateFloatingIP, .addSecurityGroup, .removeSecurityGroup:
            return .medium
        case .create, .delete, .attachVolume, .detachVolume, .serverStateChange:
            return .high
        }
    }
}

public enum CacheInvalidationImpact {
    case low    // Affects only the specific resource
    case medium // Affects the resource and immediate dependencies
    case high   // Affects the resource and all related resources
}