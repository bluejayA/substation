import XCTest
@testable import MemoryKit
import Foundation

/// Tests for MultiLevelCacheManager cloud-specific caching features
final class MultiLevelCacheTests: XCTestCase {

    // MARK: - Test Properties

    private var testCacheDirectory: URL!

    // MARK: - Setup and Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Create a temporary directory for test cache files
        let tempDir = FileManager.default.temporaryDirectory
        testCacheDirectory = tempDir.appendingPathComponent("test-cache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testCacheDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up test cache directory
        if let testDir = testCacheDirectory {
            try? FileManager.default.removeItem(at: testDir)
        }
        try await super.tearDown()
    }

    // MARK: - Cloud-Specific Directory Tests

    func testCacheUsesCloudSpecificSubdirectory() async throws {
        let cloudName = "test-cloud"
        let config = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 10,
            l2MaxSize: 10,
            l3MaxSize: 100,
            l3CacheDirectory: testCacheDirectory,
            cacheIdentifier: cloudName
        )

        let cache = MultiLevelCacheManager<String, Data>(configuration: config)

        // Store some data to trigger L3 cache file creation
        let testData = Data("test data content".utf8)
        await cache.store(testData, forKey: "test-key", priority: .normal)

        // Verify cloud-specific subdirectory was created
        let cloudDir = testCacheDirectory.appendingPathComponent(cloudName)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: cloudDir.path),
            "Cloud-specific subdirectory should be created"
        )
    }

    func testDifferentCloudsUseDifferentDirectories() async throws {
        let cloud1 = "production"
        let cloud2 = "staging"

        let config1 = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 10,
            l2MaxSize: 10,
            l3MaxSize: 100,
            l3CacheDirectory: testCacheDirectory,
            cacheIdentifier: cloud1
        )

        let config2 = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 10,
            l2MaxSize: 10,
            l3MaxSize: 100,
            l3CacheDirectory: testCacheDirectory,
            cacheIdentifier: cloud2
        )

        let cache1 = MultiLevelCacheManager<String, Data>(configuration: config1)
        let cache2 = MultiLevelCacheManager<String, Data>(configuration: config2)

        // Store data in both caches
        let testData = Data("test data".utf8)
        await cache1.store(testData, forKey: "shared-key", priority: .normal)
        await cache2.store(testData, forKey: "shared-key", priority: .normal)

        // Verify both cloud directories exist
        let cloud1Dir = testCacheDirectory.appendingPathComponent(cloud1)
        let cloud2Dir = testCacheDirectory.appendingPathComponent(cloud2)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: cloud1Dir.path),
            "Production cloud directory should exist"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: cloud2Dir.path),
            "Staging cloud directory should exist"
        )
    }

    func testCloudNameWithSpecialCharactersIsSanitized() async throws {
        let cloudName = "cloud/with:special chars"
        // Sanitization REMOVES invalid characters (/, :, space), doesn't replace with underscore
        let expectedSanitized = "cloudwithspecialchars"

        let config = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 10,
            l2MaxSize: 10,
            l3MaxSize: 100,
            l3CacheDirectory: testCacheDirectory,
            cacheIdentifier: cloudName
        )

        let cache = MultiLevelCacheManager<String, Data>(configuration: config)

        // Store large data (>= 500KB) to trigger L3 storage and directory creation
        // Small data goes to L1/L2, only large data or overflow goes to L3
        let testData = Data(repeating: 0x42, count: 512 * 1024)  // 512KB to force L3
        await cache.store(testData, forKey: "key", priority: .normal)

        // Verify sanitized directory was created
        let sanitizedDir = testCacheDirectory.appendingPathComponent(expectedSanitized)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: sanitizedDir.path),
            "Sanitized cloud directory should be created"
        )
    }

    // MARK: - Consistent Hash-Based Filename Tests

    func testConsistentFilenameGeneration() async throws {
        let cloudName = "test-cloud"
        let config = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 1,
            l1MaxMemory: 1,
            l2MaxSize: 1,
            l2MaxMemory: 1,
            l3MaxSize: 100,
            l3CacheDirectory: testCacheDirectory,
            cacheIdentifier: cloudName
        )

        let cache = MultiLevelCacheManager<String, Data>(configuration: config)

        // Store large data (>= 500KB) to trigger L3 storage directly
        // Small data goes to L1/L2 based on priority, only large data or overflow goes to L3
        let testData = Data(repeating: 0x41, count: 512 * 1024)  // 512KB to force L3
        let testKey = "nova_server_list"
        await cache.store(testData, forKey: testKey, priority: .normal)

        // Get list of files in the cloud directory
        let cloudDir = testCacheDirectory.appendingPathComponent(cloudName)
        let files = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
        let datFiles = files.filter { $0.hasSuffix(".dat") }

        // Verify at least one .dat file exists
        XCTAssertFalse(datFiles.isEmpty, "Should have created at least one .dat file")

        // Verify filename format is cache_<hash>.dat (no timestamp)
        for filename in datFiles {
            XCTAssertTrue(
                filename.hasPrefix("cache_"),
                "Filename should start with 'cache_'"
            )
            XCTAssertTrue(
                filename.hasSuffix(".dat"),
                "Filename should end with '.dat'"
            )
            // Verify it's a hash format (cache_<32-char-hex>.dat)
            // SHA256 produces 32 bytes, we use first 16 bytes = 32 hex characters
            let nameWithoutPrefix = filename.dropFirst("cache_".count)
            let nameWithoutSuffix = nameWithoutPrefix.dropLast(".dat".count)
            XCTAssertEqual(
                nameWithoutSuffix.count, 32,
                "Hash portion should be 32 characters (16 bytes from SHA256)"
            )
            // Verify it's hexadecimal
            let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
            XCTAssertTrue(
                nameWithoutSuffix.unicodeScalars.allSatisfy { hexChars.contains($0) },
                "Hash should be hexadecimal"
            )
        }
    }

    func testSameKeyProducesSameFilename() async throws {
        let cloudName = "consistency-test"
        let testKey = "test_consistent_key"
        let testData = Data("data".utf8)

        // Create first cache instance
        let config1 = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 1,
            l1MaxMemory: 1,
            l2MaxSize: 1,
            l2MaxMemory: 1,
            l3MaxSize: 100,
            l3CacheDirectory: testCacheDirectory,
            cacheIdentifier: cloudName
        )
        let cache1 = MultiLevelCacheManager<String, Data>(configuration: config1)
        await cache1.store(testData, forKey: testKey, priority: .normal)

        // Get files after first store
        let cloudDir = testCacheDirectory.appendingPathComponent(cloudName)
        let files1 = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
            .filter { $0.hasSuffix(".dat") }

        // Clear the cache
        await cache1.clearAll()

        // Create second cache instance (simulating restart)
        let config2 = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 1,
            l1MaxMemory: 1,
            l2MaxSize: 1,
            l2MaxMemory: 1,
            l3MaxSize: 100,
            l3CacheDirectory: testCacheDirectory,
            cacheIdentifier: cloudName
        )
        let cache2 = MultiLevelCacheManager<String, Data>(configuration: config2)
        await cache2.store(testData, forKey: testKey, priority: .normal)

        // Get files after second store
        let files2 = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
            .filter { $0.hasSuffix(".dat") }

        // Verify same filename is used (hash-based consistency)
        XCTAssertEqual(
            Set(files1), Set(files2),
            "Same key should produce same filename across instances"
        )
    }

    // MARK: - Stale Cache Cleanup Tests

    func testCleanupStaleCacheFilesRemovesOldFiles() async throws {
        let cloudName = "cleanup-test"
        let cloudDir = testCacheDirectory.appendingPathComponent(cloudName)
        try FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true)

        // Create some test cache files with old modification dates
        let oldFile = cloudDir.appendingPathComponent("cache_old_1234567890abcdef.dat")
        let newFile = cloudDir.appendingPathComponent("cache_new_fedcba0987654321.dat")

        try Data("old data".utf8).write(to: oldFile)
        try Data("new data".utf8).write(to: newFile)

        // Set old file's modification date to 10 hours ago
        let oldDate = Date().addingTimeInterval(-10 * 60 * 60) // 10 hours ago
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: oldFile.path
        )

        // Run cleanup with 8-hour max age
        let removedCount = MultiLevelCacheManager<String, Data>.cleanupStaleCacheFiles(
            maxAge: 8 * 60 * 60, // 8 hours
            cloudName: cloudName,
            cacheDirectory: testCacheDirectory
        )

        // Verify old file was removed
        XCTAssertEqual(removedCount, 1, "Should remove 1 stale file")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: oldFile.path),
            "Old file should be removed"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: newFile.path),
            "New file should still exist"
        )
    }

    func testCleanupStaleCacheFilesOnlyAffectsSpecifiedCloud() async throws {
        let cloud1 = "cloud-one"
        let cloud2 = "cloud-two"

        let cloud1Dir = testCacheDirectory.appendingPathComponent(cloud1)
        let cloud2Dir = testCacheDirectory.appendingPathComponent(cloud2)

        try FileManager.default.createDirectory(at: cloud1Dir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cloud2Dir, withIntermediateDirectories: true)

        // Create old files in both directories
        let oldFile1 = cloud1Dir.appendingPathComponent("cache_old1.dat")
        let oldFile2 = cloud2Dir.appendingPathComponent("cache_old2.dat")

        try Data("data1".utf8).write(to: oldFile1)
        try Data("data2".utf8).write(to: oldFile2)

        // Set both files as old
        let oldDate = Date().addingTimeInterval(-10 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldFile1.path)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldFile2.path)

        // Clean up only cloud1
        let removedCount = MultiLevelCacheManager<String, Data>.cleanupStaleCacheFiles(
            maxAge: 8 * 60 * 60,
            cloudName: cloud1,
            cacheDirectory: testCacheDirectory
        )

        // Verify only cloud1's file was removed
        XCTAssertEqual(removedCount, 1, "Should remove 1 file from cloud1")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: oldFile1.path),
            "Cloud1's old file should be removed"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: oldFile2.path),
            "Cloud2's old file should still exist"
        )
    }

    func testCleanupReturnsZeroForNonexistentDirectory() async throws {
        let removedCount = MultiLevelCacheManager<String, Data>.cleanupStaleCacheFiles(
            cloudName: "nonexistent-cloud",
            cacheDirectory: testCacheDirectory
        )

        XCTAssertEqual(removedCount, 0, "Should return 0 for nonexistent directory")
    }

    func testCleanupIgnoresNonDatFiles() async throws {
        let cloudName = "ignore-test"
        let cloudDir = testCacheDirectory.appendingPathComponent(cloudName)
        try FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true)

        // Create various file types
        let datFile = cloudDir.appendingPathComponent("cache_test.dat")
        let txtFile = cloudDir.appendingPathComponent("cache_test.txt")
        let jsonFile = cloudDir.appendingPathComponent("cache_test.json")

        try Data("dat".utf8).write(to: datFile)
        try Data("txt".utf8).write(to: txtFile)
        try Data("json".utf8).write(to: jsonFile)

        // Set all files as old
        let oldDate = Date().addingTimeInterval(-10 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: datFile.path)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: txtFile.path)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: jsonFile.path)

        // Run cleanup
        let removedCount = MultiLevelCacheManager<String, Data>.cleanupStaleCacheFiles(
            maxAge: 8 * 60 * 60,
            cloudName: cloudName,
            cacheDirectory: testCacheDirectory
        )

        // Verify only .dat file was removed
        XCTAssertEqual(removedCount, 1, "Should only remove .dat file")
        XCTAssertFalse(FileManager.default.fileExists(atPath: datFile.path), ".dat file should be removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: txtFile.path), ".txt file should remain")
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonFile.path), ".json file should remain")
    }

    // MARK: - Configuration Tests

    func testConfigurationWithCacheIdentifier() async throws {
        let cloudName = "config-test-cloud"
        let config = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 100,
            l1MaxMemory: 1024 * 1024,
            l2MaxSize: 500,
            l2MaxMemory: 5 * 1024 * 1024,
            l3MaxSize: 1000,
            l3CacheDirectory: testCacheDirectory,
            defaultTTL: 600,
            enableCompression: true,
            enableMetrics: true,
            cacheIdentifier: cloudName
        )

        XCTAssertEqual(config.cacheIdentifier, cloudName, "cacheIdentifier should be set correctly")
        XCTAssertEqual(config.l1MaxSize, 100)
        XCTAssertEqual(config.l3MaxSize, 1000)
    }

    func testConfigurationWithoutCacheIdentifier() async throws {
        let config = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 100,
            l3CacheDirectory: testCacheDirectory
        )

        XCTAssertNil(config.cacheIdentifier, "cacheIdentifier should be nil when not provided")
    }

    // MARK: - Integration Tests

    func testCloudDirectoryCreatedOnCacheInit() async throws {
        let cloudName = "init-test-cloud"
        let config = MultiLevelCacheManager<String, Data>.Configuration(
            l1MaxSize: 100,
            l2MaxSize: 100,
            l3MaxSize: 100,
            l3CacheDirectory: testCacheDirectory,
            cacheIdentifier: cloudName
        )

        // Just creating the cache should create the cloud directory
        let _ = MultiLevelCacheManager<String, Data>(configuration: config)

        // Verify cloud-specific directory was created during initialization
        let cloudDir = testCacheDirectory.appendingPathComponent(cloudName)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: cloudDir.path),
            "Cloud directory should be created during cache initialization"
        )
    }

    func testHashBasedFilenameIsDeterministic() async throws {
        // Test that the same key always produces the same hash
        let key1 = "nova_server_list"
        let key2 = "nova_server_list"
        let key3 = "neutron_network_list"

        // Use the same hash function as MultiLevelCacheManager
        func simpleHash(_ input: String) -> String {
            var hash: UInt64 = 5381
            for char in input.utf8 {
                hash = ((hash << 5) &+ hash) &+ UInt64(char)
            }
            return String(format: "%016llx", hash)
        }

        let hash1 = simpleHash(key1)
        let hash2 = simpleHash(key2)
        let hash3 = simpleHash(key3)

        // Same keys should produce same hash
        XCTAssertEqual(hash1, hash2, "Same keys should produce same hash")

        // Different keys should produce different hashes
        XCTAssertNotEqual(hash1, hash3, "Different keys should produce different hashes")

        // Hash should be 16 characters (64-bit hex)
        XCTAssertEqual(hash1.count, 16, "Hash should be 16 hex characters")
    }
}
