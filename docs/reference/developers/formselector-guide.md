# FormSelector Component Guide

## Overview

**FormSelector** is a powerful selection component for choosing items from large lists with multi-column display, search/filter capabilities, and support for both single and multi-select modes. It's used extensively for selecting resources like networks, images, flavors, and security groups.

Selecting from thousands of resources without search is user torture. FormSelector handles search, scrolling, multi-column display, and multi-select so your users don't quit in frustration.

## Location

- **Component:** [Sources/Substation/Components/FormSelector.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormSelector.swift)
- **Usage:** All forms that require resource selection from lists

## Features

- [x] **Multi-column display** with headers
- [x] **Search/filter** by typing to narrow results
- [x] **Single and multi-select** modes
- [x] **Scrolling** with scroll indicators
- [x] **Checkbox indicators** for selection state
- [x] **Tab support** for multiple selection modes
- [x] **Keyboard navigation** (UP/DOWN, SPACE, ENTER)
- [x] **Empty state handling**
- [x] **Real-time filtering**

## Basic Usage

### 1. Single-Select Selector (Images, Networks, Flavors)

```swift
// Make your type conform to FormSelectableItem
extension Image: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        let lowercased = query.lowercased()
        return (name?.lowercased().contains(lowercased) ?? false) ||
               (id.lowercased().contains(lowercased))
    }
}

// Create selector
let imageSelector = FormSelector<Image>(
    label: "Select Image",
    tabs: [
        FormSelectorTab(
            title: "Images",
            columns: [
                FormSelectorColumn(header: "Name", width: 30) { $0.name ?? "Unnamed" },
                FormSelectorColumn(header: "Size", width: 10) { "\($0.minDisk ?? 0)GB" },
                FormSelectorColumn(header: "Status", width: 10) { $0.status ?? "unknown" }
            ]
        )
    ],
    items: images,
    selectedItemIds: selectedImageId.map { [$0] } ?? [],
    highlightedIndex: highlightedIndex,
    multiSelect: false,
    isActive: isSelectingImage
)

// Render
let component = imageSelector.render()
```

### 2. Multi-Select Selector (Security Groups, Networks)

```swift
extension SecurityGroup: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        return name?.lowercased().contains(query.lowercased()) ?? false
    }
}

let securityGroupSelector = FormSelector<SecurityGroup>(
    label: "Select Security Groups",
    tabs: [
        FormSelectorTab(
            title: "Security Groups",
            columns: [
                FormSelectorColumn(header: "Name", width: 30) { $0.name ?? "Unknown" },
                FormSelectorColumn(header: "Description", width: 40) { $0.description ?? "" }
            ]
        )
    ],
    items: securityGroups,
    selectedItemIds: selectedSecurityGroupIds,
    highlightedIndex: highlightedIndex,
    multiSelect: true,  // Multi-select mode
    isActive: isSelecting
)
```

### 3. Multi-Tab Selector

```swift
// Example: Select source with different tabs for images vs volumes
let bootSourceSelector = FormSelector<BootSourceItem>(
    label: "Select Source",
    tabs: [
        FormSelectorTab(
            title: "Images",
            columns: [
                FormSelectorColumn(header: "Name", width: 30) { $0.name },
                FormSelectorColumn(header: "Size", width: 10) { $0.sizeDisplay }
            ]
        ),
        FormSelectorTab(
            title: "Volumes",
            columns: [
                FormSelectorColumn(header: "Name", width: 30) { $0.name },
                FormSelectorColumn(header: "Size", width: 10) { $0.sizeDisplay },
                FormSelectorColumn(header: "Bootable", width: 10) { $0.bootable ? "Yes" : "No" }
            ]
        )
    ],
    selectedTabIndex: selectedTabIndex,
    items: currentTabItems,
    selectedItemIds: selectedItemIds,
    highlightedIndex: highlightedIndex,
    multiSelect: false
)
```

## State Management

### Using FormSelectorState

The **FormSelectorState** struct manages selection state, navigation, and search.

