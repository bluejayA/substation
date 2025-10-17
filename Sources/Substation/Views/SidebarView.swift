import Foundation
import OSClient
import SwiftNCurses

@MainActor
struct SidebarView {

    static func draw(screen: OpaquePointer?, screenCols: Int32, screenRows: Int32, currentView: ViewMode, tui: TUI) async {
        let sidebarWidth = LayoutUtilities.shared.calculateSidebarWidth(screenCols: screenCols)

        // Skip rendering if sidebar is hidden (width = 0)
        guard sidebarWidth > 0 else { return }

        let surface = SwiftNCurses.surface(from: screen)

        // Clear and draw sidebar background using SwiftNCurses
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
                views = ViewMode.allCases.filter { isNavigableView($0) }.sorted { $0.title < $1.title }
            }

            let maxNavItems = Int(screenRows - 8) - 5 // Leave space for Resource Summary
            let availableViews = views.prefix(maxNavItems)

            for (index, view) in availableViews.enumerated() {
                // Highlight first match with success, rest with info
                let isFilteredView = isInCommandMode && !commandQuery.isEmpty
                let navStyle: TextStyle = (index == 0 && isFilteredView) ? .success : .info
                let titleStyle: TextStyle = view == currentView ? .emphasis : navStyle

                // Display view title without key shortcuts
                let titleText = Text(view.title).styled(titleStyle).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 1))
                components.append(titleText)
            }
        }

        // Render the entire sidebar as a VStack
        let sidebarComponent = VStack(spacing: 0, children: components)
        let contentBounds = Rect(x: 0, y: 2, width: sidebarWidth, height: screenRows - 4)
        await SwiftNCurses.render(sidebarComponent, on: surface, in: contentBounds)

        // Vertical separator using SwiftNCurses
        let separatorComponents = (0..<Int(screenRows - 4)).map { _ in Text("|").info() }
        let separatorSection = VStack(spacing: 0, children: separatorComponents)
        let separatorBounds = Rect(x: sidebarWidth, y: 2, width: 1, height: screenRows - 4)
        await SwiftNCurses.render(separatorSection, on: surface, in: separatorBounds)
    }

    // MARK: - Command Filtering

    private static func filterViewsByCommand(commandQuery: String, allViews: [ViewMode]) -> [ViewMode] {
        // Show all navigable views when command mode is active but query is empty
        guard !commandQuery.isEmpty else {
            return allViews.filter { isNavigableView($0) }.sorted { $0.title < $1.title }
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
        // Only show views that have navigation commands defined in ResourceRegistry
        return ResourceRegistry.shared.hasNavigationCommand(for: view)
    }
}