import Foundation
import SwiftTUI

// MARK: - FormBuilderState

/// Comprehensive state management for FormBuilder
/// Handles navigation, field activation, validation, and user input
struct FormBuilderState {
    // MARK: - Properties

    var fields: [FormField]
    var selectedFieldIndex: Int
    var validationErrors: [String]
    var showValidationErrors: Bool

    // Text field states for editing
    var textFieldStates: [String: FormTextFieldState]

    // Checkbox field states
    var checkboxStates: [String: FormCheckboxFieldState]

    // Selection states
    var selectorStates: [String: FormSelectorFieldState]

    // MARK: - Initialization

    init(fields: [FormField], preservingStateFrom previousState: FormBuilderState? = nil) {
        self.fields = fields
        self.selectedFieldIndex = 0
        self.validationErrors = []
        self.showValidationErrors = false
        // Preserve states from previous FormBuilderState if provided
        self.textFieldStates = previousState?.textFieldStates ?? [:]
        self.checkboxStates = previousState?.checkboxStates ?? [:]
        self.selectorStates = previousState?.selectorStates ?? [:]

        initializeFieldStates()
        selectFirstVisibleField()
        restoreSelectedFieldIndex()
        restoreActiveState()
    }

    // MARK: - Field State Initialization

    private mutating func initializeFieldStates() {
        // Preserve existing states to maintain search queries, cursor positions, etc.
        let existingTextStates = textFieldStates
        let existingCheckboxStates = checkboxStates
        let existingSelectorStates = selectorStates

        for field in fields {
            switch field {
            case .text(let textField):
                // Preserve existing state if available, otherwise create new
                if let existingState = existingTextStates[textField.id] {
                    textFieldStates[textField.id] = existingState
                } else {
                    textFieldStates[textField.id] = FormTextFieldState(
                        initialValue: textField.value
                    )
                }
            case .number(let numberField):
                // Preserve existing state if available, otherwise create new
                if let existingState = existingTextStates[numberField.id] {
                    textFieldStates[numberField.id] = existingState
                } else {
                    textFieldStates[numberField.id] = FormTextFieldState(
                        initialValue: numberField.value
                    )
                }
            case .selector(let selectorField):
                // Preserve existing state if available, otherwise create new
                if let existingState = existingSelectorStates[selectorField.id] {
                    // Update items but preserve search and selection state
                    var updatedState = existingState
                    updatedState.items = selectorField.items
                    // Validate highlightedIndex against new items count
                    let filteredItems = updatedState.getFilteredItems()
                    if updatedState.highlightedIndex >= filteredItems.count {
                        updatedState.highlightedIndex = max(0, filteredItems.count - 1)
                        updatedState.scrollOffset = 0
                    }
                    selectorStates[selectorField.id] = updatedState
                } else {
                    var newState = FormSelectorFieldState(
                        items: selectorField.items,
                        selectedItemId: selectorField.selectedItemId,
                        highlightedIndex: selectorField.highlightedIndex,
                        scrollOffset: selectorField.scrollOffset,
                        searchQuery: selectorField.searchQuery ?? "",
                        isMultiSelect: false
                    )
                    // Activate the state if the field is active
                    if selectorField.isActive {
                        newState.activate()
                    }
                    selectorStates[selectorField.id] = newState
                }
            case .multiSelect(let multiSelectField):
                // Preserve existing state if available, otherwise create new
                if let existingState = existingSelectorStates[multiSelectField.id] {
                    // Update items but preserve search and selection state
                    var updatedState = existingState
                    updatedState.items = multiSelectField.items
                    // Validate highlightedIndex against new items count
                    let filteredItems = updatedState.getFilteredItems()
                    if updatedState.highlightedIndex >= filteredItems.count {
                        updatedState.highlightedIndex = max(0, filteredItems.count - 1)
                        updatedState.scrollOffset = 0
                    }
                    selectorStates[multiSelectField.id] = updatedState
                } else {
                    var newState = FormSelectorFieldState(
                        items: multiSelectField.items,
                        selectedItemIds: multiSelectField.selectedItemIds,
                        highlightedIndex: multiSelectField.highlightedIndex,
                        scrollOffset: multiSelectField.scrollOffset,
                        searchQuery: multiSelectField.searchQuery ?? "",
                        isMultiSelect: true
                    )
                    // Activate the state if the field is active
                    if multiSelectField.isActive {
                        newState.activate()
                    }
                    selectorStates[multiSelectField.id] = newState
                }
            case .checkbox(let checkboxField):
                // Preserve existing state if available, otherwise create new
                if let existingState = existingCheckboxStates[checkboxField.id] {
                    checkboxStates[checkboxField.id] = existingState
                } else {
                    checkboxStates[checkboxField.id] = FormCheckboxFieldState(
                        isChecked: checkboxField.isChecked
                    )
                }
            default:
                break
            }
        }
    }

