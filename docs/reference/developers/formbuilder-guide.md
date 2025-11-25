# FormBuilder Component Guide

## Overview

The **FormBuilder** component provides a unified, consistent API for creating forms across all OpenStack services in the Substation UI. It consolidates all form field types into a single component with built-in validation, navigation, and state management.

You could build all this yourself. You could spend weeks implementing text editing, navigation, validation, and state management. Or you could use FormBuilder and ship your feature today. Your choice.

## Features

- **Unified API**: Single component for all form field types
- **Built-in Validation**: Automatic error display and validation state
- **Consistent Styling**: All fields follow the same visual patterns
- **State Management**: Comprehensive state handling with FormBuilderState
- **Keyboard Navigation**: TAB/Shift+TAB for field navigation
- **Field Types**: Text, Number, Toggle, Select, Selector, Multi-Select, Info, Custom
- **Conditional Visibility**: Show/hide fields based on logic
- **Search Support**: Built-in search for selector fields

## Quick Start

### 1. Basic Form Example

```swift
// Define your fields
let fields: [FormField] = [
    .text(FormFieldText(
        id: "name",
        label: "Network Name",
        value: networkName,
        isRequired: true,
        isSelected: selectedFieldId == "name"
    )),

    .number(FormFieldNumber(
        id: "mtu",
        label: "MTU",
        value: mtu,
        minValue: 68,
        maxValue: 9000,
        unit: "bytes",
        isRequired: true,
        isSelected: selectedFieldId == "mtu"
    )),

    .toggle(FormFieldToggle(
        id: "portSecurity",
        label: "Port Security",
        value: portSecurityEnabled,
        isSelected: selectedFieldId == "portSecurity",
        enabledLabel: "Enabled",
        disabledLabel: "Disabled"
    ))
]

// Create the form
let form = FormBuilder(
    title: "Create Network",
    fields: fields,
    selectedFieldId: state.getCurrentFieldId(),
    validationErrors: state.validationErrors,
    showValidationErrors: state.showValidationErrors
)

// Render
await SwiftNCurses.render(form.render(), on: surface, in: bounds)
```

### 2. State Management

```swift
// Initialize state
var formState = FormBuilderState(fields: fields)

// Navigation
formState.nextField()        // TAB
formState.previousField()    // Shift+TAB

// Activation
formState.activateCurrentField()    // SPACE
formState.deactivateCurrentField()  // ENTER or ESC

// Input handling
formState.handleCharacterInput(char)
formState.handleSpecialKey(keyCode)

// Toggle actions
formState.toggleCurrentField()  // For toggles, selections

// Validation
let isValid = formState.validateForm()

// Get values
let name = formState.getTextValue("name")
let mtu = formState.getNumberValue("mtu")
let portSecurity = formState.getToggleValue("portSecurity")
let termsAccepted = formState.checkboxStates["acceptTerms"]?.isChecked ?? false
```

## Field Types

### Text Field

For single-line text input with cursor support, history, and validation.

```swift
.text(FormFieldText(
    id: "serverName",
    label: "Server Name",
    value: serverName,
    placeholder: "Enter server name",
    isRequired: true,
    isVisible: true,
    isSelected: selectedFieldId == "serverName",
    isActive: isEditing,
    cursorPosition: cursorPos,
    validationError: nameError,
    maxWidth: 50,
    maxLength: 255
))
```

**Features:**

- Cursor movement (LEFT/RIGHT, HOME/END)
- History (UP/DOWN arrows)
- Character-by-character editing
- Backspace/Delete support
- Auto-validation display

### Number Field

For numeric input with range validation and optional units.

```swift
.number(FormFieldNumber(
    id: "volumeSize",
    label: "Volume Size",
    value: volumeSize,
    placeholder: "Enter size",
    isRequired: true,
    isVisible: true,
    isSelected: selectedFieldId == "volumeSize",
    isActive: isEditing,
    validationError: sizeError,
    minValue: 1,
    maxValue: 1000,
    unit: "GB"
))
```

