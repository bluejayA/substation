// Sources/Substation/Modules/Images/Extensions/ImagesModule+BatchOperations.swift
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

/// Batch operation support for ImagesModule
///
/// This extension enables the ImagesModule to participate in batch operations,
/// particularly bulk deletion of image resources. Images are given the lowest
/// deletion priority (9) because they are system-level resources that other
/// resources may depend on.
///
/// ## Deletion Priority
///
/// Images have priority 9 (lowest) because:
/// - Images are base system resources used by servers and volumes
/// - Images should only be deleted after all dependent resources are removed
/// - Deleting images first could leave servers in an inconsistent state
/// - Snapshot images may be referenced by other images or volumes
///
/// ## Idempotent Deletion
///
/// The batch delete operation treats 404 (Not Found) errors as successful
/// deletions. This ensures idempotent behavior where:
/// - Retrying a failed batch operation is safe
/// - Concurrent deletion attempts do not cause failures
/// - Resources deleted by other processes are handled gracefully
extension ImagesModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for images
    ///
    /// Currently supports:
    /// - `imageBulkDelete`: Bulk deletion of multiple images
    ///
    /// Future operations may include:
    /// - `imageBulkDeactivate`: Deactivate multiple images
    /// - `imageBulkReactivate`: Reactivate multiple images
    /// - `imageBulkUpdateVisibility`: Update visibility for multiple images
    public var supportedBatchOperationTypes: Set<String> {
        return ["imageBulkDelete"]
    }

    /// Deletion priority for images
    ///
    /// Returns 9 (lowest priority) because images are system-level resources
    /// that other resources depend on:
    /// - Servers are created from images
    /// - Volume snapshots may be stored as images
    /// - Other images may be based on these images
    ///
    /// This ensures that when performing cross-module batch deletions,
    /// images are removed last after all dependent resources like servers
    /// and volumes have been deleted.
    public var deletionPriority: Int {
        return 9
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch deletion of image resources
    ///
    /// Deletes multiple images in sequence, tracking individual results.
    /// Each image deletion is independent, so partial failures are possible.
    ///
    /// The operation is idempotent: if an image is already deleted (404 error),
    /// the operation is reported as successful. This allows safe retries and
    /// handles race conditions with concurrent deletion attempts.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let imageIDs = ["image-1", "image-2", "image-3"]
    /// let results = await imagesModule.executeBatchDelete(
    ///     resourceIDs: imageIDs,
    ///     client: client
    /// )
    ///
    /// for result in results {
    ///     if result.success {
    ///         print("Deleted image: \(result.resourceID)")
    ///     } else {
    ///         print("Failed to delete \(result.resourceID): \(result.error ?? "Unknown error")")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of image UUIDs to delete
    ///   - client: OSClient instance for making Glance API calls
    /// - Returns: Array of individual operation results, one per image ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        Logger.shared.logInfo(
            "ImagesModule+BatchOperations - Starting batch delete",
            context: ["imageCount": resourceIDs.count]
        )

        var results: [IndividualOperationResult] = []

        for imageID in resourceIDs {
            Logger.shared.logDebug(
                "ImagesModule+BatchOperations - Deleting image",
                context: ["imageID": imageID]
            )

            do {
                try await client.deleteImage(id: imageID)

                Logger.shared.logDebug(
                    "ImagesModule+BatchOperations - Image deleted successfully",
                    context: ["imageID": imageID]
                )

                results.append(.success(resourceID: imageID))

            } catch let error as OpenStackError {
                // Treat 404 as success - image already deleted (idempotent behavior)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "ImagesModule+BatchOperations - Image already deleted (404)",
                        context: ["imageID": imageID]
                    )
                    results.append(.success(resourceID: imageID))
                } else {
                    // Log and record the failure
                    let errorMessage = error.localizedDescription
                    Logger.shared.logError(
                        "ImagesModule+BatchOperations - Failed to delete image",
                        context: [
                            "imageID": imageID,
                            "error": errorMessage
                        ]
                    )
                    results.append(.failure(resourceID: imageID, error: errorMessage))
                }

            } catch {
                // Handle unexpected errors
                let errorMessage = error.localizedDescription
                Logger.shared.logError(
                    "ImagesModule+BatchOperations - Unexpected error deleting image",
                    context: [
                        "imageID": imageID,
                        "error": errorMessage
                    ]
                )
                results.append(.failure(resourceID: imageID, error: errorMessage))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        Logger.shared.logInfo(
            "ImagesModule+BatchOperations - Batch delete completed",
            context: [
                "total": results.count,
                "succeeded": successCount,
                "failed": failureCount
            ]
        )

        return results
    }

    /// Validate images before batch deletion
    ///
    /// Performs pre-flight validation to ensure images can be deleted.
    /// This checks for:
    /// - Non-empty resource ID list
    /// - Valid image ID format
    ///
    /// Note: This does not verify image existence or state, as images
    /// may be deleted concurrently and 404 errors are handled as success.
    ///
    /// - Parameter resourceIDs: Array of image UUIDs to validate
    /// - Returns: Validation result with any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty input
        if resourceIDs.isEmpty {
            errors.append("No image IDs provided for deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate image ID format (should be UUID format)
        for imageID in resourceIDs {
            if imageID.isEmpty {
                errors.append("Empty image ID in deletion list")
            } else if imageID.count < 32 {
                warnings.append("Image ID '\(imageID)' appears to be invalid format")
            }
        }

        // Check for duplicates
        let uniqueIDs = Set(resourceIDs)
        if uniqueIDs.count < resourceIDs.count {
            warnings.append("Duplicate image IDs detected - will be processed once")
        }

        Logger.shared.logDebug(
            "ImagesModule+BatchOperations - Validation completed",
            context: [
                "imageCount": resourceIDs.count,
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
