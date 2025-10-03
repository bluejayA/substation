import Foundation
import OSClient

@MainActor
struct ResourceResolver {
    private let cachedServers: [Server]
    private let cachedNetworks: [Network]
    private let cachedImages: [Image]
    private let cachedFlavors: [Flavor]
    private let cachedSubnets: [Subnet]
    private let cachedSecurityGroups: [SecurityGroup]
    private let resourceNameCache: ResourceNameCache
    private let client: OSClient

    init(
        cachedServers: [Server],
        cachedNetworks: [Network],
        cachedImages: [Image],
        cachedFlavors: [Flavor],
        cachedSubnets: [Subnet],
        cachedSecurityGroups: [SecurityGroup],
        resourceNameCache: ResourceNameCache,
        client: OSClient
    ) {
        self.cachedServers = cachedServers
        self.cachedNetworks = cachedNetworks
        self.cachedImages = cachedImages
        self.cachedFlavors = cachedFlavors
        self.cachedSubnets = cachedSubnets
        self.cachedSecurityGroups = cachedSecurityGroups
        self.resourceNameCache = resourceNameCache
        self.client = client
    }

    func resolveFlavorAsync(_ id: String) async -> Flavor? {
        // Only try to find in current cache - no API calls during drawing
        if let flavor = cachedFlavors.first(where: { $0.id == id }) {
            await resourceNameCache.setFlavorNameAsync(flavor.id, name: flavor.name ?? flavor.id)
            return flavor
        }

        // If not found, return nil without making API call
        return nil
    }

    func resolveFlavorNameAsync(_ id: String) async -> String {
        if let cachedName = await resourceNameCache.getFlavorNameAsync(id) {
            return cachedName
        }

        // Only try to find in current cache - no API calls during drawing
        if let flavor = cachedFlavors.first(where: { $0.id == id }) {
            await resourceNameCache.setFlavorNameAsync(flavor.id, name: flavor.name ?? flavor.id)
            return flavor.name ?? flavor.id
        }

        // Return ID as fallback without making expensive API call
        return id
    }

    func resolveImageNameAsync(_ id: String) async -> String {
        if let cachedName = await resourceNameCache.getImageNameAsync(id) {
            return cachedName
        }

        // Only try to find in current cache - no API calls during drawing
        if let image = cachedImages.first(where: { $0.id == id }) {
            let name = image.name ?? "Unnamed Image"
            await resourceNameCache.setImageNameAsync(image.id, name: name)
            return name
        }

        // Return ID as fallback without making expensive API call
        return id
    }

    func resolveNetworkName(_ id: String) async -> String {
        if let cachedName = await resourceNameCache.getNetworkNameAsync(id) {
            return cachedName
        }

        // Only try to find in current cache - no API calls during drawing
        if let network = cachedNetworks.first(where: { $0.id == id }) {
            await resourceNameCache.setNetworkNameAsync(network.id, name: network.name ?? "Unknown Network")
            return network.name ?? "Unknown Network"
        }

        // Return ID as fallback without making expensive API call
        return id
    }

    // Helper function to pre-populate cache with all known names
    func prePopulateCache() {
        Logger.shared.logDebug("ResourceResolver: Pre-populating resource name cache")

        let startTime = Date().timeIntervalSinceReferenceDate

        Task {
            // Pre-cache all flavor names
            for flavor in cachedFlavors {
                await resourceNameCache.setFlavorNameAsync(flavor.id, name: flavor.name ?? flavor.id)
            }

            // Pre-cache all image names
            for image in cachedImages {
                let name = image.name ?? "Unnamed Image"
                await resourceNameCache.setImageNameAsync(image.id, name: name)
            }

            // Pre-cache all network names
            for network in cachedNetworks {
                await resourceNameCache.setNetworkNameAsync(network.id, name: network.name ?? "Unknown Network")
            }

            let duration = (Date().timeIntervalSinceReferenceDate - startTime) * 1000
            Logger.shared.logDebug("ResourceResolver: Pre-populated cache in \(String(format: "%.1f", duration))ms")
        }
    }

    func getServerIP(_ server: Server) -> String? {
        guard let addresses = server.addresses else { return nil }
        for (_, addressList) in addresses {
            for address in addressList {
                if address.version == 4 {
                    return address.addr
                }
            }
        }
        return nil
    }
}
