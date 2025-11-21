import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

/// Service layer for resource count operations
///
/// This service provides utility functions that are used across the application.
/// Most resource operations have been moved to their respective module Action files.
@MainActor
final class ResourceOperations {
    private let tui: TUI

    init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Resource Count Operations

    /// Update resource counts for dashboard display
    ///
    /// This function updates the resource counts used by the dashboard and other views.
    /// For large datasets (>500 servers), it uses estimates to prevent performance issues.
    internal func updateResourceCounts() {
        let startTime = Date().timeIntervalSinceReferenceDate

        // Update basic counts (fast operations)
        tui.resourceCounts.servers = tui.cacheManager.cachedServers.count
        tui.resourceCounts.serverGroups = tui.cacheManager.cachedServerGroups.count
        tui.resourceCounts.networks = tui.cacheManager.cachedNetworks.count
        tui.resourceCounts.securityGroups = tui.cacheManager.cachedSecurityGroups.count
        tui.resourceCounts.volumes = tui.cacheManager.cachedVolumes.count
        tui.resourceCounts.images = tui.cacheManager.cachedImages.count
        tui.resourceCounts.keyPairs = tui.cacheManager.cachedKeyPairs.count
        tui.resourceCounts.ports = tui.cacheManager.cachedPorts.count
        tui.resourceCounts.routers = tui.cacheManager.cachedRouters.count
        tui.resourceCounts.subnets = tui.cacheManager.cachedSubnets.count

        // For very large datasets, skip detailed server status counting to prevent hangs
        let serverCount = tui.cacheManager.cachedServers.count
        if serverCount > 500 {
            // Use estimates for large datasets to prevent performance issues
            tui.resourceCounts.activeServers = Int(Double(serverCount) * 0.8) // Assume 80% active
            tui.resourceCounts.errorServers = Int(Double(serverCount) * 0.05) // Assume 5% errors

            Logger.shared.logDebug("Using estimated server counts for \(serverCount) servers (performance optimization)")
        } else {
            // For smaller datasets, do actual counting
            var activeCount = 0
            var errorCount = 0

            for server in tui.cacheManager.cachedServers {
                if let status = server.status?.lowercased() {
                    if status == "active" {
                        activeCount += 1
                    } else if status.contains("error") || status.contains("fault") {
                        errorCount += 1
                    }
                }
            }

            tui.resourceCounts.activeServers = activeCount
            tui.resourceCounts.errorServers = errorCount
        }

        let endTime = Date().timeIntervalSinceReferenceDate
        let duration = (endTime - startTime) * 1000 // Convert to milliseconds

        if duration > 10 { // Log if resource counting takes more than 10ms
            Logger.shared.logDebug("updateResourceCounts() took \(String(format: "%.1f", duration))ms for \(serverCount) servers")
        }
    }
}
