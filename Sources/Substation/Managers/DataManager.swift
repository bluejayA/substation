import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OSClient
import struct OSClient.Port

@MainActor
class DataManager {

    weak var tui: TUI?
    private var client: OSClient

    // MARK: - Pagination Support
    private var serverPaginationManager: PaginationManager<Server>?
    private var networkPaginationManager: PaginationManager<Network>?
    private var volumePaginationManager: PaginationManager<Volume>?
    private var portPaginationManager: PaginationManager<Port>?
    private var imagePaginationManager: PaginationManager<Image>?
    private var securityGroupPaginationManager: PaginationManager<SecurityGroup>?

    // Configuration for different resource types
    private var paginationConfigs: [String: PaginationConfig] = [
        "servers": .medium,
        "networks": .medium,
        "volumes": .medium,
        "ports": .large,      // Ports can be very numerous
        "images": .large,     // Images can be very numerous
        "securityGroups": .medium
    ]

    // Track which resources have pagination enabled
    private var paginationEnabled: Set<String> = []

    // Performance tracking
    private var lastFullRefresh: Date = Date.distantPast
    private var fullRefreshInterval: TimeInterval = 30.0 // Full refresh every 30 seconds
    private var fastRefreshInterval: TimeInterval = 5.0  // Fast refresh every 5 seconds

    // Smart caching for expensive resources
    private var lastPortsRefresh: Date = Date.distantPast
    private var lastImagesRefresh: Date = Date.distantPast
    private var lastSecurityGroupsRefresh: Date = Date.distantPast
    private var lastFloatingIPsRefresh: Date = Date.distantPast
    private var expensiveResourceCacheInterval: TimeInterval = 60.0 // Cache expensive resources for 1 minute

    init(client: OSClient, tui: TUI) {
        self.client = client
        self.tui = tui

        // Clear router cache to force refresh with interface data
        tui.cachedRouters.removeAll()
        Logger.shared.logInfo("DataManager - Cleared router cache for interface data enhancement", context: [:])
    }

    // Initialize project ID resolution when DataManager is set up
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

    // Smart refresh that decides between full and fast refresh
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

    // Force a full refresh (bypassing the throttle)
    // Use this when switching clouds or when cache is explicitly cleared
    func forceFullRefresh() async {
        Logger.shared.logInfo("DataManager.forceFullRefresh() - Forcing full data refresh")
        await refreshAllDataOptimized()
        lastFullRefresh = Date()
    }

    // Optimized full refresh with early completion strategy
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

        // Update pagination data for critical resources
        await updatePaginationData()

        // Phase 2: Secondary Resources (important but not critical)
        await refreshSecondaryResources()

        // UI is now fully functional - update and report success
        tui.resourceOperations.updateResourceCounts()
        tui.resourceResolver.prePopulateCache()

        // Final pagination data update after all secondary resources
        await updatePaginationData()

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

        // Auto-enable pagination for large datasets after all data is loaded
        await enableAutoPagination(threshold: 500)

