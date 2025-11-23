import Foundation
import OSClient

/// Resolves resource names from UUIDs using cached data
///
/// This struct dynamically accesses cached data from the CacheManager,
/// ensuring it always has the latest cached resources without needing
/// to be recreated when cache updates occur.
@MainActor
struct ResourceResolver {
    private let cacheManager: CacheManager
    private let resourceNameCache: ResourceNameCache
    private let client: OSClient

    /// Dynamic accessors for cached resources from CacheManager
    private var cachedServers: [Server] { cacheManager.cachedServers }
    private var cachedNetworks: [Network] { cacheManager.cachedNetworks }
    private var cachedImages: [Image] { cacheManager.cachedImages }
    private var cachedFlavors: [Flavor] { cacheManager.cachedFlavors }
    private var cachedSubnets: [Subnet] { cacheManager.cachedSubnets }
    private var cachedSecurityGroups: [SecurityGroup] { cacheManager.cachedSecurityGroups }

    /// Initialize with CacheManager for dynamic resource access
    ///
    /// - Parameters:
    ///   - cacheManager: The cache manager holding all cached resources
    ///   - resourceNameCache: Cache for resolved resource names
    ///   - client: The OpenStack client
    init(
        cacheManager: CacheManager,
        resourceNameCache: ResourceNameCache,
        client: OSClient
    ) {
        self.cacheManager = cacheManager
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
