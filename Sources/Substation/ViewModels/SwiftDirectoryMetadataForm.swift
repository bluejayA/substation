import Foundation
import OSClient

/// Swift Directory Metadata Form
/// Allows applying metadata to all objects within a directory path
struct SwiftDirectoryMetadataForm {
    // Directory info
    var containerName: String = ""
    var directoryPath: String = ""

    // Form data
    var contentType: String = ""
    var recursive: Bool = false

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Directory info (read-only)
        fields.append(.info(FormFieldInfo(
            id: "directoryInfo",
            label: "Directory",
            value: "\(containerName) / \(directoryPath)",
            isVisible: true,
            style: .accent
        )))

        // Content-Type field
        fields.append(.text(FormFieldText(
            id: "contentType",
            label: "Content-Type",
            value: contentType,
            placeholder: "application/octet-stream",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == "contentType",
            isActive: activeFieldId == "contentType",
            cursorPosition: formState.getTextFieldCursorPosition("contentType"),
            validationError: nil
        )))

        // Recursive checkbox
        fields.append(.checkbox(FormFieldCheckbox(
            id: "recursive",
            label: "Recursive (apply to subdirectories)",
            isChecked: recursive,
            isVisible: true,
            isSelected: selectedFieldId == "recursive"
        )))

        // Info field
        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: "This will update Content-Type for ALL objects in this directory. Recursive applies to subdirectories.",
            isVisible: true,
            style: .warning
        )))

        return fields
    }

    // Update form from state
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let ct = formState.getTextValue("contentType") {
            contentType = ct
        }
        if let rec = formState.getCheckboxValue("recursive") {
            recursive = rec
        }
    }

    // Validate the entire form
    func validateForm() -> [String] {
        let errors: [String] = []

        // No strict validation - content type is optional

        return errors
    }

    // Check if form is valid
    func isValid() -> Bool {
        return validateForm().isEmpty
    }

    // Initialize for a directory
    mutating func initializeForDirectory(containerName: String, directoryPath: String) {
        self.containerName = containerName
        self.directoryPath = directoryPath
        self.contentType = ""
        self.recursive = false
    }
}
