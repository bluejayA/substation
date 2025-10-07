import Foundation
import OSClient
import struct OSClient.Port

// Helper function to convert ResourceType to SearchResourceType
private func convertResourceType(_ resourceType: OpenStackCacheManager.ResourceType) -> SearchResourceType? {
    switch resourceType {
    case .server: return .server
    case .network: return .network
    case .subnet: return .subnet
    case .port: return .port
    case .router: return .router
    case .image: return .image
    case .flavor: return .flavor
    default: return nil // Some OSClient types don't have Search equivalents
    }
}

// Helper function to convert SearchResourceType to ResourceType for cache
private func toResourceType(_ searchType: SearchResourceType) -> ResourceType {
    switch searchType {
    case .server: return .server
    case .network: return .network
    case .subnet: return .subnet
    case .port: return .port
    case .router: return .router
    case .volume: return .volume
    case .image: return .image
    case .flavor: return .flavor
    case .securityGroup: return .securityGroup
    case .keyPair: return .keyPair
    case .floatingIP: return .floatingIP
    case .serverGroup: return .securityGroup // Map to closest type
    case .volumeSnapshot: return .volume // Map to volume for relationships
    case .volumeBackup: return .volume // Map to volume for relationships
    case .barbicanSecret: return .securityGroup // Map to security for relationships
    case .barbicanContainer: return .securityGroup // Map to security for relationships
    case .loadBalancer: return .network // Map to network for relationships
    case .swiftContainer: return .volume // Map to volume for relationships
    case .swiftObject: return .volume // Map to volume for relationships
    }
}

// MARK: - Resource Relationship Mapper

