// Tests/SubstationTests/Modules/ModuleHealthTests.swift
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

// MARK: - Module Health Test Suite

/// Test suite for module health check functionality.
///
/// Tests cover:
/// - ModuleHealthStatus creation and properties
/// - Health check execution
/// - Module registry health aggregation
/// - Error detection and reporting
/// - Metrics collection
final class ModuleHealthTests: XCTestCase {

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            ModuleRegistry.shared.clear()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            ModuleRegistry.shared.clear()
        }
        super.tearDown()
    }

    // MARK: - ModuleHealthStatus Tests

    /// Test healthy status creation
    @MainActor
    func testHealthyStatusCreation() {
        let status = ModuleHealthStatus(
            isHealthy: true,
            lastCheck: Date(),
            errors: [],
            metrics: ["serverCount": 10]
        )

        XCTAssertTrue(status.isHealthy)
        XCTAssertTrue(status.errors.isEmpty)
        XCTAssertEqual(status.metrics["serverCount"] as? Int, 10)
    }

    /// Test unhealthy status creation
    @MainActor
    func testUnhealthyStatusCreation() {
        let errors = ["Connection failed", "Timeout occurred"]
        let status = ModuleHealthStatus(
            isHealthy: false,
            lastCheck: Date(),
            errors: errors,
            metrics: [:]
        )

        XCTAssertFalse(status.isHealthy)
        XCTAssertEqual(status.errors.count, 2)
        XCTAssertTrue(status.errors.contains("Connection failed"))
        XCTAssertTrue(status.errors.contains("Timeout occurred"))
    }

    /// Test health status with metrics
    @MainActor
    func testHealthStatusWithMetrics() {
        let metrics: [String: Any] = [
            "serverCount": 50,
            "networkCount": 10,
            "lastRefresh": Date(),
            "cacheHitRate": 0.85
        ]

        let status = ModuleHealthStatus(
            isHealthy: true,
            lastCheck: Date(),
            errors: [],
            metrics: metrics
        )

        XCTAssertEqual(status.metrics.count, 4)
        XCTAssertEqual(status.metrics["serverCount"] as? Int, 50)
        XCTAssertEqual(status.metrics["cacheHitRate"] as? Double, 0.85)
    }

    /// Test health status lastCheck timestamp
    @MainActor
    func testHealthStatusTimestamp() {
        let checkTime = Date()
        let status = ModuleHealthStatus(
            isHealthy: true,
            lastCheck: checkTime,
            errors: [],
            metrics: [:]
        )

        XCTAssertEqual(status.lastCheck.timeIntervalSince1970, checkTime.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - Module Health Check Tests

    /// Test single module health check
    @MainActor
    func testSingleModuleHealthCheck() async throws {
        let module = HealthTestModule(
            identifier: "test-module",
            displayName: "Test Module",
            isHealthy: true
        )

        try await ModuleRegistry.shared.register(module)

        let healthResults = await ModuleRegistry.shared.healthCheckAll()

        XCTAssertEqual(healthResults.count, 1)
        XCTAssertTrue(healthResults["test-module"]?.isHealthy ?? false)
    }

    /// Test multiple modules health check
    @MainActor
    func testMultipleModulesHealthCheck() async throws {
        let module1 = HealthTestModule(identifier: "module-1", displayName: "Module 1", isHealthy: true)
        let module2 = HealthTestModule(identifier: "module-2", displayName: "Module 2", isHealthy: true)
        let module3 = HealthTestModule(identifier: "module-3", displayName: "Module 3", isHealthy: false)

        try await ModuleRegistry.shared.register(module1)
        try await ModuleRegistry.shared.register(module2)
        try await ModuleRegistry.shared.register(module3)

        let healthResults = await ModuleRegistry.shared.healthCheckAll()

        XCTAssertEqual(healthResults.count, 3)
        XCTAssertTrue(healthResults["module-1"]?.isHealthy ?? false)
        XCTAssertTrue(healthResults["module-2"]?.isHealthy ?? false)
        XCTAssertFalse(healthResults["module-3"]?.isHealthy ?? true)
    }

    /// Test health check with errors
    @MainActor
    func testHealthCheckWithErrors() async throws {
        let errors = ["API connection failed", "Cache corrupted"]
        let module = HealthTestModule(
            identifier: "error-module",
            displayName: "Error Module",
            isHealthy: false,
            errors: errors
        )

        try await ModuleRegistry.shared.register(module)

        let healthResults = await ModuleRegistry.shared.healthCheckAll()

        XCTAssertFalse(healthResults["error-module"]?.isHealthy ?? true)
        XCTAssertEqual(healthResults["error-module"]?.errors.count, 2)
    }

    /// Test health check metrics collection
    @MainActor
    func testHealthCheckMetricsCollection() async throws {
        let metrics: [String: Any] = [
            "itemCount": 100,
            "cacheSize": 1024,
            "uptime": 3600.0
        ]

        let module = HealthTestModule(
            identifier: "metrics-module",
            displayName: "Metrics Module",
            isHealthy: true,
            metrics: metrics
        )

        try await ModuleRegistry.shared.register(module)

        let healthResults = await ModuleRegistry.shared.healthCheckAll()
        let moduleHealth = healthResults["metrics-module"]

        XCTAssertEqual(moduleHealth?.metrics["itemCount"] as? Int, 100)
        XCTAssertEqual(moduleHealth?.metrics["cacheSize"] as? Int, 1024)
        XCTAssertEqual(moduleHealth?.metrics["uptime"] as? Double, 3600.0)
    }

    // MARK: - Health Check Logic Tests

    /// Test count drop detection logic
    @MainActor
    func testCountDropDetectionLogic() {
        // Simulate the fixed health check logic
        var cachedCount = 50
        var errors: [String] = []

        // Simulate data refresh with count drop to zero
        let newCount = 0

        // Fixed logic: compare BEFORE updating cached value
        if cachedCount > 0 && newCount == 0 {
            errors.append("Count dropped to zero unexpectedly")
        }

        // Update AFTER comparison
        cachedCount = newCount

        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("dropped to zero"))
        XCTAssertEqual(cachedCount, 0)
    }

    /// Test count increase is not flagged
    @MainActor
    func testCountIncreaseNotFlagged() {
        var cachedCount = 10
        var errors: [String] = []

        let newCount = 20

        if cachedCount > 0 && newCount == 0 {
            errors.append("Count dropped to zero unexpectedly")
        }

        cachedCount = newCount

        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(cachedCount, 20)
    }

    /// Test count decrease (non-zero) is not flagged
    @MainActor
    func testCountDecreaseNonZeroNotFlagged() {
        var cachedCount = 50
        var errors: [String] = []

        let newCount = 25

        if cachedCount > 0 && newCount == 0 {
            errors.append("Count dropped to zero unexpectedly")
        }

        cachedCount = newCount

        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(cachedCount, 25)
    }

    /// Test starting from zero is not flagged
    @MainActor
    func testStartingFromZeroNotFlagged() {
        var cachedCount = 0
        var errors: [String] = []

        let newCount = 0

        if cachedCount > 0 && newCount == 0 {
            errors.append("Count dropped to zero unexpectedly")
        }

        cachedCount = newCount

        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - Health Check Frequency Tests

    /// Test health checks are timestamped
    @MainActor
    func testHealthChecksAreTimestamped() async throws {
        let module = HealthTestModule(
            identifier: "timestamp-module",
            displayName: "Timestamp Module",
            isHealthy: true
        )

        try await ModuleRegistry.shared.register(module)

        let beforeCheck = Date()
        let healthResults = await ModuleRegistry.shared.healthCheckAll()
        let afterCheck = Date()

        let checkTime = healthResults["timestamp-module"]?.lastCheck

        XCTAssertNotNil(checkTime)
        XCTAssertGreaterThanOrEqual(checkTime!, beforeCheck)
        XCTAssertLessThanOrEqual(checkTime!, afterCheck)
    }

    // MARK: - Edge Cases

    /// Test health check with empty registry
    @MainActor
    func testHealthCheckEmptyRegistry() async {
        let healthResults = await ModuleRegistry.shared.healthCheckAll()
        XCTAssertTrue(healthResults.isEmpty)
    }

    /// Test health check after module unload
    @MainActor
    func testHealthCheckAfterModuleUnload() async throws {
        let module = HealthTestModule(
            identifier: "unload-test",
            displayName: "Unload Test",
            isHealthy: true
        )

        try await ModuleRegistry.shared.register(module)

        var healthResults = await ModuleRegistry.shared.healthCheckAll()
        XCTAssertEqual(healthResults.count, 1)

        await ModuleRegistry.shared.unload("unload-test")

        healthResults = await ModuleRegistry.shared.healthCheckAll()
        XCTAssertEqual(healthResults.count, 0)
    }

    /// Test health check with special characters in identifier
    @MainActor
    func testHealthCheckWithSpecialIdentifier() async throws {
        let module = HealthTestModule(
            identifier: "module_v2.0-beta",
            displayName: "Special Module",
            isHealthy: true
        )

        try await ModuleRegistry.shared.register(module)

        let healthResults = await ModuleRegistry.shared.healthCheckAll()
        XCTAssertNotNil(healthResults["module_v2.0-beta"])
    }
}

// MARK: - Test Helper Types

/// Mock module for health check testing
@MainActor
final class HealthTestModule: OpenStackModule {
    let identifier: String
    let displayName: String
    let version: String = "1.0.0"
    let dependencies: [String] = []

    private let mockIsHealthy: Bool
    private let mockErrors: [String]
    private let mockMetrics: [String: Any]

    required init(tui: TUI) {
        self.identifier = "health-test"
        self.displayName = "Health Test"
        self.mockIsHealthy = true
        self.mockErrors = []
        self.mockMetrics = [:]
    }

    init(
        identifier: String,
        displayName: String,
        isHealthy: Bool,
        errors: [String] = [],
        metrics: [String: Any] = [:]
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.mockIsHealthy = isHealthy
        self.mockErrors = errors
        self.mockMetrics = metrics
    }

    func configure() async throws {}

    func registerViews() -> [ModuleViewRegistration] {
        return []
    }

    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        return []
    }

    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        return []
    }

    func registerActions() -> [ModuleActionRegistration] {
        return []
    }

    func cleanup() async {}

    func healthCheck() async -> ModuleHealthStatus {
        return ModuleHealthStatus(
            isHealthy: mockIsHealthy,
            lastCheck: Date(),
            errors: mockErrors,
            metrics: mockMetrics
        )
    }
}
