import Foundation
import SwiftTUI
import CrossPlatformTimer

// MARK: - Progress Tracking Models

/// Represents the current state of a multi-stage operation
public struct OperationProgress: Sendable {
    let operationId: String
    let operationName: String
    let currentStage: Int
    let totalStages: Int
    let stageName: String
    let stageProgress: Double // 0.0 to 1.0 for current stage
    let overallProgress: Double // 0.0 to 1.0 for entire operation
    let estimatedTimeRemaining: TimeInterval?
    let message: String
    let startTime: Date
    let isComplete: Bool
    let isCancellable: Bool

    var progressPercentage: Int {
        return Int(overallProgress * 100)
    }

    var stageProgressPercentage: Int {
        return Int(stageProgress * 100)
    }
}

/// Defines the stages for different types of operations
public struct OperationStage: Sendable {
    let name: String
    let description: String
    let estimatedDuration: TimeInterval
    let weight: Double // Relative weight for progress calculation (0.0 to 1.0)
}

/// Pre-defined operation types with their standard stages
public enum OperationType {
    case serverCreation
    case serverDeletion
    case volumeAttachment
    case volumeDetachment
    case volumeCreation
    case networkCreation
    case dataRefresh
    case batchOperation(itemCount: Int)
    case batchServerCreate(serverCount: Int)
    case batchServerDelete(serverCount: Int)
    case batchVolumeCreate(volumeCount: Int)
    case batchVolumeDelete(volumeCount: Int)
    case batchVolumeAttach(attachmentCount: Int)
    case batchVolumeDetach(detachmentCount: Int)
    case batchNetworkTopology(resourceCount: Int)
    case batchResourceCleanup(resourceCount: Int)
    case batchFloatingIPCreate(ipCount: Int)
    case batchFloatingIPAssign(assignmentCount: Int)

