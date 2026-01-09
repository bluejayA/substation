import Foundation
import OSClient

// MARK: - Resource Dependency Resolver

/// Resolves resource dependencies and determines optimal execution order for batch operations
actor ResourceDependencyResolver {

    // MARK: - Dependency Graph Types

    public enum ResourceType: String, CaseIterable, Sendable {
        case network
        case subnet
        case port
        case router
        case server
        case volume
        case volumeBackup
        case floatingIP
        case securityGroup
        case serverGroup
        case keyPair
        case image
        case swiftContainer
        case swiftObject
        case barbicanSecret
        case flavor
        case cluster
        case clusterTemplate

        /// Module identifier for BatchOperationRegistry lookup
        ///
        /// Maps each resource type to its corresponding module identifier string
        /// used by the BatchOperationRegistry for provider resolution.
        public var moduleIdentifier: String {
            switch self {
            case .server:
                return "servers"
            case .volume, .volumeBackup:
                return "volumes"
            case .network:
                return "networks"
            case .subnet:
                return "subnets"
            case .port:
                return "ports"
            case .router:
                return "routers"
            case .floatingIP:
                return "floatingIPs"
            case .securityGroup:
                return "securityGroups"
            case .serverGroup:
                return "serverGroups"
            case .keyPair:
                return "keyPairs"
            case .image:
                return "images"
            case .swiftContainer, .swiftObject:
                return "swift"
            case .barbicanSecret:
                return "barbican"
            case .flavor:
                return "flavors"
            case .cluster, .clusterTemplate:
                return "magnum"
            }
        }
    }

    public struct DependencyNode: Sendable, Hashable {
        public let id: String
        public let type: ResourceType
        public let name: String?
        public let dependencies: Set<String> // IDs of resources this depends on
        public let metadata: [String: String]

        public init(
            id: String,
            type: ResourceType,
            name: String? = nil,
            dependencies: Set<String> = [],
            metadata: [String: String] = [:]
        ) {
            self.id = id
            self.type = type
            self.name = name
            self.dependencies = dependencies
            self.metadata = metadata
        }
    }

    public struct ExecutionPlan: Sendable {
        public let operationID: String
        public let phases: [ExecutionPhase]
        public let totalOperations: Int
        public let estimatedDuration: TimeInterval
        public let warnings: [String]

        public init(
            operationID: String,
            phases: [ExecutionPhase],
            totalOperations: Int,
            estimatedDuration: TimeInterval,
            warnings: [String] = []
        ) {
            self.operationID = operationID
            self.phases = phases
            self.totalOperations = totalOperations
            self.estimatedDuration = estimatedDuration
            self.warnings = warnings
        }
    }

    public struct ExecutionPhase: Sendable {
        public let phaseNumber: Int
        public let operations: [PlannedOperation]
        public let canRunInParallel: Bool
        public let description: String
        public let estimatedDuration: TimeInterval

        public init(
            phaseNumber: Int,
            operations: [PlannedOperation],
            canRunInParallel: Bool,
            description: String,
            estimatedDuration: TimeInterval
        ) {
            self.phaseNumber = phaseNumber
            self.operations = operations
            self.canRunInParallel = canRunInParallel
            self.description = description
            self.estimatedDuration = estimatedDuration
        }
    }

    public struct PlannedOperation: Sendable, Hashable {
        public let id: String
        public let type: ResourceType
        public let action: OperationAction
        public let resourceIdentifier: String
        public let dependencies: Set<String>
        public let estimatedDuration: TimeInterval
        public let metadata: [String: String]

        public init(
            id: String,
            type: ResourceType,
            action: OperationAction,
            resourceIdentifier: String,
            dependencies: Set<String> = [],
            estimatedDuration: TimeInterval,
            metadata: [String: String] = [:]
        ) {
            self.id = id
            self.type = type
            self.action = action
            self.resourceIdentifier = resourceIdentifier
            self.dependencies = dependencies
            self.estimatedDuration = estimatedDuration
            self.metadata = metadata
        }
    }

    public enum OperationAction: String, Sendable, CaseIterable {
        case create
        case delete
        case update
        case attach
        case detach
        case upload
        case download

        public var estimatedDurationSeconds: TimeInterval {
            switch self {
            case .create:
                return 30.0 // Most creates take ~30 seconds
            case .delete:
                return 15.0 // Deletes are faster
            case .update:
                return 20.0 // Updates are moderate
            case .attach:
                return 25.0 // Attachments take time
            case .detach:
                return 10.0 // Detachments are fast
            case .upload:
                return 45.0 // Uploads can take longer depending on size
            case .download:
                return 40.0 // Downloads similar to uploads
            }
        }
    }

    // MARK: - Properties

    private var dependencyGraph: [String: DependencyNode] = [:]
    private var maxConcurrency: Int = 10

    // MARK: - Initialization

    public init(maxConcurrency: Int = 10) {
        self.maxConcurrency = maxConcurrency
    }

    // MARK: - Main Interface

    /// Creates an execution plan for a batch operation
    public func createExecutionPlan(for operation: BatchOperationType) async throws -> ExecutionPlan {
        let operationID = UUID().uuidString
        var warnings: [String] = []

        Logger.shared.logInfo("ResourceDependencyResolver - Creating execution plan for: \(operation.description)")

        // Clear previous state
        dependencyGraph.removeAll()

        // Build dependency graph based on operation type
        let operations = try await buildOperationsFromBatchType(operation)

        // Create dependency nodes
        for op in operations {
            let node = DependencyNode(
                id: op.id,
                type: op.type,
                name: op.resourceIdentifier,
                dependencies: op.dependencies,
                metadata: op.metadata
            )
            dependencyGraph[op.id] = node
        }

        // Validate dependencies
        let validationResult = await validateDependencies()
        if !validationResult.isValid {
            throw BatchOperationError.dependencyValidationFailed(validationResult.errors.joined(separator: "; "))
        }
        warnings.append(contentsOf: validationResult.warnings)

        // Create execution phases
        let phases = await createExecutionPhases(from: operations)

        // Calculate total duration and operation count
        let totalOperations = operations.count
        let estimatedDuration = phases.reduce(0) { total, phase in
            total + (phase.canRunInParallel ? phase.estimatedDuration : phase.operations.reduce(0) { $0 + $1.estimatedDuration })
        }

        let plan = ExecutionPlan(
            operationID: operationID,
            phases: phases,
            totalOperations: totalOperations,
            estimatedDuration: estimatedDuration,
            warnings: warnings
        )

        Logger.shared.logInfo("ResourceDependencyResolver - Execution plan created: \(phases.count) phases, \(totalOperations) operations, ~\(Int(estimatedDuration/60)) minutes")

        return plan
    }

    /// Validates that all dependencies can be satisfied
    public func validateDependencies() async -> (isValid: Bool, errors: [String], warnings: [String]) {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for circular dependencies
        let circularDeps = await detectCircularDependencies()
        if !circularDeps.isEmpty {
            errors.append("Circular dependencies detected: \(circularDeps.joined(separator: ", "))")
        }

        // Check for missing dependencies
        for (nodeId, node) in dependencyGraph {
            for depId in node.dependencies {
                if dependencyGraph[depId] == nil {
                    errors.append("Node \(nodeId) depends on missing resource \(depId)")
                }
            }
        }

        // Check for potential conflicts
        let conflicts = await detectPotentialConflicts()
        warnings.append(contentsOf: conflicts)

        return (isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    // MARK: - Private Implementation

    /// Build planned operations from a batch operation type
    ///
    /// This method first attempts to use the BatchOperationBuilderRegistry to find
    /// a registered builder for the operation. If no builder is found, it falls back
    /// to the legacy switch-based implementation for backwards compatibility.
    ///
    /// The registry-based approach allows modules to define their own operation
    /// building logic, enabling true decentralization of batch operation types.
    ///
    /// - Parameter batchType: The batch operation type to build operations from
    /// - Returns: Array of planned operations ready for execution
    /// - Throws: BatchOperationError if operations cannot be built
    private func buildOperationsFromBatchType(_ batchType: BatchOperationType) async throws -> [PlannedOperation] {
        // First, try to use the decentralized builder registry
        let operations = await buildOperationsViaRegistry(batchType)
        if let operations = operations {
            Logger.shared.logDebug(
                "ResourceDependencyResolver - Built \(operations.count) operations via registry"
            )
            return operations
        }

        // Fallback to legacy switch-based implementation
        // This maintains backwards compatibility during the transition period
        Logger.shared.logDebug(
            "ResourceDependencyResolver - Using legacy builder for: \(batchType.description)"
        )

        return try buildOperationsLegacy(batchType)
    }

    /// Build operations using the decentralized builder registry
    ///
    /// Looks up a registered builder that can handle the batch operation type
    /// and delegates the building to that builder.
    ///
    /// - Parameter batchType: The batch operation type to build
    /// - Returns: Array of planned operations, or nil if no builder found
    @MainActor
    private func buildOperationsViaRegistry(
        _ batchType: BatchOperationType
    ) async -> [PlannedOperation]? {
        guard let builder = BatchOperationBuilderRegistry.shared.builder(for: batchType) else {
            Logger.shared.logDebug(
                "ResourceDependencyResolver - No builder registered for: \(batchType.description)"
            )
            return nil
        }

        do {
            return try await builder.buildOperations(for: batchType)
        } catch {
            Logger.shared.logError(
                "ResourceDependencyResolver - Builder failed: \(error.localizedDescription)"
            )
            return nil
        }
    }

    /// Legacy implementation of operation building
    ///
    /// This method contains the original switch-based implementation for building
    /// operations. It is kept for backwards compatibility during the transition
    /// to the decentralized builder registry.
    ///
    /// - Note: This method is deprecated and will be removed in a future version.
    ///         Modules should register builders with BatchOperationBuilderRegistry instead.
    ///
    /// - Parameter batchType: The batch operation type to build
    /// - Returns: Array of planned operations
    /// - Throws: BatchOperationError if the operation type is not supported
    private func buildOperationsLegacy(_ batchType: BatchOperationType) throws -> [PlannedOperation] {
        switch batchType {
        case .serverBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .server, idPrefix: "server")

        case .volumeBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .volume, idPrefix: "volume")

        case .networkInterfaceBulkAttach(let interfaces):
            return buildNetworkInterfaceAttachOperations(interfaces)

        case .networkBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .network, idPrefix: "network")

        case .subnetBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .subnet, idPrefix: "subnet")

        case .routerBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .router, idPrefix: "router")

        case .portBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .port, idPrefix: "port")

        case .floatingIPBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .floatingIP, idPrefix: "floatingip")

        case .securityGroupBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .securityGroup, idPrefix: "securitygroup")

        case .serverGroupBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .serverGroup, idPrefix: "servergroup")

        case .keyPairBulkDelete(let names):
            return buildDeleteOperations(ids: names, type: .keyPair, idPrefix: "keypair")

        case .imageBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .image, idPrefix: "image")

        case .swiftContainerBulkDelete(let names):
            return buildDeleteOperations(ids: names, type: .swiftContainer, idPrefix: "swift-container", duration: 3.0)

        case .swiftObjectBulkDelete(let containerName, let objectNames):
            return objectNames.enumerated().map { (index, name) in
                PlannedOperation(
                    id: "swift-object-delete-\(index)",
                    type: .swiftObject,
                    action: .delete,
                    resourceIdentifier: "\(containerName)/\(name)",
                    dependencies: [],
                    estimatedDuration: 2.0
                )
            }

        case .volumeBackupBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .volumeBackup, idPrefix: "volume-backup")

        case .barbicanSecretBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .barbicanSecret, idPrefix: "barbican-secret")

        case .clusterBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .cluster, idPrefix: "cluster", duration: 30.0)

        case .clusterTemplateBulkDelete(let ids):
            return buildDeleteOperations(ids: ids, type: .clusterTemplate, idPrefix: "cluster-template")
        }
    }

    // MARK: - Generic Operation Builders

    /// Build delete operations for a list of resource identifiers
    ///
    /// This generic method replaces individual buildXXXDeleteOperations methods,
    /// reducing code duplication while maintaining the same functionality.
    ///
    /// - Parameters:
    ///   - ids: Array of resource identifiers to delete
    ///   - type: The resource type for the operations
    ///   - idPrefix: Prefix for operation IDs (e.g., "server", "volume")
    ///   - duration: Estimated duration per operation (defaults to standard delete time)
    /// - Returns: Array of planned delete operations
    private func buildDeleteOperations(
        ids: [String],
        type: ResourceType,
        idPrefix: String,
        duration: TimeInterval = OperationAction.delete.estimatedDurationSeconds
    ) -> [PlannedOperation] {
        return ids.enumerated().map { (index, id) in
            PlannedOperation(
                id: "\(idPrefix)-delete-\(index)",
                type: type,
                action: .delete,
                resourceIdentifier: id,
                dependencies: [],
                estimatedDuration: duration
            )
        }
    }

    private func buildNetworkInterfaceAttachOperations(_ interfaces: [NetworkInterfaceOperation]) -> [PlannedOperation] {
        return interfaces.enumerated().map { (index, interface) in
            PlannedOperation(
                id: "interface-attach-\(index)",
                type: .port,
                action: .attach,
                resourceIdentifier: interface.portID ?? "port-\(index)",
                dependencies: Set([
                    "server-\(interface.serverID)",
                    "network-\(interface.networkID)"
                ]),
                estimatedDuration: OperationAction.attach.estimatedDurationSeconds,
                metadata: [
                    "serverID": interface.serverID,
                    "networkID": interface.networkID
                ]
            )
        }
    }

    private func createExecutionPhases(from operations: [PlannedOperation]) async -> [ExecutionPhase] {
        var phases: [ExecutionPhase] = []
        var remainingOps = Set(operations)
        var completedOps = Set<String>()
        var phaseNumber = 1

        while !remainingOps.isEmpty {
            // Find operations that have all dependencies satisfied
            let readyOps = remainingOps.filter { op in
                op.dependencies.isSubset(of: completedOps)
            }

            guard !readyOps.isEmpty else {
                Logger.shared.logError("ResourceDependencyResolver - Dependency deadlock detected with \(remainingOps.count) remaining operations")
                break
            }

            // Group operations by type for parallel execution
            let groupedOps = Dictionary(grouping: readyOps) { $0.type }

            // Determine if operations can run in parallel
            let canRunInParallel = readyOps.count > 1 && readyOps.allSatisfy { op in
                // Create operations can usually run in parallel
                // Delete operations need careful ordering
                op.action == .create || op.action == .attach
            }

            // Calculate phase duration
            let phaseDuration = canRunInParallel ?
                readyOps.map(\.estimatedDuration).max() ?? 0 :
                readyOps.reduce(0) { $0 + $1.estimatedDuration }

            // Create description
            let typeGroups = groupedOps.keys.map { type in
                "\(groupedOps[type]?.count ?? 0) \(type.rawValue)s"
            }.joined(separator: ", ")

            let phase = ExecutionPhase(
                phaseNumber: phaseNumber,
                operations: Array(readyOps),
                canRunInParallel: canRunInParallel,
                description: "Phase \(phaseNumber): \(typeGroups)",
                estimatedDuration: phaseDuration
            )

            phases.append(phase)

            // Mark operations as completed and remove from remaining
            for op in readyOps {
                completedOps.insert(op.id)
                remainingOps.remove(op)
            }

            phaseNumber += 1
        }

        return phases
    }

    private func detectCircularDependencies() async -> [String] {
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        var circularDeps: [String] = []

        for nodeId in dependencyGraph.keys {
            if !visited.contains(nodeId) {
                await detectCircularDependenciesHelper(
                    nodeId: nodeId,
                    visited: &visited,
                    recursionStack: &recursionStack,
                    circularDeps: &circularDeps
                )
            }
        }

        return circularDeps
    }

    private func detectCircularDependenciesHelper(
        nodeId: String,
        visited: inout Set<String>,
        recursionStack: inout Set<String>,
        circularDeps: inout [String]
    ) async {
        visited.insert(nodeId)
        recursionStack.insert(nodeId)

        if let node = dependencyGraph[nodeId] {
            for depId in node.dependencies {
                if !visited.contains(depId) {
                    await detectCircularDependenciesHelper(
                        nodeId: depId,
                        visited: &visited,
                        recursionStack: &recursionStack,
                        circularDeps: &circularDeps
                    )
                } else if recursionStack.contains(depId) {
                    circularDeps.append("\(nodeId) -> \(depId)")
                }
            }
        }

        recursionStack.remove(nodeId)
    }

    private func detectPotentialConflicts() async -> [String] {
        var warnings: [String] = []

        // Check for resource name conflicts
        let nameGroups = Dictionary(grouping: dependencyGraph.values) { $0.name ?? "unnamed" }
        for (name, nodes) in nameGroups {
            if nodes.count > 1 && name != "unnamed" {
                warnings.append("Multiple resources with name '\(name)': \(nodes.map(\.type.rawValue).joined(separator: ", "))")
            }
        }

        // Check for high-concurrency scenarios that might stress the system
        let createOps = dependencyGraph.values.filter { node in
            // Assume operations with no dependencies are creates
            node.dependencies.isEmpty && node.type != .flavor && node.type != .image
        }

        if createOps.count > maxConcurrency * 2 {
            warnings.append("High concurrency operation (\(createOps.count) creates) may stress the OpenStack cluster")
        }

        return warnings
    }
}