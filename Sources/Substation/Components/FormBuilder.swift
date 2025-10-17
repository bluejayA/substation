import Foundation
import SwiftNCurses

// MARK: - FormBuilder Architecture
//
// FormBuilder provides a declarative, type-safe form rendering system with the following design:
//
// **Rendering Patterns:**
// - Text/Number/Toggle/Select fields: Rendered inline by FormBuilder
// - Selector/MultiSelect fields: ALWAYS rendered as custom view overlays by the view layer
// - Custom fields: User-provided components rendered inline
//
// **Custom View Pattern for Selectors:**
// When a selector or multiSelect field becomes active (user presses SPACE):
// 1. FormBuilder renders a collapsed summary with "[Press SPACE to select]" prompt
// 2. The view layer (e.g., ServerCreateView) detects the active field via formState.getCurrentField()
// 3. The view renders a specialized view (FlavorSelectionView, NetworkSelectionView, etc.) as an overlay
// 4. Input is routed to FormBuilderState which manages the selector state
// 5. When user presses ENTER/ESC, the field deactivates and the overlay closes
//
// This pattern ensures:
// - Consistent UX with rich, specialized selection interfaces
// - Type-safe integration with OSClient types
// - Clean separation: FormBuilder handles layout, views handle selection UI
//
// See ServerCreateView.swift lines 76-104 for the reference implementation.

// MARK: - FormField Definition

/// Unified form field type that supports all input patterns
enum FormField {
    /// Text input field
    case text(FormFieldText)

    /// Numeric input field
    case number(FormFieldNumber)

    /// Boolean toggle field
    case toggle(FormFieldToggle)

    /// Boolean checkbox field
    case checkbox(FormFieldCheckbox)

    /// Single selection from enum-like options
    case select(FormFieldSelect)

    /// Single selection from a list with search and columns
    case selector(FormFieldSelector)

    /// Multiple selection from a list
    case multiSelect(FormFieldMultiSelect)

    /// Read-only info display
    case info(FormFieldInfo)

    /// Custom field with user-provided component
    case custom(FormFieldCustom)

    // MARK: - Field Properties

    var id: String {
        switch self {
        case .text(let field): return field.id
        case .number(let field): return field.id
        case .toggle(let field): return field.id
        case .checkbox(let field): return field.id
        case .select(let field): return field.id
        case .selector(let field): return field.id
        case .multiSelect(let field): return field.id
        case .info(let field): return field.id
        case .custom(let field): return field.id
        }
    }

    var label: String {
        switch self {
        case .text(let field): return field.label
        case .number(let field): return field.label
        case .toggle(let field): return field.label
        case .checkbox(let field): return field.label
        case .select(let field): return field.label
        case .selector(let field): return field.label
        case .multiSelect(let field): return field.label
        case .info(let field): return field.label
        case .custom(let field): return field.label
        }
    }

    var isRequired: Bool {
        switch self {
        case .text(let field): return field.isRequired
        case .number(let field): return field.isRequired
        case .select(let field): return field.isRequired
        case .selector(let field): return field.isRequired
        case .multiSelect(let field): return field.isRequired
        case .toggle, .checkbox, .info, .custom: return false
        }
    }

    var isVisible: Bool {
        switch self {
        case .text(let field): return field.isVisible
        case .number(let field): return field.isVisible
        case .toggle(let field): return field.isVisible
        case .checkbox(let field): return field.isVisible
        case .select(let field): return field.isVisible
        case .selector(let field): return field.isVisible
        case .multiSelect(let field): return field.isVisible
        case .info(let field): return field.isVisible
        case .custom(let field): return field.isVisible
        }
    }

    var validationError: String? {
        switch self {
        case .text(let field): return field.validationError
        case .number(let field): return field.validationError
        case .select(let field): return field.validationError
        case .selector(let field): return field.validationError
        case .multiSelect(let field): return field.validationError
        case .toggle, .checkbox, .info, .custom: return nil
        }
    }

