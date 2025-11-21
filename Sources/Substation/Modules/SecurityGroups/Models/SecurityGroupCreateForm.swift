import Foundation
import OSClient

enum SecurityGroupCreateField: CaseIterable {
    case name, description

    var title: String {
        switch self {
        case .name: return "Security Group Name"
        case .description: return "Description (Optional)"
        }
    }
}

struct SecurityGroupCreateForm: FormViewModel {
    var securityGroupName: String = ""
    var securityGroupDescription: String = ""
    var currentField: SecurityGroupCreateField = .name
    var fieldEditMode: Bool = false // true when editing a text field

    mutating func nextField() {
        let fields = SecurityGroupCreateField.allCases
        if let currentIndex = fields.firstIndex(of: currentField) {
            let nextIndex = (currentIndex + 1) % fields.count
            currentField = fields[nextIndex]
        }
        fieldEditMode = false
    }

    mutating func previousField() {
        let fields = SecurityGroupCreateField.allCases
        if let currentIndex = fields.firstIndex(of: currentField) {
            let prevIndex = currentIndex == 0 ? fields.count - 1 : currentIndex - 1
            currentField = fields[prevIndex]
        }
        fieldEditMode = false
    }

    mutating func appendToCurrentField(_ input: String) {
        switch currentField {
        case .name:
            securityGroupName += input
        case .description:
            securityGroupDescription += input
        }
    }

    mutating func backspaceCurrentField() {
        switch currentField {
        case .name:
            if !securityGroupName.isEmpty {
                securityGroupName.removeLast()
            }
        case .description:
            if !securityGroupDescription.isEmpty {
                securityGroupDescription.removeLast()
            }
        }
    }

    mutating func clearCurrentField() {
        switch currentField {
        case .name:
            securityGroupName = ""
        case .description:
            securityGroupDescription = ""
        }
    }

    func validateForm() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []

        // Name validation
        if securityGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Security group name is required")
        } else if securityGroupName.count > 255 {
            errors.append("Security group name must be 255 characters or less")
        }

        // Description validation (optional, but if provided, check length)
        if !securityGroupDescription.isEmpty && securityGroupDescription.count > 255 {
            errors.append("Description must be 255 characters or less")
        }

        return (errors.isEmpty, errors)
    }

    func getFieldValue(_ field: SecurityGroupCreateField) -> String {
        switch field {
        case .name:
            return securityGroupName
        case .description:
            return securityGroupDescription
        }
    }

    mutating func reset() {
        securityGroupName = ""
        securityGroupDescription = ""
        currentField = .name
        fieldEditMode = false
    }

    // Navigation helpers
    func isOnFirstField() -> Bool {
        return currentField == SecurityGroupCreateField.allCases.first
    }

    func isOnLastField() -> Bool {
        return currentField == SecurityGroupCreateField.allCases.last
    }

    // MARK: - FormViewModel Protocol

    func getFieldConfigurations() -> [FormFieldConfiguration] {
        let fields = SecurityGroupCreateField.allCases
        let validationState = getValidationState()

        return fields.map { field in
            let isSelected = field == currentField
            let isActive = fieldEditMode && isSelected
            let hasError = !validationState.isValid && getFieldError(field, from: validationState.errors) != nil
            let errorMessage = getFieldError(field, from: validationState.errors)

            switch field {
            case .name:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: true,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    placeholder: "Enter security group name",
                    value: securityGroupName,
                    fieldType: .text
                )

            case .description:
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: false,
                    isSelected: isSelected,
                    isActive: isActive,
                    hasError: hasError,
                    errorMessage: errorMessage,
                    placeholder: "Enter description (optional)",
                    value: securityGroupDescription,
                    fieldType: .text
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
        return "Create Security Group"
    }

    func getNavigationHelp() -> String {
        if fieldEditMode {
            return "Type to edit | Esc to cancel | Enter to confirm"
        } else {
            return "UP/DOWN Navigate | Enter Edit | Esc Cancel"
        }
    }

    func isInSpecialMode() -> Bool {
        return fieldEditMode
    }

    private func getFieldError(_ field: SecurityGroupCreateField, from errors: [String]) -> String? {
        // Map validation errors to specific fields
        for error in errors {
            switch field {
            case .name:
                if error.contains("name") {
                    return error
                }
            case .description:
                if error.contains("Description") {
                    return error
                }
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

        // Security Group Name Field
        let nameFieldId = SecurityGroupCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameFieldId,
            label: SecurityGroupCreateField.name.title,
            value: securityGroupName,
            placeholder: "Enter security group name",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameFieldId,
            isActive: activeFieldId == nameFieldId,
            cursorPosition: formState.textFieldStates[nameFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        // Description Field
        let descriptionFieldId = SecurityGroupCreateFieldId.description.rawValue
        fields.append(.text(FormFieldText(
            id: descriptionFieldId,
            label: SecurityGroupCreateField.description.title,
            value: securityGroupDescription,
            placeholder: "Enter description (optional)",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == descriptionFieldId,
            isActive: activeFieldId == descriptionFieldId,
            cursorPosition: formState.textFieldStates[descriptionFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        return fields
    }
}

// MARK: - Field Identifiers

enum SecurityGroupCreateFieldId: String {
    case name = "security-group-name"
    case description = "security-group-description"
}