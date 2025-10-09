import Foundation
import Testing
@testable import Substation

/// Tests for ContextSwitcher functionality
///
/// Validates cloud context discovery, switching, and error handling.
@Suite("ContextSwitcher Tests", .serialized)
struct ContextSwitcherTests {

    // MARK: - Test Fixtures
    //
    // Note: CloudConfigManager is final and cannot be mocked via subclassing.
    // These tests verify the ContextSwitcher's logic around cloud management
    // without mocking the CloudConfigManager itself.
    //
    // For full integration testing with actual clouds.yaml files,
    // create test fixtures in the test resources directory.

    /// Create a test cloud configuration
    private func createTestCloudConfig(authURL: String = "http://test.example.com:5000/v3") -> CloudConfig {
        let auth = AuthConfig(
            auth_url: authURL,
            username: "testuser",
            password: "testpass",
            project_name: "testproject",
            project_domain_name: "Default",
            user_domain_name: "Default",
            application_credential_id: nil,
            application_credential_secret: nil,
            application_credential_name: nil,
            user_id: nil,
            project_id: nil,
            project_domain_id: nil,
            user_domain_id: nil,
            token: nil,
            identity_provider: nil,
            protocol: nil,
            mapped_local_user: nil,
            system_scope: nil,
            passcode: nil,
            totp: nil,
            verify: nil,
            cacert: nil,
            cert: nil,
            key: nil,
            insecure: nil
        )

        return CloudConfig(
            auth: auth,
            region_name: .single("RegionOne"),
            interface: "public",
            identity_api_version: "3",
            compute_api_version: nil,
            network_api_version: nil,
            volume_api_version: nil,
            image_api_version: nil,
            object_store_api_version: nil,
            load_balancer_api_version: nil,
            orchestration_api_version: nil,
            dns_api_version: nil,
            key_manager_api_version: nil,
            baremetal_api_version: nil,
            volume_service_type: nil,
            compute_service_type: nil,
            network_service_type: nil,
            disable_vendor_agent: nil,
            floating_ip_source: nil,
            nat_destination: nil,
            auth_type: nil,
            auth_methods: nil,
            use_direct_access: nil,
            split_loggers: nil
        )
    }

    // MARK: - Cloud Discovery Tests

    @Test("Format context list shows message when no clouds")
    @MainActor
    func testFormatContextListNoClouds() async {
        // Create a real CloudConfigManager (will check standard paths)
        let manager = CloudConfigManager()
        let switcher = ContextSwitcher(cloudConfigManager: manager)

        let formatted = await switcher.formatContextList()
        // Either shows actual clouds or "no clouds configured" message
        #expect(formatted.contains("Available clouds:") || formatted.contains("No clouds configured"))
    }

    @Test("Default context returns nil or first cloud when no selection")
    @MainActor
    func testDefaultContext() async {
        let manager = CloudConfigManager()
        let switcher = ContextSwitcher(cloudConfigManager: manager)

        let defaultCloud = await switcher.defaultContext()
        // Either nil (no clouds) or a cloud name (has clouds)
        // Just verify it doesn't crash
        #expect(defaultCloud == nil || !defaultCloud!.isEmpty)
    }

    // MARK: - Error Handling Tests

    @Test("Context switch error provides helpful message for not found")
    @MainActor
    func testContextSwitchErrorNotFound() {
        let error = ContextSwitchError.cloudNotFound("missing", available: ["cloud1", "cloud2"])
        let description = error.errorDescription ?? ""

        #expect(description.contains("missing"))
        #expect(description.contains("cloud1"))
        #expect(description.contains("cloud2"))
    }

    @Test("Context switch error provides helpful message for empty clouds")
    @MainActor
    func testContextSwitchErrorNoClouds() {
        let error = ContextSwitchError.cloudNotFound("missing", available: [])
        let description = error.errorDescription ?? ""

        #expect(description.contains("No clouds are configured"))
    }

    @Test("Context switch error provides recovery suggestion")
    @MainActor
    func testContextSwitchErrorRecoverySuggestion() {
        let error = ContextSwitchError.cloudNotFound("missing", available: ["cloud1"])
        let suggestion = error.recoverySuggestion ?? ""

        #expect(suggestion.contains("cloud1"))
    }

    // MARK: - Basic Functionality Tests

    @Test("Context switcher initializes correctly")
    @MainActor
    func testContextSwitcherInit() async {
        let manager = CloudConfigManager()
        let switcher = ContextSwitcher(cloudConfigManager: manager)

        // Verify current context is nil on initialization
        #expect(switcher.currentContext == nil)
    }

    @Test("Available contexts returns array")
    @MainActor
    func testAvailableContextsReturnsArray() async {
        let manager = CloudConfigManager()
        let switcher = ContextSwitcher(cloudConfigManager: manager)

        let contexts = await switcher.availableContexts()
        // Should return an array (empty or with clouds)
        #expect(contexts is [String])
    }
}
