// Sources/Substation/Managers/DataManager.swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OSClient
import struct OSClient.Port

/// Coordinates data fetching operations via DataProviderRegistry
///
/// DataManager serves as the high-level coordinator for data refresh operations,
/// delegating actual fetching to registered DataProviders. It handles:
/// - Phased refresh coordination
/// - Project ID resolution
/// - Cache management
/// - Service catalog and health check operations
/// - Router detail fetching
@MainActor
class DataManager {

    weak var tui: TUI?
    private var client: OSClient

    // Performance tracking
    private var lastFullRefresh: Date = Date.distantPast
    private var fullRefreshInterval: TimeInterval = 30.0 // Full refresh every 30 seconds
    private var fastRefreshInterval: TimeInterval = 5.0  // Fast refresh every 5 seconds

    /// Initialize DataManager with OSClient and TUI reference
    ///
    /// - Parameters:
    ///   - client: The OSClient for API operations
    ///   - tui: The main TUI instance
    init(client: OSClient, tui: TUI) {
        self.client = client
        self.tui = tui

        // Clear router cache to force refresh with interface data
        tui.cacheManager.cachedRouters.removeAll()
        Logger.shared.logInfo("DataManager - Cleared router cache for interface data enhancement", context: [:])
    }

    // MARK: - Project ID Resolution

    /// Initialize project ID resolution when DataManager is set up
    func initializeProjectID() async {
        do {
            let projectName = await client.project
            Logger.shared.logInfo("DataManager - Resolving project ID for '\(projectName)'...")
            try await client.resolveProjectID()
            let projectID = await client.projectID
            if let projectID = projectID {
                Logger.shared.logInfo("DataManager - Resolved project ID: \(projectID)")
            } else {
                Logger.shared.logWarning("DataManager - Could not resolve project ID, using project name as fallback")
            }
        } catch {
            Logger.shared.logError("DataManager - Failed to resolve project ID: \(error)")
        }
    }

    // MARK: - Data Refresh Coordination

    /// Smart refresh that decides between full and fast refresh
    func refreshAllData() async {
        let now = Date()
        let timeSinceLastFull = now.timeIntervalSince(lastFullRefresh)

        if timeSinceLastFull < fullRefreshInterval {
            // Use fast refresh for recent updates
            await refreshCoreDataOptimized()
        } else {
            // Full refresh needed
            await refreshAllDataOptimized()
            lastFullRefresh = now
        }
    }

    /// Force a full refresh (bypassing the throttle)
    ///
    /// Use this when switching clouds or when cache is explicitly cleared
    func forceFullRefresh() async {
        Logger.shared.logInfo("DataManager.forceFullRefresh() - Forcing full data refresh")
        await refreshAllDataOptimized()
        lastFullRefresh = Date()
    }

    /// Optimized full refresh with early completion strategy
    private func refreshAllDataOptimized() async {
        guard let tui = tui else { return }

        let startTime = Date().timeIntervalSinceReferenceDate
        Logger.shared.logInfo("DataManager.refreshAllDataOptimized() - Starting optimized data refresh")

        // Clear all caches since data is changing
        Task { await tui.memoryContainer.clearAllCaches() }

        // Phase 1: Critical Resources (must complete first for UI responsiveness)
        await refreshCriticalResources()

        // Update UI immediately with critical data
        tui.resourceOperations.updateResourceCounts()
        tui.markNeedsRedraw()

        // Phase 2: Secondary Resources (important but not critical)
        await refreshSecondaryResources()

        // UI is now fully functional - update and report success
        tui.resourceOperations.updateResourceCounts()
        tui.resourceResolver.prePopulateCache()

        let functionalTime = Date().timeIntervalSinceReferenceDate
        let functionalDuration = functionalTime - startTime
        Logger.shared.logInfo("DataManager - Core functionality available in \(String(format: "%.2f", functionalDuration))s")

        if functionalDuration <= 3.0 {
            Logger.shared.logInfo("DataManager - Performance target met: \(String(format: "%.2f", functionalDuration))s <= 3.0s")
        }

        tui.markNeedsRedraw()

        // Phase 3: Expensive Resources (run in background, don't block completion)
        Task.detached { [weak self] in
            await self?.refreshExpensiveResourcesBackground()
            await MainActor.run {
                tui.resourceOperations.updateResourceCounts()
                tui.markNeedsRedraw()
            }
        }

        // Report core completion time (not total time)
        Logger.shared.logInfo("DataManager.refreshAllDataOptimized() - Core completed in \(String(format: "%.2f", functionalDuration))s")
    }

    // MARK: - Phased Refresh via Registry

    /// Phase 1: Critical resources needed for basic UI functionality
    private func refreshCriticalResources() async {
        Logger.shared.logDebug("DataManager - Phase 1: Fetching critical resources")
        let phaseStart = Date().timeIntervalSinceReferenceDate

        let _ = await DataProviderRegistry.shared.fetchPhase(.critical, forceRefresh: true)

        let phaseDuration = Date().timeIntervalSinceReferenceDate - phaseStart
        Logger.shared.logInfo("DataManager - Phase 1 completed in \(String(format: "%.2f", phaseDuration))s")
    }

