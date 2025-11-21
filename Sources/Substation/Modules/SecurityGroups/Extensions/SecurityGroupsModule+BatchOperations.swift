// Sources/Substation/Modules/SecurityGroups/Extensions/SecurityGroupsModule+BatchOperations.swift
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

/// Batch operation support for SecurityGroupsModule
///
/// This extension enables the SecurityGroupsModule to participate in batch operations,
/// particularly bulk deletion of security groups. Security groups are given a high
/// deletion priority (8) because they should be deleted late in the dependency chain,
/// after servers and ports that may reference them have been removed.
///
/// ## Deletion Priority
///
/// Security groups have priority 8 (late deletion) because:
/// - Servers must be deleted before their associated security groups
/// - Ports must be detached before security groups can be removed
/// - Security group rules are automatically deleted with the group
/// - Deleting security groups last ensures no active references remain
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension SecurityGroupsModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for security groups
    ///
    /// Currently supports:
    /// - `securityGroupBulkDelete`: Bulk deletion of multiple security groups
    ///
    /// Future operations may include:
    /// - `securityGroupBulkClone`: Clone multiple security groups
    /// - `securityGroupBulkExport`: Export security group configurations
    public var supportedBatchOperationTypes: Set<String> {
        return ["securityGroupBulkDelete"]
    }

    /// Deletion priority for security groups
    ///
    /// Returns 8 (late priority) because security groups must be deleted after
    /// resources that reference them:
    /// - Servers with security group associations
    /// - Ports bound to security groups
    /// - Other network resources referencing security groups
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// security groups are removed only after servers, ports, and other
    /// dependent resources have been deleted.
    public var deletionPriority: Int {
        return 8
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of security groups
    ///
    /// Deletes multiple security groups in sequence, tracking individual results.
    /// Each security group deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a security group is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let securityGroupIDs = ["sg-1", "sg-2", "sg-3"]
    /// let results = await securityGroupsModule.executeBatchDelete(
    ///     resourceIDs: securityGroupIDs,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted security group: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of security group UUIDs to delete
    ///   - client: OSClient instance for making Neutron API calls
    /// - Returns: Array of individual operation results, one per security group ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "SecurityGroupsModule+BatchOperations - Starting batch delete",
            context: ["securityGroupCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for securityGroupID in resourceIDs {
            Logger.shared.logDebug(
                "SecurityGroupsModule+BatchOperations - Deleting security group",
                context: ["securityGroupID": securityGroupID]
            )

            do {
                try await client.deleteSecurityGroup(id: securityGroupID)

                Logger.shared.logDebug(
                    "SecurityGroupsModule+BatchOperations - Security group deleted successfully",
                    context: ["securityGroupID": securityGroupID]
                )

                results.append(.success(resourceID: securityGroupID))

            } catch let error as OpenStackError {
                // Treat 404 as success - security group already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "SecurityGroupsModule+BatchOperations - Security group already deleted (404)",
                        context: ["securityGroupID": securityGroupID]
                    )
                    results.append(.success(resourceID: securityGroupID))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "SecurityGroupsModule+BatchOperations - Failed to delete security group",
                        context: [
                            "securityGroupID": securityGroupID,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: securityGroupID, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "SecurityGroupsModule+BatchOperations - Unexpected error deleting security group",
                    context: [
                        "securityGroupID": securityGroupID,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: securityGroupID, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "SecurityGroupsModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate security groups before batch deletion
    ///
    /// Performs pre-flight validation to ensure security groups can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid security group ID format
    ///
    /// Note: This does not verify security group existence or state, as groups
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of security group UUIDs to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No security group IDs provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate security group ID format (should be UUID format)
        for securityGroupID in resourceIDs {
            if securityGroupID.isEmpty {
                errors.append("Empty security group ID in deletion list")
            } else if securityGroupID.count < 32 {
                warnings.append("Security group ID '\(securityGroupID)' appears to be invalid format")
            }
        }

        // Check for duplicates
        let uniqueIDs = Set(resourceIDs)
        if uniqueIDs.count < resourceIDs.count {
            warnings.append("Duplicate security group IDs detected - will be processed once")
        }

        Logger.shared.logDebug(
            "SecurityGroupsModule+BatchOperations - Validation completed",
            context: [
                "securityGroupCount": resourceIDs.count,
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
