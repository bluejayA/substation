import Foundation

enum NetworkCreateFieldId: String, CaseIterable {
    case name = "name"
    case description = "description"
    case mtu = "mtu"
    case portSecurity = "portSecurity"

    var title: String {
        switch self {
        case .name:
            return "Network Name"
        case .description:
            return "Description"
        case .mtu:
            return "MTU"
        case .portSecurity:
            return "Port Security"
        }
    }
}

struct NetworkCreateForm {
    private static let networkNamePlaceholder = "Enter network name"
    private static let networkDescriptionPlaceholder = "Enter description"
    private static let mtuPlaceholder = "Default: 1500"
    private static let networkNameRequiredError = "Network name is required"
    private static let networkNameInvalidCharsError = "Network name can only contain letters, numbers, spaces, and @._- characters"
    private static let mtuRequiredError = "MTU is required"
    private static let mtuInvalidError = "MTU must be a number between 68 and 9000"
    private static let portSecurityEnabledLabel = "Enabled"
    private static let portSecurityDisabledLabel = "Disabled"

    var networkName: String = ""
    var networkDescription: String = ""
    var mtu: String = "1500"
    var portSecurityEnabled: Bool = true

    var errorMessage: String? = nil
    var isLoading: Bool = false

    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState? = nil) -> [FormField] {
        var fields: [FormField] = []

        let nameId = NetworkCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameId,
            label: NetworkCreateFieldId.name.title,
            value: networkName,
            placeholder: Self.networkNamePlaceholder,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.getTextFieldCursorPosition(nameId),
            validationError: getNameValidationError()
        )))

        let descriptionId = NetworkCreateFieldId.description.rawValue
        fields.append(.text(FormFieldText(
            id: descriptionId,
            label: NetworkCreateFieldId.description.title,
            value: networkDescription,
            placeholder: Self.networkDescriptionPlaceholder,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == descriptionId,
            isActive: activeFieldId == descriptionId,
            cursorPosition: formState?.getTextFieldCursorPosition(descriptionId)
        )))

        let mtuId = NetworkCreateFieldId.mtu.rawValue
        fields.append(.text(FormFieldText(
            id: mtuId,
            label: NetworkCreateFieldId.mtu.title,
            value: mtu,
            placeholder: Self.mtuPlaceholder,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == mtuId,
            isActive: activeFieldId == mtuId,
            cursorPosition: formState?.getTextFieldCursorPosition(mtuId),
            validationError: getMtuValidationError()
        )))

        let portSecurityId = NetworkCreateFieldId.portSecurity.rawValue
        fields.append(.toggle(FormFieldToggle(
            id: portSecurityId,
            label: NetworkCreateFieldId.portSecurity.title,
            value: portSecurityEnabled,
            isVisible: true,
            isSelected: selectedFieldId == portSecurityId,
            enabledLabel: Self.portSecurityEnabledLabel,
            disabledLabel: Self.portSecurityDisabledLabel
        )))

        return fields
    }

    private func getNameValidationError() -> String? {
        let trimmedName = networkName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return Self.networkNameRequiredError
        }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@._- ")
        if trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return Self.networkNameInvalidCharsError
        }

        return nil
    }

    private func getMtuValidationError() -> String? {
        let trimmedMtu = mtu.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedMtu.isEmpty {
            return Self.mtuRequiredError
        }

        guard let mtuValue = Int(trimmedMtu), mtuValue >= 68 && mtuValue <= 9000 else {
            return Self.mtuInvalidError
        }

        return nil
    }

    func validateForm() -> [String] {
        var errors: [String] = []

        if let nameError = getNameValidationError() {
            errors.append(nameError)
        }

        if let mtuError = getMtuValidationError() {
            errors.append(mtuError)
        }

        return errors
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let name = formState.getTextValue(NetworkCreateFieldId.name.rawValue) {
            networkName = name
        }

        if let description = formState.getTextValue(NetworkCreateFieldId.description.rawValue) {
            networkDescription = description
        }

        if let mtuValue = formState.getTextValue(NetworkCreateFieldId.mtu.rawValue) {
            mtu = mtuValue
        }

        if let portSecurity = formState.getToggleValue(NetworkCreateFieldId.portSecurity.rawValue) {
            portSecurityEnabled = portSecurity
        }
    }

    func getTrimmedName() -> String {
        return networkName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTrimmedDescription() -> String {
        return networkDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getMtu() -> Int? {
        return Int(mtu.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func getMTUValue() -> Int? {
        return getMtu()
    }
}