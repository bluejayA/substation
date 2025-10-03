import Foundation
import CNCurses

// MARK: - Render Buffer

/// High-performance render buffer that batches ncurses calls
/// Reduces 2000+ individual ncurses calls to ~200 by buffering operations
@MainActor
public class RenderBuffer {

    // MARK: - Cell Structure

    struct Cell: Equatable {
        var character: Character
        var style: TextStyle
        var dirty: Bool

        init(character: Character = " ", style: TextStyle = .primary, dirty: Bool = false) {
            self.character = character
            self.style = style
            self.dirty = dirty
        }
    }

    // MARK: - Properties

    private var cells: [[Cell]]
    private let width: Int32
    private let height: Int32
    private var enabled: Bool

    // MARK: - Initialization

    public init(width: Int32, height: Int32, enabled: Bool = true) {
        self.width = width
        self.height = height
        self.enabled = enabled

        // Initialize buffer with blank cells
        self.cells = Array(repeating: Array(repeating: Cell(), count: Int(width)), count: Int(height))
    }

    // MARK: - Public Interface

    /// Write text to buffer at specified position
    public func write(at position: Position, text: String, style: TextStyle) {
        guard enabled else { return }
        guard position.row >= 0 && position.row < height else { return }
        guard position.col >= 0 && position.col < width else { return }

        var col = position.col
        for character in text {
            guard col < width else { break }

            let row = Int(position.row)
            let colIndex = Int(col)

            // Only mark dirty if actually changed
            let currentCell = cells[row][colIndex]
            if currentCell.character != character || currentCell.style != style {
                cells[row][colIndex] = Cell(character: character, style: style, dirty: true)
            }

            col += 1
        }
    }

    /// Write single character to buffer
    public func write(at position: Position, character: Character, style: TextStyle) {
        guard enabled else { return }
        guard position.row >= 0 && position.row < height else { return }
        guard position.col >= 0 && position.col < width else { return }

        let row = Int(position.row)
        let col = Int(position.col)

        // Only mark dirty if actually changed
        let currentCell = cells[row][col]
        if currentCell.character != character || currentCell.style != style {
            cells[row][col] = Cell(character: character, style: style, dirty: true)
        }
    }

    /// Clear a rectangular region
    public func clear(rect: Rect) {
        guard enabled else { return }

        for row in rect.origin.row..<(rect.origin.row + rect.size.height) {
            guard row >= 0 && row < height else { continue }

            for col in rect.origin.col..<(rect.origin.col + rect.size.width) {
                guard col >= 0 && col < width else { continue }

                let rowIndex = Int(row)
                let colIndex = Int(col)
                cells[rowIndex][colIndex] = Cell(character: " ", style: .primary, dirty: true)
            }
        }
    }

    /// Flush buffer to ncurses window - this is where optimization happens
    public func flush(to window: WindowHandle, colorScheme: ColorScheme) {
        guard enabled else { return }

        var currentStyle: TextStyle? = nil

        for row in 0..<Int(height) {
            var col = 0

            while col < Int(width) {
                let cell = cells[row][col]

                // Skip non-dirty cells for maximum performance
                guard cell.dirty else {
                    col += 1
                    continue
                }

                // Collect consecutive cells with same style for batch writing
                var text = String(cell.character)
                var endCol = col + 1

                while endCol < Int(width) {
                    let nextCell = cells[row][endCol]
                    if !nextCell.dirty || nextCell.style != cell.style {
                        break
                    }
                    text.append(nextCell.character)
                    endCol += 1
                }

                // Move cursor
                _ = compatWMove(window, Int32(row), Int32(col))

                // Apply style only if different from current
                if currentStyle != cell.style {
                    if let prevStyle = currentStyle {
                        removeStyle(prevStyle, from: window, colorScheme: colorScheme)
                    }
                    applyStyle(cell.style, to: window, colorScheme: colorScheme)
                    currentStyle = cell.style
                }

                // Write the batched text
                _ = compatWAddStr(window, text)

                // Mark cells as clean
                for c in col..<endCol {
                    cells[row][c].dirty = false
                }

                col = endCol
            }
        }

        // Remove final style
        if let style = currentStyle {
            removeStyle(style, from: window, colorScheme: colorScheme)
        }
    }

    /// Enable or disable buffering
    public func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }

    /// Clear all dirty flags without clearing content
    public func markClean() {
        for row in 0..<Int(height) {
            for col in 0..<Int(width) {
                cells[row][col].dirty = false
            }
        }
    }

    /// Mark all cells as dirty (force full redraw)
    public func markAllDirty() {
        for row in 0..<Int(height) {
            for col in 0..<Int(width) {
                cells[row][col].dirty = true
            }
        }
    }

    // MARK: - Private Helpers

    private func applyStyle(_ style: TextStyle, to window: WindowHandle, colorScheme: ColorScheme) {
        let colorPair = colorScheme.colorPair(for: style.color)
        let attributes = style.attributes.ncursesValue

        _ = compatWAttrOn(window, colorPair)
        if attributes != 0 {
            _ = compatWAttrOn(window, attributes)
        }
    }

    private func removeStyle(_ style: TextStyle, from window: WindowHandle, colorScheme: ColorScheme) {
        let colorPair = colorScheme.colorPair(for: style.color)
        let attributes = style.attributes.ncursesValue

        _ = compatWAttrOff(window, colorPair)
        if attributes != 0 {
            _ = compatWAttrOff(window, attributes)
        }
    }
}
