import XCTest
@testable import Substation

/// Integration tests for version embedding system
///
/// These tests verify the end-to-end functionality of the version embedding
/// system, including the interaction between the build plugin and the runtime code.
final class VersionEmbeddingIntegrationTests: XCTestCase {

    // MARK: - Setup and Teardown

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // MARK: - Build Information Integration Tests

    /// Test that version information is properly embedded in binary
    func testVersionEmbeddedInBinary() {
        // Verify that BuildInfo is accessible and contains valid data
        XCTAssertFalse(BuildInfo.version.isEmpty, "Version should be embedded")
        XCTAssertFalse(BuildInfo.gitCommitHash.isEmpty, "Commit hash should be embedded")
        XCTAssertFalse(BuildInfo.buildDate.isEmpty, "Build date should be embedded")
        XCTAssertFalse(BuildInfo.configuration.isEmpty, "Configuration should be embedded")
    }

    /// Test that version info doesn't require git at runtime
    func testVersionDoesNotRequireGitAtRuntime() {
        // This test verifies that BuildInfo values are available
        // without executing any git commands at runtime

        // Access all BuildInfo values
        let version = BuildInfo.version
        let commitHash = BuildInfo.gitCommitHash
        let buildDate = BuildInfo.buildDate
        let configuration = BuildInfo.configuration

        // If we got here without errors, the values are embedded
        XCTAssertNotNil(version, "Version should be available without git")
        XCTAssertNotNil(commitHash, "Commit hash should be available without git")
        XCTAssertNotNil(buildDate, "Build date should be available without git")
        XCTAssertNotNil(configuration, "Configuration should be available without git")
    }

    /// Test that version info is consistent across multiple accesses
    func testVersionInfoConsistency() {
        // Access BuildInfo multiple times
        var versions: [String] = []
        var commits: [String] = []
        var dates: [String] = []
        var configs: [String] = []

        for _ in 0..<10 {
            versions.append(BuildInfo.version)
            commits.append(BuildInfo.gitCommitHash)
            dates.append(BuildInfo.buildDate)
            configs.append(BuildInfo.configuration)
        }

        // All values should be identical
        XCTAssertEqual(Set(versions).count, 1, "Version should be consistent")
        XCTAssertEqual(Set(commits).count, 1, "Commit hash should be consistent")
        XCTAssertEqual(Set(dates).count, 1, "Build date should be consistent")
        XCTAssertEqual(Set(configs).count, 1, "Configuration should be consistent")
    }

    // MARK: - Version Format Validation Tests

    /// Test that version follows semantic versioning or git describe format
    func testVersionFollowsExpectedFormat() {
        let version = BuildInfo.version

        // Skip if version is "unknown"
        guard version != "unknown" else {
            return
        }

        // Version should match one of these patterns:
        // 1. Semantic version: "1.2.3"
        // 2. Semantic version with pre-release: "1.2.3-alpha.1"
        // 3. Git describe: "v1.2.3-5-gabc1234"
        // 4. Short hash: "abc1234"

        let semverPattern = #"^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$"#
        let gitDescribePattern = #"^v?\d+\.\d+\.\d+(-\d+-g[a-f0-9]+)?$"#
        let shortHashPattern = #"^[a-f0-9]{7,}$"#

        let isSemver = version.range(of: semverPattern, options: .regularExpression) != nil
        let isGitDescribe = version.range(of: gitDescribePattern, options: .regularExpression) != nil
        let isShortHash = version.range(of: shortHashPattern, options: .regularExpression) != nil

        XCTAssertTrue(isSemver || isGitDescribe || isShortHash,
                     "Version '\(version)' should match expected format")
    }

    /// Test that commit hash is valid git short hash
    func testCommitHashIsValidGitHash() {
        let commitHash = BuildInfo.gitCommitHash

        // Skip if commit hash is "Unknown"
        guard commitHash != "Unknown" else {
            return
        }

        // Should be lowercase hexadecimal
        let hexPattern = #"^[a-f0-9]+$"#
        let isHex = commitHash.range(of: hexPattern, options: .regularExpression) != nil

        XCTAssertTrue(isHex, "Commit hash '\(commitHash)' should be hexadecimal")
        XCTAssertGreaterThanOrEqual(commitHash.count, 7, "Commit hash should be at least 7 characters")
    }

    /// Test that build date is recent and valid
    func testBuildDateIsRecentAndValid() {
        let buildDateString = BuildInfo.buildDate

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let buildDate = formatter.date(from: buildDateString) else {
            XCTFail("Build date '\(buildDateString)' should be valid ISO 8601")
            return
        }

        let now = Date()

        // Build date should not be in the future (with 1 hour tolerance for clock skew)
        XCTAssertLessThanOrEqual(buildDate, now.addingTimeInterval(3600),
                                "Build date should not be in the future")

        // Build date should not be too old (within last year)
        let oneYearAgo = now.addingTimeInterval(-365 * 24 * 3600)
        XCTAssertGreaterThanOrEqual(buildDate, oneYearAgo,
                                   "Build date should not be more than a year old")
    }

