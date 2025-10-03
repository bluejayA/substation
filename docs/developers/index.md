# Developer Documentation

## Welcome to the Substation Developer Guide

**Translation**: You're about to build forms. Let's make sure they don't suck.

## The Real Talk

You're here because you need to create a form in Substation. Maybe it's a network creation form. Maybe it's server deployment. Maybe it's that weird edge case your PM just threw at you at 4:30 PM on Friday.

**Good news**: We've already solved the hard parts. You just need to assemble the pieces.

**Better news**: The components are actually well-designed, documented, and battle-tested.

**Best news**: You won't need to reinvent text field editing for the 47th time.

## The Three Sacred Components

### 1. FormBuilder - The Brain

**What it does**: Creates complete forms with validation, navigation, and state management.

**When to use it**: Every single time you need a form. No exceptions. Don't be clever.

**Read this**: [FormBuilder Guide](formbuilder-guide.md)

```swift
// This is literally all you need for a basic form
let form = FormBuilder(
    title: "Create Network",
    fields: [
        .text(FormFieldText(id: "name", label: "Network Name", value: name, isRequired: true)),
        .int(FormFieldNumber(id: "mtu", label: "MTU", value: mtu, minValue: 68, maxValue: 9000)),
        .bool(FormFieldToggle(id: "portSec", label: "Port Security", value: enabled))
    ]
)
```

**Why it's good**: Handles navigation, validation, state management, and rendering. You write 10 lines instead of 500.

### 2. FormTextField - The Workhorse

**What it does**: Text input with cursor, history, validation, and all the keyboard shortcuts users expect.

**When to use it**: Any time you need string input. Names, IPs, CIDRs, descriptions, UUIDs you're never going to remember.

**Read this**: [FormTextField Guide](formtextfield-guide.md)

```swift
let textField = FormTextField(
    label: "Server Name",
    value: serverName,
    placeholder: "my-server-01",
    isRequired: true,
    isSelected: true,
    isActive: isEditing,
    validationError: nameError
)
```

**Why it's good**:

- Cursor works correctly (yes, this is harder than you think)
- History with UP/DOWN arrows (your users will love this)
- Validation shows inline (users see errors immediately)
- Handles HOME/END/LEFT/RIGHT like they expect

**Horror story**: Before FormTextField, we had 6 different text input implementations. All slightly broken in different ways. All reinventing the wheel. Don't go back to that dark timeline.

### 3. FormSelector - The Power User

**What it does**: Select from large lists (images, networks, flavors) with search, multi-column display, and scrolling.

**When to use it**: Selecting resources. Any resource. Images, networks, flavors, security groups, availability zones.

**Read this**: [FormSelector Guide](formselector-guide.md)

```swift
let selector = FormSelector<Image>(
    label: "Select Image",
    tabs: [FormSelectorTab(
        title: "Images",
        columns: [
            FormSelectorColumn(header: "Name", width: 30) { $0.name ?? "Unknown" },
            FormSelectorColumn(header: "Size", width: 10) { "\($0.minDisk ?? 0)GB" }
        ]
    )],
    items: images,
    multiSelect: false,
    isActive: isSelecting
)
```

**Why it's good**:

- Search actually works (type to filter)
- Multi-column display (users can see multiple attributes)
- Handles 10,000+ items without choking
- Multi-select for things like security groups

## Quick Start: Create Your First Form in 5 Minutes

**Scenario**: You need a network creation form. Name, MTU, port security. Let's go.

### Step 1: Define Your Form Model

```swift
struct NetworkCreateForm {
    var networkName: String = ""
    var mtu: String = "1500"
    var portSecurityEnabled: Bool = true
    var currentFieldId: String = "name"

    // State management
    var nameFieldState = FormTextFieldState(initialValue: "")
    var mtuFieldState = FormTextFieldState(initialValue: "1500")
}
```

### Step 2: Build Your Fields

