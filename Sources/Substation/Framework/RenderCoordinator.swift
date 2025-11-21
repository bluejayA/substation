import Foundation
import SwiftNCurses

/// Coordinates rendering optimization and dirty region tracking.
/// Manages performance monitoring, adaptive polling, and UI caching.
@MainActor
final class RenderCoordinator {

    // MARK: - Render State

    /// Flag indicating if screen needs redraw
    var needsRedraw: Bool = true

    /// Last time the screen was drawn
    var lastDrawTime: Date = Date()

    /// Minimum time between redraws (~30fps)
    var redrawThrottleInterval: TimeInterval = 0.032

    // MARK: - Performance Tracking

    /// Last time performance was logged
    var lastPerformanceLog: Date = Date()

    /// Interval for performance logging (30 seconds)
    var performanceLogInterval: TimeInterval = 30.0

    /// Previous scroll offset for change detection
    var previousScrollOffset: Int = 0

    /// Last time a scroll event occurred
    var lastScrollTime: Date = Date()

    /// Count of scroll events for batching
    var scrollEventCount: Int = 0

    /// Timer for batching scroll events
    var scrollBatchTimer: Timer?

    // MARK: - Adaptive Polling

    /// Last time input was received
    private var lastInputTime: Date = Date()

    /// Count of consecutive idle polls
    private var consecutiveIdlePolls: Int = 0

    /// Current sleep interval for adaptive polling (starts at 5ms)
    private var currentSleepInterval: UInt64 = 5_000_000

    // MARK: - Dependencies

    /// Render optimizer for partial updates
    let renderOptimizer: RenderOptimizer

    /// Performance monitor for metrics
    let performanceMonitor: PerformanceMonitor

    /// Virtual list controllers by view identifier
    var virtualListControllers: [String: VirtualListController] = [:]

    /// Search controllers by view identifier
    var searchControllers: [String: ListSearchController] = [:]

    // MARK: - Initialization

    /// Creates a new render coordinator with default configuration
    init() {
        self.renderOptimizer = RenderOptimizer()
        self.performanceMonitor = PerformanceMonitor()
    }

    /// Creates a new render coordinator with existing dependencies
    /// - Parameters:
    ///   - renderOptimizer: Existing render optimizer to use
    ///   - performanceMonitor: Existing performance monitor to use
    init(renderOptimizer: RenderOptimizer, performanceMonitor: PerformanceMonitor) {
        self.renderOptimizer = renderOptimizer
        self.performanceMonitor = performanceMonitor
    }

    // MARK: - Redraw Management

    /// Mark that the screen needs redraw
    func markNeedsRedraw() {
        needsRedraw = true
        renderOptimizer.markMainPanelDirty()
    }

    /// Check if we should redraw (respecting throttle)
    /// - Returns: true if redraw should proceed
    func shouldRedraw() -> Bool {
        return renderOptimizer.shouldRender(force: needsRedraw)
    }

    /// Force immediate redraw (for important updates)
    func forceRedraw() {
        needsRedraw = true
        renderOptimizer.markFullScreenDirty()
        lastDrawTime = Date(timeIntervalSince1970: 0) // Force past throttle
    }

    /// Mark that the screen was drawn
    func markDrawCompleted() {
        needsRedraw = false
        renderOptimizer.markClean()
    }

    // MARK: - Dirty Region Marking

    /// Mark header region as dirty
    func markHeaderDirty() {
        renderOptimizer.markHeaderDirty()
    }

    /// Mark sidebar region as dirty
    func markSidebarDirty() {
        renderOptimizer.markSidebarDirty()
    }

    /// Mark status bar region as dirty
    func markStatusBarDirty() {
        renderOptimizer.markStatusBarDirty()
    }

    /// Mark that a scroll operation occurred
    func markScrollOperation() {
        renderOptimizer.markMainPanelDirty()
        needsRedraw = true
    }

