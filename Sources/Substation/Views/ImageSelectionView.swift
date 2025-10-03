import Foundation
import OSClient
import SwiftTUI

struct ImageSelectionView {
    @MainActor
    static func drawImageSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        images: [Image],
        selectedImageIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        title: String = "Select Source Image"
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        let tabs = [
            FormSelectorTab<Image>(
                title: "Images",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 35) { image in
                        (image.name ?? "Unknown").padding(toLength: 35, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "STATUS", width: 15) { image in
                        (image.status ?? "unknown").padding(toLength: 15, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "SIZE", width: 12) { image in
                        let sizeGB = (image.size ?? 0) / 1_073_741_824
                        return "\(sizeGB) GB".padding(toLength: 12, withPad: " ", startingAt: 0)
                    }
                ]
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: images,
            selectedItemIds: selectedImageIds,
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
