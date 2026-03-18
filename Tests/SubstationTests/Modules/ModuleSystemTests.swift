// Tests/SubstationTests/Modules/ModuleSystemTests.swift
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

// MARK: - Module System Test Suite

/// Comprehensive test suite for the Substation module system.
///
/// This test suite validates all core components of the module architecture including:
/// - ModuleCatalog: Static module metadata and dependency ordering
/// - ModuleRegistry: Dynamic module loading and lifecycle management
/// - FeatureFlags: Module system configuration
/// - DataProviderRegistry: Centralized data fetching infrastructure
/// - ActionProviderRegistry: Action handler registration and lookup
/// - ViewRegistry: View handler registration and retrieval
/// - FormRegistry: Form handler registration
/// - DataRefreshRegistry: Refresh handler management
/// - ActionRegistry: Action execution and keybinding management
final class ModuleSystemTests: XCTestCase {

    // MARK: - Setup and Teardown

    /// Clear all registries - assumes running on main thread
    @MainActor
    private static func clearRegistriesMainActor() {
        ViewRegistry.shared.clear()
        FormRegistry.shared.clear()
        DataRefreshRegistry.shared.clear()
        ActionRegistry.shared.clear()
        DataProviderRegistry.shared.clear()
        ActionProviderRegistry.shared.clearAll()
        ModuleRegistry.shared.clear()
    }

    /// Clear registries before each test
    override func setUp() {
        super.setUp()
        // XCTest runs on main thread, so we can use assumeIsolated
        MainActor.assumeIsolated {
            Self.clearRegistriesMainActor()
        }
    }

    /// Clear registries after each test
    override func tearDown() {
        MainActor.assumeIsolated {
            Self.clearRegistriesMainActor()
        }
        super.tearDown()
    }

    // MARK: - ModuleCatalog Tests

    /// Test that allModuleIdentifiers returns the expected 16 modules
    @MainActor func testModuleCatalogAllModuleIdentifiersCount() {
        let identifiers = ModuleCatalog.allModuleIdentifiers
        XCTAssertEqual(
            identifiers.count,
            16,
            "ModuleCatalog should contain exactly 16 module identifiers"
        )
    }

    /// Test that all expected module identifiers are present
    @MainActor func testModuleCatalogAllModuleIdentifiersContents() {
        let identifiers = ModuleCatalog.allModuleIdentifiers

        let expectedModules = [
            "barbican", "swift", "keypairs", "servergroups", "flavors",
            "images", "securitygroups", "volumes", "networks", "subnets",
            "routers", "floatingips", "ports", "servers", "magnum", "hypervisors"
        ]

        for module in expectedModules {
            XCTAssertTrue(
                identifiers.contains(module),
                "ModuleCatalog should contain '\(module)' module"
            )
        }
    }

    /// Test that modulesByLoadOrder returns modules sorted by dependency phase
    @MainActor func testModuleCatalogModulesByLoadOrder() {
        let orderedModules = ModuleCatalog.modulesByLoadOrder

        XCTAssertEqual(
            orderedModules.count,
            16,
            "modulesByLoadOrder should return all 16 modules"
        )

        // Verify phase ordering
        var lastPhase: ModuleCatalog.LoadPhase = .independent
        for module in orderedModules {
            XCTAssertGreaterThanOrEqual(
                module.phase.rawValue,
                lastPhase.rawValue,
                "Modules should be sorted by load phase: '\(module.identifier)' has phase \(module.phase) but follows phase \(lastPhase)"
            )
            lastPhase = module.phase
        }
    }

    /// Test that independent modules come before dependent modules
    @MainActor func testModuleCatalogDependencyOrdering() {
        let orderedModules = ModuleCatalog.modulesByLoadOrder

        // Find indices of modules
        let networksIndex = orderedModules.firstIndex { $0.identifier == "networks" }
        let subnetsIndex = orderedModules.firstIndex { $0.identifier == "subnets" }
        let serversIndex = orderedModules.firstIndex { $0.identifier == "servers" }
        let imagesIndex = orderedModules.firstIndex { $0.identifier == "images" }

        XCTAssertNotNil(networksIndex, "Networks module should exist")
        XCTAssertNotNil(subnetsIndex, "Subnets module should exist")
        XCTAssertNotNil(serversIndex, "Servers module should exist")
        XCTAssertNotNil(imagesIndex, "Images module should exist")

        // Networks should come before subnets (subnets depends on networks)
        if let netIdx = networksIndex, let subIdx = subnetsIndex {
            XCTAssertLessThan(
                netIdx,
                subIdx,
                "Networks should load before Subnets"
            )
        }

        // Images should come before servers (servers depends on images)
        if let imgIdx = imagesIndex, let srvIdx = serversIndex {
            XCTAssertLessThan(
                imgIdx,
                srvIdx,
                "Images should load before Servers"
            )
        }
    }

