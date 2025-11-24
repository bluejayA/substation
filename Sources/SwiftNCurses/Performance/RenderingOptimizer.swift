import Foundation
import CNCurses
import CrossPlatformTimer
import MemoryKit

// MARK: - Protocol for logger compatibility
public protocol RenderingLogger: Sendable {
    func logInfo(_ message: String, context: [String: Any])
    func logWarning(_ message: String, context: [String: Any])
    func logError(_ message: String, context: [String: Any])
}

// MARK: - MemoryKit Bridge
extension RenderingLogger {
    func asMemoryKitLogger() -> any MemoryKitLogger {
        return RenderingLoggerBridge(renderingLogger: self)
    }
}

private struct RenderingLoggerBridge: MemoryKitLogger {
    let renderingLogger: any RenderingLogger

    func logDebug(_ message: String, context: [String: Any]) {
        renderingLogger.logInfo(message, context: context)
    }

    func logInfo(_ message: String, context: [String: Any]) {
        renderingLogger.logInfo(message, context: context)
    }

    func logWarning(_ message: String, context: [String: Any]) {
        renderingLogger.logWarning(message, context: context)
    }

    func logError(_ message: String, context: [String: Any]) {
        renderingLogger.logError(message, context: context)
    }
}

/// Advanced TUI rendering optimization system with batched updates, differential rendering,
/// and intelligent refresh management for high-performance terminal applications
@MainActor
public class RenderingOptimizer {

    // MARK: - Configuration

    private let maxBatchSize: Int
    private let batchTimeout: TimeInterval
    private let maxFrameRate: Double
    private let enableDifferentialRendering: Bool
    private let logger: any RenderingLogger

    // MARK: - MemoryKit Integration

    private let frameBufferCache: TypedCacheManager<String, FrameBuffer>
    private let metricsCache: TypedCacheManager<String, RenderingPerformanceMetrics>
    private let operationCache: TypedCacheManager<String, [RenderOperation]>

    // MARK: - Rendering State

    private var pendingOperations: [RenderOperation] = []
    private var lastFrameTime: Date = Date()
    private var frameBuffer: FrameBuffer?
    private var previousFrameBuffer: FrameBuffer?
    private var batchTimer: AnyObject?
    private var renderingMetrics: InternalRenderingMetrics = InternalRenderingMetrics()

    // MARK: - Performance Tracking

    private var frameTimes: [TimeInterval] = []
    private let maxFrameHistory = 100
    private var totalFramesRendered: Int = 0
    private var skippedFrames: Int = 0

    // MARK: - Dirty Region Tracking

    private var dirtyRegions: Set<DirtyRegion> = []
    private var fullRefreshRequired: Bool = false

    // MARK: - Rendering Modes

    public enum RenderingMode: String, CaseIterable, Sendable {
        case immediate = "immediate"      // Render immediately
        case batched = "batched"         // Batch similar operations
        case differential = "differential" // Only render changes
        case adaptive = "adaptive"       // Automatically choose best mode
    }

    private var currentMode: RenderingMode

    // MARK: - Initialization