    /// Phase 2: Secondary resources for enhanced functionality
    private func refreshSecondaryResources() async {
        Logger.shared.logDebug("DataManager - Phase 2: Fetching secondary resources")
        let phaseStart = Date().timeIntervalSinceReferenceDate

        let _ = await DataProviderRegistry.shared.fetchPhase(.secondary, forceRefresh: true)

        let phaseDuration = Date().timeIntervalSinceReferenceDate - phaseStart
        Logger.shared.logInfo("DataManager - Phase 2 completed in \(String(format: "%.2f", phaseDuration))s")
    }

    /// Phase 3: Expensive resources that can be slow (background loading)
    private func refreshExpensiveResourcesBackground() async {
        Logger.shared.logDebug("DataManager - Phase 3: Fetching expensive resources (background)")
        let phaseStart = Date().timeIntervalSinceReferenceDate

        let _ = await DataProviderRegistry.shared.fetchPhase(.expensive, forceRefresh: true)

        let phaseDuration = Date().timeIntervalSinceReferenceDate - phaseStart
        Logger.shared.logInfo("DataManager - Phase 3 background completed in \(String(format: "%.2f", phaseDuration))s")
    }

    /// Fast refresh for frequently changing core resources only
    private func refreshCoreDataOptimized() async {
        guard let tui = tui else { return }

        let startTime = Date().timeIntervalSinceReferenceDate
        Logger.shared.logDebug("DataManager - Fast refresh of core resources")

        // Clear caches to ensure fresh data is displayed - must complete before fetching
        await tui.memoryContainer.clearAllCaches()

        // Fetch only the fast-refresh resources
        let fastResources = ["servers", "volumes", "floatingips"]
        let _ = await DataProviderRegistry.shared.fetchMultiple(
            resourceTypes: fastResources,
            priority: .fast,
            forceRefresh: true
        )

        tui.resourceOperations.updateResourceCounts()

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        Logger.shared.logDebug("DataManager - Fast refresh completed in \(String(format: "%.2f", duration))s")

        tui.markNeedsRedraw()
    }

    // MARK: - Cache Management

    /// Purge all caches and perform full refresh
    ///
    /// Delegates cache clearing to registered DataProviders via the registry,
    /// then clears any remaining non-provider caches.
    func purgeCache() async {
        guard let tui = tui else { return }

        // Clear all provider-managed caches via registry
        await DataProviderRegistry.shared.clearAllCaches()

        // Clear caches not managed by DataProviders
        tui.cacheManager.cachedVolumeTypes.removeAll()
        tui.cacheManager.cachedAvailabilityZones.removeAll()
        tui.cacheManager.cachedComputeLimits = nil
        tui.cacheManager.cachedComputeQuotas = nil
        tui.cacheManager.cachedNetworkQuotas = nil
        tui.cacheManager.cachedVolumeQuotas = nil
        await tui.resourceNameCache.clearAsync()

        Logger.shared.logInfo("DataManager - Cache purged via DataProviderRegistry")

        await refreshAllDataOptimized()
    }

    // MARK: - Service Catalog and Health Check Operations

    /// Get services from OpenStack service catalog (fast, no health checks)
    ///
    /// - Returns: Array of services from the catalog
    func getCatalog() async throws -> [Service] {
        let keystone = await client.keystone
        return try await keystone.listCatalog()
    }

    /// Get service catalog with full endpoint information
    ///
    /// - Returns: Array of catalog entries with endpoints
    func getCatalogWithEndpoints() async throws -> [TokenCatalogEntry] {
        let keystone = await client.keystone
        return try await keystone.listCatalogWithEndpoints()
    }

    /// Get token lifetime remaining
    ///
    /// - Returns: Time interval until token expiration, or nil if not available
    func getTokenLifetime() async -> TimeInterval? {
        return await client.coreClient.timeUntilTokenExpiration
    }