```swift
// 1. Initialize state
var selectorState = FormSelectorState<Image>(
    items: images,
    multiSelect: false
)

// 2. Navigate items
selectorState.moveUp()    // UP arrow
selectorState.moveDown()  // DOWN arrow

// 3. Toggle selection
selectorState.toggleSelection()  // SPACE key

// 4. Search/filter
selectorState.appendToSearch("ubuntu")  // Type 'u', 'b', 'u', etc.
selectorState.removeLastSearchCharacter()  // BACKSPACE

// 5. Switch tabs (if multi-tab)
selectorState.nextTab(tabCount: 2)

// 6. Get selected items
let selected = selectorState.selectedItems  // [Image]
let hasSelection = selectorState.hasSelection  // Bool

// 7. Query filtered items
let filtered = selectorState.getFilteredItems()
```

### Integration with Forms

```swift
struct ServerCreateForm {
    var images: [Image] = []
    var selectedImageId: String?
    var isSelectingImage: Bool = false

    var imageSelectorState: FormSelectorState<Image>

    init() {
        self.imageSelectorState = FormSelectorState<Image>(
            items: [],
            multiSelect: false
        )
    }

    mutating func updateImages(_ newImages: [Image]) {
        self.images = newImages
        imageSelectorState.items = newImages
    }

    mutating func activateImageSelector() {
        isSelectingImage = true
    }

    mutating func confirmImageSelection() {
        if let selected = imageSelectorState.selectedItems.first {
            selectedImageId = selected.id
        }
        isSelectingImage = false
    }

    mutating func cancelImageSelection() {
        imageSelectorState.clearSelection()
        isSelectingImage = false
    }
}
```

## Properties

### FormSelector

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Selector title |
| `tabs` | `[FormSelectorTab]` | Tab configurations |
| `selectedTabIndex` | `Int` | Currently active tab |
| `items` | `[Item]` | Items to display |
| `selectedItemIds` | `Set<String>` | Selected item IDs |
| `highlightedIndex` | `Int` | Currently highlighted item |
| `multiSelect` | `Bool` | Enable multi-selection |
| `scrollOffset` | `Int` | Scroll position |
| `searchQuery` | `String?` | Current search filter |
| `maxWidth` | `Int?` | Maximum display width |
| `maxHeight` | `Int?` | Maximum display height |
| `isActive` | `Bool` | Selector is active |
| `validationError` | `String?` | Validation error message |

### FormSelectorTab

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | Tab name |
| `columns` | `[FormSelectorColumn]` | Column definitions |
| `description` | `String?` | Optional tab description |

### FormSelectorColumn

| Property | Type | Description |
|----------|------|-------------|
| `header` | `String` | Column header text |
| `width` | `Int` | Column width in characters |
| `getValue` | `(Item) -> String` | Extract column value from item |

### FormSelectableItem Protocol

```swift
protocol FormSelectableItem {
    var id: String { get }
    var sortKey: String { get }
    func matchesSearch(_ query: String) -> Bool
}
```

## Keyboard Interactions

### Navigation

- **UP ARROW** - Move selection up
- **DOWN ARROW** - Move selection down
- **TAB** - Switch between tabs (if multi-tab)

### Selection

- **SPACE** - Toggle selection (multi-select) or select item (single-select)
- **ENTER** - Confirm selection and close
- **ESC** - Cancel and close

### Search/Filter

- **Type characters** - Filter items by search query
- **BACKSPACE** - Remove last search character

## Visual Layout

### Single-Select Mode

```
Select Image

Browse and select item. SPACE: select, ENTER: confirm
[ ] Name                           Size       Status
--------------------------------------------------------
[ ] Ubuntu 22.04 LTS              10GB       active
[X] Debian 12                     8GB        active
[ ] CentOS Stream 9               12GB       active
[ ] Rocky Linux 9                 10GB       active

(1-4 of 12) Use UP/DOWN to scroll

SPACE:select ENTER:confirm ESC:cancel
```

### Multi-Select Mode

```
Select Security Groups

Browse and select items. SPACE: toggle, ENTER: confirm
[ ] Name                           Description
--------------------------------------------------------
[X] default                        Default security group
[X] web-servers                    HTTP/HTTPS access
[ ] ssh-access                     SSH access only
[ ] database                       Database ports

(1-4 of 8) Use UP/DOWN to scroll
[2] web-servers, default

SPACE:select ENTER:confirm ESC:cancel
```