    /// Test definition(for:) returns correct metadata for known modules
    @MainActor func testModuleCatalogDefinitionForKnownModule() {
        let serversDefinition = ModuleCatalog.definition(for: "servers")

        XCTAssertNotNil(serversDefinition, "Should return definition for 'servers'")
        XCTAssertEqual(serversDefinition?.identifier, "servers")
        XCTAssertEqual(serversDefinition?.displayName, "Servers")
        XCTAssertEqual(serversDefinition?.phase, .multiDependent)
        XCTAssertTrue(
            serversDefinition?.dependencies.contains("networks") ?? false,
            "Servers should depend on networks"
        )
        XCTAssertTrue(
            serversDefinition?.dependencies.contains("images") ?? false,
            "Servers should depend on images"
        )
    }

    /// Test definition(for:) returns nil for unknown modules
    @MainActor func testModuleCatalogDefinitionForUnknownModule() {
        let unknownDefinition = ModuleCatalog.definition(for: "nonexistent")
        XCTAssertNil(unknownDefinition, "Should return nil for unknown module identifier")
    }

    /// Test moduleCount returns correct count
    @MainActor func testModuleCatalogModuleCount() {
        XCTAssertEqual(
            ModuleCatalog.moduleCount,
            16,
            "moduleCount should return 16"
        )
    }

    /// Test that all module definitions have valid metadata
    @MainActor func testModuleCatalogDefinitionValidity() {
        for definition in ModuleCatalog.availableModules {
            XCTAssertFalse(
                definition.identifier.isEmpty,
                "Module identifier should not be empty"
            )
            XCTAssertFalse(
                definition.displayName.isEmpty,
                "Module displayName should not be empty"
            )

            // Verify dependencies reference existing modules
            for dependency in definition.dependencies {
                XCTAssertTrue(
                    ModuleCatalog.allModuleIdentifiers.contains(dependency),
                    "Module '\(definition.identifier)' has unknown dependency '\(dependency)'"
                )
            }
        }
    }

    // MARK: - ModuleRegistry Tests

    /// Test module registration via register(_:)
    @MainActor func testModuleRegistryRegisterModule() async throws {
        let mockModule = MockOpenStackModule(
            identifier: "test-module",
            displayName: "Test Module",
            dependencies: []
        )

        try await ModuleRegistry.shared.register(mockModule)

        let retrieved = ModuleRegistry.shared.module(for: "test-module")
        XCTAssertNotNil(retrieved, "Registered module should be retrievable")
        XCTAssertEqual(retrieved?.identifier, "test-module")
    }

    /// Test dependency validation rejects modules with missing dependencies
    @MainActor func testModuleRegistryRejectsMissingDependencies() async {
        let moduleWithMissingDep = MockOpenStackModule(
            identifier: "dependent-module",
            displayName: "Dependent Module",
            dependencies: ["nonexistent-dependency"]
        )

        do {
            try await ModuleRegistry.shared.register(moduleWithMissingDep)
            XCTFail("Should throw error for missing dependency")
        } catch {
            XCTAssertTrue(
                error is ModuleError,
                "Should throw ModuleError for missing dependency"
            )
            if case ModuleError.missingDependency(let message) = error {
                XCTAssertTrue(
                    message.contains("nonexistent-dependency"),
                    "Error message should mention missing dependency"
                )
            }
        }
    }

    /// Test module(for:) retrieval
    @MainActor func testModuleRegistryModuleRetrieval() async throws {
        let module1 = MockOpenStackModule(
            identifier: "module-1",
            displayName: "Module One",
            dependencies: []
        )
        let module2 = MockOpenStackModule(
            identifier: "module-2",
            displayName: "Module Two",
            dependencies: []
        )

        try await ModuleRegistry.shared.register(module1)
        try await ModuleRegistry.shared.register(module2)

        let retrieved1 = ModuleRegistry.shared.module(for: "module-1")
        let retrieved2 = ModuleRegistry.shared.module(for: "module-2")
        let retrievedNil = ModuleRegistry.shared.module(for: "nonexistent")

        XCTAssertNotNil(retrieved1)
        XCTAssertNotNil(retrieved2)
        XCTAssertNil(retrievedNil)
        XCTAssertEqual(retrieved1?.identifier, "module-1")
        XCTAssertEqual(retrieved2?.identifier, "module-2")
    }

    /// Test allModules() returns all loaded modules in order
    @MainActor func testModuleRegistryAllModules() async throws {
        let module1 = MockOpenStackModule(
            identifier: "first",
            displayName: "First",
            dependencies: []
        )
        let module2 = MockOpenStackModule(
            identifier: "second",
            displayName: "Second",
            dependencies: []
        )

        try await ModuleRegistry.shared.register(module1)
        try await ModuleRegistry.shared.register(module2)

        let allModules = ModuleRegistry.shared.allModules()
        XCTAssertEqual(allModules.count, 2, "Should return 2 modules")
        XCTAssertEqual(allModules[0].identifier, "first", "Should maintain load order")
        XCTAssertEqual(allModules[1].identifier, "second", "Should maintain load order")
    }

    /// Test unload(_:) properly removes modules
    @MainActor func testModuleRegistryUnload() async throws {
        let module = MockOpenStackModule(
            identifier: "unload-test",
            displayName: "Unload Test",
            dependencies: []
        )

        try await ModuleRegistry.shared.register(module)
        XCTAssertNotNil(ModuleRegistry.shared.module(for: "unload-test"))

        await ModuleRegistry.shared.unload("unload-test")

        XCTAssertNil(
            ModuleRegistry.shared.module(for: "unload-test"),
            "Module should be removed after unload"
        )
        XCTAssertTrue(
            module.cleanupCalled,
            "Cleanup should be called on unload"
        )
    }

