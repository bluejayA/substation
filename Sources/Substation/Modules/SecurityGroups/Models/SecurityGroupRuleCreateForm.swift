import Foundation
import OSClient

enum SecurityGroupRuleCreateField: CaseIterable {
    case direction, `protocol`, portType, portRangeMin, portRangeMax, ethertype, remoteType, remoteValue

    var title: String {
        switch self {
        case .direction: return "Direction"
        case .`protocol`: return "Protocol"
        case .portType: return "Port Configuration"
        case .portRangeMin: return "Port Range Min"
        case .portRangeMax: return "Port Range Max"
        case .ethertype: return "Ether Type"
        case .remoteType: return "Remote"
        case .remoteValue: return "Remote Value"
        }
    }
}

struct SecurityGroupRuleCreateForm: FormViewModel {
    var direction: SecurityGroupDirection = .ingress
    var ruleProtocol: SecurityGroupProtocol = .tcp
    var portType: SecurityGroupPortType = .all
    var portRangeMin: String = ""
    var portRangeMax: String = ""
    var remoteType: SecurityGroupRemoteType = .cidr
    var remoteValue: String = "0.0.0.0/0" // Default to allow all
    var remoteSecurityGroups: [SecurityGroup] = []
    var selectedRemoteSecurityGroupIndex: Int = 0
    var selectedRemoteSecurityGroups: Set<String> = [] // For multi-selection
    var securityGroupSelectionMode: Bool = false
    var ethertype: SecurityGroupEtherType = .ipv4

    var currentField: SecurityGroupRuleCreateField = .direction
    var fieldEditMode: Bool = false

    mutating func nextField() {
        let fields = getVisibleFields()
        if let currentIndex = fields.firstIndex(of: currentField) {
            let nextIndex = (currentIndex + 1) % fields.count
            currentField = fields[nextIndex]
        }
        fieldEditMode = false
    }

    mutating func previousField() {
        let fields = getVisibleFields()
        if let currentIndex = fields.firstIndex(of: currentField) {
            let prevIndex = currentIndex == 0 ? fields.count - 1 : currentIndex - 1
            currentField = fields[prevIndex]
        }
        fieldEditMode = false
    }

    // Get fields that should be visible based on current state
    func getVisibleFields() -> [SecurityGroupRuleCreateField] {
        var fields: [SecurityGroupRuleCreateField] = [.direction, .`protocol`]

        // Only show port fields if protocol supports ports
        if ruleProtocol != .icmp && ruleProtocol != .any {
            fields.append(.portType)
            if portType == .custom {
                fields.append(.portRangeMin)
                fields.append(.portRangeMax)
            }
        }

        fields.append(.ethertype)
        fields.append(.remoteType)

        // Always show remoteValue field - it handles both CIDR and Security Group cases
        fields.append(.remoteValue)

        return fields
    }

    mutating func toggleDirection() {
        direction = direction == .ingress ? .egress : .ingress
    }

    mutating func nextProtocol() {
        let protocols = SecurityGroupProtocol.allCases
        if let currentIndex = protocols.firstIndex(of: ruleProtocol) {
            let nextIndex = (currentIndex + 1) % protocols.count
            ruleProtocol = protocols[nextIndex]

            // Reset port configuration when protocol changes
            if ruleProtocol == .icmp || ruleProtocol == .any {
                portType = .all
                portRangeMin = ""
                portRangeMax = ""
            }
        }
    }

    mutating func previousProtocol() {
        let protocols = SecurityGroupProtocol.allCases
        if let currentIndex = protocols.firstIndex(of: ruleProtocol) {
            let prevIndex = currentIndex == 0 ? protocols.count - 1 : currentIndex - 1
            ruleProtocol = protocols[prevIndex]

            // Reset port configuration when protocol changes
            if ruleProtocol == .icmp || ruleProtocol == .any {
                portType = .all
                portRangeMin = ""
                portRangeMax = ""
            }
        }
    }

    mutating func nextPortType() {
        let portTypes = SecurityGroupPortType.allCases
        if let currentIndex = portTypes.firstIndex(of: portType) {
            let nextIndex = (currentIndex + 1) % portTypes.count
            portType = portTypes[nextIndex]

            // Clear port values when switching types
            portRangeMin = ""
            portRangeMax = ""
        }
    }

