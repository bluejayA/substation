// Sources/Substation/Modules/Core/BatchOperations/BatchOperationBuilder.swift
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2025 Kevin Carter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - Batch Operation Builder Protocol

/// Protocol for building planned operations from batch operation types
///
/// Modules implement this protocol to define how their batch operation types
/// are converted into executable `PlannedOperation` instances. This enables
/// decentralized batch operation definition where each module owns its
/// operation building logic.
///
/// ## Overview
///
/// The `BatchOperationBuilder` protocol is part of the batch operations
/// decentralization architecture. Instead of a centralized switch statement
/// that knows about all operation types, each module registers its own builder
/// that handles its specific operation types.
///
/// ## Example
///
/// ```swift
/// struct ServersBatchOperationBuilder: BatchOperationBuilder {
///     static let operationTypeIdentifier = "serverBulkDelete"
///
///     func canBuild(for operation: BatchOperationType) -> Bool {
///         if case .serverBulkDelete = operation {
///             return true
///         }
///         return false
///     }
///
///     func buildOperations(
///         for operation: BatchOperationType
///     ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
///         guard case .serverBulkDelete(let serverIDs) = operation else {
///             throw BatchOperationError.invalidConfiguration(
///                 "Invalid operation type for ServersBatchOperationBuilder"
///             )
///         }
///         return buildDeleteOperations(
///             ids: serverIDs,
///             type: .server,
///             idPrefix: "server"
///         )
///     }
/// }
/// ```
///
/// ## Registration
///
/// Builders are registered during module initialization:
///
/// ```swift
/// BatchOperationBuilderRegistry.shared.register(
///     ServersBatchOperationBuilder(),
///     for: "serverBulkDelete"
/// )
/// ```
protocol BatchOperationBuilder: Sendable {
    /// Unique identifier for this operation type
    ///
    /// This identifier is used to look up the appropriate builder
    /// in the registry when processing a batch operation.
    static var operationTypeIdentifier: String { get }

    /// Check if this builder can handle the given operation
    ///
    /// - Parameter operation: The batch operation to check
    /// - Returns: True if this builder can build operations for the given type
    func canBuild(for operation: BatchOperationType) -> Bool

    /// Build planned operations from a batch operation
    ///
    /// Converts the high-level batch operation into a list of individual
    /// planned operations that can be executed by the dependency resolver.
    ///
    /// - Parameter operation: The batch operation to build from
    /// - Returns: Array of planned operations ready for execution
    /// - Throws: BatchOperationError if the operation cannot be built
    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation]

    /// Resource type associated with this builder
    ///
    /// Used for dependency graph construction and operation grouping.
    var resourceType: ResourceDependencyResolver.ResourceType { get }

    /// Default estimated duration per operation in seconds
    ///
    /// Used for execution time estimates when not otherwise specified.
    var defaultEstimatedDuration: TimeInterval { get }
}

/// Default implementations for BatchOperationBuilder
extension BatchOperationBuilder {
    /// Default estimated duration is the standard delete time
    var defaultEstimatedDuration: TimeInterval {
        return ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
    }
}

// MARK: - Batch Operation Builder Registry

/// Registry for batch operation builders
///
/// Maintains a collection of operation builders that modules register to handle
/// their specific batch operation types. The registry enables decentralized
/// operation building where each module defines its own operation conversion logic.
///
/// ## Architecture
///
/// This registry is part of the decentralization effort for batch operations.
/// Instead of a monolithic switch statement in ResourceDependencyResolver,
/// each module registers builders that know how to convert their operation types
/// into planned operations.
///
/// ## Thread Safety
///
/// The registry is marked as `@MainActor` for thread safety, matching the
/// pattern used by other registries in the system (FormRegistry, ViewRegistry).
///
/// ## Usage
///
/// ```swift
/// // Register a builder during module initialization
/// BatchOperationBuilderRegistry.shared.register(
///     ServersBatchOperationBuilder(),
///     for: "serverBulkDelete"
/// )
///
/// // Find builder for an operation
/// if let builder = BatchOperationBuilderRegistry.shared.builder(for: operation) {
///     let plannedOps = try await builder.buildOperations(for: operation)
/// }
/// ```
@MainActor
final class BatchOperationBuilderRegistry {
    /// Shared singleton instance
    static let shared = BatchOperationBuilderRegistry()

