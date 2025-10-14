import Foundation
import OSClient

/// Swift Container Metadata Form
struct SwiftContainerMetadataForm {
    // Container info
    var containerName: String = ""

    // Form data
    var readACL: String = ""
    var writeACL: String = ""
    var customMetadata: [String: String] = [:]

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Container name (read-only)
        fields.append(.info(FormFieldInfo(
            id: "containerName",
            label: "Container",
            value: containerName,
            isVisible: true,
            style: .accent
        )))

        // Read ACL field
        fields.append(.text(FormFieldText(
            id: "readACL",
            label: "Read ACL",
            value: readACL,
            placeholder: ".r:*,.rlistings (optional)",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == "readACL",
            isActive: activeFieldId == "readACL",
            cursorPosition: formState.getTextFieldCursorPosition("readACL"),
            validationError: nil
        )))

        // Write ACL field
        fields.append(.text(FormFieldText(
            id: "writeACL",
            label: "Write ACL",
            value: writeACL,
            placeholder: "user:project:user_id (optional)",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == "writeACL",
            isActive: activeFieldId == "writeACL",
            cursorPosition: formState.getTextFieldCursorPosition("writeACL"),
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
            value: "Read ACL: .r:* for public read, .rlistings for listing. Write ACL: user:project:user_id",
            isVisible: true,
            style: .info
        )))

        return fields
    }

    // Update form from state
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let acl = formState.getTextValue("readACL") {
            readACL = acl
        }
        if let acl = formState.getTextValue("writeACL") {
            writeACL = acl
        }
    }

    // Validate the entire form
    func validateForm() -> [String] {
        let errors: [String] = []

        // No strict validation - ACLs are optional and can be any format

        return errors
    }

    // Check if form is valid
    func isValid() -> Bool {
        return validateForm().isEmpty
    }

    // Initialize from metadata response
    mutating func loadFromMetadata(_ metadata: SwiftContainerMetadataResponse) {
        self.containerName = metadata.containerName
        self.readACL = metadata.readACL ?? ""
        self.writeACL = metadata.writeACL ?? ""
        self.customMetadata = metadata.metadata
    }
}
