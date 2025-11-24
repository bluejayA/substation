# DetailView Component Guide

## Overview

**DetailView** is a reusable component for rendering detailed information screens with section-based layouts and scrollable content. It standardizes how detailed resource information is displayed, providing consistent formatting for field labels, values, and hierarchical organization.

## Location

- **Component:** [Sources/Substation/Components/DetailView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/DetailView.swift)
- **Usage:** Detail screens for all resource types (server details, volume details, network details, etc.)

## Features

- Section-based hierarchical organization
- Automatic field label and value formatting
- Scrolling support for large content
- Defensive bounds checking
- Customizable text styles per section
- Nil-safe convenience builders
- Custom component support for complex layouts
- Consistent padding and spacing

## When to Use

**Use DetailView when**:

- Displaying detailed resource information
- Need consistent section-based layout
- Want automatic field formatting (label: value)
- Building detail screens for resources
- Need scrolling for long content

**Don't use DetailView when**:

- Building forms (use FormBuilder)
- Building lists (use StatusListView)
- Building complex custom layouts (use raw SwiftNCurses components)

## Basic Usage

### Step 1: Build Sections with Detail Items

```swift
// Create basic information section
let basicInfoSection = DetailSection(
    title: "Basic Information",
    items: [
        .field(label: "ID", value: server.id, style: .secondary),
        .field(label: "Name", value: server.name ?? "Unnamed", style: .secondary),
        .field(label: "Status", value: server.status?.rawValue ?? "Unknown", style: .secondary)
    ]
)

// Create hardware information section
let hardwareSection = DetailSection(
    title: "Hardware Information",
    items: [
        .field(label: "Flavor ID", value: flavor.id, style: .secondary),
        .field(label: "Flavor Name", value: flavor.name ?? "Unknown", style: .secondary),
        .field(label: "vCPUs", value: String(flavor.vcpus), style: .secondary),
        .field(label: "RAM", value: "\(flavor.ram) MB", style: .secondary)
    ]
)
```

### Step 2: Create and Render DetailView

```swift
let detailView = DetailView(
    title: "Server Details: \(server.name ?? "Unnamed")",
    sections: [basicInfoSection, hardwareSection],
    helpText: "Press ESC to return to server list",
    scrollOffset: currentScrollOffset
)

await detailView.draw(
    screen: screen,
    startRow: startRow,
    startCol: startCol,
    width: width,
    height: height
)
```

## DetailItem Types

### Field Item

Standard label-value pair with optional styling:

```swift
.field(label: "Network Name", value: "my-network", style: .secondary)
.field(label: "Status", value: "ACTIVE", style: .success)
.field(label: "Error", value: "Connection failed", style: .error)
```

### Custom Component

For complex layouts requiring SwiftNCurses components:

```swift
.customComponent(
    HStack(spacing: 0, children: [
        Text("Status: ").secondary(),
        StatusIcon.server(status: server.status?.rawValue),
        Text(" \(server.status?.rawValue ?? "Unknown")")
            .styled(TextStyle.forStatus(server.status?.rawValue))
    ])
)
```

### Spacer

Empty line for visual separation:

```swift
.spacer
```

## Convenience Builders

### Nil-Safe String Fields

```swift
// Only creates field if value exists and is not empty
DetailView.buildFieldItem(label: "Name", value: server.name)
DetailView.buildFieldItem(label: "Host ID", value: server.hostId, defaultValue: "N/A")
```

### Integer Fields with Suffix

```swift
// Only creates field if value exists
DetailView.buildFieldItem(label: "Size", value: volume.size, suffix: " GB")
DetailView.buildFieldItem(label: "vCPUs", value: flavor.vcpus)
```

### Double Fields with Formatting

```swift
DetailView.buildFieldItem(
    label: "Size",
    value: image.size,
    format: "%.2f",
    suffix: " GB"
)
```

### CustomStringConvertible Fields (Dates, etc.)

```swift
DetailView.buildFieldItem(label: "Created", value: server.createdAt)
DetailView.buildFieldItem(label: "Updated", value: server.updatedAt)
```

### Section Builder

