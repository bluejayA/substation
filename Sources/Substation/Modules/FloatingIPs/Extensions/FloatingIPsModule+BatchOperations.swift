// Sources/Substation/Modules/FloatingIPs/Extensions/FloatingIPsModule+BatchOperations.swift
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

/// Batch operation support for FloatingIPsModule
///
/// This extension enables the FloatingIPsModule to participate in batch operations,
/// particularly bulk deletion of floating IP addresses. Floating IPs are given
/// deletion priority 4, which means they are deleted after ports but before
/// most other network resources.
///
/// ## Deletion Priority
///
/// Floating IPs have priority 4 because:
/// - They can be safely deleted after servers are removed
/// - They should be deleted after ports are disassociated
/// - They are independent resources that do not block other deletions
/// - Deleting them early frees up public IP addresses for reuse
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension FloatingIPsModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for floating IPs
    ///
    /// Currently supports:
    /// - `floatingIPBulkDelete`: Bulk deletion of multiple floating IPs
    ///
    /// Future operations may include:
    /// - `floatingIPBulkDisassociate`: Disassociate multiple floating IPs from servers
    /// - `floatingIPBulkAssociate`: Associate multiple floating IPs with ports
    public var supportedBatchOperationTypes: Set<String> {
        return ["floatingIPBulkDelete"]
    }

    /// Deletion priority for floating IPs
    ///
    /// Returns 4 (mid-high priority) because floating IPs should be deleted
    /// after servers and ports but before base network resources:
    /// - After servers (priority 1) that use them
    /// - After ports (priority 3) they may be associated with
    /// - Before networks that provide the external IP pool
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// floating IPs are released after the resources using them are removed.
    public var deletionPriority: Int {
        return 4
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of floating IP addresses
    ///
    /// Deletes multiple floating IPs in sequence, tracking individual results.
    /// Each floating IP deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a floating IP is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let floatingIPIDs = ["fip-1", "fip-2", "fip-3"]
    /// let results = await floatingIPsModule.executeBatchDelete(
    ///     resourceIDs: floatingIPIDs,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted floating IP: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of floating IP UUIDs to delete
    ///   - client: OSClient instance for making Neutron API calls
    /// - Returns: Array of individual operation results, one per floating IP ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "FloatingIPsModule+BatchOperations - Starting batch delete",
            context: ["floatingIPCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for floatingIPID in resourceIDs {
            Logger.shared.logDebug(
                "FloatingIPsModule+BatchOperations - Deleting floating IP",
                context: ["floatingIPID": floatingIPID]
            )

            do {
                try await client.deleteFloatingIP(id: floatingIPID)

                Logger.shared.logDebug(
                    "FloatingIPsModule+BatchOperations - Floating IP deleted successfully",
                    context: ["floatingIPID": floatingIPID]
                )

                results.append(.success(resourceID: floatingIPID))

            } catch let error as OpenStackError {
                // Treat 404 as success - floating IP already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "FloatingIPsModule+BatchOperations - Floating IP already deleted (404)",
                        context: ["floatingIPID": floatingIPID]
                    )
                    results.append(.success(resourceID: floatingIPID))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "FloatingIPsModule+BatchOperations - Failed to delete floating IP",
                        context: [
                            "floatingIPID": floatingIPID,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: floatingIPID, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "FloatingIPsModule+BatchOperations - Unexpected error deleting floating IP",
                    context: [
                        "floatingIPID": floatingIPID,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: floatingIPID, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "FloatingIPsModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate floating IPs before batch deletion
    ///
    /// Performs pre-flight validation to ensure floating IPs can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid floating IP ID format
    ///
    /// Note: This does not verify floating IP existence or state, as floating IPs
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of floating IP UUIDs to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No floating IP IDs provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate floating IP ID format (should be UUID format)
        for floatingIPID in resourceIDs {
            if floatingIPID.isEmpty {
                errors.append("Empty floating IP ID in deletion list")
            } else if floatingIPID.count < 32 {
                warnings.append("Floating IP ID '\(floatingIPID)' appears to be invalid format")
            }
        }

        // Check for duplicates
        let uniqueIDs = Set(resourceIDs)
        if uniqueIDs.count < resourceIDs.count {
            warnings.append("Duplicate floating IP IDs detected - will be processed once")
        }

        Logger.shared.logDebug(
            "FloatingIPsModule+BatchOperations - Validation completed",
            context: [
                "floatingIPCount": resourceIDs.count,
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
