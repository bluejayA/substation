import Foundation
import OSClient
import SwiftTUI

struct ServerGroupViews {
    // Layout constants
    private static let groupNameWidth = 30
    private static let policyWidth = 18
    private static let membersWidth = 8
    private static let projectDisplayOffset = 65
    private static let serverNameWidth = 26
    private static let statusDisplayWidth = 11
    private static let ipDisplayWidth = 15
    private static let maxServerNameTruncation = 25
    private static let maxMetadataValueTruncation = 50
    private static let maxMembersToShowBase = 3

    // Additional Layout Constants
    private static let formHeightOffset: Int32 = 2
    private static let detailHeightOffset: Int32 = 4
    private static let instructionSpacing: Int32 = 3
    private static let errorFooterOffset: Int32 = 2
    private static let helpFooterOffset: Int32 = 1
    private static let visibleHeightOffset = 3
    private static let maxMetadataOffset = 2
    private static let memberHeightPadding: Int32 = 1
    private static let scrollCenterDivisor = 2

    // Bounds and Rectangle Constants
    private static let boundsWidthOffset: Int32 = 4  // Standard width offset for bounds
    private static let boundsHeight: Int32 = 1       // Standard height for single-line bounds
    private static let currentRowOffset: Int32 = 2   // Standard offset for currentRow calculations
    private static let maxMembersOffset = 3          // Offset for member display calculations

    // Text Constants
    private static let unknownText = "Unknown"
    private static let unnamedServerText = "Unnamed Server"
    private static let noServersText = "No servers in this group"
    private static let noServersAvailableText = "No servers available"
    private static let noneIPText = "None"
    private static let andMorePrefix = "  ... and "
    private static let serverSingular = " server"
    private static let serverPlural = " servers"

    // UI Layout constants
    private static let contentVerticalOffset: Int32 = 6  // Title + headers + footer
    private static let titleOffset: Int32 = 2
    private static let headerStartRow: Int32 = 3
    private static let separatorRow: Int32 = 4
    private static let listStartRow: Int32 = 5
    private static let uiPadding: Int32 = 2
    private static let minimumRemainingWidth = 5

