import Foundation
import OSClient

// MARK: - Batch Operation Types

/// Core batch operation types supported by the system
public enum BatchOperationType: Sendable, Hashable {
    case serverBulkCreate(configs: [ServerCreateConfig])
    case serverBulkDelete(serverIDs: [String])
    case networkTopologyDeploy(topology: NetworkTopologyDeployment)
    case resourceCleanup(criteria: ResourceCleanupCriteria)
    case volumeBulkAttach(operations: [VolumeAttachmentOperation])
    case volumeBulkDetach(operations: [VolumeDetachmentOperation])
    case volumeBulkCreate(configs: [VolumeCreateConfig])
    case volumeBulkDelete(volumeIDs: [String])
    case floatingIPBulkCreate(configs: [FloatingIPCreateConfig])
    case floatingIPBulkAssign(assignments: [FloatingIPAssignment])
    case floatingIPBulkDelete(floatingIPIDs: [String])
    case securityGroupBulkCreate(configs: [SecurityGroupCreateConfig])
    case securityGroupBulkDelete(securityGroupIDs: [String])
    case networkInterfaceBulkAttach(operations: [NetworkInterfaceOperation])
    case networkBulkDelete(networkIDs: [String])
    case subnetBulkDelete(subnetIDs: [String])
    case routerBulkDelete(routerIDs: [String])
    case portBulkDelete(portIDs: [String])
    case serverGroupBulkDelete(serverGroupIDs: [String])
    case keyPairBulkDelete(keyPairNames: [String])
    case imageBulkDelete(imageIDs: [String])
    case swiftContainerBulkCreate(configs: [SwiftContainerCreateConfig])
    case swiftContainerBulkDelete(containerNames: [String])
    case swiftObjectBulkUpload(operations: [SwiftObjectUploadOperation])
    case swiftObjectBulkDownload(operations: [SwiftObjectDownloadOperation])
    case swiftObjectBulkDelete(containerName: String, objectNames: [String])

    public var description: String {
        switch self {
        case .serverBulkCreate(let configs):
            return "Bulk create \(configs.count) servers"
        case .serverBulkDelete(let serverIDs):
            return "Bulk delete \(serverIDs.count) servers"
        case .networkTopologyDeploy(let topology):
            return "Deploy network topology: \(topology.name)"
        case .resourceCleanup:
            return "Resource cleanup operation"
        case .volumeBulkAttach(let operations):
            return "Bulk attach \(operations.count) volumes"
        case .volumeBulkDetach(let operations):
            return "Bulk detach \(operations.count) volumes"
        case .volumeBulkCreate(let configs):
            return "Bulk create \(configs.count) volumes"
        case .volumeBulkDelete(let volumeIDs):
            return "Bulk delete \(volumeIDs.count) volumes"
        case .floatingIPBulkCreate(let configs):
            return "Bulk create \(configs.count) floating IPs"
        case .floatingIPBulkAssign(let assignments):
            return "Bulk assign \(assignments.count) floating IPs"
        case .floatingIPBulkDelete(let floatingIPIDs):
            return "Bulk delete \(floatingIPIDs.count) floating IPs"
        case .securityGroupBulkCreate(let configs):
            return "Bulk create \(configs.count) security groups"
        case .securityGroupBulkDelete(let securityGroupIDs):
            return "Bulk delete \(securityGroupIDs.count) security groups"
        case .networkInterfaceBulkAttach(let operations):
            return "Bulk attach \(operations.count) network interfaces"
        case .networkBulkDelete(let networkIDs):
            return "Bulk delete \(networkIDs.count) networks"
        case .subnetBulkDelete(let subnetIDs):
            return "Bulk delete \(subnetIDs.count) subnets"
        case .routerBulkDelete(let routerIDs):
            return "Bulk delete \(routerIDs.count) routers"
        case .portBulkDelete(let portIDs):
            return "Bulk delete \(portIDs.count) ports"
        case .serverGroupBulkDelete(let serverGroupIDs):
            return "Bulk delete \(serverGroupIDs.count) server groups"
        case .keyPairBulkDelete(let keyPairNames):
            return "Bulk delete \(keyPairNames.count) key pairs"
        case .imageBulkDelete(let imageIDs):
            return "Bulk delete \(imageIDs.count) images"
        case .swiftContainerBulkCreate(let configs):
            return "Bulk create \(configs.count) Swift containers"
        case .swiftContainerBulkDelete(let containerNames):
            return "Bulk delete \(containerNames.count) Swift containers"
        case .swiftObjectBulkUpload(let operations):
            return "Bulk upload \(operations.count) Swift objects"
        case .swiftObjectBulkDownload(let operations):
            return "Bulk download \(operations.count) Swift objects"
        case .swiftObjectBulkDelete(_, let objectNames):
            return "Bulk delete \(objectNames.count) Swift objects"
        }
    }