actor ResourceRelationshipMapper {
    private var relationshipGraph: RelationshipGraph = RelationshipGraph()

    private let cacheExpiryInterval: TimeInterval = 120.0 // 2 minutes

    // MARK: - Relationship Update Interface

    func updateRelationships(with resources: SearchableResources) async {
        let startTime = Date().timeIntervalSinceReferenceDate

        Logger.shared.logInfo("ResourceRelationshipMapper - Starting relationship mapping")

        await relationshipGraph.clear()

        // Clear caches through MemoryKit
        await SubstationMemoryContainer.shared.relationshipCache.clearAll()

        // Map server relationships
        await mapServerRelationships(resources.servers, allResources: resources)

        // Map network relationships
        await mapNetworkRelationships(resources.networks, allResources: resources)

        // Map volume relationships
        await mapVolumeRelationships(resources.volumes, allResources: resources)

        // Map security group relationships
        await mapSecurityGroupRelationships(resources.securityGroups, allResources: resources)

        // Map subnet relationships
        await mapSubnetRelationships(resources.subnets, allResources: resources)

        // Map port relationships
        await mapPortRelationships(resources.ports, allResources: resources)

        // Map router relationships
        await mapRouterRelationships(resources.routers, allResources: resources)

        // Map floating IP relationships
        await mapFloatingIPRelationships(resources.floatingIPs, allResources: resources)

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        Logger.shared.logInfo("ResourceRelationshipMapper - Relationship mapping completed in \(String(format: "%.1f", duration * 1000))ms")
    }

    // MARK: - Relationship Query Interface

    func getRelationships(for resourceId: String, type: SearchResourceType) async -> [ResourceRelationship] {
        let resourceType = toResourceType(type)

        // Check cache first
        if let cachedRelationships = await SubstationMemoryContainer.shared.relationshipCache.getDependencies(for: resourceId, type: resourceType) {
            return cachedRelationships
        }

        // Build relationships
        let relationships = await buildResourceRelationships(resourceId: resourceId, type: type)

        // Cache the results (fire and forget)
        Task { @MainActor in
            await SubstationMemoryContainer.shared.relationshipCache.cacheDependencies(relationships, for: resourceId, type: resourceType)
        }

        return relationships
    }

    func getDependents(for resourceId: String, type: SearchResourceType) async -> [ResourceRelationship] {
        let resourceType = toResourceType(type)

        // Check cache first
        if let cachedDependents = await SubstationMemoryContainer.shared.relationshipCache.getInverseRelationships(for: resourceId, type: resourceType) {
            return cachedDependents
        }

        let dependents = await relationshipGraph.getDependents(for: resourceId, type: type)

        // Cache the results (fire and forget)
        Task { @MainActor in
            await SubstationMemoryContainer.shared.relationshipCache.cacheInverseRelationships(dependents, for: resourceId, type: resourceType)
        }

        return dependents
    }

    func getTopologyGraph(for resourceIds: [String]) async -> SearchTopologyGraph {
        var nodes: [TopologyNode] = []
        var edges: [TopologyEdge] = []
        var processedResources: Set<String> = []

        for resourceId in resourceIds {
            await buildTopologySubgraph(
                resourceId: resourceId,
                nodes: &nodes,
                edges: &edges,
                processedResources: &processedResources,
                depth: 0,
                maxDepth: 3
            )
        }

        return SearchTopologyGraph(nodes: nodes, edges: edges)
    }

    func getImpactAnalysis(for resourceId: String, type: SearchResourceType) async -> ImpactAnalysis {
        let directDependencies = await getRelationships(for: resourceId, type: type)
        let dependents = await getDependents(for: resourceId, type: type)

        var affectedResources: Set<String> = Set([resourceId])
        var impactLevel = ImpactLevel.low

        // Calculate impact based on number of dependents and their types
        for dependent in dependents {
            affectedResources.insert(dependent.targetResourceId)

            // Server dependencies have higher impact
            if dependent.targetResourceType == SearchResourceType.server {
                impactLevel = max(impactLevel, .high)
            } else if dependent.targetResourceType == SearchResourceType.network {
                impactLevel = max(impactLevel, .medium)
            }
        }

        // Critical resources (like networks with many dependents) have high impact
        if dependents.count > 10 {
            impactLevel = .critical
        } else if dependents.count > 5 {
            impactLevel = max(impactLevel, .high)
        }

        return ImpactAnalysis(
            resourceId: resourceId,
            resourceType: type,
            impactLevel: impactLevel,
            directDependencies: directDependencies,
            dependents: dependents,
            totalAffectedResources: affectedResources.count
        )
    }

    // MARK: - Private Relationship Mapping Methods

    private func mapServerRelationships(_ servers: [Server], allResources: SearchableResources) async {
        for server in servers {
            var relationships: [ResourceRelationship] = []

            // Server -> Image relationship
            if let imageId = server.image?.id {
                relationships.append(ResourceRelationship(
                    sourceResourceId: server.id,
                    sourceResourceType: SearchResourceType.server,
                    targetResourceId: imageId,
                    targetResourceType: SearchResourceType.image,
                    relationshipType: .dependsOn,
                    description: "Server uses image"
                ))
            }

            // Server -> Flavor relationship
            if let flavorId = server.flavor?.id {
                relationships.append(ResourceRelationship(
                    sourceResourceId: server.id,
                    sourceResourceType: SearchResourceType.server,
                    targetResourceId: flavorId,
                    targetResourceType: SearchResourceType.flavor,
                    relationshipType: .dependsOn,
                    description: "Server uses flavor"
                ))
            }

            // Server -> Security Groups relationships
            if let securityGroups = server.securityGroups {
                for securityGroup in securityGroups {
                    relationships.append(ResourceRelationship(
                        sourceResourceId: server.id,
                        sourceResourceType: SearchResourceType.server,
                        targetResourceId: securityGroup.name, // Using name as ID for security group refs
                        targetResourceType: SearchResourceType.securityGroup,
                        relationshipType: .associatedWith,
                        description: "Server assigned to security group"
                    ))
                }
            }

            // Server -> Network relationships (through addresses)
            if let addresses = server.addresses {
                for (networkName, _) in addresses {
                    // Find network by name
                    if let network = allResources.networks.first(where: { $0.name == networkName }) {
                        relationships.append(ResourceRelationship(
                            sourceResourceId: server.id,
                            sourceResourceType: SearchResourceType.server,
                            targetResourceId: network.id,
                            targetResourceType: SearchResourceType.network,
                            relationshipType: .connectedTo,
                            description: "Server connected to network"
                        ))
                    }
                }
            }

            // Server -> Volume relationships
            let attachedVolumes = allResources.volumes.filter { volume in
                volume.attachments?.contains { $0.serverId == server.id } == true
            }

            for volume in attachedVolumes {
                relationships.append(ResourceRelationship(
                    sourceResourceId: server.id,
                    sourceResourceType: SearchResourceType.server,
                    targetResourceId: volume.id,
                    targetResourceType: SearchResourceType.volume,
                    relationshipType: .attachedTo,
                    description: "Server has attached volume"
                ))
            }

            await relationshipGraph.addRelationships(relationships)
        }
    }

    private func mapNetworkRelationships(_ networks: [Network], allResources: SearchableResources) async {
        for network in networks {
            var relationships: [ResourceRelationship] = []

            // Network -> Subnet relationships
            let networkSubnets = allResources.subnets.filter { $0.networkId == network.id }
            for subnet in networkSubnets {
                relationships.append(ResourceRelationship(
                    sourceResourceId: network.id,
                    sourceResourceType: SearchResourceType.network,
                    targetResourceId: subnet.id,
                    targetResourceType: SearchResourceType.subnet,
                    relationshipType: .contains,
                    description: "Network contains subnet"
                ))
            }

            // Network -> Port relationships
            let networkPorts = allResources.ports.filter { $0.networkId == network.id }
            for port in networkPorts {
                relationships.append(ResourceRelationship(
                    sourceResourceId: network.id,
                    sourceResourceType: SearchResourceType.network,
                    targetResourceId: port.id,
                    targetResourceType: SearchResourceType.port,
                    relationshipType: .contains,
                    description: "Network contains port"
                ))
            }

            await relationshipGraph.addRelationships(relationships)
        }
    }

    private func mapVolumeRelationships(_ volumes: [Volume], allResources: SearchableResources) async {
        for volume in volumes {
            var relationships: [ResourceRelationship] = []

            // Volume -> Server relationships (via attachments)
            if let attachments = volume.attachments {
                for attachment in attachments {
                    relationships.append(ResourceRelationship(
                        sourceResourceId: volume.id,
                        sourceResourceType: SearchResourceType.volume,
                        targetResourceId: attachment.serverId ?? "unknown-server",
                        targetResourceType: SearchResourceType.server,
                        relationshipType: .attachedTo,
                        description: "Volume attached to server"
                    ))
                }
            }

            // Volume -> Volume relationships (snapshots)
            if let snapshotId = volume.snapshotId {
                relationships.append(ResourceRelationship(
                    sourceResourceId: volume.id,
                    sourceResourceType: SearchResourceType.volume,
                    targetResourceId: snapshotId,
                    targetResourceType: SearchResourceType.volume, // Snapshots are also volumes
                    relationshipType: .derivedFrom,
                    description: "Volume created from snapshot"
                ))
            }

            await relationshipGraph.addRelationships(relationships)
        }
    }

    private func mapSecurityGroupRelationships(_ securityGroups: [SecurityGroup], allResources: SearchableResources) async {
        for securityGroup in securityGroups {
            var relationships: [ResourceRelationship] = []

            // Security Group -> Security Group relationships (via rules)
            if let rules = securityGroup.securityGroupRules {
                for rule in rules {
                    if let remoteGroupId = rule.remoteGroupId {
                        relationships.append(ResourceRelationship(
                            sourceResourceId: securityGroup.id,
                            sourceResourceType: SearchResourceType.securityGroup,
                            targetResourceId: remoteGroupId,
                            targetResourceType: SearchResourceType.securityGroup,
                            relationshipType: .references,
                            description: "Security group references another group"
                        ))
                    }
                }
            }

            await relationshipGraph.addRelationships(relationships)
        }
    }

    private func mapSubnetRelationships(_ subnets: [Subnet], allResources: SearchableResources) async {
        for subnet in subnets {
            var relationships: [ResourceRelationship] = []

            // Subnet -> Network relationship (already mapped in network relationships)

            // Subnet -> Port relationships
            let subnetPorts = allResources.ports.filter { port in
                port.fixedIps?.contains { $0.subnetId == subnet.id } == true
            }

            for port in subnetPorts {
                relationships.append(ResourceRelationship(
                    sourceResourceId: subnet.id,
                    sourceResourceType: SearchResourceType.subnet,
                    targetResourceId: port.id,
                    targetResourceType: SearchResourceType.port,
                    relationshipType: .contains,
                    description: "Subnet contains port"
                ))
            }

            await relationshipGraph.addRelationships(relationships)
        }
    }

    private func mapPortRelationships(_ ports: [Port], allResources: SearchableResources) async {
        for port in ports {
            var relationships: [ResourceRelationship] = []

            // Port -> Device relationships
            if let deviceId = port.deviceId {
                // Try to determine device type from device owner
                let deviceType: SearchResourceType
                if let deviceOwner = port.deviceOwner {
                    if deviceOwner.contains("compute") {
                        deviceType = .server
                    } else if deviceOwner.contains("router") {
                        deviceType = .router
                    } else {
                        deviceType = .server // Default assumption
                    }
                } else {
                    deviceType = .server
                }

                relationships.append(ResourceRelationship(
                    sourceResourceId: port.id,
                    sourceResourceType: SearchResourceType.port,
                    targetResourceId: deviceId,
                    targetResourceType: deviceType,
                    relationshipType: .attachedTo,
                    description: "Port attached to device"
                ))
            }

            // Port -> Floating IP relationships
            let portFloatingIPs = allResources.floatingIPs.filter { $0.portId == port.id }
            for floatingIP in portFloatingIPs {
                relationships.append(ResourceRelationship(
                    sourceResourceId: port.id,
                    sourceResourceType: SearchResourceType.port,
                    targetResourceId: floatingIP.id,
                    targetResourceType: SearchResourceType.floatingIP,
                    relationshipType: .assignedTo,
                    description: "Port has floating IP"
                ))
            }

            await relationshipGraph.addRelationships(relationships)
        }
    }

    private func mapRouterRelationships(_ routers: [Router], allResources: SearchableResources) async {
        for router in routers {
            var relationships: [ResourceRelationship] = []

            // Router -> Port relationships (router interfaces)
            let routerPorts = allResources.ports.filter { port in
                port.deviceId == router.id && port.deviceOwner?.contains("router") == true
            }

            for port in routerPorts {
                relationships.append(ResourceRelationship(
                    sourceResourceId: router.id,
                    sourceResourceType: SearchResourceType.router,
                    targetResourceId: port.id,
                    targetResourceType: SearchResourceType.port,
                    relationshipType: .contains,
                    description: "Router interface port"
                ))
            }

            await relationshipGraph.addRelationships(relationships)
        }
    }

    private func mapFloatingIPRelationships(_ floatingIPs: [FloatingIP], allResources: SearchableResources) async {
        for floatingIP in floatingIPs {
            var relationships: [ResourceRelationship] = []

            // Floating IP -> Port relationship
            if let portId = floatingIP.portId {
                relationships.append(ResourceRelationship(
                    sourceResourceId: floatingIP.id,
                    sourceResourceType: SearchResourceType.floatingIP,
                    targetResourceId: portId,
                    targetResourceType: SearchResourceType.port,
                    relationshipType: .assignedTo,
                    description: "Floating IP assigned to port"
                ))
            }

            await relationshipGraph.addRelationships(relationships)
        }
    }

    private func buildResourceRelationships(resourceId: String, type: SearchResourceType) async -> [ResourceRelationship] {
        return await relationshipGraph.getRelationships(for: resourceId, type: type)
    }

    private func buildTopologySubgraph(
        resourceId: String,
        nodes: inout [TopologyNode],
        edges: inout [TopologyEdge],
        processedResources: inout Set<String>,
        depth: Int,
        maxDepth: Int
    ) async {
        guard depth < maxDepth && !processedResources.contains(resourceId) else {
            return
        }

        processedResources.insert(resourceId)

        // Add the current resource as a node
        // Note: We'd need to look up the resource details from our data
        let nodeType = inferResourceTypeFromId(resourceId)
        nodes.append(TopologyNode(
            id: resourceId,
            type: nodeType,
            name: resourceId, // Would be replaced with actual name
            position: TopologyPosition(x: 0, y: 0), // Would be calculated
            metadata: [:]
        ))

        // Get relationships and add edges
        let relationships = await relationshipGraph.getRelationships(for: resourceId, type: nodeType)

        for relationship in relationships {
            edges.append(TopologyEdge(
                id: "\(relationship.sourceResourceId)-\(relationship.targetResourceId)",
                sourceId: relationship.sourceResourceId,
                targetId: relationship.targetResourceId,
                type: relationship.relationshipType,
                description: relationship.description
            ))

            // Recursively process connected resources
            await buildTopologySubgraph(
                resourceId: relationship.targetResourceId,
                nodes: &nodes,
                edges: &edges,
                processedResources: &processedResources,
                depth: depth + 1,
                maxDepth: maxDepth
            )
        }
    }

    private func inferResourceTypeFromId(_ resourceId: String) -> SearchResourceType {
        // Simple heuristic based on UUID patterns or naming conventions
        // In practice, we'd maintain a mapping of resource IDs to types
        if resourceId.contains("server") || resourceId.count == 36 {
            return .server
        } else if resourceId.contains("network") {
            return .network
        } else if resourceId.contains("volume") {
            return .volume
        } else {
            return .server // Default fallback
        }
    }
}

