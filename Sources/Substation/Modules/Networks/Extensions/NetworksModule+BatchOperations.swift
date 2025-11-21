// Sources/Substation/Modules/Networks/Extensions/NetworksModule+BatchOperations.swift
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

// MARK: - BatchOperationProvider Conformance

/// Extension providing batch operation support for NetworksModule
///
/// This extension enables bulk network operations including batch deletion
/// with proper error handling and idempotent behavior. Networks are assigned
/// a deletion priority of 7 (late deletion) because they are base resources
/// that other resources depend on.
///
/// ## Dependency Ordering
///
/// Networks must be deleted after their dependent resources:
/// - Subnets (priority 6)
/// - Ports (priority 5)
/// - Routers (priority 4)
/// - Floating IPs (priority 3)
///
/// ## Error Handling
///
/// The batch delete operation treats HTTP 404 errors as success to ensure
/// idempotent behavior. This allows retry operations to succeed even if
/// the resource was already deleted.
extension NetworksModule: BatchOperationProvider {
    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for networks
    ///
    /// Currently supports:
    /// - `networkBulkDelete`: Delete multiple networks in a batch
    var supportedBatchOperationTypes: Set<String> { ["networkBulkDelete"] }

    /// Deletion priority for dependency ordering
    ///
    /// Networks have priority 7 (late deletion) because they are foundational
    /// resources that other Neutron resources depend on. They must be deleted
    /// after subnets, ports, routers, and floating IPs.
    var deletionPriority: Int { 7 }

    // MARK: - Batch Delete Implementation

    /// Execute batch deletion of networks
    ///
    /// Deletes multiple networks by their IDs. Each deletion is tracked
    /// individually and HTTP 404 errors are treated as success for
    /// idempotent behavior.
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of network IDs to delete
    ///   - client: OSClient instance for making API calls
    /// - Returns: Array of individual operation results, one per network ID
    func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        var results: [IndividualOperationResult] = []

        Logger.shared.logInfo(
            "NetworksModule - Starting batch delete for \(resourceIDs.count) networks"
        )

        for networkID in resourceIDs {
            do {
                Logger.shared.logDebug(
                    "NetworksModule - Deleting network: \(networkID)"
                )

                try await client.deleteNetwork(id: networkID)

                Logger.shared.logDebug(
                    "NetworksModule - Successfully deleted network: \(networkID)"
                )

                results.append(.success(resourceID: networkID))

            } catch let error as OpenStackError {
                // Treat 404 as success - resource already deleted (idempotent)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "NetworksModule - Network \(networkID) already deleted (404)"
                    )
                    results.append(.success(resourceID: networkID))
                } else {
                    Logger.shared.logError(
                        "NetworksModule - Failed to delete network \(networkID): \(error)"
                    )
                    results.append(.failure(
                        resourceID: networkID,
                        error: error.localizedDescription
                    ))
                }
            } catch {
                Logger.shared.logError(
                    "NetworksModule - Unexpected error deleting network \(networkID): \(error)"
                )
                results.append(.failure(
                    resourceID: networkID,
                    error: error.localizedDescription
                ))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.filter { !$0.success }.count

        Logger.shared.logInfo(
            "NetworksModule - Batch delete completed: \(successCount) succeeded, \(failureCount) failed"
        )

        return results
    }

    // MARK: - Batch Validation

    /// Validate networks before batch deletion
    ///
    /// Performs pre-flight validation to check that:
    /// - At least one network ID is provided
    /// - Network IDs appear to be valid UUIDs
    ///
    /// Note: Full dependency checking (subnets, ports) is performed by
    /// the BatchOperationManager during execution planning.
    ///
    /// - Parameter resourceIDs: Array of network IDs to validate
    /// - Returns: Validation result with any errors or warnings
    func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty resource list
        if resourceIDs.isEmpty {
            errors.append("No network IDs provided for batch deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate UUID format for each network ID
        for networkID in resourceIDs {
            if UUID(uuidString: networkID) == nil {
                warnings.append("Network ID '\(networkID)' may not be a valid UUID")
            }
        }

        // Check for potential external network deletion
        if let tui = tui {
            let networks = tui.cacheManager.cachedNetworks
            for networkID in resourceIDs {
                if let network = networks.first(where: { $0.id == networkID }) {
                    if network.external == true {
                        warnings.append(
                            "Network '\(network.name ?? networkID)' is an external network"
                        )
                    }
                    if network.shared == true {
                        warnings.append(
                            "Network '\(network.name ?? networkID)' is a shared network"
                        )
                    }
                }
            }
        }

        Logger.shared.logDebug(
            "NetworksModule - Batch validation completed: \(errors.count) errors, \(warnings.count) warnings"
        )

        return BatchOperationValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}