    var stages: [OperationStage] {
        switch self {
        case .serverCreation:
            return [
                OperationStage(name: "Scheduling", description: "Requesting compute resources", estimatedDuration: 5.0, weight: 0.1),
                OperationStage(name: "Building", description: "Preparing server instance", estimatedDuration: 20.0, weight: 0.4),
                OperationStage(name: "Networking", description: "Configuring network interfaces", estimatedDuration: 10.0, weight: 0.3),
                OperationStage(name: "Finalizing", description: "Completing server setup", estimatedDuration: 5.0, weight: 0.2)
            ]
        case .serverDeletion:
            return [
                OperationStage(name: "Stopping", description: "Gracefully shutting down server", estimatedDuration: 15.0, weight: 0.4),
                OperationStage(name: "Cleanup", description: "Removing associated resources", estimatedDuration: 10.0, weight: 0.6)
            ]
        case .volumeAttachment:
            return [
                OperationStage(name: "Preparing", description: "Preparing volume for attachment", estimatedDuration: 5.0, weight: 0.3),
                OperationStage(name: "Attaching", description: "Attaching volume to server", estimatedDuration: 15.0, weight: 0.4),
                OperationStage(name: "Configuring", description: "Configuring device mapping", estimatedDuration: 10.0, weight: 0.3)
            ]
        case .volumeDetachment:
            return [
                OperationStage(name: "Unmounting", description: "Safely unmounting volume", estimatedDuration: 10.0, weight: 0.4),
                OperationStage(name: "Detaching", description: "Detaching volume from server", estimatedDuration: 15.0, weight: 0.6)
            ]
        case .volumeCreation:
            return [
                OperationStage(name: "Allocating", description: "Allocating storage space", estimatedDuration: 10.0, weight: 0.3),
                OperationStage(name: "Creating", description: "Creating volume from source", estimatedDuration: 30.0, weight: 0.7)
            ]
        case .networkCreation:
            return [
                OperationStage(name: "Planning", description: "Planning network topology", estimatedDuration: 5.0, weight: 0.2),
                OperationStage(name: "Creating", description: "Creating network infrastructure", estimatedDuration: 20.0, weight: 0.5),
                OperationStage(name: "Configuring", description: "Configuring DHCP and routing", estimatedDuration: 15.0, weight: 0.3)
            ]
        case .dataRefresh:
            return [
                OperationStage(name: "Fetching", description: "Retrieving updated data", estimatedDuration: 8.0, weight: 0.7),
                OperationStage(name: "Processing", description: "Processing and caching data", estimatedDuration: 2.0, weight: 0.3)
            ]
        case .batchOperation(let itemCount):
            let estimatedTimePerItem: TimeInterval = 3.0
            return [
                OperationStage(name: "Processing", description: "Processing \(itemCount) items", estimatedDuration: Double(itemCount) * estimatedTimePerItem, weight: 1.0)
            ]

        case .batchServerCreate(let serverCount):
            let timePerServer: TimeInterval = 60.0 // ~1 minute per server
            return [
                OperationStage(name: "Validating", description: "Validating server configurations", estimatedDuration: 5.0, weight: 0.05),
                OperationStage(name: "Planning", description: "Creating execution plan", estimatedDuration: 5.0, weight: 0.05),
                OperationStage(name: "Creating", description: "Creating \(serverCount) servers", estimatedDuration: Double(serverCount) * timePerServer, weight: 0.85),
                OperationStage(name: "Finalizing", description: "Finalizing server configurations", estimatedDuration: 10.0, weight: 0.05)
            ]

        case .batchServerDelete(let serverCount):
            let timePerServer: TimeInterval = 30.0 // ~30 seconds per server deletion
            return [
                OperationStage(name: "Planning", description: "Planning deletion order", estimatedDuration: 3.0, weight: 0.1),
                OperationStage(name: "Deleting", description: "Deleting \(serverCount) servers", estimatedDuration: Double(serverCount) * timePerServer, weight: 0.9)
            ]

        case .batchVolumeCreate(let volumeCount):
            let timePerVolume: TimeInterval = 45.0 // ~45 seconds per volume
            return [
                OperationStage(name: "Validating", description: "Validating volume configurations", estimatedDuration: 3.0, weight: 0.1),
                OperationStage(name: "Creating", description: "Creating \(volumeCount) volumes", estimatedDuration: Double(volumeCount) * timePerVolume, weight: 0.9)
            ]

        case .batchVolumeDelete(let volumeCount):
            let timePerVolume: TimeInterval = 20.0 // ~20 seconds per volume deletion
            return [
                OperationStage(name: "Deleting", description: "Deleting \(volumeCount) volumes", estimatedDuration: Double(volumeCount) * timePerVolume, weight: 1.0)
            ]

        case .batchVolumeAttach(let attachmentCount):
            let timePerAttachment: TimeInterval = 30.0 // ~30 seconds per attachment
            return [
                OperationStage(name: "Preparing", description: "Preparing volume attachments", estimatedDuration: 5.0, weight: 0.1),
                OperationStage(name: "Attaching", description: "Attaching \(attachmentCount) volumes", estimatedDuration: Double(attachmentCount) * timePerAttachment, weight: 0.9)
            ]

        case .batchVolumeDetach(let detachmentCount):
            let timePerDetachment: TimeInterval = 15.0 // ~15 seconds per detachment
            return [
                OperationStage(name: "Detaching", description: "Detaching \(detachmentCount) volumes", estimatedDuration: Double(detachmentCount) * timePerDetachment, weight: 1.0)
            ]

        case .batchNetworkTopology(let resourceCount):
            let timePerResource: TimeInterval = 25.0 // ~25 seconds per network resource
            return [
                OperationStage(name: "Planning", description: "Planning network topology", estimatedDuration: 10.0, weight: 0.1),
                OperationStage(name: "Creating Networks", description: "Creating network infrastructure", estimatedDuration: 30.0, weight: 0.2),
                OperationStage(name: "Creating Subnets", description: "Creating subnets", estimatedDuration: Double(resourceCount) * 0.4 * timePerResource, weight: 0.4),
                OperationStage(name: "Creating Ports", description: "Creating ports and interfaces", estimatedDuration: Double(resourceCount) * 0.3 * timePerResource, weight: 0.3)
            ]

        case .batchResourceCleanup(let resourceCount):
            let timePerResource: TimeInterval = 20.0 // ~20 seconds per resource cleanup
            return [
                OperationStage(name: "Analyzing", description: "Analyzing resources for cleanup", estimatedDuration: 15.0, weight: 0.1),
                OperationStage(name: "Planning", description: "Planning safe deletion order", estimatedDuration: 10.0, weight: 0.1),
                OperationStage(name: "Cleaning", description: "Cleaning up \(resourceCount) resources", estimatedDuration: Double(resourceCount) * timePerResource, weight: 0.8)
            ]

        case .batchFloatingIPCreate(let ipCount):
            let timePerIP: TimeInterval = 10.0 // ~10 seconds per floating IP
            return [
                OperationStage(name: "Creating", description: "Creating \(ipCount) floating IPs", estimatedDuration: Double(ipCount) * timePerIP, weight: 1.0)
            ]

        case .batchFloatingIPAssign(let assignmentCount):
            let timePerAssignment: TimeInterval = 15.0 // ~15 seconds per assignment
            return [
                OperationStage(name: "Assigning", description: "Assigning \(assignmentCount) floating IPs", estimatedDuration: Double(assignmentCount) * timePerAssignment, weight: 1.0)
            ]
        }
    }
}

