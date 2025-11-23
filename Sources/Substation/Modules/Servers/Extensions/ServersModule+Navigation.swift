// Sources/Substation/Modules/Servers/Extensions/ServersModule+Navigation.swift
import Foundation
import OSClient

// MARK: - ModuleNavigationProvider Conformance

extension ServersModule: ModuleNavigationProvider {

    /// Number of servers in the current view
    ///
    /// Returns the count of cached servers, applying any active search filter.
    /// This value is used for scroll calculations and empty state detection.
    var itemCount: Int {
        guard let tui = tui else { return 0 }

        let servers = tui.cacheManager.cachedServers

        // Apply search filter if present
        if let query = tui.searchQuery, !query.isEmpty {
            let filtered = FilterUtils.filterServers(
                servers,
                query: query,
                getServerIP: tui.resourceResolver.getServerIP
            )
            return filtered.count
        }

        return servers.count
    }

    /// Maximum selection index for servers view
    ///
    /// Returns the maximum valid selection index for bounds checking.
    var maxSelectionIndex: Int {
        return max(0, itemCount - 1)
    }

    /// Refresh server data from the API
    ///
    /// Clears cached server data and fetches fresh data from Nova.
    /// Also refreshes related resources (flavors, images) that are
    /// commonly needed when working with servers.
    ///
    /// - Throws: Any errors encountered during the refresh operation
    func refresh() async throws {
        guard let tui = tui else {
            throw ModuleError.invalidState("TUI reference is nil")
        }

        Logger.shared.logInfo("ServersModule refreshing data", context: [:])

        // Clear all caches to ensure fresh data
        await tui.cacheManager.clearAllCaches()

        // Fetch servers
        let serverResponse = try await tui.client.nova.listServers(forceRefresh: true)
        tui.cacheManager.cachedServers = serverResponse.servers

        // Fetch related resources
        let flavors = try await tui.client.nova.listFlavors(forceRefresh: true)
        tui.cacheManager.cachedFlavors = flavors

        let images = try await tui.client.glance.listImages()
        tui.cacheManager.cachedImages = images

        Logger.shared.logInfo("ServersModule refresh completed", context: [
            "serverCount": serverResponse.servers.count,
            "flavorCount": flavors.count,
            "imageCount": images.count
        ])
    }

    /// Get contextual command suggestions for servers view
    ///
    /// Returns commands that are commonly used when working with servers,
    /// such as related resource views and server operations.
    ///
    /// - Returns: Array of suggested command strings
    func getContextualSuggestions() -> [String] {
        return ["flavors", "images", "servergroups", "volumes", "networks", "securitygroups"]
    }

    /// Navigation provider accessor
    ///
    /// Returns self since ServersModule conforms to ModuleNavigationProvider.
    var navigationProvider: (any ModuleNavigationProvider)? {
        return self
    }

    /// Open detail view for the currently selected server
    ///
    /// Handles navigation to the server detail view for the currently selected
    /// server in the servers list. This filters servers based on any active
    /// search query and validates the selection index before transitioning.
    ///
    /// - Parameters:
    ///   - tui: The TUI instance for accessing view state and cache
    /// - Returns: true if the detail view was opened, false otherwise
    func openDetailView(tui: TUI) -> Bool {
        // Only handle servers view
        guard tui.viewCoordinator.currentView == .servers else {
            return false
        }

        // Filter servers using the same logic as itemCount
        let servers = tui.cacheManager.cachedServers
        let filteredServers: [Server]

        if let query = tui.searchQuery, !query.isEmpty {
            filteredServers = FilterUtils.filterServers(
                servers,
                query: query,
                getServerIP: tui.resourceResolver.getServerIP
            )
        } else {
            filteredServers = servers
        }

        // Validate selection
        guard !filteredServers.isEmpty &&
              tui.viewCoordinator.selectedIndex < filteredServers.count else {
            return false
        }

        // Set selected resource and navigate to detail view
        tui.viewCoordinator.selectedResource = filteredServers[tui.viewCoordinator.selectedIndex]
        tui.changeView(to: .serverDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0

        return true
    }
}

// MARK: - Workload Scenarios

extension ServersModule {

