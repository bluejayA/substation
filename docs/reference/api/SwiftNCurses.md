# SwiftNCurses Framework API Reference

This is the API reference for SwiftNCurses, Substation's terminal UI framework. For building your first terminal UI, start with the integration guide. This document covers the complete SwiftNCurses API including components, styling, and rendering.

## Package Overview

SwiftNCurses provides a declarative, component-based terminal UI framework with:

- **SwiftUI-like syntax** with result builders for familiar development experience
- **Cross-platform rendering** using NCurses abstraction layer
- **High-performance rendering** with render buffering and virtual scrolling
- **Component-based architecture** with composable, reusable components
- **Semantic color system** based on GitHub Primer design system
- **MainActor isolation** for thread-safe terminal operations

## Core Types

### Geometry Types

```swift
/// Type-safe position representation
public struct Position: Equatable, Hashable, Sendable {
    public let row: Int32
    public let col: Int32

    /// Convenience properties for x/y access
    public var x: Int32 { col }
    public var y: Int32 { row }

    public init(row: Int32, col: Int32)
    public init(x: Int32, y: Int32)

    public static let zero = Position(row: 0, col: 0)

    public func offset(by offset: Position) -> Position
}

/// Alias for familiar Point terminology
public typealias Point = Position

/// Type-safe size representation
public struct Size: Equatable, Hashable, Sendable {
    public let width: Int32
    public let height: Int32

    public init(width: Int32, height: Int32)

    public static let zero = Size(width: 0, height: 0)
    public var area: Int32 { width * height }
}

/// Type-safe rectangle representation
public struct Rect: Equatable, Hashable, Sendable {
    public let origin: Position
    public let size: Size

    public init(origin: Position, size: Size)
    public init(x: Int32, y: Int32, width: Int32, height: Int32)

    public static let zero = Rect(origin: .zero, size: .zero)

    public var minX: Int32
    public var minY: Int32
    public var maxX: Int32
    public var maxY: Int32

    public func contains(_ position: Position) -> Bool
    public func inset(by insets: EdgeInsets) -> Rect
}

/// Edge insets for padding and margins
public struct EdgeInsets: Equatable, Hashable, Sendable {
    public let top: Int32
    public let leading: Int32
    public let bottom: Int32
    public let trailing: Int32

    public init(top: Int32, leading: Int32, bottom: Int32, trailing: Int32)
    public init(all: Int32)

    public static let zero = EdgeInsets(all: 0)
}
```

### Color System

SwiftNCurses uses a semantic color system inspired by GitHub's Primer Design System for professional, accessible terminal UIs.

```swift
/// Semantic color types for consistent theming
public enum Color: CaseIterable, Sendable {
    case primary      // Main text/content (Blue)
    case secondary    // Supporting text (Cyan)
    case accent       // Highlights/selections (White on Blue)
    case success      // Positive states (Green)
    case warning      // Caution states (Yellow)
    case error        // Error states (Red)
    case info         // Information/neutral (White)
    case background   // Background color
    case border       // Borders and separators (Dark Gray)
    case muted        // Subdued text (Magenta)
    case emphasis     // Strong emphasis (Black on White)

    /// Maps semantic colors to ncurses color pair indices
    public var colorPairIndex: Int32
}

/// Text attributes for styling
public struct TextAttributes: OptionSet, Hashable, Sendable {
    public static let normal    = TextAttributes([])
    public static let bold      = TextAttributes(rawValue: 1 << 0)
    public static let dim       = TextAttributes(rawValue: 1 << 1)
    public static let reverse   = TextAttributes(rawValue: 1 << 2)
    public static let underline = TextAttributes(rawValue: 1 << 3)
    public static let blink     = TextAttributes(rawValue: 1 << 4)
}

/// Complete text styling configuration
public struct TextStyle: Hashable, Sendable {
    public let color: Color
    public let attributes: TextAttributes

    public init(color: Color, attributes: TextAttributes = .normal)

    // Predefined styles
    public static let primary: TextStyle
    public static let secondary: TextStyle
    public static let accent: TextStyle
    public static let success: TextStyle
    public static let warning: TextStyle
    public static let error: TextStyle
    public static let info: TextStyle
    public static let border: TextStyle
    public static let muted: TextStyle
    public static let emphasis: TextStyle

    // Enhanced styles with attributes
    public static let primaryBold: TextStyle
    public static let accentBold: TextStyle
    public static let errorBold: TextStyle
    public static let emphasisBold: TextStyle
    public static let mutedDim: TextStyle

    // Style modifiers
    public func bold() -> TextStyle
    public func dim() -> TextStyle
    public func reverse() -> TextStyle

    /// Automatically choose style based on status string
    public static func forStatus(_ status: String?) -> TextStyle
}
```