    var isSelected: Bool {
        switch self {
        case .text(let field): return field.isSelected
        case .number(let field): return field.isSelected
        case .toggle(let field): return field.isSelected
        case .checkbox(let field): return field.isSelected
        case .select(let field): return field.isSelected
        case .selector(let field): return field.isSelected
        case .multiSelect(let field): return field.isSelected
        case .info(let field): return field.isSelected
        case .custom(let field): return field.isSelected
        }
    }

    var isActive: Bool {
        switch self {
        case .text(let field): return field.isActive
        case .number(let field): return field.isActive
        case .toggle, .checkbox, .info, .custom: return false
        case .select(let field): return field.isActive
        case .selector(let field): return field.isActive
        case .multiSelect(let field): return field.isActive
        }
    }
}

// MARK: - Text Field

struct FormFieldText {
    let id: String
    let label: String
    var value: String
    let placeholder: String
    let isRequired: Bool
    let isVisible: Bool
    var isSelected: Bool
    var isActive: Bool
    var cursorPosition: Int?
    let validationError: String?
    let maxWidth: Int?
    let maxLength: Int?

    init(
        id: String,
        label: String,
        value: String = "",
        placeholder: String = "Press SPACE to edit",
        isRequired: Bool = false,
        isVisible: Bool = true,
        isSelected: Bool = false,
        isActive: Bool = false,
        cursorPosition: Int? = nil,
        validationError: String? = nil,
        maxWidth: Int? = 50,
        maxLength: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.isActive = isActive
        self.cursorPosition = cursorPosition
        self.validationError = validationError
        self.maxWidth = maxWidth
        self.maxLength = maxLength
    }
}

// MARK: - Number Field

struct FormFieldNumber {
    let id: String
    let label: String
    var value: String
    let placeholder: String
    let isRequired: Bool
    let isVisible: Bool
    var isSelected: Bool
    var isActive: Bool
    var cursorPosition: Int?
    let validationError: String?
    let minValue: Int?
    let maxValue: Int?
    let unit: String?

    init(
        id: String,
        label: String,
        value: String = "",
        placeholder: String = "Enter number",
        isRequired: Bool = false,
        isVisible: Bool = true,
        isSelected: Bool = false,
        isActive: Bool = false,
        cursorPosition: Int? = nil,
        validationError: String? = nil,
        minValue: Int? = nil,
        maxValue: Int? = nil,
        unit: String? = nil
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.isActive = isActive
        self.cursorPosition = cursorPosition
        self.validationError = validationError
        self.minValue = minValue
        self.maxValue = maxValue
        self.unit = unit
    }
}

// MARK: - Toggle Field

struct FormFieldToggle {
    let id: String
    let label: String
    var value: Bool
    let isVisible: Bool
    var isSelected: Bool
    let enabledLabel: String?
    let disabledLabel: String?

    init(
        id: String,
        label: String,
        value: Bool = false,
        isVisible: Bool = true,
        isSelected: Bool = false,
        enabledLabel: String? = nil,
        disabledLabel: String? = nil
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.enabledLabel = enabledLabel
        self.disabledLabel = disabledLabel
    }
}

// MARK: - Checkbox Field

struct FormFieldCheckbox {
    let id: String
    let label: String
    var isChecked: Bool
    let isVisible: Bool
    var isSelected: Bool
    let isDisabled: Bool
    let helpText: String?

    init(
        id: String,
        label: String,
        isChecked: Bool = false,
        isVisible: Bool = true,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        helpText: String? = nil
    ) {
        self.id = id
        self.label = label
        self.isChecked = isChecked
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.helpText = helpText
    }
}

// MARK: - Select Field (Enum-like options)

struct FormFieldSelect {
    let id: String
    let label: String
    let options: [FormSelectOption]
    var selectedOptionId: String?
    let isRequired: Bool
    let isVisible: Bool
    var isSelected: Bool
    var isActive: Bool
    let validationError: String?

