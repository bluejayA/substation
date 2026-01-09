import Foundation
import OSClient

// MARK: - Batch Operation Types

/// Core batch operation types supported by the system
///
/// - Important: This centralized enum is being deprecated in favor of a decentralized
///   approach where each module defines its own operation types and registers builders
///   with the `BatchOperationBuilderRegistry`. New operation types should use the
///   `BatchOperationBuilder` protocol instead of adding cases to this enum.
///
/// ## Migration Path
///
/// Instead of adding new cases to this enum, modules should:
/// 1. Create a struct conforming to `BatchOperationBuilder`
/// 2. Register the builder with `BatchOperationBuilderRegistry.shared.register()`
/// 3. The `ResourceDependencyResolver` will automatically use registered builders
///
/// Existing cases will continue to work via the legacy fallback in
/// `ResourceDependencyResolver.buildOperationsLegacy()`.
///
/// ## Example
///
/// ```swift
/// // Old approach (deprecated)
/// case myNewBulkDelete(ids: [String])
///
/// // New approach (preferred)
/// struct MyNewBulkDeleteBuilder: BatchOperationBuilder {
///     static let operationTypeIdentifier = "myNewBulkDelete"
///     // ... implementation
/// }
/// BatchOperationBuilderRegistry.shared.register(MyNewBulkDeleteBuilder())
/// ```
public enum BatchOperationType: Sendable, Hashable {
    case serverBulkDelete(serverIDs: [String])
    case volumeBulkDelete(volumeIDs: [String])
    case floatingIPBulkDelete(floatingIPIDs: [String])
    case securityGroupBulkDelete(securityGroupIDs: [String])
    case networkInterfaceBulkAttach(operations: [NetworkInterfaceOperation])
    case networkBulkDelete(networkIDs: [String])
    case subnetBulkDelete(subnetIDs: [String])
    case routerBulkDelete(routerIDs: [String])
    case portBulkDelete(portIDs: [String])
    case serverGroupBulkDelete(serverGroupIDs: [String])
    case keyPairBulkDelete(keyPairNames: [String])
    case imageBulkDelete(imageIDs: [String])
    case swiftContainerBulkDelete(containerNames: [String])
    case swiftObjectBulkDelete(containerName: String, objectNames: [String])
    case volumeBackupBulkDelete(backupIDs: [String])
    case barbicanSecretBulkDelete(secretIDs: [String])
    case clusterBulkDelete(clusterIDs: [String])
    case clusterTemplateBulkDelete(templateIDs: [String])

    public var description: String {
        switch self {
        case .serverBulkDelete(let serverIDs):
            return "Bulk delete \(serverIDs.count) servers"
        case .volumeBulkDelete(let volumeIDs):
            return "Bulk delete \(volumeIDs.count) volumes"
        case .floatingIPBulkDelete(let floatingIPIDs):
            return "Bulk delete \(floatingIPIDs.count) floating IPs"
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
        case .swiftContainerBulkDelete(let containerNames):
            return "Bulk delete \(containerNames.count) Swift containers"
        case .swiftObjectBulkDelete(_, let objectNames):
            return "Bulk delete \(objectNames.count) Swift objects"
        case .volumeBackupBulkDelete(let backupIDs):
            return "Bulk delete \(backupIDs.count) volume backups"
        case .barbicanSecretBulkDelete(let secretIDs):
            return "Bulk delete \(secretIDs.count) Barbican secrets"
        case .clusterBulkDelete(let clusterIDs):
            return "Bulk delete \(clusterIDs.count) Kubernetes clusters"
        case .clusterTemplateBulkDelete(let templateIDs):
            return "Bulk delete \(templateIDs.count) cluster templates"
        }
    }

    public var estimatedTimeMinutes: Int {
        switch self {
        case .serverBulkDelete(let serverIDs):
            return max(1, serverIDs.count / 10) // ~10 deletions per minute
        case .volumeBulkDelete(let volumeIDs):
            return max(1, volumeIDs.count / 15) // ~15 deletions per minute
        case .floatingIPBulkDelete(let floatingIPIDs):
            return max(1, floatingIPIDs.count / 20) // ~20 deletions per minute
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
        case .swiftContainerBulkDelete(let containerNames):
            return max(1, containerNames.count / 15) // ~15 deletions per minute
        case .swiftObjectBulkDelete(_, let objectNames):
            return max(1, objectNames.count / 30) // ~30 deletions per minute
        case .volumeBackupBulkDelete(let backupIDs):
            return max(1, backupIDs.count / 10) // ~10 deletions per minute
        case .barbicanSecretBulkDelete(let secretIDs):
            return max(1, secretIDs.count / 20) // ~20 deletions per minute
        case .clusterBulkDelete(let clusterIDs):
            return max(1, clusterIDs.count / 3) // ~3 deletions per minute (clusters take longer)
        case .clusterTemplateBulkDelete(let templateIDs):
            return max(1, templateIDs.count / 15) // ~15 deletions per minute
        }
    }

    /// Extract resource IDs and module identifier from the operation
    ///
    /// Provides a unified way to get the resource identifiers and the
    /// corresponding module identifier for registry lookup.
    ///
    /// - Returns: Tuple containing resource IDs and module identifier
    public var resourceInfo: (resourceIDs: [String], moduleID: String) {
        switch self {
        case .serverBulkDelete(let ids):
            return (ids, "servers")
        case .volumeBulkDelete(let ids):
            return (ids, "volumes")
        case .floatingIPBulkDelete(let ids):
            return (ids, "floatingIPs")
        case .securityGroupBulkDelete(let ids):
            return (ids, "securityGroups")
        case .networkInterfaceBulkAttach(let ops):
            return (ops.map { $0.serverID }, "servers")
        case .networkBulkDelete(let ids):
            return (ids, "networks")
        case .subnetBulkDelete(let ids):
            return (ids, "subnets")
        case .routerBulkDelete(let ids):
            return (ids, "routers")
        case .portBulkDelete(let ids):
            return (ids, "ports")
        case .serverGroupBulkDelete(let ids):
            return (ids, "serverGroups")
        case .keyPairBulkDelete(let names):
            return (names, "keyPairs")
        case .imageBulkDelete(let ids):
            return (ids, "images")
        case .swiftContainerBulkDelete(let names):
            return (names, "swift")
        case .swiftObjectBulkDelete(_, let names):
            return (names, "swift")
        case .volumeBackupBulkDelete(let ids):
            return (ids, "volumes")
        case .barbicanSecretBulkDelete(let ids):
            return (ids, "barbican")
        case .clusterBulkDelete(let ids):
            return (ids, "magnum")
        case .clusterTemplateBulkDelete(let ids):
            return (ids, "magnum")
        }
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
    public let results: [BatchIndividualOperationResult]
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
        results: [BatchIndividualOperationResult] = [],
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

/// Result of an individual operation within a batch execution
///
/// This struct tracks detailed execution information for a single resource
/// operation within a batch, including timing, status, and error details.
/// Used internally by BatchOperationManager for execution tracking.
public struct BatchIndividualOperationResult: Sendable {
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