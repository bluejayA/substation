import OSClient
import SwiftTUI

struct VolumeManagementView {
    // Layout Constants
    private static let titleStartOffset: Int32 = 2
    private static let contentIndent: Int32 = 2
    private static let itemIndent: Int32 = 4
    private static let serverItemIndent: Int32 = 6
    private static let detailsIndent: Int32 = 52
    private static let toggleWidth: Int32 = 4
    private static let toggleSpacing: Int32 = 5
    private static let rowSpacing: Int32 = 1
    private static let sectionSpacing: Int32 = 2
    private static let serverInfoWidth: Int32 = 50
    private static let indicatorWidth: Int32 = 2
    private static let maxServerNameLength = 25
    private static let flavorIdDisplayLength = 8
    private static let headerSpacing: Int32 = 17
    private static let footerSpacing: Int32 = 6
    private static let pendingChangesOffset: Int32 = 5
    private static let footerOffset: Int32 = 3
    private static let controlsOffset: Int32 = 1
    private static let errorMessageWidth: Int32 = 28
    private static let loadingMessageWidth: Int32 = 40
    private static let errorPrefixLength = 7

    // Text Constants
    private static let unnamedVolumeText = "Unnamed Volume"
    private static let unnamedServerText = "Unnamed Server"
    private static let errorPrefix = "Error: "
    private static let noVolumeSelectedError = "No volume selected"
    private static let volumeLabel = "Volume: "
    private static let statusLabel = "Status: "
    private static let operationLabel = "Operation: "
    private static let volumeInfoSeparator = " | "
    private static let volumeSizeUnit = "GB"
    private static let volumeSizeFormat = "(%d%@)"
    private static let loadingMessage = "Processing volume attachment operation..."
    private static let currentlyAttachedText = " (currently attached)"
    private static let currentlyAttachedAsText = " (currently attached as %@)"
    private static let alreadyAttachedText = " (already attached)"
    private static let pendingAttachmentFormat = "Pending attachment to %d server(s)"
    private static let scrollIndicatorFormat = "(%d/%d) Use UP/DOWN to scroll"
    private static let selectedIndicator = "> "
    private static let unselectedIndicator = "  "
    private static let checkboxSelected = "[X]"
    private static let checkboxUnselected = "[ ]"
    private static let unknownStatus = "unknown"
    private static let flavorPrefix = " Flavor: "

    // Instruction Text Constants
    private static let viewNotAttachedInstruction = "Volume is not attached to any servers. Press TAB to switch to attach mode."
    private static let viewAttachedInstruction = "Viewing current server attachments. Press TAB to switch modes."
    private static let attachAvailableInstruction = "Select a server to attach this volume. SPACE to select, ENTER to apply."
    private static let attachAlreadyAttachedInstruction = "Volume is already attached. Detach first before attaching to another server."
    private static let detachNotAttachedInstruction = "Volume is not attached to any servers."
    private static let detachConfirmInstruction = "Volume will be detached from the attached server. Press ENTER to confirm."

    // List Title Constants
    private static let noServersAttachedTitle = "No servers (volume not attached)"
    private static let attachedServersTitle = "Attached to Servers:"
    private static let availableServersTitle = "Available Servers:"
    private static let alreadyAttachedTitle = "Already Attached (detach first):"
    private static let detachServersTitle = "Detach from Server:"
    private static let noServersToDetachTitle = "No servers to detach from"

    // Empty Message Constants
    private static let volumeNotAttachedMessage = "Volume is not attached to any servers"
    private static let noServersAvailableMessage = "No servers available"
    private static let volumeAlreadyAttachedMessage = "Volume is already attached"

    // Footer Control Constants
    private static let mainFooterText = "TAB: Switch operation | UP/DOWN: Navigate"
    private static let viewFooterControls = "ENTER: Edit attachment | ESC: Cancel"
    private static let attachAvailableFooterControls = "SPACE: Select server | ENTER: Apply | ESC: Cancel"
    private static let attachUnavailableFooterControls = "ESC: Cancel"
    private static let detachAvailableFooterControls = "ENTER: Detach | ESC: Cancel"
    private static let detachUnavailableFooterControls = "ESC: Cancel"