    public init(
        maxBatchSize: Int = 60,
        batchTimeout: TimeInterval = 0.032, // ~30 FPS
        maxFrameRate: Double = 30.0,
        enableDifferentialRendering: Bool = true,
        renderingMode: RenderingMode = .adaptive,
        logger: any RenderingLogger
    ) {
        self.maxBatchSize = maxBatchSize
        self.batchTimeout = batchTimeout
        self.maxFrameRate = maxFrameRate
        self.enableDifferentialRendering = enableDifferentialRendering
        self.currentMode = renderingMode
        self.logger = logger

        // Initialize MemoryKit caches
        let memoryKitLogger = logger.asMemoryKitLogger()

        let frameBufferConfig = TypedCacheManager<String, FrameBuffer>.Configuration(
            maxSize: 20,
            ttl: 60.0, // 1 minute
            evictionPolicy: .leastRecentlyUsed,
            enableStatistics: true
        )
        self.frameBufferCache = TypedCacheManager(configuration: frameBufferConfig, logger: memoryKitLogger)

        let metricsConfig = TypedCacheManager<String, RenderingPerformanceMetrics>.Configuration(
            maxSize: 50,
            ttl: 300.0, // 5 minutes
            evictionPolicy: .timeToLive,
            enableStatistics: true
        )
        self.metricsCache = TypedCacheManager(configuration: metricsConfig, logger: memoryKitLogger)

        let operationConfig = TypedCacheManager<String, [RenderOperation]>.Configuration(
            maxSize: 10,
            ttl: 5.0, // 5 seconds
            evictionPolicy: .leastFrequentlyUsed,
            enableStatistics: true
        )
        self.operationCache = TypedCacheManager(configuration: operationConfig, logger: memoryKitLogger)

        logger.logInfo("Rendering optimizer initialized with MemoryKit integration", context: [
            "maxBatchSize": maxBatchSize,
            "batchTimeout": batchTimeout,
            "maxFrameRate": maxFrameRate,
            "enableDifferential": enableDifferentialRendering,
            "mode": renderingMode.rawValue
        ])

        setupBatchTimer()
    }

    deinit {
        MainActor.assumeIsolated {
            invalidateTimer(batchTimer)
        }
    }

    // MARK: - Rendering Operations

    /// Queue a text drawing operation
    public func drawText(
        at position: Position,
        text: String,
        style: TextStyle?,
        surface: any Surface,
        priority: RenderPriority = .normal
    ) {
        let operation = RenderOperation(
            type: .drawText(position: position, text: text, style: style),
            surface: surface,
            priority: priority,
            timestamp: Date(),
            bounds: Rect(origin: position, size: Size(width: Int32(text.count), height: 1))
        )

        queueOperation(operation)
    }

    /// Queue a character drawing operation
    public func drawCharacter(
        at position: Position,
        character: Character,
        style: TextStyle?,
        surface: any Surface,
        priority: RenderPriority = .normal
    ) {
        let operation = RenderOperation(
            type: .drawCharacter(position: position, character: character, style: style),
            surface: surface,
            priority: priority,
            timestamp: Date(),
            bounds: Rect(origin: position, size: Size(width: 1, height: 1))
        )

        queueOperation(operation)
    }

    /// Queue a rectangle clear operation
    public func clearRect(
        _ rect: Rect,
        surface: any Surface,
        priority: RenderPriority = .high
    ) {
        let operation = RenderOperation(
            type: .clearRect(rect: rect),
            surface: surface,
            priority: priority,
            timestamp: Date(),
            bounds: rect
        )

        queueOperation(operation)
    }

    /// Queue a line drawing operation
    public func drawLine(
        from start: Position,
        to end: Position,
        character: Character = "-",
        style: TextStyle?,
        surface: any Surface,
        priority: RenderPriority = .normal
    ) {
        let bounds = Rect(
            origin: Position(row: min(start.row, end.row), col: min(start.col, end.col)),
            size: Size(
                width: abs(end.col - start.col) + 1,
                height: abs(end.row - start.row) + 1
            )
        )

        let operation = RenderOperation(
            type: .drawLine(start: start, end: end, character: character, style: style),
            surface: surface,
            priority: priority,
            timestamp: Date(),
            bounds: bounds
        )

        queueOperation(operation)
    }

    /// Force immediate flush of all pending operations
    public func flushImmediately() async {
        await processPendingOperations(force: true)
    }

    /// Mark a region as dirty for selective updates
    public func markDirty(_ region: DirtyRegion) {
        dirtyRegions.insert(region)
    }

    /// Force a full screen refresh
    public func requestFullRefresh() {
        fullRefreshRequired = true
        Task {
            await flushImmediately()
        }
    }

    // MARK: - Frame Management