    /// Test healthCheckAll() aggregates all module health
    @MainActor func testModuleRegistryHealthCheckAll() async throws {
        let healthyModule = MockOpenStackModule(
            identifier: "healthy",
            displayName: "Healthy",
            dependencies: [],
            isHealthy: true
        )
        let unhealthyModule = MockOpenStackModule(
            identifier: "unhealthy",
            displayName: "Unhealthy",
            dependencies: [],
            isHealthy: false
        )

        try await ModuleRegistry.shared.register(healthyModule)
        try await ModuleRegistry.shared.register(unhealthyModule)

        let healthResults = await ModuleRegistry.shared.healthCheckAll()

        XCTAssertEqual(healthResults.count, 2, "Should return health for 2 modules")
        XCTAssertTrue(
            healthResults["healthy"]?.isHealthy ?? false,
            "Healthy module should report healthy"
        )
        XCTAssertFalse(
            healthResults["unhealthy"]?.isHealthy ?? true,
            "Unhealthy module should report unhealthy"
        )
    }

    /// Test clear() removes all modules
    @MainActor func testModuleRegistryClear() async throws {
        let module = MockOpenStackModule(
            identifier: "clear-test",
            displayName: "Clear Test",
            dependencies: []
        )

        try await ModuleRegistry.shared.register(module)
        XCTAssertEqual(ModuleRegistry.shared.allModules().count, 1)

        ModuleRegistry.shared.clear()

        XCTAssertEqual(
            ModuleRegistry.shared.allModules().count,
            0,
            "All modules should be cleared"
        )
    }

    // MARK: - FeatureFlags Tests

    /// Test useModuleSystem default value
    @MainActor func testFeatureFlagsUseModuleSystemDefault() {
        // In DEBUG mode without env var, should default to true
        XCTAssertTrue(
            FeatureFlags.useModuleSystem,
            "useModuleSystem should default to true"
        )
    }

    /// Test enabledModules defaults to catalog modules minus disabledByDefault
    @MainActor func testFeatureFlagsEnabledModulesDefault() {
        let enabledModules = FeatureFlags.enabledModules
        let expectedModules = ModuleCatalog.defaultEnabledModuleIdentifiers

        XCTAssertEqual(
            enabledModules,
            expectedModules,
            "enabledModules should default to defaultEnabledModuleIdentifiers"
        )
    }

    /// Test that swift is excluded from default enabled modules
    @MainActor func testFeatureFlagsExcludesSwiftByDefault() {
        XCTAssertFalse(
            FeatureFlags.enabledModules.contains("swift"),
            "Swift module should not be in default enabled modules"
        )
    }

    // MARK: - DataProviderRegistry Tests

    /// Test provider registration
    @MainActor func testDataProviderRegistryRegister() async {
        let provider = MockDataProvider(resourceType: "test-resource")

        DataProviderRegistry.shared.register(provider, from: "test-module")

        let retrieved = DataProviderRegistry.shared.provider(for: "test-resource")
        XCTAssertNotNil(retrieved, "Provider should be retrievable after registration")
        XCTAssertEqual(retrieved?.resourceType, "test-resource")
    }

    /// Test fetchData(for:priority:forceRefresh:)
    @MainActor func testDataProviderRegistryFetchData() async {
        let provider = MockDataProvider(resourceType: "fetch-test", itemCount: 42)
        DataProviderRegistry.shared.register(provider, from: "test-module")

        let result = await DataProviderRegistry.shared.fetchData(
            for: "fetch-test",
            priority: .critical,
            forceRefresh: false
        )

        XCTAssertNotNil(result, "Should return fetch result")
        XCTAssertEqual(result?.itemCount, 42, "Should return correct item count")
        XCTAssertNil(result?.error, "Should not have error")
    }

    /// Test fetchData returns nil for unregistered resource type
    @MainActor func testDataProviderRegistryFetchDataUnregistered() async {
        let result = await DataProviderRegistry.shared.fetchData(
            for: "nonexistent",
            priority: .critical,
            forceRefresh: false
        )

        XCTAssertNil(result, "Should return nil for unregistered resource type")
    }

    /// Test fetchPhase(_:forceRefresh:) for phased loading
    @MainActor func testDataProviderRegistryFetchPhase() async {
        // Register providers for critical resources
        let serversProvider = MockDataProvider(resourceType: "servers", itemCount: 10)
        let networksProvider = MockDataProvider(resourceType: "networks", itemCount: 5)

        DataProviderRegistry.shared.register(serversProvider, from: "servers-module")
        DataProviderRegistry.shared.register(networksProvider, from: "networks-module")

        let results = await DataProviderRegistry.shared.fetchPhase(
            .critical,
            forceRefresh: false
        )

        // Should fetch servers and networks from critical phase
        XCTAssertTrue(
            results.keys.contains("servers") || results.keys.contains("networks"),
            "Should fetch critical phase resources"
        )
    }

