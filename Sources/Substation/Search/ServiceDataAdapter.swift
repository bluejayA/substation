import Foundation
import OSClient

// Import Port from OSClient to avoid ambiguity with Foundation.Port
import struct OSClient.Port

// MARK: - Service Data Adapter Protocol

public protocol ServiceDataAdapter: Sendable {
    var serviceName: String { get }
    var supportedResourceTypes: [SearchResourceType] { get }

    func search(_ query: SearchQuery) async throws -> [SearchResult]
    func getAllResources() async throws -> [any Sendable]
    func getResourceById(_ id: String, type: SearchResourceType) async throws -> (any Sendable)?
    func getResourceRelationships(_ resourceId: String, type: SearchResourceType) async throws -> [CrossServiceRelationship]
}

// MARK: - Resource Update Model

public struct ResourceUpdate: Codable, Sendable {
    let resourceId: String
    let resourceType: SearchResourceType
    let updateType: ResourceUpdateType
    let updatedAt: Date
    let newData: [String: String]
    let oldData: [String: String]?

    public init(
        resourceId: String,
        resourceType: SearchResourceType,
        updateType: ResourceUpdateType,
        updatedAt: Date,
        newData: [String: String],
        oldData: [String: String]? = nil
    ) {
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.updateType = updateType
        self.updatedAt = updatedAt
        self.newData = newData
        self.oldData = oldData
    }
}

public enum ResourceUpdateType: String, Codable, CaseIterable, Sendable {
    case created = "created"
    case updated = "updated"
    case deleted = "deleted"
    case statusChanged = "status_changed"
}

// MARK: - Nova Service Adapter

