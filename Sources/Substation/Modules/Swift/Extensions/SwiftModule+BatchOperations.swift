// Sources/Substation/Modules/Swift/Extensions/SwiftModule+BatchOperations.swift
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

/// Batch operation support for SwiftModule
///
/// This extension enables the SwiftModule to participate in batch operations,
/// particularly bulk deletion of Swift containers and objects. Swift containers
/// are given a high deletion priority (8) because they should be deleted late
/// in the deletion sequence since other resources do not typically depend on them.
///
/// ## Deletion Priority
///
/// Swift containers have priority 8 (late deletion) because:
/// - Swift containers are standalone storage resources
/// - No other OpenStack resources depend on Swift containers
/// - Containers can only be deleted when empty
/// - Deleting containers late allows any dependent cleanup to occur first
///
/// ## Container vs Object Deletion
///
/// This module supports two batch operation types:
/// - `swiftContainerBulkDelete`: Delete multiple containers by name
/// - `swiftObjectBulkDelete`: Delete multiple objects (requires container context)
///
/// Note: Swift uses container and object names, not UUIDs like other OpenStack
/// services. For object deletion, the resource ID format is "containerName/objectName".
///
/// ## Idempotent Deletion
///
/// The batch delete operations treat 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension SwiftModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for Swift
    ///
    /// Currently supports:
    /// - `swiftContainerBulkDelete`: Bulk deletion of multiple containers
    /// - `swiftObjectBulkDelete`: Bulk deletion of multiple objects
    ///
    /// Future operations may include:
    /// - `swiftContainerBulkCreate`: Create multiple containers
    /// - `swiftObjectBulkUpload`: Upload multiple objects
    public var supportedBatchOperationTypes: Set<String> {
        return ["swiftContainerBulkDelete", "swiftObjectBulkDelete"]
    }

    /// Deletion priority for Swift containers
    ///
    /// Returns 8 (late priority) because Swift containers:
    /// - Are independent storage resources
    /// - No compute or network resources depend on them
    /// - Should be deleted after servers, volumes, and networks
    /// - May contain data that should be preserved until other cleanup completes
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// Swift containers are removed after compute and network resources
    /// have been cleaned up.
    public var deletionPriority: Int {
        return 8
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of Swift containers
    ///
    /// Deletes multiple containers in sequence, tracking individual results.
    /// Each container deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if a container is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let containerNames = ["backup-2024", "logs-old", "temp-data"]
    /// let results = await swiftModule.executeBatchDelete(
    ///     resourceIDs: containerNames,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted container: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of container names to delete
    ///   - client: OSClient instance for making Swift API calls
    /// - Returns: Array of individual operation results, one per container name
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "SwiftModule+BatchOperations - Starting batch delete",
            context: ["containerCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for containerName in resourceIDs {
            Logger.shared.logDebug(
                "SwiftModule+BatchOperations - Deleting container",
                context: ["containerName": containerName]
            )

            do {
                try await client.swift.deleteContainer(containerName: containerName)

                Logger.shared.logDebug(
                    "SwiftModule+BatchOperations - Container deleted successfully",
                    context: ["containerName": containerName]
                )

                results.append(.success(resourceID: containerName))

            } catch let error as OpenStackError {
                // Treat 404 as success - container already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "SwiftModule+BatchOperations - Container already deleted (404)",
                        context: ["containerName": containerName]
                    )
                    results.append(.success(resourceID: containerName))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "SwiftModule+BatchOperations - Failed to delete container",
                        context: [
                            "containerName": containerName,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: containerName, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "SwiftModule+BatchOperations - Unexpected error deleting container",
                    context: [
                        "containerName": containerName,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: containerName, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "SwiftModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate Swift containers before batch deletion
    ///
    /// Performs pre-flight validation to ensure containers can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid container name format
    ///
    /// Note: This does not verify container existence, emptiness, or ACLs,
    /// as containers may be deleted concurrently and 404 errors are handled
    /// as success. Containers must be empty to delete successfully.
    ///
    /// - Parameter resourceIDs: Array of container names to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No container names provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate container name format
        for containerName in resourceIDs {
            if containerName.isEmpty {
                errors.append("Empty container name in deletion list")
            } else if containerName.contains("/") {
                // Container names cannot contain slashes
                errors.append("Container name '\(containerName)' contains invalid character '/'")
            } else if containerName.count > 256 {
                // Swift container names have a max length
                warnings.append("Container name '\(containerName)' exceeds recommended length")
            }
        }

        // Check for duplicates
        let uniqueNames = Set(resourceIDs)
        if uniqueNames.count < resourceIDs.count {
            warnings.append("Duplicate container names detected - will be processed once")
        }

        // Add warning about non-empty containers
        if errors.isEmpty {
            warnings.append("Containers must be empty before deletion - non-empty containers will fail")
        }

        Logger.shared.logDebug(
            "SwiftModule+BatchOperations - Validation completed",
            context: [
                "containerCount": resourceIDs.count,
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
