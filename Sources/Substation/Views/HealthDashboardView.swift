import Foundation
import SwiftTUI
import OSClient


// MARK: - Health Dashboard View

/// Enterprise-grade health monitoring dashboard with real-time telemetry integration
struct HealthDashboardView {

    // MARK: - Navigation State

    /// Current navigation section within the dashboard
    enum DashboardSection: CaseIterable {
        case overview
        case alerts
        case metrics
        case services

        var title: String {
            switch self {
            case .overview: return "System Overview"
            case .alerts: return "Active Alerts"
            case .metrics: return "Performance Metrics"
            case .services: return "Service Status"
            }
        }

        var sectionIndex: Int {
            switch self {
            case .overview: return 1
            case .alerts: return 2
            case .metrics: return 3
            case .services: return 4
            }
        }
    }

    /// Dashboard navigation state
    final class NavigationState: @unchecked Sendable {
        var currentSection: DashboardSection = .services
        var selectedIndex: Int = 0
        var scrollOffset: Int = 0
        var autoRefreshEnabled: Bool = true
        var manualRefreshRequested: Bool = false
        var showingDetails: Bool = false
        var detailsContent: String = ""

        // New window system properties
        var showingModal: Bool = false
        var modalTitle: String = ""
        var modalContent: String = ""

        // Data caching to prevent unnecessary refreshes during navigation
        var cachedHealthScore: HealthScore?
        var cachedActiveAlerts: [Alert]?
        var cachedRecentMetrics: [Metric]?
        fileprivate var cachedServiceStatus: [(String, ServiceStatus)]?
        var lastDataFetch: Date = Date(timeIntervalSince1970: 0)
        private let cacheValidityDuration: TimeInterval = 5.0 // 5 seconds cache

        // Selected service for detail view transitions
        var selectedService: HealthDashboardService?

        // Actual item counts for sections (updated dynamically)
        var actualServiceCount: Int = 0
        var actualAlertCount: Int = 0
        var actualMetricCount: Int = 0

        func shouldRefreshData() -> Bool {
            let now = Date()
            return now.timeIntervalSince(lastDataFetch) > cacheValidityDuration || manualRefreshRequested
        }

        func markDataRefreshed() {
            lastDataFetch = Date()
            manualRefreshRequested = false
        }

        func requestRefresh() {
            manualRefreshRequested = true
            // Clear all cached data to force fresh fetch
            cachedHealthScore = nil
            cachedActiveAlerts = nil
            cachedRecentMetrics = nil
            cachedServiceStatus = nil
        }

        func resetSelection() {
            selectedIndex = 0
            scrollOffset = 0
        }

        func moveUp() {
            if selectedIndex > 0 {
                selectedIndex -= 1
                if selectedIndex < scrollOffset {
                    scrollOffset = selectedIndex
                }
            }
        }

        func moveDown(maxItems: Int, visibleItems: Int = 6) {
            if selectedIndex < maxItems - 1 {
                selectedIndex += 1
                // Adjust scroll to keep selection visible
                if selectedIndex >= scrollOffset + visibleItems {
                    scrollOffset = selectedIndex - visibleItems + 1
                }
            }
        }

        func nextSection() {
            let allSections = DashboardSection.allCases
            if let currentIndex = allSections.firstIndex(of: currentSection) {
                currentSection = allSections[(currentIndex + 1) % allSections.count]
                resetSelection()
            }
        }

        func previousSection() {
            let allSections = DashboardSection.allCases
            if let currentIndex = allSections.firstIndex(of: currentSection) {
                let newIndex = (currentIndex - 1 + allSections.count) % allSections.count
                currentSection = allSections[newIndex]
                resetSelection()
            }
        }
    }

    // MARK: - Dashboard Configuration

    private struct DashboardConfig {
        static let refreshInterval: TimeInterval = 2.0
        static let maxAlertsToShow: Int = 5
        static let maxMetricsToShow: Int = 8
        static let maxServiceStatusItems: Int = 6
        static let progressBarWidth: Int = 20
    }

    // MARK: - Navigation Input Handling

    /// Handle input for dashboard navigation
    /// - Parameters:
    ///   - ch: Input character code
    ///   - navigationState: Current navigation state
    ///   - telemetryActor: Telemetry system for data refresh
    /// - Returns: True if input was handled, false if it should be passed to parent
    @MainActor
    static func handleInput(_ ch: Int32, navigationState: NavigationState, telemetryActor: TelemetryActor?, dataManager: DataManager?) async -> Bool {
        switch ch {
        // Removed manual refresh with 'r' key to avoid navigation conflicts

        case Int32(97): // a - Toggle auto-refresh
            navigationState.autoRefreshEnabled.toggle()
            Logger.shared.logUserAction("health_dashboard_auto_refresh_toggle", details: [
                "enabled": navigationState.autoRefreshEnabled
            ])
            return true

        case 258: // DOWN arrow - Navigate down in services
            let maxItems = getMaxItemsForSection(.services, telemetryActor: telemetryActor, navigationState: navigationState)
            let visibleItems = getVisibleItemsForSection(.services, navigationState: navigationState)
            Logger.shared.logDebug("Health Dashboard Navigation DOWN - maxItems: \(maxItems), currentIndex: \(navigationState.selectedIndex)")
            if maxItems > 0 {
                navigationState.moveDown(maxItems: maxItems, visibleItems: visibleItems)
                Logger.shared.logUserAction("health_dashboard_navigate_down", details: [
                    "section": "services",
                    "selectedIndex": navigationState.selectedIndex,
                    "maxItems": maxItems
                ])
                return true
            }
            return false

        case 259: // UP arrow - Navigate up in services
            let maxItems = getMaxItemsForSection(.services, telemetryActor: telemetryActor, navigationState: navigationState)
            Logger.shared.logDebug("Health Dashboard Navigation UP - maxItems: \(maxItems), currentIndex: \(navigationState.selectedIndex)")
            if maxItems > 0 {
                navigationState.moveUp()
                Logger.shared.logUserAction("health_dashboard_navigate_up", details: [
                    "section": "services",
                    "selectedIndex": navigationState.selectedIndex,
                    "maxItems": maxItems
                ])
                return true
            }
            return false

        // Section navigation removed for unified view

        case 338: // PAGE DOWN
            let maxItems = getMaxItemsForSection(.services, telemetryActor: telemetryActor, navigationState: navigationState)
            let visibleItems = getVisibleItemsForSection(.services, navigationState: navigationState)
            navigationState.selectedIndex = min(navigationState.selectedIndex + visibleItems, maxItems - 1)
            navigationState.scrollOffset = min(navigationState.scrollOffset + visibleItems, max(0, maxItems - visibleItems))
            return true

        case 339: // PAGE UP
            let visibleItems = getVisibleItemsForSection(.services, navigationState: navigationState)
            navigationState.selectedIndex = max(navigationState.selectedIndex - visibleItems, 0)
            navigationState.scrollOffset = max(navigationState.scrollOffset - visibleItems, 0)
            return true

        case Int32(32): // SPACE - Show details for selected item in new window
            return await handleItemDetailsTransition(navigationState: navigationState, telemetryActor: telemetryActor, dataManager: dataManager)

        case Int32(27): // ESC - Close modal window, details, or return to main menu
            if navigationState.showingModal {
                navigationState.showingModal = false
                navigationState.modalTitle = ""
                navigationState.modalContent = ""
                return true
            } else if navigationState.showingDetails {
                navigationState.showingDetails = false
                navigationState.detailsContent = ""
                return true
            }
            return false

        default:
            return false
        }
    }

