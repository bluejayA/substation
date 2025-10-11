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

// MARK: - Allowed Address Pair Actions

@MainActor
extension Actions {

    // MARK: - Open Management View

    internal func managePortAllowedAddressPairs(screen: OpaquePointer?) async {
        guard currentView == .ports else { return }

        let filteredPorts = FilterUtils.filterPorts(cachedPorts, query: searchQuery)
        guard selectedIndex < filteredPorts.count else {
            statusMessage = "No port selected"
            return
        }

        let sourcePort = filteredPorts[selectedIndex]
        let portName = sourcePort.name ?? sourcePort.id
        let portIP = sourcePort.fixedIps?.first?.ipAddress ?? "N/A"

        // Populate resource name cache synchronously for display
        for server in cachedServers {
            if let serverName = server.name {
                tui.resourceNameCache.setServerName(server.id, name: serverName)
            }
        }
        for network in cachedNetworks {
            if let networkName = network.name {
                tui.resourceNameCache.setNetworkName(network.id, name: networkName)
            }
        }

        // Initialize the form with the source port and all available target ports
        tui.allowedAddressPairForm = AllowedAddressPairManagementForm(
            sourcePort: sourcePort,
            availablePorts: cachedPorts
        )

        // Switch to the management view
        tui.changeView(to: .portAllowedAddressPairManagement, resetSelection: false)
        statusMessage = "Add port '\(portName)' (\(portIP)) as allowed address pair to other ports"

        Logger.shared.logUserAction("manage_port_allowed_address_pairs", details: [
            "sourcePortId": sourcePort.id,
            "sourcePortName": portName,
            "sourcePortIP": portIP
        ])
    }

    // MARK: - Apply Allowed Address Pair Changes

    internal func applyAllowedAddressPairChanges(screen: OpaquePointer?) async {
        guard currentView == .portAllowedAddressPairManagement else { return }
        guard let form = tui.allowedAddressPairForm else { return }
        guard form.mode == .selectPorts else { return }

        guard form.hasPendingChanges() else {
            statusMessage = "No changes pending"
            return
        }

        let sourcePortIP = form.getSourcePortIPAddress()
        let portsToAdd = form.getTargetPortsToAdd()
        let portsToRemove = form.getTargetPortsToRemove()

        Logger.shared.logInfo("Applying allowed address pair changes", context: [
            "sourcePortId": form.sourcePort.id,
            "sourcePortIP": sourcePortIP,
            "portsToAddCount": portsToAdd.count,
            "portsToRemoveCount": portsToRemove.count
        ])

        var changeSummary: [String] = []
        if portsToAdd.count > 0 {
            changeSummary.append("adding to \(portsToAdd.count) port(s)")
        }
        if portsToRemove.count > 0 {
            changeSummary.append("removing from \(portsToRemove.count) port(s)")
        }
        statusMessage = "Applying changes: \(changeSummary.joined(separator: ", "))..."

        var successCount = 0
        var failureCount = 0

        // Add source port to target ports
        for targetPort in portsToAdd {
            do {
                let updatedPairs = form.getAllowedAddressPairsForPort(targetPort.id, adding: true)
                let request = UpdatePortRequest(allowedAddressPairs: updatedPairs)
                let updatedPort = try await client.neutron.updatePort(id: targetPort.id, request: request)

                // Update cached port
                if let index = cachedPorts.firstIndex(where: { $0.id == updatedPort.id }) {
                    cachedPorts[index] = updatedPort
                }
                successCount += 1
            } catch {
                Logger.shared.logError("Failed to add allowed address pair to port", context: [
                    "targetPortId": targetPort.id,
                    "error": error.localizedDescription
                ])
                failureCount += 1
            }
        }

        // Remove source port from target ports
        for targetPort in portsToRemove {
            do {
                let updatedPairs = form.getAllowedAddressPairsForPort(targetPort.id, adding: false)
                let request = UpdatePortRequest(allowedAddressPairs: updatedPairs)
                let updatedPort = try await client.neutron.updatePort(id: targetPort.id, request: request)

                // Update cached port
                if let index = cachedPorts.firstIndex(where: { $0.id == updatedPort.id }) {
                    cachedPorts[index] = updatedPort
                }
                successCount += 1
            } catch {
                Logger.shared.logError("Failed to remove allowed address pair from port", context: [
                    "targetPortId": targetPort.id,
                    "error": error.localizedDescription
                ])
                failureCount += 1
            }
        }

        if failureCount == 0 {
            statusMessage = "Successfully updated \(successCount) port(s) with allowed address pair '\(sourcePortIP)'"
        } else {
            statusMessage = "Updated \(successCount) port(s), failed \(failureCount) port(s)"
        }

        Logger.shared.logInfo("Completed allowed address pair changes", context: [
            "sourcePortId": form.sourcePort.id,
            "successCount": successCount,
            "failureCount": failureCount
        ])

        // Return to ports list
        tui.changeView(to: .ports, resetSelection: false)
    }

}