    // MARK: - Navigation

    mutating func nextField() {
        let visibleFields = getVisibleFields()
        guard !visibleFields.isEmpty else { return }

        deactivateCurrentField()

        if selectedFieldIndex < visibleFields.count - 1 {
            selectedFieldIndex += 1
        } else {
            selectedFieldIndex = 0
        }
    }

    mutating func previousField() {
        let visibleFields = getVisibleFields()
        guard !visibleFields.isEmpty else { return }

        deactivateCurrentField()

        if selectedFieldIndex > 0 {
            selectedFieldIndex -= 1
        } else {
            selectedFieldIndex = visibleFields.count - 1
        }
    }

    private mutating func selectFirstVisibleField() {
        let visibleFields = getVisibleFields()
        if !visibleFields.isEmpty {
            selectedFieldIndex = 0
        }
    }

    private mutating func restoreSelectedFieldIndex() {
        let visibleFields = getVisibleFields()
        if let selectedIndex = visibleFields.firstIndex(where: { $0.isSelected }) {
            selectedFieldIndex = selectedIndex
        }
    }

    private mutating func restoreActiveState() {
        for field in fields {
            if field.isActive {
                switch field {
                case .text(let textField):
                    textFieldStates[textField.id]?.activate()
                case .number(let numberField):
                    textFieldStates[numberField.id]?.activate()
                case .selector(let selectorField):
                    selectorStates[selectorField.id]?.activate()
                case .multiSelect(let multiSelectField):
                    selectorStates[multiSelectField.id]?.activate()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Field Activation

    mutating func activateCurrentField() {
        guard let currentField = getCurrentField() else { return }

        switch currentField {
        case .text(let textField):
            var state = textFieldStates[textField.id] ?? FormTextFieldState(initialValue: textField.value)
            state.activate()
            textFieldStates[textField.id] = state
        case .number(let numberField):
            var state = textFieldStates[numberField.id] ?? FormTextFieldState(initialValue: numberField.value)
            state.activate()
            textFieldStates[numberField.id] = state
        case .selector(let selectorField):
            var state = selectorStates[selectorField.id] ?? FormSelectorFieldState(
                items: selectorField.items,
                selectedItemId: selectorField.selectedItemId,
                isMultiSelect: false
            )
            state.activate()
            selectorStates[selectorField.id] = state
        case .multiSelect(let multiSelectField):
            var state = selectorStates[multiSelectField.id] ?? FormSelectorFieldState(
                items: multiSelectField.items,
                selectedItemIds: multiSelectField.selectedItemIds,
                isMultiSelect: true
            )
            state.activate()
            selectorStates[multiSelectField.id] = state
        default:
            break
        }

        updateFieldState(isActive: true)
    }

    mutating func deactivateCurrentField() {
        guard let currentField = getCurrentField() else { return }

        switch currentField {
        case .text(let textField):
            var state = textFieldStates[textField.id] ?? FormTextFieldState(initialValue: textField.value)
            state.confirm()
            textFieldStates[textField.id] = state
            syncTextFieldToForm(textField.id)
        case .number(let numberField):
            var state = textFieldStates[numberField.id] ?? FormTextFieldState(initialValue: numberField.value)
            state.confirm()
            textFieldStates[numberField.id] = state
            syncTextFieldToForm(numberField.id)
        case .selector(let selectorField):
            var state = selectorStates[selectorField.id]
            state?.deactivate()
            if let updatedState = state {
                selectorStates[selectorField.id] = updatedState
            }
        case .multiSelect(let multiSelectField):
            var state = selectorStates[multiSelectField.id]
            state?.deactivate()
            if let updatedState = state {
                selectorStates[multiSelectField.id] = updatedState
            }
        default:
            break
        }

        updateFieldState(isActive: false)
    }

    mutating func cancelCurrentField() {
        guard let currentField = getCurrentField() else { return }

        switch currentField {
        case .text(let textField):
            var state = textFieldStates[textField.id] ?? FormTextFieldState(initialValue: textField.value)
            state.cancel()
            textFieldStates[textField.id] = state
            syncTextFieldToForm(textField.id)
        case .number(let numberField):
            var state = textFieldStates[numberField.id] ?? FormTextFieldState(initialValue: numberField.value)
            state.cancel()
            textFieldStates[numberField.id] = state
            syncTextFieldToForm(numberField.id)
        case .selector(let selectorField):
            var state = selectorStates[selectorField.id]
            state?.deactivate()
            if let updatedState = state {
                selectorStates[selectorField.id] = updatedState
            }
        case .multiSelect(let multiSelectField):
            var state = selectorStates[multiSelectField.id]
            state?.deactivate()
            if let updatedState = state {
                selectorStates[multiSelectField.id] = updatedState
            }
        default:
            break
        }

        updateFieldState(isActive: false)
    }

    func isCurrentFieldActive() -> Bool {
        guard let currentField = getCurrentField() else { return false }

        switch currentField {
        case .text(let textField):
            return textFieldStates[textField.id]?.isEditing ?? false
        case .number(let numberField):
            return textFieldStates[numberField.id]?.isEditing ?? false
        case .selector(let selectorField):
            return selectorStates[selectorField.id]?.isActive ?? false
        case .multiSelect(let multiSelectField):
            return selectorStates[multiSelectField.id]?.isActive ?? false
        default:
            return false
        }
    }

    /// Toggle the checkbox state for the current field (if it's a checkbox)
    mutating func toggleCurrentCheckbox() {
        guard let currentField = getCurrentField() else { return }

        if case .checkbox(let checkboxField) = currentField {
            checkboxStates[checkboxField.id]?.toggle()
        }
    }

    // MARK: - Field Updates

    private mutating func updateFieldState(isActive: Bool) {
        guard let currentField = getCurrentField() else { return }
        let fieldIndex = findFieldIndex(currentField.id)

        guard let actualIndex = fieldIndex else { return }

        switch fields[actualIndex] {
        case .text(var textField):
            textField.isActive = isActive
            textField.isSelected = true
            fields[actualIndex] = .text(textField)
        case .number(var numberField):
            numberField.isActive = isActive
            numberField.isSelected = true
            fields[actualIndex] = .number(numberField)
        case .selector(var selectorField):
            selectorField.isActive = isActive
            selectorField.isSelected = true
            fields[actualIndex] = .selector(selectorField)
        case .multiSelect(var multiSelectField):
            multiSelectField.isActive = isActive
            multiSelectField.isSelected = true
            fields[actualIndex] = .multiSelect(multiSelectField)
        default:
            break
        }
    }

    // MARK: - Input Handling

    mutating func handleCharacterInput(_ char: Character) {
        guard let currentField = getCurrentField() else { return }

        switch currentField {
        case .text(let textField):
            var state = textFieldStates[textField.id] ?? FormTextFieldState(initialValue: textField.value)
            state.handleCharacterInput(char)
            textFieldStates[textField.id] = state
            syncTextFieldToForm(textField.id)
        case .number(let numberField):
            if char.isNumber || char == "." {
                var state = textFieldStates[numberField.id] ?? FormTextFieldState(initialValue: numberField.value)
                state.handleCharacterInput(char)
                textFieldStates[numberField.id] = state
                syncTextFieldToForm(numberField.id)
            }
        case .selector(let selectorField):
            var state = selectorStates[selectorField.id]
            state?.appendToSearch(char)
            if let updatedState = state {
                selectorStates[selectorField.id] = updatedState
            }
            syncSelectorToForm(selectorField.id)
        case .multiSelect(let multiSelectField):
            var state = selectorStates[multiSelectField.id]
            state?.appendToSearch(char)
            if let updatedState = state {
                selectorStates[multiSelectField.id] = updatedState
            }
            syncSelectorToForm(multiSelectField.id)
        default:
            break
        }
    }

    mutating func handleSpecialKey(_ keyCode: Int32) -> Bool {
        guard let currentField = getCurrentField() else { return false }

        switch currentField {
        case .text(let textField):
            var state = textFieldStates[textField.id] ?? FormTextFieldState(initialValue: textField.value)
            let handled = state.handleSpecialKey(keyCode)
            if handled {
                textFieldStates[textField.id] = state
                syncTextFieldToForm(textField.id)
            }
            return handled
        case .number(let numberField):
            var state = textFieldStates[numberField.id] ?? FormTextFieldState(initialValue: numberField.value)
            let handled = state.handleSpecialKey(keyCode)
            if handled {
                textFieldStates[numberField.id] = state
                syncTextFieldToForm(numberField.id)
            }
            return handled
        case .selector(let selectorField):
            let handled = handleSelectorSpecialKey(keyCode, fieldId: selectorField.id)
            if handled {
                syncSelectorToForm(selectorField.id)
            }
            return handled
        case .multiSelect(let multiSelectField):
            let handled = handleSelectorSpecialKey(keyCode, fieldId: multiSelectField.id)
            if handled {
                syncSelectorToForm(multiSelectField.id)
            }
            return handled
        default:
            return false
        }
    }

    private mutating func handleSelectorSpecialKey(_ keyCode: Int32, fieldId: String) -> Bool {
        guard var state = selectorStates[fieldId] else { return false }

        switch keyCode {
        case Int32(259): // KEY_UP
            state.moveUp()
            selectorStates[fieldId] = state
            return true
        case Int32(258): // KEY_DOWN
            state.moveDown()
            selectorStates[fieldId] = state
            return true
        case Int32(127), Int32(8): // BACKSPACE
            state.removeLastSearchCharacter()
            selectorStates[fieldId] = state
            return true
        default:
            return false
        }
    }

    // MARK: - Toggle Actions

    mutating func toggleCurrentField() {
        guard let currentField = getCurrentField() else { return }

        switch currentField {
        case .toggle(var toggleField):
            toggleField.value.toggle()
            if let index = findFieldIndex(toggleField.id) {
                fields[index] = .toggle(toggleField)
            }
        case .checkbox(var checkboxField):
            checkboxField.isChecked.toggle()
            if let index = findFieldIndex(checkboxField.id) {
                fields[index] = .checkbox(checkboxField)
            }
            // Also update the checkbox state
            checkboxStates[checkboxField.id]?.toggle()
        case .select(let selectField):
            // Select fields don't need to be active to toggle - cycle immediately
            cycleSelectOption(selectField)
        case .selector(let selectorField):
            if selectorField.isActive {
                selectorStates[selectorField.id]?.toggleSelection()
                syncSelectorToForm(selectorField.id)
            }
        case .multiSelect(let multiSelectField):
            if multiSelectField.isActive {
                selectorStates[multiSelectField.id]?.toggleSelection()
                syncSelectorToForm(multiSelectField.id)
            }
        default:
            break
        }
    }

    private mutating func cycleSelectOption(_ selectField: FormFieldSelect) {
        guard !selectField.options.isEmpty else { return }

        let currentIndex: Int
        if let selectedId = selectField.selectedOptionId,
           let index = selectField.options.firstIndex(where: { $0.id == selectedId }) {
            currentIndex = index
        } else {
            currentIndex = -1
        }

        let nextIndex = (currentIndex + 1) % selectField.options.count
        let nextOption = selectField.options[nextIndex]

        var updatedField = selectField
        updatedField.selectedOptionId = nextOption.id

        if let index = findFieldIndex(selectField.id) {
            fields[index] = .select(updatedField)
        }
    }

    mutating func cyclePreviousOption() {
        guard let currentField = getCurrentField() else { return }

        if case .select(let selectField) = currentField {
            guard !selectField.options.isEmpty else { return }

            let currentIndex: Int
            if let selectedId = selectField.selectedOptionId,
               let index = selectField.options.firstIndex(where: { $0.id == selectedId }) {
                currentIndex = index
            } else {
                currentIndex = 0
            }

            let previousIndex = (currentIndex - 1 + selectField.options.count) % selectField.options.count
            let previousOption = selectField.options[previousIndex]

            var updatedField = selectField
            updatedField.selectedOptionId = previousOption.id

            if let index = findFieldIndex(selectField.id) {
                fields[index] = .select(updatedField)
            }
        }
    }

    // MARK: - Sync Helpers

    private mutating func syncTextFieldToForm(_ fieldId: String) {
        guard let state = textFieldStates[fieldId],
              let index = findFieldIndex(fieldId) else { return }

        switch fields[index] {
        case .text(var textField):
            textField.value = state.value
            textField.cursorPosition = state.cursorPosition
            fields[index] = .text(textField)
        case .number(var numberField):
            numberField.value = state.value
            numberField.cursorPosition = state.cursorPosition
            fields[index] = .number(numberField)
        default:
            break
        }
    }

    private mutating func syncSelectorToForm(_ fieldId: String) {
        guard let state = selectorStates[fieldId],
              let index = findFieldIndex(fieldId) else { return }

        switch fields[index] {
        case .selector(var selectorField):
            selectorField.selectedItemId = state.selectedItemId
            selectorField.highlightedIndex = state.highlightedIndex
            selectorField.scrollOffset = state.scrollOffset
            selectorField.searchQuery = state.searchQuery
            fields[index] = .selector(selectorField)
        case .multiSelect(var multiSelectField):
            multiSelectField.selectedItemIds = state.selectedItemIds
            multiSelectField.highlightedIndex = state.highlightedIndex
            multiSelectField.scrollOffset = state.scrollOffset
            multiSelectField.searchQuery = state.searchQuery
            fields[index] = .multiSelect(multiSelectField)
        default:
            break
        }
    }

    // MARK: - Query Helpers

    func getCurrentField() -> FormField? {
        let visibleFields = getVisibleFields()
        guard selectedFieldIndex < visibleFields.count else { return nil }
        return visibleFields[selectedFieldIndex]
    }

    func getVisibleFields() -> [FormField] {
        return fields.filter { field in
            guard field.isVisible else { return false }
            // Filter out non-interactive fields (info fields)
            switch field {
            case .info:
                return false
            default:
                return true
            }
        }
    }

    func getCurrentFieldId() -> String? {
        return getCurrentField()?.id
    }

    func getActiveFieldId() -> String? {
        for field in fields {
            if field.isActive {
                return field.id
            }
        }
        return nil
    }

    private func findFieldIndex(_ fieldId: String) -> Int? {
        return fields.firstIndex { $0.id == fieldId }
    }

    // MARK: - Validation

    mutating func validateForm() -> Bool {
        validationErrors.removeAll()

        for field in fields.filter({ $0.isVisible }) {
            if let error = field.validationError, !error.isEmpty {
                validationErrors.append("\(field.label): \(error)")
            }
        }

        showValidationErrors = !validationErrors.isEmpty
        return validationErrors.isEmpty
    }

    mutating func clearValidation() {
        validationErrors.removeAll()
        showValidationErrors = false
    }

    // MARK: - Field Value Getters

    func getTextValue(_ fieldId: String) -> String? {
        return textFieldStates[fieldId]?.value
    }

    func getNumberValue(_ fieldId: String) -> Int? {
        guard let stringValue = textFieldStates[fieldId]?.value else { return nil }
        return Int(stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
    }

    func getToggleValue(_ fieldId: String) -> Bool? {
        guard let field = fields.first(where: { $0.id == fieldId }) else { return nil }
        if case .toggle(let toggleField) = field {
            return toggleField.value
        }
        return nil
    }

    func getCheckboxValue(_ fieldId: String) -> Bool? {
        return checkboxStates[fieldId]?.isChecked
    }

    func getSelectedOptionId(_ fieldId: String) -> String? {
        guard let field = fields.first(where: { $0.id == fieldId }) else { return nil }
        if case .select(let selectField) = field {
            return selectField.selectedOptionId
        }
        return nil
    }

    func getSelectorSelectedId(_ fieldId: String) -> String? {
        return selectorStates[fieldId]?.selectedItemId
    }

    func getMultiSelectSelectedIds(_ fieldId: String) -> Set<String>? {
        return selectorStates[fieldId]?.selectedItemIds
    }

    func getTextFieldCursorPosition(_ fieldId: String) -> Int? {
        return textFieldStates[fieldId]?.cursorPosition
    }

    func isTextFieldActive(_ fieldId: String) -> Bool {
        return textFieldStates[fieldId]?.isEditing ?? false
    }

    func getSelectorState(_ fieldId: String) -> FormSelectorFieldState? {
        return selectorStates[fieldId]
    }
}

// MARK: - FormSelectorFieldState

struct FormSelectorFieldState {
    var items: [any FormSelectorItem]
    var selectedItemId: String?
    var selectedItemIds: Set<String>
    var highlightedIndex: Int
    var scrollOffset: Int
    var searchQuery: String
    var isActive: Bool
    var isMultiSelect: Bool

    init(
        items: [any FormSelectorItem],
        selectedItemId: String? = nil,
        selectedItemIds: Set<String> = [],
        highlightedIndex: Int = 0,
        scrollOffset: Int = 0,
        searchQuery: String = "",
        isMultiSelect: Bool = false
    ) {
        self.items = items
        self.selectedItemId = selectedItemId
        self.selectedItemIds = selectedItemIds
        self.highlightedIndex = highlightedIndex
        self.scrollOffset = scrollOffset
        self.searchQuery = searchQuery
        self.isActive = false
        self.isMultiSelect = isMultiSelect
    }

    mutating func activate() {
        isActive = true
    }

    mutating func deactivate() {
        isActive = false
    }

    mutating func toggleSelection() {
        let filteredItems = getFilteredItems()
        guard highlightedIndex < filteredItems.count else { return }
        let itemId = filteredItems[highlightedIndex].id

        if isMultiSelect {
            if selectedItemIds.contains(itemId) {
                selectedItemIds.remove(itemId)
            } else {
                selectedItemIds.insert(itemId)
            }
        } else {
            selectedItemId = itemId
        }
    }

    mutating func moveUp() {
        if highlightedIndex > 0 {
            highlightedIndex -= 1
            adjustScrollOffset()
        }
    }

    mutating func moveDown() {
        let filteredItems = getFilteredItems()
        if highlightedIndex < filteredItems.count - 1 {
            highlightedIndex += 1
            adjustScrollOffset()
        }
    }

    mutating func appendToSearch(_ char: Character) {
        searchQuery.append(char)
        highlightedIndex = 0
        scrollOffset = 0
    }

    mutating func removeLastSearchCharacter() {
        if !searchQuery.isEmpty {
            searchQuery.removeLast()
            highlightedIndex = 0
            scrollOffset = 0
        }
    }

    private mutating func adjustScrollOffset() {
        let maxVisibleItems = 10

        if highlightedIndex < scrollOffset {
            scrollOffset = highlightedIndex
        } else if highlightedIndex >= scrollOffset + maxVisibleItems {
            scrollOffset = highlightedIndex - maxVisibleItems + 1
        }

        if scrollOffset < 0 {
            scrollOffset = 0
        }
    }

    func getFilteredItems() -> [any FormSelectorItem] {
        guard !searchQuery.isEmpty else { return items }
        return items.filter { $0.matchesSearch(searchQuery) }
    }
}
