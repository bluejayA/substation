import Foundation
import OSClient
import SwiftTUI

@MainActor
struct SidebarView {

    static func draw(screen: OpaquePointer?, screenCols: Int32, screenRows: Int32, currentView: ViewMode, tui: TUI) async {
        let sidebarWidth = LayoutUtilities.shared.calculateSidebarWidth(screenCols: screenCols)

        // Skip rendering if sidebar is hidden (width = 0)
        guard sidebarWidth > 0 else { return }

        let surface = SwiftTUI.surface(from: screen)

        // Clear and draw sidebar background using SwiftTUI
        let sidebarBounds = Rect(x: 0, y: 2, width: sidebarWidth, height: screenRows - 4)
        await surface.fill(rect: sidebarBounds, character: " ", style: .secondary)

        var components: [any Component] = []

        // Navigation section with bounds checking
        if screenRows > 5 && screenCols > Int32(sidebarWidth) {
            // Get command input state
            let isInCommandMode = tui.unifiedInputState.isCommandMode && tui.unifiedInputState.isActive
            let commandQuery = isInCommandMode ? (tui.unifiedInputState.command ?? "") : ""

            if isInCommandMode && !commandQuery.isEmpty {
                components.append(Text("Filtered (\(commandQuery))").emphasis().bold().padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 0)))
            } else if isInCommandMode {
                components.append(Text("All Resources").emphasis().bold().padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 0)))
            } else {
                components.append(Text("Navigation").emphasis().bold().padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 0)))
            }

            // Filter views based on command input
            let views: [ViewMode]
            if isInCommandMode {
                views = filterViewsByCommand(commandQuery: commandQuery, allViews: ViewMode.allCases)
            } else {
                views = ViewMode.allCases.filter { !$0.key.isEmpty }.sorted { $0.title < $1.title }
            }

            let maxNavItems = Int(screenRows - 8) - 5 // Leave space for Resource Summary
            let availableViews = views.prefix(maxNavItems)

            for (index, view) in availableViews.enumerated() {
                // Highlight first match with success, rest with info
                let isFilteredView = isInCommandMode && !commandQuery.isEmpty
                let navStyle: TextStyle = (index == 0 && isFilteredView) ? .success : .info
                let keyStyle: TextStyle = view == currentView ? .emphasis : .secondary

                // Combine key and text for compact mode
                var concatenated = [
                    Text(view.key).styled(keyStyle).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 1))
                ]
                concatenated.append(Text("\(view.title)").styled(navStyle).padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 1)))
                components.append(HStack(spacing: 0, children: concatenated))
            }
        }

        // Render the entire sidebar as a VStack
        let sidebarComponent = VStack(spacing: 0, children: components)
        let contentBounds = Rect(x: 0, y: 2, width: sidebarWidth, height: screenRows - 4)
        await SwiftTUI.render(sidebarComponent, on: surface, in: contentBounds)

        // Vertical separator using SwiftTUI
        let separatorComponents = (0..<Int(screenRows - 4)).map { _ in Text("|").info() }
        let separatorSection = VStack(spacing: 0, children: separatorComponents)
        let separatorBounds = Rect(x: sidebarWidth, y: 2, width: 1, height: screenRows - 4)
        await SwiftTUI.render(separatorSection, on: surface, in: separatorBounds)
    }

    // MARK: - Command Filtering

    private static func filterViewsByCommand(commandQuery: String, allViews: [ViewMode]) -> [ViewMode] {
        // Show all navigable views when command mode is active but query is empty
        guard !commandQuery.isEmpty else {
            return allViews.filter { !$0.key.isEmpty && isNavigableView($0) }.sorted { $0.title < $1.title }
        }

        let query = commandQuery.lowercased()

        // Use ResourceRegistry's ranked matching for optimal ordering
        let rankedMatches = ResourceRegistry.shared.rankedMatches(for: query)

        // Convert ranked matches to ViewModes, filtering for navigable views
        var viewModeSet = Set<ViewMode>()
        var orderedViews: [ViewMode] = []

        for match in rankedMatches {
            let viewMode = match.viewMode
            // Only include each ViewMode once and only if it's navigable
            if !viewModeSet.contains(viewMode) && isNavigableView(viewMode) {
                viewModeSet.insert(viewMode)
                orderedViews.append(viewMode)
            }
        }

        return orderedViews
    }

    private static func isNavigableView(_ view: ViewMode) -> Bool {
        // Filter out detail views, create views, and management views
        switch view {
        case .loading, .help, .about:
            return true
        case .serverDetail, .serverGroupDetail, .networkDetail, .securityGroupDetail,
             .volumeDetail, .volumeArchiveDetail, .imageDetail, .flavorDetail,
             .subnetDetail, .portDetail, .routerDetail, .floatingIPDetail,
             .keyPairDetail, .healthDashboardServiceDetail,
             .barbicanSecretDetail, .barbicanContainerDetail, .octaviaLoadBalancerDetail,
             .swiftContainerDetail, .swiftObjectDetail:
            return false
        case .serverCreate, .serverGroupCreate, .networkCreate, .securityGroupCreate,
             .subnetCreate, .volumeCreate, .portCreate, .routerCreate, .floatingIPCreate,
             .keyPairCreate, .barbicanSecretCreate, .barbicanContainerCreate,
             .octaviaLoadBalancerCreate, .swiftContainerCreate, .swiftUpload:
            return false
        case .serverSecurityGroups, .serverNetworkInterfaces, .serverGroupManagement,
             .volumeManagement, .floatingIPServerSelect, .serverSnapshotManagement,
             .serverResize, .volumeSnapshotManagement, .volumeBackupManagement,
             .networkServerAttachment, .securityGroupServerAttachment,
             .securityGroupServerManagement, .networkServerManagement,
             .volumeServerManagement, .floatingIPServerManagement,
             .subnetRouterManagement, .flavorSelection, .securityGroupRuleManagement:
            return false
        default:
            return true
        }
    }
}