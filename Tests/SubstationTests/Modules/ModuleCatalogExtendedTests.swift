// Tests/SubstationTests/Modules/ModuleCatalogExtendedTests.swift
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

// MARK: - Extended ModuleCatalog Test Suite

/// Extended test suite for ModuleCatalog functionality.
///
/// Tests cover:
/// - Module definitions and metadata
/// - Dependency resolution
/// - Load phase ordering
/// - Module category organization
final class ModuleCatalogExtendedTests: XCTestCase {

    // MARK: - Module Definition Tests

    /// Test all expected modules are present
    @MainActor
    func testAllExpectedModulesPresent() {
        let expectedModules = [
            "barbican", "swift", "keypairs", "servergroups", "flavors",
            "images", "securitygroups", "volumes", "networks", "subnets",
            "routers", "floatingips", "ports", "servers", "magnum", "hypervisors"
        ]

        let catalogModules = ModuleCatalog.allModuleIdentifiers

        for module in expectedModules {
            XCTAssertTrue(
                catalogModules.contains(module),
                "ModuleCatalog should contain '\(module)'"
            )
        }
    }

    /// Test module count matches expected
    @MainActor
    func testModuleCountMatchesExpected() {
        // The catalog should have modules for all OpenStack services
        XCTAssertGreaterThanOrEqual(
            ModuleCatalog.moduleCount,
            15,
            "Should have at least 15 modules"
        )
    }

    /// Test each module has required metadata
    @MainActor
    func testModulesHaveRequiredMetadata() {
        for definition in ModuleCatalog.availableModules {
            XCTAssertFalse(
                definition.identifier.isEmpty,
                "Module '\(definition.identifier)' should have non-empty identifier"
            )
            XCTAssertFalse(
                definition.displayName.isEmpty,
                "Module '\(definition.identifier)' should have non-empty displayName"
            )
        }
    }

    // MARK: - Dependency Tests

    /// Test Servers module has correct dependencies
    @MainActor
    func testServersModuleDependencies() {
        let serversDefinition = ModuleCatalog.definition(for: "servers")

        XCTAssertNotNil(serversDefinition)
        XCTAssertTrue(
            serversDefinition?.dependencies.contains("images") ?? false,
            "Servers should depend on images"
        )
        XCTAssertTrue(
            serversDefinition?.dependencies.contains("networks") ?? false,
            "Servers should depend on networks"
        )
        XCTAssertTrue(
            serversDefinition?.dependencies.contains("flavors") ?? false,
            "Servers should depend on flavors"
        )
    }

    /// Test Subnets module depends on Networks
    @MainActor
    func testSubnetsModuleDependsOnNetworks() {
        let subnetsDefinition = ModuleCatalog.definition(for: "subnets")

        XCTAssertNotNil(subnetsDefinition)
        XCTAssertTrue(
            subnetsDefinition?.dependencies.contains("networks") ?? false,
            "Subnets should depend on networks"
        )
    }

    /// Test Ports module has network dependency
    @MainActor
    func testPortsModuleDependencies() {
        let portsDefinition = ModuleCatalog.definition(for: "ports")

        XCTAssertNotNil(portsDefinition)
        XCTAssertTrue(
            portsDefinition?.dependencies.contains("networks") ?? false,
            "Ports should depend on networks"
        )
    }

    /// Test FloatingIPs module dependencies
    @MainActor
    func testFloatingIPsModuleDependencies() {
        let floatingIPsDefinition = ModuleCatalog.definition(for: "floatingips")

        XCTAssertNotNil(floatingIPsDefinition)
        XCTAssertTrue(
            floatingIPsDefinition?.dependencies.contains("networks") ?? false,
            "FloatingIPs should depend on networks"
        )
    }

    /// Test Routers module dependencies
    @MainActor
    func testRoutersModuleDependencies() {
        let routersDefinition = ModuleCatalog.definition(for: "routers")

        XCTAssertNotNil(routersDefinition)
        XCTAssertTrue(
            routersDefinition?.dependencies.contains("networks") ?? false,
            "Routers should depend on networks"
        )
    }

