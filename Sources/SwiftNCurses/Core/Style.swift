import Foundation
import CNCurses

// MARK: - Modern Color System (2024)

/**
 * GitHub-Inspired Color Scheme based on Primer Design System (2024)
 *
 * This color system emphasizes:
 * - Professional, accessible colors following GitHub's design principles
 * - Excellent contrast ratios for accessibility compliance
 * - Clear visual hierarchy through semantic color roles
 * - Modern, clean aesthetic suitable for development tools
 *
 * Color Palette (GitHub Primer-inspired):
 * - Primary (Blue): GitHub's signature blue for branding and links
 * - Secondary (Gray): Professional secondary text and highlights
 * - Accent (White on Blue): GitHub-style selection and focus states
 * - Success (Green): GitHub's success green for positive states
 * - Warning (Orange): Attention-grabbing orange for warnings
 * - Error (Red): GitHub's error red for critical states
 * - Info (Gray): Clean readable text for information
 * - Border (Light Gray): Subtle borders and structural elements
 * - Muted (Medium Gray): Subdued secondary information
 * - Emphasis (Dark Gray on Light): Strong emphasis for important text
 */

/// Semantic color types for consistent theming
public enum Color: CaseIterable, Sendable {
    case primary      // Main text/content
    case secondary    // Supporting text
    case accent       // Highlights/selections
    case success      // Positive states (active, available)
    case warning      // Caution states
    case error        // Error states
    case info         // Information/neutral
    case background   // Background color
    case border       // Borders and separators
    case muted        // Subdued text/secondary information
    case emphasis     // Strong emphasis/important text

    /// Maps semantic colors to ncurses color pair indices
    public var colorPairIndex: Int32 {
        switch self {
        case .primary: return 1        // Main content text
        case .secondary: return 2      // Supporting/highlighted text
        case .accent: return 3         // Selected items/accent
        case .success: return 4        // Success states/active
        case .warning: return 5        // Warning states
        case .error: return 6          // Error states
        case .info: return 7           // Information/neutral
        case .background: return 0     // Default background
        case .border: return 8         // Borders and structure
        case .muted: return 8          // Subdued text
        case .emphasis: return 11      // Strong emphasis
        }
    }
}

/// Text attributes for styling
public struct TextAttributes: OptionSet, Hashable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let normal    = TextAttributes([])
    public static let bold      = TextAttributes(rawValue: 1 << 0)
    public static let dim       = TextAttributes(rawValue: 1 << 1)
    public static let reverse   = TextAttributes(rawValue: 1 << 2)
    public static let underline = TextAttributes(rawValue: 1 << 3)
    public static let blink     = TextAttributes(rawValue: 1 << 4)

    /// Convert to ncurses attributes
    internal var ncursesValue: Int32 {
        var attrs: Int32 = 0
        if contains(.bold) { attrs |= Int32(2097152) } // A_BOLD
        if contains(.dim) { attrs |= Int32(4194304) } // A_DIM
        if contains(.reverse) { attrs |= Int32(262144) } // A_REVERSE
        if contains(.underline) { attrs |= Int32(131072) } // A_UNDERLINE
        if contains(.blink) { attrs |= Int32(524288) } // A_BLINK
        return attrs
    }
}

/// Complete text styling configuration
public struct TextStyle: Hashable, Sendable {
    public let color: Color
    public let attributes: TextAttributes

    public init(color: Color, attributes: TextAttributes = .normal) {
        self.color = color
        self.attributes = attributes
    }

    // MARK: - Predefined Styles

    public static let primary = TextStyle(color: .primary)
    public static let secondary = TextStyle(color: .secondary)
    public static let accent = TextStyle(color: .accent)
    public static let success = TextStyle(color: .success)
    public static let warning = TextStyle(color: .warning)
    public static let error = TextStyle(color: .error)
    public static let info = TextStyle(color: .info)
    public static let border = TextStyle(color: .border)
    public static let muted = TextStyle(color: .muted)
    public static let emphasis = TextStyle(color: .emphasis)

