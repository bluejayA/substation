// Sources/Substation/Modules/Flavors/FlavorsDataProvider.swift
import Foundation
import OSClient

/// Data provider implementation for Nova Flavors
///
/// This provider handles all data fetching operations for flavors,
/// replacing the centralized fetchFlavors() method in DataManager.
@MainActor
final class FlavorsDataProvider: DataProvider {
    // MARK: - Properties

    /// Weak reference to the module
    private weak var module: FlavorsModule?

    /// Weak reference to TUI for client and cache access
    private weak var tui: TUI?

    /// Last refresh timestamp
    private(set) var lastRefreshTime: Date?

    // MARK: - DataProvider Protocol

    let resourceType: String = "flavors"

    var currentItemCount: Int {
        return tui?.cacheManager.cachedFlavors.count ?? 0
    }

    var supportsPagination: Bool {
        return false
    }

    // MARK: - Initialization

    /// Initialize the flavors data provider
    ///
    /// - Parameters:
    ///   - module: The FlavorsModule instance
    ///   - tui: The main TUI instance
    init(module: FlavorsModule, tui: TUI) {
        self.module = module
        self.tui = tui
    }

    // MARK: - Data Fetching

    /// Fetch flavors from the OpenStack API
    ///
    /// - Parameters:
    ///   - priority: The fetch priority determining timeout behavior
    ///   - forceRefresh: Whether to bypass caches and fetch fresh data
    /// - Returns: Result of the fetch operation
    func fetchData(priority: DataFetchPriority, forceRefresh: Bool) async -> DataFetchResult {
        guard let tui = tui else {
            return DataFetchResult(
                itemCount: 0,
                duration: 0,
                error: ModuleError.invalidState("TUI reference is nil")
            )
        }

        let startTime = Date()

        do {
            Logger.shared.logDebug("FlavorsDataProvider - Fetching flavors", context: [
                "priority": priority.rawValue,
                "forceRefresh": forceRefresh
            ])

            // Determine timeout based on priority
            let timeoutSeconds = timeoutForPriority(priority)

            // Fetch flavors with appropriate timeout
            let flavors: [Flavor]
            if timeoutSeconds > 0 {
                flavors = try await withTimeout(seconds: timeoutSeconds) {
                    try await tui.client.listFlavors(forceRefresh: forceRefresh)
                }
            } else {
                flavors = try await tui.client.listFlavors(forceRefresh: forceRefresh)
            }

            // Update cache
            tui.cacheManager.cachedFlavors = flavors
            lastRefreshTime = Date()

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logInfo("FlavorsDataProvider - Fetched \(flavors.count) flavors", context: [
                "duration": String(format: "%.2f", duration),
                "priority": priority.rawValue
            ])

            return DataFetchResult(
                itemCount: flavors.count,
                duration: duration,
                fromCache: false
            )

        } catch let error as TimeoutError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logWarning("FlavorsDataProvider - Fetch timed out", context: [
                "timeout": timeoutForPriority(priority),
                "duration": String(format: "%.2f", duration)
            ])
            return DataFetchResult(
                itemCount: currentItemCount,
                duration: duration,
                error: error
            )

        } catch let error as OpenStackError {
            let duration = Date().timeIntervalSince(startTime)
            handleOpenStackError(error)
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.logError("FlavorsDataProvider - Failed to fetch flavors: \(error)")
            return DataFetchResult(
                itemCount: 0,
                duration: duration,
                error: error
            )
        }
    }

    /// Clear the flavors cache
    func clearCache() async {
        tui?.cacheManager.cachedFlavors.removeAll()
        tui?.cacheManager.cachedFlavorRecommendations.removeAll()
        lastRefreshTime = nil
        Logger.shared.logDebug("FlavorsDataProvider - Cache cleared")
    }

    // MARK: - Private Methods

    /// Get timeout interval based on priority
    ///
    /// - Parameter priority: The fetch priority
    /// - Returns: Timeout in seconds
    private func timeoutForPriority(_ priority: DataFetchPriority) -> TimeInterval {
        switch priority {
        case .critical:
            return 30.0  // Generous timeout for critical data
        case .secondary:
            return 20.0
        case .background:
            return 10.0  // Aggressive timeout for background fetches
        case .onDemand:
            return 30.0  // User-initiated, allow more time
        case .fast:
            return 15.0  // Quick refresh
        }
    }

    /// Handle OpenStack-specific errors with appropriate logging
    ///
    /// - Parameter error: The OpenStack error to handle
    private func handleOpenStackError(_ error: OpenStackError) {
        switch error {
        case .httpError(403, _):
            Logger.shared.logDebug("FlavorsDataProvider - Flavor access may require admin privileges (HTTP 403)")
        case .httpError(404, _):
            Logger.shared.logDebug("FlavorsDataProvider - Nova service may not be available (HTTP 404)")
        default:
            Logger.shared.logError("FlavorsDataProvider - OpenStack error: \(error)")
        }
    }

    /// Execute an operation with a timeout
    ///
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: TimeoutError if the operation times out
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
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

    /// Error type for timeout operations
    struct TimeoutError: Error {}

    // MARK: - Flavor Recommendations

    /// Generate flavor recommendations for all workload types
    ///
    /// - Parameter priority: The fetch priority
    func generateFlavorRecommendations(priority: DataFetchPriority) async {
        guard let tui = tui else { return }

        // Skip if recently generated (cache for 30 minutes)
        let now = Date()
        if priority == .background && now.timeIntervalSince(tui.cacheManager.lastRecommendationsRefresh) < 1800 && !tui.cacheManager.cachedFlavorRecommendations.isEmpty {
            Logger.shared.logDebug("FlavorsDataProvider - Skipping recommendations generation (cached \(tui.cacheManager.cachedFlavorRecommendations.count) workload types)")
            return
        }

        Logger.shared.logDebug("FlavorsDataProvider - Generating flavor recommendations in background...")
        let generateStart = Date().timeIntervalSinceReferenceDate

        var newRecommendations: [WorkloadType: [FlavorRecommendation]] = [:]

        // Generate recommendations for each workload type
        for workloadType in WorkloadType.allCases {
            do {
                let scenarios = generateWorkloadScenarios(for: workloadType)
                var recommendations: [FlavorRecommendation] = []

                // Get one comprehensive recommendation and use its alternatives for diversity
                let mainRecommendation = try await tui.client.suggestOptimalSize(
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
                Logger.shared.logDebug("FlavorsDataProvider - Generated \(recommendations.count) recommendations for \(workloadType.displayName)")

            } catch {
                Logger.shared.logWarning("FlavorsDataProvider - Failed to generate recommendations for \(workloadType.displayName): \(error)")
            }
        }

        // Update cache
        tui.cacheManager.cachedFlavorRecommendations = newRecommendations
        tui.resourceCache.setRecommendationsRefreshTime(now)

        let generateDuration = Date().timeIntervalSinceReferenceDate - generateStart
        Logger.shared.logDebug("FlavorsDataProvider - Generated flavor recommendations for \(newRecommendations.count) workload types in \(String(format: "%.2f", generateDuration))s")
    }

    /// Generate workload scenarios for recommendations
    ///
    /// - Parameter workloadType: The type of workload
    /// - Returns: Array of load profile and budget combinations
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
    ///
    /// - Parameters:
    ///   - flavor: The flavor to describe
    ///   - workloadType: The workload type
    ///   - scenario: The scenario parameters
    /// - Returns: Formatted reasoning string
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
    ///
    /// - Parameters:
    ///   - workloadType: The workload type
    ///   - scenario: The scenario parameters
    /// - Returns: Tuple of scenario name and description
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
}