```swift
// Only creates section if it has items (nil values are filtered out)
if let section = DetailView.buildSection(
    title: "Timestamps",
    items: [
        DetailView.buildFieldItem(label: "Created", value: server.createdAt),
        DetailView.buildFieldItem(label: "Updated", value: server.updatedAt),
        DetailView.buildFieldItem(label: "Launched", value: server.launchedAt)
    ]
) {
    sections.append(section)
}
```

## Real-World Examples

### Simple Detail View (Flavor Details)

```swift
func drawFlavorDetail(
    screen: OpaquePointer?,
    startRow: Int32,
    startCol: Int32,
    width: Int32,
    height: Int32,
    flavor: Flavor,
    scrollOffset: Int = 0
) async {
    var sections: [DetailSection] = []

    // Basic information
    var basicItems: [DetailItem?] = [
        DetailView.buildFieldItem(label: "ID", value: flavor.id),
        DetailView.buildFieldItem(label: "Name", value: flavor.name),
        DetailView.buildFieldItem(label: "vCPUs", value: flavor.vcpus),
        DetailView.buildFieldItem(label: "RAM", value: flavor.ram, suffix: " MB"),
        DetailView.buildFieldItem(label: "Disk", value: flavor.disk, suffix: " GB")
    ]

    if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
        sections.append(basicSection)
    }

    let detailView = DetailView(
        title: "Flavor Details",
        sections: sections,
        helpText: "Press ESC to return",
        scrollOffset: scrollOffset
    )

    await detailView.draw(
        screen: screen,
        startRow: startRow,
        startCol: startCol,
        width: width,
        height: height
    )
}
```

### Complex Detail View with Custom Components (Server Details)

```swift
func drawServerDetail(
    screen: OpaquePointer?,
    startRow: Int32,
    startCol: Int32,
    width: Int32,
    height: Int32,
    server: Server,
    cachedVolumes: [Volume],
    scrollOffset: Int = 0
) async {
    var sections: [DetailSection] = []

    // Basic Information with custom status component
    var basicItems: [DetailItem] = []
    basicItems.append(.field(label: "ID", value: server.id, style: .secondary))
    basicItems.append(.field(label: "Name", value: server.name ?? "Unnamed", style: .secondary))

    // Custom component for status with icon
    basicItems.append(.customComponent(
        HStack(spacing: 0, children: [
            Text("  Status: ").secondary(),
            StatusIcon.server(status: server.status?.rawValue),
            Text(" \(server.status?.rawValue ?? "Unknown")")
                .styled(TextStyle.forStatus(server.status?.rawValue))
        ])
    ))

    if let taskState = server.taskState {
        basicItems.append(.field(label: "Task State", value: taskState, style: .secondary))
    }

    sections.append(DetailSection(title: "Basic Information", items: basicItems))

    // Network Information with nested items
    if let addresses = server.addresses, !addresses.isEmpty {
        var networkItems: [DetailItem] = []
        for (networkName, addressList) in addresses {
            networkItems.append(.field(label: "Network", value: networkName, style: .secondary))
            for address in addressList {
                let version = address.version == 4 ? "IPv4" : "IPv6"
                networkItems.append(.field(label: "  \(version)", value: address.addr, style: .info))
            }
        }
        sections.append(DetailSection(title: "Network Information", items: networkItems))
    }

    // Storage Information
    let attachedVolumes = cachedVolumes.filter {
        $0.attachments?.contains { $0.serverId == server.id } ?? false
    }

    if !attachedVolumes.isEmpty {
        var storageItems: [DetailItem] = []
        for volume in attachedVolumes {
            storageItems.append(.field(
                label: "Volume Name",
                value: volume.name ?? "Unnamed",
                style: .secondary
            ))
            storageItems.append(.field(
                label: "Size",
                value: "\(volume.size ?? 0) GB",
                style: .secondary
            ))
            storageItems.append(.customComponent(
                HStack(spacing: 0, children: [
                    Text("  Status: ").secondary(),
                    Text(volume.status ?? "Unknown")
                        .styled(TextStyle.forStatus(volume.status))
                ])
            ))
            storageItems.append(.spacer) // Separator between volumes
        }
        sections.append(DetailSection(title: "Storage Information", items: storageItems))
    }

    // Timestamps using convenience builders
    if let timestampSection = DetailView.buildSection(
        title: "Timestamps",
        items: [
            DetailView.buildFieldItem(label: "Created", value: server.createdAt),
            DetailView.buildFieldItem(label: "Updated", value: server.updatedAt),
            DetailView.buildFieldItem(label: "Launched", value: server.launchedAt)
        ]
    ) {
        sections.append(timestampSection)
    }

    // Fault information with error styling
    if let fault = server.fault {
        let faultSection = DetailSection(
            title: "Fault Information",
            items: [
                .field(label: "Code", value: String(fault.code), style: .error),
                .field(label: "Message", value: fault.message, style: .error),
                DetailView.buildFieldItem(label: "Created", value: fault.created) ?? .spacer
            ],
            titleStyle: .error
        )
        sections.append(faultSection)
    }

    let detailView = DetailView(
        title: "Server Details: \(server.name ?? "Unnamed")",
        sections: sections,
        helpText: "Press ESC to return to server list",
        scrollOffset: scrollOffset
    )

    await detailView.draw(
        screen: screen,
        startRow: startRow,
        startCol: startCol,
        width: width,
        height: height
    )
}
```

