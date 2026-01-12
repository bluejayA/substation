// Tests/SubstationTests/Modules/FormRegistryTests.swift
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

// MARK: - FormRegistry Test Suite

/// Test suite for FormRegistry functionality.
///
/// Tests cover:
/// - Form handler registration
/// - Form handler retrieval
/// - Form validation
/// - Multiple form registrations
final class FormRegistryTests: XCTestCase {

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            FormRegistry.shared.clear()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            FormRegistry.shared.clear()
        }
        super.tearDown()
    }

    // MARK: - Registration Tests

    /// Test basic form handler registration
    @MainActor
    func testFormHandlerRegistration() {
        let registration = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration)

        let handler = FormRegistry.shared.handler(for: .serverCreate)
        XCTAssertNotNil(handler)
    }

    /// Test multiple form handler registrations
    @MainActor
    func testMultipleFormHandlerRegistrations() {
        let registration1 = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        let registration2 = ModuleFormHandlerRegistration(
            viewMode: .networkCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        let registration3 = ModuleFormHandlerRegistration(
            viewMode: .volumeCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration1)
        FormRegistry.shared.register(registration2)
        FormRegistry.shared.register(registration3)

        XCTAssertNotNil(FormRegistry.shared.handler(for: .serverCreate))
        XCTAssertNotNil(FormRegistry.shared.handler(for: .networkCreate))
        XCTAssertNotNil(FormRegistry.shared.handler(for: .volumeCreate))
    }

    /// Test overwriting existing registration
    @MainActor
    func testOverwritingExistingRegistration() {
        let registration1 = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        let registration2 = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration1)
        FormRegistry.shared.register(registration2)

        // Second registration should overwrite first
        let handler = FormRegistry.shared.handler(for: .serverCreate)
        XCTAssertNotNil(handler)
    }

    // MARK: - Retrieval Tests

    /// Test handler retrieval for registered view mode
    @MainActor
    func testHandlerRetrievalForRegistered() {
        let registration = ModuleFormHandlerRegistration(
            viewMode: .networkCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration)

        let handler = FormRegistry.shared.handler(for: .networkCreate)
        XCTAssertNotNil(handler)
    }

    /// Test handler retrieval returns nil for unregistered
    @MainActor
    func testHandlerRetrievalReturnsNilForUnregistered() {
        let handler = FormRegistry.shared.handler(for: .serverCreate)
        XCTAssertNil(handler)
    }

    /// Test all registrations retrieval
    @MainActor
    func testAllRegistrationsRetrieval() {
        let registration1 = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        let registration2 = ModuleFormHandlerRegistration(
            viewMode: .networkCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration1)
        FormRegistry.shared.register(registration2)

        let allRegistrations = FormRegistry.shared.allRegistrations()
        XCTAssertEqual(allRegistrations.count, 2)
    }

    // MARK: - Validation Tests

    /// Test form validation returns true
    @MainActor
    func testFormValidationReturnsTrue() {
        let registration = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration)

        let handler = FormRegistry.shared.handler(for: .serverCreate)
        XCTAssertTrue(handler?.formValidation() ?? false)
    }

    /// Test form validation returns false
    @MainActor
    func testFormValidationReturnsFalse() {
        let registration = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { false }
        )

        FormRegistry.shared.register(registration)

        let handler = FormRegistry.shared.handler(for: .serverCreate)
        XCTAssertFalse(handler?.formValidation() ?? true)
    }

    /// Test form validation with conditional logic
    @MainActor
    func testFormValidationWithConditionalLogic() {
        var isValid = false

        let registration = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { isValid }
        )

        FormRegistry.shared.register(registration)

        let handler = FormRegistry.shared.handler(for: .serverCreate)

        // Initially false
        XCTAssertFalse(handler?.formValidation() ?? true)

        // Change to true
        isValid = true
        XCTAssertTrue(handler?.formValidation() ?? false)
    }

    // MARK: - Clear Tests

    /// Test clear removes all registrations
    @MainActor
    func testClearRemovesAllRegistrations() {
        let registration1 = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        let registration2 = ModuleFormHandlerRegistration(
            viewMode: .networkCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration1)
        FormRegistry.shared.register(registration2)

        XCTAssertEqual(FormRegistry.shared.allRegistrations().count, 2)

        FormRegistry.shared.clear()

        XCTAssertEqual(FormRegistry.shared.allRegistrations().count, 0)
        XCTAssertNil(FormRegistry.shared.handler(for: .serverCreate))
        XCTAssertNil(FormRegistry.shared.handler(for: .networkCreate))
    }

    // MARK: - View Mode Tests

    /// Test registration with different view modes
    @MainActor
    func testRegistrationWithDifferentViewModes() {
        let viewModes: [ViewMode] = [
            .serverCreate,
            .networkCreate,
            .volumeCreate,
            .imageCreate,
            .keyPairCreate
        ]

        for viewMode in viewModes {
            let registration = ModuleFormHandlerRegistration(
                viewMode: viewMode,
                handler: { _, _ in },
                formValidation: { true }
            )
            FormRegistry.shared.register(registration)
        }

        for viewMode in viewModes {
            XCTAssertNotNil(
                FormRegistry.shared.handler(for: viewMode),
                "Should have handler for \(viewMode)"
            )
        }
    }
}

