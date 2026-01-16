import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Backward Compatibility Aliases

/// Primary alias for the main OpenStack client
public typealias OSClient = OpenStackClient
public typealias OSClientLogger = OpenStackClientLogger

// MARK: - Extended Compatibility Operations
// The following extensions provide additional methods not in the core consolidated client

extension OpenStackClient {

    // MARK: - Server Group Operations

    /// Delete a server group
    public func deleteServerGroup(id: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.deleteServerGroup(id: id)
        }
    }

    // MARK: - Quota Operations

    /// Get compute quotas for the current project
    public func getComputeQuotas() async throws -> ComputeQuotaSet {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            guard let projectId = await self.projectID else {
                throw OpenStackError.configurationError("Project ID not available - ensure authentication is complete")
            }
            let quotaSet = try await nova.getQuotas(projectId: projectId)

            // Convert QuotaSet to ComputeQuotaSet
            return ComputeQuotaSet(
                cores: quotaSet.cores,
                instances: quotaSet.instances,
                ram: quotaSet.ram,
                keyPairs: quotaSet.keyPairs,
                securityGroups: quotaSet.securityGroups,
                securityGroupRules: quotaSet.securityGroupRules,
                serverGroups: quotaSet.serverGroups,
                serverGroupMembers: quotaSet.serverGroupMembers,
                floatingIps: quotaSet.floatingIps
            )
        }
    }

    /// Get network quotas for the current project
    public func getNetworkQuotas() async throws -> NetworkQuotaSet {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            guard let projectId = await self.projectID else {
                throw OpenStackError.configurationError("Project ID not available - ensure authentication is complete")
            }
            return try await neutron.getQuotas(projectId: projectId)
        }
    }

    /// Get volume quotas for the current project
    public func getVolumeQuotas() async throws -> VolumeQuotaSet {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            guard let projectId = await self.projectID else {
                throw OpenStackError.configurationError("Project ID not available - ensure authentication is complete")
            }
            return try await cinder.getQuotas(projectId: projectId)
        }
    }

    /// Get compute limits (alias for getComputeQuotas for compatibility)
    public func getComputeLimits() async throws -> ComputeQuotaSet {
        return try await getComputeQuotas()
    }

    // MARK: - Security Group Operations

    /// Create a security group rule
    public func createSecurityGroupRule(request: CreateSecurityGroupRuleRequest) async throws -> SecurityGroupRule {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.createSecurityGroupRule(request: request)
        }
    }

    /// Create a security group rule (backward compatibility method)
    public func createSecurityGroupRule(
        securityGroupId: String,
        direction: SecurityGroupDirection,
        protocol: SecurityGroupProtocol?,
        ethertype: SecurityGroupEtherType,
        portRangeMin: Int?,
        portRangeMax: Int?,
        remoteIpPrefix: String?,
        remoteGroupId: String?
    ) async throws -> SecurityGroupRule {
        let request = CreateSecurityGroupRuleRequest(
            securityGroupId: securityGroupId,
            direction: direction.rawValue,
            ethertype: ethertype.rawValue,
            protocol: `protocol`?.rawValue,
            portRangeMin: portRangeMin,
            portRangeMax: portRangeMax,
            remoteIpPrefix: remoteIpPrefix,
            remoteGroupId: remoteGroupId
        )
        return try await createSecurityGroupRule(request: request)
    }

    /// Delete a security group rule
    public func deleteSecurityGroupRule(id: String) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            try await neutron.deleteSecurityGroupRule(id: id)
        }
    }

    /// Get a security group by ID
    public func getSecurityGroup(id: String) async throws -> SecurityGroup {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.getSecurityGroup(id: id)
        }
    }

    /// Resolve project ID (backward compatibility method)
    public func resolveProjectID() async throws {
        // This method would typically resolve project name to ID
        // For now, we'll make it a no-op as the OpenStackClient handles this internally
        // TODO: Implement proper project ID resolution if needed
    }

    // MARK: - Volume Management Extensions

    /// Create volume from image (generic volume creation - adapter method)
    public func createVolumeFromImage(name: String?, size: Int, imageRef: String?, availabilityZone: String? = nil, volumeType: String? = nil) async throws -> Volume {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            let request = CreateVolumeRequest(
                name: name,
                description: nil,
                size: size,
                volumeType: volumeType,
                availabilityZone: availabilityZone,
                sourceVolid: nil,
                snapshotId: nil,
                imageRef: imageRef
            )
            return try await cinder.createVolume(request: request)
        }
    }

    /// Attach volume to server
    public func attachVolume(volumeId: String, serverId: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.attachVolume(serverId: serverId, volumeId: volumeId)
        }
    }

    /// Detach volume from server
    public func detachVolume(serverId: String, volumeId: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.detachVolume(serverId: serverId, volumeId: volumeId)
        }
    }

    // MARK: - Floating IP Extensions

    /// Create a floating IP
    public func createFloatingIP(networkID: String, portID: String? = nil, subnetID: String? = nil, description: String? = nil) async throws -> FloatingIP {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.createFloatingIP(networkID: networkID, portID: portID, subnetID: subnetID, description: description)
        }
    }

    /// Update a floating IP (assign/unassign to port)
    public func updateFloatingIP(id: String, portID: String? = nil, fixedIP: String? = nil) async throws -> FloatingIP {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.updateFloatingIP(id: id, portID: portID, fixedIP: fixedIP)
        }
    }

    // MARK: - Port Extensions

    /// Create a port
    public func createPort(name: String?, description: String?, networkID: String, subnetID: String?, securityGroups: [String]? = nil, qosPolicyID: String? = nil) async throws -> Port {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            let request = CreatePortRequest(
                name: name,
                description: description,
                networkId: networkID,
                adminStateUp: true,
                macAddress: nil,
                fixedIps: subnetID != nil ? [FixedIP(subnetId: subnetID!, ipAddress: "")] : nil,
                deviceId: nil,
                deviceOwner: nil,
                securityGroups: securityGroups
            )
            return try await neutron.createPort(request: request)
        }
    }

    // MARK: - Network Attachment Extensions

    /// Attach network to server (creates new port and attaches it)
    public func attachNetwork(serverID: String, networkID: String) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            let port = try await neutron.createPort(request: CreatePortRequest(
                name: "auto-attachment-\(UUID().uuidString.prefix(8))",
                description: "Auto-created for network attachment",
                networkId: networkID,
                adminStateUp: true
            ))

            let nova = await self.nova
            let _ = try await nova.attachPortToServer(serverId: serverID, portId: port.id)
        }
    }

    // MARK: - Server Security Group Management

    /// Add security group to server (compatibility alias)
    public func addSecurityGroup(serverID: String, securityGroupName: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.addSecurityGroupToServer(serverId: serverID, securityGroupName: securityGroupName)
        }
    }

    /// Remove security group from server (compatibility alias)
    public func removeSecurityGroup(serverID: String, securityGroupName: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.removeSecurityGroupFromServer(serverId: serverID, securityGroupName: securityGroupName)
        }
    }

    /// Get security groups for a specific server
    public func getServerSecurityGroups(serverID: String) async throws -> [SecurityGroup] {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.getServerSecurityGroups(serverId: serverID)
        }
    }

    /// Get network interfaces (ports) for a server
    public func getServerInterfaces(serverID: String) async throws -> [InterfaceAttachment] {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.listServerInterfaces(serverId: serverID)
        }
    }

    /// Create a snapshot of a server
    public func createServerSnapshot(serverID: String, name: String, metadata: [String: String]? = nil) async throws -> String {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.createServerSnapshot(serverId: serverID, name: name, metadata: metadata)
        }
    }

    /// Get console output for a server
    public func getConsoleOutput(serverID: String, length: Int? = nil) async throws -> String {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.getConsoleOutput(id: serverID, length: length)
        }
    }

    /// Get remote console URL for a server
    public func getRemoteConsole(serverID: String, protocol: String = "vnc", type: String = "novnc") async throws -> RemoteConsole {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.getRemoteConsole(id: serverID, protocol: `protocol`, type: type)
        }
    }

    // MARK: - Port Management

    /// Attach port to server
    public func attachPort(serverID: String, portID: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            let _ = try await nova.attachPortToServer(serverId: serverID, portId: portID)
        }
    }

    /// Detach port from server
    public func detachPort(serverID: String, portID: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.detachPortFromServer(serverId: serverID, portId: portID)
        }
    }

    /// Delete a port
    public func deletePort(id: String) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            try await neutron.deletePort(id: id)
        }
    }

    // MARK: - Router Management

    /// Create a router
    public func createRouter(name: String, description: String? = nil, adminStateUp: Bool = true, externalGatewayInfo: String? = nil) async throws -> Router {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            let request = CreateRouterRequest(
                name: name,
                description: description,
                adminStateUp: adminStateUp,
                distributed: nil,
                ha: nil,
                externalGatewayInfo: externalGatewayInfo != nil ? ExternalGatewayInfo(networkId: externalGatewayInfo!) : nil
            )
            return try await neutron.createRouter(request: request)
        }
    }

    /// Get router details with interfaces
    public func getRouter(id: String, forceRefresh: Bool = false) async throws -> Router {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.getRouter(id: id, forceRefresh: forceRefresh)
        }
    }

    /// Delete a router
    public func deleteRouter(id: String) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            try await neutron.deleteRouter(id: id)
        }
    }

    /// Update a router
    public func updateRouter(id: String, request: UpdateRouterRequest) async throws -> Router {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.updateRouter(id: id, request: request)
        }
    }

    /// Add an interface to a router
    ///
    /// - Parameters:
    ///   - routerId: The router ID
    ///   - subnetId: The subnet ID to attach (optional if portId is provided)
    ///   - portId: The port ID to attach (optional if subnetId is provided)
    /// - Returns: The created router interface
    @discardableResult
    public func addRouterInterface(routerId: String, subnetId: String? = nil, portId: String? = nil) async throws -> RouterInterface {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.addRouterInterface(routerId: routerId, subnetId: subnetId, portId: portId)
        }
    }

    /// Remove an interface from a router
    public func removeRouterInterface(routerId: String, subnetId: String? = nil, portId: String? = nil) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            try await neutron.removeRouterInterface(routerId: routerId, subnetId: subnetId, portId: portId)
        }
    }

    // MARK: - Floating IP Management

    /// Delete a floating IP
    public func deleteFloatingIP(id: String) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            try await neutron.deleteFloatingIP(id: id)
        }
    }

    // MARK: - Volume Snapshot Management

    /// Create a volume snapshot
    public func createVolumeSnapshot(volumeID: String, name: String, description: String? = nil) async throws -> String {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            let request = CreateSnapshotRequest(volumeId: volumeID, name: name, description: description, force: true)
            let snapshot = try await cinder.createSnapshot(request: request)
            return snapshot.id
        }
    }

    /// Get snapshots for a specific volume
    ///
    /// - Parameters:
    ///   - volumeId: The ID of the volume to get snapshots for
    ///   - forceRefresh: Whether to bypass cache and fetch fresh data from API
    /// - Returns: Array of volume snapshots for the specified volume
    public func getVolumeSnapshots(volumeId: String, forceRefresh: Bool = false) async throws -> [VolumeSnapshot] {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            return try await cinder.listSnapshots(volumeId: volumeId, forceRefresh: forceRefresh)
        }
    }

    /// Get all volume snapshots
    public func getAllVolumeSnapshots() async throws -> [VolumeSnapshot] {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            return try await cinder.listSnapshots()
        }
    }

    /// Delete a volume snapshot
    public func deleteVolumeSnapshot(snapshotId: String) async throws {
        try await executeWithTokenRefresh {
            let cinder = await self.cinder
            try await cinder.deleteSnapshot(id: snapshotId)
        }
    }

    // MARK: - Volume Backup Management

    /// Create a volume backup
    public func createVolumeBackup(volumeID: String, name: String, description: String? = nil, incremental: Bool = false, force: Bool = true) async throws -> String {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            let request = CreateBackupRequest(
                volumeId: volumeID,
                name: name,
                description: description,
                container: nil,
                incremental: incremental,
                force: force,
                snapshotId: nil
            )
            let backup = try await cinder.createBackup(request: request)
            return backup.id
        }
    }

    /// Get backups for a specific volume
    public func getVolumeBackups(volumeId: String) async throws -> [VolumeBackup] {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            return try await cinder.listBackups(volumeId: volumeId)
        }
    }

    /// Get all volume backups
    public func getAllVolumeBackups() async throws -> [VolumeBackup] {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            return try await cinder.listBackups()
        }
    }

    /// Delete a volume backup
    public func deleteVolumeBackup(backupId: String) async throws {
        try await executeWithTokenRefresh {
            let cinder = await self.cinder
            try await cinder.deleteBackup(id: backupId)
        }
    }

    // MARK: - Key Pair Management

    /// Create a key pair
    public func createKeyPair(name: String, publicKey: String? = nil, keyType: String? = nil) async throws -> KeyPair {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.createKeyPair(name: name, publicKey: publicKey)
        }
    }

    /// Delete a key pair
    public func deleteKeyPair(name: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.deleteKeyPair(name: name)
        }
    }

    // MARK: - Image Management

    /// Delete an image
    public func deleteImage(id: String) async throws {
        try await executeWithTokenRefresh {
            let glance = await self.glance
            try await glance.deleteImage(id: id)
        }
    }

    // MARK: - Volume Creation Methods

    /// Create volume from snapshot (generic volume creation - adapter method)
    public func createVolumeFromSnapshot(name: String?, size: Int, snapshotId: String?, availabilityZone: String? = nil, volumeType: String? = nil) async throws -> Volume {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            let request = CreateVolumeRequest(
                name: name,
                description: nil,
                size: size,
                volumeType: volumeType,
                availabilityZone: availabilityZone,
                sourceVolid: nil,
                snapshotId: snapshotId,
                imageRef: nil
            )
            return try await cinder.createVolume(request: request)
        }
    }

    /// Create blank volume (generic volume creation - adapter method)
    public func createBlankVolume(name: String?, size: Int, availabilityZone: String? = nil, volumeType: String? = nil) async throws -> Volume {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            let request = CreateVolumeRequest(
                name: name,
                description: nil,
                size: size,
                volumeType: volumeType,
                availabilityZone: availabilityZone,
                sourceVolid: nil,
                snapshotId: nil,
                imageRef: nil
            )
            return try await cinder.createVolume(request: request)
        }
    }

    // MARK: - Server Group Management

    /// Create a server group
    public func createServerGroup(name: String, policy: String) async throws -> ServerGroup {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.createServerGroup(name: name, policy: policy)
        }
    }

    // MARK: - Optimization Features

    /// Suggest optimal server size based on workload requirements
    public func suggestOptimalSize(
        workloadType: WorkloadType,
        expectedLoad: LoadProfile,
        budget: Budget? = nil
    ) async throws -> FlavorRecommendation {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            let flavors = try await nova.listFlavors()

            return FlavorOptimizer.suggestOptimalFlavor(
                flavors: flavors,
                workloadType: workloadType,
                expectedLoad: expectedLoad,
                budget: budget
            )
        }
    }

    /// Get telemetry actor for metrics collection
    public var telemetryActor: TelemetryActor {
        get async {
            return SharedTelemetryActor.shared
        }
    }

    /// Record a metric for telemetry
    public func recordMetric(_ metric: Metric) async {
        let telemetry = await telemetryActor
        await telemetry.recordMetric(metric)
    }

    /// Get current health score
    public func getHealthScore() async -> HealthScore {
        let telemetry = await telemetryActor
        return await telemetry.getHealthScore()
    }

    /// Get active alerts
    public func getActiveAlerts() async -> [Alert] {
        let telemetry = await telemetryActor
        return await telemetry.getActiveAlerts()
    }

    /// Get search actor for advanced search functionality
    public var searchActor: SearchActor {
        get async {
            return SearchActor()
        }
    }

    /// Perform advanced search across resources
    public func search(_ query: SearchQuery) async throws -> SearchResult {
        let search = await searchActor
        return try await search.executeSearch(query)
    }
}

