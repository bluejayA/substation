import Foundation
import OSClient

enum VolumeSnapshotFieldId: String {
    case name
    case description
}

struct VolumeSnapshotManagementForm {
    var selectedVolume: Volume?
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
        if let volume = selectedVolume {
            let volumeName = volume.name ?? "volume"
            let timestamp = Int(Date().timeIntervalSince1970)
            snapshotName = "\(volumeName)-snapshot-\(timestamp)"
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
        guard let volume = selectedVolume else { return [:] }

        let volumeName = volume.name ?? "Unnamed Volume"
        var metadata = [
            "source_volume_id": volume.id,
            "source_volume_name": volumeName,
            "snapshot_created_by": "substation",
            "snapshot_created_at": ISO8601DateFormatter().string(from: Date())
        ]

        if !snapshotDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            metadata["description"] = snapshotDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return metadata
    }

    // MARK: - FormBuilder Integration

    func buildFields(selectedFieldId: String? = nil, activeFieldId: String? = nil, formState: FormBuilderState? = nil) -> [FormField] {
        var fields: [FormField] = []

        // Snapshot Name field
        let nameId = VolumeSnapshotFieldId.name.rawValue
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
            validationError: getNameValidationError()
        )))

        // Description field
        let descId = VolumeSnapshotFieldId.description.rawValue
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

    private func getNameValidationError() -> String? {
        if snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Snapshot name is required"
        }
        return nil
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let nameState = formState.textFieldStates[VolumeSnapshotFieldId.name.rawValue] {
            snapshotName = nameState.value
        }
        if let descState = formState.textFieldStates[VolumeSnapshotFieldId.description.rawValue] {
            snapshotDescription = descState.value
        }
    }
}