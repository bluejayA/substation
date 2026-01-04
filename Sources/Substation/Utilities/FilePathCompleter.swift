import Foundation

/// Utility for file path completion and validation
///
/// Provides tab-completion functionality for file path text fields in forms.
/// Supports tilde expansion, directory listing, and common path filtering.
struct FilePathCompleter {

    // MARK: - Path Expansion

    /// Expands a path by replacing ~ with the user's home directory
    ///
    /// - Parameter path: The path to expand
    /// - Returns: The expanded path
    static func expandPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return trimmed.replacingOccurrences(of: "~", with: home, options: .anchored)
        }
        return trimmed
    }

    // MARK: - File Existence

    /// Checks if a file exists at the given path
    ///
    /// - Parameter path: The path to check (supports ~ expansion)
    /// - Returns: true if the file exists, false otherwise
    static func fileExists(at path: String) -> Bool {
        let expanded = expandPath(path)
        return FileManager.default.fileExists(atPath: expanded)
    }

    /// Checks if a path points to a directory
    ///
    /// - Parameter path: The path to check (supports ~ expansion)
    /// - Returns: true if the path is a directory, false otherwise
    static func isDirectory(at path: String) -> Bool {
        let expanded = expandPath(path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) {
            return isDir.boolValue
        }
        return false
    }

    // MARK: - Tab Completion

    /// Gets completions for a given partial path
    ///
    /// - Parameter partialPath: The partial path to complete
    /// - Returns: Array of possible completions (full paths)
    static func getCompletions(for partialPath: String) -> [String] {
        let trimmed = partialPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Default to home directory contents
            return listDirectory("~")
        }

        let expanded = expandPath(trimmed)

        // If path ends with /, list directory contents
        if trimmed.hasSuffix("/") {
            return listDirectory(trimmed)
        }

        // Otherwise, find matching entries in the parent directory
        let url = URL(fileURLWithPath: expanded)
        let parentDir = url.deletingLastPathComponent().path
        let prefix = url.lastPathComponent

        guard FileManager.default.fileExists(atPath: parentDir) else {
            return []
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: parentDir)
            let matches = contents.filter { $0.hasPrefix(prefix) }
            return matches.map { item in
                let fullPath = (parentDir as NSString).appendingPathComponent(item)
                // Replace home directory back to ~ for display
                return collapseHomePath(fullPath)
            }.sorted()
        } catch {
            return []
        }
    }

    /// Performs tab completion on a path, returning the completed path
    ///
    /// - Parameter partialPath: The partial path to complete
    /// - Returns: A tuple containing (completedPath, hasMultipleMatches)
    static func tabComplete(_ partialPath: String) -> (path: String, hasMultiple: Bool) {
        let completions = getCompletions(for: partialPath)

        if completions.isEmpty {
            return (partialPath, false)
        }

        if completions.count == 1 {
            var completed = completions[0]
            // Add trailing slash if it's a directory
            let expanded = expandPath(completed)
            if isDirectory(at: expanded) && !completed.hasSuffix("/") {
                completed += "/"
            }
            return (completed, false)
        }

        // Multiple matches - find common prefix
        let commonPrefix = findCommonPrefix(completions)
        if commonPrefix.count > partialPath.count {
            return (commonPrefix, true)
        }

        return (partialPath, true)
    }

    // MARK: - Private Helpers

    /// Lists contents of a directory
    private static func listDirectory(_ path: String) -> [String] {
        let expanded = expandPath(path)

        guard FileManager.default.fileExists(atPath: expanded) else {
            return []
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: expanded)
            // Filter out hidden files (starting with .)
            let visible = contents.filter { !$0.hasPrefix(".") }
            return visible.map { item in
                let fullPath = (expanded as NSString).appendingPathComponent(item)
                return collapseHomePath(fullPath)
            }.sorted()
        } catch {
            return []
        }
    }

    /// Replaces home directory path with ~ for display
    private static func collapseHomePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "~", options: .anchored)
        }
        return path
    }

    /// Finds the longest common prefix among strings
    private static func findCommonPrefix(_ strings: [String]) -> String {
        guard let first = strings.first else { return "" }
        guard strings.count > 1 else { return first }

        var prefix = first
        for string in strings.dropFirst() {
            while !string.hasPrefix(prefix) && !prefix.isEmpty {
                prefix = String(prefix.dropLast())
            }
        }
        return prefix
    }

    // MARK: - Validation Helpers

    /// Validates a public key file path
    ///
    /// - Parameter path: The path to validate
    /// - Returns: An error message if invalid, nil if valid
    static func validatePublicKeyPath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "File path is required"
        }

        let expanded = expandPath(trimmed)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: expanded) else {
            return "File not found: \(trimmed)"
        }

        // Check if it's a file (not a directory)
        if isDirectory(at: expanded) {
            return "Path is a directory, not a file"
        }

        // Check if readable
        guard FileManager.default.isReadableFile(atPath: expanded) else {
            return "File is not readable"
        }

        return nil
    }
}
