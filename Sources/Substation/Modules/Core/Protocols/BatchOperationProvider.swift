// Sources/Substation/Modules/Core/Protocols/BatchOperationProvider.swift
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

import Foundation
import OSClient

/// Protocol for modules that provide batch operations
///
/// Modules conforming to this protocol can register their own batch operation
/// types and provide execution logic for those operations. This enables
/// resource-specific batch delete, update, and other bulk operations while
/// maintaining proper dependency ordering and validation.
///
/// ## Overview
///
/// The `BatchOperationProvider` protocol extends `OpenStackModule` to add
/// batch operation capabilities. Each module declares its supported operation
/// types and implements the necessary execution and validation logic.
///
/// ## Deletion Priority
///
/// The `deletionPriority` property controls the order in which resources are
/// deleted when performing cross-module batch deletions. Lower values are
/// deleted first, which is important for handling dependencies:
///
/// - Priority 1-3: Resources that depend on nothing (floating IPs, security groups)
/// - Priority 4-6: Mid-level resources (ports, servers)
/// - Priority 7-9: Base resources that others depend on (networks, volumes)
///
/// ## Example
///
/// ```swift
/// extension ServersModule: BatchOperationProvider {
///     var supportedBatchOperationTypes: Set<String> { ["delete", "stop", "start"] }
///     var deletionPriority: Int { 4 }
///
///     func executeBatchDelete(
///         resourceIDs: [String],
///         client: OSClient
///     ) async -> [IndividualOperationResult] {
///         // Implementation
///     }
/// }
/// ```
@MainActor
protocol BatchOperationProvider: OpenStackModule {
    /// Supported batch operation identifiers for this module
    ///
    /// Each string represents a type of batch operation this module can perform.
    /// Common values include "delete", "start", "stop", "update", etc.
    var supportedBatchOperationTypes: Set<String> { get }

    /// Execute a batch delete operation for resources of this module's type
    ///
    /// This method performs deletion of multiple resources in a single batch
    /// operation. Each resource is processed and its result is tracked
    /// individually, allowing partial success scenarios.
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of resource IDs to delete
    ///   - client: OSClient instance for making API calls
    /// - Returns: Array of individual operation results, one per resource ID
    func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult]

    /// Validate resources before batch operation
    ///
    /// Performs pre-flight validation to ensure resources can be processed.
    /// This may check for dependencies, permissions, resource states, etc.
    ///
    /// - Parameter resourceIDs: Array of resource IDs to validate
    /// - Returns: Validation result containing any errors or warnings
    func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation

    /// Get deletion priority for dependency ordering
    ///
    /// Lower values are deleted first. This ensures that dependent resources
    /// are removed before the resources they depend on.
    ///
    /// Default value is 5 (mid-priority).
    var deletionPriority: Int { get }
}

/// Default implementations for BatchOperationProvider
extension BatchOperationProvider {
    /// Default validation that passes all non-empty resource sets
    ///
    /// Override this method to implement resource-specific validation logic.
    ///
    /// - Parameter resourceIDs: Array of resource IDs to validate
    /// - Returns: Validation result with any errors
    func validateBatchOperation(resourceIDs: [String]) async -> BatchOperationValidation {
        if resourceIDs.isEmpty {
            return BatchOperationValidation(isValid: false, errors: ["No resources provided"])
        }
        return BatchOperationValidation(isValid: true, errors: [])
    }

    /// Default deletion priority (mid-level)
    ///
    /// Override this property to set appropriate priority based on
    /// resource dependencies.
    var deletionPriority: Int { 5 }
}

// MARK: - Supporting Types

/// Result of batch operation validation
///
/// Contains the validation outcome including whether the operation can proceed,
/// any blocking errors, and non-blocking warnings.
struct BatchOperationValidation: Sendable {
    /// Whether the batch operation can proceed
    let isValid: Bool

    /// Blocking errors that prevent the operation
    let errors: [String]

    /// Non-blocking warnings about potential issues
    let warnings: [String]

