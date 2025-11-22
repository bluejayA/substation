import Foundation
import OSClient
import SwiftNCurses
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
        tui.refreshManager.lastUserActivityTime = Date()

        Logger.shared.logUserAction("input_received", details: [
            "keyCode": ch,
            "currentView": "\(tui.viewCoordinator.currentView)",
            "fieldEditMode": tui.securityGroupCreateForm.fieldEditMode || tui.subnetCreateForm.fieldEditMode || tui.barbicanSecretCreateForm.fieldEditMode
        ])

        // Handle modal input if a modal is active
        if tui.userFeedback.currentModal != nil {
            await handleModalInput(ch, screen: screen)
            return
        }

        // Check ViewRegistry metadata for dynamic input routing
        let viewId = tui.viewCoordinator.currentView.viewIdentifierId
        if let metadata = ViewRegistry.shared.metadata(forId: viewId),
           let inputHandler = metadata.inputHandler {
            let handled = await inputHandler(ch, screen)
            if handled {
                return
            }
        }

        // Advanced Search view input handling
        if tui.viewCoordinator.currentView == .advancedSearch {
            let handled = AdvancedSearchView.handleInput(ch)
            if handled {
                return
            }
            // If not handled by search view, allow global navigation to continue
        }

        // Health Dashboard view input handling
        if tui.viewCoordinator.currentView == .healthDashboard {
            let telemetryActor = await tui.getTelemetryActor()
            let handled = await HealthDashboardView.handleInput(ch, navigationState: tui.viewCoordinator.healthDashboardNavState, telemetryActor: telemetryActor, dataManager: tui.dataManager)
            if handled {
                tui.forceRedraw()
                return
            }
            // If not handled by health dashboard, allow global navigation to continue
        }

        // UNIVERSAL SEARCH: Handle / key for all views before specialized routing
        if ch == Int32(47) { // / - search or filter
            Logger.shared.logUserAction("search_filter_prompt", details: ["view": "\(tui.viewCoordinator.currentView)"])
            if let input = ViewUtils.prompt("Search: ", screen: screen, screenRows: tui.screenRows), !input.isEmpty {
                Logger.shared.logUserAction("search_applied", details: ["query": input, "view": "\(tui.viewCoordinator.currentView)"])
                tui.searchQuery = input
                tui.viewCoordinator.scrollOffset = 0
                tui.viewCoordinator.selectedIndex = 0
            } else {
                Logger.shared.logUserAction("search_cleared", details: ["view": "\(tui.viewCoordinator.currentView)"])
                tui.searchQuery = nil
            }
            return
        }

        await handleMainInput(ch, screen: screen)
    }

    // MARK: - Main Input Handler
    private func handleMainInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("main_input_handling", details: [
            "keyCode": ch,
            "view": "\(tui.viewCoordinator.currentView)",
            "selectedIndex": tui.viewCoordinator.selectedIndex,
            "scrollOffset": tui.viewCoordinator.scrollOffset
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
                    let success = await CommandActionHandler.shared.executeAction(actionType, in: tui.viewCoordinator.currentView, tui: tui, screen: screen)
                    if success {
                        tui.statusMessage = "Executed action: \(actionType.rawValue)"
                    }
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

                case .reloadModule(let moduleName):
                    // Handle module hot-reload
                    Task {
                        if let moduleName = moduleName {
                            // Reload specific module
                            tui.statusMessage = "Reloading module: \(moduleName)..."
                            tui.forceRedraw()

                            let result = await ModuleRegistry.shared.reloadModule(moduleName)
                            switch result {
                            case .success(let moduleId, let duration):
                                let durationStr = String(format: "%.2f", duration)
                                tui.statusMessage = "Module '\(moduleId)' reloaded successfully in \(durationStr)s"
                            case .failure(let moduleId, let error):
                                tui.statusMessage = "Failed to reload '\(moduleId)': \(error)"
                            case .skipped(let moduleId, let reason):
                                tui.statusMessage = "Reload skipped for '\(moduleId)': \(reason)"
                            }
                        } else {
                            // Reload all modules
                            tui.statusMessage = "Reloading all modules..."
                            tui.forceRedraw()

                            let results = await ModuleRegistry.shared.reloadAll()
                            let successCount = results.filter {
                                if case .success = $0 { return true }
                                return false
                            }.count
                            let failureCount = results.filter {
                                if case .failure = $0 { return true }
                                return false
                            }.count
                            let skippedCount = results.filter {
                                if case .skipped = $0 { return true }
                                return false
                            }.count

                            tui.statusMessage = "Reload complete: \(successCount) success, \(failureCount) failed, \(skippedCount) skipped"
                        }
                        tui.unifiedInputState.clear()
                        tui.forceRedraw()
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
                // Handle Tab completion
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

        // Letter keys trigger helpful hints to use
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
            if !tui.viewCoordinator.currentView.isDetailView && tui.viewCoordinator.currentView.supportsMultiSelect {
                Logger.shared.logUserAction("toggle_multi_select_mode", details: [
                    "view": "\(tui.viewCoordinator.currentView)",
                    "wasEnabled": tui.selectionManager.multiSelectMode
                ])
                handleToggleMultiSelectMode()
            }
        case Int32(87): // W - Web Access
            if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_container_web_access", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleManageContainerWebAccess(screen: screen)
            }
        case Int32(77): // M - Manage things or Performance Metrics
            if tui.viewCoordinator.currentView == .swiftBackgroundOperations && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("show_performance_metrics", details: ["view": "swiftBackgroundOperations"])
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".performanceMetrics")
                tui.viewCoordinator.scrollOffset = 0 // Reset scroll when entering metrics view
                tui.changeView(to: .performanceMetrics, resetSelection: false)
            } else if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_container_metadata", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleManageContainerMetadata(screen: screen)
            } else if tui.viewCoordinator.currentView == .swiftContainerDetail && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_tree_item_metadata", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleSwiftTreeItemMetadata(screen: screen)
            } else if tui.viewCoordinator.currentView == .securityGroups && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_security_group_rules", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleManageSecurityGroupRules(screen: screen)
            } else if tui.viewCoordinator.currentView == .floatingIPs && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_floating_ip_server_assignment", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleManageFloatingIPServerAssignment(screen: screen)
            } else if tui.viewCoordinator.currentView == .ports && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_port_server_assignment", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleManagePortServerAssignment(screen: screen)
            } else if tui.viewCoordinator.currentView == .networks && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_network_to_server", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleManageNetworkInterfaceAttachmentToServer(screen: screen)
            } else if tui.viewCoordinator.currentView == .securityGroups && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_security_group", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleAttachSecurityGroup(screen: screen)
            } else if tui.viewCoordinator.currentView == .volumes && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_volume", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleAttachVolume(screen: screen)
            } else if tui.viewCoordinator.currentView == .subnets && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_subnet_router", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleAttachSubnetRouter(screen: screen)
            }
        case Int32(69): // E - Manage allowed address pairs for ports (SHIFT-E)
            if tui.viewCoordinator.currentView == .ports && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_port_allowed_address_pairs", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleManagePortAllowedAddressPairs(screen: screen)
            }
        case Int32(85): // U - Upload object to container (SHIFT-U)
            if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("upload_object_to_container", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleUploadObjectToContainer(screen: screen)
            } else if tui.viewCoordinator.currentView == .swiftContainerDetail {
                // From container detail view (inside a container), also allow upload
                Logger.shared.logUserAction("upload_object_to_container_from_detail", details: ["container": tui.viewCoordinator.swiftNavState.currentContainer ?? "unknown"])
                await handleUploadObjectToContainer(screen: screen)
            }
        case Int32(68): // D - Download container or object (SHIFT-D)
            if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("download_container", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleDownloadContainer(screen: screen)
            } else if tui.viewCoordinator.currentView == .swiftContainerDetail && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("download_object", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleDownloadObject(screen: screen)
            }
        case Int32(259), Int32(258), Int32(338), Int32(339), Int32(262), Int32(360), Int32(27): // Navigation keys
            // Use centralized navigation handler for all basic navigation
            if let navigationHandler = navigationHandler {
                // For swiftBackgroundOperations, pass the actual count of operations
                let maxIndex: Int?
                if tui.viewCoordinator.currentView == .swiftBackgroundOperations {
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
            if tui.selectionManager.multiSelectMode && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("toggle_multi_select_item", details: [
                    "view": "\(tui.viewCoordinator.currentView)",
                    "selectedIndex": tui.viewCoordinator.selectedIndex
                ])
                await handleMultiSelectToggle()
            } else if !tui.viewCoordinator.currentView.isDetailView {
                // Special handling for Swift hierarchical navigation
                if tui.viewCoordinator.currentView == .swift {
                    Logger.shared.logUserAction("swift_navigate_into_container", details: [
                        "selectedIndex": tui.viewCoordinator.selectedIndex
                    ])
                    await handleSwiftContainerNavigation()
                } else if tui.viewCoordinator.currentView == .swiftContainerDetail {
                    Logger.shared.logUserAction("swift_navigate_into_item", details: [
                        "selectedIndex": tui.viewCoordinator.selectedIndex,
                        "currentPath": tui.viewCoordinator.swiftNavState.currentPathString
                    ])
                    await handleSwiftTreeItemNavigation()
                } else if tui.viewCoordinator.currentView == .swiftBackgroundOperations {
                    Logger.shared.logUserAction("open_operation_detail", details: [
                        "selectedIndex": tui.viewCoordinator.selectedIndex
                    ])
                    await handleOpenOperationDetail()
                } else {
                    Logger.shared.logUserAction("open_detail_view", details: [
                        "view": "\(tui.viewCoordinator.currentView)",
                        "selectedIndex": tui.viewCoordinator.selectedIndex
                    ])
                    tui.openDetailView()
                }
            }
        // NOTE: / key (Int32(47)) is now handled universally before specialized view routing
        // Context-Sensitive Actions (Uppercase letters)
        case Int32(67): // C - Create new resource
            Logger.shared.logUserAction("create_action", details: ["view": "\(tui.viewCoordinator.currentView)", "selectedIndex": tui.viewCoordinator.selectedIndex])
            await handleCreateResource()
        case Int32(76): // L - View server logs
            if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("view_server_logs", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleViewServerLogs(screen: screen)
            }
        case Int32(79): // O - View server console or open console in browser
            if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("view_server_console", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleViewServerConsole(screen: screen)
            } else if tui.viewCoordinator.currentView == .serverConsole {
                Logger.shared.logUserAction("open_console_in_browser")
                await handleOpenConsoleInBrowser()
            }
        case Int32(66): // B - Create backup (volume)
            if tui.viewCoordinator.currentView == .volumes && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("create_volume_backup", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleVolumeBackup(screen: screen)
            }
        case Int32(80): // P - Create snapshot or Manage floating IP port assignment
            if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("create_snapshot", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleCreateSnapshot(screen: screen)
            } else if tui.viewCoordinator.currentView == .volumes && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("create_volume_snapshot", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                    await module.createVolumeSnapshot(screen: screen)
                }
            } else if tui.viewCoordinator.currentView == .floatingIPs && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("manage_floating_ip_port_assignment", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleManageFloatingIPPortAssignment(screen: screen)
            }
        case Int32(82): // R - Restart server
            if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("restart_server", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleRestartServer(screen: screen)
            }
        case Int32(83): // S - Start server
            if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("start_server", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleStartServer(screen: screen)
            }
        case Int32(84): // T - Stop server
            if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
                Logger.shared.logUserAction("stop_server", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                await handleStopServer(screen: screen)
            }
        case Int32(63): // ? - Show help
            if tui.viewCoordinator.currentView != .help {
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".help")
                tui.viewCoordinator.helpScrollOffset = 0 // Reset scroll when entering help
                tui.changeView(to: .help, resetSelection: false)
            }
        case Int32(64): // @ - Show about page
            if tui.viewCoordinator.currentView != .about {
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".about")
                tui.viewCoordinator.helpScrollOffset = 0 // Reset scroll when entering about
                tui.changeView(to: .about, resetSelection: false)
            }
        case Int32(127), Int32(330): // DELETE key - Delete resources
            Logger.shared.logUserAction("delete_action", details: ["view": "\(tui.viewCoordinator.currentView)", "selectedIndex": tui.viewCoordinator.selectedIndex])
            await handleDeleteKey(screen: screen)
        case Int32(90): // Z - Resize selected server
            Logger.shared.logUserAction("resize_server", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
            await handleResizeServer(screen: screen)
        case Int32(65): // A - Cycle refresh interval
            Logger.shared.logUserAction("cycle_refresh_interval", details: ["currentInterval": tui.refreshManager.baseRefreshInterval])
            tui.cycleRefreshInterval()
        default:
            Logger.shared.logUserAction("unhandled_key", details: ["keyCode": ch, "view": "\(tui.viewCoordinator.currentView)"])
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

        Logger.shared.logUserAction("create_resource_initiated", details: ["view": "\(tui.viewCoordinator.currentView)"])

        if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
            // Navigate to server creation
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".serverCreate")
            tui.changeView(to: .serverCreate)

            // Reset form and populate with cached data
            var form = ServerCreateForm()
            form.images = tui.cacheManager.cachedImages
            form.volumes = tui.cacheManager.cachedVolumes
            form.flavors = tui.cacheManager.cachedFlavors
            form.networks = tui.cacheManager.cachedNetworks
            form.securityGroups = tui.cacheManager.cachedSecurityGroups
            form.keyPairs = tui.cacheManager.cachedKeyPairs
            form.serverGroups = tui.cacheManager.cachedServerGroups
            tui.serverCreateForm = form

            // Initialize FormBuilderState with form fields
            tui.serverCreateFormState = FormBuilderState(fields: form.buildFields(selectedFieldId: nil))
        } else if tui.viewCoordinator.currentView == .networks && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".networkCreate")
            tui.changeView(to: .networkCreate)
            tui.networkCreateForm = NetworkCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.networkCreateFormState = FormBuilderState(fields: tui.networkCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.viewCoordinator.currentView == .securityGroups && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".securityGroupCreate")
            tui.changeView(to: .securityGroupCreate)
            tui.securityGroupCreateForm = SecurityGroupCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.securityGroupCreateFormState = FormBuilderState(fields: tui.securityGroupCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.viewCoordinator.currentView == .subnets && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".subnetCreate")
            tui.changeView(to: .subnetCreate)
            tui.subnetCreateForm = SubnetCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.subnetCreateFormState = FormBuilderState(fields: tui.subnetCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                cachedNetworks: tui.cacheManager.cachedNetworks,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.viewCoordinator.currentView == .keyPairs && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".keyPairCreate")
            tui.changeView(to: .keyPairCreate)
            tui.keyPairCreateForm = KeyPairCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.keyPairCreateFormState = FormBuilderState(fields: tui.keyPairCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.viewCoordinator.currentView == .volumes && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".volumeCreate")
            tui.changeView(to: .volumeCreate)
            // Load all snapshots for volume creation
            if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                _ = await module.loadAllVolumeSnapshots()
            }
            // Reset form and populate cached data
            tui.volumeCreateForm = VolumeCreateForm()
            tui.volumeCreateForm.images = tui.cacheManager.cachedImages
            tui.volumeCreateForm.snapshots = tui.cacheManager.cachedVolumeSnapshots
            tui.volumeCreateForm.volumeTypes = tui.cacheManager.cachedVolumeTypes
            // Initialize form state
            tui.volumeCreateFormState = FormBuilderState(fields: tui.volumeCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: nil
            ))
        } else if tui.viewCoordinator.currentView == .ports && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".portCreate")
            tui.changeView(to: .portCreate)
            tui.portCreateForm = PortCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.portCreateFormState = FormBuilderState(fields: tui.portCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: []),
                networks: tui.cacheManager.cachedNetworks,
                securityGroups: tui.cacheManager.cachedSecurityGroups,
                qosPolicies: tui.cacheManager.cachedQoSPolicies
            ))
        } else if tui.viewCoordinator.currentView == .floatingIPs && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".floatingIPCreate")
            tui.changeView(to: .floatingIPCreate)
            tui.floatingIPCreateForm = FloatingIPCreateForm()
            let externalNetworks = tui.cacheManager.cachedNetworks.filter { $0.external == true }
            tui.floatingIPCreateFormState = FormBuilderState(
                fields: tui.floatingIPCreateForm.buildFields(
                    externalNetworks: externalNetworks,
                    subnets: tui.cacheManager.cachedSubnets,
                    selectedFieldId: nil
                )
            )
        } else if tui.viewCoordinator.currentView == .routers && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".routerCreate")
            tui.changeView(to: .routerCreate)
            tui.routerCreateForm = RouterCreateForm()
            tui.routerCreateFormState = FormBuilderState(
                fields: tui.routerCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: nil,
                    availabilityZones: tui.cacheManager.cachedAvailabilityZones,
                    externalNetworks: tui.cacheManager.cachedNetworks
                )
            )
        } else if tui.viewCoordinator.currentView == .serverGroups && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".serverGroupCreate")
            tui.changeView(to: .serverGroupCreate)
            tui.serverGroupCreateForm = ServerGroupCreateForm() // Reset form

            // Initialize FormBuilderState with form fields
            tui.serverGroupCreateFormState = FormBuilderState(fields: tui.serverGroupCreateForm.buildFields(
                selectedFieldId: nil,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if (tui.viewCoordinator.currentView == .barbicanSecrets || tui.viewCoordinator.currentView == .barbican) && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".barbicanSecretCreate")
            tui.changeView(to: .barbicanSecretCreate)
            tui.barbicanSecretCreateForm = BarbicanSecretCreateForm() // Reset form
            tui.barbicanSecretCreateFormState = FormBuilderState(fields: tui.barbicanSecretCreateForm.buildFields(
                selectedFieldId: BarbicanSecretCreateFieldId.name.rawValue,
                activeFieldId: nil,
                formState: FormBuilderState(fields: [])
            ))
        } else if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".swiftContainerCreate")
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

        Logger.shared.logUserAction("refresh_initiated", details: ["view": "\(tui.viewCoordinator.currentView)"])
        let startTime = Date()

        // Full data refresh
        let refreshStart = Date()
        await tui.dataManager.refreshAllData()
        let refreshDuration = Date().timeIntervalSince(refreshStart)
        Logger.shared.logPerformance("full_data_refresh", duration: refreshDuration)
        tui.refreshManager.lastRefresh = Date()

        // Request refresh for health dashboard if on that view
        if tui.viewCoordinator.currentView == .healthDashboard {
            tui.viewCoordinator.healthDashboardNavState.requestRefresh()
        }

        tui.statusMessage = "Data refreshed"

        let duration = Date().timeIntervalSince(startTime)
        Logger.shared.logPerformance("refresh_completed", duration: duration, context: [
            "view": "\(tui.viewCoordinator.currentView)",
            "refreshType": "full_data"
        ])
    }

    private func handleCachePurge() async {
        guard let tui = tui else { return }

        Logger.shared.logUserAction("cache_purge_initiated")
        let startTime = Date()

        await tui.dataManager.purgeCache()
        tui.refreshManager.lastRefresh = Date()

        let duration = Date().timeIntervalSince(startTime)
        Logger.shared.logPerformance("cache_purge_and_refresh", duration: duration)
    }

    // MARK: - Multi-Select Helper Methods
    private func handleToggleMultiSelectMode() {
        guard let tui = tui else { return }

        tui.selectionManager.multiSelectMode.toggle()
        if !tui.selectionManager.multiSelectMode {
            tui.selectionManager.multiSelectedResourceIDs.removeAll()
            tui.statusMessage = "Multi-select mode OFF"
        } else {
            tui.statusMessage = "Multi-select mode ON - Use SPACE to select items, CTRL-X to exit, DELETE to bulk delete"
        }
    }

    private func handleMultiSelectToggle() async {
        guard let tui = tui else { return }

        let resourceID = getSelectedResourceID()
        guard !resourceID.isEmpty else { return }

        if tui.selectionManager.multiSelectedResourceIDs.contains(resourceID) {
            tui.selectionManager.multiSelectedResourceIDs.remove(resourceID)
            Logger.shared.logUserAction("deselect_resource", details: ["resourceID": resourceID])
        } else {
            tui.selectionManager.multiSelectedResourceIDs.insert(resourceID)
            Logger.shared.logUserAction("select_resource", details: ["resourceID": resourceID])
        }

        tui.statusMessage = "\(tui.selectionManager.multiSelectedResourceIDs.count) items selected"
    }

    private func getSelectedResourceID() -> String {
        guard let tui = tui else { return "" }

        switch tui.viewCoordinator.currentView {
        case .servers:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedServers.count else { return "" }
            return tui.cacheManager.cachedServers[tui.viewCoordinator.selectedIndex].id
        case .volumes:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedVolumes.count else { return "" }
            return tui.cacheManager.cachedVolumes[tui.viewCoordinator.selectedIndex].id
        case .networks:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedNetworks.count else { return "" }
            return tui.cacheManager.cachedNetworks[tui.viewCoordinator.selectedIndex].id
        case .subnets:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSubnets.count else { return "" }
            return tui.cacheManager.cachedSubnets[tui.viewCoordinator.selectedIndex].id
        case .routers:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedRouters.count else { return "" }
            return tui.cacheManager.cachedRouters[tui.viewCoordinator.selectedIndex].id
        case .ports:
            // Ports are sorted in the view, so we need to use the filtered/sorted list
            let filteredPorts = FilterUtils.filterPorts(tui.cacheManager.cachedPorts, query: tui.searchQuery)
            guard tui.viewCoordinator.selectedIndex < filteredPorts.count else { return "" }
            return filteredPorts[tui.viewCoordinator.selectedIndex].id
        case .floatingIPs:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedFloatingIPs.count else { return "" }
            return tui.cacheManager.cachedFloatingIPs[tui.viewCoordinator.selectedIndex].id
        case .securityGroups:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSecurityGroups.count else { return "" }
            return tui.cacheManager.cachedSecurityGroups[tui.viewCoordinator.selectedIndex].id
        case .serverGroups:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedServerGroups.count else { return "" }
            return tui.cacheManager.cachedServerGroups[tui.viewCoordinator.selectedIndex].id
        case .keyPairs:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedKeyPairs.count else { return "" }
            return tui.cacheManager.cachedKeyPairs[tui.viewCoordinator.selectedIndex].name ?? ""
        case .images:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedImages.count else { return "" }
            return tui.cacheManager.cachedImages[tui.viewCoordinator.selectedIndex].id
        case .volumeArchives:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedVolumeBackups.count else { return "" }
            return tui.cacheManager.cachedVolumeBackups[tui.viewCoordinator.selectedIndex].id
        case .barbicanSecrets, .barbican:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSecrets.count else { return "" }
            return tui.cacheManager.cachedSecrets[tui.viewCoordinator.selectedIndex].secretRef ?? ""
        case .swift:
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSwiftContainers.count else { return "" }
            return tui.cacheManager.cachedSwiftContainers[tui.viewCoordinator.selectedIndex].id
        case .swiftContainerDetail:
            guard let objects = tui.cacheManager.cachedSwiftObjects else { return "" }
            // Build tree structure to match what's displayed
            let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)
            // Apply search filter if present
            let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)
            guard tui.viewCoordinator.selectedIndex < filteredItems.count else { return "" }
            return filteredItems[tui.viewCoordinator.selectedIndex].id
        default:
            return ""
        }
    }

    // MARK: - Server Action Methods
    private func handleDeleteKey(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Handle bulk delete in multi-select mode
        if tui.selectionManager.multiSelectMode && !tui.selectionManager.multiSelectedResourceIDs.isEmpty {
            await handleBulkDelete(screen: screen)
            return
        }

        if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                await module.deleteServer(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .keyPairs && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "keyPairs") as? KeyPairsModule {
                await module.deleteKeyPair(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .images && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "images") as? ImagesModule {
                await module.deleteImage(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .volumes && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                await module.deleteVolume(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .networks && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "networks") as? NetworksModule {
                await module.deleteNetwork(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .subnets && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "subnets") as? SubnetsModule {
                await module.deleteSubnet(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .routers && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "routers") as? RoutersModule {
                await module.deleteRouter(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .ports && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "ports") as? PortsModule {
                await module.deletePort(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .floatingIPs && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "floatingIPs") as? FloatingIPsModule {
                await module.deleteFloatingIP(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .serverGroups && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "serverGroups") as? ServerGroupsModule {
                await module.deleteServerGroup(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .securityGroups && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "securityGroups") as? SecurityGroupsModule {
                await module.deleteSecurityGroup(screen: screen)
            }
        } else if (tui.viewCoordinator.currentView == .barbicanSecrets || tui.viewCoordinator.currentView == .barbican) && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "barbican") as? BarbicanModule {
                await module.deleteSecret(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .volumeArchives && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                await module.deleteVolumeArchive(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "swift") as? SwiftModule {
                await module.deleteSwiftContainer(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .swiftContainerDetail && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "swift") as? SwiftModule {
                await module.deleteSwiftObject(screen: screen)
            }
        } else if tui.viewCoordinator.currentView == .swiftBackgroundOperations && !tui.viewCoordinator.currentView.isDetailView {
            await handleCancelBackgroundOperation(screen: screen)
        } else if tui.viewCoordinator.currentView == .swiftBackgroundOperationDetail {
            await handleCancelBackgroundOperationFromDetail(screen: screen)
        }
    }

    private func handleRestartServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                await module.restartServer(screen: screen)
            }
        }
    }

    private func handleResizeServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                await module.resizeServer(screen: screen)
            }
        }
    }

    private func handleViewServerLogs(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                await module.viewServerLogs(screen: screen)
            }
        }
    }

    private func handleViewServerConsole(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                await module.viewServerConsole(screen: screen)
            }
        }
    }

    private func handleOpenConsoleInBrowser() async {
        guard let tui = tui else { return }

        if let console = tui.viewCoordinator.selectedResource as? RemoteConsole {
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

        if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                await module.startServer(screen: screen)
            }
        }
    }

    private func handleStopServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                await module.stopServer(screen: screen)
            }
        }
    }

    private func handleAttachSecurityGroup(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .securityGroups && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "securitygroups") as? SecurityGroupsModule {
                await module.manageSecurityGroupToServers(screen: screen)
            }
        }
    }

    private func handleManageNetworkInterfaceAttachmentToServer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .networks && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "networks") as? NetworksModule {
                await module.manageNetworkToServers(screen: screen)
            }
        }
    }

    private func handleCreateSnapshot(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if (tui.viewCoordinator.currentView == .servers && !tui.viewCoordinator.currentView.isDetailView) || tui.viewCoordinator.currentView == .serverDetail {
            if let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule {
                await module.createServerSnapshot(screen: screen)
            }
        } else if (tui.viewCoordinator.currentView == .volumes && !tui.viewCoordinator.currentView.isDetailView) || tui.viewCoordinator.currentView == .volumeDetail {
            if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                await module.createVolumeSnapshot(screen: screen)
            }
        }
    }

    private func handleVolumeBackup(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if (tui.viewCoordinator.currentView == .volumes && !tui.viewCoordinator.currentView.isDetailView) || tui.viewCoordinator.currentView == .volumeDetail {
            if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                await module.createVolumeBackup(screen: screen)
            }
        }
    }

    private func handleAttachVolume(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .volumes && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                await module.attachVolumeToServers(screen: screen)
            }
        }
    }



    private func handleManageSecurityGroupRules(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .securityGroups && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "securitygroups") as? SecurityGroupsModule {
                await module.manageSecurityGroupRules(screen: screen)
            }
        }
    }

    private func handleManageContainerMetadata(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSwiftContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = tui.cacheManager.cachedSwiftContainers[tui.viewCoordinator.selectedIndex]
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

        if tui.viewCoordinator.currentView == .swiftContainerDetail && !tui.viewCoordinator.currentView.isDetailView {
            guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
                tui.statusMessage = "No container selected"
                return
            }

            guard let allObjects = tui.cacheManager.cachedSwiftObjects else {
                tui.statusMessage = "No objects loaded"
                return
            }

            // Build tree from objects
            let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)

            guard tui.viewCoordinator.selectedIndex < treeItems.count else {
                tui.statusMessage = "No item selected"
                return
            }

            let selectedItem = treeItems[tui.viewCoordinator.selectedIndex]

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

        if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSwiftContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = tui.cacheManager.cachedSwiftContainers[tui.viewCoordinator.selectedIndex]
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
        guard tui != nil else { return }

        // NOTE: Module-handled views (forms, create views, management views) are now
        // delegated via ViewRegistry at the start of handleInput()
    }

    // MARK: - Floating IP Action Methods
    private func handleManageFloatingIPServerAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .floatingIPs && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "floatingips") as? FloatingIPsModule {
                await module.manageFloatingIPServerAssignment(screen: screen)
            }
        }
    }

    private func handleManageFloatingIPPortAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .floatingIPs && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "floatingips") as? FloatingIPsModule {
                await module.manageFloatingIPPortAssignment(screen: screen)
            }
        }
    }

    private func handleManagePortServerAssignment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .ports && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "ports") as? PortsModule {
                await module.managePortServerAssignment(screen: screen)
            }
        }
    }

    private func handleManagePortAllowedAddressPairs(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .ports && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "ports") as? PortsModule {
                await module.managePortAllowedAddressPairs(screen: screen)
            }
        }
    }

    private func handleAttachSubnetRouter(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        if tui.viewCoordinator.currentView == .subnets && !tui.viewCoordinator.currentView.isDetailView {
            if let module = ModuleRegistry.shared.module(for: "routers") as? RoutersModule {
                await module.manageSubnetRouterAttachment(screen: screen)
            }
        }
    }

    private func handleUploadObjectToContainer(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let containerName: String

        if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
            // Called from container list - get selected container
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSwiftContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = tui.cacheManager.cachedSwiftContainers[tui.viewCoordinator.selectedIndex]
            guard let name = container.name else {
                tui.statusMessage = "Invalid container"
                return
            }
            containerName = name

        } else if tui.viewCoordinator.currentView == .swiftContainerDetail {
            // Called from inside a container - use current container from navigation state
            guard let currentContainer = tui.viewCoordinator.swiftNavState.currentContainer else {
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

        if tui.viewCoordinator.currentView == .swift && !tui.viewCoordinator.currentView.isDetailView {
            guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSwiftContainers.count else {
                tui.statusMessage = "No container selected"
                return
            }

            let container = tui.cacheManager.cachedSwiftContainers[tui.viewCoordinator.selectedIndex]
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

        if tui.viewCoordinator.currentView == .swiftContainerDetail && !tui.viewCoordinator.currentView.isDetailView {
            guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
                tui.statusMessage = "No container selected"
                return
            }

            guard let allObjects = tui.cacheManager.cachedSwiftObjects else {
                tui.statusMessage = "No objects loaded"
                return
            }

            // Build tree from objects
            let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)

            // Apply search filter if present
            let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)

            guard tui.viewCoordinator.selectedIndex < filteredItems.count else {
                tui.statusMessage = "No item selected"
                return
            }

            let selectedItem = filteredItems[tui.viewCoordinator.selectedIndex]

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

    private func handleBulkDelete(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let itemCount = tui.selectionManager.multiSelectedResourceIDs.count
        let resourceType = tui.viewCoordinator.currentView.title

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
            "view": "\(tui.viewCoordinator.currentView)",
            "count": itemCount
        ])

        let batchOperation: BatchOperationType

        switch tui.viewCoordinator.currentView {
        case .servers:
            batchOperation = .serverBulkDelete(serverIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .volumes:
            batchOperation = .volumeBulkDelete(volumeIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .networks:
            batchOperation = .networkBulkDelete(networkIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .subnets:
            batchOperation = .subnetBulkDelete(subnetIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .routers:
            batchOperation = .routerBulkDelete(routerIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .ports:
            batchOperation = .portBulkDelete(portIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .floatingIPs:
            batchOperation = .floatingIPBulkDelete(floatingIPIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .securityGroups:
            batchOperation = .securityGroupBulkDelete(securityGroupIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .serverGroups:
            batchOperation = .serverGroupBulkDelete(serverGroupIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .keyPairs:
            batchOperation = .keyPairBulkDelete(keyPairNames: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .images:
            batchOperation = .imageBulkDelete(imageIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .volumeArchives:
            batchOperation = .volumeBackupBulkDelete(backupIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .barbicanSecrets, .barbican:
            batchOperation = .barbicanSecretBulkDelete(secretIDs: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .swift:
            batchOperation = .swiftContainerBulkDelete(containerNames: Array(tui.selectionManager.multiSelectedResourceIDs))
        case .swiftContainerDetail:
            // Get container name from selected resource
            guard let container = tui.viewCoordinator.selectedResource as? SwiftContainer, let containerName = container.name else {
                tui.statusMessage = "No container selected"
                return
            }
            batchOperation = .swiftObjectBulkDelete(containerName: containerName, objectNames: Array(tui.selectionManager.multiSelectedResourceIDs))
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
        tui.selectionManager.multiSelectMode = false
        tui.selectionManager.multiSelectedResourceIDs.removeAll()

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
                "view": "\(tui.viewCoordinator.currentView)",
                "successful": result.successfulOperations,
                "failed": result.failedOperations
            ])
        }

        backgroundOp.task = task
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

        guard tui.viewCoordinator.selectedIndex < tui.cacheManager.cachedSwiftContainers.count else {
            tui.statusMessage = "No container selected"
            return
        }

        let container = tui.cacheManager.cachedSwiftContainers[tui.viewCoordinator.selectedIndex]
        guard let containerName = container.name else {
            tui.statusMessage = "Invalid container"
            return
        }

        Logger.shared.logInfo("Navigating into container: \(containerName)")

        // Update navigation state
        tui.viewCoordinator.swiftNavState.navigateIntoContainer(containerName)

        // Change to container detail view
        tui.changeView(to: .swiftContainerDetail, resetSelection: true)

        // Load objects for this container
        if let swiftModule = ModuleRegistry.shared.module(for: "swift") as? SwiftModule {
            await swiftModule.fetchSwiftObjects(containerName: containerName, priority: "interactive")
        }

        Logger.shared.logInfo("Container navigation complete, showing \(tui.cacheManager.cachedSwiftObjects?.count ?? 0) objects")
    }

    /// Handle SPACEBAR navigation when in container detail view (tree items)
    private func handleSwiftTreeItemNavigation() async {
        guard let tui = tui else { return }

        guard let objects = tui.cacheManager.cachedSwiftObjects else {
            tui.statusMessage = "No objects loaded"
            return
        }

        let currentPath = tui.viewCoordinator.swiftNavState.currentPathString

        // Build tree structure
        let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)

        // Apply search filter if present
        let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)

        guard tui.viewCoordinator.selectedIndex < filteredItems.count else {
            tui.statusMessage = "No item selected"
            return
        }

        let selectedItem = filteredItems[tui.viewCoordinator.selectedIndex]

        switch selectedItem {
        case .directory(let directoryName, _, _):
            // Navigate into directory
            Logger.shared.logInfo("Navigating into directory: \(directoryName)")
            tui.viewCoordinator.swiftNavState.navigateIntoDirectory(directoryName)

            // Reset selection to top
            tui.viewCoordinator.selectedIndex = 0
            tui.viewCoordinator.scrollOffset = 0

            // Stay in the same view (swiftContainerDetail)
            tui.markNeedsRedraw()

            Logger.shared.logInfo("Directory navigation complete, new path: \(tui.viewCoordinator.swiftNavState.currentPathString)")

        case .object(let object):
            // Open object detail view
            Logger.shared.logInfo("Opening object detail: \(object.name ?? "unknown")")
            tui.viewCoordinator.selectedResource = object
            tui.changeView(to: .swiftObjectDetail, resetSelection: false)
            tui.viewCoordinator.detailScrollOffset = 0
        }
    }

    // MARK: - Swift Background Operations Helpers

    private func handleOpenOperationDetail() async {
        guard let tui = tui else { return }

        let operations = tui.swiftBackgroundOps.getAllOperations()
        guard tui.viewCoordinator.selectedIndex < operations.count else {
            tui.statusMessage = "No operation selected"
            return
        }

        let operation = operations[tui.viewCoordinator.selectedIndex]
        tui.viewCoordinator.selectedResource = operation
        tui.changeView(to: .swiftBackgroundOperationDetail, resetSelection: false)
        tui.viewCoordinator.detailScrollOffset = 0
    }

    /// Handles DELETE key in background operations view with context-aware behavior
    /// - If operation is active (running/queued): Cancel it
    /// - If operation is inactive (completed/failed/cancelled): Remove it from history
    private func handleCancelBackgroundOperation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let operations = tui.swiftBackgroundOps.getAllOperations()
        guard tui.viewCoordinator.selectedIndex < operations.count else {
            tui.statusMessage = "No operation selected"
            await tui.draw(screen: screen)
            return
        }

        let operation = operations[tui.viewCoordinator.selectedIndex]

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
            if tui.viewCoordinator.selectedIndex >= remainingOps.count {
                tui.viewCoordinator.selectedIndex = max(0, remainingOps.count - 1)
            }

            // Force full screen refresh to immediately show the removal
            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()

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
        guard let operation = tui.viewCoordinator.selectedResource as? SwiftBackgroundOperation else {
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
            if tui.viewCoordinator.selectedIndex >= remainingOps.count {
                tui.viewCoordinator.selectedIndex = max(0, remainingOps.count - 1)
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
            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()
        }

        await tui.draw(screen: screen)
    }

    // MARK: - Modal Input Handler
    /// Handle input for confirmation modals
    /// Note: Only confirmation modals are currently used in the application.
    /// Input, selection, and progress modal types are defined but unused - all input/selection
    /// is handled through FormBuilder components instead.
    private func handleModalInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard let modal = tui.userFeedback.currentModal else { return }

        // Only handle confirmation modals - other modal types are unused
        guard case .confirmation(_, _, _, _, _, let onConfirm, let onCancel) = modal.type else {
            return
        }

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
    }
}
