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

    // MARK: - Subnet Detail View

    @MainActor
    static func drawSubnetDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                width: Int32, height: Int32, subnet: Subnet, scrollOffset: Int = 0) async {

        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: subnet.id),
            DetailView.buildFieldItem(label: "Name", value: subnet.name, defaultValue: "Unnamed Subnet"),
            DetailView.buildFieldItem(label: "Network ID", value: subnet.networkId),
            DetailView.buildFieldItem(label: "Description", value: subnet.description)
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Network Configuration Section
        var configItems: [DetailItem] = []

        // IP Version with intelligence
        let ipVersion = subnet.ipVersion
        configItems.append(.field(label: "IP Version", value: "IPv\(ipVersion)", style: .accent))
        if ipVersion == 4 {
            configItems.append(.field(label: "  Info", value: "32-bit addressing, ~4.3 billion addresses", style: .info))
        } else if ipVersion == 6 {
            configItems.append(.field(label: "  Info", value: "128-bit addressing, virtually unlimited addresses", style: .info))
        }

        // CIDR with network analysis
        let cidrInfo = analyzeCIDR(subnet.cidr, ipVersion: ipVersion)
        configItems.append(.field(label: "CIDR", value: subnet.cidr, style: .secondary))
        if let networkSize = cidrInfo.networkSize {
            configItems.append(.field(label: "  Network Size", value: networkSize, style: .info))
        }
        if let usableHosts = cidrInfo.usableHosts {
            configItems.append(.field(label: "  Usable IPs", value: usableHosts, style: .info))
        }

        // Gateway with intelligence
        if let gatewayIp = subnet.gatewayIp, !gatewayIp.isEmpty {
            configItems.append(.field(label: "Gateway IP", value: gatewayIp, style: .success))
            configItems.append(.field(label: "  Info", value: "Default route for subnet traffic", style: .info))
        } else {
            configItems.append(.field(label: "Gateway IP", value: "None", style: .warning))
            configItems.append(.field(label: "  Info", value: "No default route - isolated subnet", style: .warning))
        }

        // DHCP with intelligence
        if let dhcpEnabled = subnet.dhcpEnabled ?? subnet.enableDhcp {
            configItems.append(.field(label: "DHCP Enabled", value: dhcpEnabled ? "Yes" : "No", style: dhcpEnabled ? .success : .secondary))
            if dhcpEnabled {
                configItems.append(.field(label: "  Info", value: "Automatic IP assignment enabled", style: .info))
                if ipVersion == 4 {
                    configItems.append(.field(label: "  Metadata", value: "Cloud-init metadata service available", style: .info))
                }
            } else {
                configItems.append(.field(label: "  Info", value: "Manual IP configuration required", style: .warning))
            }
        }

        sections.append(DetailSection(title: "Network Configuration", items: configItems))

        // DNS Nameservers Section
        if let dnsNameservers = subnet.dnsNameservers, !dnsNameservers.isEmpty {
            var dnsItems: [DetailItem] = []
            dnsItems.append(.field(label: "DNS Servers", value: "\(dnsNameservers.count) configured", style: .accent))
            for (index, dns) in dnsNameservers.enumerated() {
                let label = index == 0 ? "Primary" : (index == 1 ? "Secondary" : "Server \(index + 1)")
                dnsItems.append(.field(label: "  \(label)", value: dns, style: .info))
            }
            sections.append(DetailSection(title: "DNS Configuration", items: dnsItems))
        }

        // Allocation Pools Section with efficiency analysis
        if let allocationPools = subnet.allocationPools, !allocationPools.isEmpty {
            var poolItems: [DetailItem] = []

            let totalPoolIPs = allocationPools.reduce(0) { total, pool in
                total + calculatePoolSize(start: pool.start, end: pool.end, ipVersion: ipVersion)
            }

            poolItems.append(.field(label: "Total Pools", value: "\(allocationPools.count)", style: .accent))
            poolItems.append(.field(label: "Total IPs Available", value: formatNumber(totalPoolIPs), style: .info))

            if let cidrTotal = cidrInfo.totalIPs, cidrTotal > 0 {
                let efficiency = (Double(totalPoolIPs) / Double(cidrTotal)) * 100.0
                let efficiencyStr = String(format: "%.1f%%", efficiency)
                let effStyle: TextStyle = efficiency > 80 ? .success : (efficiency > 50 ? .warning : .error)
                poolItems.append(.field(label: "Pool Efficiency", value: efficiencyStr, style: effStyle))
            }

            poolItems.append(.spacer)

            for (index, pool) in allocationPools.enumerated() {
                let poolSize = calculatePoolSize(start: pool.start, end: pool.end, ipVersion: ipVersion)
                poolItems.append(.field(label: "Pool \(index + 1)", value: "\(pool.start) - \(pool.end)", style: .secondary))
                poolItems.append(.field(label: "  Size", value: formatNumber(poolSize) + " IPs", style: .info))
                if index < allocationPools.count - 1 {
                    poolItems.append(.spacer)
                }
            }

            sections.append(DetailSection(title: "Allocation Pools", items: poolItems))
        }

        // Host Routes Section
        if let hostRoutes = subnet.hostRoutes, !hostRoutes.isEmpty {
            var routeItems: [DetailItem] = []
            routeItems.append(.field(label: "Static Routes", value: "\(hostRoutes.count) configured", style: .accent))
            routeItems.append(.field(label: "Info", value: "Custom routes pushed to instances via DHCP", style: .info))
            routeItems.append(.spacer)

            for (index, route) in hostRoutes.enumerated() {
                routeItems.append(.field(label: "Route \(index + 1)", value: route.destination, style: .secondary))
                routeItems.append(.field(label: "  Next Hop", value: route.nexthop, style: .info))
                if index < hostRoutes.count - 1 {
                    routeItems.append(.spacer)
                }
            }
            sections.append(DetailSection(title: "Host Routes", items: routeItems))
        }

        // IPv6 Configuration Section (only if IPv6)
        if ipVersion == 6 {
            var ipv6Items: [DetailItem] = []

            if let addressMode = subnet.ipv6AddressMode {
                ipv6Items.append(.field(label: "Address Mode", value: addressMode, style: .accent))
                let modeDesc = getIPv6ModeDescription(addressMode)
                if !modeDesc.isEmpty {
                    ipv6Items.append(.field(label: "  Description", value: modeDesc, style: .info))
                }
            }

            if let raMode = subnet.ipv6RaMode {
                if !ipv6Items.isEmpty {
                    ipv6Items.append(.spacer)
                }
                ipv6Items.append(.field(label: "RA Mode", value: raMode, style: .accent))
                let raDesc = getIPv6RAModeDescription(raMode)
                if !raDesc.isEmpty {
                    ipv6Items.append(.field(label: "  Description", value: raDesc, style: .info))
                }
            }

            if !ipv6Items.isEmpty {
                sections.append(DetailSection(title: "IPv6 Configuration", items: ipv6Items))
            }
        }

        // Subnet Pool Information Section
        var subnetPoolItems: [DetailItem] = []

        if let subnetpoolId = subnet.subnetpoolId {
            subnetPoolItems.append(.field(label: "Subnet Pool ID", value: subnetpoolId, style: .secondary))
            subnetPoolItems.append(.field(label: "  Info", value: "Part of a managed subnet pool", style: .info))
        }

        if let useDefault = subnet.useDefaultSubnetpool {
            if !subnetPoolItems.isEmpty {
                subnetPoolItems.append(.spacer)
            }
            subnetPoolItems.append(.field(label: "Use Default Pool", value: useDefault ? "Yes" : "No", style: .secondary))
            if useDefault {
                subnetPoolItems.append(.field(label: "  Info", value: "Uses tenant's default subnet pool", style: .info))
            }
        }

        if !subnetPoolItems.isEmpty {
            sections.append(DetailSection(title: "Subnet Pool", items: subnetPoolItems))
        }

        // Ownership Section
        let ownershipItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Project ID", value: subnet.projectId ?? subnet.tenantId),
            DetailView.buildFieldItem(label: "Revision Number", value: subnet.revisionNumber)
        ]

        if let ownershipSection = DetailView.buildSection(title: "Ownership", items: ownershipItems) {
            sections.append(ownershipSection)
        }

        // Tags Section
        if let tags = subnet.tags, !tags.isEmpty {
            var tagItems: [DetailItem] = []
            for tag in tags {
                tagItems.append(.field(label: "Tag", value: tag, style: .accent))
            }
            sections.append(DetailSection(title: "Tags", items: tagItems))
        }

        // Timestamps Section
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var timestampItems: [DetailItem?] = []
        if let created = subnet.createdAt {
            timestampItems.append(.field(label: "Created", value: formatter.string(from: created), style: .secondary))
        }
        if let updated = subnet.updatedAt {
            timestampItems.append(.field(label: "Updated", value: formatter.string(from: updated), style: .secondary))
        }

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Subnet Details: \(subnet.name ?? "Unnamed Subnet")",
            sections: sections,
            helpText: "Press ESC to return to subnet list",
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

    // MARK: - Helper Functions

    private struct CIDRInfo {
        let networkSize: String?
        let usableHosts: String?
        let totalIPs: Int?
    }

    private static func analyzeCIDR(_ cidr: String, ipVersion: Int) -> CIDRInfo {
        guard let prefixLength = cidr.split(separator: "/").last.flatMap({ Int($0) }) else {
            return CIDRInfo(networkSize: nil, usableHosts: nil, totalIPs: nil)
        }

        if ipVersion == 4 {
            let hostBits = 32 - prefixLength
            let totalIPs = hostBits >= 31 ? (1 << hostBits) : 0
            let usableIPs = totalIPs > 2 ? totalIPs - 2 : totalIPs

            let sizeDesc = getIPv4NetworkSizeDescription(prefixLength)
            let usableDesc = formatNumber(usableIPs)

            return CIDRInfo(
                networkSize: sizeDesc,
                usableHosts: usableDesc,
                totalIPs: totalIPs
            )
        } else if ipVersion == 6 {
            let hostBits = 128 - prefixLength
            let sizeDesc = getIPv6NetworkSizeDescription(prefixLength)

            if hostBits < 64 {
                let totalIPs = hostBits >= 31 ? (1 << hostBits) : 0
                return CIDRInfo(
                    networkSize: sizeDesc,
                    usableHosts: formatNumber(totalIPs),
                    totalIPs: totalIPs
                )
            } else {
                return CIDRInfo(
                    networkSize: sizeDesc,
                    usableHosts: "Effectively unlimited",
                    totalIPs: nil
                )
            }
        }

        return CIDRInfo(networkSize: nil, usableHosts: nil, totalIPs: nil)
    }

    private static func getIPv4NetworkSizeDescription(_ prefixLength: Int) -> String {
        switch prefixLength {
        case 8: return "Class A sized (16.7M hosts)"
        case 16: return "Class B sized (65K hosts)"
        case 24: return "Class C sized (254 hosts)"
        case 25: return "Half Class C (126 hosts)"
        case 26: return "Quarter Class C (62 hosts)"
        case 27: return "32 host network"
        case 28: return "16 host network"
        case 29: return "8 host network"
        case 30: return "Point-to-point link (2 hosts)"
        case 31: return "Point-to-point link (RFC 3021)"
        case 32: return "Single host"
        default:
            let hostBits = 32 - prefixLength
            if hostBits > 20 {
                return "Large network"
            } else if hostBits > 10 {
                return "Medium network"
            } else {
                return "Small network"
            }
        }
    }

    private static func getIPv6NetworkSizeDescription(_ prefixLength: Int) -> String {
        switch prefixLength {
        case 48: return "Site allocation (65K subnets)"
        case 56: return "Large organization (256 subnets)"
        case 64: return "Standard subnet (recommended)"
        case 80: return "Small subnet"
        case 96: return "Tiny subnet"
        case 112: return "Very small subnet"
        case 120: return "Micro subnet"
        case 128: return "Single address"
        default:
            if prefixLength < 64 {
                return "Large allocation"
            } else {
                return "Small allocation"
            }
        }
    }

    private static func getIPv6ModeDescription(_ mode: String) -> String {
        switch mode.lowercased() {
        case "slaac":
            return "Stateless autoconfiguration - addresses generated from router advertisements"
        case "dhcpv6-stateful":
            return "DHCPv6 stateful - addresses assigned by DHCPv6 server"
        case "dhcpv6-stateless":
            return "DHCPv6 stateless - addresses via SLAAC, other config via DHCPv6"
        default:
            return ""
        }
    }

    private static func getIPv6RAModeDescription(_ mode: String) -> String {
        switch mode.lowercased() {
        case "slaac":
            return "Router advertisements enable SLAAC"
        case "dhcpv6-stateful":
            return "Router advertisements direct to DHCPv6 server"
        case "dhcpv6-stateless":
            return "Router advertisements enable SLAAC + DHCPv6 for config"
        default:
            return ""
        }
    }

    private static func calculatePoolSize(start: String, end: String, ipVersion: Int) -> Int {
        if ipVersion == 4 {
            return calculateIPv4PoolSize(start: start, end: end)
        } else {
            return 1
        }
    }

    private static func calculateIPv4PoolSize(start: String, end: String) -> Int {
        let startOctets = start.split(separator: ".").compactMap { Int($0) }
        let endOctets = end.split(separator: ".").compactMap { Int($0) }

        guard startOctets.count == 4, endOctets.count == 4 else {
            return 0
        }

        let startInt = (startOctets[0] << 24) + (startOctets[1] << 16) + (startOctets[2] << 8) + startOctets[3]
        let endInt = (endOctets[0] << 24) + (endOctets[1] << 16) + (endOctets[2] << 8) + endOctets[3]

        return max(0, endInt - startInt + 1)
    }

    private static func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
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