    public var estimatedTimeMinutes: Int {
        switch self {
        case .serverBulkCreate(let configs):
            return max(1, configs.count / 5) // ~5 servers per minute
        case .serverBulkDelete(let serverIDs):
            return max(1, serverIDs.count / 10) // ~10 deletions per minute
        case .networkTopologyDeploy:
            return 3 // Network topology typically takes 2-3 minutes
        case .resourceCleanup:
            return 2 // Variable, but estimate 2 minutes
        case .volumeBulkAttach(let operations):
            return max(1, operations.count / 8) // ~8 attachments per minute
        case .volumeBulkDetach(let operations):
            return max(1, operations.count / 12) // ~12 detachments per minute
        case .volumeBulkCreate(let configs):
            return max(1, configs.count / 6) // ~6 volumes per minute
        case .volumeBulkDelete(let volumeIDs):
            return max(1, volumeIDs.count / 15) // ~15 deletions per minute
        case .floatingIPBulkCreate(let configs):
            return max(1, configs.count / 20) // ~20 IPs per minute
        case .floatingIPBulkAssign(let assignments):
            return max(1, assignments.count / 15) // ~15 assignments per minute
        case .floatingIPBulkDelete(let floatingIPIDs):
            return max(1, floatingIPIDs.count / 20) // ~20 deletions per minute
        case .securityGroupBulkCreate(let configs):
            return max(1, configs.count / 10) // ~10 security groups per minute
        case .securityGroupBulkDelete(let securityGroupIDs):
            return max(1, securityGroupIDs.count / 15) // ~15 deletions per minute
        case .networkInterfaceBulkAttach(let operations):
            return max(1, operations.count / 12) // ~12 attachments per minute
        case .networkBulkDelete(let networkIDs):
            return max(1, networkIDs.count / 10) // ~10 deletions per minute
        case .subnetBulkDelete(let subnetIDs):
            return max(1, subnetIDs.count / 15) // ~15 deletions per minute
        case .routerBulkDelete(let routerIDs):
            return max(1, routerIDs.count / 10) // ~10 deletions per minute
        case .portBulkDelete(let portIDs):
            return max(1, portIDs.count / 20) // ~20 deletions per minute
        case .serverGroupBulkDelete(let serverGroupIDs):
            return max(1, serverGroupIDs.count / 15) // ~15 deletions per minute
        case .keyPairBulkDelete(let keyPairNames):
            return max(1, keyPairNames.count / 30) // ~30 deletions per minute
        case .imageBulkDelete(let imageIDs):
            return max(1, imageIDs.count / 8) // ~8 deletions per minute (slower due to image size)
        case .swiftContainerBulkCreate(let configs):
            return max(1, configs.count / 20) // ~20 containers per minute
        case .swiftContainerBulkDelete(let containerNames):
            return max(1, containerNames.count / 15) // ~15 deletions per minute
        case .swiftObjectBulkUpload(let operations):
            return max(1, operations.count / 10) // ~10 uploads per minute (varies by size)
        case .swiftObjectBulkDownload(let operations):
            return max(1, operations.count / 15) // ~15 downloads per minute
        case .swiftObjectBulkDelete(_, let objectNames):
            return max(1, objectNames.count / 30) // ~30 deletions per minute
        }
    }
}

// MARK: - Batch Operation Configuration Types

public struct ServerCreateConfig: Sendable, Hashable {
    public let name: String
    public let imageID: String
    public let flavorID: String
    public let networkIDs: [String]
    public let keyPairName: String?
    public let securityGroups: [String]
    public let userData: String?
    public let availabilityZone: String?
    public let metadata: [String: String]