### Detail View with Metadata (Key-Value Pairs)

```swift
// Display server metadata
if let metadata = server.metadata, !metadata.isEmpty {
    var metadataItems: [DetailItem] = []
    for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
        metadataItems.append(.field(label: key, value: value, style: .secondary))
    }
    sections.append(DetailSection(title: "Metadata", items: metadataItems))
}
```

## Section Styling

Sections can have different title styles to convey importance or state:

```swift
// Normal section (default)
DetailSection(title: "Basic Information", items: items, titleStyle: .primary)

// Important section
DetailSection(title: "Configuration", items: items, titleStyle: .accent)

// Error/fault section
DetailSection(title: "Fault Information", items: items, titleStyle: .error)

// Warning section
DetailSection(title: "Deprecation Notice", items: items, titleStyle: .warning)

// Informational section
DetailSection(title: "Help", items: items, titleStyle: .info)
```

## Scrolling

DetailView automatically handles scrolling for large content:

```swift
// In your view state
var scrollOffset: Int = 0

// Handle scroll input
func handleScroll(direction: ScrollDirection) {
    switch direction {
    case .up:
        scrollOffset = max(0, scrollOffset - 1)
    case .down:
        scrollOffset += 1
    }
}

// Render with current scroll offset
let detailView = DetailView(
    title: "Details",
    sections: sections,
    scrollOffset: scrollOffset
)
```

## Best Practices

### Use Convenience Builders for Optional Fields

```swift
// Good - nil-safe, compact, readable
var items: [DetailItem?] = [
    DetailView.buildFieldItem(label: "Name", value: resource.name),
    DetailView.buildFieldItem(label: "Size", value: resource.size, suffix: " GB"),
    DetailView.buildFieldItem(label: "Created", value: resource.createdAt)
]

if let section = DetailView.buildSection(title: "Info", items: items) {
    sections.append(section)
}

// Bad - manual nil checking, verbose, error-prone
var items: [DetailItem] = []
if let name = resource.name {
    items.append(.field(label: "Name", value: name, style: .secondary))
}
if let size = resource.size {
    items.append(.field(label: "Size", value: "\(size) GB", style: .secondary))
}
// ... repetitive code
```

### Group Related Information in Sections

```swift
// Good - logical grouping
sections.append(DetailSection(title: "Basic Information", items: basicItems))
sections.append(DetailSection(title: "Network Information", items: networkItems))
sections.append(DetailSection(title: "Storage Information", items: storageItems))

// Bad - everything in one giant section
sections.append(DetailSection(title: "Details", items: allItems))
```

### Use Custom Components for Complex Layouts

