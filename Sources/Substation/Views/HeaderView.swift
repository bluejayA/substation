import Foundation
import OSClient
import SwiftNCurses

@MainActor
struct HeaderView {

    static func draw(screen: OpaquePointer?, client: OSClient, screenCols: Int32) async {
        let surface = SwiftNCurses.surface(from: screen)

        let timeStr = DateFormatter.timeOnly.string(from: Date())
        let headerLeft = "* SUBSTATION - The operator's control panel"
        let region = await client.region
        let project = await client.project
        let headerRight = "Region: \(region) | Project: \(project) | \(timeStr)"

        // Create header with left and right aligned content
        let headerBounds = Rect(x: 0, y: 0, width: screenCols, height: 1)

        // Calculate spacing for right alignment
        let totalUsedSpace = headerLeft.count + headerRight.count
        let availableSpace = Int(screenCols) - totalUsedSpace
        let spacingText = availableSpace > 2 ? String(repeating: " ", count: availableSpace) : " "

        let headerComponent = HStack(spacing: 0, children: [
            Text(headerLeft).emphasis().bold(),
            Text(spacingText).primary(),
            Text(headerRight).secondary()
        ])

        // Fill background and render header
        await surface.fill(rect: headerBounds, character: " ", style: .primary)
        await SwiftNCurses.render(headerComponent, on: surface, in: headerBounds)

        // Separator line using SwiftNCurses
        let separatorBounds = Rect(x: 0, y: 1, width: screenCols, height: 1)
        let separatorComponent = Text(String(repeating: "-", count: Int(screenCols))).info()
        await SwiftNCurses.render(separatorComponent, on: surface, in: separatorBounds)
    }
}