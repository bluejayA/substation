import Foundation

// Optimizes screen rendering by tracking what needs to be redrawn
class RenderOptimizer {

    // Track different types of content changes
    enum DirtyRegion {
        case fullScreen
        case viewTransition  // Only this triggers screen clear
        case header
        case sidebar
        case mainPanel
        case statusBar
        case scrollContent(startRow: Int32, endRow: Int32)
    }

    private var dirtyRegions: Set<DirtyRegion> = []
    private var lastRenderTime: Date = Date()
    private var renderThrottleInterval: TimeInterval = 0.016 // ~60fps

    // Screen layout constants
    private let headerHeight: Int32 = 2
    private let sidebarWidth: Int32 = 25
    private let statusBarHeight: Int32 = 2

    // Track if we need any render at all
    private var needsRender: Bool = false

    // Force a full screen redraw
    func markFullScreenDirty() {
        dirtyRegions.removeAll()
        dirtyRegions.insert(.fullScreen)
        needsRender = true
        Logger.shared.logDebug("RenderOptimizer - Marked full screen dirty")
    }

    // Force immediate full screen redraw with clear for view transitions
    // This is the ONLY case that should clear the screen to prevent flashing
    func markViewTransitionDirty() {
        dirtyRegions.removeAll()
        dirtyRegions.insert(.viewTransition)
        needsRender = true
        lastRenderTime = Date(timeIntervalSince1970: 0) // Force immediate render
        Logger.shared.logDebug("RenderOptimizer - Marked view transition dirty (immediate with clear)")
    }

    // Check if full redraw is already queued
    private var hasFullRedraw: Bool {
        dirtyRegions.contains(.fullScreen) || dirtyRegions.contains(.viewTransition)
    }

    // Mark specific regions for update
    func markHeaderDirty() {
        if !hasFullRedraw {
            dirtyRegions.insert(.header)
            needsRender = true
        }
    }

    func markSidebarDirty() {
        if !hasFullRedraw {
            dirtyRegions.insert(.sidebar)
            needsRender = true
        }
    }

    func markMainPanelDirty() {
        if !hasFullRedraw {
            dirtyRegions.insert(.mainPanel)
            needsRender = true
        }
    }

    func markStatusBarDirty() {
        if !hasFullRedraw {
            dirtyRegions.insert(.statusBar)
            needsRender = true
        }
    }

    // Mark specific content rows for scrolling optimization
    func markScrollContentDirty(startRow: Int32, endRow: Int32) {
        if !hasFullRedraw {
            dirtyRegions.insert(.scrollContent(startRow: startRow, endRow: endRow))
            needsRender = true
        }
    }

    // Check if render should proceed (throttling)
    func shouldRender(force: Bool = false) -> Bool {
        guard needsRender else { return false }

        if force {
            return true
        }

        let now = Date()
        let timeSinceLastRender = now.timeIntervalSince(lastRenderTime)

        if timeSinceLastRender >= renderThrottleInterval {
            lastRenderTime = now
            return true
        }

        return false
    }

    // Get optimized render plan
    func getRenderPlan(screenRows: Int32, screenCols: Int32) -> RenderPlan {
        // View transitions require screen clear to prevent artifacts from different layouts
        if dirtyRegions.contains(.viewTransition) {
            return RenderPlan(
                shouldClearScreen: true,
                renderHeader: true,
                renderSidebar: true,
                renderMainPanel: true,
                renderStatusBar: true,
                scrollOptimization: nil
            )
        }

        // Full screen redraw WITHOUT clear - components overwrite their areas
        // This prevents flashing while still redrawing everything
        if dirtyRegions.contains(.fullScreen) {
            return RenderPlan(
                shouldClearScreen: false,
                renderHeader: true,
                renderSidebar: true,
                renderMainPanel: true,
                renderStatusBar: true,
                scrollOptimization: nil
            )
        }

        // Partial screen updates for performance
        return RenderPlan(
            shouldClearScreen: false,
            renderHeader: dirtyRegions.contains(.header),
            renderSidebar: dirtyRegions.contains(.sidebar),
            renderMainPanel: dirtyRegions.contains(.mainPanel),
            renderStatusBar: dirtyRegions.contains(.statusBar),
            scrollOptimization: getScrollOptimization()
        )
    }

    private func getScrollOptimization() -> ScrollOptimization? {
        for region in dirtyRegions {
            if case .scrollContent(let startRow, let endRow) = region {
                return ScrollOptimization(startRow: startRow, endRow: endRow)
            }
        }
        return nil
    }