    init(
        id: String,
        label: String,
        options: [FormSelectOption],
        selectedOptionId: String? = nil,
        isRequired: Bool = false,
        isVisible: Bool = true,
        isSelected: Bool = false,
        isActive: Bool = false,
        validationError: String? = nil
    ) {
        self.id = id
        self.label = label
        self.options = options
        self.selectedOptionId = selectedOptionId
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.isActive = isActive
        self.validationError = validationError
    }

    var selectedOption: FormSelectOption? {
        options.first { $0.id == selectedOptionId }
    }
}

struct FormSelectOption {
    let id: String
    let title: String
    let description: String?

    init(id: String, title: String, description: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
    }
}

// MARK: - Selector Field (Advanced selection with columns)

struct FormFieldSelector {
    let id: String
    let label: String
    let items: [any FormSelectorItem]
    var selectedItemId: String?
    let isRequired: Bool
    let isVisible: Bool
    var isSelected: Bool
    var isActive: Bool
    let validationError: String?
    let columns: [FormSelectorItemColumn]
    var searchQuery: String?
    var highlightedIndex: Int
    var scrollOffset: Int

    init(
        id: String,
        label: String,
        items: [any FormSelectorItem] = [],
        selectedItemId: String? = nil,
        isRequired: Bool = false,
        isVisible: Bool = true,
        isSelected: Bool = false,
        isActive: Bool = false,
        validationError: String? = nil,
        columns: [FormSelectorItemColumn] = [],
        searchQuery: String? = nil,
        highlightedIndex: Int = 0,
        scrollOffset: Int = 0
    ) {
        self.id = id
        self.label = label
        self.items = items
        self.selectedItemId = selectedItemId
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.isActive = isActive
        self.validationError = validationError
        self.columns = columns
        self.searchQuery = searchQuery
        self.highlightedIndex = highlightedIndex
        self.scrollOffset = scrollOffset
    }
}

// MARK: - Multi-Select Field

struct FormFieldMultiSelect {
    let id: String
    let label: String
    let items: [any FormSelectorItem]
    var selectedItemIds: Set<String>
    let isRequired: Bool
    let isVisible: Bool
    var isSelected: Bool
    var isActive: Bool
    let validationError: String?
    let columns: [FormSelectorItemColumn]
    var searchQuery: String?
    var highlightedIndex: Int
    var scrollOffset: Int
    let minSelections: Int?
    let maxSelections: Int?

    init(
        id: String,
        label: String,
        items: [any FormSelectorItem] = [],
        selectedItemIds: Set<String> = [],
        isRequired: Bool = false,
        isVisible: Bool = true,
        isSelected: Bool = false,
        isActive: Bool = false,
        validationError: String? = nil,
        columns: [FormSelectorItemColumn] = [],
        searchQuery: String? = nil,
        highlightedIndex: Int = 0,
        scrollOffset: Int = 0,
        minSelections: Int? = nil,
        maxSelections: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.items = items
        self.selectedItemIds = selectedItemIds
        self.isRequired = isRequired
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.isActive = isActive
        self.validationError = validationError
        self.columns = columns
        self.searchQuery = searchQuery
        self.highlightedIndex = highlightedIndex
        self.scrollOffset = scrollOffset
        self.minSelections = minSelections
        self.maxSelections = maxSelections
    }
}

// MARK: - Info Field (Read-only display)

struct FormFieldInfo {
    let id: String
    let label: String
    var value: String
    let isVisible: Bool
    var isSelected: Bool
    let style: TextStyle

    init(
        id: String,
        label: String,
        value: String,
        isVisible: Bool = true,
        isSelected: Bool = false,
        style: TextStyle = .info
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.style = style
    }
}

// MARK: - Custom Field

struct FormFieldCustom {
    let id: String
    let label: String
    let isVisible: Bool
    var isSelected: Bool
    let render: () -> any Component

    init(
        id: String,
        label: String,
        isVisible: Bool = true,
        isSelected: Bool = false,
        render: @escaping () -> any Component
    ) {
        self.id = id
        self.label = label
        self.isVisible = isVisible
        self.isSelected = isSelected
        self.render = render
    }
}

