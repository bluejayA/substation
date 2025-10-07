import Foundation
import OSClient
import SwiftTUI

struct NetworkViews {
    @MainActor
    static func drawDetailedNetworkList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                      width: Int32, height: Int32, cachedNetworks: [Network],
                                      searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                       dataManager: DataManager? = nil,
                                      virtualScrollManager: VirtualScrollManager<Network>? = nil,
                                      multiSelectMode: Bool = false, selectedItems: Set<String> = []) async {

        let statusListView = createNetworkStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedNetworks,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            dataManager: dataManager,
            virtualScrollManager: virtualScrollManager,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Network Detail View

    @MainActor
    static func drawNetworkDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        network: Network,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: network.id),
            DetailView.buildFieldItem(label: "Name", value: network.name),
            DetailView.buildFieldItem(label: "Description", value: network.description),
            network.status.map { .field(label: "Status", value: $0, style: $0.lowercased() == "active" ? .success : $0.lowercased().contains("error") ? .error : .warning) },
            network.adminStateUp.map { .field(label: "Admin State", value: $0 ? "UP" : "DOWN", style: $0 ? .success : .error) }
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Network Configuration Section
        var configItems: [DetailItem?] = []

        if let shared = network.shared {
            configItems.append(.field(label: "Shared", value: shared ? "Yes" : "No", style: shared ? .success : .secondary))
            if shared {
                configItems.append(.field(label: "  Description", value: "Available to all projects", style: .info))
            } else {
                configItems.append(.field(label: "  Description", value: "Private to project", style: .info))
            }
        }

        if let external = network.external {
            configItems.append(.field(label: "External", value: external ? "Yes" : "No", style: external ? .success : .secondary))
            if external {
                configItems.append(.field(label: "  Description", value: "Can be used as router gateway", style: .info))
            }
        }

        if let mtu = network.mtu {
            configItems.append(.field(label: "MTU", value: String(mtu), style: .secondary))
            let mtuAssessment = getMTUAssessment(mtu)
            if !mtuAssessment.isEmpty {
                configItems.append(.field(label: "  Description", value: mtuAssessment, style: .info))
            }
        }

        if let portSecurityEnabled = network.portSecurityEnabled {
            configItems.append(.field(label: "Port Security", value: portSecurityEnabled ? "Enabled" : "Disabled", style: portSecurityEnabled ? .success : .warning))
            if !portSecurityEnabled {
                configItems.append(.field(label: "  Warning", value: "Security groups disabled by default on ports", style: .warning))
            }
        }

        if let configSection = DetailView.buildSection(title: "Network Configuration", items: configItems, titleStyle: .accent) {
            sections.append(configSection)
        }

        // Provider Network Section
        var providerItems: [DetailItem?] = []

        if let providerNetworkType = network.providerNetworkType {
            providerItems.append(.field(label: "Network Type", value: providerNetworkType, style: .secondary))
            let typeDescription = getProviderNetworkTypeDescription(providerNetworkType)
            if !typeDescription.isEmpty {
                providerItems.append(.field(label: "  Description", value: typeDescription, style: .info))
            }
        }

        if let providerPhysicalNetwork = network.providerPhysicalNetwork {
            providerItems.append(.field(label: "Physical Network", value: providerPhysicalNetwork, style: .secondary))
        }

        if let providerSegmentationId = network.providerSegmentationId {
            providerItems.append(.field(label: "Segmentation ID", value: String(providerSegmentationId), style: .secondary))
            if let networkType = network.providerNetworkType {
                let segmentDescription = getSegmentationDescription(networkType, id: providerSegmentationId)
                if !segmentDescription.isEmpty {
                    providerItems.append(.field(label: "  Description", value: segmentDescription, style: .info))
                }
            }
        }

        if let providerSection = DetailView.buildSection(title: "Provider Network", items: providerItems) {
            sections.append(providerSection)
        }

        // Network Segments Section
        if let segments = network.segments, !segments.isEmpty {
            var segmentItems: [DetailItem] = []

            for (index, segment) in segments.enumerated() {
                segmentItems.append(.field(label: "Segment \(index + 1)", value: "", style: .accent))

                if let networkType = segment.providerNetworkType {
                    segmentItems.append(.field(label: "  Network Type", value: networkType, style: .secondary))
                }

                if let physicalNetwork = segment.providerPhysicalNetwork {
                    segmentItems.append(.field(label: "  Physical Network", value: physicalNetwork, style: .secondary))
                }

                if let segmentationId = segment.providerSegmentationId {
                    segmentItems.append(.field(label: "  Segmentation ID", value: String(segmentationId), style: .secondary))
                }

                segmentItems.append(.spacer)
            }

            // Remove trailing spacer
            if !segmentItems.isEmpty && segmentItems.last?.isSpacerType == true {
                segmentItems.removeLast()
            }

            sections.append(DetailSection(title: "Network Segments", items: segmentItems))
        }

        // Subnets Section
        if let subnets = network.subnets, !subnets.isEmpty {
            let subnetItems = subnets.map { DetailItem.field(label: "Subnet ID", value: $0, style: .secondary) }
            sections.append(DetailSection(title: "Subnets", items: subnetItems))
        } else {
            sections.append(DetailSection(
                title: "Subnets",
                items: [.field(label: "Status", value: "No subnets configured", style: .warning)]
            ))
        }

        // DNS Configuration Section
        var dnsItems: [DetailItem?] = []

        if let dnsName = network.dnsName {
            dnsItems.append(.field(label: "DNS Name", value: dnsName, style: .secondary))
        }

        if let dnsDomain = network.dnsDomain {
            dnsItems.append(.field(label: "DNS Domain", value: dnsDomain, style: .secondary))
        }

        if let dnsSection = DetailView.buildSection(title: "DNS Configuration", items: dnsItems) {
            sections.append(dnsSection)
        }

        // Address Scopes Section
        var addressScopeItems: [DetailItem?] = []

        if let ipv4AddressScope = network.ipv4AddressScope {
            addressScopeItems.append(.field(label: "IPv4 Address Scope", value: ipv4AddressScope, style: .secondary))
        }

        if let ipv6AddressScope = network.ipv6AddressScope {
            addressScopeItems.append(.field(label: "IPv6 Address Scope", value: ipv6AddressScope, style: .secondary))
        }

        if let addressScopeSection = DetailView.buildSection(title: "Address Scopes", items: addressScopeItems) {
            sections.append(addressScopeSection)
        }

        // Availability Zones Section
        var azItems: [DetailItem?] = []

        if let availabilityZones = network.availabilityZones, !availabilityZones.isEmpty {
            let azList = availabilityZones.joined(separator: ", ")
            azItems.append(.field(label: "Availability Zones", value: azList, style: .success))
        }

        if let availabilityZoneHints = network.availabilityZoneHints, !availabilityZoneHints.isEmpty {
            let hintsList = availabilityZoneHints.joined(separator: ", ")
            azItems.append(.field(label: "AZ Hints", value: hintsList, style: .secondary))
        }

        if let azSection = DetailView.buildSection(title: "Availability Zones", items: azItems) {
            sections.append(azSection)
        }

        // QoS Section
        if let qosPolicyId = network.qosPolicyId {
            let qosItems: [DetailItem?] = [
                .field(label: "QoS Policy ID", value: qosPolicyId, style: .secondary),
                .field(label: "Status", value: "QoS policy attached to network", style: .success)
            ]

            if let qosSection = DetailView.buildSection(title: "Quality of Service", items: qosItems) {
                sections.append(qosSection)
            }
        }

        // Additional Information Section
        var additionalItems: [DetailItem?] = []

        if let tenantId = network.tenantId {
            additionalItems.append(.field(label: "Tenant ID", value: tenantId, style: .secondary))
        }

        if let projectId = network.projectId {
            additionalItems.append(.field(label: "Project ID", value: projectId, style: .secondary))
        }

        if let revisionNumber = network.revisionNumber {
            additionalItems.append(.field(label: "Revision", value: String(revisionNumber), style: .secondary))
        }

        if let additionalSection = DetailView.buildSection(title: "Additional Information", items: additionalItems) {
            sections.append(additionalSection)
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: network.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: network.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Tags Section
        if let tags = network.tags, !tags.isEmpty {
            let tagItems = tags.map { DetailItem.field(label: "Tag", value: $0, style: .secondary) }
            sections.append(DetailSection(title: "Tags", items: tagItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Network Details: \(network.name ?? "Unnamed Network")",
            sections: sections,
            helpText: "Press ESC to return to networks list",
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

    // MARK: - Helper Functions for Enhanced Network Information

    private static func getProviderNetworkTypeDescription(_ networkType: String) -> String {
        switch networkType.lowercased() {
        case "flat": return "Flat network without VLAN tagging"
        case "vlan": return "VLAN-based network isolation"
        case "vxlan": return "VXLAN overlay network"
        case "gre": return "GRE tunnel-based network"
        case "geneve": return "Geneve overlay network"
        case "local": return "Local network isolated to single host"
        default: return ""
        }
    }

    private static func getSegmentationDescription(_ networkType: String, id: Int) -> String {
        switch networkType.lowercased() {
        case "vlan": return "VLAN ID: \(id) (1-4094)"
        case "vxlan": return "VNI: \(id) (VXLAN Network Identifier)"
        case "gre": return "GRE Key: \(id)"
        case "geneve": return "VNI: \(id) (Geneve Network Identifier)"
        default: return "Segmentation ID: \(id)"
        }
    }

    private static func getMTUAssessment(_ mtu: Int) -> String {
        switch mtu {
        case 1500: return "Standard Ethernet MTU"
        case 9000...9216: return "Jumbo frames enabled"
        case 1400...1499: return "Reduced for overlay tunneling"
        case 1280: return "IPv6 minimum MTU"
        default: return "Custom MTU: \(mtu)"
        }
    }

    // MARK: - Network Create View

    // Layout Constants
    private static let componentTopPadding: Int32 = 1
    private static let statusMessageTopPadding: Int32 = 2
    private static let statusMessageLeadingPadding: Int32 = 2
    private static let validationErrorLeadingPadding: Int32 = 2
    private static let loadingErrorBoundsHeight: Int32 = 6
    private static let fieldActiveSpacing = "                      "

    // Text Constants
    private static let formTitle = "Create New Network"
    private static let creatingNetworkText = "Creating network..."
    private static let errorPrefix = "Error: "
    private static let requiredFieldSuffix = ": *"
    private static let optionalFieldSuffix = " (optional)"

    // Field Display Constants
    private static let validationErrorsTitle = "Validation Errors:"
    private static let validationErrorPrefix = "- "
    private static let checkboxSelectedText = "[X]"
    private static let checkboxUnselectedText = "[ ]"
    private static let editPromptText = "Press SPACE to edit..."
    private static let togglePromptText = "Press SPACE to toggle"

    // Field Label Constants
    private static let networkNameFieldLabel = "Network Name"
    private static let descriptionFieldLabel = "Description"
    private static let mtuFieldLabel = "MTU"
    private static let portSecurityFieldLabel = "Port Security"

    // Placeholder Constants
    private static let networkNamePlaceholder = "[Enter network name]"
    private static let descriptionPlaceholder = "[Optional description]"
    private static let mtuPlaceholder = "[Enter MTU (68-9000)]"

    // UI Component Constants
    private static let selectedIndicator = "> "
    private static let unselectedIndicator = "  "
    private static let componentSpacing: Int32 = 0
    private static let networkCreateMinScreenWidth: Int32 = 10
    private static let networkCreateMinScreenHeight: Int32 = 10
    private static let networkCreateBoundsMinWidth: Int32 = 1
    private static let networkCreateBoundsMinHeight: Int32 = 1
    private static let networkCreateScreenTooSmallText = "Screen too small for network create form"
    private static let networkCreateFormTitle = "Create New Network"

    @MainActor
    static func drawNetworkCreate(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                width: Int32, height: Int32, networkCreateForm: NetworkCreateForm,
                                networkCreateFormState: FormBuilderState) async {

        let surface = SwiftTUI.surface(from: screen)

        guard width > Self.networkCreateMinScreenWidth && height > Self.networkCreateMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.networkCreateBoundsMinWidth, width), height: max(Self.networkCreateBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.networkCreateScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        let fields = networkCreateForm.buildFields(
            selectedFieldId: networkCreateFormState.getCurrentFieldId(),
            activeFieldId: networkCreateFormState.getActiveFieldId(),
            formState: networkCreateFormState
        )

        let validationErrors = networkCreateForm.validateForm()

        let formBuilder = FormBuilder(
            title: Self.networkCreateFormTitle,
            fields: fields,
            selectedFieldId: networkCreateFormState.getCurrentFieldId(),
            validationErrors: validationErrors,
            showValidationErrors: !validationErrors.isEmpty
        )

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)
    }

}