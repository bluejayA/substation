# Developer Documentation

Welcome to the Substation Developer Guide.

**Translation**: You're about to build forms. Let's make sure they don't suck.

## The Real Talk

You're here because you need to create a form in Substation. Maybe it's a network creation form. Maybe it's server deployment. Maybe it's that weird edge case your PM just threw at you at 4:30 PM on Friday.

**Good news**: We've already solved the hard parts. You just need to assemble the pieces.

**Better news**: The components are actually well-designed, documented, and battle-tested.

**Best news**: You won't need to reinvent text field editing for the 47th time.

## Documentation Overview

### [FormBuilder Guide](formbuilder-guide.md)

**What it does**: Creates complete forms with validation, navigation, and state management.

**When to use it**: Every single time you need a form. No exceptions. Don't be clever.

**Read this first** - FormBuilder is the brain of your forms. It handles:

- Form layout and rendering
- Field navigation (Tab, Shift-Tab, arrow keys)
- Validation and error display
- State management
- Submission handling

### [FormTextField Guide](formtextfield-guide.md)

**What it does**: Text input with cursor, history, validation, and all the keyboard shortcuts users expect.

**When to use it**: Any time you need string input. Names, IPs, CIDRs, descriptions, UUIDs.

**Read this** when you need:

- Text input fields
- Proper cursor handling
- Input history (UP/DOWN arrows)
- Inline validation
- Home/End/Left/Right navigation

### [FormSelector Guide](formselector-guide.md)

**What it does**: Select from large lists (images, networks, flavors) with search, multi-column display, and scrolling.

**When to use it**: Selecting resources. Any resource. Images, networks, flavors, security groups, availability zones.

**Read this** when you need:

- Resource selection from large lists
- Multi-column display
- Search/filter functionality
- Multi-select capability
- Handling 10,000+ items

### [StatusListView Guide](statuslistview-guide.md)

**What it does**: Renders primary resource lists with StatusIcon indicators and multi-column display.

**When to use it**: Building primary list views for resources (servers, volumes, networks, images).

**Read this** when you need:

- Primary resource list views
- StatusIcon + text columns
- Automatic filtering and scrolling
- Consistent list rendering
- 80-90% code reduction

### [DetailView Guide](detailview-guide.md)

**What it does**: Renders detailed information screens with section-based layouts and scrollable content.

**When to use it**: Building detail screens for resources (server details, volume details, network details).

**Read this** when you need:

- Detail screens with consistent formatting
- Section-based information organization
- Automatic field label and value formatting
- Scrolling for large content
- 70-85% code reduction

### [Testing Guide](testing.md)

**What it does**: Comprehensive guide to running tests, writing tests, and understanding the testing infrastructure.

**When to use it**: Before contributing code, after making changes, when adding new features.

**Read this** when you need:

- Run the test suite
- Write new tests
- Understand test coverage
- Debug failing tests
- Set up CI/CD

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
await SwiftNCurses.render(formBuilder.render(), on: surface, in: bounds)
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

## Field Types Reference

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

**Detailed field documentation**: See component guides for comprehensive field type documentation and examples.

## Best Practices

### Use FormBuilder for Everything

**Why**: Consistency. One API. One behavior. Users learn once, use everywhere.

**Bad**: Custom form rendering with hand-rolled navigation and validation.

**Good**: `FormBuilder(title: "Create Thing", fields: fields)`

### Validate Early

**Why**: Users want immediate feedback. Waiting until submit is 1990s web form behavior.

```swift
// Good - validate as they type
mutating func handleNameInput(_ char: Character) {
    nameFieldState.handleCharacterInput(char)
    validateName()  // Immediate feedback
}
```

### Provide Clear Error Messages

**Good**: "Network name must be between 1 and 255 characters"

**Bad**: "Invalid input"

**Worse**: "Error code: NET_NAME_ERR_001"

### Make Resources Searchable

**Why**: Users will have 1000+ images. Scrolling is death.

```swift
// Good - search name, ID, tags
func matchesSearch(_ query: String) -> Bool {
    let q = query.lowercased()
    return (name?.lowercased().contains(q) ?? false) ||
           id.lowercased().contains(q) ||
           (tags?.joined().lowercased().contains(q) ?? false)
}
```

### Don't Reinvent Components

**Why**: We already solved cursor movement, history, validation, scrolling, search. Don't rebuild them badly.

**Bad**: Writing your own text input with cursor tracking.

**Good**: Using `FormTextField` which already handles this correctly.

## Component Source Code

**Study these when the guides aren't enough**:

- `/Sources/Substation/Components/FormBuilder.swift` - Main form builder
- `/Sources/Substation/Components/FormBuilderState.swift` - State management
- `/Sources/Substation/Components/FormTextField.swift` - Text input component
- `/Sources/Substation/Components/FormSelector.swift` - Selection component
- `/Sources/Substation/Components/FormSelectorRenderer.swift` - Type-specific selector rendering
- `/Sources/Substation/Components/StatusListView.swift` - Primary list view component

## Example Forms in the Codebase

**Simple forms**:

- `/Sources/Substation/Modules/Networks/Models/NetworkCreateForm.swift` - Name, MTU, port security
- `/Sources/Substation/Modules/Routers/Models/RouterCreateForm.swift` - Name, gateway, conditional fields

**Complex forms**:

- `/Sources/Substation/Modules/Servers/Views/ServerCreateView.swift` - Images, flavors, networks, security groups
- `/Sources/Substation/Modules/Subnets/Models/SubnetCreateForm.swift` - IP validation, CIDR, allocation pools

## Troubleshooting

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

## Related Documentation

- **[API Reference](../../reference/api/index.md)** - Complete API documentation for OSClient, SwiftNCurses, CrossPlatformTimer
- **[Architecture Overview](../../architecture/index.md)** - Overall system architecture
- **[Performance Documentation](../../performance/index.md)** - Benchmarking and optimization

## Questions?

1. **Read the component guides first** - They have detailed examples
2. **Look at existing forms** - Copy patterns that work
3. **Check the source** - It's well-commented
4. **Ask in PR** - We're here to help

---

**Remember**: Building forms doesn't have to be painful. Use the components. Follow the patterns. Ship features instead of debugging cursor position at 2 AM.

**Now go build something.**