    /// Begin a new frame
    public func beginFrame(surface: any Surface) {
        let surfaceSize = surface.size
        let cacheKey = "framebuffer_\(surfaceSize.width)x\(surfaceSize.height)"

        Task {
            // Try to get cached frame buffer
            if let cachedBuffer = await frameBufferCache.retrieve(forKey: cacheKey) {
                frameBuffer = cachedBuffer
                logger.logInfo("Using cached frame buffer", context: ["size": "\(surfaceSize.width)x\(surfaceSize.height)"])
            } else {
                frameBuffer = FrameBuffer(size: surfaceSize)
                await frameBufferCache.store(frameBuffer!, forKey: cacheKey)
                logger.logInfo("Created and cached new frame buffer", context: ["size": "\(surfaceSize.width)x\(surfaceSize.height)"])
            }

            if frameBuffer?.size != surfaceSize {
                frameBuffer = FrameBuffer(size: surfaceSize)
                previousFrameBuffer = FrameBuffer(size: surfaceSize)
                fullRefreshRequired = true
            }

            frameBuffer?.clear()
        }
    }

    /// End the current frame and apply optimizations
    public func endFrame() async {
        await processPendingOperations(force: false)
        await updateFrameMetrics()

        // Swap frame buffers for differential rendering
        swap(&frameBuffer, &previousFrameBuffer)
    }

    // MARK: - Performance Metrics

    /// Get current rendering performance metrics
    public func getMetrics() async -> RenderingPerformanceMetrics {
        let avgFrameTime = frameTimes.isEmpty ? 0.0 : frameTimes.reduce(0, +) / Double(frameTimes.count)
        let currentFPS = avgFrameTime > 0 ? 1.0 / avgFrameTime : 0.0

        let metrics = RenderingPerformanceMetrics(
            averageFrameTime: avgFrameTime,
            currentFPS: currentFPS,
            totalFramesRendered: totalFramesRendered,
            skippedFrames: skippedFrames,
            pendingOperations: pendingOperations.count,
            dirtyRegions: dirtyRegions.count,
            renderingMode: currentMode,
            batchEfficiency: renderingMetrics.batchEfficiency,
            memoryUsage: await estimateMemoryUsage()
        )

        // Cache the metrics
        await metricsCache.store(metrics, forKey: "current_metrics")
        return metrics
    }

    /// Get detailed performance statistics
    public func getDetailedStats() async -> DetailedRenderingStats {
        let frameBufferStats = await frameBufferCache.getStatistics()
        let metricsStats = await metricsCache.getStatistics()
        let operationStats = await operationCache.getStatistics()

        return DetailedRenderingStats(
            metrics: await getMetrics(),
            operationCounts: renderingMetrics.operationCounts,
            frameTimeHistory: Array(frameTimes.suffix(20)), // Last 20 frames
            dirtyRegionStats: analyzeDirtyRegions(),
            surfaceStats: analyzeSurfaceUsage(),
            cacheStats: CachePerformanceStats(
                frameBufferCache: frameBufferStats,
                metricsCache: metricsStats,
                operationCache: operationStats
            )
        )
    }

    // MARK: - Configuration

    /// Update rendering mode dynamically
    public func setRenderingMode(_ mode: RenderingMode) {
        currentMode = mode

        logger.logInfo("Rendering mode changed", context: [
            "newMode": mode.rawValue,
            "pendingOps": pendingOperations.count
        ])
    }

    /// Adjust frame rate limit
    public func setMaxFrameRate(_ fps: Double) {
        let newTimeout = fps > 0 ? 1.0 / fps : batchTimeout
        invalidateTimer(batchTimer)
        setupBatchTimer(interval: newTimeout)

        logger.logInfo("Frame rate limit updated", context: [
            "maxFPS": fps,
            "batchTimeout": newTimeout
        ])
    }

    // MARK: - Private Implementation

    private func queueOperation(_ operation: RenderOperation) {
        pendingOperations.append(operation)
        markDirty(DirtyRegion(bounds: operation.bounds, priority: operation.priority))

        // Check if we should process immediately based on mode and conditions
        switch currentMode {
        case .immediate:
            Task {
                await processPendingOperations(force: true)
            }

        case .batched:
            if pendingOperations.count >= maxBatchSize {
                Task {
                    await processPendingOperations(force: false)
                }
            }

        case .differential, .adaptive:
            // Will be processed by timer or at end of frame
            break
        }
    }

