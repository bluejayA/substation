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
        case .serverBulkCreate(let configs):
            if configs.isEmpty {
                errors.append("No server configurations provided")
            }
            for (index, config) in configs.enumerated() {
                if config.name.isEmpty {
                    errors.append("Server \(index): Name is required")
                }
                if config.imageID.isEmpty {
                    errors.append("Server \(index): Image ID is required")
                }
                if config.flavorID.isEmpty {
                    errors.append("Server \(index): Flavor ID is required")
                }
                if config.networkIDs.isEmpty {
                    errors.append("Server \(index): At least one network is required")
                }
            }

        case .serverBulkDelete(let serverIDs):
            if serverIDs.isEmpty {
                errors.append("No server IDs provided for deletion")
            }

        case .networkTopologyDeploy(let topology):
            if topology.network.name.isEmpty {
                errors.append("Network name is required")
            }
            for (index, subnet) in topology.subnets.enumerated() {
                if subnet.name.isEmpty {
                    errors.append("Subnet \(index): Name is required")
                }
                if subnet.cidr.isEmpty {
                    errors.append("Subnet \(index): CIDR is required")
                }
                // Basic CIDR validation
                if !isValidCIDR(subnet.cidr) {
                    errors.append("Subnet \(index): Invalid CIDR format")
                }
            }

        case .volumeBulkCreate(let configs):
            if configs.isEmpty {
                errors.append("No volume configurations provided")
            }
            for (index, config) in configs.enumerated() {
                if config.name.isEmpty {
                    errors.append("Volume \(index): Name is required")
                }
                if config.size <= 0 {
                    errors.append("Volume \(index): Size must be positive")
                }
            }

        case .volumeBulkDelete(let volumeIDs):
            if volumeIDs.isEmpty {
                errors.append("No volume IDs provided for deletion")
            }

        case .volumeBulkAttach(let operations):
            if operations.isEmpty {
                errors.append("No volume attachment operations provided")
            }
            for (index, op) in operations.enumerated() {
                if op.volumeID.isEmpty {
                    errors.append("Attachment \(index): Volume ID is required")
                }
                if op.serverID.isEmpty {
                    errors.append("Attachment \(index): Server ID is required")
                }
            }

        case .volumeBulkDetach(let operations):
            if operations.isEmpty {
                errors.append("No volume detachment operations provided")
            }

        case .swiftContainerBulkCreate(let configs):
            if configs.isEmpty {
                errors.append("No Swift container configurations provided")
            }
            for (index, config) in configs.enumerated() {
                if config.name.isEmpty {
                    errors.append("Container \(index): Name is required")
                }
            }

        case .swiftContainerBulkDelete(let containerNames):
            if containerNames.isEmpty {
                errors.append("No container names provided for deletion")
            }

        case .swiftObjectBulkUpload(let operations):
            if operations.isEmpty {
                errors.append("No upload operations provided")
            }
            for (index, op) in operations.enumerated() {
                if op.objectName.isEmpty {
                    errors.append("Upload \(index): Object name is required")
                }
                if op.localPath.isEmpty {
                    errors.append("Upload \(index): Local path is required")
                }
                if op.containerName.isEmpty {
                    errors.append("Upload \(index): Container name is required")
                }
            }

        case .swiftObjectBulkDownload(let operations):
            if operations.isEmpty {
                errors.append("No download operations provided")
            }
            for (index, op) in operations.enumerated() {
                if op.objectName.isEmpty {
                    errors.append("Download \(index): Object name is required")
                }
                if op.containerName.isEmpty {
                    errors.append("Download \(index): Container name is required")
                }
                if op.localPath.isEmpty {
                    errors.append("Download \(index): Destination path is required")
                }
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
            case (.server, .create):
                resourceID = try await executeServerCreate(operation, execution: execution)

            case (.server, .delete):
                try await executeServerDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.network, .create):
                resourceID = try await executeNetworkCreate(operation, execution: execution)

            case (.network, .delete):
                try await executeNetworkDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.subnet, .create):
                resourceID = try await executeSubnetCreate(operation, execution: execution)

            case (.volume, .create):
                resourceID = try await executeVolumeCreate(operation, execution: execution)

            case (.volume, .delete):
                try await executeVolumeDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.volume, .attach):
                try await executeVolumeAttach(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.volume, .detach):
                try await executeVolumeDetach(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.floatingIP, .create):
                resourceID = try await executeFloatingIPCreate(operation, execution: execution)

            case (.floatingIP, .attach):
                try await executeFloatingIPAssign(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.securityGroup, .create):
                resourceID = try await executeSecurityGroupCreate(operation, execution: execution)

            case (.port, .create):
                resourceID = try await executePortCreate(operation, execution: execution)

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

            case (.swiftContainer, .create):
                resourceID = try await executeSwiftContainerCreate(operation, execution: execution)

            case (.swiftContainer, .delete):
                try await executeSwiftContainerDelete(operation, execution: execution)
                resourceID = operation.resourceIdentifier

            case (.swiftObject, .upload):
                resourceID = try await executeSwiftObjectUpload(operation, execution: execution)

            case (.swiftObject, .download):
                try await executeSwiftObjectDownload(operation, execution: execution)
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

    private func executeServerCreate(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        // Extract configuration from batch operation
        guard case .serverBulkCreate(let configs) = execution.type,
              let config = configs.first(where: { $0.name == operation.resourceIdentifier }) else {
            throw BatchOperationError.executionFailed("Server configuration not found")
        }

        let server = try await client.createServer(
            name: config.name,
            imageRef: config.imageID,
            flavorRef: config.flavorID,
            networkId: config.networkIDs.first ?? "",
            keyName: config.keyPairName,
            userData: config.userData,
            securityGroups: config.securityGroups,
            availabilityZone: config.availabilityZone
        )
        return server.id
    }

    private func executeServerDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteServer(id: operation.resourceIdentifier)
    }

    private func executeNetworkCreate(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        // Extract configuration from batch operation
        guard case .networkTopologyDeploy(let topology) = execution.type else {
            throw BatchOperationError.executionFailed("Network topology configuration not found")
        }

        let network = try await client.createNetwork(
            name: topology.network.name,
            description: nil,
            adminStateUp: topology.network.adminStateUp,
            shared: topology.network.shared,
            external: topology.network.external
        )
        return network.id
    }

    private func executeNetworkDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteNetwork(id: operation.resourceIdentifier)
    }

    private func executeSubnetCreate(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        guard case .networkTopologyDeploy(let topology) = execution.type,
              let subnetConfig = topology.subnets.first(where: { $0.name == operation.resourceIdentifier }) else {
            throw BatchOperationError.executionFailed("Subnet configuration not found")
        }

        // For simplicity, we'll use a placeholder network ID
        // In a real implementation, you'd resolve the network ID from dependencies
        let networkID = "placeholder-network-id"

        let subnet = try await client.createSubnet(
            name: subnetConfig.name,
            networkID: networkID,
            cidr: subnetConfig.cidr,
            ipVersion: 4,
            gatewayIP: subnetConfig.gatewayIP,
            dnsNameservers: subnetConfig.dnsNameservers.isEmpty ? nil : subnetConfig.dnsNameservers,
            enableDhcp: true
        )
        return subnet.id
    }

    private func executeVolumeCreate(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        guard case .volumeBulkCreate(let configs) = execution.type,
              let config = configs.first(where: { $0.name == operation.resourceIdentifier }) else {
            throw BatchOperationError.executionFailed("Volume configuration not found")
        }

        let volume = try await client.createVolumeFromImage(
            name: config.name,
            size: config.size,
            imageRef: nil,
            availabilityZone: config.availabilityZone,
            volumeType: config.volumeType
        )
        return volume.id
    }

    private func executeVolumeDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteVolume(id: operation.resourceIdentifier)
    }

    private func executeVolumeAttach(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        let serverID = operation.metadata["serverID"] ?? ""
        let _ = operation.metadata["device"]

        try await client.attachVolume(
            volumeId: operation.resourceIdentifier,
            serverId: serverID
        )
    }

    private func executeVolumeDetach(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        let serverID = operation.metadata["serverID"] ?? ""

        try await client.detachVolume(
            serverId: serverID,
            volumeId: operation.resourceIdentifier
        )
    }

    private func executeFloatingIPCreate(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        let networkID = operation.metadata["networkID"] ?? ""

        let floatingIP = try await client.createFloatingIP(
            networkID: networkID,
            portID: nil,
            subnetID: nil,
            description: operation.metadata["description"]
        )
        return floatingIP.id
    }

    private func executeFloatingIPAssign(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        let _ = operation.metadata["serverID"] ?? ""
        let portID = operation.metadata["portID"]

        _ = try await client.updateFloatingIP(
            id: operation.resourceIdentifier,
            portID: portID
        )
    }

    private func executeSecurityGroupCreate(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        guard case .securityGroupBulkCreate(let configs) = execution.type,
              let config = configs.first(where: { $0.name == operation.resourceIdentifier }) else {
            throw BatchOperationError.executionFailed("Security group configuration not found")
        }

        let securityGroup = try await client.createSecurityGroup(
            name: config.name,
            description: config.description
        )

        // Create rules if specified
        for rule in config.rules {
            let direction = SecurityGroupDirection(rawValue: rule.direction) ?? .ingress
            let protocolEnum = SecurityGroupProtocol(rawValue: rule.ipProtocol)
            let ethertype = SecurityGroupEtherType.ipv4 // Default to IPv4

            _ = try await client.createSecurityGroupRule(
                securityGroupId: securityGroup.id,
                direction: direction,
                protocol: protocolEnum,
                ethertype: ethertype,
                portRangeMin: rule.portRangeMin,
                portRangeMax: rule.portRangeMax,
                remoteIpPrefix: rule.remoteIPPrefix,
                remoteGroupId: rule.remoteGroupID
            )
        }

        return securityGroup.id
    }

    private func executePortCreate(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        guard case .networkTopologyDeploy(let topology) = execution.type,
              let portConfig = topology.ports.first(where: { $0.name == operation.resourceIdentifier }) else {
            throw BatchOperationError.executionFailed("Port configuration not found")
        }

        // For simplicity, using placeholder network ID
        let networkID = "placeholder-network-id"

        let port = try await client.createPort(
            name: portConfig.name,
            description: nil,
            networkID: networkID,
            subnetID: nil,
            securityGroups: portConfig.securityGroups.isEmpty ? nil : portConfig.securityGroups,
            qosPolicyID: nil
        )
        return port.id
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
        try await client.deleteSubnet(id: operation.resourceIdentifier)
    }

    private func executeRouterDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteRouter(id: operation.resourceIdentifier)
    }

    private func executePortDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deletePort(id: operation.resourceIdentifier)
    }

    private func executeFloatingIPDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteFloatingIP(id: operation.resourceIdentifier)
    }

    private func executeSecurityGroupDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteSecurityGroup(id: operation.resourceIdentifier)
    }

    private func executeServerGroupDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteServerGroup(id: operation.resourceIdentifier)
    }

    private func executeKeyPairDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteKeyPair(name: operation.resourceIdentifier)
    }

    private func executeImageDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.deleteImage(id: operation.resourceIdentifier)
    }

    // MARK: - Swift Object Storage Executors

    private func executeSwiftContainerCreate(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        guard case .swiftContainerBulkCreate(let configs) = execution.type,
              let config = configs.first(where: { $0.name == operation.resourceIdentifier }) else {
            throw BatchOperationError.executionFailed("Swift container configuration not found")
        }

        let request = CreateSwiftContainerRequest(
            name: config.name,
            metadata: config.metadata,
            readACL: config.readACL,
            writeACL: config.writeACL
        )

        try await client.swift.createContainer(request: request)
        return config.name
    }

    private func executeSwiftContainerDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        try await client.swift.deleteContainer(containerName: operation.resourceIdentifier)
    }

    private func executeSwiftObjectUpload(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws -> String {
        guard case .swiftObjectBulkUpload(let operations) = execution.type,
              let uploadOp = operations.first(where: { $0.objectName == operation.resourceIdentifier }) else {
            throw BatchOperationError.executionFailed("Swift upload operation not found")
        }

        // Read file data
        let fileURL = URL(fileURLWithPath: uploadOp.localPath)
        let data = try Data(contentsOf: fileURL)

        let request = UploadSwiftObjectRequest(
            containerName: uploadOp.containerName,
            objectName: uploadOp.objectName,
            data: data,
            contentType: uploadOp.contentType,
            metadata: uploadOp.metadata
        )

        try await client.swift.uploadObject(request: request)
        return uploadOp.objectName
    }

    private func executeSwiftObjectDownload(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        guard case .swiftObjectBulkDownload(let operations) = execution.type,
              let downloadOp = operations.first(where: { $0.objectName == operation.resourceIdentifier }) else {
            throw BatchOperationError.executionFailed("Swift download operation not found")
        }

        let data = try await client.swift.downloadObject(containerName: downloadOp.containerName, objectName: downloadOp.objectName)

        // Write to destination
        let fileURL = URL(fileURLWithPath: downloadOp.localPath)
        try data.write(to: fileURL)
    }

    private func executeSwiftObjectDelete(
        _ operation: ResourceDependencyResolver.PlannedOperation,
        execution: BatchOperationExecution
    ) async throws {
        guard case .swiftObjectBulkDelete(let containerName, _) = execution.type else {
            throw BatchOperationError.executionFailed("Swift delete operation not found")
        }

        try await client.swift.deleteObject(containerName: containerName, objectName: operation.resourceIdentifier)
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