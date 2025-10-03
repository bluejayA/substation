import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Cross-Platform Timer Abstraction

/// Cross-platform timer abstraction for async contexts
public class CrossPlatformTimer {

    /// Create a cross-platform timer that works in async contexts
    public static func createTimer(
        interval: TimeInterval,
        repeats: Bool,
        action: @escaping @Sendable () -> Void
    ) -> AnyObject {
        #if canImport(Foundation) && !os(Linux)
        // Use Foundation Timer on macOS/iOS
        return Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
            action()
        }
        #else
        // Use Task-based approach on Linux
        let task = repeats
            ? createRepeatingTimer(interval: interval, action: action)
            : createOneShotTimer(delay: interval, action: action)
        return TimerWrapper(task: task)
        #endif
    }

    /// Create a repeating timer using Task
    public static func createRepeatingTimer(
        interval: TimeInterval,
        tolerance: TimeInterval = 0.1,
        action: @escaping @Sendable () -> Void
    ) -> Task<Void, Never> {
        return Task { @MainActor in
            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Create a one-shot timer using Task
    public static func createOneShotTimer(
        delay: TimeInterval,
        action: @escaping @Sendable () -> Void
    ) -> Task<Void, Never> {
        return Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                action()
            }
        }
    }
}

/// Wrapper for Task-based timers to provide unified interface
public final class TimerWrapper: @unchecked Sendable {
    private let task: Task<Void, Never>

    public init(task: Task<Void, Never>) {
        self.task = task
    }

    /// Cancel the timer (equivalent to Timer.invalidate())
    public func invalidate() {
        task.cancel()
    }
}

/// Helper function to invalidate any timer-like object
public func invalidateTimer(_ timer: AnyObject) {
    if let foundationTimer = timer as? Timer {
        foundationTimer.invalidate()
    } else if let wrapper = timer as? TimerWrapper {
        wrapper.invalidate()
    }
}