import Foundation
import struct OSClient.Port
import OSClient
import SwiftNCurses

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
                                         cachedPorts: [Port], cachedNetworks: [Network],
                                         multiSelectMode: Bool = false, selectedItems: Set<String> = []) async {

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
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
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

    @MainActor
    static func drawFloatingIPDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        floatingIP: FloatingIP,
        cachedServers: [Server],
        cachedPorts: [Port],
        cachedNetworks: [Network],
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let isActive = floatingIP.portId != nil
        let status = isActive ? "ACTIVE" : "AVAILABLE"

        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: floatingIP.id),
            DetailView.buildFieldItem(label: "IP Address", value: floatingIP.floatingIpAddress),
            .field(label: "Status", value: status, style: isActive ? .success : .info),
            DetailView.buildFieldItem(label: "Description", value: floatingIP.description)
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // NAT Intelligence Section
        let natInfo = getNATTypeDescription(isAttached: isActive)
        let natItems: [DetailItem?] = [
            .field(label: "Type", value: natInfo.title, style: natInfo.style),
            .field(label: "Description", value: natInfo.description, style: .info)
        ]
        if let natSection = DetailView.buildSection(title: "NAT Configuration", items: natItems, titleStyle: .accent) {
            sections.append(natSection)
        }

        // Attachment Information Section
        if let portID = floatingIP.portId {
            var attachmentItems: [DetailItem?] = []

            attachmentItems.append(.field(label: "Port ID", value: portID, style: .secondary))

            if let fixedIP = floatingIP.fixedIpAddress {
                attachmentItems.append(.field(label: "Fixed IP Address", value: fixedIP, style: .accent))
            }

            if let port = cachedPorts.first(where: { $0.id == portID }) {
                if let deviceID = port.deviceId {
                    attachmentItems.append(.field(label: "Device ID", value: deviceID, style: .muted))

                    if let server = cachedServers.first(where: { $0.id == deviceID }) {
                        let serverName = server.name ?? "Unnamed Server"
                        attachmentItems.append(.field(label: "Server", value: serverName, style: .secondary))
                        attachmentItems.append(.field(label: "  Server Status", value: server.status?.rawValue ?? "Unknown", style: server.status?.rawValue.lowercased() == "active" ? .success : .warning))
                    }
                }

                if let portName = port.name {
                    attachmentItems.append(.field(label: "Port Name", value: portName, style: .secondary))
                }

                if let deviceOwner = port.deviceOwner {
                    attachmentItems.append(.field(label: "Device Owner", value: deviceOwner, style: .secondary))
                    let ownerDescription = getDeviceOwnerDescription(deviceOwner)
                    if !ownerDescription.isEmpty {
                        attachmentItems.append(.field(label: "  Description", value: ownerDescription, style: .info))
                    }
                }
            }

            if let attachmentSection = DetailView.buildSection(title: "Attachment Information", items: attachmentItems, titleStyle: .accent) {
                sections.append(attachmentSection)
            }
        } else {
            sections.append(DetailSection(
                title: "Attachment Information",
                items: [.field(label: "Status", value: "Not attached to any port", style: .info)]
            ))
        }

        // Router Information Section
        if let routerId = floatingIP.routerId {
            let routerItems: [DetailItem?] = [
                .field(label: "Router ID", value: routerId, style: .secondary),
                .field(label: "Description", value: "Floating IP is routed through this router", style: .info)
            ]

            if let routerSection = DetailView.buildSection(title: "Router Information", items: routerItems) {
                sections.append(routerSection)
            }
        }

        // Network Information Section
        let externalNetwork = cachedNetworks.first(where: { $0.id == floatingIP.floatingNetworkId })
        let networkName = externalNetwork?.name ?? "Unknown"

        var networkItems: [DetailItem?] = [
            .field(label: "External Network", value: networkName, style: .secondary),
            .field(label: "Network ID", value: floatingIP.floatingNetworkId, style: .muted)
        ]

        if let externalNetwork = externalNetwork {
            if let shared = externalNetwork.shared {
                networkItems.append(.field(label: "Shared Network", value: shared ? "Yes" : "No", style: shared ? .info : .secondary))
            }
        }

        if let networkSection = DetailView.buildSection(title: "Network Information", items: networkItems) {
            sections.append(networkSection)
        }

        // DNS Configuration Section
        var dnsItems: [DetailItem?] = []

        if let dnsName = floatingIP.dnsName {
            dnsItems.append(.field(label: "DNS Name", value: dnsName, style: .secondary))
        }

        if let dnsDomain = floatingIP.dnsDomain {
            dnsItems.append(.field(label: "DNS Domain", value: dnsDomain, style: .secondary))
        }

        if let dnsSection = DetailView.buildSection(title: "DNS Configuration", items: dnsItems) {
            sections.append(dnsSection)
        }

        // QoS Section with Intelligence
        if let qosPolicyId = floatingIP.qosPolicyId {
            let qosItems: [DetailItem?] = [
                .field(label: "QoS Policy ID", value: qosPolicyId, style: .secondary),
                .field(label: "Status", value: "QoS policy attached", style: .success),
                .spacer,
                .field(label: "Bandwidth Limiting", value: getQoSBandwidthDescription(), style: .info),
                .field(label: "Note", value: "Check QoS policy details for specific limits", style: .info)
            ]

            if let qosSection = DetailView.buildSection(title: "Quality of Service", items: qosItems, titleStyle: .accent) {
                sections.append(qosSection)
            }
        }

        // Port Status Intelligence Section
        if let portID = floatingIP.portId,
           let port = cachedPorts.first(where: { $0.id == portID }) {
            let portStatusItems = getPortStatusIntelligence(port: port)
            if !portStatusItems.isEmpty {
                sections.append(DetailSection(
                    title: "Port Status Details",
                    items: portStatusItems,
                    titleStyle: .accent
                ))
            }
        }

        // Security Analysis Section
        let port = floatingIP.portId != nil ? cachedPorts.first(where: { $0.id == floatingIP.portId }) : nil
        let securityItems = analyzeSecurityPosture(floatingIP: floatingIP, port: port)
        sections.append(DetailSection(
            title: "Security Analysis",
            items: securityItems,
            titleStyle: .accent
        ))

        // Additional Information Section
        var additionalItems: [DetailItem?] = []

        if let tenantId = floatingIP.tenantId {
            additionalItems.append(.field(label: "Tenant ID", value: tenantId, style: .secondary))
        }

        if let projectId = floatingIP.projectId {
            additionalItems.append(.field(label: "Project ID", value: projectId, style: .secondary))
        }

        if let revisionNumber = floatingIP.revisionNumber {
            additionalItems.append(.field(label: "Revision", value: String(revisionNumber), style: .secondary))
        }

        if let additionalSection = DetailView.buildSection(title: "Additional Information", items: additionalItems) {
            sections.append(additionalSection)
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: floatingIP.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: floatingIP.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Tags Section
        if let tags = floatingIP.tags, !tags.isEmpty {
            let tagItems = tags.map { DetailItem.field(label: "Tag", value: $0, style: .secondary) }
            sections.append(DetailSection(title: "Tags", items: tagItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Floating IP Details: \(floatingIP.floatingIpAddress ?? "Unknown")",
            sections: sections,
            helpText: "Press ESC to return to floating IPs list",
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

    // MARK: - Helper Functions for Enhanced Floating IP Information

    private static func getDeviceOwnerDescription(_ deviceOwner: String) -> String {
        switch deviceOwner {
        case "compute:nova": return "Attached to Nova compute instance"
        case "network:router_interface": return "Router interface port"
        case "network:router_gateway": return "Router external gateway port"
        case "network:dhcp": return "DHCP server port"
        case "network:floatingip": return "Floating IP port"
        case "network:ha_router_replicated_interface": return "HA router replicated interface"
        case "network:router_interface_distributed": return "Distributed router interface"
        case "network:router_centralized_snat": return "Centralized SNAT port for DVR"
        default:
            if deviceOwner.hasPrefix("compute:") {
                return "Nova compute instance in availability zone"
            }
            return ""
        }
    }

    private static func getNATTypeDescription(isAttached: Bool) -> (title: String, description: String, style: TextStyle) {
        if isAttached {
            return (
                "DNAT (Destination NAT) Active",
                "Inbound traffic to this floating IP is translated to the fixed IP",
                .success
            )
        } else {
            return (
                "No NAT Active",
                "Floating IP is unattached - no NAT translation occurring",
                .info
            )
        }
    }

    private static func getQoSBandwidthDescription() -> String {
        return "QoS policy limits bandwidth for this floating IP"
    }

    private static func analyzeSecurityPosture(floatingIP: FloatingIP, port: Port?) -> [DetailItem] {
        var items: [DetailItem] = []

        if floatingIP.portId == nil {
            items.append(.field(
                label: "Security Warning",
                value: "Floating IP is allocated but unattached",
                style: .warning
            ))
            items.append(.field(
                label: "  Risk",
                value: "Unused floating IP consumes public IP space",
                style: .info
            ))
            items.append(.field(
                label: "  Recommendation",
                value: "Consider releasing if not needed",
                style: .info
            ))
        } else {
            items.append(.field(
                label: "Public Internet Exposure",
                value: "This floating IP is accessible from the internet",
                style: .info
            ))

            if let port = port {
                if let securityGroups = port.securityGroups, !securityGroups.isEmpty {
                    items.append(.field(
                        label: "Security Groups",
                        value: "\(securityGroups.count) security group(s) applied",
                        style: .success
                    ))
                    items.append(.field(
                        label: "  Note",
                        value: "Traffic is filtered by security group rules",
                        style: .info
                    ))
                } else {
                    items.append(.field(
                        label: "Security Warning",
                        value: "No security groups found on port",
                        style: .warning
                    ))
                }

                if let portSecurityEnabled = port.portSecurityEnabled {
                    let securityStatus = portSecurityEnabled ? "Enabled" : "Disabled"
                    let securityStyle: TextStyle = portSecurityEnabled ? .success : .error
                    items.append(.field(
                        label: "Port Security",
                        value: securityStatus,
                        style: securityStyle
                    ))
                    if !portSecurityEnabled {
                        items.append(.field(
                            label: "  Warning",
                            value: "Port security disabled - all traffic allowed",
                            style: .error
                        ))
                    }
                }
            }
        }

        items.append(.spacer)
        items.append(.field(
            label: "Best Practices",
            value: "Use security groups to restrict inbound traffic",
            style: .info
        ))
        items.append(.field(
            label: "",
            value: "Only attach floating IPs when external access is needed",
            style: .info
        ))
        items.append(.field(
            label: "",
            value: "Consider using a bastion host for SSH access",
            style: .info
        ))

        return items
    }

    private static func getPortStatusIntelligence(port: Port) -> [DetailItem] {
        var items: [DetailItem] = []

        if let status = port.status {
            let statusStyle: TextStyle = status.uppercased() == "ACTIVE" ? .success : .warning
            items.append(.field(
                label: "Port Status",
                value: status.uppercased(),
                style: statusStyle
            ))

            if status.uppercased() == "DOWN" {
                items.append(.field(
                    label: "  Note",
                    value: "Port is down - traffic will not flow",
                    style: .warning
                ))
            } else if status.uppercased() == "ACTIVE" {
                items.append(.field(
                    label: "  Note",
                    value: "Port is active and forwarding traffic",
                    style: .success
                ))
            }
        }

        if let adminStateUp = port.adminStateUp {
            let adminState = adminStateUp ? "UP" : "DOWN"
            let adminStyle: TextStyle = adminStateUp ? .success : .error
            items.append(.field(
                label: "Admin State",
                value: adminState,
                style: adminStyle
            ))
        }

        if let deviceOwner = port.deviceOwner {
            items.append(.field(
                label: "Port Role",
                value: getDeviceOwnerDescription(deviceOwner),
                style: .info
            ))
        }

        if let macAddress = port.macAddress {
            items.append(.field(
                label: "MAC Address",
                value: macAddress,
                style: .secondary
            ))
        }

        if let fixedIps = port.fixedIps, !fixedIps.isEmpty {
            items.append(.spacer)
            items.append(.field(
                label: "Fixed IPs on Port",
                value: "\(fixedIps.count) IP address(es)",
                style: .info
            ))
            for fixedIp in fixedIps {
                items.append(.field(
                    label: "  IP",
                    value: fixedIp.ipAddress,
                    style: .accent
                ))
            }
        }

        return items
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
        let surface = SwiftNCurses.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.floatingIPCreateMinScreenWidth && height > Self.floatingIPCreateMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.floatingIPCreateBoundsMinWidth, width), height: max(Self.floatingIPCreateBoundsMinHeight, height))
            await SwiftNCurses.render(Text(Self.floatingIPCreateScreenTooSmallText).error(), on: surface, in: errorBounds)
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
        await SwiftNCurses.render(formBuilder.render(), on: surface, in: bounds)

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
                let surface = SwiftNCurses.surface(from: screen)
                let overlayBounds = Rect(x: startCol, y: startRow, width: width, height: height)
                surface.clear(rect: overlayBounds)
                await SwiftNCurses.render(selectorComponent, on: surface, in: overlayBounds)
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
        let surface = SwiftNCurses.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.floatingIPServerSelectionMinScreenWidth && height > Self.floatingIPServerSelectionMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.floatingIPServerSelectionBoundsMinWidth, width), height: max(Self.floatingIPServerSelectionBoundsMinHeight, height))
            await SwiftNCurses.render(Text(Self.floatingIPServerSelectionScreenTooSmallText).error(), on: surface, in: errorBounds)
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
        await SwiftNCurses.render(serverSelectionComponent, on: surface, in: bounds)
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