    /// Map of operation type identifiers to their builders
    private var builders: [String: any BatchOperationBuilder] = [:]

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Register a batch operation builder
    ///
    /// - Parameters:
    ///   - builder: The builder instance to register
    ///   - identifier: The operation type identifier (defaults to builder's static identifier)
    func register(
        _ builder: any BatchOperationBuilder,
        for identifier: String? = nil
    ) {
        let key = identifier ?? type(of: builder).operationTypeIdentifier
        builders[key] = builder
        Logger.shared.logInfo(
            "BatchOperationBuilderRegistry - Registered builder for: \(key)"
        )
    }

    /// Unregister a batch operation builder
    ///
    /// - Parameter identifier: The operation type identifier to unregister
    func unregister(_ identifier: String) {
        builders.removeValue(forKey: identifier)
        Logger.shared.logInfo(
            "BatchOperationBuilderRegistry - Unregistered builder: \(identifier)"
        )
    }

    /// Find a builder that can handle the given operation
    ///
    /// Searches registered builders to find one that can build operations
    /// for the given batch operation type.
    ///
    /// - Parameter operation: The batch operation to find a builder for
    /// - Returns: A builder that can handle the operation, or nil if none found
    func builder(for operation: BatchOperationType) -> (any BatchOperationBuilder)? {
        // First try direct lookup using resourceInfo
        let info = operation.resourceInfo
        let lookupKey = "\(info.moduleID)BulkDelete"

        if let builder = builders[lookupKey], builder.canBuild(for: operation) {
            return builder
        }

        // Fallback to iterating through all builders
        for (_, builder) in builders {
            if builder.canBuild(for: operation) {
                return builder
            }
        }

        return nil
    }

    /// Get builder by identifier
    ///
    /// - Parameter identifier: The operation type identifier
    /// - Returns: The registered builder, or nil if not found
    func builder(for identifier: String) -> (any BatchOperationBuilder)? {
        return builders[identifier]
    }

    /// Get all registered builder identifiers
    ///
    /// - Returns: Set of all registered operation type identifiers
    func allBuilderIdentifiers() -> Set<String> {
        return Set(builders.keys)
    }

    /// Check if a builder is registered for the given identifier
    ///
    /// - Parameter identifier: The operation type identifier to check
    /// - Returns: True if a builder is registered
    func hasBuilder(for identifier: String) -> Bool {
        return builders[identifier] != nil
    }

    /// Get the count of registered builders
    ///
    /// - Returns: Number of registered builders
    var builderCount: Int {
        return builders.count
    }

    /// Clear all registered builders
    ///
    /// Primarily used for testing purposes.
    func clearAll() {
        builders.removeAll()
        Logger.shared.logInfo("BatchOperationBuilderRegistry - Cleared all builders")
    }
}

// MARK: - Generic Delete Operation Builder

/// Generic builder for simple bulk delete operations
///
/// This builder handles the common case of bulk delete operations that
/// don't require special handling. It can be used directly by modules
/// or subclassed for customization.
///
/// ## Usage
///
/// ```swift
/// let builder = GenericDeleteOperationBuilder(
///     operationIdentifier: "serverBulkDelete",
///     resourceType: .server,
///     idPrefix: "server"
/// )
/// BatchOperationBuilderRegistry.shared.register(builder)
/// ```
struct GenericDeleteOperationBuilder: BatchOperationBuilder {
    /// The operation type identifier
    static let operationTypeIdentifier: String = "genericBulkDelete"

    /// Instance-specific operation identifier
    private let operationIdentifier: String

    /// Resource type for this builder
    let resourceType: ResourceDependencyResolver.ResourceType

    /// Prefix for operation IDs
    private let idPrefix: String

    /// Custom duration per operation
    let defaultEstimatedDuration: TimeInterval

    /// Closure to extract resource IDs from operation
    private let extractIDs: @Sendable (BatchOperationType) -> [String]?

    /// Create a generic delete operation builder
    ///
    /// - Parameters:
    ///   - operationIdentifier: Unique identifier for this operation type
    ///   - resourceType: The resource type being operated on
    ///   - idPrefix: Prefix for generated operation IDs
    ///   - duration: Estimated duration per operation (defaults to standard delete time)
    ///   - extractIDs: Closure to extract resource IDs from the operation
    init(
        operationIdentifier: String,
        resourceType: ResourceDependencyResolver.ResourceType,
        idPrefix: String,
        duration: TimeInterval = ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds,
        extractIDs: @escaping @Sendable (BatchOperationType) -> [String]?
    ) {
        self.operationIdentifier = operationIdentifier
        self.resourceType = resourceType
        self.idPrefix = idPrefix
        self.defaultEstimatedDuration = duration
        self.extractIDs = extractIDs
    }