**Example**:

```swift
// Using predefined styles
let title = Text("Welcome").styled(.primaryBold)
let error = Text("Error!").styled(.error)
let muted = Text("Optional").styled(.mutedDim)

// Using style modifiers
let highlighted = Text("Important").primary().bold()

// Automatic status styling
let status = TextStyle.forStatus("active")  // Returns .success
let failed = TextStyle.forStatus("error")   // Returns .error
```

## SwiftNCurses Main Interface

The `SwiftNCurses` struct provides the primary interface for terminal operations.

### Terminal Initialization

```swift
public struct SwiftNCurses {
    /// Initialize SwiftNCurses with ncurses
    @MainActor public static func initialize(colorScheme: ColorScheme? = nil)

    /// Initialize terminal colors and cursor settings
    @MainActor public static func initializeTerminal(colorScheme: ColorScheme? = nil) -> Bool

    /// Initialize terminal screen (replaces initscr())
    @MainActor public static func initializeScreen() -> WindowHandle?

    /// Complete terminal initialization sequence
    /// Returns (screen, rows, cols, success)
    @MainActor public static func initializeTerminalSession() -> (
        screen: WindowHandle?,
        rows: Int32,
        cols: Int32,
        success: Bool
    )

    /// Cleanup terminal (replaces endwin())
    @MainActor public static func cleanupTerminal()
}
```

**Example**:

```swift
// Standard initialization pattern
let (screen, rows, cols, success) = SwiftNCurses.initializeTerminalSession()
guard success, let screen = screen else {
    print("Failed to initialize terminal")
    return
}
defer { SwiftNCurses.cleanupTerminal() }

print("Terminal initialized: \(cols)x\(rows)")
```

### Surface Management

```swift
extension SwiftNCurses {
    /// Create a drawing surface from an ncurses window
    @MainActor public static func surface(from window: OpaquePointer?) -> CursesSurface

    /// Create a drawing surface from a WindowHandle
    @MainActor public static func surface(from window: WindowHandle) -> CursesSurface

    /// Render a component to a surface
    @MainActor public static func render(
        _ component: any Component,
        on surface: any Surface,
        in rect: Rect? = nil
    ) async
}
```

**Example**:

```swift
let surface = SwiftNCurses.surface(from: screen)

// Render a component
await SwiftNCurses.render(
    Text("Hello, World!").primary(),
    on: surface,
    in: Rect(x: 0, y: 0, width: 20, height: 1)
)
```

### Screen Operations

```swift
extension SwiftNCurses {
    /// Clear entire screen
    @MainActor public static func clearScreen(_ window: WindowHandle)

    /// Refresh screen (standard refresh)
    @MainActor public static func refreshScreen(_ window: WindowHandle)

    /// Batched screen update - preferred over refresh()
    /// Updates virtual screen then flushes to terminal in one syscall
    @MainActor public static func batchedRefresh(_ window: WindowHandle)

    /// Update virtual screen without flushing (for batching)
    @MainActor public static func wnoutrefresh(_ window: WindowHandle)

    /// Flush all pending screen updates to terminal
    @MainActor public static func doupdate()

    /// Clear to end of line from current position
    @MainActor public static func clearToEndOfLine(_ window: WindowHandle)

    /// Move cursor to position
    @MainActor public static func moveCursor(_ window: WindowHandle, to position: Point)

    /// Get maximum Y coordinate
    @MainActor public static func getMaxY(_ window: WindowHandle) -> Int32

    /// Get maximum X coordinate
    @MainActor public static func getMaxX(_ window: WindowHandle) -> Int32
}
```

**Example**:

```swift
// Clear and redraw
SwiftNCurses.clearScreen(screen)

// Render multiple components
await SwiftNCurses.render(header, on: surface, in: headerBounds)
await SwiftNCurses.render(content, on: surface, in: contentBounds)
await SwiftNCurses.render(footer, on: surface, in: footerBounds)

// Batched refresh (preferred - reduces syscalls)
SwiftNCurses.batchedRefresh(screen)
```

### Input Handling

```swift
extension SwiftNCurses {
    /// Get character input
    @MainActor public static func getInput(_ window: WindowHandle) -> Int32

    /// Set input delay mode
    @MainActor public static func setInputDelay(_ window: WindowHandle, enabled: Bool)

    /// Wait for any input
    @MainActor public static func waitForInput(_ window: WindowHandle)
}
```

### Styled Text Drawing

```swift
extension SwiftNCurses {
    /// Draw styled text at position using color pair
    @MainActor public static func drawStyledText(
        _ window: WindowHandle,
        at position: Position,
        text: String,
        colorPair: Int32
    )

    /// Draw styled text using semantic color
    @MainActor public static func drawStyledText(
        _ window: WindowHandle,
        at position: Position,
        text: String,
        color: Color
    )

    /// Draw styled text using TextStyle
    @MainActor public static func drawStyledText(
        _ window: WindowHandle,
        at position: Position,
        text: String,
        style: TextStyle
    )

    // Semantic color helpers
    @MainActor public static func primaryColor() -> Int32
    @MainActor public static func secondaryColor() -> Int32
    @MainActor public static func accentColor() -> Int32
    @MainActor public static func warningColor() -> Int32
    @MainActor public static func successColor() -> Int32
    @MainActor public static func infoColor() -> Int32
    @MainActor public static func errorColor() -> Int32
    @MainActor public static func borderColor() -> Int32
    @MainActor public static func mutedColor() -> Int32
    @MainActor public static func emphasisColor() -> Int32
}
```

### Timer Management

```swift
extension SwiftNCurses {
    /// Create a repeating timer that works in async contexts
    @MainActor public static func createRepeatingTimer(
        interval: TimeInterval,
        tolerance: TimeInterval = 0.1,
        action: @escaping () -> Void
    ) -> Task<Void, Never>

    /// Create a one-shot timer that works in async contexts
    @MainActor public static func createOneShotTimer(
        delay: TimeInterval,
        action: @escaping () -> Void
    ) -> Task<Void, Never>
}
```

**Example**:

```swift
// Repeating timer for auto-refresh
let refreshTimer = SwiftNCurses.createRepeatingTimer(interval: 60.0) {
    Task { await refreshData() }
}

// Cancel timer when done
refreshTimer.cancel()
```

## Component System

### Component Protocol

All UI elements conform to the `Component` protocol:

```swift
/// Base protocol for all UI components
public protocol Component: Sendable {
    /// Render the component on a surface within the given bounds
    @MainActor func render(in context: DrawingContext) async

    /// Calculate the preferred size for this component
    var intrinsicSize: Size { get }
}

extension Component {
    /// Default intrinsic size for components that don't specify one
    public var intrinsicSize: Size {
        return Size(width: 0, height: 1)
    }

    /// Render with automatic context creation
    @MainActor public func render(on surface: any Surface, in rect: Rect) async

    /// Add padding around this component
    public func padding(_ edges: EdgeInsets) -> Padded
    public func padding(_ amount: Int32) -> Padded
}
```

### DrawingContext

```swift
/// Provides a drawing context for components with surface and bounds information
public struct DrawingContext: Sendable {
    public let surface: any Surface
    public let bounds: Rect

    public init(surface: any Surface, bounds: Rect)

    /// Create a sub-context with adjusted bounds
    public func subContext(rect: Rect) -> DrawingContext

    /// Check if a position is within the context bounds
    public func contains(_ position: Position) -> Bool

    /// Get the absolute position for a relative position within this context
    public func absolutePosition(for relativePosition: Position) -> Position

    /// Draw text at a position with style
    @MainActor public func draw(at position: Position, text: String, style: TextStyle? = nil) async

    /// Draw a border around the context bounds with optional title
    @MainActor public func drawBorder(style: TextStyle = .border, title: String? = nil) async
}
```

### Surface Protocol

