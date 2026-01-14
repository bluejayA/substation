import Foundation
#if canImport(Compression)
import Compression
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Advanced multi-level cache manager providing L1 (memory), L2 (compressed memory), and L3 (disk) caching
/// Generic implementation for MemoryKit - works with any cache key/value types
public actor MultiLevelCacheManager<Key: Hashable & Sendable, Value: Codable & Sendable> {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let l1MaxSize: Int
        public let l1MaxMemory: Int
        public let l2MaxSize: Int
        public let l2MaxMemory: Int
        public let l3MaxSize: Int
        public let l3CacheDirectory: URL?
        public let defaultTTL: TimeInterval
        public let enableCompression: Bool
        public let enableMetrics: Bool
        /// Optional identifier used for generating consistent cache filenames (e.g., cloud name).
        /// When set, cache files use a hash of this identifier instead of timestamps,
        /// enabling cache reuse across application restarts.
        public let cacheIdentifier: String?

        public init(
            l1MaxSize: Int = 1000,
            l1MaxMemory: Int = 20 * 1024 * 1024,  // 20 MB for L1
            l2MaxSize: Int = 5000,
            l2MaxMemory: Int = 50 * 1024 * 1024,  // 50 MB for L2 (compressed)
            l3MaxSize: Int = 50000,               // 50k entries on disk
            l3CacheDirectory: URL? = nil,
            defaultTTL: TimeInterval = 300.0,     // 5 minutes
            enableCompression: Bool = true,
            enableMetrics: Bool = true,
            cacheIdentifier: String? = nil
        ) {
            self.l1MaxSize = l1MaxSize
            self.l1MaxMemory = l1MaxMemory
            self.l2MaxSize = l2MaxSize
            self.l2MaxMemory = l2MaxMemory
            self.l3MaxSize = l3MaxSize
            self.l3CacheDirectory = l3CacheDirectory
            self.defaultTTL = defaultTTL
            self.enableCompression = enableCompression
            self.enableMetrics = enableMetrics
            self.cacheIdentifier = cacheIdentifier
        }
    }

    // MARK: - Cache Priority

    public enum CachePriority: Int, CaseIterable, Sendable {
        case critical = 4    // Auth tokens, service endpoints
        case high = 3        // Active servers, current projects
        case normal = 2      // General resources
        case low = 1         // Historical data, rarely accessed

        public var weight: Double {
            switch self {
            case .critical: return 4.0
            case .high: return 2.0
            case .normal: return 1.0
            case .low: return 0.5
            }
        }

        public var ttlMultiplier: Double {
            switch self {
            case .critical: return 2.0  // Double TTL for critical items
            case .high: return 1.5
            case .normal: return 1.0
            case .low: return 0.5       // Half TTL for low priority
            }
        }
    }

    // MARK: - Cache Entries

    private struct L1CacheEntry {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
        let accessCount: Int
        let lastAccessed: Date
        let priority: CachePriority

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        var score: Double {
            let age = Date().timeIntervalSince(lastAccessed)
            let accessRate = Double(accessCount) / max(1.0, Date().timeIntervalSince(timestamp) / 60.0)
            let priorityWeight = priority.weight

            return (accessRate * priorityWeight) / (1.0 + age / 60.0)
        }

        func accessed() -> L1CacheEntry {
            L1CacheEntry(
                data: data,
                timestamp: timestamp,
                ttl: ttl,
                accessCount: accessCount + 1,
                lastAccessed: Date(),
                priority: priority
            )
        }
    }

    private struct L2CacheEntry {
        let compressedData: Data
        let originalSize: Int
        let compressionRatio: Double
        let timestamp: Date
        let ttl: TimeInterval
        let accessCount: Int
        let lastAccessed: Date
        let priority: CachePriority

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        var score: Double {
            let age = Date().timeIntervalSince(lastAccessed)
            let accessRate = Double(accessCount) / max(1.0, Date().timeIntervalSince(timestamp) / 60.0)
            let priorityWeight = priority.weight
            let compressionBonus = min(compressionRatio / 10.0, 0.5) // Up to 50% bonus for good compression

            return (accessRate * priorityWeight + compressionBonus) / (1.0 + age / 60.0)
        }

        func accessed() -> L2CacheEntry {
            L2CacheEntry(
                compressedData: compressedData,
                originalSize: originalSize,
                compressionRatio: compressionRatio,
                timestamp: timestamp,
                ttl: ttl,
                accessCount: accessCount + 1,
                lastAccessed: Date(),
                priority: priority
            )
        }
    }

    private struct L3CacheMetadata {
        let filename: String
        let size: Int
        let timestamp: Date
        let ttl: TimeInterval
        let accessCount: Int
        let lastAccessed: Date
        let priority: CachePriority
        let isCompressed: Bool

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        func accessed() -> L3CacheMetadata {
            L3CacheMetadata(
                filename: filename,
                size: size,
                timestamp: timestamp,
                ttl: ttl,
                accessCount: accessCount + 1,
                lastAccessed: Date(),
                priority: priority,
                isCompressed: isCompressed
            )
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let logger: (any MemoryKitLogger)?

    /// L1 Cache: Fast in-memory cache for frequently accessed items
    private var l1Cache: [String: L1CacheEntry] = [:]

    /// L2 Cache: Compressed memory cache for medium-priority items
    private var l2Cache: [String: L2CacheEntry] = [:]

    /// L3 Cache: Disk-based cache for long-term storage
    private let l3CacheDirectory: URL
    private var l3Index: [String: L3CacheMetadata] = [:]

    // Performance Tracking
    private var l1Hits: Int = 0
    private var l2Hits: Int = 0
    private var l3Hits: Int = 0
    private var totalMisses: Int = 0
    private var compressionStats: CompressionStats = CompressionStats()

    // Reusable JSON encoders/decoders for performance (PERF-004)
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // Sampled logging for performance (PERF-001)
    private var operationCount: Int = 0
    private let logSampleRate: Int = 1000

    // Maintenance
    private var maintenanceTask: Task<Void, Never>?

    /// Determines if current operation should be logged (sampling).
    ///
    /// Only logs 1 in every `logSampleRate` operations to reduce overhead.
    private func shouldLog() -> Bool {
        operationCount += 1
        return operationCount % logSampleRate == 0
    }

    // MARK: - Initialization

    /// Creates a new multi-level cache manager.
    ///
    /// - Parameters:
    ///   - configuration: Cache configuration options
    ///   - logger: Optional logger for cache operations
    public init(
        configuration: Configuration = Configuration(),
        logger: (any MemoryKitLogger)? = nil
    ) {
        self.configuration = configuration
        self.logger = logger

        // Setup L3 cache directory with cloud-specific subdirectory
        let baseDirectory: URL
        if let cacheDir = configuration.l3CacheDirectory {
            baseDirectory = cacheDir
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            baseDirectory = homeDir.appendingPathComponent(".config/substation/multi-level-cache")
        }

        // Append cloud name as subdirectory if provided for cloud-specific caching
        if let cloudName = configuration.cacheIdentifier {
            // Use secure sanitization to prevent path traversal attacks
            let sanitizedCloudName = Self.sanitizeCloudName(cloudName)
            self.l3CacheDirectory = baseDirectory.appendingPathComponent(sanitizedCloudName)
        } else {
            self.l3CacheDirectory = baseDirectory
        }

        // Create cache directory with secure permissions (owner only)
        do {
            try Self.createSecureDirectory(at: l3CacheDirectory)
        } catch {
            logger?.logWarning("Failed to create cache directory with secure permissions", context: [
                "directory": l3CacheDirectory.path,
                "error": error.localizedDescription
            ])
            // Fall back to standard creation
            try? FileManager.default.createDirectory(at: l3CacheDirectory, withIntermediateDirectories: true)
        }

        logger?.logInfo("Multi-level cache manager initialized", context: [
            "l1MaxSize": configuration.l1MaxSize,
            "l1MaxMemory": configuration.l1MaxMemory,
            "l2MaxSize": configuration.l2MaxSize,
            "l2MaxMemory": configuration.l2MaxMemory,
            "l3MaxSize": configuration.l3MaxSize,
            "cacheDirectory": l3CacheDirectory.path
        ])
    }

    /// Start the cache manager (call after initialization)
    public func start() {
        startMaintenanceTasks()
    }

    // MARK: - Static Cache Cleanup

    /// Default base cache directory path used when no custom directory is specified
    private static var defaultCacheDirectory: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config/substation/multi-level-cache")
    }

    /// Sanitizes a cloud name for safe use as a directory name.
    ///
    /// Uses a whitelist approach to prevent path traversal attacks. Only allows
    /// alphanumeric characters, hyphens, and underscores. All other characters
    /// are removed. The result is also limited to 64 characters.
    ///
    /// - Parameter cloudName: The cloud name to sanitize
    /// - Returns: A sanitized string safe for use as a directory name
    private static func sanitizeCloudName(_ cloudName: String) -> String {
        // Whitelist approach: only allow safe characters
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))

        let sanitized = cloudName.unicodeScalars
            .filter { allowed.contains($0) }
            .map { Character($0) }
            .prefix(64)  // Limit length to prevent filesystem issues

        let result = String(sanitized)

        // Ensure result is not empty or a reserved name
        if result.isEmpty || result == "." || result == ".." {
            return "default_cache"
        }

        return result
    }

    /// Creates a directory with secure permissions (owner only).
    ///
    /// - Parameter url: The URL of the directory to create
    /// - Throws: Any error from FileManager
    private static func createSecureDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]  // rwx------ (owner only)
        )
    }

    /// Writes data to a file with secure permissions (owner read/write only).
    ///
    /// - Parameters:
    ///   - data: The data to write
    ///   - url: The URL to write to
    /// - Throws: Any error from writing or setting attributes
    private func writeSecureFile(_ data: Data, to url: URL) throws {
        // Check if target is a symlink (prevent symlink attacks)
        if let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
           resourceValues.isSymbolicLink == true {
            try FileManager.default.removeItem(at: url)
        }

        // Write atomically to prevent partial reads
        try data.write(to: url, options: [.atomic])

        // Set restrictive permissions (owner read/write only)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],  // rw------- (owner only)
            ofItemAtPath: url.path
        )
    }

    /// Cleans up stale cache files from the cache directory.
    ///
    /// This static method should be called at application startup to remove cache files
    /// that are older than the specified maximum age. This prevents operators from being
    /// presented with stale data when first loading the application.
    ///
    /// When a cloud name is provided, only the cloud-specific subdirectory is cleaned.
    /// Cache files are stored in `~/.config/substation/multi-level-cache/<cloudName>/`.
    ///
    /// - Parameters:
    ///   - maxAge: Maximum age of cache files to keep in seconds (default: 8 hours = 28800 seconds)
    ///   - cloudName: Optional cloud name for cloud-specific cache cleanup. When provided,
    ///     cleans the `<cloudName>/` subdirectory.
    ///   - cacheDirectory: Optional custom base cache directory. Uses default if not specified.
    /// - Returns: The number of stale cache files that were removed
    @discardableResult
    public static func cleanupStaleCacheFiles(
        maxAge: TimeInterval = 8 * 60 * 60, // 8 hours in seconds
        cloudName: String? = nil,
        cacheDirectory: URL? = nil
    ) -> Int {
        let baseDirectory = cacheDirectory ?? defaultCacheDirectory

        // Use cloud-specific subdirectory if cloud name is provided
        let directory: URL
        if let cloudName = cloudName {
            let sanitizedCloudName = sanitizeCloudName(cloudName)
            directory = baseDirectory.appendingPathComponent(sanitizedCloudName)
        } else {
            directory = baseDirectory
        }

        guard FileManager.default.fileExists(atPath: directory.path) else {
            return 0
        }

        var removedCount = 0
        let now = Date()

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
            )

            for fileURL in files {
                // Only process .dat cache files
                guard fileURL.pathExtension == "dat" else { continue }

                do {
                    let resourceValues = try fileURL.resourceValues(
                        forKeys: [.contentModificationDateKey, .isRegularFileKey]
                    )

                    // Skip if not a regular file
                    guard resourceValues.isRegularFile == true else { continue }

                    // Check file age
                    if let modificationDate = resourceValues.contentModificationDate {
                        let age = now.timeIntervalSince(modificationDate)
                        if age > maxAge {
                            try FileManager.default.removeItem(at: fileURL)
                            removedCount += 1
                        }
                    }
                } catch {
                    // Continue with other files if one fails
                    continue
                }
            }
        } catch {
            // Unable to read directory contents
            return 0
        }

        return removedCount
    }

    deinit {
        maintenanceTask?.cancel()
    }

    // MARK: - Public API

    /// Stores data with intelligent tier placement.
    ///
    /// Data is automatically placed in the appropriate cache tier based on
    /// priority and configuration settings.
    ///
    /// - Parameters:
    ///   - value: The value to cache
    ///   - key: The cache key
    ///   - priority: Priority level for the entry
    ///   - customTTL: Optional custom time-to-live
    public func store(
        _ value: Value,
        forKey key: Key,
        priority: CachePriority = .normal,
        customTTL: TimeInterval? = nil
    ) async {
        do {
            let keyString = String(describing: key)
            // Use reusable encoder for performance (PERF-004)
            let jsonData = try jsonEncoder.encode(value)
            let baseTTL = customTTL ?? configuration.defaultTTL
            let adjustedTTL = baseTTL * priority.ttlMultiplier

            await storeData(
                jsonData,
                forKey: keyString,
                priority: priority,
                ttl: adjustedTTL
            )

        } catch {
            logger?.logError("Failed to encode data for multi-level cache", context: [
                "key": String(describing: key),
                "error": error.localizedDescription
            ])
        }
    }

    /// Retrieve data with intelligent tier promotion
    public func retrieve(
        forKey key: Key,
        as type: Value.Type
    ) async -> Value? {
        let keyString = String(describing: key)
        let startTime = Date()
        let logThisOp = shouldLog()  // Sample logging for performance (PERF-001)

        // Try L1 cache first
        if let l1Entry = l1Cache[keyString], !l1Entry.isExpired {
            l1Cache[keyString] = l1Entry.accessed()
            l1Hits += 1

            do {
                // Use reusable decoder for performance (PERF-004)
                let value = try jsonDecoder.decode(type, from: l1Entry.data)
                if logThisOp {
                    logger?.logDebug("L1 cache hit (sampled)", context: [
                        "key": keyString,
                        "responseTime": Date().timeIntervalSince(startTime),
                        "totalL1Hits": l1Hits
                    ])
                }
                return value
            } catch {
                // Remove corrupted entry
                l1Cache.removeValue(forKey: keyString)
            }
        }

        // Try L2 cache
        if let l2Entry = l2Cache[keyString], !l2Entry.isExpired {
            do {
                let decompressedData = try await decompress(l2Entry.compressedData)
                // Use reusable decoder for performance (PERF-004)
                let decoded = try jsonDecoder.decode(type, from: decompressedData)

                l2Cache[keyString] = l2Entry.accessed()
                l2Hits += 1

                // Promote to L1 if frequently accessed
                if l2Entry.accessCount >= 3 {
                    await promoteToL1(key: keyString, data: decompressedData, from: l2Entry)
                }

                if logThisOp {
                    logger?.logDebug("L2 cache hit (sampled)", context: [
                        "key": keyString,
                        "responseTime": Date().timeIntervalSince(startTime),
                        "totalL2Hits": l2Hits
                    ])
                }
                return decoded

            } catch {
                // Remove corrupted entry
                l2Cache.removeValue(forKey: keyString)
            }
        }

        // Try L3 cache
        if let l3Meta = l3Index[keyString], !l3Meta.isExpired {
            do {
                let data = try await loadFromL3(key: keyString, metadata: l3Meta)
                // Use reusable decoder for performance (PERF-004)
                let decoded = try jsonDecoder.decode(type, from: data)

                l3Index[keyString] = l3Meta.accessed()
                l3Hits += 1

                // Promote to L2 if frequently accessed
                if l3Meta.accessCount >= 2 {
                    await promoteToL2(key: keyString, data: data, from: l3Meta)
                }

                if logThisOp {
                    logger?.logDebug("L3 cache hit (sampled)", context: [
                        "key": keyString,
                        "responseTime": Date().timeIntervalSince(startTime),
                        "totalL3Hits": l3Hits
                    ])
                }
                return decoded

            } catch {
                // Remove corrupted entry
                l3Index.removeValue(forKey: keyString)
                try? FileManager.default.removeItem(at: l3CacheDirectory.appendingPathComponent(l3Meta.filename))
            }
        }

        totalMisses += 1
        logger?.logDebug("Cache miss", context: [
            "key": keyString,
            "responseTime": Date().timeIntervalSince(startTime)
        ])
        return nil
    }

    /// Remove specific key from all cache levels
    public func remove(forKey key: Key) async {
        let keyString = String(describing: key)

        // Remove from L1
        l1Cache.removeValue(forKey: keyString)

        // Remove from L2
        l2Cache.removeValue(forKey: keyString)

        // Remove from L3
        if let l3Meta = l3Index.removeValue(forKey: keyString) {
            try? FileManager.default.removeItem(at: l3CacheDirectory.appendingPathComponent(l3Meta.filename))
        }
    }

    /// Clear all cache levels
    public func clearAll() async {
        l1Cache.removeAll()
        l2Cache.removeAll()

        // Clear L3 files
        for metadata in l3Index.values {
            try? FileManager.default.removeItem(at: l3CacheDirectory.appendingPathComponent(metadata.filename))
        }
        l3Index.removeAll()

        // Reset statistics
        l1Hits = 0
        l2Hits = 0
        l3Hits = 0
        totalMisses = 0
        compressionStats = CompressionStats()

        logger?.logInfo("All cache levels cleared", context: [:])
    }

    /// Get comprehensive cache statistics
    public func getStatistics() async -> MultiLevelCacheStatistics {
        let totalRequests = l1Hits + l2Hits + l3Hits + totalMisses
        let overallHitRate = totalRequests > 0 ? Double(l1Hits + l2Hits + l3Hits) / Double(totalRequests) : 0.0

        let l1MemoryUsage = l1Cache.values.reduce(0) { $0 + $1.data.count }
        let l2MemoryUsage = l2Cache.values.reduce(0) { $0 + $1.compressedData.count }
        let l3DiskUsage = l3Index.values.reduce(0) { $0 + $1.size }

        return MultiLevelCacheStatistics(
            l1Stats: CacheTierStatistics(
                entries: l1Cache.count,
                maxEntries: configuration.l1MaxSize,
                memoryUsage: l1MemoryUsage,
                maxMemory: configuration.l1MaxMemory,
                hitCount: l1Hits,
                hitRate: totalRequests > 0 ? Double(l1Hits) / Double(totalRequests) : 0.0
            ),
            l2Stats: CacheTierStatistics(
                entries: l2Cache.count,
                maxEntries: configuration.l2MaxSize,
                memoryUsage: l2MemoryUsage,
                maxMemory: configuration.l2MaxMemory,
                hitCount: l2Hits,
                hitRate: totalRequests > 0 ? Double(l2Hits) / Double(totalRequests) : 0.0
            ),
            l3Stats: CacheTierStatistics(
                entries: l3Index.count,
                maxEntries: configuration.l3MaxSize,
                memoryUsage: l3DiskUsage,
                maxMemory: Int.max,
                hitCount: l3Hits,
                hitRate: totalRequests > 0 ? Double(l3Hits) / Double(totalRequests) : 0.0
            ),
            overallHitRate: overallHitRate,
            totalMisses: totalMisses,
            compressionStats: compressionStats
        )
    }

    // MARK: - Private Implementation

    private func storeData(
        _ data: Data,
        forKey key: String,
        priority: CachePriority,
        ttl: TimeInterval
    ) async {
        let size = data.count

        // Determine initial placement based on size, priority, and current utilization
        if size < 50 * 1024 && priority.rawValue >= CachePriority.high.rawValue && l1Cache.count < configuration.l1MaxSize {
            // Store in L1 for small, high-priority items
            await storeInL1(key: key, data: data, priority: priority, ttl: ttl)
        } else if size < 500 * 1024 && l2Cache.count < configuration.l2MaxSize {
            // Store in L2 for medium-sized items
            await storeInL2(key: key, data: data, priority: priority, ttl: ttl)
        } else {
            // Store in L3 for large items or when other caches are full
            await storeInL3(key: key, data: data, priority: priority, ttl: ttl)
        }

        // Perform maintenance if needed
        await performMaintenanceIfNeeded()
    }

    private func storeInL1(
        key: String,
        data: Data,
        priority: CachePriority,
        ttl: TimeInterval
    ) async {
        let entry = L1CacheEntry(
            data: data,
            timestamp: Date(),
            ttl: ttl,
            accessCount: 0,
            lastAccessed: Date(),
            priority: priority
        )

        // Remove from other tiers if present
        l2Cache.removeValue(forKey: key)
        if let l3Meta = l3Index.removeValue(forKey: key) {
            try? FileManager.default.removeItem(at: l3CacheDirectory.appendingPathComponent(l3Meta.filename))
        }

        l1Cache[key] = entry
    }

    private func storeInL2(
        key: String,
        data: Data,
        priority: CachePriority,
        ttl: TimeInterval
    ) async {
        do {
            let compressedData = try await compress(data)
            let compressionRatio = Double(data.count) / Double(compressedData.count)

            let entry = L2CacheEntry(
                compressedData: compressedData,
                originalSize: data.count,
                compressionRatio: compressionRatio,
                timestamp: Date(),
                ttl: ttl,
                accessCount: 0,
                lastAccessed: Date(),
                priority: priority
            )

            // Remove from other tiers if present
            l1Cache.removeValue(forKey: key)
            if let l3Meta = l3Index.removeValue(forKey: key) {
                try? FileManager.default.removeItem(at: l3CacheDirectory.appendingPathComponent(l3Meta.filename))
            }

            l2Cache[key] = entry

        } catch {
            // Fall back to L3 if compression fails
            await storeInL3(key: key, data: data, priority: priority, ttl: ttl)
        }
    }

    /// Stores data in the L3 (disk) cache tier.
    ///
    /// - Parameters:
    ///   - key: Cache key
    ///   - data: Data to store
    ///   - priority: Cache priority level
    ///   - ttl: Time-to-live in seconds
    private func storeInL3(
        key: String,
        data: Data,
        priority: CachePriority,
        ttl: TimeInterval
    ) async {
        do {
            let filename = generateL3Filename(for: key)
            let fileURL = l3CacheDirectory.appendingPathComponent(filename)

            // Try compression for disk storage (only for files > 4KB to avoid overhead)
            var finalData = data
            var isCompressed = false

            if configuration.enableCompression && data.count > 4096 {
                if let compressed = try? await compress(data),
                   compressed.count < Int(Double(data.count) * 0.85) { // Only if 15%+ savings
                    finalData = compressed
                    isCompressed = true
                }
            }

            // Write with secure permissions (owner read/write only)
            try writeSecureFile(finalData, to: fileURL)

            let metadata = L3CacheMetadata(
                filename: filename,
                size: finalData.count,
                timestamp: Date(),
                ttl: ttl,
                accessCount: 0,
                lastAccessed: Date(),
                priority: priority,
                isCompressed: isCompressed
            )

            // Remove from other tiers if present
            l1Cache.removeValue(forKey: key)
            l2Cache.removeValue(forKey: key)

            l3Index[key] = metadata

        } catch {
            logger?.logError("Failed to store data in L3 cache", context: [
                "key": key,
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Compression Operations

    private func compress(_ data: Data) async throws -> Data {
        guard configuration.enableCompression else { return data }

        let startTime = Date()

        #if canImport(Compression)
        let compressedData = try data.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { buffer.deallocate() }

            let compressedSize = compression_encode_buffer(
                buffer, data.count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, COMPRESSION_LZFSE
            )

            guard compressedSize > 0 else {
                throw MultiLevelCacheError.compressionFailed
            }

            return Data(bytes: buffer, count: compressedSize)
        }
        #else
        // On Linux or when compression is not available, return original data
        let compressedData = data
        #endif

        let compressionTime = Date().timeIntervalSince(startTime)
        compressionStats.recordCompression(
            originalSize: data.count,
            compressedSize: compressedData.count,
            compressionTime: compressionTime
        )

        return compressedData
    }

    /// Decompresses LZFSE-compressed data with automatic buffer sizing.
    ///
    /// Uses a progressive buffer sizing strategy starting at 8x the compressed size
    /// and doubling up to 64x if needed. This handles highly compressible data
    /// (like JSON with repeated strings) that may have compression ratios > 10x.
    ///
    /// - Parameter compressedData: The compressed data to decompress
    /// - Returns: The decompressed data
    /// - Throws: MultiLevelCacheError.decompressionFailed if decompression fails
    private func decompress(_ compressedData: Data) async throws -> Data {
        guard configuration.enableCompression else { return compressedData }

        let startTime = Date()

        #if canImport(Compression)
        // Try progressively larger buffer sizes to handle highly compressible data
        var multiplier = 8
        let maxMultiplier = 64

        while multiplier <= maxMultiplier {
            let estimatedSize = compressedData.count * multiplier

            let result: Data? = compressedData.withUnsafeBytes { bytes -> Data? in
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: estimatedSize)
                defer { buffer.deallocate() }

                guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else {
                    return nil
                }

                let decompressedSize = compression_decode_buffer(
                    buffer, estimatedSize,
                    baseAddress, compressedData.count,
                    nil, COMPRESSION_LZFSE
                )

                guard decompressedSize > 0 else {
                    return nil  // Buffer may be too small, retry with larger
                }

                return Data(bytes: buffer, count: decompressedSize)
            }

            if let decompressedData = result {
                let decompressionTime = Date().timeIntervalSince(startTime)
                compressionStats.recordDecompression(decompressionTime: decompressionTime)
                return decompressedData
            }

            // Double buffer size and retry
            multiplier *= 2
        }

        // All attempts failed
        throw MultiLevelCacheError.decompressionFailed
        #else
        // On Linux or when compression is not available, return data as-is
        let decompressionTime = Date().timeIntervalSince(startTime)
        compressionStats.recordDecompression(decompressionTime: decompressionTime)
        return compressedData
        #endif
    }

    // MARK: - Tier Promotion

    private func promoteToL1(key: String, data: Data, from l2Entry: L2CacheEntry) async {
        guard l1Cache.count < configuration.l1MaxSize else { return }

        let l1Entry = L1CacheEntry(
            data: data,
            timestamp: l2Entry.timestamp,
            ttl: l2Entry.ttl,
            accessCount: l2Entry.accessCount,
            lastAccessed: l2Entry.lastAccessed,
            priority: l2Entry.priority
        )

        l1Cache[key] = l1Entry
        l2Cache.removeValue(forKey: key)

        logger?.logDebug("Promoted cache entry to L1", context: [
            "key": key,
            "accessCount": l2Entry.accessCount
        ])
    }

    private func promoteToL2(key: String, data: Data, from l3Meta: L3CacheMetadata) async {
        guard l2Cache.count < configuration.l2MaxSize else { return }

        do {
            let compressedData = try await compress(data)
            let compressionRatio = Double(data.count) / Double(compressedData.count)

            let l2Entry = L2CacheEntry(
                compressedData: compressedData,
                originalSize: data.count,
                compressionRatio: compressionRatio,
                timestamp: l3Meta.timestamp,
                ttl: l3Meta.ttl,
                accessCount: l3Meta.accessCount,
                lastAccessed: l3Meta.lastAccessed,
                priority: l3Meta.priority
            )

            l2Cache[key] = l2Entry
            l3Index.removeValue(forKey: key)
            try? FileManager.default.removeItem(at: l3CacheDirectory.appendingPathComponent(l3Meta.filename))

            logger?.logDebug("Promoted cache entry to L2", context: [
                "key": key,
                "accessCount": l3Meta.accessCount,
                "compressionRatio": compressionRatio
            ])

        } catch {
            logger?.logError("Failed to promote L3 entry to L2", context: [
                "key": key,
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - L3 Operations

    /// Loads data from L3 (disk) cache tier.
    ///
    /// Uses async file I/O to avoid blocking the actor during disk access (PERF-003).
    ///
    /// - Parameters:
    ///   - key: The cache key
    ///   - metadata: Metadata for the cached entry
    /// - Returns: The cached data (decompressed if necessary)
    /// - Throws: Any error from file I/O or decompression
    private func loadFromL3(key: String, metadata: L3CacheMetadata) async throws -> Data {
        let fileURL = l3CacheDirectory.appendingPathComponent(metadata.filename)

        // Perform file I/O outside actor isolation to avoid blocking (PERF-003)
        let fileData = try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: fileURL)
        }.value

        if metadata.isCompressed {
            return try await decompress(fileData)
        } else {
            return fileData
        }
    }

    /// Generates a consistent filename for L3 cache storage using a hash-based approach.
    ///
    /// Filenames are always generated using a deterministic hash of the cache key,
    /// ensuring cache reuse across application restarts. Cloud isolation is handled
    /// by the directory structure (`~/.config/substation/multi-level-cache/<cloudName>/`),
    /// so the hash is based solely on the key for consistency within each cloud's cache.
    ///
    /// - Parameter key: The cache key to generate a filename for
    /// - Returns: A deterministic filename for the cache entry
    private func generateL3Filename(for key: String) -> String {
        // Generate consistent hash based on the cache key
        let hash = Self.simpleHash(key)
        return "cache_\(hash).dat"
    }

    /// Secure hash function for generating consistent cache filenames.
    ///
    /// Uses SHA256 when available for collision resistance (SEC-006), falling
    /// back to a djb2-style hash on platforms without CryptoKit.
    ///
    /// - Parameter input: The string to hash
    /// - Returns: A hexadecimal string representation of the hash
    private static func simpleHash(_ input: String) -> String {
        #if canImport(CryptoKit)
        // Use SHA256 for better collision resistance (SEC-006)
        let hash = SHA256.hash(data: Data(input.utf8))
        // Use first 16 bytes (32 hex chars) for reasonable filename length
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
        #else
        // Fallback to djb2 on platforms without CryptoKit
        var hash: UInt64 = 5381
        for char in input.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        return String(format: "%016llx", hash)
        #endif
    }

    // MARK: - Maintenance

    private func startMaintenanceTasks() {
        maintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minutes
                await self?.performMaintenance()
            }
        }
    }

    private func performMaintenanceIfNeeded() async {
        let l1MemoryUsage = l1Cache.values.reduce(0) { $0 + $1.data.count }
        let l2MemoryUsage = l2Cache.values.reduce(0) { $0 + $1.compressedData.count }

        if l1Cache.count > configuration.l1MaxSize || l1MemoryUsage > configuration.l1MaxMemory ||
           l2Cache.count > configuration.l2MaxSize || l2MemoryUsage > configuration.l2MaxMemory ||
           l3Index.count > configuration.l3MaxSize {
            await performMaintenance()
        }
    }

    private func performMaintenance() async {
        let startTime = Date()

        // Clean expired entries
        await cleanExpiredEntries()

        // Evict least valuable entries if over limits
        await evictIfNeeded()

        // Clean up orphaned L3 files
        await cleanupOrphanedL3Files()

        let maintenanceTime = Date().timeIntervalSince(startTime)
        logger?.logDebug("Multi-level cache maintenance completed", context: [
            "maintenanceTime": maintenanceTime,
            "l1Entries": l1Cache.count,
            "l2Entries": l2Cache.count,
            "l3Entries": l3Index.count
        ])
    }

    private func cleanExpiredEntries() async {
        // Clean L1
        let expiredL1 = l1Cache.filter { $0.value.isExpired }
        for key in expiredL1.keys {
            l1Cache.removeValue(forKey: key)
        }

        // Clean L2
        let expiredL2 = l2Cache.filter { $0.value.isExpired }
        for key in expiredL2.keys {
            l2Cache.removeValue(forKey: key)
        }

        // Clean L3
        let expiredL3 = l3Index.filter { $0.value.isExpired }
        for (key, metadata) in expiredL3 {
            l3Index.removeValue(forKey: key)
            try? FileManager.default.removeItem(at: l3CacheDirectory.appendingPathComponent(metadata.filename))
        }

        if !expiredL1.isEmpty || !expiredL2.isEmpty || !expiredL3.isEmpty {
            logger?.logDebug("Cleaned expired cache entries", context: [
                "expiredL1": expiredL1.count,
                "expiredL2": expiredL2.count,
                "expiredL3": expiredL3.count
            ])
        }
    }

    /// Evicts entries from cache tiers when they exceed configured limits.
    ///
    /// Entries are sorted by score (higher = more valuable) and the lowest-scoring
    /// entries are evicted first. Valuable entries may be demoted to lower tiers.
    private func evictIfNeeded() async {
        // Evict from L1 if needed
        if l1Cache.count > configuration.l1MaxSize {
            let sortedL1 = l1Cache.sorted { $0.value.score > $1.value.score }
            let targetCount = Int(Double(configuration.l1MaxSize) * 0.8)
            // Clamp toEvict to valid range to prevent array index out of bounds
            let toEvict = min(l1Cache.count - targetCount, sortedL1.count)

            guard toEvict > 0 else { return }

            // Evict lowest-scoring entries (at end of sorted array)
            let startIndex = max(0, sortedL1.count - toEvict)
            for i in startIndex..<sortedL1.count {
                let (key, entry) = sortedL1[i]
                l1Cache.removeValue(forKey: key)

                // Demote valuable entries to L2
                if entry.priority.rawValue >= CachePriority.normal.rawValue {
                    await demoteToL2(key: key, from: entry)
                }
            }
        }

        // Evict from L2 if needed
        if l2Cache.count > configuration.l2MaxSize {
            let sortedL2 = l2Cache.sorted { $0.value.score > $1.value.score }
            let targetCount = Int(Double(configuration.l2MaxSize) * 0.8)
            // Clamp toEvict to valid range to prevent array index out of bounds
            let toEvict = min(l2Cache.count - targetCount, sortedL2.count)

            guard toEvict > 0 else { return }

            // Evict lowest-scoring entries (at end of sorted array)
            let startIndex = max(0, sortedL2.count - toEvict)
            for i in startIndex..<sortedL2.count {
                let (key, entry) = sortedL2[i]
                l2Cache.removeValue(forKey: key)

                // Demote valuable entries to L3
                if entry.priority.rawValue >= CachePriority.normal.rawValue {
                    do {
                        let decompressedData = try await decompress(entry.compressedData)
                        await demoteToL3(key: key, data: decompressedData, from: entry)
                    } catch {
                        // If decompression fails, just discard
                        logger?.logWarning("Failed to decompress during L2 eviction", context: [
                            "key": key
                        ])
                    }
                }
            }
        }

        // Evict from L3 if needed
        if l3Index.count > configuration.l3MaxSize {
            let sortedL3 = l3Index.sorted { $0.value.accessCount < $1.value.accessCount }
            let targetCount = Int(Double(configuration.l3MaxSize) * 0.8)
            let toEvict = min(l3Index.count - targetCount, sortedL3.count)

            guard toEvict > 0 else { return }

            for i in 0..<toEvict {
                let (key, metadata) = sortedL3[i]
                l3Index.removeValue(forKey: key)
                do {
                    try FileManager.default.removeItem(at: l3CacheDirectory.appendingPathComponent(metadata.filename))
                } catch {
                    logger?.logWarning("Failed to remove L3 cache file", context: [
                        "filename": metadata.filename,
                        "error": error.localizedDescription
                    ])
                }
            }
        }
    }

    private func demoteToL2(key: String, from l1Entry: L1CacheEntry) async {
        guard l2Cache.count < configuration.l2MaxSize else { return }

        do {
            let compressedData = try await compress(l1Entry.data)
            let compressionRatio = Double(l1Entry.data.count) / Double(compressedData.count)

            let l2Entry = L2CacheEntry(
                compressedData: compressedData,
                originalSize: l1Entry.data.count,
                compressionRatio: compressionRatio,
                timestamp: l1Entry.timestamp,
                ttl: l1Entry.ttl,
                accessCount: l1Entry.accessCount,
                lastAccessed: l1Entry.lastAccessed,
                priority: l1Entry.priority
            )

            l2Cache[key] = l2Entry
        } catch {
            // If compression fails, demote to L3 without compression
            await demoteToL3(key: key, data: l1Entry.data, priority: l1Entry.priority, ttl: l1Entry.ttl)
        }
    }

    private func demoteToL3(key: String, data: Data, from entry: L2CacheEntry) async {
        await storeInL3(
            key: key,
            data: data,
            priority: entry.priority,
            ttl: entry.ttl
        )
    }

    private func demoteToL3(key: String, data: Data, priority: CachePriority, ttl: TimeInterval) async {
        await storeInL3(
            key: key,
            data: data,
            priority: priority,
            ttl: ttl
        )
    }

    private func cleanupOrphanedL3Files() async {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: l3CacheDirectory, includingPropertiesForKeys: nil)
            let indexedFiles = Set(l3Index.values.map { $0.filename })

            for file in files {
                if !indexedFiles.contains(file.lastPathComponent) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            // Ignore directory read errors
        }
    }
}