    /// Generate workload scenarios for server creation
    ///
    /// Returns a set of predefined workload scenarios based on the workload type.
    /// Each scenario includes a name, description, load profile, and budget.
    /// Used by the server creation form to suggest appropriate configurations.
    ///
    /// - Parameter workloadType: The type of workload to generate scenarios for
    /// - Returns: Array of workload scenario tuples with name, description, load profile, and budget
    func generateWorkloadScenarios(for workloadType: WorkloadType) -> [(name: String, description: String, loadProfile: LoadProfile, budget: Budget)] {
        guard let tui = tui else { return [] }

        let defaultBudget = tui.serverCreateForm.optimizationBudget ?? Budget(
            maxMonthlyCost: 1000.0,
            currency: "USD"
        )

        switch workloadType {
        case .compute:
            return [
                (
                    name: "Light Computing",
                    description: "Basic CPU tasks, development, testing",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.4,
                        diskIOPS: 500,
                        networkThroughput: 50,
                        concurrentUsers: 5
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 0.5, currency: "USD")
                ),
                (
                    name: "Intensive Computing",
                    description: "Heavy calculations, batch processing, compilation",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.9,
                        memoryUtilization: 0.6,
                        diskIOPS: 1000,
                        networkThroughput: 100,
                        concurrentUsers: 20
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "High-Performance Computing",
                    description: "Scientific computing, simulations, rendering",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.95,
                        memoryUtilization: 0.8,
                        diskIOPS: 2000,
                        networkThroughput: 200,
                        concurrentUsers: 50
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 2.0, currency: "USD")
                )
            ]

        case .memory:
            return [
                (
                    name: "Medium Memory Load",
                    description: "Application caching, small databases",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.4,
                        memoryUtilization: 0.7,
                        diskIOPS: 800,
                        networkThroughput: 100,
                        concurrentUsers: 25
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 0.7, currency: "USD")
                ),
                (
                    name: "High Memory Load",
                    description: "In-memory databases, big data analytics",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.5,
                        memoryUtilization: 0.9,
                        diskIOPS: 1500,
                        networkThroughput: 200,
                        concurrentUsers: 100
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "Extreme Memory Load",
                    description: "Large in-memory datasets, real-time analytics",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.95,
                        diskIOPS: 2500,
                        networkThroughput: 500,
                        concurrentUsers: 200
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 2.5, currency: "USD")
                )
            ]

        case .storage:
            return [
                (
                    name: "Moderate I/O",
                    description: "File servers, document storage",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.3,
                        memoryUtilization: 0.4,
                        diskIOPS: 2000,
                        networkThroughput: 200,
                        concurrentUsers: 50
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 0.6, currency: "USD")
                ),
                (
                    name: "High I/O",
                    description: "Database servers, backup systems",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.5,
                        memoryUtilization: 0.6,
                        diskIOPS: 5000,
                        networkThroughput: 500,
                        concurrentUsers: 100
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "Extreme I/O",
                    description: "High-performance databases, distributed storage",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.7,
                        diskIOPS: 10000,
                        networkThroughput: 1000,
                        concurrentUsers: 250
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 2.0, currency: "USD")
                )
            ]

        case .network:
            return [
                (
                    name: "Web Application",
                    description: "Standard web servers, API services",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.5,
                        memoryUtilization: 0.5,
                        diskIOPS: 1000,
                        networkThroughput: 500,
                        concurrentUsers: 100
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 0.7, currency: "USD")
                ),
                (
                    name: "High-Traffic Web",
                    description: "Load balancers, CDN, high-traffic sites",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.6,
                        diskIOPS: 2000,
                        networkThroughput: 2000,
                        concurrentUsers: 500
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "Network Gateway",
                    description: "Routers, gateways, network appliances",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.7,
                        memoryUtilization: 0.4,
                        diskIOPS: 1500,
                        networkThroughput: 5000,
                        concurrentUsers: 1000
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 1.5, currency: "USD")
                )
            ]

        default:
            // Balanced, GPU, Accelerated workloads
            return [
                (
                    name: "Standard Workload",
                    description: "Balanced resource usage, general applications",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.6,
                        diskIOPS: 1000,
                        networkThroughput: 200,
                        concurrentUsers: 50
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "Heavy Workload",
                    description: "Resource-intensive applications",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.8,
                        memoryUtilization: 0.8,
                        diskIOPS: 2000,
                        networkThroughput: 500,
                        concurrentUsers: 100
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 1.5, currency: "USD")
                )
            ]
        }
    }
}
