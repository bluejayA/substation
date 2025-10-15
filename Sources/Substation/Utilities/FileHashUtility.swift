import Foundation
import Crypto

/// Actor-based utility for computing MD5 hashes of files for ETAG comparison
/// Uses streaming computation to avoid loading entire files into memory
actor FileHashUtility {

    /// Compute MD5 hash of a file using streaming reads
    /// - Parameter fileURL: URL of the file to hash
    /// - Returns: MD5 hash as lowercase hex string
    /// - Throws: File I/O errors
    static func computeMD5(fileURL: URL) async throws -> String {
        let chunkSize = 1024 * 1024 // 1MB chunks for memory efficiency

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FileHashError.fileNotFound(path: fileURL.path)
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw FileHashError.cannotOpenFile(path: fileURL.path)
        }

        defer {
            try? fileHandle.close()
        }

        var hasher = Insecure.MD5()

        // Read file in chunks for memory efficiency
        while true {
            // Check for cancellation
            if Task.isCancelled {
                throw CancellationError()
            }

            guard let chunk = try? fileHandle.read(upToCount: chunkSize) else {
                break
            }

            if chunk.isEmpty {
                break
            }

            hasher.update(data: chunk)
        }

        let digest = hasher.finalize()

        // Convert to lowercase hex string (matching Swift ETAG format)
        let hashString = digest.map { String(format: "%02x", $0) }.joined()

        return hashString
    }

    /// Check if local file matches remote object by comparing MD5 hashes
    /// - Parameters:
    ///   - localFileURL: URL of the local file
    ///   - remoteEtag: ETAG from Swift API (may include quotes)
    /// - Returns: true if MD5 hashes match (file is identical)
    /// - Throws: File I/O errors
    static func localFileMatchesRemote(localFileURL: URL, remoteEtag: String) async throws -> Bool {
        // Compute local file MD5
        let localMD5 = try await computeMD5(fileURL: localFileURL)

        // Normalize remote ETAG (strip quotes, lowercase)
        let normalizedRemoteEtag = normalizeEtag(remoteEtag)

        // Compare case-insensitively
        return localMD5.lowercased() == normalizedRemoteEtag.lowercased()
    }

    /// Normalize ETAG string by removing quotes and whitespace
    /// - Parameter etag: Raw ETAG string from API
    /// - Returns: Normalized ETAG string
    static func normalizeEtag(_ etag: String) -> String {
        // Remove surrounding quotes and whitespace
        return etag.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    }
}

/// Errors that can occur during file hashing operations
enum FileHashError: Error, LocalizedError {
    case fileNotFound(path: String)
    case cannotOpenFile(path: String)
    case readError(path: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .cannotOpenFile(let path):
            return "Cannot open file for reading: \(path)"
        case .readError(let path):
            return "Error reading file: \(path)"
        }
    }
}
