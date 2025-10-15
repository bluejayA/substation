import Foundation

/// Static helper utilities for Swift object storage operations
enum SwiftStorageHelpers {

    // MARK: - File Size Formatting

    /// Format bytes into human-readable file size string
    /// - Parameters:
    ///   - bytes: Number of bytes
    ///   - precision: Number of decimal places (default: 2)
    /// - Returns: Formatted string (e.g., "1.5 MB", "500 KB")
    static func formatFileSize(_ bytes: Int64, precision: Int = 2) -> String {
        let kb: Double = 1024
        let mb: Double = kb * 1024
        let gb: Double = mb * 1024
        let tb: Double = gb * 1024

        let bytesDouble = Double(bytes)

        if bytesDouble >= tb {
            return String(format: "%.\(precision)f TB", bytesDouble / tb)
        } else if bytesDouble >= gb {
            return String(format: "%.\(precision)f GB", bytesDouble / gb)
        } else if bytesDouble >= mb {
            return String(format: "%.\(precision)f MB", bytesDouble / mb)
        } else if bytesDouble >= kb {
            return String(format: "%.\(precision)f KB", bytesDouble / kb)
        } else {
            return "\(bytes) bytes"
        }
    }

    /// Format transfer rate into human-readable string
    /// - Parameters:
    ///   - bytesPerSecond: Transfer rate in bytes per second
    ///   - precision: Number of decimal places (default: 2)
    /// - Returns: Formatted string (e.g., "1.5 MB/s", "500 KB/s")
    static func formatTransferRate(_ bytesPerSecond: Double, precision: Int = 2) -> String {
        let kb: Double = 1024
        let mb: Double = kb * 1024
        let gb: Double = mb * 1024

        if bytesPerSecond >= gb {
            return String(format: "%.\(precision)f GB/s", bytesPerSecond / gb)
        } else if bytesPerSecond >= mb {
            return String(format: "%.\(precision)f MB/s", bytesPerSecond / mb)
        } else if bytesPerSecond >= kb {
            return String(format: "%.\(precision)f KB/s", bytesPerSecond / kb)
        } else {
            return String(format: "%.\(precision)f B/s", bytesPerSecond)
        }
    }

    // MARK: - Content Type Detection

    /// Detect content type from file URL extension
    /// - Parameter url: File URL
    /// - Returns: MIME type string, defaults to "application/octet-stream"
    static func detectContentType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        // Text formats
        case "txt": return "text/plain"
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "md": return "text/markdown"
        case "yaml", "yml": return "application/x-yaml"
        case "toml": return "application/toml"

        // Programming languages
        case "swift": return "text/x-swift"
        case "rs": return "text/x-rust"
        case "go": return "text/x-go"
        case "py": return "text/x-python"
        case "rb": return "text/x-ruby"
        case "java": return "text/x-java"
        case "c": return "text/x-c"
        case "cpp", "cc", "cxx": return "text/x-c++"
        case "h", "hpp": return "text/x-c-header"

        // Images
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "heif": return "image/heif"
        case "bmp": return "image/bmp"
        case "ico": return "image/x-icon"

        // Video formats
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"
        case "mkv": return "video/x-matroska"
        case "webm": return "video/webm"
        case "flv": return "video/x-flv"
        case "wmv": return "video/x-ms-wmv"

        // Audio formats
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "flac": return "audio/flac"
        case "aac": return "audio/aac"
        case "ogg": return "audio/ogg"
        case "m4a": return "audio/mp4"
        case "wma": return "audio/x-ms-wma"

        // Archives
        case "zip": return "application/zip"
        case "tar": return "application/x-tar"
        case "gz": return "application/gzip"
        case "bz2": return "application/x-bzip2"
        case "7z": return "application/x-7z-compressed"
        case "rar": return "application/vnd.rar"

        // Documents
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"

