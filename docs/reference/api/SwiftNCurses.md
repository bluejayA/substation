# SwiftNCurses Framework API Reference

This is the API reference for SwiftNCurses. If you're building your first terminal UI, start with the integration guide instead. This covers the complete SwiftNCurses terminal UI framework and components.

## Package Overview

SwiftNCurses provides a declarative terminal UI framework with:

- **SwiftUI-like syntax** for familiar development experience
- **Cross-platform rendering** using NCurses abstraction
- **High-performance rendering** with 60+ FPS capability
- **Component-based architecture** for reusability
- **Event-driven input handling** for responsive UIs

## Core Components

### Surface Management

```swift
import SwiftNCurses

// Create rendering surface
let surface = SwiftNCurses.surface(from: screen)

// Get surface dimensions
let (width, height) = SwiftNCurses.getScreenSize()
let maxY = SwiftNCurses.getMaxY(screen)
let maxX = SwiftNCurses.getMaxX(screen)
```

### Component Rendering

```swift
// Basic text rendering
await SwiftNCurses.render(
    Text("Hello, World!").bold().color(.blue),
    on: surface,
    in: Rect(x: 0, y: 0, width: 20, height: 1)
)

// List component
let listComponent = List(items: ["Item 1", "Item 2", "Item 3"])
await SwiftNCurses.render(listComponent, on: surface, in: bounds)

// Table component
let tableComponent = Table(data: serverData, columns: columns)
await SwiftNCurses.render(tableComponent, on: surface, in: bounds)
```

### Input Handling

```swift
// Get user input
let key = SwiftNCurses.getInput(screen)

// Handle special keys
switch key {
case Int32(259): // Arrow Up
    // Handle up arrow
case Int32(258): // Arrow Down
    // Handle down arrow
case 10, 13: // Enter
    // Handle enter key
case 27: // Escape
    // Handle escape key
default:
    // Handle other keys
}
```

### Screen Management

```swift
// Screen operations
SwiftNCurses.clear(screen)
SwiftNCurses.refresh(screen)

// Initialize/cleanup
let screen = SwiftNCurses.initializeScreen()
SwiftNCurses.cleanup(screen)
```

## UI Components

### Text Component

```swift
public struct Text {
    public init(_ content: String)

    // Styling modifiers
    public func bold() -> Text
    public func color(_ color: Color) -> Text
    public func background(_ color: Color) -> Text
    public func underline() -> Text
}
```

**Example**:

```swift
// Simple text
let text = Text("Hello, World!")

// Styled text
let styledText = Text("Error!")
    .bold()
    .color(.red)
    .underline()

// Render
await SwiftNCurses.render(text, on: surface, in: bounds)
```

### List Component

```swift
public struct List<Item> {
    public init(items: [Item])

    // Configuration
    public func selectedIndex(_ index: Int) -> List
    public func onSelection(_ handler: @escaping (Item) -> Void) -> List
    public func scrollable(_ enabled: Bool = true) -> List
}
```

**Example**:

```swift
let items = ["Server 1", "Server 2", "Server 3"]

let list = List(items: items)
    .selectedIndex(0)
    .scrollable(true)
    .onSelection { item in
        print("Selected: \(item)")
    }

await SwiftNCurses.render(list, on: surface, in: bounds)
```

### Table Component

```swift
public struct Table<Data> {
    public init(data: [Data], columns: [TableColumn])

    // Configuration
    public func sortable(_ enabled: Bool = true) -> Table
    public func selectable(_ enabled: Bool = true) -> Table
    public func headerStyle(_ style: HeaderStyle) -> Table
}
```

**Example**:

```swift
struct Server {
    let name: String
    let status: String
    let ip: String
}

let servers = [
    Server(name: "web-01", status: "ACTIVE", ip: "10.0.0.1"),
    Server(name: "web-02", status: "ACTIVE", ip: "10.0.0.2")
]

let columns = [
    TableColumn(header: "Name", width: 20) { $0.name },
    TableColumn(header: "Status", width: 10) { $0.status },
    TableColumn(header: "IP", width: 15) { $0.ip }
]

let table = Table(data: servers, columns: columns)
    .sortable(true)
    .selectable(true)

await SwiftNCurses.render(table, on: surface, in: bounds)
```

### Form Component

```swift
public struct Form {
    public init(@FormBuilder content: () -> [FormField])

    // Validation
    public func validate() -> [ValidationError]
    public func onSubmit(_ handler: @escaping () -> Void) -> Form
}
```

**Example**:

