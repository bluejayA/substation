import Foundation
import SwiftNCurses
import OSClient

// MARK: - Advanced Search View

struct AdvancedSearchView {
    // MARK: - Search State

    @MainActor
    private static var tui: TUI?
    @MainActor
    private static var searchEngine: SearchEngine = SearchEngine.shared

    // Enhanced search state
    @MainActor
    private static var inputState: UnifiedInputView.InputState = UnifiedInputView.InputState()
    @MainActor
    private static var currentQuery: String = ""
    @MainActor
    private static var globalSearchQuery: GlobalSearchQuery = GlobalSearchQuery()
    @MainActor
    private static var unifiedResults: UnifiedSearchResults?
    @MainActor
    private static var searchResults: [SearchResult] = []
    @MainActor
    private static var filteredResults: [SearchResult] = [] // Client-side filtered results
    @MainActor
    private static var activeSuggestions: [SearchSuggestion] = []

    // Enhanced UI state
    @MainActor
    private static var selectedResourceId: String? = nil  // ID-based selection (survives filtering)
    @MainActor
    private static var showingResultDetail: Bool = false
    @MainActor
    private static var showingCrossServiceResults: Bool = false
    @MainActor
    private static var isSearching: Bool = false
    @MainActor
    private static var searchDebounceTask: Task<Void, Never>? = nil
    @MainActor
    private static var lastSearchTime: TimeInterval = 0.0
    @MainActor
    private static var lastTypingTime: TimeInterval = 0.0
    @MainActor
    private static var enableCrossServiceSearch: Bool = true // Always enabled
    @MainActor
    private static var enableParallelSearch: Bool = true
    @MainActor
    private static var isLoadingLiveData: Bool = false

    // Pagination
    @MainActor
    private static var currentPage: Int = 0
    @MainActor
    private static var resultsPerPage: Int = 20
    @MainActor
    private static var totalResults: Int = 0

    // MARK: - Selection Helpers

    /// Get the current selected index in the results list
    /// Converts from ID-based selection to index-based for display
    @MainActor
    private static func getSelectedIndex(in results: [SearchResult]) -> Int {
        guard let resourceId = selectedResourceId else { return 0 }
        return results.firstIndex { $0.resourceId == resourceId } ?? 0
    }

    /// Set the selected resource by ID
    @MainActor
    private static func selectResource(_ result: SearchResult) {
        selectedResourceId = result.resourceId
    }

    /// Move selection up or down by offset
    @MainActor
    private static func moveSelection(by offset: Int, in results: [SearchResult]) {
        guard !results.isEmpty else { return }

        let currentIndex = getSelectedIndex(in: results)
        let newIndex = max(0, min(currentIndex + offset, results.count - 1))

        if newIndex < results.count {
            selectedResourceId = results[newIndex].resourceId
        }
    }

    // MARK: - Layout Constants

    private static let minScreenWidth: Int32 = 50
    private static let minScreenHeight: Int32 = 10
    private static let searchBarHeight: Int32 = 4 // Increased for better input area
    private static let statusBarHeight: Int32 = 1

    // Column width constants for aligned display
    private static let typeColumnWidth = 8
    private static let statusColumnWidth = 10
    private static let indicatorsColumnWidth = 2
    private static let columnSpacing = 4 // spaces between columns
    private static let marginWidth = 6 // left/right margins

    // MARK: - Search Performance Constants

    private static let searchDebounceDelay: TimeInterval = 0.2 // 200ms debounce
    private static let maxClientFilterResults = 1000 // Client-side filter threshold

    // MARK: - Main Rendering

