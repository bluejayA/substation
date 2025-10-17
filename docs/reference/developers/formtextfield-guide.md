# FormTextField Component Guide

## Overview

**FormTextField** is a unified text input component that provides consistent text editing behavior across all forms in Substation. It includes built-in cursor management, input history, validation display, and keyboard navigation.

## Location

- **Component:** [Sources/Substation/Components/FormTextField.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormTextField.swift)
- **Usage:** All create/edit forms that require text input

## Features

- ✅ **Visual cursor** with position tracking
- ✅ **Input history** (UP/DOWN arrows to browse previous values)
- ✅ **Full cursor movement** (LEFT/RIGHT, HOME/END)
- ✅ **Character editing** (INSERT, DELETE, BACKSPACE)
- ✅ **Validation display** with inline error messages
- ✅ **State indicators** (selected, active, error states)
- ✅ **Max width/length** constraints
- ✅ **Placeholder support** with activation hints

## Basic Usage

### 1. Simple Text Field

```swift
let textField = FormTextField(
    label: "Server Name",
    value: serverName,
    placeholder: "Press SPACE to edit",
    isRequired: true,
    isSelected: currentField == .name,
    isActive: isEditingName,
    maxWidth: 50
)

// Render the field
let component = textField.render()
```

### 2. Text Field with Validation

```swift
// Perform validation
var nameError: String? = nil
if serverName.isEmpty {
    nameError = "Server name is required"
} else if serverName.count > 255 {
    nameError = "Server name must be 255 characters or less"
}

let textField = FormTextField(
    label: "Server Name",
    value: serverName,
    placeholder: "Enter server name",
    isRequired: true,
    isSelected: currentField == .name,
    isActive: isEditingName,
    maxWidth: 50,
    validationError: nameError
)
```

### 3. Optional Text Field

```swift
let descriptionField = FormTextField(
    label: "Description",
    value: description,
    placeholder: "Enter optional description",
    isRequired: false,  // Optional field
    isSelected: currentField == .description,
    isActive: isEditingDescription,
    maxWidth: 80
)
```

## State Management

### Using FormTextFieldState

The **FormTextFieldState** struct manages the internal state of text editing, including cursor position, history, and edit mode.

```swift
// 1. Initialize state
var nameFieldState = FormTextFieldState(initialValue: "")

// 2. Activate editing (user presses SPACE)
nameFieldState.activate()

// 3. Handle character input
for char in "my-server".characters {
    nameFieldState.handleCharacterInput(char)
}

// 4. Handle special keys
nameFieldState.handleSpecialKey(Int32(260))  // LEFT arrow

// 5. Confirm changes (user presses ENTER)
nameFieldState.confirm()

// 6. Or cancel (user presses ESC)
nameFieldState.cancel()

// 7. Get the value
let finalValue = nameFieldState.value
```

### Integration with Forms

```swift
struct NetworkCreateForm {
    var networkName: String = ""
    var nameFieldState: FormTextFieldState = FormTextFieldState(initialValue: "")
    var currentField: NetworkCreateField = .name
    var isEditingName: Bool = false

    mutating func activateNameField() {
        isEditingName = true
        nameFieldState.activate()
    }

    mutating func confirmNameField() {
        networkName = nameFieldState.value
        isEditingName = false
        nameFieldState.confirm()
    }

    mutating func cancelNameField() {
        nameFieldState.cancel()
        isEditingName = false
    }
}
```

## Properties

### FormTextField

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Field label (e.g., "Server Name") |
| `value` | `String` | Current field value |
| `placeholder` | `String` | Placeholder text when empty |
| `isRequired` | `Bool` | Show required indicator (*) |
| `isSelected` | `Bool` | Field is currently selected |
| `isActive` | `Bool` | Field is in edit mode |
| `maxWidth` | `Int?` | Maximum display width (truncates with ...) |
| `validationError` | `String?` | Error message to display |
| `cursorPosition` | `Int?` | Cursor position when active |

### FormTextFieldState

| Property | Type | Description |
|----------|------|-------------|
| `value` | `String` | Current input value |
| `isEditing` | `Bool` | Currently in edit mode |
| `originalValue` | `String` | Value before editing (for cancel) |
| `cursorPosition` | `Int` | Current cursor position (0-based) |
| `history` | `[String]` | Previous input values (max 50) |
| `historyIndex` | `Int?` | Current position in history |

