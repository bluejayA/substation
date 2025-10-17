import Foundation

/// A bordered container with an optional title
public struct BorderedContainer: Component {
    public let title: String?
    public let content: @Sendable () async -> Void

    public init(title: String? = nil, content: @escaping @Sendable () async -> Void) {
        self.title = title
        self.content = content
    }

    @MainActor
    public func render(in context: DrawingContext) async {
        // Draw border
        await context.drawBorder(style: .border, title: title)

        // Render content in inner area (inside the border)
        await content()
    }
}