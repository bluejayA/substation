import Foundation
import OSClient
import SwiftNCurses

struct VolumeTypeSelectionView {
    @MainActor
    static func drawVolumeTypeSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        volumeTypes: [VolumeType],
        selectedVolumeTypeIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Volume Type"
    ) async {
        let surface = SwiftNCurses.surface(from: screen)

        let tabs = [
            FormSelectorTab<VolumeType>(
                title: "Volume Types",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { volumeType in
                        (volumeType.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "DESCRIPTION", width: 40) { volumeType in
                        (volumeType.description ?? "No description").padding(toLength: 40, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: volumeTypes,
            selectedItemIds: selectedVolumeTypeIds,
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxWidth: Int(width),
            maxHeight: Int(height),
            isActive: true
        )

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftNCurses.render(selector.render(), on: surface, in: bounds)
    }
}