### Multi-Tab Mode

```
Select Source

Mode: [Images] (TAB to switch)
Browse and select item. SPACE: select, ENTER: confirm
[ ] Name                           Size       Status
--------------------------------------------------------
[ ] Ubuntu 22.04 LTS              10GB       active
[X] Debian 12                     8GB        active

TAB:switch SPACE:select ENTER:confirm ESC:cancel
```

### With Search Active

```
Select Image

Browse and select item. SPACE: select, ENTER: confirm
Search: ubuntu_
[ ] Name                           Size       Status
--------------------------------------------------------
[ ] Ubuntu 22.04 LTS              10GB       active
[ ] Ubuntu 20.04 LTS              8GB        active

(1-2 of 2)

SPACE:select ENTER:confirm ESC:cancel
```

## Advanced Features

### 1. Custom Column Formatting

```swift
FormSelectorColumn(header: "Size", width: 12) { image in
    if let size = image.minDisk {
        return "\(size)GB"
    } else {
        return "Unknown"
    }
}

FormSelectorColumn(header: "Status", width: 10) { image in
    switch image.status {
    case "active": return "[OK]"
    case "saving": return "[SAVE]"
    case "error": return "[ERR]"
    default: return image.status ?? "???"
    }
}
```

### 2. Conditional Columns

```swift
let columns: [FormSelectorColumn<Network>]
if showDetailedView {
    columns = [
        FormSelectorColumn(header: "Name", width: 25) { $0.name ?? "Unknown" },
        FormSelectorColumn(header: "Status", width: 10) { $0.adminStateUp ? "UP" : "DOWN" },
        FormSelectorColumn(header: "External", width: 10) { $0.external ? "Yes" : "No" },
        FormSelectorColumn(header: "Subnets", width: 10) { "\($0.subnets?.count ?? 0)" }
    ]
} else {
    columns = [
        FormSelectorColumn(header: "Name", width: 40) { $0.name ?? "Unknown" },
        FormSelectorColumn(header: "Status", width: 10) { $0.adminStateUp ? "UP" : "DOWN" }
    ]
}
```

### 3. Search Implementation

```swift
extension Flavor: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        let lowercased = query.lowercased()

        // Search by name
        if name?.lowercased().contains(lowercased) == true {
            return true
        }

        // Search by specs
        let vcpuMatch = "\(vcpus)".contains(lowercased)
        let ramMatch = "\(ram)".contains(lowercased)

        return vcpuMatch || ramMatch
    }
}
```

### 4. Scroll Management

The FormSelector automatically handles scrolling:

```swift
// FormSelectorState internally manages scroll offset
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
```

### 5. Tab Switching

```swift
// Define multiple tabs for different item types
let tabs = [
    FormSelectorTab<BootSource>(
        title: "Images",
        columns: imageColumns,
        description: "Boot from an image"
    ),
    FormSelectorTab<BootSource>(
        title: "Volumes",
        columns: volumeColumns,
        description: "Boot from a bootable volume"
    ),
    FormSelectorTab<BootSource>(
        title: "Snapshots",
        columns: snapshotColumns,
        description: "Boot from a volume snapshot"
    )
]

// Handle tab switching in state
selectorState.nextTab(tabCount: tabs.count)
```

## Common Patterns

### 1. Network Selection

```swift
extension Network: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        return name?.lowercased().contains(query.lowercased()) ?? false
    }
}

let networkSelector = FormSelector<Network>(
    label: "Select Network",
    tabs: [
        FormSelectorTab(
            title: "Networks",
            columns: [
                FormSelectorColumn(header: "Name", width: 30) { $0.name ?? "Unknown" },
                FormSelectorColumn(header: "Status", width: 10) {
                    $0.adminStateUp == true ? "UP" : "DOWN"
                },
                FormSelectorColumn(header: "External", width: 10) {
                    $0.external == true ? "Ext" : ""
                }
            ]
        )
    ],
    items: networks,
    selectedItemIds: selectedNetworkId.map { [$0] } ?? [],
    highlightedIndex: 0,
    multiSelect: false
)
```

