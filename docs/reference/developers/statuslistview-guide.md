# StatusListView Component Guide

## Overview

**StatusListView** is a reusable component for rendering primary resource lists with StatusIcon indicators and multi-column text display. It handles filtering, scrolling, and pagination automatically, providing a consistent interface for all primary resource views (servers, images, volumes, networks, etc.).

Writing list rendering code manually means 150+ lines of column formatting, scroll management, and filter logic per view. StatusListView reduces that to 15 lines. Stop writing boilerplate. Use StatusListView.

## Location

- **Component:** [Sources/Substation/Components/StatusListView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/StatusListView.swift)
- **Extensions:** [Sources/Substation/Extensions/*+StatusListView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Extensions/)
- **Usage:** Primary list views for all resource types

## Features

- Status icon display (first column)
- Multi-column text display with custom styling
- Automatic search/filter handling
- Three rendering modes: traditional, paginated, virtual scrolling
- Scroll management and indicators
- Type-safe generic implementation with Sendable constraint
- Closure-based column configuration

## When to Use

**Use StatusListView when**:

- Displaying primary resource lists (servers, volumes, images, networks)
- Need StatusIcon + multiple text columns
- Want automatic filtering and scroll handling
- Building new primary list views

**Use FormSelector when**:

- Selecting resources from lists (used in forms)
- Need multi-select capability
- Want checkbox indicators
- Building selection interfaces

## Basic Usage

### Step 1: Create Extension with StatusListView Configuration

```swift
import Foundation
import OSClient
import SwiftNCurses

extension ServerViews {
    @MainActor
    static func createServerStatusListView(
        cachedFlavors: [Flavor],
        cachedImages: [Image]
    ) -> StatusListView<Server> {
        return StatusListView<Server>(
            title: "Servers",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 30,
                    getValue: { $0.name }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 12,
                    getValue: { $0.status },
                    getStyle: { server in
                        switch server.status.lowercased() {
                        case "active": return .success
                        case "error": return .error
                        case "build", "building": return .warning
                        default: return .info
                        }
                    }
                ),
                StatusListColumn(
                    header: "IP ADDRESS",
                    width: 15,
                    getValue: { server in
                        getServerIP(server: server)
                    }
                ),
                StatusListColumn(
                    header: "FLAVOR / IMAGE",
                    width: 40,
                    getValue: { server in
                        formatFlavorImageInfo(
                            server: server,
                            cachedFlavors: cachedFlavors,
                            cachedImages: cachedImages
                        )
                    },
                    getStyle: { _ in .info }
                )
            ],
            getStatusIcon: { server in server.status },
            filterItems: { servers, query in
                guard let query = query, !query.isEmpty else { return servers }
                return servers.filter { server in
                    server.name.lowercased().contains(query.lowercased()) ||
                    server.id.lowercased().contains(query.lowercased()) ||
                    server.status.lowercased().contains(query.lowercased())
                }
            }
        )
    }
}
```

### Step 2: Use in View Draw Function

```swift
@MainActor
static func drawDetailedServerList(
    screen: OpaquePointer?,
    startRow: Int32,
    startCol: Int32,
    width: Int32,
    height: Int32,
    servers: [Server],
    searchQuery: String?,
    scrollOffset: Int,
    selectedIndex: Int,
    cachedFlavors: [Flavor],
    cachedImages: [Image],
    dataManager: DataManager? = nil
) async {
    let statusListView = createServerStatusListView(
        cachedFlavors: cachedFlavors,
        cachedImages: cachedImages
    )

    await statusListView.draw(
        screen: screen,
        startRow: startRow,
        startCol: startCol,
        width: width,
        height: height,
        items: servers,
        searchQuery: searchQuery,
        scrollOffset: scrollOffset,
        selectedIndex: selectedIndex,
        dataManager: dataManager  // Optional for pagination
    )
}
```

## Column Configuration

### Basic Text Column

```swift
StatusListColumn(
    header: "NAME",
    width: 30,
    getValue: { $0.name ?? "Unknown" }
)
```

### Column with Custom Styling

```swift
StatusListColumn(
    header: "STATUS",
    width: 12,
    getValue: { $0.status ?? "Unknown" },
    getStyle: { item in
        switch item.status?.lowercased() {
        case "active": return .success
        case "error": return .error
        case "build": return .warning
        default: return .info
        }
    }
)
```

### Column with Formatting

```swift
StatusListColumn(
    header: "SIZE",
    width: 10,
    getValue: { image in
        if let size = image.size {
            return String(format: "%.1f GB", Double(size) / 1_073_741_824)
        }
        return "Unknown"
    }
)
```

### Column with Context Capture

For complex views that need external data (e.g., FloatingIPs showing associated server/network names):

```swift
static func createFloatingIPStatusListView(
    cachedServers: [Server],
    cachedPorts: [Port],
    cachedNetworks: [Network]
) -> StatusListView<FloatingIP> {
    // Create lookup dictionaries
    let portLookup: [String: Port] = Dictionary(
        uniqueKeysWithValues: cachedPorts.map { ($0.id, $0) }
    )
    let serverLookup: [String: Server] = Dictionary(
        uniqueKeysWithValues: cachedServers.map { ($0.id, $0) }
    )

    return StatusListView<FloatingIP>(
        title: "Floating IPs",
        columns: [
            StatusListColumn(
                header: "INSTANCE",
                width: 25,
                getValue: { floatingIP in
                    // Closures capture the lookup dictionaries
                    guard let portId = floatingIP.portId,
                          let port = portLookup[portId],
                          let deviceId = port.deviceId,
                          let server = serverLookup[deviceId] else {
                        return "Not attached"
                    }
                    return server.name
                }
            )
        ],
        getStatusIcon: { /* ... */ },
        filterItems: { /* ... */ }
    )
}
```

## Status Icon Configuration

The `getStatusIcon` closure determines what status to show in the first column:

```swift
// Simple status from field
getStatusIcon: { server in server.status }