```swift
let fields: [FormField] = [
    .text(FormFieldText(
        id: "name",
        label: "Network Name",
        value: form.networkName,
        isRequired: true,
        isSelected: form.currentFieldId == "name",
        isActive: form.isEditingName
    )),

    .int(FormFieldNumber(
        id: "mtu",
        label: "MTU",
        value: form.mtu,
        minValue: 68,
        maxValue: 9000,
        unit: "bytes",
        isRequired: true,
        isSelected: form.currentFieldId == "mtu"
    )),

    .bool(FormFieldToggle(
        id: "portSecurity",
        label: "Port Security",
        value: form.portSecurityEnabled,
        isSelected: form.currentFieldId == "portSecurity"
    ))
]
```

### Step 3: Create and Render

```swift
let formBuilder = FormBuilder(
    title: "Create Network",
    fields: fields,
    selectedFieldId: form.currentFieldId,
    validationErrors: form.validate()
)

// Render it
await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)
```

### Step 4: Handle Input

```swift
switch keyCode {
case Int32(9):  // TAB
    form.nextField()

case Int32(32):  // SPACE
    if form.currentFieldId == "name" {
        form.nameFieldState.activate()
    }

case Int32(10):  // ENTER
    if form.isEditingName {
        form.networkName = form.nameFieldState.value
        form.nameFieldState.confirm()
    } else {
        // Submit the form
        await createNetwork(form)
    }
}
```

**Done.** You have a functional form with validation, navigation, and state management.

## Field Types: When to Use What

| Need This | Use This | Example |
|-----------|----------|---------|
| Server name | `.text` | String input, 1-255 chars |
| MTU value | `.number` | Number with range (68-9000) |
| Port security | `.toggle` | Enable/disable toggle |
| Accept terms | `.checkbox` | Checkbox with help text |
| IP version | `.select` | IPv4 vs IPv6 |
| Select image | `.selector` | Pick from 1000s of images |
| Security groups | `.multiSelect` | Pick multiple |
| Current status | `.info` | Read-only display |
| Something weird | `.custom` | Build your own |

## Common Patterns

### Pattern 1: Text Input with Validation

```swift
// Validate name
var nameError: String?
if networkName.isEmpty {
    nameError = "Network name is required"
} else if networkName.count > 255 {
    nameError = "Name must be 255 characters or less"
}

// Create field with error
.text(FormFieldText(
    id: "name",
    label: "Network Name",
    value: networkName,
    isRequired: true,
    validationError: nameError
))
```

### Pattern 2: Conditional Fields

```swift
// Only show external network if gateway is enabled
let fields: [FormField] = [
    .bool(FormFieldToggle(id: "gateway", label: "External Gateway", value: gatewayEnabled)),

    .selector(FormFieldSelector(
        id: "extNet",
        label: "External Network",
        items: networks,
        isVisible: gatewayEnabled,  // Only show if gateway enabled
        isRequired: gatewayEnabled
    ))
]
```

### Pattern 3: Resource Selection with Search

```swift
// Make your resource searchable
extension Image: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        let q = query.lowercased()
        return (name?.lowercased().contains(q) ?? false) ||
               id.lowercased().contains(q)
    }
}

// Create selector
.selector(FormFieldSelector(
    id: "image",
    label: "Select Image",
    items: images,
    columns: [
        FormSelectorColumn(header: "Name", width: 30) { $0.name ?? "Unknown" },
        FormSelectorColumn(header: "Size", width: 10) { "\($0.minDisk ?? 0)GB" }
    ]
))
```

## Best Practices (Learn From Our Mistakes)

### ✅ DO: Use FormBuilder for Everything

**Why**: Consistency. One API. One behavior. Users learn once, use everywhere.

**Bad**: Custom form rendering with hand-rolled navigation and validation.

**Good**: `FormBuilder(title: "Create Thing", fields: fields)`

### ✅ DO: Validate Early

**Why**: Users want immediate feedback. Waiting until submit is 1990s web form behavior.

```swift
// Good - validate as they type
mutating func handleNameInput(_ char: Character) {
    nameFieldState.handleCharacterInput(char)
    validateName()  // Immediate feedback
}

// Bad - validate on submit only
func submit() {
    if validateAll() {  // User just wasted 2 minutes filling invalid data
        // ...
    }
}
```

