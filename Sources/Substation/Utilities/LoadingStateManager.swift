import Foundation
import SwiftTUI
import CrossPlatformTimer

// MARK: - Loading State Types

/// Different types of loading states for various UI scenarios
public enum LoadingStateType: Sendable {
    case skeleton           // Show skeleton layout for list views
    case spinner           // Simple spinner for single operations
    case progressBar       // Progress bar for multi-stage operations
    case dots              // Animated dots for subtle loading
    case pulse             // Pulsing animation for content placeholders
    case custom(String)    // Custom loading animation

    var animationFrames: [String] {
        switch self {
        case .spinner:
            return ["|", "/", "-", "\\"]
        case .dots:
            return ["   ", ".  ", ".. ", "..."]
        case .pulse:
            return [".", ":", "|", "#", "|", ":"]
        case .custom(let frames):
            return [frames]
        default:
            return ["|", "/", "-", "\\"]
        }
    }

    var frameInterval: TimeInterval {
        switch self {
        case .spinner:
            return 0.1
        case .dots:
            return 0.5
        case .pulse:
            return 0.3
        case .progressBar:
            return 0.1
        case .skeleton:
            return 0.8
        case .custom:
            return 0.2
        }
    }
}

/// Loading state for a specific UI component or view
public struct LoadingState: Sendable {
    let id: String
    let type: LoadingStateType
    let message: String
    let startTime: Date
    let estimatedDuration: TimeInterval?
    let isCancellable: Bool
    var currentFrame: Int
    var isActive: Bool

    init(id: String, type: LoadingStateType, message: String,
         estimatedDuration: TimeInterval? = nil, isCancellable: Bool = false) {
        self.id = id
        self.type = type
        self.message = message
        self.startTime = Date()
        self.estimatedDuration = estimatedDuration
        self.isCancellable = isCancellable
        self.currentFrame = 0
        self.isActive = true
    }
}

/// Context for loading operations
public struct LoadingContext {
    let viewId: String
    let operation: String
    let resourceType: String?
    let expectedItems: Int?
    let priority: LoadingPriority

    enum LoadingPriority: Int, Comparable {
        case background = 0
        case normal = 1
        case high = 2
        case critical = 3