// Derived status
getStatusIcon: { network in
    if network.isExternal { return "external" }
    if network.isShared { return "shared" }
    return "private"
}

// Complex status logic
getStatusIcon: { port in
    if port.deviceId != nil { return "active" }
    return "down"
}
```

## Filter Configuration

The `filterItems` closure handles search/filter logic:

```swift
filterItems: { items, query in
    guard let query = query, !query.isEmpty else { return items }
    return items.filter { item in
        (item.name?.lowercased().contains(query.lowercased()) ?? false) ||
        item.id.lowercased().contains(query.lowercased())
    }
}
```

## Rendering Modes

### Traditional Scrolling (Default)

```swift
await statusListView.draw(
    screen: screen,
    startRow: startRow,
    startCol: startCol,
    width: width,
    height: height,
    items: items,
    searchQuery: searchQuery,
    scrollOffset: scrollOffset,
    selectedIndex: selectedIndex
)
```

### Paginated Rendering

```swift
await statusListView.draw(
    screen: screen,
    startRow: startRow,
    startCol: startCol,
    width: width,
    height: height,
    items: items,
    searchQuery: searchQuery,
    scrollOffset: scrollOffset,
    selectedIndex: selectedIndex,
    dataManager: dataManager  // Handles pagination
)
```

### Virtual Scrolling

```swift
await statusListView.draw(
    screen: screen,
    startRow: startRow,
    startCol: startCol,
    width: width,
    height: height,
    items: items,
    searchQuery: searchQuery,
    scrollOffset: scrollOffset,
    selectedIndex: selectedIndex,
    virtualScrollManager: virtualScrollManager  // Handles virtual scrolling
)
```

## Real-World Examples

### Simple Resource (KeyPairs)

```swift
extension KeyPairViews {
    @MainActor
    static func createKeyPairStatusListView() -> StatusListView<KeyPair> {
        return StatusListView<KeyPair>(
            title: "Key Pairs",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 30,
                    getValue: { $0.name }
                ),
                StatusListColumn(
                    header: "FINGERPRINT",
                    width: 50,
                    getValue: { kp in
                        let fp = kp.fingerprint ?? "Unknown"
                        return String(fp.prefix(50))
                    },
                    getStyle: { _ in .info }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { keyPairs, query in
                guard let query = query, !query.isEmpty else { return keyPairs }
                return keyPairs.filter { $0.name.lowercased().contains(query.lowercased()) }
            }
        )
    }
}
```

### Complex Resource with Multiple Fields (Volumes)

```swift
extension VolumeViews {
    @MainActor
    static func createVolumeStatusListView() -> StatusListView<Volume> {
        return StatusListView<Volume>(
            title: "Volumes",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 30,
                    getValue: { $0.name ?? "Unnamed" }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 12,
                    getValue: { $0.status ?? "unknown" },
                    getStyle: { volume in
                        switch (volume.status ?? "unknown").lowercased() {
                        case "available": return .success
                        case "in-use": return .success
                        case "error": return .error
                        case "creating", "attaching", "detaching": return .warning
                        default: return .info
                        }
                    }
                ),
                StatusListColumn(
                    header: "SIZE",
                    width: 10,
                    getValue: { "\($0.size ?? 0) GB" },
                    getStyle: { _ in .accent }
                ),
                StatusListColumn(
                    header: "ATTACHED TO",
                    width: 30,
                    getValue: { volume in
                        volume.attachments?.first?.serverId ?? "Not attached"
                    },
                    getStyle: { _ in .info }
                )
            ],
            getStatusIcon: { $0.status ?? "unknown" },
            filterItems: { volumes, query in
                guard let query = query, !query.isEmpty else { return volumes }
                return volumes.filter { volume in
                    (volume.name?.lowercased().contains(query.lowercased()) ?? false) ||
                    volume.id.lowercased().contains(query.lowercased())
                }
            }
        )
    }
}
```

### Resource with Date Formatting (Barbican Secrets)

```swift
extension BarbicanViews {
    @MainActor
    static func createBarbicanSecretStatusListView() -> StatusListView<Secret> {
        return StatusListView<Secret>(
            title: "Secrets",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 20,
                    getValue: { $0.name ?? "Unknown" }
                ),
                StatusListColumn(
                    header: "TYPE",
                    width: 12,
                    getValue: { $0.secretType ?? "opaque" },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "CREATED",
                    width: 16,
                    getValue: { secret in
                        if let created = secret.created {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .short
                            formatter.timeStyle = .short
                            return formatter.string(from: created)
                        }
                        return "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "EXPIRATION",
                    width: 16,
                    getValue: { secret in
                        if let expiration = secret.expiration {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .short
                            formatter.timeStyle = .short
                            return formatter.string(from: expiration)
                        }
                        return "Never"
                    },
                    getStyle: { secret in
                        if let expiration = secret.expiration {
                            return expiration < Date() ? .error : .warning
                        }
                        return .success
                    }
                )
            ],
            getStatusIcon: { $0.status ?? "unknown" },
            filterItems: { secrets, query in
                guard let query = query, !query.isEmpty else { return secrets }
                return secrets.filter { secret in
                    (secret.name?.lowercased().contains(query.lowercased()) ?? false) ||
                    (secret.secretType?.lowercased().contains(query.lowercased()) ?? false)
                }
            }
        )
    }
}
```

## Migration from Manual Rendering

### Before (Manual Rendering)

```swift
static func drawDetailedVolumeList(...) async {
    let surface = SwiftNCurses.surface(from: screen)
    var components: [any Component] = []

    // Title
    components.append(Text("Volumes").emphasis().bold())

    // Header row
    let nameHeader = String("NAME".prefix(30)).padding(toLength: 30, withPad: " ", startingAt: 0)
    let statusHeader = String("STATUS".prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)
    // ... 100+ lines of manual rendering logic

    await SwiftNCurses.render(VStack(spacing: 0, children: components), on: surface, in: bounds)
}
```

### After (StatusListView)

```swift
static func drawDetailedVolumeList(...) async {
    let statusListView = createVolumeStatusListView()
    await statusListView.draw(
        screen: screen,
        startRow: startRow,
        startCol: startCol,
        width: width,
        height: height,
        items: volumes,
        searchQuery: searchQuery,
        scrollOffset: scrollOffset,
        selectedIndex: selectedIndex
    )
}
```

**Result**: Reduced from ~150 lines to ~15 lines (90% reduction).

## Best Practices

### Column Width Allocation

Total width should not exceed available screen space. Typical allocation:

```swift
columns: [
    StatusListColumn(header: "NAME", width: 30, ...),      // Primary identifier
    StatusListColumn(header: "STATUS", width: 12, ...),    // Status info
    StatusListColumn(header: "DETAIL", width: 40, ...),    // Additional context
    StatusListColumn(header: "EXTRA", width: 15, ...)      // Optional info
]
// Total: ~97 characters (leaves room for StatusIcon and padding)
```

### Status Icon Consistency

Use consistent status values across similar resources:

```swift
// Good - consistent status patterns
getStatusIcon: { server in server.status }  // "active", "error", "build"
getStatusIcon: { volume in volume.status }  // "available", "error", "creating"