// MARK: - Flavor Optimization Types

public enum WorkloadType: String, CaseIterable, Sendable {
    case compute = "compute"
    case memory = "memory"
    case storage = "storage"
    case network = "network"
    case balanced = "balanced"
    case gpu = "gpu"
    case accelerated = "accelerated"

    public var displayName: String {
        switch self {
        case .compute: return "Compute Intensive"
        case .memory: return "Memory Intensive"
        case .storage: return "Storage Intensive"
        case .network: return "Network Intensive"
        case .balanced: return "Balanced"
        case .gpu: return "GPU Accelerated"
        case .accelerated: return "Hardware Accelerated"
        }
    }

    public var description: String {
        switch self {
        case .compute: return "High CPU requirements"
        case .memory: return "High RAM requirements"
        case .storage: return "High disk I/O requirements"
        case .network: return "High network throughput requirements"
        case .balanced: return "Balanced resource requirements"
        case .gpu: return "GPU-accelerated computing"
        case .accelerated: return "PCI passthrough & specialized hardware"
        }
    }
}

public struct LoadProfile: Sendable {
    public let cpuUtilization: Double // 0.0 - 1.0
    public let memoryUtilization: Double // 0.0 - 1.0
    public let diskIOPS: Int
    public let networkThroughput: Int // Mbps
    public let concurrentUsers: Int

