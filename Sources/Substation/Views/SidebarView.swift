import Foundation
import OSClient
import SwiftTUI

@MainActor
struct SidebarView {

    static func draw(screen: OpaquePointer?, screenCols: Int32, screenRows: Int32, currentView: ViewMode) async {
        let sidebarWidth = calculateSidebarWidth(screenCols: screenCols)
        let surface = SwiftTUI.surface(from: screen)

        // Clear and draw sidebar background using SwiftTUI
        let sidebarBounds = Rect(x: 0, y: 2, width: sidebarWidth, height: screenRows - 4)
        await surface.fill(rect: sidebarBounds, character: " ", style: .secondary)

        var components: [any Component] = []

        // Navigation section with bounds checking
        if screenRows > 5 && screenCols > Int32(sidebarWidth) {
            let isCompact = sidebarWidth <= 7

            if !isCompact {
                components.append(Text("Navigation").emphasis().bold().padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 0)))
            } else {
                components.append(Text("Nav").emphasis().bold().padding(EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 0)))
            }

            let views = ViewMode.allCases.filter { !$0.key.isEmpty }.sorted { $0.title < $1.title }
            let maxNavItems = Int(screenRows - 8) - 5 // Leave space for Resource Summary
            let availableViews = views.prefix(maxNavItems)

            for view in availableViews {
                let navStyle: TextStyle = .info
                let keyStyle: TextStyle = view == currentView ? .emphasis : .secondary

                // Combine key and text for compact mode
                var concatenated = [
                    Text(view.key).styled(keyStyle).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 1))
                ]
                if !isCompact {
                    concatenated.append(Text("\(view.title)").styled(navStyle).padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 1)))
                }
                components.append(HStack(spacing: 0, children: concatenated))
            }
        }

        // Render the entire sidebar as a VStack
        let sidebarComponent = VStack(spacing: 0, children: components)
        let contentBounds = Rect(x: 0, y: 2, width: sidebarWidth, height: screenRows - 4)
        await SwiftTUI.render(sidebarComponent, on: surface, in: contentBounds)

        // Vertical separator using SwiftTUI
        let separatorComponents = (0..<Int(screenRows - 4)).map { _ in Text("|").info() }
        let separatorSection = VStack(spacing: 0, children: separatorComponents)
        let separatorBounds = Rect(x: sidebarWidth, y: 2, width: 1, height: screenRows - 4)
        await SwiftTUI.render(separatorSection, on: surface, in: separatorBounds)
    }

    private static func calculateSidebarWidth(screenCols: Int32) -> Int32 {
        // Responsive sidebar width based on screen size
        if screenCols < 70 {
            return 7  // Compact mode: "[d]" format
        } else {
            return 25 // Full mode: complete text
        }
    }
}