// MARK: - Relationship Graph Storage

private actor RelationshipGraph {
    private var relationships: [String: [ResourceRelationship]] = [:]
    private var inverseRelationships: [String: [ResourceRelationship]] = [:]

    func addRelationships(_ newRelationships: [ResourceRelationship]) {
        for relationship in newRelationships {
            let sourceKey = "\(relationship.sourceResourceType.rawValue):\(relationship.sourceResourceId)"
            let targetKey = "\(relationship.targetResourceType.rawValue):\(relationship.targetResourceId)"

            // Forward relationships
            if relationships[sourceKey] == nil {
                relationships[sourceKey] = []
            }
            relationships[sourceKey]?.append(relationship)

            // Inverse relationships
            let inverseRelationship = ResourceRelationship(
                sourceResourceId: relationship.targetResourceId,
                sourceResourceType: relationship.targetResourceType,
                targetResourceId: relationship.sourceResourceId,
                targetResourceType: relationship.sourceResourceType,
                relationshipType: relationship.relationshipType.inverse,
                description: "Inverse: \(relationship.description)"
            )

            if inverseRelationships[targetKey] == nil {
                inverseRelationships[targetKey] = []
            }
            inverseRelationships[targetKey]?.append(inverseRelationship)
        }
    }

    func getRelationships(for resourceId: String, type: SearchResourceType) -> [ResourceRelationship] {
        let key = "\(type.rawValue):\(resourceId)"
        return relationships[key] ?? []
    }

    func getDependents(for resourceId: String, type: SearchResourceType) -> [ResourceRelationship] {
        let key = "\(type.rawValue):\(resourceId)"
        return inverseRelationships[key] ?? []
    }

    func clear() {
        relationships.removeAll()
        inverseRelationships.removeAll()
    }
}