    public init(cpuUtilization: Double, memoryUtilization: Double, diskIOPS: Int, networkThroughput: Int, concurrentUsers: Int) {
        self.cpuUtilization = cpuUtilization
        self.memoryUtilization = memoryUtilization
        self.diskIOPS = diskIOPS
        self.networkThroughput = networkThroughput
        self.concurrentUsers = concurrentUsers
    }
}

public struct Budget: Sendable {
    public let maxMonthlyCost: Double
    public let currency: String

    public init(maxMonthlyCost: Double, currency: String = "USD") {
        self.maxMonthlyCost = maxMonthlyCost
        self.currency = currency
    }
}

public struct FlavorRecommendation: Sendable {
    public let recommendedFlavor: Flavor
    public let alternativeFlavors: [Flavor]
    public let reasoningScore: Double // 0.0 - 1.0
    public let reasoning: String
    public let estimatedMonthlyCost: Double?
    public let performanceProfile: PerformanceProfile

    public init(recommendedFlavor: Flavor, alternativeFlavors: [Flavor], reasoningScore: Double, reasoning: String, estimatedMonthlyCost: Double?, performanceProfile: PerformanceProfile) {
        self.recommendedFlavor = recommendedFlavor
        self.alternativeFlavors = alternativeFlavors
        self.reasoningScore = reasoningScore
        self.reasoning = reasoning
        self.estimatedMonthlyCost = estimatedMonthlyCost
        self.performanceProfile = performanceProfile
    }
}

