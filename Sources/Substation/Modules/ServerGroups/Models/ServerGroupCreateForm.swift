import Foundation
import OSClient

enum ServerGroupCreateField: CaseIterable {
    case name, policy

    var title: String {
        switch self {
        case .name: return "Server Group Name"
        case .policy: return "Policy"
        }
    }
}

// MARK: - ServerGroupPolicy FormSelectorItem Conformance

extension ServerGroupPolicy: FormSelectableItem, FormSelectorItem {
    public var id: String {
        return self.rawValue
    }

    public var sortKey: String {
        return displayName
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return displayName.lowercased().contains(lowercaseQuery) ||
               description.lowercased().contains(lowercaseQuery) ||
               rawValue.lowercased().contains(lowercaseQuery)
    }
}

struct ServerGroupCreateForm: FormViewModel {
    // Validation Constants
    private static let minimumNameLength = 2
    private static let maximumNameLength = 255
    private static let defaultFieldWidth = 40

    // Text Constants
    private static let serverGroupNameTitle = "Server Group Name"
    private static let policyTitle = "Policy"
    private static let selectPolicyTitle = "Select Policy"
    private static let formTitle = "Create Server Group"
    private static let placeholderText = "Enter server group name"

    // Error Messages
    private static let nameRequiredError = "Server group name is required"
    private static let nameTooShortError = "Server group name must be at least 2 characters"
    private static let nameTooLongError = "Server group name must be less than 255 characters"

    // Help Text Constants
    private static let editingHelpText = "ESC: Exit editing | Type to enter name"
    private static let selectionHelpText = "UP/DOWN: Navigate policies | SPACE: Select | ESC: Cancel selection"
    private static let defaultHelpText = "TAB/UP/DOWN: Navigate fields | ENTER: Create | ESC: Cancel | SPACE: Select policy"

    var serverGroupName: String = ""
    var selectedPolicy: ServerGroupPolicy = .antiAffinity

    // Policy selection mode for visual interface
    var policySelectionMode: Bool = false
    var selectedPolicyIndex: Int = 0

    var currentField: ServerGroupCreateField = .name
    var fieldEditMode: Bool = false

    // Form state management
    var errorMessage: String? = nil
    var isLoading: Bool = false

    // MARK: - Navigation Methods

    mutating func nextField() {
        currentField = getNextField(from: currentField)
        fieldEditMode = false
    }

    mutating func previousField() {
        currentField = getPreviousField(from: currentField)
        fieldEditMode = false
    }

    mutating func togglePolicySelectionMode() {
        policySelectionMode.toggle()
        if policySelectionMode {
            selectedPolicyIndex = getCurrentPolicyIndex()
        }
    }

    mutating func nextPolicyInSelection() {
        selectedPolicyIndex = getNextPolicyIndex(from: selectedPolicyIndex)
    }

    mutating func previousPolicyInSelection() {
        selectedPolicyIndex = getPreviousPolicyIndex(from: selectedPolicyIndex)
    }

    mutating func selectCurrentPolicy() {
        selectedPolicy = getPolicyAtIndex(selectedPolicyIndex)
        policySelectionMode = false
    }

    mutating func cyclePolicySelection() {
        let currentIndex = getCurrentPolicyIndex()
        let nextIndex = getNextPolicyIndex(from: currentIndex)
        selectedPolicy = getPolicyAtIndex(nextIndex)
    }

    mutating func previousPolicySelection() {
        let currentIndex = getCurrentPolicyIndex()
        let prevIndex = getPreviousPolicyIndex(from: currentIndex)
        selectedPolicy = getPolicyAtIndex(prevIndex)
    }

    // MARK: - Validation Methods

    func validate() -> [String] {
        var errors: [String] = []
        let trimmedName = getTrimmedServerGroupName()

        if trimmedName.isEmpty {
            errors.append(Self.nameRequiredError)
        }

        if trimmedName.count < Self.minimumNameLength {
            errors.append(Self.nameTooShortError)
        }

        if trimmedName.count > Self.maximumNameLength {
            errors.append(Self.nameTooLongError)
        }

        return errors
    }

    func isValid() -> Bool {
        return validate().isEmpty
    }