// MARK: - Supporting Types

/// Errors that can occur during multi-level cache operations
public enum MultiLevelCacheError: Error, LocalizedError {
    /// Compression operation failed during cache promotion or storage
    case compressionFailed
    /// Decompression operation failed during cache retrieval
    case decompressionFailed

    public var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress data for cache storage"
        case .decompressionFailed:
            return "Failed to decompress cached data"
        }
    }

    public var failureReason: String? {
        switch self {
        case .compressionFailed:
            return "The compression algorithm returned an invalid result or empty output"
        case .decompressionFailed:
            return "The decompression algorithm could not decode the compressed data"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .compressionFailed:
            return "The entry will be stored without compression in a lower cache tier"
        case .decompressionFailed:
            return "The corrupted cache entry will be removed and data will be fetched fresh"
        }
    }
}

/// Statistics tracking for compression and decompression operations.
public struct CompressionStats: Sendable {
    /// Total number of compression operations performed
    public var totalCompressions: Int = 0
    /// Total number of decompression operations performed
    public var totalDecompressions: Int = 0
    /// Total bytes before compression
    public var totalOriginalBytes: Int = 0
    /// Total bytes after compression
    public var totalCompressedBytes: Int = 0
    /// Running average compression time in seconds
    public var averageCompressionTime: TimeInterval = 0.0
    /// Running average decompression time in seconds
    public var averageDecompressionTime: TimeInterval = 0.0

