import Foundation

// MARK: - Core Geometry Types

/// Type-safe position representation
public struct Position: Equatable, Hashable, Sendable {
    public let row: Int32
    public let col: Int32

    /// Convenience properties for x/y access
    public var x: Int32 { col }
    public var y: Int32 { row }

    public init(row: Int32, col: Int32) {
        self.row = row
        self.col = col
    }

    public init(x: Int32, y: Int32) {
        self.row = y
        self.col = x
    }

    public static let zero = Position(row: 0, col: 0)

    public func offset(by offset: Position) -> Position {
        Position(row: row + offset.row, col: col + offset.col)
    }
}

/// Alias for familiar Point terminology
public typealias Point = Position

/// Type-safe size representation
public struct Size: Equatable, Hashable, Sendable {
    public let width: Int32
    public let height: Int32

    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }

    public static let zero = Size(width: 0, height: 0)

    public var area: Int32 {
        width * height
    }
}

/// Type-safe rectangle representation
public struct Rect: Equatable, Hashable, Sendable {
    public let origin: Position
    public let size: Size

    public init(origin: Position, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Int32, y: Int32, width: Int32, height: Int32) {
        self.origin = Position(row: y, col: x)
        self.size = Size(width: width, height: height)
    }

    public static let zero = Rect(origin: .zero, size: .zero)

    public var minX: Int32 { origin.col }
    public var minY: Int32 { origin.row }
    public var maxX: Int32 { origin.col + size.width }
    public var maxY: Int32 { origin.row + size.height }

    public func contains(_ position: Position) -> Bool {
        position.col >= minX && position.col < maxX &&
        position.row >= minY && position.row < maxY
    }

    public func inset(by insets: EdgeInsets) -> Rect {
        Rect(
            origin: Position(row: origin.row + insets.top, col: origin.col + insets.leading),
            size: Size(
                width: size.width - insets.leading - insets.trailing,
                height: size.height - insets.top - insets.bottom
            )
        )
    }
}

/// Edge insets for padding and margins
public struct EdgeInsets: Equatable, Hashable, Sendable {
    public let top: Int32
    public let leading: Int32
    public let bottom: Int32
    public let trailing: Int32

    public init(top: Int32, leading: Int32, bottom: Int32, trailing: Int32) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init(all: Int32) {
        self.init(top: all, leading: all, bottom: all, trailing: all)
    }

    public static let zero = EdgeInsets(all: 0)
}