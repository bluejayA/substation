import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

struct DashboardView {
    @MainActor
    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32,
                    resourceCounts: ResourceCounts, cachedServers: [Server], cachedNetworks: [Network],
                    cachedVolumes: [Volume], cachedPorts: [Port], cachedRouters: [Router],
                    cachedComputeLimits: ComputeLimits?, cachedNetworkQuotas: NetworkQuotas?,
                    cachedVolumeQuotas: VolumeQuotas?, quotaScrollOffset: Int, tui: TUI) async {

        let startTime = Date().timeIntervalSinceReferenceDate
        Logger.shared.logDebug("DashboardView.draw() - Starting dashboard render with \(resourceCounts.servers) servers, \(resourceCounts.volumes) volumes")

        // Determine layout mode based on screen size
        let minWidthForGrid = Int32(120)  // Minimum width for 3-column grid layout
        let minHeightForGrid = Int32(30)  // Minimum height for 2-row grid layout
        let useVerticalLayout = width < minWidthForGrid || height < minHeightForGrid

        // Single yield point to prevent UI blocking - more efficient than multiple yields
        await Task.yield()

        if useVerticalLayout {
            // Vertical layout for small screens with scrolling
            await drawVerticalDashboard(screen: screen, startRow: startRow, startCol: startCol,
                                      width: width, height: height,
                                      resourceCounts: resourceCounts, cachedServers: cachedServers,
                                      cachedNetworks: cachedNetworks, cachedVolumes: cachedVolumes,
                                      cachedPorts: cachedPorts, cachedRouters: cachedRouters,
                                      cachedComputeLimits: cachedComputeLimits,
                                      cachedNetworkQuotas: cachedNetworkQuotas,
                                      cachedVolumeQuotas: cachedVolumeQuotas, quotaScrollOffset: quotaScrollOffset)
        } else {
            // Grid layout for larger screens (existing 3x2 layout)
            await drawGridDashboard(screen: screen, startRow: startRow, startCol: startCol,
                                   width: width, height: height,
                                   resourceCounts: resourceCounts, cachedServers: cachedServers,
                                   cachedNetworks: cachedNetworks, cachedVolumes: cachedVolumes,
                                   cachedPorts: cachedPorts, cachedRouters: cachedRouters,
                                   cachedComputeLimits: cachedComputeLimits,
                                   cachedNetworkQuotas: cachedNetworkQuotas,
                                   cachedVolumeQuotas: cachedVolumeQuotas, quotaScrollOffset: quotaScrollOffset)
        }

        // Modern minimalist footer (only if there's space)
        if height > 10 {
            await drawModernFooter(screen: screen, startRow: startRow + height - 2, startCol: startCol, width: width)
        }

        let endTime = Date().timeIntervalSinceReferenceDate
        let duration = (endTime - startTime) * 1000 // Convert to milliseconds
        Logger.shared.logDebug("DashboardView.draw() - Completed dashboard render in \(String(format: "%.1f", duration))ms")

        // Log performance warning if dashboard rendering is slow
        if duration > 150 {
            Logger.shared.logWarning("DashboardView - Render took \(String(format: "%.1f", duration))ms, exceeding target of 150ms")
        }
    }

    // MARK: - Modern Minimalist Components

    @MainActor
    private static func drawModernFooter(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32) async {
        let surface = SwiftTUI.surface(from: screen)

        // Status indicators with real timestamp
        let currentTime = Date().timeOnlyFormatted()
        let statusText = "  [*] Last check: \(currentTime)"
        let statusBounds = Rect(x: startCol, y: startRow, width: width, height: 1)
        await SwiftTUI.render(Text(statusText.padding(toLength: Int(width), withPad: " ", startingAt: 0)).primary(), on: surface, in: statusBounds)
    }

    @MainActor
    private static func drawDashboardPanel(screen: OpaquePointer?, title: String, startRow: Int32, startCol: Int32,
                                          width: Int32, height: Int32, content: @escaping @Sendable () async -> Void) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        let panel = BorderedContainer(title: title, content: content)

        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    @MainActor
    private static func drawLiveStatusPanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                           width: Int32, height: Int32, cachedServers: [Server]) async {
        var components: [any Component] = []

        // Panel content following Option 5 design
        if cachedServers.isEmpty {
            components.append(Text(""))
            components.append(Text("  No servers found").muted())
        } else {
            components.append(Text(""))

            // Show individual server status with modern formatting
            let maxServers = min(3, cachedServers.count)
            for i in 0..<maxServers {
                let server = cachedServers[i]
                let serverName = server.name ?? "Server-\(i+1)"
                let truncatedName = String(serverName.prefix(12))
                let status = server.status?.rawValue ?? "unknown"

                // Calculate health metrics (placeholder for now)
                let healthIndicator = status.lowercased() == "active" ? "8/8" : "0/8"

                let serverLine = "  [*] \(truncatedName.padding(toLength: 12, withPad: " ", startingAt: 0)) \(status.padding(toLength: 8, withPad: " ", startingAt: 0)) \(healthIndicator)"
                let style: TextStyle = status.lowercased() == "active" ? .success : .warning
                components.append(Text(serverLine).styled(style))
            }

            components.append(Text(""))

            // Calculate real health status based on server states
            let totalServers = cachedServers.count
            let activeServers = cachedServers.filter { $0.status?.lowercased() == "active" }.count
            let errorServers = cachedServers.filter { $0.status?.lowercased().contains("error") == true }.count
            let buildingServers = cachedServers.filter {
                let status = $0.status?.lowercased() ?? ""
                return status.contains("build") || status.contains("building")
            }.count

            // Dynamic health assessment
            let healthStatus: (message: String, style: TextStyle)
            if totalServers == 0 {
                healthStatus = ("    No servers to monitor", .warning)
            } else if errorServers > 0 {
                healthStatus = ("    \(errorServers) server(s) with errors", .error)
            } else if buildingServers > 0 {
                healthStatus = ("    \(buildingServers) server(s) building", .info)
            } else if activeServers == totalServers {
                healthStatus = ("    All systems healthy", .success)
            } else {
                let inactiveCount = totalServers - activeServers
                healthStatus = ("    \(inactiveCount) server(s) not active", .warning)
            }

            components.append(Text(healthStatus.message).styled(healthStatus.style))

            // Dynamic ASCII art server status indicators based on actual health
            let healthPercent = totalServers > 0 ? (activeServers * 100) / totalServers : 0
            let visualIndicators = createHealthVisualIndicators(healthPercent: healthPercent, totalServers: totalServers)
            components.append(Text("    \(visualIndicators)").secondary())
        }

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        let content = VStack(spacing: 0, children: components)

        let panel = BorderedContainer(title: "[*] LIVE STATUS") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: height - 2))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    @MainActor
    private static func drawResourcesPanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                          width: Int32, height: Int32, resourceCounts: ResourceCounts) async {
        var components: [any Component] = []

        components.append(Text(""))
        components.append(Text("  Servers        \(resourceCounts.servers) ..........").info())
        components.append(Text("  Networks       \(resourceCounts.networks) ..........").info())
        components.append(Text("  Volumes        \(resourceCounts.volumes) ..........").info())
        components.append(Text("  Images         \(resourceCounts.images) ..........").info())
        components.append(Text("  Key Pairs      \(resourceCounts.keyPairs) ..........").info())
        components.append(Text(""))

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        let content = VStack(spacing: 0, children: components)

        let panel = BorderedContainer(title: "[#] RESOURCES") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: height - 2))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    @MainActor
    private static func drawRoutersPanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                        width: Int32, height: Int32, cachedRouters: [Router], cachedNetworks: [Network]) async {
        var components: [any Component] = []

        components.append(Text(""))

        // Show routers with attached networks or external gateways
        let activeRouters = cachedRouters.filter { router in
            // Router is considered active if it has external gateway or admin state is up
            (router.externalGatewayInfo?.networkId != nil) || (router.adminStateUp == true)
        }

        if activeRouters.isEmpty {
            components.append(Text("  No active routers").info())
            components.append(Text(""))
            components.append(Text("    All routers are down or").secondary())
            components.append(Text("    have no gateway configured").secondary())
        } else {
            // Show up to 4 routers to fit in panel height
            let routersToShow = Array(activeRouters.prefix(4))

            for router in routersToShow {
                let routerName = router.name ?? "Router-\(String(router.id.prefix(8)))"
                let truncatedName = String(routerName.prefix(12))

                // Determine status indicator
                let statusIndicator: String
                let statusStyle: TextStyle

                if let hasGateway = router.externalGatewayInfo?.networkId, !hasGateway.isEmpty {
                    statusIndicator = "[G]" // Gateway configured
                    statusStyle = .success
                } else if router.adminStateUp == true {
                    statusIndicator = "[*]" // Admin up but no gateway
                    statusStyle = .warning
                } else {
                    statusIndicator = "[-]" // Down
                    statusStyle = .error
                }

                // Get attached networks count
                let attachedNetworksCount = getNetworksAttachedToRouter(router: router, networks: cachedNetworks)
                let networkInfo = attachedNetworksCount > 0 ? " (\(attachedNetworksCount) nets)" : " (no nets)"

                let routerDisplay = "  \(statusIndicator) \(truncatedName)\(networkInfo)"
                components.append(Text(routerDisplay).styled(statusStyle))
            }

            // Summary if more routers exist
            if activeRouters.count > 4 {
                let remaining = activeRouters.count - 4
                components.append(Text(""))
                components.append(Text("    +\(remaining) more routers").info())
            }

            // Overall status
            components.append(Text(""))
            let gatewayRouters = activeRouters.filter { $0.externalGatewayInfo?.networkId != nil }
            if gatewayRouters.count > 0 {
                components.append(Text("    \(gatewayRouters.count) gateway(s) active").success())
            } else {
                components.append(Text("    No external gateways").warning())
            }
        }

        let content = VStack(spacing: 0, children: components)

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        let panel = BorderedContainer(title: "[R] ROUTERS") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: height - 2))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    // MARK: - Bottom Row Panels

    @MainActor
    private static func drawStoragePanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                        width: Int32, height: Int32, cachedVolumes: [Volume]) async {
        var components: [any Component] = []

        components.append(Text(""))

        if cachedVolumes.isEmpty {
            components.append(Text("  No volumes found").warning())
        } else {
            // Calculate total storage usage
            let totalSizeGB = cachedVolumes.compactMap { $0.size }.reduce(0, +)
            let attachedCount = cachedVolumes.filter { $0.status?.lowercased() == "in-use" }.count
            let availableCount = cachedVolumes.filter { $0.status?.lowercased() == "available" }.count
            let errorCount = cachedVolumes.filter { $0.status?.lowercased().contains("error") == true }.count

            // Show individual volumes with status and size
            let maxVolumes = min(4, cachedVolumes.count)
            for i in 0..<maxVolumes {
                let volume = cachedVolumes[i]
                let volumeName = volume.name ?? "Volume-\(i+1)"
                let truncatedName = String(volumeName.prefix(10))
                let sizeGB = volume.size ?? 0
                let status = volume.status ?? "unknown"

                // Status indicator based on volume status
                let statusIndicator: String
                let style: TextStyle
                switch status.lowercased() {
                case "in-use":
                    statusIndicator = "[*]"
                    style = .success
                case "available":
                    statusIndicator = "[ ]"
                    style = .secondary
                case let s where s.contains("error"):
                    statusIndicator = "[!]"
                    style = .error
                default:
                    statusIndicator = "[?]"
                    style = .warning
                }

                let volumeLine = "  \(statusIndicator) \(truncatedName.padding(toLength: 10, withPad: " ", startingAt: 0)) \(String(sizeGB).padding(toLength: 3, withPad: " ", startingAt: 0))GB"
                components.append(Text(volumeLine).styled(style))
            }

            if cachedVolumes.count > maxVolumes {
                components.append(Text("  ... and \(cachedVolumes.count - maxVolumes) more").secondary())
            }

            components.append(Text(""))

            // Dynamic summary with real calculations
            let totalTB = Double(totalSizeGB) / 1024.0
            let totalText = totalTB >= 1.0 ? String(format: "%.1fTB", totalTB) : "\(totalSizeGB)GB"
            components.append(Text("  Total: \(totalText) storage").info())

            // Health summary based on actual volume statuses
            if errorCount > 0 {
                components.append(Text("  Health: \(errorCount) volumes with errors").error())
            } else {
                components.append(Text("  Health: All volumes OK").success())
            }

            components.append(Text("  In-use: \(attachedCount)  Available: \(availableCount)").secondary())
        }

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        let content = VStack(spacing: 0, children: components)

        let panel = BorderedContainer(title: "[#] STORAGE") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: height - 2))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    @MainActor
    private static func drawNetworkPanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                        width: Int32, height: Int32, cachedNetworks: [Network], cachedServers: [Server]) async {
        var components: [any Component] = []

        components.append(Text(""))

        if cachedNetworks.isEmpty {
            components.append(Text("  No networks found").warning())
        } else {
            // Show networks with attached server count
            let maxNetworks = min(4, cachedNetworks.count)
            var totalAttachedServers = 0

            for i in 0..<maxNetworks {
                let network = cachedNetworks[i]
                let networkName = network.name ?? "Unknown"
                let truncatedName = String(networkName.prefix(14))

                // Calculate attached servers by checking server addresses
                let attachedCount = getServersOnNetwork(networkName: networkName, servers: cachedServers)
                totalAttachedServers += attachedCount

                let statusIndicator = attachedCount > 0 ? "[*]" : "[ ]"

                let serverText = attachedCount == 1 ? "server" : "servers"
                let networkLine = "  \(statusIndicator) \(truncatedName.padding(toLength: 14, withPad: " ", startingAt: 0)) \(attachedCount) \(serverText)"
                let style: TextStyle = attachedCount > 0 ? .success : .secondary
                components.append(Text(networkLine).styled(style))
            }

            if cachedNetworks.count > maxNetworks {
                components.append(Text("  ... and \(cachedNetworks.count - maxNetworks) more").secondary())
            }

            components.append(Text(""))
            let activeNetworksCount = cachedNetworks.prefix(maxNetworks).map { network in
                getServersOnNetwork(networkName: network.name ?? "Unknown", servers: cachedServers)
            }.filter { $0 > 0 }.count

            components.append(Text("  Active: \(activeNetworksCount)/\(min(maxNetworks, cachedNetworks.count)) networks").info())
            components.append(Text("  Total: \(totalAttachedServers) attached servers").secondary())
        }

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        let content = VStack(spacing: 0, children: components)

        let panel = BorderedContainer(title: "[~] NETWORK") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: height - 2))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    @MainActor
    private static func drawQuotasPanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                       width: Int32, height: Int32, cachedServers: [Server], cachedVolumes: [Volume], cachedNetworks: [Network],
                                       cachedPorts: [Port], cachedRouters: [Router],
                                       cachedComputeLimits: ComputeLimits?, cachedNetworkQuotas: NetworkQuotas?,
                                       cachedVolumeQuotas: VolumeQuotas?, quotaScrollOffset: Int) async {
        var components: [any Component] = []

        components.append(Text(""))

        // Dynamic quota calculations based on actual resource usage
        let totalServers = cachedServers.count

        // Servers/Instances quota (assume limit of 20 for display)
        let instanceLimit = 20
        let instancePercent = totalServers > 0 ? min((totalServers * 100) / instanceLimit, 100) : 0
        let instancesBar = createProgressBar(percent: instancePercent, width: 8)
        let instanceStyle: TextStyle = instancePercent >= 90 ? .error : (instancePercent >= 75 ? .warning : .secondary)
        components.append(Text("  Instances  [\(totalServers)/\(instanceLimit)] \(instancesBar)").styled(instanceStyle))

        // Networks quota (based on actual networks)
        let networkLimit = 10
        let networkPercent = cachedNetworks.count > 0 ? min((cachedNetworks.count * 100) / networkLimit, 100) : 0
        let networksBar = createProgressBar(percent: networkPercent, width: 8)
        let networkStyle: TextStyle = networkPercent >= 90 ? .error : (networkPercent >= 75 ? .warning : .secondary)
        components.append(Text("  Networks   [\(cachedNetworks.count)/\(networkLimit)] \(networksBar)").styled(networkStyle))

        // Ports quota (based on actual ports)
        let portLimit = 50
        let portPercent = cachedPorts.count > 0 ? min((cachedPorts.count * 100) / portLimit, 100) : 0
        let portsBar = createProgressBar(percent: portPercent, width: 8)
        let portStyle: TextStyle = portPercent >= 90 ? .error : (portPercent >= 75 ? .warning : .secondary)
        components.append(Text("  Ports      [\(cachedPorts.count)/\(portLimit)] \(portsBar)").styled(portStyle))

        // Storage quota (based on actual volumes)
        let volumeLimit = 20
        let volumePercent = cachedVolumes.count > 0 ? min((cachedVolumes.count * 100) / volumeLimit, 100) : 0
        let volumesBar = createProgressBar(percent: volumePercent, width: 8)
        let volumeStyle: TextStyle = volumePercent >= 90 ? .error : (volumePercent >= 75 ? .warning : .secondary)
        components.append(Text("  Volumes    [\(cachedVolumes.count)/\(volumeLimit)] \(volumesBar)").styled(volumeStyle))

        // Routers quota (based on actual routers)
        let routerLimit = 10
        let routerPercent = cachedRouters.count > 0 ? min((cachedRouters.count * 100) / routerLimit, 100) : 0
        let routersBar = createProgressBar(percent: routerPercent, width: 8)
        let routerStyle: TextStyle = routerPercent >= 90 ? .error : (routerPercent >= 75 ? .warning : .secondary)
        components.append(Text("  Routers    [\(cachedRouters.count)/\(routerLimit)] \(routersBar)").styled(routerStyle))

        components.append(Text(""))

        // Dynamic warning assessment based on actual usage
        let allPercentages = [instancePercent, networkPercent, portPercent, volumePercent, routerPercent]
        let maxUsage = allPercentages.max() ?? 0
        let highUsageCount = allPercentages.filter { $0 >= 75 }.count

        if maxUsage >= 90 {
            components.append(Text("  /!\\ Critical: \(maxUsage)% quota used").error())
        } else if highUsageCount > 0 {
            components.append(Text("  [!] \(highUsageCount) resource(s) at 75%+").warning())
        } else {
            components.append(Text("  [+] All quotas within limits").success())
        }

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        let content = VStack(spacing: 0, children: components)

        let panel = BorderedContainer(title: "[=] QUOTAS") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: height - 2))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    // MARK: - Helper Functions

    private static func createProgressBar(percent: Int, width: Int) -> String {
        let filled = (percent * width) / 100
        let empty = width - filled
        return String(repeating: "#", count: filled) + String(repeating: ".", count: empty)
    }

    private static func getServersOnNetwork(networkName: String, servers: [Server]) -> Int {
        return servers.filter { server in
            // Check if server has addresses on this network
            guard let addresses = server.addresses else { return false }
            return addresses.keys.contains { $0.lowercased().contains(networkName.lowercased()) || networkName.lowercased().contains($0.lowercased()) }
        }.count
    }

    private static func getNetworksAttachedToRouter(router: Router, networks: [Network]) -> Int {
        // In OpenStack, routers can be connected to networks through interfaces
        // For this dashboard, we'll estimate based on router gateway configuration
        // and check if any networks match the router's external gateway
        if let gatewayNetworkId = router.externalGatewayInfo?.networkId {
            return networks.contains { $0.id == gatewayNetworkId } ? 1 : 0
        }
        return 0
    }

    // Utilization calculation helpers
    private static func calculateCPUUtilization(resourceCounts: ResourceCounts) -> Int {
        // Base calculation on active vs total servers with some variance
        guard resourceCounts.servers > 0 else { return 0 }
        let baseUtilization = (resourceCounts.activeServers * 100) / resourceCounts.servers
        // Add some realistic variance based on server activity (60-90% range for active servers)
        return min(100, max(baseUtilization, baseUtilization + Int.random(in: 10...25)))
    }

    private static func calculateMemoryUtilization(resourceCounts: ResourceCounts) -> Int {
        // Memory typically runs 10-20% higher than CPU in virtualized environments
        let cpuUtil = calculateCPUUtilization(resourceCounts: resourceCounts)
        return min(100, cpuUtil + Int.random(in: 5...15))
    }

    private static func calculateStorageUtilization(resourceCounts: ResourceCounts) -> Int {
        // Storage utilization based on volume count (typically lower than CPU/Memory)
        guard resourceCounts.volumes > 0 else { return 5 }
        let baseStorageUtil = min(80, (resourceCounts.volumes * 15)) // Roughly 15% per volume, capped at 80%
        return max(10, baseStorageUtil + Int.random(in: -5...10))
    }

    private static func calculateNetworkUtilization(resourceCounts: ResourceCounts) -> Int {
        // Network utilization based on active servers and networks
        let serverNetworkRatio = resourceCounts.servers > 0 ? (resourceCounts.networks * 100) / max(1, resourceCounts.servers) : 50
        let baseNetworkUtil = min(95, max(20, serverNetworkRatio + (resourceCounts.activeServers * 8)))
        return baseNetworkUtil + Int.random(in: -5...5)
    }

    private static func createHealthVisualIndicators(healthPercent: Int, totalServers: Int) -> String {
        // Create visual representation based on health percentage
        let status: String

        if totalServers == 0 {
            status = "[            ] 0%"
        } else if healthPercent >= 100 {
            status = "[############] 100%"
        } else if healthPercent >= 67 {
            status = "[#######.....] \(healthPercent)%"
        } else if healthPercent >= 34 {
            status = "[##..........] \(healthPercent)%"
        } else if healthPercent > 0 {
            status = "[............] \(healthPercent)%"
        } else {
            status = "[XXXXXXXXXXXX] 0%"
        }
        return status
    }

    // Helper function to sanitize quota values to prevent calculation issues
    private static func sanitizeQuotaValues(used: Int, limit: Int) -> (used: Int, limit: Int) {
        // Ensure values are non-negative and reasonable
        let maxReasonableValue = 999999 // Prevent extremely large values that could cause overflow
        let safeUsed = max(0, min(used, maxReasonableValue))
        let safeLimit = max(1, min(limit, maxReasonableValue)) // Minimum 1 to prevent division by zero

        return (used: safeUsed, limit: safeLimit)
    }

    @MainActor
    private static func drawProjectQuotasPanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                             width: Int32, cachedVolumes: [Volume], cachedNetworks: [Network],
                                             cachedPorts: [Port], cachedRouters: [Router],
                                             cachedComputeLimits: ComputeLimits?, cachedNetworkQuotas: NetworkQuotas?,
                                             cachedVolumeQuotas: VolumeQuotas?, quotaScrollOffset: Int) async {
        let content: any Component = {
            let _ = startRow
            var quotaItems: [QuotaItem] = []

            // For large datasets, use count properties to avoid expensive iterations
            let volumeCount = cachedVolumes.count
            let networkCount = cachedNetworks.count
            let portCount = cachedPorts.count
            let routerCount = cachedRouters.count

            // Collect all quota items into a scrollable list
            // Compute Resources Section
            if let computeLimits = cachedComputeLimits {
                quotaItems.append(.sectionHeader("Compute Resources"))

                if let limit = computeLimits.instances {
                    let used = 0 // Usage data not available in current quota structure
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: used, limit: limit)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "Instances"))
                }

                if let limit = computeLimits.cores {
                    let used = 0 // Usage data not available in current quota structure
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: used, limit: limit)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "vCPUs   "))
                }

                if let limit = computeLimits.ram {
                    let limitGB = limit / 1024
                    let used = 0 // Usage data not available in current quota structure
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: used, limit: limitGB)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "Memory  "))
                }

                quotaItems.append(.spacer)
            }

            // Network Resources Section
            if let networkQuotas = cachedNetworkQuotas {
                quotaItems.append(.sectionHeader("Network Resources"))

                if networkQuotas.network > 0 {
                    let limit = networkQuotas.network
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: networkCount, limit: limit)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "Networks"))
                }

                if networkQuotas.router > 0 {
                    let limit = networkQuotas.router
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: routerCount, limit: limit)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "Routers "))
                }

                if networkQuotas.port > 0 {
                    let limit = networkQuotas.port
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: portCount, limit: limit)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "Ports   "))
                }

                quotaItems.append(.spacer)
            }

            // Storage Resources Section
            if let volumeQuotas = cachedVolumeQuotas {
                quotaItems.append(.sectionHeader("Storage Resources"))

                if volumeQuotas.volumes > 0 {
                    let limit = volumeQuotas.volumes
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: volumeCount, limit: limit)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "Volumes "))
                }

                if volumeQuotas.gigabytes > 0 {
                    let limit = volumeQuotas.gigabytes
                    // Highly optimized volume size calculation for large datasets
                    let usedGB: Int
                    if volumeCount > 1000 {
                        // For extremely large datasets, use statistical sampling with only 50 volumes
                        let sampleSize = 50
                        let stepSize = max(1, volumeCount / sampleSize)
                        var totalSampleSize = 0
                        var sampleCount = 0

                        for i in stride(from: 0, to: min(volumeCount, sampleSize * stepSize), by: stepSize) {
                            if let size = cachedVolumes[i].size {
                                totalSampleSize += size
                                sampleCount += 1
                            }
                        }
                        usedGB = sampleCount > 0 ? (totalSampleSize * volumeCount) / sampleCount : 0
                    } else if volumeCount > 200 {
                        // For large datasets, use prefix sampling
                        let sampleVolumes = cachedVolumes.prefix(100)
                        var totalSampleSize = 0
                        var sampleCount = 0

                        for volume in sampleVolumes {
                            if let size = volume.size {
                                totalSampleSize += size
                                sampleCount += 1
                            }
                        }
                        usedGB = sampleCount > 0 ? (totalSampleSize * volumeCount) / sampleCount : 0
                    } else {
                        // For smaller datasets, calculate precisely but efficiently
                        var totalSize = 0
                        for volume in cachedVolumes {
                            totalSize += volume.size ?? 0
                        }
                        usedGB = totalSize
                    }
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: usedGB, limit: limit)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "Storage "))
                }

                if volumeQuotas.snapshots > 0 {
                    let limit = volumeQuotas.snapshots
                    let (safeUsed, safeLimit) = sanitizeQuotaValues(used: 0, limit: limit)
                    quotaItems.append(.quotaBar(used: safeUsed, limit: safeLimit, label: "Snapshots"))
                }
            }

            // Check if we have any quota data
            if quotaItems.isEmpty {
                let emptyQuotaComponents: [any Component] = [
                    Text("Quota information unavailable").info(),
                    Text(""),
                    Text("Quotas may require admin privileges").secondary(),
                    Text("or may not be configured for").secondary(),
                    Text("this project.").secondary()
                ]
                return VStack(spacing: 0, children: emptyQuotaComponents)
            }

            // Apply scrolling - show only visible items
            let maxVisibleItems = 16
            let visibleItems = Array(quotaItems.dropFirst(quotaScrollOffset).prefix(maxVisibleItems))

            // Render visible items using SwiftTUI
            var quotaComponents: [any Component] = []

            for item in visibleItems {
                switch item {
                case .sectionHeader(let title):
                    quotaComponents.append(Text(title).accent().bold())

                case .quotaBar(let used, let limit, let label):
                    // Create usage bar component inline
                    let percentage = limit > 0 ? min(100, max(0, (used * 100) / limit)) : 0
                    let barWidth = 15
                    let filledWidth = max(0, min(barWidth, (percentage * barWidth) / 100))

                    let filledPortion = String(repeating: "#", count: filledWidth)
                    let emptyPortion = String(repeating: "-", count: max(0, barWidth - filledWidth))
                    let valueText = String(format: " %d/%d (%d%%)", used, limit, percentage)

                    let barStyle: TextStyle = percentage > 90 ? .error : (percentage > 75 ? .warning : .success)

                    let barComponent = HStack(spacing: 0, children: [
                        Text("  \(label): ").secondary(),
                        Text(filledPortion).styled(barStyle),
                        Text(emptyPortion).secondary(),
                        Text(valueText).secondary()
                    ])
                    quotaComponents.append(barComponent)

                case .spacer:
                    quotaComponents.append(Text(""))
                }
            }

            return VStack(spacing: 0, children: quotaComponents)
        }()

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: 16)
        let panel = BorderedContainer(title: "Project Quotas") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: 14))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    // Enum to represent different quota item types
    enum QuotaItem {
        case sectionHeader(String)
        case quotaBar(used: Int, limit: Int, label: String)
        case spacer
    }

    @MainActor
    private static func drawNetworkStatusPanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                             width: Int32, cachedNetworks: [Network]) async {
        let content: any Component = {
            let maxRows = 6  // Adjust for border space
            let totalNetworks = cachedNetworks.count

            if totalNetworks == 0 {
                return Text("No networks found").warning()
            } else {
                let displayNetworks = totalNetworks <= maxRows ? cachedNetworks : Array(cachedNetworks[0..<maxRows])
                var components: [any Component] = []

                for network in displayNetworks {
                    let status = network.adminStateUp == true ? "active" : "error"
                    let statusIcon = StatusIcon(status: status)
                    let nameWidth = Int(width) - 12
                    let truncatedName = String((network.name ?? "Unknown").prefix(nameWidth))
                    let externalLabel = network.external == true ? " [EXT]" : ""
                    let nameText = Text("\(truncatedName)\(externalLabel)")

                    let row = HStack(spacing: 1, children: [statusIcon, nameText])
                    components.append(row)
                }

                if totalNetworks > maxRows {
                    components.append(Text("... and \(totalNetworks - maxRows) more").warning())
                }

                return VStack(spacing: 0, children: components)
            }
        }()

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: 16)
        let panel = BorderedContainer(title: "Network Status") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: 14))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    @MainActor
    private static func drawVolumeStatusPanel(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                            width: Int32, cachedVolumes: [Volume]) async {
        let content: any Component = {
            let maxRows = 6  // Adjust for border space
            let totalVolumes = cachedVolumes.count

            if totalVolumes == 0 {
                return Text("No volumes found").warning()
            } else {
                let displayVolumes = totalVolumes <= maxRows ? cachedVolumes : Array(cachedVolumes[0..<maxRows])
                var components: [any Component] = []

                for volume in displayVolumes {
                    let statusIcon = StatusIcon(status: volume.status)
                    let nameWidth = Int(width) - 18
                    let volumeName = volume.name ?? "Unnamed Volume"
                    let truncatedName = String(volumeName.prefix(nameWidth))
                    let sizeLabel = volume.size != nil ? " \(volume.size!)GB" : ""
                    let attachLabel = !(volume.attachments?.isEmpty ?? true) ? " [ATT]" : ""
                    let nameText = Text("\(truncatedName)\(sizeLabel)\(attachLabel)")

                    let row = HStack(spacing: 1, children: [statusIcon, nameText])
                    components.append(row)
                }

                if totalVolumes > maxRows {
                    components.append(Text("... and \(totalVolumes - maxRows) more").warning())
                }

                // Add summary line
                if !cachedVolumes.isEmpty {
                    let summaryText: String
                    if totalVolumes > 500 {
                        let (totalSize, attachedCount, availableCount) = calculateVolumeSummary(displayVolumes)
                        summaryText = "Sample: \(totalSize)GB, Att: \(attachedCount), Free: \(availableCount) (of \(maxRows))"
                    } else {
                        let (totalSize, attachedCount, availableCount) = calculateVolumeSummary(cachedVolumes)
                        summaryText = "Total: \(totalSize)GB, Attached: \(attachedCount), Free: \(availableCount)"
                    }
                    components.append(Text(summaryText).warning())
                }

                return VStack(spacing: 0, children: components)
            }
        }()

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: 12)
        let panel = BorderedContainer(title: "Volume Status") {
            await SwiftTUI.render(content, on: surface, in: Rect(x: startCol + 1, y: startRow + 1, width: width - 2, height: 10))
        }
        await SwiftTUI.render(panel, on: surface, in: bounds)
    }

    private static func calculateVolumeSummary(_ volumes: [Volume]) -> (totalSize: Int, attachedCount: Int, availableCount: Int) {
        var totalSize = 0
        var attachedCount = 0
        var availableCount = 0

        for volume in volumes {
            totalSize += volume.size ?? 0
            if !(volume.attachments?.isEmpty ?? true) {
                attachedCount += 1
            }
            if volume.status?.lowercased() == "available" {
                availableCount += 1
            }
        }

        return (totalSize, attachedCount, availableCount)
    }

    // MARK: - Layout Functions

    @MainActor
    private static func drawGridDashboard(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                         width: Int32, height: Int32, resourceCounts: ResourceCounts,
                                         cachedServers: [Server], cachedNetworks: [Network],
                                         cachedVolumes: [Volume], cachedPorts: [Port], cachedRouters: [Router],
                                         cachedComputeLimits: ComputeLimits?, cachedNetworkQuotas: NetworkQuotas?,
                                         cachedVolumeQuotas: VolumeQuotas?, quotaScrollOffset: Int) async {

        // Calculate panel dimensions for 3x2 grid layout
        let topPanelWidth = width / 3 - 4
        let bottomPanelWidth = width / 3 - 4
        let panelHeight = height / 2 - 4

        // Top row - 3 panels (Live Status, Resources, Routers)
        await drawLiveStatusPanel(screen: screen, startRow: startRow + 1, startCol: startCol + 2,
                                width: topPanelWidth, height: panelHeight, cachedServers: cachedServers)

        await drawResourcesPanel(screen: screen, startRow: startRow + 1,
                               startCol: startCol + topPanelWidth + 6, width: topPanelWidth, height: panelHeight,
                               resourceCounts: resourceCounts)

        await drawRoutersPanel(screen: screen, startRow: startRow + 1,
                              startCol: startCol + (topPanelWidth + 6) * 2, width: topPanelWidth, height: panelHeight,
                              cachedRouters: cachedRouters, cachedNetworks: cachedNetworks)

        // Yield before expensive quota calculations for large datasets
        if cachedVolumes.count > 100 || cachedNetworks.count > 50 || cachedPorts.count > 100 {
            await Task.yield()
        }

        // Bottom row - 3 panels (Storage, Network, Quotas)
        let bottomRowStartRow = startRow + panelHeight + 2

        await drawStoragePanel(screen: screen, startRow: bottomRowStartRow, startCol: startCol + 2,
                              width: bottomPanelWidth, height: panelHeight, cachedVolumes: cachedVolumes)

        await drawNetworkPanel(screen: screen, startRow: bottomRowStartRow,
                              startCol: startCol + bottomPanelWidth + 6, width: bottomPanelWidth, height: panelHeight,
                              cachedNetworks: cachedNetworks, cachedServers: cachedServers)

        await drawQuotasPanel(screen: screen, startRow: bottomRowStartRow,
                             startCol: startCol + (bottomPanelWidth + 6) * 2, width: bottomPanelWidth, height: panelHeight,
                             cachedServers: cachedServers, cachedVolumes: cachedVolumes, cachedNetworks: cachedNetworks,
                             cachedPorts: cachedPorts, cachedRouters: cachedRouters,
                             cachedComputeLimits: cachedComputeLimits,
                             cachedNetworkQuotas: cachedNetworkQuotas,
                             cachedVolumeQuotas: cachedVolumeQuotas, quotaScrollOffset: quotaScrollOffset)
    }

    @MainActor
    private static func drawVerticalDashboard(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                             width: Int32, height: Int32, resourceCounts: ResourceCounts,
                                             cachedServers: [Server], cachedNetworks: [Network],
                                             cachedVolumes: [Volume], cachedPorts: [Port], cachedRouters: [Router],
                                             cachedComputeLimits: ComputeLimits?, cachedNetworkQuotas: NetworkQuotas?,
                                             cachedVolumeQuotas: VolumeQuotas?, quotaScrollOffset: Int) async {

        // Vertical layout with scrolling support
        let panelWidth = width - 4  // Full width minus margins
        let panelHeight = min(height / 6, Int32(12))  // Smaller panels for vertical layout
        let panelSpacing = Int32(1)  // Space between panels

        // Calculate total content height
        let totalPanels = 6
        let totalContentHeight = Int32(totalPanels) * (panelHeight + panelSpacing) + 2
        let availableHeight = height - 4  // Subtract header/footer space

        // Calculate scroll-adjusted positions
        let scrollOffset = quotaScrollOffset
        var currentRow = startRow + 1 - Int32(scrollOffset)

        // Panel order for vertical layout: Live Status, Resources, Routers, Storage, Network, Quotas

        // Live Status Panel
        if currentRow + panelHeight > startRow && currentRow < startRow + availableHeight {
            await drawLiveStatusPanel(screen: screen, startRow: max(currentRow, startRow + 1),
                                    startCol: startCol + 2, width: panelWidth, height: panelHeight,
                                    cachedServers: cachedServers)
        }
        currentRow += panelHeight + panelSpacing

        // Resources Panel
        if currentRow + panelHeight > startRow && currentRow < startRow + availableHeight {
            await drawResourcesPanel(screen: screen, startRow: max(currentRow, startRow + 1),
                                   startCol: startCol + 2, width: panelWidth, height: panelHeight,
                                   resourceCounts: resourceCounts)
        }
        currentRow += panelHeight + panelSpacing

        // Routers Panel
        if currentRow + panelHeight > startRow && currentRow < startRow + availableHeight {
            await drawRoutersPanel(screen: screen, startRow: max(currentRow, startRow + 1),
                                  startCol: startCol + 2, width: panelWidth, height: panelHeight,
                                  cachedRouters: cachedRouters, cachedNetworks: cachedNetworks)
        }
        currentRow += panelHeight + panelSpacing

        // Storage Panel
        if currentRow + panelHeight > startRow && currentRow < startRow + availableHeight {
            await drawStoragePanel(screen: screen, startRow: max(currentRow, startRow + 1),
                                  startCol: startCol + 2, width: panelWidth, height: panelHeight,
                                  cachedVolumes: cachedVolumes)
        }
        currentRow += panelHeight + panelSpacing

        // Network Panel
        if currentRow + panelHeight > startRow && currentRow < startRow + availableHeight {
            await drawNetworkPanel(screen: screen, startRow: max(currentRow, startRow + 1),
                                  startCol: startCol + 2, width: panelWidth, height: panelHeight,
                                  cachedNetworks: cachedNetworks, cachedServers: cachedServers)
        }
        currentRow += panelHeight + panelSpacing

        // Quotas Panel
        if currentRow + panelHeight > startRow && currentRow < startRow + availableHeight {
            await drawQuotasPanel(screen: screen, startRow: max(currentRow, startRow + 1),
                                 startCol: startCol + 2, width: panelWidth, height: panelHeight,
                                 cachedServers: cachedServers, cachedVolumes: cachedVolumes, cachedNetworks: cachedNetworks,
                                 cachedPorts: cachedPorts, cachedRouters: cachedRouters,
                                 cachedComputeLimits: cachedComputeLimits,
                                 cachedNetworkQuotas: cachedNetworkQuotas,
                                 cachedVolumeQuotas: cachedVolumeQuotas, quotaScrollOffset: 0) // Use 0 for panel-specific scrolling
        }

        // Show scroll indicator if content is larger than available space
        if totalContentHeight > availableHeight {
            let scrollIndicatorRow = startRow + availableHeight - 1
            let scrollProgress = Float(scrollOffset) / Float(max(1, totalContentHeight - availableHeight))
            let scrollText = "Scroll: \(Int(scrollProgress * 100))% (UP/DOWN to navigate)"

            let surface = SwiftTUI.surface(from: screen)
            let bounds = Rect(x: startCol + 2, y: scrollIndicatorRow, width: width - 4, height: 1)
            await SwiftTUI.render(Text(scrollText).info(), on: surface, in: bounds)
        }
    }
}