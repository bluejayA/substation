import Foundation
import OSClient
import SwiftTUI
import CrossPlatformTimer

// MARK: - Input Handler
@MainActor
class InputHandler {
    private weak var tui: TUI?

    init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Main Input Router
    func handleInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Filter out mouse scroll and mouse-related key codes
        if isMouseOrScrollInput(ch) {
            Logger.shared.logDebug("Filtered out mouse/scroll input: \(ch)")
            return
        }

        // Update last activity time to prevent auto-refresh during active navigation
        tui.lastUserActivityTime = Date()

        Logger.shared.logUserAction("input_received", details: [
            "keyCode": ch,
            "currentView": "\(tui.currentView)",
            "fieldEditMode": tui.securityGroupCreateForm.fieldEditMode || tui.subnetCreateForm.fieldEditMode || tui.barbicanSecretCreateForm.fieldEditMode
        ])

        // ServerCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to server create handler when in server create view
        if tui.currentView == .serverCreate {
            await tui.handleServerCreateInput(ch, screen: screen)
            return
        }

        // KeyPairCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to key pair create handler when in key pair create view
        if tui.currentView == .keyPairCreate {
            await tui.handleKeyPairCreateInput(ch, screen: screen)
            return
        }

        // VolumeCreateForm now uses FormBuilder which handles its own input state
        // Delegate all input to volume create handler when in volume create view
        if tui.currentView == .volumeCreate {
            await tui.handleVolumeCreateInput(ch, screen: screen)
            return
        }

        // NetworkCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to network create handler when in network create view
        if tui.currentView == .networkCreate {
            await tui.handleNetworkCreateInput(ch, screen: screen)
            return
        }

        // If we're in security group create mode and editing a text field,
        // only allow ESC to exit edit mode, delegate everything else to security group create handler
        if tui.currentView == .securityGroupCreate && tui.securityGroupCreateForm.fieldEditMode {
            if ch == Int32(27) { // ESC - Exit edit mode
                Logger.shared.logUserAction("field_edit_exit", details: ["form": "securityGroupCreate"])
                tui.securityGroupCreateForm.fieldEditMode = false
                return
            }
            // Delegate all other input to security group create handler
            await tui.handleSecurityGroupCreateInput(ch, screen: screen)
            return
        }

        // If we're in subnet create mode and editing a text field,
        // only allow ESC to exit edit mode, delegate everything else to subnet create handler
        if tui.currentView == .subnetCreate && tui.subnetCreateForm.fieldEditMode {
            if ch == Int32(27) { // ESC - Exit edit mode
                Logger.shared.logUserAction("field_edit_exit", details: ["form": "subnetCreate"])
                tui.subnetCreateForm.fieldEditMode = false
                return
            }
            // Delegate all other input to subnet create handler
            await tui.handleSubnetCreateInput(ch, screen: screen)
            return
        }

        // If we're in port create mode and editing a text field,
        // only allow ESC to exit edit mode, delegate everything else to port create handler
        if tui.currentView == .portCreate && tui.portCreateForm.fieldEditMode {
            if ch == Int32(27) { // ESC - Exit edit mode
                Logger.shared.logUserAction("field_edit_exit", details: ["form": "portCreate"])
                tui.portCreateForm.fieldEditMode = false
                return
            }
            // Delegate all other input to port create handler
            await tui.handlePortCreateInput(ch, screen: screen)
            return
        }

        // FloatingIPCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to floating IP create handler when in floating IP create view
        if tui.currentView == .floatingIPCreate {
            await tui.handleFloatingIPCreateInput(ch, screen: screen)
            return
        }

        // RouterCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to router create handler when in router create view
        if tui.currentView == .routerCreate {
            await tui.handleRouterCreateInput(ch, screen: screen)
            return
        }

        // If we're in server group create mode and editing a text field,
        // only allow ESC to exit edit mode, delegate everything else to server group create handler
        if tui.currentView == .serverGroupCreate && tui.serverGroupCreateForm.fieldEditMode {
            if ch == Int32(27) { // ESC - Exit edit mode
                Logger.shared.logUserAction("field_edit_exit", details: ["form": "serverGroupCreate"])
                tui.serverGroupCreateForm.fieldEditMode = false
                return
            }
            // Delegate all other input to server group create handler
            await tui.handleServerGroupCreateInput(ch, screen: screen)
            return
        }

        // If we're in barbican secret create mode, delegate ALL input to the form handler
        if tui.currentView == .barbicanSecretCreate {
            Logger.shared.logDebug("ROUTING: barbicanSecretCreate input ch=\(ch), payloadEditMode=\(tui.barbicanSecretCreateForm.payloadEditMode)")
            await handleBarbicanSecretCreateInput(ch, screen: screen)
            return
        }

        // Advanced Search view input handling
        if tui.currentView == .advancedSearch {
            let handled = AdvancedSearchView.handleInput(ch)
            if handled {
                return
            }
            // If not handled by search view, allow global navigation to continue
        }

        // Health Dashboard view input handling
        if tui.currentView == .healthDashboard {
            let telemetryActor = await tui.getTelemetryActor()
            let handled = await HealthDashboardView.handleInput(ch, navigationState: tui.healthDashboardNavState, telemetryActor: telemetryActor, dataManager: tui.dataManager)
            if handled {
                tui.forceRedraw()
                return
            }
            // If not handled by health dashboard, allow global navigation to continue
        }