```swift
let form = Form {
    FormField.text(
        label: "Name",
        value: name,
        isRequired: true
    )
    FormField.toggle(
        label: "Enable",
        value: enabled
    )
}
.onSubmit {
    // Handle form submission
}

await SwiftNCurses.render(form, on: surface, in: bounds)
```

## Color System

```swift
public enum Color {
    case black
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white
    case custom(r: Int, g: Int, b: Int)
}
```

**Example**:

```swift
// Standard colors
Text("Error").color(.red)
Text("Success").color(.green)
Text("Warning").color(.yellow)

// Custom colors
Text("Custom").color(.custom(r: 100, g: 150, b: 200))
```

## Layout System

### Rect Structure

```swift
public struct Rect {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int)
}
```

### Layout Helpers

```swift
// Split screen vertically
func splitVertical(bounds: Rect, ratio: Double) -> (Rect, Rect) {
    let splitY = Int(Double(bounds.height) * ratio)
    let top = Rect(x: bounds.x, y: bounds.y, width: bounds.width, height: splitY)
    let bottom = Rect(x: bounds.x, y: bounds.y + splitY, width: bounds.width, height: bounds.height - splitY)
    return (top, bottom)
}

// Split screen horizontally
func splitHorizontal(bounds: Rect, ratio: Double) -> (Rect, Rect) {
    let splitX = Int(Double(bounds.width) * ratio)
    let left = Rect(x: bounds.x, y: bounds.y, width: splitX, height: bounds.height)
    let right = Rect(x: bounds.x + splitX, y: bounds.y, width: bounds.width - splitX, height: bounds.height)
    return (left, right)
}
```

**Example**:

```swift
// Split screen into header and content
let (header, content) = splitVertical(bounds: fullScreen, ratio: 0.1)

await SwiftNCurses.render(headerText, on: surface, in: header)
await SwiftNCurses.render(contentList, on: surface, in: content)
```

## Event Handling

### Key Codes

```swift
// Navigation keys
let KEY_UP: Int32 = 259
let KEY_DOWN: Int32 = 258
let KEY_LEFT: Int32 = 260
let KEY_RIGHT: Int32 = 261

// Special keys
let KEY_ENTER: Int32 = 10
let KEY_ESC: Int32 = 27
let KEY_TAB: Int32 = 9
let KEY_BACKSPACE: Int32 = 127
let KEY_DELETE: Int32 = 330

// Page navigation
let KEY_PPAGE: Int32 = 339  // Page Up
let KEY_NPAGE: Int32 = 338  // Page Down
let KEY_HOME: Int32 = 262
let KEY_END: Int32 = 360
```

### Input Loop

```swift
var running = true
while running {
    let key = SwiftNCurses.getInput(screen)

    switch key {
    case KEY_UP:
        // Handle up arrow
        viewModel.moveUp()

    case KEY_DOWN:
        // Handle down arrow
        viewModel.moveDown()

    case KEY_ENTER:
        // Handle enter
        viewModel.select()

    case KEY_ESC:
        // Handle escape
        running = false

    case Int32(UnicodeScalar("q").value):
        // Handle 'q' key
        running = false

    default:
        // Handle other keys
        if let scalar = UnicodeScalar(Int(key)) {
            viewModel.handleCharacter(Character(scalar))
        }
    }

    // Re-render
    await renderScreen()
    SwiftNCurses.refresh(screen)
}
```

## Performance Optimization

### Rendering Best Practices

```swift
// 1. Minimize full screen redraws
// Only redraw changed regions
await SwiftNCurses.render(updatedComponent, on: surface, in: changedBounds)

// 2. Batch updates
let components = [component1, component2, component3]
for (component, bounds) in zip(components, boundsList) {
    await SwiftNCurses.render(component, on: surface, in: bounds)
}
SwiftNCurses.refresh(screen)  // Single refresh after all updates

// 3. Use double buffering
// SwiftNCurses handles this automatically

// 4. Limit rendering frequency
let targetFPS = 60
let frameTime = 1.0 / Double(targetFPS)
// Render at most once per frameTime
```

### Memory Management

```swift
// 1. Clear screen when switching views
SwiftNCurses.clear(screen)

// 2. Cleanup on exit
defer { SwiftNCurses.cleanup(screen) }

// 3. Avoid retaining large data structures in components
// Pass only what's needed for rendering
```

## Cross-Platform Considerations

### Platform Detection

```swift
#if canImport(Darwin)
// macOS-specific code
#else
// Linux-specific code
#endif
```

### Terminal Capabilities

```swift
// Check terminal size
let (width, height) = SwiftNCurses.getScreenSize()

// Ensure minimum size
guard width >= 80 && height >= 24 else {
    print("Terminal too small. Minimum size: 80x24")
    return
}

// Handle resize events
// SwiftNCurses automatically handles SIGWINCH on supported platforms
```