    mutating func previousPortType() {
        let portTypes = SecurityGroupPortType.allCases
        if let currentIndex = portTypes.firstIndex(of: portType) {
            let prevIndex = currentIndex == 0 ? portTypes.count - 1 : currentIndex - 1
            portType = portTypes[prevIndex]

            // Clear port values when switching types
            portRangeMin = ""
            portRangeMax = ""
        }
    }

    mutating func nextRemoteType() {
        let remoteTypes = SecurityGroupRemoteType.allCases
        if let currentIndex = remoteTypes.firstIndex(of: remoteType) {
            let nextIndex = (currentIndex + 1) % remoteTypes.count
            remoteType = remoteTypes[nextIndex]

            // Set default values based on remote type
            switch remoteType {
            case .cidr:
                remoteValue = "0.0.0.0/0"
            case .securityGroup:
                remoteValue = ""
                selectedRemoteSecurityGroupIndex = 0
                selectedRemoteSecurityGroups.removeAll()
            }
        }
    }

    mutating func previousRemoteType() {
        let remoteTypes = SecurityGroupRemoteType.allCases
        if let currentIndex = remoteTypes.firstIndex(of: remoteType) {
            let prevIndex = currentIndex == 0 ? remoteTypes.count - 1 : currentIndex - 1
            remoteType = remoteTypes[prevIndex]

            // Set default values based on remote type
            switch remoteType {
            case .cidr:
                remoteValue = "0.0.0.0/0"
            case .securityGroup:
                remoteValue = ""
                selectedRemoteSecurityGroupIndex = 0
                selectedRemoteSecurityGroups.removeAll()
            }
        }
    }

    mutating func nextRemoteSecurityGroup() {
        if !remoteSecurityGroups.isEmpty {
            selectedRemoteSecurityGroupIndex = (selectedRemoteSecurityGroupIndex + 1) % remoteSecurityGroups.count
        }
    }

    mutating func previousRemoteSecurityGroup() {
        if !remoteSecurityGroups.isEmpty {
            selectedRemoteSecurityGroupIndex = selectedRemoteSecurityGroupIndex == 0 ?
                remoteSecurityGroups.count - 1 : selectedRemoteSecurityGroupIndex - 1
        }
    }

    // MARK: - Multi-selection methods for security groups

    /// Toggle security group selection (multi-select)
    mutating func toggleSecurityGroupSelection(groupID: String) {
        if selectedRemoteSecurityGroups.contains(groupID) {
            selectedRemoteSecurityGroups.remove(groupID)
        } else {
            selectedRemoteSecurityGroups.insert(groupID)
        }
    }

    /// Check if security group is selected
    func isSecurityGroupSelected(groupID: String) -> Bool {
        return selectedRemoteSecurityGroups.contains(groupID)
    }

    /// Enter security group selection mode
    mutating func enterSecurityGroupSelectionMode() {
        securityGroupSelectionMode = true
    }

    /// Exit security group selection mode
    mutating func exitSecurityGroupSelectionMode() {
        securityGroupSelectionMode = false
    }

    /// Get display value for selected security groups
    private func getSelectedSecurityGroupsDisplayValue() -> String {
        if remoteSecurityGroups.isEmpty {
            return "[No other security groups available]"
        } else if selectedRemoteSecurityGroups.isEmpty {
            return "[SPACE to select from \(remoteSecurityGroups.count) available]"
        } else {
            return "\(selectedRemoteSecurityGroups.count) of \(remoteSecurityGroups.count) security group(s) selected"
        }
    }

    mutating func toggleEthertype() {
        ethertype = ethertype == .ipv4 ? .ipv6 : .ipv4

        // Update default CIDR when ethertype changes
        if remoteType == .cidr {
            remoteValue = ethertype == .ipv4 ? "0.0.0.0/0" : "::/0"
        }
    }

    mutating func appendToCurrentField(_ input: String) {
        switch currentField {
        case .portRangeMin:
            // Only allow numeric input for ports
            if input.allSatisfy({ $0.isNumber }) {
                portRangeMin += input
            }
        case .portRangeMax:
            // Only allow numeric input for ports
            if input.allSatisfy({ $0.isNumber }) {
                portRangeMax += input
            }
        case .remoteValue:
            remoteValue += input
        default:
            break
        }
    }