```swift
/// Abstract drawing surface for rendering components
public protocol Surface: Sendable {
    /// Draw text at a specific position with optional styling
    @MainActor func draw(at position: Position, text: String, style: TextStyle?) async

    /// Move cursor to position without drawing
    @MainActor func move(to position: Position)

    /// Clear a rectangular area
    @MainActor func clear(rect: Rect)

    /// Clear to end of line from current position
    @MainActor func clearToEndOfLine()

    /// Draw a single character at position
    @MainActor func draw(at position: Position, character: Character, style: TextStyle?) async

    /// Get the size of the surface
    @MainActor var size: Size { get }

    /// Create a drawing context for the given bounds
    @MainActor func context(for bounds: Rect) -> DrawingContext

    /// Get string input from user at position
    @MainActor func getStringInput(at position: Position, prompt: String, maxLength: Int) -> String?

    /// Get character input from user
    @MainActor func getCharacterInput() -> Character?
}

extension Surface {
    /// Draw text with default primary style
    @MainActor public func draw(at position: Position, text: String) async

    /// Fill a rectangle with a character
    @MainActor public func fill(rect: Rect, character: Character = " ", style: TextStyle? = nil) async

    /// Draw a horizontal line
    @MainActor public func drawHorizontalLine(
        at row: Int32,
        from startCol: Int32,
        to endCol: Int32,
        character: Character = "-",
        style: TextStyle? = nil
    ) async

    /// Draw a vertical line
    @MainActor public func drawVerticalLine(
        at col: Int32,
        from startRow: Int32,
        to endRow: Int32,
        character: Character = "|",
        style: TextStyle? = nil
    ) async
}
```

### CursesSurface

```swift
/// Concrete implementation of Surface using ncurses
@MainActor public class CursesSurface: Surface {
    public init(window: OpaquePointer?, colorScheme: ColorScheme? = nil, enableBuffering: Bool = true)

    public var size: Size

    /// Flush the render buffer to screen
    public func flushBuffer()

    /// Enable or disable render buffering
    public func setBufferingEnabled(_ enabled: Bool)

    /// Mark all buffer cells as dirty for full redraw
    public func markBufferDirty()
}
```

## UI Components

### Text Components

```swift
/// Basic text rendering component
public struct Text: Component {
    public init(_ content: String, style: TextStyle = .primary)

    // Style modifiers (chainable)
    public func primary() -> Text
    public func secondary() -> Text
    public func accent() -> Text
    public func success() -> Text
    public func warning() -> Text
    public func error() -> Text
    public func info() -> Text
    public func muted() -> Text
    public func emphasis() -> Text
    public func bold() -> Text
    public func dim() -> Text
    public func reverse() -> Text
    public func styled(_ newStyle: TextStyle) -> Text

    // Quick constructors
    public static func primary(_ content: String) -> Text
    public static func accent(_ content: String) -> Text
}

/// Text component that automatically styles based on status
public struct StatusText: Component {
    public init(_ status: String, customStyle: TextStyle? = nil)
}

/// Text component with automatic formatting and truncation
public struct FormattedText: Component {
    public enum TextAlignment: Sendable {
        case leading
        case center
        case trailing
    }

    public init(
        _ content: String,
        style: TextStyle = .primary,
        maxWidth: Int32? = nil,
        alignment: TextAlignment = .leading
    )
}

/// Text with automatic padding for table-like layouts
public struct PaddedText: Component {
    public init(
        _ content: String,
        width: Int32,
        style: TextStyle = .primary,
        alignment: FormattedText.TextAlignment = .leading
    )
}

/// Text component that handles line breaks and wrapping
public struct MultilineText: Component {
    public init(_ content: String, style: TextStyle = .primary, maxWidth: Int32)
}
```

**Example**:

```swift
// Simple text
let text = Text("Hello, World!")

// Styled text with chaining
let styled = Text("Error!")
    .error()
    .bold()

// Status-aware text
let status = StatusText("ACTIVE")  // Automatically uses .success style

// Formatted text with alignment
let centered = FormattedText("Title", maxWidth: 40, alignment: .center)

// Multiline text with wrapping
let description = MultilineText(longText, maxWidth: 60)
```

### Layout Components

