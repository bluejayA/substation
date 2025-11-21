// Sources/Substation/Modules/Barbican/Extensions/BarbicanModule+BatchOperations.swift
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

/// Batch operation support for BarbicanModule
///
/// This extension enables the BarbicanModule to participate in batch operations,
/// particularly bulk deletion of secrets. Secrets are given a high deletion
/// priority (8) because they should typically be deleted late in the process,
/// after resources that may depend on them have been removed.
///
/// ## Deletion Priority
///
/// Secrets have priority 8 (delete late) because:
/// - Other resources may reference secrets for authentication or encryption
/// - Servers may use secrets for configuration or credentials
/// - Deleting secrets first could cause dependent resources to fail
/// - Late deletion ensures clean teardown without breaking dependencies
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension BarbicanModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for Barbican secrets
    ///
    /// Currently supports:
    /// - `barbicanSecretBulkDelete`: Bulk deletion of multiple secrets
    ///
    /// Future operations may include:
    /// - `barbicanSecretBulkUpdate`: Update metadata on multiple secrets
    public var supportedBatchOperationTypes: Set<String> {
        return ["barbicanSecretBulkDelete"]
    }

    /// Deletion priority for Barbican secrets
    ///
    /// Returns 8 (low priority - delete late) because secrets may be
    /// referenced by other resources:
    /// - Servers may use secrets for credentials or configuration
    /// - Applications may depend on secrets for encryption keys
    /// - Other services may reference secrets for authentication
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// secrets are removed after resources that may depend on them.
    public var deletionPriority: Int {
        return 8
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of Barbican secrets
    ///
    /// Deletes multiple secrets in sequence, tracking individual results.
    /// Each secret deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a secret is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let secretIDs = ["secret-1", "secret-2", "secret-3"]
    /// let results = await barbicanModule.executeBatchDelete(
    ///     resourceIDs: secretIDs,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted secret: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of secret UUIDs to delete
    ///   - client: OSClient instance for making Barbican API calls
    /// - Returns: Array of individual operation results, one per secret ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "BarbicanModule+BatchOperations - Starting batch delete",
            context: ["secretCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for secretID in resourceIDs {
            Logger.shared.logDebug(
                "BarbicanModule+BatchOperations - Deleting secret",
                context: ["secretID": secretID]
            )

            do {
                try await client.barbican.deleteSecret(id: secretID)

                Logger.shared.logDebug(
                    "BarbicanModule+BatchOperations - Secret deleted successfully",
                    context: ["secretID": secretID]
                )

                results.append(.success(resourceID: secretID))

            } catch let error as OpenStackError {
                // Treat 404 as success - secret already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "BarbicanModule+BatchOperations - Secret already deleted (404)",
                        context: ["secretID": secretID]
                    )
                    results.append(.success(resourceID: secretID))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "BarbicanModule+BatchOperations - Failed to delete secret",
                        context: [
                            "secretID": secretID,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: secretID, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "BarbicanModule+BatchOperations - Unexpected error deleting secret",
                    context: [
                        "secretID": secretID,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: secretID, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "BarbicanModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate secrets before batch deletion
    ///
    /// Performs pre-flight validation to ensure secrets can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid secret ID format
    ///
    /// Note: This does not verify secret existence or state, as secrets
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of secret UUIDs to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No secret IDs provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate secret ID format (should be UUID format)
        for secretID in resourceIDs {
            if secretID.isEmpty {
                errors.append("Empty secret ID in deletion list")
            } else if secretID.count < 32 {
                warnings.append("Secret ID '\(secretID)' appears to be invalid format")
            }
        }

        // Check for duplicates
        let uniqueIDs = Set(resourceIDs)
        if uniqueIDs.count < resourceIDs.count {
            warnings.append("Duplicate secret IDs detected - will be processed once")
        }

        Logger.shared.logDebug(
            "BarbicanModule+BatchOperations - Validation completed",
            context: [
                "secretCount": resourceIDs.count,
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
