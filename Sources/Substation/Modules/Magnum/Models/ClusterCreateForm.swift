// Sources/Substation/Modules/Magnum/Models/ClusterCreateForm.swift
import Foundation
import OSClient

/// Field identifiers for ClusterCreate FormBuilder
enum ClusterCreateFieldId: String, CaseIterable {
    case name = "name"
    case clusterTemplateId = "cluster_template_id"
    case keypair = "keypair"
    case masterCount = "master_count"
    case nodeCount = "node_count"
    case createTimeout = "create_timeout"

    var title: String {
        switch self {
        case .name:
            return "Cluster Name"
        case .clusterTemplateId:
            return "Cluster Template"
        case .keypair:
            return "SSH Keypair"
        case .masterCount:
            return "Master Nodes"
        case .nodeCount:
            return "Worker Nodes"
        case .createTimeout:
            return "Create Timeout"
        }
    }
}

/// ClusterCreateForm using FormBuilder architecture
///
/// This form manages the state and field generation for creating
/// a new Magnum cluster.
struct ClusterCreateForm {
    // MARK: - Constants

    private static let clusterNamePlaceholder = "my-kubernetes-cluster"
    private static let clusterNameRequiredError = "Cluster name is required"
    private static let templateRequiredError = "Cluster template is required"

    // MARK: - Properties

    var clusterName: String = ""
    var selectedTemplateId: String? = nil
    var selectedKeypairId: String? = nil
    var masterCount: String = "1"
    var nodeCount: String = "1"
    var createTimeout: String = "60"

    // Form state
    var errorMessage: String? = nil
    var isLoading: Bool = false

    // Cached data
    var templates: [ClusterTemplate] = []
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

        // Cluster Name (text field - required)
        let nameId = ClusterCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameId,
            label: ClusterCreateFieldId.name.title,
            value: clusterName,
            placeholder: Self.clusterNamePlaceholder,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.getTextFieldCursorPosition(nameId),
            validationError: getNameValidationError(),
            maxWidth: 50,
            maxLength: 64
        )))

        // Cluster Template (selector - required)
        let templateId = ClusterCreateFieldId.clusterTemplateId.rawValue
        fields.append(.selector(FormFieldSelector(
            id: templateId,
            label: ClusterCreateFieldId.clusterTemplateId.title,
            items: templates,
            selectedItemId: selectedTemplateId,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == templateId,
            isActive: activeFieldId == templateId,
            validationError: getTemplateValidationError(),
            columns: [
                FormSelectorItemColumn(header: "Name", width: 30) { item in
                    (item as? ClusterTemplate)?.displayName ?? "Unknown"
                },
                FormSelectorItemColumn(header: "COE", width: 15) { item in
                    (item as? ClusterTemplate)?.coeDisplayName ?? "Unknown"
                }
            ]
        )))

        // SSH Keypair (selector - optional)
        let keypairId = ClusterCreateFieldId.keypair.rawValue
        fields.append(.selector(FormFieldSelector(
            id: keypairId,
            label: ClusterCreateFieldId.keypair.title,
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

        // Master Nodes (number field - required)
        let masterCountId = ClusterCreateFieldId.masterCount.rawValue
        fields.append(.number(FormFieldNumber(
            id: masterCountId,
            label: ClusterCreateFieldId.masterCount.title,
            value: masterCount,
            placeholder: "Number of master nodes",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == masterCountId,
            isActive: activeFieldId == masterCountId,
            cursorPosition: formState?.getTextFieldCursorPosition(masterCountId),
            validationError: nil,
            minValue: 1,
            maxValue: 10,
            unit: nil
        )))

        // Worker Nodes (number field - required)
        let nodeCountId = ClusterCreateFieldId.nodeCount.rawValue
        fields.append(.number(FormFieldNumber(
            id: nodeCountId,
            label: ClusterCreateFieldId.nodeCount.title,
            value: nodeCount,
            placeholder: "Number of worker nodes",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nodeCountId,
            isActive: activeFieldId == nodeCountId,
            cursorPosition: formState?.getTextFieldCursorPosition(nodeCountId),
            validationError: nil,
            minValue: 1,
            maxValue: 100,
            unit: nil
        )))

        // Create Timeout (number field - optional)
        let timeoutId = ClusterCreateFieldId.createTimeout.rawValue
        fields.append(.number(FormFieldNumber(
            id: timeoutId,
            label: "\(ClusterCreateFieldId.createTimeout.title) (minutes)",
            value: createTimeout,
            placeholder: "Timeout in minutes",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == timeoutId,
            isActive: activeFieldId == timeoutId,
            cursorPosition: formState?.getTextFieldCursorPosition(timeoutId),
            validationError: nil,
            minValue: 10,
            maxValue: 1440,
            unit: "min"
        )))

        return fields
    }

    // MARK: - Form State Updates

    /// Update form from FormBuilderState
    ///
    /// - Parameter formState: The form builder state to sync from
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Text fields
        if let value = formState.getTextValue(ClusterCreateFieldId.name.rawValue) {
            clusterName = value
        }

        // Number fields (stored as text)
        if let value = formState.getTextValue(ClusterCreateFieldId.masterCount.rawValue) {
            masterCount = value
        }
        if let value = formState.getTextValue(ClusterCreateFieldId.nodeCount.rawValue) {
            nodeCount = value
        }
        if let value = formState.getTextValue(ClusterCreateFieldId.createTimeout.rawValue) {
            createTimeout = value
        }

        // Selector fields
        if let selectedId = formState.selectorStates[ClusterCreateFieldId.clusterTemplateId.rawValue]?.selectedItemId {
            selectedTemplateId = selectedId
        }
        if let selectedId = formState.selectorStates[ClusterCreateFieldId.keypair.rawValue]?.selectedItemId {
            selectedKeypairId = selectedId
        }
    }

    // MARK: - Validation

    /// Validate the form and return any errors
    ///
    /// - Returns: Dictionary of field IDs to error messages
    func validate() -> [String: String] {
        var errors: [String: String] = [:]

        if let nameError = getNameValidationError() {
            errors[ClusterCreateFieldId.name.rawValue] = nameError
        }

        if let templateError = getTemplateValidationError() {
            errors[ClusterCreateFieldId.clusterTemplateId.rawValue] = templateError
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

        if let templateError = getTemplateValidationError() {
            errors.append(templateError)
        }

        return errors
    }

    /// Check if the form is valid for submission
    var isValid: Bool {
        return validate().isEmpty
    }

    // MARK: - Private Validation Helpers

    private func getNameValidationError() -> String? {
        if clusterName.trimmingCharacters(in: .whitespaces).isEmpty {
            return Self.clusterNameRequiredError
        }
        return nil
    }

    private func getTemplateValidationError() -> String? {
        if selectedTemplateId == nil || selectedTemplateId?.isEmpty == true {
            return Self.templateRequiredError
        }
        return nil
    }

    // MARK: - Reset

    /// Reset the form to initial state
    mutating func reset() {
        clusterName = ""
        selectedTemplateId = templates.first?.uuid
        selectedKeypairId = keypairs.first?.id
        masterCount = "1"
        nodeCount = "1"
        createTimeout = "60"
        errorMessage = nil
        isLoading = false
    }
}

// MARK: - Protocol Conformance Adapters

extension ClusterCreateForm {
    /// Adapter for FormStateRebuildable - makes formState non-optional
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return self.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: Optional.some(formState))
    }
}

// Declare protocol conformance
extension ClusterCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
