import SwiftTUI
import OSClient

@MainActor
struct SourceSelectionView {

    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32, width: Int32, height: Int32, images: [Image], volumes: [Volume], bootSource: BootSource, selectedImageId: String?, selectedVolumeId: String?, selectedIndex: Int, scrollOffset: Int, searchQuery: String?) async {
        let surface = SwiftTUI.surface(from: screen)
        let mainRect = Rect(x: startCol, y: startRow, width: width, height: height)

        // Sort images and volumes alphabetically by name
        let sortedImages = images.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        let sortedVolumes = volumes.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }

        if bootSource == .image {
            await drawImageSelection(
                surface: surface,
                rect: mainRect,
                images: sortedImages,
                selectedImageId: selectedImageId,
                selectedIndex: selectedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                width: width,
                height: height
            )
        } else {
            await drawVolumeSelection(
                surface: surface,
                rect: mainRect,
                volumes: sortedVolumes,
                selectedVolumeId: selectedVolumeId,
                selectedIndex: selectedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                width: width,
                height: height
            )
        }
    }

    private static func drawImageSelection(
        surface: any Surface,
        rect: Rect,
        images: [Image],
        selectedImageId: String?,
        selectedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        width: Int32,
        height: Int32
    ) async {
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
                description: "Select boot image. TAB: switch to volumes, SPACE: select, ENTER: confirm"
            )
        ]

        let selector = FormSelector(
            label: "Select Boot Source - Image",
            tabs: tabs,
            selectedTabIndex: 0,
            items: images,
            selectedItemIds: selectedImageId != nil ? [selectedImageId!] : [],
            highlightedIndex: selectedIndex,
            multiSelect: false,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxWidth: Int(width),
            maxHeight: Int(height),
            isActive: true
        )

        surface.clear(rect: rect)
        await SwiftTUI.render(selector.render(), on: surface, in: rect)
    }

    private static func drawVolumeSelection(
        surface: any Surface,
        rect: Rect,
        volumes: [Volume],
        selectedVolumeId: String?,
        selectedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        width: Int32,
        height: Int32
    ) async {
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
            label: "Select Boot Source - Volume",
            tabs: tabs,
            selectedTabIndex: 0,
            items: bootableVolumes,
            selectedItemIds: selectedVolumeId != nil ? [selectedVolumeId!] : [],
            highlightedIndex: selectedIndex,
            multiSelect: false,
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
