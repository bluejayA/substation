import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import SwiftTUI

struct SwiftBackgroundOperationsView {

    @MainActor
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        operations: [SwiftBackgroundOperation],
        scrollOffset: Int,
        selectedIndex: Int
    ) async {
        guard let screen = screen else { return }

        let columns = [
            StatusListColumn<SwiftBackgroundOperation>(
                header: "Type",
                width: 10,
                getValue: { $0.type.displayName }
            ),
            StatusListColumn<SwiftBackgroundOperation>(
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
            StatusListColumn<SwiftBackgroundOperation>(
                header: "File/Object",
                width: 30,
                getValue: { $0.displayName }
            ),
            StatusListColumn<SwiftBackgroundOperation>(
                header: "Container",
                width: 20,
                getValue: { $0.containerName }
            ),
            StatusListColumn<SwiftBackgroundOperation>(
                header: "Progress",
                width: 15,
                getValue: { operation in
                    if operation.status == .completed {
                        return "100%"
                    } else if operation.status.isActive {
                        return "\(operation.progressPercentage)%"
                    } else {
                        return "-"
                    }
                }
            ),
            StatusListColumn<SwiftBackgroundOperation>(
                header: "Size",
                width: 12,
                getValue: { operation in
                    if operation.totalBytes > 0 {
                        return "\(operation.formattedBytesTransferred) / \(operation.formattedTotalBytes)"
                    } else {
                        return "-"
                    }
                }
            ),
            StatusListColumn<SwiftBackgroundOperation>(
                header: "Rate",
                width: 12,
                getValue: { operation in
                    if operation.status == .running {
                        return operation.formattedTransferRate
                    } else {
                        return "-"
                    }
                }
            ),
            StatusListColumn<SwiftBackgroundOperation>(
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
            virtualScrollManager: nil as VirtualScrollManager<SwiftBackgroundOperation>?,
            multiSelectMode: false,
            selectedItems: []
        )
    }
}
