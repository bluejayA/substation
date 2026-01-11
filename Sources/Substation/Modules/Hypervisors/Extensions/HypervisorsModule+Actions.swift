// Sources/Substation/Modules/Hypervisors/Extensions/HypervisorsModule+Actions.swift
import Foundation
import OSClient
import SwiftNCurses

/// Action provider implementation for Hypervisors module
extension HypervisorsModule: ActionProvider {

    // MARK: - ActionProvider Protocol

    /// Actions available in list view
    var listViewActions: [ActionType] {
        return [.refresh, .clearCache]
    }

    /// Actions available in detail view
    var detailViewActions: [ActionType] {
        return [.refresh, .clearCache]
    }

    /// Create view mode (not applicable for hypervisors)
    var createViewMode: ViewMode? {
        return nil
    }

    /// Execute an action
    ///
    /// - Parameters:
    ///   - action: Action type to execute
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    /// - Returns: True if action was handled
    func executeAction(_ action: ActionType, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch action {
        case .refresh:
            tui.statusMessage = "Refreshing hypervisors..."
            do {
                try await refresh()
                tui.statusMessage = "Hypervisors refreshed"
            } catch {
                tui.statusMessage = "Failed to refresh: \(error.localizedDescription)"
            }
            return true

        case .clearCache:
            tui.cacheManager.cachedHypervisors = []
            tui.statusMessage = "Hypervisor cache cleared"
            return true

        default:
            return false
        }
    }

    /// Get selected resource ID
    ///
    /// - Parameter tui: TUI instance
    /// - Returns: ID of selected hypervisor
    func getSelectedResourceId(tui: TUI) -> String {
        let hypervisors = tui.cacheManager.cachedHypervisors
        let filteredHypervisors = FilterUtils.filterHypervisors(
            hypervisors,
            query: tui.searchQuery
        )

        guard tui.viewCoordinator.selectedIndex < filteredHypervisors.count else {
            return ""
        }

        return filteredHypervisors[tui.viewCoordinator.selectedIndex].id
    }

    // MARK: - Hypervisor Actions

    /// Enable a hypervisor with confirmation prompt
    ///
    /// Prompts the user for confirmation before enabling the hypervisor's
    /// compute service, allowing it to receive new instance scheduling requests.
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    func enableHypervisor(screen: OpaquePointer?, tui: TUI) async {
        guard let hypervisor = tui.viewCoordinator.selectedResource as? Hypervisor,
              let hostname = hypervisor.hypervisorHostname else {
            tui.statusMessage = "No hypervisor selected"
            return
        }

        // Check if already enabled
        if hypervisor.status?.lowercased() == "enabled" {
            tui.statusMessage = "Hypervisor '\(hostname)' is already enabled"
            return
        }

        // Build hypervisor details for confirmation
        var details: [String] = []
        details.append("Hostname: \(hostname)")
        if let state = hypervisor.state {
            details.append("State: \(state.uppercased())")
        }
        if let status = hypervisor.status {
            details.append("Current Status: \(status.capitalized)")
        }
        if let runningVms = hypervisor.runningVms {
            details.append("Running VMs: \(runningVms)")
        }

        // Show confirmation using ViewUtils (same as delete confirmations)
        guard await ViewUtils.confirmOperation(
            title: "Confirm Enable Hypervisor",
            message: "Enable the following hypervisor?",
            details: details,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Enable cancelled"
            await tui.draw(screen: screen)
            return
        }

        tui.statusMessage = "Enabling hypervisor '\(hostname)'..."
        await tui.draw(screen: screen)

        do {
            try await tui.client.nova.enableComputeService(host: hostname)
            tui.statusMessage = "Hypervisor '\(hostname)' enabled"

            // Refresh hypervisor data
            try await refresh()

            // Update selected resource if still viewing detail
            if let updatedHypervisor = tui.cacheManager.cachedHypervisors.first(where: { $0.id == hypervisor.id }) {
                tui.viewCoordinator.selectedResource = updatedHypervisor
            }
        } catch {
            tui.statusMessage = "Failed to enable hypervisor: \(error.localizedDescription)"
        }
    }

