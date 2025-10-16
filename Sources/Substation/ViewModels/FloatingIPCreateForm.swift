import Foundation
import OSClient
import struct OSClient.Port

enum FloatingIPCreateFieldId: String, CaseIterable {
    case description = "description"
    case floatingNetwork = "floating_network"
    case subnet = "subnet"
    case specificIP = "specific_ip"
    case dnsName = "dns_name"
    case dnsDomain = "dns_domain"

    var title: String {
        switch self {
        case .description: return "Description"
        case .floatingNetwork: return "External Network"
        case .subnet: return "Subnet"
        case .specificIP: return "Specific IP Address"
        case .dnsName: return "DNS Name"
        case .dnsDomain: return "DNS Domain"
        }
    }
}

struct FloatingIPCreateForm {

    // MARK: - Constants

    private static let descriptionPlaceholder = "Optional description"
    private static let specificIPPlaceholder = "Leave empty for auto-assignment"
    private static let dnsNamePlaceholder = "DNS name for floating IP"
    private static let dnsDomainPlaceholder = "DNS domain"

    // Error Messages
    private static let floatingNetworkRequiredError = "External network selection is required"
    private static let noExternalNetworksAvailableError = "No external networks available"
    private static let selectedNetworkInvalidError = "Selected external network is no longer available"
    private static let specificIPInvalidError = "Invalid IP address format"
    private static let subnetSelectionInvalidError = "Selected subnet is no longer available"
    private static let dnsNameInvalidError = "Invalid DNS name format"
    private static let dnsDomainInvalidError = "Invalid DNS domain format"

    // MARK: - Properties

    var description: String = ""
    var specificIPAddress: String = ""
    var dnsName: String = ""
    var dnsDomain: String = ""

    var selectedExternalNetworkID: String?
    var selectedSubnetID: String?

    var errorMessage: String? = nil
    var isLoading: Bool = false

    // MARK: - Field Generation

    func buildFields(externalNetworks: [Network], subnets: [Subnet], selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState? = nil) -> [FormField] {
        var fields: [FormField] = []

        // Description (optional text field)
        let descriptionId = FloatingIPCreateFieldId.description.rawValue
        fields.append(.text(FormFieldText(
            id: descriptionId,
            label: FloatingIPCreateFieldId.description.title,
            value: description,
            placeholder: Self.descriptionPlaceholder,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == descriptionId,
            isActive: activeFieldId == descriptionId,
            cursorPosition: formState?.getTextFieldCursorPosition(descriptionId),
            validationError: nil
        )))

        // External Network (required selector)
        let networkId = FloatingIPCreateFieldId.floatingNetwork.rawValue
        fields.append(.selector(FormFieldSelector(
            id: networkId,
            label: FloatingIPCreateFieldId.floatingNetwork.title,
            items: externalNetworks.map { $0 as any FormSelectorItem },
            selectedItemId: selectedExternalNetworkID,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == networkId,
            isActive: activeFieldId == networkId,
            validationError: getNetworkValidationError(externalNetworks: externalNetworks),
            columns: [
                FormSelectorItemColumn(header: "Name", width: 40) { item in
                    if let network = item as? Network {
                        return network.name ?? network.id
                    }
                    return item.id
                }
            ],
            searchQuery: formState?.getSelectorState(networkId)?.searchQuery,
            highlightedIndex: formState?.getSelectorState(networkId)?.highlightedIndex ?? 0,
            scrollOffset: formState?.getSelectorState(networkId)?.scrollOffset ?? 0
        )))

        // Subnet (optional selector, only visible when network is selected)
        if selectedExternalNetworkID != nil {
            let filteredSubnets = getFilteredSubnets(externalNetworks: externalNetworks, allSubnets: subnets)
            let subnetId = FloatingIPCreateFieldId.subnet.rawValue
            fields.append(.selector(FormFieldSelector(
                id: subnetId,
                label: FloatingIPCreateFieldId.subnet.title,
                items: filteredSubnets.map { $0 as any FormSelectorItem },
                selectedItemId: selectedSubnetID,
                isRequired: false,
                isVisible: true,
                isSelected: selectedFieldId == subnetId,
                isActive: activeFieldId == subnetId,
                validationError: getSubnetValidationError(subnets: filteredSubnets),
                columns: [
                    FormSelectorItemColumn(header: "Name", width: 40) { item in
                        if let subnet = item as? Subnet {
                            return subnet.name ?? subnet.id
                        }
                        return item.id
                    }
                ],
                searchQuery: formState?.getSelectorState(subnetId)?.searchQuery,
                highlightedIndex: formState?.getSelectorState(subnetId)?.highlightedIndex ?? 0,
                scrollOffset: formState?.getSelectorState(subnetId)?.scrollOffset ?? 0
            )))
        }

        // Specific IP Address (optional text field, only visible when network is selected)
        if selectedExternalNetworkID != nil {
            let specificIPId = FloatingIPCreateFieldId.specificIP.rawValue
            fields.append(.text(FormFieldText(
                id: specificIPId,
                label: FloatingIPCreateFieldId.specificIP.title,
                value: specificIPAddress,
                placeholder: Self.specificIPPlaceholder,
                isRequired: false,
                isVisible: true,
                isSelected: selectedFieldId == specificIPId,
                isActive: activeFieldId == specificIPId,
                cursorPosition: formState?.getTextFieldCursorPosition(specificIPId),
                validationError: getSpecificIPValidationError(externalNetworks: externalNetworks)
            )))
        }

        // DNS Name (optional text field)
        let dnsNameId = FloatingIPCreateFieldId.dnsName.rawValue
        fields.append(.text(FormFieldText(
            id: dnsNameId,
            label: FloatingIPCreateFieldId.dnsName.title,
            value: dnsName,
            placeholder: Self.dnsNamePlaceholder,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == dnsNameId,
            isActive: activeFieldId == dnsNameId,
            cursorPosition: formState?.getTextFieldCursorPosition(dnsNameId),
            validationError: getDNSNameValidationError()
        )))

        // DNS Domain (optional text field)
        let dnsDomainId = FloatingIPCreateFieldId.dnsDomain.rawValue
        fields.append(.text(FormFieldText(
            id: dnsDomainId,
            label: FloatingIPCreateFieldId.dnsDomain.title,
            value: dnsDomain,
            placeholder: Self.dnsDomainPlaceholder,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == dnsDomainId,
            isActive: activeFieldId == dnsDomainId,
            cursorPosition: formState?.getTextFieldCursorPosition(dnsDomainId),
            validationError: getDNSDomainValidationError()
        )))

        return fields
    }