// Avoid - inconsistent custom values
getStatusIcon: { _ in "ok" }
getStatusIcon: { _ in "ready" }
```

### Filter Performance

Keep filter logic simple and fast:

```swift
// Good - simple string matching
filterItems: { items, query in
    guard let query = query, !query.isEmpty else { return items }
    let lowercased = query.lowercased()
    return items.filter { $0.name?.lowercased().contains(lowercased) ?? false }
}

// Avoid - complex operations in filter
filterItems: { items, query in
    guard let query = query, !query.isEmpty else { return items }
    return items.filter { item in
        // Avoid: regex, API calls, complex calculations
        item.name?.range(of: query, options: .regularExpression) != nil
    }
}
```

### Helper Functions

Extract complex logic into helper functions (mark as `internal` not `private` for reuse):

```swift
// Good - helpers in extension or view struct
internal static func formatServerIP(_ server: Server) -> String {
    // Complex IP extraction logic
}

StatusListColumn(
    header: "IP ADDRESS",
    width: 15,
    getValue: { server in formatServerIP(server) }
)
```

## Type Safety

StatusListView is generic over `T: Sendable` for concurrent safety:

```swift
struct StatusListView<T: Sendable> {
    // Ensures type safety and concurrency compliance
}

// Your types must conform to Sendable
extension Server: Sendable { }  // Already done for OSClient types
extension Volume: Sendable { }
```

## Component Architecture

```
StatusListView<T: Sendable>
|
+-- title: String                           // View title
+-- columns: [StatusListColumn<T>]          // Column configuration
+-- getStatusIcon: (T) -> String            // Status icon logic
+-- filterItems: ([T], String?) -> [T]      // Filter logic
|
+-- draw(screen, bounds, items, ...)        // Main render function
    |
    +-- Filters items via filterItems closure
    +-- Calculates scroll boundaries
    +-- Renders title and search info
    +-- Renders headers
    +-- Renders StatusIcon + columns for each item
    +-- Renders scroll indicators
