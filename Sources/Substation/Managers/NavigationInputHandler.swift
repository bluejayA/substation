import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftTUI

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
            "view": "\(tui.currentView)",
            "selectedIndex": tui.selectedIndex,
            "scrollOffset": tui.scrollOffset
        ])

        // Mark renderer for scroll optimization
        tui.markScrollOperation()

        // Help/About views
        if tui.currentView == .help || tui.currentView == .about {
            tui.helpScrollOffset = max(tui.helpScrollOffset - 1, 0)
            return true
        }

        // Dashboard quota scrolling
        if tui.currentView == .dashboard {
            tui.quotaScrollOffset = max(tui.quotaScrollOffset - 1, 0)
            return true
        }

        // Detail views
        if tui.currentView.isDetailView {
            tui.detailScrollOffset = max(tui.detailScrollOffset - 1, 0)
            return true
        }

        // List-based views (servers, networks, volumes, etc.)
        if tui.selectedIndex > 0 {
            tui.selectedIndex -= 1
            // Adjust scroll if selection moves out of view
            if tui.selectedIndex < tui.scrollOffset {
                tui.scrollOffset = tui.selectedIndex
            }
        }

        return true
    }

    private func handleDownArrow(maxIndex: Int? = nil) async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("navigation_down", details: [
            "view": "\(tui.currentView)",
            "selectedIndex": tui.selectedIndex,
            "scrollOffset": tui.scrollOffset
        ])

        // Mark renderer for scroll optimization
        tui.markScrollOperation()

        // Help/About views
        if tui.currentView == .help || tui.currentView == .about {
            tui.helpScrollOffset = min(tui.helpScrollOffset + 1, 50)
            return true
        }

        // Dashboard quota scrolling
        if tui.currentView == .dashboard {
            let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
            tui.quotaScrollOffset = min(tui.quotaScrollOffset + 1, maxQuotaScroll)
            return true
        }

        // Detail views
        if tui.currentView.isDetailView {
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.detailScrollOffset = min(tui.detailScrollOffset + 1, maxScroll)
            return true
        }

        // List-based views
        let effectiveMaxIndex = maxIndex ?? tui.getMaxSelectionIndex()
        if tui.selectedIndex < effectiveMaxIndex {
            tui.selectedIndex += 1
            // Adjust scroll to keep selection in view
            let visibleItems = Int(tui.screenRows) - 10
            if tui.selectedIndex >= tui.scrollOffset + visibleItems {
                tui.scrollOffset = tui.selectedIndex - visibleItems + 1
            }
        }

        return true
    }

    // MARK: - Page Navigation

    private func handlePageUp() async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("page_up", details: [
            "view": "\(tui.currentView)",
            "selectedIndex": tui.selectedIndex
        ])

        tui.markScrollOperation()

        if tui.currentView == .help || tui.currentView == .about {
            tui.helpScrollOffset = max(tui.helpScrollOffset - 10, 0)
        } else if tui.currentView == .dashboard {
            tui.quotaScrollOffset = max(tui.quotaScrollOffset - 10, 0)
        } else if tui.currentView.isDetailView {
            tui.detailScrollOffset = max(tui.detailScrollOffset - 10, 0)
        } else {
            // Page up by viewport size
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let newIndex = max(tui.selectedIndex - pageSize, 0)
            tui.selectedIndex = newIndex
            if tui.selectedIndex < tui.scrollOffset {
                tui.scrollOffset = max(tui.selectedIndex - 5, 0)
            }
        }

        return true
    }

    private func handlePageDown(maxIndex: Int? = nil) async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("page_down", details: [
            "view": "\(tui.currentView)",
            "selectedIndex": tui.selectedIndex
        ])

        tui.markScrollOperation()

        if tui.currentView == .help || tui.currentView == .about {
            tui.helpScrollOffset = min(tui.helpScrollOffset + 10, 50)
        } else if tui.currentView == .dashboard {
            let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
            tui.quotaScrollOffset = min(tui.quotaScrollOffset + 10, maxQuotaScroll)
        } else if tui.currentView.isDetailView {
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.detailScrollOffset = min(tui.detailScrollOffset + 10, maxScroll)
        } else {
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let effectiveMaxIndex = maxIndex ?? tui.getMaxSelectionIndex()
            let newIndex = min(tui.selectedIndex + pageSize, effectiveMaxIndex)
            tui.selectedIndex = newIndex
            let visibleItems = Int(tui.screenRows) - 8
            if tui.selectedIndex >= tui.scrollOffset + visibleItems {
                tui.scrollOffset = min(tui.selectedIndex - visibleItems + 6, effectiveMaxIndex)
            }
        }

        return true
    }

    // MARK: - Jump Navigation

    private func handleHome() async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("home_key", details: ["view": "\(tui.currentView)"])

        tui.markScrollOperation()

        if tui.currentView.isDetailView {
            tui.detailScrollOffset = 0
        } else if tui.currentView == .help || tui.currentView == .about {
            tui.helpScrollOffset = 0
        } else if tui.currentView == .dashboard {
            tui.quotaScrollOffset = 0
        } else {
            tui.selectedIndex = 0
            tui.scrollOffset = 0
        }

        return true
    }

    private func handleEnd(maxIndex: Int? = nil) async -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("end_key", details: ["view": "\(tui.currentView)"])

        tui.markScrollOperation()

        if tui.currentView.isDetailView {
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.detailScrollOffset = maxScroll
        } else if tui.currentView == .help || tui.currentView == .about {
            tui.helpScrollOffset = 50
        } else if tui.currentView == .dashboard {
            let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
            tui.quotaScrollOffset = maxQuotaScroll
        } else {
            let effectiveMaxIndex = maxIndex ?? tui.getMaxSelectionIndex()
            tui.selectedIndex = max(0, effectiveMaxIndex)
            let visibleItems = Int(tui.screenRows) - 10
            tui.scrollOffset = max(0, tui.selectedIndex - visibleItems + 1)
        }

        return true
    }

    // MARK: - Escape Handling

    private func handleEscape() -> Bool {
        guard let tui = tui else { return false }

        Logger.shared.logUserAction("escape_key", details: [
            "view": "\(tui.currentView)",
            "isDetailView": tui.currentView.isDetailView,
            "hasSearchQuery": tui.searchQuery != nil,
            "multiSelectMode": tui.multiSelectMode
        ])

        // Priority 1: Exit multi-select mode
        if tui.multiSelectMode {
            Logger.shared.logUserAction("exit_multi_select_mode", details: ["selectedCount": tui.multiSelectedResourceIDs.count])
            tui.multiSelectMode = false
            tui.multiSelectedResourceIDs.removeAll()
            tui.statusMessage = "Exited multi-select mode"
            return true
        }

        // Priority 2: Return from help view
        if tui.currentView == .help {
            Logger.shared.logNavigation(".help", to: "\(tui.previousView)")
            tui.changeView(to: tui.previousView, resetSelection: false)
            return true
        }

        // Priority 3: Return from detail views
        if tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: "\(tui.currentView.parentView)", details: ["action": "escape_detail"])

            // Special handling for health dashboard service detail
            if tui.currentView == .healthDashboardServiceDetail {
                tui.healthDashboardNavState.currentSection = .services
                Logger.shared.logUserAction("health_dashboard_return_to_services", details: ["from": "service_detail"])
            }

            tui.changeView(to: tui.currentView.parentView, resetSelection: false)
            tui.selectedResource = nil
            return true
        }

        // Priority 3.5: Return from sub-list views (like Swift container objects)
        if tui.currentView == .swiftContainerDetail {
            Logger.shared.logNavigation("\(tui.currentView)", to: "\(tui.currentView.parentView)", details: ["action": "escape_sublist"])

            // Restore selection to the container that was opened
            if let container = tui.selectedResource as? SwiftContainer,
               let containerName = container.name,
               let index = tui.cachedSwiftContainers.firstIndex(where: { $0.name == containerName }) {
                tui.selectedIndex = index
                // Ensure the selected item is visible in the viewport
                let visibleItems = Int(tui.screenRows) - 10
                if index < tui.scrollOffset {
                    tui.scrollOffset = index
                } else if index >= tui.scrollOffset + visibleItems {
                    tui.scrollOffset = max(0, index - visibleItems + 1)
                }
            }

            tui.changeView(to: tui.currentView.parentView, resetSelection: false)
            tui.selectedResource = nil
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
            if tui.selectedIndex > 0 {
                tui.selectedIndex -= 1
                if tui.selectedIndex < tui.scrollOffset {
                    tui.scrollOffset = tui.selectedIndex
                }
            }
            return true

        case Int32(258): // KEY_DOWN
            if tui.selectedIndex < maxIndex {
                tui.selectedIndex += 1
                let visibleItems = Int(tui.screenRows) - 10
                if tui.selectedIndex >= tui.scrollOffset + visibleItems {
                    tui.scrollOffset = tui.selectedIndex - visibleItems + 1
                }
            }
            return true

        case Int32(338): // PAGE_DOWN
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let newIndex = min(tui.selectedIndex + pageSize, maxIndex)
            tui.selectedIndex = newIndex
            let visibleItems = Int(tui.screenRows) - 8
            if tui.selectedIndex >= tui.scrollOffset + visibleItems {
                tui.scrollOffset = min(tui.selectedIndex - visibleItems + 6, maxIndex)
            }
            return true

        case Int32(339): // PAGE_UP
            let pageSize = min(20, Int(tui.screenRows) - 8)
            let newIndex = max(tui.selectedIndex - pageSize, 0)
            tui.selectedIndex = newIndex
            if tui.selectedIndex < tui.scrollOffset {
                tui.scrollOffset = max(tui.selectedIndex - 5, 0)
            }
            return true

        case Int32(262): // HOME
            tui.selectedIndex = 0
            tui.scrollOffset = 0
            return true

        case Int32(360): // END
            tui.selectedIndex = max(0, maxIndex)
            let visibleItems = Int(tui.screenRows) - 10
            tui.scrollOffset = max(0, tui.selectedIndex - visibleItems + 1)
            return true

        default:
            return false
        }
    }

    /// Handle form navigation (UP/DOWN for field navigation)
    static func handleFormNavigation(_ ch: Int32, fieldCount: Int, tui: TUI) async -> Bool {
        switch ch {
        case Int32(259): // KEY_UP
            if tui.selectedIndex > 0 {
                tui.selectedIndex -= 1
            }
            return true

        case Int32(258): // KEY_DOWN
            if tui.selectedIndex < fieldCount - 1 {
                tui.selectedIndex += 1
            }
            return true

        case Int32(262): // HOME
            tui.selectedIndex = 0
            return true

        case Int32(360): // END
            tui.selectedIndex = max(0, fieldCount - 1)
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
            tui.detailScrollOffset = max(tui.detailScrollOffset - 1, 0)
            return true

        case Int32(258): // KEY_DOWN
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.detailScrollOffset = min(tui.detailScrollOffset + 1, maxScroll)
            return true

        case Int32(339): // PAGE_UP
            tui.detailScrollOffset = max(tui.detailScrollOffset - 10, 0)
            return true

        case Int32(338): // PAGE_DOWN
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.detailScrollOffset = min(tui.detailScrollOffset + 10, maxScroll)
            return true

        case Int32(262): // HOME
            tui.detailScrollOffset = 0
            return true

        case Int32(360): // END
            let maxScroll = tui.calculateMaxDetailScrollOffset()
            tui.detailScrollOffset = maxScroll
            return true

        default:
            return false
        }
    }

    /// Centralized ESC key handling with context awareness
    static func handleEscapeKey(tui: TUI) async -> Bool {
        Logger.shared.logUserAction("escape_key", details: [
            "view": "\(tui.currentView)",
            "isDetailView": tui.currentView.isDetailView,
            "hasSearchQuery": tui.searchQuery != nil,
            "multiSelectMode": tui.multiSelectMode
        ])

        // Priority 1: Exit multi-select mode
        if tui.multiSelectMode {
            Logger.shared.logUserAction("exit_multi_select_mode", details: ["selectedCount": tui.multiSelectedResourceIDs.count])
            tui.multiSelectMode = false
            tui.multiSelectedResourceIDs.removeAll()
            tui.statusMessage = "Exited multi-select mode"
            return true
        }

        // Priority 2: Return from help view
        if tui.currentView == .help {
            Logger.shared.logNavigation(".help", to: "\(tui.previousView)")
            tui.changeView(to: tui.previousView, resetSelection: false)
            return true
        }

        // Priority 3: Return from detail views
        if tui.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.currentView)", to: "\(tui.currentView.parentView)", details: ["action": "escape_detail"])

            // Special handling for health dashboard service detail
            if tui.currentView == .healthDashboardServiceDetail {
                tui.healthDashboardNavState.currentSection = .services
                Logger.shared.logUserAction("health_dashboard_return_to_services", details: ["from": "service_detail"])
            }

            tui.changeView(to: tui.currentView.parentView, resetSelection: false)
            tui.selectedResource = nil
            return true
        }

        // Priority 3.5: Return from sub-list views (like Swift container objects)
        if tui.currentView == .swiftContainerDetail {
            Logger.shared.logNavigation("\(tui.currentView)", to: "\(tui.currentView.parentView)", details: ["action": "escape_sublist"])

            // Restore selection to the container that was opened
            if let container = tui.selectedResource as? SwiftContainer,
               let containerName = container.name,
               let index = tui.cachedSwiftContainers.firstIndex(where: { $0.name == containerName }) {
                tui.selectedIndex = index
                // Ensure the selected item is visible in the viewport
                let visibleItems = Int(tui.screenRows) - 10
                if index < tui.scrollOffset {
                    tui.scrollOffset = index
                } else if index >= tui.scrollOffset + visibleItems {
                    tui.scrollOffset = max(0, index - visibleItems + 1)
                }
            }

            tui.changeView(to: tui.currentView.parentView, resetSelection: false)
            tui.selectedResource = nil
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
}
