import Foundation
import OSClient
import SwiftTUI

@MainActor
struct HeaderView {

    static func draw(screen: OpaquePointer?, client: OSClient, screenCols: Int32) async {
        let surface = SwiftTUI.surface(from: screen)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let timeStr = timeFormatter.string(from: Date())
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
        await SwiftTUI.render(headerComponent, on: surface, in: headerBounds)

        // Separator line using SwiftTUI
        let separatorBounds = Rect(x: 0, y: 1, width: screenCols, height: 1)
        let separatorComponent = Text(String(repeating: "-", count: Int(screenCols))).info()
        await SwiftTUI.render(separatorComponent, on: surface, in: separatorBounds)
    }
}