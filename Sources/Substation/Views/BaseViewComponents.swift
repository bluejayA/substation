import Foundation
import OSClient
import SwiftTUI

struct BaseViewComponents {
    // MARK: - Core Rendering Helpers

    @MainActor
    static func drawTitle(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                          width: Int32, title: String? = nil) async {
        guard let title = title, title.count + 4 < width else { return }

        let surface = SwiftTUI.surface(from: screen)
        let titleStart = startCol + 2
        let bounds = Rect(x: titleStart, y: startRow, width: Int32(title.count + 4), height: 1)
        let titleComponent = Text("[ \(title) ]").accent()

        await SwiftTUI.render(titleComponent, on: surface, in: bounds)
    }

    @MainActor
    static func drawBorder(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                          width: Int32, height: Int32, title: String? = nil) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        // Create a bordered container with optional title
        let borderComponent: any Component = BorderedContainer(
            title: title,
            content: {}
        )

        await SwiftTUI.render(borderComponent, on: surface, in: bounds)

        // Draw title if provided
        if let title = title {
            await drawTitle(screen: screen, startRow: startRow, startCol: startCol, width: width, title: title)
        }
    }

    @MainActor
    static func clearArea(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                         width: Int32, height: Int32) async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        // Fill with secondary background style to maintain consistent styling
        await surface.fill(rect: bounds, character: " ", style: .secondary)
    }


    // MARK: - Enhanced Title Display

    @MainActor
    static func drawEnhancedTitle(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                 width: Int32, title: String, searchQuery: String? = nil) async {
        let titleText = searchQuery != nil ? "\(title) (filtered: \(searchQuery!))" : title
        await drawTitle(screen: screen, startRow: startRow, startCol: startCol,
                 width: width, title: titleText)
    }

}