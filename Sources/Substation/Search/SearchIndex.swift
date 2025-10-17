import Foundation
import OSClient
import struct OSClient.Port

// MARK: - Search Index Core

actor SearchIndex {
    private var textIndex: TextIndex = TextIndex()
    private var ipIndex: IPIndex = IPIndex()
    private var metadataIndex: MetadataIndex = MetadataIndex()
    private var tagIndex: TagIndex = TagIndex()

    private var totalResources = 0
    private var lastUpdateTime = Date.distantPast

    // MARK: - Index Update Interface

    func updateIndex(with resources: SearchableResources) async {
        let startTime = Date().timeIntervalSinceReferenceDate

        Logger.shared.logInfo("SearchIndex - Starting index update with \(getTotalResourceCount(resources)) resources")

        await textIndex.clear()
        await ipIndex.clear()
        await metadataIndex.clear()
        await tagIndex.clear()

        var resourceCount = 0

        // Index servers
        for server in resources.servers {
            await indexServer(server)
            resourceCount += 1
        }

        // Index networks
        for network in resources.networks {
            await indexNetwork(network)
            resourceCount += 1
        }

        // Index volumes
        for volume in resources.volumes {
            await indexVolume(volume)
            resourceCount += 1
        }

        // Index images
        for image in resources.images {
            await indexImage(image)
            resourceCount += 1
        }

        // Index flavors
        for flavor in resources.flavors {
            await indexFlavor(flavor)
            resourceCount += 1
        }

        // Index security groups
        for securityGroup in resources.securityGroups {
            await indexSecurityGroup(securityGroup)
            resourceCount += 1
        }

        // Index key pairs
        for keyPair in resources.keyPairs {
            await indexKeyPair(keyPair)
            resourceCount += 1
        }

        // Index subnets
        for subnet in resources.subnets {
            await indexSubnet(subnet)
            resourceCount += 1
        }

        // Index ports
        for port in resources.ports {
            await indexPort(port)
            resourceCount += 1
        }

        // Index routers
        for router in resources.routers {
            await indexRouter(router)
            resourceCount += 1
        }

        // Index floating IPs
        for floatingIP in resources.floatingIPs {
            await indexFloatingIP(floatingIP)
            resourceCount += 1
        }

        // Index server groups
        for serverGroup in resources.serverGroups {
            await indexServerGroup(serverGroup)
            resourceCount += 1
        }

        // Index volume snapshots
        for volumeSnapshot in resources.volumeSnapshots {
            await indexVolumeSnapshot(volumeSnapshot)
            resourceCount += 1
        }

        // Index volume backups
        for volumeBackup in resources.volumeBackups {
            await indexVolumeBackup(volumeBackup)
            resourceCount += 1
        }

        // Index Barbican secrets
        for secret in resources.barbicanSecrets {
            await indexBarbicanSecret(secret)
            resourceCount += 1
        }

        // Index load balancers
        for loadBalancer in resources.loadBalancers {
            await indexLoadBalancer(loadBalancer)
            resourceCount += 1
        }

        // Index Swift containers
        for swiftContainer in resources.swiftContainers {
            await indexSwiftContainer(swiftContainer)
            resourceCount += 1
        }

        // Index Swift objects
        for swiftObject in resources.swiftObjects {
            await indexSwiftObject(swiftObject)
            resourceCount += 1
        }

        totalResources = resourceCount
        lastUpdateTime = Date()

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        Logger.shared.logInfo("SearchIndex - Index updated with \(totalResources) resources in \(String(format: "%.1f", duration * 1000))ms")
    }

    // MARK: - Search Interface

    func searchText(_ query: String, fuzzy: Bool = false) async -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []

        // Search in text index
        let textResults = await textIndex.search(query, fuzzy: fuzzy)
        results.append(contentsOf: textResults)

        // Search in IP addresses if query looks like an IP
        if query.isValidIPPattern {
            let ipResults = await ipIndex.search(query)
            results.append(contentsOf: ipResults)
        }

        // Search in metadata
        let metadataResults = await metadataIndex.search(query)
        results.append(contentsOf: metadataResults)

        // Search in tags
        let tagResults = await tagIndex.search(query)
        results.append(contentsOf: tagResults)

        // Merge and deduplicate results
        return mergeResults(results)
    }

    func getSuggestions(for partialQuery: String, limit: Int = 10) async -> [SearchSuggestion] {
        guard partialQuery.count >= 2 else { return [] }

        var suggestions: [SearchSuggestion] = []

        // Get text-based suggestions
        let textSuggestions = await textIndex.getSuggestions(for: partialQuery, limit: limit / 2)
        suggestions.append(contentsOf: textSuggestions)

        // Get tag suggestions
        let tagSuggestions = await tagIndex.getSuggestions(for: partialQuery, limit: limit / 2)
        suggestions.append(contentsOf: tagSuggestions)

        // Sort by relevance and limit
        suggestions.sort { $0.score > $1.score }
        return Array(suggestions.prefix(limit))
    }

    func getStats() -> SearchIndexStats {
        return SearchIndexStats(
            totalResources: totalResources,
            lastUpdateTime: lastUpdateTime,
            indexSizeBytes: getIndexSize()
        )
    }

    // MARK: - Private Resource Indexing Methods

    private func indexServer(_ server: Server) async {
        let searchableText = buildServerSearchText(server)
        let ipAddresses = extractServerIPs(server)
        let metadata = server.metadata ?? [:]
        let tags = extractServerTags(server)

        let result = SearchResult(
            resourceId: server.id,
            resourceType: .server,
            name: server.name,
            description: nil,
            status: server.status?.rawValue,
            createdAt: server.createdAt,
            updatedAt: server.updatedAt,
            ipAddresses: ipAddresses,
            metadata: metadata,
            tags: tags,
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await ipIndex.addEntries(ipAddresses, result: result)
        await metadataIndex.addEntries(metadata, result: result)
        await tagIndex.addEntries(tags, result: result)
    }

    private func indexNetwork(_ network: Network) async {
        let searchableText = buildNetworkSearchText(network)
        let metadata: [String: String] = [:] // Networks don't have metadata in this model
        let tags = extractNetworkTags(network)

        let result = SearchResult(
            resourceId: network.id,
            resourceType: .network,
            name: network.name,
            description: network.description,
            status: network.status,
            createdAt: network.createdAt,
            updatedAt: network.updatedAt,
            ipAddresses: [],
            metadata: metadata,
            tags: tags,
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await metadataIndex.addEntries(metadata, result: result)
        await tagIndex.addEntries(tags, result: result)
    }

    private func indexVolume(_ volume: Volume) async {
        let searchableText = buildVolumeSearchText(volume)
        let metadata = volume.metadata ?? [:]
        let tags = extractVolumeTags(volume)

        let result = SearchResult(
            resourceId: volume.id,
            resourceType: .volume,
            name: volume.name,
            description: volume.description,
            status: volume.status,
            createdAt: volume.createdAt,
            updatedAt: volume.updatedAt,
            ipAddresses: [],
            metadata: metadata,
            tags: tags,
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await metadataIndex.addEntries(metadata, result: result)
        await tagIndex.addEntries(tags, result: result)
    }

    private func indexImage(_ image: Image) async {
        let searchableText = buildImageSearchText(image)
        let metadata = image.metadata ?? [:]
        let tags = extractImageTags(image)

        let result = SearchResult(
            resourceId: image.id,
            resourceType: .image,
            name: image.name,
            description: nil, // Images don't have description in this model
            status: image.status,
            createdAt: image.createdAt,
            updatedAt: image.updatedAt,
            ipAddresses: [],
            metadata: metadata,
            tags: tags,
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await metadataIndex.addEntries(metadata, result: result)
        await tagIndex.addEntries(tags, result: result)
    }

    private func indexFlavor(_ flavor: Flavor) async {
        let searchableText = buildFlavorSearchText(flavor)

        let result = SearchResult(
            resourceId: flavor.id,
            resourceType: .flavor,
            name: flavor.name,
            description: flavor.description,
            status: nil,
            createdAt: nil,
            updatedAt: nil,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    private func indexSecurityGroup(_ securityGroup: SecurityGroup) async {
        let searchableText = buildSecurityGroupSearchText(securityGroup)
        let tags = extractSecurityGroupTags(securityGroup)

        let result = SearchResult(
            resourceId: securityGroup.id,
            resourceType: .securityGroup,
            name: securityGroup.name,
            description: securityGroup.description,
            status: nil,
            createdAt: securityGroup.createdAt,
            updatedAt: securityGroup.updatedAt,
            ipAddresses: [],
            metadata: [:],
            tags: tags,
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await tagIndex.addEntries(tags, result: result)
    }

    private func indexKeyPair(_ keyPair: KeyPair) async {
        let searchableText = buildKeyPairSearchText(keyPair)

        let result = SearchResult(
            resourceId: keyPair.name ?? keyPair.fingerprint ?? "unknown",
            resourceType: .keyPair,
            name: keyPair.name,
            description: nil,
            status: nil,
            createdAt: nil,
            updatedAt: nil,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    private func indexSubnet(_ subnet: Subnet) async {
        let searchableText = buildSubnetSearchText(subnet)
        let ipAddresses = [subnet.cidr]

        let result = SearchResult(
            resourceId: subnet.id,
            resourceType: .subnet,
            name: subnet.name,
            description: subnet.description,
            status: nil,
            createdAt: nil,
            updatedAt: nil,
            ipAddresses: ipAddresses,
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await ipIndex.addEntries(ipAddresses, result: result)
    }

    private func indexPort(_ port: Port) async {
        let searchableText = buildPortSearchText(port)
        let ipAddresses = port.fixedIps?.compactMap { $0.ipAddress } ?? []

        let result = SearchResult(
            resourceId: port.id,
            resourceType: .port,
            name: port.name,
            description: port.description,
            status: port.status,
            createdAt: port.createdAt,
            updatedAt: port.updatedAt,
            ipAddresses: ipAddresses,
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await ipIndex.addEntries(ipAddresses, result: result)
    }

    private func indexRouter(_ router: Router) async {
        let searchableText = buildRouterSearchText(router)

        let result = SearchResult(
            resourceId: router.id,
            resourceType: .router,
            name: router.name,
            description: router.description,
            status: router.status,
            createdAt: nil,
            updatedAt: nil,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    private func indexFloatingIP(_ floatingIP: FloatingIP) async {
        let searchableText = buildFloatingIPSearchText(floatingIP)
        let ipAddresses = [floatingIP.floatingIpAddress, floatingIP.fixedIpAddress].compactMap { $0 }

        let result = SearchResult(
            resourceId: floatingIP.id,
            resourceType: .floatingIP,
            name: nil,
            description: floatingIP.description,
            status: floatingIP.status,
            createdAt: floatingIP.createdAt,
            updatedAt: floatingIP.updatedAt,
            ipAddresses: ipAddresses,
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await ipIndex.addEntries(ipAddresses, result: result)
    }

    private func indexServerGroup(_ serverGroup: ServerGroup) async {
        let searchableText = buildServerGroupSearchText(serverGroup)

        let result = SearchResult(
            resourceId: serverGroup.id,
            resourceType: .serverGroup,
            name: serverGroup.name,
            description: nil,
            status: nil,
            createdAt: nil,
            updatedAt: nil,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    private func indexVolumeSnapshot(_ snapshot: VolumeSnapshot) async {
        let searchableText = buildVolumeSnapshotSearchText(snapshot)

        let result = SearchResult(
            resourceId: snapshot.id,
            resourceType: .volumeSnapshot,
            name: snapshot.name,
            description: snapshot.description,
            status: snapshot.status,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    private func indexVolumeBackup(_ backup: VolumeBackup) async {
        let searchableText = buildVolumeBackupSearchText(backup)

        let result = SearchResult(
            resourceId: backup.id,
            resourceType: .volumeBackup,
            name: backup.name,
            description: backup.description,
            status: backup.status,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    private func indexBarbicanSecret(_ secret: Secret) async {
        let searchableText = buildBarbicanSecretSearchText(secret)

        let result = SearchResult(
            resourceId: secret.secretRef ?? secret.id,
            resourceType: .barbicanSecret,
            name: secret.name,
            description: nil,
            status: secret.status,
            createdAt: secret.created,
            updatedAt: secret.updated,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    private func indexLoadBalancer(_ loadBalancer: LoadBalancer) async {
        let searchableText = buildLoadBalancerSearchText(loadBalancer)

        let result = SearchResult(
            resourceId: loadBalancer.id,
            resourceType: .loadBalancer,
            name: loadBalancer.name,
            description: nil,
            status: loadBalancer.provisioningStatus,
            createdAt: nil,
            updatedAt: nil,
            ipAddresses: [loadBalancer.vipAddress],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
        await ipIndex.addEntries([loadBalancer.vipAddress], result: result)
    }

    private func indexSwiftContainer(_ container: SwiftContainer) async {
        let searchableText = buildSwiftContainerSearchText(container)

        let result = SearchResult(
            resourceId: container.name ?? "",
            resourceType: .swiftContainer,
            name: container.name ?? "",
            description: nil,
            status: nil,
            createdAt: nil,
            updatedAt: nil,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    private func indexSwiftObject(_ object: SwiftObject) async {
        let searchableText = buildSwiftObjectSearchText(object)

        let result = SearchResult(
            resourceId: object.name ?? "",
            resourceType: .swiftObject,
            name: object.name ?? "",
            description: nil,
            status: nil,
            createdAt: nil,
            updatedAt: object.lastModified,
            ipAddresses: [],
            metadata: [:],
            tags: [],
            relevanceScore: 0.0,
            matchHighlights: [],
            relationships: []
        )

        await textIndex.addEntry(searchableText, result: result)
    }

    // MARK: - Text Building Methods

    private func buildServerSearchText(_ server: Server) -> String {
        var components: [String] = []

        if let name = server.name { components.append(name) }
        if let status = server.status?.rawValue { components.append(status) }
        components.append(server.id)

        // Add flavor name if available
        if let flavorName = server.flavor?.name { components.append(flavorName) }

        // Add image name if available
        if let imageName = server.image?.name { components.append(imageName) }

        // Add metadata values
        if let metadata = server.metadata {
            components.append(contentsOf: metadata.values)
        }

        return components.joined(separator: " ")
    }

    private func buildNetworkSearchText(_ network: Network) -> String {
        var components: [String] = []

        if let name = network.name { components.append(name) }
        if let status = network.status { components.append(status) }
        if let description = network.description { components.append(description) }
        components.append(network.id)

        return components.joined(separator: " ")
    }

    private func buildVolumeSearchText(_ volume: Volume) -> String {
        var components: [String] = []

        if let name = volume.name { components.append(name) }
        if let status = volume.status { components.append(status) }
        if let description = volume.description { components.append(description) }
        components.append(volume.id)

        return components.joined(separator: " ")
    }

    private func buildImageSearchText(_ image: Image) -> String {
        var components: [String] = []

        if let name = image.name { components.append(name) }
        if let status = image.status { components.append(status) }
        // Images don't have description in this model
        components.append(image.id)

        return components.joined(separator: " ")
    }

    private func buildFlavorSearchText(_ flavor: Flavor) -> String {
        var components: [String] = []

        if let name = flavor.name { components.append(name) }
        if let description = flavor.description { components.append(description) }
        components.append(flavor.id)

        return components.joined(separator: " ")
    }

    private func buildSecurityGroupSearchText(_ securityGroup: SecurityGroup) -> String {
        var components: [String] = []

        if let name = securityGroup.name { components.append(name) }
        if let description = securityGroup.description { components.append(description) }
        components.append(securityGroup.id)

        return components.joined(separator: " ")
    }

    private func buildKeyPairSearchText(_ keyPair: KeyPair) -> String {
        var components: [String] = []

        if let name = keyPair.name { components.append(name) }
        if let type = keyPair.type { components.append(type) }
        if let fingerprint = keyPair.fingerprint { components.append(fingerprint) }

        return components.joined(separator: " ")
    }

    private func buildSubnetSearchText(_ subnet: Subnet) -> String {
        var components: [String] = []

        if let name = subnet.name { components.append(name) }
        if let description = subnet.description { components.append(description) }
        components.append(subnet.cidr)
        components.append(subnet.id)
        components.append(subnet.networkId)

        return components.joined(separator: " ")
    }

    private func buildPortSearchText(_ port: Port) -> String {
        var components: [String] = []

        if let name = port.name { components.append(name) }
        if let description = port.description { components.append(description) }
        if let status = port.status { components.append(status) }
        components.append(port.id)
        components.append(port.networkId)

        if let deviceId = port.deviceId { components.append(deviceId) }

        return components.joined(separator: " ")
    }

    private func buildRouterSearchText(_ router: Router) -> String {
        var components: [String] = []

        if let name = router.name { components.append(name) }
        if let description = router.description { components.append(description) }
        if let status = router.status { components.append(status) }
        components.append(router.id)

        return components.joined(separator: " ")
    }

    private func buildFloatingIPSearchText(_ floatingIP: FloatingIP) -> String {
        var components: [String] = []

        if let description = floatingIP.description { components.append(description) }
        if let status = floatingIP.status { components.append(status) }
        if let floatingIp = floatingIP.floatingIpAddress { components.append(floatingIp) }
        if let fixedIp = floatingIP.fixedIpAddress { components.append(fixedIp) }
        components.append(floatingIP.id)

        if let portId = floatingIP.portId { components.append(portId) }

        return components.joined(separator: " ")
    }

    private func buildServerGroupSearchText(_ serverGroup: ServerGroup) -> String {
        var components: [String] = []

        if let name = serverGroup.name { components.append(name) }
        components.append(serverGroup.id)

        if let policies = serverGroup.policies {
            components.append(contentsOf: policies)
        }

        return components.joined(separator: " ")
    }

    private func buildVolumeSnapshotSearchText(_ snapshot: VolumeSnapshot) -> String {
        var components: [String] = []

        if let name = snapshot.name { components.append(name) }
        if let description = snapshot.description { components.append(description) }
        if let status = snapshot.status { components.append(status) }
        components.append(snapshot.id)
        components.append(snapshot.volumeId)

        return components.joined(separator: " ")
    }

    private func buildVolumeBackupSearchText(_ backup: VolumeBackup) -> String {
        var components: [String] = []

        if let name = backup.name { components.append(name) }
        if let description = backup.description { components.append(description) }
        if let status = backup.status { components.append(status) }
        components.append(backup.id)
        if let volumeId = backup.volumeId { components.append(volumeId) }

        return components.joined(separator: " ")
    }

    private func buildBarbicanSecretSearchText(_ secret: Secret) -> String {
        var components: [String] = []

        if let name = secret.name { components.append(name) }
        if let status = secret.status { components.append(status) }
        if let algorithm = secret.algorithm { components.append(algorithm) }
        if let secretRef = secret.secretRef { components.append(secretRef) }

        return components.joined(separator: " ")
    }

    private func buildLoadBalancerSearchText(_ loadBalancer: LoadBalancer) -> String {
        var components: [String] = []

        components.append(loadBalancer.name)
        components.append(loadBalancer.provisioningStatus)
        components.append(loadBalancer.operatingStatus)
        components.append(loadBalancer.vipAddress)
        components.append(loadBalancer.id)

        return components.joined(separator: " ")
    }

    private func buildSwiftContainerSearchText(_ container: SwiftContainer) -> String {
        var components: [String] = []

        if let name = container.name {
            components.append(name)
        }
        components.append(String(container.count))
        components.append(String(container.bytes))

        return components.joined(separator: " ")
    }

    private func buildSwiftObjectSearchText(_ object: SwiftObject) -> String {
        var components: [String] = []

        if let name = object.name {
            components.append(name)
        }
        if let contentType = object.contentType {
            components.append(contentType)
        }
        components.append(String(object.bytes))

        return components.joined(separator: " ")
    }

    // MARK: - Utility Methods

    private func extractServerIPs(_ server: Server) -> [String] {
        var ips: [String] = []

        if let addresses = server.addresses {
            for (_, networkAddresses) in addresses {
                for address in networkAddresses {
                    ips.append(address.addr)
                }
            }
        }

        return ips
    }

    private func extractServerTags(_ server: Server) -> [String] {
        // Extract tags from server metadata or other sources
        var tags: [String] = []

        if let metadata = server.metadata {
            // Look for common tag patterns in metadata
            for (key, value) in metadata {
                if key.lowercased().contains("tag") || key.lowercased().contains("label") {
                    tags.append(value)
                }
            }
        }

        return tags
    }

    private func extractNetworkTags(_ network: Network) -> [String] {
        return []  // Networks typically don't have explicit tags
    }

    private func extractVolumeTags(_ volume: Volume) -> [String] {
        var tags: [String] = []

        if let metadata = volume.metadata {
            for (key, value) in metadata {
                if key.lowercased().contains("tag") || key.lowercased().contains("label") {
                    tags.append(value)
                }
            }
        }

        return tags
    }

    private func extractImageTags(_ image: Image) -> [String] {
        var tags: [String] = []

        if let metadata = image.metadata {
            for (key, value) in metadata {
                if key.lowercased().contains("tag") || key.lowercased().contains("label") {
                    tags.append(value)
                }
            }
        }

        return tags
    }

    private func extractSecurityGroupTags(_ securityGroup: SecurityGroup) -> [String] {
        return []  // Security groups typically don't have explicit tags
    }

    private func getTotalResourceCount(_ resources: SearchableResources) -> Int {
        return resources.servers.count +
               resources.networks.count +
               resources.volumes.count +
               resources.images.count +
               resources.flavors.count +
               resources.securityGroups.count +
               resources.keyPairs.count +
               resources.subnets.count +
               resources.ports.count +
               resources.routers.count +
               resources.floatingIPs.count
    }

    private func mergeResults(_ results: [SearchResult]) -> [SearchResult] {
        // Remove duplicates and merge relevance scores
        var uniqueResults: [String: SearchResult] = [:]

        for result in results {
            let key = "\(result.resourceType.rawValue):\(result.resourceId)"

            if let existing = uniqueResults[key] {
                // Merge with higher relevance score
                var merged = existing
                merged.relevanceScore = max(existing.relevanceScore, result.relevanceScore)
                uniqueResults[key] = merged
            } else {
                uniqueResults[key] = result
            }
        }

        return Array(uniqueResults.values).sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func getIndexSize() -> Int {
        // Rough estimate of index size in bytes
        return totalResources * 500 // Estimated 500 bytes per indexed resource
    }
}

// MARK: - Supporting Types

struct SearchIndexStats {
    let totalResources: Int
    let lastUpdateTime: Date
    let indexSizeBytes: Int
}

extension String {
    var isValidIPPattern: Bool {
        return self.isValidIPAddress ||
               self.contains(".") && self.count >= 3 ||
               self.contains("*") ||
               self.contains("/")
    }
}