import Foundation
import OSClient
import SwiftTUI

struct SubnetViews {
    @MainActor
    static func drawDetailedSubnetList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                      width: Int32, height: Int32, cachedSubnets: [Subnet],
                                      searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

        let statusListView = createSubnetStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedSubnets,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Subnet Detail View (Gold Standard Pattern following RouterDetail)

    @MainActor
    static func drawSubnetDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                width: Int32, height: Int32, subnet: Subnet) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.subnetDetailMinScreenWidth && height > Self.subnetDetailMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.subnetDetailBoundsMinWidth, width), height: max(Self.subnetDetailBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.subnetDetailScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Subnet Detail
        var components: [any Component] = []

        // Title - optimized string construction
        let subnetName = subnet.name ?? Self.subnetDetailUnnamedSubnetText
        let titleText = Self.subnetDetailTitle + Self.subnetDetailFieldValueSeparator + subnetName
        components.append(Text(titleText).accent().bold()
                         .padding(Self.subnetDetailTitleEdgeInsets))

        // Basic Information Section
        components.append(Text(Self.subnetDetailBasicInfoTitle).primary().bold())

        var basicInfo: [any Component] = []
        // Pre-calculate common field prefixes for optimal performance
        let fieldPrefix = Self.subnetDetailInfoFieldIndent
        let fieldSeparator = Self.subnetDetailFieldValueSeparator
        let idPrefix = fieldPrefix + Self.subnetDetailIdLabel + fieldSeparator
        let namePrefix = fieldPrefix + Self.subnetDetailNameLabel + fieldSeparator
        let networkPrefix = fieldPrefix + Self.subnetDetailNetworkIdLabel + fieldSeparator

        // Optimized string construction for basic info fields
        let idText = idPrefix + subnet.id
        let nameText = namePrefix + subnetName
        let networkText = networkPrefix + subnet.networkId

        basicInfo.append(Text(idText).secondary())
        basicInfo.append(Text(nameText).secondary())
        basicInfo.append(Text(networkText).secondary())

        let basicInfoSection = VStack(spacing: 0, children: basicInfo)
            .padding(Self.subnetDetailSectionEdgeInsets)
        components.append(basicInfoSection)

        // Help text
        components.append(Text(Self.subnetDetailHelpText).info()
            .padding(Self.subnetDetailHelpEdgeInsets))

        // Render unified subnet detail
        let subnetDetailComponent = VStack(spacing: Self.subnetDetailComponentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(subnetDetailComponent, on: surface, in: bounds)
    }

    // MARK: - Subnet List View Constants
    // Layout Constants
    private static let subnetListMinScreenWidth: Int32 = 10
    private static let subnetListMinScreenHeight: Int32 = 10
    private static let subnetListHeaderTopPadding: Int32 = 2
    private static let subnetListHeaderLeadingPadding: Int32 = 0
    private static let subnetListHeaderBottomPadding: Int32 = 0
    private static let subnetListHeaderTrailingPadding: Int32 = 0
    private static let subnetListNoSubnetsTopPadding: Int32 = 2
    private static let subnetListNoSubnetsLeadingPadding: Int32 = 2
    private static let subnetListNoSubnetsBottomPadding: Int32 = 0
    private static let subnetListNoSubnetsTrailingPadding: Int32 = 0
    private static let subnetListScrollInfoTopPadding: Int32 = 1
    private static let subnetListScrollInfoLeadingPadding: Int32 = 0
    private static let subnetListScrollInfoBottomPadding: Int32 = 0
    private static let subnetListScrollInfoTrailingPadding: Int32 = 0
    private static let subnetListReservedSpaceForHeaderFooter = 10
    private static let subnetListComponentSpacing: Int32 = 0
    private static let subnetListItemLeadingPadding: Int32 = 2
    private static let subnetListItemTopPadding: Int32 = 0
    private static let subnetListItemBottomPadding: Int32 = 0
    private static let subnetListItemTrailingPadding: Int32 = 0
    private static let subnetListMinVisibleItems = 1
    private static let subnetListBoundsMinWidth: Int32 = 1
    private static let subnetListBoundsMinHeight: Int32 = 1

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let subnetListHeaderEdgeInsets = EdgeInsets(top: subnetListHeaderTopPadding, leading: subnetListHeaderLeadingPadding, bottom: subnetListHeaderBottomPadding, trailing: subnetListHeaderTrailingPadding)
    private static let subnetListNoSubnetsEdgeInsets = EdgeInsets(top: subnetListNoSubnetsTopPadding, leading: subnetListNoSubnetsLeadingPadding, bottom: subnetListNoSubnetsBottomPadding, trailing: subnetListNoSubnetsTrailingPadding)
    private static let subnetListScrollInfoEdgeInsets = EdgeInsets(top: subnetListScrollInfoTopPadding, leading: subnetListScrollInfoLeadingPadding, bottom: subnetListScrollInfoBottomPadding, trailing: subnetListScrollInfoTrailingPadding)
    private static let subnetListItemEdgeInsets = EdgeInsets(top: subnetListItemTopPadding, leading: subnetListItemLeadingPadding, bottom: subnetListItemBottomPadding, trailing: subnetListItemTrailingPadding)

    // Text Constants
    private static let subnetListTitle = "Subnets"
    private static let subnetListFilteredTitlePrefix = "Subnets (filtered: "
    private static let subnetListFilteredTitleSuffix = ")"
    private static let subnetListHeader = " NAME                                 NETWORK ID                    SUBNET ID"
    private static let subnetListNoSubnetsText = "No subnets found"
    private static let subnetListScrollInfoPrefix = "["
    private static let subnetListScrollInfoSeparator = "-"
    private static let subnetListScrollInfoMiddle = "/"
    private static let subnetListScrollInfoSuffix = "]"
    private static let subnetListUnnamedSubnetText = "Unnamed"
    private static let subnetListStatusIconActive = "active"
    private static let subnetListScreenTooSmallText = "Screen too small"
    private static let subnetListNamePadLength = 32
    private static let subnetListNetworkIdPadLength = 29
    private static let subnetListIdPadLength = 12
    private static let subnetListPadCharacter = " "
    private static let subnetListSeparatorLength = 75
    private static let subnetListItemTextSpacing = " "

    // MARK: - Subnet Detail View Constants
    // Detail View Constants
    private static let subnetDetailTitle = "Subnet Details"
    private static let subnetDetailBasicInfoTitle = "Basic Information"
    private static let subnetDetailConfigurationTitle = "Configuration"
    private static let subnetDetailAllocationPoolsTitle = "Allocation Pools"
    private static let subnetDetailIdLabel = "ID"
    private static let subnetDetailNameLabel = "Name"
    private static let subnetDetailNetworkIdLabel = "Network ID"
    private static let subnetDetailCidrLabel = "CIDR"
    private static let subnetDetailIpVersionLabel = "IP Version"
    private static let subnetDetailGatewayIpLabel = "Gateway IP"
    private static let subnetDetailDhcpEnabledLabel = "DHCP Enabled"
    private static let subnetDetailDnsLabel = "DNS Nameservers"
    private static let subnetDetailFieldValueSeparator = ": "
    private static let subnetDetailUnnamedSubnetText = "Unnamed Subnet"
    private static let subnetDetailYesText = "Yes"
    private static let subnetDetailNoText = "No"
    private static let subnetDetailNotAvailableText = "Unknown"
    private static let subnetDetailPoolItemPrefix = "- "
    private static let subnetDetailHelpText = "Press ESC to return to subnet list"
    private static let subnetDetailScreenTooSmallText = "Screen too small"

    // Detail View Layout Constants
    private static let subnetDetailMinScreenWidth: Int32 = 10
    private static let subnetDetailMinScreenHeight: Int32 = 10
    private static let subnetDetailBoundsMinWidth: Int32 = 1
    private static let subnetDetailBoundsMinHeight: Int32 = 1
    private static let subnetDetailTitleTopPadding: Int32 = 0
    private static let subnetDetailTitleLeadingPadding: Int32 = 0
    private static let subnetDetailTitleBottomPadding: Int32 = 2
    private static let subnetDetailTitleTrailingPadding: Int32 = 0
    private static let subnetDetailSectionTopPadding: Int32 = 0
    private static let subnetDetailSectionLeadingPadding: Int32 = 4
    private static let subnetDetailSectionBottomPadding: Int32 = 1
    private static let subnetDetailSectionTrailingPadding: Int32 = 0
    private static let subnetDetailHelpTopPadding: Int32 = 1
    private static let subnetDetailHelpLeadingPadding: Int32 = 0
    private static let subnetDetailHelpBottomPadding: Int32 = 0
    private static let subnetDetailHelpTrailingPadding: Int32 = 0
    private static let subnetDetailInfoFieldIndent = "  "
    private static let subnetDetailComponentSpacing: Int32 = 0

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let subnetDetailTitleEdgeInsets = EdgeInsets(top: subnetDetailTitleTopPadding, leading: subnetDetailTitleLeadingPadding, bottom: subnetDetailTitleBottomPadding, trailing: subnetDetailTitleTrailingPadding)
    private static let subnetDetailSectionEdgeInsets = EdgeInsets(top: subnetDetailSectionTopPadding, leading: subnetDetailSectionLeadingPadding, bottom: subnetDetailSectionBottomPadding, trailing: subnetDetailSectionTrailingPadding)
    private static let subnetDetailHelpEdgeInsets = EdgeInsets(top: subnetDetailHelpTopPadding, leading: subnetDetailHelpLeadingPadding, bottom: subnetDetailHelpBottomPadding, trailing: subnetDetailHelpTrailingPadding)

    // MARK: - Subnet Create View

    // Layout Constants
    private static let statusMessageTopPadding: Int32 = 2
    private static let statusMessageLeadingPadding: Int32 = 2
    private static let loadingErrorBoundsHeight: Int32 = 6

    // Text Constants
    private static let formTitle = "Create New Subnet"
    private static let creatingSubnetText = "Creating subnet..."
    private static let errorPrefix = "Error: "

    // Selection Window Titles
    private static let selectNetworkTitle = "Select Network"
    private static let selectIpVersionTitle = "Select IP Version"

    @MainActor
    static func drawSubnetCreate(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        subnetCreateForm: SubnetCreateForm,
        cachedNetworks: [Network],
        formState: FormBuilderState
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        // Build form fields
        let fields = subnetCreateForm.buildFields(
            selectedFieldId: formState.getCurrentFieldId(),
            activeFieldId: formState.getActiveFieldId(),
            cachedNetworks: cachedNetworks,
            formState: formState
        )

        // Create FormBuilder
        let formBuilder = FormBuilder(
            title: Self.formTitle,
            fields: fields,
            selectedFieldId: formState.getCurrentFieldId(),
            validationErrors: subnetCreateForm.validate(availableNetworks: cachedNetworks),
            showValidationErrors: formState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)

        // If a selector field is active, render specialized view as overlay
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
                    selectorState: formState.getSelectorState(selectorField.id) ?? FormSelectorFieldState(items: selectorField.items),
                    cachedNetworks: cachedNetworks
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
        selectorState: FormSelectorFieldState,
        cachedNetworks: [Network]
    ) async {
        // Use specialized views for specific fields based on field ID
        switch field.id {
        case SubnetCreateFieldId.network.rawValue:
            // Use NetworkSelectionView for network selection
            let selectedIds: Set<String> = field.selectedItemId.map { Set([$0]) } ?? []
            await NetworkSelectionView.drawNetworkSelection(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                networks: cachedNetworks,
                selectedNetworkIds: selectedIds,
                highlightedIndex: selectorState.highlightedIndex,
                scrollOffset: selectorState.scrollOffset,
                searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
                title: Self.selectNetworkTitle
            )
        case SubnetCreateFieldId.ipVersion.rawValue:
            // Use generic selector view for IP version selection
            await drawIPVersionSelector(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                field: field,
                selectorState: selectorState
            )
        default:
            break
        }
    }

    @MainActor
    private static func drawIPVersionSelector(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        field: FormFieldSelector,
        selectorState: FormSelectorFieldState
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        // Build a simple selection view for IP versions
        var components: [any Component] = []

        // Title
        components.append(Text(Self.selectIpVersionTitle).emphasis().bold()
            .padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 0)))

        // Get filtered items
        let filteredItems = selectorState.getFilteredItems()
        let ipVersions = filteredItems.compactMap { $0 as? IPVersion }

        // Render each IP version option
        for (index, version) in ipVersions.enumerated() {
            let isSelected = index == selectorState.highlightedIndex
            let isCurrentlySelected = version.rawValue == field.selectedItemId

            let indicator = isSelected ? "> " : "  "
            let checkbox = isCurrentlySelected ? "[X] " : "[ ] "
            let displayText = "\(indicator)\(checkbox)\(version.displayName)"

            let style: TextStyle = isSelected ? .accent : (isCurrentlySelected ? .success : .secondary)
            components.append(Text(displayText).styled(style)
                .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        }

        // Help text
        components.append(Text("Press SPACE to select, ENTER to confirm, ESC to cancel").info()
            .padding(EdgeInsets(top: 1, leading: 2, bottom: 0, trailing: 0)))

        // Render
        let selectorComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(selectorComponent, on: surface, in: bounds)
    }
}