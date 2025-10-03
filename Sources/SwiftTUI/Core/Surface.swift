import Foundation
import CNCurses

// MARK: - Surface Protocol

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

// MARK: - Curses Surface Implementation

/// Concrete implementation of Surface using ncurses
@MainActor public class CursesSurface: Surface, @unchecked Sendable {
    private let window: WindowHandle
    private let colorScheme: ColorScheme
    private var renderBuffer: RenderBuffer?
    private var bufferingEnabled: Bool = true

    @MainActor public init(window: OpaquePointer?, colorScheme: ColorScheme? = nil, enableBuffering: Bool = true) {
        self.window = WindowHandle(window)
        self.colorScheme = colorScheme ?? ColorScheme()
        self.bufferingEnabled = enableBuffering

        // Initialize render buffer with screen size
        let maxY = compatGetMaxY(WindowHandle(window))
        let maxX = compatGetMaxX(WindowHandle(window))
        if enableBuffering {
            self.renderBuffer = RenderBuffer(width: maxX, height: maxY, enabled: true)
        }
    }


    public var size: Size {
        let maxY = compatGetMaxY(window)
        let maxX = compatGetMaxX(window)
        return Size(width: maxX, height: maxY)
    }

    @MainActor public func draw(at position: Position, text: String, style: TextStyle? = nil) async {
        let effectiveStyle = style ?? .primary

        // Use render buffer if enabled
        if bufferingEnabled, let buffer = renderBuffer {
            buffer.write(at: position, text: text, style: effectiveStyle)
        } else {
            // Fallback to direct ncurses calls
            move(to: position)
            applyStyle(effectiveStyle)
            _ = compatWAddStr(window, text)
            removeStyle(effectiveStyle)
        }
    }

    @MainActor public func draw(at position: Position, character: Character, style: TextStyle? = nil) async {
        let effectiveStyle = style ?? .primary

        // Use render buffer if enabled
        if bufferingEnabled, let buffer = renderBuffer {
            buffer.write(at: position, character: character, style: effectiveStyle)
        } else {
            // Fallback to direct ncurses calls
            move(to: position)
            applyStyle(effectiveStyle)
            _ = compatWAddCh(window, UInt32(character.asciiValue ?? 32))
            removeStyle(effectiveStyle)
        }
    }

    @MainActor public func move(to position: Position) {
        _ = compatWMove(window, position.row, position.col)
    }

    @MainActor public func clear(rect: Rect) {
        for row in rect.origin.row..<(rect.origin.row + rect.size.height) {
            move(to: Position(row: row, col: rect.origin.col))
            for _ in 0..<rect.size.width {
                _ = compatWAddCh(window, UInt32(Character(" ").asciiValue!))
            }
        }
    }

    @MainActor public func clearToEndOfLine() {
        _ = compatWClrToEol(window)
    }

    // MARK: - Style Application

    @MainActor private func applyStyle(_ style: TextStyle) {
        let colorPair = colorScheme.colorPair(for: style.color)
        let attributes = style.attributes.ncursesValue

        _ = compatWAttrOn(window, colorPair)
        if attributes != 0 {
            _ = compatWAttrOn(window, attributes)
        }
    }

    @MainActor private func removeStyle(_ style: TextStyle) {
        let colorPair = colorScheme.colorPair(for: style.color)
        let attributes = style.attributes.ncursesValue

        _ = compatWAttrOff(window, colorPair)
        if attributes != 0 {
            _ = compatWAttrOff(window, attributes)
        }
    }

    @MainActor public func context(for bounds: Rect) -> DrawingContext {
        return DrawingContext(surface: self, bounds: bounds)
    }

    // MARK: - Render Buffer Control

    /// Flush the render buffer to screen
    @MainActor public func flushBuffer() {
        if bufferingEnabled, let buffer = renderBuffer {
            buffer.flush(to: window, colorScheme: colorScheme)
        }
    }

    /// Enable or disable render buffering
    @MainActor public func setBufferingEnabled(_ enabled: Bool) {
        bufferingEnabled = enabled
        renderBuffer?.setEnabled(enabled)
    }

    /// Mark all buffer cells as dirty for full redraw
    @MainActor public func markBufferDirty() {
        renderBuffer?.markAllDirty()
    }

    @MainActor public func getStringInput(at position: Position, prompt: String, maxLength: Int) -> String? {
        // Enable echo mode temporarily
        _ = compatEcho()
        _ = compatNodelay(window, false)
        defer {
            _ = compatNoEcho()
            _ = compatNodelay(window, true)
        }

        // Clear the input area
        move(to: position)
        clearToEndOfLine()

        // Show prompt with secondary styling
        applyStyle(.secondary)
        _ = compatWAddStr(window, prompt)
        removeStyle(.secondary)

        // Get input
        let buf = UnsafeMutablePointer<CChar>.allocate(capacity: maxLength + 1)
        defer { buf.deallocate() }
        _ = compatWGetNStr(window, buf, Int32(maxLength))

        // Clear the line after input
        move(to: position)
        clearToEndOfLine()

        let input = String(cString: buf)
        return input.isEmpty ? nil : input
    }

    @MainActor public func getCharacterInput() -> Character? {
        _ = compatNodelay(window, false)
        defer {
            _ = compatNodelay(window, true)
        }

        let ch = compatWGetCh(window)
        guard ch >= 0 else { return nil }

        return Character(UnicodeScalar(Int(ch)) ?? UnicodeScalar(32)!)
    }
}

// MARK: - Surface Extensions

extension Surface {
    /// Draw text with default primary style
    @MainActor public func draw(at position: Position, text: String) async {
        await draw(at: position, text: text, style: .primary)
    }

    /// Fill a rectangle with a character
    @MainActor public func fill(rect: Rect, character: Character = " ", style: TextStyle? = nil) async {
        for row in rect.origin.row..<(rect.origin.row + rect.size.height) {
            for col in rect.origin.col..<(rect.origin.col + rect.size.width) {
                await draw(at: Position(row: row, col: col), character: character, style: style)
            }
        }
    }

    /// Draw a horizontal line
    @MainActor public func drawHorizontalLine(at row: Int32, from startCol: Int32, to endCol: Int32,
                                  character: Character = "-", style: TextStyle? = nil) async {
        for col in startCol...endCol {
            await draw(at: Position(row: row, col: col), character: character, style: style)
        }
    }

    /// Draw a vertical line
    @MainActor public func drawVerticalLine(at col: Int32, from startRow: Int32, to endRow: Int32,
                                character: Character = "|", style: TextStyle? = nil) async {
        for row in startRow...endRow {
            await draw(at: Position(row: row, col: col), character: character, style: style)
        }
    }
}

