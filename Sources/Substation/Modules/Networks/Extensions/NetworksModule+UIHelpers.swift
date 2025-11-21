// Sources/Substation/Modules/Networks/Extensions/NetworksModule+UIHelpers.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Network UI Helper Operations

extension NetworksModule {
    /// Perform batch network attachment to multiple selected servers
    ///
    /// This method attaches the currently selected network to all servers in
    /// the selection set. It uses the BatchOperationManager for coordinated
    /// execution with progress tracking.
    ///
    /// The operation flow:
    /// 1. Validates server and network selection
    /// 2. Creates NetworkInterfaceOperation for each selected server
    /// 3. Executes batch attachment with progress callback
    /// 4. Reports results and clears selections
    ///
    /// Status messages are updated throughout the operation to provide feedback.
    ///
    /// - Note: Requires at least one server to be selected and a network resource
    ///         to be set as the selectedResource
    internal func performBatchNetworkAttachment() async {
        guard let tui = tui else { return }

        guard !tui.selectionManager.selectedServers.isEmpty else {
            tui.statusMessage = "No servers selected for network attachment"
            return
        }

        guard let selectedNetwork = tui.viewCoordinator.selectedResource as? Network else {
            tui.statusMessage = "No network selected for attachment"
            return
        }

        let networkName = selectedNetwork.name ?? "Unknown"
        let serverCount = tui.selectionManager.selectedServers.count

        // Create network interface operations for each selected server
        let operations = Array(tui.selectionManager.selectedServers).map { serverId in
            NetworkInterfaceOperation(
                serverID: serverId,
                networkID: selectedNetwork.id,
                portID: nil,
                fixedIPs: []
            )
        }

        tui.statusMessage = "Starting batch attachment of network '\(networkName)' to \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        // Execute the batch operation
        let batchOperation = BatchOperationType.networkInterfaceBulkAttach(operations: operations)

        let result = await tui.batchOperationManager.execute(batchOperation) { @Sendable progress in
            Task { @MainActor in
                let percentage = Int(progress.completionPercentage * 100)
                tui.statusMessage = "Attaching network: \(progress.currentOperation)/\(progress.totalOperations) (\(percentage)%)"
            }
        }

        // Update status message with results
        switch result.status {
        case .completed:
            if result.failedOperations == 0 {
                tui.statusMessage = "Successfully attached network '\(networkName)' to \(result.successfulOperations) server\(result.successfulOperations == 1 ? "" : "s")"
            } else {
                tui.statusMessage = "Attached network to \(result.successfulOperations) server\(result.successfulOperations == 1 ? "" : "s"), \(result.failedOperations) failed. Check logs for details."
            }
        case .failed:
            tui.statusMessage = "Failed to attach network to servers. See logs for details."
        case .cancelled:
            tui.statusMessage = "Network attachment operation was cancelled"
        case .executing, .planning, .validating:
            tui.statusMessage = "Network attachment operation in progress..."
        case .pending:
            tui.statusMessage = "Network attachment operation pending..."
        case .rollingBack:
            tui.statusMessage = "Rolling back network attachment operation..."
        case .rolledBack:
            tui.statusMessage = "Network attachment operation rolled back"
        }

        // Clear selections and return to networks view
        tui.selectionManager.selectedServers.removeAll()
        tui.changeView(to: .networks, resetSelection: false)

        // Refresh server data to show updated network attachments
        tui.refreshAfterOperation()
    }

    /// Perform enhanced network management for connect/disconnect operations
    ///
    /// This method handles both attaching (connecting) and detaching (disconnecting)
    /// networks from servers based on the current attachment mode. It processes
    /// each selected server individually with proper error handling.
    ///
    /// For attach operations:
    /// - Creates a new port for each server on the selected network
    /// - Attaches the port to the server
    ///
    /// For detach operations:
    /// - Finds the port connecting the server to the network
    /// - Deletes the port to disconnect the server
    ///
    /// - Note: Requires at least one server to be selected and a network resource
    ///         to be set as the selectedResource
    internal func performEnhancedNetworkManagement() async {
        guard let tui = tui else { return }

        guard !tui.selectionManager.selectedServers.isEmpty else {
            tui.statusMessage = "No servers selected for network \(tui.selectionManager.attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }

        guard let selectedNetwork = tui.viewCoordinator.selectedResource as? Network else {
            tui.statusMessage = "No network selected for \(tui.selectionManager.attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }

        let networkName = selectedNetwork.name ?? "Unknown"
        let serverCount = tui.selectionManager.selectedServers.count
        let action = tui.selectionManager.attachmentMode == .attach ? "connecting" : "disconnecting"
        tui.statusMessage = "\(action.capitalized) network '\(networkName)' \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        // Force immediate UI update to show status message
        tui.forceRedraw()

        var successCount = 0
        var errorCount = 0

        for serverId in tui.selectionManager.selectedServers {
            guard let server = tui.cacheManager.cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                continue
            }

            do {
                if tui.selectionManager.attachmentMode == .attach {
                    let port = try await tui.client.createPort(
                        name: "server-\(serverId)-network-\(selectedNetwork.id)",
                        description: "Auto-created port for enhanced management",
                        networkID: selectedNetwork.id,
                        subnetID: nil,
                        securityGroups: nil,
                        qosPolicyID: nil
                    )
                    try await tui.client.attachPort(serverID: serverId, portID: port.id)
                } else {
                    // Find and delete the port connecting this server to the network
                    let ports = try await tui.client.listPorts()
                    if let port = ports.first(where: { $0.deviceId == serverId && $0.networkId == selectedNetwork.id }) {
                        try await tui.client.deletePort(id: port.id)
                    }
                }
                successCount += 1
            } catch {
                errorCount += 1
                Logger.shared.logError("Failed to \(tui.selectionManager.attachmentMode == .attach ? "attach" : "detach") network", error: error, context: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "networkId": selectedNetwork.id,
                    "networkName": networkName
                ])
            }
        }

        if errorCount == 0 {
            tui.statusMessage = "Successfully \(tui.selectionManager.attachmentMode == .attach ? "connected" : "disconnected") network '\(networkName)' \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            tui.statusMessage = "Failed to \(tui.selectionManager.attachmentMode == .attach ? "connect" : "disconnect") network \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") any servers"
        } else {
            tui.statusMessage = "\(tui.selectionManager.attachmentMode == .attach ? "Connected" : "Disconnected") network \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed"
        }

        tui.selectionManager.selectedServers.removeAll()
        tui.changeView(to: .networks, resetSelection: false)
        tui.refreshAfterOperation()
    }
}