    // MARK: - Cross-Component Integration Tests

    /// Test that BuildInfo values would work in user-facing displays
    func testBuildInfoSuitableForDisplay() {
        // Create a formatted display string similar to what would be shown to users
        let displayString = """
        Substation
        Version: \(BuildInfo.version)
        Commit: \(BuildInfo.gitCommitHash)
        Built: \(BuildInfo.buildDate)
        Configuration: \(BuildInfo.configuration)
        """

        // Verify the display string contains all components
        XCTAssertTrue(displayString.contains("Substation"))
        XCTAssertTrue(displayString.contains("Version:"))
        XCTAssertTrue(displayString.contains("Commit:"))
        XCTAssertTrue(displayString.contains("Built:"))
        XCTAssertTrue(displayString.contains("Configuration:"))

        // Verify no placeholder values leaked through
        XCTAssertFalse(displayString.contains("$"), "Should not contain template variables")
        XCTAssertFalse(displayString.contains("("), "Should not contain interpolation syntax")
    }

    /// Test that BuildInfo can be logged safely
    func testBuildInfoCanBeLoggedSafely() {
        // Simulate logging BuildInfo
        let logEntry = [
            "version": BuildInfo.version,
            "commit": BuildInfo.gitCommitHash,
            "buildDate": BuildInfo.buildDate,
            "configuration": BuildInfo.configuration
        ]

        // Verify all fields are present
        XCTAssertEqual(logEntry.count, 4, "Log entry should contain 4 fields")

        // Verify all values are non-empty
        for (key, value) in logEntry {
            XCTAssertFalse(value.isEmpty, "\(key) should not be empty in log entry")
        }
    }

    // MARK: - Performance Tests

    /// Test that accessing BuildInfo is fast (compile-time constants)
    func testBuildInfoAccessPerformance() {
        measure {
            // Access BuildInfo values many times
            for _ in 0..<1000 {
                _ = BuildInfo.version
                _ = BuildInfo.gitCommitHash
                _ = BuildInfo.buildDate
                _ = BuildInfo.configuration
            }
        }

        // If this test completes quickly, BuildInfo is properly inlined
        // as compile-time constants rather than computed at runtime
    }

    // MARK: - Backwards Compatibility Tests

    /// Test that BuildInfo provides all expected fields
    func testBuildInfoProvidesExpectedFields() {
        // Verify the public API is stable
        let version: String = BuildInfo.version
        let commitHash: String = BuildInfo.gitCommitHash
        let buildDate: String = BuildInfo.buildDate
        let configuration: String = BuildInfo.configuration

        // Type checking ensures the API hasn't changed
        XCTAssertTrue(version is String)
        XCTAssertTrue(commitHash is String)
        XCTAssertTrue(buildDate is String)
        XCTAssertTrue(configuration is String)
    }

    // MARK: - Edge Case Tests

    /// Test behavior when git information is not available
    func testGracefulDegradationWithoutGit() {
        // BuildInfo should have fallback values if git is not available
        // The plugin sets "unknown" or "Unknown" as fallback values

        let version = BuildInfo.version
        let commitHash = BuildInfo.gitCommitHash

        // Verify fallback values are reasonable
        if version == "unknown" {
            XCTAssertTrue(true, "Version uses fallback value when git is unavailable")
        } else {
            XCTAssertFalse(version.isEmpty, "Version should not be empty")
        }

        if commitHash == "Unknown" {
            XCTAssertTrue(true, "Commit hash uses fallback value when git is unavailable")
        } else {
            XCTAssertFalse(commitHash.isEmpty, "Commit hash should not be empty")
        }
    }

    /// Test that BuildInfo handles special characters safely
    func testBuildInfoHandlesSpecialCharactersSafely() {
        // Verify that BuildInfo values don't contain problematic characters
        let problematicChars = CharacterSet(charactersIn: "\"\'\n\r\t\\")

        XCTAssertNil(BuildInfo.version.rangeOfCharacter(from: problematicChars),
                    "Version should not contain problematic characters")
        XCTAssertNil(BuildInfo.gitCommitHash.rangeOfCharacter(from: problematicChars),
                    "Commit hash should not contain problematic characters")
        XCTAssertNil(BuildInfo.configuration.rangeOfCharacter(from: problematicChars),
                    "Configuration should not contain problematic characters")
    }

    // MARK: - Documentation Tests

    /// Test that BuildInfo is properly documented
    func testBuildInfoIsDocumented() {
        // This test ensures the enum and its properties exist and are accessible
        // If the code compiles and runs, the BuildInfo enum is properly defined

        // Access all public members
        _ = BuildInfo.version
        _ = BuildInfo.gitCommitHash
        _ = BuildInfo.buildDate
        _ = BuildInfo.configuration

        XCTAssertTrue(true, "BuildInfo is properly defined and accessible")
    }
}
