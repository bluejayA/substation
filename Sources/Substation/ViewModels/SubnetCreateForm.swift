import Foundation
import OSClient

enum SubnetCreateField: CaseIterable {
    case name, network, ipVersion, cidr, gatewayEnabled, dhcpEnabled, allocationPools, dns, hostRoutes

    var title: String {
        switch self {
        case .name: return "Subnet Name"
        case .network: return "Network"
        case .ipVersion: return "IP Version"
        case .cidr: return "CIDR"
        case .gatewayEnabled: return "Gateway Enabled"
        case .dhcpEnabled: return "DHCP Enabled"
        case .allocationPools: return "Allocation Pools"
        case .dns: return "DNS Nameservers"
        case .hostRoutes: return "Host Routes"
        }
    }
}

enum IPVersion: String, CaseIterable {
    case ipv4 = "4"
    case ipv6 = "6"

    var displayName: String {
        switch self {
        case .ipv4: return "IPv4"
        case .ipv6: return "IPv6"
        }
    }
}

// MARK: - IPVersion FormSelectorItem Conformance

extension IPVersion: FormSelectorItem {
    var id: String {
        return self.rawValue
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return displayName.lowercased().contains(lowercaseQuery) ||
               rawValue.contains(lowercaseQuery)
    }
}

struct SubnetCreateForm: FormViewModel {
    var subnetName: String = ""

    // Network selection with modern pattern
    var selectedNetworkIndex: Int = 0
    var selectedNetworkID: String? = nil
    var networkSelectionMode: Bool = false

    var ipVersion: IPVersion = .ipv4
    var cidr: String = ""
    var gatewayEnabled: Bool = true
    var dhcpEnabled: Bool = true
    var allocationPools: String = ""
    var dns: String = ""
    var hostRoutes: String = ""

    var currentField: SubnetCreateField = .name
    var fieldEditMode: Bool = false // true when editing a text field

    mutating func nextField() {
        let fields = SubnetCreateField.allCases
        if let currentIndex = fields.firstIndex(of: currentField) {
            let nextIndex = (currentIndex + 1) % fields.count
            currentField = fields[nextIndex]
        }
        fieldEditMode = false
    }

    mutating func previousField() {
        let fields = SubnetCreateField.allCases
        if let currentIndex = fields.firstIndex(of: currentField) {
            let prevIndex = currentIndex == 0 ? fields.count - 1 : currentIndex - 1
            currentField = fields[prevIndex]
        }
        fieldEditMode = false
    }

    mutating func toggleIPVersion() {
        ipVersion = ipVersion == .ipv4 ? .ipv6 : .ipv4
        // Update CIDR placeholder when IP version changes
        if cidr.isEmpty {
            cidr = ipVersion == .ipv4 ? "192.168.1.0/24" : "2001:db8::/64"
        }
    }

    mutating func toggleGateway() {
        gatewayEnabled.toggle()
    }

    mutating func toggleDHCP() {
        dhcpEnabled.toggle()
    }

    // MARK: - Network Selection Methods

    /// Toggle network selection
    mutating func toggleNetworkSelection(networkID: String) {
        if selectedNetworkID == networkID {
            selectedNetworkID = nil
        } else {
            selectedNetworkID = networkID
        }
    }

    /// Check if network is selected
    func isNetworkSelected(networkID: String) -> Bool {
        return selectedNetworkID == networkID
    }

    /// Enter network selection mode
    mutating func enterNetworkSelectionMode() {
        networkSelectionMode = true
    }

    /// Exit network selection mode and apply selection
    mutating func exitNetworkSelectionMode(networks: [Network]) {
        networkSelectionMode = false

        // Update selectedNetworkIndex based on selectedNetworkID
        if let selectedID = selectedNetworkID,
           let index = networks.firstIndex(where: { $0.id == selectedID }) {
            selectedNetworkIndex = index
        }
    }

    /// Validate the form and return validation errors if any
    func validate() -> [String] {
        var errors: [String] = []

        // Validate subnet name using centralized validator
        errors.append(contentsOf: InputValidator.validateNameField(subnetName, maxLength: 255))

        // Validate CIDR using centralized validator
        let trimmedCidr = cidr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCidr.isEmpty {
            errors.append("CIDR is required")
        } else {
            errors.append(contentsOf: InputValidator.validateCIDR(trimmedCidr))
        }

        // Validate allocation pools format if provided
        let trimmedPools = allocationPools.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPools.isEmpty && !isValidAllocationPools(trimmedPools) {
            errors.append("Invalid allocation pools format (example: 192.168.1.2,192.168.1.200)")
        }

        // Validate DNS nameservers format if provided
        let trimmedDns = dns.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDns.isEmpty && !isValidDNS(trimmedDns) {
            errors.append("Invalid DNS nameservers format (example: 1.1.1.1,8.8.8.8)")
        }

        // Validate host routes format if provided
        let trimmedRoutes = hostRoutes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRoutes.isEmpty && !isValidHostRoutes(trimmedRoutes) {
            errors.append("Invalid host routes format (example: 192.168.200.0/24,10.56.1.254)")
        }

        return errors
    }

