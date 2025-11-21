import Foundation
import SwiftNCurses
import OSClient

@MainActor
struct UnifiedInputBarView {

    static func draw(screen: OpaquePointer?, tui: TUI, screenCols: Int32, screenRows: Int32) async {
        let surface = SwiftNCurses.surface(from: screen)

        // Position the input bar just above the status bar
        // Status bar is now at screenRows - 1 (bottom row)
        // Input bar should be at screenRows - 2 (second from bottom)
        let inputBarRow = screenRows - 2
        let inputBarHeight: Int32 = 1

        guard inputBarRow > 0 else { return }

        let inputBounds = Rect(x: 0, y: inputBarRow, width: screenCols, height: inputBarHeight)

        // Create the input bar component
        let inputComponent = createInputBar(tui: tui, width: screenCols)

        // Clear the area first
        await surface.fill(rect: inputBounds, character: " ", style: .secondary)

        // Render the input bar
        await SwiftNCurses.render(inputComponent, on: surface, in: inputBounds)
    }

    private static func createInputBar(tui: TUI, width: Int32) -> any Component {
        let state = tui.unifiedInputState
        let availableWidth = Int(width) - 4

        // Determine prompt based on mode
        let prompt: String

        if state.isCommandMode {
            prompt = ":"
        } else if state.isActive {
            prompt = "/"
        } else {
            prompt = ""
        }

        // Create query display
        let maxInputWidth = availableWidth - 20 // Reserve space for hints
        let queryDisplay: String
        if state.displayText.isEmpty && !state.isActive {
            // Show hint when inactive
            queryDisplay = "/ search | : commands | ? help"
        } else {
            queryDisplay = createCompactQueryDisplay(
                query: state.displayText,
                cursor: state.cursorPosition,
                maxWidth: maxInputWidth,
                isActive: state.isActive
            )
        }

        // Create status indicator with suggestions for command mode
        let statusIndicator: String
        if state.isCommandMode {
            // Show Tab completion hint if in completion mode
            if tui.commandMode.isInTabCompletion() {
                let hint = tui.commandMode.getTabCompletionHint()
                statusIndicator = hint.isEmpty ? "[cmd]" : hint
            } else if let command = state.command, !command.isEmpty {
                // Show command suggestions
                let suggestions = tui.commandMode.getSuggestions(for: command)
                if !suggestions.isEmpty {
                    let firstSuggestion = suggestions[0]
                    statusIndicator = "[\(firstSuggestion)]"
                } else if tui.commandMode.isValidCommand(command) {
                    statusIndicator = "[ok]"
                } else {
                    statusIndicator = "[?]"
                }
            } else {
                statusIndicator = "[cmd]"
            }
        } else if state.isActive && !state.displayText.isEmpty {
            // Show filter result count if we're filtering
            if let count = getFilteredResultCount(tui: tui, query: state.searchQuery) {
                statusIndicator = "[\(count)]"
            } else {
                statusIndicator = "[...]"
            }
        } else {
            statusIndicator = ""
        }

        // Build the input line
        let inputText: String
        if prompt.isEmpty {
            inputText = " \(queryDisplay)"
        } else {
            inputText = " \(queryDisplay) \(statusIndicator)"
        }

        let truncatedText = String(inputText.prefix(Int(width) - 2))

        return Text(truncatedText)
            .styled(state.isActive ? .primary : .muted)
    }

    private static func createCompactQueryDisplay(
        query: String,
        cursor: Int,
        maxWidth: Int,
        isActive: Bool
    ) -> String {
        if query.isEmpty {
            return isActive ? "_" : ""
        }

        let displayQuery = query.count > maxWidth ? String(query.suffix(maxWidth)) : query

        if !isActive {
            return displayQuery
        }

        // Show cursor position
        let safeCursor = min(cursor, displayQuery.count)
        if safeCursor >= displayQuery.count {
            return "\(displayQuery)_"
        } else {
            let beforeCursor = String(displayQuery.prefix(safeCursor))
            let atCursor = String(displayQuery[displayQuery.index(displayQuery.startIndex, offsetBy: safeCursor)])
            let afterCursor = safeCursor < displayQuery.count - 1 ?
                String(displayQuery.suffix(displayQuery.count - safeCursor - 1)) : ""
            return "\(beforeCursor)[\(atCursor)]\(afterCursor)"
        }
    }

    private static func getFilteredResultCount(tui: TUI, query: String) -> Int? {
        guard !query.isEmpty else { return nil }

        // Get the current view's filtered count
        let count: Int
        switch tui.viewCoordinator.currentView {
        case .servers:
            count = FilterUtils.filterServers(tui.cacheManager.cachedServers, query: query).count
        case .serverGroups:
            count = FilterUtils.filterServerGroups(tui.cacheManager.cachedServerGroups, query: query).count
        case .networks:
            count = FilterUtils.filterNetworks(tui.cacheManager.cachedNetworks, query: query).count
        case .securityGroups:
            count = FilterUtils.filterSecurityGroups(tui.cacheManager.cachedSecurityGroups, query: query).count
        case .volumes:
            count = FilterUtils.filterVolumes(tui.cacheManager.cachedVolumes, query: query).count
        case .images:
            count = FilterUtils.filterImages(tui.cacheManager.cachedImages, query: query).count
        case .flavors:
            count = FilterUtils.filterFlavors(tui.cacheManager.cachedFlavors, query: query).count
        case .subnets:
            count = FilterUtils.filterSubnets(tui.cacheManager.cachedSubnets, query: query).count
        case .ports:
            count = FilterUtils.filterPorts(tui.cacheManager.cachedPorts, query: query).count
        case .routers:
            count = FilterUtils.filterRouters(tui.cacheManager.cachedRouters, query: query).count
        case .floatingIPs:
            count = FilterUtils.filterFloatingIPs(tui.cacheManager.cachedFloatingIPs, query: query).count
        case .keyPairs:
            count = FilterUtils.filterKeyPairs(tui.cacheManager.cachedKeyPairs, query: query).count
        default:
            return nil
        }

        return count
    }
}
