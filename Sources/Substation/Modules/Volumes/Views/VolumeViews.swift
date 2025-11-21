import Foundation
import OSClient
import SwiftNCurses

struct VolumeViews {

    // MARK: - Volume List View

    @MainActor
    static func drawDetailedVolumeList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                     width: Int32, height: Int32, cachedVolumes: [Volume],
                                     searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                      dataManager: DataManager? = nil,
                                     virtualScrollManager: VirtualScrollManager<Volume>? = nil,
                                     multiSelectMode: Bool = false, selectedItems: Set<String> = []) async {

        let statusListView = createVolumeStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedVolumes,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            dataManager: dataManager,
            virtualScrollManager: virtualScrollManager,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Volume Detail View

    @MainActor
    static func drawVolumeDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                               width: Int32, height: Int32, volume: Volume, scrollOffset: Int = 0) async {

        var sections: [DetailSection] = []

        // Basic Information Section
        let status = volume.status ?? "Unknown"
        let statusStyle: TextStyle = status.lowercased() == "available" ? .success :
                                   status.lowercased() == "in-use" ? .info :
                                   (status.lowercased().contains("error") ? .error : .warning)

        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: volume.id),
            DetailView.buildFieldItem(label: "Name", value: volume.name),
            DetailView.buildFieldItem(label: "Description", value: volume.description),
            .field(label: "Status", value: status, style: statusStyle),
            volume.size.map { .field(label: "Size", value: "\($0) GB", style: .accent) }
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Volume Configuration Section
        var configItems: [DetailItem?] = []

        if let volumeType = volume.volumeType {
            configItems.append(.field(label: "Volume Type", value: volumeType, style: .secondary))
            let typeDescription = getVolumeTypeDescription(volumeType)
            if !typeDescription.isEmpty {
                configItems.append(.field(label: "  Description", value: typeDescription, style: .info))
            }
        }

        if let bootable = volume.bootable {
            let bootableValue = bootable.lowercased() == "true"
            configItems.append(.field(label: "Bootable", value: bootableValue ? "Yes" : "No", style: bootableValue ? .success : .secondary))
            if bootableValue {
                configItems.append(.field(label: "  Description", value: "Can be used to boot an instance", style: .info))
            }
        }

        if let encrypted = volume.encrypted {
            configItems.append(.field(label: "Encrypted", value: encrypted ? "Yes" : "No", style: encrypted ? .success : .warning))
            if !encrypted {
                configItems.append(.field(label: "  Warning", value: "Volume data is not encrypted at rest", style: .warning))
            }
        }

        if let multiattach = volume.multiattach {
            configItems.append(.field(label: "Multi-attach", value: multiattach ? "Enabled" : "Disabled", style: multiattach ? .success : .secondary))
            if multiattach {
                configItems.append(.field(label: "  Description", value: "Volume can be attached to multiple instances", style: .info))
            }
        }

        if let sharedTargets = volume.sharedTargets {
            configItems.append(.field(label: "Shared Targets", value: sharedTargets ? "Yes" : "No", style: .secondary))
        }

        if let configSection = DetailView.buildSection(title: "Volume Configuration", items: configItems, titleStyle: .accent) {
            sections.append(configSection)
        }

        // Source Information Section
        var sourceItems: [DetailItem?] = []

        if let sourceVolid = volume.sourceVolid {
            sourceItems.append(.field(label: "Source Volume ID", value: sourceVolid, style: .secondary))
            sourceItems.append(.field(label: "  Type", value: "Cloned from volume", style: .info))
        }

        if let snapshotId = volume.snapshotId {
            sourceItems.append(.field(label: "Snapshot ID", value: snapshotId, style: .secondary))
            sourceItems.append(.field(label: "  Type", value: "Created from snapshot", style: .info))
        }

        if let imageId = volume.imageId {
            sourceItems.append(.field(label: "Image ID", value: imageId, style: .secondary))
            sourceItems.append(.field(label: "  Type", value: "Created from image", style: .info))
        }

        if let sourceSection = DetailView.buildSection(title: "Source Information", items: sourceItems) {
            sections.append(sourceSection)
        }

        // Attachments Section
        if let attachments = volume.attachments, !attachments.isEmpty {
            var attachmentItems: [DetailItem] = []

            for attachment in attachments {
                if let serverId = attachment.serverId {
                    attachmentItems.append(.field(label: "Server ID", value: serverId, style: .secondary))

                    if let device = attachment.device {
                        attachmentItems.append(.field(label: "  Device", value: device, style: .accent))
                    }

                    if let attachmentId = attachment.id {
                        attachmentItems.append(.field(label: "  Attachment ID", value: attachmentId, style: .muted))
                    }

                    if let volumeId = attachment.volumeId {
                        attachmentItems.append(.field(label: "  Volume ID", value: volumeId, style: .muted))
                    }

                    attachmentItems.append(.spacer)
                }
            }

            // Remove trailing spacer
            if !attachmentItems.isEmpty && attachmentItems.last?.isSpacerType == true {
                attachmentItems.removeLast()
            }

            sections.append(DetailSection(title: "Attachments", items: attachmentItems))
        } else {
            sections.append(DetailSection(
                title: "Attachments",
                items: [.field(label: "Status", value: "Not attached to any server", style: .info)]
            ))
        }

        // Status Information Section
        var statusInfoItems: [DetailItem?] = []

        if let replicationStatus = volume.replicationStatus {
            statusInfoItems.append(.field(label: "Replication Status", value: replicationStatus, style: .secondary))
        }

        if let migrationStatus = volume.migrationStatus {
            statusInfoItems.append(.field(label: "Migration Status", value: migrationStatus, style: .warning))
        }

        if let statusInfoSection = DetailView.buildSection(title: "Status Information", items: statusInfoItems) {
            sections.append(statusInfoSection)
        }

        // Location and Placement Section
        var locationItems: [DetailItem?] = []

        if let availabilityZone = volume.availabilityZone {
            locationItems.append(.field(label: "Availability Zone", value: availabilityZone, style: .secondary))
        }

        if let hostAttr = volume.hostAttr {
            locationItems.append(.field(label: "Host", value: hostAttr, style: .secondary))
        }

        if let clusterName = volume.clusterName {
            locationItems.append(.field(label: "Cluster", value: clusterName, style: .secondary))
        }

        if let locationSection = DetailView.buildSection(title: "Location and Placement", items: locationItems) {
            sections.append(locationSection)
        }

        // Group Information Section
        var groupItems: [DetailItem?] = []

        if let consistencygroupId = volume.consistencygroupId {
            groupItems.append(.field(label: "Consistency Group ID", value: consistencygroupId, style: .secondary))
            groupItems.append(.field(label: "  Description", value: "Part of consistency group for snapshots", style: .info))
        }

        if let groupId = volume.groupId {
            groupItems.append(.field(label: "Group ID", value: groupId, style: .secondary))
        }

        if let groupSection = DetailView.buildSection(title: "Group Information", items: groupItems) {
            sections.append(groupSection)
        }

        // Provider Information Section
        var providerItems: [DetailItem?] = []

        if let providerId = volume.providerId {
            providerItems.append(.field(label: "Provider ID", value: providerId, style: .secondary))
        }

        if let serviceUuid = volume.serviceUuid {
            providerItems.append(.field(label: "Service UUID", value: serviceUuid, style: .secondary))
        }

        if let providerSection = DetailView.buildSection(title: "Provider Information", items: providerItems) {
            sections.append(providerSection)
        }

        // Metadata Section
        if let metadata = volume.metadata, !metadata.isEmpty {
            let metadataItems = metadata.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Metadata", items: metadataItems))
        }

        // Ownership Section
        var ownershipItems: [DetailItem?] = []

        if let projectId = volume.projectId {
            ownershipItems.append(.field(label: "Project ID", value: projectId, style: .secondary))
        }

        if let userId = volume.userId {
            ownershipItems.append(.field(label: "User ID", value: userId, style: .secondary))
        }

        if let ownershipSection = DetailView.buildSection(title: "Ownership", items: ownershipItems) {
            sections.append(ownershipSection)
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: volume.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: volume.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Volume Details: \(volume.name ?? "Unnamed Volume")",
            sections: sections,
            helpText: "Press ESC to return to volume list",
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

    // MARK: - Helper Functions for Enhanced Volume Information

    private static func getVolumeTypeDescription(_ volumeType: String) -> String {
        switch volumeType.lowercased() {
        case "ssd": return "Solid State Drive - High IOPS, low latency"
        case "hdd": return "Hard Disk Drive - High capacity, lower IOPS"
        case "nvme": return "NVMe SSD - Ultra-high IOPS, ultra-low latency"
        case "iscsi": return "iSCSI network storage"
        case "rbd": return "Ceph RBD block storage"
        case "lvm": return "LVM-based local storage"
        case let type where type.contains("ssd"): return "SSD-based storage"
        case let type where type.contains("hdd"): return "HDD-based storage"
        default: return ""
        }
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
            let surface = SwiftNCurses.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftNCurses.render(Text("Screen too small").error(), on: surface, in: errorBounds)
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
                                title: "Select Source Image",
                                description: "Select image to create volume from. SPACE: select, ENTER: confirm"
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
                        }
                        return
                    }
                case VolumeCreateFieldId.volumeType.rawValue:
                    if let state = formBuilderState.selectorStates[selectorField.id] {
                        let selectedIds = state.selectedItemId.map { Set([$0]) } ?? []
                        if let volumeTypes = selectorField.items as? [VolumeType] {
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
        let surface = SwiftNCurses.surface(from: screen)

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
        await SwiftNCurses.render(finalComponent, on: surface, in: bounds)
    }

    // MARK: - Pagination and Virtual Scrolling Navigation Helpers

    /// Handle navigation for paginated volume list
    ///
    /// Note: Pagination is now handled via VirtualScrollManager. This method
    /// exists for backwards compatibility but defers to virtual scroll navigation.
    /// - Parameters:
    ///   - dataManager: The data manager (unused, kept for API compatibility)
    ///   - direction: Navigation direction
    /// - Returns: Always false - use handleVirtualScrollNavigation instead
    @MainActor
    static func handlePaginatedNavigation(dataManager: DataManager?, direction: NavigationDirection) async -> Bool {
        // Pagination is now handled via VirtualScrollManager
        // This method is kept for backwards compatibility but returns false
        return false
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

    /// Get current volume list status (virtual scrolling)
    ///
    /// - Parameters:
    ///   - dataManager: The data manager (unused, kept for API compatibility)
    ///   - virtualScrollManager: The virtual scroll manager
    /// - Returns: Status string from virtual scroll manager, or nil
    @MainActor
    static func getVolumeListStatus(dataManager: DataManager?, virtualScrollManager: VirtualScrollManager<Volume>?) -> String? {
        if let virtualScrollManager = virtualScrollManager {
            return "Virtual: \(virtualScrollManager.getScrollInfo())"
        }
        return nil
    }

    /// Check if enhanced scrolling (virtual scroll) is available
    ///
    /// - Parameters:
    ///   - dataManager: The data manager (unused, kept for API compatibility)
    ///   - virtualScrollManager: The virtual scroll manager
    /// - Returns: True if virtual scroll manager is available
    @MainActor
    static func hasEnhancedScrolling(dataManager: DataManager?, virtualScrollManager: VirtualScrollManager<Volume>?) -> Bool {
        return virtualScrollManager != nil
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