    /// Check if this builder can handle the operation
    func canBuild(for operation: BatchOperationType) -> Bool {
        return extractIDs(operation) != nil
    }

    /// Build planned delete operations
    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard let ids = extractIDs(operation) else {
            throw BatchOperationError.invalidConfiguration(
                "Cannot extract IDs for operation: \(operation.description)"
            )
        }

        return ids.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "\(idPrefix)-delete-\(index)",
                type: resourceType,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: defaultEstimatedDuration
            )
        }
    }
}

// MARK: - Standard Module Builders

/// Builder for server bulk delete operations
struct ServerBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "serverBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .server

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .serverBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .serverBulkDelete(let serverIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for ServerBulkDeleteBuilder"
            )
        }

        return serverIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "server-delete-\(index)",
                type: .server,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for volume bulk delete operations
struct VolumeBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "volumeBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .volume

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .volumeBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .volumeBulkDelete(let volumeIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for VolumeBulkDeleteBuilder"
            )
        }

        return volumeIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "volume-delete-\(index)",
                type: .volume,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for volume backup bulk delete operations
struct VolumeBackupBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "volumeBackupBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .volumeBackup

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .volumeBackupBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .volumeBackupBulkDelete(let backupIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for VolumeBackupBulkDeleteBuilder"
            )
        }

        return backupIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "volume-backup-delete-\(index)",
                type: .volumeBackup,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for floating IP bulk delete operations
struct FloatingIPBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "floatingIPBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .floatingIP

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .floatingIPBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .floatingIPBulkDelete(let floatingIPIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for FloatingIPBulkDeleteBuilder"
            )
        }

        return floatingIPIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "floatingip-delete-\(index)",
                type: .floatingIP,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for security group bulk delete operations
struct SecurityGroupBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "securityGroupBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .securityGroup

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .securityGroupBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .securityGroupBulkDelete(let securityGroupIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for SecurityGroupBulkDeleteBuilder"
            )
        }

        return securityGroupIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "securitygroup-delete-\(index)",
                type: .securityGroup,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for network interface bulk attach operations
struct NetworkInterfaceBulkAttachBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "networkInterfaceBulkAttach"
    let resourceType: ResourceDependencyResolver.ResourceType = .port

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .networkInterfaceBulkAttach = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .networkInterfaceBulkAttach(let interfaces) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for NetworkInterfaceBulkAttachBuilder"
            )
        }

        return interfaces.enumerated().map { (index, interface) in
            ResourceDependencyResolver.PlannedOperation(
                id: "interface-attach-\(index)",
                type: .port,
                action: .attach,
                resourceIdentifier: interface.portID ?? "port-\(index)",
                dependencies: Set([
                    "server-\(interface.serverID)",
                    "network-\(interface.networkID)"
                ]),
                estimatedDuration: ResourceDependencyResolver.OperationAction.attach.estimatedDurationSeconds,
                metadata: [
                    "serverID": interface.serverID,
                    "networkID": interface.networkID
                ]
            )
        }
    }
}

/// Builder for network bulk delete operations
struct NetworkBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "networkBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .network

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .networkBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .networkBulkDelete(let networkIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for NetworkBulkDeleteBuilder"
            )
        }

        return networkIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "network-delete-\(index)",
                type: .network,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for subnet bulk delete operations
struct SubnetBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "subnetBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .subnet

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .subnetBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .subnetBulkDelete(let subnetIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for SubnetBulkDeleteBuilder"
            )
        }

        return subnetIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "subnet-delete-\(index)",
                type: .subnet,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for router bulk delete operations
struct RouterBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "routerBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .router

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .routerBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .routerBulkDelete(let routerIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for RouterBulkDeleteBuilder"
            )
        }

        return routerIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "router-delete-\(index)",
                type: .router,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for port bulk delete operations
struct PortBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "portBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .port

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .portBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .portBulkDelete(let portIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for PortBulkDeleteBuilder"
            )
        }

        return portIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "port-delete-\(index)",
                type: .port,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for server group bulk delete operations
struct ServerGroupBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "serverGroupBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .serverGroup

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .serverGroupBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .serverGroupBulkDelete(let serverGroupIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for ServerGroupBulkDeleteBuilder"
            )
        }

        return serverGroupIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "servergroup-delete-\(index)",
                type: .serverGroup,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for key pair bulk delete operations
