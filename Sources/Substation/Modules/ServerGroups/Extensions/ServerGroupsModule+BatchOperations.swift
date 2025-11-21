// Sources/Substation/Modules/ServerGroups/Extensions/ServerGroupsModule+BatchOperations.swift
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

/// Batch operation support for ServerGroupsModule
///
/// This extension enables the ServerGroupsModule to participate in batch operations,
/// particularly bulk deletion of server groups. Server groups are given a late
/// deletion priority (8) because they should be deleted after the servers that
/// reference them have been removed.
///
/// ## Deletion Priority
///
/// Server groups have priority 8 (late) because:
/// - Servers reference server groups for scheduling policies
/// - Servers must be deleted first before their groups can be removed
/// - Deleting server groups early would cause scheduler inconsistencies
/// - Server groups are independent infrastructure that supports other resources
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension ServerGroupsModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for server groups
    ///
    /// Currently supports:
    /// - `serverGroupBulkDelete`: Bulk deletion of multiple server groups
    ///
    /// Future operations may include:
    /// - `serverGroupBulkUpdate`: Update multiple server group policies
    public var supportedBatchOperationTypes: Set<String> {
        return ["serverGroupBulkDelete"]
    }

    /// Deletion priority for server groups
    ///
    /// Returns 8 (late priority) because server groups should be deleted
    /// after servers that depend on them:
    /// - Servers reference groups for affinity/anti-affinity scheduling
    /// - Deleting groups before servers could cause scheduling issues
    /// - Server groups are foundational scheduling infrastructure
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// server groups are removed after all servers have been deleted.
    public var deletionPriority: Int {
        return 8
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of server groups
    ///
    /// Deletes multiple server groups in sequence, tracking individual results.
    /// Each server group deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a server group is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let serverGroupIDs = ["group-1", "group-2", "group-3"]
    /// let results = await serverGroupsModule.executeBatchDelete(
    ///     resourceIDs: serverGroupIDs,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted server group: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of server group UUIDs to delete
    ///   - client: OSClient instance for making Nova API calls
    /// - Returns: Array of individual operation results, one per server group ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "ServerGroupsModule+BatchOperations - Starting batch delete",
            context: ["serverGroupCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for serverGroupID in resourceIDs {
            Logger.shared.logDebug(
                "ServerGroupsModule+BatchOperations - Deleting server group",
                context: ["serverGroupID": serverGroupID]
            )

            do {
                try await client.deleteServerGroup(id: serverGroupID)

                Logger.shared.logDebug(
                    "ServerGroupsModule+BatchOperations - Server group deleted successfully",
                    context: ["serverGroupID": serverGroupID]
                )

                results.append(.success(resourceID: serverGroupID))

            } catch let error as OpenStackError {
                // Treat 404 as success - server group already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "ServerGroupsModule+BatchOperations - Server group already deleted (404)",
                        context: ["serverGroupID": serverGroupID]
                    )
                    results.append(.success(resourceID: serverGroupID))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "ServerGroupsModule+BatchOperations - Failed to delete server group",
                        context: [
                            "serverGroupID": serverGroupID,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: serverGroupID, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "ServerGroupsModule+BatchOperations - Unexpected error deleting server group",
                    context: [
                        "serverGroupID": serverGroupID,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: serverGroupID, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "ServerGroupsModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate server groups before batch deletion
    ///
    /// Performs pre-flight validation to ensure server groups can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid server group ID format
    ///
    /// Note: This does not verify server group existence or state, as server groups
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of server group UUIDs to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No server group IDs provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate server group ID format (should be UUID format)
        for serverGroupID in resourceIDs {
            if serverGroupID.isEmpty {
                errors.append("Empty server group ID in deletion list")
            } else if serverGroupID.count < 32 {
                warnings.append("Server group ID '\(serverGroupID)' appears to be invalid format")
            }
        }

        // Check for duplicates
        let uniqueIDs = Set(resourceIDs)
        if uniqueIDs.count < resourceIDs.count {
            warnings.append("Duplicate server group IDs detected - will be processed once")
        }

        Logger.shared.logDebug(
            "ServerGroupsModule+BatchOperations - Validation completed",
            context: [
                "serverGroupCount": resourceIDs.count,
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