public struct PerformanceProfile: Sendable {
    public let expectedCPUUsage: Double
    public let expectedMemoryUsage: Double
    public let expectedBottlenecks: [String]
    public let scalabilityScore: Double // 0.0 - 1.0

    public init(expectedCPUUsage: Double, expectedMemoryUsage: Double, expectedBottlenecks: [String], scalabilityScore: Double) {
        self.expectedCPUUsage = expectedCPUUsage
        self.expectedMemoryUsage = expectedMemoryUsage
        self.expectedBottlenecks = expectedBottlenecks
        self.scalabilityScore = scalabilityScore
    }
}

// MARK: - Enhanced Flavor Optimizer

public struct FlavorOptimizer {
    public static func suggestOptimalFlavor(
        flavors: [Flavor],
        workloadType: WorkloadType,
        expectedLoad: LoadProfile,
        budget: Budget?
    ) -> FlavorRecommendation {

        // Enhanced multi-stage filtering and scoring
        let eligibleFlavors = filterEligibleFlavors(flavors, workloadType: workloadType, expectedLoad: expectedLoad, budget: budget)

        // Apply advanced scoring algorithm
        let scoredFlavors = eligibleFlavors.map { flavor in
            (flavor: flavor, score: calculateAdvancedFlavorScore(flavor, workloadType: workloadType, expectedLoad: expectedLoad, budget: budget))
        }.sorted { $0.score > $1.score }

        guard let bestFlavor = scoredFlavors.first else {
            // For GPU and accelerated workloads, return error recommendation if no compatible hardware found
            if workloadType == .gpu || workloadType == .accelerated {
                let hardwareType = workloadType == .gpu ? "GPU hardware" : "PCI passthrough capabilities"
                let fallbackFlavor = flavors.first ?? Flavor(id: "error", name: "No Compatible Flavors", vcpus: 0, ram: 0, disk: 0)
                return FlavorRecommendation(
                    recommendedFlavor: fallbackFlavor,
                    alternativeFlavors: [],
                    reasoningScore: 0.0,
                    reasoning: "ERROR: No flavors found with required \(hardwareType) for \(workloadType.displayName) workload. Please ensure your OpenStack deployment has flavors with the necessary hardware capabilities.",
                    estimatedMonthlyCost: 0.0,
                    performanceProfile: PerformanceProfile(expectedCPUUsage: 0.0, expectedMemoryUsage: 0.0, expectedBottlenecks: ["No compatible hardware available"], scalabilityScore: 0.0)
                )
            }

            // Intelligent fallback selection for other workload types
            let fallbackFlavor = selectIntelligentFallback(eligibleFlavors.isEmpty ? flavors : eligibleFlavors, workloadType: workloadType)
            return FlavorRecommendation(
                recommendedFlavor: fallbackFlavor,
                alternativeFlavors: [],
                reasoningScore: 0.2,
                reasoning: generateFallbackReasoning(fallbackFlavor, workloadType: workloadType, budget: budget),
                estimatedMonthlyCost: estimatedMonthlyCost(for: fallbackFlavor),
                performanceProfile: calculatePerformanceProfile(fallbackFlavor, expectedLoad: expectedLoad)
            )
        }

        // Select diverse alternatives with different characteristics
        let alternatives = selectDiverseAlternatives(scoredFlavors, primaryFlavor: bestFlavor.flavor, workloadType: workloadType)
        let reasoning = generateAdvancedReasoning(bestFlavor.flavor, workloadType: workloadType, score: bestFlavor.score, expectedLoad: expectedLoad)

        // Filter out recommendations with confidence less than 25%
        if bestFlavor.score < 0.25 {
            // Return fallback recommendation if confidence is too low
            let fallbackFlavor = eligibleFlavors.first ?? bestFlavor.flavor
            return FlavorRecommendation(
                recommendedFlavor: fallbackFlavor,
                alternativeFlavors: [],
                reasoningScore: 0.25,
                reasoning: "Low confidence recommendation - consider reviewing workload requirements",
                estimatedMonthlyCost: estimatedMonthlyCost(for: fallbackFlavor),
                performanceProfile: calculatePerformanceProfile(fallbackFlavor, expectedLoad: expectedLoad)
            )
        }

        return FlavorRecommendation(
            recommendedFlavor: bestFlavor.flavor,
            alternativeFlavors: alternatives,
            reasoningScore: bestFlavor.score,
            reasoning: reasoning,
            estimatedMonthlyCost: estimatedMonthlyCost(for: bestFlavor.flavor),
            performanceProfile: calculatePerformanceProfile(bestFlavor.flavor, expectedLoad: expectedLoad)
        )
    }