// MARK: - Progress Indicator Actor

/// Thread-safe progress tracking system for long-running operations
@MainActor
public final class ProgressIndicator: Sendable {

    // MARK: - Public Properties

    public private(set) var activeOperations: [String: OperationProgress] = [:]
    public private(set) var completedOperations: [String: OperationProgress] = [:]

    // MARK: - Private Properties

    private var operationTimers: [String: AnyObject] = [:]
    private var progressUpdateHandlers: [String: (OperationProgress) -> Void] = [:]
    private var completionHandlers: [String: (OperationProgress, Bool) -> Void] = [:]

    // Performance tracking
    private var operationMetrics: [String: OperationMetrics] = [:]

    // MARK: - Batch Operation Support

    /// Tracks batch operation progress from BatchOperationProgress
    public func updateBatchProgress(_ batchProgress: BatchOperationProgress) {
        let operationId = batchProgress.operationID

        // Map batch status to our progress system
        let stageName: String
        let stageProgress: Double
        let message: String

        switch batchProgress.currentStatus {
        case .pending:
            stageName = "Pending"
            stageProgress = 0.0
            message = "Batch operation queued"
        case .validating:
            stageName = "Validating"
            stageProgress = 0.1
            message = "Validating batch operation configuration"
        case .planning:
            stageName = "Planning"
            stageProgress = 0.2
            message = "Creating execution plan with dependency resolution"
        case .executing:
            stageName = "Executing"
            stageProgress = batchProgress.completionPercentage
            message = batchProgress.currentOperationDescription ?? "Processing batch operations"
        case .completed:
            stageName = "Complete"
            stageProgress = 1.0
            message = "Batch operation completed successfully"
        case .failed:
            stageName = "Failed"
            stageProgress = batchProgress.completionPercentage
            message = "Batch operation failed"
        case .cancelled:
            stageName = "Cancelled"
            stageProgress = batchProgress.completionPercentage
            message = "Batch operation was cancelled"
        case .rollingBack:
            stageName = "Rolling Back"
            stageProgress = 0.5
            message = "Rolling back failed operations"
        case .rolledBack:
            stageName = "Rolled Back"
            stageProgress = 1.0
            message = "Batch operation rolled back successfully"
        }

        // Update or create progress entry
        if var operation = activeOperations[operationId] {
            // Update existing operation
            let overallProgress = batchProgress.completionPercentage

            operation = OperationProgress(
                operationId: operation.operationId,
                operationName: operation.operationName,
                currentStage: operation.currentStage,
                totalStages: operation.totalStages,
                stageName: stageName,
                stageProgress: stageProgress,
                overallProgress: overallProgress,
                estimatedTimeRemaining: batchProgress.estimatedTimeRemaining,
                message: message,
                startTime: operation.startTime,
                isComplete: !batchProgress.currentStatus.isActive,
                isCancellable: batchProgress.currentStatus.isActive
            )

            activeOperations[operationId] = operation
            progressUpdateHandlers[operationId]?(operation)

            // Handle completion
            if !batchProgress.currentStatus.isActive {
                let success = batchProgress.currentStatus == .completed
                completeOperation(operationId: operationId, success: success, finalMessage: message)
            }
        } else if batchProgress.currentStatus.isActive {
            // Create new operation tracking for active batch operation
            let progress = OperationProgress(
                operationId: operationId,
                operationName: "Batch Operation (\(batchProgress.totalOperations) items)",
                currentStage: 0,
                totalStages: 1,
                stageName: stageName,
                stageProgress: stageProgress,
                overallProgress: batchProgress.completionPercentage,
                estimatedTimeRemaining: batchProgress.estimatedTimeRemaining,
                message: message,
                startTime: Date(),
                isComplete: false,
                isCancellable: true
            )

            activeOperations[operationId] = progress
        }
    }

