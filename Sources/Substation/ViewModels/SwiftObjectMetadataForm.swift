import Foundation
import OSClient

/// Swift Object Metadata Form
struct SwiftObjectMetadataForm {
    // Object info
    var containerName: String = ""
    var objectName: String = ""

    // Form data
    var contentType: String = ""
    var customMetadata: [String: String] = [:]

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Object name (read-only)
        fields.append(.info(FormFieldInfo(
            id: "objectInfo",
            label: "Object",
            value: "\(containerName) / \(objectName)",
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

        // Custom metadata info
        if !customMetadata.isEmpty {
            fields.append(.info(FormFieldInfo(
                id: "metadataHeader",
                label: "Custom Metadata",
                value: "\(customMetadata.count) metadata entries",
                isVisible: true,
                style: .info
            )))

            // Display each metadata entry (read-only for now)
            for (index, (key, value)) in customMetadata.sorted(by: { $0.key < $1.key }).enumerated() {
                fields.append(.info(FormFieldInfo(
                    id: "metadata_\(index)",
                    label: "  \(key)",
                    value: value,
                    isVisible: true,
                    style: .info
                )))
            }
        }

        // Info field
        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: "Content-Type determines how the object is served. Common types: text/plain, application/json, image/png",
            isVisible: true,
            style: .info
        )))

        return fields
    }

    // Update form from state
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let ct = formState.getTextValue("contentType") {
            contentType = ct
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

    // Initialize from metadata response
    mutating func loadFromMetadata(containerName: String, metadata: SwiftObjectMetadataResponse) {
        self.containerName = containerName
        self.objectName = metadata.objectName
        self.contentType = metadata.contentType ?? ""
        self.customMetadata = metadata.metadata
    }
}
