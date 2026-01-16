// Sources/Substation/Framework/BackgroundOperations/BackgroundOperationsView.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import SwiftNCurses

/// View for displaying a list of background operations
struct BackgroundOperationsView {

    /// Draw the background operations list view
    ///
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - startRow: Starting row position
    ///   - startCol: Starting column position
    ///   - width: Available width
    ///   - height: Available height
    ///   - operations: Array of operations to display
    ///   - scrollOffset: Current scroll offset
    ///   - selectedIndex: Currently selected index
    @MainActor
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        operations: [BackgroundOperation],
        scrollOffset: Int,
        selectedIndex: Int
    ) async {
        guard let screen = screen else { return }

        let columns = [
            StatusListColumn<BackgroundOperation>(
                header: "Type",
                width: 16,
                getValue: { $0.type.displayName }
            ),
            StatusListColumn<BackgroundOperation>(
                header: "Status",
                width: 12,
                getValue: { $0.status.displayName },
                getStyle: { operation in
                    switch operation.status {
                    case .running: return .info
                    case .completed: return .success
                    case .failed: return .error
                    case .cancelled: return .secondary
                    case .queued: return .accent
                    }
                }
            ),
            StatusListColumn<BackgroundOperation>(
                header: "Resource",
                width: 28,
                getValue: { $0.displayName }
            ),
            StatusListColumn<BackgroundOperation>(
                header: "Context",
                width: 18,
                getValue: { operation in
                    if let context = operation.resourceContext {
                        return context
                    } else if operation.type.tracksItems {
                        return "-"
                    } else {
                        return "-"
                    }
                }
            ),
            StatusListColumn<BackgroundOperation>(
                header: "Progress",
                width: 18,
                getValue: { operation in
                    if operation.type.tracksItems {
                        if operation.status == .completed {
                            return operation.itemsSummary
                        } else if operation.status.isActive {
                            return "\(operation.itemsCompleted)/\(operation.itemsTotal) (\(operation.progressPercentage)%)"
                        } else {
                            return operation.itemsSummary
                        }
                    } else {
                        if operation.status == .completed {
                            return "100%"
                        } else if operation.status.isActive {
                            return "\(operation.progressPercentage)%"
                        } else {
                            return "-"
                        }
                    }
                }
            ),
            StatusListColumn<BackgroundOperation>(
                header: "Size/Failed",
                width: 14,
                getValue: { operation in
                    if operation.type.tracksItems {
                        if operation.itemsFailed > 0 {
                            return "\(operation.itemsFailed) failed"
                        } else {
                            return "-"
                        }
                    } else if operation.totalBytes > 0 {
                        return "\(operation.formattedBytesTransferred) / \(operation.formattedTotalBytes)"
                    } else {
                        return "-"
                    }
                }
            ),
            StatusListColumn<BackgroundOperation>(
                header: "Rate",
                width: 12,
                getValue: { operation in
                    if operation.type.tracksBytes && operation.status == .running {
                        return operation.formattedTransferRate
                    } else {
                        return "-"
                    }
                }
            ),
            StatusListColumn<BackgroundOperation>(
                header: "Time",
                width: 8,
                getValue: { $0.formattedElapsedTime }
            )
        ]

        let statusListView = StatusListView(
            title: "Operations",
            columns: columns,
            getStatusIcon: { _ in "" },
            filterItems: { items, _ in items },
            getItemID: { $0.id.uuidString }
        )

        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: operations,
            searchQuery: nil as String?,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            dataManager: nil as DataManager?,
            virtualScrollManager: nil as VirtualScrollManager<BackgroundOperation>?,
            multiSelectMode: false,
            selectedItems: []
        )
    }
}