    // Standard padding patterns
    private static let standardPadding = EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)
    private static let sectionPadding = EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)
    private static let bottomSpacingPadding = EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)
    private static let topSpacingPadding = EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)
    private static let formPadding = EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)
    private static let errorPadding = EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)

    // Header text constants
    private static let serverGroupListHeader = "   NAME                           POLICY             MEMBERS  PROJECT"
    private static let serverManagementHeader = "     NAME                        STATUS      IP ADDRESS     MEMBERSHIP"

    // MARK: - Server Group List View

    @MainActor
    static func drawDetailedServerGroupList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                           width: Int32, height: Int32, cachedServerGroups: [ServerGroup],
                                           searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

        let statusListView = createServerGroupStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedServerGroups,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Server Group Detail View

    // Detail View Constants
    private static let sgDetailTitle = "Server Group Details"
    private static let sgDetailBasicInfoTitle = "Basic Information"
    private static let sgDetailMembersTitle = "Members"
    private static let sgDetailMetadataTitle = "Metadata"
    private static let sgDetailIdLabel = "ID"
    private static let sgDetailNameLabel = "Name"
    private static let sgDetailPolicyLabel = "Policy"
    private static let sgDetailDescriptionLabel = "Description"
    private static let sgDetailProjectIdLabel = "Project ID"
    private static let sgDetailUserIdLabel = "User ID"
    private static let sgDetailFieldValueSeparator = ": "
    private static let sgDetailMetadataKeySeparator = ": "
    private static let sgDetailMemberNameSuffix = " - "
    private static let sgDetailNoMembersText = "No servers in this group"
    private static let sgDetailScrollMoreText = "... and "
    private static let sgDetailScrollSuffix = " more - Use Server Management for full list"

    // Detail View Layout Constants
    private static let sgDetailMaxVisibleMembers = 5
    private static let sgDetailMaxMetadataItems = 8
    private static let sgDetailMetadataValueMaxLength = 50
    private static let sgDetailMemberNameMaxLength = 25
    private static let sgDetailInfoFieldIndent = "  "
    private static let sgDetailComponentSpacing: Int32 = 0

    @MainActor
    static func drawServerGroupDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                    width: Int32, height: Int32, serverGroup: ServerGroup,
                                    cachedServers: [Server]) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Main Server Group Detail
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text("\(Self.sgDetailTitle)\(Self.sgDetailFieldValueSeparator)\(serverGroup.name ?? unknownText)").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Basic Information Section
        components.append(Text(Self.sgDetailBasicInfoTitle).primary().bold())

        var basicInfo: [any Component] = []
        basicInfo.append(Text("\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailIdLabel)\(Self.sgDetailFieldValueSeparator)\(serverGroup.id)").secondary())
        basicInfo.append(Text("\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailNameLabel)\(Self.sgDetailFieldValueSeparator)\(serverGroup.name ?? unknownText)").secondary())

        // Policy with appropriate styling
        let policyStyle = policyStyleForDetail(serverGroup.primaryPolicy)
        basicInfo.append(HStack(spacing: 0, children: [
            Text("\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailPolicyLabel)\(Self.sgDetailFieldValueSeparator)").secondary(),
            Text(serverGroup.primaryPolicy?.displayName ?? Self.unknownText).styled(policyStyle)
        ]))

        // Policy Description
        if let policy = serverGroup.primaryPolicy {
            basicInfo.append(Text("\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailDescriptionLabel)\(Self.sgDetailFieldValueSeparator)\(policy.description)").info())
        }

        // Project ID
        if let projectId = serverGroup.project_id {
            basicInfo.append(Text("\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailProjectIdLabel)\(Self.sgDetailFieldValueSeparator)\(projectId)").secondary())
        }

        // User ID
        if let userId = serverGroup.user_id {
            basicInfo.append(Text("\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailUserIdLabel)\(Self.sgDetailFieldValueSeparator)\(userId)").secondary())
        }

        let basicInfoSection = VStack(spacing: 0, children: basicInfo)
            .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
        components.append(basicInfoSection)

        // Members Section
        components.append(Text("\(Self.sgDetailMembersTitle) (\(serverGroup.members.count))").primary().bold())

        if serverGroup.members.isEmpty {
            components.append(Text("\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailNoMembersText)").info()
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0)))
        } else {
            // Get member servers and sort them by name for consistent display
            let memberServers = cachedServers.filter { serverGroup.members.contains($0.id) }
                                             .sorted { ($0.name ?? Self.unnamedServerText) < ($1.name ?? Self.unnamedServerText) }

            var memberComponents: [any Component] = []

            // Show members with limit
            let visibleMembers = memberServers.prefix(Self.sgDetailMaxVisibleMembers)
            for server in visibleMembers {
                let serverName = server.name ?? Self.unnamedServerText
                let truncatedName = String(serverName.prefix(Self.sgDetailMemberNameMaxLength))
                let status = server.status?.rawValue ?? Self.unknownText
                let statusStyle = statusStyleForMember(server.status?.rawValue)
                let ip = getServerIP(server) ?? Self.noneIPText

                let memberRow = HStack(spacing: 0, children: [
                    StatusIcon(status: server.status?.rawValue),
                    Text(" \(truncatedName)").secondary(),
                    Text(" (\(status))").styled(statusStyle),
                    Text("\(Self.sgDetailMemberNameSuffix)\(ip)").info()
                ])
                memberComponents.append(memberRow)
            }

            // Show scroll indicator if there are more members
            if memberServers.count > Self.sgDetailMaxVisibleMembers {
                let remainingCount = memberServers.count - Self.sgDetailMaxVisibleMembers
                let scrollText = "\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailScrollMoreText)\(remainingCount) more\(Self.sgDetailScrollSuffix)"
                memberComponents.append(Text(scrollText).warning())
            }

            let membersSection = VStack(spacing: 0, children: memberComponents)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
            components.append(membersSection)
        }

        // Metadata Section
        if let metadata = serverGroup.metadata, !metadata.isEmpty {
            components.append(Text(Self.sgDetailMetadataTitle).primary().bold())

            var metadataComponents: [any Component] = []
            let visibleMetadata = metadata.prefix(Self.sgDetailMaxMetadataItems)
            for (key, value) in visibleMetadata {
                let truncatedValue = String(value.prefix(Self.sgDetailMetadataValueMaxLength))
                let metadataRow = HStack(spacing: 0, children: [
                    Text("\(Self.sgDetailInfoFieldIndent)\(key)\(Self.sgDetailMetadataKeySeparator)").secondary(),
                    Text(truncatedValue).primary()
                ])
                metadataComponents.append(metadataRow)
            }

            if metadata.count > Self.sgDetailMaxMetadataItems {
                let remainingCount = metadata.count - Self.sgDetailMaxMetadataItems
                metadataComponents.append(Text("\(Self.sgDetailInfoFieldIndent)\(Self.sgDetailScrollMoreText)\(remainingCount) more items").warning())
            }

            let metadataSection = VStack(spacing: 0, children: metadataComponents)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
            components.append(metadataSection)
        }

        // Render unified server group detail
        let serverGroupDetailComponent = VStack(spacing: Self.sgDetailComponentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(serverGroupDetailComponent, on: surface, in: bounds)
    }

    // MARK: - Server Group Create View

    // Layout Constants
    private static let sgCreateComponentTopPadding: Int32 = 1
    private static let sgCreateStatusMessageTopPadding: Int32 = 2
    private static let sgCreateStatusMessageLeadingPadding: Int32 = 2
    private static let sgCreateValidationErrorLeadingPadding: Int32 = 2
    private static let sgCreateLoadingErrorBoundsHeight: Int32 = 6
    private static let sgCreateFieldActiveSpacing = "                      "

    // Text Constants
    private static let sgCreateFormTitle = "Create Server Group"
    private static let sgCreateCreatingText = "Creating server group..."
    private static let sgCreateErrorPrefix = "Error: "
    private static let sgCreateRequiredFieldSuffix = ": *"
    private static let sgCreateOptionalFieldSuffix = " (optional)"

    // Field Display Constants
    private static let sgCreateValidationErrorsTitle = "Validation Errors:"
    private static let sgCreateValidationErrorPrefix = "- "
    private static let sgCreateEditPromptText = "Press SPACE to edit..."
    private static let sgCreateSelectPromptText = "Press SPACE to select"
    private static let sgCreateCheckboxSelectedText = "[X]"
    private static let sgCreateCheckboxUnselectedText = "[ ]"

    // Field Label Constants
    private static let sgCreateNameFieldLabel = "Server Group Name"
    private static let sgCreatePolicyFieldLabel = "Policy"

    // Placeholder Constants
    private static let sgCreateNamePlaceholder = "[Enter server group name]"

    // UI Component Constants
    private static let sgCreateSelectedIndicator = "> "
    private static let sgCreateUnselectedIndicator = "  "
    private static let sgCreateComponentSpacing: Int32 = 0

    @MainActor
    static func drawServerGroupCreateForm(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: ServerGroupCreateForm,
        formState: FormBuilderState
    ) async {
        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Build form fields
        let fields = form.buildFields(
            selectedFieldId: formState.getCurrentFieldId(),
            activeFieldId: formState.getActiveFieldId(),
            formState: formState
        )

        // Create FormBuilder
        let formBuilder = FormBuilder(
            title: Self.sgCreateFormTitle,
            fields: fields,
            selectedFieldId: formState.getCurrentFieldId(),
            validationErrors: form.validate(),
            showValidationErrors: formState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)

        // If a selector field is active, render overlay
        if let currentField = formState.getCurrentField() {
            switch currentField {
            case .selector(let selectorField) where selectorField.isActive:
                await renderSelectorOverlay(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    field: selectorField,
                    selectorState: formState.selectorStates[selectorField.id] ?? FormSelectorFieldState(items: selectorField.items)
                )
            default:
                break
            }
        }
    }

    // MARK: - Overlay Rendering

    @MainActor
    private static func renderSelectorOverlay(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        field: FormFieldSelector,
        selectorState: FormSelectorFieldState
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        // Use FormSelectorRenderer for standard selector rendering
        if let selectorComponent = FormSelectorRenderer.renderSelector(
            label: field.label,
            items: field.items,
            selectedItemId: field.selectedItemId,
            highlightedIndex: selectorState.highlightedIndex,
            scrollOffset: selectorState.scrollOffset,
            searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
            columns: field.columns,
            maxHeight: Int(height)
        ) {
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            surface.clear(rect: bounds)
            await SwiftTUI.render(selectorComponent, on: surface, in: bounds)
        }
    }

    // MARK: - Management View

    @MainActor
    static func drawServerGroupManagement(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                        width: Int32, height: Int32, form: ServerGroupManagementForm) async {

        // Clear the area behind the window to prevent artifacts
        await BaseViewComponents.clearArea(screen: screen, startRow: startRow - 1, startCol: startCol,
                                     width: width, height: height)

        guard let serverGroup = form.selectedServerGroup else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: startCol + uiPadding, y: startRow + uiPadding, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftTUI.render(Text("No server group selected").error(), on: surface, in: errorBounds)
            return
        }

        // Enhanced title with border
        await BaseViewComponents.drawEnhancedTitle(screen: screen, startRow: startRow, startCol: startCol,
                                            width: width, title: "Manage Server Group: \(serverGroup.name ?? unknownText)")

        let surface = SwiftTUI.surface(from: screen)
        var currentRow = startRow + 2

        let policyStyle = policyStyleForManagement(serverGroup.primaryPolicy)

        let policyName = serverGroup.primaryPolicy?.displayName ?? unknownText
        let infoRow = HStack(spacing: 0, children: [
            Text("Policy: ").secondary(),
            Text(policyName).styled(policyStyle),
            Text(" | Members: ").secondary(),
            Text("\(serverGroup.members.count)").primary()
        ])

        let infoBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
        await SwiftTUI.render(infoRow, on: surface, in: infoBounds)
        currentRow += 1

        // Instructions using SwiftTUI
        let instructions = [
            "Note: OpenStack Nova does not support modifying membership of existing servers.",
            "Server group membership can only be set during server creation."
        ]

        for (index, instruction) in instructions.enumerated() {
            let instructionBounds = Rect(x: startCol + uiPadding, y: currentRow + Int32(index), width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftTUI.render(Text(instruction).info(), on: surface, in: instructionBounds)
        }
        currentRow += instructionSpacing

        // Show pending changes if any using SwiftTUI
        if let pendingInfo = form.getPendingChangesInfo() {
            let pendingBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftTUI.render(Text(pendingInfo).warning(), on: surface, in: pendingBounds)
            currentRow += 1
        }

        // Server list using SwiftTUI
        let allServers = form.getAllServers()
        if allServers.isEmpty {
            let noServersBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftTUI.render(Text(noServersAvailableText).info(), on: surface, in: noServersBounds)
        } else {
            // Headers using SwiftTUI
            let headerBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftTUI.render(Text(serverManagementHeader).muted(), on: surface, in: headerBounds)
            currentRow += 1

            let separatorBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftTUI.render(Text(String(repeating: "-", count: Int(width - boundsWidthOffset))).border(), on: surface, in: separatorBounds)
            currentRow += 1

            // Server list
            let visibleHeight = Int(height) - Int(currentRow - startRow) - visibleHeightOffset
            let startIndex = max(0, form.selectedResourceIndex - visibleHeight / scrollCenterDivisor)
            let endIndex = min(allServers.count, startIndex + visibleHeight)

            // Convert server list to SwiftTUI components
            var serverListComponents: [any Component] = []

            for (_, serverIndex) in (startIndex..<endIndex).enumerated() {
                let server = allServers[serverIndex]
                let isHighlighted = serverIndex == form.selectedResourceIndex
                let serverStatus = form.getServerStatus(server.id)

                // Checkbox style
                let checkboxStyle: TextStyle = {
                    switch serverStatus {
                    case .inGroup: return .success     // Green for in group
                    case .notInGroup: return .secondary // Default for not in group
                    }
                }()

                // Highlight indicator
                let highlightText = isHighlighted ? ">" : " "
                let highlightStyle: TextStyle = isHighlighted ? .primary : .secondary

                // Status style
                let status = server.status?.rawValue ?? unknownText
                let statusStyle = statusStyleForServer(status)

                // Text style for main content
                let textStyle: TextStyle = isHighlighted ? .primary : .secondary

                // Name (26 chars)
                let serverName = server.name ?? unnamedServerText
                let nameDisplay = String(serverName.prefix(serverNameWidth)).padding(toLength: serverNameWidth, withPad: " ", startingAt: 0)

                // Status (11 chars)
                let statusDisplay = String(status.prefix(statusDisplayWidth - 1)).padding(toLength: statusDisplayWidth, withPad: " ", startingAt: 0)

                // IP Address (15 chars)
                let ip = getServerIP(server) ?? noneIPText
                let ipDisplay = String(ip.prefix(ipDisplayWidth)).padding(toLength: ipDisplayWidth, withPad: " ", startingAt: 0)

                // Create server row with SwiftTUI
                let serverRow = HStack(spacing: 0, children: [
                    Text(serverStatus.checkboxDisplay).styled(checkboxStyle),
                    Text(highlightText).styled(highlightStyle),
                    StatusIcon(status: server.status?.rawValue),
                    Text(" \(nameDisplay)").styled(textStyle),
                    Text("\(statusDisplay)").styled(statusStyle),
                    Text("\(ipDisplay)").styled(textStyle),
                    Text(" \(serverStatus.description)").styled(checkboxStyle)
                ])

                serverListComponents.append(serverRow)
            }

            // Render all server rows
            let serverListSection = VStack(spacing: 0, children: serverListComponents)
            let serverListBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: Int32(serverListComponents.count))
            await SwiftTUI.render(serverListSection, on: surface, in: serverListBounds)
        }

        // Show error message if any using SwiftTUI
        if let errorMessage = form.errorMessage {
            let errorRow = startRow + height - errorFooterOffset
            let truncatedError = String(errorMessage.prefix(Int(width - boundsWidthOffset)))
            let errorBounds = Rect(x: startCol + uiPadding, y: errorRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftTUI.render(Text("Error: \(truncatedError)").error(), on: surface, in: errorBounds)
        }

        // Navigation help using SwiftTUI
        let helpRow = startRow + height - helpFooterOffset
        let helpText = form.getNavigationHelp()
        let truncatedHelp = String(helpText.prefix(Int(width - boundsWidthOffset)))
        let helpBounds = Rect(x: startCol + uiPadding, y: helpRow, width: width - boundsWidthOffset, height: boundsHeight)
        await SwiftTUI.render(Text(truncatedHelp).info(), on: surface, in: helpBounds)
    }

    // MARK: - Helper Functions

    private static func formatMemberCount(_ count: Int) -> String {
        let suffix = count == 1 ? serverSingular : serverPlural
        return "\(count)\(suffix)"
    }

    private static func statusStyleForServer(_ status: String?) -> TextStyle {
        guard let status = status else { return .secondary }
        let lowercasedStatus = status.lowercased()

        if lowercasedStatus == "active" { return .success }
        if lowercasedStatus.contains("error") { return .error }
        return .info
    }

    private static func statusStyleForMember(_ status: String?) -> TextStyle {
        guard let status = status else { return .secondary }
        let lowercasedStatus = status.lowercased()

        switch lowercasedStatus {
        case "active": return .success
        case let s where s.contains("error"): return .error
        default: return .info
        }
    }

    private static func policyStyleForList(_ policy: ServerGroupPolicy?) -> TextStyle {
        switch policy {
        case .antiAffinity: return .warning    // Red for anti-affinity
        case .affinity: return .success        // Green for affinity
        case .softAntiAffinity: return .success // Yellow for soft anti-affinity
        case .softAffinity: return .info       // Blue for soft affinity
        case .none: return .secondary          // Default for unknown
        }
    }

    private static func policyStyleForDetail(_ policy: ServerGroupPolicy?) -> TextStyle {
        switch policy {
        case .antiAffinity: return .error     // Red
        case .affinity: return .success       // Green
        case .softAntiAffinity: return .warning // Yellow
        case .softAffinity: return .accent     // Blue
        case .none: return .secondary         // Default
        }
    }

    private static func policyStyleForManagement(_ policy: ServerGroupPolicy?) -> TextStyle {
        switch policy {
        case .antiAffinity: return .accent
        case .affinity: return .success
        case .softAntiAffinity: return .info
        case .softAffinity: return .warning
        case .none: return .secondary
        }
    }

    private static func getServerIP(_ server: Server) -> String? {
        guard let addresses = server.addresses else { return nil }
        for (_, addressList) in addresses.sorted(by: { $0.key < $1.key }) {
            for address in addressList.sorted(by: { $0.addr < $1.addr }) {
                if address.version == 4 {
                    return address.addr
                }
            }
        }
        return nil
    }
}