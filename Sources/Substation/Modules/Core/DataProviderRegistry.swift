// Sources/Substation/Modules/Core/DataProviderRegistry.swift
import Foundation

/// Central registry for module data providers
///
/// This registry maintains all data provider registrations from modules,
/// providing centralized access to decentralized data fetching capabilities.
@MainActor
final class DataProviderRegistry {
    /// Shared singleton instance
    static let shared = DataProviderRegistry()

    /// All registered providers indexed by resource type
    private var providers: [String: any DataProvider] = [:]

    /// Module identifiers indexed by resource type for debugging
    private var providerModules: [String: String] = [:]

    /// Private initializer for singleton
    private init() {}

    /// Register a data provider
    /// - Parameters:
    ///   - provider: The data provider to register
    ///   - moduleIdentifier: The identifier of the module registering this provider
    func register(_ provider: any DataProvider, from moduleIdentifier: String) {
        let resourceType = provider.resourceType
        providers[resourceType] = provider
        providerModules[resourceType] = moduleIdentifier

        Logger.shared.logInfo("DataProviderRegistry - Registered provider", context: [
            "resourceType": resourceType,
            "module": moduleIdentifier,
            "supportsPagination": provider.supportsPagination
        ])
    }

    /// Get provider for a resource type
    /// - Parameter resourceType: The resource type identifier
    /// - Returns: The data provider if registered
    func provider(for resourceType: String) -> (any DataProvider)? {
        return providers[resourceType]
    }

    /// Fetch data for a resource type using its registered provider
    /// - Parameters:
    ///   - resourceType: The resource type to fetch
    ///   - priority: The fetch priority
    ///   - forceRefresh: Whether to force refresh
    /// - Returns: Fetch result or nil if no provider registered
    func fetchData(
        for resourceType: String,
        priority: DataFetchPriority,
        forceRefresh: Bool = false
    ) async -> DataFetchResult? {
        guard let provider = providers[resourceType] else {
            Logger.shared.logWarning("No data provider registered for resource type: \(resourceType)")
            return nil
        }

        Logger.shared.logDebug("Fetching data via provider", context: [
            "resourceType": resourceType,
            "priority": priority.rawValue,
            "forceRefresh": forceRefresh
        ])

        return await provider.fetchData(priority: priority, forceRefresh: forceRefresh)
    }

    /// Fetch data for multiple resource types concurrently
    /// - Parameters:
    ///   - resourceTypes: Array of resource types to fetch
    ///   - priority: The fetch priority for all resources
    ///   - forceRefresh: Whether to force refresh
    /// - Returns: Dictionary of results indexed by resource type
    func fetchMultiple(
        resourceTypes: [String],
        priority: DataFetchPriority,
        forceRefresh: Bool = false
    ) async -> [String: DataFetchResult] {
        await withTaskGroup(of: (String, DataFetchResult?).self) { group in
            for resourceType in resourceTypes {
                group.addTask {
                    let result = await self.fetchData(
                        for: resourceType,
                        priority: priority,
                        forceRefresh: forceRefresh
                    )
                    return (resourceType, result)
                }
            }

            var results: [String: DataFetchResult] = [:]
            for await (resourceType, result) in group {
                if let result = result {
                    results[resourceType] = result
                }
            }
            return results
        }
    }

    /// Clear cache for specific resource type
    /// - Parameter resourceType: The resource type to clear cache for
    func clearCache(for resourceType: String) async {
        guard let provider = providers[resourceType] else {
            Logger.shared.logWarning("No provider to clear cache for: \(resourceType)")
            return
        }

        await provider.clearCache()
        Logger.shared.logDebug("Cleared cache for resource type: \(resourceType)")
    }

    /// Clear all caches
    func clearAllCaches() async {
        for (resourceType, provider) in providers {
            await provider.clearCache()
            Logger.shared.logDebug("Cleared cache for: \(resourceType)")
        }
    }

    /// Get resources that need refresh based on staleness
    /// - Parameter threshold: Time interval in seconds
    /// - Returns: Array of resource types that need refresh
    func getStaleResources(threshold: TimeInterval) -> [String] {
        return providers.compactMap { resourceType, provider in
            provider.needsRefresh(threshold: threshold) ? resourceType : nil
        }
    }

    /// Get all registered resource types
    /// - Returns: Array of resource type identifiers
    func allResourceTypes() -> [String] {
        return Array(providers.keys).sorted()
    }