```swift
/// Vertical stack container
public struct VStack: Component {
    public init(spacing: Int32 = 0, @ComponentBuilder content: () -> [any Component])
    public init(spacing: Int32 = 0, children: [any Component])
}

/// Horizontal stack container
public struct HStack: Component {
    public init(spacing: Int32 = 1, @ComponentBuilder content: () -> [any Component])
    public init(spacing: Int32 = 1, children: [any Component])
}

/// Component that applies padding to child components
public struct Padded: Component {
    public init(_ child: any Component, padding: EdgeInsets)
    public init(_ child: any Component, padding: Int32)
}

/// Component that renders nothing (useful for conditional rendering)
public struct EmptyComponent: Component {
    public init()
}
```

**Example**:

```swift
// Vertical stack with spacing
let vstack = VStack(spacing: 1) {
    Text("Header").primaryBold()
    Text("Content").primary()
    Text("Footer").muted()
}

// Horizontal stack
let hstack = HStack(spacing: 2) {
    StatusIcon(status: "active")
    Text("Server Name")
    Text("10.0.0.1").muted()
}

// Padded content
let padded = Text("Padded Content").padding(2)
```

### ComponentBuilder

SwiftNCurses provides a result builder for declarative component composition:

```swift
@resultBuilder
public struct ComponentBuilder {
    public static func buildBlock(_ components: any Component...) -> [any Component]
    public static func buildBlock(_ component: any Component) -> any Component
    public static func buildOptional(_ component: (any Component)?) -> any Component
    public static func buildEither(first component: any Component) -> any Component
    public static func buildEither(second component: any Component) -> any Component
    public static func buildArray(_ components: [any Component]) -> [any Component]
}
```

**Example**:

```swift
// Conditional rendering
let content = VStack {
    Text("Title")
    if showDetails {
        Text("Details")
    }
    if isError {
        Text("Error").error()
    } else {
        Text("OK").success()
    }
}
```

### List Components

```swift
/// High-level list component with headers, scrolling, and selection
public struct ListView<Item: Sendable>: Component {
    public struct ListConfiguration: Sendable {
        public init(
            showHeaders: Bool = true,
            showBorder: Bool = true,
            title: String? = nil,
            headerStyle: TextStyle = .accent,
            separatorStyle: TextStyle = .secondary,
            selectionStyle: TextStyle = .primary,
            maxVisibleItems: Int? = nil
        )
    }

    public init(
        items: [Item],
        selectedIndex: Int? = nil,
        scrollOffset: Int = 0,
        configuration: ListConfiguration = .standard(),
        @ComponentBuilder rowRenderer: @escaping @Sendable (Item, Bool, Int) -> any Component
    )
}

/// Component that handles row selection styling
public struct SelectableRow: Component {
    public init(_ child: any Component, isSelected: Bool, style: TextStyle = .primary)
}

/// Standard list item with icon, text, and optional status
public struct ListItem: Component {
    public init(
        icon: (any Component)? = nil,
        text: String,
        status: (any Component)? = nil,
        style: TextStyle = .primary
    )
}

/// List item with fixed-width columns for table-like display
public struct TableListItem: Component {
    public struct TableColumn: Sendable {
        public init(content: any Component, width: Int32, alignment: FormattedText.TextAlignment = .leading)
        public init(text: String, width: Int32, style: TextStyle = .primary, alignment: FormattedText.TextAlignment = .leading)
    }

    public init(columns: [TableColumn])
}
```

**Example**:

```swift
struct Server {
    let name: String
    let status: String
    let ip: String
}

let servers: [Server] = [...]

let list = ListView(
    items: servers,
    selectedIndex: selectedIndex,
    scrollOffset: scrollOffset,
    configuration: ListView.ListConfiguration(
        title: "Servers",
        maxVisibleItems: 20
    )
) { server, isSelected, index in
    TableListItem(columns: [
        .init(text: server.name, width: 20),
        .init(content: StatusText(server.status), width: 10),
        .init(text: server.ip, width: 15, style: .muted)
    ])
}
```

### Virtual Scrolling

For large datasets, use `VirtualScrollView` for optimal performance:

