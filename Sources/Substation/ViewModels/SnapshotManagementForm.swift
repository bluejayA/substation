import Foundation
import OSClient

enum SnapshotFieldId: String {
    case name
    case description
}

struct SnapshotManagementForm {
    var selectedServer: Server?
    var snapshotName: String = ""
    var snapshotDescription: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?

    mutating func reset() {
        snapshotName = ""
        snapshotDescription = ""
        isLoading = false
        errorMessage = nil
        successMessage = nil
        generateDefaultSnapshotName()
    }

    mutating func generateDefaultSnapshotName() {
        if let server = selectedServer {
            let serverName = server.name ?? "server"
            let timestamp = Int(Date().timeIntervalSince1970)
            snapshotName = "\(serverName)-snapshot-\(timestamp)"
        }
    }

    // Validate the form before submission
    func isValid() -> Bool {
        return !snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Get validation error message
    func getValidationError() -> String? {
        if snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Snapshot name is required"
        }
        return nil
    }

    // Generate metadata for the snapshot
    func generateSnapshotMetadata() -> [String: String] {
        guard let server = selectedServer else { return [:] }

        let serverName = server.name ?? "Unnamed Server"
        var metadata = [
            "source_server_id": server.id,
            "source_server_name": serverName,
            "snapshot_created_by": "substation",
            "snapshot_created_at": ISO8601DateFormatter().string(from: Date())
        ]

        if !snapshotDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            metadata["description"] = snapshotDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return metadata
    }

    // Build FormBuilder fields
    func buildFields(selectedFieldId: String? = nil, activeFieldId: String? = nil, formState: FormBuilderState? = nil) -> [FormField] {
        var fields: [FormField] = []

        // Snapshot Name field
        let nameId = SnapshotFieldId.name.rawValue
        let nameValue = formState?.textFieldStates[nameId]?.value ?? snapshotName
        fields.append(.text(FormFieldText(
            id: nameId,
            label: "Snapshot Name",
            value: nameValue,
            placeholder: "Enter snapshot name",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.textFieldStates[nameId]?.cursorPosition,
            validationError: nil
        )))

        // Description field
        let descId = SnapshotFieldId.description.rawValue
        let descValue = formState?.textFieldStates[descId]?.value ?? snapshotDescription
        fields.append(.text(FormFieldText(
            id: descId,
            label: "Description",
            value: descValue,
            placeholder: "Optional description",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == descId,
            isActive: activeFieldId == descId,
            cursorPosition: formState?.textFieldStates[descId]?.cursorPosition,
            validationError: nil
        )))

        return fields
    }
}
