import Foundation
import OSClient
import SwiftTUI

struct VolumeSnapshotSelectionView {
    @MainActor
    static func drawVolumeSnapshotSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        snapshots: [VolumeSnapshot],
        selectedSnapshotIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Source Snapshot"
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        let tabs = [
            FormSelectorTab<VolumeSnapshot>(
                title: "Snapshots",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { snapshot in
                        (snapshot.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "STATUS", width: 15) { snapshot in
                        (snapshot.status ?? "unknown").padding(toLength: 15, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "SIZE", width: 12) { snapshot in
                        let sizeGB = snapshot.size ?? 0
                        return "\(sizeGB) GB".padding(toLength: 12, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "DESCRIPTION", width: 25) { snapshot in
                        (snapshot.description ?? "No description").padding(toLength: 25, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: snapshots,
            selectedItemIds: selectedSnapshotIds,
            highlightedIndex: highlightedIndex,
            multiSelect: false,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxWidth: Int(width),
            maxHeight: Int(height),
            isActive: true
        )

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selector.render(), on: surface, in: bounds)
    }
}