    /// Starts tracking a batch operation with proper type information
    public func startBatchOperation(
        id: String,
        type: OperationType,
        name: String,
        totalItems: Int,
        isCancellable: Bool = true
    ) {
        Logger.shared.logInfo("ProgressIndicator - Starting batch operation: \(name) (\(totalItems) items)")
        startOperation(id: id, type: type, name: name, isCancellable: isCancellable)
    }

    /// Updates batch operation with current item progress
    public func updateBatchOperationProgress(
        operationId: String,
        currentItem: Int,
        totalItems: Int,
        itemDescription: String? = nil,
        throughputPerMinute: Double? = nil
    ) {
        guard let operation = activeOperations[operationId],
              !operation.isComplete else { return }

        let itemProgress = totalItems > 0 ? Double(currentItem) / Double(totalItems) : 0.0
        let message = itemDescription ?? "Processing item \(currentItem) of \(totalItems)"

        // Add throughput information to message if available
        let enhancedMessage: String
        if let throughput = throughputPerMinute {
            enhancedMessage = "\(message) (~\(String(format: "%.1f", throughput)) items/min)"
        } else {
            enhancedMessage = message
        }

        updateStageProgress(operationId: operationId, stageProgress: itemProgress, message: enhancedMessage)
    }

    /// Get batch operation specific metrics
    public func getBatchOperationMetrics(operationId: String) -> (
        itemsProcessed: Int,
        totalItems: Int,
        throughputPerMinute: Double?,
        estimatedTimeRemaining: TimeInterval?
    )? {
        guard let operation = getProgress(for: operationId) else { return nil }

        // Extract metrics from operation progress
        let totalItems = extractTotalItemsFromMessage(operation.message)
        let itemsProcessed = Int(operation.overallProgress * Double(totalItems))

        // Calculate throughput if we have timing information
        let elapsed = Date().timeIntervalSince(operation.startTime)
        let throughput = elapsed > 0 ? (Double(itemsProcessed) / elapsed) * 60.0 : nil

        return (
            itemsProcessed: itemsProcessed,
            totalItems: totalItems,
            throughputPerMinute: throughput,
            estimatedTimeRemaining: operation.estimatedTimeRemaining
        )
    }

    // MARK: - Operation Management

