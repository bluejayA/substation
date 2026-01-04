import Foundation
import OSClient

// MARK: - Disk Format Options

/// Supported disk formats for Glance images
enum ImageDiskFormat: String, CaseIterable {
    case qcow2 = "qcow2"
    case raw = "raw"
    case vhd = "vhd"
    case vhdx = "vhdx"
    case vmdk = "vmdk"
    case vdi = "vdi"
    case iso = "iso"
    case ami = "ami"

    var title: String {
        switch self {
        case .qcow2: return "QCOW2"
        case .raw: return "RAW"
        case .vhd: return "VHD"
        case .vhdx: return "VHDX"
        case .vmdk: return "VMDK"
        case .vdi: return "VDI"
        case .iso: return "ISO"
        case .ami: return "AMI"
        }
    }

    var description: String {
        switch self {
        case .qcow2: return "QEMU Copy-On-Write"
        case .raw: return "Unstructured disk image"
        case .vhd: return "Virtual Hard Disk"
        case .vhdx: return "Virtual Hard Disk v2"
        case .vmdk: return "VMware"
        case .vdi: return "VirtualBox"
        case .iso: return "Optical disc image"
        case .ami: return "Amazon Machine Image"
        }
    }

    /// Convert to FormSelectOption for use in select fields
    var asSelectOption: FormSelectOption {
        FormSelectOption(id: rawValue, title: title, description: description)
    }

    /// All cases as FormSelectOptions
    static var allOptions: [FormSelectOption] {
        allCases.map { $0.asSelectOption }
    }
}

// MARK: - Container Format Options

/// Supported container formats for Glance images
enum ImageContainerFormat: String, CaseIterable {
    case bare = "bare"
    case ovf = "ovf"
    case ova = "ova"
    case docker = "docker"

    var title: String {
        switch self {
        case .bare: return "bare"
        case .ovf: return "OVF"
        case .ova: return "OVA"
        case .docker: return "Docker"
        }
    }

    var description: String {
        switch self {
        case .bare: return "No container"
        case .ovf: return "Open Virtualization Format"
        case .ova: return "Open Virtual Appliance"
        case .docker: return "Container image"
        }
    }

    /// Convert to FormSelectOption for use in select fields
    var asSelectOption: FormSelectOption {
        FormSelectOption(id: rawValue, title: title, description: description)
    }

    /// All cases as FormSelectOptions
    static var allOptions: [FormSelectOption] {
        allCases.map { $0.asSelectOption }
    }
}

// MARK: - Visibility Options

/// Image visibility options
enum ImageVisibility: String, CaseIterable {
    case privateImage = "private"
    case publicImage = "public"
    case shared = "shared"
    case community = "community"

    var title: String {
        switch self {
        case .privateImage: return "Private"
        case .publicImage: return "Public"
        case .shared: return "Shared"
        case .community: return "Community"
        }
    }

    var description: String {
        switch self {
        case .privateImage: return "Only project members"
        case .publicImage: return "All users"
        case .shared: return "Specific projects"
        case .community: return "All authenticated users"
        }
    }

    /// Convert to FormSelectOption for use in select fields
    var asSelectOption: FormSelectOption {
        FormSelectOption(id: rawValue, title: title, description: description)
    }

    /// All cases as FormSelectOptions
    static var allOptions: [FormSelectOption] {
        allCases.map { $0.asSelectOption }
    }
}

// MARK: - Image Create Form

/// Simplified form model for creating a new Glance image
struct ImageCreateForm {
    // MARK: - Required Properties

    /// Image name (required)
    var name: String = ""

    /// Image file path for upload (TAB completion supported)
    var imageFilePath: String = ""

    // MARK: - Format Properties

    /// Disk format (defaults to qcow2)
    var diskFormat: ImageDiskFormat = .qcow2

    /// Container format (defaults to bare)
    var containerFormat: ImageContainerFormat = .bare

    /// Visibility setting (defaults to private)
    var visibility: ImageVisibility = .privateImage

    // MARK: - Optional Properties

    /// Minimum disk size in GB (0 = no minimum)
    var minDisk: Int = 0

    /// Minimum RAM in MB (0 = no minimum)
    var minRam: Int = 0

    // MARK: - Form Building

    /// Build form fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Image name (required)
        fields.append(.text(FormFieldText(
            id: ImageCreateFieldId.name.rawValue,
            label: "Image Name",
            value: name,
            placeholder: "my-ubuntu-image",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ImageCreateFieldId.name.rawValue,
            isActive: activeFieldId == ImageCreateFieldId.name.rawValue,
            cursorPosition: formState.getTextFieldCursorPosition(ImageCreateFieldId.name.rawValue),
            validationError: validateName()
        )))

        // Image file path with TAB completion (required)
        fields.append(.text(FormFieldText(
            id: ImageCreateFieldId.imageFilePath.rawValue,
            label: "Image File Path (TAB to complete)",
            value: imageFilePath,
            placeholder: "~/images/ubuntu.qcow2",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ImageCreateFieldId.imageFilePath.rawValue,
            isActive: activeFieldId == ImageCreateFieldId.imageFilePath.rawValue,
            cursorPosition: formState.getTextFieldCursorPosition(ImageCreateFieldId.imageFilePath.rawValue),
            validationError: validateFilePath()
        )))

