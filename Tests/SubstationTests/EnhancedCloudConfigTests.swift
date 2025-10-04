import XCTest
@testable import Substation

final class EnhancedCloudConfigTests: XCTestCase {

    // MARK: - YAML Value Processor Tests

    func testBasicValueProcessing() {
        let processor = YAMLValueProcessor()

        // Test simple unquoted values
        XCTAssertEqual(processor.processValue("simple"), "simple")
        XCTAssertEqual(processor.processValue("  spaced  "), "spaced")

        // Test single-quoted strings
        XCTAssertEqual(processor.processValue("'quoted string'"), "quoted string")
        XCTAssertEqual(processor.processValue("'don''t'"), "don't")

        // Test double-quoted strings
        XCTAssertEqual(processor.processValue("\"double quoted\""), "double quoted")
        XCTAssertEqual(processor.processValue("\"escaped\\n\""), "escaped\n")
        XCTAssertEqual(processor.processValue("\"tab\\t\""), "tab\t")
        XCTAssertEqual(processor.processValue("\"quote\\\"\""), "quote\"")
        XCTAssertEqual(processor.processValue("\"backslash\\\\\""), "backslash\\")
    }

    func testEnvironmentVariableExpansion() {
        // Set test environment variables
        setenv("TEST_VAR", "test_value", 1)
        setenv("EMPTY_VAR", "", 1)

        let processor = YAMLValueProcessor()

        // Test simple variable expansion
        XCTAssertEqual(processor.processValue("$TEST_VAR"), "test_value")
        XCTAssertEqual(processor.processValue("${TEST_VAR}"), "test_value")

        // Test variable with default
        XCTAssertEqual(processor.processValue("${NONEXISTENT:-default}"), "default")
        XCTAssertEqual(processor.processValue("${TEST_VAR:-default}"), "test_value")
        XCTAssertEqual(processor.processValue("${EMPTY_VAR:-default}"), "default")

        // Test variable expansion in strings
        XCTAssertEqual(processor.processValue("prefix_${TEST_VAR}_suffix"), "prefix_test_value_suffix")

        // Clean up
        unsetenv("TEST_VAR")
        unsetenv("EMPTY_VAR")
    }

    func testHexEscapeSequences() {
        let processor = YAMLValueProcessor()

        // Test ASCII hex escapes (project requires ASCII only)
        XCTAssertEqual(processor.processValue("\"\\x41\""), "A")  // ASCII 65 = 'A'
        XCTAssertEqual(processor.processValue("\"\\x20\""), " ")  // ASCII 32 = space
        XCTAssertEqual(processor.processValue("\"\\x7F\""), "\u{7F}") // ASCII 127 = DEL
    }

    // MARK: - Enhanced YAML Parser Tests

    func testBasicCloudsParsing() async throws {
        let yamlContent = """
        clouds:
          testcloud:
            auth:
              auth_url: https://identity.example.com/v3
              username: testuser
              password: testpass
              project_name: testproject
            region_name: RegionOne
        """

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        XCTAssertEqual(config.clouds.count, 1)
        XCTAssertNotNil(config.clouds["testcloud"])

        let cloudConfig = config.clouds["testcloud"]!
        XCTAssertEqual(cloudConfig.auth.auth_url, "https://identity.example.com/v3")
        XCTAssertEqual(cloudConfig.auth.username, "testuser")
        XCTAssertEqual(cloudConfig.auth.password, "testpass")
        XCTAssertEqual(cloudConfig.auth.project_name, "testproject")
        XCTAssertEqual(cloudConfig.region_name, "RegionOne")
    }

    func testApplicationCredentialParsing() async throws {
        let yamlContent = """
        clouds:
          appcloud:
            auth:
              auth_url: "https://keystone.example.com:5000/v3"
              application_credential_id: "abc123"
              application_credential_secret: "secret456"
              project_name: "myproject"
            region_name: us-west-1
            interface: public
        """

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        let cloudConfig = config.clouds["appcloud"]!
        XCTAssertEqual(cloudConfig.auth.application_credential_id, "abc123")
        XCTAssertEqual(cloudConfig.auth.application_credential_secret, "secret456")
        XCTAssertEqual(cloudConfig.auth.project_name, "myproject")
        XCTAssertEqual(cloudConfig.region_name, "us-west-1")
        XCTAssertEqual(cloudConfig.interface, "public")
    }