    /// Test clearAllCaches clears all providers
    @MainActor func testDataProviderRegistryClearAllCaches() async {
        let provider1 = MockDataProvider(resourceType: "cache-test-1")
        let provider2 = MockDataProvider(resourceType: "cache-test-2")

        DataProviderRegistry.shared.register(provider1, from: "module-1")
        DataProviderRegistry.shared.register(provider2, from: "module-2")

        await DataProviderRegistry.shared.clearAllCaches()

        XCTAssertTrue(provider1.cacheClearedCount > 0, "Provider 1 cache should be cleared")
        XCTAssertTrue(provider2.cacheClearedCount > 0, "Provider 2 cache should be cleared")
    }

    /// Test allResourceTypes returns registered types
    @MainActor func testDataProviderRegistryAllResourceTypes() async {
        let provider1 = MockDataProvider(resourceType: "type-a")
        let provider2 = MockDataProvider(resourceType: "type-b")

        DataProviderRegistry.shared.register(provider1, from: "module-1")
        DataProviderRegistry.shared.register(provider2, from: "module-2")

        let types = DataProviderRegistry.shared.allResourceTypes()

        XCTAssertTrue(types.contains("type-a"), "Should contain type-a")
        XCTAssertTrue(types.contains("type-b"), "Should contain type-b")
    }

    /// Test getStaleResources returns resources needing refresh
    @MainActor func testDataProviderRegistryGetStaleResources() async {
        let freshProvider = MockDataProvider(
            resourceType: "fresh",
            lastRefresh: Date()
        )
        let staleProvider = MockDataProvider(
            resourceType: "stale",
            lastRefresh: Date().addingTimeInterval(-3600) // 1 hour ago
        )

        DataProviderRegistry.shared.register(freshProvider, from: "module-1")
        DataProviderRegistry.shared.register(staleProvider, from: "module-2")

        let staleResources = DataProviderRegistry.shared.getStaleResources(threshold: 300)

        XCTAssertTrue(
            staleResources.contains("stale"),
            "Stale resource should be identified"
        )
        XCTAssertFalse(
            staleResources.contains("fresh"),
            "Fresh resource should not be stale"
        )
    }

    /// Test clear() removes all providers
    @MainActor func testDataProviderRegistryClear() async {
        let provider = MockDataProvider(resourceType: "clear-test")
        DataProviderRegistry.shared.register(provider, from: "module")

        DataProviderRegistry.shared.clear()

        XCTAssertNil(
            DataProviderRegistry.shared.provider(for: "clear-test"),
            "Provider should be removed after clear"
        )
        XCTAssertEqual(
            DataProviderRegistry.shared.allResourceTypes().count,
            0,
            "No resource types should remain"
        )
    }

    // MARK: - ActionProviderRegistry Tests

    /// Test provider registration for list and detail views
    @MainActor func testActionProviderRegistryRegister() async throws {
        let module = MockActionProviderModule(
            identifier: "action-test",
            displayName: "Action Test",
            dependencies: []
        )

        ActionProviderRegistry.shared.register(
            module,
            listViewMode: .servers,
            detailViewMode: .serverDetail
        )

        XCTAssertTrue(
            ActionProviderRegistry.shared.hasProvider(for: .servers),
            "Should have provider for list view"
        )
        XCTAssertTrue(
            ActionProviderRegistry.shared.hasProvider(for: .serverDetail),
            "Should have provider for detail view"
        )
    }

    /// Test provider(for:) retrieval
    @MainActor func testActionProviderRegistryRetrieval() async throws {
        let module = MockActionProviderModule(
            identifier: "retrieval-test",
            displayName: "Retrieval Test",
            dependencies: []
        )

        ActionProviderRegistry.shared.register(
            module,
            listViewMode: .networks,
            detailViewMode: nil
        )

        let provider = ActionProviderRegistry.shared.provider(for: .networks)
        XCTAssertNotNil(provider, "Should retrieve registered provider")
        XCTAssertEqual(provider?.identifier, "retrieval-test")
    }

    /// Test isDetailView correctly identifies detail views
    @MainActor func testActionProviderRegistryIsDetailView() async throws {
        let module = MockActionProviderModule(
            identifier: "detail-test",
            displayName: "Detail Test",
            dependencies: []
        )

        ActionProviderRegistry.shared.register(
            module,
            listViewMode: .volumes,
            detailViewMode: .volumeDetail
        )

        XCTAssertFalse(
            ActionProviderRegistry.shared.isDetailView(.volumes),
            "List view should not be identified as detail view"
        )
        XCTAssertTrue(
            ActionProviderRegistry.shared.isDetailView(.volumeDetail),
            "Detail view should be identified as detail view"
        )
    }

    /// Test allRegisteredViewModes returns all registered modes
    @MainActor func testActionProviderRegistryAllViewModes() async throws {
        let module1 = MockActionProviderModule(
            identifier: "module-1",
            displayName: "Module 1",
            dependencies: []
        )
        let module2 = MockActionProviderModule(
            identifier: "module-2",
            displayName: "Module 2",
            dependencies: []
        )

        ActionProviderRegistry.shared.register(module1, listViewMode: .servers)
        ActionProviderRegistry.shared.register(module2, listViewMode: .networks)

        let viewModes = ActionProviderRegistry.shared.allRegisteredViewModes()

        XCTAssertTrue(viewModes.contains(.servers))
        XCTAssertTrue(viewModes.contains(.networks))
    }

