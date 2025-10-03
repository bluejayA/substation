import Foundation
import OSClient
import SwiftTUI

struct BaseViewComponents {
    // MARK: - SwiftTUI Migration Helpers

    /// Render a SwiftTUI component to an ncurses screen
    @MainActor static func renderSwiftTUIComponent(_ component: any Component,
                                       screen: OpaquePointer?,
                                       startRow: Int32, startCol: Int32,
                                       width: Int32, height: Int32) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(component, on: surface, in: bounds)
    }

    /// Create a simple text list component
    static func createTextList(items: [String],
                              selectedIndex: Int? = nil,
                              title: String? = nil) -> any Component {
        var components: [any Component] = []

        if let title = title {
            components.append(
                Text(title).emphasis().bold()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
            )
        }

        for (index, item) in items.enumerated() {
            let isSelected = selectedIndex == index
            let style: TextStyle = isSelected ? .accent : .primary
            components.append(Text(item).styled(style))
        }

        return VStack(spacing: 0, children: components)
    }

    // MARK: - Core Rendering Helpers (Legacy)

    @MainActor
    static func drawTitle(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                          width: Int32, title: String? = nil) async {
        guard let title = title, title.count + 4 < width else { return }

        let surface = SwiftTUI.surface(from: screen)
        let titleStart = startCol + 2
        let bounds = Rect(x: titleStart, y: startRow, width: Int32(title.count + 4), height: 1)
        let titleComponent = Text("[ \(title) ]").accent()

        await SwiftTUI.render(titleComponent, on: surface, in: bounds)
    }

    @MainActor
    static func drawBorder(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                          width: Int32, height: Int32, title: String? = nil) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        // Create a bordered container with optional title
        let borderComponent: any Component = BorderedContainer(
            title: title,
            content: {}
        )

        await SwiftTUI.render(borderComponent, on: surface, in: bounds)

        // Draw title if provided
        if let title = title {
            await drawTitle(screen: screen, startRow: startRow, startCol: startCol, width: width, title: title)
        }
    }

    @MainActor
    static func clearArea(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                         width: Int32, height: Int32) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        // Fill with secondary background style to maintain consistent styling
        await surface.fill(rect: bounds, character: " ", style: .secondary)
    }

    @MainActor
    static func drawProgressBar(screen: OpaquePointer?, row: Int32, col: Int32,
                               width: Int32, current: Int, total: Int, color: Int32) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: col, y: row, width: width, height: 1)

        let progress = total > 0 ? Double(current) / Double(total) : 0.0
        let progressBar = ProgressBar(progress: progress, width: width)
        await SwiftTUI.render(progressBar, on: surface, in: bounds)
    }

    // MARK: - List Components

    @MainActor
    static func drawListHeaders(screen: OpaquePointer?, headers: [String],
                               startRow: Int32, startCol: Int32) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol + 2, y: startRow, width: 80, height: 1)

        let headerText = Text(headers.joined(separator: " ")).secondary()
        await SwiftTUI.render(headerText, on: surface, in: bounds)
    }

    @MainActor
    static func drawScrollIndicator(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                   width: Int32, height: Int32, currentOffset: Int,
                                   totalItems: Int, visibleItems: Int,
                                   paginationInfo: String? = nil, loadingInfo: String? = nil) async {
        guard totalItems > visibleItems else { return }

        let surface = SwiftTUI.surface(from: screen)
        let indicatorRow = startRow + height - 3
        let indicatorCol = Int32(1)

        // Use pagination info if available, otherwise fall back to basic page calculation
        let displayInfo: String
        if let paginationInfo = paginationInfo {
            displayInfo = paginationInfo
        } else {
            let currentPage = currentOffset / visibleItems + 1
            let totalPages = (totalItems - 1) / visibleItems + 1
            displayInfo = "Page \(currentPage)/\(totalPages)"
        }

        // Render pagination info
        let infoBounds = Rect(x: indicatorCol, y: indicatorRow, width: Int32(displayInfo.count), height: 1)
        let infoComponent = Text(displayInfo).accent()

        await SwiftTUI.render(infoComponent, on: surface, in: infoBounds)

        // Show loading info if available
        if let loadingInfo = loadingInfo {
            let loadingCol = indicatorCol - Int32(loadingInfo.count) - 3
            let loadingBounds = Rect(x: loadingCol, y: indicatorRow, width: Int32(loadingInfo.count), height: 1)
            let loadingComponent = Text(loadingInfo).warning()
            await SwiftTUI.render(loadingComponent, on: surface, in: loadingBounds)
        }

        // Progress bar for scroll position
        await drawProgressBar(screen: screen, row: indicatorRow + 1, col: indicatorCol,
                      width: 20, current: currentOffset,
                      total: max(1, totalItems - visibleItems), color: 2)
    }

    // MARK: - Status Indicators

    @MainActor
    static func drawStatusIcon(screen: OpaquePointer?, status: String?,
                              activeStates: [String] = ["active", "available"],
                              errorStates: [String] = ["error", "fault"]) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: 0, y: 0, width: 3, height: 1)

        let statusIcon = StatusIcon(status: status)
        await SwiftTUI.render(statusIcon, on: surface, in: bounds)
    }

    // MARK: - Enhanced Title Display

    @MainActor
    static func drawEnhancedTitle(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                 width: Int32, title: String, searchQuery: String? = nil) async {
        let titleText = searchQuery != nil ? "\(title) (filtered: \(searchQuery!))" : title
        await drawTitle(screen: screen, startRow: startRow, startCol: startCol,
                 width: width, title: titleText)
    }

    // MARK: - Context Help

    @MainActor
    static func drawContextHelp(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                               helpText: String) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol + 4, y: startRow, width: Int32(helpText.count), height: 1)

        let helpComponent = Text(helpText).warning()
        await SwiftTUI.render(helpComponent, on: surface, in: bounds)
    }

    // MARK: - Enhanced Pagination Support

    @MainActor
    static func drawPaginationStatus(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                   width: Int32, statusInfo: String, loadingInfo: String? = nil) async {
        let surface = SwiftTUI.surface(from: screen)
        let statusRow = startRow
        let statusCol = startCol + width - Int32(statusInfo.count) - 2

        // Status info
        let statusBounds = Rect(x: statusCol, y: statusRow, width: Int32(statusInfo.count), height: 1)
        let statusComponent = Text(statusInfo).accent()

        await SwiftTUI.render(statusComponent, on: surface, in: statusBounds)

        // Show loading indicator if present
        if let loadingInfo = loadingInfo {
            let loadingCol = statusCol - Int32(loadingInfo.count) - 2
            let loadingBounds = Rect(x: loadingCol, y: statusRow + 1, width: Int32(loadingInfo.count), height: 1)
            let loadingComponent = Text(loadingInfo).warning()
            await SwiftTUI.render(loadingComponent, on: surface, in: loadingBounds)
        }
    }

    @MainActor
    static func drawLoadingSpinner(screen: OpaquePointer?, row: Int32, col: Int32, step: Int) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: col, y: row, width: 1, height: 1)

        let spinChars = ["|", "/", "-", "\\"]
        let char = spinChars[step % spinChars.count]
        let spinner = Text(char).accent()

        await SwiftTUI.render(spinner, on: surface, in: bounds)
    }

    // MARK: - Enhanced List Row Rendering

    @MainActor
    static func drawListRow(screen: OpaquePointer?, row: Int32, col: Int32,
                           isSelected: Bool, content: () async -> Void) async {
        let surface = SwiftTUI.surface(from: screen)

        // Clear the line first
        // Clearing handled by SwiftTUI surface operations

        // Apply selection highlighting if needed
        if isSelected {
            let rowBounds = Rect(x: col, y: row, width: 120, height: 1) // Use reasonable width
            await surface.fill(rect: rowBounds, character: " ", style: .accent)
        }

        await content()
    }

    // MARK: - Field Display Helpers

    @MainActor
    static func drawField(screen: OpaquePointer?, row: Int32, col: Int32,
                         label: String, value: String, isSelected: Bool = false,
                         labelWidth: Int = 20, maxValueWidth: Int = 40) async {
        let surface = SwiftTUI.surface(from: screen)
        let totalWidth = labelWidth + maxValueWidth + 2
        let bounds = Rect(x: col, y: row, width: Int32(totalWidth), height: 1)

        let paddedLabel = label.padding(toLength: labelWidth, withPad: ".", startingAt: 0)
        let truncatedValue = String(value.prefix(maxValueWidth))

        let labelStyle: TextStyle = isSelected ? .accent : .secondary
        let fieldComponent = HStack(spacing: 0, children: [
            Text("\(paddedLabel): ").styled(labelStyle),
            Text(truncatedValue).primary()
        ])

        await SwiftTUI.render(fieldComponent, on: surface, in: bounds)
    }
}