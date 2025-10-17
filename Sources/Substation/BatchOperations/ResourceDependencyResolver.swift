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
        case floatingIP
        case securityGroup
        case serverGroup
        case keyPair
        case image
        case swiftContainer
        case swiftObject
        case flavor

        /// Resources that must exist before this resource can be created
        public var dependencies: [ResourceType] {
            switch self {
            case .network:
                return []
            case .subnet:
                return [.network]
            case .port:
                return [.network, .subnet]
            case .router:
                return [.network] // External network for gateway
            case .server:
                return [.image, .flavor, .network, .keyPair] // Basic dependencies
            case .volume:
                return []
            case .floatingIP:
                return [.network] // External network
            case .securityGroup:
                return []
            case .serverGroup:
                return []
            case .keyPair:
                return []
            case .image:
                return []
            case .flavor:
                return []
            case .swiftContainer:
                return []
            case .swiftObject:
                return [.swiftContainer]
            }
        }

        /// Resources that depend on this resource (reverse dependencies)
        public var dependents: [ResourceType] {
            return ResourceType.allCases.filter { type in
                type.dependencies.contains(self)
            }
        }

        /// Safe deletion order priority (lower number = delete first)
        public var deletionPriority: Int {
            switch self {
            case .server:
                return 1 // Delete servers first
            case .volume:
                return 2 // Then volumes (may be attached to servers)
            case .port:
                return 3 // Then ports
            case .floatingIP:
                return 4 // Then floating IPs
            case .router:
                return 5 // Then routers
            case .subnet:
                return 6 // Then subnets
            case .network:
                return 7 // Then networks
            case .securityGroup:
                return 8 // Security groups can be deleted late
            case .serverGroup:
                return 8 // Server groups can be deleted late
            case .keyPair, .image, .flavor:
                return 9 // System resources last
            case .swiftObject:
                return 2 // Delete objects before containers
            case .swiftContainer:
                return 8 // Delete containers late (after objects)
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

    private func buildOperationsFromBatchType(_ batchType: BatchOperationType) async throws -> [PlannedOperation] {
        var operations: [PlannedOperation] = []

        switch batchType {
        case .serverBulkDelete(let serverIDs):
            operations = await buildServerDeleteOperations(serverIDs)

        case .volumeBulkDelete(let volumeIDs):
            operations = await buildVolumeDeleteOperations(volumeIDs)

        case .networkInterfaceBulkAttach(let interfaces):
            operations = await buildNetworkInterfaceAttachOperations(interfaces)

        case .networkBulkDelete(let networkIDs):
            operations = await buildNetworkDeleteOperations(networkIDs)

        case .subnetBulkDelete(let subnetIDs):
            operations = await buildSubnetDeleteOperations(subnetIDs)

        case .routerBulkDelete(let routerIDs):
            operations = await buildRouterDeleteOperations(routerIDs)

        case .portBulkDelete(let portIDs):
            operations = await buildPortDeleteOperations(portIDs)

        case .floatingIPBulkDelete(let floatingIPIDs):
            operations = await buildFloatingIPDeleteOperations(floatingIPIDs)

        case .securityGroupBulkDelete(let securityGroupIDs):
            operations = await buildSecurityGroupDeleteOperations(securityGroupIDs)

        case .serverGroupBulkDelete(let serverGroupIDs):
            operations = await buildServerGroupDeleteOperations(serverGroupIDs)

        case .keyPairBulkDelete(let keyPairNames):
            operations = await buildKeyPairDeleteOperations(keyPairNames)

        case .imageBulkDelete(let imageIDs):
            operations = await buildImageDeleteOperations(imageIDs)

        case .swiftContainerBulkDelete(let containerNames):
            operations = await buildSwiftContainerDeleteOperations(containerNames)

        case .swiftObjectBulkDelete(let containerName, let objectNames):
            operations = await buildSwiftObjectDeleteOperations(containerName: containerName, objectNames: objectNames)
        }

        return operations
    }

    private func buildServerDeleteOperations(_ serverIDs: [String]) async -> [PlannedOperation] {
        return serverIDs.enumerated().map { (index, serverID) in
            PlannedOperation(
                id: "server-delete-\(index)",
                type: .server,
                action: .delete,
                resourceIdentifier: serverID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildVolumeDeleteOperations(_ volumeIDs: [String]) async -> [PlannedOperation] {
        return volumeIDs.enumerated().map { (index, volumeID) in
            PlannedOperation(
                id: "volume-delete-\(index)",
                type: .volume,
                action: .delete,
                resourceIdentifier: volumeID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildNetworkInterfaceAttachOperations(_ interfaces: [NetworkInterfaceOperation]) async -> [PlannedOperation] {
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

    private func buildNetworkDeleteOperations(_ networkIDs: [String]) async -> [PlannedOperation] {
        return networkIDs.enumerated().map { (index, networkID) in
            PlannedOperation(
                id: "network-delete-\(index)",
                type: .network,
                action: .delete,
                resourceIdentifier: networkID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildSubnetDeleteOperations(_ subnetIDs: [String]) async -> [PlannedOperation] {
        return subnetIDs.enumerated().map { (index, subnetID) in
            PlannedOperation(
                id: "subnet-delete-\(index)",
                type: .subnet,
                action: .delete,
                resourceIdentifier: subnetID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildRouterDeleteOperations(_ routerIDs: [String]) async -> [PlannedOperation] {
        return routerIDs.enumerated().map { (index, routerID) in
            PlannedOperation(
                id: "router-delete-\(index)",
                type: .router,
                action: .delete,
                resourceIdentifier: routerID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildPortDeleteOperations(_ portIDs: [String]) async -> [PlannedOperation] {
        return portIDs.enumerated().map { (index, portID) in
            PlannedOperation(
                id: "port-delete-\(index)",
                type: .port,
                action: .delete,
                resourceIdentifier: portID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildFloatingIPDeleteOperations(_ floatingIPIDs: [String]) async -> [PlannedOperation] {
        return floatingIPIDs.enumerated().map { (index, floatingIPID) in
            PlannedOperation(
                id: "floatingip-delete-\(index)",
                type: .floatingIP,
                action: .delete,
                resourceIdentifier: floatingIPID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildSecurityGroupDeleteOperations(_ securityGroupIDs: [String]) async -> [PlannedOperation] {
        return securityGroupIDs.enumerated().map { (index, securityGroupID) in
            PlannedOperation(
                id: "securitygroup-delete-\(index)",
                type: .securityGroup,
                action: .delete,
                resourceIdentifier: securityGroupID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildServerGroupDeleteOperations(_ serverGroupIDs: [String]) async -> [PlannedOperation] {
        return serverGroupIDs.enumerated().map { (index, serverGroupID) in
            PlannedOperation(
                id: "servergroup-delete-\(index)",
                type: .serverGroup,
                action: .delete,
                resourceIdentifier: serverGroupID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildKeyPairDeleteOperations(_ keyPairNames: [String]) async -> [PlannedOperation] {
        return keyPairNames.enumerated().map { (index, keyPairName) in
            PlannedOperation(
                id: "keypair-delete-\(index)",
                type: .keyPair,
                action: .delete,
                resourceIdentifier: keyPairName,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    private func buildImageDeleteOperations(_ imageIDs: [String]) async -> [PlannedOperation] {
        return imageIDs.enumerated().map { (index, imageID) in
            PlannedOperation(
                id: "image-delete-\(index)",
                type: .image,
                action: .delete,
                resourceIdentifier: imageID,
                dependencies: [],
                estimatedDuration: OperationAction.delete.estimatedDurationSeconds
            )
        }
    }

    // MARK: - Swift Object Storage Operations

    private func buildSwiftContainerDeleteOperations(_ containerNames: [String]) async -> [PlannedOperation] {
        return containerNames.enumerated().map { (index, name) in
            PlannedOperation(
                id: "swift-container-delete-\(index)",
                type: .swiftContainer,
                action: .delete,
                resourceIdentifier: name,
                dependencies: [],
                estimatedDuration: 3.0
            )
        }
    }

    private func buildSwiftObjectDeleteOperations(containerName: String, objectNames: [String]) async -> [PlannedOperation] {
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
    }
}