    /// Test clearAll removes all providers
    @MainActor func testActionProviderRegistryClearAll() async throws {
        let module = MockActionProviderModule(
            identifier: "clear-test",
            displayName: "Clear Test",
            dependencies: []
        )

        ActionProviderRegistry.shared.register(module, listViewMode: .servers)
        ActionProviderRegistry.shared.clearAll()

        XCTAssertEqual(
            ActionProviderRegistry.shared.providerCount,
            0,
            "All providers should be cleared"
        )
    }

    // MARK: - ViewRegistry Tests

    /// Test view registration
    @MainActor func testViewRegistryRegister() {
        let registration = ModuleViewRegistration(
            viewMode: .servers,
            title: "Servers",
            renderHandler: { _, _, _, _, _ in },
            inputHandler: nil,
            category: .compute
        )

        ViewRegistry.shared.register(registration)

        let retrieved = ViewRegistry.shared.handler(for: .servers)
        XCTAssertNotNil(retrieved, "Should retrieve registered view")
        XCTAssertEqual(retrieved?.title, "Servers")
    }

    /// Test handler(for:) retrieval
    @MainActor func testViewRegistryHandlerRetrieval() {
        let registration = ModuleViewRegistration(
            viewMode: .networks,
            title: "Networks",
            renderHandler: { _, _, _, _, _ in },
            inputHandler: nil,
            category: .network
        )

        ViewRegistry.shared.register(registration)

        let handler = ViewRegistry.shared.handler(for: .networks)
        XCTAssertNotNil(handler)
        XCTAssertEqual(handler?.category, .network)

        let missingHandler = ViewRegistry.shared.handler(for: .volumes)
        XCTAssertNil(missingHandler, "Should return nil for unregistered view")
    }

    /// Test allRegistrations returns all registered views
    @MainActor func testViewRegistryAllRegistrations() {
        let reg1 = ModuleViewRegistration(
            viewMode: .servers,
            title: "Servers",
            renderHandler: { _, _, _, _, _ in },
            inputHandler: nil,
            category: .compute
        )
        let reg2 = ModuleViewRegistration(
            viewMode: .networks,
            title: "Networks",
            renderHandler: { _, _, _, _, _ in },
            inputHandler: nil,
            category: .network
        )

        ViewRegistry.shared.register(reg1)
        ViewRegistry.shared.register(reg2)

        let all = ViewRegistry.shared.allRegistrations()
        XCTAssertEqual(all.count, 2)
    }

    /// Test registrations(in:) returns views by category
    @MainActor func testViewRegistryRegistrationsByCategory() {
        let computeReg = ModuleViewRegistration(
            viewMode: .servers,
            title: "Servers",
            renderHandler: { _, _, _, _, _ in },
            inputHandler: nil,
            category: .compute
        )
        let networkReg = ModuleViewRegistration(
            viewMode: .networks,
            title: "Networks",
            renderHandler: { _, _, _, _, _ in },
            inputHandler: nil,
            category: .network
        )

        ViewRegistry.shared.register(computeReg)
        ViewRegistry.shared.register(networkReg)

        let computeViews = ViewRegistry.shared.registrations(in: .compute)
        let networkViews = ViewRegistry.shared.registrations(in: .network)

        XCTAssertEqual(computeViews.count, 1)
        XCTAssertEqual(networkViews.count, 1)
        XCTAssertEqual(computeViews.first?.viewMode, .servers)
        XCTAssertEqual(networkViews.first?.viewMode, .networks)
    }

    /// Test clear removes all registrations
    @MainActor func testViewRegistryClear() {
        let registration = ModuleViewRegistration(
            viewMode: .servers,
            title: "Servers",
            renderHandler: { _, _, _, _, _ in },
            inputHandler: nil,
            category: .compute
        )

        ViewRegistry.shared.register(registration)
        ViewRegistry.shared.clear()

        XCTAssertNil(ViewRegistry.shared.handler(for: .servers))
        XCTAssertEqual(ViewRegistry.shared.allRegistrations().count, 0)
    }

    // MARK: - FormRegistry Tests

    /// Test form handler registration
    @MainActor func testFormRegistryRegister() {
        let registration = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration)

