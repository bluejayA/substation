import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

struct FloatingIPViews {

    // MARK: - Performance Optimizations

    // Cached padded constant strings (calculated once at startup)
    private static let paddedUnassignedText: String = {
        var text = floatingIPListUnassignedText
        while text.count < floatingIPListInstancePadLength {
            text.append(" ")
        }
        return text
    }()

    private static let paddedActiveStatus: String = {
        var text = floatingIPListActiveStatus
        while text.count < floatingIPListStatusPadLength {
            text.append(" ")
        }
        return text
    }()

    private static let paddedAvailableStatus: String = {
        var text = floatingIPListAvailableStatus
        while text.count < floatingIPListStatusPadLength {
            text.append(" ")
        }
        return text
    }()

    // Fast string padding helper (avoids String.padding which allocates)
    private static func padString(_ value: String, to length: Int) -> String {
        if value.count >= length {
            return String(value.prefix(length))
        }
        var result = value
        result.reserveCapacity(length)
        result.append(String(repeating: " ", count: length - value.count))
        return result
    }

    // Optimized status info getter
    private static func getStatusInfo(isActive: Bool) -> (text: String, style: TextStyle, icon: String) {
        if isActive {
            return (paddedActiveStatus, .success, floatingIPListStatusIconActive)
        }
        return (paddedAvailableStatus, .info, floatingIPListStatusIconAvailable)
    }

    // MARK: - Phase 1: Component Warm-up for cold start elimination

    @MainActor private static var isWarmedUp = false

    /// Warm-up mechanism to eliminate cold start penalty
    /// Pre-allocates common string sizes and triggers lazy static initialization
    @MainActor static func warmUp() {
        guard !isWarmedUp else { return }

        // Trigger lazy static initialization by accessing cached constants
        _ = paddedUnassignedText
        _ = paddedActiveStatus
        _ = paddedAvailableStatus

        // Pre-allocate common string sizes to avoid allocations during rendering
        var warmupBuffer = ""
        warmupBuffer.reserveCapacity(floatingIPListIpAddressPadLength)
        warmupBuffer = padString("warmup", to: floatingIPListIpAddressPadLength)
        warmupBuffer.reserveCapacity(floatingIPListInstancePadLength)
        warmupBuffer = padString("warmup", to: floatingIPListInstancePadLength)
        warmupBuffer.reserveCapacity(floatingIPListStatusPadLength)
        warmupBuffer = padString("warmup", to: floatingIPListStatusPadLength)

        // Trigger getStatusInfo to initialize conditional paths
        _ = getStatusInfo(isActive: true)
        _ = getStatusInfo(isActive: false)

        // Mark as warmed up to prevent re-warming
        isWarmedUp = true
        Logger.shared.logInfo("FloatingIPViews - Component warm-up completed")
    }

    // MARK: - Floating IP List View