    // MARK: - Helper Methods (simplified for brevity)

    private static func filterEligibleFlavors(_ flavors: [Flavor], workloadType: WorkloadType, expectedLoad: LoadProfile, budget: Budget?) -> [Flavor] {
        return flavors.filter { flavor in
            // Check budget constraints
            if let budget = budget {
                guard estimatedMonthlyCost(for: flavor) <= budget.maxMonthlyCost else {
                    return false
                }
            }

            // Check hardware acceleration requirements and exclusions
            switch workloadType {
            case .gpu:
                // GPU workloads require actual GPU hardware
                return hasGPUCapability(flavor)
            case .accelerated:
                // Accelerated workloads require PCI passthrough capabilities
                return hasPCIPassthroughCapability(flavor)
            default:
                // Other workload types should NOT get GPU/accelerated flavors
                // Exclude flavors with specialized hardware to keep them available for specialized workloads
                return !hasGPUCapability(flavor) && !hasPCIPassthroughCapability(flavor)
            }
        }
    }

    /// Check if flavor has GPU capabilities based on extra specs
    private static func hasGPUCapability(_ flavor: Flavor) -> Bool {
        guard let extraSpecs = flavor.extraSpecs else { return false }

        // Check for various GPU-related extra specs used in OpenStack
        let gpuIndicators = [
            "pci_passthrough:alias",  // PCI passthrough for GPU devices
            "capabilities:gpu",       // Explicit GPU capability
            "hw:gpu_api",            // GPU API support
            "resources:VGPU",        // Virtual GPU resources
            "capabilities:gpu_api",  // Alternative GPU API spec
            "hw:gpu"                 // Direct GPU hardware spec
        ]

        // Check if any GPU-related specs are present and not empty/false
        return gpuIndicators.contains { key in
            if let value = extraSpecs[key] {
                return !value.isEmpty && value.lowercased() != "false" && value != "0"
            }
            return false
        }
    }