    func testEnvironmentVariableInYAML() async throws {
        // Set environment variables for test
        setenv("OS_USERNAME", "env_user", 1)
        setenv("OS_PASSWORD", "env_pass", 1)
        setenv("OS_PROJECT", "env_project", 1)

        let yamlContent = """
        clouds:
          envcloud:
            auth:
              auth_url: https://identity.example.com/v3
              username: $OS_USERNAME
              password: "${OS_PASSWORD}"
              project_name: ${OS_PROJECT:-default_project}
            region_name: RegionOne
        """

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        let cloudConfig = config.clouds["envcloud"]!
        XCTAssertEqual(cloudConfig.auth.username, "env_user")
        XCTAssertEqual(cloudConfig.auth.password, "env_pass")
        XCTAssertEqual(cloudConfig.auth.project_name, "env_project")

        // Clean up
        unsetenv("OS_USERNAME")
        unsetenv("OS_PASSWORD")
        unsetenv("OS_PROJECT")
    }

    func testMultipleClouds() async throws {
        let yamlContent = """
        clouds:
          cloud1:
            auth:
              auth_url: https://cloud1.example.com/v3
              username: user1
              password: pass1
              project_name: project1
            region_name: Region1

          cloud2:
            auth:
              auth_url: https://cloud2.example.com/v3
              application_credential_id: cred_id
              application_credential_secret: cred_secret
              project_name: project2
            region_name: Region2
            interface: internal
        """

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        XCTAssertEqual(config.clouds.count, 2)

        let cloud1 = config.clouds["cloud1"]!
        XCTAssertEqual(cloud1.auth.username, "user1")
        XCTAssertEqual(cloud1.auth.password, "pass1")
        XCTAssertEqual(cloud1.region_name, "Region1")

        let cloud2 = config.clouds["cloud2"]!
        XCTAssertEqual(cloud2.auth.application_credential_id, "cred_id")
        XCTAssertEqual(cloud2.auth.application_credential_secret, "cred_secret")
        XCTAssertEqual(cloud2.region_name, "Region2")
        XCTAssertEqual(cloud2.interface, "internal")
    }

    // MARK: - Authentication Manager Tests

    func testPasswordAuthMethodDetermination() async {
        let authManager = AuthenticationManager()
        let authConfig = AuthConfig(
            auth_url: "https://example.com/v3",
            username: "user",
            password: "pass",
            project_name: "project",
            project_domain_name: "Default",
            user_domain_name: "Default",
            application_credential_id: nil,
            application_credential_secret: nil
        )

        let method = await authManager.determineAuthMethod(from: authConfig)

        switch method {
        case .password(let username, let password, let projectName, let userDomain, let projectDomain):
            XCTAssertEqual(username, "user")
            XCTAssertEqual(password, "pass")
            XCTAssertEqual(projectName, "project")
            XCTAssertEqual(userDomain, "Default")
            XCTAssertEqual(projectDomain, "Default")
        default:
            XCTFail("Expected password authentication method")
        }
    }

    func testApplicationCredentialAuthMethodDetermination() async {
        let authManager = AuthenticationManager()
        let authConfig = AuthConfig(
            auth_url: "https://example.com/v3",
            username: nil,
            password: nil,
            project_name: "project",
            project_domain_name: nil,
            user_domain_name: nil,
            application_credential_id: "cred_id",
            application_credential_secret: "cred_secret"
        )

        let method = await authManager.determineAuthMethod(from: authConfig)

        switch method {
        case .applicationCredentialById(let id, let secret, let projectName):
            XCTAssertEqual(id, "cred_id")
            XCTAssertEqual(secret, "cred_secret")
            XCTAssertEqual(projectName, "project")
        default:
            XCTFail("Expected application credential authentication method")
        }
    }

