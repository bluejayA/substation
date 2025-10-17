import Foundation
import CNCurses
import CrossPlatformTimer

// MARK: - SwiftNCurses Main Interface

/// Terminal error constant equivalent to ncurses ERR
public let TUI_ERR: Int32 = -1

/// Main interface for the SwiftNCurses library
public struct SwiftNCurses {
    /// Initialize SwiftNCurses with ncurses
    @MainActor public static func initialize(colorScheme: ColorScheme? = nil) {
        let scheme = colorScheme ?? ColorScheme.shared
        scheme.initialize()
    }

    /// Initialize terminal colors and cursor settings (replaces color init sequence)
    @MainActor public static func initializeTerminal(colorScheme: ColorScheme? = nil) -> Bool {
        // Hide cursor
        if curs_set(0) == ERR {
            return false
        }

        // Disable mouse reporting
        mousemask(0, nil)

        // Initialize colors using SwiftNCurses color scheme
        guard has_colors() else { return false }

        let scheme = colorScheme ?? ColorScheme.shared
        scheme.initialize()

        return true
    }

    /// Create a drawing surface from an ncurses window
    @MainActor public static func surface(from window: OpaquePointer?) -> CursesSurface {
        return CursesSurface(window: window)
    }

    /// Create a drawing surface from a WindowHandle
    @MainActor public static func surface(from window: WindowHandle) -> CursesSurface {
        return CursesSurface(window: window.pointer)
    }

    /// Render a component to a surface
    @MainActor public static func render(
        _ component: any Component,
        on surface: any Surface,
        in rect: Rect? = nil
    ) async {
        let renderRect = rect ?? Rect(origin: .zero, size: surface.size)
        let startTime = Date().timeIntervalSinceReferenceDate
        await component.render(on: surface, in: renderRect)

        // CRITICAL: Flush render buffer after component tree traversal
        if let cursesSurface = surface as? CursesSurface {
            cursesSurface.flushBuffer()
        }

        let duration = Date().timeIntervalSinceReferenceDate - startTime
        if duration > 0.050 { // Log slow renders (>50ms)
            SwiftNCursesLoggerConfig.shared.logger.logWarning("SwiftNCurses: Slow render detected", context: [
                "duration_ms": Int(duration * 1000),
                "component": String(describing: type(of: component))
            ])
        }
    }
}

// MARK: - Extensions for convenience

extension Text {
    /// Quick text creation with primary style
    public static func primary(_ content: String) -> Text {
        return Text(content, style: .primary)
    }

    /// Quick text creation with accent style
    public static func accent(_ content: String) -> Text {
        return Text(content, style: .accent)
    }
}

// MARK: - Cross-Platform Timer Management

/// Cross-platform timer abstraction for async contexts
extension SwiftNCurses {
    /// Create a repeating timer that works in async contexts
    @MainActor
    public static func createRepeatingTimer(
        interval: TimeInterval,
        tolerance: TimeInterval = 0.1,
        action: @escaping () -> Void
    ) -> Task<Void, Never> {
        return Task { @MainActor in
            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Create a one-shot timer that works in async contexts
    @MainActor
    public static func createOneShotTimer(
        delay: TimeInterval,
        action: @escaping () -> Void
    ) -> Task<Void, Never> {
        return Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                action()
            }
        }
    }

}


// MARK: - Terminal Initialization and Management

/// Comprehensive terminal management to replace direct ncurses calls
extension SwiftNCurses {
    /// Initialize terminal screen (replaces initscr())
    @MainActor public static func initializeScreen() -> WindowHandle? {
        guard let screen = initscr() else { return nil }
        return WindowHandle(screen)
    }

    /// Cleanup terminal (replaces endwin())
    @MainActor public static func cleanupTerminal() {
        SwiftNCursesLoggerConfig.shared.logger.logDebug("SwiftNCurses: Cleaning up terminal", context: [:])
        endwin()
        SwiftNCursesLoggerConfig.shared.logger.logInfo("SwiftNCurses: Terminal cleanup complete", context: [:])
    }