    /// Check if flavor has PCI passthrough capabilities for hardware acceleration
    private static func hasPCIPassthroughCapability(_ flavor: Flavor) -> Bool {
        guard let extraSpecs = flavor.extraSpecs else { return false }

        // Check for PCI passthrough and hardware acceleration specs
        let pciIndicators = [
            "pci_passthrough:alias",     // PCI passthrough devices
            "capabilities:pci_passthrough", // PCI passthrough capability
            "hw:pci_passthrough",        // Hardware PCI passthrough
            "resources:ACCELERATOR",     // Generic accelerator resources
            "capabilities:fpga",         // FPGA acceleration
            "hw:accelerator"            // Hardware accelerator spec
        ]

        // Check if any PCI/accelerator-related specs are present and enabled
        return pciIndicators.contains { key in
            if let value = extraSpecs[key] {
                return !value.isEmpty && value.lowercased() != "false" && value != "0"
            }
            return false
        }
    }

    private static func calculateAdvancedFlavorScore(_ flavor: Flavor, workloadType: WorkloadType, expectedLoad: LoadProfile, budget: Budget?) -> Double {
        // Calculate workload-specific scoring weights
        let weights = getWorkloadWeights(for: workloadType)

        // CPU scoring - match against expected utilization
        let cpuRequirement = expectedLoad.cpuUtilization * Double(expectedLoad.concurrentUsers)
        let cpuCapacity = Double(flavor.vcpus)
        let cpuUtilizationAfterLoad = cpuRequirement / cpuCapacity
        let cpuScore = calculateResourceScore(utilization: cpuUtilizationAfterLoad, optimal: 0.7)

        // Memory scoring - match against expected utilization
        let memoryRequirementMB = expectedLoad.memoryUtilization * Double(expectedLoad.concurrentUsers) * 1024.0
        let memoryCapacityMB = Double(flavor.ram)
        let memoryUtilizationAfterLoad = memoryRequirementMB / memoryCapacityMB
        let memoryScore = calculateResourceScore(utilization: memoryUtilizationAfterLoad, optimal: 0.6)

        // Storage scoring based on IOPS requirements
        let diskScore = calculateDiskScore(flavor: flavor, expectedIOPS: expectedLoad.diskIOPS)

        // Network scoring - basic estimation
        let networkScore = calculateNetworkScore(flavor: flavor, expectedThroughput: expectedLoad.networkThroughput)

        // Cost efficiency scoring
        let costScore = calculateCostEfficiencyScore(flavor: flavor, budget: budget)

        // Workload-specific bonus scoring
        let workloadBonus = calculateWorkloadSpecificBonus(flavor: flavor, workloadType: workloadType)

        // Weighted final score
        let finalScore = (cpuScore * weights.cpu +
                         memoryScore * weights.memory +
                         diskScore * weights.storage +
                         networkScore * weights.network +
                         costScore * 0.15 +
                         workloadBonus * 0.1)

        return max(0.0, min(1.0, finalScore))
    }

    private static func getWorkloadWeights(for workloadType: WorkloadType) -> (cpu: Double, memory: Double, storage: Double, network: Double) {
        switch workloadType {
        case .compute:
            return (cpu: 0.5, memory: 0.2, storage: 0.15, network: 0.15)
        case .memory:
            return (cpu: 0.2, memory: 0.5, storage: 0.15, network: 0.15)
        case .storage:
            return (cpu: 0.15, memory: 0.2, storage: 0.5, network: 0.15)
        case .network:
            return (cpu: 0.15, memory: 0.2, storage: 0.15, network: 0.5)
        case .balanced:
            return (cpu: 0.25, memory: 0.25, storage: 0.25, network: 0.25)
        case .gpu:
            return (cpu: 0.3, memory: 0.3, storage: 0.2, network: 0.2)
        case .accelerated:
            return (cpu: 0.4, memory: 0.25, storage: 0.2, network: 0.15)
        }
    }

    private static func calculateResourceScore(utilization: Double, optimal: Double) -> Double {
        // Score based on how close utilization is to optimal range (50-80%)
        let targetRange = optimal...optimal + 0.2

        if targetRange.contains(utilization) {
            return 1.0 // Perfect utilization
        } else if utilization < optimal {
            // Under-utilization penalty (expensive)
            return max(0.0, 0.3 + (utilization / optimal) * 0.7)
        } else {
            // Over-utilization penalty (performance risk)
            let overUtilization = utilization - (optimal + 0.2)
            return max(0.0, 1.0 - overUtilization * 2.0)
        }
    }