## Common Patterns

### Pattern 1: List with Selection

```swift
struct ListView {
    var items: [String]
    var selectedIndex: Int = 0

    mutating func moveUp() {
        selectedIndex = max(0, selectedIndex - 1)
    }

    mutating func moveDown() {
        selectedIndex = min(items.count - 1, selectedIndex + 1)
    }

    func render(on surface: Surface, in bounds: Rect) async {
        let list = List(items: items)
            .selectedIndex(selectedIndex)
            .scrollable(true)

        await SwiftNCurses.render(list, on: surface, in: bounds)
    }
}
```

### Pattern 2: Multi-Column Table

```swift
struct TableView<T> {
    var data: [T]
    var columns: [TableColumn<T>]
    var selectedIndex: Int = 0

    func render(on surface: Surface, in bounds: Rect) async {
        let table = Table(data: data, columns: columns)
            .selectable(true)
            .sortable(true)

        await SwiftNCurses.render(table, on: surface, in: bounds)
    }
}
```

### Pattern 3: Form with Validation

```swift
struct FormView {
    var name: String = ""
    var enabled: Bool = false

    var nameError: String? {
        guard !name.isEmpty else { return "Name is required" }
        guard name.count <= 255 else { return "Name too long" }
        return nil
    }

    var isValid: Bool {
        nameError == nil
    }

    func render(on surface: Surface, in bounds: Rect) async {
        let form = Form {
            FormField.text(
                label: "Name",
                value: name,
                error: nameError,
                isRequired: true
            )
            FormField.toggle(
                label: "Enabled",
                value: enabled
            )
        }

        await SwiftNCurses.render(form, on: surface, in: bounds)
    }
}
```

## Testing

### Mock Screen for Testing

```swift
#if DEBUG
class MockScreen {
    var renderedComponents: [(any Component, Rect)] = []

    func render(_ component: any Component, in bounds: Rect) {
        renderedComponents.append((component, bounds))
    }

    func clear() {
        renderedComponents.removeAll()
    }
}
#endif
```

### Component Testing

```swift
func testListRendering() async {
    let screen = MockScreen()
    let items = ["Item 1", "Item 2", "Item 3"]
    let list = List(items: items).selectedIndex(0)

    await screen.render(list, in: Rect(x: 0, y: 0, width: 80, height: 24))

    XCTAssertEqual(screen.renderedComponents.count, 1)
}
```

## Migration from NCurses

### Direct NCurses

**Before**:

```c
initscr();
printw("Hello, World!");
refresh();
endwin();
```

**After**:

```swift
let screen = SwiftNCurses.initializeScreen()
defer { SwiftNCurses.cleanup(screen) }

await SwiftNCurses.render(
    Text("Hello, World!"),
    on: SwiftNCurses.surface(from: screen),
    in: Rect(x: 0, y: 0, width: 20, height: 1)
)
SwiftNCurses.refresh(screen)
```

## Best Practices

### 1. Initialize Screen Once

```swift
// Good: Initialize at app start
let screen = SwiftNCurses.initializeScreen()
defer { SwiftNCurses.cleanup(screen) }

// Bad: Initialize multiple times
// let screen1 = SwiftNCurses.initializeScreen()
// let screen2 = SwiftNCurses.initializeScreen()  // Don't do this
```

### 2. Always Use Defer for Cleanup

```swift
// Ensures cleanup even on error
let screen = SwiftNCurses.initializeScreen()
defer { SwiftNCurses.cleanup(screen) }

// Your app code here
```

### 3. Batch Screen Updates

```swift
// Good: Render all components, then refresh once
await SwiftNCurses.render(header, on: surface, in: headerBounds)
await SwiftNCurses.render(content, on: surface, in: contentBounds)
await SwiftNCurses.render(footer, on: surface, in: footerBounds)
SwiftNCurses.refresh(screen)  // Single refresh

// Bad: Refresh after each component
// await SwiftNCurses.render(header, ...)
// SwiftNCurses.refresh(screen)  // Too many refreshes
```

### 4. Handle Terminal Resize

```swift
// Check for resize and adjust layout
let (newWidth, newHeight) = SwiftNCurses.getScreenSize()
if newWidth != currentWidth || newHeight != currentHeight {
    currentWidth = newWidth
    currentHeight = newHeight
    // Recalculate layout bounds
    updateLayout()
}
```

---

**See Also**:

- [OSClient API](osclient.md) - OpenStack client library
- [Integration Guide](integration.md) - CrossPlatformTimer and integration examples
- [API Reference Index](index.md) - Quick reference and navigation