// MARK: - DataRefreshRegistry Tests

/// Test suite for DataRefreshRegistry functionality.
final class DataRefreshRegistryTests: XCTestCase {

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            DataRefreshRegistry.shared.clear()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            DataRefreshRegistry.shared.clear()
        }
        super.tearDown()
    }

    // MARK: - Registration Tests

    /// Test refresh handler registration
    @MainActor
    func testRefreshHandlerRegistration() {
        let registration = ModuleDataRefreshRegistration(
            identifier: "servers-refresh",
            refreshHandler: { },
            cacheKey: "servers",
            refreshInterval: 30
        )

        DataRefreshRegistry.shared.register(registration)

        let handler = DataRefreshRegistry.shared.handler(for: "servers-refresh")
        XCTAssertNotNil(handler)
    }

    /// Test multiple refresh handler registrations
    @MainActor
    func testMultipleRefreshHandlerRegistrations() {
        let registrations = [
            ModuleDataRefreshRegistration(
                identifier: "servers-refresh",
                refreshHandler: { },
                cacheKey: "servers",
                refreshInterval: 30
            ),
            ModuleDataRefreshRegistration(
                identifier: "networks-refresh",
                refreshHandler: { },
                cacheKey: "networks",
                refreshInterval: 60
            ),
            ModuleDataRefreshRegistration(
                identifier: "volumes-refresh",
                refreshHandler: { },
                cacheKey: "volumes",
                refreshInterval: 45
            )
        ]

        for registration in registrations {
            DataRefreshRegistry.shared.register(registration)
        }

        XCTAssertNotNil(DataRefreshRegistry.shared.handler(for: "servers-refresh"))
        XCTAssertNotNil(DataRefreshRegistry.shared.handler(for: "networks-refresh"))
        XCTAssertNotNil(DataRefreshRegistry.shared.handler(for: "volumes-refresh"))
    }

    // MARK: - Retrieval Tests

    /// Test handler retrieval for registered identifier
    @MainActor
    func testHandlerRetrievalForRegistered() {
        let registration = ModuleDataRefreshRegistration(
            identifier: "test-refresh",
            refreshHandler: { },
            cacheKey: "test",
            refreshInterval: 30
        )

        DataRefreshRegistry.shared.register(registration)

        XCTAssertNotNil(DataRefreshRegistry.shared.handler(for: "test-refresh"))
    }

    /// Test handler retrieval returns nil for unregistered
    @MainActor
    func testHandlerRetrievalReturnsNilForUnregistered() {
        XCTAssertNil(DataRefreshRegistry.shared.handler(for: "nonexistent"))
    }

    // MARK: - Clear Tests

    /// Test clear removes all handlers
    @MainActor
    func testClearRemovesAllHandlers() {
        let registration = ModuleDataRefreshRegistration(
            identifier: "clear-test",
            refreshHandler: { },
            cacheKey: nil,
            refreshInterval: nil
        )

        DataRefreshRegistry.shared.register(registration)
        XCTAssertNotNil(DataRefreshRegistry.shared.handler(for: "clear-test"))

        DataRefreshRegistry.shared.clear()
        XCTAssertNil(DataRefreshRegistry.shared.handler(for: "clear-test"))
    }

    // MARK: - Refresh Handler Tests

    /// Test refresh handler execution
    @MainActor
    func testRefreshHandlerExecution() async throws {
        var handlerExecuted = false

        let registration = ModuleDataRefreshRegistration(
            identifier: "execution-test",
            refreshHandler: {
                handlerExecuted = true
            },
            cacheKey: "test",
            refreshInterval: 30
        )

        DataRefreshRegistry.shared.register(registration)

        let handler = DataRefreshRegistry.shared.handler(for: "execution-test")
        try await handler?.refreshHandler()

        XCTAssertTrue(handlerExecuted)
    }

    /// Test refresh interval is stored correctly
    @MainActor
    func testRefreshIntervalStored() {
        let registration = ModuleDataRefreshRegistration(
            identifier: "interval-test",
            refreshHandler: { },
            cacheKey: "test",
            refreshInterval: 45
        )

        DataRefreshRegistry.shared.register(registration)

        let handler = DataRefreshRegistry.shared.handler(for: "interval-test")
        XCTAssertEqual(handler?.refreshInterval, 45)
    }

    /// Test cache key is stored correctly
    @MainActor
    func testCacheKeyStored() {
        let registration = ModuleDataRefreshRegistration(
            identifier: "cache-key-test",
            refreshHandler: { },
            cacheKey: "my-cache-key",
            refreshInterval: 30
        )

        DataRefreshRegistry.shared.register(registration)

        let handler = DataRefreshRegistry.shared.handler(for: "cache-key-test")
        XCTAssertEqual(handler?.cacheKey, "my-cache-key")
    }

    /// Test nil cache key and refresh interval
    @MainActor
    func testNilOptionalFields() {
        let registration = ModuleDataRefreshRegistration(
            identifier: "nil-test",
            refreshHandler: { },
            cacheKey: nil,
            refreshInterval: nil
        )

        DataRefreshRegistry.shared.register(registration)

        let handler = DataRefreshRegistry.shared.handler(for: "nil-test")
        XCTAssertNotNil(handler)
        XCTAssertNil(handler?.cacheKey)
        XCTAssertNil(handler?.refreshInterval)
    }
}