        let handler = FormRegistry.shared.handler(for: .serverCreate)
        XCTAssertNotNil(handler)
    }

    /// Test handler retrieval
    @MainActor func testFormRegistryHandlerRetrieval() {
        let registration = ModuleFormHandlerRegistration(
            viewMode: .networkCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration)

        XCTAssertNotNil(FormRegistry.shared.handler(for: .networkCreate))
        XCTAssertNil(FormRegistry.shared.handler(for: .volumeCreate))
    }

    /// Test clear removes all handlers
    @MainActor func testFormRegistryClear() {
        let registration = ModuleFormHandlerRegistration(
            viewMode: .serverCreate,
            handler: { _, _ in },
            formValidation: { true }
        )

        FormRegistry.shared.register(registration)
        FormRegistry.shared.clear()

        XCTAssertNil(FormRegistry.shared.handler(for: .serverCreate))
    }

    // MARK: - DataRefreshRegistry Tests

    /// Test refresh handler registration
    @MainActor func testDataRefreshRegistryRegister() {
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

    /// Test handler retrieval
    @MainActor func testDataRefreshRegistryHandlerRetrieval() {
        let registration = ModuleDataRefreshRegistration(
            identifier: "networks-refresh",
            refreshHandler: { },
            cacheKey: "networks",
            refreshInterval: 60
        )

        DataRefreshRegistry.shared.register(registration)

        XCTAssertNotNil(DataRefreshRegistry.shared.handler(for: "networks-refresh"))
        XCTAssertNil(DataRefreshRegistry.shared.handler(for: "nonexistent"))
    }

    /// Test clear removes all handlers
    @MainActor func testDataRefreshRegistryClear() {
        let registration = ModuleDataRefreshRegistration(
            identifier: "clear-test",
            refreshHandler: { },
            cacheKey: nil,
            refreshInterval: nil
        )

        DataRefreshRegistry.shared.register(registration)
        DataRefreshRegistry.shared.clear()

        XCTAssertNil(DataRefreshRegistry.shared.handler(for: "clear-test"))
    }

    // MARK: - ActionRegistry Tests

    /// Test action registration
    @MainActor func testActionRegistryRegister() {
        let action = ModuleActionRegistration(
            identifier: "server.delete",
            title: "Delete Server",
            keybinding: "d",
            viewModes: [.servers, .serverDetail],
            handler: { _ in },
            description: "Delete the selected server",
            requiresConfirmation: true,
            category: .lifecycle
        )

        ActionRegistry.shared.register(action)

        let retrieved = ActionRegistry.shared.action(for: "server.delete")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Delete Server")
    }

    /// Test actions(for:) by view mode
    @MainActor func testActionRegistryActionsByViewMode() {
        let action1 = ModuleActionRegistration(
            identifier: "action-1",
            title: "Action 1",
            keybinding: nil,
            viewModes: [.servers],
            handler: { _ in }
        )
        let action2 = ModuleActionRegistration(
            identifier: "action-2",
            title: "Action 2",
            keybinding: nil,
            viewModes: [.servers, .networks],
            handler: { _ in }
        )

        ActionRegistry.shared.register(action1)
        ActionRegistry.shared.register(action2)

        let serverActions = ActionRegistry.shared.actions(for: .servers)
        let networkActions = ActionRegistry.shared.actions(for: .networks)

        XCTAssertEqual(serverActions.count, 2, "Servers should have 2 actions")
        XCTAssertEqual(networkActions.count, 1, "Networks should have 1 action")
    }

    /// Test actions(for:in:) by keybinding and view mode
    @MainActor func testActionRegistryActionsByKeybinding() {
        let action = ModuleActionRegistration(
            identifier: "delete-action",
            title: "Delete",
            keybinding: "d",
            viewModes: [.servers],
            handler: { _ in }
        )

        ActionRegistry.shared.register(action)

        let matchingActions = ActionRegistry.shared.actions(for: "d", in: .servers)
        let nonMatchingActions = ActionRegistry.shared.actions(for: "d", in: .networks)

        XCTAssertEqual(matchingActions.count, 1)
        XCTAssertEqual(nonMatchingActions.count, 0)
    }

    /// Test execute(identifier:screen:)
    @MainActor func testActionRegistryExecuteByIdentifier() async {
        var executed = false
        let action = ModuleActionRegistration(
            identifier: "exec-test",
            title: "Execute Test",
            keybinding: nil,
            viewModes: [.servers],
            handler: { _ in
                executed = true
            }
        )

        ActionRegistry.shared.register(action)

        let result = await ActionRegistry.shared.execute(identifier: "exec-test", screen: nil)

        XCTAssertTrue(result, "Should return true for successful execution")
        XCTAssertTrue(executed, "Handler should be called")
    }

    /// Test execute returns false for unknown action
    @MainActor func testActionRegistryExecuteUnknown() async {
        let result = await ActionRegistry.shared.execute(identifier: "nonexistent", screen: nil)
        XCTAssertFalse(result, "Should return false for unknown action")
    }

    /// Test actions(for:) by category
    @MainActor func testActionRegistryActionsByCategory() {
        let lifecycleAction = ModuleActionRegistration(
            identifier: "lifecycle-action",
            title: "Lifecycle",
            keybinding: nil,
            viewModes: [.servers],
            handler: { _ in },
            category: .lifecycle
        )
        let networkAction = ModuleActionRegistration(
            identifier: "network-action",
            title: "Network",
            keybinding: nil,
            viewModes: [.servers],
            handler: { _ in },
            category: .network
        )

        ActionRegistry.shared.register(lifecycleAction)
        ActionRegistry.shared.register(networkAction)

        let lifecycleActions = ActionRegistry.shared.actions(for: .lifecycle)
        let networkActions = ActionRegistry.shared.actions(for: .network)

        XCTAssertEqual(lifecycleActions.count, 1)
        XCTAssertEqual(networkActions.count, 1)
    }

    /// Test clear removes all actions
    @MainActor func testActionRegistryClear() {
        let action = ModuleActionRegistration(
            identifier: "clear-test",
            title: "Clear Test",
            keybinding: "c",
            viewModes: [.servers],
            handler: { _ in }
        )

        ActionRegistry.shared.register(action)
        ActionRegistry.shared.clear()

        XCTAssertNil(ActionRegistry.shared.action(for: "clear-test"))
        XCTAssertEqual(ActionRegistry.shared.allActions().count, 0)
    }

    /// Test helpText(for:) generates formatted help
    @MainActor func testActionRegistryHelpText() {
        let action = ModuleActionRegistration(
            identifier: "help-test",
            title: "Help Test Action",
            keybinding: "h",
            viewModes: [.servers],
            handler: { _ in },
            description: "Test description",
            category: .general
        )

        ActionRegistry.shared.register(action)

        let helpText = ActionRegistry.shared.helpText(for: .servers)

        XCTAssertTrue(helpText.contains("Help Test Action"))
        XCTAssertTrue(helpText.contains("[h]"))
        XCTAssertTrue(helpText.contains("Test description"))
    }

    // MARK: - Integration Tests

    /// Test module registration integrates with view registry
    @MainActor func testModuleRegistrationIntegration() async throws {
        let module = MockOpenStackModuleWithViews(
            identifier: "integration-test",
            displayName: "Integration Test",
            dependencies: []
        )

        try await ModuleRegistry.shared.register(module)

        // Check that views were registered
        let viewHandler = ViewRegistry.shared.handler(for: .servers)
        XCTAssertNotNil(viewHandler, "Module should register views")
    }

    /// Test cross-module dependencies work correctly
    @MainActor func testCrossModuleDependencies() async throws {
        // Register modules in correct order
        let baseModule = MockOpenStackModule(
            identifier: "base",
            displayName: "Base",
            dependencies: []
        )
        let dependentModule = MockOpenStackModule(
            identifier: "dependent",
            displayName: "Dependent",
            dependencies: ["base"]
        )

        try await ModuleRegistry.shared.register(baseModule)
        try await ModuleRegistry.shared.register(dependentModule)

        XCTAssertEqual(ModuleRegistry.shared.allModules().count, 2)
        XCTAssertNotNil(ModuleRegistry.shared.module(for: "dependent"))
    }

    /// Test module health checks after loading
    @MainActor func testModuleHealthChecksAfterLoading() async throws {
        let module1 = MockOpenStackModule(
            identifier: "health-1",
            displayName: "Health 1",
            dependencies: [],
            isHealthy: true
        )
        let module2 = MockOpenStackModule(
            identifier: "health-2",
            displayName: "Health 2",
            dependencies: [],
            isHealthy: true
        )

        try await ModuleRegistry.shared.register(module1)
        try await ModuleRegistry.shared.register(module2)

        let healthResults = await ModuleRegistry.shared.healthCheckAll()

        XCTAssertEqual(healthResults.count, 2)
        for (_, status) in healthResults {
            XCTAssertTrue(status.isHealthy, "All modules should be healthy")
        }
    }

    // MARK: - Performance Tests

    /// Test registry lookup performance
    @MainActor func testRegistryLookupPerformance() {
        // Register multiple actions
        for i in 0..<100 {
            let action = ModuleActionRegistration(
                identifier: "action-\(i)",
                title: "Action \(i)",
                keybinding: nil,
                viewModes: [.servers],
                handler: { _ in }
            )
            ActionRegistry.shared.register(action)
        }

        measure {
            for i in 0..<1000 {
                _ = ActionRegistry.shared.action(for: "action-\(i % 100)")
            }
        }
    }

    /// Test view registry performance
    @MainActor func testViewRegistryPerformance() {
        // Pre-register some views
        let viewModes: [ViewMode] = [.servers, .networks, .volumes, .images]
        for viewMode in viewModes {
            let registration = ModuleViewRegistration(
                viewMode: viewMode,
                title: "\(viewMode)",
                renderHandler: { _, _, _, _, _ in },
                inputHandler: nil,
                category: .compute
            )
            ViewRegistry.shared.register(registration)
        }

        measure {
            for _ in 0..<1000 {
                _ = ViewRegistry.shared.handler(for: .servers)
                _ = ViewRegistry.shared.handler(for: .networks)
                _ = ViewRegistry.shared.handler(for: .volumes)
            }
        }
    }

    /// Test data provider registry fetch performance
    @MainActor func testDataProviderFetchPerformance() async {
        let provider = MockDataProvider(resourceType: "perf-test", itemCount: 100)
        DataProviderRegistry.shared.register(provider, from: "test")

        let startTime = Date()
        for _ in 0..<100 {
            _ = await DataProviderRegistry.shared.fetchData(
                for: "perf-test",
                priority: .fast,
                forceRefresh: false
            )
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(
            duration,
            1.0,
            "100 fetch operations should complete within 1 second"
        )
    }

    // MARK: - Edge Case Tests

    /// Test duplicate module registration
    @MainActor func testDuplicateModuleRegistration() async throws {
        let module1 = MockOpenStackModule(
            identifier: "duplicate",
            displayName: "First",
            dependencies: []
        )
        let module2 = MockOpenStackModule(
            identifier: "duplicate",
            displayName: "Second",
            dependencies: []
        )

        try await ModuleRegistry.shared.register(module1)
        try await ModuleRegistry.shared.register(module2)

        // Second registration should overwrite
        let retrieved = ModuleRegistry.shared.module(for: "duplicate")
        XCTAssertEqual(
            retrieved?.displayName,
            "Second",
            "Second registration should overwrite first"
        )
    }

    /// Test empty module catalog operations
    @MainActor func testEmptyRegistryOperations() {
        // Operations on empty registries should not crash
        XCTAssertNil(ViewRegistry.shared.handler(for: .servers))
        XCTAssertEqual(ViewRegistry.shared.allRegistrations().count, 0)
        XCTAssertEqual(ActionRegistry.shared.allActions().count, 0)
        XCTAssertEqual(FormRegistry.shared.allRegistrations().count, 0)
    }

    /// Test special characters in identifiers
    @MainActor func testSpecialCharactersInIdentifiers() async throws {
        let module = MockOpenStackModule(
            identifier: "test-module_v2.0",
            displayName: "Test Module V2",
            dependencies: []
        )

        try await ModuleRegistry.shared.register(module)

        let retrieved = ModuleRegistry.shared.module(for: "test-module_v2.0")
        XCTAssertNotNil(retrieved)
    }
}

// MARK: - Mock Types for Testing

/// Mock OpenStack module for testing
@MainActor
final class MockOpenStackModule: OpenStackModule {
    let identifier: String
    let displayName: String
    let version: String = "1.0.0"
    let dependencies: [String]

    var configureCalled = false
    var cleanupCalled = false
    private let isHealthy: Bool

    required init(tui: TUI) {
        self.identifier = "mock"
        self.displayName = "Mock"
        self.dependencies = []
        self.isHealthy = true
    }

    init(
        identifier: String,
        displayName: String,
        dependencies: [String],
        isHealthy: Bool = true
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.dependencies = dependencies
        self.isHealthy = isHealthy
    }

    func configure() async throws {
        configureCalled = true
    }

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

    func cleanup() async {
        cleanupCalled = true
    }

    func healthCheck() async -> ModuleHealthStatus {
        return ModuleHealthStatus(
            isHealthy: isHealthy,
            lastCheck: Date(),
            errors: isHealthy ? [] : ["Test error"],
            metrics: [:]
        )
    }
}

/// Mock module that registers views for integration testing
@MainActor
final class MockOpenStackModuleWithViews: OpenStackModule {
    let identifier: String
    let displayName: String
    let version: String = "1.0.0"
    let dependencies: [String]

    required init(tui: TUI) {
        self.identifier = "mock-with-views"
        self.displayName = "Mock With Views"
        self.dependencies = []
    }

    init(identifier: String, displayName: String, dependencies: [String]) {
        self.identifier = identifier
        self.displayName = displayName
        self.dependencies = dependencies
    }

    func configure() async throws {}

    func registerViews() -> [ModuleViewRegistration] {
        return [
            ModuleViewRegistration(
                viewMode: .servers,
                title: "Servers",
                renderHandler: { _, _, _, _, _ in },
                inputHandler: nil,
                category: .compute
            )
        ]
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
            isHealthy: true,
            lastCheck: Date(),
            errors: [],
            metrics: [:]
        )
    }
}