### 2. Flavor Selection

```swift
extension Flavor: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        let lowercased = query.lowercased()
        return (name?.lowercased().contains(lowercased) ?? false) ||
               "\(vcpus)".contains(lowercased) ||
               "\(ram)".contains(lowercased)
    }
}

let flavorSelector = FormSelector<Flavor>(
    label: "Select Flavor",
    tabs: [
        FormSelectorTab(
            title: "Flavors",
            columns: [
                FormSelectorColumn(header: "Name", width: 25) { $0.name ?? "Unknown" },
                FormSelectorColumn(header: "vCPUs", width: 8) { "\($0.vcpus)" },
                FormSelectorColumn(header: "RAM", width: 12) { "\($0.ram)MB" },
                FormSelectorColumn(header: "Disk", width: 10) { "\($0.disk)GB" }
            ]
        )
    ],
    items: flavors,
    selectedItemIds: selectedFlavorId.map { [$0] } ?? [],
    highlightedIndex: 0,
    multiSelect: false
)
```

### 3. Security Group Multi-Select

```swift
extension SecurityGroup: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        return (name?.lowercased().contains(query.lowercased()) ?? false) ||
               (description?.lowercased().contains(query.lowercased()) ?? false)
    }
}

let secGroupSelector = FormSelector<SecurityGroup>(
    label: "Select Security Groups",
    tabs: [
        FormSelectorTab(
            title: "Security Groups",
            columns: [
                FormSelectorColumn(header: "Name", width: 30) { $0.name ?? "Unknown" },
                FormSelectorColumn(header: "Rules", width: 10) {
                    "\($0.securityGroupRules?.count ?? 0)"
                }
            ]
        )
    ],
    items: securityGroups,
    selectedItemIds: selectedSecurityGroupIds,
    highlightedIndex: 0,
    multiSelect: true,  // Multi-select enabled
    maxHeight: 15
)
```

## Complete Example

### Server Create Form - Image Selection

```swift
// 1. Define Image as FormSelectableItem
extension Image: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        let lowercased = query.lowercased()
        return (name?.lowercased().contains(lowercased) ?? false) ||
               (id.lowercased().contains(lowercased))
    }
}

// 2. Add selector state to form
struct ServerCreateForm {
    var images: [Image] = []
    var selectedImageId: String?
    var isSelectingImage: Bool = false
    var imageSelectorState: FormSelectorState<Image>

    init() {
        self.imageSelectorState = FormSelectorState<Image>(
            items: [],
            multiSelect: false
        )
    }

    mutating func updateImages(_ newImages: [Image]) {
        self.images = newImages
        imageSelectorState.items = newImages
    }
}

// 3. Render selector in view
static func drawImageSelector(screen: OpaquePointer?, form: ServerCreateForm,
                              width: Int32, height: Int32) async {
    let selector = FormSelector<Image>(
        label: "Select Image",
        tabs: [
            FormSelectorTab(
                title: "Images",
                columns: [
                    FormSelectorColumn(header: "Name", width: 35) {
                        $0.name ?? "Unnamed"
                    },
                    FormSelectorColumn(header: "Size", width: 10) {
                        "\($0.minDisk ?? 0)GB"
                    },
                    FormSelectorColumn(header: "Status", width: 10) {
                        $0.status ?? "unknown"
                    }
                ]
            )
        ],
        items: form.images,
        selectedItemIds: form.selectedImageId.map { [$0] } ?? [],
        highlightedIndex: form.imageSelectorState.highlightedIndex,
        multiSelect: false,
        scrollOffset: form.imageSelectorState.scrollOffset,
        searchQuery: form.imageSelectorState.searchQuery,
        maxWidth: Int(width),
        maxHeight: Int(height) - 5,
        isActive: form.isSelectingImage
    )

    let surface = SwiftNCurses.surface(from: screen)
    let bounds = Rect(x: 0, y: 0, width: width, height: height)
    await SwiftNCurses.render(selector.render(), on: surface, in: bounds)
}

// 4. Handle input
func handleImageSelectorInput(_ keyCode: Int32, form: inout ServerCreateForm) {
    switch keyCode {
    case Int32(259):  // UP
        form.imageSelectorState.moveUp()
    case Int32(258):  // DOWN
        form.imageSelectorState.moveDown()
    case Int32(32):   // SPACE
        form.imageSelectorState.toggleSelection()
    case Int32(10):   // ENTER
        if let selected = form.imageSelectorState.selectedItems.first {
            form.selectedImageId = selected.id
        }
        form.isSelectingImage = false
    case Int32(27):   // ESC
        form.isSelectingImage = false
    case Int32(127), Int32(8):  // BACKSPACE
        form.imageSelectorState.removeLastSearchCharacter()
    default:
        // Handle character input for search
        if let scalar = UnicodeScalar(Int(keyCode)), isPrintable(scalar) {
            form.imageSelectorState.appendToSearch(Character(scalar))
        }
    }
}
```

