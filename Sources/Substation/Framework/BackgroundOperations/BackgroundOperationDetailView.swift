// Sources/Substation/Framework/BackgroundOperations/BackgroundOperationDetailView.swift
import Foundation
import SwiftNCurses

/// View for displaying detailed information about a background operation
struct BackgroundOperationDetailView {

    /// Draw the operation detail view
    ///
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - startRow: Starting row position
    ///   - startCol: Starting column position
    ///   - width: Available width
    ///   - height: Available height
    ///   - operation: The operation to display details for
    ///   - scrollOffset: Current scroll offset
    @MainActor
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        operation: BackgroundOperation,
        scrollOffset: Int
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        var basicItems: [DetailItem] = []
        basicItems.append(.field(label: "Operation ID", value: operation.id.uuidString.prefix(8) + "...", style: .secondary))
        basicItems.append(.field(label: "Type", value: operation.type.displayName, style: .secondary))
        basicItems.append(.field(label: "Category", value: operation.type.category.rawValue, style: .secondary))

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
        resourceItems.append(.field(label: "Resource", value: operation.resourceName, style: .secondary))
        if let resourceType = operation.resourceType {
            resourceItems.append(.field(label: "Resource Type", value: resourceType, style: .secondary))
        }
        if let context = operation.resourceContext {
            resourceItems.append(.field(label: "Context", value: context, style: .secondary))
        }

        sections.append(DetailSection(title: "Resource Information", items: resourceItems))

        // Progress Information Section (only for active or completed operations)
        if operation.status.isActive || operation.status == .completed {
            var progressItems: [DetailItem] = []
            progressItems.append(.field(label: "Progress", value: "\(operation.progressPercentage)%", style: .secondary))

            // Show byte-level stats for transfer operations
            if operation.type.tracksBytes {
                progressItems.append(.field(label: "Bytes Transferred", value: operation.formattedBytesTransferred, style: .secondary))
                progressItems.append(.field(label: "Total Size", value: operation.formattedTotalBytes, style: .secondary))

                if operation.status == .running {
                    progressItems.append(.field(label: "Transfer Rate", value: operation.formattedTransferRate, style: .secondary))
                }
            }

            // Show item-level stats for bulk operations
            if operation.type.tracksItems {
                progressItems.append(.field(label: "Items Completed", value: "\(operation.itemsCompleted)/\(operation.itemsTotal)", style: .secondary))

                if operation.itemsFailed > 0 {
                    progressItems.append(.field(label: "Items Failed", value: "\(operation.itemsFailed)", style: .error))
                }

                if operation.itemsSkipped > 0 {
                    progressItems.append(.field(label: "Items Skipped", value: "\(operation.itemsSkipped)", style: .info))
                }
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

        if !operation.status.isActive {
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
            helpText = "Press DELETE to remove | ESC to return"
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