struct KeyPairBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "keyPairBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .keyPair

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .keyPairBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .keyPairBulkDelete(let keyPairNames) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for KeyPairBulkDeleteBuilder"
            )
        }

        return keyPairNames.enumerated().map { (index, name) in
            ResourceDependencyResolver.PlannedOperation(
                id: "keypair-delete-\(index)",
                type: .keyPair,
                action: .delete,
                resourceIdentifier: name,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for image bulk delete operations
struct ImageBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "imageBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .image

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .imageBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .imageBulkDelete(let imageIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for ImageBulkDeleteBuilder"
            )
        }

        return imageIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "image-delete-\(index)",
                type: .image,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

/// Builder for Swift container bulk delete operations
struct SwiftContainerBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "swiftContainerBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .swiftContainer
    let defaultEstimatedDuration: TimeInterval = 3.0

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .swiftContainerBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .swiftContainerBulkDelete(let containerNames) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for SwiftContainerBulkDeleteBuilder"
            )
        }

        return containerNames.enumerated().map { (index, name) in
            ResourceDependencyResolver.PlannedOperation(
                id: "swift-container-delete-\(index)",
                type: .swiftContainer,
                action: .delete,
                resourceIdentifier: name,
                dependencies: [],
                estimatedDuration: defaultEstimatedDuration
            )
        }
    }
}

/// Builder for Swift object bulk delete operations
struct SwiftObjectBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "swiftObjectBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .swiftObject
    let defaultEstimatedDuration: TimeInterval = 2.0

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .swiftObjectBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .swiftObjectBulkDelete(let containerName, let objectNames) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for SwiftObjectBulkDeleteBuilder"
            )
        }

        return objectNames.enumerated().map { (index, name) in
            ResourceDependencyResolver.PlannedOperation(
                id: "swift-object-delete-\(index)",
                type: .swiftObject,
                action: .delete,
                resourceIdentifier: "\(containerName)/\(name)",
                dependencies: [],
                estimatedDuration: defaultEstimatedDuration
            )
        }
    }
}

/// Builder for Barbican secret bulk delete operations
struct BarbicanSecretBulkDeleteBuilder: BatchOperationBuilder {
    static let operationTypeIdentifier = "barbicanSecretBulkDelete"
    let resourceType: ResourceDependencyResolver.ResourceType = .barbicanSecret

    init() {}

    func canBuild(for operation: BatchOperationType) -> Bool {
        if case .barbicanSecretBulkDelete = operation {
            return true
        }
        return false
    }

    func buildOperations(
        for operation: BatchOperationType
    ) async throws -> [ResourceDependencyResolver.PlannedOperation] {
        guard case .barbicanSecretBulkDelete(let secretIDs) = operation else {
            throw BatchOperationError.invalidConfiguration(
                "Invalid operation type for BarbicanSecretBulkDeleteBuilder"
            )
        }

        return secretIDs.enumerated().map { (index, id) in
            ResourceDependencyResolver.PlannedOperation(
                id: "barbican-secret-delete-\(index)",
                type: .barbicanSecret,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: ResourceDependencyResolver.OperationAction.delete.estimatedDurationSeconds
            )
        }
    }
}

// MARK: - Builder Registration Helper

/// Helper to register all standard batch operation builders
///
/// This function registers all the built-in builders for standard
/// batch operation types. Call this during application initialization
/// to enable the decentralized batch operation building.
///
/// ## Usage
///
/// ```swift
/// // During app initialization
/// await registerStandardBatchOperationBuilders()
/// ```
@MainActor
func registerStandardBatchOperationBuilders() {
    let registry = BatchOperationBuilderRegistry.shared

    // Server operations
    registry.register(ServerBulkDeleteBuilder())

    // Volume operations
    registry.register(VolumeBulkDeleteBuilder())
    registry.register(VolumeBackupBulkDeleteBuilder())

    // Network operations
    registry.register(FloatingIPBulkDeleteBuilder())
    registry.register(SecurityGroupBulkDeleteBuilder())
    registry.register(NetworkInterfaceBulkAttachBuilder())
    registry.register(NetworkBulkDeleteBuilder())
    registry.register(SubnetBulkDeleteBuilder())
    registry.register(RouterBulkDeleteBuilder())
    registry.register(PortBulkDeleteBuilder())

    // Other operations
    registry.register(ServerGroupBulkDeleteBuilder())
    registry.register(KeyPairBulkDeleteBuilder())
    registry.register(ImageBulkDeleteBuilder())
    registry.register(SwiftContainerBulkDeleteBuilder())
    registry.register(SwiftObjectBulkDeleteBuilder())
    registry.register(BarbicanSecretBulkDeleteBuilder())

    Logger.shared.logInfo(
        "BatchOperationBuilderRegistry - Registered \(registry.builderCount) standard builders"
    )
}