    /// Starts tracking a new operation
    public func startOperation(id: String, type: OperationType, name: String, isCancellable: Bool = true) {
        let stages = type.stages
        let progress = OperationProgress(
            operationId: id,
            operationName: name,
            currentStage: 0,
            totalStages: stages.count,
            stageName: stages.first?.name ?? "Starting",
            stageProgress: 0.0,
            overallProgress: 0.0,
            estimatedTimeRemaining: stages.reduce(0) { $0 + $1.estimatedDuration },
            message: stages.first?.description ?? "Starting operation",
            startTime: Date(),
            isComplete: false,
            isCancellable: isCancellable
        )

        activeOperations[id] = progress
        operationMetrics[id] = OperationMetrics(stages: stages, startTime: Date())

        // Start automatic progress updates for realistic progress indication
        startProgressTimer(for: id, stages: stages)
    }

    /// Updates progress for a specific stage
    public func updateStageProgress(operationId: String, stageProgress: Double, message: String? = nil) {
        guard var operation = activeOperations[operationId],
              !operation.isComplete else { return }

        let clampedProgress = max(0.0, min(1.0, stageProgress))
        let stages = getStages(for: operation)
        let overallProgress = calculateOverallProgress(currentStage: operation.currentStage,
                                                     stageProgress: clampedProgress,
                                                     stages: stages)

        operation = OperationProgress(
            operationId: operation.operationId,
            operationName: operation.operationName,
            currentStage: operation.currentStage,
            totalStages: operation.totalStages,
            stageName: operation.stageName,
            stageProgress: clampedProgress,
            overallProgress: overallProgress,
            estimatedTimeRemaining: calculateEstimatedTimeRemaining(for: operation, stages: stages),
            message: message ?? operation.message,
            startTime: operation.startTime,
            isComplete: false,
            isCancellable: operation.isCancellable
        )

        activeOperations[operationId] = operation
        progressUpdateHandlers[operationId]?(operation)
    }

    /// Advances to the next stage of an operation
    public func advanceToNextStage(operationId: String, message: String? = nil) {
        guard var operation = activeOperations[operationId],
              !operation.isComplete else { return }

        let stages = getStages(for: operation)
        let nextStage = operation.currentStage + 1

        if nextStage >= stages.count {
            // Operation is complete
            completeOperation(operationId: operationId, success: true, finalMessage: message)
            return
        }

        let newStageName = stages[nextStage].name
        let newMessage = message ?? stages[nextStage].description
        let overallProgress = calculateOverallProgress(currentStage: nextStage,
                                                     stageProgress: 0.0,
                                                     stages: stages)

        operation = OperationProgress(
            operationId: operation.operationId,
            operationName: operation.operationName,
            currentStage: nextStage,
            totalStages: operation.totalStages,
            stageName: newStageName,
            stageProgress: 0.0,
            overallProgress: overallProgress,
            estimatedTimeRemaining: calculateEstimatedTimeRemaining(for: operation, stages: stages),
            message: newMessage,
            startTime: operation.startTime,
            isComplete: false,
            isCancellable: operation.isCancellable
        )

        activeOperations[operationId] = operation
        progressUpdateHandlers[operationId]?(operation)
    }

