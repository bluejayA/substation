// Sources/Substation/Framework/RefreshManager.swift
import Foundation

/// Manages auto-refresh timing and user activity tracking for the TUI
///
/// This class handles the intelligent refresh system that:
/// - Defers auto-refresh during user activity to prevent UI disruption
/// - Enables fast refresh after operations to show state transitions
/// - Allows cycling through different refresh intervals
/// - Supports view-specific refresh timing (e.g., faster for floating IPs)
@MainActor
final class RefreshManager {

    // MARK: - Configuration

    /// Whether auto-refresh is enabled
    var autoRefresh: Bool = true

    /// Base refresh interval (can be cycled by user)
    var baseRefreshInterval: TimeInterval

    /// Available refresh intervals for cycling
    private let availableIntervals: [TimeInterval] = [3.0, 5.0, 7.0, 10.0, 15.0, 30.0]

    // MARK: - Timing State

    /// Last time data was refreshed
    var lastRefresh: Date = Date()

    /// Time until which fast refresh should be used (after operations)
    private var fastRefreshUntil: Date?

    /// Last time user interacted with the UI
    var lastUserActivityTime: Date = Date()

    /// Cooldown period after user activity before resuming auto-refresh
    private let activityCooldownPeriod: TimeInterval = 3.0

    // MARK: - View State Reference

    /// Reference to get current view for view-specific refresh timing
    var getCurrentView: (() -> ViewMode)?

    // MARK: - Initialization

    /// Initialize the refresh manager with a base refresh interval
    /// - Parameter baseRefreshInterval: The default refresh interval in seconds
    init(baseRefreshInterval: TimeInterval = 10.0) {
        self.baseRefreshInterval = baseRefreshInterval
    }

    // MARK: - Computed Properties

    /// Current effective refresh interval based on state
    ///
    /// Returns a faster interval (3s) after operations, view-specific intervals
    /// for certain views, or the base interval otherwise.
    var refreshInterval: TimeInterval {
        // Fast refresh after operations
        if let until = fastRefreshUntil, Date() < until {
            return 3.0
        }

        // Floating IP views need faster refresh for real-time status
        if let currentView = getCurrentView?() {
            if currentView == .floatingIPs || currentView == .floatingIPServerSelect {
                return 1.0
            }
        }

        return baseRefreshInterval
    }

    // MARK: - Public Methods

    /// Check if it's time to refresh
    ///
    /// Returns false if:
    /// - Auto-refresh is disabled
    /// - User activity occurred within the cooldown period
    /// - Refresh interval has not elapsed
    func shouldRefresh() -> Bool {
        guard autoRefresh else { return false }

        // Defer refresh during user activity
        let timeSinceActivity = Date().timeIntervalSince(lastUserActivityTime)
        if timeSinceActivity < activityCooldownPeriod {
            return false
        }

        // Check if refresh interval has elapsed
        let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceRefresh >= refreshInterval
    }

    /// Mark that user activity occurred
    ///
    /// This resets the activity timer and defers auto-refresh
    func markUserActivity() {
        lastUserActivityTime = Date()
    }

    /// Mark that a refresh occurred
    ///
    /// Updates the last refresh timestamp
    func markRefreshCompleted() {
        lastRefresh = Date()
    }

    /// Cycle through available refresh intervals
    ///
    /// Moves to the next interval in the list, wrapping around at the end.
    /// Returns a message describing the new interval for UI display.
    /// - Returns: A formatted string describing the new interval
    func cycleRefreshInterval() -> String {
        if let currentIndex = availableIntervals.firstIndex(of: baseRefreshInterval) {
            let nextIndex = (currentIndex + 1) % availableIntervals.count
            baseRefreshInterval = availableIntervals[nextIndex]
        } else {
            // If current interval not in list, start from first
            baseRefreshInterval = availableIntervals[0]
        }

        // Format interval for display
        if baseRefreshInterval >= 60 {
            let minutes = Int(baseRefreshInterval / 60)
            return "Auto-refresh: \(minutes)m"
        } else {
            return "Auto-refresh: \(Int(baseRefreshInterval))s"
        }
    }

    /// Enable fast refresh for a duration after an operation
    ///
    /// This provides rapid updates to show state transitions after operations
    /// like server start/stop, volume attach/detach, etc.
    /// - Parameter duration: How long to use fast refresh in seconds
    func enableFastRefresh(duration: TimeInterval = 60.0) {
        fastRefreshUntil = Date().addingTimeInterval(duration)
    }

    /// Trigger immediate refresh (for after operations)
    ///
    /// Sets the last refresh to distant past to force immediate refresh check
    /// and enables fast refresh mode for showing state transitions.
    func refreshAfterOperation() {
        lastRefresh = Date.distantPast // Force immediate refresh check
        enableFastRefresh()
    }

    /// Toggle auto-refresh on/off
    ///
    /// - Returns: The new state of auto-refresh
    func toggleAutoRefresh() -> Bool {
        autoRefresh.toggle()
        return autoRefresh
    }

    /// Get time since last user activity
    ///
    /// - Returns: The time interval since the last user activity
    func timeSinceActivity() -> TimeInterval {
        return Date().timeIntervalSince(lastUserActivityTime)
    }

    /// Get time since last refresh
    ///
    /// - Returns: The time interval since the last data refresh
    func timeSinceRefresh() -> TimeInterval {
        return Date().timeIntervalSince(lastRefresh)
    }

    /// Check if user is currently active (within cooldown period)
    ///
    /// - Returns: True if user activity occurred within the cooldown period
    func isUserActive() -> Bool {
        return timeSinceActivity() < activityCooldownPeriod
    }
}