```swift
/// High-performance virtual scrolling component for large datasets
public struct VirtualScrollView<Item: Sendable, ItemView: Component>: Component {
    public init(
        items: [Item],
        itemHeight: Int32 = 1,
        scrollOffset: Int = 0,
        selectedIndex: Int? = nil,
        renderItem: @escaping @Sendable (Item, Bool) -> ItemView
    )
}

/// Controller for managing virtual scrolling state and behavior
@MainActor
public final class VirtualListController {
    public var scrollOffset: Int
    public var selectedIndex: Int

    // Navigation methods
    public func moveUp()
    public func moveDown()
    public func pageUp(visibleItems: Int)
    public func pageDown(visibleItems: Int, totalItems: Int)
    public func moveToTop()
    public func moveToBottom(totalItems: Int)

    // Scroll management
    public func ensureVisible(index: Int, visibleItems: Int)
    public func adjustScroll(forTotalItems totalItems: Int, visibleItems: Int)
}
```

**Example**:

```swift
// For lists with 1000+ items
let virtualList = VirtualScrollView(
    items: largeDataset,
    itemHeight: 1,
    scrollOffset: controller.scrollOffset,
    selectedIndex: controller.selectedIndex
) { item, isSelected in
    TableListItem(columns: [
        .init(text: item.name, width: 30),
        .init(text: item.value, width: 20)
    ])
}

await SwiftNCurses.render(virtualList, on: surface, in: contentBounds)
```

### Status and Border Components

```swift
/// Status indicator component
public struct StatusIcon: Component {
    public init(
        status: String?,
        activeStates: [String] = ["active", "available"],
        errorStates: [String] = ["error", "fault"]
    )
}

/// Border component
public struct Border: Component {
    public init(
        title: String? = nil,
        style: TextStyle = .border,
        @ComponentBuilder content: () -> any Component
    )
}

/// Separator line component
public struct Separator: Component {
    public enum Direction: Sendable {
        case horizontal
        case vertical
    }

    public init(direction: Direction, style: TextStyle = .border)
}
```

## Input Handling

### KeyEvent Enum

```swift
/// Enhanced key events
public enum KeyEvent {
    case character(Character)
    case arrowUp, arrowDown, arrowLeft, arrowRight
    case pageUp, pageDown
    case home, end
    case enter, escape, space, backspace
    case functionKey(Int)
    case unknown(Int32)

    /// Check if this is a movement key
    public var isMovement: Bool

    /// Check if this is a navigation key
    public var isNavigation: Bool
}
```

### EnhancedInputManager

```swift
/// Enhanced input manager for improved user experience
@MainActor
public class EnhancedInputManager {
    public init()

    /// Get the next key with enhanced processing
    public func getNextKey() -> KeyEvent?
}
```

### Input Loop Pattern

```swift
let inputManager = EnhancedInputManager()
var running = true

while running {
    let key = SwiftNCurses.getInput(screen)

    switch key {
    case Int32(KEY_UP):
        controller.moveUp()

    case Int32(KEY_DOWN):
        controller.moveDown()

    case Int32(KEY_PPAGE):  // Page Up
        controller.pageUp(visibleItems: visibleCount)

    case Int32(KEY_NPAGE):  // Page Down
        controller.pageDown(visibleItems: visibleCount, totalItems: items.count)

    case 10, 13:  // Enter
        handleSelection()

    case 27:  // Escape
        handleBack()

    case Int32(Character("q").asciiValue!):
        running = false

    default:
        if key >= 32 && key <= 126 {
            handleCharacter(Character(UnicodeScalar(Int(key))!))
        }
    }

    // Re-render
    await renderScreen()
    SwiftNCurses.batchedRefresh(screen)
}
```

## Animation Support

```swift
/// Simple animation support for enhanced UX
@MainActor
public class AnimationManager {
    public init()

    /// Start a simple fade animation
    public func startFadeIn(id: String, duration: TimeInterval = 0.3)

    /// Start a slide animation
    public func startSlideIn(id: String, direction: Animation.Direction, duration: TimeInterval = 0.2)

    /// Get the current progress of an animation (0.0 to 1.0)
    public func getProgress(for id: String) -> Double

    /// Check if an animation is active
    public func isAnimating(_ id: String) -> Bool
}

public struct Animation: Sendable {
    public enum AnimationType: Sendable {
        case fadeIn
        case slide(Direction)
    }

    public enum Direction: Sendable {
        case left, right, up, down
    }
}
```

