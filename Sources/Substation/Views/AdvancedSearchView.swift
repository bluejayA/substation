import Foundation
import SwiftTUI
import OSClient

// MARK: - Advanced Search View

struct AdvancedSearchView {
    // MARK: - Search State

    @MainActor
    private static var tui: TUI?
    @MainActor
    private static var searchEngine: SearchEngine = SearchEngine.shared
    @MainActor
    private static var unifiedSearchOrchestrator: UnifiedSearchOrchestrator?
    @MainActor
    private static var savedSearchManager: SavedSearchManager = SavedSearchManager.shared
    @MainActor
    private static var smartFilter: SmartFilter = SmartFilter()

    // Enhanced search state
    @MainActor
    private static var currentQuery: String = ""
    @MainActor
    private static var displayQuery: String = "" // Immediate display, separate from search query
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
    private static var selectedResultIndex: Int = 0
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
    private static var cursorPosition: Int = 0
    @MainActor
    private static var isInSearchInputMode: Bool = false
    @MainActor
    private static var isLoadingLiveData: Bool = false

    // Pagination
    @MainActor
    private static var currentPage: Int = 0
    @MainActor
    private static var resultsPerPage: Int = 20
    @MainActor
    private static var totalResults: Int = 0

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
        let surface = SwiftTUI.surface(from: screen)

        // Bounds checking
        guard width >= minScreenWidth && height >= minScreenHeight else {
            let errorBounds = Rect(x: startCol, y: startRow, width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small for Advanced Search").error(), on: surface, in: errorBounds)
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
        } else if showingResultDetail && selectedResultIndex < searchResults.count {
            components.append(createResultDetail(width: width, height: contentHeight))
        } else {
            components.append(createSearchResults(width: width, height: contentHeight))
        }

        // Add status bar
        components.append(createStatusBar(width: width))

        // Create main layout
        let mainComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        await SwiftTUI.render(mainComponent, on: surface, in: bounds)
    }

    // MARK: - Search Bar Component

    @MainActor
    private static func createSearchBar(width: Int32) -> any Component {
        var components: [any Component] = []
        let availableWidth = Int(width) - 4 // Account for padding

        // Modern search input line (inspired by fzf/ripgrep)
        let searchPrompt = "> "
        let promptWidth = searchPrompt.count
        let inputWidth = availableWidth - promptWidth - 15 // Reserve space for status

        // Create query display with proper cursor positioning
        let queryDisplay = createQueryDisplay(query: displayQuery,
                                            cursor: cursorPosition,
                                            maxWidth: inputWidth,
                                            isSearching: isSearching)

        // Status indicator (like fzf)
        let statusIndicator = createStatusIndicator()
        let statusWidth = statusIndicator.count

        // Main input line with prompt, query, and status
        let inputPadding = max(0, availableWidth - promptWidth - queryDisplay.count - statusWidth - 2)
        let paddingSpaces = String(repeating: " ", count: inputPadding)

        // Title
        let titleText = "Search \(statusIndicator)"
        components.append(Text(titleText).emphasis().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        let searchStack = HStack(spacing: 0, children: [
            Text(" \(searchPrompt)").styled(.primary),
            Text(" \(queryDisplay)").styled(.secondary),
            Text(" \(paddingSpaces)").styled(.secondary),
        ]).border().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))

        components.append(searchStack)

        // Results summary line (like fzf's "x/y" indicator)
        let resultsSummary = createResultsSummary()
        components.append(
            Text(resultsSummary)
                .secondary()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
        )

        // Quick suggestions (only show if not searching and query is short)
        if !isSearching && displayQuery.count < 3 && !activeSuggestions.isEmpty {
            let suggestionsLine = activeSuggestions.prefix(3).map { "[\($0.text)]" }.joined(separator: " ")
            let truncatedSuggestions = String(suggestionsLine.prefix(availableWidth))

            if !truncatedSuggestions.isEmpty {
                components.append(
                    Text(" \(truncatedSuggestions)")
                        .muted()
                        .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
                )
            }
        }

