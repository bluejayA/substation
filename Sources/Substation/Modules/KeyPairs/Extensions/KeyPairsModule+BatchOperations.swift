// Sources/Substation/Modules/KeyPairs/Extensions/KeyPairsModule+BatchOperations.swift
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

/// Batch operation support for KeyPairsModule
///
/// This extension enables the KeyPairsModule to participate in batch operations,
/// particularly bulk deletion of SSH key pairs. Key pairs are given the lowest
/// deletion priority (9) because they are system-level resources that should be
/// deleted after all other resources that may reference them.
///
/// ## Deletion Priority
///
/// Key pairs have priority 9 (lowest) because:
/// - Key pairs are referenced by servers during creation
/// - Key pairs are often shared across multiple servers
/// - Deleting key pairs does not affect running servers (keys are injected at boot)
/// - Key pairs should be retained until all dependent resources are cleaned up
///
/// ## Key Pair Identification
///
/// Unlike most OpenStack resources that use UUIDs, key pairs are identified by
/// their name. The batch delete operation accepts key pair names as resource IDs.
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension KeyPairsModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for key pairs
    ///
    /// Currently supports:
    /// - `keyPairBulkDelete`: Bulk deletion of multiple SSH key pairs
    ///
    /// Future operations may include:
    /// - `keyPairBulkExport`: Export multiple key pairs
    public var supportedBatchOperationTypes: Set<String> {
        return ["keyPairBulkDelete"]
    }

    /// Deletion priority for key pairs
    ///
    /// Returns 9 (lowest priority) because key pairs are system resources
    /// that should be deleted last:
    /// - Key pairs are referenced at server creation time
    /// - Key pairs can be shared across multiple servers
    /// - Deleting key pairs prematurely does not break running servers
    ///   but may cause issues with automation and new server creation
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// key pairs are removed only after servers, networks, volumes, and
    /// other dependent resources have been cleaned up.
    public var deletionPriority: Int {
        return 9
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of SSH key pairs
    ///
    /// Deletes multiple key pairs in sequence, tracking individual results.
    /// Each key pair deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a key pair is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Important Note
    ///
    /// Key pairs are identified by name, not UUID. The `resourceIDs` parameter
    /// should contain key pair names, not UUIDs.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let keyPairNames = ["my-keypair", "test-keypair", "dev-keypair"]
    /// let results = await keyPairsModule.executeBatchDelete(
    ///     resourceIDs: keyPairNames,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted key pair: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of key pair names to delete
    ///   - client: OSClient instance for making Nova API calls
    /// - Returns: Array of individual operation results, one per key pair name
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "KeyPairsModule+BatchOperations - Starting batch delete",
            context: ["keyPairCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for keyPairName in resourceIDs {
            Logger.shared.logDebug(
                "KeyPairsModule+BatchOperations - Deleting key pair",
                context: ["keyPairName": keyPairName]
            )

            do {
                try await client.deleteKeyPair(name: keyPairName)

                Logger.shared.logDebug(
                    "KeyPairsModule+BatchOperations - Key pair deleted successfully",
                    context: ["keyPairName": keyPairName]
                )

                results.append(.success(resourceID: keyPairName))

            } catch let error as OpenStackError {
                // Treat 404 as success - key pair already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "KeyPairsModule+BatchOperations - Key pair already deleted (404)",
                        context: ["keyPairName": keyPairName]
                    )
                    results.append(.success(resourceID: keyPairName))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "KeyPairsModule+BatchOperations - Failed to delete key pair",
                        context: [
                            "keyPairName": keyPairName,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: keyPairName, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "KeyPairsModule+BatchOperations - Unexpected error deleting key pair",
                    context: [
                        "keyPairName": keyPairName,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: keyPairName, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "KeyPairsModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate key pairs before batch deletion
    ///
    /// Performs pre-flight validation to ensure key pairs can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid key pair name format
    ///
    /// Note: This does not verify key pair existence or state, as key pairs
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of key pair names to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No key pair names provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate key pair name format
        for keyPairName in resourceIDs {
            if keyPairName.isEmpty {
                errors.append("Empty key pair name in deletion list")
            } else if keyPairName.contains(" ") {
                warnings.append("Key pair name '\(keyPairName)' contains spaces - may be invalid")
            } else if keyPairName.count > 255 {
                warnings.append("Key pair name '\(keyPairName)' exceeds 255 characters - may be invalid")
            }
        }

        // Check for duplicates
        let uniqueNames = Set(resourceIDs)
        if uniqueNames.count < resourceIDs.count {
            warnings.append("Duplicate key pair names detected - will be processed once")
        }

        Logger.shared.logDebug(
            "KeyPairsModule+BatchOperations - Validation completed",
            context: [
                "keyPairCount": resourceIDs.count,
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