    /// Average compression ratio (original size / compressed size).
    ///
    /// Returns 1.0 if no data has been compressed yet.
    public var averageCompressionRatio: Double {
        guard totalOriginalBytes > 0 && totalCompressedBytes > 0 else { return 1.0 }
        return Double(totalOriginalBytes) / Double(totalCompressedBytes)
    }

    /// Records a compression operation.
    ///
    /// - Parameters:
    ///   - originalSize: Size of data before compression in bytes
    ///   - compressedSize: Size of data after compression in bytes
    ///   - compressionTime: Time taken to compress in seconds
    public mutating func recordCompression(originalSize: Int, compressedSize: Int, compressionTime: TimeInterval) {
        let previousTotal = Double(totalCompressions) * averageCompressionTime
        totalCompressions += 1
        totalOriginalBytes += originalSize
        totalCompressedBytes += compressedSize
        averageCompressionTime = (previousTotal + compressionTime) / Double(totalCompressions)
    }

    /// Records a decompression operation.
    ///
    /// - Parameter decompressionTime: Time taken to decompress in seconds
    public mutating func recordDecompression(decompressionTime: TimeInterval) {
        let previousTotal = Double(totalDecompressions) * averageDecompressionTime
        totalDecompressions += 1
        // Use separate counter to avoid division by zero when decompressions > compressions
        averageDecompressionTime = (previousTotal + decompressionTime) / Double(totalDecompressions)
    }
}

