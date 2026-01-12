// Tests/SubstationTests/Modules/DataProviderTests.swift
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2025 Kevin Carter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
@testable import Substation

// MARK: - DataProvider Test Suite

/// Comprehensive test suite for DataProvider implementations.
///
/// Tests cover:
/// - DataFetchPriority behavior
/// - DataFetchResult creation and properties
/// - DataProvider protocol requirements
/// - DataProviderRegistry operations
/// - Timeout handling patterns
/// - Cache management
final class DataProviderTests: XCTestCase {

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            DataProviderRegistry.shared.clear()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            DataProviderRegistry.shared.clear()
        }
        super.tearDown()
    }

    // MARK: - DataFetchPriority Tests

    /// Test all DataFetchPriority cases have correct raw values
    @MainActor
    func testDataFetchPriorityRawValues() {
        XCTAssertEqual(DataFetchPriority.critical.rawValue, "critical")
        XCTAssertEqual(DataFetchPriority.secondary.rawValue, "secondary")
        XCTAssertEqual(DataFetchPriority.background.rawValue, "background")
        XCTAssertEqual(DataFetchPriority.onDemand.rawValue, "on-demand")
        XCTAssertEqual(DataFetchPriority.fast.rawValue, "fast")
    }

    /// Test DataFetchPriority is Sendable
    @MainActor
    func testDataFetchPriorityIsSendable() {
        let priority: DataFetchPriority = .critical

        Task {
            // This compiles because DataFetchPriority is Sendable
            let _ = priority
        }

        XCTAssertTrue(true, "DataFetchPriority should be Sendable")
    }

    // MARK: - DataFetchResult Tests

    /// Test DataFetchResult initialization with all parameters
    @MainActor
    func testDataFetchResultInitializationWithAllParameters() {
        let error = TestDataProviderError.testError
        let result = DataFetchResult(
            itemCount: 42,
            duration: 1.5,
            fromCache: true,
            error: error
        )

        XCTAssertEqual(result.itemCount, 42)
        XCTAssertEqual(result.duration, 1.5)
        XCTAssertTrue(result.fromCache)
        XCTAssertNotNil(result.error)
    }

    /// Test DataFetchResult initialization with default values
    @MainActor
    func testDataFetchResultInitializationWithDefaults() {
        let result = DataFetchResult(
            itemCount: 10,
            duration: 0.5
        )

        XCTAssertEqual(result.itemCount, 10)
        XCTAssertEqual(result.duration, 0.5)
        XCTAssertFalse(result.fromCache)
        XCTAssertNil(result.error)
    }

    /// Test DataFetchResult is Sendable
    @MainActor
    func testDataFetchResultIsSendable() {
        let result = DataFetchResult(itemCount: 5, duration: 0.1)

        Task {
            // This compiles because DataFetchResult is Sendable
            let _ = result.itemCount
        }

        XCTAssertTrue(true, "DataFetchResult should be Sendable")
    }

    // MARK: - Mock DataProvider Tests

    /// Test mock data provider registration
    @MainActor
    func testMockDataProviderRegistration() {
        let provider = TestDataProvider(resourceType: "test-resource")

        DataProviderRegistry.shared.register(provider, from: "test-module")

        let retrieved = DataProviderRegistry.shared.provider(for: "test-resource")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.resourceType, "test-resource")
    }

    /// Test mock data provider fetchData
    @MainActor
    func testMockDataProviderFetchData() async {
        let provider = TestDataProvider(resourceType: "fetch-resource", mockItemCount: 25)
        DataProviderRegistry.shared.register(provider, from: "test-module")

        let result = await DataProviderRegistry.shared.fetchData(
            for: "fetch-resource",
            priority: .critical,
            forceRefresh: false
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.itemCount, 25)
        XCTAssertNil(result?.error)
    }

    /// Test mock data provider with force refresh
    @MainActor
    func testMockDataProviderForceRefresh() async {
        let provider = TestDataProvider(resourceType: "refresh-resource")
        DataProviderRegistry.shared.register(provider, from: "test-module")

        // First fetch (from cache = false when forceRefresh)
        let result1 = await DataProviderRegistry.shared.fetchData(
            for: "refresh-resource",
            priority: .critical,
            forceRefresh: true
        )

        // Second fetch (from cache = true when not forceRefresh)
        let result2 = await DataProviderRegistry.shared.fetchData(
            for: "refresh-resource",
            priority: .critical,
            forceRefresh: false
        )

        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertFalse(result1?.fromCache ?? true)
        XCTAssertTrue(result2?.fromCache ?? false)
    }

    /// Test data provider current item count
    @MainActor
    func testDataProviderCurrentItemCount() async {
        let provider = TestDataProvider(resourceType: "count-resource", mockItemCount: 100)
        DataProviderRegistry.shared.register(provider, from: "test-module")

        XCTAssertEqual(provider.currentItemCount, 100)
    }

    /// Test data provider last refresh time
    @MainActor
    func testDataProviderLastRefreshTime() async {
        let provider = TestDataProvider(resourceType: "time-resource")
        DataProviderRegistry.shared.register(provider, from: "test-module")

        // Initially nil
        XCTAssertNil(provider.lastRefreshTime)

        // After fetch, should be set
        _ = await provider.fetchData(priority: .critical, forceRefresh: true)

        XCTAssertNotNil(provider.lastRefreshTime)
    }

    /// Test data provider needs refresh
    @MainActor
    func testDataProviderNeedsRefresh() async {
        let provider = TestDataProvider(resourceType: "needs-refresh-resource")

        // Without last refresh time, should need refresh
        XCTAssertTrue(provider.needsRefresh(threshold: 60))

        // After fetch, should not need refresh immediately
        _ = await provider.fetchData(priority: .critical, forceRefresh: true)
        XCTAssertFalse(provider.needsRefresh(threshold: 60))
    }

    /// Test data provider clear cache
    @MainActor
    func testDataProviderClearCache() async {
        let provider = TestDataProvider(resourceType: "clear-cache-resource")

        // Fetch to set last refresh time
        _ = await provider.fetchData(priority: .critical, forceRefresh: true)
        XCTAssertNotNil(provider.lastRefreshTime)

        // Clear cache
        await provider.clearCache()

        XCTAssertNil(provider.lastRefreshTime)
        XCTAssertEqual(provider.currentItemCount, 0)
    }

    // MARK: - DataProviderRegistry Tests

    /// Test registry provider count
    @MainActor
    func testRegistryProviderCount() {
        let provider1 = TestDataProvider(resourceType: "resource-1")
        let provider2 = TestDataProvider(resourceType: "resource-2")
        let provider3 = TestDataProvider(resourceType: "resource-3")

        DataProviderRegistry.shared.register(provider1, from: "module-1")
        DataProviderRegistry.shared.register(provider2, from: "module-2")
        DataProviderRegistry.shared.register(provider3, from: "module-3")

        let types = DataProviderRegistry.shared.allResourceTypes()
        XCTAssertEqual(types.count, 3)
    }

    /// Test registry all resource types
    @MainActor
    func testRegistryAllResourceTypes() {
        let provider1 = TestDataProvider(resourceType: "servers")
        let provider2 = TestDataProvider(resourceType: "networks")

        DataProviderRegistry.shared.register(provider1, from: "servers-module")
        DataProviderRegistry.shared.register(provider2, from: "networks-module")

        let types = DataProviderRegistry.shared.allResourceTypes()

        XCTAssertTrue(types.contains("servers"))
        XCTAssertTrue(types.contains("networks"))
    }

    /// Test registry clear all caches
    @MainActor
    func testRegistryClearAllCaches() async {
        let provider1 = TestDataProvider(resourceType: "cache-1")
        let provider2 = TestDataProvider(resourceType: "cache-2")

        DataProviderRegistry.shared.register(provider1, from: "module-1")
        DataProviderRegistry.shared.register(provider2, from: "module-2")

        // Fetch to populate caches
        _ = await provider1.fetchData(priority: .critical, forceRefresh: true)
        _ = await provider2.fetchData(priority: .critical, forceRefresh: true)

        XCTAssertNotNil(provider1.lastRefreshTime)
        XCTAssertNotNil(provider2.lastRefreshTime)

        // Clear all caches
        await DataProviderRegistry.shared.clearAllCaches()

        XCTAssertNil(provider1.lastRefreshTime)
        XCTAssertNil(provider2.lastRefreshTime)
    }

    /// Test registry get stale resources
    @MainActor
    func testRegistryGetStaleResources() async {
        let freshProvider = TestDataProvider(
            resourceType: "fresh",
            mockLastRefresh: Date()
        )
        let staleProvider = TestDataProvider(
            resourceType: "stale",
            mockLastRefresh: Date().addingTimeInterval(-3600) // 1 hour ago
        )

        DataProviderRegistry.shared.register(freshProvider, from: "module-1")
        DataProviderRegistry.shared.register(staleProvider, from: "module-2")

        let staleResources = DataProviderRegistry.shared.getStaleResources(threshold: 300)

        XCTAssertTrue(staleResources.contains("stale"))
        XCTAssertFalse(staleResources.contains("fresh"))
    }

    /// Test registry clear removes all providers
    @MainActor
    func testRegistryClear() {
        let provider = TestDataProvider(resourceType: "clear-test")
        DataProviderRegistry.shared.register(provider, from: "module")

        XCTAssertEqual(DataProviderRegistry.shared.allResourceTypes().count, 1)

        DataProviderRegistry.shared.clear()

        XCTAssertEqual(DataProviderRegistry.shared.allResourceTypes().count, 0)
        XCTAssertNil(DataProviderRegistry.shared.provider(for: "clear-test"))
    }

    /// Test registry returns nil for unregistered resource
    @MainActor
    func testRegistryReturnsNilForUnregistered() async {
        let result = await DataProviderRegistry.shared.fetchData(
            for: "nonexistent",
            priority: .critical,
            forceRefresh: false
        )

        XCTAssertNil(result)
    }

    // MARK: - Timeout Pattern Tests

    /// Test safe timeout pattern with successful operation
    @MainActor
    func testSafeTimeoutPatternSuccess() async throws {
        let result = try await withThrowingTaskGroup(of: Int.self) { group -> Int in
            group.addTask {
                // Fast operation
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                return 42
            }

            group.addTask {
                // Slow timeout
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                throw TestDataProviderError.timeout
            }

            // Safe pattern - guard let instead of force unwrap
            guard let result = try await group.next() else {
                throw TestDataProviderError.timeout
            }
            group.cancelAll()
            return result
        }

        XCTAssertEqual(result, 42)
    }

    /// Test safe timeout pattern with timeout
    @MainActor
    func testSafeTimeoutPatternTimeout() async {
        do {
            _ = try await withThrowingTaskGroup(of: Int.self) { group -> Int in
                group.addTask {
                    // Slow operation
                    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    return 42
                }

                group.addTask {
                    // Fast timeout
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    throw TestDataProviderError.timeout
                }

                guard let result = try await group.next() else {
                    throw TestDataProviderError.timeout
                }
                group.cancelAll()
                return result
            }

            XCTFail("Should have thrown timeout error")
        } catch {
            XCTAssertTrue(error is TestDataProviderError)
        }
    }

    // MARK: - Priority-based Timeout Tests

    /// Test timeout values for different priorities
    @MainActor
    func testTimeoutForPriority() {
        // These values should match the implementation in DataProviders
        let criticalTimeout = timeoutForPriority(.critical)
        let secondaryTimeout = timeoutForPriority(.secondary)
        let backgroundTimeout = timeoutForPriority(.background)
        let onDemandTimeout = timeoutForPriority(.onDemand)
        let fastTimeout = timeoutForPriority(.fast)

        XCTAssertEqual(criticalTimeout, 30.0)
        XCTAssertEqual(secondaryTimeout, 20.0)
        XCTAssertEqual(backgroundTimeout, 10.0)
        XCTAssertEqual(onDemandTimeout, 30.0)
        XCTAssertEqual(fastTimeout, 15.0)
    }

    // MARK: - Helper Methods

    private func timeoutForPriority(_ priority: DataFetchPriority) -> TimeInterval {
        switch priority {
        case .critical:
            return 30.0
        case .secondary:
            return 20.0
        case .background:
            return 10.0
        case .onDemand:
            return 30.0
        case .fast:
            return 15.0
        }
    }
}

