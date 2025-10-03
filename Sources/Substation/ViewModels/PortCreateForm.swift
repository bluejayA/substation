import Foundation
import OSClient

enum PortCreateField: CaseIterable {
    case name, description, network, macAddress, portSecurity, securityGroups, portType, qosPolicy, qosPolicySelect

    var title: String {
        switch self {
        case .name: return "Port Name"
        case .description: return "Description (Optional)"
        case .network: return "Network"
        case .macAddress: return "MAC Address (Optional)"
        case .portSecurity: return "Port Security"
        case .securityGroups: return "Security Groups"
        case .portType: return "Port Type"
        case .qosPolicy: return "QoS Policy"
        case .qosPolicySelect: return "QoS Policy Selection"
        }
    }
}

struct PortCreateForm {
    var portName: String = ""
    var portDescription: String = ""
    var selectedNetworkID: String?
    var selectedNetworkIndex: Int = 0
    var networkSelectionMode: Bool = false
    var macAddress: String = ""
    var portSecurityEnabled: Bool = true
    var selectedSecurityGroupIDs: Set<String> = []
    var selectedSecurityGroupIndices: Set<Int> = []
    var securityGroupSelectionMode: Bool = false
    var selectedSecurityGroupIndex: Int = 0
    var selectedPortTypeIndex: Int = 0 // Default to normal
    var qosPolicyEnabled: Bool = false
    var selectedQosPolicyIndex: Int = 0

    var currentField: PortCreateField = .name
    var fieldEditMode: Bool = false

    mutating func nextField() {
        let visibleFields = getVisibleFields()
        if let currentIndex = visibleFields.firstIndex(of: currentField) {
            let nextIndex = (currentIndex + 1) % visibleFields.count
            currentField = visibleFields[nextIndex]
        }
        fieldEditMode = false
    }

    mutating func previousField() {
        let visibleFields = getVisibleFields()
        if let currentIndex = visibleFields.firstIndex(of: currentField) {
            let prevIndex = currentIndex == 0 ? visibleFields.count - 1 : currentIndex - 1
            currentField = visibleFields[prevIndex]
        }
        fieldEditMode = false
    }

    func getVisibleFields() -> [PortCreateField] {
        var fields: [PortCreateField] = [.name, .description, .network, .macAddress, .portSecurity]

        if portSecurityEnabled {
            fields.append(.securityGroups)
        }

        fields.append(.portType)
        fields.append(.qosPolicy)

        if qosPolicyEnabled {
            fields.append(.qosPolicySelect)
        }

        return fields
    }

    mutating func togglePortSecurity() {
        portSecurityEnabled.toggle()
        if !portSecurityEnabled {
            selectedSecurityGroupIDs.removeAll()
            selectedSecurityGroupIndices.removeAll()
        }
    }

    mutating func toggleQosPolicy() {
        qosPolicyEnabled.toggle()
        if !qosPolicyEnabled {
            selectedQosPolicyIndex = 0
        }
    }

    mutating func toggleSecurityGroup(_ index: Int) {
        if selectedSecurityGroupIndices.contains(index) {
            selectedSecurityGroupIndices.remove(index)
        } else {
            selectedSecurityGroupIndices.insert(index)
        }
    }

    func getSelectedPortType() -> PortType {
        return PortType.allCases[selectedPortTypeIndex]
    }

    mutating func nextPortType() {
        selectedPortTypeIndex = (selectedPortTypeIndex + 1) % PortType.allCases.count
    }

    mutating func previousPortType() {
        selectedPortTypeIndex = selectedPortTypeIndex == 0 ? PortType.allCases.count - 1 : selectedPortTypeIndex - 1
    }

    mutating func toggleNetworkSelection(networkID: String) {
        if selectedNetworkID == networkID {
            selectedNetworkID = nil
        } else {
            selectedNetworkID = networkID
        }
    }

    mutating func enterNetworkSelectionMode() {
        networkSelectionMode = true
    }

    mutating func exitNetworkSelectionMode(networks: [Network]) {
        networkSelectionMode = false
        if let selectedID = selectedNetworkID,
           let index = networks.firstIndex(where: { $0.id == selectedID }) {
            selectedNetworkIndex = index
        }
    }