    private static func calculateDiskScore(flavor: Flavor, expectedIOPS: Int) -> Double {
        // Basic disk scoring - larger disk generally means better I/O capability
        let diskGB = Double(flavor.disk)
        let expectedIOPSPerGB = Double(expectedIOPS) / max(1.0, diskGB)

        // Assume 10 IOPS per GB is reasonable, 20+ is demanding
        if expectedIOPSPerGB <= 10.0 {
            return 1.0
        } else if expectedIOPSPerGB <= 20.0 {
            return 1.0 - (expectedIOPSPerGB - 10.0) / 10.0 * 0.3
        } else {
            return max(0.2, 0.7 - (expectedIOPSPerGB - 20.0) / 20.0 * 0.5)
        }
    }

    private static func calculateNetworkScore(flavor: Flavor, expectedThroughput: Int) -> Double {
        // Network performance often correlates with vCPU count
        let estimatedNetworkCapacity = Double(flavor.vcpus) * 100.0 // 100 Mbps per vCPU estimate
        let utilizationRatio = Double(expectedThroughput) / estimatedNetworkCapacity
        return calculateResourceScore(utilization: utilizationRatio, optimal: 0.6)
    }

    private static func calculateCostEfficiencyScore(flavor: Flavor, budget: Budget?) -> Double {
        guard let budget = budget else { return 0.8 } // Neutral score if no budget specified

        let estimatedCost = estimatedMonthlyCost(for: flavor)
        let budgetUtilization = estimatedCost / budget.maxMonthlyCost

        // Best score when using 60-80% of budget
        return calculateResourceScore(utilization: budgetUtilization, optimal: 0.6)
    }

    private static func calculateWorkloadSpecificBonus(flavor: Flavor, workloadType: WorkloadType) -> Double {
        switch workloadType {
        case .gpu:
            // Bonus if flavor name suggests GPU support
            return (flavor.name?.lowercased().contains("gpu") ?? false) ? 0.5 : 0.0
        case .accelerated:
            // Bonus for flavors that suggest hardware acceleration
            let name = flavor.name?.lowercased() ?? ""
            return (name.contains("accel") || name.contains("sr-iov") || name.contains("dpdk")) ? 0.3 : 0.0
        case .compute:
            // Bonus for compute-optimized flavors (high vCPU to RAM ratio)
            let cpuToRAMRatio = Double(flavor.vcpus) / (Double(flavor.ram) / 1024.0)
            return cpuToRAMRatio > 0.5 ? 0.2 : 0.0
        case .memory:
            // Bonus for memory-optimized flavors (high RAM to vCPU ratio)
            let ramToCPURatio = (Double(flavor.ram) / 1024.0) / Double(flavor.vcpus)
            return ramToCPURatio > 4.0 ? 0.2 : 0.0
        default:
            return 0.0
        }
    }

    private static func selectIntelligentFallback(_ flavors: [Flavor], workloadType: WorkloadType) -> Flavor {
        return flavors.first ?? Flavor(id: "fallback", name: "Fallback", vcpus: 1, ram: 1024, disk: 10)
    }

    private static func selectDiverseAlternatives(_ scoredFlavors: [(flavor: Flavor, score: Double)], primaryFlavor: Flavor, workloadType: WorkloadType) -> [Flavor] {
        return Array(scoredFlavors.dropFirst().map { $0.flavor }.prefix(3))
    }

