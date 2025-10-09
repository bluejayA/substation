import Foundation

@MainActor
final class LayoutUtilities: @unchecked Sendable {
    static let shared = LayoutUtilities()

    private init() {}

    // MARK: - Sidebar Width Calculation

    /// Calculate the sidebar width based on screen columns
    /// - Parameter screenCols: The number of columns available on the screen
    /// - Returns: The appropriate sidebar width (0 for hidden, 25 for full)
    func calculateSidebarWidth(screenCols: Int32) -> Int32 {
        // Responsive sidebar width based on screen size
        if screenCols < 100 {
            return 0  // Hidden: no sidebar on small screens
        } else {
            return 25 // Full mode: complete text
        }
    }
}