public actor NovaServiceAdapter: ServiceDataAdapter {
    public let serviceName = "nova"
    public let supportedResourceTypes: [SearchResourceType] = [.server, .flavor, .serverGroup]

    private let novaService: NovaService
    private let logger = Logger.shared

    public init(novaService: NovaService) {
        self.novaService = novaService
    }

    public func search(_ query: SearchQuery) async throws -> [SearchResult] {
        let startTime = Date().timeIntervalSinceReferenceDate
        var results: [SearchResult] = []

        // Search servers if included in query
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.server) {
            do {
                let serverResponse = try await novaService.listServers()
                let serverResults = filterAndConvertServers(serverResponse.servers, query: query)
                results.append(contentsOf: serverResults)
            } catch {
                logger.logError("NovaServiceAdapter - Server search failed: \(error)")
            }
        }

        // Search flavors if included in query
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.flavor) {
            do {
                let flavorResponse = try await novaService.listFlavors()
                let flavorResults = filterAndConvertFlavors(flavorResponse, query: query)
                results.append(contentsOf: flavorResults)
            } catch {
                logger.logError("NovaServiceAdapter - Flavor search failed: \(error)")
            }
        }

        // Search server groups if included in query
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.serverGroup) {
            do {
                let groupResponse = try await novaService.listServerGroups()
                let groupResults = filterAndConvertServerGroups(groupResponse, query: query)
                results.append(contentsOf: groupResults)
            } catch {
                logger.logError("NovaServiceAdapter - Server group search failed: \(error)")
            }
        }

        let searchTime = Date().timeIntervalSinceReferenceDate - startTime
        logger.logInfo("NovaServiceAdapter - Search completed in \(searchTime)s, found \(results.count) results")

        return results
    }

    public func getAllResources() async throws -> [any Sendable] {
        var resources: [any Sendable] = []

        let serverResponse = try await novaService.listServers()
        resources.append(contentsOf: serverResponse.servers)

        let flavorResponse = try await novaService.listFlavors()
        resources.append(contentsOf: flavorResponse)

        let groupResponse = try await novaService.listServerGroups()
        resources.append(contentsOf: groupResponse)

        return resources
    }

    public func getResourceById(_ id: String, type: SearchResourceType) async throws -> (any Sendable)? {
        switch type {
        case .server:
            return try await novaService.getServer(id: id)
        case .flavor:
            return try await novaService.getFlavor(id: id)
        case .serverGroup:
            // Server groups not directly accessible by ID in current implementation
            return nil
        default:
            return nil
        }
    }

    public func getResourceRelationships(_ resourceId: String, type: SearchResourceType) async throws -> [CrossServiceRelationship] {
        var relationships: [CrossServiceRelationship] = []

        switch type {
        case .server:
            let server = try await novaService.getServer(id: resourceId)

            // Server -> Flavor relationship
            if let flavorId = server.flavor?.id {
                relationships.append(CrossServiceRelationship(
                    sourceResourceId: resourceId,
                    sourceResourceType: .server,
                    targetResourceId: flavorId,
                    targetResourceType: .flavor,
                    relationshipType: CrossServiceRelationshipType.uses
                ))
            }

            // Server -> Image relationship
            if let imageId = server.image?.id {
                relationships.append(CrossServiceRelationship(
                    sourceResourceId: resourceId,
                    sourceResourceType: .server,
                    targetResourceId: imageId,
                    targetResourceType: .image,
                    relationshipType: CrossServiceRelationshipType.uses
                ))
            }

        default:
            break
        }

        return relationships
    }

    // MARK: - Private Helper Methods

    private func filterAndConvertServers(_ servers: [Server], query: SearchQuery) -> [SearchResult] {
        return servers.compactMap { server -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: server, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: server.id,
                resourceType: .server,
                name: server.name,
                description: nil,
                status: server.status?.rawValue,
                createdAt: server.createdAt,
                updatedAt: server.updatedAt,
                ipAddresses: extractIPAddresses(from: server),
                metadata: server.metadata ?? [:],
                tags: [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: server.name ?? "", query: query.text)
            )
        }
    }

    private func filterAndConvertFlavors(_ flavors: [Flavor], query: SearchQuery) -> [SearchResult] {
        return flavors.compactMap { flavor -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: flavor, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: flavor.id,
                resourceType: .flavor,
                name: flavor.name,
                description: flavor.description,
                status: nil,
                createdAt: nil,
                updatedAt: nil,
                ipAddresses: [],
                metadata: ["vcpus": String(flavor.vcpus), "ram": String(flavor.ram), "disk": String(flavor.disk)],
                tags: [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: flavor.name ?? "", query: query.text)
            )
        }
    }

    private func filterAndConvertServerGroups(_ groups: [ServerGroup], query: SearchQuery) -> [SearchResult] {
        return groups.compactMap { group -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: group, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: group.id,
                resourceType: .serverGroup,
                name: group.name,
                description: nil,
                status: nil,
                createdAt: nil,
                updatedAt: nil,
                ipAddresses: [],
                metadata: group.metadata ?? [:],
                tags: [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: group.name ?? "", query: query.text)
            )
        }
    }

    private func calculateRelevanceScore(for server: Server, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        // Name match (highest weight)
        if let name = server.name?.lowercased() {
            if name.contains(searchText) {
                score += name == searchText ? 10.0 : 5.0
            }
        }

        // Status match
        if server.status?.lowercased().contains(searchText) == true {
            score += 3.0
        }

        // ID match
        if server.id.lowercased().contains(searchText) {
            score += 2.0
        }

        // Apply filters
        for filter in query.filters where filter.enabled {
            if applyFilterToServer(filter, server) {
                score += 1.0
            } else {
                return 0.0 // Filter doesn't match, exclude result
            }
        }

        return score
    }

    private func calculateRelevanceScore(for flavor: Flavor, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        // Name match
        if flavor.name?.lowercased().contains(searchText) == true {
            score += flavor.name?.lowercased() == searchText ? 10.0 : 5.0
        }

        // Description match
        if let description = flavor.description?.lowercased(), description.contains(searchText) {
            score += 2.0
        }

        // ID match
        if flavor.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func calculateRelevanceScore(for group: ServerGroup, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        // Name match
        if group.name?.lowercased().contains(searchText) == true {
            score += group.name?.lowercased() == searchText ? 10.0 : 5.0
        }

        // ID match
        if group.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func applyFilterToServer(_ filter: SearchFilter, _ server: Server) -> Bool {
        switch filter.type {
        case .status(let statuses):
            if let status = server.status {
                return statuses.contains(status.rawValue)
            }
            return false
        case .dateRange(let from, let to):
            if let created = server.createdAt {
                return created >= from && created <= to
            }
            return false
        case .metadata(let key, let value, let op):
            guard let serverMetadata = server.metadata,
                  let metadataValue = serverMetadata[key] else {
                return false
            }
            return applyStringFilter(metadataValue, value: value, operator: op)
        default:
            return true
        }
    }

    private func applyStringFilter(_ text: String, value: String, operator: FilterOperator) -> Bool {
        let textLower = text.lowercased()
        let valueLower = value.lowercased()

        switch `operator` {
        case .equals:
            return textLower == valueLower
        case .contains:
            return textLower.contains(valueLower)
        case .startsWith:
            return textLower.hasPrefix(valueLower)
        case .endsWith:
            return textLower.hasSuffix(valueLower)
        }
    }

    private func extractIPAddresses(from server: Server) -> [String] {
        var ips: [String] = []

        if let addresses = server.addresses {
            for (_, addressList) in addresses {
                for address in addressList {
                    ips.append(address.addr)
                }
            }
        }

        return ips
    }

    private func findMatchHighlights(in text: String, query: String) -> [TextRange] {
        guard !query.isEmpty else { return [] }

        var highlights: [TextRange] = []
        let lowercaseText = text.lowercased()
        let lowercaseQuery = query.lowercased()

        var searchStartIndex = lowercaseText.startIndex

        while searchStartIndex < lowercaseText.endIndex {
            if let range = lowercaseText[searchStartIndex...].range(of: lowercaseQuery) {
                let startOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound)
                let endOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound)

                highlights.append(TextRange(start: startOffset, length: endOffset - startOffset))

                searchStartIndex = range.upperBound
            } else {
                break
            }
        }

        return highlights
    }
}