## Keyboard Interactions

### Edit Mode Activation

- **SPACE** - Activate field for editing

### Cursor Movement

- **LEFT ARROW** - Move cursor left
- **RIGHT ARROW** - Move cursor right
- **HOME** - Move cursor to start
- **END** - Move cursor to end

### Editing

- **Characters** - Insert at cursor position
- **BACKSPACE** - Delete character before cursor
- **DELETE** - Delete character at cursor

### History Navigation

- **UP ARROW** - Previous value in history
- **DOWN ARROW** - Next value in history

### Completion

- **ENTER** - Confirm changes and exit edit mode
- **ESC** - Cancel changes and revert

## Visual States

### 1. Not Selected (Default)

```
Server Name: *
  my-server
```

- Gray text for value
- No selection indicator

### 2. Selected (Not Editing)

```
Server Name: *
> my-server (SPACE to edit)
```

- Yellow warning color
- Selection indicator `>`
- Activation hint

### 3. Active (Editing)

```
Server Name: *
> my-ser_ver
```

- White/bright text
- Visible cursor `_` at position
- Cursor shown as block over character

### 4. Validation Error

```
Server Name: *
> my-server
  ! Server name must be 255 characters or less
```

- Red error color
- Error message with `!` prefix
- Error shown below field

## Advanced Features

### 1. Cursor Position Display

When editing, the cursor is shown in two ways:

**At end of text:**

```
my-server_
```

**In middle of text:**

```
my-[s]erver
```

The character at cursor position is shown in brackets.

### 2. Input History

The component maintains a history of up to 50 previous values:

```swift
// First input
nameFieldState.value = "server-1"
nameFieldState.confirm()  // Added to history

// Second input
nameFieldState.value = "server-2"
nameFieldState.confirm()  // Added to history

// Later, browse history
nameFieldState.activate()
nameFieldState.handleSpecialKey(Int32(259))  // UP - shows "server-2"
nameFieldState.handleSpecialKey(Int32(259))  // UP - shows "server-1"
nameFieldState.handleSpecialKey(Int32(258))  // DOWN - shows "server-2"
```

### 3. Word Movement (Advanced)

FormTextFieldState includes word-level navigation:

```swift
// Move to previous word
nameFieldState.moveCursorToPreviousWord()

// Move to next word
nameFieldState.moveCursorToNextWord()

// Delete word before cursor (Ctrl+W behavior)
nameFieldState.deleteWordBeforeCursor()

// Delete from cursor to end (Ctrl+K behavior)
nameFieldState.deleteToEndOfLine()
```

### 4. Truncation

Long values are truncated with ellipsis when `maxWidth` is set:

```swift
let textField = FormTextField(
    label: "Name",
    value: "very-long-server-name-that-exceeds-width",
    maxWidth: 20  // Truncates to "very-long-server-..."
)
```

## Validation Patterns

### Common Validators

```swift
// Required field
var error: String?
if value.isEmpty {
    error = "This field is required"
}

// Length validation
if value.count > maxLength {
    error = "Must be \(maxLength) characters or less"
}

// Character set validation
let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
if value.rangeOfCharacter(from: allowed.inverted) != nil {
    error = "Only letters, numbers, hyphens, and underscores allowed"
}

// Format validation (CIDR)
if !value.matches(pattern: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$"#) {
    error = "Must be in CIDR format (e.g., 192.168.1.0/24)"
}
```

### Using InputValidator

Substation includes a centralized `InputValidator` for common patterns:

```swift
import Foundation

// Name validation
let nameErrors = InputValidator.validateNameField(serverName, maxLength: 255)
let nameError = nameErrors.first

// Description validation
let descErrors = InputValidator.validateDescriptionField(description, maxLength: 1024)

// CIDR validation
let cidrErrors = InputValidator.validateCIDR(cidrValue)

// Numeric validation
let mtuErrors = InputValidator.validateNumericInput(mtu, min: 68, max: 9000)
```

## Complete Example

### Network Create Form