    /// Get provider statistics for monitoring
    /// - Returns: Dictionary of statistics per resource type
    func getProviderStatistics() -> [String: [String: Any]] {
        var stats: [String: [String: Any]] = [:]

        for (resourceType, provider) in providers {
            stats[resourceType] = [
                "module": providerModules[resourceType] ?? "unknown",
                "itemCount": provider.currentItemCount,
                "lastRefresh": provider.lastRefreshTime?.timeIntervalSinceNow ?? -1,
                "supportsPagination": provider.supportsPagination
            ]
        }

        return stats
    }

    /// Unregister a provider (for module cleanup)
    /// - Parameter resourceType: The resource type to unregister
    func unregister(resourceType: String) {
        providers.removeValue(forKey: resourceType)
        providerModules.removeValue(forKey: resourceType)
        Logger.shared.logInfo("Unregistered data provider for: \(resourceType)")
    }

    /// Clear all registrations (for testing)
    func clear() {
        providers.removeAll()
        providerModules.removeAll()
    }
}

/// Extension for phased data fetching (matching current DataManager pattern)
extension DataProviderRegistry {
    /// Resource phase categories matching DataManager's refresh phases
    enum ResourcePhase {
        case critical   // Phase 1: Must complete for UI functionality
        case secondary  // Phase 2: Important but not critical
        case expensive  // Phase 3: Can be slow, run in background

        var resourceTypes: [String] {
            switch self {
            case .critical:
                return ["servers", "servergroups", "networks", "flavors"]
            case .secondary:
                return ["volumes", "subnets", "keypairs", "volumetypes",
                       "availabilityzones", "secrets", "floatingips", "images", "swift",
                       "clusters", "hypervisors"]
            case .expensive:
                return ["ports", "routers", "securitygroups", "quotas"]
            }
        }

        var priority: DataFetchPriority {
            switch self {
            case .critical: return .critical
            case .secondary: return .secondary
            case .expensive: return .background
            }
        }
    }

    /// Fetch resources for a specific phase
    /// - Parameters:
    ///   - phase: The resource phase to fetch
    ///   - forceRefresh: Whether to force refresh
    /// - Returns: Results for all resources in the phase
    func fetchPhase(_ phase: ResourcePhase, forceRefresh: Bool = false) async -> [String: DataFetchResult] {
        return await fetchMultiple(
            resourceTypes: phase.resourceTypes,
            priority: phase.priority,
            forceRefresh: forceRefresh
        )
    }

    /// Perform phased refresh matching DataManager's current behavior
    /// - Parameter forceRefresh: Whether to force refresh all data
    func performPhasedRefresh(forceRefresh: Bool = false) async {
        let startTime = Date()

        // Phase 1: Critical resources
        Logger.shared.logInfo("DataProviderRegistry - Phase 1: Fetching critical resources")
        let criticalResults = await fetchPhase(.critical, forceRefresh: forceRefresh)
        let phase1Duration = Date().timeIntervalSince(startTime)
        Logger.shared.logInfo("DataProviderRegistry - Phase 1 completed", context: [
            "duration": String(format: "%.2f", phase1Duration),
            "resourceCount": criticalResults.count
        ])

        // Phase 2: Secondary resources
        Logger.shared.logInfo("DataProviderRegistry - Phase 2: Fetching secondary resources")
        let secondaryResults = await fetchPhase(.secondary, forceRefresh: forceRefresh)
        let phase2Duration = Date().timeIntervalSince(startTime) - phase1Duration
        Logger.shared.logInfo("DataProviderRegistry - Phase 2 completed", context: [
            "duration": String(format: "%.2f", phase2Duration),
            "resourceCount": secondaryResults.count
        ])

        // Phase 3: Expensive resources (in background)
        // Use Task with explicit MainActor hop for any UI state updates
        Task { @MainActor [weak self] in
            await self?.fetchExpensiveResourcesBackground(forceRefresh: forceRefresh)
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        Logger.shared.logInfo("DataProviderRegistry - Core refresh completed", context: [
            "totalDuration": String(format: "%.2f", totalDuration)
        ])
    }

    private func fetchExpensiveResourcesBackground(forceRefresh: Bool) async {
        Logger.shared.logInfo("DataProviderRegistry - Phase 3: Fetching expensive resources (background)")
        let startTime = Date()
        let _ = await fetchPhase(.expensive, forceRefresh: forceRefresh)
        let duration = Date().timeIntervalSince(startTime)
        Logger.shared.logInfo("DataProviderRegistry - Phase 3 completed", context: [
            "duration": String(format: "%.2f", duration)
        ])
    }
}