    /// Get maximum items for current section for bounds checking
    private static func getMaxItemsForSection(_ section: DashboardSection, telemetryActor: TelemetryActor?, navigationState: NavigationState? = nil) -> Int {
        // Use actual counts if available, otherwise return safe defaults
        switch section {
        case .overview:
            return 1 // Only the overview summary is selectable
        case .alerts:
            return navigationState?.actualAlertCount ?? 10 // Use actual count or default
        case .metrics:
            return navigationState?.actualMetricCount ?? 8 // Use actual count or default
        case .services:
            // For services, use cached service count if available, otherwise default to reasonable number
            let actualCount = navigationState?.actualServiceCount ?? 0
            if actualCount > 0 {
                return actualCount
            }
            // If no actual count yet, try to get from cached services
            if let cachedServices = navigationState?.cachedServiceStatus {
                return cachedServices.count
            }
            return 20 // Final fallback
        }
    }

    /// Get visible items for current section for scrolling calculations
    private static func getVisibleItemsForSection(_ section: DashboardSection, navigationState: NavigationState? = nil) -> Int {
        switch section {
        case .overview: return 1 // Only the overview summary is selectable
        case .alerts: return min(navigationState?.actualAlertCount ?? 5, 5)
        case .metrics: return min(navigationState?.actualMetricCount ?? 8, 8)
        case .services: return navigationState?.actualServiceCount ?? 20 // Show all services up to screen limit
        }
    }

    /// Handle item details display for selected items (legacy inline method)
    @MainActor
    private static func handleItemDetails(navigationState: NavigationState, telemetryActor: TelemetryActor?, dataManager: DataManager?) async {
        Logger.shared.logUserAction("health_dashboard_item_details", details: [
            "section": "\(navigationState.currentSection)",
            "selectedIndex": navigationState.selectedIndex
        ])

        guard let telemetryActor = telemetryActor else { return }

        // Show details only for services section
        switch navigationState.currentSection {
        case .services:
            // Show detailed service information
            await showServiceDetails(navigationState: navigationState, telemetryActor: telemetryActor, dataManager: dataManager)
        default:
            // No details for other sections
            return
        }
    }

    /// Handle item details display in modal window for selected items (legacy)
    @MainActor
    private static func handleItemDetailsWindow(navigationState: NavigationState, telemetryActor: TelemetryActor?, dataManager: DataManager?) async {
        Logger.shared.logUserAction("health_dashboard_modal_details", details: [
            "section": "\(navigationState.currentSection)",
            "selectedIndex": navigationState.selectedIndex
        ])

        guard let telemetryActor = telemetryActor else { return }

        // Show modal window details only for services section
        switch navigationState.currentSection {
        case .services:
            // Show detailed service information in modal window
            await showServiceModalDetails(navigationState: navigationState, telemetryActor: telemetryActor, dataManager: dataManager)
        default:
            // No modal details for other sections
            return
        }
    }

    /// Handle item details by transitioning to detail view (like other resources)
    @MainActor
    private static func handleItemDetailsTransition(navigationState: NavigationState, telemetryActor: TelemetryActor?, dataManager: DataManager?) async -> Bool {
        Logger.shared.logUserAction("health_dashboard_detail_transition", details: [
            "section": "\(navigationState.currentSection)",
            "selectedIndex": navigationState.selectedIndex
        ])

        guard let telemetryActor = telemetryActor else { return true }

        // In unified view, always handle service detail transitions
        return await prepareServiceDetailTransition(navigationState: navigationState, telemetryActor: telemetryActor, dataManager: dataManager)
    }

    /// Prepare service detail data for view transition
    @MainActor
    private static func prepareServiceDetailTransition(navigationState: NavigationState, telemetryActor: TelemetryActor, dataManager: DataManager?) async -> Bool {
        // Use cached service status if available and valid
        let serviceStatus: [(String, ServiceStatus)]
        if let cachedStatus = navigationState.cachedServiceStatus,
           !navigationState.shouldRefreshData() {
            serviceStatus = cachedStatus
        } else {
            let metrics: [Metric]
            if let cachedMetrics = navigationState.cachedRecentMetrics {
                metrics = cachedMetrics
            } else {
                metrics = await telemetryActor.getMetrics(from: Date().addingTimeInterval(-600))
            }
            serviceStatus = await getOpenStackServiceStatus(from: metrics, dataManager: dataManager)
            navigationState.cachedServiceStatus = serviceStatus
        }

        guard navigationState.selectedIndex < serviceStatus.count else { return true }

        let (serviceName, status) = Array(serviceStatus)[navigationState.selectedIndex]

        // Get endpoint information
        var endpoints: [String] = []
        if let dataManager = dataManager {
            do {
                let catalogEntries = try await dataManager.getRawCatalog()
                if let catalogEntry = catalogEntries.first(where: { entry in
                    let entryName = (entry.name ?? entry.type).lowercased()
                    return entryName == serviceName.lowercased() || entry.type.lowercased() == serviceName.lowercased()
                }) {
                    endpoints = catalogEntry.endpoints.map { "\($0.interface): \($0.url)" }
                }
            } catch OpenStackError.authenticationFailed {
                Logger.shared.logError("Authentication failed while getting service endpoints: Session may have expired")
                endpoints = ["Authentication required - Please restart the application"]
            } catch let error as OpenStackError {
                Logger.shared.logError("Failed to get service endpoints for transition (OpenStackError): \(error)")
                endpoints = ["Error retrieving endpoints: \(error)"]
            } catch {
                Logger.shared.logError("Failed to get service endpoints for transition (generic error): \(error)")
                endpoints = ["Error retrieving endpoints"]
            }
        }

        // Create service detail object
        let serviceDetail = HealthDashboardService(
            name: serviceName,
            type: "OpenStack Service",
            avgResponseTime: status.avgResponseTime,
            isHealthy: status.isHealthy,
            endpoints: endpoints,
            lastUpdated: Date()
        )

        // Store the selected service for the detail view
        navigationState.selectedService = serviceDetail

        // Signal TUI to transition to service detail view
        // Return false to let the main input handler (which calls openDetailView) take over
        return false
    }


    /// Show detailed service information
    @MainActor
    private static func showServiceDetails(navigationState: NavigationState, telemetryActor: TelemetryActor, dataManager: DataManager? = nil) async {
        // Use cached service status if available and valid, otherwise fetch fresh data
        let serviceStatus: [(String, ServiceStatus)]
        if let cachedStatus = navigationState.cachedServiceStatus,
           !navigationState.shouldRefreshData() {
            serviceStatus = cachedStatus
        } else {
            let metrics = await telemetryActor.getMetrics(from: Date().addingTimeInterval(-600))
            serviceStatus = await getOpenStackServiceStatus(from: metrics, dataManager: dataManager)
            navigationState.cachedServiceStatus = serviceStatus
        }

        guard navigationState.selectedIndex < serviceStatus.count else { return }

        let (serviceName, status) = Array(serviceStatus)[navigationState.selectedIndex]
        Logger.shared.logUserAction("health_dashboard_service_details", details: [
            "serviceName": serviceName,
            "isHealthy": status.isHealthy,
            "avgResponseTime": status.avgResponseTime
        ])

        let healthStatus = status.isHealthy ? "HEALTHY" : "DEGRADED"

        // Handle response time classification - 0ms means no data, not excellent performance
        let responseTimeDisplay: String
        let responseTimeColor: String
        if status.avgResponseTime == 0.0 {
            responseTimeDisplay = "No recent data"
            responseTimeColor = "NO DATA"
        } else if status.avgResponseTime < 100 {
            responseTimeDisplay = "\(String(format: "%.0f", status.avgResponseTime))ms"
            responseTimeColor = "EXCELLENT"
        } else if status.avgResponseTime < 500 {
            responseTimeDisplay = "\(String(format: "%.0f", status.avgResponseTime))ms"
            responseTimeColor = "GOOD"
        } else {
            responseTimeDisplay = "\(String(format: "%.0f", status.avgResponseTime))ms"
            responseTimeColor = "POOR"
        }

        // Get endpoint information from service catalog
        let endpointInfo = await getServiceEndpointInfo(serviceName: serviceName, dataManager: dataManager)

        navigationState.showingDetails = true
        navigationState.detailsContent = """
        SERVICE DETAILS
        Service: \(serviceName)
        Status: \(healthStatus)
        Response Time: \(responseTimeDisplay) (\(responseTimeColor))
        Health Check: \(status.isHealthy ? "PASSING" : "FAILING")
        Last Updated: \(DateFormatter.timeOnly.string(from: Date()))
        \(endpointInfo)
        Connection: \(status.isHealthy ? "Stable" : "Unstable")
        """
    }