    /// Set terminal to cbreak mode (replaces cbreak())
    @MainActor public static func setCBreakMode() -> Int32 {
        return cbreak()
    }

    /// Disable character echo (replaces noecho())
    @MainActor public static func disableEcho() -> Int32 {
        return noecho()
    }

    /// Enable keypad for special keys (replaces keypad())
    @MainActor public static func enableKeypad(_ window: WindowHandle, _ enable: Bool) -> Int32 {
        return compatKeypad(window, enable)
    }

    /// Set nodelay mode for non-blocking input (replaces nodelay())
    @MainActor public static func setNodelay(_ window: WindowHandle, _ enable: Bool) -> Int32 {
        return compatNodelay(window, enable)
    }

    /// Set cursor visibility (replaces curs_set())
    @MainActor public static func setCursorVisibility(_ visibility: Int32) -> Int32 {
        return curs_set(visibility)
    }

    /// Check if terminal supports colors (replaces has_colors())
    @MainActor public static func hasColors() -> Bool {
        return has_colors()
    }

    /// Initialize color system (replaces start_color())
    @MainActor public static func startColor() -> Int32 {
        return start_color()
    }

    /// Use default colors (replaces use_default_colors())
    @MainActor public static func useDefaultColors() -> Int32 {
        return use_default_colors()
    }

    /// Set mouse mask (replaces mousemask())
    @MainActor public static func setMouseMask(_ newmask: UInt32, _ oldmask: UnsafeMutablePointer<UInt32>?) -> UInt32 {
        var oldmask_mmask: mmask_t = 0
        let result = mousemask(mmask_t(newmask), &oldmask_mmask)
        oldmask?.pointee = UInt32(oldmask_mmask)
        return UInt32(result)
    }

    /// Get maximum Y coordinate (replaces getmaxy())
    @MainActor public static func getMaxY(_ window: WindowHandle) -> Int32 {
        return compatGetMaxY(window)
    }

    /// Get maximum X coordinate (replaces getmaxx())
    @MainActor public static func getMaxX(_ window: WindowHandle) -> Int32 {
        return compatGetMaxX(window)
    }

    /// Disable mouse tracking sequences
    @MainActor public static func disableMouseTracking() {
        print("\u{001B}[?1000l", terminator: "")
        print("\u{001B}[?1002l", terminator: "")
        print("\u{001B}[?1003l", terminator: "")
        print("\u{001B}[?1006l", terminator: "")
        print("\u{001B}[?1015l", terminator: "")
        try? FileHandle.standardOutput.synchronize()
    }

