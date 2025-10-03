import Foundation
import MemoryKit

@MainActor
final class ResourceNameCache {

    // MARK: - MemoryKit Integration

    /// ResourceCacheAdapter provides MemoryKit-backed caching
    private let adapter: ResourceCacheAdapter

    // MARK: - Initialization

    /// Initialize with dependency injection support
    init(adapter: ResourceCacheAdapter) {
        self.adapter = adapter
        Logger.shared.logInfo("ResourceNameCache initialized with MemoryKit integration")
    }

    /// Legacy initializer for backward compatibility
    convenience init() {
        // Create a default SubstationMemoryManager if none provided
        // This will be replaced when proper dependency injection is set up
        fatalError("ResourceNameCache requires MemoryKit adapter. Use init(adapter:) instead.")
    }

    // MARK: - Legacy API Compatibility

    func setFlavorName(_ id: String, name: String) {
        Task {
            await adapter.setFlavorName(id, name: name)
        }
    }

    func setImageName(_ id: String, name: String) {
        Task {
            await adapter.setImageName(id, name: name)
        }
    }

    func setServerName(_ id: String, name: String) {
        Task {
            await adapter.setServerName(id, name: name)
        }
    }

    func setNetworkName(_ id: String, name: String) {
        Task {
            await adapter.setNetworkName(id, name: name)
        }
    }

    func setSubnetName(_ id: String, name: String) {
        Task {
            await adapter.setSubnetName(id, name: name)
        }
    }

    func setSecurityGroupName(_ id: String, name: String) {
        Task {
            await adapter.setSecurityGroupName(id, name: name)
        }
    }

    func getFlavorName(_ id: String) -> String? {
        return adapter.getFlavorNameSync(id)
    }

    func getImageName(_ id: String) -> String? {
        return adapter.getImageNameSync(id)
    }

    func getServerName(_ id: String) -> String? {
        return adapter.getServerNameSync(id)
    }

    func getNetworkName(_ id: String) -> String? {
        return adapter.getNetworkNameSync(id)
    }

    func getSubnetName(_ id: String) -> String? {
        return adapter.getSubnetNameSync(id)
    }

    func getSecurityGroupName(_ id: String) -> String? {
        return adapter.getSecurityGroupNameSync(id)
    }

    func clear() {
        Task {
            await adapter.clear()
        }
    }

    // MARK: - Enhanced Async API

    /// Async version of setFlavorName for better MemoryKit integration
    func setFlavorNameAsync(_ id: String, name: String) async {
        await adapter.setFlavorName(id, name: name)
    }

    func setImageNameAsync(_ id: String, name: String) async {
        await adapter.setImageName(id, name: name)
    }

    func setServerNameAsync(_ id: String, name: String) async {
        await adapter.setServerName(id, name: name)
    }

    func setNetworkNameAsync(_ id: String, name: String) async {
        await adapter.setNetworkName(id, name: name)
    }

    func setSubnetNameAsync(_ id: String, name: String) async {
        await adapter.setSubnetName(id, name: name)
    }

    func setSecurityGroupNameAsync(_ id: String, name: String) async {
        await adapter.setSecurityGroupName(id, name: name)
    }

    /// Async version of getFlavorName for proper MemoryKit integration
    func getFlavorNameAsync(_ id: String) async -> String? {
        return await adapter.getFlavorName(id)
    }

    func getImageNameAsync(_ id: String) async -> String? {
        return await adapter.getImageName(id)
    }

    func getServerNameAsync(_ id: String) async -> String? {
        return await adapter.getServerName(id)
    }

    func getNetworkNameAsync(_ id: String) async -> String? {
        return await adapter.getNetworkName(id)
    }

    func getSubnetNameAsync(_ id: String) async -> String? {
        return await adapter.getSubnetName(id)
    }

    func getSecurityGroupNameAsync(_ id: String) async -> String? {
        return await adapter.getSecurityGroupName(id)
    }

    /// Async version of clear for proper MemoryKit integration
    func clearAsync() async {
        await adapter.clear()
    }

    // MARK: - Statistics and Monitoring

    /// Get cache statistics
    func getStatistics() async -> ResourceCacheStatistics {
        return await adapter.getStatistics()
    }

    /// Get cache hit rate
    func getCacheHitRate() async -> Double {
        return await adapter.getCacheHitRate()
    }
}