    /// Mark that a view transition occurred for full screen redraw
    func markViewTransition() {
        renderOptimizer.markViewTransitionDirty()
        needsRedraw = true
    }

    // MARK: - Adaptive Polling

    /// Mark that input was received - resets adaptive polling
    func markInputReceived() {
        lastInputTime = Date()
        consecutiveIdlePolls = 0
        currentSleepInterval = 5_000_000 // 5ms for active periods
    }

    /// Get adaptive sleep interval for polling based on activity
    /// - Returns: Sleep interval in nanoseconds
    func getAdaptiveSleepInterval() -> UInt64 {
        let timeSinceInput = Date().timeIntervalSince(lastInputTime)

        if timeSinceInput < 0.1 {
            return 5_000_000 // 5ms - active input
        } else if timeSinceInput < 1.0 {
            return 10_000_000 // 10ms - recent input
        } else if timeSinceInput < 5.0 {
            return 20_000_000 // 20ms - cooling down
        } else {
            consecutiveIdlePolls += 1
            if consecutiveIdlePolls > 100 {
                return 50_000_000 // 50ms - idle
            }
            return 30_000_000 // 30ms - mostly idle
        }
    }

    /// Get current consecutive idle poll count
    /// - Returns: Number of consecutive polls without input
    func getConsecutiveIdlePolls() -> Int {
        return consecutiveIdlePolls
    }

    /// Set consecutive idle poll count
    /// - Parameter count: New poll count value
    func setConsecutiveIdlePolls(_ count: Int) {
        consecutiveIdlePolls = count
    }

    /// Get current sleep interval
    /// - Returns: Current sleep interval in nanoseconds
    func getCurrentSleepInterval() -> UInt64 {
        return currentSleepInterval
    }

    /// Set current sleep interval
    /// - Parameter interval: New sleep interval in nanoseconds
    func setCurrentSleepInterval(_ interval: UInt64) {
        currentSleepInterval = interval
    }

    /// Calculate and update sleep interval based on idle polling state
    /// Uses exponential backoff with caps
    func updateAdaptiveSleepInterval() {
        // Exponential backoff with caps:
        // 0-5 polls: 5ms (responsive for immediate input)
        // 6-15 polls: 10ms (short idle)
        // 16-30 polls: 20ms (medium idle)
        // 31+ polls: 30ms (long idle, saves CPU)
        if consecutiveIdlePolls <= 5 {
            currentSleepInterval = 5_000_000 // 5ms
        } else if consecutiveIdlePolls <= 15 {
            currentSleepInterval = 10_000_000 // 10ms
        } else if consecutiveIdlePolls <= 30 {
            currentSleepInterval = 20_000_000 // 20ms
        } else {
            currentSleepInterval = 30_000_000 // 30ms max for deep idle
        }
    }

    /// Increment the idle poll counter
    func incrementIdlePolls() {
        consecutiveIdlePolls += 1
    }

    // MARK: - UI Cache Management

    /// Clear UI caches when view changes
    func handleUICacheClearing() {
        virtualListControllers.removeAll()
        searchControllers.removeAll()
    }

    // MARK: - Render Plan

    /// Get the current render plan
    /// - Parameters:
    ///   - screenRows: Screen height
    ///   - screenCols: Screen width
    /// - Returns: Render plan indicating what to redraw
    func getRenderPlan(screenRows: Int32, screenCols: Int32) -> RenderPlan {
        return renderOptimizer.getRenderPlan(screenRows: screenRows, screenCols: screenCols)
    }

    // MARK: - Performance Optimization

    /// Reduce animation frequency for performance
    func reduceAnimationFrequency() {
        renderOptimizer.reduceAnimationFrequency()
    }

    /// Optimize rendering frequency
    func optimizeRenderingFrequency() {
        renderOptimizer.optimizeRenderingFrequency()
    }

    /// Reset rendering frequency to default
    func resetRenderingFrequency() {
        renderOptimizer.resetRenderingFrequency()
    }
}
