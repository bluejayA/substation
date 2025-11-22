import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses

/// Centralized handler for all basic navigation inputs (UP/DOWN/PAGE UP/PAGE DOWN/HOME/END/etc.)
/// This consolidates 70+ duplicate input handling cases from across 30+ form handlers
@MainActor
final class NavigationInputHandler {
    private weak var tui: TUI?

    init(tui: TUI) {
        self.tui = tui
    }

    /// Handle common navigation keys that work the same across ALL views
    /// Returns true if the input was handled, false if it should be passed to view-specific handlers
    /// - Parameter maxIndex: Optional override for max selection index (used by management views with custom filtering)
    func handleNavigationInput(_ ch: Int32, screen: OpaquePointer?, maxIndex: Int? = nil) async -> Bool {
        guard tui != nil else { return false }

        switch ch {
        case Int32(259): // KEY_UP
            return await handleUpArrow()

        case Int32(258): // KEY_DOWN
            return await handleDownArrow(maxIndex: maxIndex)

        case Int32(338): // PAGE_DOWN
            return await handlePageDown(maxIndex: maxIndex)

        case Int32(339): // PAGE_UP
            return await handlePageUp()

        case Int32(262): // HOME
            return await handleHome()

        case Int32(360): // END
            return await handleEnd(maxIndex: maxIndex)

        case Int32(27): // ESC
            return handleEscape()

        default:
            return false // Not a navigation key, let caller handle it
        }
    }

    // MARK: - Arrow Key Navigation

    private func handleUpArrow() async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("navigation_up", details: [
            "view": "\(tui.viewCoordinator.currentView)",
            "selectedIndex": tui.viewCoordinator.selectedIndex,
            "scrollOffset": tui.viewCoordinator.scrollOffset
        ])

        // Mark renderer for scroll optimization
        tui.markScrollOperation()

        // Help/About views
        if tui.viewCoordinator.currentView == .help || tui.viewCoordinator.currentView == .about {
            tui.viewCoordinator.helpScrollOffset = max(tui.viewCoordinator.helpScrollOffset - 1, 0)
            return true
        }

        // Detail views
        if tui.viewCoordinator.currentView.isDetailView {
            tui.viewCoordinator.detailScrollOffset = max(tui.viewCoordinator.detailScrollOffset - 1, 0)
            return true
        }

        // List-based views (servers, networks, volumes, etc.)
        if tui.viewCoordinator.selectedIndex > 0 {
            tui.viewCoordinator.selectedIndex -= 1
            // Adjust scroll if selection moves out of view
            if tui.viewCoordinator.selectedIndex < tui.viewCoordinator.scrollOffset {
                tui.viewCoordinator.scrollOffset = tui.viewCoordinator.selectedIndex
            }
        }