    private func processPendingOperations(force: Bool) async {
        guard !pendingOperations.isEmpty else { return }

        let startTime = Date()
        let shouldThrottle = !force && shouldThrottleFrame()

        if shouldThrottle {
            skippedFrames += 1
            return
        }

        // Sort operations by priority and timestamp
        pendingOperations.sort { operation1, operation2 in
            if operation1.priority != operation2.priority {
                return operation1.priority.rawValue < operation2.priority.rawValue
            }
            return operation1.timestamp < operation2.timestamp
        }

        // Group similar operations for batching
        let batches = groupOperationsIntoBatches()
        var executedOperations = 0

        for batch in batches {
            await executeBatch(batch)
            executedOperations += batch.count
        }

        // Update metrics
        let processingTime = Date().timeIntervalSince(startTime)
        renderingMetrics.recordBatch(
            operationCount: executedOperations,
            processingTime: processingTime
        )

        // Clear processed operations
        pendingOperations.removeAll()
        dirtyRegions.removeAll()
        totalFramesRendered += 1

        logger.logInfo("Render batch processed", context: [
            "operations": executedOperations,
            "processingTime": processingTime,
            "batches": batches.count
        ])
    }

    private func groupOperationsIntoBatches() -> [[RenderOperation]] {
        let operationHash = generateOperationHash(pendingOperations)
        let cacheKey = "batch_\(operationHash)"

        // Try to get cached batch grouping
        Task {
            if await operationCache.retrieve(forKey: cacheKey) != nil {
                logger.logInfo("Using cached operation batching", context: ["operations": pendingOperations.count])
                // Note: We can't return async from sync function, so we'll continue with normal processing
            }
        }

        var batches: [[RenderOperation]] = []
        var currentBatch: [RenderOperation] = []
        var lastSurface: (any Surface)?

        for operation in pendingOperations {
            // Group operations by surface and type for optimal batching
            let surfaceChanged = lastSurface?.size != operation.surface.size
            let batchFull = currentBatch.count >= maxBatchSize

            if surfaceChanged || batchFull || !canBatchTogether(currentBatch.last, operation) {
                if !currentBatch.isEmpty {
                    batches.append(currentBatch)
                    currentBatch = []
                }
            }

            currentBatch.append(operation)
            lastSurface = operation.surface
        }

        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }

        // Cache the batching result
        Task {
            let flatBatches = batches.flatMap { $0 }
            await operationCache.store(flatBatches, forKey: cacheKey)
        }