    func testAuthConfigValidation() async {
        let authManager = AuthenticationManager()

        // Test valid password config
        let validPasswordAuth = AuthConfig(
            auth_url: "https://example.com/v3",
            username: "user",
            password: "pass",
            project_name: "project",
            project_domain_name: "Default",
            user_domain_name: "Default",
            application_credential_id: nil,
            application_credential_secret: nil
        )

        let passwordErrors = await authManager.validateAuthConfiguration(validPasswordAuth)
        XCTAssertTrue(passwordErrors.isEmpty)

        // Test invalid config (missing auth_url)
        let invalidAuth = AuthConfig(
            auth_url: "",
            username: "user",
            password: "pass",
            project_name: "project",
            project_domain_name: "Default",
            user_domain_name: "Default",
            application_credential_id: nil,
            application_credential_secret: nil
        )

        let invalidErrors = await authManager.validateAuthConfiguration(invalidAuth)
        XCTAssertFalse(invalidErrors.isEmpty)
        XCTAssertTrue(invalidErrors.contains { $0.contains("auth_url") })

        // Test missing authentication method
        let noAuthMethod = AuthConfig(
            auth_url: "https://example.com/v3",
            username: nil,
            password: nil,
            project_name: "project",
            project_domain_name: "Default",
            user_domain_name: "Default",
            application_credential_id: nil,
            application_credential_secret: nil
        )

        let noAuthErrors = await authManager.validateAuthConfiguration(noAuthMethod)
        XCTAssertFalse(noAuthErrors.isEmpty)
        XCTAssertTrue(noAuthErrors.contains { $0.contains("authentication method") })
    }

    // MARK: - Secure Credential Storage Tests

    func testCredentialStorage() async {
        let storage = SecureCredentialStorage()

        // Test store and retrieve
        await storage.store("secret_value", for: "test_key")
        let retrieved = await storage.retrieve(for: "test_key")
        XCTAssertEqual(retrieved, "secret_value")

        // Test non-existent key
        let missing = await storage.retrieve(for: "missing_key")
        XCTAssertNil(missing)

        // Test clear specific key
        await storage.clear(for: "test_key")
        let clearedValue = await storage.retrieve(for: "test_key")
        XCTAssertNil(clearedValue)

        // Test clear all
        await storage.store("value1", for: "key1")
        await storage.store("value2", for: "key2")
        await storage.clearAll()

        let cleared1 = await storage.retrieve(for: "key1")
        let cleared2 = await storage.retrieve(for: "key2")
        XCTAssertNil(cleared1)
        XCTAssertNil(cleared2)
    }

    // MARK: - Integration Tests

    func testEnhancedCloudConfigManagerIntegration() async throws {
        // Create a temporary YAML file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test-clouds.yaml")

        let yamlContent = """
        clouds:
          testcloud:
            auth:
              auth_url: https://identity.example.com/v3
              username: testuser
              password: "testpass"
              project_name: testproject
              user_domain_name: Default
              project_domain_name: Default
            region_name: RegionOne
            interface: public
            identity_api_version: "3"
        """

        try yamlContent.write(to: testFile, atomically: true, encoding: .utf8)

        let manager = CloudConfigManager()

        // Test loading clouds config
        let config = try await manager.loadCloudsConfig(path: testFile.path)
        XCTAssertEqual(config.clouds.count, 1)
        XCTAssertNotNil(config.clouds["testcloud"])

        // Test listing available clouds
        let availableClouds = try await manager.listAvailableClouds(path: testFile.path)
        XCTAssertEqual(availableClouds, ["testcloud"])

        // Test getting specific cloud config
        let cloudConfig = try await manager.getCloudConfig("testcloud", path: testFile.path)
        XCTAssertEqual(cloudConfig.auth.username, "testuser")
        XCTAssertEqual(cloudConfig.auth.password, "testpass")
        XCTAssertEqual(cloudConfig.region_name, "RegionOne")

        // Test validation
        let validationErrors = try await manager.validateCloudConfig("testcloud", path: testFile.path)
        XCTAssertTrue(validationErrors.isEmpty)

        // Test authentication method determination
        let authMethod = try await manager.getAuthenticationMethod("testcloud", path: testFile.path)
        XCTAssertNotNil(authMethod)

        switch authMethod {
        case .password(let username, _, let projectName, _, _):
            XCTAssertEqual(username, "testuser")
            XCTAssertEqual(projectName, "testproject")
        default:
            XCTFail("Expected password authentication method")
        }

        // Test environment variable detection
        let hasEnvVars = try await manager.hasEnvironmentVariables("testcloud", path: testFile.path)
        XCTAssertFalse(hasEnvVars) // This config doesn't use env vars

        // Test cloud info
        let cloudInfo = try await manager.getCloudInfo("testcloud", path: testFile.path)
        XCTAssertEqual(cloudInfo.name, "testcloud")
        XCTAssertTrue(cloudInfo.validationErrors.isEmpty)
        XCTAssertFalse(cloudInfo.hasEnvironmentVariables)
        XCTAssertNotNil(cloudInfo.authenticationMethod)

        // Clean up
        try FileManager.default.removeItem(at: testFile)
    }

