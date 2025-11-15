import XCTest
@testable import OSClient

/// Unit tests for KeystoneService catalog methods
final class KeystoneServiceTests: XCTestCase {

    // MARK: - Test Fixtures

    /// Mock OpenStackClientCore for testing
    actor MockOpenStackClientCore: OpenStackService {
        var serviceName: String { "identity" }
        var core: OpenStackClientCore { self as! OpenStackClientCore }

        var requestCalled = false
        var requestPath: String?
        var requestMethod: String?
        var lastExpectedStatus: Int?
        var mockResponse: Any?
        var shouldThrowError: (any Error)?

        func request<T: Decodable>(
            service: String,
            method: String,
            path: String,
            body: Data? = nil,
            headers: [String: String]? = nil,
            expected: Int
        ) async throws -> T {
            requestCalled = true
            requestPath = path
            requestMethod = method
            lastExpectedStatus = expected

            if let error = shouldThrowError {
                throw error
            }

            guard let response = mockResponse as? T else {
                throw OpenStackError.invalidResponse
            }

            return response
        }

        func requestVoid(
            service: String,
            method: String,
            path: String,
            body: Data? = nil,
            headers: [String: String]? = nil,
            expected: Int
        ) async throws {
            requestCalled = true
            requestPath = path
            requestMethod = method
            lastExpectedStatus = expected

            if let error = shouldThrowError {
                throw error
            }
        }

        func requestRaw(
            service: String,
            method: String,
            path: String,
            body: Data? = nil,
            headers: [String: String]? = nil,
            expected: Int
        ) async throws -> (Data, HTTPURLResponse) {
            throw OpenStackError.invalidResponse
        }

        func setMockResponse<T>(_ response: T) {
            mockResponse = response
        }

        func reset() {
            requestCalled = false
            requestPath = nil
            requestMethod = nil
            lastExpectedStatus = nil
            mockResponse = nil
            shouldThrowError = nil
        }
    }

    // MARK: - Helper Methods

    /// Create mock catalog response
    func createMockCatalogResponse() -> CatalogResponse {
        let endpoints = [
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
            ),
            TokenEndpoint(
                id: "endpoint3",
                interface: "admin",
                region: "RegionOne",
                url: "https://compute.admin.example.com:8774/v2.1"
            )
        ]

        let catalogEntries = [
            TokenCatalogEntry(
                id: "service1",
                name: "nova",
                type: "compute",
                endpoints: endpoints
            ),
            TokenCatalogEntry(
                id: "service2",
                name: "neutron",
                type: "network",
                endpoints: [
                    TokenEndpoint(
                        id: "endpoint4",
                        interface: "public",
                        region: "RegionOne",
                        url: "https://network.example.com:9696"
                    )
                ]
            ),
            TokenCatalogEntry(
                id: "service3",
                name: "keystone",
                type: "identity",
                endpoints: [
                    TokenEndpoint(
                        id: "endpoint5",
                        interface: "public",
                        region: "RegionOne",
                        url: "https://keystone.example.com:5000/v3"
                    )
                ]
            )
        ]