    /// Complete terminal initialization sequence
    @MainActor public static func initializeTerminalSession() -> (screen: WindowHandle?, rows: Int32, cols: Int32, success: Bool) {
        SwiftNCursesLoggerConfig.shared.logger.logDebug("SwiftNCurses: Initializing terminal session", context: [:])

        // Set TERM if not set
        if getenv("TERM") == nil {
            SwiftNCursesLoggerConfig.shared.logger.logDebug("SwiftNCurses: TERM not set, defaulting to xterm", context: [:])
            setenv("TERM", "xterm", 1)
        }

        guard let screen = initializeScreen() else {
            SwiftNCursesLoggerConfig.shared.logger.logError("SwiftNCurses: Failed to initialize screen", context: [:])
            return (nil, 0, 0, false)
        }

        SwiftNCursesLoggerConfig.shared.logger.logDebug("SwiftNCurses: Screen initialized successfully", context: [:])

        // Setup terminal modes
        // Use nodelay + cbreak for true non-blocking I/O (prevents rt_sigsuspend on Linux)
        // This allows our Swift adaptive polling loop to control CPU usage efficiently
        guard disableEcho() != TUI_ERR,
              setCBreakMode() != TUI_ERR,
              enableKeypad(screen, true) != TUI_ERR,
              setNodelay(screen, true) != TUI_ERR else {
            SwiftNCursesLoggerConfig.shared.logger.logError("SwiftNCurses: Failed to setup terminal modes", context: [:])
            cleanupTerminal()
            return (nil, 0, 0, false)
        }

        SwiftNCursesLoggerConfig.shared.logger.logDebug("SwiftNCurses: Terminal modes configured", context: [:])

        // Hide cursor
        let _ = setCursorVisibility(0)

        // Disable mouse
        let _ = setMouseMask(0, nil)
        disableMouseTracking()

        // Initialize colors if supported
        if hasColors() {
            SwiftNCursesLoggerConfig.shared.logger.logDebug("SwiftNCurses: Color support detected, initializing colors", context: [:])
            if startColor() != TUI_ERR {
                let _ = useDefaultColors()
                initialize()
                SwiftNCursesLoggerConfig.shared.logger.logDebug("SwiftNCurses: Colors initialized successfully", context: [:])
            } else {
                SwiftNCursesLoggerConfig.shared.logger.logWarning("SwiftNCurses: Failed to start color system", context: [:])
            }
        } else {
            SwiftNCursesLoggerConfig.shared.logger.logWarning("SwiftNCurses: Terminal does not support colors", context: [:])
        }

        let rows = getMaxY(screen)
        let cols = getMaxX(screen)

        SwiftNCursesLoggerConfig.shared.logger.logInfo("SwiftNCurses: Terminal session initialized successfully", context: [
            "rows": rows,
            "cols": cols
        ])

        return (screen, rows, cols, true)
    }
}

// MARK: - Screen Management Operations

/// Comprehensive screen management to replace CNCurses operations
extension SwiftNCurses {
    /// Clear entire screen (replaces clear(), werase())
    @MainActor public static func clearScreen(_ window: WindowHandle) {
        _ = compatWErase(window)
    }

    /// Refresh screen (replaces refresh(), wrefresh())
    @MainActor public static func refreshScreen(_ window: WindowHandle) {
        _ = compatWRefresh(window)
    }

    /// Clear to end of line (replaces wclrtoeol())
    @MainActor public static func clearToEndOfLine(_ window: WindowHandle) {
        _ = compatWClrToEol(window)
    }

    /// Move cursor to position (replaces wmove())
    @MainActor public static func moveCursor(_ window: WindowHandle, to position: Point) {
        _ = compatWMove(window, position.y, position.x)
    }

    /// Set input delay mode (replaces nodelay())
    @MainActor public static func setInputDelay(_ window: WindowHandle, enabled: Bool) {
        _ = compatNodelay(window, enabled)
    }

    /// Get character input (replaces wgetch())
    @MainActor public static func getInput(_ window: WindowHandle) -> Int32 {
        return compatWGetCh(window)
    }

    /// Refresh screen (replaces wrefresh())
    @MainActor public static func refresh(_ window: WindowHandle) {
        _ = compatWRefresh(window)
    }

    /// Update virtual screen without flushing to terminal (replaces wnoutrefresh())
    /// Use this followed by doupdate() to batch screen updates and reduce syscalls
    @MainActor public static func wnoutrefresh(_ window: WindowHandle) {
        _ = compatWnoutrefresh(window)
    }

    /// Flush all pending screen updates to terminal (replaces doupdate())
    /// Call this once after all wnoutrefresh() calls to batch terminal writes
    @MainActor public static func doupdate() {
        _ = compatDoupdate()
    }

    /// Batched screen update - preferred over refresh()
    /// Updates virtual screen then flushes to terminal in one syscall
    /// This reduces CPU usage by batching all writes instead of flushing after each draw operation
    @MainActor public static func batchedRefresh(_ window: WindowHandle) {
        wnoutrefresh(window)
        doupdate()
    }

    /// Clear screen (replaces wclear())
    @MainActor public static func clear(_ window: WindowHandle) {
        _ = compatWClear(window)
    }

    /// Wait for any input (convenience method)
    @MainActor public static func waitForInput(_ window: WindowHandle) {
        _ = compatWGetCh(window)
    }