        default: return "application/octet-stream"
        }
    }

    /// Validate content type string format
    /// - Parameter contentType: MIME type string to validate
    /// - Returns: True if content type is well-formed
    static func validateContentType(_ contentType: String) -> Bool {
        // Content type should be in format: type/subtype
        let parts = contentType.split(separator: "/")

        guard parts.count == 2 else {
            return false
        }

        let type = String(parts[0]).lowercased()
        let subtype = String(parts[1]).lowercased()

        // Validate type part
        let validTypes = ["text", "image", "audio", "video", "application", "multipart", "message"]
        guard validTypes.contains(type) || type.hasPrefix("x-") else {
            return false
        }

        // Validate subtype is not empty
        guard !subtype.isEmpty else {
            return false
        }

        // Check for valid characters (alphanumeric, dash, dot, plus)
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-.+"))
        guard subtype.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            return false
        }

        return true
    }

    // MARK: - Object Name Encoding/Decoding

    /// Encode object name for safe storage/transmission
    /// Preserves forward slashes for path structure but encodes special characters
    /// - Parameter name: Object name to encode
    /// - Returns: Encoded object name
    static func encodeObjectName(_ name: String) -> String {
        // Characters that should be percent-encoded in object names
        var allowedCharacters = CharacterSet.urlPathAllowed
        // Remove characters that could cause issues
        allowedCharacters.remove(charactersIn: "#?&=")

        // Split by forward slash, encode each component, then rejoin
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        let encodedComponents = components.map { component -> String in
            String(component).addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? String(component)
        }

        return encodedComponents.joined(separator: "/")
    }

    /// Decode object name from storage
    /// Handles percent-encoded characters
    /// - Parameter name: Encoded object name
    /// - Returns: Decoded object name
    static func decodeObjectName(_ name: String) -> String {
        return name.removingPercentEncoding ?? name
    }

    /// Validate object name for safety and correctness
    /// - Parameter name: Object name to validate
    /// - Returns: Tuple with validity status and optional reason
    static func validateObjectName(_ name: String) -> (valid: Bool, reason: String?) {
        // Check for empty name
        if name.isEmpty {
            return (false, "Object name cannot be empty")
        }

        // Check for path traversal attempts
        if name.contains("../") || name.contains("..\\") {
            return (false, "Object name contains path traversal sequence (../)")
        }

        // Check if name starts with path separator
        if name.hasPrefix("/") {
            return (false, "Object name cannot start with /")
        }

        // Check for null bytes
        if name.contains("\0") {
            return (false, "Object name contains null byte")
        }

        // Check for control characters
        let controlCharacterRange: ClosedRange<UnicodeScalar> = "\u{0000}"..."\u{001F}"
        if name.unicodeScalars.contains(where: { controlCharacterRange.contains($0) }) {
            return (false, "Object name contains control characters")
        }

        // Check for excessively long names (Swift has 1024 byte limit)
        if name.utf8.count > 1024 {
            return (false, "Object name exceeds 1024 bytes")
        }

        return (true, nil)
    }

    // MARK: - Path Utilities

    /// Extract filename from object name (handles paths with separators)
    /// - Parameter objectName: Full object name/path
    /// - Returns: Just the filename portion
    static func extractFileName(from objectName: String) -> String {
        return (objectName as NSString).lastPathComponent
    }

    /// Build destination path preserving or flattening directory structure
    /// - Parameters:
    ///   - objectName: Full object name/path
    ///   - destinationBase: Base destination path
    ///   - preserveStructure: Whether to preserve directory structure
    /// - Returns: Full destination file path
    static func buildDestinationPath(
        objectName: String,
        destinationBase: String,
        preserveStructure: Bool
    ) -> String {
        if preserveStructure && objectName.contains("/") {
            // Preserve directory structure
            return (destinationBase as NSString).appendingPathComponent(objectName)
        } else {
            // Flatten structure - use only filename
            let fileName = extractFileName(from: objectName)
            return (destinationBase as NSString).appendingPathComponent(fileName)
        }
    }
}