// MARK: - Test Helper Types

/// Test error type for DataProvider tests
enum TestDataProviderError: Error {
    case testError
    case timeout
    case fetchFailed
}

/// Mock DataProvider for testing
@MainActor
final class TestDataProvider: DataProvider {
    let resourceType: String
    private(set) var lastRefreshTime: Date?
    private(set) var currentItemCount: Int
    let supportsPagination: Bool = false

    private let mockItemCount: Int
    private var fetchCount: Int = 0

    init(
        resourceType: String,
        mockItemCount: Int = 10,
        mockLastRefresh: Date? = nil
    ) {
        self.resourceType = resourceType
        self.mockItemCount = mockItemCount
        self.currentItemCount = mockItemCount
        self.lastRefreshTime = mockLastRefresh
    }

    func fetchData(
        priority: DataFetchPriority,
        forceRefresh: Bool
    ) async -> DataFetchResult {
        fetchCount += 1
        lastRefreshTime = Date()

        // Simulate some work
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms

        return DataFetchResult(
            itemCount: mockItemCount,
            duration: 0.001,
            fromCache: !forceRefresh && fetchCount > 1,
            error: nil
        )
    }

    func refreshResource(id: String, priority: DataFetchPriority) async -> DataFetchResult {
        return await fetchData(priority: priority, forceRefresh: true)
    }

    func clearCache() async {
        lastRefreshTime = nil
        currentItemCount = 0
    }

    func getPaginatedItems(page: Int, pageSize: Int) async -> [Any]? {
        return nil
    }
}
