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
        let listTitle = getListTitle(for: form.selectedOperation, volume: volume)

        components.append(Text(listTitle).accent())

        let maxDisplayRows = max(1, Int(height - Self.headerSpacing))
        let startIndex = max(0, form.selectedResourceIndex - maxDisplayRows + 1)
        let endIndex = min(displayServers.count, startIndex + maxDisplayRows)

        if displayServers.isEmpty {
            let emptyMessage = getEmptyMessage(for: form.selectedOperation, volume: volume)
            components.append(Text("  \(emptyMessage)").info())
        } else {
            for i in startIndex..<endIndex {
                let server = displayServers[i]
                let isSelected = i == form.selectedResourceIndex
                let serverComponent = createServerItemComponent(server: server, form: form, isSelected: isSelected)
                components.append(serverComponent)
            }
        }

        return components
    }

    private static func createServerItemComponent(server: Server, form: VolumeManagementForm, isSelected: Bool) -> any Component {
        var itemComponents: [any Component] = []

        // Selection indicator
        let indicator = isSelected ? Self.selectedIndicator : Self.unselectedIndicator
        itemComponents.append(Text(indicator).styled(isSelected ? .accent : .primary))

        // Toggle indicator for attach mode only
        if form.selectedOperation == .attach && (form.selectedVolume?.attachments?.isEmpty ?? true) {
            let isToggled = form.isServerSelected(server.id)
            let toggleChar = isToggled ? Self.checkboxSelected : Self.checkboxUnselected
            let toggleStyle: TextStyle = isToggled ? .success : .secondary
            itemComponents.append(Text("\(toggleChar) ").styled(toggleStyle))
        }

        // Server info components
        let serverName = server.name ?? Self.unnamedServerText
        let displayName = String(serverName.prefix(Self.maxServerNameLength))
        let status = server.status?.rawValue ?? Self.unknownStatus
        let statusInfo = " (\(status.uppercased()))"

        var serverInfoText = displayName + statusInfo

        // Server flavor info if available
        if let flavorId = server.flavor?.id {
            let flavorInfo = "\(Self.flavorPrefix)\(String(flavorId.prefix(Self.flavorIdDisplayLength)))"
            serverInfoText += flavorInfo
        }

        itemComponents.append(Text(serverInfoText).styled(isSelected ? .accent : .secondary))

        // Current attachment indicator
        if form.isServerCurrentlyAttached(server.id) {
            let attachmentText: String
            if let volume = form.selectedVolume,
               let attachment = volume.attachments?.first(where: { $0.serverId == server.id }),
               let device = attachment.device {
                attachmentText = String(format: Self.currentlyAttachedAsText, device)
            } else {
                attachmentText = Self.currentlyAttachedText
            }
            itemComponents.append(Text(attachmentText).success())
        }

        // Status indicator for attach mode
        if form.selectedOperation == .attach && form.isServerCurrentlyAttached(server.id) {
            itemComponents.append(Text(Self.alreadyAttachedText).info())
        }

        return HStack(spacing: 0, children: itemComponents)
    }

    @MainActor
    private static func renderFooterComponents(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                             width: Int32, height: Int32, form: VolumeManagementForm, volume: Volume) async {
        let surface = SwiftTUI.surface(from: screen)

        // Scroll indicator
        let displayServers = form.getCurrentDisplayItems()
        let maxDisplayRows = max(1, Int(height - Self.headerSpacing))
        if displayServers.count > maxDisplayRows {
            let scrollRow = startRow + height - Self.footerSpacing
            let scrollText = String(format: Self.scrollIndicatorFormat, form.selectedResourceIndex + 1, displayServers.count)
            let scrollBounds = Rect(x: startCol + Self.contentIndent, y: scrollRow, width: Int32(scrollText.count), height: Self.rowSpacing)
            await SwiftTUI.render(Text(scrollText).info(), on: surface, in: scrollBounds)
        }

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

    @MainActor
    private static func drawServerItem(screen: OpaquePointer?, server: Server, form: VolumeManagementForm, isSelected: Bool, startCol: Int32, row: Int32) async {
        let surface = SwiftTUI.surface(from: screen)
        var currentCol = startCol

        // Toggle indicator for attach mode only
        if form.selectedOperation == .attach && (form.selectedVolume?.attachments?.isEmpty ?? true) {
            let isToggled = form.isServerSelected(server.id)
            let toggleChar = isToggled ? Self.checkboxSelected : Self.checkboxUnselected
            let toggleStyle: TextStyle = isToggled ? .success : .secondary
            let toggleBounds = Rect(x: currentCol, y: row, width: Self.toggleWidth, height: Self.rowSpacing)
            await SwiftTUI.render(Text("\(toggleChar) ").styled(toggleStyle), on: surface, in: toggleBounds)
            currentCol += Self.toggleSpacing
        }

        // Server info components
        let serverName = server.name ?? Self.unnamedServerText
        let displayName = String(serverName.prefix(Self.maxServerNameLength))
        let status = server.status?.rawValue ?? Self.unknownStatus
        let statusInfo = " (\(status.uppercased()))"

        var serverInfoComponents: [any Component] = [
            Text(displayName).styled(isSelected ? .accent : .secondary),
            Text(statusInfo).styled(isSelected ? .accent : .secondary)
        ]

        // Server flavor info if available
        if let flavorId = server.flavor?.id {
            let flavorInfo = "\(Self.flavorPrefix)\(String(flavorId.prefix(Self.flavorIdDisplayLength)))"
            serverInfoComponents.append(Text(flavorInfo).styled(isSelected ? .accent : .secondary))
        }

        let serverInfoBounds = Rect(x: currentCol, y: row, width: Self.serverInfoWidth, height: Self.rowSpacing)
        await SwiftTUI.render(HStack(spacing: 0, children: serverInfoComponents), on: surface, in: serverInfoBounds)

        // Current attachment indicator
        if form.isServerCurrentlyAttached(server.id) {
            let attachmentText: String
            if let volume = form.selectedVolume,
               let attachment = volume.attachments?.first(where: { $0.serverId == server.id }),
               let device = attachment.device {
                attachmentText = String(format: Self.currentlyAttachedAsText, device)
            } else {
                attachmentText = Self.currentlyAttachedText
            }
            let attachmentBounds = Rect(x: currentCol + Self.detailsIndent, y: row, width: Int32(attachmentText.count), height: Self.rowSpacing)
            await SwiftTUI.render(Text(attachmentText).success(), on: surface, in: attachmentBounds)
        }

        // Status indicator for attach mode
        if form.selectedOperation == .attach && form.isServerCurrentlyAttached(server.id) {
            let statusBounds = Rect(x: currentCol + Self.detailsIndent, y: row, width: Int32(Self.alreadyAttachedText.count), height: Self.rowSpacing)
            await SwiftTUI.render(Text(Self.alreadyAttachedText).info(), on: surface, in: statusBounds)
        }
    }
}