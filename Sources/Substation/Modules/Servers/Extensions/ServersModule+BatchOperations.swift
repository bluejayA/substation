// Sources/Substation/Modules/Servers/Extensions/ServersModule+BatchOperations.swift
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

/// Batch operation support for ServersModule
///
/// This extension enables the ServersModule to participate in batch operations,
/// particularly bulk deletion of server instances. Servers are given the highest
/// deletion priority (1) because they should be deleted before their dependent
/// resources like volumes, ports, and security groups.
///
/// ## Deletion Priority
///
/// Servers have priority 1 (highest) because:
/// - Servers must be deleted before their attached volumes can be deleted
/// - Servers must be deleted before their ports are released
/// - Servers must be deleted before security groups can be removed
/// - Deleting servers first ensures clean teardown of all dependencies
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension ServersModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for servers
    ///
    /// Currently supports:
    /// - `serverBulkDelete`: Bulk deletion of multiple servers
    ///
    /// Future operations may include:
    /// - `serverBulkStart`: Start multiple servers
    /// - `serverBulkStop`: Stop multiple servers
    /// - `serverBulkReboot`: Reboot multiple servers
    public var supportedBatchOperationTypes: Set<String> {
        return ["serverBulkDelete"]
    }

    /// Deletion priority for servers
    ///
    /// Returns 1 (highest priority) because servers must be deleted first
    /// to release their dependencies:
    /// - Attached volumes
    /// - Network ports
    /// - Floating IP associations
    /// - Security group memberships
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// servers are removed before attempting to delete networks, volumes,
    /// or security groups that may still be in use.
    public var deletionPriority: Int {
        return 1
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of server instances
    ///
    /// Deletes multiple servers in sequence, tracking individual results.
    /// Each server deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a server is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let serverIDs = ["server-1", "server-2", "server-3"]
    /// let results = await serversModule.executeBatchDelete(
    ///     resourceIDs: serverIDs,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted server: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of server UUIDs to delete
    ///   - client: OSClient instance for making Nova API calls
    /// - Returns: Array of individual operation results, one per server ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "ServersModule+BatchOperations - Starting batch delete",
            context: ["serverCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for serverID in resourceIDs {
            Logger.shared.logDebug(
                "ServersModule+BatchOperations - Deleting server",
                context: ["serverID": serverID]
            )

            do {
                try await client.deleteServer(id: serverID)

                Logger.shared.logDebug(
                    "ServersModule+BatchOperations - Server deleted successfully",
                    context: ["serverID": serverID]
                )

                results.append(.success(resourceID: serverID))

            } catch let error as OpenStackError {
                // Treat 404 as success - server already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "ServersModule+BatchOperations - Server already deleted (404)",
                        context: ["serverID": serverID]
                    )
                    results.append(.success(resourceID: serverID))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "ServersModule+BatchOperations - Failed to delete server",
                        context: [
                            "serverID": serverID,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: serverID, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "ServersModule+BatchOperations - Unexpected error deleting server",
                    context: [
                        "serverID": serverID,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: serverID, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "ServersModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate servers before batch deletion
    ///
    /// Performs pre-flight validation to ensure servers can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid server ID format
    ///
    /// Note: This does not verify server existence or state, as servers
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of server UUIDs to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No server IDs provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate server ID format (should be UUID format)
        for serverID in resourceIDs {
            if serverID.isEmpty {
                errors.append("Empty server ID in deletion list")
            } else if serverID.count < 32 {
                warnings.append("Server ID '\(serverID)' appears to be invalid format")
            }
        }

        // Check for duplicates
        let uniqueIDs = Set(resourceIDs)
        if uniqueIDs.count < resourceIDs.count {
            warnings.append("Duplicate server IDs detected - will be processed once")
        }

        Logger.shared.logDebug(
            "ServersModule+BatchOperations - Validation completed",
            context: [
                "serverCount": resourceIDs.count,
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