    /// Draw styled text at position (replaces wmove/wattron/waddstr/wattroff pattern)
    @MainActor public static func drawStyledText(
        _ window: WindowHandle,
        at position: Position,
        text: String,
        colorPair: Int32
    ) {
        _ = compatWMove(window, position.row, position.col)
        _ = compatWAttrOn(window, colorPair)
        _ = compatWAddStr(window, text)
        _ = compatWAttrOff(window, colorPair)
    }

    /// Draw styled text using semantic color
    @MainActor public static func drawStyledText(
        _ window: WindowHandle,
        at position: Position,
        text: String,
        color: Color
    ) {
        drawStyledText(window, at: position, text: text, colorPair: colorPair(for: color))
    }

    /// Get color pair for semantic color
    @MainActor public static func colorPair(for color: Color) -> Int32 {
        return ColorScheme.shared.colorPair(for: color)
    }

    /// Draw styled text using SwiftNCurses semantic color
    @MainActor public static func drawStyledText(
        _ window: WindowHandle,
        at position: Position,
        text: String,
        style: TextStyle
    ) {
        let surface = CursesSurface(window: window.pointer)
        Task {
            await surface.draw(at: position, text: text, style: style)
        }
    }

    // MARK: - Semantic Color Helpers

    /// Get color pair for semantic color types
    @MainActor public static func primaryColor() -> Int32 { colorPair(for: .primary) }
    @MainActor public static func secondaryColor() -> Int32 { colorPair(for: .secondary) }
    @MainActor public static func accentColor() -> Int32 { colorPair(for: .accent) }
    @MainActor public static func warningColor() -> Int32 { colorPair(for: .warning) }
    @MainActor public static func successColor() -> Int32 { colorPair(for: .success) }
    @MainActor public static func infoColor() -> Int32 { colorPair(for: .info) }
    @MainActor public static func errorColor() -> Int32 { colorPair(for: .error) }
    @MainActor public static func borderColor() -> Int32 { colorPair(for: .border) }
    @MainActor public static func mutedColor() -> Int32 { colorPair(for: .muted) }
    @MainActor public static func emphasisColor() -> Int32 { colorPair(for: .emphasis) }
    @MainActor public static func invertedColor() -> Int32 { 9 << 8 } // Special inverted color


    /// Clear specific area (replaces BaseViewComponents.clearArea)
    @MainActor public static func clearArea(
        _ window: WindowHandle,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) {
        let _ = SwiftNCurses.surface(from: window)
        let _ = Rect(x: startCol, y: startRow, width: width, height: height)
        // Clear by filling with spaces
        for row in startRow..<(startRow + height) {
            _ = compatWMove(window, row, startCol)
            for _ in 0..<width {
                _ = compatWAddStr(window, " ")
            }
        }
    }
}

// MARK: - Migration Helpers

/// Helper functions to ease migration from existing ViewUtils patterns
extension SwiftNCurses {
    /// Migrate from ViewUtils.colorPair pattern
    @MainActor public static func migrateColoredText(
        text: String,
        colorPair: Int32,
        surface: any Surface,
        at position: Position
    ) async {
        let style = styleFromColorPair(colorPair)
        await Text(text).styled(style).render(on: surface, in: Rect(origin: position, size: Size(width: Int32(text.count), height: 1)))
    }

    private static func styleFromColorPair(_ colorPair: Int32) -> TextStyle {
        switch colorPair {
        case 1: return .primary
        case 2: return .secondary
        case 3: return .accent
        case 4: return .info
        case 5: return .success
        case 6: return .primary
        case 7: return .error
        default: return .primary
        }
    }

    /// Helper to migrate status icon patterns
    @MainActor public static func migrateStatusIcon(
        status: String?,
        activeStates: [String] = ["active", "available"],
        errorStates: [String] = ["error", "fault"],
        surface: any Surface,
        at position: Position
    ) async {
        await StatusIcon(status: status, activeStates: activeStates, errorStates: errorStates)
            .render(on: surface, in: Rect(origin: position, size: Size(width: 3, height: 1)))
    }
}