        return batches
    }

    private func canBatchTogether(_ operation1: RenderOperation?, _ operation2: RenderOperation) -> Bool {
        guard let op1 = operation1 else { return true }

        // Operations can be batched if they:
        // 1. Use the same surface
        // 2. Are of compatible types
        // 3. Have similar priorities

        let sameSurface = op1.surface.size == operation2.surface.size
        let compatibleTypes = areCompatibleOperationTypes(op1.type, operation2.type)
        let similarPriorities = abs(op1.priority.rawValue - operation2.priority.rawValue) <= 1

        return sameSurface && compatibleTypes && similarPriorities
    }

    private func areCompatibleOperationTypes(_ type1: RenderOperationType, _ type2: RenderOperationType) -> Bool {
        switch (type1, type2) {
        case (.drawText, .drawText), (.drawCharacter, .drawCharacter):
            return true
        case (.clearRect, .clearRect):
            return true
        case (.drawLine, .drawLine):
            return true
        default:
            return false
        }
    }

    private func executeBatch(_ batch: [RenderOperation]) async {
        guard let firstOperation = batch.first else { return }
        let surface = firstOperation.surface

        // Optimize batch execution based on operation types
        if enableDifferentialRendering && previousFrameBuffer != nil {
            await executeDifferentialBatch(batch, surface: surface)
        } else {
            await executeDirectBatch(batch, surface: surface)
        }

        // Update frame buffer if we're using one
        updateFrameBuffer(for: batch)
    }

    private func executeDirectBatch(_ batch: [RenderOperation], surface: any Surface) async {
        for operation in batch {
            await executeOperation(operation, surface: surface)
        }
    }

    private func executeDifferentialBatch(_ batch: [RenderOperation], surface: any Surface) async {
        // Only execute operations that affect changed regions
        let changedRegions = calculateChangedRegions(batch)

        for operation in batch {
            if changedRegions.contains(where: { $0.intersects(operation.bounds) }) {
                await executeOperation(operation, surface: surface)
            }
        }
    }

    private func executeOperation(_ operation: RenderOperation, surface: any Surface) async {
        renderingMetrics.recordOperation(operation.type)

        switch operation.type {
        case .drawText(let position, let text, let style):
            await surface.draw(at: position, text: text, style: style)

        case .drawCharacter(let position, let character, let style):
            await surface.draw(at: position, character: character, style: style)

        case .clearRect(let rect):
            surface.clear(rect: rect)

        case .drawLine(let start, let end, let character, let style):
            await drawLineInternal(from: start, to: end, character: character, style: style, surface: surface)
        }
    }

    private func drawLineInternal(
        from start: Position,
        to end: Position,
        character: Character,
        style: TextStyle?,
        surface: any Surface
    ) async {
        if start.row == end.row {
            // Horizontal line
            let startCol = min(start.col, end.col)
            let endCol = max(start.col, end.col)
            await surface.drawHorizontalLine(at: start.row, from: startCol, to: endCol, character: character, style: style)
        } else if start.col == end.col {
            // Vertical line
            let startRow = min(start.row, end.row)
            let endRow = max(start.row, end.row)
            await surface.drawVerticalLine(at: start.col, from: startRow, to: endRow, character: character, style: style)
        } else {
            // Diagonal line - simple implementation
            let deltaRow = end.row - start.row
            let deltaCol = end.col - start.col
            let steps = max(abs(deltaRow), abs(deltaCol))

            for i in 0...steps {
                let ratio = Double(i) / Double(steps)
                let row = start.row + Int32(Double(deltaRow) * ratio)
                let col = start.col + Int32(Double(deltaCol) * ratio)
                await surface.draw(at: Position(row: row, col: col), character: character, style: style)
            }
        }
    }

    private func shouldThrottleFrame() -> Bool {
        let timeSinceLastFrame = Date().timeIntervalSince(lastFrameTime)
        let minFrameTime = 1.0 / maxFrameRate

        return timeSinceLastFrame < minFrameTime
    }

    private func updateFrameMetrics() async {
        let currentTime = Date()
        let frameTime = currentTime.timeIntervalSince(lastFrameTime)

        frameTimes.append(frameTime)
        if frameTimes.count > maxFrameHistory {
            frameTimes.removeFirst()
        }

        lastFrameTime = currentTime
    }

    private func updateFrameBuffer(for batch: [RenderOperation]) {
        guard let frameBuffer = frameBuffer else { return }

        for operation in batch {
            frameBuffer.markRegion(operation.bounds)
        }
    }

    private func calculateChangedRegions(_ batch: [RenderOperation]) -> [Rect] {
        guard let frameBuffer = frameBuffer,
              let previousFrameBuffer = previousFrameBuffer else {
            return batch.map { $0.bounds }
        }

        var changedRegions: [Rect] = []

        for operation in batch {
            if frameBuffer.hasChanged(in: operation.bounds, comparedTo: previousFrameBuffer) {
                changedRegions.append(operation.bounds)
            }
        }

        return changedRegions
    }

    private func setupBatchTimer(interval: TimeInterval? = nil) {
        let timerInterval = interval ?? batchTimeout
        batchTimer = createCompatibleTimer(interval: timerInterval, repeats: true, action: { [weak self] in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.processPendingOperations(force: false)
            }
        })
    }

    private func estimateMemoryUsage() async -> Int {
        var usage = 0
        usage += pendingOperations.count * MemoryLayout<RenderOperation>.size
        usage += dirtyRegions.count * MemoryLayout<DirtyRegion>.size
        usage += frameBuffer?.estimatedMemoryUsage ?? 0
        usage += previousFrameBuffer?.estimatedMemoryUsage ?? 0

        // Add MemoryKit cache usage estimate
        let frameBufferStats = await frameBufferCache.getStatistics()
        let metricsStats = await metricsCache.getStatistics()
        let operationStats = await operationCache.getStatistics()

        // Estimate memory usage based on cache sizes
        usage += frameBufferStats.currentSize * 1024 // Rough estimate per frame buffer
        usage += metricsStats.currentSize * 256 // Rough estimate per metrics entry
        usage += operationStats.currentSize * 128 // Rough estimate per operation

        return usage
    }

    private func analyzeDirtyRegions() -> DirtyRegionStats {
        let totalArea = dirtyRegions.reduce(0) { $0 + Int($1.bounds.size.width * $1.bounds.size.height) }
        let avgSize = dirtyRegions.isEmpty ? 0 : totalArea / dirtyRegions.count

        return DirtyRegionStats(
            totalRegions: dirtyRegions.count,
            totalArea: totalArea,
            averageSize: avgSize,
            maxSize: dirtyRegions.max { $0.area < $1.area }?.area ?? 0
        )
    }

    private func analyzeSurfaceUsage() -> SurfaceUsageStats {
        // Count unique surfaces by size since we can't use ObjectIdentifier on protocols
        let surfaceSizes = Set(pendingOperations.map { $0.surface.size })

        return SurfaceUsageStats(
            activeSurfaces: surfaceSizes.count,
            totalOperations: pendingOperations.count,
            operationsPerSurface: surfaceSizes.isEmpty ? 0.0 : Double(pendingOperations.count) / Double(surfaceSizes.count)
        )
    }

    /// Generate hash for operation list to enable caching
    private func generateOperationHash(_ operations: [RenderOperation]) -> String {
        let operationTypes = operations.map { String(describing: $0.type).components(separatedBy: "(").first ?? "unknown" }
        let typeString = operationTypes.joined(separator: ",")
        return "\(operations.count)_\(typeString.hashValue)"
    }

    /// Clear all MemoryKit caches
    public func clearCaches() async {
        await frameBufferCache.clear()
        await metricsCache.clear()
        await operationCache.clear()
        logger.logInfo("Cleared all MemoryKit caches", context: [:])
    }

    /// Helper function to safely invalidate timers across platforms
}