### ✅ DO: Provide Clear Error Messages

**Good**: "Network name must be between 1 and 255 characters"

**Bad**: "Invalid input"

**Worse**: "Error code: NET_NAME_ERR_001"

### ✅ DO: Make Resources Searchable

**Why**: Users will have 1000+ images. Scrolling is death.

```swift
// Good - search name, ID, tags
func matchesSearch(_ query: String) -> Bool {
    let q = query.lowercased()
    return (name?.lowercased().contains(q) ?? false) ||
           id.lowercased().contains(q) ||
           (tags?.joined().lowercased().contains(q) ?? false)
}

// Bad - only search name
func matchesSearch(_ query: String) -> Bool {
    return name?.contains(query) ?? false
}
```

### ❌ DON'T: Reinvent Components

**Why**: We already solved cursor movement, history, validation, scrolling, search. Don't rebuild them badly.

**Bad**: Writing your own text input with cursor tracking.

**Good**: Using `FormTextField` which already handles this correctly.

### ❌ DON'T: Skip State Management

**Why**: FormTextFieldState and FormSelectorState handle edge cases you haven't thought of.

**Bad**: Tracking cursor position manually with an Int variable.

**Good**: Using `FormTextFieldState` which handles cursor, history, editing state, cancellation.

### ❌ DON'T: Hardcode Dimensions

**Bad**: `maxWidth: 50` everywhere

**Good**: Use consistent constants

```swift
// Define once
private static let nameFieldWidth = 50
private static let descriptionFieldWidth = 80
private static let idFieldWidth = 20
```

## Troubleshooting (You'll Hit These)

### "My field isn't accepting input!"

**Check**:

1. Is `isActive` true?
2. Is `isSelected` true?
3. Are you calling `handleCharacterInput()`?
4. Is your event loop actually calling your input handler?

**Fix**: Set both `isSelected: true` and `isActive: true` when editing.

### "Search doesn't work!"

**Check**:

1. Does your type implement `FormSelectableItem`?
2. Is `matchesSearch()` actually implemented?
3. Are you updating `searchQuery` in the selector state?

**Fix**: Implement the protocol correctly. See the guide.

### "Validation errors don't show!"

**Check**:

1. Is `validationError` set on the field?
2. Is `showValidationErrors: true` on FormBuilder?
3. Is your validation function actually running?

**Fix**: Set `validationError` on the field AND `showValidationErrors` on the builder.

### "My selector shows nothing!"

**Check**:

1. Is `items` array empty?
2. Did you forget to set `isVisible: true`?
3. Did your search filter everything out?

**Fix**: Debug your data flow. Items need to exist and be visible.

## Examples in the Wild

**Simple forms**:

- [NetworkCreateForm.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/ViewModels/NetworkCreateForm.swift) - Name, MTU, port security
- [RouterCreateForm.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/ViewModels/RouterCreateForm.swift) - Name, gateway, conditional fields

**Complex forms**:

- [ServerCreateView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Views/ServerCreateView.swift) - Images, flavors, networks, security groups
- [SubnetCreateForm.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/ViewModels/SubnetCreateForm.swift) - IP validation, CIDR, allocation pools

## Component Source Code

**Study these when the docs aren't enough**:

- [FormBuilder.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormBuilder.swift) - Main form builder
- [FormBuilderState.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormBuilderState.swift) - State management
- [FormTextField.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormTextField.swift) - Text input component
- [FormSelector.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormSelector.swift) - Selection component
- [FormSelectorRenderer.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormSelectorRenderer.swift) - Type-specific selector rendering

## Questions?

1. **Read the component guides first** - They have detailed examples
2. **Look at existing forms** - Copy patterns that work
3. **Check the source** - It's well-commented
4. **Ask in PR** - We're here to help

## Remember

Building forms doesn't have to be painful. Use the components. Follow the patterns. Ship features instead of debugging cursor position at 2 AM.

**Now go build something.**