// MARK: - Neutron Service Adapter

public actor NeutronServiceAdapter: ServiceDataAdapter {
    public let serviceName = "neutron"
    public let supportedResourceTypes: [SearchResourceType] = [.network, .subnet, .port, .router, .floatingIP, .securityGroup]

    private let neutronService: NeutronService
    private let logger = Logger.shared

    public init(neutronService: NeutronService) {
        self.neutronService = neutronService
    }

    public func search(_ query: SearchQuery) async throws -> [SearchResult] {
        let startTime = Date().timeIntervalSinceReferenceDate
        var results: [SearchResult] = []

        // Search networks
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.network) {
            do {
                let networkResponse = try await neutronService.listNetworks()
                let networkResults = filterAndConvertNetworks(networkResponse, query: query)
                results.append(contentsOf: networkResults)
            } catch {
                logger.logError("NeutronServiceAdapter - Network search failed: \(error)")
            }
        }

        // Search subnets
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.subnet) {
            do {
                let subnetResponse = try await neutronService.listSubnets()
                let subnetResults = filterAndConvertSubnets(subnetResponse, query: query)
                results.append(contentsOf: subnetResults)
            } catch {
                logger.logError("NeutronServiceAdapter - Subnet search failed: \(error)")
            }
        }

        // Search ports
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.port) {
            do {
                let portResponse = try await neutronService.listPorts()
                let portResults = filterAndConvertPorts(portResponse, query: query)
                results.append(contentsOf: portResults)
            } catch {
                logger.logError("NeutronServiceAdapter - Port search failed: \(error)")
            }
        }

        // Search routers
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.router) {
            do {
                let routerResponse = try await neutronService.listRouters()
                let routerResults = filterAndConvertRouters(routerResponse, query: query)
                results.append(contentsOf: routerResults)
            } catch {
                logger.logError("NeutronServiceAdapter - Router search failed: \(error)")
            }
        }

        // Search floating IPs
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.floatingIP) {
            do {
                let floatingIPResponse = try await neutronService.listFloatingIPs()
                let floatingIPResults = filterAndConvertFloatingIPs(floatingIPResponse, query: query)
                results.append(contentsOf: floatingIPResults)
            } catch {
                logger.logError("NeutronServiceAdapter - Floating IP search failed: \(error)")
            }
        }

        // Search security groups
        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.securityGroup) {
            do {
                let securityGroupResponse = try await neutronService.listSecurityGroups()
                let securityGroupResults = filterAndConvertSecurityGroups(securityGroupResponse, query: query)
                results.append(contentsOf: securityGroupResults)
            } catch {
                logger.logError("NeutronServiceAdapter - Security group search failed: \(error)")
            }
        }

        let searchTime = Date().timeIntervalSinceReferenceDate - startTime
        logger.logInfo("NeutronServiceAdapter - Search completed in \(searchTime)s, found \(results.count) results")

        return results
    }

    public func getAllResources() async throws -> [any Sendable] {
        var resources: [any Sendable] = []

        let networkResponse = try await neutronService.listNetworks()
        resources.append(contentsOf: networkResponse)

        let subnetResponse = try await neutronService.listSubnets()
        resources.append(contentsOf: subnetResponse)

        let portResponse = try await neutronService.listPorts()
        resources.append(contentsOf: portResponse)

        let routerResponse = try await neutronService.listRouters()
        resources.append(contentsOf: routerResponse)

        let floatingIPResponse = try await neutronService.listFloatingIPs()
        resources.append(contentsOf: floatingIPResponse)

        let securityGroupResponse = try await neutronService.listSecurityGroups()
        resources.append(contentsOf: securityGroupResponse)

        return resources
    }

    public func getResourceById(_ id: String, type: SearchResourceType) async throws -> (any Sendable)? {
        switch type {
        case .network:
            return try await neutronService.getNetwork(id: id)
        case .subnet:
            return try await neutronService.getSubnet(id: id)
        case .port:
            return try await neutronService.getPort(id: id)
        case .router:
            return try await neutronService.getRouter(id: id)
        case .floatingIP:
            return try await neutronService.getFloatingIP(id: id)
        case .securityGroup:
            return try await neutronService.getSecurityGroup(id: id)
        default:
            return nil
        }
    }

    public func getResourceRelationships(_ resourceId: String, type: SearchResourceType) async throws -> [CrossServiceRelationship] {
        var relationships: [CrossServiceRelationship] = []

        switch type {
        case .network:
            let subnets = try await neutronService.listSubnets()
            for subnet in subnets {
                if subnet.networkId == resourceId {
                    relationships.append(CrossServiceRelationship(
                        sourceResourceId: resourceId,
                        sourceResourceType: .network,
                        targetResourceId: subnet.id,
                        targetResourceType: .subnet,
                        relationshipType: CrossServiceRelationshipType.contains
                    ))
                }
            }

        case .subnet:
            let subnet = try await neutronService.getSubnet(id: resourceId)
            relationships.append(CrossServiceRelationship(
                sourceResourceId: resourceId,
                sourceResourceType: .subnet,
                targetResourceId: subnet.networkId,
                targetResourceType: .network,
                relationshipType: CrossServiceRelationshipType.belongsTo
            ))

        case .port:
            let port = try await neutronService.getPort(id: resourceId)
            relationships.append(CrossServiceRelationship(
                sourceResourceId: resourceId,
                sourceResourceType: .port,
                targetResourceId: port.networkId,
                targetResourceType: .network,
                relationshipType: CrossServiceRelationshipType.belongsTo
            ))

        default:
            break
        }

        return relationships
    }

    // MARK: - Private Helper Methods

    private func filterAndConvertNetworks(_ networks: [Network], query: SearchQuery) -> [SearchResult] {
        return networks.compactMap { network -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: network, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: network.id,
                resourceType: .network,
                name: network.name,
                description: network.description,
                status: network.status,
                createdAt: network.createdAt,
                updatedAt: network.updatedAt,
                ipAddresses: [],
                metadata: [:],
                tags: network.tags ?? [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: network.name ?? "", query: query.text)
            )
        }
    }

    private func filterAndConvertSubnets(_ subnets: [Subnet], query: SearchQuery) -> [SearchResult] {
        return subnets.compactMap { subnet -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: subnet, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: subnet.id,
                resourceType: .subnet,
                name: subnet.name,
                description: subnet.description,
                status: nil,
                createdAt: subnet.createdAt,
                updatedAt: subnet.updatedAt,
                ipAddresses: [subnet.cidr],
                metadata: [:],
                tags: subnet.tags ?? [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: subnet.name ?? "", query: query.text)
            )
        }
    }

    private func filterAndConvertPorts(_ ports: [Port], query: SearchQuery) -> [SearchResult] {
        return ports.compactMap { port -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: port, query: query)
            guard matchScore > 0 else { return nil }

            let ips = port.fixedIps?.map { $0.ipAddress } ?? []

            return SearchResult(
                resourceId: port.id,
                resourceType: .port,
                name: port.name,
                description: port.description,
                status: port.status,
                createdAt: port.createdAt,
                updatedAt: port.updatedAt,
                ipAddresses: ips,
                metadata: [:],
                tags: port.tags ?? [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: port.name ?? "", query: query.text)
            )
        }
    }

    private func filterAndConvertRouters(_ routers: [Router], query: SearchQuery) -> [SearchResult] {
        return routers.compactMap { router -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: router, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: router.id,
                resourceType: .router,
                name: router.name,
                description: router.description,
                status: router.status,
                createdAt: router.createdAt,
                updatedAt: router.updatedAt,
                ipAddresses: [],
                metadata: [:],
                tags: router.tags ?? [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: router.name ?? "", query: query.text)
            )
        }
    }

    private func filterAndConvertFloatingIPs(_ floatingIPs: [FloatingIP], query: SearchQuery) -> [SearchResult] {
        return floatingIPs.compactMap { floatingIP -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: floatingIP, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: floatingIP.id,
                resourceType: .floatingIP,
                name: floatingIP.description,
                description: floatingIP.description,
                status: floatingIP.status,
                createdAt: floatingIP.createdAt,
                updatedAt: floatingIP.updatedAt,
                ipAddresses: floatingIP.floatingIpAddress.map { [$0] } ?? [],
                metadata: [:],
                tags: floatingIP.tags ?? [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: floatingIP.floatingIpAddress ?? "", query: query.text)
            )
        }
    }

    private func filterAndConvertSecurityGroups(_ securityGroups: [SecurityGroup], query: SearchQuery) -> [SearchResult] {
        return securityGroups.compactMap { securityGroup -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: securityGroup, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: securityGroup.id,
                resourceType: .securityGroup,
                name: securityGroup.name,
                description: securityGroup.description,
                status: nil,
                createdAt: securityGroup.createdAt,
                updatedAt: securityGroup.updatedAt,
                ipAddresses: [],
                metadata: [:],
                tags: securityGroup.tags ?? [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: securityGroup.name ?? "", query: query.text)
            )
        }
    }

    private func calculateRelevanceScore(for network: Network, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        if let name = network.name?.lowercased() {
            if name.contains(searchText) {
                score += name == searchText ? 10.0 : 5.0
            }
        }

        if let description = network.description?.lowercased(), description.contains(searchText) {
            score += 2.0
        }

        if network.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func calculateRelevanceScore(for subnet: Subnet, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        if let name = subnet.name?.lowercased() {
            if name.contains(searchText) {
                score += name == searchText ? 10.0 : 5.0
            }
        }

        if subnet.cidr.lowercased().contains(searchText) {
            score += 7.0
        }

        if subnet.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func calculateRelevanceScore(for port: Port, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        if let name = port.name?.lowercased() {
            if name.contains(searchText) {
                score += name == searchText ? 10.0 : 5.0
            }
        }

        if let fixedIPs = port.fixedIps {
            for fixedIP in fixedIPs {
                if fixedIP.ipAddress.lowercased().contains(searchText) {
                    score += 7.0
                }
            }
        }

        if port.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func calculateRelevanceScore(for router: Router, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        if let name = router.name?.lowercased() {
            if name.contains(searchText) {
                score += name == searchText ? 10.0 : 5.0
            }
        }

        if router.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func calculateRelevanceScore(for floatingIP: FloatingIP, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        if let ipAddress = floatingIP.floatingIpAddress, ipAddress.lowercased().contains(searchText) {
            score += 10.0
        }

        if let description = floatingIP.description?.lowercased(), description.contains(searchText) {
            score += 3.0
        }

        if floatingIP.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func calculateRelevanceScore(for securityGroup: SecurityGroup, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        if let name = securityGroup.name, name.lowercased().contains(searchText) {
            score += name.lowercased() == searchText ? 10.0 : 5.0
        }

        if let description = securityGroup.description?.lowercased(), description.contains(searchText) {
            score += 2.0
        }

        if securityGroup.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func findMatchHighlights(in text: String, query: String) -> [TextRange] {
        guard !query.isEmpty else { return [] }

        var highlights: [TextRange] = []
        let lowercaseText = text.lowercased()
        let lowercaseQuery = query.lowercased()

        var searchStartIndex = lowercaseText.startIndex

        while searchStartIndex < lowercaseText.endIndex {
            if let range = lowercaseText[searchStartIndex...].range(of: lowercaseQuery) {
                let startOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound)
                let endOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound)

                highlights.append(TextRange(start: startOffset, length: endOffset - startOffset))
                searchStartIndex = range.upperBound
            } else {
                break
            }
        }

        return highlights
    }
}

// MARK: - Cinder Service Adapter

public actor CinderServiceAdapter: ServiceDataAdapter {
    public let serviceName = "cinder"
    public let supportedResourceTypes: [SearchResourceType] = [.volume]

    private let cinderService: CinderService
    private let logger = Logger.shared

    public init(cinderService: CinderService) {
        self.cinderService = cinderService
    }

    public func search(_ query: SearchQuery) async throws -> [SearchResult] {
        let startTime = Date().timeIntervalSinceReferenceDate
        var results: [SearchResult] = []

        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.volume) {
            do {
                let volumeResponse = try await cinderService.listVolumes()
                let volumeResults = filterAndConvertVolumes(volumeResponse, query: query)
                results.append(contentsOf: volumeResults)
            } catch {
                logger.logError("CinderServiceAdapter - Volume search failed: \(error)")
            }
        }

        let searchTime = Date().timeIntervalSinceReferenceDate - startTime
        logger.logInfo("CinderServiceAdapter - Search completed in \(searchTime)s, found \(results.count) results")

        return results
    }

    public func getAllResources() async throws -> [any Sendable] {
        let volumeResponse = try await cinderService.listVolumes()
        return volumeResponse
    }

    public func getResourceById(_ id: String, type: SearchResourceType) async throws -> (any Sendable)? {
        switch type {
        case .volume:
            return try await cinderService.getVolume(id: id)
        default:
            return nil
        }
    }

    public func getResourceRelationships(_ resourceId: String, type: SearchResourceType) async throws -> [CrossServiceRelationship] {
        var relationships: [CrossServiceRelationship] = []

        switch type {
        case .volume:
            let volume = try await cinderService.getVolume(id: resourceId)

            // Volume -> Server relationship (if attached)
            if let attachments = volume.attachments {
                for attachment in attachments {
                    if let serverId = attachment.serverId {
                        relationships.append(CrossServiceRelationship(
                            sourceResourceId: resourceId,
                            sourceResourceType: .volume,
                            targetResourceId: serverId,
                            targetResourceType: .server,
                            relationshipType: CrossServiceRelationshipType.attachedTo
                        ))
                    }
                }
            }

        default:
            break
        }

        return relationships
    }

    private func filterAndConvertVolumes(_ volumes: [Volume], query: SearchQuery) -> [SearchResult] {
        return volumes.compactMap { volume -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: volume, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: volume.id,
                resourceType: .volume,
                name: volume.name,
                description: volume.description,
                status: volume.status,
                createdAt: volume.createdAt,
                updatedAt: volume.updatedAt,
                ipAddresses: [],
                metadata: volume.metadata ?? [:],
                tags: [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: volume.name ?? "", query: query.text)
            )
        }
    }

    private func calculateRelevanceScore(for volume: Volume, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        if let name = volume.name?.lowercased() {
            if name.contains(searchText) {
                score += name == searchText ? 10.0 : 5.0
            }
        }

        if let description = volume.description?.lowercased(), description.contains(searchText) {
            score += 2.0
        }

        if let status = volume.status, status.lowercased().contains(searchText) {
            score += 3.0
        }

        if volume.id.lowercased().contains(searchText) {
            score += 2.0
        }

        return score
    }

    private func findMatchHighlights(in text: String, query: String) -> [TextRange] {
        guard !query.isEmpty else { return [] }

        var highlights: [TextRange] = []
        let lowercaseText = text.lowercased()
        let lowercaseQuery = query.lowercased()

        var searchStartIndex = lowercaseText.startIndex

        while searchStartIndex < lowercaseText.endIndex {
            if let range = lowercaseText[searchStartIndex...].range(of: lowercaseQuery) {
                let startOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound)
                let endOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound)

                highlights.append(TextRange(start: startOffset, length: endOffset - startOffset))
                searchStartIndex = range.upperBound
            } else {
                break
            }
        }

        return highlights
    }
}