    mutating func backspaceCurrentField() {
        switch currentField {
        case .portRangeMin:
            if !portRangeMin.isEmpty {
                portRangeMin.removeLast()
            }
        case .portRangeMax:
            if !portRangeMax.isEmpty {
                portRangeMax.removeLast()
            }
        case .remoteValue:
            if !remoteValue.isEmpty {
                remoteValue.removeLast()
            }
        default:
            break
        }
    }

    mutating func clearCurrentField() {
        switch currentField {
        case .portRangeMin:
            portRangeMin = ""
        case .portRangeMax:
            portRangeMax = ""
        case .remoteValue:
            remoteValue = ethertype == .ipv4 ? "0.0.0.0/0" : "::/0"
        default:
            break
        }
    }

    func validateForm() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []

        // Port validation for TCP/UDP
        if ruleProtocol == .tcp || ruleProtocol == .udp {
            if portType == .custom {
                // Validate port range min
                if portRangeMin.isEmpty {
                    errors.append("Port number is required for \(ruleProtocol.rawValue.uppercased())")
                } else if let minPort = Int(portRangeMin), (minPort < 1 || minPort > 65535) {
                    errors.append("Port must be between 1 and 65535")
                }

                // Validate port range max if provided
                if !portRangeMax.isEmpty {
                    if let maxPort = Int(portRangeMax), (maxPort < 1 || maxPort > 65535) {
                        errors.append("Port range maximum must be between 1 and 65535")
                    } else if let minPort = Int(portRangeMin), let maxPort = Int(portRangeMax), minPort > maxPort {
                        errors.append("Port range minimum must be less than or equal to maximum")
                    }
                }
            }
        }

        // Remote validation
        if remoteType == .cidr {
            if remoteValue.isEmpty {
                errors.append("CIDR block is required")
            } else {
                // Basic CIDR validation
                if ethertype == .ipv4 && !isValidIPv4CIDR(remoteValue) {
                    errors.append("Invalid IPv4 CIDR block")
                } else if ethertype == .ipv6 && !isValidIPv6CIDR(remoteValue) {
                    errors.append("Invalid IPv6 CIDR block")
                }
            }
        } else if remoteType == .securityGroup {
            if remoteSecurityGroups.isEmpty {
                errors.append("No security groups available")
            } else if selectedRemoteSecurityGroups.isEmpty {
                errors.append("At least one security group must be selected")
            }
        }

