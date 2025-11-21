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

        // Dashboard quota scrolling
        if tui.viewCoordinator.currentView == .dashboard {
            tui.viewCoordinator.quotaScrollOffset = max(tui.viewCoordinator.quotaScrollOffset - 1, 0)
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

        // Dashboard quota scrolling
        if tui.viewCoordinator.currentView == .dashboard {
            let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
            tui.viewCoordinator.quotaScrollOffset = min(tui.viewCoordinator.quotaScrollOffset + 1, maxQuotaScroll)
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
        if tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: "\(tui.viewCoordinator.currentView.parentView)", details: ["action": "escape_detail"])

            // Special handling for Swift object detail view
            if tui.viewCoordinator.currentView == .swiftObjectDetail {
                // Restore selection to the object that was opened
                if let object = tui.viewCoordinator.selectedResource as? SwiftObject,
                   let objectName = object.name,
                   let objects = tui.cacheManager.cachedSwiftObjects,
                   let index = objects.firstIndex(where: { $0.name == objectName }) {
                    tui.viewCoordinator.selectedIndex = index
                    // Ensure the selected item is visible in the viewport
                    let visibleItems = Int(tui.screenRows) - 10
                    if index < tui.viewCoordinator.scrollOffset {
                        tui.viewCoordinator.scrollOffset = index
                    } else if index >= tui.viewCoordinator.scrollOffset + visibleItems {
                        tui.viewCoordinator.scrollOffset = max(0, index - visibleItems + 1)
                    }
                }
            }

            // Special handling for health dashboard service detail
            if tui.viewCoordinator.currentView == .healthDashboardServiceDetail {
                tui.viewCoordinator.healthDashboardNavState.currentSection = .services
                Logger.shared.logUserAction("health_dashboard_return_to_services", details: ["from": "service_detail"])
            }

            tui.changeView(to: tui.viewCoordinator.currentView.parentView, resetSelection: false)
            tui.viewCoordinator.selectedResource = nil
            return true
        }

        // Priority 3.5: Return from sub-list views (like Swift container objects with hierarchical navigation)
        if tui.viewCoordinator.currentView == .swiftContainerDetail {
            // Check if we can navigate up within the hierarchy
            if tui.viewCoordinator.swiftNavState.canNavigateUp() && !tui.viewCoordinator.swiftNavState.isAtContainerRoot {
                // Navigate up one directory level
                Logger.shared.logUserAction("swift_navigate_up", details: [
                    "fromPath": tui.viewCoordinator.swiftNavState.currentPathString,
                    "depth": tui.viewCoordinator.swiftNavState.depth
                ])

                tui.viewCoordinator.swiftNavState.navigateUp()

                // Reset selection to top
                tui.viewCoordinator.selectedIndex = 0
                tui.viewCoordinator.scrollOffset = 0

                // Stay in the same view (swiftContainerDetail)
                tui.markNeedsRedraw()

                Logger.shared.logInfo("Navigated up to path: \(tui.viewCoordinator.swiftNavState.currentPathString)")
                return true
            } else {
                // Navigate back to container list
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".swift", details: [
                    "action": "escape_container",
                    "containerName": tui.viewCoordinator.swiftNavState.currentContainer ?? "unknown"
                ])

                // Restore selection to the container that was opened
                if let containerName = tui.viewCoordinator.swiftNavState.currentContainer,
                   let index = tui.cacheManager.cachedSwiftContainers.firstIndex(where: { $0.name == containerName }) {
                    tui.viewCoordinator.selectedIndex = index
                    // Ensure the selected item is visible in the viewport
                    let visibleItems = Int(tui.screenRows) - 10
                    if index < tui.viewCoordinator.scrollOffset {
                        tui.viewCoordinator.scrollOffset = index
                    } else if index >= tui.viewCoordinator.scrollOffset + visibleItems {
                        tui.viewCoordinator.scrollOffset = max(0, index - visibleItems + 1)
                    }
                }

                // Reset navigation state
                tui.viewCoordinator.swiftNavState.reset()

                // Return to container list view
                tui.changeView(to: .swift, resetSelection: false)
                tui.viewCoordinator.selectedResource = nil
                return true
            }
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
        if tui.viewCoordinator.currentView.isDetailView {
            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: "\(tui.viewCoordinator.currentView.parentView)", details: ["action": "escape_detail"])

            // Special handling for Swift object detail view
            if tui.viewCoordinator.currentView == .swiftObjectDetail {
                // Restore selection to the object that was opened
                if let object = tui.viewCoordinator.selectedResource as? SwiftObject,
                   let objectName = object.name,
                   let objects = tui.cacheManager.cachedSwiftObjects,
                   let index = objects.firstIndex(where: { $0.name == objectName }) {
                    tui.viewCoordinator.selectedIndex = index
                    // Ensure the selected item is visible in the viewport
                    let visibleItems = Int(tui.screenRows) - 10
                    if index < tui.viewCoordinator.scrollOffset {
                        tui.viewCoordinator.scrollOffset = index
                    } else if index >= tui.viewCoordinator.scrollOffset + visibleItems {
                        tui.viewCoordinator.scrollOffset = max(0, index - visibleItems + 1)
                    }
                }
            }

            // Special handling for health dashboard service detail
            if tui.viewCoordinator.currentView == .healthDashboardServiceDetail {
                tui.viewCoordinator.healthDashboardNavState.currentSection = .services
                Logger.shared.logUserAction("health_dashboard_return_to_services", details: ["from": "service_detail"])
            }

            tui.changeView(to: tui.viewCoordinator.currentView.parentView, resetSelection: false)
            tui.viewCoordinator.selectedResource = nil
            return true
        }

        // Priority 3.5: Return from sub-list views (like Swift container objects with hierarchical navigation)
        if tui.viewCoordinator.currentView == .swiftContainerDetail {
            // Check if we can navigate up within the hierarchy
            if tui.viewCoordinator.swiftNavState.canNavigateUp() && !tui.viewCoordinator.swiftNavState.isAtContainerRoot {
                // Navigate up one directory level
                Logger.shared.logUserAction("swift_navigate_up", details: [
                    "fromPath": tui.viewCoordinator.swiftNavState.currentPathString,
                    "depth": tui.viewCoordinator.swiftNavState.depth
                ])

                tui.viewCoordinator.swiftNavState.navigateUp()

                // Reset selection to top
                tui.viewCoordinator.selectedIndex = 0
                tui.viewCoordinator.scrollOffset = 0

                // Stay in the same view (swiftContainerDetail)
                tui.markNeedsRedraw()

                Logger.shared.logInfo("Navigated up to path: \(tui.viewCoordinator.swiftNavState.currentPathString)")
                return true
            } else {
                // Navigate back to container list
                Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".swift", details: [
                    "action": "escape_container",
                    "containerName": tui.viewCoordinator.swiftNavState.currentContainer ?? "unknown"
                ])

                // Restore selection to the container that was opened
                if let containerName = tui.viewCoordinator.swiftNavState.currentContainer,
                   let index = tui.cacheManager.cachedSwiftContainers.firstIndex(where: { $0.name == containerName }) {
                    tui.viewCoordinator.selectedIndex = index
                    // Ensure the selected item is visible in the viewport
                    let visibleItems = Int(tui.screenRows) - 10
                    if index < tui.viewCoordinator.scrollOffset {
                        tui.viewCoordinator.scrollOffset = index
                    } else if index >= tui.viewCoordinator.scrollOffset + visibleItems {
                        tui.viewCoordinator.scrollOffset = max(0, index - visibleItems + 1)
                    }
                }

                // Reset navigation state
                tui.viewCoordinator.swiftNavState.reset()

                // Return to container list view
                tui.changeView(to: .swift, resetSelection: false)
                tui.viewCoordinator.selectedResource = nil
                return true
            }
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