/// Mock action provider module for testing
@MainActor
final class MockActionProviderModule: OpenStackModule, ActionProvider {
    let identifier: String
    let displayName: String
    let version: String = "1.0.0"
    let dependencies: [String]

    var listViewActions: [ActionType] = [.create, .delete, .refresh]
    var detailViewActions: [ActionType] = [.delete, .refresh]
    var createViewMode: ViewMode? = nil

    required init(tui: TUI) {
        self.identifier = "mock-action-provider"
        self.displayName = "Mock Action Provider"
        self.dependencies = []
    }

    init(identifier: String, displayName: String, dependencies: [String]) {
        self.identifier = identifier
        self.displayName = displayName
        self.dependencies = dependencies
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
            isHealthy: true,
            lastCheck: Date(),
            errors: [],
            metrics: [:]
        )
    }

    func executeAction(
        _ action: ActionType,
        screen: OpaquePointer?,
        tui: TUI
    ) async -> Bool {
        return true
    }
}

/// Mock data provider for testing
@MainActor
final class MockDataProvider: DataProvider {
    let resourceType: String
    private(set) var lastRefreshTime: Date?
    private(set) var currentItemCount: Int
    let supportsPagination: Bool = false
    var cacheClearedCount: Int = 0

    init(resourceType: String, itemCount: Int = 0, lastRefresh: Date? = nil) {
        self.resourceType = resourceType
        self.currentItemCount = itemCount
        self.lastRefreshTime = lastRefresh ?? Date()
    }

    func fetchData(
        priority: DataFetchPriority,
        forceRefresh: Bool
    ) async -> DataFetchResult {
        return DataFetchResult(
            itemCount: currentItemCount,
            duration: 0.1,
            fromCache: !forceRefresh,
            error: nil
        )
    }

    func refreshResource(id: String, priority: DataFetchPriority) async -> DataFetchResult {
        return await fetchData(priority: priority, forceRefresh: true)
    }

    func clearCache() async {
        cacheClearedCount += 1
        lastRefreshTime = nil
    }

    func getPaginatedItems(page: Int, pageSize: Int) async -> [Any]? {
        return nil
    }
}
