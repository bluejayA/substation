// Sources/Substation/Modules/Hypervisors/Extensions/HypervisorsModule+Views.swift
import Foundation
import SwiftNCurses

/// View registration extension for Hypervisors module
extension HypervisorsModule {

    // MARK: - View Identifiers

    /// Static view identifiers for the Hypervisors module
    enum Views {
        /// List view identifier
        static let list = DynamicViewIdentifier(
            id: "hypervisors.list",
            moduleId: "hypervisors",
            viewType: .list
        )

        /// Detail view identifier
        static let detail = DynamicViewIdentifier(
            id: "hypervisors.detail",
            moduleId: "hypervisors",
            viewType: .detail
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [list, detail]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register views with enhanced metadata
    ///
    /// - Returns: Array of ViewMetadata for all module views
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        var metadata: [ViewMetadata] = []

        // Hypervisors List View
        metadata.append(ViewMetadata(
            identifier: Views.list,
            title: "Hypervisors",
            parentViewId: nil,
            isDetailView: false,
            supportsMultiSelect: false,
            category: .compute,
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderHypervisorsList(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: { [weak self, weak tui] ch, screen in
                guard let self = self, let tui = tui else { return false }
                return await self.handleListViewInput(ch, screen: screen, tui: tui)
            }
        ))

        // Hypervisor Detail View
        metadata.append(ViewMetadata(
            identifier: Views.detail,
            title: "Hypervisor Details",
            parentViewId: Views.list.id,
            isDetailView: true,
            supportsMultiSelect: false,
            category: .compute,
            renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                guard let self = self, let tui = tui else { return }
                await self.renderHypervisorDetail(
                    tui: tui,
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height
                )
            },
            inputHandler: { [weak self, weak tui] ch, screen in
                guard let self = self, let tui = tui else { return false }
                return await self.handleDetailViewInput(ch, screen: screen, tui: tui)
            }
        ))

        return metadata
    }

    // MARK: - List View Input Handling

    /// Handle input in the hypervisors list view
    ///
    /// - Parameters:
    ///   - ch: The input character code
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    /// - Returns: True if the input was handled
    func handleListViewInput(_ ch: Int32, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch ch {
        case Int32(Character("S").asciiValue!):  // SHIFT-S - View servers
            Logger.shared.logUserAction("view_hypervisor_servers", details: [
                "selectedIndex": tui.viewCoordinator.selectedIndex
            ])
            await viewHypervisorServersFromList(screen: screen, tui: tui)
            return true

        case Int32(Character("E").asciiValue!):  // SHIFT-E - Enable hypervisor
            Logger.shared.logUserAction("enable_hypervisor", details: [
                "selectedIndex": tui.viewCoordinator.selectedIndex
            ])
            await enableHypervisorFromList(screen: screen, tui: tui)
            return true

        case Int32(Character("D").asciiValue!):  // SHIFT-D - Disable hypervisor
            Logger.shared.logUserAction("disable_hypervisor", details: [
                "selectedIndex": tui.viewCoordinator.selectedIndex
            ])
            await disableHypervisorFromList(screen: screen, tui: tui)
            return true

        default:
            return false
        }
    }

    // MARK: - List View Actions

    /// View servers on the selected hypervisor from list view
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    private func viewHypervisorServersFromList(screen: OpaquePointer?, tui: TUI) async {
        // Get the selected hypervisor from the filtered list
        let hypervisors = tui.cacheManager.cachedHypervisors
        let filteredHypervisors = FilterUtils.filterHypervisors(
            hypervisors,
            query: tui.searchQuery
        )

        guard !filteredHypervisors.isEmpty else {
            tui.statusMessage = "No hypervisors available - try refreshing (c)"
            return
        }

        guard tui.viewCoordinator.selectedIndex < filteredHypervisors.count else {
            // Clamp the index to valid range and use that
            let validIndex = max(0, min(tui.viewCoordinator.selectedIndex, filteredHypervisors.count - 1))
            tui.viewCoordinator.selectedIndex = validIndex
            // Continue with the clamped index
            let hypervisor = filteredHypervisors[validIndex]
            tui.viewCoordinator.selectedResource = hypervisor
            await viewHypervisorServers(screen: screen, tui: tui)
            return
        }

        let hypervisor = filteredHypervisors[tui.viewCoordinator.selectedIndex]

        // Set the selected resource and view servers
        tui.viewCoordinator.selectedResource = hypervisor
        await viewHypervisorServers(screen: screen, tui: tui)
    }

    /// Enable the selected hypervisor from list view
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    private func enableHypervisorFromList(screen: OpaquePointer?, tui: TUI) async {
        // Get the selected hypervisor from the filtered list
        let hypervisors = tui.cacheManager.cachedHypervisors
        let filteredHypervisors = FilterUtils.filterHypervisors(
            hypervisors,
            query: tui.searchQuery
        )

        guard tui.viewCoordinator.selectedIndex < filteredHypervisors.count else {
            tui.statusMessage = "No hypervisor selected"
            return
        }

        let hypervisor = filteredHypervisors[tui.viewCoordinator.selectedIndex]

        // Set the selected resource and enable
        tui.viewCoordinator.selectedResource = hypervisor
        await enableHypervisor(screen: screen, tui: tui)
    }

    /// Disable the selected hypervisor from list view with reason prompt
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - tui: TUI instance
    private func disableHypervisorFromList(screen: OpaquePointer?, tui: TUI) async {
        // Get the selected hypervisor from the filtered list
        let hypervisors = tui.cacheManager.cachedHypervisors
        let filteredHypervisors = FilterUtils.filterHypervisors(
            hypervisors,
            query: tui.searchQuery
        )

        guard tui.viewCoordinator.selectedIndex < filteredHypervisors.count else {
            tui.statusMessage = "No hypervisor selected"
            return
        }

        let hypervisor = filteredHypervisors[tui.viewCoordinator.selectedIndex]

        // Set the selected resource and disable with prompt
        tui.viewCoordinator.selectedResource = hypervisor
        await disableHypervisorWithPrompt(screen: screen, tui: tui)
    }
}
