import Foundation
import OSClient
import SwiftTUI

struct VolumeViews {

    // MARK: - Volume List View

    @MainActor
    static func drawDetailedVolumeList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                     width: Int32, height: Int32, cachedVolumes: [Volume],
                                     searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                      dataManager: DataManager? = nil,
                                     virtualScrollManager: VirtualScrollManager<Volume>? = nil) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Main Volume List
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        let titleText = searchQuery.map { "Volumes (filtered: \($0))" } ?? "Volumes"
        components.append(Text(titleText).emphasis().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        // Header
        components.append(Text(" ST  NAME                   STATUS       SIZE     ATTACHED TO").muted()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)).border())

        // Content - enhanced with pagination and virtual scrolling support
        await renderVolumeList(
            components: &components,
            cachedVolumes: cachedVolumes,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            height: height,
            width: width,
            dataManager: dataManager,
            virtualScrollManager: virtualScrollManager
        )

        // Render unified volume list
        let volumeListComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(volumeListComponent, on: surface, in: bounds)
    }

    // MARK: - Enhanced Rendering with Pagination Support

    @MainActor
    private static func renderVolumeList(
        components: inout [any Component],
        cachedVolumes: [Volume],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        height: Int32,
        width: Int32,

        dataManager: DataManager?,
        virtualScrollManager: VirtualScrollManager<Volume>?
    ) async {
        // Determine which rendering approach to use based on available systems
        if let virtualScrollManager = virtualScrollManager {
            await renderWithVirtualScrolling(
                components: &components,
                virtualScrollManager: virtualScrollManager,
                selectedIndex: selectedIndex,
                height: height,
                width: width
            )
        } else if let dataManager = dataManager, dataManager.isPaginationEnabled(for: "volumes") {
            await renderWithPagination(
                components: &components,
                dataManager: dataManager,
                selectedIndex: selectedIndex,
                height: height,
                width: width
            )
        } else {
            // Fallback to traditional rendering
            await renderTraditional(
                components: &components,
                cachedVolumes: cachedVolumes,
                searchQuery: searchQuery,
                scrollOffset: scrollOffset,
                selectedIndex: selectedIndex,
                height: height,
                width: width
            )
        }
    }

    @MainActor
    private static func renderWithVirtualScrolling(
        components: inout [any Component],
        virtualScrollManager: VirtualScrollManager<Volume>,
        selectedIndex: Int,
        height: Int32,
        width: Int32
    ) async {
        let maxVisibleItems = max(1, Int(height) - 10)
        let renderableItems = virtualScrollManager.getRenderableItems(
            startRow: 5, // Volume list start row
            endRow: 5 + Int32(maxVisibleItems)
        )

        if renderableItems.isEmpty {
            components.append(Text("No volumes found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            for (volume, _, index) in renderableItems {
                let isSelected = index == selectedIndex
                let volumeComponent = createVolumeListItemComponent(
                    volume: volume,
                    isSelected: isSelected,
                    width: width
                )
                components.append(volumeComponent)
            }

            // Virtual scrolling status
            let scrollInfo = virtualScrollManager.getScrollInfo()
            components.append(Text("Virtual: \(scrollInfo)").info()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
        }
    }

    @MainActor
    private static func renderWithPagination(
        components: inout [any Component],
        dataManager: DataManager,
        selectedIndex: Int,
        height: Int32,
        width: Int32
    ) async {
        let paginatedVolumes: [Volume] = await dataManager.getPaginatedItems(for: "volumes", type: Volume.self)

        if paginatedVolumes.isEmpty {
            components.append(Text("No volumes found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            let maxVisibleItems = max(1, Int(height) - 10)
            let endIndex = min(paginatedVolumes.count, maxVisibleItems)

            for i in 0..<endIndex {
                let volume = paginatedVolumes[i]
                let isSelected = i == selectedIndex
                let volumeComponent = createVolumeListItemComponent(
                    volume: volume,
                    isSelected: isSelected,
                    width: width
                )
                components.append(volumeComponent)
            }

            // Pagination status
            if let paginationStatus = dataManager.getPaginationStatus(for: "volumes") {
                components.append(Text("Paginated: \(paginationStatus)").info()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
            }
        }
    }

    @MainActor
    private static func renderTraditional(
        components: inout [any Component],
        cachedVolumes: [Volume],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        height: Int32,
        width: Int32
    ) async {
        let filteredVolumes = FilterUtils.filterVolumes(cachedVolumes, query: searchQuery)

        if filteredVolumes.isEmpty {
            components.append(Text("No volumes found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            // Calculate visible range for simple viewport
            let maxVisibleItems = max(1, Int(height) - 10) // Reserve space for header and footer
            let startIndex = max(0, min(scrollOffset, filteredVolumes.count - maxVisibleItems))
            let endIndex = min(filteredVolumes.count, startIndex + maxVisibleItems)

            for i in startIndex..<endIndex {
                let volume = filteredVolumes[i]
                let isSelected = i == selectedIndex
                let volumeComponent = createVolumeListItemComponent(volume: volume, isSelected: isSelected, width: width)
                components.append(volumeComponent)
            }

            // Traditional scroll indicator
            if filteredVolumes.count > maxVisibleItems {
                let scrollText = "[\(startIndex + 1)-\(endIndex)/\(filteredVolumes.count)]"
                components.append(Text(scrollText).info()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
            }
        }
    }

    // MARK: - Component Creation Functions

    private static func createVolumeListItemComponent(volume: Volume, isSelected: Bool, width: Int32) -> any Component {
        // Volume name with formatting (22 chars to match header)
        let volumeName = String((volume.name ?? "Unnamed").prefix(22)).padding(toLength: 22, withPad: " ", startingAt: 0)

        // Enhanced status with color coding (12 chars to match header)
        let status = volume.status ?? "Unknown"
        let statusStyle: TextStyle = {
            switch status.lowercased() {
            case "available", "in-use": return .success
            case "error": return .error
            case "creating", "attaching", "detaching": return .warning
            default: return .info
            }
        }()
        let statusText = String(status.prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)

        // Size display (8 chars to match header)
        let sizeText = "\(volume.size ?? 0)GB"
        let sizeDisplay = String(sizeText.prefix(8)).padding(toLength: 8, withPad: " ", startingAt: 0)

        // Attachment info (remaining space)
        let remainingWidth = max(0, Int(width) - 50)
        let attachmentInfo: String
        if !(volume.attachments?.isEmpty ?? true) {
            let serverNames = volume.attachments?.compactMap { $0.serverId } ?? []
            attachmentInfo = serverNames.isEmpty ? "Attached" : String(serverNames.first?.prefix(remainingWidth) ?? "")
        } else {
            attachmentInfo = "Not attached"
        }
        let attachmentDisplay = remainingWidth > 5 ? String(attachmentInfo.prefix(remainingWidth)) : ""

        let rowStyle: TextStyle = isSelected ? .accent : .secondary

        return HStack(spacing: 0, children: [
            StatusIcon(status: volume.status ?? "unknown"),
            Text(" \(volumeName)").styled(rowStyle),
            Text(" \(statusText)").styled(statusStyle),
            Text(" \(sizeDisplay)").styled(.info),
            Text(" \(attachmentDisplay)").styled(rowStyle)
        ]).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
    }

    // MARK: - Volume Detail View

    @MainActor
    static func drawVolumeDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                               width: Int32, height: Int32, volume: Volume) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Main Volume Detail
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text("Volume Details: \(volume.name ?? "Unnamed")").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Basic Information Section
        components.append(Text("Basic Information").primary().bold())

        var basicInfo: [any Component] = []
        basicInfo.append(Text("ID: \(volume.id)").secondary())
        basicInfo.append(Text("Name: \(volume.name ?? "Unnamed")").secondary())

        // Status with appropriate styling
        let status = volume.status ?? "Unknown"
        let statusStyle: TextStyle = status.lowercased() == "available" ? .success :
                                   (status.lowercased().contains("error") ? .error : .accent)
        basicInfo.append(HStack(spacing: 0, children: [
            Text("Status: ").secondary(),
            Text(status).styled(statusStyle)
        ]))

        if let size = volume.size {
            basicInfo.append(Text("Size: \(size)GB").secondary())
        }

        if let volumeType = volume.volumeType {
            basicInfo.append(Text("Type: \(volumeType)").secondary())
        }

        let basicInfoSection = VStack(spacing: 0, children: basicInfo)
            .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
        components.append(basicInfoSection)

        // Properties Section
        components.append(Text("Properties").primary().bold())

        var properties: [any Component] = []
        if let bootable = volume.bootable {
            properties.append(Text("Bootable: \(bootable == "true" ? "Yes" : "No")").secondary())
        }
        if let encrypted = volume.encrypted {
            properties.append(Text("Encrypted: \(encrypted ? "Yes" : "No")").secondary())
        }

        if !properties.isEmpty {
            let propertiesSection = VStack(spacing: 0, children: properties)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
            components.append(propertiesSection)
        }

        // Attachments Section
        if !(volume.attachments?.isEmpty ?? true) {
            components.append(Text("Attachments").primary().bold())

            var attachmentComponents: [any Component] = []
            for attachment in volume.attachments ?? [] {
                if let serverId = attachment.serverId, let device = attachment.device {
                    attachmentComponents.append(Text("- Server: \(serverId) (Device: \(device))").secondary())
                } else if let serverId = attachment.serverId {
                    attachmentComponents.append(Text("- Server: \(serverId)").secondary())
                } else {
                    attachmentComponents.append(Text("- Attached").secondary())
                }
            }

            let attachmentsSection = VStack(spacing: 0, children: attachmentComponents)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
            components.append(attachmentsSection)
        }

        // Render unified volume detail
        let volumeDetailComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(volumeDetailComponent, on: surface, in: bounds)
    }

    // MARK: - Volume Create View

    // Layout Constants
    private static let volCreateComponentTopPadding: Int32 = 1
    private static let volCreateStatusMessageTopPadding: Int32 = 2
    private static let volCreateStatusMessageLeadingPadding: Int32 = 2
    private static let volCreateValidationErrorLeadingPadding: Int32 = 2
    private static let volCreateLoadingErrorBoundsHeight: Int32 = 6
    private static let volCreateFieldActiveSpacing = "                      "

    // Text Constants
    private static let volCreateFormTitle = "Create Volume"
    private static let volCreateCreatingText = "Creating volume..."
    private static let volCreateErrorPrefix = "Error: "
    private static let volCreateRequiredFieldSuffix = ": *"
    private static let volCreateOptionalFieldSuffix = " (optional)"

    // Field Display Constants
    private static let volCreateValidationErrorsTitle = "Validation Errors:"
    private static let volCreateValidationErrorPrefix = "- "
    private static let volCreateEditPromptText = "Press SPACE to edit..."
    private static let volCreateSelectPromptText = "Press SPACE to select"

    // Field Label Constants
    private static let volCreateNameFieldLabel = "Volume Name"
    private static let volCreateSizeFieldLabel = "Volume Size (GB)"
    private static let volCreateSourceTypeFieldLabel = "Source Type"
    private static let volCreateImageFieldLabel = "Source Image"
    private static let volCreateSnapshotFieldLabel = "Source Snapshot"
    private static let volCreateVolumeTypeFieldLabel = "Volume Type"

    // Placeholder Constants
    private static let volCreateNamePlaceholder = "[Enter volume name]"
    private static let volCreateSizePlaceholder = "[Enter size in GB]"

    // UI Component Constants
    private static let volCreateSelectedIndicator = "> "
    private static let volCreateUnselectedIndicator = "  "
    private static let volCreateComponentSpacing: Int32 = 0

    // Help Text Constants
    private static let volCreateHelpText = "TAB/Up/Down: Navigate | SPACE: Edit/Select | ENTER: Create | ESC: Cancel"

    @MainActor
    static func drawVolumeCreate(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                               width: Int32, height: Int32, formBuilderState: FormBuilderState) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Check if a selector field is active and render custom overlay
        if let currentField = formBuilderState.getCurrentField(), formBuilderState.isCurrentFieldActive() {
            switch currentField {
            case .selector(let selectorField):
                // Render custom selector overlays
                switch selectorField.id {
                case VolumeCreateFieldId.sourceType.rawValue:
                    if let state = formBuilderState.selectorStates[selectorField.id] {
                        let selectedIds = state.selectedItemId.map { Set([$0]) } ?? []
                        await SourceTypeSelectionView.drawSourceTypeSelection(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            sourceTypes: selectorField.items as? [SourceTypeOption] ?? [],
                            selectedSourceTypeIds: selectedIds,
                            highlightedIndex: state.highlightedIndex,
                            scrollOffset: state.scrollOffset,
                            searchQuery: state.searchQuery,
                            title: "Select Source Type"
                        )
                        return
                    }
                case VolumeCreateFieldId.source.rawValue:
                    if let state = formBuilderState.selectorStates[selectorField.id] {
                        let selectedIds = state.selectedItemId.map { Set([$0]) } ?? []

                        // Determine which view to use based on source type
                        if let images = selectorField.items as? [Image] {
                            await ImageSelectionView.drawImageSelection(
                                screen: screen,
                                startRow: startRow,
                                startCol: startCol,
                                width: width,
                                height: height,
                                images: images,
                                selectedImageIds: selectedIds,
                                highlightedIndex: state.highlightedIndex,
                                scrollOffset: state.scrollOffset,
                                searchQuery: state.searchQuery,
                                title: "Select Source Image"
                            )
                        } else if let snapshots = selectorField.items as? [VolumeSnapshot] {
                            await VolumeSnapshotSelectionView.drawVolumeSnapshotSelection(
                                screen: screen,
                                startRow: startRow,
                                startCol: startCol,
                                width: width,
                                height: height,
                                snapshots: snapshots,
                                selectedSnapshotIds: selectedIds,
                                highlightedIndex: state.highlightedIndex,
                                scrollOffset: state.scrollOffset,
                                searchQuery: state.searchQuery,
                                title: "Select Source Snapshot"
                            )
                        } else if let volumeTypes = selectorField.items as? [VolumeType] {
                            await VolumeTypeSelectionView.drawVolumeTypeSelection(
                                screen: screen,
                                startRow: startRow,
                                startCol: startCol,
                                width: width,
                                height: height,
                                volumeTypes: volumeTypes,
                                selectedVolumeTypeIds: selectedIds,
                                highlightedIndex: state.highlightedIndex,
                                scrollOffset: state.scrollOffset,
                                searchQuery: state.searchQuery,
                                title: "Select Volume Type"
                            )
                        }
                        return
                    }
                default:
                    break
                }
            default:
                break
            }
        }

        // Main Volume Create Form using FormBuilder
        let surface = SwiftTUI.surface(from: screen)

        // Create FormBuilder instance
        let formBuilder = FormBuilder(
            title: "Create Volume",
            fields: formBuilderState.fields,
            selectedFieldId: formBuilderState.getCurrentFieldId(),
            validationErrors: [],
            showValidationErrors: false
        )

        // Render form
        let formComponent = formBuilder.render()

        // Add help text at the bottom
        let helpText = Text("TAB: Next Field | SPACE: Edit/Select | ENTER: Submit | ESC: Cancel").info()
        let finalComponent = VStack(spacing: 0, children: [
            formComponent,
            helpText.padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        ])

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(finalComponent, on: surface, in: bounds)
    }

    // MARK: - Pagination and Virtual Scrolling Navigation Helpers

    /// Handle navigation for paginated volume list
    @MainActor
    static func handlePaginatedNavigation(dataManager: DataManager?, direction: NavigationDirection) async -> Bool {
        guard let dataManager = dataManager, dataManager.isPaginationEnabled(for: "volumes") else {
            return false
        }

        switch direction {
        case .nextPage:
            return await dataManager.nextPage(for: "volumes")
        case .previousPage:
            return await dataManager.previousPage(for: "volumes")
        case .scrollUp, .scrollDown:
            // Individual item scrolling handled differently for volumes
            return false
        }
    }

    /// Handle navigation for virtual scrolling volume list
    @MainActor
    static func handleVirtualScrollNavigation(virtualScrollManager: VirtualScrollManager<Volume>?, direction: NavigationDirection) async -> Bool {
        guard let virtualScrollManager = virtualScrollManager else {
            return false
        }

        switch direction {
        case .scrollUp:
            await virtualScrollManager.scrollUp()
            return true
        case .scrollDown:
            await virtualScrollManager.scrollDown()
            return true
        case .nextPage:
            await virtualScrollManager.pageDown()
            return true
        case .previousPage:
            await virtualScrollManager.pageUp()
            return true
        }
    }

    /// Get current volume list status (pagination or virtual scrolling)
    @MainActor
    static func getVolumeListStatus(dataManager: DataManager?, virtualScrollManager: VirtualScrollManager<Volume>?) -> String? {
        if let virtualScrollManager = virtualScrollManager {
            return "Virtual: \(virtualScrollManager.getScrollInfo())"
        } else if let dataManager = dataManager, dataManager.isPaginationEnabled(for: "volumes") {
            if let status = dataManager.getPaginationStatus(for: "volumes") {
                return "Pages: \(status)"
            }
        }
        return nil
    }

    /// Check if enhanced scrolling (pagination or virtual) is available
    @MainActor
    static func hasEnhancedScrolling(dataManager: DataManager?, virtualScrollManager: VirtualScrollManager<Volume>?) -> Bool {
        return virtualScrollManager != nil || (dataManager?.isPaginationEnabled(for: "volumes") == true)
    }

    // Navigation direction enum for cleaner API
    enum NavigationDirection {
        case scrollUp
        case scrollDown
        case nextPage
        case previousPage
    }

    // MARK: - Helper Functions for Selection Windows

    private static func formatVolumeTypeDisplayText(_ volumeType: VolumeType) -> String {
        let name = volumeType.name ?? "Unknown"
        if let description = volumeType.description, !description.isEmpty {
            return "\(name) - \(description)"
        }
        return name
    }

    private static func formatImageDisplayText(_ image: Image) -> String {
        let name = image.name ?? "Unnamed Image"
        let status = image.status ?? "Unknown"
        return "\(name) (\(status))"
    }

    private static func formatSnapshotDisplayText(_ snapshot: VolumeSnapshot) -> String {
        let name = snapshot.name ?? "Unnamed"
        let status = snapshot.status ?? "Unknown"
        return "\(name) (\(status))"
    }
}