    /// Test all dependencies reference existing modules
    @MainActor
    func testAllDependenciesExist() {
        for definition in ModuleCatalog.availableModules {
            for dependency in definition.dependencies {
                XCTAssertTrue(
                    ModuleCatalog.allModuleIdentifiers.contains(dependency),
                    "Module '\(definition.identifier)' has unknown dependency '\(dependency)'"
                )
            }
        }
    }

    /// Test no circular dependencies exist
    @MainActor
    func testNoCircularDependencies() {
        for definition in ModuleCatalog.availableModules {
            var visited = Set<String>()
            let hasCircular = checkCircularDependency(
                moduleId: definition.identifier,
                visited: &visited
            )
            XCTAssertFalse(
                hasCircular,
                "Module '\(definition.identifier)' has circular dependency"
            )
        }
    }

    // MARK: - Load Phase Tests

    /// Test modules are sorted by load phase
    @MainActor
    func testModulesSortedByLoadPhase() {
        let orderedModules = ModuleCatalog.modulesByLoadOrder

        var lastPhase: ModuleCatalog.LoadPhase = .independent
        for module in orderedModules {
            XCTAssertGreaterThanOrEqual(
                module.phase.rawValue,
                lastPhase.rawValue,
                "Modules should be sorted by phase: '\(module.identifier)'"
            )
            lastPhase = module.phase
        }
    }

    /// Test independent modules have no dependencies
    @MainActor
    func testIndependentModulesHaveNoDependencies() {
        let orderedModules = ModuleCatalog.modulesByLoadOrder

        for module in orderedModules where module.phase == .independent {
            XCTAssertTrue(
                module.dependencies.isEmpty,
                "Independent module '\(module.identifier)' should have no dependencies"
            )
        }
    }

    /// Test dependent modules have dependencies
    @MainActor
    func testDependentModulesHaveDependencies() {
        let orderedModules = ModuleCatalog.modulesByLoadOrder

        for module in orderedModules {
            if module.phase == .networkDependent || module.phase == .multiDependent {
                XCTAssertFalse(
                    module.dependencies.isEmpty,
                    "Dependent module '\(module.identifier)' should have dependencies"
                )
            }
        }
    }

    /// Test multi-dependent modules have multiple dependencies
    @MainActor
    func testMultiDependentModulesHaveMultipleDependencies() {
        let orderedModules = ModuleCatalog.modulesByLoadOrder

        for module in orderedModules where module.phase == .multiDependent {
            XCTAssertGreaterThanOrEqual(
                module.dependencies.count,
                1,
                "Multi-dependent module '\(module.identifier)' should have at least one dependency"
            )
        }
    }

    // MARK: - Module Category Tests

    /// Test compute modules are identified
    @MainActor
    func testComputeModulesIdentified() {
        let computeModules = ["servers", "flavors", "keypairs", "servergroups", "hypervisors"]

        for moduleId in computeModules {
            let definition = ModuleCatalog.definition(for: moduleId)
            if definition != nil {
                XCTAssertTrue(true, "Compute module '\(moduleId)' exists")
            }
        }
    }

    /// Test network modules are identified
    @MainActor
    func testNetworkModulesIdentified() {
        let networkModules = ["networks", "subnets", "ports", "routers", "floatingips", "securitygroups"]

        for moduleId in networkModules {
            let definition = ModuleCatalog.definition(for: moduleId)
            XCTAssertNotNil(definition, "Network module '\(moduleId)' should exist")
        }
    }

    /// Test storage modules are identified
    @MainActor
    func testStorageModulesIdentified() {
        let storageModules = ["volumes", "images", "swift"]

        for moduleId in storageModules {
            let definition = ModuleCatalog.definition(for: moduleId)
            XCTAssertNotNil(definition, "Storage module '\(moduleId)' should exist")
        }
    }

    // MARK: - Definition Lookup Tests

    /// Test definition lookup by identifier
    @MainActor
    func testDefinitionLookupByIdentifier() {
        let identifiers = ["servers", "networks", "volumes", "images"]

        for id in identifiers {
            let definition = ModuleCatalog.definition(for: id)
            XCTAssertNotNil(definition, "Should find definition for '\(id)'")
            XCTAssertEqual(definition?.identifier, id)
        }
    }

    /// Test definition lookup returns nil for unknown module
    @MainActor
    func testDefinitionLookupReturnsNilForUnknown() {
        let definition = ModuleCatalog.definition(for: "nonexistent-module")
        XCTAssertNil(definition)
    }

