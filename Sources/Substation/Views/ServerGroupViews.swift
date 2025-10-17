import Foundation
import OSClient
import SwiftNCurses

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
                                           searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                           multiSelectMode: Bool = false, selectedItems: Set<String> = []) async {

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
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Server Group Detail View

    @MainActor
    static func drawServerGroupDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                    width: Int32, height: Int32, serverGroup: ServerGroup,
                                    cachedServers: [Server], scrollOffset: Int = 0) async {

        var sections: [DetailSection] = []

        // Basic Information Section
        var basicItems: [DetailItem] = []
        basicItems.append(.field(label: "ID", value: serverGroup.id, style: .secondary))
        basicItems.append(.field(label: "Name", value: serverGroup.name ?? "Unknown", style: .secondary))

        // Policy with custom component for styling
        let policyStyle = policyStyleForDetail(serverGroup.primaryPolicy)
        basicItems.append(.customComponent(
            HStack(spacing: 0, children: [
                Text("  Policy: ").secondary(),
                Text(serverGroup.primaryPolicy?.displayName ?? "Unknown").styled(policyStyle)
            ])
        ))

        // Policy Description
        if let policy = serverGroup.primaryPolicy {
            basicItems.append(.field(label: "Description", value: policy.description, style: .info))
        }

        // Project and User IDs
        if let projectId = serverGroup.project_id {
            basicItems.append(.field(label: "Project ID", value: projectId, style: .secondary))
        }

        if let userId = serverGroup.user_id {
            basicItems.append(.field(label: "User ID", value: userId, style: .secondary))
        }

        sections.append(DetailSection(title: "Basic Information", items: basicItems))

        // Policy Details Section - Enhanced!
        if let policy = serverGroup.primaryPolicy {
            var policyItems: [DetailItem] = []
            policyItems.append(.field(label: "Type", value: policy.displayName, style: .secondary))
            policyItems.append(.field(label: "Strategy", value: policy.description, style: .info))

            // Add explanation based on policy type
            let explanation: String
            switch policy {
            case .antiAffinity:
                explanation = "Servers must run on different physical hosts"
            case .affinity:
                explanation = "Servers should run on the same physical host"
            case .softAntiAffinity:
                explanation = "Servers preferably run on different hosts (best effort)"
            case .softAffinity:
                explanation = "Servers preferably run on the same host (best effort)"
            }
            policyItems.append(.field(label: "Behavior", value: explanation, style: .accent))

            sections.append(DetailSection(title: "Policy Details", items: policyItems, titleStyle: .accent))
        }

        // Members Section with enhanced details
        if serverGroup.members.isEmpty {
            let noMembersSection = DetailSection(
                title: "Members (0)",
                items: [.field(label: "Status", value: "No servers in this group", style: .info)]
            )
            sections.append(noMembersSection)
        } else {
            // Get member servers and sort them by name
            let memberServers = cachedServers.filter { serverGroup.members.contains($0.id) }
                                             .sorted { ($0.name ?? "Unnamed Server") < ($1.name ?? "Unnamed Server") }

            var memberItems: [DetailItem] = []

            // Enhanced member information
            for server in memberServers {
                let serverName = server.name ?? "Unnamed Server"

                // Server name with status icon
                memberItems.append(.customComponent(
                    HStack(spacing: 0, children: [
                        Text("  ").secondary(),
                        StatusIcon(status: server.status?.rawValue),
                        Text(" \(serverName)").secondary()
                    ])
                ))

                // Status with styling
                let status = server.status?.rawValue ?? "Unknown"
                let statusStyle = statusStyleForMember(server.status?.rawValue)
                memberItems.append(.customComponent(
                    HStack(spacing: 0, children: [
                        Text("    Status: ").secondary(),
                        Text(status).styled(statusStyle)
                    ])
                ))

                // IP Address
                if let ip = getServerIP(server) {
                    memberItems.append(.field(label: "    IP Address", value: ip, style: .info))
                }

                // Availability Zone
                if let az = server.availabilityZone {
                    memberItems.append(.field(label: "    Availability Zone", value: az, style: .secondary))
                }

                // Hypervisor (useful for verifying policy compliance)
                if let hypervisor = server.hypervisorHostname {
                    memberItems.append(.field(label: "    Hypervisor", value: hypervisor, style: .accent))
                }

                memberItems.append(.spacer)
            }

            // Member count in title
            let memberTitle = "Members (\(memberServers.count))"
            sections.append(DetailSection(title: memberTitle, items: memberItems))

            // Hypervisor Distribution Analysis
            if !memberServers.isEmpty {
                let distributionItems = analyzeHypervisorDistribution(
                    policy: serverGroup.primaryPolicy,
                    memberServers: memberServers
                )
                if !distributionItems.isEmpty {
                    sections.append(DetailSection(
                        title: "Hypervisor Distribution Analysis",
                        items: distributionItems,
                        titleStyle: .accent
                    ))
                }
            }

            // Capacity Analysis
            if !memberServers.isEmpty {
                let capacityItems = getCapacityAnalysis(
                    policy: serverGroup.primaryPolicy,
                    memberServers: memberServers
                )
                if !capacityItems.isEmpty {
                    sections.append(DetailSection(
                        title: "Capacity Analysis",
                        items: capacityItems,
                        titleStyle: .accent
                    ))
                }
            }

            // Policy Use Cases
            if serverGroup.primaryPolicy != nil {
                let useCaseItems = getPolicyUseCases(policy: serverGroup.primaryPolicy)
                if !useCaseItems.isEmpty {
                    sections.append(DetailSection(
                        title: "When to Use This Policy",
                        items: useCaseItems,
                        titleStyle: .accent
                    ))
                }
            }

            // Unresolved Members (if any)
            let unresolvedMembers = serverGroup.members.filter { memberId in
                !memberServers.contains { $0.id == memberId }
            }

            if !unresolvedMembers.isEmpty {
                var unresolvedItems: [DetailItem] = []
                unresolvedItems.append(.field(
                    label: "Note",
                    value: "\(unresolvedMembers.count) member(s) not found in cache",
                    style: .warning
                ))
                for memberId in unresolvedMembers.prefix(5) {
                    unresolvedItems.append(.field(label: "Server ID", value: memberId, style: .secondary))
                }
                if unresolvedMembers.count > 5 {
                    unresolvedItems.append(.field(
                        label: "Additional",
                        value: "\(unresolvedMembers.count - 5) more unresolved",
                        style: .warning
                    ))
                }
                sections.append(DetailSection(title: "Unresolved Members", items: unresolvedItems, titleStyle: .warning))
            }
        }

        // Metadata Section
        if let metadata = serverGroup.metadata, !metadata.isEmpty {
            var metadataItems: [DetailItem] = []
            for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
                metadataItems.append(.field(label: key, value: value, style: .secondary))
            }
            sections.append(DetailSection(title: "Metadata", items: metadataItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Server Group Details: \(serverGroup.name ?? "Unknown")",
            sections: sections,
            helpText: "Press ESC to return to server group list",
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
            let surface = SwiftNCurses.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftNCurses.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftNCurses.surface(from: screen)

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
        await SwiftNCurses.render(formBuilder.render(), on: surface, in: bounds)

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
        let surface = SwiftNCurses.surface(from: screen)

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
            await SwiftNCurses.render(selectorComponent, on: surface, in: bounds)
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
            let surface = SwiftNCurses.surface(from: screen)
            let errorBounds = Rect(x: startCol + uiPadding, y: startRow + uiPadding, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftNCurses.render(Text("No server group selected").error(), on: surface, in: errorBounds)
            return
        }

        // Enhanced title with border
        await BaseViewComponents.drawEnhancedTitle(screen: screen, startRow: startRow, startCol: startCol,
                                            width: width, title: "Manage Server Group: \(serverGroup.name ?? unknownText)")

        let surface = SwiftNCurses.surface(from: screen)
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
        await SwiftNCurses.render(infoRow, on: surface, in: infoBounds)
        currentRow += 1

        // Instructions using SwiftNCurses
        let instructions = [
            "Note: OpenStack Nova does not support modifying membership of existing servers.",
            "Server group membership can only be set during server creation."
        ]

        for (index, instruction) in instructions.enumerated() {
            let instructionBounds = Rect(x: startCol + uiPadding, y: currentRow + Int32(index), width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftNCurses.render(Text(instruction).info(), on: surface, in: instructionBounds)
        }
        currentRow += instructionSpacing

        // Show pending changes if any using SwiftNCurses
        if let pendingInfo = form.getPendingChangesInfo() {
            let pendingBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftNCurses.render(Text(pendingInfo).warning(), on: surface, in: pendingBounds)
            currentRow += 1
        }

        // Server list using SwiftNCurses
        let allServers = form.getAllServers()
        if allServers.isEmpty {
            let noServersBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftNCurses.render(Text(noServersAvailableText).info(), on: surface, in: noServersBounds)
        } else {
            // Headers using SwiftNCurses
            let headerBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftNCurses.render(Text(serverManagementHeader).muted(), on: surface, in: headerBounds)
            currentRow += 1

            let separatorBounds = Rect(x: startCol + uiPadding, y: currentRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftNCurses.render(Text(String(repeating: "-", count: Int(width - boundsWidthOffset))).border(), on: surface, in: separatorBounds)
            currentRow += 1

            // Server list
            let visibleHeight = Int(height) - Int(currentRow - startRow) - visibleHeightOffset
            let startIndex = max(0, form.selectedResourceIndex - visibleHeight / scrollCenterDivisor)
            let endIndex = min(allServers.count, startIndex + visibleHeight)

            // Convert server list to SwiftNCurses components
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

                // Create server row with SwiftNCurses
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
            await SwiftNCurses.render(serverListSection, on: surface, in: serverListBounds)
        }

        // Show error message if any using SwiftNCurses
        if let errorMessage = form.errorMessage {
            let errorRow = startRow + height - errorFooterOffset
            let truncatedError = String(errorMessage.prefix(Int(width - boundsWidthOffset)))
            let errorBounds = Rect(x: startCol + uiPadding, y: errorRow, width: width - boundsWidthOffset, height: boundsHeight)
            await SwiftNCurses.render(Text("Error: \(truncatedError)").error(), on: surface, in: errorBounds)
        }

        // Navigation help using SwiftNCurses
        let helpRow = startRow + height - helpFooterOffset
        let helpText = form.getNavigationHelp()
        let truncatedHelp = String(helpText.prefix(Int(width - boundsWidthOffset)))
        let helpBounds = Rect(x: startCol + uiPadding, y: helpRow, width: width - boundsWidthOffset, height: boundsHeight)
        await SwiftNCurses.render(Text(truncatedHelp).info(), on: surface, in: helpBounds)
    }

    // MARK: - Helper Functions


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

    // MARK: - Intelligence Helper Functions

    private static func analyzeHypervisorDistribution(
        policy: ServerGroupPolicy?,
        memberServers: [Server]
    ) -> [DetailItem] {
        var items: [DetailItem] = []

        let serversWithHypervisor = memberServers.filter { $0.hypervisorHostname != nil }
        let hypervisorNames = Set(serversWithHypervisor.compactMap { $0.hypervisorHostname })

        guard let policy = policy else {
            return items
        }

        switch policy {
        case .antiAffinity, .softAntiAffinity:
            let isCompliant = hypervisorNames.count == serversWithHypervisor.count && serversWithHypervisor.count == memberServers.count

            if isCompliant {
                items.append(.field(
                    label: "Compliance Status",
                    value: "All \(memberServers.count) members on different hosts",
                    style: .success
                ))
            } else if serversWithHypervisor.isEmpty {
                items.append(.field(
                    label: "Compliance Status",
                    value: "Unknown - hypervisor information not available",
                    style: .info
                ))
            } else {
                let complianceStatus = "\(hypervisorNames.count) unique hypervisors for \(serversWithHypervisor.count) servers"
                items.append(.field(
                    label: "Compliance Status",
                    value: complianceStatus,
                    style: policy == .antiAffinity ? .warning : .info
                ))

                if policy == .antiAffinity {
                    items.append(.field(
                        label: "  Warning",
                        value: "Anti-affinity policy may be violated",
                        style: .warning
                    ))
                } else {
                    items.append(.field(
                        label: "  Note",
                        value: "Soft anti-affinity allows same-host placement if needed",
                        style: .info
                    ))
                }
            }

            if !hypervisorNames.isEmpty {
                items.append(.spacer)
                items.append(.field(
                    label: "Hypervisor Distribution",
                    value: "\(hypervisorNames.count) hypervisor(s) in use",
                    style: .info
                ))
                for hypervisor in hypervisorNames.sorted() {
                    let serverCount = serversWithHypervisor.filter { $0.hypervisorHostname == hypervisor }.count
                    items.append(.field(
                        label: "  \(hypervisor)",
                        value: "\(serverCount) server(s)",
                        style: serverCount > 1 ? .warning : .success
                    ))
                }
            }

        case .affinity, .softAffinity:
            let isCompliant = hypervisorNames.count == 1 && serversWithHypervisor.count == memberServers.count

            if isCompliant {
                let hypervisorName = hypervisorNames.first ?? "Unknown"
                items.append(.field(
                    label: "Compliance Status",
                    value: "All \(memberServers.count) members on same host",
                    style: .success
                ))
                items.append(.field(
                    label: "Hypervisor",
                    value: hypervisorName,
                    style: .accent
                ))
            } else if serversWithHypervisor.isEmpty {
                items.append(.field(
                    label: "Compliance Status",
                    value: "Unknown - hypervisor information not available",
                    style: .info
                ))
            } else {
                items.append(.field(
                    label: "Compliance Status",
                    value: "Servers distributed across \(hypervisorNames.count) hypervisors",
                    style: policy == .affinity ? .warning : .info
                ))

                if policy == .affinity {
                    items.append(.field(
                        label: "  Warning",
                        value: "Affinity policy may be violated",
                        style: .warning
                    ))
                } else {
                    items.append(.field(
                        label: "  Note",
                        value: "Soft affinity allows multi-host placement if needed",
                        style: .info
                    ))
                }

                items.append(.spacer)
                items.append(.field(
                    label: "Hypervisor Distribution",
                    value: "\(hypervisorNames.count) hypervisor(s) in use",
                    style: .info
                ))
                for hypervisor in hypervisorNames.sorted() {
                    let serverCount = serversWithHypervisor.filter { $0.hypervisorHostname == hypervisor }.count
                    items.append(.field(
                        label: "  \(hypervisor)",
                        value: "\(serverCount) server(s)",
                        style: .accent
                    ))
                }
            }
        }

        return items
    }

    private static func getCapacityAnalysis(
        policy: ServerGroupPolicy?,
        memberServers: [Server]
    ) -> [DetailItem] {
        var items: [DetailItem] = []

        let serversWithHypervisor = memberServers.filter { $0.hypervisorHostname != nil }
        let uniqueHypervisors = Set(serversWithHypervisor.compactMap { $0.hypervisorHostname })

        guard let policy = policy else {
            return items
        }

        switch policy {
        case .antiAffinity, .softAntiAffinity:
            if !uniqueHypervisors.isEmpty {
                items.append(.field(
                    label: "Unique Hypervisors Used",
                    value: "\(uniqueHypervisors.count) of available in cluster",
                    style: .info
                ))

                if policy == .antiAffinity {
                    items.append(.field(
                        label: "Capacity Note",
                        value: "Maximum group size limited by hypervisor count",
                        style: .info
                    ))
                    items.append(.field(
                        label: "  Warning",
                        value: "Adding more servers requires available hypervisors",
                        style: .warning
                    ))
                }
            }

        case .affinity, .softAffinity:
            if uniqueHypervisors.count == 1 {
                items.append(.field(
                    label: "Capacity Note",
                    value: "All servers on single hypervisor",
                    style: .info
                ))
                items.append(.field(
                    label: "  Consideration",
                    value: "Single host failure would impact all members",
                    style: .warning
                ))
            }
        }

        return items
    }

    private static func getPolicyUseCases(policy: ServerGroupPolicy?) -> [DetailItem] {
        var items: [DetailItem] = []

        guard let policy = policy else {
            return items
        }

        items.append(.field(label: "Use Case", value: "", style: .info))

        switch policy {
        case .antiAffinity:
            items.append(.field(
                label: "  Ideal For",
                value: "High availability applications",
                style: .info
            ))
            items.append(.field(
                label: "",
                value: "Fault tolerance (servers on different physical hardware)",
                style: .info
            ))
            items.append(.field(
                label: "",
                value: "Critical workloads requiring redundancy",
                style: .info
            ))

        case .affinity:
            items.append(.field(
                label: "  Ideal For",
                value: "Performance-sensitive applications",
                style: .info
            ))
            items.append(.field(
                label: "",
                value: "Low-latency inter-server communication",
                style: .info
            ))
            items.append(.field(
                label: "",
                value: "Workloads with high network traffic between servers",
                style: .info
            ))

        case .softAntiAffinity:
            items.append(.field(
                label: "  Ideal For",
                value: "Applications preferring high availability",
                style: .info
            ))
            items.append(.field(
                label: "",
                value: "When strict anti-affinity might fail due to capacity",
                style: .info
            ))
            items.append(.field(
                label: "",
                value: "Balanced approach between HA and flexibility",
                style: .info
            ))

        case .softAffinity:
            items.append(.field(
                label: "  Ideal For",
                value: "Applications preferring performance",
                style: .info
            ))
            items.append(.field(
                label: "",
                value: "When strict affinity might fail due to capacity",
                style: .info
            ))
            items.append(.field(
                label: "",
                value: "Balanced approach between performance and flexibility",
                style: .info
            ))
        }

        return items
    }
}