        // Contextual hints (less prominent, adaptive)
        let hints = getContextualHints()
        if !hints.isEmpty {
            let truncatedHints = String(hints.prefix(availableWidth))
            components.append(
                Text(truncatedHints)
                    .muted()
                    .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 0))
            )
        }

        return VStack(spacing: 0, children: components)
    }

    @MainActor
    private static func createQueryDisplay(query: String, cursor: Int, maxWidth: Int, isSearching: Bool) -> String {
        if query.isEmpty {
            return isSearching ? "|" : "_"
        }

        let displayQuery = query.count > maxWidth ? String(query.suffix(maxWidth)) : query

        if isSearching {
            return "\(displayQuery)|"
        } else {
            // Show cursor position within query
            let safeCursor = min(cursor, displayQuery.count)
            if safeCursor >= displayQuery.count {
                return "\(displayQuery)_"
            } else {
                let beforeCursor = String(displayQuery.prefix(safeCursor))
                let atCursor = safeCursor < displayQuery.count ? String(displayQuery[displayQuery.index(displayQuery.startIndex, offsetBy: safeCursor)]) : "_"
                let afterCursor = safeCursor < displayQuery.count - 1 ? String(displayQuery.suffix(displayQuery.count - safeCursor - 1)) : ""
                return "\(beforeCursor)[\(atCursor)]\(afterCursor)"
            }
        }
    }

    @MainActor
    private static func createStatusIndicator() -> String {
        if isSearching {
            let elapsed = Date().timeIntervalSinceReferenceDate - lastTypingTime
            let spinner = ["|", "/", "-", "\\"]
            let spinnerChar = spinner[Int(elapsed * 4) % spinner.count]
            return "[\(spinnerChar)]"
        } else if !filteredResults.isEmpty {
            return "[\(filteredResults.count)]"
        } else if !displayQuery.isEmpty {
            return "[0]"
        } else {
            return "[ready]"
        }
    }

    @MainActor
    private static func createResultsSummary() -> String {
        let totalResults = searchResults.count
        let filteredCount = filteredResults.isEmpty ? totalResults : filteredResults.count

        if isLoadingLiveData {
            return "  Loading live data..."
        } else if isSearching {
            return "  Searching..."
        } else if filteredCount == 0 {
            return "  No matches found"
        } else {
            return "  \(filteredCount)/\(totalResults) results"
        }
    }

    @MainActor
    private static func getContextualHints() -> String {
        if showingCrossServiceResults {
            return "C: Toggle view | ESC: Back"
        } else if !displayQuery.isEmpty && (!filteredResults.isEmpty || !searchResults.isEmpty) {
            return "UP/DOWN: Navigate | ENTER: Load | ESC: Clear"
        } else if !displayQuery.isEmpty {
            return "ESC: Clear search"
        } else {
            return "Type to search across OpenStack services"
        }
    }

    // MARK: - Search Results Component

    @MainActor
    private static func createSearchResults(width: Int32, height: Int32) -> any Component {
        var components: [any Component] = []

        // Determine what results to show based on search state
        let resultsToShow: [SearchResult]
        if displayQuery.isEmpty {
            // No query - show all search results (initial load)
            resultsToShow = searchResults
        } else {
            // There's a query - show filtered results (which may be empty if no matches)
            resultsToShow = filteredResults
        }

        if resultsToShow.isEmpty {
            if isLoadingLiveData {
                return createLoadingDataIndicator()
            } else if displayQuery.isEmpty {
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

        // Results list
        let availableRows = Int(height) - (lastSearchTime > 0 ? 3 : 2) // Header + column header
        let startIndex = max(0, selectedResultIndex - availableRows / 2)
        let endIndex = min(startIndex + availableRows, resultsToShow.count)

        var resultComponents: [any Component] = []
        for i in startIndex..<endIndex {
            let result = resultsToShow[i]
            let isSelected = i == selectedResultIndex

            resultComponents.append(createSearchResultRow(result, isSelected: isSelected, width: Int(width), query: displayQuery))
        }

        if !resultComponents.isEmpty {
            components.append(
                VStack(spacing: 0, children: resultComponents)
                    .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
            )
        }

        // Pagination info (fzf-style)
        if resultsToShow.count > availableRows {
            let currentPage = selectedResultIndex / availableRows + 1
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
            "Advanced Search",
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
        if displayQuery.isEmpty {
            resultsToShow = searchResults
        } else {
            resultsToShow = filteredResults
        }
        guard selectedResultIndex < resultsToShow.count else {
            return Text("No result selected").warning()
        }

        let result = resultsToShow[selectedResultIndex]
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
        let statusText = if isSearching {
            "Searching..."
        } else if searchResults.isEmpty && !currentQuery.isEmpty {
            "No results"
        } else if !searchResults.isEmpty {
            "Results: \(searchResults.count) | Selected: \(selectedResultIndex + 1)"
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

        // Handle ESC first (always available)
        if key == 27 { // ESC
            if showingResultDetail || showingCrossServiceResults {
                showingResultDetail = false
                showingCrossServiceResults = false
                return true
            } else if !displayQuery.isEmpty {
                // ESC in search mode clears the query
                displayQuery = ""
                cursorPosition = 0
                clearSearchResults()
                isInSearchInputMode = false
                return true
            } else {
                // ESC with empty query - return to previous view
                if let tuiInstance = tui {
                    tuiInstance.changeView(to: tuiInstance.previousView)
                    return true
                }
            }
            return false
        }

        // Handle special keys that work in all modes
        switch key {
        case 10, 13: // ENTER
            if inMainSearchMode && (!filteredResults.isEmpty || !searchResults.isEmpty) {
                executeSelectedResult()
                return true
            }
            return false

        case 32: // SPACE
            if inMainSearchMode {
                // SPACE as text input when in search mode
                return handleTextInput(key)
            }
            return false

        case 258, 259: // DOWN (258), UP (259) arrow keys (navigation)
            return handleNavigationInput(key)

        case 127, 8: // BACKSPACE
            return handleBackspace()

        case 260, 261: // LEFT (260), RIGHT (261) arrow keys - cursor movement
            if inMainSearchMode && !displayQuery.isEmpty {
                // Cursor movement when we have text
                switch key {
                case 260: // LEFT
                    cursorPosition = max(0, cursorPosition - 1)
                case 261: // RIGHT
                    cursorPosition = min(displayQuery.count, cursorPosition + 1)
                default:
                    break
                }
                return true
            } else {
                return handleNavigationInput(key)
            }

        // Number keys as text input
        case Int32(Character("1").asciiValue!)...Int32(Character("6").asciiValue!):
            if inMainSearchMode {
                return handleTextInput(key)
            }
            return false

        default:
            // Handle character input
            if key >= 32 && key < 127 {
                let character = Character(UnicodeScalar(Int(key))!)

                // In main search mode, prioritize text input for most characters
                if inMainSearchMode {
                    // Check if this is a command shortcut when not actively typing
                    // Use SHIFT as modifier for commands to avoid conflicts
                    if !isInSearchInputMode && displayQuery.isEmpty {
                        switch character {
                        case "D": // SHIFT+D - detail (only if we have results)
                            if !filteredResults.isEmpty || !searchResults.isEmpty {
                                showingResultDetail = true
                                return true
                            }
                            break
                        default:
                            break
                        }
                    }

                    // Handle as text input
                    return handleTextInput(key)
                }
            }
            return false
        }
    }

    @MainActor
    private static func handleTextInput(_ key: Int32) -> Bool {
        guard key >= 32 && key < 127 else { return false }

        let character = Character(UnicodeScalar(Int(key))!)

        // Insert character at cursor position
        if cursorPosition >= displayQuery.count {
            displayQuery.append(character)
        } else {
            let insertIndex = displayQuery.index(displayQuery.startIndex, offsetBy: cursorPosition)
            displayQuery.insert(character, at: insertIndex)
        }

        cursorPosition += 1
        lastTypingTime = Date().timeIntervalSinceReferenceDate
        isInSearchInputMode = true

        // Immediate UI feedback, debounced search
        performClientSideFilter()
        scheduleSearch()

        return true
    }

    @MainActor
    private static func handleNavigationInput(_ key: Int32) -> Bool {
        switch key {
        case 258: // DOWN (258)
            if !filteredResults.isEmpty || !searchResults.isEmpty {
                let resultsToShow: [SearchResult] = displayQuery.isEmpty ? searchResults : filteredResults
                let maxIndex = resultsToShow.count - 1
                selectedResultIndex = min(selectedResultIndex + 1, maxIndex)
            }
            return true

        case 259: // UP (259)
            if !filteredResults.isEmpty || !searchResults.isEmpty {
                selectedResultIndex = max(selectedResultIndex - 1, 0)
            }
            return true

        default:
            return false
        }
    }

    @MainActor
    private static func handleBackspace() -> Bool {
        guard !displayQuery.isEmpty && cursorPosition > 0 else {
            return displayQuery.isEmpty
        }

        displayQuery.remove(at: displayQuery.index(displayQuery.startIndex, offsetBy: cursorPosition - 1))
        cursorPosition -= 1
        lastTypingTime = Date().timeIntervalSinceReferenceDate
        isInSearchInputMode = !displayQuery.isEmpty
        performClientSideFilter()
        scheduleSearch()
        return true
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
                    currentQuery = displayQuery
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

        if displayQuery.isEmpty || resultsToFilter.count > maxClientFilterResults {
            filteredResults = []
            tui?.forceRedraw()
            return
        }

        let query = displayQuery.lowercased()
        filteredResults = resultsToFilter.filter { result in
            let name = (result.name ?? result.resourceId).lowercased()
            let resourceType = result.resourceType.displayName.lowercased()
            let status = (result.status ?? "").lowercased()

            return name.contains(query) ||
                   resourceType.contains(query) ||
                   status.contains(query) ||
                   result.metadata.values.contains { $0.lowercased().contains(query) }
        }

        tui?.forceRedraw()
    }

    @MainActor
    private static func clearSearchResults() {
        searchResults = []
        filteredResults = []
        unifiedResults = nil
        selectedResultIndex = 0
    }

    @MainActor
    private static func executeSelectedResult() {
        let resultsToShow: [SearchResult]
        if displayQuery.isEmpty {
            resultsToShow = searchResults
        } else {
            resultsToShow = filteredResults
        }
        guard selectedResultIndex < resultsToShow.count else { return }

        let selectedResult = resultsToShow[selectedResultIndex]

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
            // Use UnifiedSearchOrchestrator for cross-service search if available
            if let orchestrator = unifiedSearchOrchestrator {
                let unified = try await orchestrator.globalSearch(globalSearchQuery)
                unifiedResults = unified
                searchResults = unified.aggregatedItems
                totalResults = unified.totalCount

                // Update UI state
                lastSearchTime = unified.searchTime
                selectedResultIndex = 0

                Logger.shared.logInfo("AdvancedSearchView - Unified search completed: \(unified.totalCount) results from \(unified.serviceResults.count) services")
            } else {
                // Fallback to single-service search using SearchEngine
                let legacyQuery = globalSearchQuery.toSearchQuery()
                let results = try await searchEngine.search(legacyQuery)
                searchResults = results.items
                totalResults = results.items.count
                lastSearchTime = Date().timeIntervalSinceReferenceDate - startTime
                selectedResultIndex = 0
                unifiedResults = nil

                Logger.shared.logInfo("AdvancedSearchView - Legacy search completed: \(results.items.count) results")
            }

            // Add to search history
            await savedSearchManager.addToHistory(query: globalSearchQuery.toSearchQuery(), resultCount: totalResults)
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
        if let orchestrator = unifiedSearchOrchestrator {
            return await orchestrator.getSearchAnalytics()
        } else {
            // Return empty analytics if orchestrator is not available
            return SearchAnalytics()
        }
    }

    // Method to initialize the orchestrator when services become available
    @MainActor
    static func initializeUnifiedSearch(with client: OpenStackClient) async {
        // In a real implementation, this would extract services from the client
        // For now, we'll continue using the SearchEngine fallback
        Logger.shared.logInfo("AdvancedSearchView - UnifiedSearchOrchestrator initialization deferred")
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
            subnets: [], // TUI doesn't cache subnets separately yet
            ports: tui.cachedPorts,
            routers: tui.cachedRouters,
            volumes: tui.cachedVolumes,
            images: tui.cachedImages,
            flavors: tui.cachedFlavors,
            securityGroups: tui.cachedSecurityGroups,
            keyPairs: tui.cachedKeyPairs,
            floatingIPs: tui.cachedFloatingIPs,
            serverGroups: [] // TUI doesn't cache server groups separately yet
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