    func getTrimmedServerGroupName() -> String {
        return serverGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func clearError() {
        errorMessage = nil
    }

    mutating func setError(_ message: String) {
        errorMessage = message
        isLoading = false
    }

    mutating func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
        }
    }

    mutating func reset() {
        serverGroupName = ""
        selectedPolicy = .antiAffinity
        policySelectionMode = false
        selectedPolicyIndex = 0
        currentField = .name
        fieldEditMode = false
        errorMessage = nil
        isLoading = false
    }

    // MARK: - FormViewModel Implementation

    func getFieldConfigurations() -> [FormFieldConfiguration] {
        return ServerGroupCreateField.allCases.map { field in
            getFieldConfiguration(for: field)
        }
    }

    func getValidationState() -> FormValidationState {
        let errors = validate()
        return FormValidationState(isValid: errors.isEmpty, errors: errors)
    }

    func getFormTitle() -> String {
        return Self.formTitle
    }

    func getNavigationHelp() -> String {
        if fieldEditMode && currentField == .name {
            return Self.editingHelpText
        } else if policySelectionMode {
            return Self.selectionHelpText
        } else {
            return Self.defaultHelpText
        }
    }

    func isInSpecialMode() -> Bool {
        return (fieldEditMode && currentField == .name) || policySelectionMode
    }

    // MARK: - Private Helper Methods

    private func getAllFields() -> [ServerGroupCreateField] {
        return ServerGroupCreateField.allCases
    }

    private func getAllPolicies() -> [ServerGroupPolicy] {
        return ServerGroupPolicy.allCases
    }

    private func getNextField(from field: ServerGroupCreateField) -> ServerGroupCreateField {
        let fields = getAllFields()
        guard let currentIndex = fields.firstIndex(of: field) else { return field }
        let nextIndex = (currentIndex + 1) % fields.count
        return fields[nextIndex]
    }

    private func getPreviousField(from field: ServerGroupCreateField) -> ServerGroupCreateField {
        let fields = getAllFields()
        guard let currentIndex = fields.firstIndex(of: field) else { return field }
        let prevIndex = currentIndex == 0 ? fields.count - 1 : currentIndex - 1
        return fields[prevIndex]
    }

    private func getCurrentPolicyIndex() -> Int {
        return getAllPolicies().firstIndex(of: selectedPolicy) ?? 0
    }

    private func getNextPolicyIndex(from index: Int) -> Int {
        let policies = getAllPolicies()
        return (index + 1) % policies.count
    }

    private func getPreviousPolicyIndex(from index: Int) -> Int {
        let policies = getAllPolicies()
        return index == 0 ? policies.count - 1 : index - 1
    }

    private func getPolicyAtIndex(_ index: Int) -> ServerGroupPolicy {
        let policies = getAllPolicies()
        guard index >= 0 && index < policies.count else { return .antiAffinity }
        return policies[index]
    }

    private func getFieldConfiguration(for field: ServerGroupCreateField) -> FormFieldConfiguration {
        let isSelected = (currentField == field)
        let isActive = isSelected && fieldEditMode

        switch field {
        case .name:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: true,
                isSelected: isSelected,
                isActive: isActive,
                placeholder: Self.placeholderText,
                value: serverGroupName.isEmpty ? nil : serverGroupName,
                maxWidth: Self.defaultFieldWidth,
                fieldType: .text
            )

        case .policy:
            if policySelectionMode {
                return FormFieldConfiguration(
                    title: Self.selectPolicyTitle,
                    isRequired: true,
                    isSelected: true,
                    isActive: true,
                    value: selectedPolicy.displayName,
                    fieldType: .multiSelection,
                    selectionMode: true,
                    selectionInfo: SelectionInfo(
                        selectedIndex: selectedPolicyIndex,
                        totalItems: getAllPolicies().count,
                        selectedItemName: getPolicyAtIndex(selectedPolicyIndex).displayName
                    )
                )
            } else {
                return FormFieldConfiguration(
                    title: field.title,
                    isRequired: true,
                    isSelected: isSelected,
                    isActive: isActive,
                    value: selectedPolicy.displayName,
                    fieldType: .enumeration,
                    selectionInfo: SelectionInfo(
                        selectedIndex: getCurrentPolicyIndex(),
                        totalItems: getAllPolicies().count,
                        selectedItemName: selectedPolicy.displayName
                    )
                )
            }
        }
    }

    // MARK: - FormBuilder Integration

    func buildFields(
        selectedFieldId: String?,
        activeFieldId: String?,
        formState: FormBuilderState
    ) -> [FormField] {
        var fields: [FormField] = []

        // Server Group Name Field
        let nameFieldId = ServerGroupCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameFieldId,
            label: ServerGroupCreateField.name.title,
            value: serverGroupName,
            placeholder: "Enter server group name",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameFieldId,
            isActive: activeFieldId == nameFieldId,
            cursorPosition: formState.textFieldStates[nameFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        // Policy Field (Selector)
        let policyFieldId = ServerGroupCreateFieldId.policy.rawValue
        let policyItems = ServerGroupPolicy.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: policyFieldId,
            label: ServerGroupCreateField.policy.title,
            items: policyItems,
            selectedItemId: selectedPolicy.rawValue,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == policyFieldId,
            isActive: activeFieldId == policyFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "POLICY", width: 20) { item in
                    (item as? ServerGroupPolicy)?.displayName ?? ""
                },
                FormSelectorItemColumn(header: "DESCRIPTION", width: 50) { item in
                    (item as? ServerGroupPolicy)?.description ?? ""
                }
            ],
            searchQuery: formState.selectorStates[policyFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[policyFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[policyFieldId]?.scrollOffset ?? 0
        )))

        return fields
    }
}

// MARK: - Field Identifiers

enum ServerGroupCreateFieldId: String {
    case name = "server-group-name"
    case policy = "server-group-policy"
}