        if tui.currentView == .serverSecurityGroups {
            // Special handling for ESC in security group management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".serverSecurityGroups", to: ".servers")
                tui.changeView(to: .servers, resetSelection: false)
                return
            }
            // Delegate all other input to security group handler
            await tui.handleSecurityGroupInput(ch, screen: screen)
            return
        }

        if tui.currentView == .securityGroupRuleManagement {
            // Delegate all input to security group rule management handler
            await tui.handleSecurityGroupRuleManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .serverResize {
            // Special handling for ESC in server resize
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".serverResize", to: ".servers")
                tui.changeView(to: .servers, resetSelection: false)
                return
            }
            // Delegate all other input to server resize handler
            await tui.handleServerResizeInput(ch, screen: screen)
            return
        }

        if tui.currentView == .serverSnapshotManagement {
            // Special handling for ESC in snapshot management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".serverSnapshotManagement", to: ".servers")
                tui.changeView(to: .servers, resetSelection: false)
                return
            }
            // Delegate all other input to snapshot management handler
            await tui.handleSnapshotManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .volumeSnapshotManagement {
            // Special handling for ESC in volume snapshot management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".volumeSnapshotManagement", to: ".volumes")
                tui.changeView(to: .volumes, resetSelection: false)
                return
            }
            // Delegate all other input to volume snapshot management handler
            await tui.handleVolumeSnapshotManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .volumeBackupManagement {
            // Special handling for ESC in volume backup management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".volumeBackupManagement", to: ".volumes")
                tui.changeView(to: .volumes, resetSelection: false)
                return
            }
            // Delegate all other input to volume backup management handler
            await tui.handleVolumeBackupManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .serverNetworkInterfaces {
            // Special handling for ESC in network interface management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".serverNetworkInterfaces", to: ".servers")
                tui.changeView(to: .servers, resetSelection: false)
                return
            }
            // Delegate all other input to network interface handler
            await tui.handleNetworkInterfaceInput(ch, screen: screen)
            return
        }

        if tui.currentView == .volumeManagement {
            // Special handling for ESC in volume management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".volumeManagement", to: ".volumes")
                tui.changeView(to: .volumes, resetSelection: false)
                return
            }
            // Delegate to volume management handler
            await tui.handleVolumeManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .networkServerAttachment {
            // Special handling for ESC in network server attachment
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".networkServerAttachment", to: ".networks")
                tui.changeView(to: .networks, resetSelection: false)
                return
            }
            // Delegate all other input to network server attachment handler
            await tui.handleNetworkServerAttachmentInput(ch, screen: screen)
            return
        }

        if tui.currentView == .securityGroupServerAttachment {
            // Special handling for ESC in security group server attachment
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".securityGroupServerAttachment", to: ".securityGroups")
                tui.changeView(to: .securityGroups, resetSelection: false)
                return
            }
            // Delegate all other input to security group server attachment handler
            await tui.handleSecurityGroupServerAttachmentInput(ch, screen: screen)
            return
        }

        if tui.currentView == .securityGroupServerManagement {
            // Special handling for ESC in security group server management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".securityGroupServerManagement", to: ".securityGroups")
                tui.changeView(to: .securityGroups, resetSelection: false)
                return
            }
            // Delegate all other input to enhanced security group server management handler
            await tui.handleSecurityGroupServerManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .networkServerManagement {
            // Special handling for ESC in network server management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".networkServerManagement", to: ".networks")
                tui.changeView(to: .networks, resetSelection: false)
                return
            }
            // Delegate all other input to enhanced network server management handler
            await tui.handleNetworkServerManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .volumeServerManagement {
            // Special handling for ESC in volume server management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".volumeServerManagement", to: ".volumes")
                tui.changeView(to: .volumes, resetSelection: false)
                return
            }
            // Delegate all other input to enhanced volume server management handler
            await tui.handleVolumeServerManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .floatingIPServerManagement {
            // Special handling for ESC in floating IP server management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".floatingIPServerManagement", to: ".floatingIPs")
                tui.changeView(to: .floatingIPs, resetSelection: false)
                return
            }
            // Delegate all other input to floating IP server management handler
            await tui.handleFloatingIPServerManagementInput(ch, screen: screen)
            return
        }

        if tui.currentView == .flavorSelection {
            // Delegate all input to flavor selection handler
            await tui.handleFlavorSelectionInput(ch, screen: screen)
            return
        }

        if tui.currentView == .subnetRouterManagement {
            // Special handling for ESC in subnet router management
            if ch == 27 { // ESC
                Logger.shared.logNavigation(".subnetRouterManagement", to: ".subnets")
                tui.changeView(to: .subnets, resetSelection: false)
                return
            }
            // Delegate all other input to subnet router management handler
            await tui.handleSubnetRouterManagementInput(ch, screen: screen)
            return
        }

        await handleMainInput(ch, screen: screen)
    }

    // MARK: - Main Input Handler
    private func handleMainInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("main_input_handling", details: [
            "keyCode": ch,
            "view": "\(tui.currentView)",
            "selectedIndex": tui.selectedIndex,
            "scrollOffset": tui.scrollOffset
        ])

        // PRIORITY 1: Handle unified input if it's active
        if tui.unifiedInputState.isActive {
            let result = UnifiedInputView.handleInput(ch, state: &tui.unifiedInputState)

            switch result {
            case .updated:
                // Reset tab completion and history when user types (input changed)
                if tui.unifiedInputState.isCommandMode {
                    tui.commandMode.resetTabCompletion()
                    tui.commandMode.resetHistoryPosition()
                }
                // Update the search query in real-time for filtering
                tui.searchQuery = tui.unifiedInputState.searchQuery.isEmpty ? nil : tui.unifiedInputState.searchQuery
                tui.forceRedraw()
                return

            case .cleared:
                tui.searchQuery = nil
                tui.forceRedraw()
                return

            case .cancelled:
                // ESC when input is active - just deactivate
                tui.unifiedInputState.clear()
                tui.searchQuery = nil
                tui.forceRedraw()
                return

            case .commandEntered(let command):
                // Execute the command using CommandMode
                let result = tui.commandMode.executeCommand(command)

                switch result {
                case .navigateToView(let viewMode):
                    tui.changeView(to: viewMode)
                    tui.statusMessage = "Navigated to \(viewMode.title)"
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .showHelp:
                    tui.changeView(to: .help)
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .showCommands:
                    let commandList = tui.commandMode.getCommandList()
                    tui.statusMessage = commandList
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .quit:
                    tui.running = false
                    return

                case .error(let message):
                    tui.statusMessage = message
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .suggestion(let original, let suggested):
                    tui.statusMessage = "Unknown command '\(original)'. Did you mean ':\(suggested)'?"
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .listContexts:
                    // List available cloud contexts
                    Task {
                        let contextList = await tui.contextSwitcher.formatContextList()
                        tui.statusMessage = contextList
                        tui.unifiedInputState.clear()
                        tui.forceRedraw()
                    }
                    return

                case .switchContext(let contextName):
                    // Switch to a different cloud context
                    Task {
                        do {
                            try await tui.contextSwitcher.switchTo(contextName, client: tui.client, tui: tui)
                            tui.statusMessage = "Switched to cloud: \(contextName)"
                            tui.unifiedInputState.clear()
                            tui.forceRedraw()
                        } catch {
                            tui.statusMessage = "Failed to switch context: \(error.localizedDescription)"
                            tui.unifiedInputState.clear()
                            tui.forceRedraw()
                        }
                    }
                    return

                case .ignored:
                    break
                }

            case .searchEntered(let query):
                // ENTER in search mode - apply the filter and release keyboard
                tui.searchQuery = query.isEmpty ? nil : query
                tui.unifiedInputState.isActive = false
                tui.forceRedraw()
                return

            case .tabCompletion(let partial):
                // Handle Tab completion in command mode
                if let completion = await tui.commandMode.completeCommand(partial) {
                    // Replace the current input with the completion
                    tui.unifiedInputState.displayText = ":\(completion)"
                    tui.unifiedInputState.cursorPosition = completion.count + 1
                    tui.forceRedraw()
                } else {
                    // No completions available
                    tui.statusMessage = "No completions for '\(partial)'"
                    tui.forceRedraw()
                }
                return

            case .historyPrevious:
                // Navigate to previous command in history
                if let previousCmd = tui.commandMode.previousCommand() {
                    tui.unifiedInputState.displayText = ":\(previousCmd)"
                    tui.unifiedInputState.cursorPosition = previousCmd.count + 1
                    tui.forceRedraw()
                }
                return

            case .historyNext:
                // Navigate to next command in history
                if let nextCmd = tui.commandMode.nextCommand() {
                    tui.unifiedInputState.displayText = ":\(nextCmd)"
                    tui.unifiedInputState.cursorPosition = nextCmd.count + 1
                } else {
                    // At the end of history, clear to just ":"
                    tui.unifiedInputState.displayText = ":"
                    tui.unifiedInputState.cursorPosition = 1
                }
                tui.forceRedraw()
                return

            case .ignored:
                break // Fall through to normal handling
            }
        }

        // PRIORITY 2: Activate unified input on / or :
        if ch == 47 { // '/' - Activate search mode
            tui.unifiedInputState.activate(asCommandMode: false)
            tui.forceRedraw()
            return
        }

        if ch == 58 { // ':' - Activate command mode
            tui.unifiedInputState.activate(asCommandMode: true)
            tui.forceRedraw()
            return
        }

        switch ch {
        case Int32(3): // CTRL-C
            Logger.shared.logUserAction("quit_application")
            tui.running = false
        case Int32(100): // d - Dashboard navigation
            Logger.shared.logNavigation("\(tui.currentView)", to: ".dashboard")
            tui.changeView(to: .dashboard)
        case Int32(107): // k - Key Pairs navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".keyPairs", details: ["action": "exit_detail"])
                tui.changeView(to: .keyPairs, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".keyPairs")
                tui.changeView(to: .keyPairs)
            }
        case Int32(115): // s - Servers navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".servers", details: ["action": "exit_detail"])
                tui.changeView(to: .servers, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".servers")
                tui.changeView(to: .servers)
            }
        case Int32(103): // g - Server Groups navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".serverGroups", details: ["action": "exit_detail"])
                tui.changeView(to: .serverGroups, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".serverGroups")
                tui.changeView(to: .serverGroups)
            }
        case Int32(114): // r - Routers navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".routers", details: ["action": "exit_detail"])
                tui.changeView(to: .routers, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".routers")
                tui.changeView(to: .routers)
            }
        case Int32(110): // n - Networks (lowercase)
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".networks", details: ["action": "exit_detail"])
                tui.changeView(to: .networks, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".networks")
                tui.changeView(to: .networks)
            }
        case Int32(117): // u - Subnets (lowercase)
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".subnets", details: ["action": "exit_detail"])
                tui.changeView(to: .subnets, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".subnets")
                tui.changeView(to: .subnets)
            }
        case Int32(101): // e - Security Groups (lowercase)
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".securityGroups", details: ["action": "exit_detail"])
                tui.changeView(to: .securityGroups, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".securityGroups")
                tui.changeView(to: .securityGroups)
            }
        case Int32(108): // l - Floating IPs navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".floatingIPs", details: ["action": "exit_detail"])
                tui.changeView(to: .floatingIPs, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".floatingIPs")
                tui.changeView(to: .floatingIPs)
            }
        case Int32(112): // p - Ports navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".ports", details: ["action": "exit_detail"])
                tui.changeView(to: .ports, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".ports")
                tui.changeView(to: .ports)
            }
        case Int32(118): // v - Volumes (lowercase)
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".volumes", details: ["action": "exit_detail"])
                tui.changeView(to: .volumes, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".volumes")
                tui.changeView(to: .volumes)
            }
        case Int32(105): // i - Images navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".images", details: ["action": "exit_detail"])
                tui.changeView(to: .images, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".images")
                tui.changeView(to: .images)
            }
        case Int32(102): // f - Flavors (lowercase)
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".flavors", details: ["action": "exit_detail"])
                tui.changeView(to: .flavors, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".flavors")
                tui.changeView(to: .flavors)
            }
        case Int32(116): // t - Topology navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".topology", details: ["action": "exit_detail"])
                tui.changeView(to: .topology, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".topology")
                tui.changeView(to: .topology)
            }
        case Int32(104): // h - Health Dashboard navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".healthDashboard", details: ["action": "exit_detail"])
                tui.changeView(to: .healthDashboard, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".healthDashboard")
                tui.changeView(to: .healthDashboard)
            }
        case Int32(98): // b - Barbican secrets navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".barbicanSecrets", details: ["action": "exit_detail"])
                tui.changeView(to: .barbicanSecrets, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".barbicanSecrets")
                tui.changeView(to: .barbicanSecrets)
            }
        case Int32(111): // o - Octavia navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".octavia", details: ["action": "exit_detail"])
                tui.changeView(to: .octavia, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".octavia")
                tui.changeView(to: .octavia)
            }
        case Int32(106): // j - Swift navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".swift", details: ["action": "exit_detail"])
                tui.changeView(to: .swift, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".swift")
                tui.changeView(to: .swift)
            }
        case Int32(24): // CTRL-X - Toggle multi-select mode
            if !tui.currentView.isDetailView && tui.currentView.supportsMultiSelect {
                Logger.shared.logUserAction("toggle_multi_select_mode", details: [
                    "view": "\(tui.currentView)",
                    "wasEnabled": tui.multiSelectMode
                ])
                handleToggleMultiSelectMode()
            }
        case Int32(77): // M - Manage security group rules
            if tui.currentView == .securityGroups && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_security_group_rules", details: ["selectedIndex": tui.selectedIndex])
                await handleManageSecurityGroupRules(screen: screen)
            }
        case Int32(109): // m - Volume Archives navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".volumeArchives", details: ["action": "exit_detail"])
                await tui.actions.loadAllVolumeSnapshots()
                await tui.actions.loadAllVolumeBackups()
                tui.changeView(to: .volumeArchives, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".volumeArchives")
                await tui.actions.loadAllVolumeSnapshots()
                await tui.actions.loadAllVolumeBackups()
                tui.changeView(to: .volumeArchives)
            }
        case Int32(122): // z - Advanced Search navigation
            if tui.currentView.isDetailView {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".advancedSearch", details: ["action": "exit_detail"])
                tui.changeView(to: .advancedSearch, resetSelection: false)
                tui.selectedResource = nil
            } else {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".advancedSearch")
                tui.changeView(to: .advancedSearch)
            }
        case Int32(9): // TAB - Cycle topology modes (only in topology view)
            if tui.currentView == .topology {
                Logger.shared.logUserAction("cycle_topology_mode", details: ["currentMode": "\(tui.currentTopologyMode)"])
                tui.cycleTopologyMode()
            }
        case Int32(259): // KEY_UP
            Logger.shared.logInfo("KEY_UP detected - currentView: \(tui.currentView), isDetailView: \(tui.currentView.isDetailView)")
            if tui.currentView == .barbicanSecrets || tui.currentView == .barbican {
                Logger.shared.logInfo("BARBICAN KEY_UP: About to call handleUpArrowKey(), secretsCount=\(tui.cachedSecrets.count), selectedIndex=\(tui.selectedIndex)")
            }
            Logger.shared.logUserAction("navigation_up", details: ["view": "\(tui.currentView)"])
            await handleUpArrowKey()
        case Int32(258): // KEY_DOWN
            Logger.shared.logInfo("KEY_DOWN detected - currentView: \(tui.currentView), isDetailView: \(tui.currentView.isDetailView)")
            if tui.currentView == .barbicanSecrets || tui.currentView == .barbican {
                Logger.shared.logInfo("BARBICAN KEY_DOWN: About to call handleDownArrowKey(), secretsCount=\(tui.cachedSecrets.count), selectedIndex=\(tui.selectedIndex)")
            }
            Logger.shared.logUserAction("navigation_down", details: ["view": "\(tui.currentView)"])
            await handleDownArrowKey()
        case Int32(338): // PAGE_DOWN
            Logger.shared.logUserAction("page_down", details: ["view": "\(tui.currentView)"])
            await handlePageDownKey()
        case Int32(339): // PAGE_UP
            Logger.shared.logUserAction("page_up", details: ["view": "\(tui.currentView)"])
            await handlePageUpKey()
        case Int32(32): // SPACEBAR - Toggle item selection in multi-select mode or show details
            if tui.multiSelectMode && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("toggle_multi_select_item", details: [
                    "view": "\(tui.currentView)",
                    "selectedIndex": tui.selectedIndex
                ])
                await handleMultiSelectToggle()
            } else if !tui.currentView.isDetailView {
                Logger.shared.logUserAction("open_detail_view", details: [
                    "view": "\(tui.currentView)",
                    "selectedIndex": tui.selectedIndex
                ])
                tui.openDetailView()
            }
        case Int32(27): // ESC - Back/clear search
            Logger.shared.logUserAction("escape_key", details: ["view": "\(tui.currentView)"])
            handleEscapeKey()
        case Int32(114): // r - Manual refresh
            Logger.shared.logUserAction("manual_refresh", details: ["view": "\(tui.currentView)"])
            await handleRefreshKey()
        case Int32(97): // a - Toggle auto-refresh
            Logger.shared.logUserAction("toggle_auto_refresh", details: ["current": tui.autoRefresh])
            handleAutoRefreshToggle()
        case Int32(99): // c - purge cache
            Logger.shared.logUserAction("purge_cache")
            await handleCachePurge()
        case Int32(47): // / - search or filter
            Logger.shared.logUserAction("search_filter_prompt", details: ["view": "\(tui.currentView)"])
            if let input = ViewUtils.prompt("Search: ", screen: screen, screenRows: tui.screenRows), !input.isEmpty {
                Logger.shared.logUserAction("search_applied", details: ["query": input, "view": "\(tui.currentView)"])
                tui.searchQuery = input
                tui.scrollOffset = 0
                tui.selectedIndex = 0
            } else {
                Logger.shared.logUserAction("search_cleared", details: ["view": "\(tui.currentView)"])
                tui.searchQuery = nil
            }
        // Secondary Commands (Uppercase) - Actions
        case Int32(67): // C - Create new resource
            Logger.shared.logUserAction("create_action", details: ["view": "\(tui.currentView)", "selectedIndex": tui.selectedIndex])
            await handleCreateResource()
        case Int32(68): // D - Detach/Dissociate action
            // Floating IP detach has been moved to the management interface (A key)
            break
        // G key removed - security groups moved to A key in security groups view
        // I key removed - interfaces moved to A key in networks view
        case Int32(76): // L - View server logs
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("view_server_logs", details: ["selectedIndex": tui.selectedIndex])
                await handleViewServerLogs(screen: screen)
            }
        case Int32(66): // B - Create backup (volume)
            if tui.currentView == .volumes && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("create_volume_backup", details: ["selectedIndex": tui.selectedIndex])
                await handleVolumeBackup(screen: screen)
            }
        case Int32(80): // P - Create snapshot
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("create_snapshot", details: ["selectedIndex": tui.selectedIndex])
                await handleCreateSnapshot(screen: screen)
            } else if tui.currentView == .volumes && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("create_volume_snapshot", details: ["selectedIndex": tui.selectedIndex])
                await tui.resourceOperations.createVolumeSnapshot(screen: screen)
            }
        case Int32(82): // R - Restart server
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("restart_server", details: ["selectedIndex": tui.selectedIndex])
                await handleRestartServer(screen: screen)
            }
        case Int32(83): // S - Start server
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("start_server", details: ["selectedIndex": tui.selectedIndex])
                await handleStartServer(screen: screen)
            }
        case Int32(84): // T - Stop server
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("stop_server", details: ["selectedIndex": tui.selectedIndex])
                await handleStopServer(screen: screen)
            }
        case Int32(63): // ? - Show help
            if tui.currentView != .help {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".help")
                tui.helpScrollOffset = 0 // Reset scroll when entering help
                tui.changeView(to: .help)
            }
        case Int32(64): // @ - Show about page
            if tui.currentView != .about {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".about")
                tui.helpScrollOffset = 0 // Reset scroll when entering about
                tui.changeView(to: .about)
            }
        case Int32(87): // W - Export topology
            Logger.shared.logUserAction("export_topology", details: ["view": "\(tui.currentView)"])
            await handleTopologyExport()
        case Int32(127), Int32(330): // DELETE key - Delete resources
            Logger.shared.logUserAction("delete_action", details: ["view": "\(tui.currentView)", "selectedIndex": tui.selectedIndex])
            await handleDeleteKey(screen: screen)
        case Int32(90): // Z - Resize selected server
            Logger.shared.logUserAction("resize_server", details: ["selectedIndex": tui.selectedIndex])
            await handleResizeServer(screen: screen)
        case Int32(65): // A - Context-sensitive: Attach security group to server OR network to server OR volume to server OR floating IP attach OR toggle auto-refresh interval
            if tui.currentView == .securityGroups && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("attach_security_group", details: ["selectedIndex": tui.selectedIndex])
                await handleAttachSecurityGroup(screen: screen)
            } else if tui.currentView == .networks && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("attach_network_to_server", details: ["selectedIndex": tui.selectedIndex])
                await handleAttachNetworkToServer(screen: screen)
            } else if tui.currentView == .floatingIPs && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_floating_ip_server_assignment", details: ["selectedIndex": tui.selectedIndex])
                await handleManageFloatingIPServerAssignment(screen: screen)
            } else if tui.currentView == .volumes && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("attach_volume", details: ["selectedIndex": tui.selectedIndex])
                await handleAttachVolume(screen: screen)
            } else if tui.currentView == .subnets && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("attach_subnet_router", details: ["selectedIndex": tui.selectedIndex])
                await handleAttachSubnetRouter(screen: screen)
            } else {
                // Default to refresh interval cycling for dashboard and other views
                Logger.shared.logUserAction("cycle_refresh_interval", details: ["currentInterval": tui.baseRefreshInterval])
                tui.cycleRefreshInterval()
            }
        case Int32(82): // R - Context-sensitive: Routers navigation OR Restart server
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                // Use R for restart in servers view
                Logger.shared.logUserAction("restart_server", details: ["selectedIndex": tui.selectedIndex])
                await handleRestartServer(screen: screen)
            } else {
                // Use R for routers navigation in all other views
                if tui.currentView.isDetailView {
                    Logger.shared.logNavigation("\(tui.currentView)", to: ".routers", details: ["action": "exit_detail"])
                    tui.changeView(to: .routers, resetSelection: false)
                    tui.selectedResource = nil
                } else {
                    Logger.shared.logNavigation("\(tui.currentView)", to: ".routers")
                    tui.changeView(to: .routers)
                }
            }
        default:
            Logger.shared.logUserAction("unhandled_key", details: ["keyCode": ch, "view": "\(tui.currentView)"])
            break
        }

        // Handle form-specific inputs after main input handling
        await handleFormInputs(ch, screen: screen)
    }

    // MARK: - Navigation Helper Methods
    private func handleUpArrowKey() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("up_arrow_navigation", details: [
            "view": "\(tui.currentView)",
            "before_selectedIndex": tui.selectedIndex,
            "before_scrollOffset": tui.scrollOffset
        ])

        // Mark renderer for scroll optimization
        tui.markScrollOperation()

        if tui.currentView == .help || tui.currentView == .about {
            tui.helpScrollOffset = max(tui.helpScrollOffset - 1, 0)
        } else if tui.currentView == .dashboard {
            tui.quotaScrollOffset = max(tui.quotaScrollOffset - 1, 0)
        } else if tui.currentView.isDetailView {
            tui.detailScrollOffset = max(tui.detailScrollOffset - 1, 0)
        } else {
            let oldIndex = tui.selectedIndex
            let maxIndex = tui.getMaxSelectionIndex()
            tui.selectedIndex = max(tui.selectedIndex - 1, 0)
            // Adjust scroll if selection moves out of view
            if tui.selectedIndex < tui.scrollOffset {
                tui.scrollOffset = tui.selectedIndex
            }

            // Enhanced debugging for Barbican navigation
            if tui.currentView == .barbicanSecrets || tui.currentView == .barbican {
                Logger.shared.logInfo("Barbican UP navigation: oldIndex=\(oldIndex) newIndex=\(tui.selectedIndex) maxIndex=\(maxIndex) secretsCount=\(tui.cachedSecrets.count)")
            }
        }

        Logger.shared.logUserAction("up_arrow_completed", details: [
            "view": "\(tui.currentView)",
            "after_selectedIndex": tui.selectedIndex,
            "after_scrollOffset": tui.scrollOffset
        ])
    }

    private func handleDownArrowKey() async {
        Logger.shared.logInfo("handleDownArrowKey called - currentView: \((tui?.currentView)!), isDetailView: \((tui?.currentView.isDetailView)!)")
        guard let tui = tui else { return }

        Logger.shared.logUserAction("down_arrow_navigation", details: [
            "view": "\(tui.currentView)",
            "before_selectedIndex": tui.selectedIndex,
            "before_scrollOffset": tui.scrollOffset
        ])

        // Mark renderer for scroll optimization
        tui.markScrollOperation()

        if tui.currentView == .help || tui.currentView == .about {
            // Let the help view handle bounds checking internally
            // We'll use a reasonable maximum to prevent infinite scrolling
            tui.helpScrollOffset = min(tui.helpScrollOffset + 1, 50)
        } else if tui.currentView == .dashboard {
            // Calculate max quota scroll based on available quota data
            let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
            tui.quotaScrollOffset = min(tui.quotaScrollOffset + 1, maxQuotaScroll)
        } else if tui.currentView.isDetailView {
            // Add proper bounds checking for detail view scrolling
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            let oldOffset = tui.detailScrollOffset
            tui.detailScrollOffset = min(tui.detailScrollOffset + 1, maxScroll)
            Logger.shared.logInfo("DOWN arrow in detail view - oldOffset: \(oldOffset), newOffset: \(tui.detailScrollOffset), maxScroll: \(maxScroll), view: \(tui.currentView)")
        } else {
            let oldIndex = tui.selectedIndex
            let maxIndex = tui.getMaxSelectionIndex()
            tui.selectedIndex = min(tui.selectedIndex + 1, maxIndex)
            // Adjust scroll to keep selection in view
            let visibleItems = Int(tui.screenRows) - 10 // Must match StatusListView maxVisibleItems calculation
            if tui.selectedIndex >= tui.scrollOffset + visibleItems {
                tui.scrollOffset = tui.selectedIndex - visibleItems + 1
            }

            // Enhanced debugging for Barbican navigation
            if tui.currentView == .barbicanSecrets || tui.currentView == .barbican {
                Logger.shared.logInfo("Barbican DOWN navigation: oldIndex=\(oldIndex) newIndex=\(tui.selectedIndex) maxIndex=\(maxIndex) secretsCount=\(tui.cachedSecrets.count)")
            }
        }

        Logger.shared.logUserAction("down_arrow_completed", details: [
            "view": "\(tui.currentView)",
            "after_selectedIndex": tui.selectedIndex,
            "after_scrollOffset": tui.scrollOffset
        ])
    }

    private func handlePageUpKey() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("page_up_navigation", details: [
            "view": "\(tui.currentView)",
            "before_selectedIndex": tui.selectedIndex,
            "before_scrollOffset": tui.scrollOffset
        ])

        // Mark renderer for scroll optimization
        tui.markScrollOperation()

        if tui.currentView == .help {
            tui.helpScrollOffset = max(tui.helpScrollOffset - 10, 0)
        } else if tui.currentView == .dashboard {
            tui.quotaScrollOffset = max(tui.quotaScrollOffset - 10, 0)
        } else if tui.currentView.isDetailView {
            tui.detailScrollOffset = max(tui.detailScrollOffset - 10, 0)
        } else {
            // Page up by viewport size (approximately 15-20 items)
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let newIndex = max(tui.selectedIndex - pageSize, 0)
            tui.selectedIndex = newIndex

            // Adjust scroll to keep selection in view
            if tui.selectedIndex < tui.scrollOffset {
                tui.scrollOffset = max(tui.selectedIndex - 5, 0) // Keep some context
            }
        }

        Logger.shared.logUserAction("page_up_completed", details: [
            "view": "\(tui.currentView)",
            "after_selectedIndex": tui.selectedIndex,
            "after_scrollOffset": tui.scrollOffset
        ])
    }

    private func handlePageDownKey() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("page_down_navigation", details: [
            "view": "\(tui.currentView)",
            "before_selectedIndex": tui.selectedIndex,
            "before_scrollOffset": tui.scrollOffset
        ])

        // Mark renderer for scroll optimization
        tui.markScrollOperation()

        if tui.currentView == .help {
            tui.helpScrollOffset = min(tui.helpScrollOffset + 10, 50)
        } else if tui.currentView == .dashboard {
            let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
            tui.quotaScrollOffset = min(tui.quotaScrollOffset + 10, maxQuotaScroll)
        } else if tui.currentView.isDetailView {
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.detailScrollOffset = min(tui.detailScrollOffset + 10, maxScroll)
        } else {
            // Page down by viewport size (approximately 15-20 items)
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let maxIndex = tui.getMaxSelectionIndex()
            let newIndex = min(tui.selectedIndex + pageSize, maxIndex)
            tui.selectedIndex = newIndex

            // Adjust scroll to keep selection in view
            let visibleItems = Int(tui.screenRows) - 8
            if tui.selectedIndex >= tui.scrollOffset + visibleItems {
                tui.scrollOffset = min(tui.selectedIndex - visibleItems + 6, maxIndex) // Keep some context
            }
        }

        Logger.shared.logUserAction("page_down_completed", details: [
            "view": "\(tui.currentView)",
            "after_selectedIndex": tui.selectedIndex,
            "after_scrollOffset": tui.scrollOffset
        ])
    }

    private func handleEscapeKey() {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("escape_key_handling", details: [
            "view": "\(tui.currentView)",
            "isDetailView": tui.currentView.isDetailView,
            "hasSearchQuery": tui.searchQuery != nil,
            "multiSelectMode": tui.multiSelectMode
        ])

        if tui.multiSelectMode {
            Logger.shared.logUserAction("exit_multi_select_mode", details: ["selectedCount": tui.multiSelectedResourceIDs.count])
            tui.multiSelectMode = false
            tui.multiSelectedResourceIDs.removeAll()
            tui.statusMessage = "Exited multi-select mode"
        } else if tui.currentView == .help {
            Logger.shared.logNavigation(".help", to: "\(tui.previousView)")
            tui.changeView(to: tui.previousView, resetSelection: false)
        } else if tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: "\(tui.currentView.parentView)", details: ["action": "escape_detail"])

            // Special handling for health dashboard service detail - return to SERVICE STATUS section
            if tui.currentView == .healthDashboardServiceDetail {
                tui.healthDashboardNavState.currentSection = .services
                Logger.shared.logUserAction("health_dashboard_return_to_services", details: ["from": "service_detail"])
            }

            tui.changeView(to: tui.currentView.parentView, resetSelection: false)
            tui.selectedResource = nil
        } else if tui.searchQuery != nil {
            Logger.shared.logUserAction("search_cleared_via_escape", details: ["previousQuery": tui.searchQuery ?? ""])
            tui.searchQuery = nil
        }
    }

    private func handleAutoRefreshToggle() {
        guard let tui = tui else { return }

        let oldValue = tui.autoRefresh
        tui.autoRefresh.toggle()
        let intervalText = tui.autoRefresh ? " (\(Int(tui.baseRefreshInterval))s interval)" : ""
        tui.statusMessage = "Auto-refresh: \(tui.autoRefresh ? "ON" : "OFF")\(intervalText)"
        tui.markSidebarDirty() // Update sidebar to show new auto-refresh status

        Logger.shared.logUserAction("auto_refresh_toggled", details: [
            "from": oldValue,
            "to": tui.autoRefresh
        ])
    }

    private func handleCreateResource() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("create_resource_initiated", details: ["view": "\(tui.currentView)"])

        if tui.currentView == .servers && !tui.currentView.isDetailView {
            // Navigate to server creation
            Logger.shared.logNavigation("\(tui.currentView)", to: ".serverCreate")
            tui.changeView(to: .serverCreate)

            // Reset form and populate with cached data
            var form = ServerCreateForm()
            form.images = tui.cachedImages
            form.volumes = tui.cachedVolumes
            form.flavors = tui.cachedFlavors
            form.networks = tui.cachedNetworks
            form.securityGroups = tui.cachedSecurityGroups
            form.keyPairs = tui.cachedKeyPairs
            form.serverGroups = tui.cachedServerGroups
            tui.serverCreateForm = form

            // Initialize FormBuilderState with form fields
            tui.serverCreateFormState = FormBuilderState(fields: form.buildFields(selectedFieldId: nil))
        } else if tui.currentView == .networks && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".networkCreate")
            tui.changeView(to: .networkCreate)
            tui.networkCreateForm = NetworkCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.networkCreateFormState = FormBuilderState(fields: tui.networkCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.currentView == .securityGroups && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".securityGroupCreate")
            tui.changeView(to: .securityGroupCreate)
            tui.securityGroupCreateForm = SecurityGroupCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.securityGroupCreateFormState = FormBuilderState(fields: tui.securityGroupCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.currentView == .subnets && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".subnetCreate")
            tui.changeView(to: .subnetCreate)
            tui.subnetCreateForm = SubnetCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.subnetCreateFormState = FormBuilderState(fields: tui.subnetCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                cachedNetworks: tui.cachedNetworks,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.currentView == .keyPairs && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".keyPairCreate")
            tui.changeView(to: .keyPairCreate)
            tui.keyPairCreateForm = KeyPairCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.keyPairCreateFormState = FormBuilderState(fields: tui.keyPairCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.currentView == .volumes && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".volumeCreate")
            tui.changeView(to: .volumeCreate)
            // Load all snapshots for volume creation
            await tui.actions.loadAllVolumeSnapshots()
            // Reset form and populate cached data
            tui.volumeCreateForm = VolumeCreateForm()
            tui.volumeCreateForm.images = tui.cachedImages
            tui.volumeCreateForm.snapshots = tui.cachedVolumeSnapshots
            tui.volumeCreateForm.volumeTypes = tui.cachedVolumeTypes
            // Initialize form state
            tui.volumeCreateFormState = FormBuilderState(fields: tui.volumeCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: nil
            ))
        } else if tui.currentView == .ports && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".portCreate")
            tui.changeView(to: .portCreate)
            tui.portCreateForm = PortCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.portCreateFormState = FormBuilderState(fields: tui.portCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: []),
                networks: tui.cachedNetworks,
                securityGroups: tui.cachedSecurityGroups,
                qosPolicies: tui.cachedQoSPolicies
            ))
        } else if tui.currentView == .floatingIPs && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".floatingIPCreate")
            tui.changeView(to: .floatingIPCreate)
            tui.floatingIPCreateForm = FloatingIPCreateForm()
            let externalNetworks = tui.cachedNetworks.filter { $0.external == true }
            tui.floatingIPCreateFormState = FormBuilderState(
                fields: tui.floatingIPCreateForm.buildFields(
                    externalNetworks: externalNetworks,
                    subnets: tui.cachedSubnets,
                    selectedFieldId: nil
                )
            )
        } else if tui.currentView == .routers && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".routerCreate")
            tui.changeView(to: .routerCreate)
            tui.routerCreateForm = RouterCreateForm()
            tui.routerCreateFormState = FormBuilderState(
                fields: tui.routerCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: nil,
                    availabilityZones: tui.cachedAvailabilityZones,
                    externalNetworks: tui.cachedNetworks
                )
            )
        } else if tui.currentView == .serverGroups && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".serverGroupCreate")
            tui.changeView(to: .serverGroupCreate)
            tui.serverGroupCreateForm = ServerGroupCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.serverGroupCreateFormState = FormBuilderState(fields: tui.serverGroupCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if (tui.currentView == .barbicanSecrets || tui.currentView == .barbican) && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".barbicanSecretCreate")
            tui.changeView(to: .barbicanSecretCreate)
            tui.barbicanSecretCreateForm = BarbicanSecretCreateForm() // Reset form
        } else if tui.currentView == .octavia && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".octaviaLoadBalancerCreate")
            tui.changeView(to: .octaviaLoadBalancerCreate)
        } else if tui.currentView == .swift && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".swiftContainerCreate")
            tui.changeView(to: .swiftContainerCreate)
        }
    }

    // MARK: - Action Helper Methods
    private func handleRefreshKey() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("refresh_initiated", details: ["view": "\(tui.currentView)"])
        let startTime = Date()

        if tui.currentView == .topology {
            // Fast topology-only refresh for topology view
            let refreshStart = Date()
            await tui.refreshTopology()
            let refreshDuration = Date().timeIntervalSince(refreshStart)
            Logger.shared.logPerformance("topology_refresh", duration: refreshDuration)
            tui.lastRefresh = Date()
        } else {
            // Full data refresh for other views
            let refreshStart = Date()
            await tui.dataManager.refreshAllData()
            let refreshDuration = Date().timeIntervalSince(refreshStart)
            Logger.shared.logPerformance("full_data_refresh", duration: refreshDuration)
            tui.lastRefresh = Date()

            // Request refresh for health dashboard if on that view
            if tui.currentView == .healthDashboard {
                tui.healthDashboardNavState.requestRefresh()
            }

            tui.statusMessage = "Data refreshed"
        }

        let duration = Date().timeIntervalSince(startTime)
        Logger.shared.logPerformance("refresh_completed", duration: duration, context: [
            "view": "\(tui.currentView)",
            "refreshType": tui.currentView == .topology ? "topology_only" : "full_data"
        ])
    }

    private func handleCachePurge() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("cache_purge_initiated")
        let startTime = Date()

        await tui.dataManager.purgeCache()
        tui.lastRefresh = Date()

        let duration = Date().timeIntervalSince(startTime)
        Logger.shared.logPerformance("cache_purge_and_refresh", duration: duration)
    }

    private func handleTopologyExport() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("topology_export_requested", details: [
            "view": "\(tui.currentView)",
            "hasTopology": tui.lastTopology != nil
        ])

        if tui.currentView == .topology && tui.lastTopology != nil {
            let exportStart = Date()
            await tui.exportTopology()
            let exportDuration = Date().timeIntervalSince(exportStart)
            Logger.shared.logPerformance("topology_export", duration: exportDuration)
        } else {
            Logger.shared.logWarning("Topology export skipped - not in topology view or no topology data")
        }
    }

    // MARK: - Multi-Select Helper Methods
    private func handleToggleMultiSelectMode() {
        guard let tui = tui else { return }

        tui.multiSelectMode.toggle()
        if !tui.multiSelectMode {
            tui.multiSelectedResourceIDs.removeAll()
            tui.statusMessage = "Multi-select mode OFF"
        } else {
            tui.statusMessage = "Multi-select mode ON - Use SPACE to select items, CTRL-X to exit, DELETE to bulk delete"
        }
    }

    private func handleMultiSelectToggle() async {
        guard let tui = tui else { return }

        let resourceID = getSelectedResourceID()
        guard !resourceID.isEmpty else { return }

        if tui.multiSelectedResourceIDs.contains(resourceID) {
            tui.multiSelectedResourceIDs.remove(resourceID)
            Logger.shared.logUserAction("deselect_resource", details: ["resourceID": resourceID])
        } else {
            tui.multiSelectedResourceIDs.insert(resourceID)
            Logger.shared.logUserAction("select_resource", details: ["resourceID": resourceID])
        }

        tui.statusMessage = "\(tui.multiSelectedResourceIDs.count) items selected"
    }

    private func getSelectedResourceID() -> String {
        guard let tui = tui else { return "" }

        switch tui.currentView {
        case .servers:
            guard tui.selectedIndex < tui.cachedServers.count else { return "" }
            return tui.cachedServers[tui.selectedIndex].id
        case .volumes:
            guard tui.selectedIndex < tui.cachedVolumes.count else { return "" }
            return tui.cachedVolumes[tui.selectedIndex].id
        case .networks:
            guard tui.selectedIndex < tui.cachedNetworks.count else { return "" }
            return tui.cachedNetworks[tui.selectedIndex].id
        case .subnets:
            guard tui.selectedIndex < tui.cachedSubnets.count else { return "" }
            return tui.cachedSubnets[tui.selectedIndex].id
        case .routers:
            guard tui.selectedIndex < tui.cachedRouters.count else { return "" }
            return tui.cachedRouters[tui.selectedIndex].id
        case .ports:
            guard tui.selectedIndex < tui.cachedPorts.count else { return "" }
            return tui.cachedPorts[tui.selectedIndex].id
        case .floatingIPs:
            guard tui.selectedIndex < tui.cachedFloatingIPs.count else { return "" }
            return tui.cachedFloatingIPs[tui.selectedIndex].id
        case .securityGroups:
            guard tui.selectedIndex < tui.cachedSecurityGroups.count else { return "" }
            return tui.cachedSecurityGroups[tui.selectedIndex].id
        case .serverGroups:
            guard tui.selectedIndex < tui.cachedServerGroups.count else { return "" }
            return tui.cachedServerGroups[tui.selectedIndex].id
        case .keyPairs:
            guard tui.selectedIndex < tui.cachedKeyPairs.count else { return "" }
            return tui.cachedKeyPairs[tui.selectedIndex].name ?? ""
        case .images:
            guard tui.selectedIndex < tui.cachedImages.count else { return "" }
            return tui.cachedImages[tui.selectedIndex].id
        default:
            return ""
        }
    }

    // MARK: - Server Action Methods
    private func handleDeleteKey(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Handle bulk delete in multi-select mode
        if tui.multiSelectMode && !tui.multiSelectedResourceIDs.isEmpty {
            await handleBulkDelete(screen: screen)
            return
        }

        if tui.currentView == .servers && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteServer(screen: screen)
        } else if tui.currentView == .keyPairs && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteKeyPair(screen: screen)
        } else if tui.currentView == .images && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteImage(screen: screen)
        } else if tui.currentView == .volumes && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteVolume(screen: screen)
        } else if tui.currentView == .networks && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteNetwork(screen: screen)
        } else if tui.currentView == .subnets && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteSubnet(screen: screen)
        } else if tui.currentView == .routers && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteRouter(screen: screen)
        } else if tui.currentView == .ports && !tui.currentView.isDetailView {
            await tui.resourceOperations.deletePort(screen: screen)
        } else if tui.currentView == .floatingIPs && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteFloatingIP(screen: screen)
        } else if tui.currentView == .serverGroups && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteServerGroup(screen: screen)
        } else if tui.currentView == .securityGroups && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteSecurityGroup(screen: screen)
        } else if (tui.currentView == .barbicanSecrets || tui.currentView == .barbican) && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteSecret(screen: screen)
        } else if tui.currentView == .volumeArchives && !tui.currentView.isDetailView {
            await tui.actions.deleteVolumeArchive(screen: screen)
        }
    }

    private func handleRestartServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .servers && !tui.currentView.isDetailView {
            await tui.actions.restartServer(screen: screen)
        }
    }

    private func handleResizeServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .servers && !tui.currentView.isDetailView {
            await tui.actions.resizeServer(screen: screen)
        }
    }

    private func handleViewServerLogs(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .servers && !tui.currentView.isDetailView {
            await tui.actions.viewServerLogs(screen: screen)
        }
    }

    private func handleStartServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .servers && !tui.currentView.isDetailView {
            await tui.actions.startServer(screen: screen)
        }
    }

    private func handleStopServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .servers && !tui.currentView.isDetailView {
            await tui.actions.stopServer(screen: screen)
        }
    }

    private func handleAttachSecurityGroup(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .securityGroups && !tui.currentView.isDetailView {
            await tui.actions.attachSecurityGroupToServers(screen: screen)
        }
    }

    private func handleAttachNetworkToServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .networks && !tui.currentView.isDetailView {
            await tui.actions.manageNetworkToServers(screen: screen)
        }
    }

    private func handleCreateSnapshot(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if (tui.currentView == .servers && !tui.currentView.isDetailView) || tui.currentView == .serverDetail {
            await tui.resourceOperations.createServerSnapshot(screen: screen)
        } else if (tui.currentView == .volumes && !tui.currentView.isDetailView) || tui.currentView == .volumeDetail {
            await tui.resourceOperations.createVolumeSnapshot(screen: screen)
        }
    }

    private func handleVolumeBackup(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if (tui.currentView == .volumes && !tui.currentView.isDetailView) || tui.currentView == .volumeDetail {
            await tui.actions.createVolumeBackup(screen: screen)
        }
    }

    private func handleAttachVolume(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .volumes && !tui.currentView.isDetailView {
            await tui.actions.attachVolumeToServers(screen: screen)
        }
    }



    private func handleManageSecurityGroupRules(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .securityGroups && !tui.currentView.isDetailView {
            await tui.actions.manageSecurityGroupRules(screen: screen)
        }
    }

    // MARK: - Form Input Handling
    private func handleFormInputs(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // NOTE: ServerCreate, KeyPairCreate, VolumeCreate, and NetworkCreate are handled earlier with early return
        // to prevent the main input handler from interfering with text input

        // Handle security group creation form navigation
        if tui.currentView == .securityGroupCreate {
            await tui.handleSecurityGroupCreateInput(ch, screen: screen)
        }

        // Handle subnet creation form navigation
        if tui.currentView == .subnetCreate {
            await tui.handleSubnetCreateInput(ch, screen: screen)
        }

        // Handle port creation form navigation
        if tui.currentView == .portCreate {
            await tui.handlePortCreateInput(ch, screen: screen)
        }

        // Handle floating IP creation form navigation
        if tui.currentView == .floatingIPCreate {
            await tui.handleFloatingIPCreateInput(ch, screen: screen)
        }

        // Handle router creation form navigation
        if tui.currentView == .routerCreate {
            await handleRouterCreateInput(ch, screen: screen)
        }

        // Handle server group creation form navigation
        if tui.currentView == .serverGroupCreate {
            await handleServerGroupCreateInput(ch, screen: screen)
        }

        // Handle server group management form navigation
        if tui.currentView == .serverGroupManagement {
            await handleServerGroupManagementInput(ch, screen: screen)
        }

    }

    // MARK: - Specialized Form Input Handlers (delegate to TUI for now)
    private func handleServerCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleServerCreateInput(ch, screen: screen)
    }

    private func handleKeyPairCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleKeyPairCreateInput(ch, screen: screen)
    }

    private func handleVolumeCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleVolumeCreateInput(ch, screen: screen)
    }

    private func handleNetworkCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleNetworkCreateInput(ch, screen: screen)
    }

    private func handleSecurityGroupCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleSecurityGroupCreateInput(ch, screen: screen)
    }

    private func handleSubnetCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleSubnetCreateInput(ch, screen: screen)
    }

    private func handleSecurityGroupInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleSecurityGroupInput(ch, screen: screen)
    }

    private func handleNetworkInterfaceInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleNetworkInterfaceInput(ch, screen: screen)
    }

    private func handleVolumeManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleVolumeManagementInput(ch, screen: screen)
    }

    private func handleShowPerformanceStats() {
        guard let tui = tui else { return }

        // Get performance data and display it
        let dashboard = tui.performanceMonitor.getDashboardData()
        let systemMetrics = dashboard.systemMetrics
        let appMetrics = dashboard.applicationMetrics
        let openStackMetrics = dashboard.openStackMetrics

        let statusMessage = """
        Performance: Score=\(String(format: "%.0f", dashboard.performanceScore * 100))% | \
        CPU=\(String(format: "%.1f", systemMetrics.cpuUsage * 100))% | \
        Memory=\(ByteCountFormatter.string(fromByteCount: systemMetrics.memoryUsage, countStyle: .memory)) | \
        FPS=\(String(format: "%.0f", appMetrics.frameRate)) | \
        API=\(String(format: "%.2f", openStackMetrics.apiResponseTime))s | \
        Alerts=\(dashboard.activeAlertsCount)
        """

        tui.statusMessage = statusMessage
    }

    private func handleRouterCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleRouterCreateInput(ch, screen: screen)
    }

    private func handleServerGroupCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleServerGroupCreateInput(ch, screen: screen)
    }

    private func handleServerGroupManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleServerGroupManagementInput(ch, screen: screen)
    }

    // MARK: - Floating IP Action Methods
    private func handleManageFloatingIPServerAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .floatingIPs && !tui.currentView.isDetailView {
            await tui.actions.manageFloatingIPServerAssignment(screen: screen)
        }
    }

    private func handleAttachSubnetRouter(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .subnets && !tui.currentView.isDetailView {
            await tui.actions.manageSubnetRouterAttachment(screen: screen)
        }
    }

    private func handleBulkDelete(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let itemCount = tui.multiSelectedResourceIDs.count
        let resourceType = tui.currentView.title

        // Show confirmation modal
        let confirmed = await ConfirmationModal.show(
            title: "Bulk Delete Confirmation",
            message: "Delete \(itemCount) \(resourceType)?",
            details: ["This action cannot be undone", "\(itemCount) items will be permanently deleted"],
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        )

        guard confirmed else {
            tui.statusMessage = "Bulk delete cancelled"
            return
        }

        Logger.shared.logUserAction("bulk_delete_initiated", details: [
            "view": "\(tui.currentView)",
            "count": itemCount
        ])

        tui.statusMessage = "Deleting \(itemCount) \(resourceType)..."

        let batchOperation: BatchOperationType

        switch tui.currentView {
        case .servers:
            batchOperation = .serverBulkDelete(serverIDs: Array(tui.multiSelectedResourceIDs))
        case .volumes:
            batchOperation = .volumeBulkDelete(volumeIDs: Array(tui.multiSelectedResourceIDs))
        case .networks:
            batchOperation = .networkBulkDelete(networkIDs: Array(tui.multiSelectedResourceIDs))
        case .subnets:
            batchOperation = .subnetBulkDelete(subnetIDs: Array(tui.multiSelectedResourceIDs))
        case .routers:
            batchOperation = .routerBulkDelete(routerIDs: Array(tui.multiSelectedResourceIDs))
        case .ports:
            batchOperation = .portBulkDelete(portIDs: Array(tui.multiSelectedResourceIDs))
        case .floatingIPs:
            batchOperation = .floatingIPBulkDelete(floatingIPIDs: Array(tui.multiSelectedResourceIDs))
        case .securityGroups:
            batchOperation = .securityGroupBulkDelete(securityGroupIDs: Array(tui.multiSelectedResourceIDs))
        case .serverGroups:
            batchOperation = .serverGroupBulkDelete(serverGroupIDs: Array(tui.multiSelectedResourceIDs))
        case .keyPairs:
            batchOperation = .keyPairBulkDelete(keyPairNames: Array(tui.multiSelectedResourceIDs))
        case .images:
            batchOperation = .imageBulkDelete(imageIDs: Array(tui.multiSelectedResourceIDs))
        default:
            tui.statusMessage = "Bulk operations not supported for \(resourceType)"
            return
        }

        let result = await tui.batchOperationManager.execute(batchOperation) { @Sendable progress in
            Task { @MainActor [weak tui] in
                tui?.statusMessage = "Deleting: \(progress.currentOperation)/\(progress.totalOperations) (\(Int(progress.completionPercentage * 100))%)"
            }
        }

        if result.status == .completed {
            tui.statusMessage = "Successfully deleted \(result.successfulOperations)/\(itemCount) \(resourceType)"
            if result.failedOperations > 0 {
                tui.statusMessage = tui.statusMessage! + " (\(result.failedOperations) failed)"
            }
        } else {
            tui.statusMessage = "Bulk delete failed: \(result.error?.localizedDescription ?? "Unknown error")"
        }

        tui.multiSelectMode = false
        tui.multiSelectedResourceIDs.removeAll()

        await tui.dataManager.refreshAllData()

        Logger.shared.logUserAction("bulk_delete_completed", details: [
            "view": "\(tui.currentView)",
            "successful": result.successfulOperations,
            "failed": result.failedOperations
        ])
    }




    private func handleServerResizeInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleServerResizeInput(ch, screen: screen)
    }

    private func handleVolumeSnapshotManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleVolumeSnapshotManagementInput(ch, screen: screen)
    }

    private func handleVolumeBackupManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        await tui.handleVolumeBackupManagementInput(ch, screen: screen)
    }

    // MARK: - Barbican Secret Input Handling
    private func handleBarbicanSecretCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Handle payload edit mode with optimized certificate processing
        if tui.barbicanSecretCreateForm.payloadEditMode {
            Logger.shared.logDebug("PAYLOAD EDIT MODE: ch=\(ch)")
            if ch == Int32(27) { // ESC - Exit payload edit mode
                tui.barbicanSecretCreateForm.exitEditMode()
                return
            }
            if let character = UnicodeScalar(UInt32(ch))?.description.first {
                await handleOptimizedPayloadInput(character)
            }
            return
        }

        // Handle regular form navigation
        await tui.handleBarbicanSecretCreateInput(ch, screen: screen)
    }

    private var lastInputTime = Date()
    private var rapidInputCount = 0
    private var isInPasteSequence = false
    private let rapidInputThreshold = 1
    private var payloadBufferTimer: AnyObject?
    private var instantFlushTimer: AnyObject?
    private var publicKeyBufferTimer: AnyObject?

    private func handleOptimizedPayloadInput(_ char: Character) async {
        guard let tui = tui else { return }

        // Add character to buffer first
        if isValidCertificateCharacter(char) {
            tui.barbicanSecretCreateForm.addToPayloadBuffer(char)
            Logger.shared.logDebug("BUFFER: Added char '\(char)', buffer size now: \(tui.barbicanSecretCreateForm.payloadBuffer.count)")
        }

        // Always use delayed flush to improve performance for any rapid input
        // Cancel any existing timer and set a new one
        if let timer = payloadBufferTimer {
            invalidateTimer(timer)
        }
        Logger.shared.logDebug("TIMER: Setting 100ms flush timer")
        payloadBufferTimer = createCompatibleTimer(interval: 0.1, repeats: false, action: { [weak self] in
            Task { @MainActor in
                Logger.shared.logDebug("TIMER: 100ms timer fired, flushing...")
                self?.flushPayloadBuffer()
            }
        })
    }


    private func readAllAvailableInput(startingWith firstChar: Character, tui: TUI) async {
        // Add the first character
        if isValidCertificateCharacter(firstChar) {
            tui.barbicanSecretCreateForm.addToPayloadBuffer(firstChar)
        }

        Logger.shared.logInfo("BULK READ: Starting bulk accumulation mode")

        // Set a longer delay to accumulate more characters before flushing
        if let timer = instantFlushTimer {
            invalidateTimer(timer)
        }
        instantFlushTimer = createCompatibleTimer(interval: 0.2, repeats: false, action: { [weak self] in
            Task { @MainActor in
                self?.flushPayloadBuffer()
                self?.isInPasteSequence = false
                guard let self = self, let tui = self.tui else { return }
                tui.barbicanSecretCreateForm.isPasteMode = false
                Logger.shared.logInfo("BULK READ: Completed paste operation")
            }
        })
    }

    private func isValidCertificateCharacter(_ char: Character) -> Bool {
        // Accept ALL Unicode scalars for maximum certificate compatibility
        // This includes all printable ASCII, control characters, and extended Unicode
        if let scalar = char.unicodeScalars.first {
            let value = scalar.value
            // Accept characters 1-255 (all printable + control characters)
            // This covers all PEM certificate requirements:
            // - Base64 characters: A-Z, a-z, 0-9, +, /, =
            // - Structural characters: -, newlines, spaces
            // - Headers/footers: BEGIN/END markers
            return value >= 1 && value <= 255
        }
        return false
    }

    @MainActor
    private func flushPayloadBuffer() {
        guard let tui = tui else { return }

        Logger.shared.logInfo("FLUSH: Starting payload buffer flush")
        let startTime = Date()

        // Flush buffer immediately and exit paste mode
        tui.barbicanSecretCreateForm.flushPayloadBuffer()

        let flushTime = Date().timeIntervalSince(startTime)
        Logger.shared.logInfo("FLUSH: Completed in \(String(format: "%.3f", flushTime))s")

        // Clear all timers
        if let timer = payloadBufferTimer {
            invalidateTimer(timer)
        }
        payloadBufferTimer = nil
        if let timer = instantFlushTimer {
            invalidateTimer(timer)
        }
        instantFlushTimer = nil

        // Reset paste sequence tracking
        isInPasteSequence = false
        rapidInputCount = 0
    }

    // MARK: - Mouse/Scroll Input Filtering
    private func isMouseOrScrollInput(_ ch: Int32) -> Bool {
        // Filter out mouse/scroll wheel character codes that may still come through
        // despite mouse reporting being disabled, but preserve all printable ASCII
        switch ch {
        case 409: // KEY_MOUSE (some terminals)
            return true
        case 410...412: // Mouse button events (some terminals)
            return true
        case 1...31: // Control characters - allow these (includes ESC at 27)
            return false
        case 32...126: // Printable ASCII range - NEVER filter these
            return false
        case 127: // DELETE key - allow this
            return false
        case 258...279: // Function keys and arrow keys - allow these
            return false
        case 330...407: // Extended function keys - allow these
            return false
        default:
            // Filter out anything else that might be mouse-related
            // This includes unusual high character codes that aren't standard keyboard input
            return ch > 500 || (ch > 127 && ch < 258)
        }
    }
}
