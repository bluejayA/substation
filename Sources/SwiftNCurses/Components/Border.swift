import Foundation

// MARK: - Border Component

/// Component that draws borders and frames around content
public struct Border: Component {
    private let child: (any Component)?
    private let style: BorderStyle
    private let title: String?

    public struct BorderStyle: Sendable {
        let topLeft: Character
        let topRight: Character
        let bottomLeft: Character
        let bottomRight: Character
        let horizontal: Character
        let vertical: Character
        let textStyle: TextStyle

        public static let standard = BorderStyle(
            topLeft: "+", topRight: "+",
            bottomLeft: "+", bottomRight: "+",
            horizontal: "-", vertical: "|",
            textStyle: .secondary
        )

        public static let rounded = BorderStyle(
            topLeft: "+", topRight: "+",
            bottomLeft: "+", bottomRight: "+",
            horizontal: "-", vertical: "|",
            textStyle: .secondary
        )

        public static let double = BorderStyle(
            topLeft: "+", topRight: "+",
            bottomLeft: "+", bottomRight: "+",
            horizontal: "=", vertical: "|",
            textStyle: .accent
        )

        public static let thick = BorderStyle(
            topLeft: "+", topRight: "+",
            bottomLeft: "+", bottomRight: "+",
            horizontal: "#", vertical: "|",
            textStyle: .primary
        )
    }

    public init(_ child: (any Component)? = nil,
                style: BorderStyle = .standard,
                title: String? = nil) {
        self.child = child
        self.style = style
        self.title = title
    }

    public var intrinsicSize: Size {
        guard let child = child else {
            return Size(width: 2, height: 2) // Just border
        }

        let childSize = child.intrinsicSize
        return Size(
            width: childSize.width + 2,  // Left and right border
            height: childSize.height + 2 // Top and bottom border
        )
    }

    @MainActor public func render(in context: DrawingContext) async {
        let bounds = context.bounds

        // Draw corners
        await context.surface.draw(
            at: bounds.origin,
            character: style.topLeft,
            style: style.textStyle
        )
        await context.surface.draw(
            at: Position(row: bounds.origin.row, col: bounds.maxX - 1),
            character: style.topRight,
            style: style.textStyle
        )
        await context.surface.draw(
            at: Position(row: bounds.maxY - 1, col: bounds.origin.col),
            character: style.bottomLeft,
            style: style.textStyle
        )
        await context.surface.draw(
            at: Position(row: bounds.maxY - 1, col: bounds.maxX - 1),
            character: style.bottomRight,
            style: style.textStyle
        )

        // Draw horizontal borders
        for col in (bounds.origin.col + 1)..<(bounds.maxX - 1) {
            await context.surface.draw(
                at: Position(row: bounds.origin.row, col: col),
                character: style.horizontal,
                style: style.textStyle
            )
            await context.surface.draw(
                at: Position(row: bounds.maxY - 1, col: col),
                character: style.horizontal,
                style: style.textStyle
            )
        }

        // Draw vertical borders
        for row in (bounds.origin.row + 1)..<(bounds.maxY - 1) {
            await context.surface.draw(
                at: Position(row: row, col: bounds.origin.col),
                character: style.vertical,
                style: style.textStyle
            )
            await context.surface.draw(
                at: Position(row: row, col: bounds.maxX - 1),
                character: style.vertical,
                style: style.textStyle
            )
        }

        // Draw title if present
        if let title = title, title.count + 4 < bounds.size.width {
            let titleText = "[ \(title) ]"
            let titleStart = bounds.origin.col + 2
            await context.surface.draw(
                at: Position(row: bounds.origin.row, col: titleStart),
                text: titleText,
                style: style.textStyle
            )
        }

        // Render child content
        if let child = child {
            let contentBounds = Rect(
                origin: Position(row: bounds.origin.row + 1, col: bounds.origin.col + 1),
                size: Size(width: bounds.size.width - 2, height: bounds.size.height - 2)
            )
            let contentContext = DrawingContext(surface: context.surface, bounds: contentBounds)
            await child.render(in: contentContext)
        }
    }
}

// MARK: - Separator Component

/// Component that draws horizontal or vertical separator lines
public struct Separator: Component {
    public enum Direction: Sendable {
        case horizontal
        case vertical
    }

    private let direction: Direction
    private let character: Character
    private let style: TextStyle
    private let length: Int32?

