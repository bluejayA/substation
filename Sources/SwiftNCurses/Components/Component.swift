import Foundation

// MARK: - Component Protocol

/// Base protocol for all UI components
public protocol Component: Sendable {
    /// Render the component on a surface within the given bounds
    @MainActor func render(in context: DrawingContext) async

    /// Calculate the preferred size for this component
    var intrinsicSize: Size { get }
}

// MARK: - Component Extensions

extension Component {
    /// Default intrinsic size for components that don't specify one
    public var intrinsicSize: Size {
        return Size(width: 0, height: 1)
    }

    /// Render with automatic context creation
    @MainActor public func render(on surface: any Surface, in rect: Rect) async {
        let context = DrawingContext(surface: surface, bounds: rect)
        await render(in: context)
    }
}

// MARK: - Layout Component

/// Component that applies padding and alignment to child components
public struct Padded: Component {
    private let child: any Component
    private let padding: EdgeInsets

    public init(_ child: any Component, padding: EdgeInsets) {
        self.child = child
        self.padding = padding
    }

    public init(_ child: any Component, padding: Int32) {
        self.init(child, padding: EdgeInsets(all: padding))
    }

    public var intrinsicSize: Size {
        let childSize = child.intrinsicSize
        return Size(
            width: childSize.width + padding.leading + padding.trailing,
            height: childSize.height + padding.top + padding.bottom
        )
    }

    @MainActor public func render(in context: DrawingContext) async {
        let paddedBounds = context.bounds.inset(by: padding)
        let paddedContext = DrawingContext(surface: context.surface, bounds: paddedBounds)
        await child.render(in: paddedContext)
    }
}

// MARK: - Empty Component

/// Component that renders nothing (useful for conditional rendering)
public struct EmptyComponent: Component {
    public init() {}

    public var intrinsicSize: Size {
        return .zero
    }

    @MainActor public func render(in context: DrawingContext) async {
        // Render nothing
    }
}

// MARK: - Component Builder Utilities

extension Component {
    /// Add padding around this component
    public func padding(_ edges: EdgeInsets) -> Padded {
        return Padded(self, padding: edges)
    }

    /// Add uniform padding around this component
    public func padding(_ amount: Int32) -> Padded {
        return Padded(self, padding: amount)
    }
}

// MARK: - Container Components

/// Vertical stack container
public struct VStack: Component {
    private let children: [any Component]
    private let spacing: Int32

    public init(spacing: Int32 = 0, @ComponentBuilder content: () -> [any Component]) {
        self.children = content()
        self.spacing = spacing
    }

    public init(spacing: Int32 = 0, children: [any Component]) {
        self.children = children
        self.spacing = spacing
    }


    public var intrinsicSize: Size {
        let totalHeight = children.reduce(0) { $0 + $1.intrinsicSize.height } +
                         Int32(max(0, children.count - 1)) * spacing
        let maxWidth = children.reduce(0) { max($0, $1.intrinsicSize.width) }
        return Size(width: maxWidth, height: totalHeight)
    }

    @MainActor public func render(in context: DrawingContext) async {
        var currentY: Int32 = 0

        for child in children {
            let childSize = child.intrinsicSize
            let childRect = Rect(
                origin: Position(row: currentY, col: 0),
                size: Size(width: context.bounds.size.width, height: childSize.height)
            )

            let childContext = context.subContext(rect: childRect)
            await child.render(in: childContext)

            currentY += childSize.height + spacing

            // Stop if we exceed available space
            if currentY >= context.bounds.size.height {
                break
            }
        }
    }
}

/// Horizontal stack container
public struct HStack: Component {
    private let children: [any Component]
    private let spacing: Int32

    public init(spacing: Int32 = 1, @ComponentBuilder content: () -> [any Component]) {
        self.children = content()
        self.spacing = spacing
    }

    public init(spacing: Int32 = 1, children: [any Component]) {
        self.children = children
        self.spacing = spacing
    }

    public var intrinsicSize: Size {
        let totalWidth = children.reduce(0) { $0 + $1.intrinsicSize.width } +
                        Int32(max(0, children.count - 1)) * spacing
        let maxHeight = children.reduce(0) { max($0, $1.intrinsicSize.height) }
        return Size(width: totalWidth, height: maxHeight)
    }

    @MainActor public func render(in context: DrawingContext) async {
        var currentX: Int32 = 0

        for child in children {
            let childSize = child.intrinsicSize
            let childRect = Rect(
                origin: Position(row: 0, col: currentX),
                size: Size(width: childSize.width, height: context.bounds.size.height)
            )

            let childContext = context.subContext(rect: childRect)
            await child.render(in: childContext)

            currentX += childSize.width + spacing

            // Stop if we exceed available space
            if currentX >= context.bounds.size.width {
                break
            }
        }
    }
}

// MARK: - Component Builder

@resultBuilder
public struct ComponentBuilder {
    public static func buildBlock(_ components: any Component...) -> [any Component] {
        return components
    }

    public static func buildBlock(_ component: any Component) -> any Component {
        return component
    }

    public static func buildOptional(_ component: (any Component)?) -> any Component {
        return component ?? EmptyComponent()
    }

    public static func buildEither(first component: any Component) -> any Component {
        return component
    }

    public static func buildEither(second component: any Component) -> any Component {
        return component
    }

    public static func buildArray(_ components: [any Component]) -> [any Component] {
        return components
    }
}