    func testBackwardCompatibility() async throws {
        // Test that the enhanced parser can handle the original simple format
        let simpleYamlContent = """
        clouds:
          simplecloud:
            auth:
              auth_url: https://identity.example.com/v3
              username: user
              password: pass
              project_name: project
            region_name: RegionOne
        """

        let parser = EnhancedYAMLParser()
        let data = simpleYamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        XCTAssertEqual(config.clouds.count, 1)
        let cloudConfig = config.clouds["simplecloud"]!
        XCTAssertEqual(cloudConfig.auth.username, "user")
        XCTAssertEqual(cloudConfig.auth.password, "pass")
        XCTAssertEqual(cloudConfig.region_name, "RegionOne")
    }

    func testErrorHandling() async throws {
        let parser = EnhancedYAMLParser()

        // Test invalid YAML structure
        let invalidYaml = "invalid: yaml: structure:"
        let invalidData = invalidYaml.data(using: .utf8)!

        do {
            _ = try await parser.parse(invalidData)
            XCTFail("Expected parsing to fail for invalid YAML")
        } catch {
            // Expected to throw an error
        }

        // Test missing required fields
        let missingFieldYaml = """
        clouds:
          badcloud:
            auth:
              username: user
              password: pass
        """

        let missingFieldData = missingFieldYaml.data(using: .utf8)!
        do {
            _ = try await parser.parse(missingFieldData)
            XCTFail("Expected parsing to fail for missing auth_url")
        } catch CloudConfigError.missingRequiredField(let field) {
            XCTAssertEqual(field, "auth_url")
        } catch {
            XCTFail("Expected CloudConfigError.missingRequiredField, got \(error)")
        }
    }

    // MARK: - Error Handling Tests

    func testSkipCloudWithMissingRequiredField() async throws {
        let yamlContent = """
        clouds:
          valid-cloud:
            auth:
              auth_url: https://identity.example.com/v3
              username: testuser
              password: testpass
              project_name: testproject
            region_name: RegionOne
          invalid-cloud:
            auth:
              username: testuser
              password: testpass
              project_name: testproject
            region_name: RegionTwo
          another-valid-cloud:
            auth:
              auth_url: https://identity2.example.com/v3
              application_credential_id: abc123
              application_credential_secret: secret456
              project_name: myproject
            region_name: RegionThree
        """

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        // Verify that only valid clouds were loaded
        XCTAssertEqual(config.clouds.count, 2)
        XCTAssertNotNil(config.clouds["valid-cloud"])
        XCTAssertNotNil(config.clouds["another-valid-cloud"])
        XCTAssertNil(config.clouds["invalid-cloud"])

        // Verify that validation warnings were recorded for invalid cloud
        XCTAssertEqual(config.validationWarnings.count, 1)
        XCTAssertNotNil(config.validationWarnings["invalid-cloud"])
        XCTAssertTrue(config.validationWarnings["invalid-cloud"]?.contains("auth_url") ?? false)

        // Verify the valid clouds have correct data
        let validCloud = config.clouds["valid-cloud"]!
        XCTAssertEqual(validCloud.auth.auth_url, "https://identity.example.com/v3")
        XCTAssertEqual(validCloud.auth.username, "testuser")

        let anotherValidCloud = config.clouds["another-valid-cloud"]!
        XCTAssertEqual(anotherValidCloud.auth.auth_url, "https://identity2.example.com/v3")
        XCTAssertEqual(anotherValidCloud.auth.application_credential_id, "abc123")
    }

    // MARK: - Region Auto-Detection Tests
    //
    // These tests verify that clouds.yaml configurations without region_name
    // are parsed correctly, allowing the application to auto-detect regions
    // from the service catalog at runtime.