    /// Completes an operation
    public func completeOperation(operationId: String, success: Bool, finalMessage: String? = nil) {
        guard var operation = activeOperations[operationId] else { return }

        // Stop timer
        if let timer = operationTimers[operationId] {
            invalidateTimer(timer)
        }
        operationTimers.removeValue(forKey: operationId)

        // Update metrics
        if var metrics = operationMetrics[operationId] {
            metrics.endTime = Date()
            metrics.wasSuccessful = success
            operationMetrics[operationId] = metrics
        }

        // Create final progress state
        operation = OperationProgress(
            operationId: operation.operationId,
            operationName: operation.operationName,
            currentStage: success ? operation.totalStages - 1 : operation.currentStage,
            totalStages: operation.totalStages,
            stageName: success ? "Complete" : "Failed",
            stageProgress: success ? 1.0 : operation.stageProgress,
            overallProgress: success ? 1.0 : operation.overallProgress,
            estimatedTimeRemaining: 0,
            message: finalMessage ?? (success ? "Operation completed successfully" : "Operation failed"),
            startTime: operation.startTime,
            isComplete: true,
            isCancellable: false
        )

        // Move to completed operations
        activeOperations.removeValue(forKey: operationId)
        completedOperations[operationId] = operation

        // Call completion handler
        completionHandlers[operationId]?(operation, success)

        // Cleanup handlers
        progressUpdateHandlers.removeValue(forKey: operationId)
        completionHandlers.removeValue(forKey: operationId)

        // Cleanup completed operations after delay
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            completedOperations.removeValue(forKey: operationId)
            operationMetrics.removeValue(forKey: operationId)
        }
    }

    /// Cancels an active operation
    public func cancelOperation(operationId: String, reason: String = "Operation cancelled by user") {
        guard let operation = activeOperations[operationId],
              operation.isCancellable else { return }

        completeOperation(operationId: operationId, success: false, finalMessage: reason)
    }

    /// Sets a progress update handler for an operation
    public func setProgressUpdateHandler(operationId: String, handler: @escaping (OperationProgress) -> Void) {
        progressUpdateHandlers[operationId] = handler
    }

    /// Sets a completion handler for an operation
    public func setCompletionHandler(operationId: String, handler: @escaping (OperationProgress, Bool) -> Void) {
        completionHandlers[operationId] = handler
    }

    // MARK: - Query Methods

    /// Gets the current progress for an operation
    public func getProgress(for operationId: String) -> OperationProgress? {
        return activeOperations[operationId] ?? completedOperations[operationId]
    }

    /// Checks if an operation is currently active
    public func isOperationActive(_ operationId: String) -> Bool {
        return activeOperations[operationId] != nil
    }

    /// Gets all active operation IDs
    public var activeOperationIds: [String] {
        return Array(activeOperations.keys)
    }

    /// Gets performance metrics for an operation
    public func getMetrics(for operationId: String) -> OperationMetrics? {
        return operationMetrics[operationId]
    }

    // MARK: - Cleanup

    /// Clears all completed operations and metrics
    public func clearCompletedOperations() {
        completedOperations.removeAll()
        operationMetrics = operationMetrics.filter { activeOperations.keys.contains($0.key) }
    }

    /// Cancels all active operations
    public func cancelAllOperations(reason: String = "All operations cancelled") {
        let activeIds = Array(activeOperations.keys)
        for operationId in activeIds {
            cancelOperation(operationId: operationId, reason: reason)
        }
    }

    // MARK: - Private Methods

    private func startProgressTimer(for operationId: String, stages: [OperationStage]) {
        let timer = createCompatibleTimer(interval: 0.5, repeats: true) { [weak self] in
            Task { @MainActor in
                self?.updateAutomaticProgress(for: operationId, stages: stages)
            }
        }
        operationTimers[operationId] = timer
    }

    private func updateAutomaticProgress(for operationId: String, stages: [OperationStage]) {
        guard let operation = activeOperations[operationId],
              !operation.isComplete else { return }

        // Simulate realistic progress updates
        let currentStage = stages[operation.currentStage]
        let elapsed = Date().timeIntervalSince(operation.startTime)
        let stageStartTime = calculateStageStartTime(stageIndex: operation.currentStage, stages: stages)
        let stageElapsed = elapsed - stageStartTime
        let stageProgress = min(0.95, stageElapsed / currentStage.estimatedDuration) // Cap at 95% for automatic updates

        if stageProgress != operation.stageProgress {
            updateStageProgress(operationId: operationId, stageProgress: stageProgress)
        }
    }

    private func calculateOverallProgress(currentStage: Int, stageProgress: Double, stages: [OperationStage]) -> Double {
        let completedStagesWeight = stages.prefix(currentStage).reduce(0) { $0 + $1.weight }
        let currentStageWeight = stages[currentStage].weight * stageProgress
        return completedStagesWeight + currentStageWeight
    }

    private func calculateEstimatedTimeRemaining(for operation: OperationProgress, stages: [OperationStage]) -> TimeInterval {
        let elapsed = Date().timeIntervalSince(operation.startTime)
        let currentStage = stages[operation.currentStage]
        let stageStartTime = calculateStageStartTime(stageIndex: operation.currentStage, stages: stages)
        let stageElapsed = elapsed - stageStartTime
        let stageRemaining = max(0, currentStage.estimatedDuration - stageElapsed)

        // Add remaining time for future stages
        let futureStagesTime = stages.dropFirst(operation.currentStage + 1).reduce(0) { $0 + $1.estimatedDuration }

        return stageRemaining + futureStagesTime
    }

    private func calculateStageStartTime(stageIndex: Int, stages: [OperationStage]) -> TimeInterval {
        return stages.prefix(stageIndex).reduce(0) { $0 + $1.estimatedDuration }
    }

    private func getStages(for operation: OperationProgress) -> [OperationStage] {
        // This would normally come from the operation type, but since we don't store it,
        // we'll infer it from the operation name or use a default
        return inferOperationType(from: operation).stages
    }

    private func inferOperationType(from operation: OperationProgress) -> OperationType {
        let name = operation.operationName.lowercased()

        // Check for batch operations first
        if name.contains("batch") {
            let itemCount = extractTotalItemsFromMessage(operation.message)

            if name.contains("server") && name.contains("creat") {
                return .batchServerCreate(serverCount: itemCount)
            } else if name.contains("server") && (name.contains("delet") || name.contains("destroy")) {
                return .batchServerDelete(serverCount: itemCount)
            } else if name.contains("volume") && name.contains("creat") {
                return .batchVolumeCreate(volumeCount: itemCount)
            } else if name.contains("volume") && (name.contains("delet") || name.contains("destroy")) {
                return .batchVolumeDelete(volumeCount: itemCount)
            } else if name.contains("volume") && name.contains("attach") {
                return .batchVolumeAttach(attachmentCount: itemCount)
            } else if name.contains("volume") && name.contains("detach") {
                return .batchVolumeDetach(detachmentCount: itemCount)
            } else if name.contains("network") && name.contains("topology") {
                return .batchNetworkTopology(resourceCount: itemCount)
            } else if name.contains("cleanup") {
                return .batchResourceCleanup(resourceCount: itemCount)
            } else if name.contains("floating") && name.contains("creat") {
                return .batchFloatingIPCreate(ipCount: itemCount)
            } else if name.contains("floating") && name.contains("assign") {
                return .batchFloatingIPAssign(assignmentCount: itemCount)
            } else {
                return .batchOperation(itemCount: itemCount)
            }
        }

        // Single operations
        if name.contains("server") && name.contains("creat") {
            return .serverCreation
        } else if name.contains("server") && (name.contains("delet") || name.contains("destroy")) {
            return .serverDeletion
        } else if name.contains("volume") && name.contains("attach") {
            return .volumeAttachment
        } else if name.contains("volume") && name.contains("detach") {
            return .volumeDetachment
        } else if name.contains("volume") && name.contains("creat") {
            return .volumeCreation
        } else if name.contains("network") && name.contains("creat") {
            return .networkCreation
        } else if name.contains("refresh") || name.contains("load") {
            return .dataRefresh
        } else {
            return .dataRefresh // Default fallback
        }
    }

    private func extractTotalItemsFromMessage(_ message: String) -> Int {
        // Try to extract numbers from messages like "Processing 10 items" or "Creating 5 servers"
        let numbers = message.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 }

        return numbers.first ?? 1 // Default to 1 if no number found
    }
}

// MARK: - Performance Metrics

/// Tracks performance metrics for operations
public struct OperationMetrics {
    let stages: [OperationStage]
    let startTime: Date
    var endTime: Date?
    var wasSuccessful: Bool?

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    var estimatedDuration: TimeInterval {
        return stages.reduce(0) { $0 + $1.estimatedDuration }
    }

    var accuracyRatio: Double? {
        guard let duration = duration else { return nil }
        return estimatedDuration / duration
    }
}