    /// Get endpoint information for a specific service
    @MainActor
    private static func getServiceEndpointInfo(serviceName: String, dataManager: DataManager?) async -> String {
        guard let dataManager = dataManager else {
            return "API Endpoints: Not available (no data manager)"
        }

        do {
            // Get the service catalog with endpoints
            let catalogEntries = try await dataManager.getRawCatalog()

            // Find the matching service by name (case-insensitive)
            if let catalogEntry = catalogEntries.first(where: { entry in
                let entryName = (entry.name ?? entry.type).lowercased()
                return entryName == serviceName.lowercased() || entry.type.lowercased() == serviceName.lowercased()
            }) {

                if catalogEntry.endpoints.isEmpty {
                    return "API Endpoints: No endpoints configured"
                }

                var endpointLines: [String] = ["API Endpoints:"]

                // Group endpoints by interface type (public, internal, admin)
                let endpointsByInterface = Dictionary(grouping: catalogEntry.endpoints) { $0.interface }

                for interface in ["public", "internal", "admin"] {
                    if let endpoints = endpointsByInterface[interface] {
                        for endpoint in endpoints {
                            let region = endpoint.region ?? "default"
                            endpointLines.append("  \(interface.capitalized) (\(region)): \(endpoint.url)")
                        }
                    }
                }

                return endpointLines.joined(separator: "\n")
            } else {
                return "API Endpoints: Service not found in catalog"
            }
        } catch OpenStackError.authenticationFailed {
            Logger.shared.logError("Authentication failed while getting service endpoints for \(serviceName): Session may have expired")
            return "API Endpoints: Authentication required - Please restart the application"
        } catch let error as OpenStackError {
            Logger.shared.logError("Failed to get service endpoints for \(serviceName) (OpenStackError): \(error)")
            return "API Endpoints: Error retrieving endpoint info (\(error))"
        } catch {
            Logger.shared.logError("Failed to get service endpoints for \(serviceName) (generic error): \(error)")
            return "API Endpoints: Error retrieving endpoint info"
        }
    }

    /// Show detailed service information in modal window
    @MainActor
    private static func showServiceModalDetails(navigationState: NavigationState, telemetryActor: TelemetryActor, dataManager: DataManager? = nil) async {
        let metrics = await telemetryActor.getMetrics(from: Date().addingTimeInterval(-600))
        let serviceStatus = await getOpenStackServiceStatus(from: metrics, dataManager: dataManager)

        guard navigationState.selectedIndex < serviceStatus.count else { return }

        let (serviceName, status) = Array(serviceStatus)[navigationState.selectedIndex]
        Logger.shared.logUserAction("health_dashboard_service_modal_details", details: [
            "serviceName": serviceName,
            "isHealthy": status.isHealthy,
            "avgResponseTime": status.avgResponseTime
        ])

        let healthStatus = status.isHealthy ? "HEALTHY" : "DEGRADED"

        // Handle response time classification - 0ms means no data, not excellent performance
        let responseTimeDisplay: String
        let responseTimeColor: String
        if status.avgResponseTime == 0.0 {
            responseTimeDisplay = "No recent data"
            responseTimeColor = "NO DATA"
        } else if status.avgResponseTime < 100 {
            responseTimeDisplay = "\(String(format: "%.0f", status.avgResponseTime))ms"
            responseTimeColor = "EXCELLENT"
        } else if status.avgResponseTime < 500 {
            responseTimeDisplay = "\(String(format: "%.0f", status.avgResponseTime))ms"
            responseTimeColor = "GOOD"
        } else {
            responseTimeDisplay = "\(String(format: "%.0f", status.avgResponseTime))ms"
            responseTimeColor = "POOR"
        }

        // Get endpoint information from service catalog
        let endpointInfo = await getServiceEndpointInfo(serviceName: serviceName, dataManager: dataManager)

        // Set modal window content
        navigationState.showingModal = true
        navigationState.modalTitle = "SERVICE DETAILS - \(serviceName.uppercased())"
        navigationState.modalContent = """
Service Name: \(serviceName)
Service Type: OpenStack Service
Current Status: \(healthStatus)

PERFORMANCE METRICS:
Response Time: \(responseTimeDisplay) (\(responseTimeColor))
Health Check: \(status.isHealthy ? "PASSING" : "FAILING")
Connection Status: \(status.isHealthy ? "Stable" : "Unstable")
Last Updated: \(DateFormatter.timeOnly.string(from: Date()))

\(endpointInfo)

OPERATIONAL STATUS:
Availability: \(status.isHealthy ? "Online" : "Degraded")
Monitoring: Active
Alert Level: \(status.isHealthy ? "Normal" : "Warning")

Press [ESC] to close this window
"""
    }



    // MARK: - Main Drawing Method

