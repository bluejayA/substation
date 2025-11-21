import Foundation
import OSClient

enum VolumeCreateFieldId: String, CaseIterable {
    case name = "name"
    case size = "size"
    case maxVolumes = "maxVolumes"
    case sourceType = "sourceType"
    case source = "source"
    case volumeType = "volumeType"

    var title: String {
        switch self {
        case .name: return "Volume Name"
        case .size: return "Volume Size"
        case .maxVolumes: return "Max Volumes"
        case .sourceType: return "Source Type"
        case .source: return "Source"
        case .volumeType: return "Volume Type"
        }
    }
}

enum VolumeSourceType: CaseIterable {
    case blank, image, snapshot

    var title: String {
        switch self {
        case .blank: return "Create Empty Volume"
        case .image: return "Create from Image"
        case .snapshot: return "Create from Snapshot"
        }
    }
}

struct SourceTypeOption: FormSelectorItem, FormSelectableItem {
    let id: String
    let name: String
    let sourceType: VolumeSourceType

    var sortKey: String {
        return name
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowerQuery = query.lowercased()
        return name.lowercased().contains(lowerQuery)
    }
}

struct VolumeCreateForm {
    var volumeName: String = ""
    var volumeSize: String = ""
    var maxVolumes: String = "1"
    var sourceType: VolumeSourceType = .blank

    // Image selection
    var selectedImageID: String? = nil

    // Snapshot selection
    var selectedSnapshotID: String? = nil

    // Volume type selection
    var selectedVolumeTypeID: String? = nil

    // Cached data
    var images: [Image] = []
    var snapshots: [VolumeSnapshot] = []
    var volumeTypes: [VolumeType] = []

    // MARK: - Field Generation

    /// Generate FormField array for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState? = nil) -> [FormField] {
        var fields: [FormField] = []