```swift
struct NetworkCreateView {
    static func drawForm(screen: OpaquePointer?, form: NetworkCreateForm) async {
        let surface = SwiftNCurses.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text("Create Network").emphasis().bold())

        // Name field
        let nameField = FormTextField(
            label: "Network Name",
            value: form.networkName,
            placeholder: "Enter network name",
            isRequired: true,
            isSelected: form.currentField == .name,
            isActive: form.isEditingName,
            maxWidth: 50,
            validationError: form.getNameValidationError(),
            cursorPosition: form.nameFieldState.cursorPosition
        )
        components.append(nameField.render())

        // Description field
        let descField = FormTextField(
            label: "Description",
            value: form.networkDescription,
            placeholder: "Enter optional description",
            isRequired: false,
            isSelected: form.currentField == .description,
            isActive: form.isEditingDescription,
            maxWidth: 80,
            cursorPosition: form.descFieldState.cursorPosition
        )
        components.append(descField.render())

        // Render all
        let formComponent = VStack(spacing: 0, children: components)
        await SwiftNCurses.render(formComponent, on: surface, in: bounds)
    }
}
```

### Input Handling

```swift
// In main input loop
switch keyCode {
case Int32(32):  // SPACE
    if !form.isEditingName {
        form.activateNameField()
    }

case Int32(10):  // ENTER
    if form.isEditingName {
        form.confirmNameField()
    }

case Int32(27):  // ESC
    if form.isEditingName {
        form.cancelNameField()
    }

default:
    if form.isEditingName {
        // Check for special keys first
        let handled = form.nameFieldState.handleSpecialKey(keyCode)

        // If not a special key, handle as character input
        if !handled, let scalar = UnicodeScalar(Int(keyCode)) {
            let char = Character(scalar)
            form.nameFieldState.handleCharacterInput(char)
        }
    }
}
```

## Best Practices

### 1. Always Use State Management

```swift
// ✅ Good - uses FormTextFieldState
var nameFieldState = FormTextFieldState(initialValue: "")

// ❌ Bad - manual state tracking is error-prone
var nameValue: String = ""
var nameCursor: Int = 0
var nameHistory: [String] = []
```

### 2. Validate on Field Change

```swift
// Validate after each change
mutating func handleNameInput(_ char: Character) {
    nameFieldState.handleCharacterInput(char)
    validateNameField()  // Immediate validation
}
```

### 3. Use Consistent Max Widths

```swift
// Names
maxWidth: 50

// Descriptions
maxWidth: 80

// Short codes/IDs
maxWidth: 20

// IP addresses
maxWidth: 30
```

### 4. Provide Clear Placeholders

```swift
// ✅ Good - descriptive
placeholder: "Enter network name (e.g., public-network)"

// ❌ Bad - vague
placeholder: "Name"
```

### 5. Handle Empty State

```swift
// Always trim whitespace before validation
let trimmedName = nameFieldState.value.trimmingCharacters(in: .whitespacesAndNewlines)

if trimmedName.isEmpty && isRequired {
    validationError = "This field is required"
}
```

## Troubleshooting

### Field not accepting input

- Check `isActive` is true
- Verify `handleCharacterInput()` is being called
- Ensure field is selected (`isSelected: true`)

### Cursor not visible

- Check `isActive` is true
- Verify `cursorPosition` is set
- Ensure render is called after cursor updates

### Validation not showing

- Set `validationError` property
- Check error message is not empty
- Verify render is called after validation

### History not working

- Ensure `confirm()` is called after edits
- Check history isn't cleared accidentally
- Verify UP/DOWN keys are handled

## Related Components

- **[FormBuilder](formbuilder-guide.md)** - Uses FormTextField internally
- **[FormSelector](formselector-guide.md)** - For selecting from lists
- **[FormRenderer](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Utilities/FormRenderer.swift)** - Form protocol definitions
- **[InputValidator](https://github.com/cloudnull/substation/blob/main/Sources/Substation/InputValidator.swift)** - Centralized validation

## Examples in Codebase

See these files for real-world usage:

- [NetworkCreateForm.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/ViewModels/NetworkCreateForm.swift)
- [SubnetCreateForm.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/ViewModels/SubnetCreateForm.swift)
- [RouterCreateForm.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/ViewModels/RouterCreateForm.swift)
- [ServerCreateView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Views/ServerCreateView.swift)