## Performance Optimization

### Render Buffering

SwiftNCurses uses a render buffer to minimize terminal I/O:

```swift
// Buffering is enabled by default
let surface = CursesSurface(window: screen.pointer, enableBuffering: true)

// Render multiple components (buffered)
await component1.render(on: surface, in: bounds1)
await component2.render(on: surface, in: bounds2)
await component3.render(on: surface, in: bounds3)

// Flush buffer to terminal (single I/O operation)
surface.flushBuffer()
```

### Batched Screen Updates

```swift
// PREFERRED: Batched refresh reduces syscalls
SwiftNCurses.batchedRefresh(screen)

// Alternative: Manual batching for complex updates
SwiftNCurses.wnoutrefresh(screen)  // Update virtual screen
// ... more wnoutrefresh calls ...
SwiftNCurses.doupdate()  // Single flush to terminal
```

### Virtual Scrolling Best Practices

```swift
// For large datasets (100+ items), always use VirtualScrollView
if items.count > 100 {
    // Only renders visible items
    let virtualList = VirtualScrollView(
        items: items,
        scrollOffset: offset,
        selectedIndex: selected
    ) { item, isSelected in
        renderRow(item, isSelected)
    }
}
```

### Memory Management

```swift
// Clear screen when switching views
SwiftNCurses.clearScreen(screen)

// Always cleanup on exit
defer { SwiftNCurses.cleanupTerminal() }

// Mark buffer dirty for full redraw after resize
surface.markBufferDirty()
```

## Best Practices

### 1. Initialize Once, Cleanup Always

```swift
let (screen, rows, cols, success) = SwiftNCurses.initializeTerminalSession()
guard success, let screen = screen else { return }
defer { SwiftNCurses.cleanupTerminal() }
```

### 2. Use Semantic Colors

```swift
// GOOD: Semantic colors
Text("Error").styled(.error)
Text("Success").styled(.success)

// AVOID: Direct color codes
// wattron(window, COLOR_PAIR(6))  // Magic numbers
```

### 3. Batch Screen Updates

```swift
// GOOD: Single refresh after all rendering
await component1.render(on: surface, in: bounds1)
await component2.render(on: surface, in: bounds2)
SwiftNCurses.batchedRefresh(screen)

// AVOID: Refresh after each component
```

### 4. Use Components, Not Direct Drawing

```swift
// GOOD: Component-based
let header = VStack {
    Text("Title").primaryBold()
    Separator(direction: .horizontal)
}
await SwiftNCurses.render(header, on: surface, in: headerBounds)

// AVOID: Direct ncurses calls
// wmove(window, 0, 0)
// waddstr(window, "Title")
```

### 5. Handle Terminal Resize

```swift
let newRows = SwiftNCurses.getMaxY(screen)
let newCols = SwiftNCurses.getMaxX(screen)

if newRows != currentRows || newCols != currentCols {
    currentRows = newRows
    currentCols = newCols
    surface.markBufferDirty()
    recalculateLayout()
}
```

## Migration from Direct NCurses

### Before (Direct NCurses)

```c
initscr();
start_color();
init_pair(1, COLOR_RED, COLOR_BLACK);
wattron(stdscr, COLOR_PAIR(1));
mvwprintw(stdscr, 0, 0, "Error!");
wattroff(stdscr, COLOR_PAIR(1));
refresh();
endwin();
```

### After (SwiftNCurses)

```swift
let (screen, _, _, success) = SwiftNCurses.initializeTerminalSession()
guard success, let screen = screen else { return }
defer { SwiftNCurses.cleanupTerminal() }

let surface = SwiftNCurses.surface(from: screen)
await SwiftNCurses.render(
    Text("Error!").error(),
    on: surface,
    in: Rect(x: 0, y: 0, width: 10, height: 1)
)
SwiftNCurses.batchedRefresh(screen)
```

---

**See Also**:

- [OSClient API](osclient.md) - OpenStack client library
- [MemoryKit API](memorykit.md) - Memory and cache management
- [Integration Guide](integration.md) - CrossPlatformTimer and integration examples
- [API Reference Index](index.md) - Quick reference and navigation
