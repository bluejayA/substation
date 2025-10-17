import Foundation
import OSClient
import SwiftTUI
import CrossPlatformTimer

// MARK: - Input Handler
@MainActor
class InputHandler {
    private weak var tui: TUI?
    private var navigationHandler: NavigationInputHandler?

    init(tui: TUI) {
        self.tui = tui
        self.navigationHandler = NavigationInputHandler(tui: tui)
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

        // Handle modal input if a modal is active
        if tui.userFeedback.currentModal != nil {
            await handleModalInput(ch, screen: screen)
            return
        }

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

        // Swift container create form
        if tui.currentView == .swiftContainerCreate {
            await tui.handleSwiftContainerCreateInput(ch, screen: screen)
            return
        }

        // Swift container metadata form
        if tui.currentView == .swiftContainerMetadata {
            await tui.handleSwiftContainerMetadataInput(ch, screen: screen)
            return
        }

        // Swift container web access form
        if tui.currentView == .swiftContainerWebAccess {
            await tui.handleSwiftContainerWebAccessInput(ch, screen: screen)
            return
        }

        // Swift object metadata form
        if tui.currentView == .swiftObjectMetadata {
            await tui.handleSwiftObjectMetadataInput(ch, screen: screen)
            return
        }

        // Swift directory metadata form
        if tui.currentView == .swiftDirectoryMetadata {
            await tui.handleSwiftDirectoryMetadataInput(ch, screen: screen)
            return
        }

        // Swift object upload form
        if tui.currentView == .swiftObjectUpload {
            await tui.handleSwiftObjectUploadInput(ch, screen: screen)
            return
        }

        // Swift container download form
        if tui.currentView == .swiftContainerDownload {
            await tui.handleSwiftContainerDownloadInput(ch, screen: screen)
            return
        }

        // Swift object download form
        if tui.currentView == .swiftObjectDownload {
            await tui.handleSwiftObjectDownloadInput(ch, screen: screen)
            return
        }

        // Swift directory download form
        if tui.currentView == .swiftDirectoryDownload {
            await tui.handleSwiftDirectoryDownloadInput(ch, screen: screen)
            return
        }

        // NetworkCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to network create handler when in network create view
        if tui.currentView == .networkCreate {
            await tui.handleNetworkCreateInput(ch, screen: screen)
            return
        }

        // PortCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to port create handler when in port create view
        if tui.currentView == .portCreate {
            await tui.handlePortCreateInput(ch, screen: screen)
            return
        }

        // SubnetCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to subnet create handler when in subnet create view
        if tui.currentView == .subnetCreate {
            await tui.handleSubnetCreateInput(ch, screen: screen)
            return
        }

        // SecurityGroupCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to security group create handler when in security group create view
        if tui.currentView == .securityGroupCreate {
            await tui.handleSecurityGroupCreateInput(ch, screen: screen)
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

        // ServerGroupCreateForm uses FormBuilder which handles its own input state
        // Delegate all input to server group create handler when in server group create view
        if tui.currentView == .serverGroupCreate {
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

        // UNIVERSAL SEARCH: Handle / key for all views before specialized routing
        if ch == Int32(47) { // / - search or filter
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
            return
        }

        // Route to specialized view handlers
        // ESC navigation is now handled by NavigationInputHandler via isDetailView check
        switch tui.currentView {
        case .serverSecurityGroups:
            await tui.handleSecurityGroupInput(ch, screen: screen)
            return
        case .securityGroupRuleManagement:
            await tui.handleSecurityGroupRuleManagementInput(ch, screen: screen)
            return
        case .serverResize:
            await tui.handleServerResizeInput(ch, screen: screen)
            return
        case .serverSnapshotManagement:
            await tui.handleSnapshotManagementInput(ch, screen: screen)
            return
        case .volumeSnapshotManagement:
            await tui.handleVolumeSnapshotManagementInput(ch, screen: screen)
            return
        case .volumeBackupManagement:
            await tui.handleVolumeBackupManagementInput(ch, screen: screen)
            return
        case .serverNetworkInterfaces:
            await tui.handleNetworkInterfaceInput(ch, screen: screen)
            return
        case .volumeManagement:
            await tui.handleVolumeManagementInput(ch, screen: screen)
            return
        case .networkServerAttachment:
            await tui.handleNetworkServerAttachmentInput(ch, screen: screen)
            return
        case .securityGroupServerAttachment:
            await tui.handleSecurityGroupServerAttachmentInput(ch, screen: screen)
            return
        case .securityGroupServerManagement:
            await tui.handleSecurityGroupServerManagementInput(ch, screen: screen)
            return
        case .networkServerManagement:
            await tui.handleNetworkServerManagementInput(ch, screen: screen)
            return
        case .volumeServerManagement:
            await tui.handleVolumeServerManagementInput(ch, screen: screen)
            return
        case .floatingIPServerManagement:
            await tui.handleFloatingIPServerManagementInput(ch, screen: screen)
            return
        case .floatingIPPortManagement:
            await tui.handleFloatingIPPortManagementInput(ch, screen: screen)
            return
        case .portServerManagement:
            await tui.handlePortServerManagementInput(ch, screen: screen)
            return
        case .portAllowedAddressPairManagement:
            await tui.handleAllowedAddressPairManagementInput(ch, screen: screen)
            return
        case .flavorSelection:
            await tui.handleFlavorSelectionInput(ch, screen: screen)
            return
        case .subnetRouterManagement:
            await tui.handleSubnetRouterManagementInput(ch, screen: screen)
            return
        default:
            break
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

                case .executeAction(let actionType):
                    // Execute an action in the current context
                    let success = await CommandActionHandler.shared.executeAction(actionType, in: tui.currentView, tui: tui, screen: screen)
                    if success {
                        tui.statusMessage = "Executed action: \(actionType.rawValue)"
                    }
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .configAction(let configAction):
                    // Handle configuration actions
                    handleConfigAction(configAction)
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .showTutorial:
                    // Show interactive tutorial view
                    tui.changeView(to: .tutorial, resetSelection: true)
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .showShortcuts:
                    // Show shortcuts reference view
                    tui.changeView(to: .shortcuts, resetSelection: true)
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .showExamples:
                    // Show command examples view
                    tui.changeView(to: .examples, resetSelection: true)
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
                    return

                case .showWelcome:
                    // Show welcome view
                    tui.changeView(to: .welcome, resetSelection: true)
                    tui.unifiedInputState.clear()
                    tui.forceRedraw()
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

        // PRIORITY 3: Universal key navigation (command-based)
        // Letter keys trigger helpful hints to use command mode
        if (ch >= 97 && ch <= 122) || (ch >= 65 && ch <= 90) { // a-z or A-Z (excluding special uppercase actions)
            // Check if this is a context-sensitive uppercase action that should be handled
            let isContextAction = (ch == 77 || ch == 68 || ch == 85 || ch == 69 || ch == 80 ||
                                   ch == 66 || ch == 82 || ch == 83 || ch == 84 || ch == 76 ||
                                   ch == 79 || ch == 87 || ch == 90 || ch == 65 || ch == 67)
            if !isContextAction {
                tui.statusMessage = "Use commands for navigation (type : and press Tab for suggestions)"
            }
            // Allow context actions and universal keys to continue below
        }

        switch ch {
        case Int32(3): // CTRL-C - Universal quit
            Logger.shared.logUserAction("quit_application")
            tui.running = false

        case Int32(24): // CTRL-X - Toggle multi-select mode
            if !tui.currentView.isDetailView && tui.currentView.supportsMultiSelect {
                Logger.shared.logUserAction("toggle_multi_select_mode", details: [
                    "view": "\(tui.currentView)",
                    "wasEnabled": tui.multiSelectMode
                ])
                handleToggleMultiSelectMode()
            }
        case Int32(87): // W - Web Access
            if tui.currentView == .swift && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_container_web_access", details: ["selectedIndex": tui.selectedIndex])
                await handleManageContainerWebAccess(screen: screen)
            }
        case Int32(77): // M - Manage things or Performance Metrics
            if tui.currentView == .swiftBackgroundOperations && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("show_performance_metrics", details: ["view": "swiftBackgroundOperations"])
                Logger.shared.logNavigation("\(tui.currentView)", to: ".performanceMetrics")
                tui.scrollOffset = 0 // Reset scroll when entering metrics view
                tui.changeView(to: .performanceMetrics, resetSelection: false)
            } else if tui.currentView == .swift && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_container_metadata", details: ["selectedIndex": tui.selectedIndex])
                await handleManageContainerMetadata(screen: screen)
            } else if tui.currentView == .swiftContainerDetail && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_tree_item_metadata", details: ["selectedIndex": tui.selectedIndex])
                await handleSwiftTreeItemMetadata(screen: screen)
            } else if tui.currentView == .securityGroups && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_security_group_rules", details: ["selectedIndex": tui.selectedIndex])
                await handleManageSecurityGroupRules(screen: screen)
            } else if tui.currentView == .floatingIPs && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_floating_ip_server_assignment", details: ["selectedIndex": tui.selectedIndex])
                await handleManageFloatingIPServerAssignment(screen: screen)
            } else if tui.currentView == .ports && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_port_server_assignment", details: ["selectedIndex": tui.selectedIndex])
                await handleManagePortServerAssignment(screen: screen)
            } else if tui.currentView == .networks && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_network_to_server", details: ["selectedIndex": tui.selectedIndex])
                await handleManageNetworkInterfaceAttachmentToServer(screen: screen)
            } else if tui.currentView == .securityGroups && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_security_group", details: ["selectedIndex": tui.selectedIndex])
                await handleAttachSecurityGroup(screen: screen)
            } else if tui.currentView == .volumes && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_volume", details: ["selectedIndex": tui.selectedIndex])
                await handleAttachVolume(screen: screen)
            } else if tui.currentView == .subnets && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_subnet_router", details: ["selectedIndex": tui.selectedIndex])
                await handleAttachSubnetRouter(screen: screen)
            }
        case Int32(69): // E - Manage allowed address pairs for ports (SHIFT-E)
            if tui.currentView == .ports && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_port_allowed_address_pairs", details: ["selectedIndex": tui.selectedIndex])
                await handleManagePortAllowedAddressPairs(screen: screen)
            }
        case Int32(85): // U - Upload object to container (SHIFT-U)
            if tui.currentView == .swift && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("upload_object_to_container", details: ["selectedIndex": tui.selectedIndex])
                await handleUploadObjectToContainer(screen: screen)
            } else if tui.currentView == .swiftContainerDetail {
                // From container detail view (inside a container), also allow upload
                Logger.shared.logUserAction("upload_object_to_container_from_detail", details: ["container": tui.swiftNavState.currentContainer ?? "unknown"])
                await handleUploadObjectToContainer(screen: screen)
            }
        case Int32(68): // D - Download container or object (SHIFT-D)
            if tui.currentView == .swift && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("download_container", details: ["selectedIndex": tui.selectedIndex])
                await handleDownloadContainer(screen: screen)
            } else if tui.currentView == .swiftContainerDetail && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("download_object", details: ["selectedIndex": tui.selectedIndex])
                await handleDownloadObject(screen: screen)
            }
        case Int32(259), Int32(258), Int32(338), Int32(339), Int32(262), Int32(360), Int32(27): // Navigation keys
            // Use centralized navigation handler for all basic navigation
            if let navigationHandler = navigationHandler {
                // For swiftBackgroundOperations, pass the actual count of operations
                let maxIndex: Int?
                if tui.currentView == .swiftBackgroundOperations {
                    maxIndex = max(0, tui.swiftBackgroundOps.getAllOperations().count - 1)
                } else {
                    maxIndex = nil
                }

                let handled = await navigationHandler.handleNavigationInput(ch, screen: screen, maxIndex: maxIndex)
                if handled {
                    return // Navigation was handled centrally
                }
            }
            // If not handled centrally, fall through to view-specific handling
            break
        case Int32(32): // SPACEBAR - Toggle item selection in multi-select mode or show details
            if tui.multiSelectMode && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("toggle_multi_select_item", details: [
                    "view": "\(tui.currentView)",
                    "selectedIndex": tui.selectedIndex
                ])
                await handleMultiSelectToggle()
            } else if !tui.currentView.isDetailView {
                // Special handling for Swift hierarchical navigation
                if tui.currentView == .swift {
                    Logger.shared.logUserAction("swift_navigate_into_container", details: [
                        "selectedIndex": tui.selectedIndex
                    ])
                    await handleSwiftContainerNavigation()
                } else if tui.currentView == .swiftContainerDetail {
                    Logger.shared.logUserAction("swift_navigate_into_item", details: [
                        "selectedIndex": tui.selectedIndex,
                        "currentPath": tui.swiftNavState.currentPathString
                    ])
                    await handleSwiftTreeItemNavigation()
                } else if tui.currentView == .swiftBackgroundOperations {
                    Logger.shared.logUserAction("open_operation_detail", details: [
                        "selectedIndex": tui.selectedIndex
                    ])
                    await handleOpenOperationDetail()
                } else {
                    Logger.shared.logUserAction("open_detail_view", details: [
                        "view": "\(tui.currentView)",
                        "selectedIndex": tui.selectedIndex
                    ])
                    tui.openDetailView()
                }
            }
        // NOTE: / key (Int32(47)) is now handled universally before specialized view routing
        // Context-Sensitive Actions (Uppercase letters)
        case Int32(67): // C - Create new resource
            Logger.shared.logUserAction("create_action", details: ["view": "\(tui.currentView)", "selectedIndex": tui.selectedIndex])
            await handleCreateResource()
        case Int32(76): // L - View server logs
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("view_server_logs", details: ["selectedIndex": tui.selectedIndex])
                await handleViewServerLogs(screen: screen)
            }
        case Int32(79): // O - View server console or open console in browser
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("view_server_console", details: ["selectedIndex": tui.selectedIndex])
                await handleViewServerConsole(screen: screen)
            } else if tui.currentView == .serverConsole {
                Logger.shared.logUserAction("open_console_in_browser")
                await handleOpenConsoleInBrowser()
            }
        case Int32(66): // B - Create backup (volume)
            if tui.currentView == .volumes && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("create_volume_backup", details: ["selectedIndex": tui.selectedIndex])
                await handleVolumeBackup(screen: screen)
            }
        case Int32(80): // P - Create snapshot or Manage floating IP port assignment
            if tui.currentView == .servers && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("create_snapshot", details: ["selectedIndex": tui.selectedIndex])
                await handleCreateSnapshot(screen: screen)
            } else if tui.currentView == .volumes && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("create_volume_snapshot", details: ["selectedIndex": tui.selectedIndex])
                await tui.resourceOperations.createVolumeSnapshot(screen: screen)
            } else if tui.currentView == .floatingIPs && !tui.currentView.isDetailView {
                Logger.shared.logUserAction("manage_floating_ip_port_assignment", details: ["selectedIndex": tui.selectedIndex])
                await handleManageFloatingIPPortAssignment(screen: screen)
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
                tui.changeView(to: .help, resetSelection: false)
            }
        case Int32(64): // @ - Show about page
            if tui.currentView != .about {
                Logger.shared.logNavigation("\(tui.currentView)", to: ".about")
                tui.helpScrollOffset = 0 // Reset scroll when entering about
                tui.changeView(to: .about, resetSelection: false)
            }
        case Int32(127), Int32(330): // DELETE key - Delete resources
            Logger.shared.logUserAction("delete_action", details: ["view": "\(tui.currentView)", "selectedIndex": tui.selectedIndex])
            await handleDeleteKey(screen: screen)
        case Int32(90): // Z - Resize selected server
            Logger.shared.logUserAction("resize_server", details: ["selectedIndex": tui.selectedIndex])
            await handleResizeServer(screen: screen)
        case Int32(65): // A - Cycle refresh interval
            Logger.shared.logUserAction("cycle_refresh_interval", details: ["currentInterval": tui.baseRefreshInterval])
            tui.cycleRefreshInterval()
        default:
            Logger.shared.logUserAction("unhandled_key", details: ["keyCode": ch, "view": "\(tui.currentView)"])
            break
        }

        // Handle form-specific inputs after main input handling
        await handleFormInputs(ch, screen: screen)
    }

    // MARK: - Resource Action Methods
    // NOTE: Basic navigation (UP/DOWN/PAGE UP/PAGE DOWN/HOME/END/ESC) is now handled by NavigationInputHandler
    // View-specific navigation overrides should be handled in individual view handlers when needed

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
            tui.barbicanSecretCreateFormState = FormBuilderState(fields: tui.barbicanSecretCreateForm.buildFields(
                selectedFieldId: BarbicanSecretCreateFieldId.name.rawValue,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.currentView == .octavia && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".octaviaLoadBalancerCreate")
            tui.changeView(to: .octaviaLoadBalancerCreate)
        } else if tui.currentView == .swift && !tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: ".swiftContainerCreate")
            tui.changeView(to: .swiftContainerCreate)

            // Initialize Swift container create form
            tui.swiftContainerCreateForm = SwiftContainerCreateForm()
            tui.swiftContainerCreateFormState = FormBuilderState(
                fields: tui.swiftContainerCreateForm.buildFields(
                    selectedFieldId: "containerName",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )
        }
    }

    // MARK: - Action Helper Methods
    private func handleRefreshKey() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("refresh_initiated", details: ["view": "\(tui.currentView)"])
        let startTime = Date()

        // Full data refresh
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

        let duration = Date().timeIntervalSince(startTime)
        Logger.shared.logPerformance("refresh_completed", duration: duration, context: [
            "view": "\(tui.currentView)",
            "refreshType": "full_data"
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
            // Ports are sorted in the view, so we need to use the filtered/sorted list
            let filteredPorts = FilterUtils.filterPorts(tui.cachedPorts, query: tui.searchQuery)
            guard tui.selectedIndex < filteredPorts.count else { return "" }
            return filteredPorts[tui.selectedIndex].id
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
        case .volumeArchives:
            guard tui.selectedIndex < tui.cachedVolumeBackups.count else { return "" }
            return tui.cachedVolumeBackups[tui.selectedIndex].id
        case .barbicanSecrets, .barbican:
            guard tui.selectedIndex < tui.cachedSecrets.count else { return "" }
            return tui.cachedSecrets[tui.selectedIndex].secretRef ?? ""
        case .swift:
            guard tui.selectedIndex < tui.cachedSwiftContainers.count else { return "" }
            return tui.cachedSwiftContainers[tui.selectedIndex].id
        case .swiftContainerDetail:
            guard let objects = tui.cachedSwiftObjects else { return "" }
            // Build tree structure to match what's displayed
            let currentPath = tui.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)
            // Apply search filter if present
            let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)
            guard tui.selectedIndex < filteredItems.count else { return "" }
            return filteredItems[tui.selectedIndex].id
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
        } else if tui.currentView == .swift && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteSwiftContainer(screen: screen)
        } else if tui.currentView == .swiftContainerDetail && !tui.currentView.isDetailView {
            await tui.resourceOperations.deleteSwiftObject(screen: screen)
        } else if tui.currentView == .swiftBackgroundOperations && !tui.currentView.isDetailView {
            await handleCancelBackgroundOperation(screen: screen)
        } else if tui.currentView == .swiftBackgroundOperationDetail {
            await handleCancelBackgroundOperationFromDetail(screen: screen)
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

    private func handleViewServerConsole(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .servers && !tui.currentView.isDetailView {
            await tui.actions.viewServerConsole(screen: screen)
        }
    }

    private func handleOpenConsoleInBrowser() async {
        guard let tui = tui else { return }

        if let console = tui.selectedResource as? RemoteConsole {
            if console.type.lowercased() == "novnc" {
                await openURLInBrowser(console.url)
                tui.statusMessage = "Opening console in default browser..."
            } else {
                tui.statusMessage = "Browser opening only supported for noVNC consoles"
            }
        }
    }

    private func openURLInBrowser(_ url: String) async {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
        #elseif os(Linux)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        process.arguments = [url]
        try? process.run()
        #endif
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

    private func handleManageNetworkInterfaceAttachmentToServer(screen: OpaquePointer?) async {
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

    private func handleManageContainerMetadata(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .swift && !tui.currentView.isDetailView {
            guard tui.selectedIndex < tui.cachedSwiftContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = tui.cachedSwiftContainers[tui.selectedIndex]
            guard let containerName = container.name else {
                tui.statusMessage = "Invalid container"
                return
            }

            // Fetch current metadata
            do {
                let metadata = try await tui.client.swift.getContainerMetadata(containerName: containerName)

                // Initialize form with current metadata
                tui.swiftContainerMetadataForm = SwiftContainerMetadataForm()
                tui.swiftContainerMetadataForm.loadFromMetadata(metadata)

                // Initialize form state
                tui.swiftContainerMetadataFormState = FormBuilderState(
                    fields: tui.swiftContainerMetadataForm.buildFields(
                        selectedFieldId: "readACL",
                        activeFieldId: nil,
                        formState: FormBuilderState(fields: [])
                    )
                )

                // Navigate to metadata form
                tui.changeView(to: .swiftContainerMetadata, resetSelection: false)
            } catch {
                tui.statusMessage = "Failed to load metadata: \(error.localizedDescription)"
            }
        }
    }

    private func handleSwiftTreeItemMetadata(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .swiftContainerDetail && !tui.currentView.isDetailView {
            guard let containerName = tui.swiftNavState.currentContainer else {
                tui.statusMessage = "No container selected"
                return
            }

            guard let allObjects = tui.cachedSwiftObjects else {
                tui.statusMessage = "No objects loaded"
                return
            }

            // Build tree from objects
            let currentPath = tui.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)

            guard tui.selectedIndex < treeItems.count else {
                tui.statusMessage = "No item selected"
                return
            }

            let selectedItem = treeItems[tui.selectedIndex]

            switch selectedItem {
            case .object(let object):
                // Handle individual object metadata
                guard let objectName = object.name else {
                    tui.statusMessage = "Invalid object"
                    return
                }

                // Fetch current metadata
                do {
                    let metadata = try await tui.client.swift.getObjectMetadata(
                        containerName: containerName,
                        objectName: objectName
                    )

                    // Initialize form with current metadata
                    tui.swiftObjectMetadataForm = SwiftObjectMetadataForm()
                    tui.swiftObjectMetadataForm.loadFromMetadata(containerName: containerName, metadata: metadata)

                    // Initialize form state
                    tui.swiftObjectMetadataFormState = FormBuilderState(
                        fields: tui.swiftObjectMetadataForm.buildFields(
                            selectedFieldId: "contentType",
                            activeFieldId: nil,
                            formState: FormBuilderState(fields: [])
                        )
                    )

                    // Navigate to metadata form
                    tui.changeView(to: .swiftObjectMetadata, resetSelection: false)
                } catch {
                    tui.statusMessage = "Failed to load metadata: \(error.localizedDescription)"
                }

            case .directory(let name, _, _):
                // Handle directory metadata (bulk update)
                let fullDirectoryPath = currentPath + name + "/"

                // Initialize directory metadata form
                tui.swiftDirectoryMetadataForm = SwiftDirectoryMetadataForm()
                tui.swiftDirectoryMetadataForm.initializeForDirectory(
                    containerName: containerName,
                    directoryPath: fullDirectoryPath
                )

                // Initialize form state
                tui.swiftDirectoryMetadataFormState = FormBuilderState(
                    fields: tui.swiftDirectoryMetadataForm.buildFields(
                        selectedFieldId: "contentType",
                        activeFieldId: nil,
                        formState: FormBuilderState(fields: [])
                    )
                )

                // Navigate to directory metadata form
                tui.changeView(to: .swiftDirectoryMetadata, resetSelection: false)
            }
        }
    }

    private func handleManageContainerWebAccess(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .swift && !tui.currentView.isDetailView {
            guard tui.selectedIndex < tui.cachedSwiftContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = tui.cachedSwiftContainers[tui.selectedIndex]
            guard let containerName = container.name else {
                tui.statusMessage = "Invalid container"
                return
            }

            // Fetch current metadata to check web access status
            do {
                let metadata = try await tui.client.swift.getContainerMetadata(containerName: containerName)

                // Get Swift storage URL
                let swiftEndpoint: String
                do {
                    swiftEndpoint = try await tui.client.coreClient.getEndpoint(for: "object-store")
                } catch {
                    tui.statusMessage = "Could not determine Swift endpoint"
                    return
                }

                // Load form with metadata and endpoint (container name is stored in the form)
                tui.swiftContainerWebAccessForm.loadFromMetadata(metadata, swiftEndpoint: swiftEndpoint)

                // Initialize form state
                tui.swiftContainerWebAccessFormState = FormBuilderState(
                    fields: tui.swiftContainerWebAccessForm.buildFields(
                        selectedFieldId: "webAccessEnabled",
                        activeFieldId: nil,
                        formState: FormBuilderState(fields: [])
                    )
                )

                // Navigate to web access form
                tui.changeView(to: .swiftContainerWebAccess, resetSelection: false)
            } catch {
                tui.statusMessage = "Failed to load web access form: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Form Input Handling
    private func handleFormInputs(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // NOTE: ServerCreate, KeyPairCreate, VolumeCreate, NetworkCreate, SecurityGroupCreate are handled earlier with early return
        // to prevent the main input handler from interfering with text input

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

    private func handleManageFloatingIPPortAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .floatingIPs && !tui.currentView.isDetailView {
            await tui.actions.manageFloatingIPPortAssignment(screen: screen)
        }
    }

    private func handleManagePortServerAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .ports && !tui.currentView.isDetailView {
            await tui.actions.managePortServerAssignment(screen: screen)
        }
    }

    private func handleManagePortAllowedAddressPairs(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .ports && !tui.currentView.isDetailView {
            await tui.actions.managePortAllowedAddressPairs(screen: screen)
        }
    }

    private func handleAttachSubnetRouter(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .subnets && !tui.currentView.isDetailView {
            await tui.actions.manageSubnetRouterAttachment(screen: screen)
        }
    }

    private func handleUploadObjectToContainer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let containerName: String

        if tui.currentView == .swift && !tui.currentView.isDetailView {
            // Called from container list - get selected container
            guard tui.selectedIndex < tui.cachedSwiftContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = tui.cachedSwiftContainers[tui.selectedIndex]
            guard let name = container.name else {
                tui.statusMessage = "Invalid container"
                return
            }
            containerName = name

        } else if tui.currentView == .swiftContainerDetail {
            // Called from inside a container - use current container from navigation state
            guard let currentContainer = tui.swiftNavState.currentContainer else {
                tui.statusMessage = "No container context"
                return
            }
            containerName = currentContainer

        } else {
            tui.statusMessage = "Upload not available from this view"
            return
        }

        // Initialize upload form
        tui.swiftObjectUploadForm = SwiftObjectUploadForm()
        tui.swiftObjectUploadForm.containerName = containerName

        // Initialize form state
        tui.swiftObjectUploadFormState = FormBuilderState(
            fields: tui.swiftObjectUploadForm.buildFields(
                selectedFieldId: "filePath",
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            )
        )

        // Navigate to upload form
        tui.changeView(to: .swiftObjectUpload, resetSelection: false)
    }

    private func handleDownloadContainer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .swift && !tui.currentView.isDetailView {
            guard tui.selectedIndex < tui.cachedSwiftContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = tui.cachedSwiftContainers[tui.selectedIndex]
            guard let containerName = container.name else {
                tui.statusMessage = "Invalid container"
                return
            }

            // Initialize download form
            tui.swiftContainerDownloadForm = SwiftContainerDownloadForm()
            tui.swiftContainerDownloadForm.containerName = containerName
            tui.swiftContainerDownloadForm.destinationPath = "./\(containerName)/"

            // Initialize form state
            tui.swiftContainerDownloadFormState = FormBuilderState(
                fields: tui.swiftContainerDownloadForm.buildFields(
                    selectedFieldId: "destinationPath",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )

            // Navigate to download form
            tui.changeView(to: .swiftContainerDownload, resetSelection: false)
        }
    }

    private func handleDownloadObject(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.currentView == .swiftContainerDetail && !tui.currentView.isDetailView {
            guard let containerName = tui.swiftNavState.currentContainer else {
                tui.statusMessage = "No container selected"
                return
            }

            guard let allObjects = tui.cachedSwiftObjects else {
                tui.statusMessage = "No objects loaded"
                return
            }

            // Build tree from objects
            let currentPath = tui.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)

            // Apply search filter if present
            let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)

            guard tui.selectedIndex < filteredItems.count else {
                tui.statusMessage = "No item selected"
                return
            }

            let selectedItem = filteredItems[tui.selectedIndex]

            switch selectedItem {
            case .object(let object):
                // Download single object
                guard let objectName = object.name else {
                    tui.statusMessage = "Invalid object"
                    return
                }

                // Extract just the filename from the full path
                let fileName: String
                if let lastSlash = objectName.lastIndex(of: "/") {
                    fileName = String(objectName[objectName.index(after: lastSlash)...])
                } else {
                    fileName = objectName
                }

                // Initialize download form
                tui.swiftObjectDownloadForm = SwiftObjectDownloadForm()
                tui.swiftObjectDownloadForm.containerName = containerName
                tui.swiftObjectDownloadForm.objectName = objectName
                tui.swiftObjectDownloadForm.destinationPath = "./\(fileName)"

                // Initialize form state
                tui.swiftObjectDownloadFormState = FormBuilderState(
                    fields: tui.swiftObjectDownloadForm.buildFields(
                        selectedFieldId: "destinationPath",
                        activeFieldId: nil,
                        formState: FormBuilderState(fields: [])
                    )
                )

                // Navigate to object download form
                tui.changeView(to: .swiftObjectDownload, resetSelection: false)

            case .directory(let directoryName, _, _):
                // Download entire directory
                let fullDirectoryPath = currentPath + directoryName + "/"

                // Initialize directory download form
                tui.swiftDirectoryDownloadForm = SwiftDirectoryDownloadForm()
                tui.swiftDirectoryDownloadForm.containerName = containerName
                tui.swiftDirectoryDownloadForm.directoryPath = fullDirectoryPath
                tui.swiftDirectoryDownloadForm.destinationPath = "./\(directoryName)/"
                tui.swiftDirectoryDownloadForm.preserveStructure = true

                // Initialize form state
                tui.swiftDirectoryDownloadFormState = FormBuilderState(
                    fields: tui.swiftDirectoryDownloadForm.buildFields(
                        selectedFieldId: "destinationPath",
                        activeFieldId: nil,
                        formState: FormBuilderState(fields: [])
                    )
                )

                // Navigate to directory download form
                tui.changeView(to: .swiftDirectoryDownload, resetSelection: false)
            }
        }
    }

    private func handleSimpleBulkDelete(resourceIDs: [String], screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let itemCount = resourceIDs.count
        var successCount = 0
        var failCount = 0

        for (index, resourceID) in resourceIDs.enumerated() {
            tui.statusMessage = "Deleting \(index + 1)/\(itemCount)..."

            do {
                switch tui.currentView {
                case .volumeArchives:
                    try await tui.client.deleteVolumeBackup(backupId: resourceID)
                case .barbicanSecrets, .barbican:
                    try await tui.client.barbican.deleteSecret(id: resourceID)
                case .swift:
                    try await tui.client.swift.deleteContainer(containerName: resourceID)
                case .swiftContainerDetail:
                    guard let container = tui.selectedResource as? SwiftContainer, let containerName = container.name else {
                        tui.statusMessage = "No container selected"
                        return
                    }
                    try await tui.client.swift.deleteObject(containerName: containerName, objectName: resourceID)
                case .flavors:
                    // Flavors don't support deletion (managed by cloud admin)
                    tui.statusMessage = "Flavors cannot be deleted"
                    return
                default:
                    break
                }
                successCount += 1
            } catch {
                failCount += 1
                Logger.shared.logError("Failed to delete resource \(resourceID): \(error)")
            }
        }

        if failCount == 0 {
            tui.statusMessage = "Successfully deleted \(successCount) items"
        } else {
            tui.statusMessage = "Deleted \(successCount) items (\(failCount) failed)"
        }

        tui.multiSelectMode = false
        tui.multiSelectedResourceIDs.removeAll()
        await tui.dataManager.refreshAllData()
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
        case .volumeArchives, .barbicanSecrets, .barbican, .swift, .swiftContainerDetail:
            // These resources don't have BatchOperation support yet, handle them directly
            await handleSimpleBulkDelete(resourceIDs: Array(tui.multiSelectedResourceIDs), screen: screen)
            return
        case .flavors:
            // Flavors don't support deletion
            tui.statusMessage = "Bulk operations not supported for flavors (cloud admin only)"
            return
        default:
            tui.statusMessage = "Bulk operations not supported for \(resourceType)"
            return
        }

        // Create background operation
        let backgroundOp = SwiftBackgroundOperation(
            type: .bulkDelete,
            resourceType: resourceType,
            itemsTotal: itemCount
        )

        // Add to background operations manager
        tui.swiftBackgroundOps.addOperation(backgroundOp)

        // Exit multi-select mode immediately
        tui.multiSelectMode = false
        tui.multiSelectedResourceIDs.removeAll()

        // Show status message and stay on current view
        tui.statusMessage = "Started bulk delete of \(itemCount) \(resourceType) in background"

        // Launch background task
        let task = Task { @MainActor [weak tui, weak backgroundOp] in
            guard let tui = tui, let backgroundOp = backgroundOp else { return }

            backgroundOp.status = .running

            let result = await tui.batchOperationManager.execute(batchOperation) { @Sendable progress in
                Task { @MainActor [weak backgroundOp] in
                    guard let backgroundOp = backgroundOp else { return }
                    backgroundOp.itemsCompleted = progress.currentOperation
                    backgroundOp.progress = progress.completionPercentage
                }
            }

            // Update background operation with final results
            backgroundOp.itemsCompleted = result.successfulOperations
            backgroundOp.itemsFailed = result.failedOperations

            // Mark as completed if batch completed (even with some failures)
            // Individual failures are tracked via itemsFailed count
            if result.status == .completed || result.status == .failed {
                if result.failedOperations == result.totalOperations {
                    // All operations failed - mark as failed with error
                    let errorMsg = result.error?.localizedDescription ?? "All \(result.totalOperations) operations failed"
                    backgroundOp.markFailed(error: errorMsg)
                } else {
                    // At least some succeeded - mark as completed
                    backgroundOp.markCompleted()
                }
            } else if result.status == .cancelled {
                backgroundOp.status = .cancelled
            } else {
                // Unexpected status
                backgroundOp.markFailed(error: "Unexpected status: \(result.status.rawValue)")
            }

            // Refresh data after completion
            await tui.dataManager.refreshAllData()

            Logger.shared.logUserAction("bulk_delete_completed", details: [
                "view": "\(tui.currentView)",
                "successful": result.successfulOperations,
                "failed": result.failedOperations
            ])
        }

        backgroundOp.task = task
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

    // MARK: - Swift Hierarchical Navigation Handlers

    /// Handle SPACEBAR navigation when at container list level
    private func handleSwiftContainerNavigation() async {
        guard let tui = tui else { return }

        guard tui.selectedIndex < tui.cachedSwiftContainers.count else {
            tui.statusMessage = "No container selected"
            return
        }

        let container = tui.cachedSwiftContainers[tui.selectedIndex]
        guard let containerName = container.name else {
            tui.statusMessage = "Invalid container"
            return
        }

        Logger.shared.logInfo("Navigating into container: \(containerName)")

        // Update navigation state
        tui.swiftNavState.navigateIntoContainer(containerName)

        // Change to container detail view
        tui.changeView(to: .swiftContainerDetail, resetSelection: true)

        // Load objects for this container
        await tui.dataManager.fetchSwiftObjects(containerName: containerName, priority: "interactive")

        Logger.shared.logInfo("Container navigation complete, showing \(tui.cachedSwiftObjects?.count ?? 0) objects")
    }

    /// Handle SPACEBAR navigation when in container detail view (tree items)
    private func handleSwiftTreeItemNavigation() async {
        guard let tui = tui else { return }

        guard let objects = tui.cachedSwiftObjects else {
            tui.statusMessage = "No objects loaded"
            return
        }

        let currentPath = tui.swiftNavState.currentPathString

        // Build tree structure
        let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)

        // Apply search filter if present
        let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)

        guard tui.selectedIndex < filteredItems.count else {
            tui.statusMessage = "No item selected"
            return
        }

        let selectedItem = filteredItems[tui.selectedIndex]

        switch selectedItem {
        case .directory(let directoryName, _, _):
            // Navigate into directory
            Logger.shared.logInfo("Navigating into directory: \(directoryName)")
            tui.swiftNavState.navigateIntoDirectory(directoryName)

            // Reset selection to top
            tui.selectedIndex = 0
            tui.scrollOffset = 0

            // Stay in the same view (swiftContainerDetail)
            tui.markNeedsRedraw()

            Logger.shared.logInfo("Directory navigation complete, new path: \(tui.swiftNavState.currentPathString)")

        case .object(let object):
            // Open object detail view
            Logger.shared.logInfo("Opening object detail: \(object.name ?? "unknown")")
            tui.selectedResource = object
            tui.changeView(to: .swiftObjectDetail, resetSelection: false)
            tui.detailScrollOffset = 0
        }
    }

    // MARK: - Swift Background Operations Helpers

    private func handleOpenOperationDetail() async {
        guard let tui = tui else { return }

        let operations = tui.swiftBackgroundOps.getAllOperations()
        guard tui.selectedIndex < operations.count else {
            tui.statusMessage = "No operation selected"
            return
        }

        let operation = operations[tui.selectedIndex]
        tui.selectedResource = operation
        tui.changeView(to: .swiftBackgroundOperationDetail, resetSelection: false)
        tui.detailScrollOffset = 0
    }

    /// Handles DELETE key in background operations view with context-aware behavior
    /// - If operation is active (running/queued): Cancel it
    /// - If operation is inactive (completed/failed/cancelled): Remove it from history
    private func handleCancelBackgroundOperation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let operations = tui.swiftBackgroundOps.getAllOperations()
        guard tui.selectedIndex < operations.count else {
            tui.statusMessage = "No operation selected"
            await tui.draw(screen: screen)
            return
        }

        let operation = operations[tui.selectedIndex]

        // Context-aware behavior based on operation status
        if operation.status.isActive {
            // Active operation: Cancel it
            let operationDesc = operation.displayName
            let confirmed = await ViewUtils.confirmOperation(
                title: "Cancel Operation",
                message: "Cancel '\(operationDesc)'?",
                details: [
                    "Type: \(operation.type.displayName)",
                    "Status: \(operation.status.displayName)",
                    "Progress: \(operation.progressPercentage)%"
                ],
                screen: screen,
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            )

            guard confirmed else {
                tui.statusMessage = "Cancellation aborted"
                await tui.draw(screen: screen)
                return
            }

            operation.cancel()
            tui.statusMessage = "Operation cancelled: \(operation.displayName)"
            Logger.shared.logUserAction("cancel_background_operation", details: [
                "operationId": operation.id.uuidString,
                "type": "\(operation.type)",
                "objectName": operation.objectName ?? "unknown"
            ])
        } else {
            // Inactive operation: Remove from history
            let operationDesc = operation.displayName
            let confirmed = await ViewUtils.confirmOperation(
                title: "Remove Operation",
                message: "Remove '\(operationDesc)' from history?",
                details: [
                    "Type: \(operation.type.displayName)",
                    "Status: \(operation.status.displayName)"
                ],
                screen: screen,
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            )

            guard confirmed else {
                tui.statusMessage = "Removal aborted"
                await tui.draw(screen: screen)
                return
            }

            tui.swiftBackgroundOps.removeOperation(id: operation.id)

            // Reset selection immediately after removal
            let remainingOps = tui.swiftBackgroundOps.getAllOperations()
            if tui.selectedIndex >= remainingOps.count {
                tui.selectedIndex = max(0, remainingOps.count - 1)
            }

            // Force full screen refresh to immediately show the removal
            tui.renderOptimizer.markFullScreenDirty()

            tui.statusMessage = "Removed operation: \(operation.displayName)"
            Logger.shared.logUserAction("remove_background_operation", details: [
                "operationId": operation.id.uuidString,
                "type": "\(operation.type)",
                "status": "\(operation.status)",
                "objectName": operation.objectName ?? "unknown"
            ])
        }

        await tui.draw(screen: screen)
    }

    /// Handles DELETE key in background operation detail view with context-aware behavior
    /// - If operation is active (running/queued): Cancel it
    /// - If operation is inactive (completed/failed/cancelled): Remove it from history and return to list
    private func handleCancelBackgroundOperationFromDetail(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard let operation = tui.selectedResource as? SwiftBackgroundOperation else {
            tui.statusMessage = "No operation selected"
            await tui.draw(screen: screen)
            return
        }

        // Context-aware behavior based on operation status
        if operation.status.isActive {
            // Active operation: Cancel it
            let operationDesc = operation.displayName
            let confirmed = await ViewUtils.confirmOperation(
                title: "Cancel Operation",
                message: "Cancel '\(operationDesc)'?",
                details: [
                    "Type: \(operation.type.displayName)",
                    "Status: \(operation.status.displayName)",
                    "Progress: \(operation.progressPercentage)%"
                ],
                screen: screen,
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            )

            guard confirmed else {
                tui.statusMessage = "Cancellation aborted"
                await tui.draw(screen: screen)
                return
            }

            operation.cancel()
            tui.statusMessage = "Operation cancelled: \(operation.displayName)"
            Logger.shared.logUserAction("cancel_background_operation_detail", details: [
                "operationId": operation.id.uuidString,
                "type": "\(operation.type)",
                "objectName": operation.objectName ?? "unknown"
            ])
        } else {
            // Inactive operation: Remove from history and return to list
            let operationDesc = operation.displayName
            let confirmed = await ViewUtils.confirmOperation(
                title: "Remove Operation",
                message: "Remove '\(operationDesc)' from history?",
                details: [
                    "Type: \(operation.type.displayName)",
                    "Status: \(operation.status.displayName)"
                ],
                screen: screen,
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            )

            guard confirmed else {
                tui.statusMessage = "Removal aborted"
                await tui.draw(screen: screen)
                return
            }

            tui.swiftBackgroundOps.removeOperation(id: operation.id)

            // Reset selection immediately after removal
            let remainingOps = tui.swiftBackgroundOps.getAllOperations()
            if tui.selectedIndex >= remainingOps.count {
                tui.selectedIndex = max(0, remainingOps.count - 1)
            }

            tui.statusMessage = "Removed operation: \(operation.displayName)"
            Logger.shared.logUserAction("remove_background_operation_detail", details: [
                "operationId": operation.id.uuidString,
                "type": "\(operation.type)",
                "status": "\(operation.status)",
                "objectName": operation.objectName ?? "unknown"
            ])

            // Return to operations list
            tui.changeView(to: .swiftBackgroundOperations, resetSelection: false)

            // Force full screen refresh to immediately show the removal
            tui.renderOptimizer.markFullScreenDirty()
        }

        await tui.draw(screen: screen)
    }

    // MARK: - Modal Input Handler
    private func handleModalInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard let modal = tui.userFeedback.currentModal else { return }

        switch modal.type {
        case .confirmation(_, _, _, _, _, let onConfirm, let onCancel):
            switch ch {
            case Int32(10), Int32(13): // ENTER - confirm
                onConfirm()
                await tui.draw(screen: screen)

            case Int32(27): // ESC - cancel
                onCancel()
                await tui.draw(screen: screen)

            case Int32(121), Int32(89): // 'y' or 'Y' - confirm
                onConfirm()
                await tui.draw(screen: screen)

            case Int32(110), Int32(78): // 'n' or 'N' - cancel
                onCancel()
                await tui.draw(screen: screen)

            default:
                // Ignore other input for confirmation modals
                break
            }

        case .input, .selection, .progress:
            // TODO: Implement input handling for other modal types
            // For now, ESC cancels any modal
            if ch == Int32(27) {
                tui.userFeedback.dismissModal()
                await tui.draw(screen: screen)
            }
        }
    }

    // MARK: - Configuration Action Handler

    /// Handle configuration actions for navigation mode and preferences
    /// - Parameter action: The configuration action to execute
    private func handleConfigAction(_ action: CommandMode.ConfigAction) {
        guard let tui = tui else { return }

        switch action {
        case .setCommandMode(let mode):
            NavigationPreferences.shared.setMode(mode)
            tui.statusMessage = "Navigation mode set to: \(mode.displayName)"
            Logger.shared.logUserAction("navigation_mode_changed", details: [
                "mode": mode.rawValue
            ])

        case .toggleMode:
            NavigationPreferences.shared.toggleMode()
            let mode = NavigationPreferences.shared.mode
            tui.statusMessage = "Navigation mode toggled to: \(mode.displayName)"
            Logger.shared.logUserAction("navigation_mode_toggled", details: [
                "mode": mode.rawValue
            ])

        case .showPreferences:
            let status = NavigationPreferences.shared.statusDescription()
            tui.statusMessage = "Current Settings - \(status.replacingOccurrences(of: "\n", with: " | "))"
        }
    }
}
