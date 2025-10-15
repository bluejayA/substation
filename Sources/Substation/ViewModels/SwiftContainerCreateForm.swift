import Foundation
import OSClient

/// Swift Container Create Form
struct SwiftContainerCreateForm {
    // Form data
    var containerName: String = ""

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Container name field
        fields.append(.text(FormFieldText(
            id: "containerName",
            label: "Container Name",
            value: containerName,
            placeholder: "my-container",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == "containerName",
            isActive: activeFieldId == "containerName",
            cursorPosition: formState.getTextFieldCursorPosition("containerName"),
            validationError: validateName()
        )))

        // Info field
        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: "Container name must be unique and cannot contain '/' character.",
            isVisible: true,
            style: .info
        )))

        return fields
    }

    // Update form from state
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let name = formState.getTextValue("containerName") {
            containerName = name
        }
    }

    // Validate name
    func validateName() -> String? {
        let trimmedName = containerName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return "Container name is required"
        }

        // Check for invalid characters
        let invalidChars = CharacterSet(charactersIn: "/")
        if trimmedName.rangeOfCharacter(from: invalidChars) != nil {
            return "Container name cannot contain '/'"
        }

        return nil
    }

    // Validate the entire form
    func validateForm() -> [String] {
        var errors: [String] = []

        if let nameError = validateName() {
            errors.append(nameError)
        }

        return errors
    }

    // Check if form is valid
    func isValid() -> Bool {
        return validateForm().isEmpty
    }
}
