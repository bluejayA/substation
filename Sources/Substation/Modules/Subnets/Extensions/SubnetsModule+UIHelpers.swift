// Sources/Substation/Modules/Subnets/Extensions/SubnetsModule+UIHelpers.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Subnet UI Helper Operations

extension SubnetsModule {
    /// Perform subnet router management (attach/detach router interface)
    ///
    /// This function handles the attachment or detachment of a router interface
    /// to/from a subnet. It validates the current selection state and performs
    /// the appropriate Neutron API call based on the attachment mode.
    ///
    /// The function:
    /// - Validates that a router and subnet are selected
    /// - Checks if the router is already attached/detached
    /// - Validates subnet and router compatibility for attachments
    /// - Calls the Neutron API to add or remove router interface
    /// - Updates the UI state and refreshes data on success
    /// - Logs errors with detailed context for debugging
    ///
    /// Router interface operations allow subnets to be connected to routers,
    /// enabling routing between different networks and external connectivity.
    ///
    /// - Important: This function expects both selectedRouterId and selectedResource
    ///   to be set before being called.
    internal func performSubnetRouterManagement() async {
        guard let tui = tui else { return }

        guard let selectedId = tui.selectionManager.selectedRouterId else {
            tui.statusMessage = "No router selected for subnet \(tui.selectionManager.attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }
        guard let selectedSubnet = tui.viewCoordinator.selectedResource as? Subnet else {
            tui.statusMessage = "No subnet selected for \(tui.selectionManager.attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }
        guard let selectedRouter = tui.cacheManager.cachedRouters.first(where: { $0.id == selectedId }) else {
            tui.statusMessage = "Selected router not found"
            return
        }

        let routerName = selectedRouter.name ?? "Unknown"
        let subnetName = selectedSubnet.name ?? "Unknown"
        let action = tui.selectionManager.attachmentMode == .attach ? "attaching" : "detaching"
        tui.statusMessage = "\(action.capitalized) router '\(routerName)' \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") subnet '\(subnetName)'..."

        // Force immediate UI update to show status message
        tui.forceRedraw()

        do {
            // Validate before attempting operation
            let isCurrentlyAttached = tui.selectionManager.attachedRouterIds.contains(selectedRouter.id)

            if tui.selectionManager.attachmentMode == .attach {
                if isCurrentlyAttached {
                    tui.statusMessage = "Router '\(routerName)' is already attached to subnet '\(subnetName)'"
                    return
                }

                // Validate subnet and router compatibility
                if let network = tui.cacheManager.cachedNetworks.first(where: { $0.id == selectedSubnet.networkId }) {
                    // Check if router is already on the same network via external gateway
                    if let routerNetwork = selectedRouter.externalGatewayInfo?.networkId, routerNetwork == network.id {
                        // This is acceptable - router can have both external gateway and internal interfaces on same network
                    }
                }

                // Add router interface
                _ = try await tui.client.neutron.addRouterInterface(routerId: selectedRouter.id, subnetId: selectedSubnet.id)
                tui.statusMessage = "Successfully attached router '\(routerName)' to subnet '\(subnetName)'"
            } else {
                if !isCurrentlyAttached {
                    tui.statusMessage = "Router '\(routerName)' is not attached to subnet '\(subnetName)'"
                    return
                }

                // Remove router interface
                _ = try await tui.client.neutron.removeRouterInterface(routerId: selectedRouter.id, subnetId: selectedSubnet.id)
                tui.statusMessage = "Successfully detached router '\(routerName)' from subnet '\(subnetName)'"
            }

            tui.selectionManager.selectedRouterId = nil
            tui.changeView(to: .subnets, resetSelection: false)
            tui.refreshAfterOperation()
        } catch {
            let errorMsg = error.localizedDescription
            let specificError = if errorMsg.contains("400") {
                "Bad Request: \(errorMsg)"
            } else if errorMsg.contains("404") {
                "Not Found: Router or subnet not found"
            } else if errorMsg.contains("409") {
                "Conflict: \(errorMsg)"
            } else {
                errorMsg
            }

            tui.statusMessage = "Failed to \(tui.selectionManager.attachmentMode == .attach ? "attach" : "detach") router: \(specificError)"
            Logger.shared.logError("Failed to \(tui.selectionManager.attachmentMode == .attach ? "attach" : "detach") router", error: error, context: [
                "routerId": selectedRouter.id,
                "routerName": routerName,
                "subnetId": selectedSubnet.id,
                "subnetName": subnetName,
                "subnetNetworkId": selectedSubnet.networkId,
                "routerExternalGateway": selectedRouter.externalGatewayInfo?.networkId ?? "none",
                "currentlyAttached": tui.selectionManager.attachedRouterIds.contains(selectedRouter.id)
            ])
        }
    }
}