        // Disk format - cycles through options with SPACE
        fields.append(.select(FormFieldSelect(
            id: ImageCreateFieldId.diskFormat.rawValue,
            label: "Disk Format (SPACE to change)",
            options: ImageDiskFormat.allOptions,
            selectedOptionId: diskFormat.rawValue,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ImageCreateFieldId.diskFormat.rawValue,
            isActive: false,
            validationError: nil
        )))

        // Container format - cycles through options with SPACE
        fields.append(.select(FormFieldSelect(
            id: ImageCreateFieldId.containerFormat.rawValue,
            label: "Container Format (SPACE to change)",
            options: ImageContainerFormat.allOptions,
            selectedOptionId: containerFormat.rawValue,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ImageCreateFieldId.containerFormat.rawValue,
            isActive: false,
            validationError: nil
        )))

        // Visibility - cycles through options with SPACE
        fields.append(.select(FormFieldSelect(
            id: ImageCreateFieldId.visibility.rawValue,
            label: "Visibility (SPACE to change)",
            options: ImageVisibility.allOptions,
            selectedOptionId: visibility.rawValue,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == ImageCreateFieldId.visibility.rawValue,
            isActive: false,
            validationError: nil
        )))

        // Min disk (optional)
        fields.append(.text(FormFieldText(
            id: ImageCreateFieldId.minDisk.rawValue,
            label: "Minimum Disk (GB)",
            value: minDisk > 0 ? String(minDisk) : "",
            placeholder: "0 (no minimum)",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == ImageCreateFieldId.minDisk.rawValue,
            isActive: activeFieldId == ImageCreateFieldId.minDisk.rawValue,
            cursorPosition: formState.getTextFieldCursorPosition(ImageCreateFieldId.minDisk.rawValue),
            validationError: nil
        )))

        // Min RAM (optional)
        fields.append(.text(FormFieldText(
            id: ImageCreateFieldId.minRam.rawValue,
            label: "Minimum RAM (MB)",
            value: minRam > 0 ? String(minRam) : "",
            placeholder: "0 (no minimum)",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == ImageCreateFieldId.minRam.rawValue,
            isActive: activeFieldId == ImageCreateFieldId.minRam.rawValue,
            cursorPosition: formState.getTextFieldCursorPosition(ImageCreateFieldId.minRam.rawValue),
            validationError: nil
        )))

        return fields
    }

    // MARK: - Form State Updates

    /// Update form from FormBuilderState
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Text fields
        if let value = formState.getTextValue(ImageCreateFieldId.name.rawValue) {
            name = value
        }
        if let value = formState.getTextValue(ImageCreateFieldId.imageFilePath.rawValue) {
            imageFilePath = value
        }
        if let value = formState.getTextValue(ImageCreateFieldId.minDisk.rawValue), let intValue = Int(value) {
            minDisk = intValue
        } else if formState.getTextValue(ImageCreateFieldId.minDisk.rawValue)?.isEmpty == true {
            minDisk = 0
        }
        if let value = formState.getTextValue(ImageCreateFieldId.minRam.rawValue), let intValue = Int(value) {
            minRam = intValue
        } else if formState.getTextValue(ImageCreateFieldId.minRam.rawValue)?.isEmpty == true {
            minRam = 0
        }

        // Select fields - get selected option ID from formState fields
        if let selectedId = formState.getSelectedOptionId(ImageCreateFieldId.diskFormat.rawValue),
           let format = ImageDiskFormat(rawValue: selectedId) {
            diskFormat = format
        }
        if let selectedId = formState.getSelectedOptionId(ImageCreateFieldId.containerFormat.rawValue),
           let format = ImageContainerFormat(rawValue: selectedId) {
            containerFormat = format
        }
        if let selectedId = formState.getSelectedOptionId(ImageCreateFieldId.visibility.rawValue),
           let vis = ImageVisibility(rawValue: selectedId) {
            visibility = vis
        }
    }

    // MARK: - Validation

    /// Validate image name
    func validateName() -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Image name is required"
        }
        if trimmed.count > 255 {
            return "Image name must be 255 characters or less"
        }
        return nil
    }

    /// Validate file path
    func validateFilePath() -> String? {
        return FilePathCompleter.validatePublicKeyPath(imageFilePath)
    }

    /// Validate entire form
    func validateForm() -> [String] {
        var errors: [String] = []

        if let nameError = validateName() {
            errors.append(nameError)
        }
        if let fileError = validateFilePath() {
            errors.append(fileError)
        }

        return errors
    }

    /// Check if form is valid for submission
    func isValid() -> Bool {
        return validateForm().isEmpty
    }

    // MARK: - API Request Building

    /// Build CreateImageRequest for API
    func buildCreateRequest() -> CreateImageRequest {
        return CreateImageRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            visibility: visibility.rawValue,
            diskFormat: diskFormat.rawValue,
            containerFormat: containerFormat.rawValue,
            minDisk: minDisk > 0 ? minDisk : nil,
            minRam: minRam > 0 ? minRam : nil,
            protected: false,
            tags: nil,
            properties: nil
        )
    }
}

// MARK: - Field Identifiers

/// Field identifiers for ImageCreateForm
enum ImageCreateFieldId: String {
    case name = "image-name"
    case imageFilePath = "image-file-path"
    case diskFormat = "disk-format"
    case containerFormat = "container-format"
    case visibility = "visibility"
    case minDisk = "min-disk"
    case minRam = "min-ram"
}