    public init(
        name: String,
        imageID: String,
        flavorID: String,
        networkIDs: [String],
        keyPairName: String? = nil,
        securityGroups: [String] = [],
        userData: String? = nil,
        availabilityZone: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.imageID = imageID
        self.flavorID = flavorID
        self.networkIDs = networkIDs
        self.keyPairName = keyPairName
        self.securityGroups = securityGroups
        self.userData = userData
        self.availabilityZone = availabilityZone
        self.metadata = metadata
    }
}

public struct VolumeCreateConfig: Sendable, Hashable {
    public let name: String
    public let size: Int
    public let volumeType: String?
    public let description: String?
    public let availabilityZone: String?
    public let metadata: [String: String]

    public init(
        name: String,
        size: Int,
        volumeType: String? = nil,
        description: String? = nil,
        availabilityZone: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.size = size
        self.volumeType = volumeType
        self.description = description
        self.availabilityZone = availabilityZone
        self.metadata = metadata
    }
}

public struct VolumeAttachmentOperation: Sendable, Hashable {
    public let volumeID: String
    public let serverID: String
    public let device: String?

    public init(volumeID: String, serverID: String, device: String? = nil) {
        self.volumeID = volumeID
        self.serverID = serverID
        self.device = device
    }
}

public struct VolumeDetachmentOperation: Sendable, Hashable {
    public let volumeID: String
    public let serverID: String

    public init(volumeID: String, serverID: String) {
        self.volumeID = volumeID
        self.serverID = serverID
    }
}

public struct FloatingIPCreateConfig: Sendable, Hashable {
    public let networkID: String
    public let description: String?

    public init(networkID: String, description: String? = nil) {
        self.networkID = networkID
        self.description = description
    }
}

public struct FloatingIPAssignment: Sendable, Hashable {
    public let floatingIPID: String
    public let serverID: String
    public let portID: String?

    public init(floatingIPID: String, serverID: String, portID: String? = nil) {
        self.floatingIPID = floatingIPID
        self.serverID = serverID
        self.portID = portID
    }
}

public struct SecurityGroupCreateConfig: Sendable, Hashable {
    public let name: String
    public let description: String
    public let rules: [SecurityGroupRuleConfig]

    public init(name: String, description: String, rules: [SecurityGroupRuleConfig] = []) {
        self.name = name
        self.description = description
        self.rules = rules
    }
}

public struct SecurityGroupRuleConfig: Sendable, Hashable {
    public let direction: String // "ingress" or "egress"
    public let ipProtocol: String // "tcp", "udp", "icmp", or protocol number
    public let portRangeMin: Int?
    public let portRangeMax: Int?
    public let remoteIPPrefix: String?
    public let remoteGroupID: String?

    public init(
        direction: String,
        ipProtocol: String,
        portRangeMin: Int? = nil,
        portRangeMax: Int? = nil,
        remoteIPPrefix: String? = nil,
        remoteGroupID: String? = nil
    ) {
        self.direction = direction
        self.ipProtocol = ipProtocol
        self.portRangeMin = portRangeMin
        self.portRangeMax = portRangeMax
        self.remoteIPPrefix = remoteIPPrefix
        self.remoteGroupID = remoteGroupID
    }
}

public struct NetworkInterfaceOperation: Sendable, Hashable {
    public let serverID: String
    public let networkID: String
    public let portID: String?
    public let fixedIPs: [String]

    public init(serverID: String, networkID: String, portID: String? = nil, fixedIPs: [String] = []) {
        self.serverID = serverID
        self.networkID = networkID
        self.portID = portID
        self.fixedIPs = fixedIPs
    }
}

// MARK: - Network Topology Deployment

public struct NetworkTopologyDeployment: Sendable, Hashable {
    public let name: String
    public let network: NetworkTopologyNetworkConfig
    public let subnets: [NetworkTopologySubnetConfig]
    public let ports: [NetworkTopologyPortConfig]
    public let router: NetworkTopologyRouterConfig?

    public init(
        name: String,
        network: NetworkTopologyNetworkConfig,
        subnets: [NetworkTopologySubnetConfig] = [],
        ports: [NetworkTopologyPortConfig] = [],
        router: NetworkTopologyRouterConfig? = nil
    ) {
        self.name = name
        self.network = network
        self.subnets = subnets
        self.ports = ports
        self.router = router
    }

    public var totalResourceCount: Int {
        return 1 + subnets.count + ports.count + (router != nil ? 1 : 0)
    }
}

