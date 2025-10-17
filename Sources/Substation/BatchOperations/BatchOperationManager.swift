import Foundation
import OSClient

// MARK: - Batch Operation Manager

/// Actor-based manager for executing batch operations with dependency resolution and parallel execution
actor BatchOperationManager {

    // MARK: - Properties

    private let client: OSClient
    private let dependencyResolver: ResourceDependencyResolver
    private let maxConcurrency: Int
    private var activeOperations: [String: BatchOperationExecution] = [:]
    private var operationHistory: [String: BatchOperationResult] = [:]

    // Progress tracking
    private var progressCallbacks: [String: (BatchOperationProgress) -> Void] = [:]

    // Cancellation support
    private var cancellationTokens: [String: Bool] = [:]

    // MARK: - Initialization

    public init(client: OSClient, maxConcurrency: Int? = nil) {
        // Use CPU-aware limit if not explicitly specified
        let concurrencyLimit = maxConcurrency ?? SystemCapabilities.optimalBatchOperationLimit()
        self.client = client
        self.dependencyResolver = ResourceDependencyResolver(maxConcurrency: concurrencyLimit)
        self.maxConcurrency = concurrencyLimit
        Logger.shared.logInfo("BatchOperationManager - Initialized with maxConcurrency=\(concurrencyLimit) (cores: \(ProcessInfo.processInfo.activeProcessorCount))")
    }

    // MARK: - Public Interface

    /// Execute a batch operation with progress tracking
    public func execute(
        _ operation: BatchOperationType,
        onProgress: @escaping (BatchOperationProgress) -> Void
    ) async -> BatchOperationResult {
        let operationID = UUID().uuidString
        let startTime = Date()

        Logger.shared.logInfo("BatchOperationManager - Starting batch operation: \(operation.description)")

        // Store progress callback
        progressCallbacks[operationID] = onProgress

        do {
            // Phase 1: Validation
            await updateProgress(operationID: operationID, status: .validating, current: 0, total: 1, description: "Validating operation configuration")

            let validationResult = try await validateOperation(operation)
            if !validationResult.isValid {
                let error = BatchOperationError.invalidConfiguration(validationResult.errors.joined(separator: "; "))
                return createFailureResult(operationID: operationID, operation: operation, startTime: startTime, error: error)
            }

            // Phase 2: Planning
            await updateProgress(operationID: operationID, status: .planning, current: 0, total: 1, description: "Creating execution plan")

            let executionPlan = try await dependencyResolver.createExecutionPlan(for: operation)

            // Phase 3: Execution
            await updateProgress(operationID: operationID, status: .executing, current: 0, total: executionPlan.totalOperations, description: "Beginning execution")

            let executionContext = BatchOperationExecution(
                operationID: operationID,
                type: operation,
                plan: executionPlan,
                startTime: startTime
            )
            activeOperations[operationID] = executionContext

            // Execute the plan
            let results = try await executePlan(executionContext)

            // Phase 4: Completion
            let endTime = Date()
            let successCount = results.filter { $0.status == .completed }.count
            let failureCount = results.filter { $0.status == .failed }.count

            let finalResult = BatchOperationResult(
                operationID: operationID,
                type: operation,
                status: failureCount == 0 ? .completed : (successCount > 0 ? .completed : .failed),
                startTime: startTime,
                endTime: endTime,
                totalOperations: executionPlan.totalOperations,
                successfulOperations: successCount,
                failedOperations: failureCount,
                results: results
            )

            // Clean up
            activeOperations.removeValue(forKey: operationID)
            progressCallbacks.removeValue(forKey: operationID)
            cancellationTokens.removeValue(forKey: operationID)

            // Store in history
            operationHistory[operationID] = finalResult

            Logger.shared.logInfo("BatchOperationManager - Completed batch operation: \(operation.description), Success rate: \(String(format: "%.1f", finalResult.successRate * 100))%")

            return finalResult

        } catch {
            Logger.shared.logError("BatchOperationManager - Batch operation failed: \(error)")
            return createFailureResult(operationID: operationID, operation: operation, startTime: startTime, error: error)
        }
    }

    /// Cancel an active batch operation
    public func cancelOperation(operationID: String) async -> Bool {
        guard activeOperations[operationID] != nil else {
            Logger.shared.logWarning("BatchOperationManager - Attempted to cancel non-existent operation: \(operationID)")
            return false
        }

        cancellationTokens[operationID] = true
        Logger.shared.logInfo("BatchOperationManager - Marked operation for cancellation: \(operationID)")

        await updateProgress(operationID: operationID, status: .cancelled, current: 0, total: 1, description: "Operation cancelled by user")

        return true
    }

    /// Get the status of an active operation
    public func getOperationStatus(operationID: String) -> BatchOperationResult? {
        return activeOperations[operationID]?.getCurrentResult() ?? operationHistory[operationID]
    }

    /// Get list of active operations
    public func getActiveOperations() -> [String] {
        return Array(activeOperations.keys)
    }

    /// Get operation history
    public func getOperationHistory() -> [BatchOperationResult] {
        return Array(operationHistory.values).sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Private Implementation

    private func validateOperation(_ operation: BatchOperationType) async throws -> ValidationResult {
        var errors: [String] = []

        // Basic validation based on operation type
        switch operation {
        case .serverBulkDelete(let serverIDs):
            if serverIDs.isEmpty {
                errors.append("No server IDs provided for deletion")
            }

        case .volumeBulkDelete(let volumeIDs):
            if volumeIDs.isEmpty {
                errors.append("No volume IDs provided for deletion")
            }

        case .swiftContainerBulkDelete(let containerNames):
            if containerNames.isEmpty {
                errors.append("No container names provided for deletion")
            }

        case .swiftObjectBulkDelete(let containerName, let objectNames):
            if containerName.isEmpty {
                errors.append("Container name is required for bulk delete")
            }
            if objectNames.isEmpty {
                errors.append("No objects specified for deletion")
            }

        default:
            // Add validation for other operation types as needed
            break
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    private func executePlan(_ execution: BatchOperationExecution) async throws -> [IndividualOperationResult] {
        var allResults: [IndividualOperationResult] = []
        var completedOperations = 0

        for phase in execution.plan.phases {
            Logger.shared.logInfo("BatchOperationManager - Executing \(phase.description)")

            let phaseResults: [IndividualOperationResult]

            if phase.canRunInParallel {
                phaseResults = try await executePhaseInParallel(phase, execution: execution, completedSoFar: completedOperations)
            } else {
                phaseResults = try await executePhaseSequentially(phase, execution: execution, completedSoFar: completedOperations)
            }

            allResults.append(contentsOf: phaseResults)
            completedOperations += phase.operations.count

            // Check for cancellation
            if cancellationTokens[execution.operationID] == true {
                Logger.shared.logInfo("BatchOperationManager - Operation cancelled during phase: \(phase.description)")
                throw BatchOperationError.cancelled
            }

            // Update progress after phase completion
            await updateProgress(
                operationID: execution.operationID,
                status: .executing,
                current: completedOperations,
                total: execution.plan.totalOperations,
                description: "Completed \(phase.description)"
            )
        }

        return allResults
    }

    private func executePhaseInParallel(
        _ phase: ResourceDependencyResolver.ExecutionPhase,
        execution: BatchOperationExecution,
        completedSoFar: Int
    ) async throws -> [IndividualOperationResult] {

        // Limit concurrency to prevent overwhelming the OpenStack cluster
        let concurrency = min(maxConcurrency, phase.operations.count)

        return try await withThrowingTaskGroup(of: [IndividualOperationResult].self) { group in
            var results: [IndividualOperationResult] = []

            // Process operations in chunks
            let chunks = phase.operations.chunked(into: concurrency)

            for chunk in chunks {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    var chunkResults: [IndividualOperationResult] = []

                    for operation in chunk {
                        // Check for cancellation
                        if await self.cancellationTokens[execution.operationID] == true {
                            throw BatchOperationError.cancelled
                        }

                        let result = await self.executeIndividualOperation(operation, execution: execution)
                        chunkResults.append(result)
                    }

                    return chunkResults
                }
            }

            // Collect results
            for try await chunkResults in group {
                results.append(contentsOf: chunkResults)
            }

            return results
        }
    }

    private func executePhaseSequentially(
        _ phase: ResourceDependencyResolver.ExecutionPhase,
        execution: BatchOperationExecution,
        completedSoFar: Int
    ) async throws -> [IndividualOperationResult] {
        var results: [IndividualOperationResult] = []

        for (index, operation) in phase.operations.enumerated() {
            // Check for cancellation
            if cancellationTokens[execution.operationID] == true {
                throw BatchOperationError.cancelled
            }

            let result = await executeIndividualOperation(operation, execution: execution)
            results.append(result)

            // Update progress for individual operation
            await updateProgress(
                operationID: execution.operationID,
                status: .executing,
                current: completedSoFar + index + 1,
                total: execution.plan.totalOperations,
                description: "Completed \(operation.resourceIdentifier)"
            )
        }

        return results
    }

    private func executeIndividualOperation(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async -> IndividualOperationResult {
        let startTime = Date()

        Logger.shared.logDebug("BatchOperationManager - Executing \(operation.action.rawValue) \(operation.type.rawValue): \(operation.resourceIdentifier)")

        do {
            let resourceID: String?

            switch (operation.type, operation.action) {
            case (.server, .delete):
                try await executeServerDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.network, .delete):
                try await executeNetworkDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.volume, .delete):
                try await executeVolumeDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.port, .attach):
                try await executeNetworkInterfaceAttach(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.subnet, .delete):
                try await executeSubnetDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.router, .delete):
                try await executeRouterDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.port, .delete):
                try await executePortDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.floatingIP, .delete):
                try await executeFloatingIPDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.securityGroup, .delete):
                try await executeSecurityGroupDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.serverGroup, .delete):
                try await executeServerGroupDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.keyPair, .delete):
                try await executeKeyPairDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.image, .delete):
                try await executeImageDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.swiftContainer, .delete):
                try await executeSwiftContainerDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.swiftObject, .delete):
                try await executeSwiftObjectDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            default:
                throw BatchOperationError.executionFailed("Unsupported operation: \(operation.action.rawValue) \(operation.type.rawValue)")
            }

            return IndividualOperationResult(
                operationIndex: 0, // Will be set by caller
                resourceType: operation.type.rawValue,
                resourceID: resourceID,
                resourceName: operation.resourceIdentifier,
                status: .completed,
                startTime: startTime,
                endTime: Date()
            )

        } catch {
            Logger.shared.logError("BatchOperationManager - Failed to execute \(operation.action.rawValue) \(operation.type.rawValue): \(error)")

            return IndividualOperationResult(
                operationIndex: 0,
                resourceType: operation.type.rawValue,
                resourceName: operation.resourceIdentifier,
                status: .failed,
                error: error,
                startTime: startTime,
                endTime: Date()
            )
        }
    }

    // MARK: - Individual Operation Executors

    private func executeServerDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        // Log project ID for debugging
        let projectId = await client.projectID
        Logger.shared.logDebug("BatchOperationManager - Deleting server \(operation.resourceIdentifier) using project ID: \(projectId ?? "nil")")

        do {
            try await client.deleteServer(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            // Treat 404 as success - resource already deleted (idempotent)
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Server \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeNetworkDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deleteNetwork(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Network \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeVolumeDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deleteVolume(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Volume \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeNetworkInterfaceAttach(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        let serverID = operation.metadata["serverID"] ?? ""
        let networkID = operation.metadata["networkID"] ?? ""

        try await client.attachNetwork(
            serverID: serverID,
            networkID: networkID
        )
    }

    private func executeSubnetDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deleteSubnet(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Subnet \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeRouterDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        let routerId = operation.resourceIdentifier

        // Fetch fresh router details to get all current interfaces
        let router = try await client.getRouter(id: routerId, forceRefresh: true)

        // Step 1: Remove all router interfaces (subnet detachments)
        if let interfaces = router.interfaces, !interfaces.isEmpty {
            Logger.shared.logDebug("BatchOperationManager - Removing \(interfaces.count) router interfaces for \(routerId)")
            for interface in interfaces {
                // Use port_id if available (more specific), otherwise subnet_id
                if let portId = interface.portId {
                    try await client.removeRouterInterface(routerId: routerId, portId: portId)
                } else if let subnetId = interface.subnetId {
                    try await client.removeRouterInterface(routerId: routerId, subnetId: subnetId)
                }
            }
        }

        // Step 2: Clear external gateway if present
        if router.externalGatewayInfo != nil {
            Logger.shared.logDebug("BatchOperationManager - Clearing external gateway for router \(routerId)")
            let clearGatewayRequest = UpdateRouterRequest(
                name: nil,
                description: nil,
                adminStateUp: nil,
                externalGatewayInfo: nil,
                routes: nil
            )
            _ = try await client.updateRouter(id: routerId, request: clearGatewayRequest)
        }

        // Step 3: Delete the router
        do {
            try await client.deleteRouter(id: routerId)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Router \(routerId) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executePortDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deletePort(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Port \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeFloatingIPDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deleteFloatingIP(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - FloatingIP \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeSecurityGroupDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deleteSecurityGroup(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - SecurityGroup \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeServerGroupDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deleteServerGroup(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - ServerGroup \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeKeyPairDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deleteKeyPair(name: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - KeyPair \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeImageDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.deleteImage(id: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Image \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    // MARK: - Swift Object Storage Executors

    private func executeSwiftContainerDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        do {
            try await client.swift.deleteContainer(containerName: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Swift container \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    private func executeSwiftObjectDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        guard case .swiftObjectBulkDelete(let containerName, _) = execution.type else {
            throw BatchOperationError.executionFailed("Swift delete operation not found")
        }

        do {
            try await client.swift.deleteObject(containerName: containerName, objectName: operation.resourceIdentifier)
        } catch let error as OpenStackError {
            if case .httpError(404, _) = error {
                Logger.shared.logDebug("BatchOperationManager - Swift object \(operation.resourceIdentifier) already deleted (404)")
                return
            }
            throw error
        }
    }

    // MARK: - Helper Methods

    private func updateProgress(
        operationID: String,
        status: BatchOperationStatus,
        current: Int,
        total: Int,
        description: String? = nil,
        throughput: Double? = nil
    ) async {
        let progress = BatchOperationProgress(
            operationID: operationID,
            currentOperation: current,
            totalOperations: total,
            currentStatus: status,
            currentOperationDescription: description,
            estimatedTimeRemaining: nil, // Could be calculated based on throughput
            throughputPerMinute: throughput
        )

        if let callback = progressCallbacks[operationID] {
            callback(progress)
        }
    }

    private func createFailureResult(
        operationID: String,
        operation: BatchOperationType,
        startTime: Date,
        error: any Error
    ) -> BatchOperationResult {
        return BatchOperationResult(
            operationID: operationID,
            type: operation,
            status: .failed,
            startTime: startTime,
            endTime: Date(),
            totalOperations: 0,
            successfulOperations: 0,
            failedOperations: 1,
            results: [],
            error: error
        )
    }

    private func isValidCIDR(_ cidr: String) -> Bool {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2,
              let prefixLength = Int(parts[1]),
              prefixLength >= 0 && prefixLength <= 32 else {
            return false
        }

        let ipParts = String(parts[0]).split(separator: ".")
        guard ipParts.count == 4 else { return false }

        return ipParts.allSatisfy { part in
            guard let octet = Int(part) else { return false }
            return octet >= 0 && octet <= 255
        }
    }
}

// MARK: - Supporting Types

private struct BatchOperationExecution {
    let operationID: String
    let type: BatchOperationType
    let plan: ResourceDependencyResolver.ExecutionPlan
    let startTime: Date
    var results: [IndividualOperationResult] = []

    func getCurrentResult() -> BatchOperationResult {
        let successCount = results.filter { $0.status == .completed }.count
        let failureCount = results.filter { $0.status == .failed }.count

        return BatchOperationResult(
            operationID: operationID,
            type: type,
            status: results.isEmpty ? .executing : (failureCount == 0 ? .completed : .failed),
            startTime: startTime,
            endTime: nil, // Still running
            totalOperations: plan.totalOperations,
            successfulOperations: successCount,
            failedOperations: failureCount,
            results: results
        )
    }
}