    // Enhanced styles with attributes
    public static let primaryBold = TextStyle(color: .primary, attributes: .bold)
    public static let accentBold = TextStyle(color: .accent, attributes: .bold)
    public static let errorBold = TextStyle(color: .error, attributes: .bold)
    public static let emphasisBold = TextStyle(color: .emphasis, attributes: .bold)
    public static let mutedDim = TextStyle(color: .muted, attributes: .dim)

    // MARK: - Style Modifiers

    public func bold() -> TextStyle {
        TextStyle(color: color, attributes: attributes.union(.bold))
    }

    public func dim() -> TextStyle {
        TextStyle(color: color, attributes: attributes.union(.dim))
    }

    public func reverse() -> TextStyle {
        TextStyle(color: color, attributes: attributes.union(.reverse))
    }

    /// Automatically choose style based on status string
    public static func forStatus(_ status: String?) -> TextStyle {
        let statusLower = status?.lowercased() ?? "unknown"

        if ["active", "available", "online", "running"].contains(statusLower) {
            return .success
        } else if ["error", "fault", "failed", "offline", "stopped"].contains(statusLower) {
            return .error
        } else if ["warning", "pending", "building", "transitioning"].contains(statusLower) {
            return .warning
        } else {
            return .info
        }
    }
}

// MARK: - Color Scheme Management

/// Manages color scheme and theme configuration
@MainActor
public class ColorScheme {
    public static let shared = ColorScheme()

    public init() {}

    /// Initialize the color scheme with ncurses
    public func initialize() {
        start_color()
        setupColorPairs()
    }

    private func setupColorPairs() {
        // Set up GitHub-inspired color pairs based on Primer Design System
        let _ = use_default_colors() // Use terminal default colors when possible

        // GitHub Primer-Inspired Color Scheme (2024):
        // Based on GitHub's design system for professional, accessible terminal UI
        // Optimized for development workflows with excellent contrast and readability

        init_pair(Int16(Color.primary.colorPairIndex), Int16(COLOR_BLUE), Int16(-1))         // Primary: GitHub blue (#0969da) - signature branding
        init_pair(Int16(Color.secondary.colorPairIndex), Int16(COLOR_CYAN), Int16(-1))      // Secondary: Light cyan - secondary text highlights
        init_pair(Int16(Color.accent.colorPairIndex), Int16(COLOR_WHITE), Int16(COLOR_BLUE)) // Accent: White on blue - GitHub selection style
        init_pair(Int16(Color.success.colorPairIndex), Int16(COLOR_GREEN), Int16(-1))       // Success: GitHub green (#1a7f37) - positive feedback
        init_pair(Int16(Color.warning.colorPairIndex), Int16(COLOR_YELLOW), Int16(-1))      // Warning: Yellow (#fb8500) - attention states
        init_pair(Int16(Color.error.colorPairIndex), Int16(COLOR_RED), Int16(-1))           // Error: GitHub red (#cf222e) - error states
        init_pair(Int16(Color.info.colorPairIndex), Int16(COLOR_WHITE), Int16(-1))          // Info: Clean white - primary readable text
        init_pair(Int16(Color.border.colorPairIndex), Int16(COLOR_BLACK), Int16(-1))        // Border: Dark gray - subtle structural elements
        init_pair(Int16(Color.muted.colorPairIndex), Int16(COLOR_MAGENTA), Int16(-1))       // Muted: Soft magenta - subdued secondary text
        init_pair(Int16(Color.emphasis.colorPairIndex), Int16(COLOR_BLACK), Int16(COLOR_WHITE)) // Emphasis: Black on white - strong emphasis

        // Special high-contrast pairs
        init_pair(9, Int16(COLOR_BLACK), Int16(COLOR_WHITE))  // High contrast inverted
        init_pair(12, Int16(COLOR_BLACK), Int16(COLOR_GREEN)) // Dark on green for success highlights
    }

    /// Get ncurses color pair for a color
    public func colorPair(for color: Color) -> Int32 {
        return color.colorPairIndex << 8
    }
}