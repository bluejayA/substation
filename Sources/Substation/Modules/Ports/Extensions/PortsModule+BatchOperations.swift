// Sources/Substation/Modules/Ports/Extensions/PortsModule+BatchOperations.swift
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

/// Batch operation support for PortsModule
///
/// This extension enables the PortsModule to participate in batch operations,
/// particularly bulk deletion of network ports. Ports are given a medium-high
/// deletion priority (3) because they should be deleted after servers and volumes
/// but before networks and routers.
///
/// ## Deletion Priority
///
/// Ports have priority 3 because:
/// - Ports must be deleted after servers that use them are removed
/// - Ports must be deleted after volumes are detached
/// - Ports should be deleted before networks can be deleted
/// - Ports should be deleted before routers can be cleaned up
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension PortsModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for ports
    ///
    /// Currently supports:
    /// - `portBulkDelete`: Bulk deletion of multiple ports
    ///
    /// Future operations may include:
    /// - `portBulkUpdate`: Update multiple ports
    /// - `portBulkSecurityGroupUpdate`: Update security groups on multiple ports
    public var supportedBatchOperationTypes: Set<String> {
        return ["portBulkDelete"]
    }

    /// Deletion priority for ports
    ///
    /// Returns 3 (medium-high priority) because ports must be deleted after
    /// servers and volumes but before networks:
    /// - Servers (priority 1) must be deleted first to release port attachments
    /// - Volumes (priority 2) should be detached before port cleanup
    /// - Ports (priority 3) are deleted after compute resources
    /// - Networks (higher priority) depend on all ports being deleted
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// ports are removed after servers but before networks and routers.
    public var deletionPriority: Int {
        return 3
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of network ports
    ///
    /// Deletes multiple ports in sequence, tracking individual results.
    /// Each port deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a port is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let portIDs = ["port-1", "port-2", "port-3"]
    /// let results = await portsModule.executeBatchDelete(
    ///     resourceIDs: portIDs,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted port: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of port UUIDs to delete
    ///   - client: OSClient instance for making Neutron API calls
    /// - Returns: Array of individual operation results, one per port ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "PortsModule+BatchOperations - Starting batch delete",
            context: ["portCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for portID in resourceIDs {
            Logger.shared.logDebug(
                "PortsModule+BatchOperations - Deleting port",
                context: ["portID": portID]
            )

            do {
                try await client.deletePort(id: portID)

                Logger.shared.logDebug(
                    "PortsModule+BatchOperations - Port deleted successfully",
                    context: ["portID": portID]
                )

                results.append(.success(resourceID: portID))

            } catch let error as OpenStackError {
                // Treat 404 as success - port already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "PortsModule+BatchOperations - Port already deleted (404)",
                        context: ["portID": portID]
                    )
                    results.append(.success(resourceID: portID))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "PortsModule+BatchOperations - Failed to delete port",
                        context: [
                            "portID": portID,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: portID, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "PortsModule+BatchOperations - Unexpected error deleting port",
                    context: [
                        "portID": portID,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: portID, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "PortsModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate ports before batch deletion
    ///
    /// Performs pre-flight validation to ensure ports can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid port ID format
    ///
    /// Note: This does not verify port existence or state, as ports
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of port UUIDs to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No port IDs provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate port ID format (should be UUID format)
        for portID in resourceIDs {
            if portID.isEmpty {
                errors.append("Empty port ID in deletion list")
            } else if portID.count < 32 {
                warnings.append("Port ID '\(portID)' appears to be invalid format")
            }
        }

        // Check for duplicates
        let uniqueIDs = Set(resourceIDs)
        if uniqueIDs.count < resourceIDs.count {
            warnings.append("Duplicate port IDs detected - will be processed once")
        }

        Logger.shared.logDebug(
            "PortsModule+BatchOperations - Validation completed",
            context: [
                "portCount": resourceIDs.count,
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
