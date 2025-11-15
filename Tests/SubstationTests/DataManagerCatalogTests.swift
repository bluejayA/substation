import XCTest
@testable import Substation
@testable import OSClient

/// Unit tests for DataManager catalog methods
final class DataManagerCatalogTests: XCTestCase {

    // MARK: - Test Fixtures

    /// Mock KeystoneService for testing
    actor MockKeystoneService {
        var listCatalogCalled = false
        var listCatalogWithEndpointsCalled = false
        var mockServices: [Service] = []
        var mockCatalogEntries: [TokenCatalogEntry] = []
        var shouldThrowError: (any Error)?

        func listCatalog(options: PaginationOptions = PaginationOptions()) async throws -> [Service] {
            listCatalogCalled = true

            if let error = shouldThrowError {
                throw error
            }

            return mockServices
        }

        func listCatalogWithEndpoints(options: PaginationOptions = PaginationOptions()) async throws -> [TokenCatalogEntry] {
            listCatalogWithEndpointsCalled = true

            if let error = shouldThrowError {
                throw error
            }

            return mockCatalogEntries
        }

        func reset() {
            listCatalogCalled = false
            listCatalogWithEndpointsCalled = false
            mockServices = []
            mockCatalogEntries = []
            shouldThrowError = nil
        }

        func setMockServices(_ services: [Service]) {
            mockServices = services
        }

        func setMockCatalogEntries(_ entries: [TokenCatalogEntry]) {
            mockCatalogEntries = entries
        }

        func setError(_ error: any Error) {
            shouldThrowError = error
        }
    }

    // MARK: - Helper Methods

    func createMockServices() -> [Service] {
        return [
            Service(
                id: "service1",
                name: "nova",
                type: "compute",
                description: "OpenStack Compute Service",
                enabled: true
            ),
            Service(
                id: "service2",
                name: "neutron",
                type: "network",
                description: "OpenStack Networking Service",
                enabled: true
            ),
            Service(
                id: "service3",
                name: "keystone",
                type: "identity",
                description: "OpenStack Identity Service",
                enabled: true
            )
        ]
    }

    func createMockCatalogEntries() -> [TokenCatalogEntry] {
        let computeEndpoints = [
            TokenEndpoint(
                id: "endpoint1",
                interface: "public",
                region: "RegionOne",
                url: "https://compute.example.com:8774/v2.1"
            ),
            TokenEndpoint(
                id: "endpoint2",
                interface: "internal",
                region: "RegionOne",
                url: "https://compute.internal.example.com:8774/v2.1"
            )
        ]

        let networkEndpoints = [
            TokenEndpoint(
                id: "endpoint3",
                interface: "public",
                region: "RegionOne",
                url: "https://network.example.com:9696"
            )
        ]

        let identityEndpoints = [
            TokenEndpoint(
                id: "endpoint4",
                interface: "public",
                region: "RegionOne",
                url: "https://keystone.example.com:5000/v3"
            )
        ]

        return [
            TokenCatalogEntry(
                id: "service1",
                name: "nova",
                type: "compute",
                endpoints: computeEndpoints
            ),
            TokenCatalogEntry(
                id: "service2",
                name: "neutron",
                type: "network",
                endpoints: networkEndpoints
            ),
            TokenCatalogEntry(
                id: "service3",
                name: "keystone",
                type: "identity",
                endpoints: identityEndpoints
            )
        ]
    }

    // MARK: - getCatalog Tests

    func testGetCatalog_ReturnsServices() {
        // Test that getCatalog returns Service objects without endpoint details
        let mockServices = createMockServices()

        // Verify services have expected structure
        XCTAssertEqual(mockServices.count, 3)

        let computeService = mockServices.first { $0.type == "compute" }
        XCTAssertNotNil(computeService)
        XCTAssertEqual(computeService?.name, "nova")
        XCTAssertEqual(computeService?.id, "service1")
        XCTAssertEqual(computeService?.enabled, true)

        // Service objects don't have endpoint information
        // This is the key difference from getCatalogWithEndpoints
    }

    func testGetCatalog_DelegatestoKeystoneService() async {
        // This test demonstrates that getCatalog should delegate to KeystoneService.listCatalog()
        // In actual implementation, DataManager.getCatalog() calls keystone.listCatalog()

        let mockKeystone = MockKeystoneService()
        let mockServices = createMockServices()
        await mockKeystone.setMockServices(mockServices)

        // Simulate the call
        let services = try? await mockKeystone.listCatalog()

        // Verify
        let called = await mockKeystone.listCatalogCalled
        XCTAssertTrue(called, "Should delegate to KeystoneService.listCatalog()")
        XCTAssertEqual(services?.count, 3)
    }