// MARK: - Form Selector Item Protocol

protocol FormSelectorItem {
    var id: String { get }
    func matchesSearch(_ query: String) -> Bool
}

struct FormSelectorItemColumn {
    let header: String
    let width: Int
    let getValue: (any FormSelectorItem) -> String

    init(header: String, width: Int, getValue: @escaping (any FormSelectorItem) -> String) {
        self.header = header
        self.width = width
        self.getValue = getValue
    }
}

// MARK: - FormBuilder Component

/// The main FormBuilder component that renders all form fields
struct FormBuilder {
    // Layout Constants
    private static let componentTopPadding: Int32 = 1
    private static let componentSpacing: Int32 = 0
    private static let validationErrorLeadingPadding: Int32 = 2
    private static let selectedIndicator = "> "
    private static let unselectedIndicator = "  "
    private static let checkboxSelected = "[X]"
    private static let checkboxUnselected = "[ ]"

    // Text Constants
    private static let requiredSuffix = ": *"
    private static let optionalSuffix = ":"
    private static let validationErrorsTitle = "Validation Errors:"
    private static let validationErrorPrefix = "- "
    private static let selectPromptText = "Press SPACE to select..."
    private static let editPromptText = "Press SPACE to edit..."

    let title: String
    let fields: [FormField]
    let selectedFieldId: String?
    let validationErrors: [String]
    let showValidationErrors: Bool

    init(
        title: String,
        fields: [FormField],
        selectedFieldId: String? = nil,
        validationErrors: [String] = [],
        showValidationErrors: Bool = false
    ) {
        self.title = title
        self.fields = fields
        self.selectedFieldId = selectedFieldId
        self.validationErrors = validationErrors
        self.showValidationErrors = showValidationErrors
    }

    /// Render the complete form
    func render() -> any Component {
        var components: [any Component] = []

        // Title
        components.append(Text(title).emphasis().bold())

        // Render visible fields
        let visibleFields = fields.filter { $0.isVisible }
        for field in visibleFields {
            let fieldComponent = renderField(field)
            components.append(fieldComponent)
        }

        // Show validation errors if requested
        if showValidationErrors && !validationErrors.isEmpty {
            components.append(Text(Self.validationErrorsTitle).error().bold()
                .padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0)))