    @MainActor
    static func drawDetailedFloatingIPList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                         width: Int32, height: Int32, cachedFloatingIPs: [FloatingIP],
                                         searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                          cachedServers: [Server],
                                         cachedPorts: [Port], cachedNetworks: [Network]) async {

        let statusListView = createFloatingIPStatusListView(
            cachedServers: cachedServers,
            cachedPorts: cachedPorts,
            cachedNetworks: cachedNetworks
        )
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedFloatingIPs,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Legacy Component Creation Functions (kept for reference)

    private static func createFloatingIPListItemComponent(
        floatingIP: FloatingIP,
        isSelected: Bool,
        portLookup: [String: Port],
        serverLookup: [String: Server],
        networkDisplayText: String,
        width: Int32
    ) -> any Component {

        // IP Address - optimized padding
        let ipAddress = padString(floatingIP.floatingIpAddress ?? "Unknown", to: Self.floatingIPListIpAddressPadLength)

        // Status - use pre-calculated padded strings
        let isActive = floatingIP.portId != nil
        let (statusText, statusStyle, statusIconValue) = getStatusInfo(isActive: isActive)

        // Instance name - optimized logic
        let instanceName: String
        if let portID = floatingIP.portId {
            if let port = portLookup[portID],
               let deviceID = port.deviceId,
               let server = serverLookup[deviceID] {
                // Server found - use server name
                instanceName = padString(server.name ?? Self.floatingIPListUnnamedServerText, to: Self.floatingIPListInstancePadLength)
            } else {
                // Port but no server - show port ID
                let portText = Self.floatingIPListPortPrefix + String(portID.prefix(Self.floatingIPListPortPrefixLength))
                instanceName = padString(portText, to: Self.floatingIPListInstancePadLength)
            }
        } else {
            // No port - use cached padded unassigned text
            instanceName = paddedUnassignedText
        }

        // Network - already pre-calculated, just use it
        let networkDisplay = networkDisplayText

        // Pre-calculate spaced text (single character concatenation is fast)
        let spacedIpAddress = Self.floatingIPListItemTextSpacing + ipAddress
        let spacedStatusText = Self.floatingIPListItemTextSpacing + statusText
        let spacedInstanceName = Self.floatingIPListItemTextSpacing + instanceName
        let spacedNetworkDisplay = Self.floatingIPListItemTextSpacing + networkDisplay

        let rowStyle: TextStyle = isSelected ? .accent : .secondary

        return HStack(spacing: Self.floatingIPListItemHStackSpacing, children: [
            StatusIcon(status: statusIconValue),
            Text(spacedIpAddress).styled(rowStyle),
            Text(spacedStatusText).styled(statusStyle),
            Text(spacedInstanceName).styled(rowStyle),
            Text(spacedNetworkDisplay).styled(rowStyle)
        ]).padding(Self.floatingIPListItemEdgeInsets)
    }

    // MARK: - Floating IP List View Constants
    // Layout Constants
    private static let floatingIPListMinScreenWidth: Int32 = 10
    private static let floatingIPListMinScreenHeight: Int32 = 10
    private static let floatingIPListBoundsMinWidth: Int32 = 1
    private static let floatingIPListBoundsMinHeight: Int32 = 1
    private static let floatingIPListHeaderTopPadding: Int32 = 2
    private static let floatingIPListHeaderLeadingPadding: Int32 = 0
    private static let floatingIPListHeaderBottomPadding: Int32 = 0
    private static let floatingIPListHeaderTrailingPadding: Int32 = 0
    private static let floatingIPListNoFloatingIPsTopPadding: Int32 = 2
    private static let floatingIPListNoFloatingIPsLeadingPadding: Int32 = 2
    private static let floatingIPListNoFloatingIPsBottomPadding: Int32 = 0
    private static let floatingIPListNoFloatingIPsTrailingPadding: Int32 = 0
    private static let floatingIPListScrollInfoTopPadding: Int32 = 1
    private static let floatingIPListScrollInfoLeadingPadding: Int32 = 0
    private static let floatingIPListScrollInfoBottomPadding: Int32 = 0
    private static let floatingIPListScrollInfoTrailingPadding: Int32 = 0
    private static let floatingIPListReservedSpaceForHeaderFooter = 10
    private static let floatingIPListComponentSpacing: Int32 = 0
    private static let floatingIPListMinVisibleItems = 1
    private static let floatingIPListNetworkInfoWidth = 60
    private static let floatingIPListItemTopPadding: Int32 = 0
    private static let floatingIPListItemLeadingPadding: Int32 = 2
    private static let floatingIPListItemBottomPadding: Int32 = 0
    private static let floatingIPListItemTrailingPadding: Int32 = 0

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let floatingIPListHeaderEdgeInsets = EdgeInsets(top: floatingIPListHeaderTopPadding, leading: floatingIPListHeaderLeadingPadding, bottom: floatingIPListHeaderBottomPadding, trailing: floatingIPListHeaderTrailingPadding)
    private static let floatingIPListNoFloatingIPsEdgeInsets = EdgeInsets(top: floatingIPListNoFloatingIPsTopPadding, leading: floatingIPListNoFloatingIPsLeadingPadding, bottom: floatingIPListNoFloatingIPsBottomPadding, trailing: floatingIPListNoFloatingIPsTrailingPadding)
    private static let floatingIPListScrollInfoEdgeInsets = EdgeInsets(top: floatingIPListScrollInfoTopPadding, leading: floatingIPListScrollInfoLeadingPadding, bottom: floatingIPListScrollInfoBottomPadding, trailing: floatingIPListScrollInfoTrailingPadding)
    private static let floatingIPListItemEdgeInsets = EdgeInsets(top: floatingIPListItemTopPadding, leading: floatingIPListItemLeadingPadding, bottom: floatingIPListItemBottomPadding, trailing: floatingIPListItemTrailingPadding)

    // Text Constants
    private static let floatingIPListTitle = "Floating IPs"
    private static let floatingIPListFilteredTitlePrefix = "Floating IPs (filtered: "
    private static let floatingIPListFilteredTitleSuffix = ")"
    private static let floatingIPListHeader = "  ST  IP ADDRESS                STATUS      INSTANCE                NETWORK"
    private static let floatingIPListSeparator = String(repeating: "-", count: Self.floatingIPListSeparatorLength)
    private static let floatingIPListNoFloatingIPsText = "No floating IPs found"
    private static let floatingIPListScrollInfoPrefix = "["
    private static let floatingIPListScrollInfoSeparator = "-"
    private static let floatingIPListScrollInfoMiddle = "/"
    private static let floatingIPListScrollInfoSuffix = "]"
    private static let floatingIPListUnnamedServerText = "Unnamed"
    private static let floatingIPListPortPrefix = "Port: "
    private static let floatingIPListUnassignedText = "<unassigned>"
    private static let floatingIPListActiveStatus = "ACTIVE"
    private static let floatingIPListAvailableStatus = "AVAILABLE"
    private static let floatingIPListStatusIconActive = "active"
    private static let floatingIPListStatusIconAvailable = "available"
    private static let floatingIPListExternalNetworkText = "External Network"
    private static let floatingIPListScreenTooSmallText = "Screen too small"
    private static let floatingIPListIpAddressPadLength = 25
    private static let floatingIPListStatusPadLength = 11
    private static let floatingIPListInstancePadLength = 23
    private static let floatingIPListPortPrefixLength = 17
    private static let floatingIPListPadCharacter = " "
    private static let floatingIPListSeparatorLength = 75
    private static let floatingIPListItemTextSpacing = " "
    private static let floatingIPListMinNetworkDisplayWidth = 5
    private static let floatingIPListMinNetworkWidth = 0
    private static let floatingIPListPaddingStartIndex = 0
    private static let floatingIPListItemHStackSpacing: Int32 = 0
    private static let floatingIPListExternalNetworkFilter = true
    private static let floatingIPListEmptyNetworkDisplay = ""

    // MARK: - Floating IP Detail View

    // Detail View Constants
    private static let floatingIPDetailMinScreenWidth: Int32 = 10
    private static let floatingIPDetailMinScreenHeight: Int32 = 10
    private static let floatingIPDetailBoundsMinWidth: Int32 = 1
    private static let floatingIPDetailBoundsMinHeight: Int32 = 1
    private static let floatingIPDetailScreenTooSmallText = "Screen too small"
    private static let floatingIPDetailTitle = "Floating IP Details"
    private static let floatingIPDetailTitleTopPadding: Int32 = 0
    private static let floatingIPDetailTitleLeadingPadding: Int32 = 0
    private static let floatingIPDetailTitleBottomPadding: Int32 = 2
    private static let floatingIPDetailTitleTrailingPadding: Int32 = 0
    private static let floatingIPDetailTitleSeparator = ": "
    private static let floatingIPDetailBasicInfoTitle = "Basic Information"
    private static let floatingIPDetailAttachmentInfoTitle = "Attachment Information"
    private static let floatingIPDetailNetworkInfoTitle = "Network Information"
    private static let floatingIPDetailIdLabel = "ID"
    private static let floatingIPDetailAddressLabel = "IP Address"
    private static let floatingIPDetailStatusLabel = "Status"
    private static let floatingIPDetailProjectIdLabel = "Project ID"
    private static let floatingIPDetailNetworkIdLabel = "Network ID"
    private static let floatingIPDetailPortIdLabel = "Port ID"
    private static let floatingIPDetailFixedIpLabel = "Fixed IP"
    private static let floatingIPDetailServerLabel = "Server"
    private static let floatingIPDetailExternalNetworkLabel = "External Network"
    private static let floatingIPDetailFieldValueSeparator = ": "
    private static let floatingIPDetailInfoFieldIndent = "  "
    private static let floatingIPDetailHelpText = "Press ESC to return to floating IP list"
    private static let floatingIPDetailActiveStatus = "ACTIVE"
    private static let floatingIPDetailAvailableStatus = "AVAILABLE"
    private static let floatingIPDetailUnnamedServerText = "Unnamed"
    private static let floatingIPDetailServerIdSeparator = " ("
    private static let floatingIPDetailServerIdSuffix = ")"
    private static let floatingIPDetailSectionTopPadding: Int32 = 0
    private static let floatingIPDetailSectionLeadingPadding: Int32 = 4
    private static let floatingIPDetailSectionBottomPadding: Int32 = 1
    private static let floatingIPDetailSectionTrailingPadding: Int32 = 0

    @MainActor
    static func drawFloatingIPDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                   width: Int32, height: Int32, floatingIP: FloatingIP,
                                   cachedServers: [Server], cachedPorts: [Port],
                                   cachedNetworks: [Network]) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.floatingIPDetailMinScreenWidth && height > Self.floatingIPDetailMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.floatingIPDetailBoundsMinWidth, width), height: max(Self.floatingIPDetailBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.floatingIPDetailScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Floating IP Detail
        var components: [any Component] = []

        // Title - optimized string construction
        let titleText = Self.floatingIPDetailTitle + Self.floatingIPDetailTitleSeparator + (floatingIP.floatingIpAddress ?? "Unknown")
        components.append(Text(titleText).accent().bold()
                         .padding(EdgeInsets(top: Self.floatingIPDetailTitleTopPadding, leading: Self.floatingIPDetailTitleLeadingPadding, bottom: Self.floatingIPDetailTitleBottomPadding, trailing: Self.floatingIPDetailTitleTrailingPadding)))

        // Basic Information Section
        components.append(Text(Self.floatingIPDetailBasicInfoTitle).primary().bold())

        var basicInfo: [any Component] = []
        // Pre-calculate common field prefixes for optimal performance
        let fieldSeparator = Self.floatingIPDetailFieldValueSeparator
        let idPrefix = Self.floatingIPDetailIdLabel + fieldSeparator
        let addressPrefix = Self.floatingIPDetailAddressLabel + fieldSeparator

        // Optimized string construction for basic info fields
        let idText = idPrefix + floatingIP.id
        let addressText = addressPrefix + (floatingIP.floatingIpAddress ?? "Unknown")
        basicInfo.append(Text(idText).secondary())
        basicInfo.append(Text(addressText).secondary())

        // Status with appropriate styling
        let status = floatingIP.portId != nil ? Self.floatingIPDetailActiveStatus : Self.floatingIPDetailAvailableStatus
        let statusStyle: TextStyle = floatingIP.portId != nil ? .success : .info
        let statusLabelText = Self.floatingIPDetailStatusLabel + fieldSeparator
        basicInfo.append(HStack(spacing: 0, children: [
            Text(statusLabelText).secondary(),
            Text(status).styled(statusStyle)
        ]))

        // FloatingIP doesn't have a description property - removing this section

        let basicInfoSection = VStack(spacing: 0, children: basicInfo)
            .padding(EdgeInsets(top: Self.floatingIPDetailSectionTopPadding, leading: Self.floatingIPDetailSectionLeadingPadding, bottom: Self.floatingIPDetailSectionBottomPadding, trailing: Self.floatingIPDetailSectionTrailingPadding))
        components.append(basicInfoSection)

        // Attachment Information Section
        if let portID = floatingIP.portId {
            components.append(Text(Self.floatingIPDetailAttachmentInfoTitle).primary().bold())

            var attachmentInfo: [any Component] = []
            // Pre-calculate prefixes for optimal performance
            let portPrefix = Self.floatingIPDetailPortIdLabel + fieldSeparator

            // Optimized string construction for attachment info
            let portText = portPrefix + portID
            attachmentInfo.append(Text(portText).secondary())

            if let port = cachedPorts.first(where: { $0.id == portID }) {
                if let fixedIP = port.fixedIps?.first {
                    let fixedIPPrefix = Self.floatingIPDetailFixedIpLabel + fieldSeparator
                    let fixedIPText = fixedIPPrefix + fixedIP.ipAddress
                    attachmentInfo.append(Text(fixedIPText).secondary())
                }
                if let deviceID = port.deviceId,
                   let server = cachedServers.first(where: { $0.id == deviceID }) {
                    let serverName = server.name ?? Self.floatingIPDetailUnnamedServerText
                    let serverPrefix = Self.floatingIPDetailServerLabel + fieldSeparator
                    let serverText = serverPrefix + serverName + Self.floatingIPDetailServerIdSeparator + deviceID + Self.floatingIPDetailServerIdSuffix
                    attachmentInfo.append(Text(serverText).secondary())
                }
            }

            let attachmentSection = VStack(spacing: 0, children: attachmentInfo)
                .padding(EdgeInsets(top: Self.floatingIPDetailSectionTopPadding, leading: Self.floatingIPDetailSectionLeadingPadding, bottom: Self.floatingIPDetailSectionBottomPadding, trailing: Self.floatingIPDetailSectionTrailingPadding))
            components.append(attachmentSection)
        }

        // Network Information Section
        if let externalNetwork = cachedNetworks.first(where: { $0.external == true }) {
            components.append(Text(Self.floatingIPDetailNetworkInfoTitle).primary().bold())

            var networkInfo: [any Component] = []
            // Pre-calculate prefixes for optimal performance
            let externalNetworkPrefix = Self.floatingIPDetailExternalNetworkLabel + fieldSeparator
            let networkIdPrefix = Self.floatingIPDetailNetworkIdLabel + fieldSeparator

            // Optimized string construction for network info
            let externalNetworkText = externalNetworkPrefix + (externalNetwork.name ?? "Unknown")
            let networkIdText = networkIdPrefix + externalNetwork.id
            networkInfo.append(Text(externalNetworkText).secondary())
            networkInfo.append(Text(networkIdText).secondary())

            let networkSection = VStack(spacing: 0, children: networkInfo)
                .padding(EdgeInsets(top: Self.floatingIPDetailSectionTopPadding, leading: Self.floatingIPDetailSectionLeadingPadding, bottom: Self.floatingIPDetailSectionBottomPadding, trailing: Self.floatingIPDetailSectionTrailingPadding))
            components.append(networkSection)
        }

        // Help text
        components.append(Text(Self.floatingIPDetailHelpText).info())

        // Render unified floating IP detail
        let floatingIPDetailComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(floatingIPDetailComponent, on: surface, in: bounds)
    }

    // MARK: - Floating IP Create View

    // Layout Constants
    private static let floatingIPCreateMinScreenWidth: Int32 = 10
    private static let floatingIPCreateMinScreenHeight: Int32 = 10
    private static let floatingIPCreateBoundsMinWidth: Int32 = 1
    private static let floatingIPCreateBoundsMinHeight: Int32 = 1
    private static let floatingIPCreateComponentTopPadding: Int32 = 1
    private static let floatingIPCreateStatusMessageTopPadding: Int32 = 2
    private static let floatingIPCreateStatusMessageLeadingPadding: Int32 = 2
    private static let floatingIPCreateValidationErrorLeadingPadding: Int32 = 2
    private static let floatingIPCreateLoadingErrorBoundsHeight: Int32 = 6
    private static let floatingIPCreateFieldActiveSpacing = "                      "

    // Text Constants
    private static let floatingIPCreateFormTitle = "Create New Floating IP"
    private static let floatingIPCreateCreatingFloatingIPText = "Creating floating IP..."
    private static let floatingIPCreateErrorPrefix = "Error: "
    private static let floatingIPCreateRequiredFieldSuffix = ": *"
    private static let floatingIPCreateSelectExternalNetworkTitle = "Select External Network"
    private static let floatingIPCreateSelectSubnetTitle = "Select Subnet"
    private static let floatingIPCreateOptionalFieldSuffix = " (optional)"
    private static let floatingIPCreateScreenTooSmallText = "Screen too small"

    // Field Display Constants
    private static let floatingIPCreateValidationErrorsTitle = "Validation Errors:"
    private static let floatingIPCreateValidationErrorPrefix = "- "
    private static let floatingIPCreateCheckboxSelectedText = "[X]"
    private static let floatingIPCreateCheckboxUnselectedText = "[ ]"
    private static let floatingIPCreateEditPromptText = "Press SPACE to edit..."
    private static let floatingIPCreateSelectPromptText = "Press SPACE to select"
    private static let floatingIPCreateTogglePromptText = "Press SPACE to toggle"

    // Field Label Constants
    private static let floatingIPCreateDescriptionFieldLabel = "Description"
    private static let floatingIPCreateNetworkFieldLabel = "External Network"
    private static let floatingIPCreateSubnetFieldLabel = "Subnet"
    private static let floatingIPCreateQoSPolicyFieldLabel = "QoS Policy"

    // Placeholder Constants
    private static let floatingIPCreateDescriptionPlaceholder = "[Enter description]"
    private static let floatingIPCreateNetworkPlaceholder = "[Select external network]"
    private static let floatingIPCreateSubnetPlaceholder = "[Select subnet]"
    private static let floatingIPCreateNoNetworksText = "[No external networks available]"
    private static let floatingIPCreateNoSubnetsText = "[No subnets available]"
    private static let floatingIPCreateNoQoSPoliciesText = "[No QoS policies available]"
    private static let floatingIPCreateNoQoSPolicySelectedText = "No QoS policy selected"
    private static let floatingIPCreateUnknownSubnetText = "Unknown"
    private static let floatingIPCreateUnnamedSubnetText = "Unnamed Subnet"

    // Server Selection Constants - Implementation now complete with gold standard pattern

    // UI Component Constants
    private static let floatingIPCreateSelectedIndicator = "> "
    private static let floatingIPCreateUnselectedIndicator = "  "
    private static let floatingIPCreateComponentSpacing: Int32 = 0
    private static let floatingIPCreateChoiceIndicatorPrefix = " ("
    private static let floatingIPCreateChoiceIndicatorSeparator = "/"
    private static let floatingIPCreateChoiceIndicatorSuffix = ")"
    private static let floatingIPCreateFieldTruncationBuffer = 10

    // MARK: - Helper Functions

    private static func getAvailablePorts(cachedPorts: [Port], form: FloatingIPCreateForm) -> [Port] {
        // For now, return all ports - could be filtered based on form requirements
        return cachedPorts
    }

    private static func formatPortDisplayText(_ port: Port) -> String {
        if let name = port.name, !name.isEmpty {
            return "\(name) (\(port.id.prefix(8)))"
        } else {
            return "Port \(port.id.prefix(8))"
        }
    }

    @MainActor
    static func drawFloatingIPCreateForm(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                       width: Int32, height: Int32, floatingIPCreateForm: FloatingIPCreateForm,
                                       floatingIPCreateFormState: FormBuilderState,
                                       cachedNetworks: [Network], cachedSubnets: [Subnet]) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.floatingIPCreateMinScreenWidth && height > Self.floatingIPCreateMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.floatingIPCreateBoundsMinWidth, width), height: max(Self.floatingIPCreateBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.floatingIPCreateScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Build the form using FormBuilder
        let externalNetworks = cachedNetworks.filter { $0.external == true }
        let formBuilder = FormBuilder(
            title: Self.floatingIPCreateFormTitle,
            fields: floatingIPCreateForm.buildFields(
                externalNetworks: externalNetworks,
                subnets: cachedSubnets,
                selectedFieldId: floatingIPCreateFormState.getCurrentFieldId(),
                activeFieldId: floatingIPCreateFormState.getActiveFieldId(),
                formState: floatingIPCreateFormState
            ),
            selectedFieldId: floatingIPCreateFormState.getCurrentFieldId(),
            validationErrors: floatingIPCreateFormState.validationErrors,
            showValidationErrors: floatingIPCreateFormState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)

        // If a selector field is active, render specialized view as overlay
        if let currentField = floatingIPCreateFormState.getCurrentField() {
            switch currentField {
            case .selector(let selectorField) where selectorField.isActive:
                await renderSelectorOverlay(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    form: floatingIPCreateForm,
                    field: selectorField,
                    selectorState: floatingIPCreateFormState.getSelectorState(selectorField.id) ?? FormSelectorFieldState(items: selectorField.items),
                    externalNetworks: externalNetworks,
                    subnets: cachedSubnets
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
        form: FloatingIPCreateForm,
        field: FormFieldSelector,
        selectorState: FormSelectorFieldState,
        externalNetworks: [Network],
        subnets: [Subnet]
    ) async {
        // Use specialized views for specific fields based on field ID
        switch field.id {
        case FloatingIPCreateFieldId.floatingNetwork.rawValue:
            // Use NetworkSelectionView for external network selection
            let selectedIds: Set<String> = form.selectedExternalNetworkID.map { Set([$0]) } ?? []
            await NetworkSelectionView.drawNetworkSelection(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                networks: externalNetworks,
                selectedNetworkIds: selectedIds,
                highlightedIndex: selectorState.highlightedIndex,
                scrollOffset: selectorState.scrollOffset,
                searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
                title: "Select External Network"
            )

        case FloatingIPCreateFieldId.subnet.rawValue:
            // Use SubnetSelectionView for subnet selection
            let filteredSubnets = getFilteredSubnets(externalNetworks: externalNetworks, allSubnets: subnets, form: form)
            let selectedIds: Set<String> = form.selectedSubnetID.map { Set([$0]) } ?? []
            await SubnetSelectionView.drawSubnetSelection(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                subnets: filteredSubnets,
                selectedSubnetIds: selectedIds,
                highlightedIndex: selectorState.highlightedIndex,
                scrollOffset: selectorState.scrollOffset,
                searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
                title: "Select Subnet"
            )

        default:
            // Fallback to generic FormSelectorRenderer for other fields
            if let selectorComponent = FormSelectorRenderer.renderSelector(
                label: field.label,
                items: field.items,
                selectedItemId: selectorState.selectedItemId,
                highlightedIndex: selectorState.highlightedIndex,
                scrollOffset: selectorState.scrollOffset,
                searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
                columns: field.columns,
                maxHeight: Int(height)
            ) {
                let surface = SwiftTUI.surface(from: screen)
                let overlayBounds = Rect(x: startCol, y: startRow, width: width, height: height)
                surface.clear(rect: overlayBounds)
                await SwiftTUI.render(selectorComponent, on: surface, in: overlayBounds)
            }
        }
    }

    private static func getFilteredSubnets(externalNetworks: [Network], allSubnets: [Subnet], form: FloatingIPCreateForm) -> [Subnet] {
        guard let selectedNetworkID = form.selectedExternalNetworkID,
              let selectedNetwork = externalNetworks.first(where: { $0.id == selectedNetworkID }),
              let networkSubnetIds = selectedNetwork.subnets else {
            return []
        }
        return allSubnets.filter { networkSubnetIds.contains($0.id) }
    }


    @MainActor
    static func drawServerSelectionView(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                       width: Int32, height: Int32, floatingIP: FloatingIP,
                                       cachedServers: [Server], cachedPorts: [Port],
                                       scrollOffset: Int, selectedIndex: Int) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.floatingIPServerSelectionMinScreenWidth && height > Self.floatingIPServerSelectionMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.floatingIPServerSelectionBoundsMinWidth, width), height: max(Self.floatingIPServerSelectionBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.floatingIPServerSelectionScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Server Selection View
        var components: [any Component] = []

        // Title with floating IP context
        let titleText = Self.floatingIPServerSelectionTitlePrefix + (floatingIP.floatingIpAddress ?? "Unknown") + Self.floatingIPServerSelectionTitleSuffix
        components.append(Text(titleText).emphasis().bold())

        // Header
        components.append(Text(Self.floatingIPServerSelectionHeader).muted()
            .padding(Self.floatingIPServerSelectionHeaderEdgeInsets))
        components.append(Text(Self.floatingIPServerSelectionSeparator).border())

        // Pre-calculate port counts for performance (O(n) instead of O(n*m))
        // Build server IDs with available ports (O(m) where m = ports)
        var serverIdsWithPorts = Set<String>()
        var portCounts: [String: Int] = [:]
        for port in cachedPorts {
            if let deviceId = port.deviceId, !(port.fixedIps?.isEmpty ?? true) {
                serverIdsWithPorts.insert(deviceId)
                portCounts[deviceId, default: 0] += 1
            }
        }

        // Filter servers using pre-built set (O(n) where n = servers)
        let availableServers = cachedServers.filter { serverIdsWithPorts.contains($0.id) }

        if availableServers.isEmpty {
            components.append(Text(Self.floatingIPServerSelectionNoServersText).info()
                .padding(Self.floatingIPServerSelectionNoServersEdgeInsets))
        } else {
            // Calculate visible range for optimal viewport performance
            let maxVisibleItems = max(Self.floatingIPServerSelectionMinVisibleItems, Int(height) - Self.floatingIPServerSelectionReservedSpace)
            let startIndex = max(0, min(scrollOffset, availableServers.count - maxVisibleItems))
            let endIndex = min(availableServers.count, startIndex + maxVisibleItems)

            for i in startIndex..<endIndex {
                let server = availableServers[i]
                let isSelected = i == selectedIndex
                let portCount = portCounts[server.id] ?? 0
                let serverComponent = Self.createServerSelectionItemComponent(
                    server: server,
                    isSelected: isSelected,
                    portCount: portCount,
                    width: width
                )
                components.append(serverComponent)
            }

            // Scroll indicator if needed - use string interpolation
            if availableServers.count > maxVisibleItems {
                let scrollText = "[\(startIndex + 1)-\(endIndex)/\(availableServers.count)]"
                components.append(Text(scrollText).info()
                    .padding(Self.floatingIPServerSelectionScrollInfoEdgeInsets))
            }
        }

        // Render unified server selection view
        let serverSelectionComponent = VStack(spacing: Self.floatingIPServerSelectionComponentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(serverSelectionComponent, on: surface, in: bounds)
    }

    // MARK: - Server Selection Component Creation

    private static func createServerSelectionItemComponent(
        server: Server,
        isSelected: Bool,
        portCount: Int,
        width: Int32
    ) -> any Component {
        // Server name - use optimized padding
        let serverName = server.name ?? Self.floatingIPServerSelectionUnnamedServerText
        let truncatedName = padString(serverName, to: Self.floatingIPServerSelectionNamePadLength)

        // Server status - optimized padding
        let serverStatus = server.status?.rawValue ?? Self.floatingIPServerSelectionUnknownStatusText
        let statusText = padString(serverStatus, to: Self.floatingIPServerSelectionStatusPadLength)
        let statusStyle: TextStyle = {
            switch serverStatus.lowercased() {
            case Self.floatingIPServerSelectionActiveStatus: return .success
            case let s where s.contains(Self.floatingIPServerSelectionErrorStatus): return .error
            default: return .accent
            }
        }()

        // Port count - already pre-calculated, just format
        let portCountText = String(portCount) + Self.floatingIPServerSelectionPortCountSuffix
        let portDisplay = padString(portCountText, to: Self.floatingIPServerSelectionPortPadLength)

        // Pre-calculate spaced text for optimal performance
        let spacedName = Self.floatingIPServerSelectionItemTextSpacing + truncatedName
        let spacedStatus = Self.floatingIPServerSelectionItemTextSpacing + statusText
        let spacedPortDisplay = Self.floatingIPServerSelectionItemTextSpacing + portDisplay

        let rowStyle: TextStyle = isSelected ? .accent : .secondary

        return HStack(spacing: Self.floatingIPServerSelectionItemHStackSpacing, children: [
            StatusIcon(status: Self.floatingIPServerSelectionStatusIconActive),
            Text(spacedName).styled(rowStyle),
            Text(spacedStatus).styled(statusStyle),
            Text(spacedPortDisplay).styled(rowStyle)
        ]).padding(Self.floatingIPServerSelectionItemEdgeInsets)
    }

    // MARK: - Server Selection View Constants

    // Layout Constants
    private static let floatingIPServerSelectionMinScreenWidth: Int32 = 10
    private static let floatingIPServerSelectionMinScreenHeight: Int32 = 10
    private static let floatingIPServerSelectionBoundsMinWidth: Int32 = 1
    private static let floatingIPServerSelectionBoundsMinHeight: Int32 = 1
    private static let floatingIPServerSelectionHeaderTopPadding: Int32 = 2
    private static let floatingIPServerSelectionHeaderLeadingPadding: Int32 = 0
    private static let floatingIPServerSelectionHeaderBottomPadding: Int32 = 0
    private static let floatingIPServerSelectionHeaderTrailingPadding: Int32 = 0
    private static let floatingIPServerSelectionNoServersTopPadding: Int32 = 2
    private static let floatingIPServerSelectionNoServersLeadingPadding: Int32 = 2
    private static let floatingIPServerSelectionNoServersBottomPadding: Int32 = 0
    private static let floatingIPServerSelectionNoServersTrailingPadding: Int32 = 0
    private static let floatingIPServerSelectionScrollInfoTopPadding: Int32 = 1
    private static let floatingIPServerSelectionScrollInfoLeadingPadding: Int32 = 0
    private static let floatingIPServerSelectionScrollInfoBottomPadding: Int32 = 0
    private static let floatingIPServerSelectionScrollInfoTrailingPadding: Int32 = 0
    private static let floatingIPServerSelectionItemTopPadding: Int32 = 0
    private static let floatingIPServerSelectionItemLeadingPadding: Int32 = 2
    private static let floatingIPServerSelectionItemBottomPadding: Int32 = 0
    private static let floatingIPServerSelectionItemTrailingPadding: Int32 = 0
    private static let floatingIPServerSelectionReservedSpace = 10
    private static let floatingIPServerSelectionMinVisibleItems = 1
    private static let floatingIPServerSelectionComponentSpacing: Int32 = 0
    private static let floatingIPServerSelectionItemHStackSpacing: Int32 = 0
    private static let floatingIPServerSelectionPaddingStartIndex = 0

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let floatingIPServerSelectionHeaderEdgeInsets = EdgeInsets(top: floatingIPServerSelectionHeaderTopPadding, leading: floatingIPServerSelectionHeaderLeadingPadding, bottom: floatingIPServerSelectionHeaderBottomPadding, trailing: floatingIPServerSelectionHeaderTrailingPadding)
    private static let floatingIPServerSelectionNoServersEdgeInsets = EdgeInsets(top: floatingIPServerSelectionNoServersTopPadding, leading: floatingIPServerSelectionNoServersLeadingPadding, bottom: floatingIPServerSelectionNoServersBottomPadding, trailing: floatingIPServerSelectionNoServersTrailingPadding)
    private static let floatingIPServerSelectionScrollInfoEdgeInsets = EdgeInsets(top: floatingIPServerSelectionScrollInfoTopPadding, leading: floatingIPServerSelectionScrollInfoLeadingPadding, bottom: floatingIPServerSelectionScrollInfoBottomPadding, trailing: floatingIPServerSelectionScrollInfoTrailingPadding)
    private static let floatingIPServerSelectionItemEdgeInsets = EdgeInsets(top: floatingIPServerSelectionItemTopPadding, leading: floatingIPServerSelectionItemLeadingPadding, bottom: floatingIPServerSelectionItemBottomPadding, trailing: floatingIPServerSelectionItemTrailingPadding)

    // Text Constants
    private static let floatingIPServerSelectionTitlePrefix = "Select Server for Floating IP: "
    private static let floatingIPServerSelectionTitleSuffix = ""
    private static let floatingIPServerSelectionHeader = "  ST  NAME                         STATUS               PORTS"
    private static let floatingIPServerSelectionSeparator = String(repeating: "-", count: 70)
    private static let floatingIPServerSelectionScreenTooSmallText = "Screen too small"
    private static let floatingIPServerSelectionNoServersText = "No servers with available ports found"
    private static let floatingIPServerSelectionScrollIndicatorPrefix = "["
    private static let floatingIPServerSelectionScrollIndicatorSeparator = "-"
    private static let floatingIPServerSelectionScrollIndicatorMiddle = "/"
    private static let floatingIPServerSelectionScrollIndicatorSuffix = "]"

    // Formatting Constants
    private static let floatingIPServerSelectionNamePadLength = 28
    private static let floatingIPServerSelectionStatusPadLength = 20
    private static let floatingIPServerSelectionPortPadLength = 10
    private static let floatingIPServerSelectionPadCharacter = " "
    private static let floatingIPServerSelectionItemTextSpacing = " "
    private static let floatingIPServerSelectionPortCountSuffix = " ports"

    // Status Constants
    private static let floatingIPServerSelectionActiveStatus = "active"
    private static let floatingIPServerSelectionErrorStatus = "error"
    private static let floatingIPServerSelectionStatusIconActive = "active"
    private static let floatingIPServerSelectionUnnamedServerText = "Unnamed Server"
    private static let floatingIPServerSelectionUnknownStatusText = "Unknown"
}