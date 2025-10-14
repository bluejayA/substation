import Foundation

/// Utility for formatting byte values into human-readable strings
public struct ByteFormatter: Sendable {
    /// Format bytes into human-readable string (B, KB, MB, GB, TB)
    /// - Parameter bytes: Number of bytes to format
    /// - Returns: Formatted string like "1.5 GB"
    public static func format(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0

        while size >= 1024.0 && unitIndex < units.count - 1 {
            size /= 1024.0
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(size)) \(units[unitIndex])"
        } else {
            return String(format: "%.2f %@", size, units[unitIndex])
        }
    }

    /// Format bytes into human-readable string with custom precision
    /// - Parameters:
    ///   - bytes: Number of bytes to format
    ///   - precision: Number of decimal places
    /// - Returns: Formatted string
    public static func format(_ bytes: Int, precision: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0

        while size >= 1024.0 && unitIndex < units.count - 1 {
            size /= 1024.0
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(size)) \(units[unitIndex])"
        } else {
            let formatString = "%.\(precision)f %@"
            return String(format: formatString, size, units[unitIndex])
        }
    }
}