    public init(direction: Direction,
                character: Character? = nil,
                style: TextStyle = .secondary,
                length: Int32? = nil) {
        self.direction = direction
        self.character = character ?? (direction == .horizontal ? "-" : "|")
        self.style = style
        self.length = length
    }

    public var intrinsicSize: Size {
        switch direction {
        case .horizontal:
            return Size(width: length ?? 10, height: 1)
        case .vertical:
            return Size(width: 1, height: length ?? 5)
        }
    }

    @MainActor public func render(in context: DrawingContext) async {
        switch direction {
        case .horizontal:
            let width = length ?? context.bounds.size.width
            for col in 0..<width {
                if col < context.bounds.size.width {
                    await context.surface.draw(
                        at: Position(row: context.bounds.origin.row, col: context.bounds.origin.col + col),
                        character: character,
                        style: style
                    )
                }
            }
        case .vertical:
            let height = length ?? context.bounds.size.height
            for row in 0..<height {
                if row < context.bounds.size.height {
                    await context.surface.draw(
                        at: Position(row: context.bounds.origin.row + row, col: context.bounds.origin.col),
                        character: character,
                        style: style
                    )
                }
            }
        }
    }
}

// MARK: - Progress Bar Component

/// Component that displays progress with customizable appearance
public struct ProgressBar: Component {
    private let progress: Double // 0.0 to 1.0
    private let width: Int32
    private let style: ProgressBarStyle

    public struct ProgressBarStyle: Sendable {
        let fillCharacter: Character
        let emptyCharacter: Character
        let leftBracket: Character?
        let rightBracket: Character?
        let fillStyle: TextStyle
        let emptyStyle: TextStyle
        let bracketStyle: TextStyle

        public static let standard = ProgressBarStyle(
            fillCharacter: "=",
            emptyCharacter: " ",
            leftBracket: "[",
            rightBracket: "]",
            fillStyle: .success,
            emptyStyle: .secondary,
            bracketStyle: .primary
        )

        public static let block = ProgressBarStyle(
            fillCharacter: "#",
            emptyCharacter: ".",
            leftBracket: "[",
            rightBracket: "]",
            fillStyle: .accent,
            emptyStyle: .info,
            bracketStyle: .primary
        )

        public static let dots = ProgressBarStyle(
            fillCharacter: "*",
            emptyCharacter: "o",
            leftBracket: nil,
            rightBracket: nil,
            fillStyle: .success,
            emptyStyle: .secondary,
            bracketStyle: .primary
        )
    }

    public init(progress: Double,
                width: Int32 = 20,
                style: ProgressBarStyle = .standard) {
        self.progress = max(0.0, min(1.0, progress))
        self.width = width
        self.style = style
    }

    public var intrinsicSize: Size {
        let bracketWidth = (style.leftBracket == nil) ? 0 : 2
        return Size(width: width + Int32(bracketWidth), height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        var currentCol: Int32 = 0

        // Left bracket
        if let leftBracket = style.leftBracket {
            await context.surface.draw(
                at: Position(row: context.bounds.origin.row, col: context.bounds.origin.col + currentCol),
                character: leftBracket,
                style: style.bracketStyle
            )
            currentCol += 1
        }

        // Progress bar content
        let fillWidth = Int32(Double(width) * progress)

        for i in 0..<width {
            let character = i < fillWidth ? style.fillCharacter : style.emptyCharacter
            let charStyle = i < fillWidth ? style.fillStyle : style.emptyStyle

            await context.surface.draw(
                at: Position(row: context.bounds.origin.row, col: context.bounds.origin.col + currentCol),
                character: character,
                style: charStyle
            )
            currentCol += 1
        }

        // Right bracket
        if let rightBracket = style.rightBracket {
            await context.surface.draw(
                at: Position(row: context.bounds.origin.row, col: context.bounds.origin.col + currentCol),
                character: rightBracket,
                style: style.bracketStyle
            )
        }
    }
}

// MARK: - Component Extensions for Borders

extension Component {
    /// Add a border around this component
    public func border(style: Border.BorderStyle = .standard, title: String? = nil) -> Border {
        return Border(self, style: style, title: title)
    }

    /// Add a rounded border around this component
    public func roundedBorder(title: String? = nil) -> Border {
        return Border(self, style: .rounded, title: title)
    }

    /// Add a double border around this component
    public func doubleBorder(title: String? = nil) -> Border {
        return Border(self, style: .double, title: title)
    }
}