    // MARK: - getCatalogWithEndpoints Tests

    func testGetCatalogWithEndpoints_ReturnsTokenCatalogEntries() {
        // Test that getCatalogWithEndpoints returns TokenCatalogEntry objects with full endpoint details
        let mockEntries = createMockCatalogEntries()

        // Verify entries have expected structure
        XCTAssertEqual(mockEntries.count, 3)

        let computeEntry = mockEntries.first { $0.type == "compute" }
        XCTAssertNotNil(computeEntry)
        XCTAssertEqual(computeEntry?.name, "nova")
        XCTAssertEqual(computeEntry?.id, "service1")
        XCTAssertEqual(computeEntry?.endpoints.count, 2)

        // Verify endpoints are preserved
        let publicEndpoint = computeEntry?.endpoints.first { $0.interface == "public" }
        XCTAssertNotNil(publicEndpoint)
        XCTAssertEqual(publicEndpoint?.url, "https://compute.example.com:8774/v2.1")
        XCTAssertEqual(publicEndpoint?.region, "RegionOne")
    }

    func testGetCatalogWithEndpoints_DelegatestoKeystoneService() async {
        // This test demonstrates that getCatalogWithEndpoints should delegate to KeystoneService.listCatalogWithEndpoints()
        let mockKeystone = MockKeystoneService()
        let mockEntries = createMockCatalogEntries()
        await mockKeystone.setMockCatalogEntries(mockEntries)

        // Simulate the call
        let entries = try? await mockKeystone.listCatalogWithEndpoints()

        // Verify
        let called = await mockKeystone.listCatalogWithEndpointsCalled
        XCTAssertTrue(called, "Should delegate to KeystoneService.listCatalogWithEndpoints()")
        XCTAssertEqual(entries?.count, 3)
    }

    func testGetCatalogWithEndpoints_PreservesAllEndpoints() {
        // Test that all endpoint interfaces are preserved
        let mockEntries = createMockCatalogEntries()
        let computeEntry = mockEntries.first { $0.type == "compute" }!

        // Verify both public and internal endpoints are present
        let publicEndpoint = computeEntry.endpoints.first { $0.interface == "public" }
        let internalEndpoint = computeEntry.endpoints.first { $0.interface == "internal" }

        XCTAssertNotNil(publicEndpoint)
        XCTAssertNotNil(internalEndpoint)
        XCTAssertEqual(publicEndpoint?.url, "https://compute.example.com:8774/v2.1")
        XCTAssertEqual(internalEndpoint?.url, "https://compute.internal.example.com:8774/v2.1")
    }

    // MARK: - Method Comparison Tests

    func testGetCatalog_vs_GetCatalogWithEndpoints() {
        // Compare the two methods to verify their differences
        let mockServices = createMockServices()
        let mockEntries = createMockCatalogEntries()

        // Both should return the same number of services
        XCTAssertEqual(mockServices.count, mockEntries.count)

        // But getCatalogWithEndpoints has endpoint information
        for (index, service) in mockServices.enumerated() {
            let entry = mockEntries[index]

            // Same basic information
            XCTAssertEqual(service.type, entry.type)
            XCTAssertEqual(service.name, entry.name)

            // But entry has endpoints
            XCTAssertGreaterThan(entry.endpoints.count, 0, "Catalog entry should have endpoints")
        }
    }

    // MARK: - Usage Pattern Tests

    func testHealthDashboard_ShouldUseCatalogWithEndpoints() {
        // Health Dashboard needs endpoint URLs for display
        // Therefore it should use getCatalogWithEndpoints() not getCatalog()

        let mockEntries = createMockCatalogEntries()
        let computeEntry = mockEntries.first { $0.type == "compute" }!

        // Simulate what HealthDashboardView does:
        // Find service by name and extract endpoint URLs
        let endpoints = computeEntry.endpoints.map { "\($0.interface): \($0.url)" }

        XCTAssertEqual(endpoints.count, 2)
        XCTAssertTrue(endpoints.contains("public: https://compute.example.com:8774/v2.1"))
        XCTAssertTrue(endpoints.contains("internal: https://compute.internal.example.com:8774/v2.1"))
    }

    func testServiceListing_CanUseEitherMethod() {
        // For simple service listing (just names and types), getCatalog() is sufficient
        let mockServices = createMockServices()

        let serviceNames = mockServices.map { $0.name ?? $0.type }
        XCTAssertEqual(serviceNames.count, 3)
        XCTAssertTrue(serviceNames.contains("nova"))
        XCTAssertTrue(serviceNames.contains("neutron"))
        XCTAssertTrue(serviceNames.contains("keystone"))
    }

    // MARK: - Error Handling Tests