    /// Validate the form with network information and return validation errors if any
    func validate(availableNetworks: [Network]) -> [String] {
        var errors = validate()

        // Check if a network is selected
        if availableNetworks.isEmpty {
            errors.append("No networks available. Please create a network first.")
        } else if selectedNetworkID == nil {
            errors.append("Network selection is required")
        } else if !availableNetworks.contains(where: { $0.id == selectedNetworkID }) {
            errors.append("Selected network is invalid")
        }

        return errors
    }

    /// Basic CIDR validation
    private func isValidCIDR(_ cidr: String, ipVersion: IPVersion) -> Bool {
        let components = cidr.split(separator: "/")
        guard components.count == 2 else { return false }

        let ip = String(components[0])
        guard let prefix = Int(components[1]) else { return false }

        switch ipVersion {
        case .ipv4:
            return isValidIPv4(ip) && prefix >= 0 && prefix <= 32
        case .ipv6:
            return isValidIPv6(ip) && prefix >= 0 && prefix <= 128
        }
    }

    /// Basic IPv4 validation
    private func isValidIPv4(_ ip: String) -> Bool {
        let components = ip.split(separator: ".")
        guard components.count == 4 else { return false }

        for component in components {
            guard let num = Int(component), num >= 0, num <= 255 else { return false }
        }
        return true
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
            let rightGroups = parts.count > 1 && !parts[1].isEmpty ? parts[1].components(separatedBy: ":") : []

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

    /// Validate allocation pools format
    private func isValidAllocationPools(_ pools: String) -> Bool {
        let poolPairs = pools.split(separator: ",")
        return poolPairs.count == 2 // Simple validation for start,end format
    }

    /// Validate DNS nameservers format
    private func isValidDNS(_ dns: String) -> Bool {
        let servers = dns.split(separator: ",")
        for server in servers {
            let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
            // Basic validation - should be valid IP
            if ipVersion == .ipv4 && !isValidIPv4(trimmed) {
                return false
            }
            // For IPv6 or mixed, basic check
            if !isValidIPv4(trimmed) && !isValidIPv6(trimmed) {
                return false
            }
        }
        return true
    }

    /// Validate host routes format
    private func isValidHostRoutes(_ routes: String) -> Bool {
        let routePairs = routes.split(separator: ",")
        return routePairs.count == 2 // Simple validation for destination,nexthop format
    }

    /// Get trimmed values for API calls
    func getTrimmedName() -> String {
        return subnetName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedCIDR() -> String {
        return cidr.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedAllocationPools() -> String {
        return allocationPools.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedDNS() -> String {
        return dns.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedHostRoutes() -> String {
        return hostRoutes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get IP version as integer
    func getIPVersionInt() -> Int {
        return Int(ipVersion.rawValue) ?? 4
    }

    // MARK: - FormViewModel Implementation

    func getFieldConfigurations() -> [FormFieldConfiguration] {
        let visibleFields = getVisibleFields()
        var configurations: [FormFieldConfiguration] = []

        for field in visibleFields {
            let config = getFieldConfiguration(for: field)
            configurations.append(config)
        }

        return configurations
    }

    func getValidationState() -> FormValidationState {
        let errors = validate(availableNetworks: [])
        return FormValidationState(isValid: errors.isEmpty, errors: errors)
    }

    func getFormTitle() -> String {
        return "Create Subnet"
    }

    func getNavigationHelp() -> String {
        if networkSelectionMode {
            return "ESC: Exit selection | ENTER: Select network | UP/DOWN: Navigate"
        } else {
            return "TAB/UP/DOWN: Navigate fields | ENTER: Create | ESC: Cancel"
        }
    }

    func isInSpecialMode() -> Bool {
        return networkSelectionMode
    }

    // MARK: - Private Helper Methods

    private func getVisibleFields() -> [SubnetCreateField] {
        return SubnetCreateField.allCases
    }

    private func getFieldConfiguration(for field: SubnetCreateField) -> FormFieldConfiguration {
        let isSelected = (currentField == field)
        let isActive = isSelected && fieldEditMode

        switch field {
        case .name:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: true,
                isSelected: isSelected,
                isActive: isActive,
                placeholder: "Enter subnet name",
                value: subnetName.isEmpty ? nil : subnetName,
                maxWidth: 40,
                fieldType: .text
            )

        case .network:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: true,
                isSelected: isSelected,
                isActive: isActive,
                fieldType: .selection,
                selectionMode: networkSelectionMode,
                selectionInfo: getNetworkSelectionInfo()
            )

        case .ipVersion:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: true,
                isSelected: isSelected,
                isActive: isActive,
                value: ipVersion.displayName,
                fieldType: .enumeration,
                selectionInfo: SelectionInfo(
                    selectedIndex: IPVersion.allCases.firstIndex(of: ipVersion) ?? 0,
                    totalItems: IPVersion.allCases.count,
                    selectedItemName: ipVersion.displayName
                )
            )

        case .cidr:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: true,
                isSelected: isSelected,
                isActive: isActive,
                placeholder: ipVersion == .ipv4 ? "e.g., 192.168.1.0/24" : "e.g., 2001:db8::/64",
                value: cidr.isEmpty ? nil : cidr,
                maxWidth: 30,
                fieldType: .text
            )

        case .gatewayEnabled:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: isActive,
                value: gatewayEnabled ? "Enabled" : "Disabled",
                fieldType: .enumeration,
                selectionInfo: SelectionInfo(
                    selectedIndex: gatewayEnabled ? 0 : 1,
                    totalItems: 2,
                    selectedItemName: gatewayEnabled ? "Enabled" : "Disabled"
                )
            )

        case .dhcpEnabled:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: isActive,
                value: dhcpEnabled ? "Enabled" : "Disabled",
                fieldType: .enumeration,
                selectionInfo: SelectionInfo(
                    selectedIndex: dhcpEnabled ? 0 : 1,
                    totalItems: 2,
                    selectedItemName: dhcpEnabled ? "Enabled" : "Disabled"
                )
            )

        case .allocationPools:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: isActive,
                placeholder: "e.g., 192.168.1.10-192.168.1.100",
                value: allocationPools.isEmpty ? nil : allocationPools,
                maxWidth: 50,
                fieldType: .text
            )

        case .dns:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: isActive,
                placeholder: "e.g., 8.8.8.8,8.8.4.4",
                value: dns.isEmpty ? nil : dns,
                maxWidth: 50,
                fieldType: .text
            )

