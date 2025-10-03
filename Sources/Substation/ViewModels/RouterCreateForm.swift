import Foundation
import OSClient

enum RouterCreateFieldId: String, CaseIterable {
    case name = "name"
    case description = "description"
    case availabilityZone = "availabilityZone"
    case externalGateway = "externalGateway"
    case externalNetwork = "externalNetwork"

    var title: String {
        switch self {
        case .name:
            return "Router Name"
        case .description:
            return "Description"
        case .availabilityZone:
            return "Availability Zone"
        case .externalGateway:
            return "External Gateway"
        case .externalNetwork:
            return "External Network"
        }
    }
}

struct AvailabilityZoneItem: FormSelectableItem, FormSelectorItem {
    let name: String

    var id: String { name }
    var sortKey: String { name }

    func matchesSearch(_ query: String) -> Bool {
        name.lowercased().contains(query.lowercased())
    }
}

struct RouterCreateForm {
    private static let routerNamePlaceholder = "Enter router name"
    private static let routerDescriptionPlaceholder = "Enter description"
    private static let routerNameRequiredError = "Router name is required"
    private static let routerNameInvalidCharsError = "Router name can only contain letters, numbers, spaces, and @._- characters"
    private static let availabilityZoneRequiredError = "Availability zone is required"
    private static let externalNetworkRequiredError = "External network is required when external gateway is enabled"
    private static let noAvailabilityZonesError = "No availability zones available"
    private static let noExternalNetworksError = "No external networks available for gateway"
    private static let externalGatewayEnabledLabel = "Enabled"
    private static let externalGatewayDisabledLabel = "Disabled"

    var routerName: String = ""
    var routerDescription: String = ""
    var selectedAvailabilityZoneId: String?
    var externalGatewayEnabled: Bool = false
    var selectedExternalNetworkId: String?

    var errorMessage: String? = nil
    var isLoading: Bool = false

    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState? = nil, availabilityZones: [String], externalNetworks: [Network]) -> [FormField] {
        var fields: [FormField] = []

        let nameId = RouterCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameId,
            label: RouterCreateFieldId.name.title,
            value: routerName,
            placeholder: Self.routerNamePlaceholder,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.getTextFieldCursorPosition(nameId),
            validationError: getNameValidationError()
        )))

        let descriptionId = RouterCreateFieldId.description.rawValue
        fields.append(.text(FormFieldText(
            id: descriptionId,
            label: RouterCreateFieldId.description.title,
            value: routerDescription,
            placeholder: Self.routerDescriptionPlaceholder,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == descriptionId,
            isActive: activeFieldId == descriptionId,
            cursorPosition: formState?.getTextFieldCursorPosition(descriptionId)
        )))

        let availabilityZoneId = RouterCreateFieldId.availabilityZone.rawValue
        let azItems = availabilityZones.map { AvailabilityZoneItem(name: $0) }
        fields.append(.selector(FormFieldSelector(
            id: availabilityZoneId,
            label: RouterCreateFieldId.availabilityZone.title,
            items: azItems,
            selectedItemId: selectedAvailabilityZoneId,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == availabilityZoneId,
            isActive: activeFieldId == availabilityZoneId,
            validationError: getAvailabilityZoneValidationError(availabilityZones: availabilityZones),
            columns: [
                FormSelectorItemColumn(header: "AVAILABILITY ZONE", width: 40) { item in
                    (item as? AvailabilityZoneItem)?.name ?? ""
                }
            ],
            searchQuery: formState?.selectorStates[availabilityZoneId]?.searchQuery,
            highlightedIndex: formState?.selectorStates[availabilityZoneId]?.highlightedIndex ?? 0,
            scrollOffset: formState?.selectorStates[availabilityZoneId]?.scrollOffset ?? 0
        )))

        let externalGatewayId = RouterCreateFieldId.externalGateway.rawValue
        fields.append(.toggle(FormFieldToggle(
            id: externalGatewayId,
            label: RouterCreateFieldId.externalGateway.title,
            value: externalGatewayEnabled,
            isVisible: true,
            isSelected: selectedFieldId == externalGatewayId,
            enabledLabel: Self.externalGatewayEnabledLabel,
            disabledLabel: Self.externalGatewayDisabledLabel
        )))

        if externalGatewayEnabled {
            let externalNetworkId = RouterCreateFieldId.externalNetwork.rawValue
            let networkItems = externalNetworks.filter { $0.external == true }
            fields.append(.selector(FormFieldSelector(
                id: externalNetworkId,
                label: RouterCreateFieldId.externalNetwork.title,
                items: networkItems,
                selectedItemId: selectedExternalNetworkId,
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == externalNetworkId,
                isActive: activeFieldId == externalNetworkId,
                validationError: getExternalNetworkValidationError(externalNetworks: externalNetworks),
                columns: [
                    FormSelectorItemColumn(header: "NETWORK NAME", width: 30) { item in
                        (item as? Network)?.name ?? "Unnamed"
                    },
                    FormSelectorItemColumn(header: "NETWORK ID", width: 36) { item in
                        (item as? Network)?.id ?? ""
                    }
                ],
                searchQuery: formState?.selectorStates[externalNetworkId]?.searchQuery,
                highlightedIndex: formState?.selectorStates[externalNetworkId]?.highlightedIndex ?? 0,
                scrollOffset: formState?.selectorStates[externalNetworkId]?.scrollOffset ?? 0
            )))
        }

        return fields
    }

    private func getNameValidationError() -> String? {
        let trimmedName = routerName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return Self.routerNameRequiredError
        }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@._- ")
        if trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return Self.routerNameInvalidCharsError
        }

        return nil
    }

    private func getAvailabilityZoneValidationError(availabilityZones: [String]) -> String? {
        if availabilityZones.isEmpty {
            return Self.noAvailabilityZonesError
        }

        if selectedAvailabilityZoneId == nil {
            return Self.availabilityZoneRequiredError
        }

        return nil
    }

    private func getExternalNetworkValidationError(externalNetworks: [Network]) -> String? {
        guard externalGatewayEnabled else { return nil }

        let externalOnly = externalNetworks.filter { $0.external == true }
        if externalOnly.isEmpty {
            return Self.noExternalNetworksError
        }

        if selectedExternalNetworkId == nil {
            return Self.externalNetworkRequiredError
        }

        return nil
    }

    func validateForm(availabilityZones: [String], externalNetworks: [Network]) -> [String] {
        var errors: [String] = []

        if let nameError = getNameValidationError() {
            errors.append(nameError)
        }

        if let azError = getAvailabilityZoneValidationError(availabilityZones: availabilityZones) {
            errors.append(azError)
        }

        if let networkError = getExternalNetworkValidationError(externalNetworks: externalNetworks) {
            errors.append(networkError)
        }

        return errors
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let name = formState.getTextValue(RouterCreateFieldId.name.rawValue) {
            routerName = name
        }

        if let description = formState.getTextValue(RouterCreateFieldId.description.rawValue) {
            routerDescription = description
        }

        if let azId = formState.selectorStates[RouterCreateFieldId.availabilityZone.rawValue]?.selectedItemId {
            selectedAvailabilityZoneId = azId
        }

        if let gatewayEnabled = formState.getToggleValue(RouterCreateFieldId.externalGateway.rawValue) {
            externalGatewayEnabled = gatewayEnabled
        }

        if let networkId = formState.selectorStates[RouterCreateFieldId.externalNetwork.rawValue]?.selectedItemId {
            selectedExternalNetworkId = networkId
        }
    }

    func getTrimmedName() -> String {
        return routerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedDescription() -> String {
        return routerDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}