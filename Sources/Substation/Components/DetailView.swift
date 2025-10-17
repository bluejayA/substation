import Foundation
import SwiftNCurses

// MARK: - DetailSection

struct DetailSection {
    let title: String
    let items: [DetailItem]
    let titleStyle: TextStyle

    init(title: String, items: [DetailItem], titleStyle: TextStyle = .primary) {
        self.title = title
        self.items = items
        self.titleStyle = titleStyle
    }
}

// MARK: - DetailItem

enum DetailItem {
    case field(label: String, value: String, style: TextStyle = .secondary)
    case customComponent(any Component)
    case spacer

    func toComponent(indent: String, separator: String, maxLabelWidth: Int = 0) -> any Component {
        switch self {
        case .field(let label, let value, let style):
            // Pad label to maxLabelWidth for alignment if specified
            let paddedLabel: String
            if maxLabelWidth > 0 && label.count < maxLabelWidth {
                paddedLabel = label + String(repeating: " ", count: maxLabelWidth - label.count)
            } else {
                paddedLabel = label
            }
            return Text(indent + paddedLabel + separator + value).styled(style)
        case .customComponent(let component):
            return component
        case .spacer:
            return Text("")
        }
    }

    var label: String? {
        if case .field(let label, _, _) = self {
            return label
        }
        return nil
    }

    var isSpacerType: Bool {
        if case .spacer = self {
            return true
        }
        return false
    }
}

// MARK: - DetailView

@MainActor
struct DetailView {
    private let title: String
    private let sections: [DetailSection]
    private let helpText: String?
    private let scrollOffset: Int
    private let scrolledToEndText: String

    // Cache for built components to reduce CPU usage
    private static var componentCache: [String: [any Component]] = [:]
    private static var lastScrollOffset: Int = -1

    // Layout constants
    private static let minScreenWidth: Int32 = 10
    private static let minScreenHeight: Int32 = 10
    private static let boundsMinWidth: Int32 = 1
    private static let boundsMinHeight: Int32 = 1
    private static let screenTooSmallText = "Screen too small"
    private static let defaultScrolledToEndText = "End of details"
    private static let defaultFieldValueSeparator = ": "
    private static let defaultInfoFieldIndent = "  "
    private static let componentSpacing: Int32 = 0

    // Pre-calculated EdgeInsets (restored original spacing for better visual)
    private static let titleEdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)
    private static let sectionTitlePadding = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    private static let sectionItemPadding = EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)
    private static let sectionBottomPadding = EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0)
    private static let helpEdgeInsets = EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)

    init(
        title: String,
        sections: [DetailSection],
        helpText: String? = nil,
        scrollOffset: Int = 0,
        scrolledToEndText: String = defaultScrolledToEndText
    ) {
        self.title = title
        self.sections = sections
        self.helpText = helpText
        self.scrollOffset = scrollOffset
        self.scrolledToEndText = scrolledToEndText
    }

    // MARK: - Main Draw Function

    func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        let surface = SwiftNCurses.surface(from: screen)

        // Defensive bounds checking
        guard width > Self.minScreenWidth && height > Self.minScreenHeight else {
            let errorBounds = Rect(
                x: max(0, startCol),
                y: max(0, startRow),
                width: max(Self.boundsMinWidth, width),
                height: max(Self.boundsMinHeight, height)
            )
            await SwiftNCurses.render(Text(Self.screenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Only clear surface when scrolling to reduce flicker
        let scrollChanged = scrollOffset != Self.lastScrollOffset
        if scrollChanged {
            let clearBounds = Rect(x: startCol, y: startRow, width: width, height: height)
            surface.clear(rect: clearBounds)
            Self.lastScrollOffset = scrollOffset
        }

        // Build components fresh each time to ensure alignment is correct
        // (Caching was causing alignment issues with dynamic content)
        var newComponents: [any Component] = []
        let components: [any Component]

            // Title
            newComponents.append(
                Text(title).accent().bold()
                    .padding(Self.titleEdgeInsets)
            )

            // Build sections using nested VStacks for better visual appearance
            for section in sections where !section.items.isEmpty {
                // Section title
                let sectionTitle = Text(section.title).styled(section.titleStyle).bold()
                    .padding(Self.sectionTitlePadding)

                // Calculate max label width for alignment in this section
                let maxLabelWidth = section.items.compactMap { $0.label?.count }.max() ?? 0

                // Build section items
                var sectionComponents: [any Component] = []
                for item in section.items {
                    let component = item.toComponent(
                        indent: Self.defaultInfoFieldIndent,
                        separator: Self.defaultFieldValueSeparator,
                        maxLabelWidth: maxLabelWidth
                    )
                    sectionComponents.append(component.padding(Self.sectionItemPadding))
                }

                // Create nested VStack for section items
                let sectionItems = VStack(spacing: 0, children: sectionComponents)

                // Add section title and items as a group
                newComponents.append(sectionTitle)
                newComponents.append(sectionItems)

                // Add spacing after section
                newComponents.append(Text("").padding(Self.sectionBottomPadding))
            }

            // Help text
            if let helpText = helpText {
                newComponents.append(
                    Text(helpText).info()
                        .padding(Self.helpEdgeInsets)
                )
            }

        components = newComponents

        // Apply scroll offset and limit visible components to screen height for performance
        // Only render what can actually be displayed to reduce CPU usage
        let maxVisibleComponents = Int(height) + 5 // Add small buffer for smooth scrolling
        let visibleComponents: [any Component]

        if scrollOffset > 0 && scrollOffset < components.count {
            let remainingComponents = Array(components.dropFirst(scrollOffset))
            // Limit to what can be visible on screen
            visibleComponents = Array(remainingComponents.prefix(maxVisibleComponents))
        } else if scrollOffset >= components.count {
            visibleComponents = [Text(scrolledToEndText).info()]
        } else {
            // Even when not scrolled, only render what fits on screen
            visibleComponents = Array(components.prefix(maxVisibleComponents))
        }

        // Render using VStack (let SwiftNCurses handle the layout)
        let detailComponent = VStack(spacing: Self.componentSpacing, children: visibleComponents)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftNCurses.render(detailComponent, on: surface, in: bounds)
    }

    // MARK: - Convenience Builders

    static func buildFieldItem(label: String, value: String?, defaultValue: String = "N/A", style: TextStyle = .secondary) -> DetailItem? {
        guard let value = value, !value.isEmpty else {
            return nil
        }
        return .field(label: label, value: value, style: style)
    }

    static func buildFieldItem(label: String, value: Int?, suffix: String = "", style: TextStyle = .secondary) -> DetailItem? {
        guard let value = value else {
            return nil
        }
        return .field(label: label, value: String(value) + suffix, style: style)
    }

    static func buildFieldItem(label: String, value: Double?, format: String = "%.2f", suffix: String = "", style: TextStyle = .secondary) -> DetailItem? {
        guard let value = value else {
            return nil
        }
        return .field(label: label, value: String(format: format, value) + suffix, style: style)
    }

    static func buildFieldItem<T: CustomStringConvertible>(label: String, value: T?, style: TextStyle = .secondary) -> DetailItem? {
        guard let value = value else {
            return nil
        }
        return .field(label: label, value: String(describing: value), style: style)
    }

    static func buildSection(title: String, items: [DetailItem?], titleStyle: TextStyle = .primary) -> DetailSection? {
        let validItems = items.compactMap { $0 }
        guard !validItems.isEmpty else {
            return nil
        }
        return DetailSection(title: title, items: validItems, titleStyle: titleStyle)
    }
}