// MARK: - Supporting Types

public struct ResourceRelationship: Codable, Sendable, Identifiable {
    public let id: UUID
    public let sourceResourceId: String
    public let sourceResourceType: SearchResourceType
    public let targetResourceId: String
    public let targetResourceType: SearchResourceType
    public let relationshipType: RelationshipType
    public let description: String
    public let metadata: [String: String]

    public init(
        sourceResourceId: String,
        sourceResourceType: SearchResourceType,
        targetResourceId: String,
        targetResourceType: SearchResourceType,
        relationshipType: RelationshipType,
        description: String,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.sourceResourceId = sourceResourceId
        self.sourceResourceType = sourceResourceType
        self.targetResourceId = targetResourceId
        self.targetResourceType = targetResourceType
        self.relationshipType = relationshipType
        self.description = description
        self.metadata = metadata
    }
}

public enum RelationshipType: String, Codable, CaseIterable, Sendable {
    case dependsOn = "depends_on"
    case contains = "contains"
    case attachedTo = "attached_to"
    case connectedTo = "connected_to"
    case associatedWith = "associated_with"
    case derivedFrom = "derived_from"
    case references = "references"
    case assignedTo = "assigned_to"

    var inverse: RelationshipType {
        switch self {
        case .dependsOn: return .contains
        case .contains: return .dependsOn
        case .attachedTo: return .attachedTo
        case .connectedTo: return .connectedTo
        case .associatedWith: return .associatedWith
        case .derivedFrom: return .derivedFrom
        case .references: return .references
        case .assignedTo: return .assignedTo
        }
    }