    // Enhanced Title Constants
    private static let manageTitlePrefix = "Manage Volume Attachments - "
    @MainActor
    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                    width: Int32, height: Int32, form: VolumeManagementForm,
                    resourceNameCache: ResourceNameCache) async {

        // Defensive bounds checking - prevent crashes on small screens
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        guard let volume = form.selectedVolume else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: startCol + Self.contentIndent, y: startRow + Self.titleStartOffset, width: Self.errorMessageWidth, height: Self.rowSpacing)
            await SwiftTUI.render(Text("\(Self.errorPrefix)\(Self.noVolumeSelectedError)").error(), on: surface, in: errorBounds)
            return
        }

        // Enhanced title with border
        let volumeName = volume.name ?? Self.unnamedVolumeText
        await BaseViewComponents.drawEnhancedTitle(screen: screen, startRow: startRow, startCol: startCol,
                                            width: width, title: "\(Self.manageTitlePrefix)\(volumeName)")

        // Build unified component structure
        var components: [any Component] = []

        // Volume info and status
        let volumeSize = String(format: Self.volumeSizeFormat, volume.size ?? 0, Self.volumeSizeUnit)
        let volumeInfoText = "\(Self.volumeLabel)\(volumeName) \(volumeSize)\(Self.volumeInfoSeparator)\(Self.statusLabel)\(form.getVolumeStatus())"
        components.append(Text(volumeInfoText).accent())

        // Show attachment info if volume is attached
        if let attachmentInfo = form.getAttachmentInfo() {
            components.append(Text(attachmentInfo).info())
        }

        // Add spacing
        components.append(Text(""))

        // Operation selector
        let operationText = "\(Self.operationLabel)\(form.selectedOperation.title)"
        components.append(Text(operationText).accent())

        // Instructions based on operation
        let instruction = getInstructionText(for: form.selectedOperation, volume: volume)
        components.append(Text(instruction).info())

        // Error message if present
        if let errorMessage = form.errorMessage {
            components.append(Text("\(Self.errorPrefix)\(errorMessage)").error())
        }

        // Loading indicator
        if form.isLoading {
            components.append(Text(Self.loadingMessage).info())
        } else {
            // Server list components
            let serverListComponents = createServerListComponents(form: form, volume: volume, height: height)
            components.append(contentsOf: serverListComponents)
        }

        // Render all components as unified VStack
        let contentBounds = Rect(x: startCol + Self.contentIndent, y: startRow + Self.titleStartOffset,
                               width: width - Self.contentIndent, height: height - Self.titleStartOffset)
        let surface = SwiftTUI.surface(from: screen)
        await SwiftTUI.render(VStack(spacing: 1, children: components), on: surface, in: contentBounds)

        // Footer components (rendered separately for positioning)
        await renderFooterComponents(screen: screen, startRow: startRow, startCol: startCol,
                                   width: width, height: height, form: form, volume: volume)
    }

    // MARK: - Component Creation Functions

    private static func createServerListComponents(form: VolumeManagementForm, volume: Volume, height: Int32) -> [any Component] {
        var components: [any Component] = []

        let displayServers = form.getCurrentDisplayItems()

        // Build selected server IDs for FormSelector
        var selectedServerIds: Set<String> = []
        for serverId in form.pendingAttachments {
            selectedServerIds.insert(serverId)
        }

        // Determine which tab is active based on operation mode
        let selectedTabIndex = form.selectedOperation == .view ? 0 : 1

        // Create tabs for View and Attach modes
        let viewTab = FormSelectorTab<Server>(
            title: "VIEW ATTACHED",
            columns: [
                FormSelectorColumn(header: "Server Name", width: 25) { server in
                    String((server.name ?? "Unnamed").prefix(25))
                },
                FormSelectorColumn(header: "Status", width: 10) { server in
                    String((server.status?.rawValue ?? "unknown").prefix(10))
                },
                FormSelectorColumn(header: "Device", width: 15) { server in
                    // Get the device path for this attachment
                    if let attachment = volume.attachments?.first(where: { $0.serverId == server.id }),
                       let device = attachment.device {
                        return String(device.prefix(15))
                    }
                    return "N/A"
                }
            ]
        )

        let attachTab = FormSelectorTab<Server>(
            title: "ATTACH TO SERVER",
            columns: [
                FormSelectorColumn(header: "Server Name", width: 25) { server in
                    String((server.name ?? "Unnamed").prefix(25))
                },
                FormSelectorColumn(header: "Status", width: 10) { server in
                    String((server.status?.rawValue ?? "unknown").prefix(10))
                },
                FormSelectorColumn(header: "Flavor", width: 15) { server in
                    if let flavorName = server.flavor?.name {
                        return String(flavorName.prefix(15))
                    }
                    return "Unknown"
                }
            ]
        )

        // Clamp highlighted index to valid range
        let safeHighlightedIndex = min(max(0, form.selectedResourceIndex), max(0, displayServers.count - 1))

        // Determine checkbox mode based on operation
        let checkboxMode: FormSelectorCheckboxMode = (form.selectedOperation == .attach && (volume.attachments?.isEmpty ?? true)) ? .multiSelect : .basic

        // Show empty message if no servers to display
        if displayServers.isEmpty {
            let emptyMessage = getEmptyMessage(for: form.selectedOperation, volume: volume)
            components.append(Text("  \(emptyMessage)").info())
            return components
        }

        let selector = FormSelector<Server>(
            label: getListTitle(for: form.selectedOperation, volume: volume),
            tabs: [viewTab, attachTab],
            selectedTabIndex: selectedTabIndex,
            items: displayServers,
            selectedItemIds: selectedServerIds,
            highlightedIndex: safeHighlightedIndex,
            checkboxMode: checkboxMode,
            scrollOffset: 0,
            searchQuery: nil,
            maxWidth: 80,
            maxHeight: Int(height) - 15,
            isActive: true
        )

        components.append(selector.render())

        return components
    }


    @MainActor
    private static func renderFooterComponents(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                             width: Int32, height: Int32, form: VolumeManagementForm, volume: Volume) async {
        let surface = SwiftTUI.surface(from: screen)

        // Pending changes summary
        if form.hasPendingChanges() {
            let summaryRow = startRow + height - Self.pendingChangesOffset
            let selectedCount = form.pendingAttachments.count
            let summaryText = String(format: Self.pendingAttachmentFormat, selectedCount)
            let summaryBounds = Rect(x: startCol + Self.contentIndent, y: summaryRow, width: Int32(summaryText.count), height: Self.rowSpacing)
            await SwiftTUI.render(Text(summaryText).accent(), on: surface, in: summaryBounds)
        }

        // Footer with controls
        let footerRow = startRow + height - Self.footerOffset
        let mainFooterBounds = Rect(x: startCol + Self.contentIndent, y: footerRow, width: Int32(Self.mainFooterText.count), height: Self.rowSpacing)
        await SwiftTUI.render(Text(Self.mainFooterText).info(), on: surface, in: mainFooterBounds)

        let footerControls = getFooterControls(for: form.selectedOperation, volume: volume)
        let controlsBounds = Rect(x: startCol + Self.contentIndent, y: footerRow + Self.controlsOffset, width: Int32(footerControls.count), height: Self.rowSpacing)
        await SwiftTUI.render(Text(footerControls).info(), on: surface, in: controlsBounds)
    }

    // MARK: - Helper Functions

    private static func getInstructionText(for operation: VolumeManagementForm.VolumeOperation, volume: Volume) -> String {
        switch operation {
        case .view:
            return volume.attachments?.isEmpty ?? true ? Self.viewNotAttachedInstruction : Self.viewAttachedInstruction
        case .attach:
            return volume.attachments?.isEmpty ?? true ? Self.attachAvailableInstruction : Self.attachAlreadyAttachedInstruction
        }
    }

    private static func getListTitle(for operation: VolumeManagementForm.VolumeOperation, volume: Volume) -> String {
        switch operation {
        case .view:
            return volume.attachments?.isEmpty ?? true ? Self.noServersAttachedTitle : Self.attachedServersTitle
        case .attach:
            return volume.attachments?.isEmpty ?? true ? Self.availableServersTitle : Self.alreadyAttachedTitle
        }
    }

    private static func getEmptyMessage(for operation: VolumeManagementForm.VolumeOperation, volume: Volume) -> String {
        switch operation {
        case .view:
            return Self.volumeNotAttachedMessage
        case .attach:
            return volume.attachments?.isEmpty ?? true ? Self.noServersAvailableMessage : Self.volumeAlreadyAttachedMessage
        }
    }

    private static func getFooterControls(for operation: VolumeManagementForm.VolumeOperation, volume: Volume) -> String {
        switch operation {
        case .view:
            return Self.viewFooterControls
        case .attach:
            return volume.attachments?.isEmpty ?? true ? Self.attachAvailableFooterControls : Self.attachUnavailableFooterControls
        }
    }
}