public struct NetworkTopologyNetworkConfig: Sendable, Hashable {
    public let name: String
    public let adminStateUp: Bool
    public let shared: Bool
    public let external: Bool

    public init(name: String, adminStateUp: Bool = true, shared: Bool = false, external: Bool = false) {
        self.name = name
        self.adminStateUp = adminStateUp
        self.shared = shared
        self.external = external
    }
}

public struct NetworkTopologySubnetConfig: Sendable, Hashable {
    public let name: String
    public let cidr: String
    public let gatewayIP: String?
    public let dnsNameservers: [String]
    public let allocationPools: [AllocationPool]

    public init(
        name: String,
        cidr: String,
        gatewayIP: String? = nil,
        dnsNameservers: [String] = [],
        allocationPools: [AllocationPool] = []
    ) {
        self.name = name
        self.cidr = cidr
        self.gatewayIP = gatewayIP
        self.dnsNameservers = dnsNameservers
        self.allocationPools = allocationPools
    }
}

public struct AllocationPool: Sendable, Hashable {
    public let start: String
    public let end: String

    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }
}

public struct NetworkTopologyPortConfig: Sendable, Hashable {
    public let name: String
    public let subnetID: String? // Will be resolved after subnet creation
    public let fixedIPs: [String]
    public let securityGroups: [String]

    public init(name: String, subnetID: String? = nil, fixedIPs: [String] = [], securityGroups: [String] = []) {
        self.name = name
        self.subnetID = subnetID
        self.fixedIPs = fixedIPs
        self.securityGroups = securityGroups
    }
}

public struct NetworkTopologyRouterConfig: Sendable, Hashable {
    public let name: String
    public let externalGatewayNetworkID: String?
    public let adminStateUp: Bool

    public init(name: String, externalGatewayNetworkID: String? = nil, adminStateUp: Bool = true) {
        self.name = name
        self.externalGatewayNetworkID = externalGatewayNetworkID
        self.adminStateUp = adminStateUp
    }
}

// MARK: - Swift Object Storage Operation Configuration Types

public struct SwiftContainerCreateConfig: Sendable, Hashable {
    public let name: String
    public let metadata: [String: String]
    public let readACL: String?
    public let writeACL: String?

    public init(
        name: String,
        metadata: [String: String] = [:],
        readACL: String? = nil,
        writeACL: String? = nil
    ) {
        self.name = name
        self.metadata = metadata
        self.readACL = readACL
        self.writeACL = writeACL
    }
}

public struct SwiftObjectUploadOperation: Sendable, Hashable {
    public let containerName: String
    public let objectName: String
    public let localPath: String
    public let contentType: String?
    public let metadata: [String: String]

    public init(
        containerName: String,
        objectName: String,
        localPath: String,
        contentType: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.containerName = containerName
        self.objectName = objectName
        self.localPath = localPath
        self.contentType = contentType
        self.metadata = metadata
    }
}

public struct SwiftObjectDownloadOperation: Sendable, Hashable {
    public let containerName: String
    public let objectName: String
    public let localPath: String

    public init(
        containerName: String,
        objectName: String,
        localPath: String
    ) {
        self.containerName = containerName
        self.objectName = objectName
        self.localPath = localPath
    }
}

// MARK: - Resource Cleanup

public struct ResourceCleanupCriteria: Sendable, Hashable {
    public let includeServers: Bool
    public let includeVolumes: Bool
    public let includeNetworks: Bool
    public let includePorts: Bool
    public let includeFloatingIPs: Bool
    public let includeSecurityGroups: Bool
    public let namePattern: String?
    public let olderThan: Date?
    public let dryRun: Bool

    public init(
        includeServers: Bool = false,
        includeVolumes: Bool = false,
        includeNetworks: Bool = false,
        includePorts: Bool = false,
        includeFloatingIPs: Bool = false,
        includeSecurityGroups: Bool = false,
        namePattern: String? = nil,
        olderThan: Date? = nil,
        dryRun: Bool = true
    ) {
        self.includeServers = includeServers
        self.includeVolumes = includeVolumes
        self.includeNetworks = includeNetworks
        self.includePorts = includePorts
        self.includeFloatingIPs = includeFloatingIPs
        self.includeSecurityGroups = includeSecurityGroups
        self.namePattern = namePattern
        self.olderThan = olderThan
        self.dryRun = dryRun
    }
}