        public static func < (lhs: LoadingPriority, rhs: LoadingPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Loading State Manager

/// Manages loading states and transitions for professional user experience
@MainActor
public final class LoadingStateManager: Sendable {

    // MARK: - Public Properties

    public private(set) var activeLoadingStates: [String: LoadingState] = [:]
    public private(set) var skeletonStates: [String: SkeletonLoadingState] = [:]

    // MARK: - Private Properties

    private var loadingTimers: [String: AnyObject] = [:]
    private var animationTimers: [String: AnyObject] = [:]
    private var progressUpdateHandlers: [String: (Double) -> Void] = [:]
    private var completionHandlers: [String: (Bool) -> Void] = [:]

    // Performance tracking
    private var loadingMetrics: [String: LoadingMetrics] = [:]
    private let maxActiveLoadingStates = 20

    // MARK: - Loading State Management

    /// Starts a loading state with the specified configuration
    public func startLoading(id: String, type: LoadingStateType, message: String,
                           context: LoadingContext, estimatedDuration: TimeInterval? = nil,
                           isCancellable: Bool = false) {
        let loadingState = LoadingState(
            id: id,
            type: type,
            message: message,
            estimatedDuration: estimatedDuration,
            isCancellable: isCancellable
        )

        activeLoadingStates[id] = loadingState
        loadingMetrics[id] = LoadingMetrics(context: context, startTime: Date())

        // Start animation timer
        startAnimationTimer(for: id, type: type)

        // Start progress tracking if duration is estimated
        if let duration = estimatedDuration {
            startProgressTimer(for: id, duration: duration)
        }
    }

    /// Updates the message for an active loading state
    public func updateMessage(id: String, message: String) {
        guard var loadingState = activeLoadingStates[id] else { return }
        loadingState = LoadingState(
            id: loadingState.id,
            type: loadingState.type,
            message: message,
            estimatedDuration: loadingState.estimatedDuration,
            isCancellable: loadingState.isCancellable
        )
        activeLoadingStates[id] = loadingState
    }

    /// Updates progress for a loading state (0.0 to 1.0)
    public func updateProgress(id: String, progress: Double) {
        progressUpdateHandlers[id]?(max(0.0, min(1.0, progress)))
    }

    /// Completes a loading state
    public func completeLoading(id: String, success: Bool = true) {
        guard let _ = activeLoadingStates[id] else { return }

        // Update metrics
        if var metrics = loadingMetrics[id] {
            metrics.endTime = Date()
            metrics.wasSuccessful = success
            loadingMetrics[id] = metrics
        }

        // Stop timers
        if let timer = loadingTimers[id] {
            invalidateTimer(timer)
        }
        loadingTimers.removeValue(forKey: id)
        if let timer = animationTimers[id] {
            invalidateTimer(timer)
        }
        animationTimers.removeValue(forKey: id)

        // Call completion handler
        completionHandlers[id]?(success)

        // Remove loading state
        activeLoadingStates.removeValue(forKey: id)
        skeletonStates.removeValue(forKey: id)

        // Cleanup handlers
        progressUpdateHandlers.removeValue(forKey: id)
        completionHandlers.removeValue(forKey: id)

        // Cleanup metrics after delay
        Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            loadingMetrics.removeValue(forKey: id)
        }
    }

    /// Cancels an active loading state
    public func cancelLoading(id: String) {
        guard let loadingState = activeLoadingStates[id],
              loadingState.isCancellable else { return }
        completeLoading(id: id, success: false)
    }

    // MARK: - Skeleton Loading

    /// Starts skeleton loading for list views
    public func startSkeletonLoading(id: String, itemCount: Int, itemHeight: Int = 3,
                                   context: LoadingContext) {
        let skeletonState = SkeletonLoadingState(
            id: id,
            itemCount: itemCount,
            itemHeight: itemHeight,
            animationPhase: 0
        )

        skeletonStates[id] = skeletonState
        loadingMetrics[id] = LoadingMetrics(context: context, startTime: Date())

        // Start skeleton animation
        startSkeletonAnimation(for: id)
    }

    /// Updates skeleton loading item count
    public func updateSkeletonItemCount(id: String, itemCount: Int) {
        guard var skeletonState = skeletonStates[id] else { return }
        skeletonState.itemCount = itemCount
        skeletonStates[id] = skeletonState
    }

    // MARK: - Animation Management

    private func startAnimationTimer(for id: String, type: LoadingStateType) {
        let timer = createCompatibleTimer(interval: type.frameInterval, repeats: true, action: { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateAnimation(for: id, type: type)
            }
        })
        animationTimers[id] = timer
    }

    private func updateAnimation(for id: String, type: LoadingStateType) {
        guard var loadingState = activeLoadingStates[id] else { return }

        let frames = type.animationFrames
        loadingState.currentFrame = (loadingState.currentFrame + 1) % frames.count

        activeLoadingStates[id] = loadingState
    }

    private func startSkeletonAnimation(for id: String) {
        let timer = createCompatibleTimer(interval: 0.8, repeats: true, action: { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateSkeletonAnimation(for: id)
            }
        })
        animationTimers[id] = timer
    }

    private func updateSkeletonAnimation(for id: String) {
        guard var skeletonState = skeletonStates[id] else { return }
        skeletonState.animationPhase = (skeletonState.animationPhase + 1) % 4
        skeletonStates[id] = skeletonState
    }