        // Report core completion time (not total time)
        Logger.shared.logInfo("DataManager.refreshAllDataOptimized() - Core completed in \(String(format: "%.2f", functionalDuration))s")
    }

    // Helper function to run tasks with limited concurrency to reduce actor contention
    private func runWithLimitedConcurrency(_ tasks: [@Sendable () async -> Void], maxConcurrent: Int? = nil, delayBetweenTasks: UInt64 = 0) async {
        // Use CPU-aware limit if not explicitly specified
        let concurrencyLimit = maxConcurrent ?? SystemCapabilities.optimalConcurrentTaskLimit()
        var taskIterator = tasks.makeIterator()

        await withTaskGroup(of: Void.self) { group in
            // Start initial batch
            for _ in 0..<min(concurrencyLimit, tasks.count) {
                if let task = taskIterator.next() {
                    group.addTask {
                        await task()
                    }
                }
                // Small delay between launching tasks to reduce URLSession busy-wait contention
                if delayBetweenTasks > 0 {
                    try? await Task.sleep(nanoseconds: delayBetweenTasks)
                }
            }

            // As tasks complete, add new ones
            while let _ = await group.next() {
                if let task = taskIterator.next() {
                    group.addTask {
                        await task()
                    }
                    // Small delay between launching tasks to reduce URLSession busy-wait contention
                    if delayBetweenTasks > 0 {
                        try? await Task.sleep(nanoseconds: delayBetweenTasks)
                    }
                }
            }
        }
    }

    // Phase 1: Critical resources needed for basic UI functionality
    private func refreshCriticalResources() async {
        Logger.shared.logDebug("DataManager - Phase 1: Fetching critical resources")
        let phaseStart = Date().timeIntervalSinceReferenceDate

        let tasks: [@Sendable () async -> Void] = [
            { [weak self] in await self?.fetchServers(priority: "critical") },
            { [weak self] in await self?.fetchServerGroups(priority: "critical") },
            { [weak self] in await self?.fetchNetworks(priority: "critical") },
            { [weak self] in await self?.fetchFlavors(priority: "critical") }
        ]

        await runWithLimitedConcurrency(tasks, maxConcurrent: 5, delayBetweenTasks: SystemCapabilities.optimalTaskDelay())

        let phaseDuration = Date().timeIntervalSinceReferenceDate - phaseStart
        Logger.shared.logInfo("DataManager - Phase 1 completed in \(String(format: "%.2f", phaseDuration))s")
    }

    // Phase 2: Secondary resources for enhanced functionality
    private func refreshSecondaryResources() async {
        Logger.shared.logDebug("DataManager - Phase 2: Fetching secondary resources")
        let phaseStart = Date().timeIntervalSinceReferenceDate

        let tasks: [@Sendable () async -> Void] = [
            { [weak self] in await self?.fetchVolumes(priority: "secondary") },
            { [weak self] in await self?.fetchSubnets(priority: "secondary") },
            { [weak self] in await self?.fetchKeyPairs(priority: "secondary") },
            { [weak self] in await self?.fetchVolumeTypes(priority: "secondary") },
            { [weak self] in await self?.fetchAvailabilityZones(priority: "secondary") },
            { [weak self] in await self?.fetchSecrets(priority: "secondary") },
            { [weak self] in await self?.refreshFloatingIPs(priority: "secondary") },
            { [weak self] in await self?.fetchImages(priority: "secondary") },
            { [weak self] in await self?.fetchSwiftContainers(priority: "secondary") }
        ]

        await runWithLimitedConcurrency(tasks, maxConcurrent: 5, delayBetweenTasks: SystemCapabilities.optimalTaskDelay())

        let phaseDuration = Date().timeIntervalSinceReferenceDate - phaseStart
        Logger.shared.logInfo("DataManager - Phase 2 completed in \(String(format: "%.2f", phaseDuration))s")
    }

    // Phase 3: Expensive resources that can be slow (background loading)
    private func refreshExpensiveResourcesBackground() async {
        Logger.shared.logDebug("DataManager - Phase 3: Fetching expensive resources (background)")
        let phaseStart = Date().timeIntervalSinceReferenceDate

        let tasks: [@Sendable () async -> Void] = [
            { [weak self] in await self?.fetchPorts(priority: "background") },
            { [weak self] in await self?.fetchRouters(priority: "background") },
            { [weak self] in await self?.fetchSecurityGroups(priority: "background") },
            { [weak self] in await self?.fetchQuotas(priority: "background") }
        ]

        await runWithLimitedConcurrency(tasks, maxConcurrent: 5, delayBetweenTasks: SystemCapabilities.optimalTaskDelay())

        let phaseDuration = Date().timeIntervalSinceReferenceDate - phaseStart
        Logger.shared.logInfo("DataManager - Phase 3 background completed in \(String(format: "%.2f", phaseDuration))s")
    }

    // Phase 3: Expensive resources that can be slow
    private func refreshExpensiveResources() async {
        Logger.shared.logDebug("DataManager - Phase 3: Fetching expensive resources")
        let phaseStart = Date().timeIntervalSinceReferenceDate

        let tasks: [@Sendable () async -> Void] = [
            { [weak self] in await self?.fetchPorts(priority: "expensive") },
            { [weak self] in await self?.fetchRouters(priority: "expensive") },
            { [weak self] in await self?.fetchSecurityGroups(priority: "expensive") },
            { [weak self] in await self?.fetchQuotas(priority: "expensive") }
        ]

        await runWithLimitedConcurrency(tasks, maxConcurrent: 5, delayBetweenTasks: SystemCapabilities.optimalTaskDelay())

        let phaseDuration = Date().timeIntervalSinceReferenceDate - phaseStart
        Logger.shared.logInfo("DataManager - Phase 3 completed in \(String(format: "%.2f", phaseDuration))s")
    }

    // Fast refresh for frequently changing core resources only
    private func refreshCoreDataOptimized() async {
        guard let tui = tui else { return }

        let startTime = Date().timeIntervalSinceReferenceDate
        Logger.shared.logDebug("DataManager - Fast refresh of core resources")

        // Clear caches to ensure fresh data is displayed - must complete before fetching
        await tui.memoryContainer.clearAllCaches()

        let tasks: [@Sendable () async -> Void] = [
            { [weak self] in await self?.fetchServers(priority: "fast") },
            { [weak self] in await self?.fetchVolumes(priority: "fast") },
            { [weak self] in await self?.refreshFloatingIPs(priority: "fast") }
        ]

        await runWithLimitedConcurrency(tasks, maxConcurrent: 5, delayBetweenTasks: SystemCapabilities.optimalTaskDelay())

        tui.resourceOperations.updateResourceCounts()

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        Logger.shared.logDebug("DataManager - Fast refresh completed in \(String(format: "%.2f", duration))s")

        tui.markNeedsRedraw()
    }

    // Individual fetch methods with error handling and timing
    private func fetchServers(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching servers (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            // Force refresh to bypass cache for live state updates
            let servers = try await client.listServers(forceRefresh: true)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(servers.count) servers in \(String(format: "%.2f", apiDuration))s")
            tui.cachedServers = servers
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Server access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch servers: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch servers: \(error)")
        }
    }

    private func fetchServerGroups(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching server groups (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            // Force refresh to bypass cache
            let serverGroups = try await client.listServerGroups(forceRefresh: true)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(serverGroups.count) server groups in \(String(format: "%.2f", apiDuration))s")
            tui.cachedServerGroups = serverGroups
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Server group access may require admin privileges (HTTP 403)")
            case .httpError(404, _):
                Logger.shared.logDebug("Server groups feature may not be available in this OpenStack deployment")
            default:
                Logger.shared.logError("Failed to fetch server groups: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch server groups: \(error)")
        }
    }

    private func fetchNetworks(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching networks (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            // Force refresh to bypass cache for live state updates
            let networks = try await client.listNetworks(forceRefresh: true)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(networks.count) networks in \(String(format: "%.2f", apiDuration))s")
            tui.cachedNetworks = networks
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Network access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch networks: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch networks: \(error)")
        }
    }

    private func fetchVolumes(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching volumes (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            let volumes = try await client.listVolumes()
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(volumes.count) volumes in \(String(format: "%.2f", apiDuration))s")
            tui.cachedVolumes = volumes
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Volume access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch volumes: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch volumes: \(error)")
        }
    }

    private func fetchFlavors(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching flavors (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            // Force refresh to bypass cache
            let flavors = try await client.listFlavors(forceRefresh: true)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(flavors.count) flavors in \(String(format: "%.2f", apiDuration))s")
            tui.cachedFlavors = flavors

            // Generate flavor recommendations in background after flavors are fetched
            await generateFlavorRecommendationsInBackground(priority: priority)
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Flavor access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch flavors: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch flavors: \(error)")
        }
    }

    private func fetchImages(priority: String) async {
        guard let tui = tui else { return }

        // Smart caching: skip if recently fetched (unless critical priority)
        let now = Date()
        if priority == "background" && now.timeIntervalSince(lastImagesRefresh) < expensiveResourceCacheInterval && !tui.cachedImages.isEmpty {
            Logger.shared.logDebug("DataManager - Skipping images fetch (cached \(tui.cachedImages.count) images, last refresh \(String(format: "%.1f", now.timeIntervalSince(lastImagesRefresh)))s ago)")
            return
        }

        do {
            Logger.shared.logDebug("DataManager - Fetching images (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate

            // More generous timeout for image datasets - often very large
            let timeoutSeconds: TimeInterval = (priority == "background") ? 20.0 : 30.0
            let images = try await withTimeout(seconds: timeoutSeconds) {
                try await self.client.listImages()
            }

            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logInfo("DataManager - Fetched \(images.count) images in \(String(format: "%.2f", apiDuration))s")

            let mappedImages = images.map { glanceImage in
                Image(
                    id: glanceImage.id,
                    name: glanceImage.name,
                    status: glanceImage.status,
                    progress: nil,
                    minRam: glanceImage.minRam,
                    minDisk: glanceImage.minDisk,
                    visibility: glanceImage.visibility,
                    size: glanceImage.size,
                    diskFormat: glanceImage.diskFormat,
                    containerFormat: glanceImage.containerFormat,
                    checksum: glanceImage.checksum,
                    owner: glanceImage.owner,
                    protected: glanceImage.protected,
                    tags: glanceImage.tags,
                    properties: glanceImage.properties,
                    createdAt: glanceImage.createdAt,
                    updatedAt: glanceImage.updatedAt,
                    metadata: nil,
                    server: nil,
                    links: nil
                )
            }

            tui.cachedImages = mappedImages
            Logger.shared.logInfo("DataManager - Cached \(tui.cachedImages.count) images")
            lastImagesRefresh = now
        } catch is TimeoutError {
            Logger.shared.logWarning("DataManager - Images fetch timed out after \((priority == "background") ? 20.0 : 30.0)s, skipping to prevent blocking")
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logWarning("DataManager - Image access may require admin privileges (HTTP 403)")
            case .httpError(404, let message):
                Logger.shared.logError("DataManager - Images fetch failed with 404: \(message ?? "No message")")
            default:
                Logger.shared.logError("DataManager - Failed to fetch images: \(error)")
            }
        } catch {
            Logger.shared.logError("DataManager - Failed to fetch images: \(error)")
        }
    }

    private func fetchPorts(priority: String) async {
        guard let tui = tui else { return }

        // Smart caching: skip if recently fetched (unless critical priority)
        let now = Date()
        if priority == "background" && now.timeIntervalSince(lastPortsRefresh) < expensiveResourceCacheInterval && !tui.cachedPorts.isEmpty {
            Logger.shared.logDebug("DataManager - Skipping ports fetch (cached \(tui.cachedPorts.count) ports, last refresh \(String(format: "%.1f", now.timeIntervalSince(lastPortsRefresh)))s ago)")
            return
        }

        do {
            Logger.shared.logDebug("DataManager - Fetching ports (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate

            // Aggressive timeout for huge port datasets - 10.0
            let timeoutSeconds: TimeInterval = (priority == "background") ? 10.0 : 12.0
            let ports = try await withTimeout(seconds: timeoutSeconds) {
                // Force refresh to bypass cache for live state updates
                try await self.client.listPorts(forceRefresh: true)
            }

            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(ports.count) ports in \(String(format: "%.2f", apiDuration))s")
            tui.cachedPorts = ports
            lastPortsRefresh = now
        } catch is TimeoutError {
            Logger.shared.logWarning("DataManager - Ports fetch timed out after \((priority == "background") ? 10.0 : 12.0)s, skipping to prevent blocking")
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Port access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch ports: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch ports: \(error)")
        }
    }

    // Fetch floating IPs with caching optimization
    private func refreshFloatingIPs(priority: String = "normal") async {
        let now = Date()
        let timeSinceLastRefresh = now.timeIntervalSince(lastFloatingIPsRefresh)

        // Skip if recently refreshed and this is a background/low priority request
        // For fast priority, always refresh to show state changes
        if priority == "background" && timeSinceLastRefresh < expensiveResourceCacheInterval {
            Logger.shared.logDebug("DataManager - Skipping floating IPs fetch (cached, last refresh \(String(format: "%.1f", timeSinceLastRefresh))s ago)")
            return
        }

        guard let tui = tui else { return }

        // Phase 2: Check if FloatingIP view is actively rendering - defer update to avoid interference
        if tui.isFloatingIPViewRendering {
            Logger.shared.logDebug("DataManager - Deferring floating IP refresh while view is rendering")
            return
        }

        do {
            let apiStart = Date().timeIntervalSinceReferenceDate
            Logger.shared.logDebug("DataManager - Fetching floating IPs (\(priority) priority)...")

            let floatingIPs = try await withThrowingTaskGroup(of: [FloatingIP].self) { group in
                group.addTask(priority: priority == "background" ? .low : .medium) {
                    // Force refresh to bypass OSClient cache and get live data
                    try await self.client.listFloatingIPs(forceRefresh: true)
                }
                return try await group.next() ?? []
            }

            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logInfo("DataManager - Fetched \(floatingIPs.count) floating IPs in \(String(format: "%.2f", apiDuration))s")

            let oldCount = tui.cachedFloatingIPs.count
            let oldIPs = tui.cachedFloatingIPs
            tui.cachedFloatingIPs = floatingIPs
            lastFloatingIPsRefresh = now

            // Log any changes in floating IP status
            for newIP in floatingIPs {
                if let oldIP = oldIPs.first(where: { $0.id == newIP.id }) {
                    if oldIP.status != newIP.status || oldIP.portId != newIP.portId {
                        Logger.shared.logInfo("DataManager - Floating IP \(newIP.floatingIpAddress ?? "unknown") changed: status=\(oldIP.status ?? "nil")→\(newIP.status ?? "nil"), portId=\(oldIP.portId ?? "nil")→\(newIP.portId ?? "nil")")
                    }
                }
            }

            Logger.shared.logInfo("DataManager - Updated floating IP cache: \(oldCount) -> \(floatingIPs.count) entries")
        } catch is TimeoutError {
            Logger.shared.logWarning("DataManager - Floating IPs fetch timed out after \((priority == "background") ? 10.0 : 12.0)s, skipping to prevent blocking")
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logWarning("DataManager - Floating IP access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("DataManager - Failed to fetch floating IPs: \(error)")
            }
        } catch {
            Logger.shared.logError("DataManager - Failed to fetch floating IPs: \(error)")
        }
    }

    private func fetchSubnets(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching subnets (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            // Force refresh to bypass cache for live state updates
            let subnets = try await client.listSubnets(forceRefresh: true)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(subnets.count) subnets in \(String(format: "%.2f", apiDuration))s")
            tui.cachedSubnets = subnets
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Subnet access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch subnets: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch subnets: \(error)")
        }
    }

    private func fetchKeyPairs(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching key pairs (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            // Force refresh to bypass cache
            let keyPairs = try await client.listKeyPairs(forceRefresh: true)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(keyPairs.count) key pairs in \(String(format: "%.2f", apiDuration))s")
            tui.cachedKeyPairs = keyPairs
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Key pair access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch key pairs: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch key pairs: \(error)")
        }
    }

    private func fetchVolumeTypes(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching volume types (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            let volumeTypes = try await client.listVolumeTypes()
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(volumeTypes.count) volume types in \(String(format: "%.2f", apiDuration))s")
            tui.cachedVolumeTypes = volumeTypes
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Volume type access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch volume types: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch volume types: \(error)")
        }
    }

    private func fetchRouters(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching routers (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            // Force refresh to bypass cache for live state updates
            let routers = try await client.listRouters(forceRefresh: true)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(routers.count) routers in \(String(format: "%.2f", apiDuration))s")
            // Debug router interface data before caching
            for router in routers {
                Logger.shared.logInfo("DataManager caching router", context: [
                    "routerId": router.id,
                    "routerName": router.name ?? "Unknown",
                    "interfacesPresent": router.interfaces != nil,
                    "interfaceCount": router.interfaces?.count ?? 0,
                    "interfaceSubnetIds": router.interfaces?.compactMap { $0.subnetId } ?? []
                ])
            }

            tui.cachedRouters = routers
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Router access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch routers: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch routers: \(error)")
        }
    }

    private func fetchSecurityGroups(priority: String) async {
        guard let tui = tui else { return }

        // Smart caching: skip if recently fetched (unless critical priority)
        let now = Date()
        if priority == "background" && now.timeIntervalSince(lastSecurityGroupsRefresh) < expensiveResourceCacheInterval && !tui.cachedSecurityGroups.isEmpty {
            Logger.shared.logDebug("DataManager - Skipping security groups fetch (cached \(tui.cachedSecurityGroups.count) groups, last refresh \(String(format: "%.1f", now.timeIntervalSince(lastSecurityGroupsRefresh)))s ago)")
            return
        }

        do {
            Logger.shared.logDebug("DataManager - Fetching security groups (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate

            // Add timeout for potentially large security group datasets
            let timeoutSeconds: TimeInterval = (priority == "background") ? 10.0 : 12.0
            let securityGroups = try await withTimeout(seconds: timeoutSeconds) {
                // Force refresh to bypass cache for live state updates
                try await self.client.listSecurityGroups(forceRefresh: true)
            }

            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(securityGroups.count) security groups in \(String(format: "%.2f", apiDuration))s")
            tui.cachedSecurityGroups = securityGroups
            lastSecurityGroupsRefresh = now
        } catch is TimeoutError {
            Logger.shared.logWarning("DataManager - Security groups fetch timed out after \((priority == "background") ? 10.0 : 12.0)s, skipping to prevent blocking")
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Security group access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch security groups: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch security groups: \(error)")
        }
    }

    private func fetchSecrets(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching secrets (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            let secrets = try await client.barbican.listSecrets()
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(secrets.count) secrets in \(String(format: "%.2f", apiDuration))s")
            tui.cachedSecrets = secrets
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Secrets access may require admin privileges (HTTP 403)")
            case .httpError(404, _):
                Logger.shared.logDebug("Barbican service may not be available in this OpenStack deployment")
            default:
                Logger.shared.logError("Failed to fetch secrets: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch secrets: \(error)")
        }
    }

    private func fetchAvailabilityZones(priority: String) async {
        guard let tui = tui else { return }
        do {
            Logger.shared.logDebug("DataManager - Fetching availability zones (\(priority) priority)...")
            let apiStart = Date().timeIntervalSinceReferenceDate
            let availabilityZones = try await client.listAvailabilityZones()
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(availabilityZones.count) availability zones in \(String(format: "%.2f", apiDuration))s")
            tui.cachedAvailabilityZones = availabilityZones.map { $0.zoneName }
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Availability zone access may require admin privileges (HTTP 403)")
            default:
                Logger.shared.logError("Failed to fetch availability zones: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch availability zones: \(error)")
        }
    }

    private func fetchQuotas(priority: String) async {
        guard let tui = tui else { return }

        Logger.shared.logDebug("DataManager - Fetching quotas (\(priority) priority)...")

        await withTaskGroup(of: Void.self) { group in
            // Compute Quotas
            group.addTask { [weak self] in
                guard let self = self else { return }
                do {
                    let apiStart = Date().timeIntervalSinceReferenceDate
                    let computeQuotas = try await self.client.getComputeQuotas()
                    let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
                    Logger.shared.logDebug("DataManager - Fetched compute quotas in \(String(format: "%.2f", apiDuration))s")
                    await MainActor.run {
                        tui.cachedComputeQuotas = computeQuotas
                    }
                } catch let error as OpenStackError {
                    switch error {
                    case .httpError(400, _):
                        Logger.shared.logWarning("Compute quotas unavailable (HTTP 400) - project ID resolution may have failed")
                    case .httpError(403, _):
                        Logger.shared.logDebug("Compute quota access requires admin privileges (HTTP 403)")
                    case .httpError(404, _):
                        Logger.shared.logDebug("Compute quota endpoint not found (HTTP 404) - this API may not be available")
                    default:
                        Logger.shared.logError("Failed to fetch compute quotas: \(error)")
                    }
                } catch {
                    Logger.shared.logError("Failed to fetch compute quotas: \(error)")
                }
            }

            // Network Quotas
            group.addTask { [weak self] in
                guard let self = self else { return }
                do {
                    let apiStart = Date().timeIntervalSinceReferenceDate
                    let networkQuotas = try await self.client.getNetworkQuotas()
                    let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
                    Logger.shared.logDebug("DataManager - Fetched network quotas in \(String(format: "%.2f", apiDuration))s")
                    await MainActor.run {
                        tui.cachedNetworkQuotas = networkQuotas
                    }
                } catch let error as OpenStackError {
                    switch error {
                    case .httpError(400, _):
                        Logger.shared.logWarning("Network quotas unavailable (HTTP 400)")
                    case .httpError(403, _):
                        Logger.shared.logDebug("Network quota access requires admin privileges (HTTP 403)")
                    case .httpError(404, _):
                        Logger.shared.logDebug("Network quota endpoint not found (HTTP 404) - this API may not be available")
                    default:
                        Logger.shared.logError("Failed to fetch network quotas: \(error)")
                    }
                } catch {
                    Logger.shared.logError("Failed to fetch network quotas: \(error)")
                }
            }

            // Volume Quotas
            group.addTask { [weak self] in
                guard let self = self else { return }
                do {
                    let apiStart = Date().timeIntervalSinceReferenceDate
                    let volumeQuotas = try await self.client.getVolumeQuotas()
                    let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
                    Logger.shared.logDebug("DataManager - Fetched volume quotas in \(String(format: "%.2f", apiDuration))s")
                    await MainActor.run {
                        tui.cachedVolumeQuotas = volumeQuotas
                    }
                } catch let error as OpenStackError {
                    switch error {
                    case .httpError(400, _):
                        Logger.shared.logWarning("Volume quotas unavailable (HTTP 400)")
                    case .httpError(403, _):
                        Logger.shared.logDebug("Volume quota access requires admin privileges (HTTP 403)")
                    case .httpError(404, _):
                        Logger.shared.logDebug("Volume quota endpoint not found (HTTP 404) - this API may not be available")
                    default:
                        Logger.shared.logError("Failed to fetch volume quotas: \(error)")
                    }
                } catch {
                    Logger.shared.logError("Failed to fetch volume quotas: \(error)")
                }
            }

            // Compute Limits
            group.addTask { [weak self] in
                guard let self = self else { return }
                do {
                    let apiStart = Date().timeIntervalSinceReferenceDate
                    let computeLimits = try await self.client.getComputeLimits()
                    let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
                    Logger.shared.logDebug("DataManager - Fetched compute limits in \(String(format: "%.2f", apiDuration))s")
                    await MainActor.run {
                        tui.cachedComputeLimits = computeLimits
                    }
                } catch let error as OpenStackError {
                    switch error {
                    case .httpError(403, _):
                        Logger.shared.logDebug("Compute limits access may require admin privileges (HTTP 403)")
                    default:
                        Logger.shared.logError("Failed to fetch compute limits: \(error)")
                    }
                } catch {
                    Logger.shared.logError("Failed to fetch compute limits: \(error)")
                }
            }
        }
    }

    // Timeout helper for expensive operations
    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    struct TimeoutError: Error {}

    // Additional utility methods for backwards compatibility
    func purgeCache() async {
        guard let tui = tui else { return }

        tui.cachedServers.removeAll()
        tui.cachedNetworks.removeAll()
        tui.cachedVolumes.removeAll()
        tui.cachedImages.removeAll()
        tui.cachedVolumeTypes.removeAll()
        tui.cachedPorts.removeAll()
        tui.cachedRouters.removeAll()
        tui.cachedFlavors.removeAll()
        tui.cachedSubnets.removeAll()
        tui.cachedSecurityGroups.removeAll()
        tui.cachedKeyPairs.removeAll()
        tui.cachedComputeLimits = nil
        tui.cachedComputeQuotas = nil
        tui.cachedNetworkQuotas = nil
        tui.cachedVolumeQuotas = nil
        await tui.resourceNameCache.clearAsync()

        Logger.shared.logInfo("DataManager - Cache purged")

        await refreshAllDataOptimized()
    }

    // Individual refresh methods for specific resources
    func refreshImageData() async {
        await fetchImages(priority: "on-demand")
    }

    /// Generate flavor recommendations for all workload types in background
    private func generateFlavorRecommendationsInBackground(priority: String) async {
        guard let tui = tui else { return }

        // Skip if recently generated (cache for 30 minutes)
        let now = Date()
        if priority == "background" && now.timeIntervalSince(tui.lastRecommendationsRefresh) < 1800 && !tui.cachedFlavorRecommendations.isEmpty {
            Logger.shared.logDebug("DataManager - Skipping flavor recommendations generation (cached \(tui.cachedFlavorRecommendations.count) workload types)")
            return
        }

        Logger.shared.logDebug("DataManager - Generating flavor recommendations in background...")
        let generateStart = Date().timeIntervalSinceReferenceDate

        var newRecommendations: [WorkloadType: [FlavorRecommendation]] = [:]

        // Generate recommendations for each workload type
        for workloadType in WorkloadType.allCases {
            do {
                let scenarios = generateWorkloadScenarios(for: workloadType)
                var recommendations: [FlavorRecommendation] = []

                // Get one comprehensive recommendation and use its alternatives for diversity
                let mainRecommendation = try await client.suggestOptimalSize(
                    workloadType: workloadType,
                    expectedLoad: scenarios.first?.loadProfile ?? LoadProfile(cpuUtilization: 0.5, memoryUtilization: 0.5, diskIOPS: 1000, networkThroughput: 100, concurrentUsers: 50),
                    budget: scenarios.first?.budget
                )

                // Add the main recommendation
                recommendations.append(mainRecommendation)

                // Create diverse recommendations from alternatives with different reasoning
                for (index, alternativeFlavor) in mainRecommendation.alternativeFlavors.enumerated() {
                    if index < scenarios.count - 1 {
                        let scenario = scenarios[index + 1]
                        let altRecommendation = FlavorRecommendation(
                            recommendedFlavor: alternativeFlavor,
                            alternativeFlavors: [],
                            reasoningScore: max(0.6, mainRecommendation.reasoningScore - 0.1 * Double(index + 1)),
                            reasoning: generateAlternativeReasoning(for: alternativeFlavor, workloadType: workloadType, scenario: scenario),
                            estimatedMonthlyCost: FlavorOptimizer.estimatedMonthlyCost(for: alternativeFlavor),
                            performanceProfile: mainRecommendation.performanceProfile
                        )
                        recommendations.append(altRecommendation)
                    }
                }

                newRecommendations[workloadType] = recommendations
                Logger.shared.logDebug("DataManager - Generated \(recommendations.count) recommendations for \(workloadType.displayName)")

            } catch {
                Logger.shared.logWarning("DataManager - Failed to generate recommendations for \(workloadType.displayName): \(error)")
            }
        }

        // Update cache
        tui.cachedFlavorRecommendations = newRecommendations
        tui.resourceCache.setRecommendationsRefreshTime(now)

        let generateDuration = Date().timeIntervalSinceReferenceDate - generateStart
        Logger.shared.logDebug("DataManager - Generated flavor recommendations for \(newRecommendations.count) workload types in \(String(format: "%.2f", generateDuration))s")
    }

    /// Generate workload scenarios for recommendations
    private func generateWorkloadScenarios(for workloadType: WorkloadType) -> [(loadProfile: LoadProfile, budget: Budget?)] {
        switch workloadType {
        case .compute:
            return [
                (LoadProfile(cpuUtilization: 0.6, memoryUtilization: 0.4, diskIOPS: 1000, networkThroughput: 100, concurrentUsers: 50), nil),
                (LoadProfile(cpuUtilization: 0.8, memoryUtilization: 0.5, diskIOPS: 2000, networkThroughput: 200, concurrentUsers: 100), Budget(maxMonthlyCost: 200)),
                (LoadProfile(cpuUtilization: 0.9, memoryUtilization: 0.6, diskIOPS: 3000, networkThroughput: 300, concurrentUsers: 200), nil)
            ]
        case .memory:
            return [
                (LoadProfile(cpuUtilization: 0.4, memoryUtilization: 0.8, diskIOPS: 800, networkThroughput: 100, concurrentUsers: 30), nil),
                (LoadProfile(cpuUtilization: 0.5, memoryUtilization: 0.9, diskIOPS: 1200, networkThroughput: 150, concurrentUsers: 80), Budget(maxMonthlyCost: 300)),
                (LoadProfile(cpuUtilization: 0.6, memoryUtilization: 0.95, diskIOPS: 1800, networkThroughput: 200, concurrentUsers: 150), nil)
            ]
        case .balanced:
            return [
                (LoadProfile(cpuUtilization: 0.5, memoryUtilization: 0.5, diskIOPS: 1000, networkThroughput: 100, concurrentUsers: 25), Budget(maxMonthlyCost: 100)),
                (LoadProfile(cpuUtilization: 0.7, memoryUtilization: 0.6, diskIOPS: 1500, networkThroughput: 150, concurrentUsers: 75), nil),
                (LoadProfile(cpuUtilization: 0.8, memoryUtilization: 0.7, diskIOPS: 2000, networkThroughput: 200, concurrentUsers: 150), Budget(maxMonthlyCost: 250))
            ]
        case .storage:
            return [
                (LoadProfile(cpuUtilization: 0.4, memoryUtilization: 0.6, diskIOPS: 5000, networkThroughput: 200, concurrentUsers: 40), nil),
                (LoadProfile(cpuUtilization: 0.6, memoryUtilization: 0.7, diskIOPS: 8000, networkThroughput: 400, concurrentUsers: 100), Budget(maxMonthlyCost: 180)),
                (LoadProfile(cpuUtilization: 0.7, memoryUtilization: 0.8, diskIOPS: 12000, networkThroughput: 600, concurrentUsers: 200), nil)
            ]
        case .network:
            return [
                (LoadProfile(cpuUtilization: 0.5, memoryUtilization: 0.4, diskIOPS: 1000, networkThroughput: 1000, concurrentUsers: 100), nil),
                (LoadProfile(cpuUtilization: 0.7, memoryUtilization: 0.5, diskIOPS: 1500, networkThroughput: 2000, concurrentUsers: 300), Budget(maxMonthlyCost: 220)),
                (LoadProfile(cpuUtilization: 0.8, memoryUtilization: 0.6, diskIOPS: 2000, networkThroughput: 5000, concurrentUsers: 500), nil)
            ]
        case .gpu:
            return [
                (LoadProfile(cpuUtilization: 0.6, memoryUtilization: 0.7, diskIOPS: 2000, networkThroughput: 500, concurrentUsers: 10), nil),
                (LoadProfile(cpuUtilization: 0.8, memoryUtilization: 0.8, diskIOPS: 3000, networkThroughput: 800, concurrentUsers: 25), Budget(maxMonthlyCost: 500)),
                (LoadProfile(cpuUtilization: 0.9, memoryUtilization: 0.9, diskIOPS: 4000, networkThroughput: 1000, concurrentUsers: 50), nil)
            ]
        case .accelerated:
            return [
                (LoadProfile(cpuUtilization: 0.7, memoryUtilization: 0.6, diskIOPS: 3000, networkThroughput: 800, concurrentUsers: 20), nil),
                (LoadProfile(cpuUtilization: 0.8, memoryUtilization: 0.7, diskIOPS: 4000, networkThroughput: 1200, concurrentUsers: 50), Budget(maxMonthlyCost: 400)),
                (LoadProfile(cpuUtilization: 0.9, memoryUtilization: 0.8, diskIOPS: 5000, networkThroughput: 1500, concurrentUsers: 100), nil)
            ]
        }
    }

    /// Generate alternative reasoning for diverse recommendations
    private func generateAlternativeReasoning(for flavor: Flavor, workloadType: WorkloadType, scenario: (loadProfile: LoadProfile, budget: Budget?)) -> String {
        let baseName = flavor.name ?? "Unknown"
        let vcpus = flavor.vcpus
        let ram = flavor.ram
        let disk = flavor.disk

        // Generate scenario name and description based on workload type and scenario parameters
        let (scenarioName, description) = generateScenarioInfo(workloadType: workloadType, scenario: scenario)

        return "SCENARIO: \(scenarioName)\n\(description): \(baseName) with \(vcpus) vCPUs, \(ram)MB RAM, and \(disk)GB storage"
    }

    /// Generate scenario name and description for recommendations
    private func generateScenarioInfo(workloadType: WorkloadType, scenario: (loadProfile: LoadProfile, budget: Budget?)) -> (name: String, description: String) {
        let cpuUtil = scenario.loadProfile.cpuUtilization
        let memUtil = scenario.loadProfile.memoryUtilization
        let users = scenario.loadProfile.concurrentUsers
        let hasBudget = scenario.budget != nil

        switch workloadType {
        case .compute:
            if cpuUtil > 0.8 {
                return hasBudget ? ("Budget Performance", "Cost-effective high-CPU option") : ("High Performance", "Maximum CPU performance")
            } else {
                return hasBudget ? ("Budget Compute", "Balanced cost and performance") : ("Standard Compute", "Reliable CPU processing")
            }
        case .memory:
            if memUtil > 0.9 {
                return hasBudget ? ("Budget Memory Max", "Cost-conscious memory intensive") : ("Memory Intensive", "Maximum memory capacity")
            } else {
                return hasBudget ? ("Budget Memory", "Memory-focused with cost limits") : ("Memory Optimized", "Enhanced memory allocation")
            }
        case .storage:
            let diskIOPS = scenario.loadProfile.diskIOPS
            if diskIOPS > 8000 {
                return hasBudget ? ("Budget High I/O", "Cost-effective storage performance") : ("High I/O", "Maximum storage throughput")
            } else {
                return hasBudget ? ("Budget Storage", "Storage-focused with cost control") : ("Storage Optimized", "Balanced storage performance")
            }
        case .network:
            let networkThroughput = scenario.loadProfile.networkThroughput
            if networkThroughput > 2000 {
                return hasBudget ? ("Budget High Network", "Cost-effective network performance") : ("High Bandwidth", "Maximum network throughput")
            } else {
                return hasBudget ? ("Budget Network", "Network-optimized within budget") : ("Network Optimized", "Enhanced network capacity")
            }
        case .balanced:
            if users > 100 {
                return hasBudget ? ("Budget Enterprise", "Cost-effective enterprise solution") : ("Enterprise Scale", "Large-scale balanced workload")
            } else {
                return hasBudget ? ("Budget Balanced", "Cost-conscious balanced approach") : ("Balanced Standard", "Well-rounded performance")
            }
        case .gpu:
            if users > 25 {
                return hasBudget ? ("Budget GPU Scale", "Cost-effective GPU computing") : ("GPU Intensive", "High-performance GPU workload")
            } else {
                return hasBudget ? ("Budget GPU", "GPU computing within budget") : ("GPU Accelerated", "GPU-powered performance")
            }
        case .accelerated:
            if users > 50 {
                return hasBudget ? ("Budget HPC Scale", "Cost-effective HPC solution") : ("HPC Intensive", "High-performance computing")
            } else {
                return hasBudget ? ("Budget HPC", "HPC within budget constraints") : ("HPC Optimized", "Specialized hardware acceleration")
            }
        }
    }

    func refreshKeyPairData() async {
        await fetchKeyPairs(priority: "on-demand")
    }

    func refreshVolumeData() async {
        await fetchVolumes(priority: "on-demand")
    }

    func refreshSecurityGroupData() async {
        await fetchSecurityGroups(priority: "on-demand")
    }

    func refreshSecretsData() async {
        await fetchSecrets(priority: "on-demand")
    }

    func refreshRouterData() async {
        await fetchRouters(priority: "on-demand")
    }

    func refreshServerGroupData() async {
        await fetchServerGroups(priority: "on-demand")
    }

    func refreshServerData() async {
        await fetchServers(priority: "on-demand")
    }

    func refreshPortData() async {
        await fetchPorts(priority: "on-demand")
    }

    // Computed properties for easier access
    var availabilityZones: [String] {
        return tui?.cachedAvailabilityZones ?? []
    }

    var externalNetworks: [Network] {
        return tui?.cachedNetworks.filter { $0.external == true } ?? []
    }

    // MARK: - Pagination Management

    // Enable pagination for a specific resource type
    func enablePagination(for resourceType: String, config: PaginationConfig? = nil) async {
        let finalConfig = config ?? paginationConfigs[resourceType] ?? .medium
        paginationConfigs[resourceType] = finalConfig
        paginationEnabled.insert(resourceType)

        Logger.shared.logInfo("DataManager - Enabled pagination for \(resourceType) with config: pageSize=\(finalConfig.pageSize)")

        // Initialize pagination manager if needed
        await initializePaginationManager(for: resourceType, config: finalConfig)
    }

    // Disable pagination for a resource type (fallback to traditional loading)
    func disablePagination(for resourceType: String) {
        paginationEnabled.remove(resourceType)
        Logger.shared.logInfo("DataManager - Disabled pagination for \(resourceType)")

        // Clean up pagination manager
        switch resourceType {
        case "servers":
            serverPaginationManager = nil
        case "networks":
            networkPaginationManager = nil
        case "volumes":
            volumePaginationManager = nil
        case "ports":
            portPaginationManager = nil
        case "images":
            imagePaginationManager = nil
        case "securityGroups":
            securityGroupPaginationManager = nil
        default:
            Logger.shared.logWarning("DataManager - Unknown resource type for pagination: \(resourceType)")
        }
    }

    // Check if pagination is enabled for a resource type
    func isPaginationEnabled(for resourceType: String) -> Bool {
        return paginationEnabled.contains(resourceType)
    }

    private func initializePaginationManager(for resourceType: String, config: PaginationConfig) async {
        guard let tui = tui else { return }

        switch resourceType {
        case "servers":
            serverPaginationManager = PaginationManager<Server>.forServers(data: tui.cachedServers, config: config)
            await serverPaginationManager?.initialLoad()
        case "networks":
            networkPaginationManager = PaginationManager<Network>.forNetworks(data: tui.cachedNetworks, config: config)
            await networkPaginationManager?.initialLoad()
        case "volumes":
            volumePaginationManager = PaginationManager<Volume>.forVolumes(data: tui.cachedVolumes, config: config)
            await volumePaginationManager?.initialLoad()
        case "ports":
            portPaginationManager = PaginationManager<Port>.forPorts(data: tui.cachedPorts, config: config)
            await portPaginationManager?.initialLoad()
        case "images":
            imagePaginationManager = PaginationManager<Image>.forImages(data: tui.cachedImages, config: config)
            await imagePaginationManager?.initialLoad()
        case "securityGroups":
            securityGroupPaginationManager = PaginationManager<SecurityGroup>.forSecurityGroups(data: tui.cachedSecurityGroups, config: config)
            await securityGroupPaginationManager?.initialLoad()
        default:
            Logger.shared.logWarning("DataManager - Unknown resource type for pagination: \(resourceType)")
        }
    }

    // Get paginated data for a specific resource type
    func getPaginatedItems<T>(for resourceType: String, type: T.Type) async -> [T] {
        guard paginationEnabled.contains(resourceType) else { return [] }

        switch (resourceType, type) {
        case ("servers", is Server.Type):
            return (serverPaginationManager?.visibleItems as? [T]) ?? []
        case ("networks", is Network.Type):
            return (networkPaginationManager?.visibleItems as? [T]) ?? []
        case ("volumes", is Volume.Type):
            return (volumePaginationManager?.visibleItems as? [T]) ?? []
        case ("ports", is Port.Type):
            return (portPaginationManager?.visibleItems as? [T]) ?? []
        case ("images", is Image.Type):
            return (imagePaginationManager?.visibleItems as? [T]) ?? []
        case ("securityGroups", is SecurityGroup.Type):
            return (securityGroupPaginationManager?.visibleItems as? [T]) ?? []
        default:
            Logger.shared.logWarning("DataManager - Unsupported type combination: \(resourceType), \(type)")
            return []
        }
    }

    // Get visible items for virtual scrolling
    func getVisibleItems<T>(for resourceType: String, type: T.Type, viewport: Range<Int>) -> [T] {
        guard let tui = tui else { return [] }

        // If pagination is enabled, use pagination manager
        if paginationEnabled.contains(resourceType) {
            switch (resourceType, type) {
            case ("servers", is Server.Type):
                return (serverPaginationManager?.visibleItems as? [T]) ?? []
            case ("networks", is Network.Type):
                return (networkPaginationManager?.visibleItems as? [T]) ?? []
            case ("volumes", is Volume.Type):
                return (volumePaginationManager?.visibleItems as? [T]) ?? []
            case ("ports", is Port.Type):
                return (portPaginationManager?.visibleItems as? [T]) ?? []
            case ("images", is Image.Type):
                return (imagePaginationManager?.visibleItems as? [T]) ?? []
            case ("securityGroups", is SecurityGroup.Type):
                return (securityGroupPaginationManager?.visibleItems as? [T]) ?? []
            default:
                return []
            }
        }

        // Fallback to traditional viewport slicing
        let allItems: [T]
        switch (resourceType, type) {
        case ("servers", is Server.Type):
            allItems = (tui.cachedServers as? [T]) ?? []
        case ("networks", is Network.Type):
            allItems = (tui.cachedNetworks as? [T]) ?? []
        case ("volumes", is Volume.Type):
            allItems = (tui.cachedVolumes as? [T]) ?? []
        case ("ports", is Port.Type):
            allItems = (tui.cachedPorts as? [T]) ?? []
        case ("images", is Image.Type):
            allItems = (tui.cachedImages as? [T]) ?? []
        case ("securityGroups", is SecurityGroup.Type):
            allItems = (tui.cachedSecurityGroups as? [T]) ?? []
        default:
            allItems = []
        }

        let startIndex = max(0, viewport.lowerBound)
        let endIndex = min(allItems.count, viewport.upperBound)

        guard startIndex < endIndex else { return [] }
        return Array(allItems[startIndex..<endIndex])
    }

    // Navigation methods for paginated resources
    func nextPage(for resourceType: String) async -> Bool {
        guard paginationEnabled.contains(resourceType) else { return false }

        switch resourceType {
        case "servers":
            if let manager = serverPaginationManager, manager.hasNextPage {
                _ = await manager.nextPage()
                return true
            }
        case "networks":
            if let manager = networkPaginationManager, manager.hasNextPage {
                _ = await manager.nextPage()
                return true
            }
        case "volumes":
            if let manager = volumePaginationManager, manager.hasNextPage {
                _ = await manager.nextPage()
                return true
            }
        case "ports":
            if let manager = portPaginationManager, manager.hasNextPage {
                _ = await manager.nextPage()
                return true
            }
        case "images":
            if let manager = imagePaginationManager, manager.hasNextPage {
                _ = await manager.nextPage()
                return true
            }
        case "securityGroups":
            if let manager = securityGroupPaginationManager, manager.hasNextPage {
                _ = await manager.nextPage()
                return true
            }
        default:
            break
        }
        return false
    }

    func previousPage(for resourceType: String) async -> Bool {
        guard paginationEnabled.contains(resourceType) else { return false }

        switch resourceType {
        case "servers":
            if let manager = serverPaginationManager, manager.hasPreviousPage {
                _ = await manager.previousPage()
                return true
            }
        case "networks":
            if let manager = networkPaginationManager, manager.hasPreviousPage {
                _ = await manager.previousPage()
                return true
            }
        case "volumes":
            if let manager = volumePaginationManager, manager.hasPreviousPage {
                _ = await manager.previousPage()
                return true
            }
        case "ports":
            if let manager = portPaginationManager, manager.hasPreviousPage {
                _ = await manager.previousPage()
                return true
            }
        case "images":
            if let manager = imagePaginationManager, manager.hasPreviousPage {
                _ = await manager.previousPage()
                return true
            }
        case "securityGroups":
            if let manager = securityGroupPaginationManager, manager.hasPreviousPage {
                _ = await manager.previousPage()
                return true
            }
        default:
            break
        }
        return false
    }

    // Get pagination status for UI display
    func getPaginationStatus(for resourceType: String) -> String? {
        guard paginationEnabled.contains(resourceType) else { return nil }

        switch resourceType {
        case "servers":
            return serverPaginationManager?.getStatusInfo()
        case "networks":
            return networkPaginationManager?.getStatusInfo()
        case "volumes":
            return volumePaginationManager?.getStatusInfo()
        case "ports":
            return portPaginationManager?.getStatusInfo()
        case "images":
            return imagePaginationManager?.getStatusInfo()
        case "securityGroups":
            return securityGroupPaginationManager?.getStatusInfo()
        default:
            return nil
        }
    }

    // Update pagination data when cache changes
    private func updatePaginationData() async {
        guard let tui = tui else { return }

        if paginationEnabled.contains("servers"), let manager = serverPaginationManager {
            await manager.updateFromFilterCache(tui.cachedServers)
        }
        if paginationEnabled.contains("networks"), let manager = networkPaginationManager {
            await manager.updateFromFilterCache(tui.cachedNetworks)
        }
        if paginationEnabled.contains("volumes"), let manager = volumePaginationManager {
            await manager.updateFromFilterCache(tui.cachedVolumes)
        }
        if paginationEnabled.contains("ports"), let manager = portPaginationManager {
            await manager.updateFromFilterCache(tui.cachedPorts)
        }
        if paginationEnabled.contains("images"), let manager = imagePaginationManager {
            await manager.updateFromFilterCache(tui.cachedImages)
        }
        if paginationEnabled.contains("securityGroups"), let manager = securityGroupPaginationManager {
            await manager.updateFromFilterCache(tui.cachedSecurityGroups)
        }
    }

    // Auto-enable pagination for large datasets
    func enableAutoPagination(threshold: Int = 500) async {
        guard let tui = tui else { return }

        // Check each resource type and enable pagination if over threshold
        if tui.cachedServers.count > threshold && !paginationEnabled.contains("servers") {
            await enablePagination(for: "servers")
            Logger.shared.logInfo("DataManager - Auto-enabled pagination for servers (\(tui.cachedServers.count) items > \(threshold))")
        }

        if tui.cachedNetworks.count > threshold && !paginationEnabled.contains("networks") {
            await enablePagination(for: "networks")
            Logger.shared.logInfo("DataManager - Auto-enabled pagination for networks (\(tui.cachedNetworks.count) items > \(threshold))")
        }

        if tui.cachedVolumes.count > threshold && !paginationEnabled.contains("volumes") {
            await enablePagination(for: "volumes")
            Logger.shared.logInfo("DataManager - Auto-enabled pagination for volumes (\(tui.cachedVolumes.count) items > \(threshold))")
        }

        if tui.cachedPorts.count > threshold && !paginationEnabled.contains("ports") {
            await enablePagination(for: "ports")
            Logger.shared.logInfo("DataManager - Auto-enabled pagination for ports (\(tui.cachedPorts.count) items > \(threshold))")
        }

        if tui.cachedImages.count > threshold && !paginationEnabled.contains("images") {
            await enablePagination(for: "images")
            Logger.shared.logInfo("DataManager - Auto-enabled pagination for images (\(tui.cachedImages.count) items > \(threshold))")
        }

        if tui.cachedSecurityGroups.count > threshold && !paginationEnabled.contains("securityGroups") {
            await enablePagination(for: "securityGroups")
            Logger.shared.logInfo("DataManager - Auto-enabled pagination for securityGroups (\(tui.cachedSecurityGroups.count) items > \(threshold))")
        }
    }

    // MARK: - Router Detail Operations

    /// Fetch detailed router information with interfaces
    func getDetailedRouter(id: String) async throws -> Router {
        let neutronService = await client.neutron
        return try await neutronService.getRouter(id: id)
    }

    // MARK: - Service Catalog and Health Check Operations

    /// Get services from OpenStack service catalog (fast, no health checks)
    func getCatalog() async throws -> [Service] {
        let keystone = await client.keystone
        return try await keystone.listCatalog()
    }

    /// Get service catalog with full endpoint information
    func getCatalogWithEndpoints() async throws -> [TokenCatalogEntry] {
        let keystone = await client.keystone
        return try await keystone.listCatalogWithEndpoints()
    }

    /// Get OpenStack service catalog with health check information
    func getTokenLifetime() async -> TimeInterval? {
        return await client.coreClient.timeUntilTokenExpiration
    }

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

    // MARK: - Swift Object Storage

    private func fetchSwiftContainers(priority: String) async {
        guard let tui = tui else { return }

        Logger.shared.logDebug("DataManager - Fetching Swift containers (\(priority) priority)...")

        do {
            let apiStart = Date().timeIntervalSinceReferenceDate
            let containers = try await client.swift.listContainers()
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(containers.count) Swift containers in \(String(format: "%.2f", apiDuration))s")
            await MainActor.run {
                tui.cachedSwiftContainers = containers
            }
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Swift container access requires permissions (HTTP 403)")
            case .httpError(404, _):
                Logger.shared.logDebug("Swift service not available (HTTP 404)")
            case .endpointNotFound:
                Logger.shared.logDebug("Swift service endpoint not found - service may not be deployed")
            default:
                Logger.shared.logError("Failed to fetch Swift containers: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch Swift containers: \(error)")
        }
    }

    public func fetchSwiftObjects(containerName: String, priority: String, forceRefresh: Bool = false) async {
        guard let tui = tui else { return }

        // Check if objects are already cached (unless forceRefresh is true)
        if !forceRefresh {
            if let cachedObjects = tui.resourceCache.getSwiftObjects(forContainer: containerName) {
                Logger.shared.logDebug("DataManager - Using cached Swift objects for container '\(containerName)' (\(cachedObjects.count) objects)")
                return
            }
        }

        Logger.shared.logDebug("DataManager - Fetching Swift objects for container '\(containerName)' (\(priority) priority)...")

        do {
            let apiStart = Date().timeIntervalSinceReferenceDate
            let objects = try await client.swift.listObjects(containerName: containerName)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("DataManager - Fetched \(objects.count) Swift objects in \(String(format: "%.2f", apiDuration))s")
            await tui.resourceCache.setSwiftObjects(objects, forContainer: containerName)
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Swift object access requires permissions (HTTP 403)")
            case .httpError(404, _):
                Logger.shared.logDebug("Swift container not found (HTTP 404)")
            default:
                Logger.shared.logError("Failed to fetch Swift objects: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch Swift objects: \(error)")
        }
    }
}

// MARK: - Service Health Status Model

/// Health status information for an OpenStack service
public struct ServiceHealthStatus: Sendable {
    public let avgResponseTime: Double
    public let isHealthy: Bool

    public init(avgResponseTime: Double, isHealthy: Bool) {
        self.avgResponseTime = avgResponseTime
        self.isHealthy = isHealthy
    }
}
