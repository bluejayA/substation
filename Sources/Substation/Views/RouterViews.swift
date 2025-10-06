import Foundation
import OSClient
import SwiftTUI

struct RouterViews {
    @MainActor
    static func drawDetailedRouterList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                      width: Int32, height: Int32, cachedRouters: [Router],
                                      searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

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
            selectedIndex: selectedIndex
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
                                width: Int32, height: Int32, router: Router, cachedSubnets: [Subnet]) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.routerDetailMinScreenWidth && height > Self.routerDetailMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.routerDetailBoundsMinWidth, width), height: max(Self.routerDetailBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.routerDetailScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Router Detail
        var components: [any Component] = []

        // Title - optimized string construction
        let routerName = router.name ?? Self.routerDetailUnnamedRouterText
        let titleText = Self.routerDetailTitle + Self.routerDetailFieldValueSeparator + routerName
        components.append(Text(titleText).accent().bold()
                         .padding(Self.routerDetailTitleEdgeInsets))

        // Basic Information Section
        components.append(Text(Self.routerDetailBasicInfoTitle).primary().bold())

        var basicInfo: [any Component] = []
        // Pre-calculate common field prefixes for optimal performance
        let fieldPrefix = Self.routerDetailInfoFieldIndent
        let fieldSeparator = Self.routerDetailFieldValueSeparator
        let idPrefix = fieldPrefix + Self.routerDetailIdLabel + fieldSeparator
        let namePrefix = fieldPrefix + Self.routerDetailNameLabel + fieldSeparator

        // Optimized string construction for basic info fields
        let idText = idPrefix + router.id
        let nameText = namePrefix + routerName
        basicInfo.append(Text(idText).secondary())
        basicInfo.append(Text(nameText).secondary())

        if let description = router.description, !description.isEmpty {
            let descPrefix = fieldPrefix + Self.routerDetailDescriptionLabel + fieldSeparator
            let descText = descPrefix + description
            basicInfo.append(Text(descText).secondary())
        }

        if let status = router.status {
            let statusPrefix = fieldPrefix + Self.routerDetailStatusLabel + fieldSeparator
            let statusText = statusPrefix + status.uppercased()
            basicInfo.append(Text(statusText).secondary())
        }

        if let adminState = router.adminStateUp {
            let adminStateText = adminState ? Self.routerDetailUpText : Self.routerDetailDownText
            let adminPrefix = fieldPrefix + Self.routerDetailAdminStateLabel + fieldSeparator
            let adminText = adminPrefix + adminStateText
            basicInfo.append(Text(adminText).secondary())
        }

        if let distributed = router.distributed {
            let distributedText = distributed ? Self.routerDetailYesText : Self.routerDetailNoText
            let distributedPrefix = fieldPrefix + Self.routerDetailDistributedLabel + fieldSeparator
            let distributedDisplayText = distributedPrefix + distributedText
            basicInfo.append(Text(distributedDisplayText).secondary())
        }

        if let ha = router.ha {
            let haText = ha ? Self.routerDetailEnabledText : Self.routerDetailDisabledText
            let haPrefix = fieldPrefix + Self.routerDetailHALabel + fieldSeparator
            let haDisplayText = haPrefix + haText
            basicInfo.append(Text(haDisplayText).secondary())
        }

        let basicInfoSection = VStack(spacing: 0, children: basicInfo)
            .padding(Self.routerDetailSectionEdgeInsets)
        components.append(basicInfoSection)

        // Metadata Section
        components.append(Text(Self.routerDetailMetadataTitle).primary().bold())

        var metadataInfo: [any Component] = []

        if let tenantId = router.tenantId {
            let tenantPrefix = fieldPrefix + Self.routerDetailTenantIdLabel + fieldSeparator
            let tenantText = tenantPrefix + tenantId
            metadataInfo.append(Text(tenantText).secondary())
        }

        if let projectId = router.projectId {
            let projectPrefix = fieldPrefix + Self.routerDetailProjectIdLabel + fieldSeparator
            let projectText = projectPrefix + projectId
            metadataInfo.append(Text(projectText).secondary())
        }

        if let createdAt = router.createdAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let createdPrefix = fieldPrefix + Self.routerDetailCreatedAtLabel + fieldSeparator
            let createdText = createdPrefix + formatter.string(from: createdAt)
            metadataInfo.append(Text(createdText).secondary())
        }

        if let updatedAt = router.updatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let updatedPrefix = fieldPrefix + Self.routerDetailUpdatedAtLabel + fieldSeparator
            let updatedText = updatedPrefix + formatter.string(from: updatedAt)
            metadataInfo.append(Text(updatedText).secondary())
        }

        if let revisionNumber = router.revisionNumber {
            let revisionPrefix = fieldPrefix + Self.routerDetailRevisionLabel + fieldSeparator
            let revisionText = revisionPrefix + String(revisionNumber)
            metadataInfo.append(Text(revisionText).secondary())
        }

        if let flavorId = router.flavor_id {
            let flavorPrefix = fieldPrefix + Self.routerDetailFlavorIdLabel + fieldSeparator
            let flavorText = flavorPrefix + flavorId
            metadataInfo.append(Text(flavorText).secondary())
        }

        if let serviceTypeId = router.service_type_id {
            let servicePrefix = fieldPrefix + Self.routerDetailServiceTypeIdLabel + fieldSeparator
            let serviceText = servicePrefix + serviceTypeId
            metadataInfo.append(Text(serviceText).secondary())
        }

        if let tags = router.tags, !tags.isEmpty {
            let tagsPrefix = fieldPrefix + Self.routerDetailTagsLabel + fieldSeparator
            let tagsText = tagsPrefix + tags.joined(separator: ", ")
            metadataInfo.append(Text(tagsText).secondary())
        } else {
            let noTagsText = fieldPrefix + Self.routerDetailTagsLabel + fieldSeparator + Self.routerDetailNoTagsText
            metadataInfo.append(Text(noTagsText).muted())
        }

        let metadataSection = VStack(spacing: 0, children: metadataInfo)
            .padding(Self.routerDetailSectionEdgeInsets)
        components.append(metadataSection)

        // External Gateway Information
        if let externalGateway = router.externalGatewayInfo {
            components.append(Text(Self.routerDetailExternalGatewayTitle).primary().bold())

            var gatewayInfo: [any Component] = []
            if let networkId = externalGateway.networkId {
                let networkPrefix = fieldPrefix + Self.routerDetailNetworkIdLabel + fieldSeparator
                let networkText = networkPrefix + networkId
                gatewayInfo.append(Text(networkText).secondary())
            }

            if let enableSnat = externalGateway.enableSnat {
                let snatText = enableSnat ? Self.routerDetailYesText : Self.routerDetailNoText
                let snatPrefix = fieldPrefix + Self.routerDetailSNATEnabledLabel + fieldSeparator
                let snatFieldText = snatPrefix + snatText
                gatewayInfo.append(Text(snatFieldText).secondary())
            }

            if let externalFixedIps = externalGateway.externalFixedIps, !externalFixedIps.isEmpty {
                let externalIpsPrefix = fieldPrefix + Self.routerDetailExternalFixedIpsLabel + fieldSeparator
                gatewayInfo.append(Text(externalIpsPrefix).secondary())

                for fixedIp in externalFixedIps {
                    var ipDetails: [String] = []
                    if let subnetId = fixedIp.subnetId {
                        ipDetails.append("Subnet: " + subnetId)
                    }
                    if let ipAddress = fixedIp.ipAddress {
                        ipDetails.append("IP: " + ipAddress)
                    }
                    let ipText = fieldPrefix + "  " + Self.routerDetailItemPrefix + ipDetails.joined(separator: ", ")
                    gatewayInfo.append(Text(ipText).muted())
                }
            } else {
                let noExternalIpsText = fieldPrefix + Self.routerDetailExternalFixedIpsLabel + fieldSeparator + Self.routerDetailNoExternalFixedIpsText
                gatewayInfo.append(Text(noExternalIpsText).muted())
            }

            let gatewaySection = VStack(spacing: 0, children: gatewayInfo)
                .padding(Self.routerDetailSectionEdgeInsets)
            components.append(gatewaySection)
        }

        // Log router interface data for debugging
        Logger.shared.logInfo("RouterDetailView - Interface debugging", context: [
            "routerId": router.id,
            "routerName": router.name ?? "Unknown",
            "interfacesPresent": router.interfaces != nil,
            "interfaceCount": router.interfaces?.count ?? 0,
            "interfaceSubnetIds": router.interfaces?.compactMap { $0.subnetId } ?? []
        ])

        // Attached Subnets Section
        if let interfaces = router.interfaces, !interfaces.isEmpty {
            components.append(Text(Self.routerDetailAttachedSubnetsTitle).primary().bold())

            var subnetInfo: [any Component] = []

            for interface in interfaces {
                guard let subnetId = interface.subnetId else { continue }

                // Find the subnet name from cached subnets
                let subnet = cachedSubnets.first { $0.id == subnetId }
                let subnetName = subnet?.name ?? "Unknown"
                let subnetCidr = subnet?.cidr ?? "Unknown"

                let subnetText = Self.routerDetailSubnetItemPrefix + subnetName + " (" + subnetCidr + ")"
                subnetInfo.append(Text(subnetText).secondary())

                // Add detailed interface information
                let subnetIdText = Self.routerDetailInfoFieldIndent + "  Subnet ID: " + subnetId
                subnetInfo.append(Text(subnetIdText).muted())

                // Add port ID if available
                if let portId = interface.portId {
                    let portIdText = Self.routerDetailInfoFieldIndent + "  " + Self.routerDetailPortIdLabel + ": " + portId
                    subnetInfo.append(Text(portIdText).muted())
                }

                // Add IP address if available
                if let ipAddress = interface.ipAddress {
                    let ipText = Self.routerDetailInfoFieldIndent + "  " + Self.routerDetailIpAddressLabel + ": " + ipAddress
                    subnetInfo.append(Text(ipText).muted())
                }
            }

            let subnetSection = VStack(spacing: 0, children: subnetInfo)
                .padding(Self.routerDetailSectionEdgeInsets)
            components.append(subnetSection)
        } else {
            // Show "No subnets attached" section
            components.append(Text(Self.routerDetailAttachedSubnetsTitle).primary().bold())

            let noSubnetsText = Self.routerDetailInfoFieldIndent + Self.routerDetailNoSubnetsText
            let noSubnetsSection = VStack(spacing: 0, children: [Text(noSubnetsText).muted()])
                .padding(Self.routerDetailSectionEdgeInsets)
            components.append(noSubnetsSection)
        }

        // Routes Section
        if let routes = router.routes, !routes.isEmpty {
            components.append(Text(Self.routerDetailRoutesTitle).primary().bold())

            var routeInfo: [any Component] = []
            for route in routes {
                let routeText = Self.routerDetailItemPrefix + "Destination: " + route.destination + ", Next Hop: " + route.nexthop
                routeInfo.append(Text(routeText).secondary())
            }

            let routeSection = VStack(spacing: 0, children: routeInfo)
                .padding(Self.routerDetailSectionEdgeInsets)
            components.append(routeSection)
        } else {
            // Show "No routes" section
            components.append(Text(Self.routerDetailRoutesTitle).primary().bold())

            let noRoutesText = Self.routerDetailInfoFieldIndent + Self.routerDetailNoRoutesText
            let noRoutesSection = VStack(spacing: 0, children: [Text(noRoutesText).muted()])
                .padding(Self.routerDetailSectionEdgeInsets)
            components.append(noRoutesSection)
        }

        // Help text
        components.append(Text(Self.routerDetailHelpText).info()
            .padding(Self.routerDetailHelpEdgeInsets))

        // Render unified router detail
        let routerDetailComponent = VStack(spacing: Self.routerDetailComponentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(routerDetailComponent, on: surface, in: bounds)
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

        let surface = SwiftTUI.surface(from: screen)

        guard width > Self.routerCreateMinScreenWidth && height > Self.routerCreateMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.routerCreateBoundsMinWidth, width), height: max(Self.routerCreateBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.routerCreateScreenTooSmallText).error(), on: surface, in: errorBounds)
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
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)

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
                        await SwiftTUI.render(selectorComponent, on: surface, in: overlayBounds)
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
        let surface = SwiftTUI.surface(from: screen)
        let dialogWidth: Int32 = Self.routerDeleteDialogWidth
        let dialogHeight: Int32 = Self.routerDeleteDialogHeight
        let dialogStartRow = startRow + (height - dialogHeight) / 2
        let dialogStartCol = startCol + (width - dialogWidth) / 2

        // Clear dialog area with error background using SwiftTUI
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
        await SwiftTUI.render(dialogComponent, on: surface, in: dialogBounds)
    }
}