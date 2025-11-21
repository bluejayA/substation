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

    /// Validate a batch operation by extracting resource IDs and delegating to module validation
    ///
    /// This method performs basic validation (empty checks) and then delegates to the
    /// appropriate module's validateBatchOperation method for resource-specific validation.
    ///
    /// - Parameter operation: The batch operation to validate
    /// - Returns: Validation result with any errors
    private func validateOperation(_ operation: BatchOperationType) async throws -> ValidationResult {
        // Use the operation's dynamic resourceInfo property
        let resourceInfo = operation.resourceInfo

        // Basic validation: check if resources were provided
        if resourceInfo.resourceIDs.isEmpty {
            return ValidationResult(
                isValid: false,
                errors: ["No resources provided for \(operation.description)"]
            )
        }

        // Delegate to module's validateBatchOperation for resource-specific validation
        let moduleValidation = await validateViaRegistry(
            moduleID: resourceInfo.moduleID,
            resourceIDs: resourceInfo.resourceIDs
        )

        return ValidationResult(
            isValid: moduleValidation.isValid,
            errors: moduleValidation.errors
        )
    }

    /// Validate via the BatchOperationRegistry by delegating to module provider
    ///
    /// - Parameters:
    ///   - moduleID: The module identifier to look up
    ///   - resourceIDs: The resource IDs to validate
    /// - Returns: Validation result from the module
    @MainActor
    private func validateViaRegistry(moduleID: String, resourceIDs: [String]) async -> BatchOperationValidation {
        guard let provider = BatchOperationRegistry.shared.provider(for: moduleID) else {
            Logger.shared.logWarning("BatchOperationManager - No provider for validation: \(moduleID)")
            // If no provider, just do basic validation (already passed empty check)
            return BatchOperationValidation(isValid: true, errors: [])
        }

        return await provider.validateBatchOperation(resourceIDs: resourceIDs)
    }

    private func executePlan(_ execution: BatchOperationExecution) async throws -> [BatchIndividualOperationResult] {
        var allResults: [BatchIndividualOperationResult] = []
        var completedOperations = 0

        for phase in execution.plan.phases {
            Logger.shared.logInfo("BatchOperationManager - Executing \(phase.description)")

            let phaseResults: [BatchIndividualOperationResult]

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
    ) async throws -> [BatchIndividualOperationResult] {

        // Limit concurrency to prevent overwhelming the OpenStack cluster
        let concurrency = min(maxConcurrency, phase.operations.count)

        return try await withThrowingTaskGroup(of: [BatchIndividualOperationResult].self) { group in
            var results: [BatchIndividualOperationResult] = []

            // Process operations in chunks
            let chunks = phase.operations.chunked(into: concurrency)

            for chunk in chunks {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    var chunkResults: [BatchIndividualOperationResult] = []

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
    ) async throws -> [BatchIndividualOperationResult] {
        var results: [BatchIndividualOperationResult] = []

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

    /// Execute an individual operation by delegating to the appropriate module provider
    ///
    /// This method maps the resource type to the corresponding module identifier,
    /// retrieves the provider from the BatchOperationRegistry, and delegates
    /// execution to that provider.
    ///
    /// - Parameters:
    ///   - operation: The planned operation to execute
    ///   - execution: The batch execution context
    /// - Returns: Result of the individual operation
    private func executeIndividualOperation(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async -> BatchIndividualOperationResult {
        let startTime = Date()

        Logger.shared.logDebug("BatchOperationManager - Executing \(operation.action.rawValue) \(operation.type.rawValue): \(operation.resourceIdentifier)")

        // Get module provider from registry using the resource type's dynamic moduleIdentifier
        let providerResults = await executeBatchDeleteViaRegistry(
            moduleID: operation.type.moduleIdentifier,
            resourceID: operation.resourceIdentifier
        )

        // Check if provider was found (empty results with no provider)
        if providerResults == nil {
            return BatchIndividualOperationResult(
                operationIndex: 0,
                resourceType: operation.type.rawValue,
                resourceName: operation.resourceIdentifier,
                status: .failed,
                error: BatchOperationError.executionFailed("No provider registered for \(operation.type.moduleIdentifier)"),
                startTime: startTime,
                endTime: Date()
            )
        }

        // Convert result
        if let result = providerResults?.first {
            return BatchIndividualOperationResult(
                operationIndex: 0,
                resourceType: operation.type.rawValue,
                resourceID: result.success ? operation.resourceIdentifier : nil,
                resourceName: operation.resourceIdentifier,
                status: result.success ? .completed : .failed,
                error: result.error.map { BatchOperationError.executionFailed($0) },
                startTime: startTime,
                endTime: Date()
            )
        } else {
            return BatchIndividualOperationResult(
                operationIndex: 0,
                resourceType: operation.type.rawValue,
                resourceName: operation.resourceIdentifier,
                status: .failed,
                error: BatchOperationError.executionFailed("No result from provider"),
                startTime: startTime,
                endTime: Date()
            )
        }
    }

    // MARK: - Registry Delegation

    /// Execute batch delete via the BatchOperationRegistry
    ///
    /// This method handles the MainActor isolation required by the registry
    /// and providers, executing the batch delete operation on the appropriate
    /// module provider.
    ///
    /// - Parameters:
    ///   - moduleID: The module identifier to look up
    ///   - resourceID: The resource ID to delete
    /// - Returns: Array of results, or nil if no provider found
    @MainActor
    private func executeBatchDeleteViaRegistry(
        moduleID: String,
        resourceID: String
    ) async -> [IndividualOperationResult]? {
        guard let provider = BatchOperationRegistry.shared.provider(for: moduleID) else {
            Logger.shared.logError("BatchOperationManager - No provider found for module: \(moduleID)")
            return nil
        }

        return await provider.executeBatchDelete(
            resourceIDs: [resourceID],
            client: client
        )
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
}

// MARK: - Supporting Types

/// Internal validation result for batch operations
private struct ValidationResult {
    let isValid: Bool
    let errors: [String]
}

private struct BatchOperationExecution {
    let operationID: String
    let type: BatchOperationType
    let plan: ResourceDependencyResolver.ExecutionPlan
    let startTime: Date
    var results: [BatchIndividualOperationResult] = []

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