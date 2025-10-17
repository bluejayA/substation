import Foundation
import CNCurses
import MemoryKit

// MARK: - Drawing Context

/// Provides a drawing context for components with surface and bounds information
public struct DrawingContext: Sendable {
    public let surface: any Surface
    public let bounds: Rect

    public init(surface: any Surface, bounds: Rect) {
        self.surface = surface
        self.bounds = bounds
    }

    /// Create a sub-context with adjusted bounds
    public func subContext(rect: Rect) -> DrawingContext {
        let adjustedRect = Rect(
            origin: Position(
                row: bounds.origin.row + rect.origin.row,
                col: bounds.origin.col + rect.origin.col
            ),
            size: Size(
                width: min(rect.size.width, bounds.size.width - rect.origin.col),
                height: min(rect.size.height, bounds.size.height - rect.origin.row)
            )
        )
        return DrawingContext(surface: surface, bounds: adjustedRect)
    }

    /// Check if a position is within the context bounds
    public func contains(_ position: Position) -> Bool {
        return bounds.contains(position)
    }

    /// Get the absolute position for a relative position within this context
    public func absolutePosition(for relativePosition: Position) -> Position {
        return Position(
            row: bounds.origin.row + relativePosition.row,
            col: bounds.origin.col + relativePosition.col
        )
    }

    /// Draw text at a position with style
    @MainActor
    public func draw(at position: Position, text: String, style: TextStyle? = nil) async {
        let absolutePosition = absolutePosition(for: position)
        guard bounds.contains(absolutePosition) else { return }

        await surface.draw(at: absolutePosition, text: text, style: style)
    }

    /// Draw a border around the context bounds with optional title
    @MainActor
    public func drawBorder(style: TextStyle = .border, title: String? = nil) async {
        let topRow = bounds.origin.row
        let bottomRow = bounds.origin.row + bounds.size.height - 1
        let leftCol = bounds.origin.col
        let rightCol = bounds.origin.col + bounds.size.width - 1

        // OPTIMIZED: Build horizontal line as single string instead of character-by-character
        let horizontalLineWidth = Int(rightCol - leftCol - 1)
        let horizontalLine = String(repeating: "-", count: max(0, horizontalLineWidth))

        // Draw top border: corner + line + corner
        await surface.draw(at: Position(row: topRow, col: leftCol), text: "+", style: style)
        if !horizontalLine.isEmpty {
            await surface.draw(at: Position(row: topRow, col: leftCol + 1), text: horizontalLine, style: style)
        }
        await surface.draw(at: Position(row: topRow, col: rightCol), text: "+", style: style)

        // Draw vertical lines (still need loops but optimized to single character writes)
        for row in (topRow + 1)..<bottomRow {
            await surface.draw(at: Position(row: row, col: leftCol), text: "|", style: style)
            await surface.draw(at: Position(row: row, col: rightCol), text: "|", style: style)
        }

        // Draw bottom border: corner + line + corner
        await surface.draw(at: Position(row: bottomRow, col: leftCol), text: "+", style: style)
        if !horizontalLine.isEmpty {
            await surface.draw(at: Position(row: bottomRow, col: leftCol + 1), text: horizontalLine, style: style)
        }
        await surface.draw(at: Position(row: bottomRow, col: rightCol), text: "+", style: style)

        // Draw title if provided
        if let title = title, title.count + 4 < bounds.size.width {
            let titleText = "[ \(title) ]"
            let titleStart = leftCol + 2
            await surface.draw(at: Position(row: topRow, col: titleStart), text: titleText, style: .secondary)
        }
    }
}


// MARK: - Input Handling Enhancement

/// Enhanced input manager for improved user experience
@MainActor
public class EnhancedInputManager {
    private var keyBuffer: [Int32] = []
    private var lastKeyTime = Date()
    private let keyBufferTimeout: TimeInterval = 0.5

    public init() {}

    /// Get the next key with enhanced processing
    public func getNextKey() -> KeyEvent? {
        let key = getch()
        guard key != ERR else { return nil }

        // Clear old keys from buffer
        clearOldKeys()

        // Add new key to buffer
        keyBuffer.append(key)
        lastKeyTime = Date()

        // Try to recognize key sequences
        if let keyEvent = recognizeKeySequence() {
            keyBuffer.removeAll()
            return keyEvent
        }

        return nil
    }

    private func clearOldKeys() {
        let now = Date()
        if now.timeIntervalSince(lastKeyTime) > keyBufferTimeout {
            keyBuffer.removeAll()
        }
    }

