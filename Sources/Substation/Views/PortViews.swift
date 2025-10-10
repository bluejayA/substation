import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

struct PortViews {

    // MARK: - Port List View

    @MainActor
    static func drawDetailedPortList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                    width: Int32, height: Int32, cachedPorts: [Port],
                                    cachedNetworks: [Network], cachedServers: [Server],
                                    searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                    multiSelectMode: Bool = false, selectedItems: Set<String> = []) async {

        let statusListView = createPortStatusListView(networks: cachedNetworks, servers: cachedServers)
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedPorts,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Port Detail View

    @MainActor
    static func drawPortDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        port: Port,
        cachedNetworks: [Network] = [],
        cachedSubnets: [Subnet] = [],
        cachedSecurityGroups: [SecurityGroup] = [],
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let networkName = cachedNetworks.first(where: { $0.id == port.networkId })?.name ?? "Unknown"

        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: port.id),
            DetailView.buildFieldItem(label: "Name", value: port.name),
            DetailView.buildFieldItem(label: "Description", value: port.description),
            .field(label: "Network", value: "\(networkName) (\(port.networkId))", style: .secondary),
            port.status.map { .field(label: "Status", value: $0, style: $0 == "ACTIVE" ? .success : $0 == "DOWN" ? .error : .warning) },
            port.adminStateUp.map { .field(label: "Admin State", value: $0 ? "UP" : "DOWN", style: $0 ? .success : .error) }
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Network Configuration Section
        var networkConfigItems: [DetailItem?] = []

        if let macAddress = port.macAddress {
            networkConfigItems.append(.field(label: "MAC Address", value: macAddress, style: .secondary))
        }

        if let bindingVnicType = port.bindingVnicType {
            networkConfigItems.append(.field(label: "VNIC Type", value: bindingVnicType, style: .secondary))
            let vnicDescription = getVnicTypeDescription(bindingVnicType)
            if !vnicDescription.isEmpty {
                networkConfigItems.append(.field(label: "  Description", value: vnicDescription, style: .info))
            }
        }

        if let bindingVifType = port.bindingVifType {
            networkConfigItems.append(.field(label: "VIF Type", value: bindingVifType, style: .secondary))
            let vifDescription = getVifTypeDescription(bindingVifType)
            if !vifDescription.isEmpty {
                networkConfigItems.append(.field(label: "  Description", value: vifDescription, style: .info))
            }
        }

        if let bindingHostId = port.bindingHostId {
            networkConfigItems.append(.field(label: "Bound Host", value: bindingHostId, style: .accent))
        }

        if let portSecurityEnabled = port.portSecurityEnabled {
            networkConfigItems.append(.field(label: "Port Security", value: portSecurityEnabled ? "Enabled" : "Disabled", style: portSecurityEnabled ? .success : .warning))
            if !portSecurityEnabled {
                networkConfigItems.append(.field(label: "  Warning", value: "Port security disabled - no security group filtering", style: .warning))
            }
        }

        if let networkConfigSection = DetailView.buildSection(title: "Network Configuration", items: networkConfigItems, titleStyle: .accent) {
            sections.append(networkConfigSection)
        }

        // Fixed IPs Section
        if let fixedIps = port.fixedIps, !fixedIps.isEmpty {
            var ipItems: [DetailItem] = []

            for fixedIP in fixedIps {
                let subnet = cachedSubnets.first(where: { $0.id == fixedIP.subnetId })
                let subnetName = subnet?.name ?? "Unknown"
                let subnetCidr = subnet?.cidr ?? "Unknown"

                ipItems.append(.field(label: "IP Address", value: fixedIP.ipAddress, style: .accent))
                ipItems.append(.field(label: "  Subnet", value: "\(subnetName) (\(subnetCidr))", style: .secondary))
                ipItems.append(.field(label: "  Subnet ID", value: fixedIP.subnetId, style: .muted))
                ipItems.append(.spacer)
            }

            // Remove trailing spacer
            if !ipItems.isEmpty && ipItems.last?.isSpacerType == true {
                ipItems.removeLast()
            }

            sections.append(DetailSection(title: "Fixed IPs", items: ipItems))
        } else {
            sections.append(DetailSection(
                title: "Fixed IPs",
                items: [.field(label: "Status", value: "No IP addresses assigned", style: .warning)]
            ))
        }

        // Device Attachment Section
        var deviceItems: [DetailItem?] = []

        if let deviceId = port.deviceId, !deviceId.isEmpty {
            deviceItems.append(.field(label: "Device ID", value: deviceId, style: .secondary))

            if let deviceOwner = port.deviceOwner {
                deviceItems.append(.field(label: "Device Owner", value: deviceOwner, style: .secondary))
                let ownerDescription = getDeviceOwnerDescription(deviceOwner)
                if !ownerDescription.isEmpty {
                    deviceItems.append(.field(label: "  Description", value: ownerDescription, style: .info))
                }
            }
        } else {
            deviceItems.append(.field(label: "Status", value: "Not attached to any device", style: .muted))
        }

        if let deviceSection = DetailView.buildSection(title: "Device Attachment", items: deviceItems) {
            sections.append(deviceSection)
        }

        // Security Groups Section
        if let securityGroups = port.securityGroups, !securityGroups.isEmpty {
            var sgItems: [DetailItem] = []

            for securityGroupID in securityGroups {
                let securityGroup = cachedSecurityGroups.first(where: { $0.id == securityGroupID })
                let sgName = securityGroup?.name ?? "Unknown"

                sgItems.append(.field(label: "Security Group", value: sgName, style: .secondary))
                sgItems.append(.field(label: "  ID", value: securityGroupID, style: .muted))
                sgItems.append(.spacer)
            }

            // Remove trailing spacer
            if !sgItems.isEmpty && sgItems.last?.isSpacerType == true {
                sgItems.removeLast()
            }

            sections.append(DetailSection(title: "Security Groups", items: sgItems))
        } else if port.portSecurityEnabled == true {
            sections.append(DetailSection(
                title: "Security Groups",
                items: [.field(label: "Warning", value: "No security groups assigned", style: .warning)]
            ))
        }

        // Allowed Address Pairs Section
        if let allowedAddressPairs = port.allowedAddressPairs, !allowedAddressPairs.isEmpty {
            var addressPairItems: [DetailItem] = []

            for pair in allowedAddressPairs {
                addressPairItems.append(.field(label: "IP Address", value: pair.ipAddress, style: .secondary))
                if let macAddress = pair.macAddress {
                    addressPairItems.append(.field(label: "  MAC Address", value: macAddress, style: .muted))
                }
                addressPairItems.append(.spacer)
            }

            // Remove trailing spacer
            if !addressPairItems.isEmpty && addressPairItems.last?.isSpacerType == true {
                addressPairItems.removeLast()
            }

            sections.append(DetailSection(title: "Allowed Address Pairs", items: addressPairItems))
        }

        // QoS Section
        if let qosPolicyId = port.qosPolicyId {
            let qosItems: [DetailItem?] = [
                .field(label: "QoS Policy ID", value: qosPolicyId, style: .secondary),
                .field(label: "Status", value: "QoS policy attached", style: .success)
            ]

            if let qosSection = DetailView.buildSection(title: "Quality of Service", items: qosItems) {
                sections.append(qosSection)
            }
        }

        // Additional Information Section
        var additionalItems: [DetailItem?] = []

        if let tenantId = port.tenantId {
            additionalItems.append(.field(label: "Tenant ID", value: tenantId, style: .secondary))
        }

        if let projectId = port.projectId {
            additionalItems.append(.field(label: "Project ID", value: projectId, style: .secondary))
        }

        if let revisionNumber = port.revisionNumber {
            additionalItems.append(.field(label: "Revision", value: String(revisionNumber), style: .secondary))
        }

        if let propagateUplinkStatus = port.propagateUplinkStatus {
            additionalItems.append(.field(label: "Propagate Uplink Status", value: propagateUplinkStatus ? "Yes" : "No", style: .secondary))
        }

        if let additionalSection = DetailView.buildSection(title: "Additional Information", items: additionalItems) {
            sections.append(additionalSection)
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: port.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: port.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Tags Section
        if let tags = port.tags, !tags.isEmpty {
            let tagItems = tags.map { DetailItem.field(label: "Tag", value: $0, style: .secondary) }
            sections.append(DetailSection(title: "Tags", items: tagItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Port Details: \(port.name ?? "Unnamed Port")",
            sections: sections,
            helpText: "Press ESC to return to ports list",
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

    // MARK: - Helper Functions for Enhanced Port Information

    private static func getVnicTypeDescription(_ vnicType: String) -> String {
        switch vnicType.lowercased() {
        case "normal": return "Standard virtual NIC for instances"
        case "direct": return "SR-IOV direct passthrough to VM"
        case "direct-physical": return "Physical NIC assigned directly to VM"
        case "macvtap": return "Kernel MACVTAP device"
        case "baremetal": return "Bare metal port binding"
        case "virtio-forwarder": return "High-performance virtio forwarder"
        default: return ""
        }
    }

    private static func getVifTypeDescription(_ vifType: String) -> String {
        switch vifType.lowercased() {
        case "ovs": return "Open vSwitch bridge"
        case "bridge": return "Linux bridge"
        case "vhostuser": return "vhost-user interface"
        case "hw_veb": return "Hardware virtual Ethernet bridge"
        case "hostdev": return "Direct device assignment"
        case "binding_failed": return "Port binding failed"
        default: return ""
        }
    }

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

    // MARK: - Port Create View

    // Layout Constants
    private static let portCreateComponentTopPadding: Int32 = 1
    private static let portCreateStatusMessageTopPadding: Int32 = 2
    private static let portCreateStatusMessageLeadingPadding: Int32 = 2
    private static let portCreateValidationErrorLeadingPadding: Int32 = 2
    private static let portCreateLoadingErrorBoundsHeight: Int32 = 6
    private static let portCreateFieldActiveSpacing = "                      "

    // Text Constants
    private static let portCreateFormTitle = "Create New Port"
    private static let portCreateCreatingPortText = "Creating port..."
    private static let portCreateErrorPrefix = "Error: "
    private static let portCreateRequiredFieldSuffix = ": *"
    private static let portCreateOptionalFieldSuffix = " (optional)"

    // Field Display Constants
    private static let portCreateValidationErrorsTitle = "Validation Errors:"
    private static let portCreateValidationErrorPrefix = "- "
    private static let portCreateCheckboxSelectedText = "[X]"
    private static let portCreateCheckboxUnselectedText = "[ ]"
    private static let portCreateEditPromptText = "Press SPACE to edit..."
    private static let portCreateSelectPromptText = "Press LEFT/RIGHT to select"
    private static let portCreateTogglePromptText = "Press SPACE to toggle"

    // Field Label Constants
    private static let portCreateNameFieldLabel = "Port Name"
    private static let portCreateDescriptionFieldLabel = "Description"
    private static let portCreateNetworkFieldLabel = "Network"
    private static let portCreateMacAddressFieldLabel = "MAC Address"
    private static let portCreatePortSecurityFieldLabel = "Port Security"
    private static let portCreateSecurityGroupsFieldLabel = "Security Groups"
    private static let portCreatePortTypeFieldLabel = "Port Type"
    private static let portCreateQosPolicyFieldLabel = "QoS Policy"
    private static let portCreateQosPolicySelectFieldLabel = "QoS Policy Selection"

    // Placeholder Constants
    private static let portCreateNamePlaceholder = "[Enter port name]"
    private static let portCreateDescriptionPlaceholder = "[Enter description]"
    private static let portCreateNetworkPlaceholder = "[Select network]"
    private static let portCreateMacAddressPlaceholder = "[Enter MAC address]"
    private static let portCreateNoNetworksText = "[No networks available]"
    private static let portCreateLoadingSecurityGroupsText = "[Loading security groups...]"
    private static let portCreateLoadingQosPoliciesText = "[Loading QoS policies...]"
    private static let portCreateNoQosPolicySelectedText = "[No QoS policy selected]"

    // UI Component Constants
    private static let portCreateSelectedIndicator = "> "
    private static let portCreateUnselectedIndicator = "  "
    private static let portCreateComponentSpacing: Int32 = 0

    @MainActor
    static func drawPortCreateForm(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                  width: Int32, height: Int32, portCreateForm: PortCreateForm,
                                  portCreateFormState: FormBuilderState,
                                  cachedNetworks: [Network], cachedSecurityGroups: [SecurityGroup],
                                  cachedQoSPolicies: [QoSPolicy] = [], selectedIndex: Int = 0) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        // Check if a selector or multiselect field is active
        if let currentField = portCreateFormState.getCurrentField() {
            if case .selector(let selectorField) = currentField, selectorField.isActive {
                // Render full-screen FormSelector overlay
                if let selectorComponent = FormSelectorRenderer.renderSelector(
                    label: selectorField.label,
                    items: selectorField.items,
                    selectedItemId: selectorField.selectedItemId,
                    highlightedIndex: selectorField.highlightedIndex,
                    scrollOffset: selectorField.scrollOffset,
                    searchQuery: selectorField.searchQuery,
                    columns: selectorField.columns,
                    maxHeight: Int(height)
                ) {
                    surface.clear(rect: bounds)
                    await SwiftTUI.render(selectorComponent, on: surface, in: bounds)
                }
                return
            } else if case .multiSelect(let multiSelectField) = currentField, multiSelectField.isActive {
                // Check if this is the network field - use NetworkSelectionView
                if multiSelectField.id == "network" {
                    await NetworkSelectionView.drawNetworkSelection(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        networks: multiSelectField.items as? [Network] ?? [],
                        selectedNetworkIds: multiSelectField.selectedItemIds,
                        highlightedIndex: multiSelectField.highlightedIndex,
                        scrollOffset: multiSelectField.scrollOffset,
                        searchQuery: multiSelectField.searchQuery
                    )
                    return
                }

                // Render full-screen FormSelector overlay for other multi-select fields
                if let multiSelectorComponent = FormSelectorRenderer.renderMultiSelector(
                    label: multiSelectField.label,
                    items: multiSelectField.items,
                    selectedItemIds: multiSelectField.selectedItemIds,
                    highlightedIndex: multiSelectField.highlightedIndex,
                    scrollOffset: multiSelectField.scrollOffset,
                    searchQuery: multiSelectField.searchQuery,
                    columns: multiSelectField.columns,
                    maxHeight: Int(height)
                ) {
                    surface.clear(rect: bounds)
                    await SwiftTUI.render(multiSelectorComponent, on: surface, in: bounds)
                }
                return
            }
        }

        // Build form fields using FormBuilder
        let fields = portCreateForm.buildFields(
            selectedFieldId: portCreateFormState.getCurrentFieldId(),
            activeFieldId: portCreateFormState.getActiveFieldId(),
            formState: portCreateFormState,
            networks: cachedNetworks,
            securityGroups: cachedSecurityGroups,
            qosPolicies: cachedQoSPolicies
        )

        // Get validation errors
        let errors = portCreateForm.validate(networks: cachedNetworks, securityGroups: cachedSecurityGroups)

        // Create FormBuilder
        let formBuilder = FormBuilder(
            title: Self.portCreateFormTitle,
            fields: fields,
            selectedFieldId: portCreateFormState.getCurrentFieldId(),
            validationErrors: errors,
            showValidationErrors: !errors.isEmpty
        )

        // Render the form
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)
    }

    // MARK: - Component Creation

    private static func getPortCreateVisibleFields(for form: PortCreateForm) -> [PortCreateField] {
        var fields: [PortCreateField] = [.name, .description, .network, .macAddress, .portSecurity]

        if form.portSecurityEnabled {
            fields.append(.securityGroups)
        }

        fields.append(.portType)
        fields.append(.qosPolicy)

        if form.qosPolicyEnabled {
            fields.append(.qosPolicySelect)
        }

        return fields
    }

    private static func createPortCreateFieldComponent(field: PortCreateField, form: PortCreateForm,
                                                      cachedNetworks: [Network],
                                                      cachedSecurityGroups: [SecurityGroup],
                                                      cachedQoSPolicies: [QoSPolicy], width: Int32, isFirstField: Bool) -> any Component {
        let isSelected = form.currentField == field

        switch field {
        case .name:
            return createPortCreateNameField(form: form, isSelected: isSelected, width: width, isFirstField: isFirstField)
        case .description:
            return createPortCreateDescriptionField(form: form, isSelected: isSelected, width: width, isFirstField: isFirstField)
        case .network:
            return createPortCreateNetworkField(form: form, isSelected: isSelected, cachedNetworks: cachedNetworks, isFirstField: isFirstField)
        case .macAddress:
            return createPortCreateMacAddressField(form: form, isSelected: isSelected, width: width, isFirstField: isFirstField)
        case .portSecurity:
            return createPortCreatePortSecurityField(form: form, isSelected: isSelected, isFirstField: isFirstField)
        case .securityGroups:
            return createPortCreateSecurityGroupsField(form: form, isSelected: isSelected, cachedSecurityGroups: cachedSecurityGroups, isFirstField: isFirstField)
        case .portType:
            return createPortCreatePortTypeField(form: form, isSelected: isSelected, isFirstField: isFirstField)
        case .qosPolicy:
            return createPortCreateQosPolicyField(form: form, isSelected: isSelected, isFirstField: isFirstField)
        case .qosPolicySelect:
            return createPortCreateQosPolicySelectField(form: form, isSelected: isSelected, cachedQoSPolicies: cachedQoSPolicies, isFirstField: isFirstField)
        }
    }

    // MARK: - Field Creation Functions

    private static func createPortCreateNameField(form: PortCreateForm, isSelected: Bool, width: Int32, isFirstField: Bool) -> any Component {
        let textField = FormTextField(
            label: Self.portCreateNameFieldLabel,
            value: form.portName,
            placeholder: Self.portCreateNamePlaceholder,
            isRequired: true,
            isSelected: isSelected,
            isActive: form.fieldEditMode && isSelected,
            maxWidth: Int(width) - 10
        )

        if isFirstField {
            return VStack(spacing: 0, children: [
                Text("").padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)),
                textField.render()
            ])
        } else {
            return textField.render()
        }
    }

    private static func createPortCreateDescriptionField(form: PortCreateForm, isSelected: Bool, width: Int32, isFirstField: Bool) -> any Component {
        let textField = FormTextField(
            label: Self.portCreateDescriptionFieldLabel,
            value: form.portDescription,
            placeholder: Self.portCreateDescriptionPlaceholder,
            isRequired: false,
            isSelected: isSelected,
            isActive: form.fieldEditMode && isSelected,
            maxWidth: Int(width) - 10
        )

        if isFirstField {
            return VStack(spacing: 0, children: [
                Text("").padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)),
                textField.render()
            ])
        } else {
            return textField.render()
        }
    }

    private static func createPortCreateNetworkField(form: PortCreateForm, isSelected: Bool, cachedNetworks: [Network], isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.portCreateNetworkFieldLabel)\(Self.portCreateRequiredFieldSuffix): (\(Self.portCreateSelectPromptText))"
        let indicator = isSelected ? Self.portCreateSelectedIndicator : Self.portCreateUnselectedIndicator

        let displayText: String
        let fieldStyle: TextStyle
        if cachedNetworks.isEmpty {
            displayText = Self.portCreateNoNetworksText
            fieldStyle = .error
        } else if form.selectedNetworkIndex < cachedNetworks.count {
            let selectedNetwork = cachedNetworks[form.selectedNetworkIndex]
            let choiceIndicator = cachedNetworks.count > 1 ? " (\(form.selectedNetworkIndex + 1)/\(cachedNetworks.count))" : ""
            displayText = "\(selectedNetwork.name ?? "Unknown")\(choiceIndicator)"
            fieldStyle = isSelected ? .warning : .success
        } else {
            displayText = Self.portCreateNetworkPlaceholder
            fieldStyle = isSelected ? .warning : .info
        }

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.portCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createPortCreateMacAddressField(form: PortCreateForm, isSelected: Bool, width: Int32, isFirstField: Bool) -> any Component {
        let textField = FormTextField(
            label: Self.portCreateMacAddressFieldLabel,
            value: form.macAddress,
            placeholder: Self.portCreateMacAddressPlaceholder,
            isRequired: false,
            isSelected: isSelected,
            isActive: form.fieldEditMode && isSelected,
            maxWidth: Int(width) - 10
        )

        if isFirstField {
            return VStack(spacing: 0, children: [
                Text("").padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)),
                textField.render()
            ])
        } else {
            return textField.render()
        }
    }

    private static func createPortCreatePortSecurityField(form: PortCreateForm, isSelected: Bool, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.portCreatePortSecurityFieldLabel): (\(Self.portCreateTogglePromptText))"
        let indicator = isSelected ? Self.portCreateSelectedIndicator : Self.portCreateUnselectedIndicator

        let checkboxText = form.portSecurityEnabled ? Self.portCreateCheckboxSelectedText : Self.portCreateCheckboxUnselectedText
        let statusText = form.portSecurityEnabled ? "Enabled" : "Disabled"
        let displayText = "\(checkboxText) \(statusText)"

        let fieldStyle: TextStyle = isSelected ? .warning : .secondary

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.portCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createPortCreateSecurityGroupsField(form: PortCreateForm, isSelected: Bool, cachedSecurityGroups: [SecurityGroup], isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.portCreateSecurityGroupsFieldLabel): (\(Self.portCreateSelectPromptText))"
        let indicator = isSelected ? Self.portCreateSelectedIndicator : Self.portCreateUnselectedIndicator

        let displayText: String
        let fieldStyle: TextStyle
        if cachedSecurityGroups.isEmpty {
            displayText = Self.portCreateLoadingSecurityGroupsText
            fieldStyle = .info
        } else {
            let selectedCount = form.selectedSecurityGroupIDs.count
            let totalCount = cachedSecurityGroups.count
            displayText = "\(selectedCount)/\(totalCount) groups selected"
            fieldStyle = isSelected ? .warning : .secondary
        }

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.portCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createPortCreatePortTypeField(form: PortCreateForm, isSelected: Bool, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.portCreatePortTypeFieldLabel): (\(Self.portCreateSelectPromptText))"
        let indicator = isSelected ? Self.portCreateSelectedIndicator : Self.portCreateUnselectedIndicator

        let portType = form.getSelectedPortType()
        let displayText = portType.displayName
        let fieldStyle: TextStyle = isSelected ? .warning : .secondary

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.portCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createPortCreateQosPolicyField(form: PortCreateForm, isSelected: Bool, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.portCreateQosPolicyFieldLabel): (\(Self.portCreateTogglePromptText))"
        let indicator = isSelected ? Self.portCreateSelectedIndicator : Self.portCreateUnselectedIndicator

        let checkboxText = form.qosPolicyEnabled ? Self.portCreateCheckboxSelectedText : Self.portCreateCheckboxUnselectedText
        let statusText = form.qosPolicyEnabled ? "Enabled" : "Disabled"
        let displayText = "\(checkboxText) \(statusText)"

        let fieldStyle: TextStyle = isSelected ? .warning : .secondary

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.portCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createPortCreateQosPolicySelectField(form: PortCreateForm, isSelected: Bool, cachedQoSPolicies: [QoSPolicy], isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.portCreateQosPolicySelectFieldLabel): (\(Self.portCreateSelectPromptText))"
        let indicator = isSelected ? Self.portCreateSelectedIndicator : Self.portCreateUnselectedIndicator

        let displayText: String
        let fieldStyle: TextStyle
        if cachedQoSPolicies.isEmpty {
            displayText = Self.portCreateLoadingQosPoliciesText
            fieldStyle = .info
        } else if form.selectedQosPolicyIndex < cachedQoSPolicies.count {
            let selectedPolicy = cachedQoSPolicies[form.selectedQosPolicyIndex]
            let choiceIndicator = cachedQoSPolicies.count > 1 ? " (\(form.selectedQosPolicyIndex + 1)/\(cachedQoSPolicies.count))" : ""
            displayText = "\(selectedPolicy.name ?? "Unknown")\(choiceIndicator)"
            fieldStyle = isSelected ? .warning : .success
        } else {
            displayText = Self.portCreateNoQosPolicySelectedText
            fieldStyle = isSelected ? .warning : .info
        }

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.portCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.portCreateComponentTopPadding, trailing: 0))
        ])
    }

    // MARK: - Helper Functions for Name Resolution

    private static func resolveNetworkInfo(networkID: String, cachedNetworks: [Network]) -> String {
        if let network = cachedNetworks.first(where: { $0.id == networkID }) {
            return "\(network.name ?? "Unknown") (\(networkID))"
        } else {
            return networkID // Fallback to ID only
        }
    }

    private static func resolveSubnetInfo(subnetID: String, cachedSubnets: [Subnet]) -> String {
        if let subnet = cachedSubnets.first(where: { $0.id == subnetID }) {
            let subnetName = subnet.name ?? "Unnamed"
            return "\(subnetName) (\(subnetID))"
        } else {
            return subnetID // Fallback to ID only
        }
    }

    private static func resolveSecurityGroupInfo(securityGroupID: String, cachedSecurityGroups: [SecurityGroup]) -> String {
        if let securityGroup = cachedSecurityGroups.first(where: { $0.id == securityGroupID }) {
            return "\(securityGroup.name ?? "Unknown") (\(securityGroupID))"
        } else {
            return securityGroupID // Fallback to ID only
        }
    }
}