    private func getFilteredSubnets(externalNetworks: [Network], allSubnets: [Subnet]) -> [Subnet] {
        guard let selectedNetworkID = selectedExternalNetworkID,
              let selectedNetwork = externalNetworks.first(where: { $0.id == selectedNetworkID }),
              let networkSubnetIds = selectedNetwork.subnets else {
            return []
        }
        return allSubnets.filter { networkSubnetIds.contains($0.id) }
    }

    // MARK: - Validation

    private func getNetworkValidationError(externalNetworks: [Network]) -> String? {
        if externalNetworks.isEmpty {
            return Self.noExternalNetworksAvailableError
        } else if selectedExternalNetworkID == nil {
            return Self.floatingNetworkRequiredError
        } else if !externalNetworks.contains(where: { $0.id == selectedExternalNetworkID }) {
            return Self.selectedNetworkInvalidError
        }
        return nil
    }

    private func getSpecificIPValidationError(externalNetworks: [Network]) -> String? {
        let trimmedIP = specificIPAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else { return nil }

        let ipComponents = trimmedIP.components(separatedBy: ".")
        guard ipComponents.count == 4 else {
            return Self.specificIPInvalidError
        }

        for component in ipComponents {
            guard let octet = Int(component), octet >= 0 && octet <= 255 else {
                return Self.specificIPInvalidError
            }
        }

        return nil
    }

    private func getSubnetValidationError(subnets: [Subnet]) -> String? {
        guard let selectedID = selectedSubnetID else { return nil }
        if !subnets.contains(where: { $0.id == selectedID }) {
            return Self.subnetSelectionInvalidError
        }
        return nil
    }

    private func getDNSNameValidationError() -> String? {
        let trimmedName = dnsName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let dnsNamePattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$"
        let regex = try? NSRegularExpression(pattern: dnsNamePattern)
        let range = NSRange(location: 0, length: trimmedName.utf16.count)

        if regex?.firstMatch(in: trimmedName, options: [], range: range) == nil {
            return Self.dnsNameInvalidError
        }
        return nil
    }

    private func getDNSDomainValidationError() -> String? {
        let trimmedDomain = dnsDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDomain.isEmpty else { return nil }

        let domainPattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$"
        let regex = try? NSRegularExpression(pattern: domainPattern)
        let range = NSRange(location: 0, length: trimmedDomain.utf16.count)

        if regex?.firstMatch(in: trimmedDomain, options: [], range: range) == nil {
            return Self.dnsDomainInvalidError
        }
        return nil
    }

    func validateForm() -> [String] {
        var errors: [String] = []

        // Validate external network selection
        if selectedExternalNetworkID == nil {
            errors.append("External network selection is required")
        }

        // Validate specific IP format if provided
        if let specificIPError = getSpecificIPValidationError(externalNetworks: []) {
            if !specificIPAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(specificIPError)
            }
        }

        // Validate DNS name if provided
        if let dnsNameError = getDNSNameValidationError() {
            errors.append(dnsNameError)
        }

        // Validate DNS domain if provided
        if let dnsDomainError = getDNSDomainValidationError() {
            errors.append(dnsDomainError)
        }

        return errors
    }

    // MARK: - Form Updates

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let desc = formState.getTextValue(FloatingIPCreateFieldId.description.rawValue) {
            description = desc
        }

        if let networkId = formState.getSelectorSelectedId(FloatingIPCreateFieldId.floatingNetwork.rawValue) {
            selectedExternalNetworkID = networkId
        }

        if let subnetId = formState.getSelectorSelectedId(FloatingIPCreateFieldId.subnet.rawValue) {
            selectedSubnetID = subnetId
        }

        if let specificIP = formState.getTextValue(FloatingIPCreateFieldId.specificIP.rawValue) {
            specificIPAddress = specificIP
        }

        if let name = formState.getTextValue(FloatingIPCreateFieldId.dnsName.rawValue) {
            dnsName = name
        }

        if let domain = formState.getTextValue(FloatingIPCreateFieldId.dnsDomain.rawValue) {
            dnsDomain = domain
        }
    }

    // MARK: - Utility Methods

    func getTrimmedDescription() -> String {
        return description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedSpecificIP() -> String {
        return specificIPAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedDNSName() -> String {
        return dnsName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedDNSDomain() -> String {
        return dnsDomain.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getSelectedExternalNetworkId(externalNetworks: [Network]) -> String? {
        return selectedExternalNetworkID
    }

    func getSelectedSubnetId(externalNetworks: [Network], subnets: [Subnet]) -> String? {
        return selectedSubnetID
    }

    func getSelectedQosPolicyId(qosPolicies: [QoSPolicy]) -> String? {
        return nil
    }
}