// MARK: - Glance Service Adapter

public actor GlanceServiceAdapter: ServiceDataAdapter {
    public let serviceName = "glance"
    public let supportedResourceTypes: [SearchResourceType] = [.image]

    private let glanceService: GlanceService
    private let logger = Logger.shared

    public init(glanceService: GlanceService) {
        self.glanceService = glanceService
    }

    public func search(_ query: SearchQuery) async throws -> [SearchResult] {
        let startTime = Date().timeIntervalSinceReferenceDate
        var results: [SearchResult] = []

        if query.resourceTypes.isEmpty || query.resourceTypes.contains(.image) {
            do {
                let imageResponse = try await glanceService.listImages()
                let imageResults = filterAndConvertImages(imageResponse, query: query)
                results.append(contentsOf: imageResults)
            } catch {
                logger.logError("GlanceServiceAdapter - Image search failed: \(error)")
            }
        }

        let searchTime = Date().timeIntervalSinceReferenceDate - startTime
        logger.logInfo("GlanceServiceAdapter - Search completed in \(searchTime)s, found \(results.count) results")

        return results
    }

    public func getAllResources() async throws -> [any Sendable] {
        let imageResponse = try await glanceService.listImages()
        return imageResponse
    }

    public func getResourceById(_ id: String, type: SearchResourceType) async throws -> (any Sendable)? {
        switch type {
        case .image:
            return try await glanceService.getImage(id: id)
        default:
            return nil
        }
    }

    public func getResourceRelationships(_ resourceId: String, type: SearchResourceType) async throws -> [CrossServiceRelationship] {
        return []
    }

    private func filterAndConvertImages(_ images: [Image], query: SearchQuery) -> [SearchResult] {
        return images.compactMap { image -> SearchResult? in
            let matchScore = calculateRelevanceScore(for: image, query: query)
            guard matchScore > 0 else { return nil }

            return SearchResult(
                resourceId: image.id,
                resourceType: .image,
                name: image.name,
                description: nil,
                status: image.status,
                createdAt: image.createdAt,
                updatedAt: image.updatedAt,
                ipAddresses: [],
                metadata: image.properties ?? [:],
                tags: image.tags ?? [],
                relevanceScore: matchScore,
                matchHighlights: findMatchHighlights(in: image.name ?? "", query: query.text)
            )
        }
    }

    private func calculateRelevanceScore(for image: Image, query: SearchQuery) -> Double {
        var score: Double = 0.0
        let searchText = query.text.lowercased()

        if let name = image.name, name.lowercased().contains(searchText) {
            score += name.lowercased() == searchText ? 10.0 : 5.0
        }

        if let status = image.status, status.lowercased().contains(searchText) {
            score += 3.0
        }

        if image.id.lowercased().contains(searchText) {
            score += 2.0
        }

        // Check tags for matches
        if let tags = image.tags {
            for tag in tags {
                if tag.lowercased().contains(searchText) {
                    score += 4.0
                }
            }
        }

        return score
    }

    private func findMatchHighlights(in text: String, query: String) -> [TextRange] {
        guard !query.isEmpty else { return [] }

        var highlights: [TextRange] = []
        let lowercaseText = text.lowercased()
        let lowercaseQuery = query.lowercased()

        var searchStartIndex = lowercaseText.startIndex

        while searchStartIndex < lowercaseText.endIndex {
            if let range = lowercaseText[searchStartIndex...].range(of: lowercaseQuery) {
                let startOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound)
                let endOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound)

                highlights.append(TextRange(start: startOffset, length: endOffset - startOffset))
                searchStartIndex = range.upperBound
            } else {
                break
            }
        }

        return highlights
    }
}

// MARK: - Keystone Service Adapter

public actor KeystoneServiceAdapter: ServiceDataAdapter {
    public let serviceName = "keystone"
    public let supportedResourceTypes: [SearchResourceType] = [] // Keystone doesn't have searchable resources in current model

    private let keystoneService: KeystoneService
    private let logger = Logger.shared

    public init(keystoneService: KeystoneService) {
        self.keystoneService = keystoneService
    }

    public func search(_ query: SearchQuery) async throws -> [SearchResult] {
        // Keystone typically doesn't have resources that match our current search model
        // This would be extended for users, projects, domains, etc. if needed
        return []
    }

    public func getAllResources() async throws -> [any Sendable] {
        return []
    }

    public func getResourceById(_ id: String, type: SearchResourceType) async throws -> (any Sendable)? {
        return nil
    }

    public func getResourceRelationships(_ resourceId: String, type: SearchResourceType) async throws -> [CrossServiceRelationship] {
        return []
    }
}