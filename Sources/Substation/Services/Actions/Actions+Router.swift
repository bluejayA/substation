import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftTUI
import MemoryKit

// MARK: - Router Actions

@MainActor
extension Actions {

    internal func manageSubnetRouterAttachment(screen: OpaquePointer?) async {
        guard currentView == .subnets else { return }

        let filteredSubnets = FilterUtils.filterSubnets(cachedSubnets, query: searchQuery)
        guard selectedIndex < filteredSubnets.count else {
            statusMessage = "No subnet selected"
            return
        }

        let subnet = filteredSubnets[selectedIndex]
        let subnetName = subnet.name ?? "Unnamed Subnet"

        // Switch to subnet router management view
        selectedResource = subnet
        attachmentMode = .attach

        // Load attached routers for filtering
        await loadAttachedRoutersForSubnet(subnet)

        tui.changeView(to: .subnetRouterManagement, resetSelection: false)
        statusMessage = "Select a router to attach subnet '\(subnetName)'"
    }

    internal func loadAttachedRoutersForSubnet(_ subnet: Subnet) async {
        attachedRouterIds.removeAll()

        Logger.shared.logInfo("=== Loading attached routers for subnet \(subnet.name ?? subnet.id) (\(subnet.id)) ===")
        Logger.shared.logInfo("Available routers: \(cachedRouters.count)")

        // Use cached router interface data to find attachments
        for router in cachedRouters {
            if let interfaces = router.interfaces {
                Logger.shared.logInfo("Router \(router.name ?? router.id) has \(interfaces.count) cached interfaces")

                for interface in interfaces {
                    if interface.subnetId == subnet.id {
                        attachedRouterIds.insert(router.id)
                        Logger.shared.logInfo("Found router \(router.name ?? router.id) attached to subnet \(subnet.name ?? subnet.id) via cached interface data")
                        break
                    }
                }
            } else {
                Logger.shared.logInfo("Router \(router.name ?? router.id) has no cached interface data")
            }
        }

        Logger.shared.logInfo("=== Final result: Subnet \(subnet.name ?? subnet.id) has \(attachedRouterIds.count) attached routers: \(Array(attachedRouterIds)) ===")
    }
}