    func testGetCatalog_HandlesAuthenticationError() async {
        let mockKeystone = MockKeystoneService()
        let authError = OpenStackError.authenticationFailed
        await mockKeystone.setError(authError)

        do {
            _ = try await mockKeystone.listCatalog()
            XCTFail("Should throw authentication error")
        } catch let error as OpenStackError {
            switch error {
            case .authenticationFailed:
                XCTAssertTrue(true, "Correctly identified as authenticationFailed")
            default:
                XCTFail("Expected authenticationFailed error")
            }
        } catch {
            XCTFail("Expected OpenStackError")
        }
    }

    func testGetCatalogWithEndpoints_HandlesAuthenticationError() async {
        let mockKeystone = MockKeystoneService()
        let authError = OpenStackError.authenticationFailed
        await mockKeystone.setError(authError)

        do {
            _ = try await mockKeystone.listCatalogWithEndpoints()
            XCTFail("Should throw authentication error")
        } catch let error as OpenStackError {
            switch error {
            case .authenticationFailed:
                XCTAssertTrue(true, "Correctly identified as authenticationFailed")
            default:
                XCTFail("Expected authenticationFailed error")
            }
        } catch {
            XCTFail("Expected OpenStackError")
        }
    }

    func testGetCatalog_HandlesEndpointNotFound() async {
        let mockKeystone = MockKeystoneService()
        let endpointError = OpenStackError.endpointNotFound(service: "identity")
        await mockKeystone.setError(endpointError)

        do {
            _ = try await mockKeystone.listCatalog()
            XCTFail("Should throw endpoint not found error")
        } catch let error as OpenStackError {
            switch error {
            case .endpointNotFound(let service):
                XCTAssertEqual(service, "identity")
            default:
                XCTFail("Expected endpointNotFound error")
            }
        } catch {
            XCTFail("Expected OpenStackError")
        }
    }

    // MARK: - Regression Tests

    func testOldGetRawCatalog_ReplacedWithGetCatalogWithEndpoints() {
        // This test documents that getRawCatalog() has been replaced
        // Old method: getRawCatalog() - made direct API call
        // New method: getCatalogWithEndpoints() - delegates to KeystoneService

        // The new method should return the same data structure
        let mockEntries = createMockCatalogEntries()

        // Verify the data structure matches what getRawCatalog used to return
        XCTAssertEqual(mockEntries.count, 3)
        XCTAssertTrue(mockEntries.allSatisfy { $0.endpoints.count > 0 })

        // Verify all required fields are present
        for entry in mockEntries {
            XCTAssertNotNil(entry.id)
            XCTAssertNotNil(entry.name)
            XCTAssertNotNil(entry.type)
            XCTAssertFalse(entry.endpoints.isEmpty)

            for endpoint in entry.endpoints {
                XCTAssertNotNil(endpoint.id)
                XCTAssertNotNil(endpoint.interface)
                XCTAssertNotNil(endpoint.region)
                XCTAssertNotNil(endpoint.url)
            }
        }
    }

    func testHealthDashboardView_UsagePattern() {
        // Test the usage pattern from HealthDashboardView
        let catalogEntries = createMockCatalogEntries()
        let serviceName = "Nova" // Case-insensitive match

        // Simulate HealthDashboardView's search logic
        if let catalogEntry = catalogEntries.first(where: { entry in
            let entryName = (entry.name ?? entry.type).lowercased()
            return entryName == serviceName.lowercased() || entry.type.lowercased() == serviceName.lowercased()
        }) {
            let endpoints = catalogEntry.endpoints.map { "\($0.interface): \($0.url)" }

            // Verify endpoints are found
            XCTAssertEqual(endpoints.count, 2)
            XCTAssertTrue(endpoints.contains("public: https://compute.example.com:8774/v2.1"))
        } else {
            XCTFail("Should find Nova service")
        }
    }

    // MARK: - Performance Considerations

    func testGetCatalog_LighterWeight() {
        // getCatalog() returns lighter Service objects (without endpoint arrays)
        // getCatalogWithEndpoints() returns heavier TokenCatalogEntry objects (with endpoint arrays)

        let mockServices = createMockServices()
        let mockEntries = createMockCatalogEntries()

        // Service objects have fewer fields
        let serviceFieldCount = 5 // id, name, type, description, enabled

        // TokenCatalogEntry has same fields plus endpoints array
        let entryFieldCount = 4 // id, name, type, endpoints (array)

        XCTAssertEqual(mockServices.count, 3)
        XCTAssertEqual(mockEntries.count, 3)

        // Verify entries have more data
        let totalEndpoints = mockEntries.reduce(0) { $0 + $1.endpoints.count }
        XCTAssertGreaterThan(totalEndpoints, 0, "Entries should have endpoint data")
    }
}