// MARK: - Batch Operation Result Types

public struct BatchOperationResult: Sendable {
    public let operationID: String
    public let type: BatchOperationType
    public let status: BatchOperationStatus
    public let startTime: Date
    public let endTime: Date?
    public let totalOperations: Int
    public let successfulOperations: Int
    public let failedOperations: Int
    public let results: [IndividualOperationResult]
    public let error: (any Error)?

    public init(
        operationID: String,
        type: BatchOperationType,
        status: BatchOperationStatus,
        startTime: Date,
        endTime: Date? = nil,
        totalOperations: Int,
        successfulOperations: Int = 0,
        failedOperations: Int = 0,
        results: [IndividualOperationResult] = [],
        error: (any Error)? = nil
    ) {
        self.operationID = operationID
        self.type = type
        self.status = status
        self.startTime = startTime
        self.endTime = endTime
        self.totalOperations = totalOperations
        self.successfulOperations = successfulOperations
        self.failedOperations = failedOperations
        self.results = results
        self.error = error
    }

    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    public var successRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(successfulOperations) / Double(totalOperations)
    }

    public var isComplete: Bool {
        return status == .completed || status == .failed || status == .cancelled
    }
}

public struct IndividualOperationResult: Sendable {
    public let operationIndex: Int
    public let resourceType: String
    public let resourceID: String?
    public let resourceName: String?
    public let status: OperationStatus
    public let error: (any Error)?
    public let startTime: Date
    public let endTime: Date?

    public init(
        operationIndex: Int,
        resourceType: String,
        resourceID: String? = nil,
        resourceName: String? = nil,
        status: OperationStatus,
        error: (any Error)? = nil,
        startTime: Date,
        endTime: Date? = nil
    ) {
        self.operationIndex = operationIndex
        self.resourceType = resourceType
        self.resourceID = resourceID
        self.resourceName = resourceName
        self.status = status
        self.error = error
        self.startTime = startTime
        self.endTime = endTime
    }

    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

public enum BatchOperationStatus: String, Sendable, CaseIterable {
    case pending = "pending"
    case validating = "validating"
    case planning = "planning"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case rollingBack = "rolling_back"
    case rolledBack = "rolled_back"

    public var isActive: Bool {
        switch self {
        case .pending, .validating, .planning, .executing, .rollingBack:
            return true
        case .completed, .failed, .cancelled, .rolledBack:
            return false
        }
    }
}

public enum OperationStatus: String, Sendable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case rolledBack = "rolled_back"

    public var isActive: Bool {
        switch self {
        case .pending, .inProgress:
            return true
        case .completed, .failed, .cancelled, .rolledBack:
            return false
        }
    }
}

// MARK: - Progress Tracking

public struct BatchOperationProgress: Sendable {
    public let operationID: String
    public let currentOperation: Int
    public let totalOperations: Int
    public let currentStatus: BatchOperationStatus
    public let currentOperationDescription: String?
    public let estimatedTimeRemaining: TimeInterval?
    public let throughputPerMinute: Double?

    public init(
        operationID: String,
        currentOperation: Int,
        totalOperations: Int,
        currentStatus: BatchOperationStatus,
        currentOperationDescription: String? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        throughputPerMinute: Double? = nil
    ) {
        self.operationID = operationID
        self.currentOperation = currentOperation
        self.totalOperations = totalOperations
        self.currentStatus = currentStatus
        self.currentOperationDescription = currentOperationDescription
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.throughputPerMinute = throughputPerMinute
    }

    public var completionPercentage: Double {
        guard totalOperations > 0 else { return 0.0 }
        return min(1.0, Double(currentOperation) / Double(totalOperations))
    }
}

// MARK: - Error Types

public enum BatchOperationError: Error, LocalizedError {
    case invalidConfiguration(String)
    case dependencyValidationFailed(String)
    case executionFailed(String)
    case rollbackFailed(String)
    case cancelled
    case timeout

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid batch operation configuration: \(message)"
        case .dependencyValidationFailed(let message):
            return "Dependency validation failed: \(message)"
        case .executionFailed(let message):
            return "Batch operation execution failed: \(message)"
        case .rollbackFailed(let message):
            return "Batch operation rollback failed: \(message)"
        case .cancelled:
            return "Batch operation was cancelled"
        case .timeout:
            return "Batch operation timed out"
        }
    }
}