        return true
    }

    private func handleDownArrow(maxIndex: Int? = nil) async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("navigation_down", details: [
            "view": "\(tui.viewCoordinator.currentView)",
            "selectedIndex": tui.viewCoordinator.selectedIndex,
            "scrollOffset": tui.viewCoordinator.scrollOffset
        ])

        // Mark renderer for scroll optimization
        tui.markScrollOperation()

        // Help/About views
        if tui.viewCoordinator.currentView == .help || tui.viewCoordinator.currentView == .about {
            tui.viewCoordinator.helpScrollOffset = min(tui.viewCoordinator.helpScrollOffset + 1, 50)
            return true
        }

        // Detail views
        if tui.viewCoordinator.currentView.isDetailView {
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.viewCoordinator.detailScrollOffset = min(tui.viewCoordinator.detailScrollOffset + 1, maxScroll)
            return true
        }

        // List-based views
        let effectiveMaxIndex = maxIndex ?? tui.getMaxSelectionIndex()
        if tui.viewCoordinator.selectedIndex < effectiveMaxIndex {
            tui.viewCoordinator.selectedIndex += 1
            // Adjust scroll to keep selection in view
            let visibleItems = Int(tui.screenRows) - 10
            if tui.viewCoordinator.selectedIndex >= tui.viewCoordinator.scrollOffset + visibleItems {
                tui.viewCoordinator.scrollOffset = tui.viewCoordinator.selectedIndex - visibleItems + 1
            }
        }

        return true
    }

    // MARK: - Page Navigation

    private func handlePageUp() async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("page_up", details: [
            "view": "\(tui.viewCoordinator.currentView)",
            "selectedIndex": tui.viewCoordinator.selectedIndex
        ])

        tui.markScrollOperation()

        if tui.viewCoordinator.currentView == .help || tui.viewCoordinator.currentView == .about {
            tui.viewCoordinator.helpScrollOffset = max(tui.viewCoordinator.helpScrollOffset - 10, 0)
        } else if tui.viewCoordinator.currentView == .dashboard {
            tui.viewCoordinator.quotaScrollOffset = max(tui.viewCoordinator.quotaScrollOffset - 10, 0)
        } else if tui.viewCoordinator.currentView.isDetailView {
            tui.viewCoordinator.detailScrollOffset = max(tui.viewCoordinator.detailScrollOffset - 10, 0)
        } else {
            // Page up by viewport size
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let newIndex = max(tui.viewCoordinator.selectedIndex - pageSize, 0)
            tui.viewCoordinator.selectedIndex = newIndex
            if tui.viewCoordinator.selectedIndex < tui.viewCoordinator.scrollOffset {
                tui.viewCoordinator.scrollOffset = max(tui.viewCoordinator.selectedIndex - 5, 0)
            }
        }

        return true
    }

    private func handlePageDown(maxIndex: Int? = nil) async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("page_down", details: [
            "view": "\(tui.viewCoordinator.currentView)",
            "selectedIndex": tui.viewCoordinator.selectedIndex
        ])

        tui.markScrollOperation()

        if tui.viewCoordinator.currentView == .help || tui.viewCoordinator.currentView == .about {
            tui.viewCoordinator.helpScrollOffset = min(tui.viewCoordinator.helpScrollOffset + 10, 50)
        } else if tui.viewCoordinator.currentView == .dashboard {
            let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
            tui.viewCoordinator.quotaScrollOffset = min(tui.viewCoordinator.quotaScrollOffset + 10, maxQuotaScroll)
        } else if tui.viewCoordinator.currentView.isDetailView {
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.viewCoordinator.detailScrollOffset = min(tui.viewCoordinator.detailScrollOffset + 10, maxScroll)
        } else {
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let effectiveMaxIndex = maxIndex ?? tui.getMaxSelectionIndex()
            let newIndex = min(tui.viewCoordinator.selectedIndex + pageSize, effectiveMaxIndex)
            tui.viewCoordinator.selectedIndex = newIndex
            let visibleItems = Int(tui.screenRows) - 8
            if tui.viewCoordinator.selectedIndex >= tui.viewCoordinator.scrollOffset + visibleItems {
                tui.viewCoordinator.scrollOffset = min(tui.viewCoordinator.selectedIndex - visibleItems + 6, effectiveMaxIndex)
            }
        }

        return true
    }

    // MARK: - Jump Navigation

    private func handleHome() async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("home_key", details: ["view": "\(tui.viewCoordinator.currentView)"])

        tui.markScrollOperation()

        if tui.viewCoordinator.currentView.isDetailView {
            tui.viewCoordinator.detailScrollOffset = 0
        } else if tui.viewCoordinator.currentView == .help || tui.viewCoordinator.currentView == .about {
            tui.viewCoordinator.helpScrollOffset = 0
        } else if tui.viewCoordinator.currentView == .dashboard {
            tui.viewCoordinator.quotaScrollOffset = 0
        } else {
            tui.viewCoordinator.selectedIndex = 0
            tui.viewCoordinator.scrollOffset = 0
        }

        return true
    }

    private func handleEnd(maxIndex: Int? = nil) async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("end_key", details: ["view": "\(tui.viewCoordinator.currentView)"])

        tui.markScrollOperation()

        if tui.viewCoordinator.currentView.isDetailView {
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.viewCoordinator.detailScrollOffset = maxScroll
        } else if tui.viewCoordinator.currentView == .help || tui.viewCoordinator.currentView == .about {
            tui.viewCoordinator.helpScrollOffset = 50
        } else if tui.viewCoordinator.currentView == .dashboard {
            let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
            tui.viewCoordinator.quotaScrollOffset = maxQuotaScroll
        } else {
            let effectiveMaxIndex = maxIndex ?? tui.getMaxSelectionIndex()
            tui.viewCoordinator.selectedIndex = max(0, effectiveMaxIndex)
            let visibleItems = Int(tui.screenRows) - 10
            tui.viewCoordinator.scrollOffset = max(0, tui.viewCoordinator.selectedIndex - visibleItems + 1)
        }

        return true
    }

    // MARK: - Escape Handling

    private func handleEscape() -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("escape_key", details: [
            "view": "\(tui.viewCoordinator.currentView)",
            "isDetailView": tui.viewCoordinator.currentView.isDetailView,
            "hasSearchQuery": tui.searchQuery != nil,
            "multiSelectMode": tui.selectionManager.multiSelectMode
        ])

        // Priority 1: Exit multi-select mode
        if tui.selectionManager.multiSelectMode {
            Logger.shared.logUserAction("exit_multi_select_mode", details: ["selectedCount": tui.selectionManager.multiSelectedResourceIDs.count])
            tui.selectionManager.multiSelectMode = false
            tui.selectionManager.multiSelectedResourceIDs.removeAll()
            tui.statusMessage = "Exited multi-select mode"
            return true
        }

        // Priority 2: Return from help view
        if tui.viewCoordinator.currentView == .help {
            Logger.shared.logNavigation(".help", to: "\(tui.viewCoordinator.previousView)")
            tui.changeView(to: tui.viewCoordinator.previousView, resetSelection: false)
            return true
        }

        // Priority 3: Return from detail views
        // Note: Swift views handle ESC in their inputHandlers for hierarchical navigation and selection restoration
        if tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: "\(tui.viewCoordinator.currentView.parentView)", details: ["action": "escape_detail"])

            // Special handling for health dashboard service detail
            if tui.viewCoordinator.currentView == .healthDashboardServiceDetail {
                tui.viewCoordinator.healthDashboardNavState.currentSection = .services
                Logger.shared.logUserAction("health_dashboard_return_to_services", details: ["from": "service_detail"])
            }

            tui.changeView(to: tui.viewCoordinator.currentView.parentView, resetSelection: false)
            tui.viewCoordinator.selectedResource = nil
            return true
        }

        // Priority 4: Clear search query
        if tui.searchQuery != nil {
            Logger.shared.logUserAction("search_cleared_via_escape", details: ["previousQuery": tui.searchQuery ?? ""])
            tui.searchQuery = nil
            return true
        }

        // Not handled at this level - let view-specific handlers deal with it
        return false
    }

    // MARK: - Static Navigation Methods for Protocol Integration

    /// Handle list navigation (UP/DOWN/PAGE/HOME/END)
    static func handleListNavigation(_ ch: Int32, maxIndex: Int, tui: TUI) async -> Bool {
        switch ch {
        case Int32(259): // KEY_UP
            if tui.viewCoordinator.selectedIndex > 0 {
                tui.viewCoordinator.selectedIndex -= 1
                if tui.viewCoordinator.selectedIndex < tui.viewCoordinator.scrollOffset {
                    tui.viewCoordinator.scrollOffset = tui.viewCoordinator.selectedIndex
                }
            }
            return true

        case Int32(258): // KEY_DOWN
            if tui.viewCoordinator.selectedIndex < maxIndex {
                tui.viewCoordinator.selectedIndex += 1
                let visibleItems = Int(tui.screenRows) - 10
                if tui.viewCoordinator.selectedIndex >= tui.viewCoordinator.scrollOffset + visibleItems {
                    tui.viewCoordinator.scrollOffset = tui.viewCoordinator.selectedIndex - visibleItems + 1
                }
            }
            return true

        case Int32(338): // PAGE_DOWN
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let newIndex = min(tui.viewCoordinator.selectedIndex + pageSize, maxIndex)
            tui.viewCoordinator.selectedIndex = newIndex
            let visibleItems = Int(tui.screenRows) - 8
            if tui.viewCoordinator.selectedIndex >= tui.viewCoordinator.scrollOffset + visibleItems {
                tui.viewCoordinator.scrollOffset = min(tui.viewCoordinator.selectedIndex - visibleItems + 6, maxIndex)
            }
            return true

        case Int32(339): // PAGE_UP
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let newIndex = max(tui.viewCoordinator.selectedIndex - pageSize, 0)
            tui.viewCoordinator.selectedIndex = newIndex
            if tui.viewCoordinator.selectedIndex < tui.viewCoordinator.scrollOffset {
                tui.viewCoordinator.scrollOffset = max(tui.viewCoordinator.selectedIndex - 5, 0)
            }
            return true

        case Int32(262): // HOME
            tui.viewCoordinator.selectedIndex = 0
            tui.viewCoordinator.scrollOffset = 0
            return true

        case Int32(360): // END
            tui.viewCoordinator.selectedIndex = max(0, maxIndex)
            let visibleItems = Int(tui.screenRows) - 10
            tui.viewCoordinator.scrollOffset = max(0, tui.viewCoordinator.selectedIndex - visibleItems + 1)
            return true

        default:
            return false
        }
    }

    /// Handle form navigation (UP/DOWN for field navigation)
    static func handleFormNavigation(_ ch: Int32, fieldCount: Int, tui: TUI) async -> Bool {
        switch ch {
        case Int32(259): // KEY_UP
            if tui.viewCoordinator.selectedIndex > 0 {
                tui.viewCoordinator.selectedIndex -= 1
            }
            return true

        case Int32(258): // KEY_DOWN
            if tui.viewCoordinator.selectedIndex < fieldCount - 1 {
                tui.viewCoordinator.selectedIndex += 1
            }
            return true

        case Int32(262): // HOME
            tui.viewCoordinator.selectedIndex = 0
            return true

        case Int32(360): // END
            tui.viewCoordinator.selectedIndex = max(0, fieldCount - 1)
            return true

        default:
            return false
        }
    }

    /// Handle management navigation (UP/DOWN with selection toggle)
    static func handleManagementNavigation(_ ch: Int32, itemCount: Int, tui: TUI) async -> Bool {
        let maxIndex = max(0, itemCount - 1)
        return await handleListNavigation(ch, maxIndex: maxIndex, tui: tui)
    }

    /// Handle detail view navigation (scrolling)
    static func handleDetailNavigation(_ ch: Int32, scrollable: Bool, tui: TUI) async -> Bool {
        guard scrollable else { return false }

        switch ch {
        case Int32(259): // KEY_UP
            tui.viewCoordinator.detailScrollOffset = max(tui.viewCoordinator.detailScrollOffset - 1, 0)
            return true

        case Int32(258): // KEY_DOWN
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.viewCoordinator.detailScrollOffset = min(tui.viewCoordinator.detailScrollOffset + 1, maxScroll)
            return true

        case Int32(339): // PAGE_UP
            tui.viewCoordinator.detailScrollOffset = max(tui.viewCoordinator.detailScrollOffset - 10, 0)
            return true

        case Int32(338): // PAGE_DOWN
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.viewCoordinator.detailScrollOffset = min(tui.viewCoordinator.detailScrollOffset + 10, maxScroll)
            return true

        case Int32(262): // HOME
            tui.viewCoordinator.detailScrollOffset = 0
            return true

        case Int32(360): // END
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.viewCoordinator.detailScrollOffset = maxScroll
            return true

        default:
            return false
        }
    }

    /// Centralized ESC key handling with context awareness
    static func handleEscapeKey(tui: TUI) async -> Bool {
        Logger.shared.logUserAction("escape_key", details: [
            "view": "\(tui.viewCoordinator.currentView)",
            "isDetailView": tui.viewCoordinator.currentView.isDetailView,
            "hasSearchQuery": tui.searchQuery != nil,
            "multiSelectMode": tui.selectionManager.multiSelectMode
        ])

        // Priority 1: Exit multi-select mode
        if tui.selectionManager.multiSelectMode {
            Logger.shared.logUserAction("exit_multi_select_mode", details: ["selectedCount": tui.selectionManager.multiSelectedResourceIDs.count])
            tui.selectionManager.multiSelectMode = false
            tui.selectionManager.multiSelectedResourceIDs.removeAll()
            tui.statusMessage = "Exited multi-select mode"
            return true
        }

        // Priority 2: Return from help view
        if tui.viewCoordinator.currentView == .help {
            Logger.shared.logNavigation(".help", to: "\(tui.viewCoordinator.previousView)")
            tui.changeView(to: tui.viewCoordinator.previousView, resetSelection: false)
            return true
        }

        // Priority 3: Return from detail views
        // Note: Swift views handle ESC in their inputHandlers for hierarchical navigation and selection restoration
        if tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: "\(tui.viewCoordinator.currentView.parentView)", details: ["action": "escape_detail"])

            // Special handling for health dashboard service detail
            if tui.viewCoordinator.currentView == .healthDashboardServiceDetail {
                tui.viewCoordinator.healthDashboardNavState.currentSection = .services
                Logger.shared.logUserAction("health_dashboard_return_to_services", details: ["from": "service_detail"])
            }

            tui.changeView(to: tui.viewCoordinator.currentView.parentView, resetSelection: false)
            tui.viewCoordinator.selectedResource = nil
            return true
        }

        // Priority 4: Clear search query
        if tui.searchQuery != nil {
            Logger.shared.logUserAction("search_cleared_via_escape", details: ["previousQuery": tui.searchQuery ?? ""])
            tui.searchQuery = nil
            return true
        }

        // Not handled - let caller handle it
        return false
    }

    // MARK: - Global Input Handling

    /// Handle global keys that work the same everywhere (CTRL-C, ?, @, A, CTRL-X, SPACEBAR)
    /// Returns true if the input was handled, false if it should be passed to other handlers
    func handleGlobalInput(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        guard let tui = tui else { return false }

        switch ch {
        case Int32(3):  // CTRL-C - Universal quit
            Logger.shared.logUserAction("quit_application")
            tui.running = false
            return true

        case Int32(24):  // CTRL-X - Toggle multi-select mode
            if !tui.viewCoordinator.currentView.isDetailView && tui.viewCoordinator.currentView.supportsMultiSelect {
                Logger.shared.logUserAction("toggle_multi_select_mode", details: [
                    "view": "\(tui.viewCoordinator.currentView)",
                    "wasEnabled": tui.selectionManager.multiSelectMode
                ])
                return handleToggleMultiSelectMode()
            }
            return false

        case Int32(63):  // ? - Show help
            if tui.viewCoordinator.currentView != .help {
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".help")
                tui.viewCoordinator.helpScrollOffset = 0
                tui.changeView(to: .help, resetSelection: false)
                return true
            }
            return false

        case Int32(64):  // @ - Show about page
            if tui.viewCoordinator.currentView != .about {
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".about")
                tui.viewCoordinator.helpScrollOffset = 0
                tui.changeView(to: .about, resetSelection: false)
                return true
            }
            return false

        case Int32(65):  // A - Cycle refresh interval
            Logger.shared.logUserAction("cycle_refresh_interval", details: ["currentInterval": tui.refreshManager.baseRefreshInterval])
            tui.cycleRefreshInterval()
            return true

        case Int32(32):  // SPACEBAR - Toggle selection or show details
            return await handleSpacebar(screen: screen)

        default:
            return false
        }
    }

    // MARK: - Multi-Select Mode

    private func handleToggleMultiSelectMode() -> Bool {
        guard let tui = tui else { return false }

        tui.selectionManager.multiSelectMode.toggle()

        if tui.selectionManager.multiSelectMode {
            tui.statusMessage = "Multi-select mode enabled (CTRL-X to exit)"
            Logger.shared.logUserAction("multi_select_mode_enabled", details: ["view": "\(tui.viewCoordinator.currentView)"])
        } else {
            tui.selectionManager.multiSelectedResourceIDs.removeAll()
            tui.statusMessage = "Multi-select mode disabled"
            Logger.shared.logUserAction("multi_select_mode_disabled", details: ["view": "\(tui.viewCoordinator.currentView)"])
        }

        return true
    }

    // MARK: - Spacebar Handling

    private func handleSpacebar(screen: OpaquePointer?) async -> Bool {
        guard let tui = tui else { return false }

        // In multi-select mode, toggle item selection
        if tui.selectionManager.multiSelectMode && !tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logUserAction("toggle_multi_select_item", details: [
                "view": "\(tui.viewCoordinator.currentView)",
                "selectedIndex": tui.viewCoordinator.selectedIndex
            ])
            return await handleMultiSelectToggle()
        }

        // Not in detail view - open detail view
        // NOTE: Module views handle SPACEBAR in their inputHandlers for view-specific navigation
        if !tui.viewCoordinator.currentView.isDetailView {
            // Swift containers require special handling (navigateIntoContainer, fetchSwiftObjects)
            // that should be done by the SwiftModule's ViewRegistry inputHandler
            if tui.viewCoordinator.currentView == .swift || tui.viewCoordinator.currentView == .swiftContainerDetail {
                return false
            }

            Logger.shared.logUserAction("open_detail_view", details: [
                "view": "\(tui.viewCoordinator.currentView)",
                "selectedIndex": tui.viewCoordinator.selectedIndex
            ])
            tui.openDetailView()
            return true
        }

        return false
    }

    private func handleMultiSelectToggle() async -> Bool {
        guard let tui = tui else { return false }

        let resourceId = getSelectedResourceId()
        guard !resourceId.isEmpty else {
            tui.statusMessage = "No item selected"
            return true
        }

        if tui.selectionManager.multiSelectedResourceIDs.contains(resourceId) {
            tui.selectionManager.multiSelectedResourceIDs.remove(resourceId)
            Logger.shared.logUserAction("multi_select_item_deselected", details: [
                "resourceId": resourceId,
                "selectedCount": tui.selectionManager.multiSelectedResourceIDs.count
            ])
        } else {
            tui.selectionManager.multiSelectedResourceIDs.insert(resourceId)
            Logger.shared.logUserAction("multi_select_item_selected", details: [
                "resourceId": resourceId,
                "selectedCount": tui.selectionManager.multiSelectedResourceIDs.count
            ])
        }

        tui.statusMessage = "\(tui.selectionManager.multiSelectedResourceIDs.count) item(s) selected"
        return true
    }

    private func getSelectedResourceId() -> String {
        guard let tui = tui else { return "" }

        // Get resource ID from module provider
        if let provider = ActionProviderRegistry.shared.provider(for: tui.viewCoordinator.currentView) {
            return provider.getSelectedResourceId(tui: tui)
        }

        return ""
    }
}