        return (errors.isEmpty, errors)
    }

    private func isValidIPv4CIDR(_ cidr: String) -> Bool {
        let components = cidr.split(separator: "/")
        guard components.count == 2,
              let prefixLength = Int(components[1]),
              prefixLength >= 0 && prefixLength <= 32 else {
            return false
        }

        let ipComponents = components[0].split(separator: ".")
        guard ipComponents.count == 4 else { return false }

        for component in ipComponents {
            guard let octet = Int(component), octet >= 0 && octet <= 255 else {
                return false
            }
        }

        return true
    }

    private func isValidIPv6CIDR(_ cidr: String) -> Bool {
        let components = cidr.split(separator: "/")
        guard components.count == 2,
              let prefixLength = Int(components[1]),
              prefixLength >= 0 && prefixLength <= 128 else {
            return false
        }

        // Comprehensive IPv6 validation
        let ipv6 = String(components[0])
        return isValidIPv6(ipv6)
    }

    /// Comprehensive IPv6 validation
    private func isValidIPv6(_ ip: String) -> Bool {
        // Handle IPv6 addresses with embedded IPv4 (e.g., ::ffff:192.0.2.1)
        if ip.contains(".") {
            return isValidIPv6WithEmbeddedIPv4(ip)
        }

        // Handle IPv6 addresses with zero compression (::)
        let parts = ip.components(separatedBy: "::")

        // Can only have one :: in a valid IPv6 address
        if parts.count > 2 {
            return false
        }

        if parts.count == 2 {
            // Has zero compression
            let leftPart = parts[0]
            let rightPart = parts[1]

            let leftGroups = leftPart.isEmpty ? [] : leftPart.components(separatedBy: ":")
            let rightGroups = rightPart.isEmpty ? [] : rightPart.components(separatedBy: ":")

            // Total groups should not exceed 8
            if leftGroups.count + rightGroups.count > 7 {
                return false
            }

            // Validate each group
            for group in leftGroups + rightGroups {
                if !isValidIPv6Group(group) {
                    return false
                }
            }

            return true
        } else {
            // No zero compression, should have exactly 8 groups
            let groups = ip.components(separatedBy: ":")

            if groups.count != 8 {
                return false
            }

            // Validate each group
            for group in groups {
                if !isValidIPv6Group(group) {
                    return false
                }
            }

            return true
        }
    }

    /// Validate IPv6 address with embedded IPv4
    private func isValidIPv6WithEmbeddedIPv4(_ ip: String) -> Bool {
        // Split by the last occurrence of ":"
        let lastColonIndex = ip.lastIndex(of: ":")
        guard let colonIndex = lastColonIndex else { return false }

        let ipv6Part = String(ip[..<colonIndex])
        let ipv4Part = String(ip[ip.index(after: colonIndex)...])

        // Validate the IPv4 part
        if !isValidIPv4(ipv4Part) {
            return false
        }

        // Validate the IPv6 part (should be 6 groups or less with ::)
        if ipv6Part.contains("::") {
            let parts = ipv6Part.components(separatedBy: "::")
            if parts.count > 2 { return false }

            let leftGroups = parts[0].isEmpty ? [] : parts[0].components(separatedBy: ":")
            let rightGroups: [String]
            if let secondPart = parts.dropFirst().first, !secondPart.isEmpty {
                rightGroups = secondPart.components(separatedBy: ":")
            } else {
                rightGroups = []
            }

            // Should have at most 6 groups total (since IPv4 takes 2 groups worth)
            if leftGroups.count + rightGroups.count > 5 {
                return false
            }

            for group in leftGroups + rightGroups {
                if !isValidIPv6Group(group) {
                    return false
                }
            }
        } else {
            let groups = ipv6Part.components(separatedBy: ":")
            // Should have exactly 6 groups (since IPv4 takes 2 groups worth)
            if groups.count != 6 {
                return false
            }

            for group in groups {
                if !isValidIPv6Group(group) {
                    return false
                }
            }
        }

        return true
    }

    /// Validate IPv4 address (for embedded IPv4 in IPv6)
    private func isValidIPv4(_ ip: String) -> Bool {
        let components = ip.split(separator: ".")
        guard components.count == 4 else { return false }

        for component in components {
            guard let num = Int(component), num >= 0, num <= 255 else { return false }
        }

        return true
    }

    /// Validate a single IPv6 group (1-4 hexadecimal digits)
    private func isValidIPv6Group(_ group: String) -> Bool {
        // Empty group is only valid with zero compression
        if group.isEmpty {
            return false
        }

        // Should be 1-4 hexadecimal characters
        if group.count > 4 {
            return false
        }

        // Check if all characters are valid hexadecimal
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return group.rangeOfCharacter(from: hexCharacterSet.inverted) == nil
    }

    func getSelectedRemoteSecurityGroup() -> SecurityGroup? {
        guard remoteType == .securityGroup,
              !remoteSecurityGroups.isEmpty,
              selectedRemoteSecurityGroupIndex < remoteSecurityGroups.count else {
            return nil
        }
        return remoteSecurityGroups[selectedRemoteSecurityGroupIndex]
    }

    func getPortRangeMinValue() -> Int? {
        return Int(portRangeMin)
    }

    func getPortRangeMaxValue() -> Int? {
        return Int(portRangeMax)
    }

    mutating func reset() {
        direction = .ingress
        ruleProtocol = .tcp
        portType = .all
        portRangeMin = ""
        portRangeMax = ""
        remoteType = .cidr
        remoteValue = "0.0.0.0/0"
        selectedRemoteSecurityGroupIndex = 0
        selectedRemoteSecurityGroups.removeAll()
        securityGroupSelectionMode = false
        ethertype = .ipv4
        currentField = .direction
        fieldEditMode = false
    }

    // Navigation helpers
    func isOnFirstField() -> Bool {
        let fields = getVisibleFields()
        return currentField == fields.first
    }

    func isOnLastField() -> Bool {
        let fields = getVisibleFields()
        return currentField == fields.last
    }

    // MARK: - FormViewModel Protocol

    func getFieldConfigurations() -> [FormFieldConfiguration] {
        let visibleFields = getVisibleFields()
        let validationState = getValidationState()

        return visibleFields.map { field in
            let isSelected = field == currentField
            let isActive = fieldEditMode && isSelected
            let hasError = !validationState.isValid && getFieldError(field, from: validationState.errors) != nil
            let errorMessage = getFieldError(field, from: validationState.errors)

            switch field {
            case .direction:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: true,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    value: direction.displayName,
                    fieldType: .enumeration,
                    selectionInfo: SelectionInfo(
                        selectedIndex: SecurityGroupDirection.allCases.firstIndex(of: direction) ?? 0,
                        totalItems: SecurityGroupDirection.allCases.count,
                        selectedItemName: direction.displayName
                    )
                )

            case .`protocol`:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: true,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    value: ruleProtocol.displayName,
                    fieldType: .enumeration,
                    selectionInfo: SelectionInfo(
                        selectedIndex: SecurityGroupProtocol.allCases.firstIndex(of: ruleProtocol) ?? 0,
                        totalItems: SecurityGroupProtocol.allCases.count,
                        selectedItemName: ruleProtocol.displayName
                    )
                )

            case .portType:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: true,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    value: portType.displayName,
                    fieldType: .enumeration,
                    selectionInfo: SelectionInfo(
                        selectedIndex: SecurityGroupPortType.allCases.firstIndex(of: portType) ?? 0,
                        totalItems: SecurityGroupPortType.allCases.count,
                        selectedItemName: portType.displayName
                    )
                )

            case .portRangeMin:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: true,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    placeholder: "Port number (1-65535)",
                    value: portRangeMin,
                    fieldType: .text
                )

            case .portRangeMax:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: false,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    placeholder: "Max port (optional for range)",
                    value: portRangeMax,
                    fieldType: .text
                )

            case .remoteType:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: true,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    value: remoteType.displayName,
                    fieldType: .enumeration,
                    selectionInfo: SelectionInfo(
                        selectedIndex: SecurityGroupRemoteType.allCases.firstIndex(of: remoteType) ?? 0,
                        totalItems: SecurityGroupRemoteType.allCases.count,
                        selectedItemName: remoteType.displayName
                    )
                )

            case .remoteValue:
                if remoteType == .cidr {
                    return FormFieldConfiguration(
                        title: field.title,
                        isRequired: true,
                        isSelected: isSelected,
                        isActive: isActive,
                        hasError: hasError,
                        errorMessage: errorMessage,
                        placeholder: ethertype == .ipv4 ? "0.0.0.0/0" : "::/0",
                        value: remoteValue,
                        fieldType: .text
                    )
                } else {
                    return FormFieldConfiguration(
                        title: "Security Groups",
                        isRequired: true,
                        isSelected: isSelected,
                        isActive: isActive,
                        hasError: hasError,
                        errorMessage: errorMessage,
                        value: getSelectedSecurityGroupsDisplayValue(),
                        fieldType: .multiSelection,
                        selectionMode: securityGroupSelectionMode
                    )
                }

            case .ethertype:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: true,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    value: ethertype.rawValue,
                    fieldType: .enumeration,
                    selectionInfo: SelectionInfo(
                        selectedIndex: SecurityGroupEtherType.allCases.firstIndex(of: ethertype) ?? 0,
                        totalItems: SecurityGroupEtherType.allCases.count,
                        selectedItemName: ethertype.rawValue
                    )
                )
            }
        }
    }

    func getValidationState() -> FormValidationState {
        let validation = validateForm()
        return FormValidationState(
            isValid: validation.isValid,
            errors: validation.errors,
            warnings: []
        )
    }

    func getFormTitle() -> String {
        return "Create Security Group Rule"
    }

    func getNavigationHelp() -> String {
        if securityGroupSelectionMode {
            return "UP/DOWN Navigate | SPACE Toggle | ENTER Confirm | ESC Exit"
        } else if fieldEditMode {
            return "Type to edit | Esc to cancel | Enter to confirm"
        } else {
            return "UP/DOWN Navigate | Enter Edit | Space Toggle | Esc Cancel"
        }
    }

    func isInSpecialMode() -> Bool {
        return fieldEditMode || securityGroupSelectionMode
    }

    private func getFieldError(_ field: SecurityGroupRuleCreateField, from errors: [String]) -> String? {
        // Map validation errors to specific fields
        for error in errors {
            switch field {
            case .portRangeMin, .portRangeMax:
                if error.contains("Port") {
                    return error
                }
            case .remoteValue:
                if error.contains("CIDR") || error.contains("IPv4") || error.contains("IPv6") {
                    return error
                }
            default:
                break
            }
        }
        return nil
    }

    // MARK: - FormBuilder Integration

    func buildFields(
        selectedFieldId: String?,
        activeFieldId: String?,
        formState: FormBuilderState
    ) -> [FormField] {
        var fields: [FormField] = []

        // Direction Field (Selector)
        let directionFieldId = SecurityGroupRuleCreateFieldId.direction.rawValue
        let directionItems = SecurityGroupDirection.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: directionFieldId,
            label: SecurityGroupRuleCreateField.direction.title,
            items: directionItems,
            selectedItemId: direction.rawValue,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == directionFieldId,
            isActive: activeFieldId == directionFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "DIRECTION", width: 12) { item in
                    (item as? SecurityGroupDirection)?.displayName ?? ""
                },
                FormSelectorItemColumn(header: "DESCRIPTION", width: 40) { item in
                    (item as? SecurityGroupDirection)?.description ?? ""
                }
            ],
            searchQuery: formState.selectorStates[directionFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[directionFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[directionFieldId]?.scrollOffset ?? 0
        )))

        // Protocol Field (Selector)
        let protocolFieldId = SecurityGroupRuleCreateFieldId.protocol.rawValue
        let protocolItems = SecurityGroupProtocol.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: protocolFieldId,
            label: SecurityGroupRuleCreateField.protocol.title,
            items: protocolItems,
            selectedItemId: ruleProtocol.rawValue,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == protocolFieldId,
            isActive: activeFieldId == protocolFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "PROTOCOL", width: 12) { item in
                    (item as? SecurityGroupProtocol)?.displayName ?? ""
                },
                FormSelectorItemColumn(header: "DESCRIPTION", width: 40) { item in
                    (item as? SecurityGroupProtocol)?.description ?? ""
                }
            ],
            searchQuery: formState.selectorStates[protocolFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[protocolFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[protocolFieldId]?.scrollOffset ?? 0
        )))

        // Port Type Field (Selector) - only for TCP/UDP
        if ruleProtocol != .icmp && ruleProtocol != .any {
            let portTypeFieldId = SecurityGroupRuleCreateFieldId.portType.rawValue
            let portTypeItems = SecurityGroupPortType.allCases.map { $0 as any FormSelectorItem }
            fields.append(.selector(FormFieldSelector(
                id: portTypeFieldId,
                label: SecurityGroupRuleCreateField.portType.title,
                items: portTypeItems,
                selectedItemId: portType.id,
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == portTypeFieldId,
                isActive: activeFieldId == portTypeFieldId,
                validationError: nil,
                columns: [
                    FormSelectorItemColumn(header: "PORT TYPE", width: 15) { item in
                        (item as? SecurityGroupPortType)?.displayName ?? ""
                    },
                    FormSelectorItemColumn(header: "DESCRIPTION", width: 35) { item in
                        (item as? SecurityGroupPortType)?.description ?? ""
                    }
                ],
                searchQuery: formState.selectorStates[portTypeFieldId]?.searchQuery,
                highlightedIndex: formState.selectorStates[portTypeFieldId]?.highlightedIndex ?? 0,
                scrollOffset: formState.selectorStates[portTypeFieldId]?.scrollOffset ?? 0
            )))

            // Port Range Min Field (Text) - only for custom ports
            if portType == .custom {
                let portMinFieldId = SecurityGroupRuleCreateFieldId.portRangeMin.rawValue
                fields.append(.text(FormFieldText(
                    id: portMinFieldId,
                    label: SecurityGroupRuleCreateField.portRangeMin.title,
                    value: portRangeMin,
                    placeholder: "1-65535",
                    isRequired: true,
                    isVisible: true,
                    isSelected: selectedFieldId == portMinFieldId,
                    isActive: activeFieldId == portMinFieldId,
                    cursorPosition: formState.textFieldStates[portMinFieldId]?.cursorPosition,
                    validationError: nil,
                    maxWidth: 20,
                    maxLength: 5
                )))

                // Port Range Max Field (Text) - optional
                let portMaxFieldId = SecurityGroupRuleCreateFieldId.portRangeMax.rawValue
                fields.append(.text(FormFieldText(
                    id: portMaxFieldId,
                    label: SecurityGroupRuleCreateField.portRangeMax.title,
                    value: portRangeMax,
                    placeholder: "Optional, defaults to min",
                    isRequired: false,
                    isVisible: true,
                    isSelected: selectedFieldId == portMaxFieldId,
                    isActive: activeFieldId == portMaxFieldId,
                    cursorPosition: formState.textFieldStates[portMaxFieldId]?.cursorPosition,
                    validationError: nil,
                    maxWidth: 20,
                    maxLength: 5
                )))
            }
        }

        // Ethertype Field (Selector)
        let ethertypeFieldId = SecurityGroupRuleCreateFieldId.ethertype.rawValue
        let ethertypeItems = SecurityGroupEtherType.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: ethertypeFieldId,
            label: SecurityGroupRuleCreateField.ethertype.title,
            items: ethertypeItems,
            selectedItemId: ethertype.rawValue,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ethertypeFieldId,
            isActive: activeFieldId == ethertypeFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "TYPE", width: 10) { item in
                    (item as? SecurityGroupEtherType)?.displayName ?? ""
                },
                FormSelectorItemColumn(header: "DESCRIPTION", width: 40) { item in
                    (item as? SecurityGroupEtherType)?.description ?? ""
                }
            ],
            searchQuery: formState.selectorStates[ethertypeFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[ethertypeFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[ethertypeFieldId]?.scrollOffset ?? 0
        )))

        // Remote Type Field (Selector)
        let remoteTypeFieldId = SecurityGroupRuleCreateFieldId.remoteType.rawValue
        let remoteTypeItems = SecurityGroupRemoteType.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: remoteTypeFieldId,
            label: SecurityGroupRuleCreateField.remoteType.title,
            items: remoteTypeItems,
            selectedItemId: remoteType.id,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == remoteTypeFieldId,
            isActive: activeFieldId == remoteTypeFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "REMOTE TYPE", width: 18) { item in
                    (item as? SecurityGroupRemoteType)?.displayName ?? ""
                },
                FormSelectorItemColumn(header: "DESCRIPTION", width: 35) { item in
                    (item as? SecurityGroupRemoteType)?.description ?? ""
                }
            ],
            searchQuery: formState.selectorStates[remoteTypeFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[remoteTypeFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[remoteTypeFieldId]?.scrollOffset ?? 0
        )))

        // Remote Value Field (Text or Selector depending on remoteType)
        let remoteValueFieldId = SecurityGroupRuleCreateFieldId.remoteValue.rawValue
        if remoteType == .cidr {
            fields.append(.text(FormFieldText(
                id: remoteValueFieldId,
                label: SecurityGroupRuleCreateField.remoteValue.title,
                value: remoteValue,
                placeholder: ethertype == .ipv4 ? "0.0.0.0/0" : "::/0",
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == remoteValueFieldId,
                isActive: activeFieldId == remoteValueFieldId,
                cursorPosition: formState.textFieldStates[remoteValueFieldId]?.cursorPosition,
                validationError: nil,
                maxWidth: 50,
                maxLength: 100
            )))
        } else {
            // Security Group selector
            let sgItems = remoteSecurityGroups.map { $0 as any FormSelectorItem }
            let selectedSGId = getSelectedRemoteSecurityGroup()?.id
            fields.append(.selector(FormFieldSelector(
                id: remoteValueFieldId,
                label: "Remote Security Group",
                items: sgItems,
                selectedItemId: selectedSGId,
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == remoteValueFieldId,
                isActive: activeFieldId == remoteValueFieldId,
                validationError: nil,
                columns: [
                    FormSelectorItemColumn(header: "NAME", width: 30) { item in
                        (item as? SecurityGroup)?.name ?? "Unnamed"
                    },
                    FormSelectorItemColumn(header: "ID", width: 36) { item in
                        (item as? SecurityGroup)?.id ?? ""
                    }
                ],
                searchQuery: formState.selectorStates[remoteValueFieldId]?.searchQuery,
                highlightedIndex: formState.selectorStates[remoteValueFieldId]?.highlightedIndex ?? 0,
                scrollOffset: formState.selectorStates[remoteValueFieldId]?.scrollOffset ?? 0
            )))
        }

        return fields
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        let fields = formState.fields

        for field in fields {
            switch field {
            case .text(let textField):
                switch textField.id {
                case SecurityGroupRuleCreateFieldId.portRangeMin.rawValue:
                    self.portRangeMin = textField.value
                case SecurityGroupRuleCreateFieldId.portRangeMax.rawValue:
                    self.portRangeMax = textField.value
                case SecurityGroupRuleCreateFieldId.remoteValue.rawValue:
                    self.remoteValue = textField.value
                default:
                    break
                }

            case .selector(let selectorField):
                switch selectorField.id {
                case SecurityGroupRuleCreateFieldId.direction.rawValue:
                    if let selectedId = selectorField.selectedItemId,
                       let newDirection = SecurityGroupDirection(rawValue: selectedId) {
                        self.direction = newDirection
                    }

                case SecurityGroupRuleCreateFieldId.protocol.rawValue:
                    if let selectedId = selectorField.selectedItemId,
                       let newProtocol = SecurityGroupProtocol(rawValue: selectedId) {
                        self.ruleProtocol = newProtocol

                        // Reset port configuration when protocol changes
                        if newProtocol == .icmp || newProtocol == .any {
                            self.portType = .all
                            self.portRangeMin = ""
                            self.portRangeMax = ""
                        }
                    }

                case SecurityGroupRuleCreateFieldId.portType.rawValue:
                    if let selectedId = selectorField.selectedItemId {
                        if selectedId == "all" {
                            self.portType = .all
                            self.portRangeMin = ""
                            self.portRangeMax = ""
                        } else if selectedId == "custom" {
                            self.portType = .custom
                        }
                    }

                case SecurityGroupRuleCreateFieldId.ethertype.rawValue:
                    if let selectedId = selectorField.selectedItemId,
                       let newEthertype = SecurityGroupEtherType(rawValue: selectedId) {
                        self.ethertype = newEthertype

                        // Update default CIDR when ethertype changes
                        if remoteType == .cidr && remoteValue.isEmpty {
                            remoteValue = newEthertype == .ipv4 ? "0.0.0.0/0" : "::/0"
                        }
                    }

                case SecurityGroupRuleCreateFieldId.remoteType.rawValue:
                    if let selectedId = selectorField.selectedItemId {
                        if selectedId == "cidr" {
                            self.remoteType = .cidr
                            if remoteValue.isEmpty {
                                remoteValue = ethertype == .ipv4 ? "0.0.0.0/0" : "::/0"
                            }
                        } else if selectedId == "security-group" {
                            self.remoteType = .securityGroup
                        }
                    }

                case SecurityGroupRuleCreateFieldId.remoteValue.rawValue:
                    // When remoteType is security group, update the selected index
                    if remoteType == .securityGroup, let selectedId = selectorField.selectedItemId {
                        if let index = remoteSecurityGroups.firstIndex(where: { $0.id == selectedId }) {
                            self.selectedRemoteSecurityGroupIndex = index
                        }
                    }

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
            case SecurityGroupRuleCreateFieldId.direction.rawValue:
                self.currentField = .direction
            case SecurityGroupRuleCreateFieldId.protocol.rawValue:
                self.currentField = .protocol
            case SecurityGroupRuleCreateFieldId.portType.rawValue:
                self.currentField = .portType
            case SecurityGroupRuleCreateFieldId.portRangeMin.rawValue:
                self.currentField = .portRangeMin
            case SecurityGroupRuleCreateFieldId.portRangeMax.rawValue:
                self.currentField = .portRangeMax
            case SecurityGroupRuleCreateFieldId.ethertype.rawValue:
                self.currentField = .ethertype
            case SecurityGroupRuleCreateFieldId.remoteType.rawValue:
                self.currentField = .remoteType
            case SecurityGroupRuleCreateFieldId.remoteValue.rawValue:
                self.currentField = .remoteValue
            default:
                break
            }
        }

        // Update edit mode based on active field
        self.fieldEditMode = formState.isCurrentFieldActive()
    }
}

// MARK: - Field Identifiers

enum SecurityGroupRuleCreateFieldId: String {
    case direction = "sg-rule-direction"
    case `protocol` = "sg-rule-protocol"
    case portType = "sg-rule-port-type"
    case portRangeMin = "sg-rule-port-min"
    case portRangeMax = "sg-rule-port-max"
    case ethertype = "sg-rule-ethertype"
    case remoteType = "sg-rule-remote-type"
    case remoteValue = "sg-rule-remote-value"
}