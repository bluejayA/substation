import Foundation

// MARK: - Cross-Platform Timer Abstraction

/// A timer that works consistently across all platforms, including Linux
/// Provides Timer.scheduledTimer functionality on macOS/iOS and Task-based timers on Linux
public final class CrossPlatformTimer: @unchecked Sendable {

    private let timer: AnyObject

    private init(timer: AnyObject) {
        self.timer = timer
    }

    /// Create a cross-platform timer
    /// - Parameters:
    ///   - interval: The time interval between timer firings
    ///   - repeats: Whether the timer should repeat
    ///   - action: The action to perform when the timer fires
    /// - Returns: A CrossPlatformTimer instance
    public static func createTimer(
        interval: TimeInterval,
        repeats: Bool,
        action: @escaping @Sendable () -> Void
    ) -> CrossPlatformTimer {
        #if canImport(Foundation) && !os(Linux)
        // Use Foundation Timer on macOS/iOS
        let foundationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
            action()
        }
        return CrossPlatformTimer(timer: foundationTimer)
        #else
        // Use Task-based timer on Linux
        let taskTimer = TaskTimer(interval: interval, repeats: repeats, action: action)
        return CrossPlatformTimer(timer: taskTimer)
        #endif
    }

    /// Create a repeating timer using Swift Concurrency
    /// - Parameters:
    ///   - interval: The time interval between timer firings
    ///   - tolerance: The tolerance for timing (ignored on Linux)
    ///   - action: The action to perform when the timer fires
    /// - Returns: A CrossPlatformTimer instance
    public static func createRepeatingTimer(
        interval: TimeInterval,
        tolerance: TimeInterval = 0.1,
        action: @escaping @Sendable () -> Void
    ) -> CrossPlatformTimer {
        let taskTimer = TaskTimer(interval: interval, repeats: true, action: action)
        return CrossPlatformTimer(timer: taskTimer)
    }

    /// Create a one-shot timer using Swift Concurrency
    /// - Parameters:
    ///   - delay: The delay before the timer fires
    ///   - action: The action to perform when the timer fires
    /// - Returns: A CrossPlatformTimer instance
    public static func createOneShotTimer(
        delay: TimeInterval,
        action: @escaping @Sendable () -> Void
    ) -> CrossPlatformTimer {
        let taskTimer = TaskTimer(interval: delay, repeats: false, action: action)
        return CrossPlatformTimer(timer: taskTimer)
    }

    /// Invalidate the timer
    public func invalidate() {
        #if canImport(Foundation) && !os(Linux)
        if let foundationTimer = timer as? Timer {
            foundationTimer.invalidate()
        }
        #endif

        if let taskTimer = timer as? TaskTimer {
            taskTimer.invalidate()
        }
    }
}

// MARK: - Task-Based Timer Implementation

/// Task-based timer for cross-platform compatibility
public final class TaskTimer: @unchecked Sendable {
    private let task: Task<Void, Never>

    public init(interval: TimeInterval, repeats: Bool, action: @escaping @Sendable () -> Void) {
        if repeats {
            self.task = Task {
                while !Task.isCancelled {
                    action()
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        } else {
            self.task = Task {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled {
                    action()
                }
            }
        }
    }

    /// Cancel the timer
    public func invalidate() {
        task.cancel()
    }

    deinit {
        task.cancel()
    }
}

// MARK: - Timer Wrapper for Legacy Support

/// Wrapper to provide unified interface for different timer types
public final class TimerWrapper: @unchecked Sendable {
    private let timer: AnyObject

    public init(timer: AnyObject) {
        self.timer = timer
    }

    /// Invalidate the wrapped timer
    public func invalidate() {
        #if canImport(Foundation) && !os(Linux)
        if let foundationTimer = timer as? Timer {
            foundationTimer.invalidate()
            return
        }
        #endif

        if let taskTimer = timer as? TaskTimer {
            taskTimer.invalidate()
            return
        }

        if let crossPlatformTimer = timer as? CrossPlatformTimer {
            crossPlatformTimer.invalidate()
            return
        }
    }
}

// MARK: - Helper Functions

/// Create a cross-platform timer and return as AnyObject for compatibility
/// - Parameters:
///   - interval: The time interval between timer firings
///   - repeats: Whether the timer should repeat
///   - action: The action to perform when the timer fires
/// - Returns: AnyObject timer that can be invalidated with invalidateTimer()
public func createCompatibleTimer(
    interval: TimeInterval,
    repeats: Bool,
    action: @escaping @Sendable () -> Void
) -> AnyObject {
    return CrossPlatformTimer.createTimer(interval: interval, repeats: repeats, action: action)
}

/// Safely invalidate any timer object
/// - Parameter timer: The timer to invalidate (can be Timer, TaskTimer, CrossPlatformTimer, or TimerWrapper)
public func invalidateTimer(_ timer: AnyObject?) {
    guard let timer = timer else { return }

    #if canImport(Foundation) && !os(Linux)
    if let foundationTimer = timer as? Timer {
        foundationTimer.invalidate()
        return
    }
    #endif

    if let crossPlatformTimer = timer as? CrossPlatformTimer {
        crossPlatformTimer.invalidate()
        return
    }

    if let taskTimer = timer as? TaskTimer {
        taskTimer.invalidate()
        return
    }

    if let timerWrapper = timer as? TimerWrapper {
        timerWrapper.invalidate()
        return
    }
}