    var displayName: String {
        switch self {
        case .dependsOn: return "Depends On"
        case .contains: return "Contains"
        case .attachedTo: return "Attached To"
        case .connectedTo: return "Connected To"
        case .associatedWith: return "Associated With"
        case .derivedFrom: return "Derived From"
        case .references: return "References"
        case .assignedTo: return "Assigned To"
        }
    }
}

struct SearchTopologyGraph: Sendable {
    let nodes: [TopologyNode]
    let edges: [TopologyEdge]
}

struct TopologyNode: Sendable, Identifiable {
    let id: String
    let type: SearchResourceType
    let name: String
    let position: TopologyPosition
    let metadata: [String: String]
}

struct TopologyEdge: Sendable, Identifiable {
    let id: String
    let sourceId: String
    let targetId: String
    let type: RelationshipType
    let description: String
}

struct TopologyPosition: Sendable {
    let x: Double
    let y: Double
}

struct ImpactAnalysis: Sendable {
    let resourceId: String
    let resourceType: SearchResourceType
    let impactLevel: ImpactLevel
    let directDependencies: [ResourceRelationship]
    let dependents: [ResourceRelationship]
    let totalAffectedResources: Int
}

enum ImpactLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    static func < (lhs: ImpactLevel, rhs: ImpactLevel) -> Bool {
        let order: [ImpactLevel] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    var displayName: String {
        switch self {
        case .low: return "Low Impact"
        case .medium: return "Medium Impact"
        case .high: return "High Impact"
        case .critical: return "Critical Impact"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}