    // Clear dirty state after successful render
    func markClean() {
        dirtyRegions.removeAll()
        needsRender = false
    }

    // Optimized scrolling - only redraw changed lines
    func optimizeScrollRender(screen: OpaquePointer?, oldScrollOffset: Int, newScrollOffset: Int,
                            contentHeight: Int, screenRows: Int32, mainStartRow: Int32) {

        let scrollDelta = newScrollOffset - oldScrollOffset

        // For small deltas, use scroll optimization
        if abs(scrollDelta) == 1 && abs(scrollDelta) < contentHeight / 4 {
            if scrollDelta > 0 {
                // Scrolling down - only redraw the new bottom line
                markScrollContentDirty(
                    startRow: mainStartRow + Int32(contentHeight - 1),
                    endRow: mainStartRow + Int32(contentHeight)
                )
            } else {
                // Scrolling up - only redraw the new top line
                markScrollContentDirty(
                    startRow: mainStartRow + 2, // Account for headers
                    endRow: mainStartRow + 3
                )
            }

            Logger.shared.logDebug("RenderOptimizer - Using scroll optimization for delta: \(scrollDelta)")
        } else {
            // Large delta - redraw main panel
            markMainPanelDirty()
            Logger.shared.logDebug("RenderOptimizer - Large scroll delta \(scrollDelta), redrawing main panel")
        }
    }

    // Performance optimization methods
    func reduceAnimationFrequency() {
        // Reduce rendering frequency to improve performance
        renderThrottleInterval = min(renderThrottleInterval * 1.5, 0.1) // Slower refresh rate
        Logger.shared.logDebug("RenderOptimizer - Reduced animation frequency to \(renderThrottleInterval)s")
    }

    func optimizeRenderingFrequency() {
        // Optimize rendering frequency for better performance
        renderThrottleInterval = max(renderThrottleInterval * 0.8, 0.04167) // Target 24fps instead of 30fps
        Logger.shared.logDebug("RenderOptimizer - Optimized rendering frequency to \(renderThrottleInterval)s")
    }

    func resetRenderingFrequency() {
        // Reset to default 30fps
        renderThrottleInterval = 0.032 // ~30fps
        Logger.shared.logDebug("RenderOptimizer - Reset rendering frequency to default")
    }

    // Performance stats
    func getStats() -> [String: Any] {
        return [
            "dirty_regions": dirtyRegions.count,
            "needs_render": needsRender,
            "time_since_last_render": Date().timeIntervalSince(lastRenderTime),
            "render_throttle_interval": renderThrottleInterval
        ]
    }
}

// Render execution plan
struct RenderPlan {
    let shouldClearScreen: Bool
    let renderHeader: Bool
    let renderSidebar: Bool
    let renderMainPanel: Bool
    let renderStatusBar: Bool
    let scrollOptimization: ScrollOptimization?

    var description: String {
        var components: [String] = []
        if shouldClearScreen { components.append("clear") }
        if renderHeader { components.append("header") }
        if renderSidebar { components.append("sidebar") }
        if renderMainPanel { components.append("main") }
        if renderStatusBar { components.append("status") }
        if scrollOptimization != nil { components.append("scroll") }
        return components.joined(separator: "+")
    }
}

struct ScrollOptimization {
    let startRow: Int32
    let endRow: Int32
}

// Make DirtyRegion hashable for Set usage
extension RenderOptimizer.DirtyRegion: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .fullScreen:
            hasher.combine("fullScreen")
        case .viewTransition:
            hasher.combine("viewTransition")
        case .header:
            hasher.combine("header")
        case .sidebar:
            hasher.combine("sidebar")
        case .mainPanel:
            hasher.combine("mainPanel")
        case .statusBar:
            hasher.combine("statusBar")
        case .scrollContent(let startRow, let endRow):
            hasher.combine("scrollContent")
            hasher.combine(startRow)
            hasher.combine(endRow)
        }
    }

    static func == (lhs: RenderOptimizer.DirtyRegion, rhs: RenderOptimizer.DirtyRegion) -> Bool {
        switch (lhs, rhs) {
        case (.fullScreen, .fullScreen),
             (.viewTransition, .viewTransition),
             (.header, .header),
             (.sidebar, .sidebar),
             (.mainPanel, .mainPanel),
             (.statusBar, .statusBar):
            return true
        case (.scrollContent(let lStart, let lEnd), .scrollContent(let rStart, let rEnd)):
            return lStart == rStart && lEnd == rEnd
        default:
            return false
        }
    }
}