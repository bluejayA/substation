import Foundation
import OSClient
import SwiftTUI

@MainActor
struct StatusBarView {

    static func draw(screen: OpaquePointer?, tui: TUI, screenCols: Int32, screenRows: Int32) async {
        let surface = SwiftTUI.surface(from: screen)
        let statusRow = screenRows - 2

        // Status bar using SwiftTUI
        let statusBounds = Rect(x: 0, y: statusRow, width: screenCols, height: 1)

        let statusText = await buildEnhancedStatusText(tui: tui, screenCols: screenCols)
        let statusComponent = Text(statusText).primary()

        await surface.fill(rect: statusBounds, character: " ", style: .border)
        await SwiftTUI.render(statusComponent, on: surface, in: statusBounds)

        // Help line using SwiftTUI
        let helpBounds = Rect(x: 0, y: screenRows - 1, width: screenCols, height: 1)

        let helpText = getDynamicHelpText(for: tui.currentView)
        let maxWidth = Int(screenCols) - 2
        let truncatedText = String(helpText.prefix(maxWidth))
        let helpComponent = Text(" \(truncatedText)").muted()

        await surface.fill(rect: helpBounds, character: " ", style: .border)
        await SwiftTUI.render(helpComponent, on: surface, in: helpBounds)
    }

    private static func getDynamicHelpText(for currentView: ViewMode) -> String {
        return UIUtils.getDynamicHelpText(for: currentView)
    }

    /// Builds enhanced status text that includes progress indicators and user-friendly error messages
    private static func buildEnhancedStatusText(tui: TUI, screenCols: Int32) async -> String {
        let maxWidth = Int(screenCols) - 4 // Leave some padding

        // Check for active progress indicators
        let activeOperations = tui.progressIndicator.activeOperations
        if !activeOperations.isEmpty {
            // Show the most recent active operation
            if let operation = activeOperations.values.first {
                let progressText = formatProgressOperation(operation)
                return ViewUtils.truncateStatusText(progressText, maxWidth: maxWidth)
            }
        }

        // Check for active loading states
        let activeLoadingStates = tui.loadingStateManager.activeLoadingStates
        if !activeLoadingStates.isEmpty {
            if let loadingState = activeLoadingStates.values.first {
                let loadingText = " \(loadingState.message)..."
                return ViewUtils.truncateStatusText(loadingText, maxWidth: maxWidth)
            }
        }

        // Show regular status message or ready state
        if let status = tui.statusMessage {
            return ViewUtils.truncateStatusText(" Status: \(status)", maxWidth: maxWidth)
        } else {
            return " Ready"
        }
    }

    /// Formats a progress operation for display in the status bar
    private static func formatProgressOperation(_ operation: OperationProgress) -> String {
        if operation.isComplete {
            return " \(operation.operationName) - Complete"
        }

        let progressPercent = operation.progressPercentage
        let progressBar = ViewUtils.createProgressBar(progress: operation.overallProgress, width: 10)

        if operation.totalStages > 1 {
            return " \(operation.operationName) - \(operation.stageName) [\(progressBar)] \(progressPercent)%"
        } else {
            return " \(operation.operationName) [\(progressBar)] \(progressPercent)%"
        }
    }
}