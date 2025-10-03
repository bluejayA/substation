import Foundation
import OSClient

enum VolumeBackupFieldId: String {
    case name
    case description
    case incremental
}

struct VolumeBackupManagementForm {
    var selectedVolume: Volume?
    var backupName: String = ""
    var backupDescription: String = ""
    var incremental: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?
    var availableBackups: [VolumeBackup] = [] // Used to check if full backup exists

    mutating func reset() {
        backupName = ""
        backupDescription = ""
        incremental = false
        isLoading = false
        errorMessage = nil
        successMessage = nil
        generateDefaultBackupName()
    }

    mutating func generateDefaultBackupName() {
        if let volume = selectedVolume {
            let volumeName = volume.name ?? "volume"
            let timestamp = Int(Date().timeIntervalSince1970)
            backupName = "\(volumeName)-backup-\(timestamp)"
        }
    }

    // Validate the form before submission
    func isValid() -> Bool {
        return !backupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Get validation error message
    func getValidationError() -> String? {
        if backupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Backup name is required"
        }
        return nil
    }

    // Check if at least one full backup exists for this volume
    func hasFullBackup() -> Bool {
        guard let volumeId = selectedVolume?.id else { return false }

        // Check if there's at least one non-incremental (full) backup for this volume
        return availableBackups.contains { backup in
            backup.volumeId == volumeId && backup.isIncremental == false
        }
    }

    // Check if incremental backup is allowed
    func canCreateIncrementalBackup() -> Bool {
        return hasFullBackup()
    }

    // MARK: - FormBuilder Integration

    func buildFields(selectedFieldId: String? = nil, activeFieldId: String? = nil, formState: FormBuilderState? = nil) -> [FormField] {
        var fields: [FormField] = []

        // Backup Name field
        let nameId = VolumeBackupFieldId.name.rawValue
        let nameValue = formState?.textFieldStates[nameId]?.value ?? backupName
        fields.append(.text(FormFieldText(
            id: nameId,
            label: "Backup Name",
            value: nameValue,
            placeholder: "Enter backup name",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.textFieldStates[nameId]?.cursorPosition,
            validationError: getNameValidationError()
        )))

        // Description field
        let descId = VolumeBackupFieldId.description.rawValue
        let descValue = formState?.textFieldStates[descId]?.value ?? backupDescription
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

        // Incremental backup checkbox
        let incrementalId = VolumeBackupFieldId.incremental.rawValue
        let canUseIncremental = canCreateIncrementalBackup()
        let incrementalValue = canUseIncremental && (formState?.checkboxStates[incrementalId]?.isChecked ?? incremental)

        let helpText: String
        if canUseIncremental {
            helpText = "Create incremental backup (only changed blocks)"
        } else {
            helpText = "Requires at least one full backup to exist for this volume"
        }

        fields.append(.checkbox(FormFieldCheckbox(
            id: incrementalId,
            label: "Incremental Backup",
            isChecked: incrementalValue,
            isVisible: true,
            isSelected: selectedFieldId == incrementalId,
            isDisabled: !canUseIncremental,
            helpText: helpText
        )))

        return fields
    }

    private func getNameValidationError() -> String? {
        if backupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Backup name is required"
        }
        return nil
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let nameState = formState.textFieldStates[VolumeBackupFieldId.name.rawValue] {
            backupName = nameState.value
        }
        if let descState = formState.textFieldStates[VolumeBackupFieldId.description.rawValue] {
            backupDescription = descState.value
        }
        if let incrementalState = formState.checkboxStates[VolumeBackupFieldId.incremental.rawValue] {
            incremental = incrementalState.isChecked
        }
    }
}