    /// Create a new validation result
    ///
    /// - Parameters:
    ///   - isValid: Whether the operation can proceed
    ///   - errors: Array of error messages (empty if valid)
    ///   - warnings: Array of warning messages (optional)
    init(isValid: Bool, errors: [String], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// Result of an individual operation within a batch
///
/// Tracks the success or failure of a single resource operation,
/// allowing batch operations to report partial success.
struct IndividualOperationResult: Sendable {
    /// The resource ID that was operated on
    let resourceID: String

    /// Whether this individual operation succeeded
    let success: Bool

    /// Error message if the operation failed
    let error: String?

    /// Create a successful operation result
    ///
    /// - Parameter resourceID: The ID of the successfully processed resource
    /// - Returns: A success result for the given resource
    static func success(resourceID: String) -> IndividualOperationResult {
        return IndividualOperationResult(resourceID: resourceID, success: true, error: nil)
    }

    /// Create a failed operation result
    ///
    /// - Parameters:
    ///   - resourceID: The ID of the resource that failed to process
    ///   - error: Description of what went wrong
    /// - Returns: A failure result for the given resource
    static func failure(resourceID: String, error: String) -> IndividualOperationResult {
        return IndividualOperationResult(resourceID: resourceID, success: false, error: error)
    }

    /// Create a new operation result
    ///
    /// - Parameters:
    ///   - resourceID: The resource ID that was operated on
    ///   - success: Whether the operation succeeded
    ///   - error: Error message if failed (nil if successful)
    init(resourceID: String, success: Bool, error: String?) {
        self.resourceID = resourceID
        self.success = success
        self.error = error
    }
}

// MARK: - Registry

/// Registry for batch operation providers
///
/// Maintains a collection of all modules that support batch operations,
/// allowing the system to discover and invoke batch capabilities dynamically.
///
/// This is a singleton that should be populated during application startup
/// as modules are registered.
///
/// ## Usage
///
/// ```swift
/// // Register a provider
/// BatchOperationRegistry.shared.register(serversModule)
///
/// // Check if a module supports batch operations
/// if BatchOperationRegistry.shared.supportsBatchOperations("servers") {
///     let provider = BatchOperationRegistry.shared.provider(for: "servers")
///     // Use provider
/// }
///
/// // Get all providers sorted for deletion
/// let providers = BatchOperationRegistry.shared.allProvidersSortedByDeletionPriority()
/// ```
@MainActor
final class BatchOperationRegistry {
    /// Shared singleton instance
    static let shared = BatchOperationRegistry()

    /// Map of module identifiers to their batch operation providers
    private var providers: [String: any BatchOperationProvider] = [:]

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Register a module as a batch operation provider
    ///
    /// - Parameter provider: The module conforming to BatchOperationProvider
    func register(_ provider: any BatchOperationProvider) {
        providers[provider.identifier] = provider
        Logger.shared.logInfo("BatchOperationRegistry - Registered provider: \(provider.identifier)")
    }

    /// Unregister a batch operation provider
    ///
    /// - Parameter moduleID: The identifier of the module to unregister
    func unregister(_ moduleID: String) {
        providers.removeValue(forKey: moduleID)
        Logger.shared.logInfo("BatchOperationRegistry - Unregistered provider: \(moduleID)")
    }

    /// Get provider for a module identifier
    ///
    /// - Parameter moduleID: The module identifier to look up
    /// - Returns: The batch operation provider, or nil if not registered
    func provider(for moduleID: String) -> (any BatchOperationProvider)? {
        return providers[moduleID]
    }

    /// Get all registered providers sorted by deletion priority
    ///
    /// Returns providers in the order they should be processed for deletion
    /// operations (lowest priority first).
    ///
    /// - Returns: Array of providers sorted by deletionPriority ascending
    func allProvidersSortedByDeletionPriority() -> [any BatchOperationProvider] {
        return providers.values.sorted { $0.deletionPriority < $1.deletionPriority }
    }

    /// Get all registered provider identifiers
    ///
    /// - Returns: Set of all registered module identifiers
    func allProviderIdentifiers() -> Set<String> {
        return Set(providers.keys)
    }

    /// Check if a module supports batch operations
    ///
    /// - Parameter moduleID: The module identifier to check
    /// - Returns: True if the module has a registered batch operation provider
    func supportsBatchOperations(_ moduleID: String) -> Bool {
        return providers[moduleID] != nil
    }

    /// Get the count of registered providers
    ///
    /// - Returns: Number of registered batch operation providers
    var providerCount: Int {
        return providers.count
    }

    /// Clear all registered providers
    ///
    /// Primarily used for testing purposes.
    func clearAll() {
        providers.removeAll()
        Logger.shared.logInfo("BatchOperationRegistry - Cleared all providers")
    }
}
