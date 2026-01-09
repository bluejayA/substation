// Sources/Substation/Modules/Magnum/Models/ClusterTemplateCreateForm.swift
import Foundation
import OSClient

/// Field identifiers for ClusterTemplateCreate FormBuilder
enum ClusterTemplateCreateFieldId: String, CaseIterable {
    case name = "name"
    case coe = "coe"
    case imageId = "image_id"
    case externalNetworkId = "external_network_id"
    case flavorId = "flavor_id"
    case masterFlavorId = "master_flavor_id"
    case keypairId = "keypair_id"
    case dockerVolumeSize = "docker_volume_size"
    case networkDriver = "network_driver"
    case floatingIpEnabled = "floating_ip_enabled"
    case masterLbEnabled = "master_lb_enabled"

    var title: String {
        switch self {
        case .name:
            return "Template Name"
        case .coe:
            return "Container Engine"
        case .imageId:
            return "Node Image"
        case .externalNetworkId:
            return "External Network"
        case .flavorId:
            return "Worker Flavor"
        case .masterFlavorId:
            return "Master Flavor"
        case .keypairId:
            return "SSH Keypair"
        case .dockerVolumeSize:
            return "Docker Volume Size"
        case .networkDriver:
            return "Network Driver"
        case .floatingIpEnabled:
            return "Enable Floating IPs"
        case .masterLbEnabled:
            return "Enable Master LB"
        }
    }
}

/// ClusterTemplateCreateForm using FormBuilder architecture
///
/// This form manages the state and field generation for creating
/// a new Magnum cluster template.
struct ClusterTemplateCreateForm {
    // MARK: - Constants

    private static let templateNamePlaceholder = "my-kubernetes-template"
    private static let templateNameRequiredError = "Template name is required"
    private static let imageRequiredError = "Node image is required"
    private static let coeRequiredError = "Container engine is required"

    // MARK: - Properties

    var templateName: String = ""
    var selectedCoe: String = "kubernetes"
    var selectedImageId: String? = nil
    var selectedExternalNetworkId: String? = nil
    var selectedFlavorId: String? = nil
    var selectedMasterFlavorId: String? = nil
    var selectedKeypairId: String? = nil
    var dockerVolumeSize: String = "50"
    var selectedNetworkDriver: String = "flannel"
    var floatingIpEnabled: Bool = true
    var masterLbEnabled: Bool = true

    // Form state
    var errorMessage: String? = nil
    var isLoading: Bool = false

    // Cached data
    var images: [Image] = []
    var flavors: [Flavor] = []
    var networks: [Network] = []
    var keypairs: [KeyPair] = []

    // MARK: - Field Generation