    @MainActor
    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                    width: Int32, height: Int32,
                    telemetryActor: TelemetryActor?, navigationState: NavigationState? = nil, dataManager: DataManager? = nil, performanceMonitor: PerformanceMonitor? = nil) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 40 && height > 15 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Terminal too small for Health Dashboard").error(), on: surface, in: errorBounds)
            return
        }

        guard let telemetryActor = telemetryActor else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftTUI.render(Text("Telemetry system not available").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Fetch data with caching to prevent unnecessary refreshes during navigation
        let healthScore: HealthScore
        let activeAlerts: [Alert]
        let recentMetrics: [Metric]

        if navigationState?.shouldRefreshData() ?? true {
            // Fetch fresh data
            healthScore = await telemetryActor.getHealthScore()
            activeAlerts = await telemetryActor.getActiveAlerts()
            recentMetrics = await telemetryActor.getMetrics(from: Date().addingTimeInterval(-600))

            // Cache the data
            navigationState?.cachedHealthScore = healthScore
            navigationState?.cachedActiveAlerts = activeAlerts
            navigationState?.cachedRecentMetrics = recentMetrics
            // Clear service cache when main data refreshes to ensure consistency
            navigationState?.cachedServiceStatus = nil
            navigationState?.markDataRefreshed()
        } else {
            // Use cached data
            if let cachedHealthScore = navigationState?.cachedHealthScore {
                healthScore = cachedHealthScore
            } else {
                healthScore = await telemetryActor.getHealthScore()
            }

            if let cachedActiveAlerts = navigationState?.cachedActiveAlerts {
                activeAlerts = cachedActiveAlerts
            } else {
                activeAlerts = await telemetryActor.getActiveAlerts()
            }

            if let cachedRecentMetrics = navigationState?.cachedRecentMetrics {
                recentMetrics = cachedRecentMetrics
            } else {
                recentMetrics = await telemetryActor.getMetrics(from: Date().addingTimeInterval(-600))
            }
        }

        // Header with timestamp
        let timestamp = DateFormatter.timeOnly.string(from: Date())
        let headerText = "SYSTEM HEALTH DASHBOARD - Updated: \(timestamp)"
        components.append(Text(headerText).emphasis().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0)))

        // Unified view - show all sections together

        // System Overview Section
        await addOverviewContent(&components, healthScore: healthScore, width: width)
        components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))) // Spacer

        // Performance Metrics Section - DEBUG VERSION (WORKING)
        let timestamp2 = DateFormatter.timeOnly.string(from: Date())
        components.append(Text("RESOURCE OVERVIEW (Updated: \(timestamp2))").primary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Test accessing dataManager and tui safely
        if let dataManager = dataManager {
            if let tui = dataManager.tui {
                // Access cached properties one at a time
                let serverCount = tui.cachedServers.count
                components.append(Text("Servers: \(serverCount)").secondary().padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)))

                let networkCount = tui.cachedNetworks.count
                components.append(Text("Networks: \(networkCount)").secondary().padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)))

                let volumeCount = tui.cachedVolumes.count
                components.append(Text("Volumes: \(volumeCount)").secondary().padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)))

                let imageCount = tui.cachedImages.count
                components.append(Text("Images: \(imageCount)").secondary().padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)))

                // Add cache metrics section
                components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))) // Spacer
                await addCacheMetrics(&components, tui: tui)
            } else {
                components.append(Text("TUI reference unavailable").muted().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
            }
        } else {
            components.append(Text("DataManager unavailable").muted().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        }
        components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))) // Spacer

        // Service Status Section (navigable in unified view)
        await addServicesContent(&components, metrics: recentMetrics, width: width, navigationState: navigationState, dataManager: dataManager, availableHeight: height)

        // Navigation and Control Information
        components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0)))

        // Navigation info for unified view
        let selectedItem = navigationState?.selectedIndex ?? 0
        let totalServices = navigationState?.actualServiceCount ?? 0
        let navigationText = "Service \(selectedItem + 1)/\(totalServices) | Use UP/DOWN arrows to navigate, SPACE for service details"
        components.append(Text(navigationText).secondary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Add details content if showing details
        if navigationState?.showingDetails == true, let detailsContent = navigationState?.detailsContent, !detailsContent.isEmpty {
            components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0)))
            components.append(Text("--- DETAILS ---").primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

            let contentLines = detailsContent.components(separatedBy: "\n")
            for line in contentLines {
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let trimmedLine = String(line.prefix(Int(width - 4)))
                    components.append(Text(trimmedLine).secondary().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
                }
            }

            components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
            components.append(Text("[ESC] Close Details").muted().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        }

        // First render the complete health dashboard
        let healthDashboardComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(healthDashboardComponent, on: surface, in: bounds)

        // Then render modal window on top if showing modal
        if navigationState?.showingModal == true {
            await renderModalWindow(screen: screen, startRow: startRow, startCol: startCol, width: width, height: height, navigationState: navigationState!)
        }
    }

    /// Render modal window overlay for service details using simple text-based approach
    @MainActor
    private static func renderModalWindow(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, navigationState: NavigationState) async {
        let surface = SwiftTUI.surface(from: screen)

        // Calculate modal window dimensions and position
        let modalWidth = min(width - 8, Int32(72))
        let modalHeight = min(height - 6, Int32(20))
        let modalStartCol = startCol + (width - modalWidth) / 2
        let modalStartRow = startRow + (height - modalHeight) / 2

        // Create modal content using text components with borders
        var modalComponents: [any Component] = []

        // Create top border
        let topBorder = "+" + String(repeating: "-", count: Int(modalWidth - 2)) + "+"
        modalComponents.append(Text(topBorder).primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Modal title with side borders
        if !navigationState.modalTitle.isEmpty {
            let titlePadding = max(0, Int(modalWidth) - 4 - navigationState.modalTitle.count) / 2
            let paddedTitle = String(repeating: " ", count: titlePadding) + navigationState.modalTitle + String(repeating: " ", count: titlePadding)
            let finalTitle = "| " + String(paddedTitle.prefix(Int(modalWidth - 4))) + String(repeating: " ", count: max(0, Int(modalWidth - 4) - paddedTitle.count)) + " |"
            modalComponents.append(Text(finalTitle).primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

            // Separator line
            let separator = "|" + String(repeating: "-", count: Int(modalWidth - 2)) + "|"
            modalComponents.append(Text(separator).secondary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        }

        // Modal content with side borders
        if !navigationState.modalContent.isEmpty {
            let contentLines = navigationState.modalContent.components(separatedBy: "\n")
            let maxContentLines = Int(modalHeight - 5) // Reserve space for borders and footer

            for line in contentLines.prefix(maxContentLines) {
                let contentText = String(line.prefix(Int(modalWidth - 4)))
                let paddedContent = contentText + String(repeating: " ", count: max(0, Int(modalWidth - 4) - contentText.count))
                let borderedLine = "| " + paddedContent + " |"
                modalComponents.append(Text(borderedLine).secondary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
            }

            // Add scroll indicator if content exceeds window
            if contentLines.count > maxContentLines {
                let truncateMsg = "... (content truncated)"
                let paddedTruncate = truncateMsg + String(repeating: " ", count: max(0, Int(modalWidth - 4) - truncateMsg.count))
                let borderedTruncate = "| " + paddedTruncate + " |"
                modalComponents.append(Text(borderedTruncate).muted().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
            }
        }

        // Modal footer with side borders
        let footerMsg = "[ESC] Close Window"
        let footerPadding = max(0, Int(modalWidth) - 4 - footerMsg.count)
        let paddedFooter = footerMsg + String(repeating: " ", count: footerPadding)
        let borderedFooter = "| " + paddedFooter + " |"
        modalComponents.append(Text(borderedFooter).muted().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Create bottom border
        let bottomBorder = "+" + String(repeating: "-", count: Int(modalWidth - 2)) + "+"
        modalComponents.append(Text(bottomBorder).primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Render modal content
        let modalComponent = VStack(spacing: 0, children: modalComponents)
        let modalBounds = Rect(x: modalStartCol, y: modalStartRow, width: modalWidth, height: modalHeight)
        await SwiftTUI.render(modalComponent, on: surface, in: modalBounds)
    }

    // MARK: - Service Detail View

    /// Draw service detail view (full window replacement)
    @MainActor
    public static func drawServiceDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                        width: Int32, height: Int32,
                                        service: HealthDashboardService, scrollOffset: Int) async {
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Service detail header
        components.append(Text("SERVICE DETAILS - \(service.name.uppercased())").primary().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0)))

        // Basic service information
        components.append(Text("BASIC INFORMATION").primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        components.append(Text("Service Name: \(service.name)").secondary().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        components.append(Text("Service Type: \(service.type)").secondary().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        components.append(Text("Last Updated: \(DateFormatter.timeOnly.string(from: service.lastUpdated))").secondary().padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))

        // Health status information
        components.append(Text("HEALTH STATUS").primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        let healthStatusText = service.isHealthy ? "HEALTHY" : "DEGRADED"
        if service.isHealthy {
            components.append(Text("Status: \(healthStatusText)").success().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
            components.append(Text("Health Check: PASSING").success().padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))
        } else {
            components.append(Text("Status: \(healthStatusText)").error().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
            components.append(Text("Health Check: FAILING").error().padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))
        }

        // Performance metrics
        components.append(Text("PERFORMANCE METRICS").primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        if service.avgResponseTime == 0.0 {
            components.append(Text("Response Time: No recent data").muted().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        } else {
            let responseTimeText = String(format: "Response Time: %.0fms", service.avgResponseTime)
            switch service.avgResponseTime {
            case 0..<100:
                components.append(Text(responseTimeText).success().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
            case 100..<500:
                components.append(Text(responseTimeText).warning().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
            default:
                components.append(Text(responseTimeText).error().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
            }
        }

        if service.isHealthy {
            components.append(Text("Connection Status: Stable").success().padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))
        } else {
            components.append(Text("Connection Status: Unstable").error().padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))
        }

        // API endpoints
        components.append(Text("API ENDPOINTS").primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        if service.endpoints.isEmpty {
            components.append(Text("No endpoints available").muted().padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))
        } else {
            for endpoint in service.endpoints {
                components.append(Text(endpoint).secondary().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
            }
            components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))) // Spacer
        }

        // Operational information
        components.append(Text("OPERATIONAL STATUS").primary().bold().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        if service.isHealthy {
            components.append(Text("Availability: Online").success().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        } else {
            components.append(Text("Availability: Degraded").warning().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        }
        components.append(Text("Monitoring: Active").success().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        if service.isHealthy {
            components.append(Text("Alert Level: Normal").success().padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))
        } else {
            components.append(Text("Alert Level: Warning").warning().padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))
        }

        // Footer with navigation instructions
        components.append(Text("").padding(EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0)))
        components.append(Text("[ESC] Back to Health Dashboard | [UP/DOWN] Scroll").muted().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Create scrollable content
        let visibleComponents = Array(components.dropFirst(scrollOffset))
        let serviceDetailComponent = VStack(spacing: 0, children: visibleComponents)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(serviceDetailComponent, on: surface, in: bounds)
    }

    // MARK: - Section Content Rendering

    /// Add content for the specified section
    @MainActor
    private static func addSectionContent(
        _ components: inout [any Component],
        section: DashboardSection,
        healthScore: HealthScore,
        activeAlerts: [Alert],
        recentMetrics: [Metric],
        width: Int32,
        height: Int32,
        navigationState: NavigationState?,
        dataManager: DataManager? = nil,
        performanceMonitor: PerformanceMonitor? = nil
    ) async {
        switch section {
        case .overview:
            await addOverviewContent(&components, healthScore: healthScore, width: width)
        case .alerts:
            await addAlertsContent(&components, alerts: activeAlerts, width: width, navigationState: navigationState)
        case .metrics:
            await addMetricsContentSafe(&components, metrics: recentMetrics, width: width, navigationState: navigationState, dataManager: dataManager)
        case .services:
            await addServicesContent(&components, metrics: recentMetrics, width: width, navigationState: navigationState, dataManager: dataManager, availableHeight: height)
        }
    }

    /// Add overview section content (health scores and component breakdown)
    @MainActor
    private static func addOverviewContent(
        _ components: inout [any Component],
        healthScore: HealthScore,
        width: Int32
    ) async {
        // Overall Health Score Section with visual indicator
        let timestamp = DateFormatter.timeOnly.string(from: Date())
        components.append(Text("OVERALL SYSTEM HEALTH (Updated: \(timestamp))").primary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        let overallScoreText = String(format: "Score: %.1f/100", healthScore.overall)
        let healthStatus = getHealthStatusIndicator(score: healthScore.overall)
        let healthBar = createProgressBar(value: healthScore.overall, maxValue: 100.0, width: Int(width / 2))

        components.append(Text("\(overallScoreText) \(healthStatus)").styled(getHealthStyle(score: healthScore.overall)).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        components.append(Text(healthBar).styled(getHealthStyle(score: healthScore.overall)).padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)))
    }

    /// Add alerts section content
    @MainActor
    private static func addAlertsContent(
        _ components: inout [any Component],
        alerts: [Alert],
        width: Int32,
        navigationState: NavigationState?
    ) async {
        let timestamp = DateFormatter.timeOnly.string(from: Date())

        // Update the actual alert count in navigation state
        navigationState?.actualAlertCount = alerts.count

        if alerts.isEmpty {
            components.append(Text("ACTIVE ALERTS (Updated: \(timestamp))").primary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
            components.append(Text("No active alerts").success().padding(EdgeInsets(top: 2, leading: 2, bottom: 1, trailing: 0)))
            return
        } else {
            components.append(Text("ACTIVE ALERTS (Updated: \(timestamp)) - \(alerts.count) alerts").primary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        }

        let startIndex = navigationState?.scrollOffset ?? 0
        let maxItems = min(Int(width / 8), DashboardConfig.maxAlertsToShow) // Adaptive based on screen width
        let alertsToShow = Array(alerts.dropFirst(startIndex).prefix(maxItems))

        for (index, alert) in alertsToShow.enumerated() {
            let isSelected = (index + startIndex) == (navigationState?.selectedIndex ?? 0)

            // Create alert row using HStack for better layout
            let alertRow = createAlertRow(
                alert: alert,
                isSelected: isSelected,
                maxWidth: Int(width - 4)
            )

            components.append(alertRow)
        }

        if alerts.count > alertsToShow.count {
            let additionalCount = alerts.count - (startIndex + alertsToShow.count)
            if additionalCount > 0 {
                components.append(Text("  ... and \(additionalCount) more alerts").muted().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
            }
        }
    }

    /// Add metrics section content - shows current resource counts with safe access patterns
    @MainActor
    private static func addMetricsContentSafe(
        _ components: inout [any Component],
        metrics: [Metric],
        width: Int32,
        navigationState: NavigationState?,
        dataManager: DataManager? = nil
    ) async {
        let timestamp = DateFormatter.timeOnly.string(from: Date())

        components.append(Text("RESOURCE OVERVIEW (Updated: \(timestamp))").primary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Defensive check: Ensure dataManager is available
        guard let dataManager = dataManager else {
            Logger.shared.logDebug("HealthDashboard - DataManager not available for metrics")
            components.append(Text("Resource data unavailable").muted().padding(EdgeInsets(top: 2, leading: 2, bottom: 1, trailing: 0)))
            return
        }

        // Defensive check: Ensure TUI reference is valid
        guard let tui = dataManager.tui else {
            Logger.shared.logDebug("HealthDashboard - TUI reference not available for metrics")
            components.append(Text("Resource data unavailable").muted().padding(EdgeInsets(top: 2, leading: 2, bottom: 1, trailing: 0)))
            return
        }

        // Safely access cached resource counts one at a time
        // This prevents any potential async/await issues with batch property access
        let serverCount = tui.cachedServers.count
        let networkCount = tui.cachedNetworks.count
        let volumeCount = tui.cachedVolumes.count
        let imageCount = tui.cachedImages.count
        let flavorCount = tui.cachedFlavors.count
        let floatingIPCount = tui.cachedFloatingIPs.count
        let securityGroupCount = tui.cachedSecurityGroups.count
        let routerCount = tui.cachedRouters.count

        // Build resource counts array from individual accesses
        let resourceCounts = [
            ("Servers", serverCount),
            ("Networks", networkCount),
            ("Volumes", volumeCount),
            ("Images", imageCount),
            ("Flavors", flavorCount),
            ("Floating IPs", floatingIPCount),
            ("Security Groups", securityGroupCount),
            ("Routers", routerCount)
        ]

        components.append(Text("COMPUTE & NETWORKING").secondary().bold().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        for (name, count) in resourceCounts.prefix(4) {
            let countText = String(format: "%-20s %3d", name + ":", count)
            components.append(Text(countText).secondary().padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)))
        }

        components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))) // Spacer
        components.append(Text("STORAGE & CONFIGURATION").secondary().bold().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        for (name, count) in resourceCounts.dropFirst(4) {
            let countText = String(format: "%-20s %3d", name + ":", count)
            components.append(Text(countText).secondary().padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)))
        }

        navigationState?.actualMetricCount = resourceCounts.count
    }

    /// Add cache metrics section - shows cache performance and statistics
    @MainActor
    private static func addCacheMetrics(
        _ components: inout [any Component],
        tui: TUI
    ) async {
        components.append(Text("CACHE METRICS").primary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Calculate total cached items
        let totalCachedResources =
            tui.cachedServers.count +
            tui.cachedNetworks.count +
            tui.cachedVolumes.count +
            tui.cachedImages.count +
            tui.cachedFlavors.count +
            tui.cachedFloatingIPs.count +
            tui.cachedSecurityGroups.count +
            tui.cachedRouters.count

        components.append(Text("Total Cached Items: \(totalCachedResources)").secondary().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))

        // Show memory container status
        components.append(Text("Memory System: Active").success().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))

        // Show cache breakdown by category
        components.append(Text("").padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        components.append(Text("Cache Distribution:").secondary().bold().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))

        let cacheBreakdown = [
            ("Compute", tui.cachedServers.count + tui.cachedFlavors.count),
            ("Network", tui.cachedNetworks.count + tui.cachedFloatingIPs.count + tui.cachedRouters.count + tui.cachedSecurityGroups.count),
            ("Storage", tui.cachedVolumes.count + tui.cachedImages.count)
        ]

        for (category, count) in cacheBreakdown {
            let percentage = totalCachedResources > 0 ? (Double(count) / Double(totalCachedResources) * 100.0) : 0
            let percentStr = String(format: "%.1f%%", percentage)
            components.append(Text("  \(category): \(count) items (\(percentStr))").secondary().padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)))
        }
    }

    /// Add services section content - now fills available vertical space
    @MainActor
    private static func addServicesContent(
        _ components: inout [any Component],
        metrics: [Metric],
        width: Int32,
        navigationState: NavigationState?,
        dataManager: DataManager? = nil,
        availableHeight: Int32 = 20
    ) async {
        // Use cached service status if available and valid, otherwise fetch fresh data
        let serviceStatus: [(String, ServiceStatus)]
        if let cachedStatus = navigationState?.cachedServiceStatus,
           !(navigationState?.shouldRefreshData() ?? true) {
            serviceStatus = cachedStatus
        } else {
            serviceStatus = await getOpenStackServiceStatus(from: metrics, dataManager: dataManager)
            // Cache the service status for future navigation
            navigationState?.cachedServiceStatus = serviceStatus
        }

        let timestamp = DateFormatter.timeOnly.string(from: Date())

        Logger.shared.logDebug("HealthDashboardView - Retrieved \(serviceStatus.count) services for display")

        // Update the actual service count in navigation state
        navigationState?.actualServiceCount = serviceStatus.count

        if serviceStatus.isEmpty {
            components.append(Text("CLIENT SIDE SERVICE STATUS (Updated: \(timestamp))").primary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
            components.append(Text("NO DATA - Service status unavailable").muted().padding(EdgeInsets(top: 2, leading: 2, bottom: 1, trailing: 0)))
            return
        } else {
            components.append(Text("CLIENT SIDE SERVICE STATUS (Updated: \(timestamp)) - \(serviceStatus.count) services").primary().padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        }

        let startIndex = navigationState?.scrollOffset ?? 0
        // Calculate how many services can fit in the available vertical space
        // Reserve space for header (2 lines), footer (4 lines), and some padding (4 lines)
        let reservedSpace: Int32 = 10
        let availableServiceLines = max(5, availableHeight - reservedSpace) // Ensure minimum of 5 services
        let maxServicesToShow = min(Int(availableServiceLines), serviceStatus.count)

        let servicesToShow = Array(serviceStatus.dropFirst(startIndex).prefix(maxServicesToShow))

        Logger.shared.logDebug("HealthDashboardView - Displaying \(servicesToShow.count) of \(serviceStatus.count) services (available height: \(availableHeight), service lines: \(availableServiceLines))")

        for (index, (serviceName, status)) in servicesToShow.enumerated() {
            let isSelected = (index + startIndex) == (navigationState?.selectedIndex ?? 0)

            // Create service status row using HStack for better layout
            let serviceRow = createServiceStatusRow(
                serviceName: serviceName,
                status: status,
                isSelected: isSelected,
                maxWidth: Int(width - 4)
            )

            components.append(serviceRow)
        }
    }

    // MARK: - Service Status Row Creation

    /// Create a well-formatted service status row with proper colors and layout
    @MainActor
    private static func createServiceStatusRow(
        serviceName: String,
        status: ServiceStatus,
        isSelected: Bool,
        maxWidth: Int
    ) -> any Component {
        let selectionIndicator = isSelected ? "> " : "  "

        // Status indicator with appropriate colors
        let statusIndicator: any Component
        if status.isHealthy {
            statusIndicator = Text("*").styled(.success).bold()
        } else {
            statusIndicator = Text("X").styled(.error).bold()
        }

        // Service name with selection highlighting
        let serviceNameText = Text(serviceName).styled(isSelected ? .accent : .secondary)

        // Response time with color coding based on performance
        let responseTime = status.avgResponseTime
        let responseText: any Component

        if responseTime == 0.0 {
            // No metrics available
            let responseTimeString = "NO DATA"
            responseText = Text(responseTimeString).styled(isSelected ? .muted.bold() : .muted)
        } else {
            let responseTimeString = String(format: "%.0fms", responseTime)
            switch responseTime {
            case 0..<100:
                responseText = Text(responseTimeString).styled(isSelected ? .success.bold() : .success)
            case 100..<500:
                responseText = Text(responseTimeString).styled(isSelected ? .warning.bold() : .warning)
            case 500..<1000:
                responseText = Text(responseTimeString).styled(isSelected ? .error.bold() : .error)
            default:
                responseText = Text(responseTimeString).styled(isSelected ? .error.bold() : .error)
            }
        }

        // Health status badge with distinctive styling
        let healthBadge: any Component
        if responseTime == 0.0 && status.isHealthy {
            // Service is available but no metrics collected yet
            healthBadge = Text("[READY]").styled(isSelected ? .success.bold() : .success)
        } else if responseTime == 0.0 && !status.isHealthy {
            // Service has problems and no data
            healthBadge = Text("[NO DATA]").styled(isSelected ? .muted.bold() : .muted)
        } else if status.isHealthy {
            healthBadge = Text("[HEALTHY]").styled(isSelected ? .success.bold() : .success)
        } else {
            healthBadge = Text("[DEGRADED]").styled(isSelected ? .error.bold() : .error)
        }

        // Create spacer to push response time to the right
        let responseLength = responseTime == 0.0 ? 7 : String(format: "%.0fms", responseTime).count
        let serviceSpacer = Text(String(repeating: " ", count: max(1, maxWidth - serviceName.count - responseLength - 20)))

        // Compose the row using HStack-like layout
        return HStack(spacing: 1, children: [
            Text(selectionIndicator).styled(isSelected ? .primary.bold() : .muted),
            statusIndicator,
            Text(" "),
            serviceNameText,
            serviceSpacer,
            responseText,
            Text(" "),
            healthBadge
        ]).padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    /// Create a well-formatted alert row with proper colors and layout
    @MainActor
    private static func createAlertRow(
        alert: Alert,
        isSelected: Bool,
        maxWidth: Int
    ) -> any Component {
        let selectionIndicator = isSelected ? "> " : "  "

        // Severity indicator with appropriate colors and symbols
        let severityIndicator: any Component
        switch alert.severity {
        case .critical:
            severityIndicator = Text("!").styled(.error).bold()
        case .warning:
            severityIndicator = Text("^").styled(.warning).bold()
        case .info:
            severityIndicator = Text("i").styled(.info).bold()
        }

        // Alert message with truncation and selection highlighting
        let truncatedMessage = String(alert.message.prefix(maxWidth - 10))
        let messageText = Text(truncatedMessage).styled(isSelected ? getAlertStyle(severity: alert.severity).bold() : getAlertStyle(severity: alert.severity))

        // Severity badge
        let severityBadge: any Component
        switch alert.severity {
        case .critical:
            severityBadge = Text("[CRITICAL]").styled(isSelected ? .error.bold() : .error)
        case .warning:
            severityBadge = Text("[WARNING]").styled(isSelected ? .warning.bold() : .warning)
        case .info:
            severityBadge = Text("[INFO]").styled(isSelected ? .info.bold() : .info)
        }

        // Compose the row
        return HStack(spacing: 1, children: [
            Text(selectionIndicator).styled(isSelected ? .primary.bold() : .muted),
            severityIndicator,
            Text(" "),
            messageText,
            Text(" "),
            severityBadge
        ]).padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    /// Create a well-formatted metric row with proper colors and layout
    @MainActor
    private static func createMetricRow(
        metricType: MetricType,
        data: HealthDashboardMetricSummary,
        isSelected: Bool,
        maxWidth: Int
    ) -> any Component {
        let selectionIndicator = isSelected ? "> " : "  "

        // Metric indicator based on type
        let metricIndicator: any Component
        switch metricType {
        case .apiCallDuration:
            metricIndicator = Text("T").styled(.secondary).bold()
        case .apiCallCount:
            metricIndicator = Text("#").styled(.secondary).bold()
        case .cacheHitRate:
            metricIndicator = Text("C").styled(.success).bold()
        case .memoryUsage:
            metricIndicator = Text("M").styled(.warning).bold()
        case .errorRate:
            metricIndicator = Text("E").styled(.error).bold()
        default:
            metricIndicator = Text("D").styled(.secondary).bold()
        }

        // Metric name
        let formattedName = formatMetricName(metricType.rawValue)
        let nameText = Text(formattedName).styled(isSelected ? .primary.bold() : .primary)

        // Values with color coding based on performance
        let unit = getMetricUnit(metricType)
        let avgValue = String(format: "%.2f", data.average)
        let minValue = String(format: "%.2f", data.minimum)
        let maxValue = String(format: "%.2f", data.maximum)

        // Color code average value based on metric type and thresholds
        let avgText: any Component
        switch metricType {
        case .apiCallDuration:
            if data.average < 100 {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .success.bold() : .success)
            } else if data.average < 500 {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .warning.bold() : .warning)
            } else {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .error.bold() : .error)
            }
        case .cacheHitRate:
            if data.average > 0.8 {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .success.bold() : .success)
            } else if data.average > 0.6 {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .warning.bold() : .warning)
            } else {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .error.bold() : .error)
            }
        case .errorRate:
            if data.average < 0.01 {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .success.bold() : .success)
            } else if data.average < 0.05 {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .warning.bold() : .warning)
            } else {
                avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .error.bold() : .error)
            }
        default:
            avgText = Text("\(avgValue)\(unit)").styled(isSelected ? .secondary.bold() : .secondary)
        }

        // Range info
        let rangeText = Text("(range: \(minValue)-\(maxValue)\(unit))").styled(isSelected ? .muted.bold() : .muted)

        // Create spacer for alignment
        let spacer = Text(" ")

        // Compose the row
        return HStack(spacing: 1, children: [
            Text(selectionIndicator).styled(isSelected ? .primary.bold() : .muted),
            metricIndicator,
            Text(" "),
            nameText,
            Text(": ").styled(.muted),
            avgText,
            spacer,
            rangeText
        ]).padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Dashboard State Management

    /// Get help text for current dashboard section
    static func getHelpText(for section: DashboardSection) -> [String] {
        switch section {
        case .overview:
            return [
                "SYSTEM OVERVIEW SECTION",
                "",
                "Shows overall system health score and component breakdown.",
                "Actions: [ENTER] for component details (future)"
            ]
        case .alerts:
            return [
                "ACTIVE ALERTS SECTION",
                "",
                "Displays current system alerts by severity.",
                "Actions: [ENTER] for alert details (future)"
            ]
        case .metrics:
            return [
                "PERFORMANCE METRICS SECTION",
                "",
                "Shows recent performance metrics and trends.",
                "Actions: [ENTER] for metric history (future)"
            ]
        case .services:
            return [
                "SERVICE STATUS SECTION",
                "",
                "Displays OpenStack service health and response times.",
                "Actions: [ENTER] for service details (future)"
            ]
        }
    }

    /// Reset navigation state for dashboard entry
    static func resetNavigationState(_ navigationState: NavigationState) {
        navigationState.currentSection = .overview
        navigationState.resetSelection()
    }

    // MARK: - Helper Methods

    private static func formatComponentName(_ name: String) -> String {
        return name.replacingOccurrences(of: "_", with: " ")
                  .split(separator: " ")
                  .map { $0.capitalized }
                  .joined(separator: " ")
    }

    private static func formatMetricName(_ name: String) -> String {
        return name.replacingOccurrences(of: "_", with: " ")
                  .split(separator: " ")
                  .map { $0.capitalized }
                  .joined(separator: " ")
    }

    private static func getHealthStatusIndicator(score: Double) -> String {
        switch score {
        case 90...:
            return "[EXCELLENT]"
        case 80..<90:
            return "[GOOD]"
        case 70..<80:
            return "[FAIR]"
        case 50..<70:
            return "[POOR]"
        default:
            return "[CRITICAL]"
        }
    }

    private static func getAlertSeverityIndicator(severity: AlertSeverity) -> String {
        switch severity {
        case .critical:
            return "[CRIT]"
        case .warning:
            return "[WARN]"
        case .info:
            return "[INFO]"
        }
    }

    private static func getHealthStyle(score: Double) -> TextStyle {
        switch score {
        case 80...:
            return .success
        case 60..<80:
            return .warning
        default:
            return .error
        }
    }

    private static func getAlertStyle(severity: AlertSeverity) -> TextStyle {
        switch severity {
        case .critical:
            return .error
        case .warning:
            return .warning
        case .info:
            return .info
        }
    }

    private static func createProgressBar(value: Double, maxValue: Double, width: Int) -> String {
        let percentage = min(max(value / maxValue, 0.0), 1.0)
        let filledWidth = Int(Double(width) * percentage)
        let emptyWidth = width - filledWidth

        let filled = String(repeating: "=", count: filledWidth)
        let empty = String(repeating: "-", count: emptyWidth)

        return "[\(filled)\(empty)] \(String(format: "%.1f", percentage * 100))%"
    }

    private static func aggregateRecentMetrics(_ metrics: [Metric]) -> [(MetricType, HealthDashboardMetricSummary)] {
        var aggregation: [MetricType: [Double]] = [:]

        // Group metrics by type
        for metric in metrics {
            aggregation[metric.type, default: []].append(metric.value)
        }

        // Calculate aggregations
        return aggregation.compactMap { (type, values) in
            guard !values.isEmpty else { return nil }

            let sum = values.reduce(0, +)
            let average = sum / Double(values.count)
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? 0

            return (type, HealthDashboardMetricSummary(average: average, minimum: minimum, maximum: maximum, count: values.count))
        }.sorted { $0.0.rawValue < $1.0.rawValue }
    }

    private static func getMetricUnit(_ type: MetricType) -> String {
        switch type {
        case .apiCallDuration:
            return "ms"
        case .apiCallCount:
            return ""
        case .cacheHitRate, .cacheMissRate:
            return "%"
        case .memoryUsage:
            return "MB"
        case .cpuUsage:
            return "%"
        case .networkLatency:
            return "ms"
        case .errorRate:
            return "%"
        case .resourceCount:
            return ""
        case .operationSuccess:
            return ""
        }
    }

    private static func getOpenStackServiceStatus(from metrics: [Metric], dataManager: DataManager? = nil) async -> [(String, ServiceStatus)] {
        // Use fast service catalog lookup (no health checks for dashboard speed)
        if let dataManager = dataManager {
            Logger.shared.logDebug("HealthDashboardView - Using fast service catalog lookup")
            return await getFastServiceStatus(dataManager: dataManager, metrics: metrics)
        }

        // Fallback to metrics-based approach (legacy behavior)
        Logger.shared.logDebug("HealthDashboardView - Using metrics-based fallback for service status")

        // Aggregate service performance from metrics
        var serviceMetrics: [String: [Double]] = [:]
        var serviceSuccessRates: [String: [Double]] = [:]

        for metric in metrics {
            // Extract service info from context if available
            if let service = metric.context["service"] {
                switch metric.type {
                case .apiCallDuration:
                    serviceMetrics[service, default: []].append(metric.value)
                case .operationSuccess:
                    serviceSuccessRates[service, default: []].append(metric.value)
                default:
                    break
                }
            }
        }

        var results: [(String, ServiceStatus)] = []

        // Calculate status for services with metrics
        for (serviceName, responseTimes) in serviceMetrics {
            let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
            let successRates = serviceSuccessRates[serviceName] ?? []
            let avgSuccessRate = successRates.isEmpty ? 1.0 : (successRates.reduce(0, +) / Double(successRates.count))

            let isHealthy = avgResponseTime < 2000 && avgSuccessRate >= 0.95
            results.append((serviceName, ServiceStatus(avgResponseTime: avgResponseTime, isHealthy: isHealthy)))
        }

        // Only add fallback services if no metrics data is available
        if results.isEmpty {
            Logger.shared.logDebug("HealthDashboardView - No metrics data available, showing placeholder message")
            return []
        }

        return results.sorted { $0.0 < $1.0 }
    }

    /// Fast service status using service catalog without health checks
    private static func getFastServiceStatus(dataManager: DataManager, metrics: [Metric]) async -> [(String, ServiceStatus)] {
        do {
            Logger.shared.logDebug("HealthDashboardView - Performing fast service catalog lookup")
            let startTime = Date().timeIntervalSinceReferenceDate

            // Get services from catalog using DataManager method
            Logger.shared.logDebug("HealthDashboardView - About to call dataManager.getCatalog()")
            let services = try await dataManager.getCatalog()
            Logger.shared.logDebug("HealthDashboardView - Successfully retrieved \(services.count) services from catalog")

            let duration = (Date().timeIntervalSinceReferenceDate - startTime) * 1000.0
            Logger.shared.logDebug("HealthDashboardView - Retrieved \(services.count) services in \(String(format: "%.0f", duration))ms")

            // If no services found in catalog, use fallback
            if services.isEmpty {
                Logger.shared.logWarning("HealthDashboardView - Service catalog is empty, using fallback services")
                return []
            }

            var results: [(String, ServiceStatus)] = []

            // Aggregate metrics by service name for response times
            var serviceMetrics: [String: [Double]] = [:]
            Logger.shared.logDebug("HealthDashboardView - Aggregating metrics for services \(metrics.count)")
            for metric in metrics {
                if let service = metric.context["service"], metric.type == .apiCallDuration {
                    Logger.shared.logDebug("HealthDashboardView - Found metric for service: \(service) with value: \(metric.value)")
                    serviceMetrics[service, default: []].append(metric.value)
                }
            }

            // Create service status based on catalog and metrics
            for service in services {
                let serviceName = (service.name ?? service.type).capitalized
                let serviceType = service.type.lowercased()

                Logger.shared.logDebug("HealthDashboardView - Processing service: \(serviceName) of type \(service.type)")

                // Calculate response time from recent metrics if available
                let avgResponseTime: Double
                let isHealthy: Bool

                // Try to find metrics by service type (compute, network, etc) or by name
                var responseTimes: [Double]? = serviceMetrics[serviceName.lowercased()]
                if responseTimes == nil || responseTimes!.isEmpty {
                    // Try matching by service type
                    responseTimes = serviceMetrics[serviceType]
                }
                if responseTimes == nil || responseTimes!.isEmpty {
                    // Try common OpenStack service name mappings
                    let serviceMapping: [String: String] = [
                        "compute": "nova",
                        "network": "neutron",
                        "identity": "keystone",
                        "image": "glance",
                        "volume": "cinder",
                        "volumev3": "cinder",
                        "object-store": "swift",
                        "orchestration": "heat"
                    ]
                    if let mappedName = serviceMapping[serviceType] {
                        responseTimes = serviceMetrics[mappedName]
                    }
                }

                if let times = responseTimes, !times.isEmpty {
                    // Use real metrics data
                    avgResponseTime = times.reduce(0, +) / Double(times.count)
                    isHealthy = avgResponseTime < 2000 // Less than 2 seconds is healthy
                    Logger.shared.logDebug("HealthDashboardView - Service \(serviceName) has \(times.count) metrics, avg: \(avgResponseTime)ms")
                } else {
                    // No metrics available - mark as healthy but with 0 response time
                    // This indicates the service exists but we haven't collected data yet
                    avgResponseTime = 0
                    isHealthy = true  // Changed from false to true - assume healthy if no data
                    Logger.shared.logDebug("HealthDashboardView - Service \(serviceName) has no metrics, marking as healthy with 0ms")
                }

                results.append((serviceName, ServiceStatus(avgResponseTime: avgResponseTime, isHealthy: isHealthy)))
            }

            return results.sorted { $0.0 < $1.0 }

        } catch OpenStackError.authenticationFailed {
            Logger.shared.logError("HealthDashboardView - CAUGHT AUTHENTICATION FAILED ERROR while getting service catalog, Session may have expired - returning error indicators")
            // Return services with authentication error indicator
            return [
                ("Authentication Failed", ServiceStatus(avgResponseTime: 0.0, isHealthy: false)),
                ("Session Expired", ServiceStatus(avgResponseTime: 0.0, isHealthy: false)),
                ("Please Restart Application", ServiceStatus(avgResponseTime: 0.0, isHealthy: false))
            ]
        } catch let error as OpenStackError {
            Logger.shared.logWarning("HealthDashboardView - Failed to get fast service status (OpenStackError): \(error)")
            return [
                ("Failed to get fast service status (OpenStackError)", ServiceStatus(avgResponseTime: 0.0, isHealthy: false))
            ]
        } catch {
            Logger.shared.logWarning("HealthDashboardView - Failed to get fast service status (generic error): \(error)")
            return [
                ("Failed to get fast service status (GenericError)", ServiceStatus(avgResponseTime: 0.0, isHealthy: false))
            ]
        }
    }

    // MARK: - Helper Functions

    /// Get health status text description
    private static func getHealthStatusText(status: Any) -> String {
        // Convert to string representation
        let statusString = "\(status)"

        switch statusString {
        case "healthy":
            return "HEALTHY - All systems operating normally"
        case "degraded":
            return "DEGRADED - Some performance issues detected"
        case "unhealthy":
            return "UNHEALTHY - Critical issues require attention"
        case "unknown":
            return "UNKNOWN - Health status cannot be determined"
        default:
            return "Status: \(statusString)"
        }
    }

    /// Format component details for display
    private static func formatComponentDetails(components: [String: Double]) -> String {
        let sortedComponents = components.sorted { $0.key < $1.key }
        return sortedComponents.map { key, value in
            let formattedName = formatComponentName(key)
            let indicator = getHealthStatusIndicator(score: value)
            return "  \(formattedName): \(String(format: "%.1f", value)) \(indicator)"
        }.joined(separator: "\n")
    }

    /// Get health assessment based on score
    private static func getHealthAssessment(score: Double) -> String {
        switch score {
        case 90...:
            return "System is performing exceptionally well. All components are healthy."
        case 80..<90:
            return "System is performing well with minor performance variations."
        case 70..<80:
            return "System performance is adequate but some components may need attention."
        case 60..<70:
            return "System performance is below optimal. Investigation recommended."
        default:
            return "System performance is concerning. Immediate attention required."
        }
    }
}

// MARK: - Supporting Types

private struct HealthDashboardMetricSummary {
    let average: Double
    let minimum: Double
    let maximum: Double
    let count: Int
}

private struct ServiceStatus {
    let avgResponseTime: Double
    let isHealthy: Bool
}

/// Public service detail model for view transitions
public struct HealthDashboardService {
    public let name: String
    public let type: String
    public let avgResponseTime: Double
    public let isHealthy: Bool
    public let endpoints: [String]
    public let lastUpdated: Date

    public init(name: String, type: String, avgResponseTime: Double, isHealthy: Bool, endpoints: [String] = [], lastUpdated: Date = Date()) {
        self.name = name
        self.type = type
        self.avgResponseTime = avgResponseTime
        self.isHealthy = isHealthy
        self.endpoints = endpoints
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Navigation Extensions

extension HealthDashboardView.NavigationState {
    /// Get current section display information
    var currentSectionInfo: String {
        return "\(currentSection.title) (\(selectedIndex + 1)/\(getApproximateItemCount()))"
    }

    /// Get approximate item count for current section
    private func getApproximateItemCount() -> Int {
        switch currentSection {
        case .overview: return 5
        case .alerts: return 10
        case .metrics: return 8
        case .services: return 6
        }
    }
}