    private static func generateAdvancedReasoning(_ flavor: Flavor, workloadType: WorkloadType, score: Double, expectedLoad: LoadProfile) -> String {
        var reasoning = "\nRECOMMENDATION ANALYSIS for \(workloadType.displayName.uppercased())\n"
        reasoning += "================================\n\n"

        // Flavor overview
        let ramGB = Double(flavor.ram) / 1024.0
        reasoning += "SELECTED: \(flavor.name ?? "Unknown Flavor")\n"
        reasoning += "Resources: \(flavor.vcpus) vCPUs, \(String(format: "%.1f", ramGB))GB RAM, \(flavor.disk)GB Disk\n"
        reasoning += "Confidence Score: \(String(format: "%.0f%%", score * 100))\n\n"

        // Resource analysis
        reasoning += "RESOURCE ANALYSIS:\n"

        // CPU Analysis
        let cpuRequirement = expectedLoad.cpuUtilization * Double(expectedLoad.concurrentUsers)
        let cpuUtilization = cpuRequirement / Double(flavor.vcpus)
        reasoning += "* CPU: \(String(format: "%.0f%%", cpuUtilization * 100)) utilization expected"

        if cpuUtilization <= 0.8 {
            reasoning += " (Good headroom for peaks)\n"
        } else if cpuUtilization <= 1.0 {
            reasoning += " (Near capacity - monitor closely)\n"
        } else {
            reasoning += " (WARNING: May exceed capacity)\n"
        }

        // Memory Analysis
        let memoryRequirement = expectedLoad.memoryUtilization * Double(expectedLoad.concurrentUsers) * 1024.0
        let memoryUtilization = memoryRequirement / Double(flavor.ram)
        reasoning += "* Memory: \(String(format: "%.0f%%", memoryUtilization * 100)) utilization expected"

        if memoryUtilization <= 0.7 {
            reasoning += " (Excellent for caching)\n"
        } else if memoryUtilization <= 0.9 {
            reasoning += " (Good balance)\n"
        } else {
            reasoning += " (WARNING: Risk of swapping)\n"
        }

        // Workload-specific insights
        reasoning += "\nWORKLOAD INSIGHTS:\n"
        switch workloadType {
        case .compute:
            reasoning += "* Optimized for CPU-intensive tasks\n"
            reasoning += "* Good for batch processing, calculations, compilation\n"
        case .memory:
            reasoning += "* Optimized for memory-intensive applications\n"
            reasoning += "* Ideal for in-memory databases, caching, analytics\n"
        case .storage:
            reasoning += "* Balanced for storage-heavy workloads\n"
            reasoning += "* Good for databases, file servers, backup systems\n"
        case .network:
            reasoning += "* Optimized for network-intensive applications\n"
            reasoning += "* Ideal for web servers, API gateways, load balancers\n"
        case .balanced:
            reasoning += "* General-purpose balanced configuration\n"
            reasoning += "* Good for web applications, development, testing\n"
        case .gpu:
            let hasGPU = flavor.name?.lowercased().contains("gpu") ?? false
            if hasGPU {
                reasoning += "* GPU acceleration available\n"
                reasoning += "* Excellent for ML/AI, rendering, scientific computing\n"
            } else {
                reasoning += "* WARNING: No GPU detected in flavor name\n"
                reasoning += "* Verify GPU availability before deployment\n"
            }
        case .accelerated:
            reasoning += "* Hardware acceleration capabilities\n"
            reasoning += "* Good for NFV, networking, specialized workloads\n"
        }

        // Performance predictions
        reasoning += "\nPERFORMANCE EXPECTATIONS:\n"
        let concurrentUsers = expectedLoad.concurrentUsers
        if concurrentUsers <= 10 {
            reasoning += "* Low load scenario - excellent responsiveness expected\n"
        } else if concurrentUsers <= 100 {
            reasoning += "* Medium load scenario - good performance expected\n"
        } else {
            reasoning += "* High load scenario - monitor performance metrics\n"
        }

        // Cost insight
        let estimatedCost = estimatedMonthlyCost(for: flavor)
        reasoning += "* Estimated monthly cost: $\(String(format: "%.2f", estimatedCost))\n"

        // Scaling recommendations
        reasoning += "\nSCALING RECOMMENDATIONS:\n"
        if cpuUtilization < 0.5 && memoryUtilization < 0.5 {
            reasoning += "* Consider smaller flavor to reduce costs\n"
        } else if cpuUtilization > 0.8 || memoryUtilization > 0.8 {
            reasoning += "* Consider larger flavor for better performance\n"
        } else {
            reasoning += "* Good baseline - monitor and scale as needed\n"
        }

        reasoning += "* Enable auto-scaling for variable workloads\n"
        reasoning += "* Consider multiple smaller instances for high availability\n"

        return reasoning
    }

    private static func generateFallbackReasoning(_ flavor: Flavor, workloadType: WorkloadType, budget: Budget?) -> String {
        return "Fallback selection: \(flavor.name ?? "Unknown") for \(workloadType.displayName) workload."
    }

    public static func estimatedMonthlyCost(for flavor: Flavor) -> Double {
        if let extraSpecs = flavor.extraSpecs {
            if let costPerHour = extraSpecs["cost:hourly"], let hourly = Double(costPerHour) {
                return hourly * 730.0
            }
            if let costPerMonth = extraSpecs["cost:monthly"], let monthly = Double(costPerMonth) {
                return monthly
            }
        }

        let baseCPUCost = Double(flavor.vcpus) * 15.0
        let ramGB = Double(flavor.ram) / 1024.0
        let baseRAMCost = ramGB * 8.0
        let diskGB = Double(flavor.disk)
        let baseDiskCost = diskGB * 0.10

        var totalCost = baseCPUCost + baseRAMCost + baseDiskCost

        if hasGPUCapability(flavor) {
            totalCost += 500.0
        } else if hasPCIPassthroughCapability(flavor) {
            totalCost += 200.0
        }

        if let ephemeral = flavor.ephemeral, ephemeral > 0 {
            totalCost += Double(ephemeral) * 0.08
        }

        return totalCost
    }

    private static func calculatePerformanceProfile(_ flavor: Flavor, expectedLoad: LoadProfile) -> PerformanceProfile {
        return PerformanceProfile(
            expectedCPUUsage: min(expectedLoad.cpuUtilization, 1.0),
            expectedMemoryUsage: min(expectedLoad.memoryUtilization, 1.0),
            expectedBottlenecks: [],
            scalabilityScore: 0.8
        )
    }
}

// MARK: - Core Extension for Project ID Support

extension OpenStackClientCore {
    /// Get project ID from current authentication context
    public var projectID: String? {
        get async {
            // For now, return nil - project ID extraction from tokens needs proper implementation
            // This would require parsing the JWT token or getting it from the service catalog
            return nil
        }
    }
}