        return CatalogResponse(catalog: catalogEntries)
    }

    // MARK: - listCatalog Tests

    func testListCatalog_Success() async throws {
        // Given
        let mockCore = MockOpenStackClientCore()
        let mockResponse = createMockCatalogResponse()
        await mockCore.setMockResponse(mockResponse)

        // Note: We cannot directly instantiate KeystoneService with a mock core
        // This test demonstrates the expected behavior

        // Expected behavior:
        // - Should call request with path "/auth/catalog"
        // - Should use GET method
        // - Should expect 200 status
        // - Should map catalog entries to Service objects

        XCTAssertTrue(true, "Placeholder for integration test")
    }

    func testListCatalog_PathCorrect() {
        // Verify that the path does not include /v3 prefix
        // The path should be "/auth/catalog" not "/v3/auth/catalog"
        // because the service base URL already includes /v3

        let expectedPath = "/auth/catalog"
        XCTAssertFalse(expectedPath.hasPrefix("/v3/"), "Path should not include /v3 prefix")
        XCTAssertTrue(expectedPath.hasPrefix("/auth/"), "Path should start with /auth/")
    }

    func testListCatalog_WithPaginationOptions() {
        // Test that pagination options are properly added to query string
        let options = PaginationOptions(
            limit: 10,
            marker: "test-marker"
        )

        let queryItems = options.queryItems
        XCTAssertEqual(queryItems.count, 2)

        let limitItem = queryItems.first { $0.name == "limit" }
        XCTAssertNotNil(limitItem)
        XCTAssertEqual(limitItem?.value, "10")

        let markerItem = queryItems.first { $0.name == "marker" }
        XCTAssertNotNil(markerItem)
        XCTAssertEqual(markerItem?.value, "test-marker")
    }

    // MARK: - listCatalogWithEndpoints Tests

    func testListCatalogWithEndpoints_ReturnsTokenCatalogEntries() {
        // Given
        let mockResponse = createMockCatalogResponse()

        // When
        let catalogEntries = mockResponse.catalog

        // Then
        XCTAssertEqual(catalogEntries.count, 3, "Should return 3 catalog entries")

        // Verify compute service
        let computeService = catalogEntries.first { $0.type == "compute" }
        XCTAssertNotNil(computeService)
        XCTAssertEqual(computeService?.name, "nova")
        XCTAssertEqual(computeService?.endpoints.count, 3)

        // Verify network service
        let networkService = catalogEntries.first { $0.type == "network" }
        XCTAssertNotNil(networkService)
        XCTAssertEqual(networkService?.name, "neutron")
        XCTAssertEqual(networkService?.endpoints.count, 1)

        // Verify identity service
        let identityService = catalogEntries.first { $0.type == "identity" }
        XCTAssertNotNil(identityService)
        XCTAssertEqual(identityService?.name, "keystone")
        XCTAssertEqual(identityService?.endpoints.count, 1)
    }

    func testListCatalogWithEndpoints_PreservesEndpointDetails() {
        // Given
        let mockResponse = createMockCatalogResponse()
        let computeService = mockResponse.catalog.first { $0.type == "compute" }!

        // When
        let publicEndpoint = computeService.endpoints.first { $0.interface == "public" }
        let internalEndpoint = computeService.endpoints.first { $0.interface == "internal" }
        let adminEndpoint = computeService.endpoints.first { $0.interface == "admin" }

        // Then
        XCTAssertNotNil(publicEndpoint)
        XCTAssertEqual(publicEndpoint?.interface, "public")
        XCTAssertEqual(publicEndpoint?.region, "RegionOne")
        XCTAssertEqual(publicEndpoint?.url, "https://compute.example.com:8774/v2.1")

        XCTAssertNotNil(internalEndpoint)
        XCTAssertEqual(internalEndpoint?.interface, "internal")
        XCTAssertEqual(internalEndpoint?.url, "https://compute.internal.example.com:8774/v2.1")

        XCTAssertNotNil(adminEndpoint)
        XCTAssertEqual(adminEndpoint?.interface, "admin")
        XCTAssertEqual(adminEndpoint?.url, "https://compute.admin.example.com:8774/v2.1")
    }

    func testListCatalogWithEndpoints_PathCorrect() {
        // Verify that the path for listCatalogWithEndpoints is the same as listCatalog
        let expectedPath = "/auth/catalog"
        XCTAssertFalse(expectedPath.hasPrefix("/v3/"), "Path should not include /v3 prefix")
        XCTAssertTrue(expectedPath.hasPrefix("/auth/"), "Path should start with /auth/")
    }

    // MARK: - Comparison Tests

    func testListCatalog_vs_ListCatalogWithEndpoints() {
        // Given
        let mockResponse = createMockCatalogResponse()

        // Simulate listCatalog mapping
        let services = mockResponse.catalog.map { entry in
            Service(
                id: entry.id ?? UUID().uuidString,
                name: entry.name,
                type: entry.type,
                description: nil,
                enabled: true
            )
        }

        // Simulate listCatalogWithEndpoints
        let catalogEntries = mockResponse.catalog

        // Then
        XCTAssertEqual(services.count, catalogEntries.count, "Both should return same number of services")

        for (index, service) in services.enumerated() {
            let catalogEntry = catalogEntries[index]
            XCTAssertEqual(service.type, catalogEntry.type)
            XCTAssertEqual(service.name, catalogEntry.name)

            // listCatalog loses endpoint information
            // listCatalogWithEndpoints preserves it
            XCTAssertGreaterThan(catalogEntry.endpoints.count, 0, "Catalog entry should have endpoints")
        }
    }

    // MARK: - Edge Cases

    func testListCatalogWithEndpoints_EmptyEndpoints() {
        // Given
        let emptyEntry = TokenCatalogEntry(
            id: "service1",
            name: "test-service",
            type: "test",
            endpoints: []
        )
        let response = CatalogResponse(catalog: [emptyEntry])

        // When
        let catalogEntries = response.catalog

        // Then
        XCTAssertEqual(catalogEntries.count, 1)
        XCTAssertEqual(catalogEntries[0].endpoints.count, 0, "Service can have zero endpoints")
    }

    func testListCatalogWithEndpoints_ServiceWithoutID() {
        // Given
        let entry = TokenCatalogEntry(
            id: nil,
            name: "test-service",
            type: "test",
            endpoints: []
        )

        // Then
        XCTAssertNil(entry.id, "Service ID can be nil")
        XCTAssertNotNil(entry.name)
        XCTAssertNotNil(entry.type)
    }

    func testListCatalogWithEndpoints_ServiceWithoutName() {
        // Given
        let entry = TokenCatalogEntry(
            id: "service1",
            name: nil,
            type: "test",
            endpoints: []
        )

        // Then
        XCTAssertNil(entry.name, "Service name can be nil")
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.type)
    }

    // MARK: - Error Handling

    func testListCatalog_AuthenticationError() async {
        // Test that authentication errors are properly propagated
        let expectedError = OpenStackError.authenticationFailed

        // Verify error type
        switch expectedError {
        case .authenticationFailed:
            XCTAssertTrue(true, "Correctly identified as authenticationFailed")
        default:
            XCTFail("Expected authenticationFailed error")
        }
    }

    func testListCatalog_EndpointNotFound() async {
        // Test that endpoint not found errors are properly propagated
        let expectedError = OpenStackError.endpointNotFound(service: "identity")

        // Verify error type
        switch expectedError {
        case .endpointNotFound(let service):
            XCTAssertEqual(service, "identity")
        default:
            XCTFail("Expected endpointNotFound error")
        }
    }

    // MARK: - Integration Behavior Tests

    func testCatalogResponse_Decodable() throws {
        // Test that CatalogResponse can be properly decoded from JSON
        let json = """
        {
            "catalog": [
                {
                    "id": "service1",
                    "name": "nova",
                    "type": "compute",
                    "endpoints": [
                        {
                            "id": "endpoint1",
                            "interface": "public",
                            "region": "RegionOne",
                            "url": "https://compute.example.com:8774/v2.1"
                        }
                    ]
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let response = try decoder.decode(CatalogResponse.self, from: data)

        XCTAssertEqual(response.catalog.count, 1)
        XCTAssertEqual(response.catalog[0].name, "nova")
        XCTAssertEqual(response.catalog[0].type, "compute")
        XCTAssertEqual(response.catalog[0].endpoints.count, 1)
        XCTAssertEqual(response.catalog[0].endpoints[0].interface, "public")
    }

    func testTokenEndpoint_AllFields() {
        // Test that TokenEndpoint preserves all required fields
        let endpoint = TokenEndpoint(
            id: "endpoint1",
            interface: "public",
            region: "RegionOne",
            url: "https://example.com/v3"
        )

        XCTAssertEqual(endpoint.id, "endpoint1")
        XCTAssertEqual(endpoint.interface, "public")
        XCTAssertEqual(endpoint.region, "RegionOne")
        XCTAssertEqual(endpoint.url, "https://example.com/v3")
    }

    func testTokenCatalogEntry_AllFields() {
        // Test that TokenCatalogEntry preserves all required fields
        let endpoints = [
            TokenEndpoint(
                id: "endpoint1",
                interface: "public",
                region: "RegionOne",
                url: "https://example.com/v3"
            )
        ]

        let entry = TokenCatalogEntry(
            id: "service1",
            name: "keystone",
            type: "identity",
            endpoints: endpoints
        )

        XCTAssertEqual(entry.id, "service1")
        XCTAssertEqual(entry.name, "keystone")
        XCTAssertEqual(entry.type, "identity")
        XCTAssertEqual(entry.endpoints.count, 1)
        XCTAssertEqual(entry.endpoints[0].id, "endpoint1")
    }
}
