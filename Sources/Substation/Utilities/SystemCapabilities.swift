import Foundation

/// System capabilities detection and resource management
enum SystemCapabilities {

    /// Get the optimal number of concurrent tasks based on available CPU cores
    /// - Returns: min(availableCores / 2, 5) with minimum of 1 to balance performance with resource usage
    static func optimalConcurrentTaskLimit() -> Int {
        let processorCount = ProcessInfo.processInfo.activeProcessorCount

        // Use half the available cores to prevent overwhelming the system
        // Cap at 5 concurrent tasks maximum, ensure at least 1
        let halfCores = max(processorCount / 2, 1)
        let limit = min(halfCores, 5)

        return limit
    }

    /// Get the optimal number of concurrent batch operations
    /// - Returns: min(availableCores, 5) for I/O-bound operations with minimum of 1
    static func optimalBatchOperationLimit() -> Int {
        let processorCount = ProcessInfo.processInfo.activeProcessorCount

        // Batch operations are I/O-bound, use full core count
        // but cap at 5 to prevent resource exhaustion, ensure at least 1
        let limit = min(processorCount, 5)

        return max(limit, 1)
    }

    /// Get optimal base refresh interval based on system resources
    /// - Returns: Refresh interval in seconds (longer on low-resource systems)
    static func optimalRefreshInterval() -> TimeInterval {
        let processorCount = ProcessInfo.processInfo.activeProcessorCount

        // On systems with 2 or fewer cores, use longer intervals to reduce CPU load
        if processorCount <= 2 {
            return 30.0  // 30 seconds on low-end systems
        } else if processorCount <= 4 {
            return 20.0  // 20 seconds on mid-range systems
        } else {
            return 10.0  // 10 seconds on high-end systems
        }
    }

    /// Get optimal delay between launching concurrent network tasks
    /// - Returns: Delay in nanoseconds
    static func optimalTaskDelay() -> UInt64 {
        let processorCount = ProcessInfo.processInfo.activeProcessorCount

        // Longer delays on low-resource systems to reduce URLSession contention
        if processorCount <= 2 {
            return 100_000_000  // 100ms on 2-core systems
        } else if processorCount <= 4 {
            return 75_000_000   // 75ms on 4-core systems
        } else {
            return 50_000_000   // 50ms on high-end systems
        }
    }

    /// Get system info for logging and diagnostics
    static func getSystemInfo() -> [String: String] {
        return [
            "processorCount": "\(ProcessInfo.processInfo.activeProcessorCount)",
            "physicalMemoryGB": String(format: "%.2f", Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824),
            "optimalConcurrentTaskLimit": "\(optimalConcurrentTaskLimit())",
            "optimalBatchOperationLimit": "\(optimalBatchOperationLimit())",
            "optimalRefreshInterval": "\(optimalRefreshInterval())s",
            "optimalTaskDelay": "\(optimalTaskDelay() / 1_000_000)ms",
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString
        ]
    }
}