**Features:**

- Only accepts numeric input
- Range validation
- Optional unit display
- Same editing features as text field

### Toggle Field

For boolean on/off switches.

```swift
.toggle(FormFieldToggle(
    id: "autoBackup",
    label: "Automatic Backups",
    value: autoBackupEnabled,
    isVisible: true,
    isSelected: selectedFieldId == "autoBackup",
    enabledLabel: "Enabled",
    disabledLabel: "Disabled"
))
```

**Interaction:**

- SPACE to toggle value
- Visual checkbox indicator [X] / [ ]
- Custom enabled/disabled labels

### Checkbox Field

For boolean checkbox inputs with optional help text and disabled state.

```swift
.checkbox(FormFieldCheckbox(
    id: "acceptTerms",
    label: "Accept Terms and Conditions",
    isChecked: termsAccepted,
    isVisible: true,
    isSelected: selectedFieldId == "acceptTerms",
    isDisabled: false,
    helpText: "You must accept the terms to continue"
))
```

**Features:**

- SPACE to toggle checked state
- Optional help text displayed below
- Can be disabled to prevent interaction
- Visual checkbox indicator [X] / [ ]
- Grayed out styling when disabled

### Select Field

For selecting from a small set of enum-like options.

```swift
.select(FormFieldSelect(
    id: "bootSource",
    label: "Boot Source",
    options: [
        FormSelectOption(id: "image", title: "Image", description: "Boot from image"),
        FormSelectOption(id: "volume", title: "Volume", description: "Boot from volume"),
        FormSelectOption(id: "snapshot", title: "Snapshot", description: "Boot from snapshot")
    ],
    selectedOptionId: selectedBootSource,
    isRequired: true,
    isVisible: true,
    isSelected: selectedFieldId == "bootSource",
    isActive: isSelecting
))
```

**Interaction:**

- SPACE to activate selection mode
- SPACE to cycle through options
- ENTER to confirm selection

### Selector Field

For selecting a single item from a large list with search and columns.

```swift
.selector(FormFieldSelector(
    id: "image",
    label: "Image",
    items: images,
    selectedItemId: selectedImageId,
    isRequired: true,
    isVisible: bootSource == "image",
    isSelected: selectedFieldId == "image",
    isActive: isSelectingImage,
    columns: [
        FormSelectorItemColumn(header: "Name", width: 30) { item in
            (item as? Image)?.name ?? "Unknown"
        },
        FormSelectorItemColumn(header: "Size", width: 10) { item in
            "\((item as? Image)?.minDisk ?? 0)GB"
        }
    ],
    searchQuery: searchQuery,
    highlightedIndex: highlightedIndex,
    scrollOffset: scrollOffset
))
```

**Features:**

- Multi-column display
- Search/filter support
- Scrolling with indicators
- Single selection

### Multi-Select Field

For selecting multiple items from a list.

```swift
.multiSelect(FormFieldMultiSelect(
    id: "networks",
    label: "Networks",
    items: networks,
    selectedItemIds: selectedNetworkIds,
    isRequired: true,
    isVisible: true,
    isSelected: selectedFieldId == "networks",
    isActive: isSelectingNetworks,
    columns: [
        FormSelectorItemColumn(header: "Name", width: 30) { item in
            (item as? Network)?.name ?? "Unknown"
        },
        FormSelectorItemColumn(header: "Status", width: 10) { item in
            (item as? Network)?.adminStateUp == true ? "UP" : "DOWN"
        }
    ],
    minSelections: 1,
    maxSelections: 5
))
```

**Interaction:**

- SPACE to toggle item selection
- Multiple items can be selected
- Selection count displayed
- Optional min/max constraints

### Info Field

For read-only informational display.

```swift
.info(FormFieldInfo(
    id: "serverStatus",
    label: "Current Status",
    value: "ACTIVE",
    isVisible: true,
    style: .success
))
```