    /// Get OpenStack service catalog with health check information
    ///
    /// - Returns: Array of tuples with service name and health status
    func getServiceCatalogWithHealthChecks() async -> [(String, ServiceHealthStatus)] {
        do {
            Logger.shared.logDebug("DataManager - Fetching service catalog and performing health checks")
            let apiStart = Date().timeIntervalSinceReferenceDate

            // Get the service catalog from Keystone
            let keystone = await client.keystone
            let services = try await keystone.listCatalog()
            let endpoints = try await keystone.listEndpoints()

            let fetchDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(services.count) services and \(endpoints.count) endpoints in \(String(format: "%.2f", fetchDuration))s")

            // Group endpoints by service
            var serviceEndpoints: [String: [Endpoint]] = [:]
            for endpoint in endpoints {
                serviceEndpoints[endpoint.serviceId, default: []].append(endpoint)
            }

            var results: [(String, ServiceHealthStatus)] = []

            // Perform health checks for each service with limited concurrency
            let healthCheckTasks: [@Sendable () async -> (String, ServiceHealthStatus)?] = services.map { service in
                let endpoints = serviceEndpoints[service.id] ?? []
                return { [weak self] in
                    await self?.performServiceHealthCheck(service: service, endpoints: endpoints)
                }
            }

            // Run health checks with limited concurrency (CPU-aware)
            let concurrencyLimit = SystemCapabilities.optimalConcurrentTaskLimit()
            var taskIterator = healthCheckTasks.makeIterator()
            await withTaskGroup(of: (String, ServiceHealthStatus)?.self) { group in
                // Start initial batch
                for _ in 0..<min(concurrencyLimit, healthCheckTasks.count) {
                    if let task = taskIterator.next() {
                        group.addTask {
                            await task()
                        }
                    }
                }

                // As tasks complete, add new ones and collect results
                while let result = await group.next() {
                    if let result = result {
                        results.append(result)
                    }
                    // Add next task if available
                    if let task = taskIterator.next() {
                        group.addTask {
                            await task()
                        }
                    }
                }
            }

            // Sort by service name for consistent display
            results.sort { $0.0 < $1.0 }

            let totalDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logInfo("DataManager - Completed service catalog health checks for \(results.count) services in \(String(format: "%.2f", totalDuration))s")

            return results
        } catch {
            Logger.shared.logError("DataManager - Failed to fetch service catalog: \(error)")
            // Return empty array on error instead of fallback data
            return []
        }
    }

    /// Perform health check for a specific service
    ///
    /// - Parameters:
    ///   - service: The service to check
    ///   - endpoints: The service endpoints
    /// - Returns: Tuple of service name and health status
    private func performServiceHealthCheck(service: Service, endpoints: [Endpoint]) async -> (String, ServiceHealthStatus)? {
        let serviceName = (service.name ?? service.type).capitalized

        // Find the public endpoint for this service
        guard let publicEndpoint = endpoints.first(where: { $0.interface == "public" }) else {
            Logger.shared.logDebug("DataManager - No public endpoint found for service \(serviceName)")
            return (serviceName, ServiceHealthStatus(avgResponseTime: 0.0, isHealthy: false))
        }

        // Perform lightweight health check
        let startTime = Date().timeIntervalSinceReferenceDate
        let isHealthy = await performLightweightHealthCheck(endpoint: publicEndpoint, serviceName: serviceName)
        let responseTime = (Date().timeIntervalSinceReferenceDate - startTime) * 1000.0 // Convert to milliseconds

        Logger.shared.logDebug("DataManager - Health check for \(serviceName): \(isHealthy ? "HEALTHY" : "UNHEALTHY") (\(String(format: "%.0f", responseTime))ms)")

        return (serviceName, ServiceHealthStatus(avgResponseTime: responseTime, isHealthy: isHealthy))
    }

    /// Perform a lightweight health check against a service endpoint
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint to check
    ///   - serviceName: The service name for logging
    /// - Returns: True if the service is healthy
    private func performLightweightHealthCheck(endpoint: Endpoint, serviceName: String) async -> Bool {
        do {
            // Construct health check URL - use root path for basic connectivity test
            guard let baseURL = URL(string: endpoint.url) else {
                Logger.shared.logWarning("DataManager - Invalid endpoint URL for \(serviceName): \(endpoint.url)")
                return false
            }

            let healthCheckURL = baseURL.appendingPathComponent("/")

            // Create a simple HTTP request with short timeout
            var request = URLRequest(url: healthCheckURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 5.0 // 5 second timeout for health checks

            // Add basic headers
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Substation-HealthCheck/1.0", forHTTPHeaderField: "User-Agent")

            // Perform the request
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // Consider 2xx, 3xx, and even some 4xx responses as "healthy"
                // since they indicate the service is responding
                let isHealthy = httpResponse.statusCode < 500
                Logger.shared.logDebug("DataManager - Health check for \(serviceName) returned HTTP \(httpResponse.statusCode)")
                return isHealthy
            }

            return false
        } catch {
            Logger.shared.logDebug("DataManager - Health check failed for \(serviceName): \(error)")
            return false
        }
    }
}

// MARK: - Service Health Status Model

/// Health status information for an OpenStack service
public struct ServiceHealthStatus: Sendable {
    /// Average response time in milliseconds
    public let avgResponseTime: Double

    /// Whether the service is healthy
    public let isHealthy: Bool

    /// Initialize a service health status
    ///
    /// - Parameters:
    ///   - avgResponseTime: Response time in milliseconds
    ///   - isHealthy: Whether the service is healthy
    public init(avgResponseTime: Double, isHealthy: Bool) {
        self.avgResponseTime = avgResponseTime
        self.isHealthy = isHealthy
    }
}