public struct MultiLevelCacheStatistics: Sendable {
    public let l1Stats: CacheTierStatistics
    public let l2Stats: CacheTierStatistics
    public let l3Stats: CacheTierStatistics
    public let overallHitRate: Double
    public let totalMisses: Int
    public let compressionStats: CompressionStats

    public var description: String {
        return """
        Multi-Level Cache Statistics:
        L1 (Memory): \(l1Stats.entries)/\(l1Stats.maxEntries) entries, \(l1Stats.memoryUsage) bytes, \(String(format: "%.1f", l1Stats.hitRate * 100))% hit rate
        L2 (Compressed): \(l2Stats.entries)/\(l2Stats.maxEntries) entries, \(l2Stats.memoryUsage) bytes, \(String(format: "%.1f", l2Stats.hitRate * 100))% hit rate
        L3 (Disk): \(l3Stats.entries)/\(l3Stats.maxEntries) entries, \(l3Stats.memoryUsage) bytes, \(String(format: "%.1f", l3Stats.hitRate * 100))% hit rate
        Overall Hit Rate: \(String(format: "%.1f", overallHitRate * 100))%
        Compression Ratio: \(String(format: "%.1f", compressionStats.averageCompressionRatio)):1
        """
    }
}

public struct CacheTierStatistics: Sendable {
    public let entries: Int
    public let maxEntries: Int
    public let memoryUsage: Int
    public let maxMemory: Int
    public let hitCount: Int
    public let hitRate: Double
}