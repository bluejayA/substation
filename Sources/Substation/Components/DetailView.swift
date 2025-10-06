import Foundation
import SwiftTUI

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

    func toComponent(indent: String, separator: String) -> any Component {
        switch self {
        case .field(let label, let value, let style):
            return Text(indent + label + separator + value).styled(style)
        case .customComponent(let component):
            return component
        case .spacer:
            return Text("")
        }
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

    // Pre-calculated EdgeInsets
    private static let titleEdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)
    private static let sectionEdgeInsets = EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0)
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
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking
        guard width > Self.minScreenWidth && height > Self.minScreenHeight else {
            let errorBounds = Rect(
                x: max(0, startCol),
                y: max(0, startRow),
                width: max(Self.boundsMinWidth, width),
                height: max(Self.boundsMinHeight, height)
            )
            await SwiftTUI.render(Text(Self.screenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        var components: [any Component] = []

        // Title
        components.append(
            Text(title).accent().bold()
                .padding(Self.titleEdgeInsets)
        )

        // Sections
        for section in sections where !section.items.isEmpty {
            // Section title
            components.append(Text(section.title).styled(section.titleStyle).bold())

            // Section items
            var sectionComponents: [any Component] = []
            for item in section.items {
                let component = item.toComponent(
                    indent: Self.defaultInfoFieldIndent,
                    separator: Self.defaultFieldValueSeparator
                )
                sectionComponents.append(component)
            }

            let sectionContent = VStack(spacing: 0, children: sectionComponents)
                .padding(Self.sectionEdgeInsets)
            components.append(sectionContent)
        }

        // Help text
        if let helpText = helpText {
            components.append(
                Text(helpText).info()
                    .padding(Self.helpEdgeInsets)
            )
        }

        // Apply scroll offset
        let visibleComponents: [any Component]
        if scrollOffset > 0 && scrollOffset < components.count {
            visibleComponents = Array(components.dropFirst(scrollOffset))
        } else if scrollOffset >= components.count {
            visibleComponents = [Text(scrolledToEndText).info()]
        } else {
            visibleComponents = components
        }

        // Render
        let detailComponent = VStack(spacing: Self.componentSpacing, children: visibleComponents)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(detailComponent, on: surface, in: bounds)
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