        case .hostRoutes:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: isActive,
                placeholder: "destination,nexthop",
                value: hostRoutes.isEmpty ? nil : hostRoutes,
                maxWidth: 50,
                fieldType: .text
            )
        }
    }

    private func getNetworkSelectionInfo() -> SelectionInfo? {
        // This would need networks data - for now return placeholder
        return SelectionInfo(selectedIndex: selectedNetworkIndex,
                           totalItems: 0, // This would be actual count
                           selectedItemName: selectedNetworkID)
    }

    // MARK: - FormBuilder Integration

    func buildFields(
        selectedFieldId: String?,
        activeFieldId: String?,
        cachedNetworks: [Network],
        formState: FormBuilderState
    ) -> [FormField] {
        var fields: [FormField] = []

        // Subnet Name Field
        let nameFieldId = SubnetCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameFieldId,
            label: SubnetCreateField.name.title,
            value: subnetName,
            placeholder: "Enter subnet name",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameFieldId,
            isActive: activeFieldId == nameFieldId,
            cursorPosition: formState.textFieldStates[nameFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        // Network Field (Selector)
        let networkFieldId = SubnetCreateFieldId.network.rawValue
        let networkItems = cachedNetworks.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: networkFieldId,
            label: SubnetCreateField.network.title,
            items: networkItems,
            selectedItemId: selectedNetworkID,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == networkFieldId,
            isActive: activeFieldId == networkFieldId,
            validationError: cachedNetworks.isEmpty ? "No networks available" : nil,
            columns: [
                FormSelectorItemColumn(header: "NAME", width: 30) { item in
                    (item as? Network)?.name ?? "Unnamed"
                },
                FormSelectorItemColumn(header: "ID", width: 36) { item in
                    (item as? Network)?.id ?? ""
                }
            ],
            searchQuery: formState.getSelectorState(networkFieldId)?.searchQuery,
            highlightedIndex: formState.getSelectorState(networkFieldId)?.highlightedIndex ?? 0,
            scrollOffset: formState.getSelectorState(networkFieldId)?.scrollOffset ?? 0
        )))

        // IP Version Field (Selector)
        let ipVersionFieldId = SubnetCreateFieldId.ipVersion.rawValue
        let ipVersionItems = IPVersion.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: ipVersionFieldId,
            label: SubnetCreateField.ipVersion.title,
            items: ipVersionItems,
            selectedItemId: ipVersion.rawValue,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ipVersionFieldId,
            isActive: activeFieldId == ipVersionFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "VERSION", width: 10) { item in
                    (item as? IPVersion)?.displayName ?? ""
                }
            ],
            searchQuery: formState.getSelectorState(ipVersionFieldId)?.searchQuery,
            highlightedIndex: formState.getSelectorState(ipVersionFieldId)?.highlightedIndex ?? 0,
            scrollOffset: formState.getSelectorState(ipVersionFieldId)?.scrollOffset ?? 0
        )))

        // CIDR Field
        let cidrFieldId = SubnetCreateFieldId.cidr.rawValue
        let cidrPlaceholder = ipVersion == .ipv4 ? "192.168.1.0/24" : "2001:db8::/64"
        fields.append(.text(FormFieldText(
            id: cidrFieldId,
            label: SubnetCreateField.cidr.title,
            value: cidr,
            placeholder: cidrPlaceholder,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == cidrFieldId,
            isActive: activeFieldId == cidrFieldId,
            cursorPosition: formState.textFieldStates[cidrFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 100
        )))

        // Gateway Enabled Field (Checkbox)
        let gatewayFieldId = SubnetCreateFieldId.gatewayEnabled.rawValue
        fields.append(.checkbox(FormFieldCheckbox(
            id: gatewayFieldId,
            label: SubnetCreateField.gatewayEnabled.title,
            isChecked: gatewayEnabled,
            isVisible: true,
            isSelected: selectedFieldId == gatewayFieldId,
            isDisabled: false,
            helpText: nil
        )))

        // DHCP Enabled Field (Checkbox)
        let dhcpFieldId = SubnetCreateFieldId.dhcpEnabled.rawValue
        fields.append(.checkbox(FormFieldCheckbox(
            id: dhcpFieldId,
            label: SubnetCreateField.dhcpEnabled.title,
            isChecked: dhcpEnabled,
            isVisible: true,
            isSelected: selectedFieldId == dhcpFieldId,
            isDisabled: false,
            helpText: nil
        )))

        // Allocation Pools Field (Optional)
        let poolsFieldId = SubnetCreateFieldId.allocationPools.rawValue
        fields.append(.text(FormFieldText(
            id: poolsFieldId,
            label: SubnetCreateField.allocationPools.title,
            value: allocationPools,
            placeholder: "[start-end, e.g., 192.168.1.2-192.168.1.200]",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == poolsFieldId,
            isActive: activeFieldId == poolsFieldId,
            cursorPosition: formState.textFieldStates[poolsFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        // DNS Field (Optional)
        let dnsFieldId = SubnetCreateFieldId.dns.rawValue
        fields.append(.text(FormFieldText(
            id: dnsFieldId,
            label: SubnetCreateField.dns.title,
            value: dns,
            placeholder: "[comma-separated, e.g., 8.8.8.8,8.8.4.4]",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == dnsFieldId,
            isActive: activeFieldId == dnsFieldId,
            cursorPosition: formState.textFieldStates[dnsFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        // Host Routes Field (Optional)
        let routesFieldId = SubnetCreateFieldId.hostRoutes.rawValue
        fields.append(.text(FormFieldText(
            id: routesFieldId,
            label: SubnetCreateField.hostRoutes.title,
            value: hostRoutes,
            placeholder: "[dest,nexthop, e.g., 192.168.200.0/24,10.56.1.254]",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == routesFieldId,
            isActive: activeFieldId == routesFieldId,
            cursorPosition: formState.textFieldStates[routesFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        return fields
    }
}

// MARK: - Field Identifiers

enum SubnetCreateFieldId: String {
    case name = "subnet-name"
    case network = "subnet-network"
    case ipVersion = "subnet-ip-version"
    case cidr = "subnet-cidr"
    case gatewayEnabled = "subnet-gateway-enabled"
    case dhcpEnabled = "subnet-dhcp-enabled"
    case allocationPools = "subnet-allocation-pools"
    case dns = "subnet-dns"
    case hostRoutes = "subnet-host-routes"
}