```swift
// Good - custom component for status with icon
.customComponent(
    HStack(spacing: 0, children: [
        Text("Status: ").secondary(),
        StatusIcon.server(status: server.status?.rawValue),
        Text(" \(server.status?.rawValue ?? "Unknown")")
            .styled(TextStyle.forStatus(server.status?.rawValue))
    ])
)

// Bad - trying to fit complex layout into simple field
.field(label: "Status", value: server.status?.rawValue ?? "Unknown", style: .secondary)
// Lost the status icon!
```

### Use Spacers for Visual Separation

```swift
// Good - spacer between volume entries
for volume in attachedVolumes {
    items.append(.field(label: "Name", value: volume.name ?? "Unnamed", style: .secondary))
    items.append(.field(label: "Size", value: "\(volume.size ?? 0) GB", style: .secondary))
    items.append(.spacer) // Visual separation
}

// Bad - no separation makes it hard to read
for volume in attachedVolumes {
    items.append(.field(label: "Name", value: volume.name ?? "Unnamed", style: .secondary))
    items.append(.field(label: "Size", value: "\(volume.size ?? 0) GB", style: .secondary))
}
```

### Use Appropriate Text Styles

```swift
// Good - styles convey meaning
.field(label: "Status", value: "ACTIVE", style: .success)
.field(label: "Error", value: "Connection failed", style: .error)
.field(label: "Building", value: "In progress", style: .warning)
.field(label: "IP Address", value: "10.0.0.1", style: .info)

// Bad - everything is secondary
.field(label: "Status", value: "ACTIVE", style: .secondary)
.field(label: "Error", value: "Connection failed", style: .secondary)
```

## Migration from Manual Rendering

### Before (Manual Rendering in ServerViews.swift)

```swift
var components: [any Component] = []

// Title
components.append(Text("Server Details: \(server.name ?? "Unnamed")").accent().bold()
    .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

// Basic Information
components.append(Text("Basic Information").primary().bold())

var basicInfo: [any Component] = []
basicInfo.append(Text("  ID: \(server.id)").secondary())
basicInfo.append(Text("  Name: \(server.name ?? "Unnamed")").secondary())
basicInfo.append(HStack(spacing: 0, children: [
    Text("  Status: ").secondary(),
    StatusIcon.server(status: server.status?.rawValue),
    Text(" \(server.status?.rawValue ?? "Unknown")")
        .styled(TextStyle.forStatus(server.status?.rawValue))
]))

let basicInfoSection = VStack(spacing: 0, children: basicInfo)
    .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
components.append(basicInfoSection)

// ... 200+ more lines of manual component building

let detailComponent = VStack(spacing: 0, children: components)
let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
await SwiftNCurses.render(detailComponent, on: surface, in: bounds)
```

### After (Using DetailView)

```swift
var sections: [DetailSection] = []

// Basic Information
var basicItems: [DetailItem] = [
    .field(label: "ID", value: server.id, style: .secondary),
    .field(label: "Name", value: server.name ?? "Unnamed", style: .secondary),
    .customComponent(
        HStack(spacing: 0, children: [
            Text("  Status: ").secondary(),
            StatusIcon.server(status: server.status?.rawValue),
            Text(" \(server.status?.rawValue ?? "Unknown")")
                .styled(TextStyle.forStatus(server.status?.rawValue))
        ])
    )
]
sections.append(DetailSection(title: "Basic Information", items: basicItems))

// ... build other sections similarly

let detailView = DetailView(
    title: "Server Details: \(server.name ?? "Unnamed")",
    sections: sections,
    helpText: "Press ESC to return",
    scrollOffset: scrollOffset
)

await detailView.draw(
    screen: screen,
    startRow: startRow,
    startCol: startCol,
    width: width,
    height: height
)
```

**Result**: Reduced from ~300 lines to ~50 lines (83% reduction), with clearer intent and easier maintenance.

## Common Patterns

### Pattern 1: Simple Resource Details

```swift
var sections: [DetailSection] = []

if let basicSection = DetailView.buildSection(
    title: "Basic Information",
    items: [
        DetailView.buildFieldItem(label: "ID", value: resource.id),
        DetailView.buildFieldItem(label: "Name", value: resource.name),
        DetailView.buildFieldItem(label: "Status", value: resource.status)
    ]
) {
    sections.append(basicSection)
}

let detailView = DetailView(
    title: "Resource Details",
    sections: sections,
    helpText: "Press ESC to return"
)
```