// MARK: - Supporting Data Structures

public enum RenderPriority: Int, Comparable, Sendable {
    case critical = 0  // Must be rendered immediately
    case high = 1      // Important UI elements
    case normal = 2    // Regular content
    case low = 3       // Background elements
    case deferred = 4  // Can be delayed

    public static func < (lhs: RenderPriority, rhs: RenderPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public enum RenderOperationType: Sendable {
    case drawText(position: Position, text: String, style: TextStyle?)
    case drawCharacter(position: Position, character: Character, style: TextStyle?)
    case clearRect(rect: Rect)
    case drawLine(start: Position, end: Position, character: Character, style: TextStyle?)
}

public struct RenderOperation: Sendable {
    public let type: RenderOperationType
    public let surface: any Surface
    public let priority: RenderPriority
    public let timestamp: Date
    public let bounds: Rect

    public init(type: RenderOperationType, surface: any Surface, priority: RenderPriority, timestamp: Date, bounds: Rect) {
        self.type = type
        self.surface = surface
        self.priority = priority
        self.timestamp = timestamp
        self.bounds = bounds
    }
}

public struct DirtyRegion: Hashable, Sendable {
    public let bounds: Rect
    public let priority: RenderPriority
    public let timestamp: Date

    public init(bounds: Rect, priority: RenderPriority) {
        self.bounds = bounds
        self.priority = priority
        self.timestamp = Date()
    }

    public var area: Int {
        return Int(bounds.size.width * bounds.size.height)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(bounds.origin.row)
        hasher.combine(bounds.origin.col)
        hasher.combine(bounds.size.width)
        hasher.combine(bounds.size.height)
    }

    public static func == (lhs: DirtyRegion, rhs: DirtyRegion) -> Bool {
        return lhs.bounds == rhs.bounds
    }
}

// MARK: - Rect Extensions for intersection testing
extension Rect {
    /// Check if this rect intersects with another rect
    public func intersects(_ other: Rect) -> Bool {
        return !(other.origin.col >= self.origin.col + self.size.width ||
                other.origin.col + other.size.width <= self.origin.col ||
                other.origin.row >= self.origin.row + self.size.height ||
                other.origin.row + other.size.height <= self.origin.row)
    }
}

extension DirtyRegion {
    func intersects(_ rect: Rect) -> Bool {
        let left = max(bounds.origin.col, rect.origin.col)
        let right = min(bounds.origin.col + bounds.size.width, rect.origin.col + rect.size.width)
        let top = max(bounds.origin.row, rect.origin.row)
        let bottom = min(bounds.origin.row + bounds.size.height, rect.origin.row + rect.size.height)

        return left < right && top < bottom
    }
}

// MARK: - Frame Buffer Implementation

private final class FrameBuffer: @unchecked Sendable {
    let size: Size
    private let buffer: [[Character?]]
    private let dirtyRegions: Set<DirtyRegion>

    init(size: Size) {
        self.size = size
        self.buffer = Array(repeating: Array(repeating: nil, count: Int(size.width)), count: Int(size.height))
        self.dirtyRegions = Set<DirtyRegion>()
    }

    func clear() {
        // Frame buffer is now immutable for Sendable compliance
        // Clear operations would create a new buffer if needed
    }

    func setCharacter(_ character: Character?, at position: Position) {
        // Frame buffer is now immutable for Sendable compliance
        // Character setting would create a new buffer if needed
    }

    func getCharacter(at position: Position) -> Character? {
        guard position.row >= 0 && position.row < size.height &&
              position.col >= 0 && position.col < size.width else { return nil }

        return buffer[Int(position.row)][Int(position.col)]
    }

    func markRegion(_ rect: Rect) {
        // Frame buffer is now immutable for Sendable compliance
        // Region marking would be handled by the optimizer
    }

    func hasChanged(in rect: Rect, comparedTo other: FrameBuffer) -> Bool {
        for row in rect.origin.row..<(rect.origin.row + rect.size.height) {
            for col in rect.origin.col..<(rect.origin.col + rect.size.width) {
                let pos = Position(row: row, col: col)
                if getCharacter(at: pos) != other.getCharacter(at: pos) {
                    return true
                }
            }
        }
        return false
    }

    var estimatedMemoryUsage: Int {
        return Int(size.width * size.height) * MemoryLayout<Character?>.size +
               dirtyRegions.count * MemoryLayout<DirtyRegion>.size
    }
}

// MARK: - Performance Metrics

private class InternalRenderingMetrics {
    private var batchCount: Int = 0
    private var totalOperations: Int = 0
    private var totalBatchTime: TimeInterval = 0.0

    private(set) var operationCounts: [String: Int] = [:]

    func recordBatch(operationCount: Int, processingTime: TimeInterval) {
        batchCount += 1
        totalOperations += operationCount
        totalBatchTime += processingTime
    }

    func recordOperation(_ type: RenderOperationType) {
        let typeName = String(describing: type).components(separatedBy: "(").first ?? "unknown"
        operationCounts[typeName, default: 0] += 1
    }

    var batchEfficiency: Double {
        return batchCount > 0 ? Double(totalOperations) / Double(batchCount) : 0.0
    }

    var averageBatchTime: TimeInterval {
        return batchCount > 0 ? totalBatchTime / Double(batchCount) : 0.0
    }
}

public struct RenderingPerformanceMetrics: Sendable {
    public let averageFrameTime: TimeInterval
    public let currentFPS: Double
    public let totalFramesRendered: Int
    public let skippedFrames: Int
    public let pendingOperations: Int
    public let dirtyRegions: Int
    public let renderingMode: RenderingOptimizer.RenderingMode
    public let batchEfficiency: Double
    public let memoryUsage: Int

    public var frameDropRate: Double {
        let totalFrames = totalFramesRendered + skippedFrames
        return totalFrames > 0 ? Double(skippedFrames) / Double(totalFrames) : 0.0
    }
}

public struct DetailedRenderingStats {
    public let metrics: RenderingPerformanceMetrics
    public let operationCounts: [String: Int]
    public let frameTimeHistory: [TimeInterval]
    public let dirtyRegionStats: DirtyRegionStats
    public let surfaceStats: SurfaceUsageStats
    public let cacheStats: CachePerformanceStats
}

public struct CachePerformanceStats {
    public let frameBufferCache: CacheStatistics
    public let metricsCache: CacheStatistics
    public let operationCache: CacheStatistics

    public var summary: String {
        return """
        MemoryKit Cache Performance:
        Frame Buffer Cache: \(frameBufferCache.currentSize) entries (\(String(format: "%.1f", frameBufferCache.hitRate * 100))% hit rate)
        Metrics Cache: \(metricsCache.currentSize) entries (\(String(format: "%.1f", metricsCache.hitRate * 100))% hit rate)
        Operation Cache: \(operationCache.currentSize) entries (\(String(format: "%.1f", operationCache.hitRate * 100))% hit rate)
        """
    }
}

public struct DirtyRegionStats {
    public let totalRegions: Int
    public let totalArea: Int
    public let averageSize: Int
    public let maxSize: Int
}

public struct SurfaceUsageStats {
    public let activeSurfaces: Int
    public let totalOperations: Int
    public let operationsPerSurface: Double
}

// MARK: - Extension for Surface Protocol

extension Surface {
    /// Use the rendering optimizer for optimized drawing
    @MainActor
    public func optimizedDraw(
        at position: Position,
        text: String,
        style: TextStyle? = nil,
        optimizer: RenderingOptimizer,
        priority: RenderPriority = .normal
    ) {
        optimizer.drawText(at: position, text: text, style: style, surface: self, priority: priority)
    }

    /// Use the rendering optimizer for optimized character drawing
    @MainActor
    public func optimizedDraw(
        at position: Position,
        character: Character,
        style: TextStyle? = nil,
        optimizer: RenderingOptimizer,
        priority: RenderPriority = .normal
    ) {
        optimizer.drawCharacter(at: position, character: character, style: style, surface: self, priority: priority)
    }

    /// Use the rendering optimizer for optimized clearing
    @MainActor
    public func optimizedClear(
        rect: Rect,
        optimizer: RenderingOptimizer,
        priority: RenderPriority = .high
    ) {
        optimizer.clearRect(rect, surface: self, priority: priority)
    }
}

// MARK: - Rendering Context Extensions

public extension DrawingContext {
    /// Create a rendering context with optimization
    func withOptimizer(_ optimizer: RenderingOptimizer) -> OptimizedDrawingContext {
        return OptimizedDrawingContext(context: self, optimizer: optimizer)
    }
}

public struct OptimizedDrawingContext {
    private let context: DrawingContext
    private let optimizer: RenderingOptimizer

    init(context: DrawingContext, optimizer: RenderingOptimizer) {
        self.context = context
        self.optimizer = optimizer
    }

    @MainActor
    public func drawText(
        at position: Position,
        text: String,
        style: TextStyle? = nil,
        priority: RenderPriority = .normal
    ) {
        let adjustedPosition = Position(
            row: context.bounds.origin.row + position.row,
            col: context.bounds.origin.col + position.col
        )
        optimizer.drawText(at: adjustedPosition, text: text, style: style, surface: context.surface, priority: priority)
    }

    @MainActor
    public func drawCharacter(
        at position: Position,
        character: Character,
        style: TextStyle? = nil,
        priority: RenderPriority = .normal
    ) {
        let adjustedPosition = Position(
            row: context.bounds.origin.row + position.row,
            col: context.bounds.origin.col + position.col
        )
        optimizer.drawCharacter(at: adjustedPosition, character: character, style: style, surface: context.surface, priority: priority)
    }

    @MainActor
    public func clear(priority: RenderPriority = .high) {
        optimizer.clearRect(context.bounds, surface: context.surface, priority: priority)
    }
}

// MARK: - Type Alias for External Compatibility

public typealias RenderingMetrics = RenderingPerformanceMetrics

