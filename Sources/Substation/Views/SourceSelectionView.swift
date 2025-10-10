import SwiftTUI
import OSClient

@MainActor
struct SourceSelectionView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, images: [Image], volumes: [Volume], bootSource: BootSource, selectedImageId: String?, selectedVolumeId: String?, selectedIndex: Int, scrollOffset: Int, searchQuery: String?) async {
        // Sort volumes alphabetically by name
        let sortedVolumes = volumes.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }

        if bootSource == .image {
            // Use unified ImageSelectionView
            await ImageSelectionView.drawImageSelection(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                images: images,
                selectedImageIds: selectedImageId != nil ? [selectedImageId!] : [],
                highlightedIndex: selectedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                title: "Select Source - Mode: Image",
                description: "Select boot image. TAB: switch to volumes, SPACE: select, ENTER: confirm"
            )
        } else {
            await drawVolumeSelection(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                volumes: sortedVolumes,
                selectedVolumeId: selectedVolumeId,
                selectedIndex: selectedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery
            )
        }
    }

    private static func drawVolumeSelection(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        volumes: [Volume],
        selectedVolumeId: String?,
        selectedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let rect = Rect(x: startCol, y: startRow, width: width, height: height)
        let bootableVolumes = volumes.filter { $0.bootable?.lowercased() == "true" }

        let tabs = [
            FormSelectorTab<Volume>(
                title: "BOOTABLE VOLUMES",
                columns: [
                    FormSelectorColumn(header: "NAME", width: 30) { volume in
                        (volume.name ?? "Unknown").padding(toLength: 30, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "STATUS", width: 10) { volume in
                        (volume.status ?? "unknown").padding(toLength: 10, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "SIZE", width: 10) { volume in
                        String(format: "%dGB", volume.size ?? 0).padding(toLength: 10, withPad: " ", startingAt: 0)
                    },
                    FormSelectorColumn(header: "BOOTABLE", width: 8) { volume in
                        let bootable = (volume.bootable?.lowercased() == "true") ? "Yes" : "No"
                        return bootable.padding(toLength: 8, withPad: " ", startingAt: 0)
                    }
                ],
                description: "Select bootable volume. TAB: switch to images, SPACE: select, ENTER: confirm"
            )
        ]

        let selector = FormSelector(
            label: "Select Source - Mode: Volume",
            tabs: tabs,
            selectedTabIndex: 0,
            items: bootableVolumes,
            selectedItemIds: selectedVolumeId != nil ? [selectedVolumeId!] : [],
            highlightedIndex: selectedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxWidth: Int(width),
            maxHeight: Int(height),
            isActive: true
        )

        surface.clear(rect: rect)
        await SwiftTUI.render(selector.render(), on: surface, in: rect)
    }
}