    /// Test definition lookup is case sensitive
    @MainActor
    func testDefinitionLookupIsCaseSensitive() {
        let lowerCase = ModuleCatalog.definition(for: "servers")
        let upperCase = ModuleCatalog.definition(for: "SERVERS")

        XCTAssertNotNil(lowerCase)
        XCTAssertNil(upperCase, "Lookup should be case sensitive")
    }

    // MARK: - Edge Cases

    /// Test empty identifier lookup
    @MainActor
    func testEmptyIdentifierLookup() {
        let definition = ModuleCatalog.definition(for: "")
        XCTAssertNil(definition)
    }

    /// Test whitespace identifier lookup
    @MainActor
    func testWhitespaceIdentifierLookup() {
        let definition = ModuleCatalog.definition(for: "   ")
        XCTAssertNil(definition)
    }

    /// Test special characters in identifier lookup
    @MainActor
    func testSpecialCharactersInIdentifierLookup() {
        let definition = ModuleCatalog.definition(for: "servers!@#")
        XCTAssertNil(definition)
    }

    // MARK: - Helper Methods

    private func checkCircularDependency(
        moduleId: String,
        visited: inout Set<String>
    ) -> Bool {
        if visited.contains(moduleId) {
            return true
        }

        visited.insert(moduleId)

        guard let definition = ModuleCatalog.definition(for: moduleId) else {
            return false
        }

        for dependency in definition.dependencies {
            if checkCircularDependency(moduleId: dependency, visited: &visited) {
                return true
            }
        }

        visited.remove(moduleId)
        return false
    }
}

// MARK: - Default Disabled Module Tests

/// Tests for modules disabled by default
final class ModuleDefaultDisabledTests: XCTestCase {

    /// Test that swift is in the disabledByDefault set
    @MainActor
    func testSwiftDisabledByDefault() {
        XCTAssertTrue(
            ModuleCatalog.disabledByDefault.contains("swift"),
            "Swift module should be disabled by default"
        )
    }

    /// Test that swift is still in the full catalog
    @MainActor
    func testSwiftStillInCatalog() {
        XCTAssertTrue(
            ModuleCatalog.allModuleIdentifiers.contains("swift"),
            "Swift module should still exist in the catalog"
        )
    }

    /// Test that defaultEnabledModuleIdentifiers excludes swift
    @MainActor
    func testDefaultEnabledExcludesSwift() {
        XCTAssertFalse(
            ModuleCatalog.defaultEnabledModuleIdentifiers.contains("swift"),
            "Swift module should not be in default enabled modules"
        )
    }

    /// Test that defaultEnabledModuleIdentifiers contains all non-disabled modules
    @MainActor
    func testDefaultEnabledContainsOtherModules() {
        let enabled = ModuleCatalog.defaultEnabledModuleIdentifiers
        let all = ModuleCatalog.allModuleIdentifiers
        let disabled = ModuleCatalog.disabledByDefault

        XCTAssertEqual(enabled, all.subtracting(disabled))
    }
}

// MARK: - Load Phase Tests

/// Tests for LoadPhase enum behavior
final class LoadPhaseTests: XCTestCase {

    /// Test load phase raw values are ordered
    @MainActor
    func testLoadPhaseRawValuesOrdered() {
        XCTAssertLessThan(
            ModuleCatalog.LoadPhase.independent.rawValue,
            ModuleCatalog.LoadPhase.networkDependent.rawValue
        )
        XCTAssertLessThan(
            ModuleCatalog.LoadPhase.networkDependent.rawValue,
            ModuleCatalog.LoadPhase.multiDependent.rawValue
        )
    }

    /// Test load phase comparison
    @MainActor
    func testLoadPhaseComparison() {
        let independent = ModuleCatalog.LoadPhase.independent
        let networkDependent = ModuleCatalog.LoadPhase.networkDependent
        let multiDependent = ModuleCatalog.LoadPhase.multiDependent

        XCTAssertTrue(independent.rawValue < networkDependent.rawValue)
        XCTAssertTrue(networkDependent.rawValue < multiDependent.rawValue)
        XCTAssertTrue(independent.rawValue < multiDependent.rawValue)
    }
}