**Use Cases:**

- Display current state
- Show calculated values
- Provide context information

### Custom Field

For completely custom field implementations.

```swift
.custom(FormFieldCustom(
    id: "customWidget",
    label: "Custom Widget",
    isVisible: true,
    render: {
        // Return any Component
        HStack(spacing: 0, children: [
            Text("Custom: ").accent(),
            Text(customValue).primary()
        ])
    }
))
```

## Advanced Usage

### Conditional Field Visibility

```swift
// Show image field only when boot source is "image"
.selector(FormFieldSelector(
    id: "image",
    label: "Image",
    items: images,
    isVisible: bootSource == "image",  // Conditional visibility
    isRequired: bootSource == "image"
))
```

### Custom Validation

```swift
// Add validation errors to fields
var validationError: String?
if volumeSize.isEmpty {
    validationError = "Size is required"
} else if Int(volumeSize) ?? 0 < 1 {
    validationError = "Size must be at least 1GB"
}

.number(FormFieldNumber(
    id: "volumeSize",
    label: "Volume Size",
    value: volumeSize,
    validationError: validationError
))
```

### Making Items Searchable

Implement the `FormSelectorItem` protocol:

```swift
extension Image: FormSelectorItem {
    var id: String { self.id }

    func matchesSearch(_ query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return name?.lowercased().contains(lowercasedQuery) ?? false
    }
}
```

### FormSelectorRenderer - Type-Specific Rendering

The **FormSelectorRenderer** is a helper that works around Swift's generic limitations when dealing with existential types. It allows FormBuilder to render selectors for specific OpenStack resource types without losing type information.

**Why it exists:**

When FormBuilder stores items as `[any FormSelectorItem]`, Swift can't infer the concrete type needed for FormSelector's generic type parameter. FormSelectorRenderer solves this by attempting to cast to known types and rendering the appropriate typed selector.

**Supported Types:**

- `Image` - OS images and snapshots
- `Volume` - Cinder volumes
- `Flavor` - Nova flavors
- `Network` - Neutron networks (single and multi-select)
- `SecurityGroup` - Security groups (single and multi-select)
- `KeyPair` - SSH key pairs
- `ServerGroup` - Server groups
- `PortType` - Port types
- `AvailabilityZoneItem` - Availability zones
- All SecurityGroup enums (Direction, Protocol, EtherType, PortType, RemoteType)
- Barbican enums (wrapped types)

**Usage Example:**

```swift
// In FormBuilderState when rendering a selector overlay
if let selectorState = formState.getSelectorState(fieldId),
   let field = formState.getCurrentField() {
    if case .selector(let selectorField) = field {
        // Use FormSelectorRenderer to render the typed selector
        if let component = FormSelectorRenderer.renderSelector(
            label: selectorField.label,
            items: selectorField.items,
            selectedItemId: selectorState.selectedItemId,
            highlightedIndex: selectorState.highlightedIndex,
            scrollOffset: selectorState.scrollOffset,
            searchQuery: selectorState.searchQuery,
            columns: selectorField.columns,
            maxHeight: maxHeight
        ) {
            // Render the typed selector component
            await SwiftNCurses.render(component, on: surface, in: bounds)
        }
    }
}
```

**Adding Support for New Types:**

To add support for a new OpenStack resource type:

1. Make your type conform to `FormSelectorItem`:

```swift
extension MyResource: FormSelectorItem {
    var id: String { self.id }

    func matchesSearch(_ query: String) -> Bool {
        return name?.lowercased().contains(query.lowercased()) ?? false
    }
}
```

2. Add a renderer method in FormSelectorRenderer:

```swift
private static func renderMyResourceSelector(
    label: String,
    items: [MyResource],
    selectedItemId: String?,
    highlightedIndex: Int,
    scrollOffset: Int,
    searchQuery: String?,
    columns: [FormSelectorItemColumn],
    maxHeight: Int?
) -> any Component {
    let selectorColumns = columns.map { column in
        FormSelectorColumn<MyResource>(
            header: column.header,
            width: column.width,
            getValue: { column.getValue($0) }
        )
    }

    let tab = FormSelectorTab<MyResource>(
        title: label,
        columns: selectorColumns
    )

    let selector = FormSelector<MyResource>(
        label: label,
        tabs: [tab],
        selectedTabIndex: 0,
        items: items,
        selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
        highlightedIndex: highlightedIndex,
        multiSelect: false,
        scrollOffset: scrollOffset,
        searchQuery: searchQuery,
        maxHeight: maxHeight,
        isActive: true
    )

    return selector.render()
}
```

3. Add type check in the main `renderSelector` method:

```swift
if let myResources = items as? [MyResource] {
    return renderMyResourceSelector(
        label: label,
        items: myResources,
        selectedItemId: selectedItemId,
        highlightedIndex: highlightedIndex,
        scrollOffset: scrollOffset,
        searchQuery: searchQuery,
        columns: columns,
        maxHeight: maxHeight
    )
}
```

## Migration Guide

### Converting Existing Forms

**Before (Old Pattern):**

```swift
// Scattered field creation in ServerCreateView
private static func createServerNameField(form: ServerCreateForm,
                                         isSelected: Bool) -> any Component {
    let indicator = isSelected ? "> " : "  "
    return VStack(spacing: 0, children: [
        Text("Server Name: *").accent().bold(),
        HStack(spacing: 0, children: [
            Text(indicator).styled(isSelected ? .accent : .secondary),
            Text(form.serverName.isEmpty ? "[Empty]" : form.serverName).primary()
        ])
    ])
}
```

**After (FormBuilder):**

```swift
// Clean, declarative field definition
.text(FormFieldText(
    id: "serverName",
    label: "Server Name",
    value: form.serverName,
    isRequired: true,
    isSelected: selectedFieldId == "serverName"
))
```

### State Management Migration

**Before:**

```swift
var serverName: String = ""
var fieldEditMode: Bool = false
var currentField: ServerCreateField = .name
```

**After:**

```swift
var formState = FormBuilderState(fields: fields)
// All state managed in formState
```

## Best Practices

1. **Use unique field IDs**: Ensure each field has a unique identifier
2. **Keep field definitions close to data**: Define fields near the data they represent
3. **Leverage conditional visibility**: Use `isVisible` for dynamic forms
4. **Validate early**: Set `validationError` as soon as validation fails
5. **Use appropriate field types**: Choose the right field type for the data
6. **Provide clear labels**: Use descriptive, user-friendly field labels
7. **Set sensible defaults**: Provide reasonable default values
8. **Use `isRequired` consistently**: Mark required fields appropriately

## Complete Example

See `ServerCreateFormExample.swift` for a complete working example of a complex form with:

- Multiple field types
- Conditional visibility
- Validation
- State management
- User interaction handling

## Troubleshooting

### Field not showing

- Check `isVisible` property
- Verify field is in the `fields` array

### Field not interactive

- Ensure `isSelected` matches current field
- Check that state management is updating `selectedFieldId`

### Validation not displaying

- Set `showValidationErrors: true` in FormBuilder
- Ensure `validationErrors` array is populated
- Check individual field `validationError` properties

### Search not working in selector

- Verify items implement `FormSelectorItem` protocol
- Check `matchesSearch()` implementation
- Ensure `searchQuery` is being updated in state

## API Reference

See the inline documentation in:

- [FormBuilder.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormBuilder.swift)
- [FormBuilderState.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormBuilderState.swift)

## Related Components

- [FormTextField](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormTextField.swift) - Used internally for text/number fields
- [FormSelector](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormSelector.swift) - Used internally for selector fields
- [FormSelectorRenderer](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormSelectorRenderer.swift) - Type-specific selector rendering helper
- [FormRenderer](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Utilities/FormRenderer.swift) - Original form protocol definitions