        // Volume Name (text field)
        let nameId = VolumeCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameId,
            label: VolumeCreateFieldId.name.title,
            value: volumeName,
            placeholder: "Enter volume name",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.getTextFieldCursorPosition(nameId),
            validationError: getNameValidationError()
        )))

        // Volume Size (number field)
        let sizeId = VolumeCreateFieldId.size.rawValue
        fields.append(.number(FormFieldNumber(
            id: sizeId,
            label: VolumeCreateFieldId.size.title,
            value: volumeSize,
            placeholder: "Enter size in GB",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == sizeId,
            isActive: activeFieldId == sizeId,
            cursorPosition: formState?.getTextFieldCursorPosition(sizeId),
            validationError: getSizeValidationError(),
            minValue: 1,
            maxValue: nil,
            unit: nil
        )))

        // Source Type (selector field with tabs)
        let sourceTypeId = VolumeCreateFieldId.sourceType.rawValue

        // Create list of source type options
        let sourceTypeOptions: [SourceTypeOption] = [
            SourceTypeOption(id: "blank", name: "Blank Volume", sourceType: .blank),
            SourceTypeOption(id: "image", name: "From Image", sourceType: .image),
            SourceTypeOption(id: "snapshot", name: "From Snapshot", sourceType: .snapshot)
        ]

        let selectedSourceTypeId = sourceTypeOptions.first(where: { $0.sourceType == sourceType })?.id

        fields.append(.selector(FormFieldSelector(
            id: sourceTypeId,
            label: VolumeCreateFieldId.sourceType.title,
            items: sourceTypeOptions,
            selectedItemId: selectedSourceTypeId,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == sourceTypeId,
            isActive: activeFieldId == sourceTypeId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "Source Type", width: 40) { item in
                    (item as? SourceTypeOption)?.name ?? "Unknown"
                }
            ]
        )))

        // Conditional source selector based on source type
        switch sourceType {
        case .blank:
            // For blank volumes, no additional source selector needed
            break

        case .image:
            // For image-based volumes, show image selector
            let sourceId = VolumeCreateFieldId.source.rawValue
            fields.append(.selector(FormFieldSelector(
                id: sourceId,
                label: "Source Image",
                items: images,
                selectedItemId: selectedImageID,
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == sourceId,
                isActive: activeFieldId == sourceId,
                validationError: getImageValidationError(),
                columns: [
                    FormSelectorItemColumn(header: "Name", width: 30) { item in
                        (item as? Image)?.name ?? "Unknown"
                    },
                    FormSelectorItemColumn(header: "Min Disk", width: 10) { item in
                        if let image = item as? Image, let minDisk = image.minDisk, minDisk > 0 {
                            return "\(minDisk)GB"
                        }
                        return "-"
                    }
                ]
            )))

        case .snapshot:
            // For snapshot-based volumes, show snapshot selector
            let sourceId = VolumeCreateFieldId.source.rawValue
            fields.append(.selector(FormFieldSelector(
                id: sourceId,
                label: "Source Snapshot",
                items: snapshots,
                selectedItemId: selectedSnapshotID,
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == sourceId,
                isActive: activeFieldId == sourceId,
                validationError: getSnapshotValidationError(),
                columns: [
                    FormSelectorItemColumn(header: "Name", width: 30) { item in
                        (item as? VolumeSnapshot)?.name ?? "Unknown"
                    },
                    FormSelectorItemColumn(header: "Size", width: 10) { item in
                        if let snapshot = item as? VolumeSnapshot, let size = snapshot.size {
                            return "\(size)GB"
                        }
                        return "-"
                    }
                ]
            )))
        }

        // Volume Type selector - always shown regardless of source type
        let volumeTypeId = VolumeCreateFieldId.volumeType.rawValue
        fields.append(.selector(FormFieldSelector(
            id: volumeTypeId,
            label: VolumeCreateFieldId.volumeType.title,
            items: volumeTypes,
            selectedItemId: selectedVolumeTypeID,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == volumeTypeId,
            isActive: activeFieldId == volumeTypeId,
            validationError: getVolumeTypeValidationError(),
            columns: [
                FormSelectorItemColumn(header: "Volume Type", width: 40) { item in
                    (item as? VolumeType)?.name ?? "Unknown"
                }
            ]
        )))

        // Max Volumes (number field)
        let maxVolumesId = VolumeCreateFieldId.maxVolumes.rawValue
        fields.append(.number(FormFieldNumber(
            id: maxVolumesId,
            label: VolumeCreateFieldId.maxVolumes.title,
            value: maxVolumes,
            placeholder: "1",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == maxVolumesId,
            isActive: activeFieldId == maxVolumesId,
            cursorPosition: formState?.getTextFieldCursorPosition(maxVolumesId),
            validationError: getMaxVolumesValidationError()
        )))

        return fields
    }

    // MARK: - Validation

    private func getNameValidationError() -> String? {
        let trimmedName = volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Volume name is required"
        }
        // Validate name contains only allowed characters
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@._-")
        if trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return "Volume name can only contain letters, numbers, and @._- characters"
        }
        return nil
    }

    private func getSizeValidationError() -> String? {
        let trimmedSize = volumeSize.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSize.isEmpty {
            return "Volume size is required"
        }
        if let size = Int(trimmedSize) {
            if size <= 0 {
                return "Volume size must be greater than 0"
            }
        } else {
            return "Volume size must be a valid number"
        }
        return nil
    }

    private func getMaxVolumesValidationError() -> String? {
        let trimmed = maxVolumes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Max volumes is required"
        }
        guard let value = Int(trimmed), value >= 1 else {
            return "Max volumes must be a number >= 1"
        }
        return nil
    }

    private func getImageValidationError() -> String? {
        // Image-based volumes require an image selection
        if images.isEmpty {
            return "No images available"
        }
        if selectedImageID == nil {
            return "Image selection is required"
        }
        if !images.contains(where: { $0.id == selectedImageID }) {
            return "Selected image is invalid"
        }
        return nil
    }

    private func getSnapshotValidationError() -> String? {
        // Snapshot-based volumes require a snapshot selection
        if snapshots.isEmpty {
            return "No snapshots available"
        }
        if selectedSnapshotID == nil {
            return "Snapshot selection is required"
        }
        if !snapshots.contains(where: { $0.id == selectedSnapshotID }) {
            return "Selected snapshot is invalid"
        }
        return nil
    }

    private func getVolumeTypeValidationError() -> String? {
        // Volume type is optional - no validation errors
        // If selected, verify it exists
        if let volumeTypeID = selectedVolumeTypeID {
            if !volumeTypes.contains(where: { $0.id == volumeTypeID }) {
                return "Selected volume type is invalid"
            }
        }
        return nil
    }

    func validate() -> [String] {
        var errors: [String] = []

        if let error = getNameValidationError() {
            errors.append(error)
        }

        if let error = getSizeValidationError() {
            errors.append(error)
        }

        if let error = getMaxVolumesValidationError() {
            errors.append(error)
        }

        // Validate source based on source type
        switch sourceType {
        case .blank:
            // No source validation for blank volumes
            break
        case .image:
            if let error = getImageValidationError() {
                errors.append(error)
            }
        case .snapshot:
            if let error = getSnapshotValidationError() {
                errors.append(error)
            }
        }

        // Validate volume type (optional)
        if let error = getVolumeTypeValidationError() {
            errors.append(error)
        }

        return errors
    }

    func isValid() -> Bool {
        return validate().isEmpty
    }

    /// Get the volume size as an integer
    func getVolumeSize() -> Int? {
        return Int(volumeSize.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - State Management

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Update volume name
        if let name = formState.getTextValue(VolumeCreateFieldId.name.rawValue) {
            volumeName = name
        }

        // Update volume size
        if let size = formState.getTextValue(VolumeCreateFieldId.size.rawValue) {
            volumeSize = size
        }

        // Update max volumes
        if let max = formState.getTextValue(VolumeCreateFieldId.maxVolumes.rawValue) {
            maxVolumes = max
        }

        // Update source type from source type selector
        if let selectedSourceTypeId = formState.getSelectorSelectedId(VolumeCreateFieldId.sourceType.rawValue) {
            switch selectedSourceTypeId {
            case "blank":
                if sourceType != .blank {
                    // Clear image/snapshot selections when switching to blank
                    selectedImageID = nil
                    selectedSnapshotID = nil
                }
                sourceType = .blank
            case "image":
                if sourceType != .image {
                    // Clear snapshot when switching to image
                    selectedSnapshotID = nil
                }
                sourceType = .image
            case "snapshot":
                if sourceType != .snapshot {
                    // Clear image when switching to snapshot
                    selectedImageID = nil
                }
                sourceType = .snapshot
            default:
                break
            }
        }

        // Update source selection based on source type
        if let selectedSourceId = formState.getSelectorSelectedId(VolumeCreateFieldId.source.rawValue) {
            switch sourceType {
            case .blank:
                // No source selector for blank volumes
                break
            case .image:
                selectedImageID = selectedSourceId
            case .snapshot:
                selectedSnapshotID = selectedSourceId
            }
        }

        // Update volume type selection (always available)
        selectedVolumeTypeID = formState.getSelectorSelectedId(VolumeCreateFieldId.volumeType.rawValue)
    }

    mutating func reset() {
        volumeName = ""
        volumeSize = ""
        maxVolumes = "1"
        sourceType = .blank
        selectedImageID = nil
        selectedSnapshotID = nil
        selectedVolumeTypeID = nil
    }
}