    @MainActor
    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                     width: Int32, height: Int32, tui: TUI) async {

        // Initialize TUI reference
        self.tui = tui

        // Initialize search engine with sample data if empty
        await initializeSearchEngineIfNeeded()

        // Create surface for rendering
        let surface = SwiftNCurses.surface(from: screen)

        // Bounds checking
        guard width >= minScreenWidth && height >= minScreenHeight else {
            let errorBounds = Rect(x: startCol, y: startRow, width: max(1, width), height: max(1, height))
            await SwiftNCurses.render(Text("Screen too small for Search").error(), on: surface, in: errorBounds)
            return
        }

        // Calculate layout
        let contentHeight = height - searchBarHeight - statusBarHeight

        // Build main component hierarchy
        var components: [any Component] = []

        // Add search bar
        components.append(createSearchBar(width: width))

        // Add main content based on current view state
        if showingCrossServiceResults {
            components.append(createCrossServiceResults(width: width, height: contentHeight))
        } else if showingResultDetail && selectedResourceId != nil {
            components.append(createResultDetail(width: width, height: contentHeight))
        } else {
            components.append(createSearchResults(width: width, height: contentHeight))
        }

        // Add status bar
        components.append(createStatusBar(width: width))

        // Create main layout
        let mainComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        await SwiftNCurses.render(mainComponent, on: surface, in: bounds)
    }

    // MARK: - Search Bar Component

    @MainActor
    private static func createSearchBar(width: Int32) -> any Component {
        // Use UnifiedInputView for the search bar
        let statusIndicator = UnifiedInputView.createStatusIndicator(
            isSearching: isSearching,
            resultCount: filteredResults.isEmpty ? searchResults.count : filteredResults.count
        )

        let resultsSummary: String
        if isLoadingLiveData {
            resultsSummary = "  Loading live data..."
        } else {
            let totalResults = searchResults.count
            let filteredCount = filteredResults.isEmpty ? totalResults : filteredResults.count
            resultsSummary = UnifiedInputView.createResultsSummary(
                isSearching: isSearching,
                totalResults: totalResults,
                filteredCount: filteredCount != totalResults ? filteredCount : nil,
                searchTime: lastSearchTime > 0 ? lastSearchTime : nil
            )
        }

        let hints = getContextualHints()

        return UnifiedInputView.createInputComponent(
            state: inputState,
            width: width,
            statusIndicator: statusIndicator,
            resultsSummary: resultsSummary,
            hints: hints
        )
    }

    @MainActor
    private static func getContextualHints() -> String {
        if showingCrossServiceResults {
            return "C: Toggle view | ESC: Back"
        } else if !inputState.displayText.isEmpty && (!filteredResults.isEmpty || !searchResults.isEmpty) {
            return "UP/DOWN: Navigate | ENTER: Load | ESC: Clear"
        } else if !inputState.displayText.isEmpty {
            return "ESC: Clear search"
        } else {
            return "Type to search across OpenStack services | : for commands"
        }
    }

    // MARK: - Search Results Component

    @MainActor
    private static func createSearchResults(width: Int32, height: Int32) -> any Component {
        var components: [any Component] = []

        // Determine what results to show based on search state
        let resultsToShow: [SearchResult]
        if inputState.displayText.isEmpty {
            // No query - show all search results (initial load)
            resultsToShow = searchResults
        } else {
            // There's a query - show filtered results (which may be empty if no matches)
            resultsToShow = filteredResults
        }

        if resultsToShow.isEmpty {
            if isLoadingLiveData {
                return createLoadingDataIndicator()
            } else if inputState.displayText.isEmpty {
                return createWelcomeScreen(width: width, height: height)
            } else if isSearching {
                return createSearchingIndicator()
            } else {
                return createNoResults()
            }
        }

        // Enhanced results header with service breakdown
        let serviceInfo = if let unified = unifiedResults {
            " | Services: \(unified.serviceResults.count) | Cache Hit: \(String(format: "%.1f", unified.cacheHitRate * 100))%"
        } else {
            ""
        }

        // Simpler, cleaner header (fzf-style)
        if lastSearchTime > 0 {
            let searchTimeMs = String(format: "%.0f", lastSearchTime * 1000)
            let headerText = "Found \(resultsToShow.count) results (\(searchTimeMs)ms)\(serviceInfo)"
            components.append(
                Text(headerText)
                    .secondary()
                    .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
            )
        }

        // Column headers - aligned with data rows
        let typeHeader = "TYPE".padding(toLength: typeColumnWidth, withPad: " ", startingAt: 0)
        let statusHeader = "STATUS".padding(toLength: statusColumnWidth, withPad: " ", startingAt: 0)
        let nameWidth = max(Int(width) - typeColumnWidth - statusColumnWidth - 15 - columnSpacing - marginWidth, 10)
        let nameHeader = "NAME".padding(toLength: nameWidth, withPad: " ", startingAt: 0)
        let createdHeader = "CREATED"
        let indicatorsHeader = String(repeating: " ", count: indicatorsColumnWidth)

        let headers = "\(typeHeader) \(nameHeader) \(statusHeader) \(createdHeader) \(indicatorsHeader)"
        components.append(
            Text(String(headers.prefix(Int(width) - 2)))
                .muted()
                .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
        )

        // Results list - use ID-based selection
        let availableRows = Int(height) - (lastSearchTime > 0 ? 3 : 2) // Header + column header
        let selectedIndex = getSelectedIndex(in: resultsToShow)
        let startIndex = max(0, selectedIndex - availableRows / 2)
        let endIndex = min(startIndex + availableRows, resultsToShow.count)

        var resultComponents: [any Component] = []
        for i in startIndex..<endIndex {
            let result = resultsToShow[i]
            let isSelected = i == selectedIndex

            resultComponents.append(createSearchResultRow(result, isSelected: isSelected, width: Int(width), query: inputState.displayText))
        }

        if !resultComponents.isEmpty {
            components.append(
                VStack(spacing: 0, children: resultComponents)
                    .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
            )
        }

        // Pagination info (fzf-style)
        if resultsToShow.count > availableRows {
            let currentPage = selectedIndex / availableRows + 1
            let totalPages = Int(ceil(Double(resultsToShow.count) / Double(availableRows)))
            let pageInfo = "[\(currentPage)/\(totalPages)]"
            components.append(
                Text(pageInfo)
                    .muted()
                    .padding(EdgeInsets(top: 1, leading: Int32(Int(width) - pageInfo.count - 4), bottom: 0, trailing: 0))
            )
        }

        return VStack(spacing: 0, children: components)
    }

    @MainActor
    private static func createSearchResultRow(_ result: SearchResult, isSelected: Bool, width: Int, query: String = "") -> any Component {
        let style: TextStyle = isSelected ? .accent : .secondary

        // Format result line components with consistent column widths
        let typeStr = String(result.resourceType.displayName.prefix(typeColumnWidth)).padding(toLength: typeColumnWidth, withPad: " ", startingAt: 0)
        let statusStr = String((result.status ?? "Unknown").prefix(statusColumnWidth)).padding(toLength: statusColumnWidth, withPad: " ", startingAt: 0)
        let createdStr = result.createdAt?.formatted(.relative(presentation: .named)) ?? "Unknown"

        // Use same nameWidth calculation as headers
        let nameWidth = max(width - typeColumnWidth - statusColumnWidth - 15 - columnSpacing - marginWidth, 10)
        let nameText = result.name ?? result.resourceId
        let truncatedName = String(nameText.prefix(nameWidth)).padding(toLength: nameWidth, withPad: " ", startingAt: 0)

        // Show relevance score indicator and IP indicator (but keep them minimal)
        let scoreIndicator = result.relevanceScore > 8 ? "*" : ""
        let ipIndicator = !result.ipAddresses.isEmpty ? "+" : ""
        let indicators = "\(scoreIndicator)\(ipIndicator)".padding(toLength: indicatorsColumnWidth, withPad: " ", startingAt: 0)

        let rowText = "\(typeStr) \(truncatedName) \(statusStr) \(createdStr) \(indicators)"
        let truncatedRow = String(rowText.prefix(width - 4))

        return Text(truncatedRow).styled(style)
    }

    // MARK: - Welcome Screen Component

    @MainActor
    private static func createWelcomeScreen(width: Int32, height: Int32) -> any Component {
        var components: [any Component] = []

        let welcomeLines = [
            "Search",
            "",
            "Start typing to search across all OpenStack resources",
            "Cross-service search is enabled by default"
        ]

        for (index, line) in welcomeLines.enumerated() {
            let style: TextStyle = index == 0 ? .accent : .secondary
            components.append(
                Text(line)
                    .styled(style)
                    .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
            )
        }

        return VStack(spacing: 0, children: components)
            .padding(EdgeInsets(top: Int32(height) / 4, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Searching Indicator Component

    @MainActor
    private static func createSearchingIndicator() -> any Component {
        // Simple spinning indicator
        let spinner = ["|", "/", "-", "\\"]
        let spinnerChar = spinner[Int(Date().timeIntervalSince1970) % spinner.count]

        return VStack(spacing: 0, children: [
            Text("Searching... \(spinnerChar)")
                .accent().bold()
                .padding(EdgeInsets(top: 2, leading: 4, bottom: 0, trailing: 0))
        ])
    }

    // MARK: - Loading Data Indicator Component

    @MainActor
    private static func createLoadingDataIndicator() -> any Component {
        // Simple spinning indicator for data loading
        let spinner = ["|", "/", "-", "\\"]
        let spinnerChar = spinner[Int(Date().timeIntervalSince1970) % spinner.count]

        return VStack(spacing: 0, children: [
            Text("Loading OpenStack data... \(spinnerChar)")
                .info().bold()
                .padding(EdgeInsets(top: 2, leading: 4, bottom: 0, trailing: 0)),
            Text("This may take a few seconds depending on your OpenStack environment size")
                .muted()
                .padding(EdgeInsets(top: 1, leading: 4, bottom: 0, trailing: 0))
        ])
    }

    // MARK: - No Results Component

    @MainActor
    private static func createNoResults() -> any Component {
        return VStack(spacing: 0, children: [
            Text("No results found for '\(currentQuery)'")
                .warning()
                .padding(EdgeInsets(top: 2, leading: 4, bottom: 0, trailing: 0)),
            Text("Try a different search term or adjust your filters")
                .muted()
                .padding(EdgeInsets(top: 1, leading: 4, bottom: 0, trailing: 0))
        ])
    }



    // MARK: - Cross-Service Results Component

    @MainActor
    private static func createCrossServiceResults(width: Int32, height: Int32) -> any Component {
        var components: [any Component] = []

        components.append(
            Text("Cross-Service Search Results")
                .primary().bold()
                .padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0))
        )

        if let unified = unifiedResults, !unified.serviceResults.isEmpty {
            var serviceComponents: [any Component] = []

            for serviceResult in unified.serviceResults {
                let serviceHeader = "\(serviceResult.serviceName.capitalized): \(serviceResult.items.count) results (\(String(format: "%.1f", serviceResult.searchTime * 1000))ms)"
                let headerStyle: TextStyle = serviceResult.isSuccessful ? .primary : .warning

                serviceComponents.append(
                    Text(serviceHeader)
                        .styled(headerStyle).bold()
                        .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
                )

                // Show top results for each service
                for (index, result) in serviceResult.items.prefix(3).enumerated() {
                    let resultLine = "  \(index + 1). \(result.resourceType.displayName): \(result.name ?? result.resourceId)"
                    let truncatedLine = String(resultLine.prefix(Int(width) - 4))

                    serviceComponents.append(
                        Text(truncatedLine)
                            .secondary()
                            .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
                    )
                }

                if serviceResult.items.count > 3 {
                    serviceComponents.append(
                        Text("  ... and \(serviceResult.items.count - 3) more")
                            .muted()
                            .padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0))
                    )
                }
            }

            components.append(VStack(spacing: 0, children: serviceComponents))
        } else {
            components.append(
                Text("No cross-service results available. Enable cross-service search and perform a query.")
                    .info()
                    .padding(EdgeInsets(top: 1, leading: 4, bottom: 0, trailing: 0))
            )
        }

        return VStack(spacing: 0, children: components)
    }


    // MARK: - Result Detail Component

    @MainActor
    private static func createResultDetail(width: Int32, height: Int32) -> any Component {
        let resultsToShow: [SearchResult]
        if inputState.displayText.isEmpty {
            resultsToShow = searchResults
        } else {
            resultsToShow = filteredResults
        }

        let selectedIndex = getSelectedIndex(in: resultsToShow)
        guard selectedIndex < resultsToShow.count else {
            return Text("No result selected").warning()
        }

        let result = resultsToShow[selectedIndex]
        var components: [any Component] = []

        // Header
        components.append(
            Text("Resource Detail: \(result.resourceType.displayName)")
                .primary().bold()
                .padding(EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0))
        )

        // Basic information
        let details = [
            ("ID", result.resourceId),
            ("Name", result.name ?? "Unknown"),
            ("Status", result.status ?? "Unknown"),
            ("Created", result.createdAt?.formatted(.dateTime) ?? "Unknown"),
            ("Updated", result.updatedAt?.formatted(.dateTime) ?? "Unknown")
        ]

        for (label, value) in details {
            components.append(
                Text("\(label): \(value)")
                    .secondary()
                    .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
            )
        }

        // IP Addresses
        if !result.ipAddresses.isEmpty {
            components.append(
                Text("IP Addresses:")
                    .accent().bold()
                    .padding(EdgeInsets(top: 1, leading: 2, bottom: 0, trailing: 0))
            )

            for ip in result.ipAddresses.prefix(5) {
                components.append(
                    Text("  - \(ip)")
                        .secondary()
                        .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                )
            }
        }

        // Metadata
        if !result.metadata.isEmpty {
            components.append(
                Text("Metadata:")
                    .accent().bold()
                    .padding(EdgeInsets(top: 1, leading: 2, bottom: 0, trailing: 0))
            )

            for (key, value) in result.metadata.prefix(5) {
                components.append(
                    Text("  \(key): \(value)")
                        .secondary()
                        .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                )
            }
        }

        return VStack(spacing: 0, children: components)
    }

    // MARK: - Status Bar Component

    @MainActor
    private static func createStatusBar(width: Int32) -> any Component {
        let resultsToShow: [SearchResult] = inputState.displayText.isEmpty ? searchResults : filteredResults
        let selectedIndex = resultsToShow.isEmpty ? 0 : getSelectedIndex(in: resultsToShow)

        let statusText = if isSearching {
            "Searching..."
        } else if searchResults.isEmpty && !currentQuery.isEmpty {
            "No results"
        } else if !resultsToShow.isEmpty {
            "Results: \(resultsToShow.count) | Selected: \(selectedIndex + 1)"
        } else {
            "Ready"
        }

        let padding = String(repeating: " ", count: max(0, Int(width) - statusText.count - 2))

        return Text(statusText + padding)
            .primary().bold()
            .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 0))
    }

    // MARK: - Input Handling

    @MainActor
    static func handleInput(_ key: Int32) -> Bool {
        // Determine input mode based on current state
        let inMainSearchMode = !showingCrossServiceResults && !showingResultDetail

        // PRIORITY 1: Handle navigation keys for immediate response
        // Enter key must be handled HERE (not in UnifiedInputView) to navigate to results
        // instead of triggering a new search
        let priority = InputPriority.classify(key)

        if inMainSearchMode && priority == .navigation {
            // Enter key navigates to selected result
            if key == 10 || key == 13 {
                if !filteredResults.isEmpty || !searchResults.isEmpty {
                    InputPriority.logInput(key, layer: "AdvancedSearchView-Navigation", handled: true)
                    navigateToDetailView()
                    return true
                }
            }
            // Arrow keys handled by handleNavigationInput
        }

        // PRIORITY 2: Try to handle input with UnifiedInputView
        if inMainSearchMode {
            let result = UnifiedInputView.handleInput(key, state: &inputState)

            switch result {
            case .ignored:
                break // Fall through to legacy handling

            case .updated:
                lastTypingTime = Date().timeIntervalSinceReferenceDate
                performClientSideFilter()
                scheduleSearch()
                return true

            case .cleared:
                clearSearchResults()
                return true

            case .cancelled:
                if showingResultDetail || showingCrossServiceResults {
                    showingResultDetail = false
                    showingCrossServiceResults = false
                    return true
                } else if inputState.displayText.isEmpty {
                    // ESC with empty query - return to previous view
                    if let tuiInstance = tui {
                        tuiInstance.changeView(to: tuiInstance.previousView)
                        return true
                    }
                }
                return false

            case .commandEntered(let command):
                // Handle command mode in next iteration
                Logger.shared.logInfo("Command entered: \(command)")
                inputState.clear()
                return true

            case .searchEntered(let query):
                // This case should never be reached due to Enter handling above
                // But keep it for safety
                Logger.shared.logInfo("AdvancedSearchView - searchEntered case reached (should not happen)")
                currentQuery = query
                Task {
                    await performSearch()
                }
                return true

            case .tabCompletion(_):
                // Tab completion not used in search view
                return false

            case .historyPrevious, .historyNext:
                // History navigation not used in search view
                return false
            }
        }

        // Handle ESC for detail/cross-service views
        if key == 27 { // ESC
            if showingResultDetail || showingCrossServiceResults {
                showingResultDetail = false
                showingCrossServiceResults = false
                return true
            }
            // ESC not handled locally - delegate back to TUI's navigation handling
            // This allows NavigationInputHandler to handle ESC (e.g., exit multi-select, go back from detail views)
            return false
        }

        // Handle navigation and special keys
        switch key {
        case 258, 259: // DOWN (258), UP (259) arrow keys (navigation)
            return handleNavigationInput(key)

        case 10, 13: // ENTER - navigate to detail view
            if inMainSearchMode && (!filteredResults.isEmpty || !searchResults.isEmpty) {
                navigateToDetailView()
                return true
            }
            return false

        case 32: // SPACE - show inline detail
            if inMainSearchMode && (!filteredResults.isEmpty || !searchResults.isEmpty) {
                showingResultDetail = true
                return true
            }
            return false

        case 68: // SHIFT+D - detail (only if we have results)
            if inMainSearchMode && !inputState.isActive && inputState.displayText.isEmpty {
                if !filteredResults.isEmpty || !searchResults.isEmpty {
                    showingResultDetail = true
                    return true
                }
            }
            return false
        default:
            return false
        }
    }

    @MainActor
    private static func handleNavigationInput(_ key: Int32) -> Bool {
        let resultsToShow: [SearchResult] = inputState.displayText.isEmpty ? searchResults : filteredResults
        guard !resultsToShow.isEmpty else { return false }

        switch key {
        case 258: // DOWN (258)
            moveSelection(by: 1, in: resultsToShow)
            return true

        case 259: // UP (259)
            moveSelection(by: -1, in: resultsToShow)
            return true

        default:
            return false
        }
    }

    @MainActor
    private static func navigateToDetailView() {
        Logger.shared.logInfo("AdvancedSearchView.navigateToDetailView() - Starting")

        guard let tuiInstance = tui else {
            Logger.shared.logWarning("AdvancedSearchView.navigateToDetailView() - No TUI instance")
            return
        }

        let resultsToShow: [SearchResult] = inputState.displayText.isEmpty ? searchResults : filteredResults
        let selectedIndex = getSelectedIndex(in: resultsToShow)
        Logger.shared.logInfo("AdvancedSearchView.navigateToDetailView() - resultsToShow.count=\(resultsToShow.count), selectedIndex=\(selectedIndex)")

        guard selectedIndex >= 0 && selectedIndex < resultsToShow.count else {
            Logger.shared.logWarning("AdvancedSearchView.navigateToDetailView() - Invalid selectedIndex: \(selectedIndex) for \(resultsToShow.count) results")
            return
        }

        let selectedResult = resultsToShow[selectedIndex]
        Logger.shared.logInfo("AdvancedSearchView.navigateToDetailView() - Selected result: \(selectedResult.resourceType) - \(selectedResult.name ?? selectedResult.resourceId)")

        // Map SearchResourceType to detail ViewMode and navigate
        if let detailView = mapResourceToDetailView(selectedResult.resourceType) {
            Logger.shared.logInfo("AdvancedSearchView.navigateToDetailView() - Mapped to detail view: \(detailView)")

            // Find and select the resource in the appropriate cached list
            let foundAndSelected = selectResourceInCache(tuiInstance, selectedResult)

            if !foundAndSelected {
                Logger.shared.logWarning("Resource not found in cache: \(selectedResult.resourceId)")
            }

            Logger.shared.logNavigation(".advancedSearch", to: "\(detailView)", details: [
                "resourceType": "\(selectedResult.resourceType)",
                "resourceId": selectedResult.resourceId,
                "foundInCache": "\(foundAndSelected)",
                "selectedIndex": "\(tuiInstance.selectedIndex)"
            ])

            tuiInstance.changeView(to: detailView, resetSelection: false)
        } else {
            Logger.shared.logWarning("AdvancedSearchView.navigateToDetailView() - No detail view mapped for \(selectedResult.resourceType)")
        }
    }

    @MainActor
    private static func selectResourceInCache(_ tui: TUI, _ result: SearchResult) -> Bool {
        let resourceId = result.resourceId

        switch result.resourceType {
        case .server:
            if let index = tui.cachedServers.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .network:
            if let index = tui.cachedNetworks.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .subnet:
            if let index = tui.cachedSubnets.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .port:
            if let index = tui.cachedPorts.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .router:
            if let index = tui.cachedRouters.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .volume:
            if let index = tui.cachedVolumes.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .image:
            if let index = tui.cachedImages.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .flavor:
            if let index = tui.cachedFlavors.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .securityGroup:
            if let index = tui.cachedSecurityGroups.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .keyPair:
            if let index = tui.cachedKeyPairs.firstIndex(where: { $0.name == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .floatingIP:
            if let index = tui.cachedFloatingIPs.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .serverGroup:
            if let index = tui.cachedServerGroups.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .volumeSnapshot:
            if let index = tui.cachedVolumeSnapshots.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .volumeBackup:
            if let index = tui.cachedVolumeBackups.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .barbicanSecret:
            if let index = tui.cachedSecrets.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .loadBalancer:
            if let index = tui.cachedLoadBalancers.firstIndex(where: { $0.id == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .swiftContainer:
            if let index = tui.cachedSwiftContainers.firstIndex(where: { $0.name == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        case .swiftObject:
            if let objects = tui.cachedSwiftObjects, let index = objects.firstIndex(where: { $0.name == resourceId }) {
                tui.selectedIndex = index
                return true
            }
        }

        return false
    }

    @MainActor
    private static func mapResourceToDetailView(_ resourceType: SearchResourceType) -> ViewMode? {
        // Map to LIST views so the user sees the resource highlighted in context
        // They can then press SPACE to view details if needed
        switch resourceType {
        case .server: return .servers
        case .network: return .networks
        case .subnet: return .subnets
        case .port: return .ports
        case .router: return .routers
        case .volume: return .volumes
        case .image: return .images
        case .flavor: return .flavors
        case .securityGroup: return .securityGroups
        case .keyPair: return .keyPairs
        case .floatingIP: return .floatingIPs
        case .serverGroup: return .serverGroups
        case .volumeSnapshot: return .volumes // Navigate to volumes list
        case .volumeBackup: return .volumes // Navigate to volumes list
        case .barbicanSecret: return .barbicanSecrets
        case .loadBalancer: return .octavia
        case .swiftContainer: return .swift
        case .swiftObject: return .swift
        }
    }

    // MARK: - Search Operations

    @MainActor
    private static func scheduleSearch() {
        // Cancel previous search task
        searchDebounceTask?.cancel()

        // Schedule new search with debounce
        searchDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(searchDebounceDelay * 1_000_000_000))
                if !Task.isCancelled {
                    currentQuery = inputState.searchQuery
                    await performSearch()
                    await loadSuggestions()
                }
            } catch {
                // Task was cancelled, ignore
            }
        }
    }

    @MainActor
    private static func performClientSideFilter() {
        let resultsToFilter = searchResults
        let query = inputState.searchQuery

        if query.isEmpty || resultsToFilter.count > maxClientFilterResults {
            filteredResults = []
            // Selection is ID-based, so it automatically persists when switching views
            tui?.forceRedraw()
            return
        }

        let queryLower = query.lowercased()
        filteredResults = resultsToFilter.filter { result in
            let name = (result.name ?? result.resourceId).lowercased()
            let resourceType = result.resourceType.displayName.lowercased()
            let status = (result.status ?? "").lowercased()

            return name.contains(queryLower) ||
                   resourceType.contains(queryLower) ||
                   status.contains(queryLower) ||
                   result.metadata.values.contains { $0.lowercased().contains(queryLower) }
        }

        // No need to clamp - ID-based selection automatically handles filtered lists
        // If the selected ID isn't in filtered results, getSelectedIndex() returns 0

        tui?.forceRedraw()
    }

    @MainActor
    private static func clearSearchResults() {
        searchResults = []
        filteredResults = []
        unifiedResults = nil
        selectedResourceId = nil  // Clear ID-based selection
    }

    @MainActor
    private static func executeSelectedResult() {
        let resultsToShow: [SearchResult]
        if inputState.displayText.isEmpty {
            resultsToShow = searchResults
        } else {
            resultsToShow = filteredResults
        }

        let selectedIndex = getSelectedIndex(in: resultsToShow)
        guard selectedIndex < resultsToShow.count else { return }

        let selectedResult = resultsToShow[selectedIndex]

        // Navigate to the appropriate detail view based on resource type
        if let tuiInstance = tui {
            Task {
                await navigateToResourceDetail(selectedResult, tui: tuiInstance)
            }
        }
    }

    @MainActor
    private static func navigateToResourceDetail(_ result: SearchResult, tui: TUI) async {
        // Find the actual resource in the cached data and navigate to its detail view
        switch result.resourceType {
        case .server:
            if let server = tui.cachedServers.first(where: { $0.id == result.resourceId }) {
                tui.selectedResource = server
                tui.changeView(to: .serverDetail, resetSelection: false)
            } else {
                // Fallback: navigate to servers list
                tui.changeView(to: .servers)
            }
        case .network:
            if let network = tui.cachedNetworks.first(where: { $0.id == result.resourceId }) {
                tui.selectedResource = network
                tui.changeView(to: .networkDetail, resetSelection: false)
            } else {
                tui.changeView(to: .networks)
            }
        case .volume:
            if let volume = tui.cachedVolumes.first(where: { $0.id == result.resourceId }) {
                tui.selectedResource = volume
                tui.changeView(to: .volumeDetail, resetSelection: false)
            } else {
                tui.changeView(to: .volumes)
            }
        case .image:
            if let image = tui.cachedImages.first(where: { $0.id == result.resourceId }) {
                tui.selectedResource = image
                tui.changeView(to: .imageDetail, resetSelection: false)
            } else {
                tui.changeView(to: .images)
            }
        case .flavor:
            if let flavor = tui.cachedFlavors.first(where: { $0.id == result.resourceId }) {
                tui.selectedResource = flavor
                tui.changeView(to: .flavorDetail, resetSelection: false)
            } else {
                tui.changeView(to: .flavors)
            }
        case .port:
            if let port = tui.cachedPorts.first(where: { $0.id == result.resourceId }) {
                tui.selectedResource = port
                tui.changeView(to: .portDetail, resetSelection: false)
            } else {
                tui.changeView(to: .ports)
            }
        case .floatingIP:
            if let floatingIP = tui.cachedFloatingIPs.first(where: { $0.id == result.resourceId }) {
                tui.selectedResource = floatingIP
                tui.changeView(to: .floatingIPDetail, resetSelection: false)
            } else {
                tui.changeView(to: .floatingIPs)
            }
        case .router:
            if let router = tui.cachedRouters.first(where: { $0.id == result.resourceId }) {
                tui.selectedResource = router
                tui.changeView(to: .routerDetail, resetSelection: false)
            } else {
                tui.changeView(to: .routers)
            }
        default:
            // For resource types without detail views, show the search detail view
            showingResultDetail = true
        }

        Logger.shared.logUserAction("search_result_selected", details: [
            "resource_type": "\(result.resourceType)",
            "resource_id": result.resourceId,
            "search_query": currentQuery
        ])
    }

    @MainActor
    private static func performSearch() async {
        guard !currentQuery.isEmpty else {
            searchResults = []
            unifiedResults = nil
            return
        }

        isSearching = true
        let startTime = Date().timeIntervalSinceReferenceDate

        // Create GlobalSearchQuery with enhanced options
        globalSearchQuery = GlobalSearchQuery(
                text: currentQuery,
                filters: [],
                resourceTypes: globalSearchQuery.resourceTypes.isEmpty ? [] : globalSearchQuery.resourceTypes,
                sorting: .relevance,
                pagination: SearchPagination(offset: 0, limit: resultsPerPage),
                fuzzySearch: true,
                includeRelationships: true,
                crossServiceEnabled: enableCrossServiceSearch,
                parallelSearchEnabled: enableParallelSearch,
                searchScope: .all,
                timeRange: nil,
                maxResultsPerService: 50,
                includeServiceMetrics: true
            )

        do {
            // Use SearchEngine for cross-service search
            let legacyQuery = globalSearchQuery.toSearchQuery()
            let results = try await searchEngine.search(legacyQuery)
            searchResults = results.items
            totalResults = results.items.count
            lastSearchTime = Date().timeIntervalSinceReferenceDate - startTime
            // Initialize selection to first result if we have any
            selectedResourceId = results.items.first?.resourceId
            unifiedResults = nil

            Logger.shared.logInfo("AdvancedSearchView - Search completed: \(results.items.count) results")
        } catch {
            Logger.shared.logError("AdvancedSearchView - Search failed: \(error)")
            searchResults = []
            unifiedResults = nil
            lastSearchTime = 0.0
        }

        isSearching = false
    }

    @MainActor
    private static func loadSuggestions() async {
        guard currentQuery.count >= 2 else {
            activeSuggestions = []
            return
        }

        activeSuggestions = await searchEngine.getSuggestions(for: currentQuery, limit: 5)
    }



    // MARK: - Advanced Search Options


    @MainActor
    static func toggleParallelSearch() {
        enableParallelSearch.toggle()
        if !currentQuery.isEmpty {
            Task {
                await performSearch()
            }
        }
    }

    @MainActor
    static func getSearchAnalytics() async -> SearchAnalytics {
        // Return empty analytics
        return SearchAnalytics()
    }

    // Initialize search engine with live OpenStack data
    @MainActor
    private static func initializeSearchEngineIfNeeded() async {
        guard !isLoadingLiveData else { return } // Prevent duplicate loading

        isLoadingLiveData = true
        defer { isLoadingLiveData = false }

        // Load live data from TUI's cached resources
        if let tuiInstance = tui {
            Logger.shared.logInfo("AdvancedSearchView - Loading live OpenStack data")

            let liveResults = await createLiveSearchResults(from: tuiInstance)

            if !liveResults.isEmpty {
                searchResults = liveResults
                Logger.shared.logInfo("AdvancedSearchView - Loaded \(searchResults.count) live resources")

                // Also populate the SearchEngine with live data for advanced search features
                let liveResources = createSearchableResources(from: tuiInstance)
                await searchEngine.updateIndex(with: liveResources)
                Logger.shared.logInfo("AdvancedSearchView - SearchEngine index updated with live data")
            } else {
                // Fallback to sample data if no live data is available yet
                Logger.shared.logInfo("AdvancedSearchView - No live data available, using sample data")
                searchResults = createSampleSearchResults()
            }
        } else {
            // Fallback to sample data if TUI is not available
            Logger.shared.logInfo("AdvancedSearchView - TUI not available, using sample data")
            searchResults = createSampleSearchResults()
        }
    }

    // Create sample search results for testing the search functionality
    @MainActor
    private static func createSampleSearchResults() -> [SearchResult] {
        var results: [SearchResult] = []

        // Sample server results
        results.append(SearchResult(
            resourceId: "server-001",
            resourceType: .server,
            name: "web-server-01",
            description: "Production web server running nginx",
            status: "ACTIVE",
            createdAt: Date().addingTimeInterval(-86400), // 1 day ago
            updatedAt: Date().addingTimeInterval(-3600),  // 1 hour ago
            ipAddresses: ["192.168.1.100", "10.0.0.5"],
            metadata: ["environment": "production", "role": "web"],
            tags: ["production", "web", "nginx"],
            relevanceScore: 10.0,
            matchHighlights: []
        ))

        results.append(SearchResult(
            resourceId: "server-002",
            resourceType: .server,
            name: "database-server",
            description: "MySQL database server for production",
            status: "ACTIVE",
            createdAt: Date().addingTimeInterval(-172800), // 2 days ago
            updatedAt: Date().addingTimeInterval(-7200),   // 2 hours ago
            ipAddresses: ["192.168.1.101"],
            metadata: ["environment": "production", "role": "database"],
            tags: ["production", "database", "mysql"],
            relevanceScore: 9.5,
            matchHighlights: []
        ))

        results.append(SearchResult(
            resourceId: "server-003",
            resourceType: .server,
            name: "api-gateway",
            description: "API gateway server in staging environment",
            status: "PAUSED",
            createdAt: Date().addingTimeInterval(-259200), // 3 days ago
            updatedAt: Date().addingTimeInterval(-10800),  // 3 hours ago
            ipAddresses: ["192.168.1.102"],
            metadata: ["environment": "staging", "role": "api"],
            tags: ["staging", "api", "gateway"],
            relevanceScore: 8.0,
            matchHighlights: []
        ))

        // Sample network results
        results.append(SearchResult(
            resourceId: "net-001",
            resourceType: .network,
            name: "production-network",
            description: "Main production network for web servers",
            status: "ACTIVE",
            createdAt: Date().addingTimeInterval(-604800), // 1 week ago
            updatedAt: Date().addingTimeInterval(-14400),  // 4 hours ago
            ipAddresses: [],
            metadata: ["subnet": "192.168.1.0/24", "external": "false"],
            tags: ["production", "internal"],
            relevanceScore: 7.5,
            matchHighlights: []
        ))

        results.append(SearchResult(
            resourceId: "net-002",
            resourceType: .network,
            name: "development-network",
            description: "Development and testing network",
            status: "ACTIVE",
            createdAt: Date().addingTimeInterval(-518400), // 6 days ago
            updatedAt: Date().addingTimeInterval(-18000),  // 5 hours ago
            ipAddresses: [],
            metadata: ["subnet": "10.0.0.0/24", "external": "false"],
            tags: ["development", "testing"],
            relevanceScore: 7.0,
            matchHighlights: []
        ))

        // Sample volume results
        results.append(SearchResult(
            resourceId: "vol-001",
            resourceType: .volume,
            name: "database-storage",
            description: "SSD storage for database server",
            status: "AVAILABLE",
            createdAt: Date().addingTimeInterval(-345600), // 4 days ago
            updatedAt: Date().addingTimeInterval(-21600),  // 6 hours ago
            ipAddresses: [],
            metadata: ["size": "100GB", "type": "SSD"],
            tags: ["storage", "ssd", "database"],
            relevanceScore: 6.5,
            matchHighlights: []
        ))

        // Sample image results
        results.append(SearchResult(
            resourceId: "img-001",
            resourceType: .image,
            name: "ubuntu-20.04-lts",
            description: "Ubuntu 20.04 LTS base image",
            status: "ACTIVE",
            createdAt: Date().addingTimeInterval(-1209600), // 2 weeks ago
            updatedAt: Date().addingTimeInterval(-25200),   // 7 hours ago
            ipAddresses: [],
            metadata: ["os": "ubuntu", "version": "20.04"],
            tags: ["ubuntu", "lts", "linux"],
            relevanceScore: 6.0,
            matchHighlights: []
        ))

        // Sample flavor results
        results.append(SearchResult(
            resourceId: "flavor-001",
            resourceType: .flavor,
            name: "m1.small",
            description: "Small instance flavor with 1 vCPU and 2GB RAM",
            status: "ACTIVE",
            createdAt: Date().addingTimeInterval(-2419200), // 4 weeks ago
            updatedAt: Date().addingTimeInterval(-28800),   // 8 hours ago
            ipAddresses: [],
            metadata: ["vcpus": "1", "ram": "2048MB", "disk": "20GB"],
            tags: ["small", "basic"],
            relevanceScore: 5.5,
            matchHighlights: []
        ))

        return results
    }

    // Create search results from live OpenStack data
    @MainActor
    private static func createLiveSearchResults(from tui: TUI) async -> [SearchResult] {
        var results: [SearchResult] = []

        // Convert Servers to SearchResults
        for server in tui.cachedServers {
            results.append(SearchResult(
                resourceId: server.id,
                resourceType: .server,
                name: server.name,
                description: "OpenStack compute instance",
                status: server.status?.rawValue ?? "UNKNOWN",
                createdAt: server.createdAt,
                updatedAt: server.updatedAt,
                ipAddresses: extractIPAddresses(from: server.addresses ?? [:]),
                metadata: convertServerMetadata(server),
                tags: extractServerTags(server),
                relevanceScore: 10.0,
                matchHighlights: []
            ))
        }

        // Convert Networks to SearchResults
        for network in tui.cachedNetworks {
            results.append(SearchResult(
                resourceId: network.id,
                resourceType: .network,
                name: network.name,
                description: "OpenStack network",
                status: network.status,
                createdAt: network.createdAt,
                updatedAt: network.updatedAt,
                ipAddresses: [],
                metadata: convertNetworkMetadata(network),
                tags: extractNetworkTags(network),
                relevanceScore: 8.0,
                matchHighlights: []
            ))
        }

        // Convert Volumes to SearchResults
        for volume in tui.cachedVolumes {
            results.append(SearchResult(
                resourceId: volume.id,
                resourceType: .volume,
                name: volume.name,
                description: "OpenStack block storage volume",
                status: volume.status,
                createdAt: volume.createdAt,
                updatedAt: volume.updatedAt,
                ipAddresses: [],
                metadata: convertVolumeMetadata(volume),
                tags: extractVolumeTags(volume),
                relevanceScore: 7.0,
                matchHighlights: []
            ))
        }

        // Convert Images to SearchResults
        for image in tui.cachedImages {
            results.append(SearchResult(
                resourceId: image.id,
                resourceType: .image,
                name: image.name,
                description: "OpenStack virtual machine image",
                status: image.status,
                createdAt: image.createdAt,
                updatedAt: image.updatedAt,
                ipAddresses: [],
                metadata: convertImageMetadata(image),
                tags: extractImageTags(image),
                relevanceScore: 6.0,
                matchHighlights: []
            ))
        }

        // Convert Flavors to SearchResults
        for flavor in tui.cachedFlavors {
            results.append(SearchResult(
                resourceId: flavor.id,
                resourceType: .flavor,
                name: flavor.name,
                description: "OpenStack compute flavor",
                status: "ACTIVE", // Flavors don't have status, assume active
                createdAt: nil, // Flavors typically don't have creation dates
                updatedAt: nil,
                ipAddresses: [],
                metadata: convertFlavorMetadata(flavor),
                tags: extractFlavorTags(flavor),
                relevanceScore: 5.0,
                matchHighlights: []
            ))
        }

        // Sort results by relevance score (highest first)
        results.sort { $0.relevanceScore > $1.relevanceScore }

        Logger.shared.logInfo("AdvancedSearchView - Successfully processed \(results.count) live resources")
        return results
    }

    // Create SearchableResources from live OpenStack data for SearchEngine
    @MainActor
    private static func createSearchableResources(from tui: TUI) -> SearchableResources {
        return SearchableResources(
            servers: tui.cachedServers,
            networks: tui.cachedNetworks,
            subnets: tui.cachedSubnets,
            ports: tui.cachedPorts,
            routers: tui.cachedRouters,
            volumes: tui.cachedVolumes,
            images: tui.cachedImages,
            flavors: tui.cachedFlavors,
            securityGroups: tui.cachedSecurityGroups,
            keyPairs: tui.cachedKeyPairs,
            floatingIPs: tui.cachedFloatingIPs,
            serverGroups: tui.cachedServerGroups,
            volumeSnapshots: tui.cachedVolumeSnapshots,
            volumeBackups: tui.cachedVolumeBackups,
            barbicanSecrets: tui.cachedSecrets,
            loadBalancers: tui.cachedLoadBalancers,
            swiftContainers: tui.cachedSwiftContainers,
            swiftObjects: tui.cachedSwiftObjects ?? []
        )
    }

    // Helper methods to extract and convert resource data

    @MainActor
    private static func extractIPAddresses(from addresses: [String: [NetworkAddress]]) -> [String] {
        var ipAddresses: [String] = []
        for (_, addressList) in addresses {
            for address in addressList {
                ipAddresses.append(address.addr)
            }
        }
        return ipAddresses
    }

    @MainActor
    private static func convertServerMetadata(_ server: Server) -> [String: String] {
        var metadata: [String: String] = [:]

        metadata["tenant_id"] = server.tenantId
        if let userId = server.userId {
            metadata["user_id"] = userId
        }
        if let hostId = server.hostId {
            metadata["host_id"] = hostId
        }
        if let availabilityZone = server.availabilityZone {
            metadata["availability_zone"] = availabilityZone
        }
        if let hypervisorHostname = server.hypervisorHostname {
            metadata["hypervisor"] = hypervisorHostname
        }

        // Add flavor and image info
        if let flavor = server.flavor {
            metadata["flavor_id"] = flavor.id
            metadata["flavor_name"] = flavor.name ?? "Unknown"
        }
        if let image = server.image {
            metadata["image_id"] = image.id
            metadata["image_name"] = image.name ?? "Unknown"
        }

        // Add server metadata
        for (key, value) in server.metadata ?? [:] {
            metadata["meta_\(key)"] = value
        }

        return metadata
    }

    @MainActor
    private static func extractServerTags(_ server: Server) -> [String] {
        var tags: [String] = []

        tags.append("server")
        tags.append("compute")

        // Add status-based tags
        switch server.status {
        case .active:
            tags.append("active")
        case .error:
            tags.append("error")
        case .shutoff:
            tags.append("stopped")
        default:
            tags.append(server.status?.rawValue.lowercased() ?? "unknown")
        }

        // Add availability zone if available
        if let az = server.availabilityZone {
            tags.append("az-\(az)")
        }

        return tags
    }

    @MainActor
    private static func convertNetworkMetadata(_ network: Network) -> [String: String] {
        var metadata: [String: String] = [:]

        if let tenantId = network.tenantId {
            metadata["tenant_id"] = tenantId
        }
        metadata["external"] = (network.external ?? false) ? "true" : "false"
        metadata["shared"] = (network.shared ?? false) ? "true" : "false"
        metadata["admin_state_up"] = (network.adminStateUp ?? false) ? "true" : "false"

        return metadata
    }

    @MainActor
    private static func extractNetworkTags(_ network: Network) -> [String] {
        var tags: [String] = []

        tags.append("network")
        if network.external ?? false {
            tags.append("external")
        } else {
            tags.append("internal")
        }
        if network.shared ?? false {
            tags.append("shared")
        }

        return tags
    }

    @MainActor
    private static func convertVolumeMetadata(_ volume: Volume) -> [String: String] {
        var metadata: [String: String] = [:]

        metadata["size"] = "\(volume.size ?? 0)GB"
        if let volumeType = volume.volumeType {
            metadata["type"] = volumeType
        }
        metadata["bootable"] = (volume.bootable != nil) ? "true" : "false"
        metadata["encrypted"] = (volume.encrypted ?? false) ? "true" : "false"

        // Add attachment info
        metadata["attachment_count"] = "\(volume.attachments?.count ?? 0)"
        if let firstAttachment = volume.attachments?.first {
            metadata["attached_to"] = firstAttachment.serverId
        }

        return metadata
    }

    @MainActor
    private static func extractVolumeTags(_ volume: Volume) -> [String] {
        var tags: [String] = []

        tags.append("volume")
        tags.append("storage")

        if volume.bootable != nil {
            tags.append("bootable")
        }
        if volume.encrypted ?? false {
            tags.append("encrypted")
        }
        if !(volume.attachments?.isEmpty ?? true) {
            tags.append("attached")
        } else {
            tags.append("available")
        }

        return tags
    }

    @MainActor
    private static func convertImageMetadata(_ image: Image) -> [String: String] {
        var metadata: [String: String] = [:]

        if let visibility = image.visibility {
            metadata["visibility"] = visibility
        }
        metadata["size"] = "\(image.size ?? 0)"
        if let diskFormat = image.diskFormat {
            metadata["disk_format"] = diskFormat
        }
        if let containerFormat = image.containerFormat {
            metadata["container_format"] = containerFormat
        }

        // Add properties from image metadata
        for (key, value) in image.properties ?? [:] {
            metadata["prop_\(key)"] = "\(value)"
        }

        return metadata
    }

    @MainActor
    private static func extractImageTags(_ image: Image) -> [String] {
        var tags: [String] = []

        tags.append("image")

        if let visibility = image.visibility {
            tags.append(visibility)
        }

        // Extract OS info from properties if available
        if let properties = image.properties {
            if let osName = properties["os_type"] {
                tags.append(osName.lowercased())
            }
            if let osDistro = properties["os_distro"] {
                tags.append(osDistro.lowercased())
            }
        }

        return tags
    }

    @MainActor
    private static func convertFlavorMetadata(_ flavor: Flavor) -> [String: String] {
        var metadata: [String: String] = [:]

        metadata["vcpus"] = "\(flavor.vcpus)"
        metadata["ram"] = "\(flavor.ram)MB"
        metadata["disk"] = "\(flavor.disk)GB"
        metadata["ephemeral"] = "\(flavor.ephemeral ?? 0)GB"
        metadata["public"] = (flavor.isPublic ?? false) ? "true" : "false"

        if let swap = flavor.swap, swap > 0 {
            metadata["swap"] = "\(swap)MB"
        }

        return metadata
    }

    @MainActor
    private static func extractFlavorTags(_ flavor: Flavor) -> [String] {
        var tags: [String] = []

        tags.append("flavor")
        tags.append("compute")

        if flavor.isPublic ?? false {
            tags.append("public")
        } else {
            tags.append("private")
        }

        // Add size-based tags
        if flavor.vcpus == 1 && flavor.ram <= 2048 {
            tags.append("small")
        } else if flavor.vcpus <= 4 && flavor.ram <= 8192 {
            tags.append("medium")
        } else {
            tags.append("large")
        }

        return tags
    }
}