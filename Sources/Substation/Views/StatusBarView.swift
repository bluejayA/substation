import Foundation
import OSClient
import SwiftTUI

@MainActor
struct StatusBarView {

    static func draw(screen: OpaquePointer?, tui: TUI, screenCols: Int32, screenRows: Int32) async {
        let surface = SwiftTUI.surface(from: screen)
        // Status bar is now at the very bottom (last row)
        let statusRow = screenRows - 1

        // Status bar using SwiftTUI
        let statusBounds = Rect(x: 0, y: statusRow, width: screenCols, height: 1)

        let statusText = await buildEnhancedStatusText(tui: tui, screenCols: screenCols)
        let statusComponent = Text(statusText).primary()

        await surface.fill(rect: statusBounds, character: " ", style: .border)
        await SwiftTUI.render(statusComponent, on: surface, in: statusBounds)
    }

    /// Builds enhanced status text that includes progress indicators and user-friendly error messages
    private static func buildEnhancedStatusText(tui: TUI, screenCols: Int32) async -> String {
        let maxWidth = Int(screenCols) - 4 // Leave some padding

        // Build status components
        var statusComponents: [String] = []

        // Add current cloud context if available
        if let currentCloud = tui.contextSwitcher.currentContext {
            statusComponents.append("Cloud: \(currentCloud)")
        }

        // Add command mode indicator if active
        if tui.unifiedInputState.isCommandMode && tui.unifiedInputState.isActive {
            statusComponents.append("CMD")
        }

        // Check for active progress indicators
        let activeOperations = tui.progressIndicator.activeOperations
        if !activeOperations.isEmpty {
            // Show the most recent active operation
            if let operation = activeOperations.values.first {
                let progressText = formatProgressOperation(operation)
                let fullStatus = buildFullStatus(components: statusComponents, mainText: progressText)
                return ViewUtils.truncateStatusText(fullStatus, maxWidth: maxWidth)
            }
        }

        // Check for active loading states
        let activeLoadingStates = tui.loadingStateManager.activeLoadingStates
        if !activeLoadingStates.isEmpty {
            if let loadingState = activeLoadingStates.values.first {
                let loadingText = "\(loadingState.message)..."
                let fullStatus = buildFullStatus(components: statusComponents, mainText: loadingText)
                return ViewUtils.truncateStatusText(fullStatus, maxWidth: maxWidth)
            }
        }

        // Show regular status message or ready state
        if let status = tui.statusMessage {
            let fullStatus = buildFullStatus(components: statusComponents, mainText: status)
            return ViewUtils.truncateStatusText(fullStatus, maxWidth: maxWidth)
        } else {
            let fullStatus = buildFullStatus(components: statusComponents, mainText: "Ready")
            return ViewUtils.truncateStatusText(fullStatus, maxWidth: maxWidth)
        }
    }

    /// Build full status string from components and main text
    private static func buildFullStatus(components: [String], mainText: String) -> String {
        if components.isEmpty {
            return " \(mainText)"
        } else {
            let prefix = components.joined(separator: " | ")
            return " [\(prefix)] \(mainText)"
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