import Foundation
import SwiftNCurses

struct LoadingView {
    // MARK: - ASCII Art Constants - Modern, Clean Design
    private static let substationAsciiArt: [String] = [
        "",
        "    //   ) )                                                                       ",
        "   ((               / / __      ___    __  ___  ___    __  ___ ( )  ___       __   ",
        "     \\\\     //   / / //   ) ) ((   ) )  / /   //   ) )  / /   / / //   ) ) //   ) )",
        "       ) ) //   / / //   / /   \\ \\     / /   //   / /  / /   / / //   / / //   / / ",
        "((___ / / ((___( ( ((___/ / //   ) )  / /   ((___( (  / /   / / ((___/ / //   / /  ",
        ""
    ]

    // Modern minimalist design
    private static let modernArt: [String] = [
        "",
        "========================================================================",
        "||                                                                    ||",
        "||     S U B S T A T I O N    -    C O N T R O L    R O O M           ||",
        "||                                                                    ||",
        "========================================================================",
        ""
    ]

    private static let bylineText = "The Operators Control Room"

    // Layout constants
    private static let loadingMinScreenWidth: Int32 = 40
    private static let loadingMinScreenHeight: Int32 = 15
    private static let loadingBoundsMinWidth: Int32 = 1
    private static let loadingBoundsMinHeight: Int32 = 1
    private static let loadingComponentSpacing: Int32 = 1
    private static let loadingTopPadding: Int32 = 2
    private static let loadingBottomPadding: Int32 = 2
    private static let loadingLeadingPadding: Int32 = 0
    private static let loadingTrailingPadding: Int32 = 0
    private static let loadingBylineTopPadding: Int32 = 1
    private static let loadingProgressTopPadding: Int32 = 3
    private static let loadingStatusTopPadding: Int32 = 2

    // Progress indicator configuration - Pure ASCII
    private static let maxProgressDots = 5
    private static let progressDotCharacter = "#"
    private static let progressEmptyCharacter = "-"

    // Alternative progress styles
    private static let progressBarCharacter = "="
    private static let progressEmptyBarCharacter = "."
    private static let progressSpinnerFrames = ["|", "/", "-", "\\"]

    // Modern progress bar width
    private static let progressBarWidth = 40

    // Text constants - Modern messaging
    private static let loadingScreenTooSmallText = "Screen too small"
    private static let loadingStatusConnecting = "Establishing connection to OpenStack cloud..."
    private static let loadingStatusAuthenticating = "Verifying credentials and permissions..."
    private static let loadingStatusInitializing = "Loading cloud resources and services..."
    private static let loadingStatusComplete = "Ready! Welcome to the control room."

    @MainActor
    static func drawLoadingScreen(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                  width: Int32, height: Int32, progressStep: Int = 0,
                                  statusMessage: String? = nil) async {

        // Create surface for optimal performance
        let surface = SwiftNCurses.surface(from: screen)

        // Make it full screen - ignore provided boundaries and use entire screen
        let fullScreenWidth = width
        let fullScreenHeight = height
        let fullScreenStartRow: Int32 = 0
        let fullScreenStartCol: Int32 = 0

        // Defensive bounds checking
        guard fullScreenWidth > loadingMinScreenWidth && fullScreenHeight > loadingMinScreenHeight else {
            let errorBounds = Rect(x: 0, y: 0,
                                   width: max(loadingBoundsMinWidth, fullScreenWidth),
                                   height: max(loadingBoundsMinHeight, fullScreenHeight))
            await SwiftNCurses.render(Text(loadingScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Clear the entire screen first
        let fullScreenBounds = Rect(x: 0, y: 0, width: fullScreenWidth, height: fullScreenHeight)
        await surface.fill(rect: fullScreenBounds, character: " ", style: .primary)

        var components: [any Component] = []

        // Choose art style based on full screen width
        let artToUse: [String]
        if fullScreenWidth > 80 {
            artToUse = substationAsciiArt  // Use modern style for wider screens
        } else {
            artToUse = modernArt  // Use compact style for narrow screens
        }

        // Left-justify the ASCII art with consistent left margin
        let leftMargin = 8

        // Add ASCII art title (left-justified)
        for line in artToUse {
            let paddedLine = String(repeating: " ", count: leftMargin) + line
            components.append(Text(paddedLine).secondary().bold())
        }

        // Add byline (left-justified) - always show for context with emphasis
        let paddedByline = String(repeating: " ", count: leftMargin) + bylineText
        components.append(Text(paddedByline).secondary().bold()
            .padding(EdgeInsets(top: loadingBylineTopPadding, leading: 0, bottom: 0, trailing: 0)))

        // Add progress indicator
        let progressComponent = createProgressIndicator(step: progressStep, width: fullScreenWidth)
        components.append(progressComponent)

        // Add status message (left-justified) - use muted color for secondary status information
        let currentStatus = statusMessage ?? getDefaultStatusMessage(for: progressStep)
        let paddedStatus = String(repeating: " ", count: leftMargin) + currentStatus
        components.append(Text(paddedStatus).muted()
            .padding(EdgeInsets(top: loadingStatusTopPadding, leading: 0, bottom: 0, trailing: 0)))

        // Render the loading screen using full screen
        let loadingComponent = VStack(spacing: loadingComponentSpacing, children: components)
            .padding(EdgeInsets(top: loadingTopPadding, leading: loadingLeadingPadding,
                               bottom: loadingBottomPadding, trailing: loadingTrailingPadding))

        let bounds = Rect(x: fullScreenStartCol, y: fullScreenStartRow, width: fullScreenWidth, height: fullScreenHeight)
        await SwiftNCurses.render(loadingComponent, on: surface, in: bounds)
    }

    private static func createProgressIndicator(step: Int, width: Int32) -> any Component {
        // Create modern progress bar
        let progressPercent = min(Double(step) / Double(maxProgressDots), 1.0)
        let leftMargin = 8
        let barWidth = min(progressBarWidth, Int(width) - (leftMargin * 2)) // Leave margin on both sides
        let filledWidth = Int(Double(barWidth) * progressPercent)
        let emptyWidth = barWidth - filledWidth

        // Create progress bar
        let filledBar = String(repeating: progressBarCharacter, count: filledWidth)
        let emptyBar = String(repeating: progressEmptyBarCharacter, count: emptyWidth)
        let progressBar = "[\(filledBar)\(emptyBar)]"

        // Add percentage
        let percentage = Int(progressPercent * 100)
        let progressText = "\(progressBar) \(percentage)%"

        // Left-justify the progress indicator
        let paddedProgress = String(repeating: " ", count: leftMargin) + progressText

        return Text(paddedProgress).warning()
            .padding(EdgeInsets(top: loadingProgressTopPadding, leading: 0, bottom: 0, trailing: 0))
    }

    private static func getDefaultStatusMessage(for step: Int) -> String {
        switch step {
        case 0:
            return loadingStatusConnecting
        case 1:
            return loadingStatusAuthenticating
        case 2, 3:
            return loadingStatusInitializing
        case 4...:
            return loadingStatusComplete
        default:
            return loadingStatusConnecting
        }
    }
}