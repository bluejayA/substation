import Foundation
import SwiftTUI

struct SwiftBackgroundOperationDetailView {

    @MainActor
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        operation: SwiftBackgroundOperation,
        scrollOffset: Int
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        var basicItems: [DetailItem] = []
        basicItems.append(.field(label: "Operation ID", value: operation.id.uuidString.prefix(8) + "...", style: .secondary))
        basicItems.append(.field(label: "Type", value: operation.type.displayName, style: .secondary))

        // Status with custom component for visual indicator
        let statusStyle: TextStyle
        switch operation.status {
        case .queued:
            statusStyle = .info
        case .running:
            statusStyle = .accent
        case .completed:
            statusStyle = .success
        case .failed:
            statusStyle = .error
        case .cancelled:
            statusStyle = .secondary
        }
        basicItems.append(.customComponent(
            HStack(spacing: 0, children: [
                Text("  Status: ").secondary(),
                Text(operation.status.displayName).styled(statusStyle).bold()
            ])
        ))

        sections.append(DetailSection(title: "Basic Information", items: basicItems))

        // Resource Information Section
        var resourceItems: [DetailItem] = []
        resourceItems.append(.field(label: "Container", value: operation.containerName, style: .secondary))
        if let objectName = operation.objectName {
            resourceItems.append(.field(label: "Object", value: objectName, style: .secondary))
        }
        resourceItems.append(.field(label: "Local Path", value: operation.localPath, style: .secondary))

        sections.append(DetailSection(title: "Resource Information", items: resourceItems))

        // Progress Information Section (only for active or completed operations)
        if operation.status.isActive || operation.status == .completed {
            var progressItems: [DetailItem] = []
            progressItems.append(.field(label: "Progress", value: "\(operation.progressPercentage)%", style: .secondary))
            progressItems.append(.field(label: "Bytes Transferred", value: operation.formattedBytesTransferred, style: .secondary))
            progressItems.append(.field(label: "Total Size", value: operation.formattedTotalBytes, style: .secondary))

            if operation.status == .running {
                progressItems.append(.field(label: "Transfer Rate", value: operation.formattedTransferRate, style: .secondary))
            }

            // Show file statistics if multi-file operation
            if operation.filesTotal > 0 {
                let fileStats = "\(operation.filesCompleted)/\(operation.filesTotal)"
                progressItems.append(.field(label: "Files Processed", value: fileStats, style: .secondary))

                if operation.filesSkipped > 0 {
                    progressItems.append(.field(label: "Files Skipped", value: "\(operation.filesSkipped)", style: .info))
                }
            }

            sections.append(DetailSection(title: "Progress Information", items: progressItems))
        }

        // Timing Information Section
        var timingItems: [DetailItem] = []
        timingItems.append(.field(label: "Started At", value: operation.startTime.formatted(), style: .secondary))
        timingItems.append(.field(label: "Elapsed Time", value: operation.formattedElapsedTime, style: .secondary))

        if operation.status == .completed {
            let duration = operation.elapsedTime
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            timingItems.append(.field(label: "Duration", value: "\(minutes)m \(seconds)s", style: .secondary))
        }

        sections.append(DetailSection(title: "Timing Information", items: timingItems))

        // Error Information Section (if failed)
        if let error = operation.error {
            var errorItems: [DetailItem] = []
            errorItems.append(.field(label: "Error Message", value: error, style: .error))
            sections.append(DetailSection(title: "Error Information", items: errorItems, titleStyle: .error))
        }

        // Build help text
        let helpText: String
        if operation.status.isActive {
            helpText = "Press DELETE to cancel | ESC to return"
        } else {
            helpText = "Press ESC to return to operations list"
        }

        // Create and render the detail view
        let detailView = DetailView(
            title: "Operation Details",
            sections: sections,
            helpText: helpText,
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
    }
}
