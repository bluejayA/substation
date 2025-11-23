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

        // PRIORITY: Handle unified input (command/search mode) before view-specific handlers
        // This ensures typing in command mode (:) or search mode (/) works correctly
        if tui.unifiedInputState.isActive {
            await handleMainInput(ch, screen: screen)
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

                case .refreshView:
                    // Refresh the current view by clearing cache and fetching fresh data
                    Task {
                        tui.statusMessage = "Refreshing..."
                        tui.forceRedraw()

                        await tui.refreshCurrentView()

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

        // MODULAR ACTION ROUTING: Route standard actions through ActionProvider system
        // This handles C (create), DELETE (delete), R (restart), S (start), T (stop)
        if let actionType = ActionType.fromKeyCode(ch) {
            // Only route actions for list views (not detail views or forms)
            if !tui.viewCoordinator.currentView.isDetailView {
                // Handle bulk delete in multi-select mode first
                if actionType == .delete && tui.selectionManager.multiSelectMode && !tui.selectionManager.multiSelectedResourceIDs.isEmpty {
                    Logger.shared.logUserAction("bulk_delete_action", details: [
                        "view": "\(tui.viewCoordinator.currentView)",
                        "selectedCount": tui.selectionManager.multiSelectedResourceIDs.count
                    ])
                    await handleBulkDelete(screen: screen)
                    return
                }

                let handled = await CommandActionHandler.shared.executeAction(
                    actionType,
                    in: tui.viewCoordinator.currentView,
                    tui: tui,
                    screen: screen
                )
                if handled {
                    return
                }
            }
        }

        // MODULAR INPUT ROUTING: All keys handled through centralized handlers
        // No more switch statement - everything goes through NavigationInputHandler

        // Handle global keys (CTRL-C, ?, @, A, CTRL-X, SPACEBAR)
        if let navigationHandler = navigationHandler {
            let globalHandled = await navigationHandler.handleGlobalInput(ch, screen: screen)
            if globalHandled {
                return
            }
        }

        // Handle navigation keys (UP/DOWN/PAGE/HOME/END/ESC)
        if let navigationHandler = navigationHandler {
            let maxIndex: Int?
            if tui.viewCoordinator.currentView == .swiftBackgroundOperations {
                maxIndex = max(0, tui.swiftBackgroundOps.getAllOperations().count - 1)
            } else {
                maxIndex = nil
            }

            let navHandled = await navigationHandler.handleNavigationInput(ch, screen: screen, maxIndex: maxIndex)
            if navHandled {
                return
            }
        }

        // Log unhandled keys
        Logger.shared.logUserAction("unhandled_key", details: ["keyCode": ch, "view": "\(tui.viewCoordinator.currentView)"])
    }

    // MARK: - Resource Action Methods
    // NOTE: Basic navigation (UP/DOWN/PAGE UP/PAGE DOWN/HOME/END/ESC) is now handled by NavigationInputHandler
    // NOTE: Create actions (SHIFT+C) are now handled via modular ActionProvider routing
    // View-specific navigation overrides should be handled in individual view handlers when needed

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

    // MARK: - Action Methods
    // NOTE: View-specific actions (L, O, B, P, Z, W, M, E, U, D) are now handled via module inputHandlers
    // NOTE: Delete, restart, start, stop, create actions are handled via modular ActionProvider routing

    // MARK: - Form Input Handling
    private func handleFormInputs(_ ch: Int32, screen: OpaquePointer?) async {
        guard tui != nil else { return }

        // NOTE: Module-handled views (forms, create views, management views) are now
        // delegated via ViewRegistry at the start of handleInput()
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

        // Get bulk delete operation from module provider
        guard let provider = ActionProviderRegistry.shared.provider(for: tui.viewCoordinator.currentView),
              let batchOperation = provider.getBulkDeleteOperation(
                  selectedIDs: tui.selectionManager.multiSelectedResourceIDs,
                  tui: tui
              ) else {
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