## Best Practices

### 1. Always Implement FormSelectableItem

```swift
// [x] Good - proper protocol conformance
extension Network: FormSelectableItem {
    var id: String { self.id }
    var sortKey: String { name ?? "Unknown" }

    func matchesSearch(_ query: String) -> Bool {
        return name?.lowercased().contains(query.lowercased()) ?? false
    }
}

// [ ] Bad - missing protocol conformance
// Will not compile
```

### 2. Use Descriptive Column Headers

```swift
// [x] Good - clear headers
FormSelectorColumn(header: "Name", width: 30)
FormSelectorColumn(header: "vCPUs", width: 8)
FormSelectorColumn(header: "RAM (MB)", width: 12)

// [ ] Bad - vague headers
FormSelectorColumn(header: "Data", width: 30)
FormSelectorColumn(header: "Info", width: 20)
```

### 3. Set Appropriate Column Widths

```swift
// [x] Good - balanced widths
FormSelectorColumn(header: "Name", width: 30)      // Main identifier
FormSelectorColumn(header: "Status", width: 10)    // Short status
FormSelectorColumn(header: "Description", width: 40)  // Longer text

// [ ] Bad - imbalanced
FormSelectorColumn(header: "Name", width: 10)      // Too narrow
FormSelectorColumn(header: "Status", width: 40)    // Too wide for status
```

### 4. Handle Empty States

```swift
if items.isEmpty {
    // Show helpful message
    return Text("No images available. Please check your connection.")
        .error()
}
```

### 5. Implement Comprehensive Search

```swift
func matchesSearch(_ query: String) -> Bool {
    let lowercased = query.lowercased()

    // Search multiple fields
    return (name?.lowercased().contains(lowercased) ?? false) ||
           (id.lowercased().contains(lowercased)) ||
           (description?.lowercased().contains(lowercased) ?? false) ||
           (tags?.joined(separator: " ").lowercased().contains(lowercased) ?? false)
}
```

## Troubleshooting

### Items not displaying

- Check `items` array is not empty
- Verify `FormSelectableItem` conformance
- Ensure `getValue` in columns returns valid strings

### Search not working

- Implement `matchesSearch()` properly
- Check search query is being updated
- Verify `searchQuery` is passed to FormSelector

### Selection not working

- Check `multiSelect` matches your use case
- Verify `toggleSelection()` is called on SPACE
- Ensure `selectedItemIds` is updated

### Scroll not working

- FormSelector handles scrolling automatically
- Check `maxHeight` is set appropriately
- Verify UP/DOWN keys are handled

## Related Components

- **[FormTextField](formtextfield-guide.md)** - For text input fields
- **[FormBuilder](formbuilder-guide.md)** - Uses FormSelector internally
- **[FormRenderer](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Utilities/FormRenderer.swift)** - Form protocol definitions

## Examples in Codebase

See these files for real-world usage:

- [ServerCreateView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Views/ServerCreateView.swift) - Image, flavor, network selection
- [SubnetCreateForm.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/ViewModels/SubnetCreateForm.swift) - Network selection
- [PortCreateForm.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/ViewModels/PortCreateForm.swift) - Network and security group multi-select
- [FormSelector.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/FormSelector.swift) - Component implementation