    private func startProgressTimer(for id: String, duration: TimeInterval) {
        let startTime = Date()
        let timer = createCompatibleTimer(interval: 0.1, repeats: true, action: { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(0.95, elapsed / duration) // Cap at 95% for estimated progress
                self.updateProgress(id: id, progress: progress)

                if elapsed >= duration {
                    if let timer = self.loadingTimers[id] {
                        invalidateTimer(timer)
                    }
                    self.loadingTimers.removeValue(forKey: id)
                }
            }
        })
        loadingTimers[id] = timer
    }

    // MARK: - Handler Management

    /// Sets a progress update handler for a loading state
    public func setProgressUpdateHandler(id: String, handler: @escaping (Double) -> Void) {
        progressUpdateHandlers[id] = handler
    }

    /// Sets a completion handler for a loading state
    public func setCompletionHandler(id: String, handler: @escaping (Bool) -> Void) {
        completionHandlers[id] = handler
    }

    // MARK: - Query Methods

    /// Gets the current loading state for an ID
    public func getLoadingState(for id: String) -> LoadingState? {
        return activeLoadingStates[id]
    }

    /// Checks if a loading state is currently active
    public func isLoading(_ id: String) -> Bool {
        return activeLoadingStates[id] != nil
    }

    /// Gets all active loading state IDs
    public var activeLoadingIds: [String] {
        return Array(activeLoadingStates.keys)
    }

    /// Gets skeleton loading state for an ID
    public func getSkeletonState(for id: String) -> SkeletonLoadingState? {
        return skeletonStates[id]
    }

    /// Checks if skeleton loading is active for an ID
    public func isSkeletonLoading(_ id: String) -> Bool {
        return skeletonStates[id] != nil
    }

    // MARK: - Cleanup

    /// Stops all active loading states
    public func stopAllLoading() {
        let activeIds = Array(activeLoadingStates.keys)
        for id in activeIds {
            completeLoading(id: id, success: false)
        }

        let skeletonIds = Array(skeletonStates.keys)
        for id in skeletonIds {
            completeLoading(id: id, success: false)
        }
    }

    /// Cleans up completed loading metrics
    public func cleanupMetrics() {
        let cutoffTime = Date().addingTimeInterval(-300) // 5 minutes ago
        loadingMetrics = loadingMetrics.filter { _, metrics in
            guard let endTime = metrics.endTime else { return true } // Keep active
            return endTime > cutoffTime
        }
    }

    // MARK: - Performance Analysis

    /// Gets performance metrics for a loading operation
    public func getMetrics(for id: String) -> LoadingMetrics? {
        return loadingMetrics[id]
    }

    /// Analyzes loading performance patterns
    public func analyzeLoadingPerformance() -> LoadingAnalysis {
        let completedMetrics = loadingMetrics.values.filter { $0.endTime != nil }
        let averageDuration = completedMetrics.isEmpty ? 0 :
            completedMetrics.reduce(0) { $0 + ($1.duration ?? 0) } / Double(completedMetrics.count)

        let slowOperations = completedMetrics.filter { ($0.duration ?? 0) > 10.0 }
        let failedOperations = completedMetrics.filter { !($0.wasSuccessful ?? true) }

        return LoadingAnalysis(
            totalOperations: completedMetrics.count,
            averageDuration: averageDuration,
            slowOperationCount: slowOperations.count,
            failureRate: completedMetrics.isEmpty ? 0 : Double(failedOperations.count) / Double(completedMetrics.count),
            recommendations: generatePerformanceRecommendations(completedMetrics)
        )
    }

    private func generatePerformanceRecommendations(_ metrics: [LoadingMetrics]) -> [String] {
        var recommendations: [String] = []

        let longLoadingOps = metrics.filter { ($0.duration ?? 0) > 20.0 }
        if longLoadingOps.count > 3 {
            recommendations.append("Consider implementing pagination for large data sets")
        }

        let networkOps = metrics.filter { $0.context.operation.contains("fetch") || $0.context.operation.contains("load") }
        if networkOps.count > 10 {
            recommendations.append("Cache frequently accessed data to reduce network requests")
        }

        let failedOps = metrics.filter { !($0.wasSuccessful ?? true) }
        if failedOps.count > 2 {
            recommendations.append("Implement retry logic for failed operations")
        }

        return recommendations
    }

    // MARK: - Rendering Helpers

    /// Renders a loading indicator for the specified state
    public func renderLoadingIndicator(for id: String, width: Int = 40) -> [Text] {
        guard let loadingState = activeLoadingStates[id] else { return [] }

        switch loadingState.type {
        case .spinner:
            return renderSpinner(loadingState, width: width)
        case .progressBar:
            return renderProgressBar(loadingState, width: width)
        case .dots:
            return renderDots(loadingState, width: width)
        case .pulse:
            return renderPulse(loadingState, width: width)
        case .skeleton:
            return [] // Skeleton rendering is handled separately
        case .custom(let customText):
            return [Text(" \(customText) ").muted()]
        }
    }

    private func renderSpinner(_ state: LoadingState, width: Int) -> [Text] {
        let frames = state.type.animationFrames
        let currentFrameText = frames[state.currentFrame]
        let message = state.message
        let padding = String(repeating: " ", count: max(0, (width - message.count - 3) / 2))
        return [Text("\(padding)\(currentFrameText) \(message)").muted()]
    }

    private func renderProgressBar(_ state: LoadingState, width: Int) -> [Text] {
        let elapsed = Date().timeIntervalSince(state.startTime)
        let progress = state.estimatedDuration.map { elapsed / $0 } ?? 0.0
        let progressWidth = max(2, width - state.message.count - 10)
        let filledWidth = Int(progress * Double(progressWidth))
        let emptyWidth = progressWidth - filledWidth

        let progressBar = String(repeating: "=", count: filledWidth) + String(repeating: "-", count: emptyWidth)
        let percentage = Int(min(100, progress * 100))
        return [Text(" \(state.message) [\(progressBar)] \(percentage)%").muted()]
    }

    private func renderDots(_ state: LoadingState, width: Int) -> [Text] {
        let frames = state.type.animationFrames
        let currentFrameText = frames[state.currentFrame]
        let message = state.message
        let padding = String(repeating: " ", count: max(0, (width - message.count - 4) / 2))
        return [Text("\(padding)\(message)\(currentFrameText)").muted()]
    }

    private func renderPulse(_ state: LoadingState, width: Int) -> [Text] {
        let frames = state.type.animationFrames
        let currentFrameText = frames[state.currentFrame]
        let message = state.message
        let padding = String(repeating: " ", count: max(0, (width - message.count - 3) / 2))
        return [Text("\(padding)\(currentFrameText) \(message)").muted()]
    }

    /// Renders skeleton loading placeholder
    public func renderSkeletonLoading(for id: String, width: Int = 80) -> [Text] {
        guard let skeletonState = skeletonStates[id] else { return [] }

        var lines: [Text] = []
        let shimmerChars = ["#", ":", ".", " "]
        let shimmerChar = shimmerChars[skeletonState.animationPhase]

        for i in 0..<skeletonState.itemCount {
            for row in 0..<skeletonState.itemHeight {
                if row == 0 {
                    // Main content line
                    let contentWidth = Int.random(in: width/2...width-10)
                    let content = String(repeating: shimmerChar, count: contentWidth)
                    lines.append(Text(content).muted())
                } else {
                    // Secondary lines (shorter)
                    let contentWidth = Int.random(in: width/4...width/2)
                    let content = String(repeating: shimmerChar, count: contentWidth)
                    let padding = String(repeating: " ", count: 2)
                    lines.append(Text("\(padding)\(content)").muted())
                }
            }
            if i < skeletonState.itemCount - 1 {
                lines.append(Text(" ")) // Spacer between items
            }
        }

        return lines
    }
}

// MARK: - Supporting Types

/// State for skeleton loading animations
public struct SkeletonLoadingState {
    let id: String
    var itemCount: Int
    let itemHeight: Int
    var animationPhase: Int
}

/// Performance metrics for loading operations
public struct LoadingMetrics {
    let context: LoadingContext
    let startTime: Date
    var endTime: Date?
    var wasSuccessful: Bool?

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

/// Analysis result for loading performance
public struct LoadingAnalysis {
    let totalOperations: Int
    let averageDuration: TimeInterval
    let slowOperationCount: Int
    let failureRate: Double
    let recommendations: [String]
}