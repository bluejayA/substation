import Foundation
import OSClient
import SwiftNCurses

/// Unified image selection view used by both Server Create and Volume Create forms
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
        title: String = "Select Image",
        description: String? = nil
    ) async {
        let surface = SwiftNCurses.surface(from: screen)

        // Sort images alphabetically for consistent display
        let sortedImages = images.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }

        // Recalculate highlightedIndex for sorted array
        // If a selectedImageId exists, find it in the sorted array
        let adjustedHighlightedIndex: Int
        if let selectedId = selectedImageIds.first,
           let indexInSorted = sortedImages.firstIndex(where: { $0.id == selectedId }) {
            adjustedHighlightedIndex = indexInSorted
        } else {
            // If no selection or can't find it, use the provided index (clamped to valid range)
            adjustedHighlightedIndex = min(highlightedIndex, max(0, sortedImages.count - 1))
        }

        let tabs = [
            FormSelectorTab<Image>(
                title: "IMAGES",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { image in
                        (image.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "STATUS", width: 10) { image in
                        (image.status ?? "unknown").padding(toLength: 10, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "SIZE", width: 10) { image in
                        let sizeGB = image.size != nil ? String(format: "%.1fGB", Double(image.size!) / (1024 * 1024 * 1024)) : "unknown"
                        return sizeGB.padding(toLength: 10, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "PUBLIC", width: 8) { image in
                        let visibility = (image.visibility == "public") ? "Yes" : "No"
                        return visibility.padding(toLength: 8, withPad: " ", startingAt: 0)
                    }
                ],
                description: description ?? "Browse and select image. SPACE: select, ENTER: confirm"
            )
        ]

        let selector = FormSelector(
            label: title,
            tabs: tabs,
            selectedTabIndex: 0,
            items: sortedImages,
            selectedItemIds: selectedImageIds,
            highlightedIndex: adjustedHighlightedIndex,
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