    mutating func toggleSecurityGroupSelection(securityGroupID: String) {
        if selectedSecurityGroupIDs.contains(securityGroupID) {
            selectedSecurityGroupIDs.remove(securityGroupID)
        } else {
            selectedSecurityGroupIDs.insert(securityGroupID)
        }
    }

    mutating func enterSecurityGroupSelectionMode() {
        securityGroupSelectionMode = true
    }

    mutating func exitSecurityGroupSelectionMode() {
        securityGroupSelectionMode = false
    }

    /// Validate the form and return validation errors if any
    func validate(networks: [Network], securityGroups: [SecurityGroup]) -> [String] {
        var errors: [String] = []

        let trimmedName = portName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append("Port name is required")
        } else {
            // Validate name contains only allowed characters for OpenStack ports
            let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@._-")
            if trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
                errors.append("Port name can only contain letters, numbers, and @._- characters")
            }
        }

        if networks.isEmpty {
            errors.append("No networks available")
        } else if selectedNetworkID == nil {
            errors.append("Network selection is required")
        } else if !networks.contains(where: { $0.id == selectedNetworkID }) {
            errors.append("Selected network is invalid")
        }

        let trimmedMac = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMac.isEmpty {
            // Validate MAC address format (XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX)
            let macPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
            let macRegex = try? NSRegularExpression(pattern: macPattern)
            if macRegex?.firstMatch(in: trimmedMac, range: NSRange(location: 0, length: trimmedMac.count)) == nil {
                errors.append("MAC address must be in format XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX")
            }
        }

        if portSecurityEnabled && selectedSecurityGroupIDs.isEmpty {
            errors.append("At least one security group must be selected when port security is enabled")
        }

        return errors
    }

    /// Get the trimmed port name
    func getTrimmedName() -> String {
        return portName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get the trimmed description (can be empty)
    func getTrimmedDescription() -> String {
        return portDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get the trimmed MAC address (can be empty)
    func getTrimmedMacAddress() -> String {
        return macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get selected security group IDs
    func getSelectedSecurityGroupIds(securityGroups: [SecurityGroup]) -> [String] {
        return Array(selectedSecurityGroupIDs)
    }

    // MARK: - FormBuilder Integration

    func buildFields(
        selectedFieldId: String?,
        activeFieldId: String?,
        formState: FormBuilderState,
        networks: [Network],
        securityGroups: [SecurityGroup],
        qosPolicies: [QoSPolicy]
    ) -> [FormField] {
        var fields: [FormField] = []

        // Name Field (Text)
        let nameFieldId = PortCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameFieldId,
            label: PortCreateField.name.title,
            value: portName,
            placeholder: "Enter port name",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameFieldId,
            isActive: activeFieldId == nameFieldId,
            cursorPosition: formState.textFieldStates[nameFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        // Description Field (Text)
        let descFieldId = PortCreateFieldId.description.rawValue
        fields.append(.text(FormFieldText(
            id: descFieldId,
            label: PortCreateField.description.title,
            value: portDescription,
            placeholder: "Enter optional description",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == descFieldId,
            isActive: activeFieldId == descFieldId,
            cursorPosition: formState.textFieldStates[descFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        // Network Field (Multi-Select with single selection constraint)
        let networkFieldId = PortCreateFieldId.network.rawValue
        let selectedNetworkIds: Set<String> = selectedNetworkID.map { Set([$0]) } ?? []
        fields.append(.multiSelect(FormFieldMultiSelect(
            id: networkFieldId,
            label: PortCreateField.network.title,
            items: networks,
            selectedItemIds: selectedNetworkIds,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == networkFieldId,
            isActive: activeFieldId == networkFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "NAME", width: 30) { item in
                    (item as? Network)?.name ?? ""
                },
                FormSelectorItemColumn(header: "ID", width: 36) { item in
                    (item as? Network)?.id ?? ""
                }
            ],
            searchQuery: formState.selectorStates[networkFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[networkFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[networkFieldId]?.scrollOffset ?? 0,
            minSelections: 1,
            maxSelections: 1
        )))

        // MAC Address Field (Text)
        let macFieldId = PortCreateFieldId.macAddress.rawValue
        fields.append(.text(FormFieldText(
            id: macFieldId,
            label: PortCreateField.macAddress.title,
            value: macAddress,
            placeholder: "XX:XX:XX:XX:XX:XX (optional)",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == macFieldId,
            isActive: activeFieldId == macFieldId,
            cursorPosition: formState.textFieldStates[macFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 20,
            maxLength: 17
        )))

        // Port Security Field (Toggle)
        let securityFieldId = PortCreateFieldId.portSecurity.rawValue
        fields.append(.toggle(FormFieldToggle(
            id: securityFieldId,
            label: PortCreateField.portSecurity.title,
            value: portSecurityEnabled,
            isVisible: true,
            isSelected: selectedFieldId == securityFieldId,
            enabledLabel: "Enabled",
            disabledLabel: "Disabled"
        )))

        // Security Groups Field (Multi-Select) - Only if port security is enabled
        if portSecurityEnabled {
            let sgFieldId = PortCreateFieldId.securityGroups.rawValue
            fields.append(.multiSelect(FormFieldMultiSelect(
                id: sgFieldId,
                label: PortCreateField.securityGroups.title,
                items: securityGroups,
                selectedItemIds: selectedSecurityGroupIDs,
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == sgFieldId,
                isActive: activeFieldId == sgFieldId,
                validationError: nil,
                columns: [
                    FormSelectorItemColumn(header: "NAME", width: 30) { item in
                        (item as? SecurityGroup)?.name ?? ""
                    },
                    FormSelectorItemColumn(header: "DESCRIPTION", width: 40) { item in
                        (item as? SecurityGroup)?.description ?? ""
                    }
                ],
                searchQuery: formState.selectorStates[sgFieldId]?.searchQuery,
                highlightedIndex: formState.selectorStates[sgFieldId]?.highlightedIndex ?? 0,
                scrollOffset: formState.selectorStates[sgFieldId]?.scrollOffset ?? 0,
                minSelections: 1,
                maxSelections: nil
            )))
        }

        // Port Type Field (Selector)
        let portTypeFieldId = PortCreateFieldId.portType.rawValue
        let portTypeItems = PortType.allCases.map { $0 as any FormSelectorItem }
        let selectedPortType = getSelectedPortType()
        fields.append(.selector(FormFieldSelector(
            id: portTypeFieldId,
            label: PortCreateField.portType.title,
            items: portTypeItems,
            selectedItemId: selectedPortType.rawValue,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == portTypeFieldId,
            isActive: activeFieldId == portTypeFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "TYPE", width: 20) { item in
                    (item as? PortType)?.displayName ?? ""
                },
                FormSelectorItemColumn(header: "DESCRIPTION", width: 50) { item in
                    (item as? PortType)?.description ?? ""
                }
            ],
            searchQuery: formState.selectorStates[portTypeFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[portTypeFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[portTypeFieldId]?.scrollOffset ?? 0
        )))

        // QoS Policy Toggle Field
        let qosFieldId = PortCreateFieldId.qosPolicy.rawValue
        fields.append(.toggle(FormFieldToggle(
            id: qosFieldId,
            label: PortCreateField.qosPolicy.title,
            value: qosPolicyEnabled,
            isVisible: true,
            isSelected: selectedFieldId == qosFieldId,
            enabledLabel: "Enabled",
            disabledLabel: "Disabled"
        )))

        // QoS Policy Selection Field - Only if QoS is enabled
        if qosPolicyEnabled && !qosPolicies.isEmpty {
            let qosSelectFieldId = PortCreateFieldId.qosPolicySelect.rawValue
            let selectedQosPolicy = qosPolicies.indices.contains(selectedQosPolicyIndex) ? qosPolicies[selectedQosPolicyIndex] : nil
            fields.append(.selector(FormFieldSelector(
                id: qosSelectFieldId,
                label: PortCreateField.qosPolicySelect.title,
                items: qosPolicies,
                selectedItemId: selectedQosPolicy?.id,
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == qosSelectFieldId,
                isActive: activeFieldId == qosSelectFieldId,
                validationError: nil,
                columns: [
                    FormSelectorItemColumn(header: "NAME", width: 30) { item in
                        (item as? QoSPolicy)?.name ?? ""
                    },
                    FormSelectorItemColumn(header: "ID", width: 36) { item in
                        (item as? QoSPolicy)?.id ?? ""
                    }
                ],
                searchQuery: formState.selectorStates[qosSelectFieldId]?.searchQuery,
                highlightedIndex: formState.selectorStates[qosSelectFieldId]?.highlightedIndex ?? 0,
                scrollOffset: formState.selectorStates[qosSelectFieldId]?.scrollOffset ?? 0
            )))
        }

        return fields
    }

    mutating func updateFromFormState(_ formState: FormBuilderState, networks: [Network], securityGroups: [SecurityGroup], qosPolicies: [QoSPolicy]) {
        let fields = formState.fields

        for field in fields {
            switch field {
            case .text(let textField):
                switch textField.id {
                case PortCreateFieldId.name.rawValue:
                    self.portName = textField.value
                case PortCreateFieldId.description.rawValue:
                    self.portDescription = textField.value
                case PortCreateFieldId.macAddress.rawValue:
                    self.macAddress = textField.value
                default:
                    break
                }

            case .selector(let selectorField):
                switch selectorField.id {
                case PortCreateFieldId.portType.rawValue:
                    if let selectedId = selectorField.selectedItemId,
                       let portType = PortType(rawValue: selectedId),
                       let index = PortType.allCases.firstIndex(of: portType) {
                        self.selectedPortTypeIndex = index
                    }

                case PortCreateFieldId.qosPolicySelect.rawValue:
                    if let selectedId = selectorField.selectedItemId,
                       let index = qosPolicies.firstIndex(where: { $0.id == selectedId }) {
                        self.selectedQosPolicyIndex = index
                    }

                default:
                    break
                }

            case .multiSelect(let multiSelectField):
                switch multiSelectField.id {
                case PortCreateFieldId.network.rawValue:
                    // Extract single network ID from Set (maxSelections: 1)
                    self.selectedNetworkID = multiSelectField.selectedItemIds.first
                    if let selectedId = multiSelectField.selectedItemIds.first,
                       let index = networks.firstIndex(where: { $0.id == selectedId }) {
                        self.selectedNetworkIndex = index
                    }

                case PortCreateFieldId.securityGroups.rawValue:
                    self.selectedSecurityGroupIDs = multiSelectField.selectedItemIds
                    // Update indices based on IDs
                    self.selectedSecurityGroupIndices = Set(
                        securityGroups.enumerated().compactMap { index, sg in
                            multiSelectField.selectedItemIds.contains(sg.id) ? index : nil
                        }
                    )

                default:
                    break
                }

            case .toggle(let toggleField):
                switch toggleField.id {
                case PortCreateFieldId.portSecurity.rawValue:
                    self.portSecurityEnabled = toggleField.value

                case PortCreateFieldId.qosPolicy.rawValue:
                    self.qosPolicyEnabled = toggleField.value

                default:
                    break
                }

            default:
                break
            }
        }

        // Update navigation state
        if let currentFieldId = formState.getCurrentFieldId() {
            switch currentFieldId {
            case PortCreateFieldId.name.rawValue:
                self.currentField = .name
            case PortCreateFieldId.description.rawValue:
                self.currentField = .description
            case PortCreateFieldId.network.rawValue:
                self.currentField = .network
            case PortCreateFieldId.macAddress.rawValue:
                self.currentField = .macAddress
            case PortCreateFieldId.portSecurity.rawValue:
                self.currentField = .portSecurity
            case PortCreateFieldId.securityGroups.rawValue:
                self.currentField = .securityGroups
            case PortCreateFieldId.portType.rawValue:
                self.currentField = .portType
            case PortCreateFieldId.qosPolicy.rawValue:
                self.currentField = .qosPolicy
            case PortCreateFieldId.qosPolicySelect.rawValue:
                self.currentField = .qosPolicySelect
            default:
                break
            }
        }

        // Update edit mode based on active field
        self.fieldEditMode = formState.isCurrentFieldActive()
    }
}

// MARK: - Field Identifiers

enum PortCreateFieldId: String {
    case name = "port-name"
    case description = "port-description"
    case network = "port-network"
    case macAddress = "port-mac-address"
    case portSecurity = "port-security"
    case securityGroups = "port-security-groups"
    case portType = "port-type"
    case qosPolicy = "port-qos-policy"
    case qosPolicySelect = "port-qos-policy-select"
}