    /// Disable a hypervisor (simple version without prompt)
    ///
    /// Disables the hypervisor's compute service, preventing new instances
    /// from being scheduled on it. Existing instances continue to run.
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    func disableHypervisor(screen: OpaquePointer?, tui: TUI) async {
        guard let hypervisor = tui.viewCoordinator.selectedResource as? Hypervisor,
              let hostname = hypervisor.hypervisorHostname else {
            tui.statusMessage = "No hypervisor selected"
            return
        }

        // Check if already disabled
        if hypervisor.status?.lowercased() == "disabled" {
            tui.statusMessage = "Hypervisor '\(hostname)' is already disabled"
            return
        }

        tui.statusMessage = "Disabling hypervisor '\(hostname)'..."

        do {
            try await tui.client.nova.disableComputeService(
                host: hostname,
                reason: "Disabled via Substation TUI"
            )
            tui.statusMessage = "Hypervisor '\(hostname)' disabled"

            // Refresh hypervisor data
            try await refresh()

            // Update selected resource if still viewing detail
            if let updatedHypervisor = tui.cacheManager.cachedHypervisors.first(where: { $0.id == hypervisor.id }) {
                tui.viewCoordinator.selectedResource = updatedHypervisor
            }
        } catch {
            tui.statusMessage = "Failed to disable hypervisor: \(error.localizedDescription)"
        }
    }

    /// Disable a hypervisor with reason prompt
    ///
    /// Prompts the user for a reason before disabling the hypervisor's
    /// compute service. Uses the same confirmation dialog as delete operations.
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    func disableHypervisorWithPrompt(screen: OpaquePointer?, tui: TUI) async {
        guard let hypervisor = tui.viewCoordinator.selectedResource as? Hypervisor,
              let hostname = hypervisor.hypervisorHostname else {
            tui.statusMessage = "No hypervisor selected"
            return
        }

        // Check if already disabled
        if hypervisor.status?.lowercased() == "disabled" {
            tui.statusMessage = "Hypervisor '\(hostname)' is already disabled"
            return
        }

        // Prompt for reason using ViewUtils
        guard let disableReason = ViewUtils.prompt(
            "Reason for disabling '\(hostname)': ",
            screen: screen,
            screenRows: tui.screenRows
        ), !disableReason.isEmpty else {
            tui.statusMessage = "Disable cancelled (no reason provided)"
            await tui.draw(screen: screen)
            return
        }

        // Build hypervisor details for confirmation
        var details: [String] = []
        details.append("Hostname: \(hostname)")
        if let state = hypervisor.state {
            details.append("State: \(state.uppercased())")
        }
        if let status = hypervisor.status {
            details.append("Current Status: \(status.capitalized)")
        }
        if let runningVms = hypervisor.runningVms {
            details.append("Running VMs: \(runningVms)")
        }
        details.append("Reason: \(disableReason)")

        // Show confirmation using ViewUtils (same as delete confirmations)
        guard await ViewUtils.confirmOperation(
            title: "Confirm Disable Hypervisor",
            message: "Disable the following hypervisor?",
            details: details,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Disable cancelled"
            await tui.draw(screen: screen)
            return
        }

        tui.statusMessage = "Disabling hypervisor '\(hostname)'..."
        await tui.draw(screen: screen)

        do {
            try await tui.client.nova.disableComputeService(
                host: hostname,
                reason: disableReason
            )
            tui.statusMessage = "Hypervisor '\(hostname)' disabled"

            // Refresh hypervisor data
            try await refresh()

            // Update selected resource if still viewing detail
            if let updatedHypervisor = tui.cacheManager.cachedHypervisors.first(where: { $0.id == hypervisor.id }) {
                tui.viewCoordinator.selectedResource = updatedHypervisor
            }
        } catch {
            tui.statusMessage = "Failed to disable hypervisor: \(error.localizedDescription)"
        }
    }

    /// View servers running on a hypervisor
    ///
    /// Fetches and displays the list of server instances running on the
    /// selected hypervisor using the hostname filter.
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    func viewHypervisorServers(screen: OpaquePointer?, tui: TUI) async {
        guard let hypervisor = tui.viewCoordinator.selectedResource as? Hypervisor else {
            tui.statusMessage = "No hypervisor selected"
            return
        }

        guard let hostname = hypervisor.hypervisorHostname else {
            tui.statusMessage = "Hypervisor has no hostname"
            return
        }

        tui.statusMessage = "Loading servers on '\(hostname)'..."

        do {
            // Fetch servers specifically for this hypervisor
            let servers = try await tui.client.nova.listHypervisorServers(hypervisorHostname: hostname)

            // Replace the servers cache with only servers from this hypervisor
            tui.cacheManager.cachedServers = servers

            tui.statusMessage = "Showing \(servers.count) server(s) on '\(hostname)'"
            tui.changeView(to: .servers, resetSelection: true)
        } catch {
            tui.statusMessage = "Failed to load servers: \(error.localizedDescription)"
        }
    }
}