```

## Common Patterns

### Pattern 1: Simple List with Status

```swift
StatusListView<Resource>(
    title: "Resources",
    columns: [
        StatusListColumn(header: "NAME", width: 40, getValue: { $0.name }),
        StatusListColumn(header: "ID", width: 36, getValue: { $0.id })
    ],
    getStatusIcon: { $0.status },
    filterItems: { resources, query in
        guard let query = query, !query.isEmpty else { return resources }
        return resources.filter { $0.name.lowercased().contains(query.lowercased()) }
    }
)
```

### Pattern 2: List with Computed Values

```swift
StatusListView<ServerGroup>(
    title: "Server Groups",
    columns: [
        StatusListColumn(header: "NAME", width: 30, getValue: { $0.name }),
        StatusListColumn(
            header: "MEMBERS",
            width: 10,
            getValue: { group in
                let count = group.members?.count ?? 0
                return "\(count) member\(count == 1 ? "" : "s")"
            }
        )
    ],
    getStatusIcon: { _ in "active" },
    filterItems: { /* ... */ }
)
```

### Pattern 3: List with External Context

```swift
static func createResourceListView(
    cachedData: [ExternalType]
) -> StatusListView<Resource> {
    let lookup = Dictionary(uniqueKeysWithValues: cachedData.map { ($0.id, $0) })

    return StatusListView<Resource>(
        columns: [
            StatusListColumn(
                header: "RELATED",
                width: 30,
                getValue: { resource in
                    lookup[resource.relatedId]?.name ?? "Unknown"
                }
            )
        ],
        // ...
    )
}
```

## Troubleshooting

### Issue: Items not filtering

**Check**: Is `filterItems` closure implemented correctly?

```swift
// Correct - returns filtered array
filterItems: { items, query in
    guard let query = query, !query.isEmpty else { return items }
    return items.filter { /* condition */ }
}

// Wrong - doesn't handle empty query
filterItems: { items, query in
    return items.filter { $0.name.contains(query!) }  // Crashes on nil!
}
```

### Issue: Column text truncated

**Check**: Column width allocation.

```swift
// If total width > screen width, text will be truncated
// Adjust column widths to fit available space
```

### Issue: Status icons not showing

**Check**: StatusIcon component mapping in `Components/StatusIcon.swift`.

```swift
// Status values must match StatusIcon cases
getStatusIcon: { server in server.status }  // "active" must map to StatusIcon case
```

### Issue: Styling not applied

**Check**: `getStyle` closure is optional - verify it's set when needed.

```swift
StatusListColumn(
    header: "STATUS",
    width: 12,
    getValue: { $0.status },
    getStyle: { item in  // Must be set for custom styling
        item.status == "active" ? .success : .error
    }
)
```

## Performance Considerations

1. **Filter Logic**: Keep simple - runs on every keystroke
2. **Column Closures**: Executed for every visible item - avoid heavy operations
3. **Context Capture**: Pre-compute lookups outside closures when possible
4. **Virtual Scrolling**: Use `virtualScrollManager` for 10,000+ items

## Related Components

- **[FormSelector](formselector-guide.md)** - For resource selection in forms
- **[FormBuilder](formbuilder-guide.md)** - For form construction
- **StatusIcon** - First column status indicator component

## Component Source Code

Study these for implementation details:

- [Sources/Substation/Components/StatusListView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Components/StatusListView.swift) - Core component (242 lines)
- [Sources/Substation/Extensions/Server+StatusListView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Extensions/Server+StatusListView.swift) - Server example
- [Sources/Substation/Extensions/FloatingIP+StatusListView.swift](https://github.com/cloudnull/substation/blob/main/Sources/Substation/Extensions/FloatingIP+StatusListView.swift) - Complex context example

## Summary

StatusListView eliminates duplicate list rendering code across primary views. Create an extension with column configuration, then render with a single `draw()` call. Results in 80-90% code reduction while maintaining consistency and type safety.

**Pattern**: Extension with configuration + Simple draw call = Consistent, maintainable list views.