    /// Generate FormField array for FormBuilder
    ///
    /// - Parameters:
    ///   - selectedFieldId: The currently selected field ID
    ///   - activeFieldId: The currently active (editing) field ID
    ///   - formState: The form builder state for cursor positions
    /// - Returns: Array of FormField for rendering
    func buildFields(
        selectedFieldId: String?,
        activeFieldId: String? = nil,
        formState: FormBuilderState? = nil
    ) -> [FormField] {
        var fields: [FormField] = []

        // Template Name (text field - required)
        let nameId = ClusterTemplateCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameId,
            label: ClusterTemplateCreateFieldId.name.title,
            value: templateName,
            placeholder: Self.templateNamePlaceholder,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.getTextFieldCursorPosition(nameId),
            validationError: getNameValidationError(),
            maxWidth: 50,
            maxLength: 64
        )))

        // Container Engine (select - required, cycles with SPACE)
        let coeId = ClusterTemplateCreateFieldId.coe.rawValue
        fields.append(.select(FormFieldSelect(
            id: coeId,
            label: "\(ClusterTemplateCreateFieldId.coe.title) (SPACE to change)",
            options: COEOption.allSelectOptions,
            selectedOptionId: selectedCoe,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == coeId,
            isActive: false,
            validationError: nil
        )))

        // Node Image (selector - required)
        let imageId = ClusterTemplateCreateFieldId.imageId.rawValue
        fields.append(.selector(FormFieldSelector(
            id: imageId,
            label: ClusterTemplateCreateFieldId.imageId.title,
            items: images.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending },
            selectedItemId: selectedImageId,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == imageId,
            isActive: activeFieldId == imageId,
            validationError: getImageValidationError(),
            columns: [
                FormSelectorItemColumn(header: "Name", width: 40) { item in
                    (item as? Image)?.name ?? "Unknown"
                },
                FormSelectorItemColumn(header: "Status", width: 15) { item in
                    (item as? Image)?.status ?? "Unknown"
                }
            ]
        )))

        // External Network (selector - optional)
        let externalNetworks = networks.filter { $0.isExternal == true }
        let extNetId = ClusterTemplateCreateFieldId.externalNetworkId.rawValue
        fields.append(.selector(FormFieldSelector(
            id: extNetId,
            label: ClusterTemplateCreateFieldId.externalNetworkId.title,
            items: externalNetworks,
            selectedItemId: selectedExternalNetworkId,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == extNetId,
            isActive: activeFieldId == extNetId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "Name", width: 30) { item in
                    (item as? Network)?.name ?? "Unknown"
                },
                FormSelectorItemColumn(header: "Status", width: 15) { item in
                    (item as? Network)?.status ?? "Unknown"
                }
            ]
        )))

        // Worker Flavor (selector - optional)
        let flavorId = ClusterTemplateCreateFieldId.flavorId.rawValue
        fields.append(.selector(FormFieldSelector(
            id: flavorId,
            label: ClusterTemplateCreateFieldId.flavorId.title,
            items: flavors,
            selectedItemId: selectedFlavorId,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == flavorId,
            isActive: activeFieldId == flavorId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "Name", width: 25) { item in
                    (item as? Flavor)?.name ?? "Unknown"
                },
                FormSelectorItemColumn(header: "vCPUs", width: 8) { item in
                    String((item as? Flavor)?.vcpus ?? 0)
                },
                FormSelectorItemColumn(header: "RAM", width: 10) { item in
                    "\((item as? Flavor)?.ram ?? 0) MB"
                }
            ]
        )))

        // Master Flavor (selector - optional)
        let masterFlavorId = ClusterTemplateCreateFieldId.masterFlavorId.rawValue
        fields.append(.selector(FormFieldSelector(
            id: masterFlavorId,
            label: ClusterTemplateCreateFieldId.masterFlavorId.title,
            items: flavors,
            selectedItemId: selectedMasterFlavorId,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == masterFlavorId,
            isActive: activeFieldId == masterFlavorId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "Name", width: 25) { item in
                    (item as? Flavor)?.name ?? "Unknown"
                },
                FormSelectorItemColumn(header: "vCPUs", width: 8) { item in
                    String((item as? Flavor)?.vcpus ?? 0)
                },
                FormSelectorItemColumn(header: "RAM", width: 10) { item in
                    "\((item as? Flavor)?.ram ?? 0) MB"
                }
            ]
        )))

        // SSH Keypair (selector - optional)
        let keypairId = ClusterTemplateCreateFieldId.keypairId.rawValue
        fields.append(.selector(FormFieldSelector(
            id: keypairId,
            label: ClusterTemplateCreateFieldId.keypairId.title,
            items: keypairs,
            selectedItemId: selectedKeypairId,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == keypairId,
            isActive: activeFieldId == keypairId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "Name", width: 30) { item in
                    (item as? KeyPair)?.name ?? "Unknown"
                },
                FormSelectorItemColumn(header: "Type", width: 15) { item in
                    (item as? KeyPair)?.type ?? "Unknown"
                }
            ]
        )))

        // Docker Volume Size (number field)
        let dockerVolId = ClusterTemplateCreateFieldId.dockerVolumeSize.rawValue
        fields.append(.number(FormFieldNumber(
            id: dockerVolId,
            label: ClusterTemplateCreateFieldId.dockerVolumeSize.title,
            value: dockerVolumeSize,
            placeholder: "Size in GB",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == dockerVolId,
            isActive: activeFieldId == dockerVolId,
            cursorPosition: formState?.getTextFieldCursorPosition(dockerVolId),
            validationError: nil,
            minValue: 1,
            maxValue: 1000,
            unit: "GB"
        )))

        // Network Driver (select - optional, cycles with SPACE)
        let netDriverId = ClusterTemplateCreateFieldId.networkDriver.rawValue
        fields.append(.select(FormFieldSelect(
            id: netDriverId,
            label: "\(ClusterTemplateCreateFieldId.networkDriver.title) (SPACE to change)",
            options: NetworkDriverOption.allSelectOptions,
            selectedOptionId: selectedNetworkDriver,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == netDriverId,
            isActive: false,
            validationError: nil
        )))

        // Floating IP Enabled (toggle)
        let floatingIpId = ClusterTemplateCreateFieldId.floatingIpEnabled.rawValue
        fields.append(.toggle(FormFieldToggle(
            id: floatingIpId,
            label: ClusterTemplateCreateFieldId.floatingIpEnabled.title,
            value: floatingIpEnabled,
            isVisible: true,
            isSelected: selectedFieldId == floatingIpId,
            enabledLabel: "Yes",
            disabledLabel: "No"
        )))

        // Master LB Enabled (toggle)
        let masterLbId = ClusterTemplateCreateFieldId.masterLbEnabled.rawValue
        fields.append(.toggle(FormFieldToggle(
            id: masterLbId,
            label: ClusterTemplateCreateFieldId.masterLbEnabled.title,
            value: masterLbEnabled,
            isVisible: true,
            isSelected: selectedFieldId == masterLbId,
            enabledLabel: "Yes",
            disabledLabel: "No"
        )))

        return fields
    }

    // MARK: - Form State Updates

    /// Update form from FormBuilderState
    ///
    /// - Parameter formState: The form builder state to sync from
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Text fields
        if let value = formState.getTextValue(ClusterTemplateCreateFieldId.name.rawValue) {
            templateName = value
        }
        if let value = formState.getTextValue(ClusterTemplateCreateFieldId.dockerVolumeSize.rawValue) {
            dockerVolumeSize = value
        }

        // Select fields (cycle-through select)
        if let selectedId = formState.getSelectedOptionId(ClusterTemplateCreateFieldId.coe.rawValue) {
            selectedCoe = selectedId
        }
        if let selectedId = formState.getSelectedOptionId(ClusterTemplateCreateFieldId.networkDriver.rawValue) {
            selectedNetworkDriver = selectedId
        }

        // Selector fields (overlay popup select)
        if let selectedId = formState.selectorStates[ClusterTemplateCreateFieldId.imageId.rawValue]?.selectedItemId {
            selectedImageId = selectedId
        }
        if let selectedId = formState.selectorStates[ClusterTemplateCreateFieldId.externalNetworkId.rawValue]?.selectedItemId {
            selectedExternalNetworkId = selectedId
        }
        if let selectedId = formState.selectorStates[ClusterTemplateCreateFieldId.flavorId.rawValue]?.selectedItemId {
            selectedFlavorId = selectedId
        }
        if let selectedId = formState.selectorStates[ClusterTemplateCreateFieldId.masterFlavorId.rawValue]?.selectedItemId {
            selectedMasterFlavorId = selectedId
        }
        if let selectedId = formState.selectorStates[ClusterTemplateCreateFieldId.keypairId.rawValue]?.selectedItemId {
            selectedKeypairId = selectedId
        }

        // Toggle fields
        if let value = formState.getToggleValue(ClusterTemplateCreateFieldId.floatingIpEnabled.rawValue) {
            floatingIpEnabled = value
        }
        if let value = formState.getToggleValue(ClusterTemplateCreateFieldId.masterLbEnabled.rawValue) {
            masterLbEnabled = value
        }
    }

    // MARK: - Validation

    /// Validate the form and return any errors
    ///
    /// - Returns: Dictionary of field IDs to error messages
    func validate() -> [String: String] {
        var errors: [String: String] = [:]

        if let nameError = getNameValidationError() {
            errors[ClusterTemplateCreateFieldId.name.rawValue] = nameError
        }

        if let imageError = getImageValidationError() {
            errors[ClusterTemplateCreateFieldId.imageId.rawValue] = imageError
        }

        return errors
    }

    /// Validate form and return array of error messages
    ///
    /// - Returns: Array of validation error messages
    func validateForm() -> [String] {
        var errors: [String] = []

        if let nameError = getNameValidationError() {
            errors.append(nameError)
        }

        if let imageError = getImageValidationError() {
            errors.append(imageError)
        }

        return errors
    }

    /// Check if the form is valid for submission
    var isValid: Bool {
        return validate().isEmpty
    }

    // MARK: - Private Validation Helpers

    private func getNameValidationError() -> String? {
        if templateName.trimmingCharacters(in: .whitespaces).isEmpty {
            return Self.templateNameRequiredError
        }
        return nil
    }

    private func getImageValidationError() -> String? {
        if selectedImageId == nil || selectedImageId?.isEmpty == true {
            return Self.imageRequiredError
        }
        return nil
    }
}

// MARK: - Protocol Conformance Adapters

extension ClusterTemplateCreateForm {
    /// Adapter for FormStateRebuildable - makes formState non-optional
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return self.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: Optional.some(formState))
    }
}

// Declare protocol conformance
extension ClusterTemplateCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