### Pattern 2: Details with Nested Information

```swift
// Network with subnets
var networkItems: [DetailItem] = []
for subnet in network.subnets {
    networkItems.append(.field(label: "Subnet", value: subnet.cidr, style: .secondary))
    networkItems.append(.field(label: "  Gateway", value: subnet.gatewayIp ?? "None", style: .info))
    networkItems.append(.field(label: "  DHCP", value: subnet.enableDhcp ? "Enabled" : "Disabled", style: .info))
    networkItems.append(.spacer)
}
sections.append(DetailSection(title: "Subnets", items: networkItems))
```

### Pattern 3: Details with Conditional Sections

```swift
// Only show fault section if fault exists
if let fault = server.fault {
    let faultSection = DetailSection(
        title: "Fault Information",
        items: [
            .field(label: "Code", value: String(fault.code), style: .error),
            .field(label: "Message", value: fault.message, style: .error)
        ],
        titleStyle: .error
    )
    sections.append(faultSection)
}
```

### Pattern 4: Details with Formatted Values

```swift
// Format bytes to GB
if let sizeBytes = image.size {
    let sizeGB = Double(sizeBytes) / 1_073_741_824
    items.append(
        DetailView.buildFieldItem(label: "Size", value: sizeGB, format: "%.2f", suffix: " GB")
    )
}

// Format dates
if let created = server.createdAt {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    items.append(.field(
        label: "Created",
        value: formatter.string(from: created),
        style: .secondary
    ))
}
```

## Troubleshooting

### Issue: Fields not showing

**Check**: Are you using convenience builders with nil values?

```swift
// This won't show if value is nil
DetailView.buildFieldItem(label: "Name", value: optionalValue)

// To always show a field
.field(label: "Name", value: optionalValue ?? "N/A", style: .secondary)
```

### Issue: Section not appearing

**Check**: Does the section have any items?

```swift
// buildSection returns nil if no valid items
if let section = DetailView.buildSection(title: "Info", items: allNilItems) {
    // This won't execute if all items are nil
    sections.append(section)
}

// To always show a section
sections.append(DetailSection(
    title: "Info",
    items: [.field(label: "Status", value: "No data", style: .muted)]
))
```

### Issue: Scroll not working

**Check**: Are you incrementing/decrementing scrollOffset?

```swift
// Correct scroll handling
func handleScroll(direction: ScrollDirection) {
    switch direction {
    case .up:
        scrollOffset = max(0, scrollOffset - 1)
    case .down:
        scrollOffset += 1  // DetailView handles max internally
    }
}
```

### Issue: Custom component not rendering

**Check**: Is the component valid SwiftNCurses syntax?

```swift
// Good - valid HStack
.customComponent(
    HStack(spacing: 0, children: [
        Text("Hello"),
        Text(" World")
    ])
)

// Bad - invalid component
.customComponent(Text("Hello") + Text("World"))  // Can't concatenate Text
```

## Performance Considerations

1. **Section Building**: Create sections once, not on every render
2. **Convenience Builders**: Low overhead - safe to use extensively
3. **Scrolling**: Only visible components are rendered
4. **Custom Components**: Keep simple - complex layouts impact performance

## Related Components

- **[StatusListView](statuslistview-guide.md)** - For list views of resources
- **[FormBuilder](formbuilder-guide.md)** - For editing resources
- **StatusIcon** - For status indicators in custom components

## Component Source Code

- [Sources/Substation/Components/DetailView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/DetailView.swift) - Core component
- [Sources/Substation/Modules/Servers/Views/ServerViews.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Modules/Servers/Views/ServerViews.swift) - Example usage (drawServerDetail function)

## Summary

DetailView standardizes how detailed information is displayed across all resource types. Use section-based organization, convenience builders for optional fields, and custom components for complex layouts. Results in 70-85% code reduction while improving consistency and maintainability.

**Pattern**: Build sections with items + Create DetailView + Single draw() call = Consistent, maintainable detail views.
