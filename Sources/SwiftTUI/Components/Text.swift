import Foundation

// MARK: - Text Component

/// Basic text rendering component that eliminates wattron/wattroff boilerplate
public struct Text: Component {
    private let content: String
    private let style: TextStyle

    public init(_ content: String, style: TextStyle = .primary) {
        self.content = content
        self.style = style
    }

    public var intrinsicSize: Size {
        return Size(width: Int32(content.count), height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        await context.draw(at: .zero, text: content, style: style)
    }
}

// MARK: - Text Style Extensions

extension Text {
    /// Apply primary style
    public func primary() -> Text {
        return Text(content, style: .primary)
    }

    /// Apply secondary style
    public func secondary() -> Text {
        return Text(content, style: .secondary)
    }

    /// Apply accent style
    public func accent() -> Text {
        return Text(content, style: .accent)
    }

    /// Apply success style
    public func success() -> Text {
        return Text(content, style: .success)
    }

    /// Apply warning style
    public func warning() -> Text {
        return Text(content, style: .warning)
    }

    /// Apply error style
    public func error() -> Text {
        return Text(content, style: .error)
    }

    /// Apply info style
    public func info() -> Text {
        return Text(content, style: .info)
    }

    /// Apply muted style
    public func muted() -> Text {
        return Text(content, style: .muted)
    }

    /// Apply emphasis style
    public func emphasis() -> Text {
        return Text(content, style: .emphasis)
    }

    /// Apply bold attribute
    public func bold() -> Text {
        return Text(content, style: style.bold())
    }

    /// Apply dim attribute
    public func dim() -> Text {
        return Text(content, style: style.dim())
    }

    /// Apply reverse attribute
    public func reverse() -> Text {
        return Text(content, style: style.reverse())
    }

    /// Apply custom style
    public func styled(_ newStyle: TextStyle) -> Text {
        return Text(content, style: newStyle)
    }
}

// MARK: - Status Text Component

/// Text component that automatically styles based on status
public struct StatusText: Component {
    private let status: String
    private let customStyle: TextStyle?

    public init(_ status: String, customStyle: TextStyle? = nil) {
        self.status = status
        self.customStyle = customStyle
    }

    public var intrinsicSize: Size {
        return Size(width: Int32(status.count), height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        let style = customStyle ?? TextStyle.forStatus(status)
        await context.draw(at: .zero, text: status, style: style)
    }
}

// MARK: - Formatted Text Component

/// Text component with automatic formatting and truncation
public struct FormattedText: Component {
    private let content: String
    private let style: TextStyle
    private let maxWidth: Int32?
    private let alignment: TextAlignment

    public enum TextAlignment: Sendable {
        case leading
        case center
        case trailing
    }

    public init(_ content: String,
                style: TextStyle = .primary,
                maxWidth: Int32? = nil,
                alignment: TextAlignment = .leading) {
        self.content = content
        self.style = style
        self.maxWidth = maxWidth
        self.alignment = alignment
    }

    public var intrinsicSize: Size {
        let width = maxWidth ?? Int32(content.count)
        return Size(width: width, height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        let availableWidth = maxWidth ?? context.bounds.size.width
        let truncatedContent = String(content.prefix(Int(availableWidth)))

        let text: String
        switch alignment {
        case .leading:
            text = truncatedContent.padding(toLength: Int(availableWidth), withPad: " ", startingAt: 0)
        case .center:
            let padding = max(0, Int(availableWidth) - truncatedContent.count) / 2
            text = String(repeating: " ", count: padding) + truncatedContent
        case .trailing:
            text = truncatedContent.padding(toLength: Int(availableWidth), withPad: " ", startingAt: 0)
        }

        await context.draw(at: .zero, text: text, style: style)
    }
}

// MARK: - Padded Text Component

/// Text with automatic padding for table-like layouts
public struct PaddedText: Component {
    private let content: String
    private let width: Int32
    private let style: TextStyle
    private let alignment: FormattedText.TextAlignment

    public init(_ content: String,
                width: Int32,
                style: TextStyle = .primary,
                alignment: FormattedText.TextAlignment = .leading) {
        self.content = content
        self.width = width
        self.style = style
        self.alignment = alignment
    }

    public var intrinsicSize: Size {
        return Size(width: width, height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        await FormattedText(content, style: style, maxWidth: width, alignment: alignment)
            .render(in: context)
    }
}

// MARK: - Multiline Text Component

/// Text component that handles line breaks and wrapping
public struct MultilineText: Component {
    private let content: String
    private let style: TextStyle
    private let maxWidth: Int32

    public init(_ content: String,
                style: TextStyle = .primary,
                maxWidth: Int32) {
        self.content = content
        self.style = style
        self.maxWidth = maxWidth
    }

    public var intrinsicSize: Size {
        let lines = wrapText(content, maxWidth: maxWidth)
        return Size(width: maxWidth, height: Int32(lines.count))
    }

    @MainActor public func render(in context: DrawingContext) async {
        let lines = wrapText(content, maxWidth: maxWidth)

        for (index, line) in lines.enumerated() {
            let position = Position(row: Int32(index), col: 0)
            await context.draw(at: position, text: line, style: style)
        }
    }

    private func wrapText(_ text: String, maxWidth: Int32) -> [String] {
        var lines: [String] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var currentLine = ""

        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"

            if testLine.count <= maxWidth {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [""] : lines
    }
}