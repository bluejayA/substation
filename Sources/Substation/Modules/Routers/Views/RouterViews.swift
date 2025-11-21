import Foundation
import OSClient
import SwiftNCurses

struct RouterViews {
    @MainActor
    static func drawDetailedRouterList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                      width: Int32, height: Int32, cachedRouters: [Router],
                                      searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                      multiSelectMode: Bool = false, selectedItems: Set<String> = []) async {

        let statusListView = createRouterStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedRouters,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Router List View Constants
    // Layout Constants
    private static let routerListMinScreenWidth: Int32 = 10
    private static let routerListMinScreenHeight: Int32 = 10
    private static let routerListHeaderTopPadding: Int32 = 2
    private static let routerListHeaderLeadingPadding: Int32 = 0
    private static let routerListHeaderBottomPadding: Int32 = 0
    private static let routerListHeaderTrailingPadding: Int32 = 0
    private static let routerListNoRoutersTopPadding: Int32 = 2
    private static let routerListNoRoutersLeadingPadding: Int32 = 2
    private static let routerListNoRoutersBottomPadding: Int32 = 0
    private static let routerListNoRoutersTrailingPadding: Int32 = 0
    private static let routerListScrollInfoTopPadding: Int32 = 1
    private static let routerListScrollInfoLeadingPadding: Int32 = 0
    private static let routerListScrollInfoBottomPadding: Int32 = 0
    private static let routerListScrollInfoTrailingPadding: Int32 = 0
    private static let routerListReservedSpaceForHeaderFooter = 10
    private static let routerListComponentSpacing: Int32 = 0
    private static let routerListItemLeadingPadding: Int32 = 2
    private static let routerListItemTopPadding: Int32 = 0
    private static let routerListItemBottomPadding: Int32 = 0
    private static let routerListItemTrailingPadding: Int32 = 0
    private static let routerListMinVisibleItems = 1
    private static let routerListBoundsMinWidth: Int32 = 1
    private static let routerListBoundsMinHeight: Int32 = 1

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let routerListHeaderEdgeInsets = EdgeInsets(top: routerListHeaderTopPadding, leading: routerListHeaderLeadingPadding, bottom: routerListHeaderBottomPadding, trailing: routerListHeaderTrailingPadding)
    private static let routerListNoRoutersEdgeInsets = EdgeInsets(top: routerListNoRoutersTopPadding, leading: routerListNoRoutersLeadingPadding, bottom: routerListNoRoutersBottomPadding, trailing: routerListNoRoutersTrailingPadding)
    private static let routerListScrollInfoEdgeInsets = EdgeInsets(top: routerListScrollInfoTopPadding, leading: routerListScrollInfoLeadingPadding, bottom: routerListScrollInfoBottomPadding, trailing: routerListScrollInfoTrailingPadding)
    private static let routerListItemEdgeInsets = EdgeInsets(top: routerListItemTopPadding, leading: routerListItemLeadingPadding, bottom: routerListItemBottomPadding, trailing: routerListItemTrailingPadding)

    // Text Constants
    private static let routerListTitle = "Routers"
    private static let routerListFilteredTitlePrefix = "Routers (filtered: "
    private static let routerListFilteredTitleSuffix = ")"
    private static let routerListHeader = " NAME                             ROUTER ID                      STATUS"
    private static let routerListSeparator = String(repeating: "-", count: Self.routerListSeparatorLength)
    private static let routerListNoRoutersText = "No routers found"
    private static let routerListScrollInfoPrefix = "["
    private static let routerListScrollInfoSeparator = "-"
    private static let routerListScrollInfoMiddle = "/"
    private static let routerListScrollInfoSuffix = "]"
    private static let routerListUnnamedRouterText = "Unnamed"
    private static let routerListActiveStatus = "ACTIVE"
    private static let routerListStatusIconActive = "active"
    private static let routerListScreenTooSmallText = "Screen too small"
    private static let routerListNamePadLength = 28
    private static let routerListIdPadLength = 30
    private static let routerListPadCharacter = " "
    private static let routerListSeparatorLength = 75
    private static let routerListItemTextSpacing = " "

    // MARK: - Router Detail View

    // Detail View Constants
    private static let routerDetailTitle = "Router Details"
    private static let routerDetailBasicInfoTitle = "Basic Information"
    private static let routerDetailExternalGatewayTitle = "External Gateway"
    private static let routerDetailAttachedSubnetsTitle = "Attached Subnets"
    private static let routerDetailRoutesTitle = "Routes"
    private static let routerDetailMetadataTitle = "Metadata"
    private static let routerDetailIdLabel = "ID"
    private static let routerDetailNameLabel = "Name"
    private static let routerDetailDescriptionLabel = "Description"
    private static let routerDetailStatusLabel = "Status"
    private static let routerDetailAdminStateLabel = "Admin State"
    private static let routerDetailDistributedLabel = "Distributed"
    private static let routerDetailHALabel = "High Availability"
    private static let routerDetailTenantIdLabel = "Tenant ID"
    private static let routerDetailProjectIdLabel = "Project ID"
    private static let routerDetailCreatedAtLabel = "Created At"
    private static let routerDetailUpdatedAtLabel = "Updated At"
    private static let routerDetailRevisionLabel = "Revision"
    private static let routerDetailFlavorIdLabel = "Flavor ID"
    private static let routerDetailServiceTypeIdLabel = "Service Type ID"
    private static let routerDetailTagsLabel = "Tags"
    private static let routerDetailNetworkIdLabel = "Network ID"
    private static let routerDetailSNATEnabledLabel = "SNAT Enabled"
    private static let routerDetailExternalFixedIpsLabel = "External Fixed IPs"
    private static let routerDetailPortIdLabel = "Port ID"
    private static let routerDetailIpAddressLabel = "IP Address"
    private static let routerDetailFieldValueSeparator = ": "
    private static let routerDetailUnnamedRouterText = "Unnamed Router"
    private static let routerDetailUpText = "UP"
    private static let routerDetailDownText = "DOWN"
    private static let routerDetailYesText = "Yes"
    private static let routerDetailNoText = "No"
    private static let routerDetailEnabledText = "Enabled"
    private static let routerDetailDisabledText = "Disabled"
    private static let routerDetailUnknownText = "Unknown"
    private static let routerDetailNoneText = "None"
    private static let routerDetailItemPrefix = "- "
    private static let routerDetailSubnetItemPrefix = "- "
    private static let routerDetailNoSubnetsText = "No subnets attached"
    private static let routerDetailNoRoutesText = "No static routes configured"
    private static let routerDetailNoTagsText = "No tags assigned"
    private static let routerDetailNoExternalFixedIpsText = "No external fixed IPs"
    private static let routerDetailHelpText = "Press ESC to return to router list"
    private static let routerDetailScreenTooSmallText = "Screen too small"

    // Detail View Layout Constants
    private static let routerDetailMinScreenWidth: Int32 = 10
    private static let routerDetailMinScreenHeight: Int32 = 10
    private static let routerDetailBoundsMinWidth: Int32 = 1
    private static let routerDetailBoundsMinHeight: Int32 = 1
    private static let routerDetailTitleTopPadding: Int32 = 0
    private static let routerDetailTitleLeadingPadding: Int32 = 0
    private static let routerDetailTitleBottomPadding: Int32 = 2
    private static let routerDetailTitleTrailingPadding: Int32 = 0
    private static let routerDetailSectionTopPadding: Int32 = 0
    private static let routerDetailSectionLeadingPadding: Int32 = 4
    private static let routerDetailSectionBottomPadding: Int32 = 1
    private static let routerDetailSectionTrailingPadding: Int32 = 0
    private static let routerDetailHelpTopPadding: Int32 = 1
    private static let routerDetailHelpLeadingPadding: Int32 = 0
    private static let routerDetailHelpBottomPadding: Int32 = 0
    private static let routerDetailHelpTrailingPadding: Int32 = 0
    private static let routerDetailInfoFieldIndent = "  "
    private static let routerDetailComponentSpacing: Int32 = 0

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let routerDetailTitleEdgeInsets = EdgeInsets(top: routerDetailTitleTopPadding, leading: routerDetailTitleLeadingPadding, bottom: routerDetailTitleBottomPadding, trailing: routerDetailTitleTrailingPadding)
    private static let routerDetailSectionEdgeInsets = EdgeInsets(top: routerDetailSectionTopPadding, leading: routerDetailSectionLeadingPadding, bottom: routerDetailSectionBottomPadding, trailing: routerDetailSectionTrailingPadding)
    private static let routerDetailHelpEdgeInsets = EdgeInsets(top: routerDetailHelpTopPadding, leading: routerDetailHelpLeadingPadding, bottom: routerDetailHelpBottomPadding, trailing: routerDetailHelpTrailingPadding)

    @MainActor
    static func drawRouterDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                width: Int32, height: Int32, router: Router, cachedSubnets: [Subnet], scrollOffset: Int = 0) async {

        var sections: [DetailSection] = []

        // Basic Information Section
        var basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: router.id),
            DetailView.buildFieldItem(label: "Name", value: router.name, defaultValue: "Unnamed Router"),
            DetailView.buildFieldItem(label: "Description", value: router.description)
        ]

        if let status = router.status {
            let statusStyle: TextStyle = status.uppercased() == "ACTIVE" ? .success : .error
            basicItems.append(.customComponent(
                HStack(spacing: 0, children: [
                    Text("  Status: ").secondary(),
                    Text(status.uppercased()).styled(statusStyle)
                ])
            ))
        }

        if let adminState = router.adminStateUp {
            let adminStateText = adminState ? "UP" : "DOWN"
            let adminStyle: TextStyle = adminState ? .success : .error
            basicItems.append(.customComponent(
                HStack(spacing: 0, children: [
                    Text("  Admin State: ").secondary(),
                    Text(adminStateText).styled(adminStyle)
                ])
            ))
        }

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Router Configuration Section - Enhanced!
        var configItems: [DetailItem] = []

        if let distributed = router.distributed {
            let distText = distributed ? "Yes (DVR)" : "No (Centralized)"
            let distStyle: TextStyle = distributed ? .success : .secondary
            configItems.append(.customComponent(
                HStack(spacing: 0, children: [
                    Text("  Distributed: ").secondary(),
                    Text(distText).styled(distStyle)
                ])
            ))

            // Add DVR explanation
            if distributed {
                configItems.append(.field(label: "  Note", value: "Distributed Virtual Router - Better performance", style: .info))
            }
        }

        if let ha = router.ha {
            let haText = ha ? "Enabled" : "Disabled"
            let haStyle: TextStyle = ha ? .success : .warning
            configItems.append(.customComponent(
                HStack(spacing: 0, children: [
                    Text("  High Availability: ").secondary(),
                    Text(haText).styled(haStyle)
                ])
            ))

            // Add HA explanation
            if ha {
                configItems.append(.field(label: "  Note", value: "VRRP-based failover for redundancy", style: .info))
            } else {
                configItems.append(.field(label: "  Warning", value: "No HA - single point of failure", style: .warning))
            }
        }

        if !configItems.isEmpty {
            sections.append(DetailSection(title: "Router Configuration", items: configItems, titleStyle: .accent))
        }

        // External Gateway Section
        if let externalGateway = router.externalGatewayInfo {
            var gatewayItems: [DetailItem?] = [
                DetailView.buildFieldItem(label: "Network ID", value: externalGateway.networkId)
            ]

            if let enableSnat = externalGateway.enableSnat {
                let snatText = enableSnat ? "Yes (Outbound NAT enabled)" : "No (No outbound NAT)"
                let snatStyle: TextStyle = enableSnat ? .success : .warning
                gatewayItems.append(.customComponent(
                    HStack(spacing: 0, children: [
                        Text("  SNAT Enabled: ").secondary(),
                        Text(snatText).styled(snatStyle)
                    ])
                ))

                if !enableSnat {
                    gatewayItems.append(.field(label: "  Note", value: "Instances need floating IPs for external access", style: .info))
                }
            }

            if let externalFixedIps = externalGateway.externalFixedIps, !externalFixedIps.isEmpty {
                gatewayItems.append(.spacer)
                for fixedIp in externalFixedIps {
                    if let ipAddress = fixedIp.ipAddress {
                        gatewayItems.append(.field(label: "External IP", value: ipAddress, style: .info))
                    }
                    if let subnetId = fixedIp.subnetId {
                        gatewayItems.append(.field(label: "  Subnet", value: subnetId, style: .secondary))
                    }
                }
            }

            if let gatewaySection = DetailView.buildSection(title: "External Gateway", items: gatewayItems) {
                sections.append(gatewaySection)
            }
        }

        // Attached Subnets Section
        if let interfaces = router.interfaces, !interfaces.isEmpty {
            var subnetItems: [DetailItem] = []

            for interface in interfaces {
                guard let subnetId = interface.subnetId else { continue }

                // Find the subnet name from cached subnets
                let subnet = cachedSubnets.first { $0.id == subnetId }
                let subnetName = subnet?.name ?? "Unknown"
                let subnetCidr = subnet?.cidr ?? "Unknown"

                subnetItems.append(.field(label: "Subnet", value: "\(subnetName) (\(subnetCidr))", style: .secondary))
                subnetItems.append(.field(label: "  Subnet ID", value: subnetId, style: .muted))

                if let portId = interface.portId {
                    subnetItems.append(.field(label: "  Port ID", value: portId, style: .muted))
                }

                if let ipAddress = interface.ipAddress {
                    subnetItems.append(.field(label: "  IP Address", value: ipAddress, style: .info))
                }

                subnetItems.append(.spacer)
            }

            // Remove trailing spacer
            if !subnetItems.isEmpty && subnetItems.last?.isSpacerType == true {
                subnetItems.removeLast()
            }

            sections.append(DetailSection(title: "Attached Subnets", items: subnetItems))
        } else {
            sections.append(DetailSection(
                title: "Attached Subnets",
                items: [.field(label: "Status", value: "No subnets attached", style: .muted)]
            ))
        }

        // Routes Section
        if let routes = router.routes, !routes.isEmpty {
            var routeItems: [DetailItem] = []

            for route in routes {
                routeItems.append(.field(label: "Route", value: "Destination: \(route.destination), Next Hop: \(route.nexthop)", style: .secondary))
                routeItems.append(.field(label: "  Destination", value: route.destination, style: .muted))
                routeItems.append(.field(label: "  Next Hop", value: route.nexthop, style: .info))
                routeItems.append(.spacer)
            }

            // Remove trailing spacer
            if !routeItems.isEmpty && routeItems.last?.isSpacerType == true {
                routeItems.removeLast()
            }

            sections.append(DetailSection(title: "Static Routes", items: routeItems))
        } else {
            sections.append(DetailSection(
                title: "Static Routes",
                items: [.field(label: "Status", value: "No static routes configured", style: .muted)]
            ))
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: router.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: router.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Tags Section
        if let tags = router.tags, !tags.isEmpty {
            let tagItems = tags.map { DetailItem.field(label: "Tag", value: $0, style: .secondary) }
            sections.append(DetailSection(title: "Tags", items: tagItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Router Details: \(router.name ?? "Unnamed Router")",
            sections: sections,
            helpText: "Press ESC to return to routers list",
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

    // MARK: - Router Create View

    // Layout Constants
    private static let routerCreateMinScreenWidth: Int32 = 10
    private static let routerCreateMinScreenHeight: Int32 = 10
    private static let routerCreateBoundsMinWidth: Int32 = 1
    private static let routerCreateBoundsMinHeight: Int32 = 1
    private static let routerCreateComponentTopPadding: Int32 = 1
    private static let routerCreateStatusMessageTopPadding: Int32 = 2
    private static let routerCreateStatusMessageLeadingPadding: Int32 = 2
    private static let routerCreateValidationErrorLeadingPadding: Int32 = 2
    private static let routerCreateValidationErrorTopPadding: Int32 = 1
    private static let routerCreateValidationErrorLeadingPaddingItem: Int32 = 2
    private static let routerCreateValidationErrorBottomPadding: Int32 = 0
    private static let routerCreateValidationErrorTrailingPadding: Int32 = 0
    private static let routerCreateLoadingErrorBoundsHeight: Int32 = 6
    private static let routerCreateFieldActiveSpacing = "                      "
    private static let routerCreateFieldComponentBottomPadding: Int32 = 1
    private static let routerCreateFieldComponentLeadingPadding: Int32 = 4
    private static let routerCreateFieldComponentTopPadding: Int32 = 0
    private static let routerCreateFieldComponentTrailingPadding: Int32 = 0
    private static let routerCreateFieldTruncationBuffer = 10
    private static let routerCreateFieldLabelLeadingPadding: Int32 = 0
    private static let routerCreateFieldLabelBottomPadding: Int32 = 0
    private static let routerCreateFieldLabelTrailingPadding: Int32 = 0

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let routerCreateValidationErrorEdgeInsets = EdgeInsets(top: routerCreateComponentTopPadding, leading: routerCreateValidationErrorLeadingPadding, bottom: routerCreateValidationErrorBottomPadding, trailing: routerCreateValidationErrorTrailingPadding)
    private static let routerCreateValidationErrorItemEdgeInsets = EdgeInsets(top: routerCreateValidationErrorTopPadding, leading: routerCreateValidationErrorLeadingPaddingItem, bottom: routerCreateValidationErrorBottomPadding, trailing: routerCreateValidationErrorTrailingPadding)
    private static let routerCreateFieldComponentEdgeInsets = EdgeInsets(top: routerCreateFieldComponentTopPadding, leading: routerCreateFieldComponentLeadingPadding, bottom: routerCreateFieldComponentBottomPadding, trailing: routerCreateFieldComponentTrailingPadding)
    private static let routerCreateFieldLabelEdgeInsets = EdgeInsets(top: routerCreateComponentTopPadding, leading: routerCreateFieldLabelLeadingPadding, bottom: routerCreateFieldLabelBottomPadding, trailing: routerCreateFieldLabelTrailingPadding)

    // Text Constants
    private static let routerCreateFormTitle = "Create New Router"
    private static let routerCreateCreatingRouterText = "Creating router..."
    private static let routerCreateErrorPrefix = "Error: "
    private static let routerCreateRequiredFieldSuffix = ": *"
    private static let routerCreateOptionalFieldSuffix = " (optional)"
    private static let routerCreateScreenTooSmallText = "Screen too small"

    // Field Display Constants
    private static let routerCreateValidationErrorsTitle = "Validation Errors:"
    private static let routerCreateValidationErrorPrefix = "- "
    private static let routerCreateCheckboxSelectedText = "[X]"
    private static let routerCreateCheckboxUnselectedText = "[ ]"
    private static let routerCreateEditPromptText = "Press SPACE to edit..."
    private static let routerCreateSelectPromptText = "Press LEFT/RIGHT to select"
    private static let routerCreateTogglePromptText = "Press SPACE to toggle"

    // Field Label Constants
    private static let routerCreateNameFieldLabel = "Router Name"
    private static let routerCreateDescriptionFieldLabel = "Description"
    private static let routerCreateAvailabilityZoneFieldLabel = "Availability Zone"
    private static let routerCreateExternalGatewayFieldLabel = "External Gateway"
    private static let routerCreateExternalNetworkFieldLabel = "External Network"

    // Placeholder Constants
    private static let routerCreateNamePlaceholder = "[Enter router name]"
    private static let routerCreateDescriptionPlaceholder = "[Enter description]"
    private static let routerCreateNoAvailabilityZoneText = "[No availability zone selected]"
    private static let routerCreateNoExternalNetworkText = "[No external network selected]"
    private static let routerCreateEnabledText = "Enabled"
    private static let routerCreateDisabledText = "Disabled"
    private static let routerCreateItemTextSpacing = " "

    // UI Component Constants
    private static let routerCreateSelectedIndicator = "> "
    private static let routerCreateUnselectedIndicator = "  "
    private static let routerCreateComponentSpacing: Int32 = 0
    private static let routerCreateChoiceIndicatorPrefix = " ("
    private static let routerCreateChoiceIndicatorSeparator = "/"
    private static let routerCreateChoiceIndicatorSuffix = ")"

    // Delete Confirmation Dialog Constants
    private static let routerDeleteDialogTopPadding: Int32 = 1
    private static let routerDeleteDialogLeadingPadding: Int32 = 2
    private static let routerDeleteDialogBottomPadding: Int32 = 0
    private static let routerDeleteDialogTrailingPadding: Int32 = 0
    private static let routerDeleteDialogWidth: Int32 = 60
    private static let routerDeleteDialogHeight: Int32 = 8
    private static let routerDeleteDialogTitle = "Confirm Router Deletion"
    private static let routerDeleteDialogUnnamedRouterText = "Unnamed Router"
    private static let routerDeleteDialogRouterLabel = "Router: "
    private static let routerDeleteDialogIdLabel = "ID: "
    private static let routerDeleteDialogInstructions = "Press Y to confirm deletion, any other key to cancel"
    private static let routerDeleteDialogWarning = "This action cannot be undone!"

    @MainActor
    static func drawRouterCreateForm(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                   width: Int32, height: Int32, routerCreateForm: RouterCreateForm,
                                   routerCreateFormState: FormBuilderState,
                                   availabilityZones: [String], externalNetworks: [Network]) async {

        let surface = SwiftNCurses.surface(from: screen)

        guard width > Self.routerCreateMinScreenWidth && height > Self.routerCreateMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.routerCreateBoundsMinWidth, width), height: max(Self.routerCreateBoundsMinHeight, height))
            await SwiftNCurses.render(Text(Self.routerCreateScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        let fields = routerCreateForm.buildFields(
            selectedFieldId: routerCreateFormState.getCurrentFieldId(),
            activeFieldId: routerCreateFormState.getActiveFieldId(),
            formState: routerCreateFormState,
            availabilityZones: availabilityZones,
            externalNetworks: externalNetworks
        )

        let validationErrors = routerCreateForm.validateForm(
            availabilityZones: availabilityZones,
            externalNetworks: externalNetworks
        )

        let formBuilder = FormBuilder(
            title: Self.routerCreateFormTitle,
            fields: fields,
            selectedFieldId: routerCreateFormState.getCurrentFieldId(),
            validationErrors: validationErrors,
            showValidationErrors: !validationErrors.isEmpty
        )

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftNCurses.render(formBuilder.render(), on: surface, in: bounds)

        if let currentField = routerCreateFormState.getCurrentField() {
            switch currentField {
            case .selector(let selectorField) where selectorField.isActive:
                if let selectorState = routerCreateFormState.getSelectorState(selectorField.id) {
                    if let selectorComponent = FormSelectorRenderer.renderSelector(
                        label: selectorField.label,
                        items: selectorField.items,
                        selectedItemId: selectorState.selectedItemId,
                        highlightedIndex: selectorState.highlightedIndex,
                        scrollOffset: selectorState.scrollOffset,
                        searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
                        columns: selectorField.columns,
                        maxHeight: Int(height)
                    ) {
                        let overlayBounds = Rect(x: startCol, y: startRow, width: width, height: height)
                        surface.clear(rect: overlayBounds)
                        await SwiftNCurses.render(selectorComponent, on: surface, in: overlayBounds)
                    }
                }
            default:
                break
            }
        }
    }


    @MainActor
    static func drawRouterDeleteConfirmation(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                           width: Int32, height: Int32, router: Router) async {
        let surface = SwiftNCurses.surface(from: screen)
        let dialogWidth: Int32 = Self.routerDeleteDialogWidth
        let dialogHeight: Int32 = Self.routerDeleteDialogHeight
        let dialogStartRow = startRow + (height - dialogHeight) / 2
        let dialogStartCol = startCol + (width - dialogWidth) / 2

        // Clear dialog area with error background using SwiftNCurses
        let backgroundBounds = Rect(x: dialogStartCol, y: dialogStartRow, width: dialogWidth, height: dialogHeight)
        await surface.fill(rect: backgroundBounds, character: " ", style: .error)

        var components: [any Component] = []

        // Title
        components.append(Text(Self.routerDeleteDialogTitle).error().bold())
        components.append(Text(""))

        // Router info
        let routerName = router.name ?? Self.routerDeleteDialogUnnamedRouterText
        components.append(Text(Self.routerDeleteDialogRouterLabel + routerName).secondary())
        components.append(Text(Self.routerDeleteDialogIdLabel + router.id).secondary())
        components.append(Text(""))

        // Warning message
        components.append(Text(Self.routerDeleteDialogWarning).error().bold())
        components.append(Text(""))

        // Instructions
        components.append(Text(Self.routerDeleteDialogInstructions).info())

        let dialogComponent = VStack(spacing: 0, children: components)
            .padding(EdgeInsets(top: Self.routerDeleteDialogTopPadding, leading: Self.routerDeleteDialogLeadingPadding, bottom: Self.routerDeleteDialogBottomPadding, trailing: Self.routerDeleteDialogTrailingPadding))

        let dialogBounds = Rect(x: dialogStartCol, y: dialogStartRow, width: dialogWidth, height: dialogHeight)
        await SwiftNCurses.render(dialogComponent, on: surface, in: dialogBounds)
    }
}