            for error in validationErrors {
                components.append(Text("\(Self.validationErrorPrefix)\(error)").error()
                    .padding(EdgeInsets(top: 0, leading: Self.validationErrorLeadingPadding, bottom: 0, trailing: 0)))
            }
        }

        return VStack(spacing: Self.componentSpacing, children: components)
    }

    // MARK: - Field Rendering

    private func renderField(_ field: FormField) -> any Component {
        let isSelected = field.id == selectedFieldId

        switch field {
        case .text(let textField):
            return renderTextField(textField, isSelected: isSelected)
        case .number(let numberField):
            return renderNumberField(numberField, isSelected: isSelected)
        case .toggle(let toggleField):
            return renderToggleField(toggleField, isSelected: isSelected)
        case .checkbox(let checkboxField):
            return renderCheckboxField(checkboxField, isSelected: isSelected)
        case .select(let selectField):
            return renderSelectField(selectField, isSelected: isSelected)
        case .selector(let selectorField):
            return renderSelectorField(selectorField, isSelected: isSelected)
        case .multiSelect(let multiSelectField):
            return renderMultiSelectField(multiSelectField, isSelected: isSelected)
        case .info(let infoField):
            return renderInfoField(infoField)
        case .custom(let customField):
            return renderCustomField(customField, isSelected: isSelected)
        }
    }

    private func renderTextField(_ field: FormFieldText, isSelected: Bool) -> any Component {
        let textField = FormTextField(
            label: field.label,
            value: field.value,
            placeholder: field.placeholder,
            isRequired: field.isRequired,
            isSelected: isSelected,
            isActive: field.isActive,
            maxWidth: field.maxWidth,
            validationError: field.validationError,
            cursorPosition: field.cursorPosition
        )

        return VStack(spacing: 0, children: [
            textField.render()
        ])
    }

    private func renderNumberField(_ field: FormFieldNumber, isSelected: Bool) -> any Component {
        var displayValue = field.value
        if let unit = field.unit, !field.value.isEmpty {
            displayValue = "\(field.value) \(unit)"
        }

        let textField = FormTextField(
            label: field.label,
            value: displayValue,
            placeholder: field.placeholder,
            isRequired: field.isRequired,
            isSelected: isSelected,
            isActive: field.isActive,
            maxWidth: 20,
            validationError: field.validationError,
            cursorPosition: field.cursorPosition
        )

        return VStack(spacing: 0, children: [
            textField.render()
        ])
    }

    private func renderToggleField(_ field: FormFieldToggle, isSelected: Bool) -> any Component {
        let indicator = isSelected ? Self.selectedIndicator : Self.unselectedIndicator
        let checkbox = field.value ? Self.checkboxSelected : Self.checkboxUnselected

        let statusLabel = field.value ?
            (field.enabledLabel ?? "Enabled") :
            (field.disabledLabel ?? "Disabled")

        let labelSuffix = Self.optionalSuffix

        return VStack(spacing: Self.componentSpacing, children: [
            Text("\(field.label)\(labelSuffix)").accent().bold(),
            HStack(spacing: 0, children: [
                Text(indicator).styled(isSelected ? .accent : .secondary),
                Text("\(checkbox) ").styled(field.value ? .success : .secondary),
                Text(statusLabel).primary()
            ])
        ]).padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0))
    }

    private func renderCheckboxField(_ field: FormFieldCheckbox, isSelected: Bool) -> any Component {
        let indicator = isSelected ? Self.selectedIndicator : Self.unselectedIndicator
        let checkbox = field.isChecked ? Self.checkboxSelected : Self.checkboxUnselected

        let labelSuffix = Self.optionalSuffix

        // Apply disabled styling if checkbox is disabled
        let checkboxStyle: TextStyle = field.isDisabled ? .secondary : (field.isChecked ? .success : .secondary)
        let labelStyle: TextStyle = field.isDisabled ? .secondary : .primary

        var components: [any Component] = [
            Text("\(field.label)\(labelSuffix)").styled(field.isDisabled ? .secondary : .accent).bold(),
            HStack(spacing: 0, children: [
                Text(indicator).styled(field.isDisabled ? .secondary : (isSelected ? .accent : .secondary)),
                Text("\(checkbox) ").styled(checkboxStyle),
                Text(field.label).styled(labelStyle)
            ])
        ]

        if let helpText = field.helpText {
            components.append(
                Text("  \(helpText)").secondary()
                    .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
            )
        }

        return VStack(spacing: Self.componentSpacing, children: components)
            .padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0))
    }

    private func renderSelectField(_ field: FormFieldSelect, isSelected: Bool) -> any Component {
        let indicator = isSelected ? Self.selectedIndicator : Self.unselectedIndicator
        let labelSuffix = field.isRequired ? Self.requiredSuffix : Self.optionalSuffix

        var valueComponents: [any Component] = [Text(indicator).styled(isSelected ? .accent : .secondary)]

        if let selected = field.selectedOption {
            valueComponents.append(Text("\(Self.checkboxSelected) ").success())
            valueComponents.append(Text(selected.title).primary())
            if let desc = selected.description {
                valueComponents.append(Text(" (\(desc))").secondary())
            }
        } else {
            valueComponents.append(Text("\(Self.checkboxUnselected) \(Self.selectPromptText)").info())
        }

        var components: [any Component] = [
            Text("\(field.label)\(labelSuffix)").accent().bold(),
            HStack(spacing: 0, children: valueComponents)
        ]

        if let error = field.validationError {
            components.append(Text("  ! \(error)").error()
                .padding(EdgeInsets(top: 0, leading: Self.validationErrorLeadingPadding, bottom: 0, trailing: 0)))
        }

        return VStack(spacing: Self.componentSpacing, children: components)
            .padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0))
    }

    private func renderSelectorField(_ field: FormFieldSelector, isSelected: Bool) -> any Component {
        // IMPORTANT: Selector fields ALWAYS render as overlays via custom views in the view layer
        // FormBuilder only renders the collapsed summary - active state shows "[Press SPACE]" prompt
        // The view layer (e.g., ServerCreateView) is responsible for rendering the full selector overlay

        // Render collapsed summary
        let indicator = isSelected ? Self.selectedIndicator : Self.unselectedIndicator
        let labelSuffix = field.isRequired ? Self.requiredSuffix : Self.optionalSuffix

        var valueComponents: [any Component] = [Text(indicator).styled(isSelected ? .accent : .secondary)]

        if let selectedId = field.selectedItemId,
           let selectedItem = field.items.first(where: { $0.id == selectedId }) {
            valueComponents.append(Text("\(Self.checkboxSelected) ").success())

            let displayText = field.columns.first?.getValue(selectedItem) ?? selectedId
            valueComponents.append(Text(displayText).primary())
        } else {
            valueComponents.append(Text("\(Self.checkboxUnselected) \(Self.selectPromptText)").info())
        }

        var components: [any Component] = [
            Text("\(field.label)\(labelSuffix)").accent().bold(),
            HStack(spacing: 0, children: valueComponents)
        ]

        if let error = field.validationError {
            components.append(Text("  ! \(error)").error()
                .padding(EdgeInsets(top: 0, leading: Self.validationErrorLeadingPadding, bottom: 0, trailing: 0)))
        }

        return VStack(spacing: Self.componentSpacing, children: components)
            .padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0))
    }

    private func renderMultiSelectField(_ field: FormFieldMultiSelect, isSelected: Bool) -> any Component {
        // IMPORTANT: MultiSelect fields ALWAYS render as overlays via custom views in the view layer
        // FormBuilder only renders the collapsed summary - active state shows "[Press SPACE]" prompt
        // The view layer (e.g., ServerCreateView) is responsible for rendering the full selector overlay

        // Render collapsed summary
        let indicator = isSelected ? Self.selectedIndicator : Self.unselectedIndicator
        let labelSuffix = field.isRequired ? Self.requiredSuffix : Self.optionalSuffix

        var valueComponents: [any Component] = [Text(indicator).styled(isSelected ? .accent : .secondary)]

        if field.selectedItemIds.isEmpty {
            valueComponents.append(Text("\(Self.checkboxUnselected) \(Self.selectPromptText)").info())
        } else {
            let selectedItems = field.items.filter { field.selectedItemIds.contains($0.id) }
            let displayText = selectedItems.compactMap { item in
                field.columns.first?.getValue(item)
            }.joined(separator: ", ")

            valueComponents.append(Text("[\(field.selectedItemIds.count)] ").success())
            valueComponents.append(Text(displayText).primary())
        }

        var components: [any Component] = [
            Text("\(field.label)\(labelSuffix)").accent().bold(),
            HStack(spacing: 0, children: valueComponents)
        ]

        if let error = field.validationError {
            components.append(Text("  ! \(error)").error()
                .padding(EdgeInsets(top: 0, leading: Self.validationErrorLeadingPadding, bottom: 0, trailing: 0)))
        }

        return VStack(spacing: Self.componentSpacing, children: components)
            .padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0))
    }

    private func renderInfoField(_ field: FormFieldInfo) -> any Component {
        return VStack(spacing: Self.componentSpacing, children: [
            Text("\(field.label):").accent().bold(),
            Text("  \(field.value)").styled(field.style)
        ]).padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0))
    }

    private func renderCustomField(_ field: FormFieldCustom, isSelected: Bool) -> any Component {
        return VStack(spacing: 0, children: [
            field.render()
        ])
    }
}
