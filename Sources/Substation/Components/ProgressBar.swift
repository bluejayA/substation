import Foundation
import SwiftTUI

// MARK: - ProgressBar Component

/// A reusable progress bar component for displaying upload/download progress
@MainActor
struct ProgressBar {
    private let progress: Double
    private let label: String?
    private let width: Int
    private let showPercentage: Bool

    /// Initialize a progress bar
    /// - Parameters:
    ///   - progress: Progress value from 0.0 to 1.0
    ///   - label: Optional label to display (e.g., "Uploading: 45%")
    ///   - width: Width of the progress bar in characters (default: 50)
    ///   - showPercentage: Whether to show percentage on the right (default: true)
    init(
        progress: Double,
        label: String? = nil,
        width: Int = 50,
        showPercentage: Bool = true
    ) {
        self.progress = max(0.0, min(1.0, progress))
        self.label = label
        self.width = max(10, width)
        self.showPercentage = showPercentage
    }

    /// Build the progress bar component
    func build() -> any Component {
        var components: [any Component] = []

        // Add label if provided
        if let label = label {
            components.append(Text(label).info()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        }

        // Build the visual progress bar
        let barComponent = buildBar()
        components.append(barComponent)

        return VStack(spacing: 0, children: components)
    }

    /// Build the visual bar component
    private func buildBar() -> any Component {
        let filledWidth = Int(Double(width) * progress)
        let emptyWidth = width - filledWidth

        // Build bar string: [########    ]
        var barString = "["
        barString += String(repeating: "#", count: filledWidth)
        barString += String(repeating: " ", count: emptyWidth)
        barString += "]"

        // Add percentage if requested
        if showPercentage {
            let percentage = Int(progress * 100)
            barString += " \(percentage)%"
        }

        return Text(barString).accent()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}

// MARK: - IndeterminateProgressBar Component

/// An indeterminate progress indicator for operations without progress tracking
@MainActor
struct IndeterminateProgressBar {
    private let label: String?
    private let frame: Int
    private let width: Int

    /// Initialize an indeterminate progress bar
    /// - Parameters:
    ///   - label: Optional label to display
    ///   - frame: Animation frame (0-19 for smooth animation)
    ///   - width: Width of the progress bar in characters (default: 50)
    init(
        label: String? = nil,
        frame: Int = 0,
        width: Int = 50
    ) {
        self.label = label
        self.frame = frame % 20
        self.width = max(10, width)
    }

    /// Build the indeterminate progress bar component
    func build() -> any Component {
        var components: [any Component] = []

        // Add label if provided
        if let label = label {
            components.append(Text(label).info()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        }

        // Build the animated indicator
        let barComponent = buildAnimatedBar()
        components.append(barComponent)

        return VStack(spacing: 0, children: components)
    }

    /// Build the animated bar component
    private func buildAnimatedBar() -> any Component {
        // Create a moving dot pattern
        let dotWidth = 5
        let position = (frame * width) / 20

        var barString = "["

        for i in 0..<width {
            if i >= position && i < position + dotWidth {
                barString += "="
            } else {
                barString += " "
            }
        }

        barString += "]"

        return Text(barString).accent()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}

// MARK: - FileProgressInfo

/// Information about file upload/download progress
struct FileProgressInfo: Sendable {
    let currentFile: Int
    let totalFiles: Int
    let currentFileName: String
    let currentFileBytes: Int64
    let totalBytes: Int64

    var overallProgress: Double {
        guard totalFiles > 0 else { return 0.0 }
        return Double(currentFile - 1) / Double(totalFiles)
    }

    var progressText: String {
        let mbCurrent = Double(currentFileBytes) / (1024 * 1024)
        let mbTotal = Double(totalBytes) / (1024 * 1024)
        return String(format: "File %d/%d: %@ (%.2f MB / %.2f MB)",
                     currentFile, totalFiles, currentFileName, mbCurrent, mbTotal)
    }
}

// MARK: - MultiFileProgressBar Component

/// A progress bar specifically designed for multi-file operations
@MainActor
struct MultiFileProgressBar {
    private let fileInfo: FileProgressInfo
    private let width: Int

    /// Initialize a multi-file progress bar
    /// - Parameters:
    ///   - fileInfo: Information about the current file progress
    ///   - width: Width of the progress bar in characters (default: 50)
    init(
        fileInfo: FileProgressInfo,
        width: Int = 50
    ) {
        self.fileInfo = fileInfo
        self.width = max(10, width)
    }

    /// Build the multi-file progress bar component
    func build() -> any Component {
        var components: [any Component] = []

        // Overall progress label
        let overallLabel = "Overall Progress: File \(fileInfo.currentFile) of \(fileInfo.totalFiles)"
        components.append(Text(overallLabel).info()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))

        // Overall progress bar
        let overallBar = ProgressBar(
            progress: fileInfo.overallProgress,
            label: nil,
            width: width,
            showPercentage: true
        )
        components.append(overallBar.build())

        // Current file info
        components.append(Text(fileInfo.progressText).muted()
            .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        return VStack(spacing: 0, children: components)
    }
}