    private func recognizeKeySequence() -> KeyEvent? {
        guard !keyBuffer.isEmpty else { return nil }

        let key = keyBuffer.last!

        // Handle basic keys
        switch key {
        case 27: // ESC
            return .escape
        case 10, 13: // Enter/Return
            return .enter
        case 32: // Space
            return .space
        case 127, 8: // Backspace/Delete
            return .backspace
        case Int32(Character("q").asciiValue!):
            return .character("q")
        case Int32(Character("Q").asciiValue!):
            return .character("Q")
        case KEY_UP:
            return .arrowUp
        case KEY_DOWN:
            return .arrowDown
        case KEY_LEFT:
            return .arrowLeft
        case KEY_RIGHT:
            return .arrowRight
        case KEY_PPAGE:
            return .pageUp
        case KEY_NPAGE:
            return .pageDown
        case KEY_HOME:
            return .home
        case KEY_END:
            return .end
        default:
            if key >= 32 && key <= 126 {
                return .character(Character(UnicodeScalar(Int(key))!))
            }
            return .unknown(key)
        }
    }
}

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
    public var isMovement: Bool {
        switch self {
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight, .pageUp, .pageDown, .home, .end:
            return true
        default:
            return false
        }
    }

    /// Check if this is a navigation key
    public var isNavigation: Bool {
        switch self {
        case .enter, .escape, .space, .backspace:
            return true
        default:
            return isMovement
        }
    }
}

// MARK: - Color Management

/// Enhanced color management for better visual experience
/// Note: Color pair initialization is now handled by SwiftNCurses.ColorScheme
public struct ColorManager: Sendable {
    public static let shared = ColorManager()

    private init() {}

    /// Get a color pair ID for a given style
    public func getColorPair(for style: TextStyle) -> Int32 {
        return style.color.colorPairIndex
    }
}

// MARK: - Animation Support

/// Simple animation support for enhanced UX
@MainActor
public class AnimationManager: @unchecked Sendable {
    private var activeAnimations: [String: Animation] = [:]
    private let memoryManager: SwiftNCursesMemoryManager

    public init() {
        self.memoryManager = SwiftNCursesLoggerConfig.shared.createMemoryManager()
    }

    /// Start a simple fade animation
    public func startFadeIn(id: String, duration: TimeInterval = 0.3) {
        let animation = Animation(
            id: id,
            duration: duration,
            type: .fadeIn,
            startTime: Date()
        )
        activeAnimations[id] = animation

        // Cache animation state
        Task {
            await cacheAnimation(animation)
        }
    }

    /// Start a slide animation
    public func startSlideIn(id: String, direction: Animation.Direction, duration: TimeInterval = 0.2) {
        let animation = Animation(
            id: id,
            duration: duration,
            type: .slide(direction),
            startTime: Date()
        )
        activeAnimations[id] = animation
    }

    /// Get the current progress of an animation (0.0 to 1.0)
    public func getProgress(for id: String) -> Double {
        guard let animation = activeAnimations[id] else { return 1.0 }

        let elapsed = Date().timeIntervalSince(animation.startTime)
        let progress = min(elapsed / animation.duration, 1.0)

        if progress >= 1.0 {
            activeAnimations.removeValue(forKey: id)
        }

        return progress
    }

    /// Check if an animation is active
    public func isAnimating(_ id: String) -> Bool {
        return activeAnimations[id] != nil
    }

    // MARK: - MemoryKit Cache Operations

    /// Cache animation state
    private func cacheAnimation(_ animation: Animation) async {
        let animationType = switch animation.type {
        case .fadeIn: "fadeIn"
        case .slide(let direction): "slide_\(direction)"
        }

        let animationState = AnimationState(
            animationId: animation.id,
            startTime: animation.startTime,
            duration: animation.duration,
            currentProgress: 0.0,
            animationType: animationType,
            isCompleted: false
        )

        await memoryManager.cacheAnimationState(animationState, forKey: animation.id)
    }

    /// Clear animation from cache
    private func clearAnimationCache(id: String) async {
        await memoryManager.clearCache(type: .animations)
    }

    /// Restore animations from cache
    public func restoreAnimationsFromCache() async {
        // Clear expired animations first
        await memoryManager.clearExpiredAnimations()
    }

    /// Clear all animation caches
    public func clearAllAnimationCaches() async {
        await memoryManager.clearCache(type: .animations)
    }
}

public struct Animation: Sendable {
    let id: String
    let duration: TimeInterval
    let type: AnimationType
    let startTime: Date

    public enum AnimationType: Sendable {
        case fadeIn
        case slide(Direction)
    }

    public enum Direction: Sendable {
        case left, right, up, down
    }
}