    func testRegionAutoDetectionWithNoRegion() async throws {
        let yamlContent = """
        clouds:
          cloud-no-region:
            auth:
              auth_url: https://identity.example.com/v3
              username: testuser
              password: testpass
              project_name: testproject
              user_domain_name: Default
              project_domain_name: Default
            interface: public
        """

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        // Verify cloud was loaded successfully
        XCTAssertEqual(config.clouds.count, 1)
        XCTAssertNotNil(config.clouds["cloud-no-region"])

        let cloud = config.clouds["cloud-no-region"]!

        // Verify region_name is nil (allowing auto-detection)
        XCTAssertNil(cloud.region_name)
        XCTAssertNil(cloud.primaryRegionName)

        // Verify other fields are properly configured
        XCTAssertEqual(cloud.auth.auth_url, "https://identity.example.com/v3")
        XCTAssertEqual(cloud.auth.username, "testuser")
        XCTAssertEqual(cloud.auth.project_name, "testproject")
        XCTAssertEqual(cloud.interface, "public")
    }

    func testRegionAutoDetectionWithEmptyString() async throws {
        let yamlContent = """
        clouds:
          cloud-empty-region:
            auth:
              auth_url: https://identity.example.com/v3
              username: testuser
              password: testpass
              project_name: testproject
              user_domain_name: Default
              project_domain_name: Default
            region_name: ""
            interface: public
        """

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        XCTAssertEqual(config.clouds.count, 1)
        let cloud = config.clouds["cloud-empty-region"]!

        // Empty string should result in nil primaryRegionName
        XCTAssertNil(cloud.primaryRegionName)
    }

    func testRegionConfigurationVariations() async throws {
        let yamlContent = """
        clouds:
          cloud-with-single-region:
            auth:
              auth_url: https://identity1.example.com/v3
              username: user1
              password: pass1
              project_name: project1
              user_domain_name: Default
              project_domain_name: Default
            region_name: RegionOne
            interface: public
          cloud-with-multiple-regions:
            auth:
              auth_url: https://identity2.example.com/v3
              username: user2
              password: pass2
              project_name: project2
              user_domain_name: Default
              project_domain_name: Default
            region_name:
              - RegionOne
              - RegionTwo
              - RegionThree
            interface: public
          cloud-with-no-region:
            auth:
              auth_url: https://identity3.example.com/v3
              username: user3
              password: pass3
              project_name: project3
              user_domain_name: Default
              project_domain_name: Default
            interface: public
        """

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!
        let config = try await parser.parse(data)

        XCTAssertEqual(config.clouds.count, 3)

        // Test single region
        let singleRegion = config.clouds["cloud-with-single-region"]!
        XCTAssertEqual(singleRegion.primaryRegionName, "RegionOne")
        XCTAssertEqual(singleRegion.allRegionNames, ["RegionOne"])

        // Test multiple regions (should use first as primary)
        let multiRegion = config.clouds["cloud-with-multiple-regions"]!
        XCTAssertEqual(multiRegion.primaryRegionName, "RegionOne")
        XCTAssertEqual(multiRegion.allRegionNames, ["RegionOne", "RegionTwo", "RegionThree"])

        // Test no region (should be nil for auto-detection)
        let noRegion = config.clouds["cloud-with-no-region"]!
        XCTAssertNil(noRegion.primaryRegionName)
        XCTAssertEqual(noRegion.allRegionNames, [])
    }

    // MARK: - Performance Tests

    func testParsingPerformance() async throws {
        // Create a large YAML configuration with multiple clouds
        var yamlContent = "clouds:\n"

        for i in 1...100 {
            yamlContent += """
              cloud\(i):
                auth:
                  auth_url: https://identity\(i).example.com/v3
                  username: user\(i)
                  password: pass\(i)
                  project_name: project\(i)
                  user_domain_name: Default
                  project_domain_name: Default
                region_name: Region\(i)
                interface: public
                identity_api_version: "3"

            """
        }

        let parser = EnhancedYAMLParser()
        let data = yamlContent.data(using: .utf8)!

        let startTime = Date()
        let config = try await parser.parse(data)
        let endTime = Date()

        let parseTime = endTime.timeIntervalSince(startTime)
        print("Parse time for 100 clouds: \(parseTime) seconds")

        // Verify parsing worked correctly
        XCTAssertEqual(config.clouds.count, 100)

        // Performance requirement: should parse within reasonable time (< 1 second for 100 clouds)
        XCTAssertLessThan(parseTime, 1.0)
    }
}

// MARK: - Test Utilities

extension EnhancedCloudConfigTests {

    /// Helper to create temporary YAML files for testing
    private func createTemporaryYAMLFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".yaml")
        try content.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile
    }

    /// Helper to clean up temporary files
    private func removeTemporaryFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}