// Sources/Substation/Modules/Subnets/Extensions/SubnetsModule+BatchOperations.swift
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

/// Batch operation support for SubnetsModule
///
/// This extension enables the SubnetsModule to participate in batch operations,
/// particularly bulk deletion of subnet resources. Subnets are given deletion
/// priority 6 because they must be deleted after routers (which may have
/// interfaces attached to subnets) but before networks (which contain subnets).
///
/// ## Deletion Priority
///
/// Subnets have priority 6 because:
/// - Subnets must be deleted after routers detach their interfaces
/// - Subnets must be deleted after ports that reference them are removed
/// - Subnets must be deleted before their parent networks can be deleted
/// - This ordering ensures proper cleanup of network topology dependencies
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension SubnetsModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for subnets
    ///
    /// Currently supports:
    /// - `subnetBulkDelete`: Bulk deletion of multiple subnets
    ///
    /// Future operations may include:
    /// - `subnetBulkUpdate`: Update multiple subnet configurations
    /// - `subnetBulkDHCPToggle`: Enable/disable DHCP on multiple subnets
    public var supportedBatchOperationTypes: Set<String> {
        return ["subnetBulkDelete"]
    }

    /// Deletion priority for subnets
    ///
    /// Returns 6 (mid-high priority) because subnets must be deleted:
    /// - After routers (priority 5) detach their interfaces
    /// - After ports (priority 4) that reference them are removed
    /// - Before networks (priority 7) can be deleted
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// subnets are removed after their dependencies are cleared and
    /// before the parent network deletion is attempted.
    public var deletionPriority: Int {
        return 6
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of subnet resources
    ///
    /// Deletes multiple subnets in sequence, tracking individual results.
    /// Each subnet deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a subnet is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let subnetIDs = ["subnet-1", "subnet-2", "subnet-3"]
    /// let results = await subnetsModule.executeBatchDelete(
    ///     resourceIDs: subnetIDs,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted subnet: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of subnet UUIDs to delete
    ///   - client: OSClient instance for making Neutron API calls
    /// - Returns: Array of individual operation results, one per subnet ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "SubnetsModule+BatchOperations - Starting batch delete",
            context: ["subnetCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for subnetID in resourceIDs {
            Logger.shared.logDebug(
                "SubnetsModule+BatchOperations - Deleting subnet",
                context: ["subnetID": subnetID]
            )

            do {
                try await client.deleteSubnet(id: subnetID)

                Logger.shared.logDebug(
                    "SubnetsModule+BatchOperations - Subnet deleted successfully",
                    context: ["subnetID": subnetID]
                )

                results.append(.success(resourceID: subnetID))

            } catch let error as OpenStackError {
                // Treat 404 as success - subnet already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "SubnetsModule+BatchOperations - Subnet already deleted (404)",
                        context: ["subnetID": subnetID]
                    )
                    results.append(.success(resourceID: subnetID))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "SubnetsModule+BatchOperations - Failed to delete subnet",
                        context: [
                            "subnetID": subnetID,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: subnetID, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "SubnetsModule+BatchOperations - Unexpected error deleting subnet",
                    context: [
                        "subnetID": subnetID,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: subnetID, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "SubnetsModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate subnets before batch deletion
    ///
    /// Performs pre-flight validation to ensure subnets can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid subnet ID format
    ///
    /// Note: This does not verify subnet existence or state, as subnets
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of subnet UUIDs to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No subnet IDs provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate subnet ID format (should be UUID format)
        for subnetID in resourceIDs {
            if subnetID.isEmpty {
                errors.append("Empty subnet ID in deletion list")
            } else if subnetID.count < 32 {
                warnings.append("Subnet ID '\(subnetID)' appears to be invalid format")
            }
        }

        // Check for duplicates
        let uniqueIDs = Set(resourceIDs)
        if uniqueIDs.count < resourceIDs.count {
            warnings.append("Duplicate subnet IDs detected - will be processed once")
        }

        Logger.shared.logDebug(
            "SubnetsModule+BatchOperations - Validation completed",
            context: [
                "subnetCount": resourceIDs.count,
                "errorCount": errors.count,
                "warningCount": warnings.count
            ]
        )

        return BatchOperationValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}
