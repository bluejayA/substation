// Sources/Substation/Modules/Volumes/Extensions/VolumesModule+BatchOperations.swift
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

/// Extension providing batch operation support for VolumesModule
///
/// This extension enables the VolumesModule to participate in batch operations
/// such as bulk deletion of volumes and volume backups. The module handles
/// 404 errors gracefully as idempotent deletions (resource already deleted).
///
/// ## Deletion Priority
///
/// Volumes have a deletion priority of 2, which means they are deleted after
/// servers (priority 1) but before networks and other infrastructure resources.
/// This ordering is important because:
/// - Servers may have attached volumes that must be detached first
/// - Volume deletion should occur before subnet/network cleanup
///
/// ## Supported Operations
///
/// - `volumeBulkDelete`: Delete multiple volumes in parallel
/// - `volumeBackupBulkDelete`: Delete multiple volume backups in parallel
extension VolumesModule: BatchOperationProvider {

    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for the Volumes module
    ///
    /// Currently supports:
    /// - `volumeBulkDelete`: Bulk deletion of volumes
    /// - `volumeBackupBulkDelete`: Bulk deletion of volume backups
    public var supportedBatchOperationTypes: Set<String> {
        return ["volumeBulkDelete", "volumeBackupBulkDelete"]
    }

    /// Deletion priority for dependency ordering
    ///
    /// Volumes have priority 2, meaning they are deleted after servers (priority 1)
    /// but before most other infrastructure resources. This ensures:
    /// - Attached volumes are properly detached from servers first
    /// - Volume-dependent resources are cleaned up in correct order
    public var deletionPriority: Int {
        return 2
    }

    // MARK: - BatchOperationProvider Methods

    /// Execute batch delete operation for volumes
    ///
    /// Deletes multiple volumes or volume backups based on the operation type.
    /// Each deletion is processed individually and results are tracked per resource.
    /// HTTP 404 errors are treated as success (idempotent deletion - resource already gone).
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of volume or backup IDs to delete
    ///   - client: OSClient instance for making API calls
    /// - Returns: Array of individual operation results, one per resource ID
    public func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        var results: [IndividualOperationResult] = []

        Logger.shared.logInfo(
            "VolumesModule+BatchOperations - Starting batch delete for \(resourceIDs.count) resources"
        )

        for resourceID in resourceIDs {
            do {
                // Attempt to delete the volume
                try await client.deleteVolume(id: resourceID)

                Logger.shared.logDebug(
                    "VolumesModule+BatchOperations - Successfully deleted volume: \(resourceID)"
                )

                results.append(.success(resourceID: resourceID))

            } catch let error as OpenStackError {
                // Treat 404 as success - resource already deleted (idempotent)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "VolumesModule+BatchOperations - Volume \(resourceID) already deleted (404)"
                    )
                    results.append(.success(resourceID: resourceID))
                } else {
                    Logger.shared.logError(
                        "VolumesModule+BatchOperations - Failed to delete volume \(resourceID): \(error)"
                    )
                    results.append(.failure(resourceID: resourceID, error: error.localizedDescription))
                }

            } catch {
                Logger.shared.logError(
                    "VolumesModule+BatchOperations - Unexpected error deleting volume \(resourceID): \(error)"
                )
                results.append(.failure(resourceID: resourceID, error: error.localizedDescription))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount

        Logger.shared.logInfo(
            "VolumesModule+BatchOperations - Batch delete completed: \(successCount) succeeded, \(failureCount) failed"
        )

        return results
    }

    /// Execute batch delete operation for volume backups
    ///
    /// Deletes multiple volume backups. Each deletion is processed individually
    /// and results are tracked per backup. HTTP 404 errors are treated as success
    /// (idempotent deletion - backup already gone).
    ///
    /// - Parameters:
    ///   - backupIDs: Array of volume backup IDs to delete
    ///   - client: OSClient instance for making API calls
    /// - Returns: Array of individual operation results, one per backup ID
    public func executeBatchBackupDelete(
        backupIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        var results: [IndividualOperationResult] = []

        Logger.shared.logInfo(
            "VolumesModule+BatchOperations - Starting batch backup delete for \(backupIDs.count) backups"
        )

        for backupID in backupIDs {
            do {
                // Attempt to delete the volume backup
                try await client.deleteVolumeBackup(backupId: backupID)

                Logger.shared.logDebug(
                    "VolumesModule+BatchOperations - Successfully deleted volume backup: \(backupID)"
                )

                results.append(.success(resourceID: backupID))

            } catch let error as OpenStackError {
                // Treat 404 as success - backup already deleted (idempotent)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "VolumesModule+BatchOperations - Volume backup \(backupID) already deleted (404)"
                    )
                    results.append(.success(resourceID: backupID))
                } else {
                    Logger.shared.logError(
                        "VolumesModule+BatchOperations - Failed to delete volume backup \(backupID): \(error)"
                    )
                    results.append(.failure(resourceID: backupID, error: error.localizedDescription))
                }

            } catch {
                Logger.shared.logError(
                    "VolumesModule+BatchOperations - Unexpected error deleting volume backup \(backupID): \(error)"
                )
                results.append(.failure(resourceID: backupID, error: error.localizedDescription))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount

        Logger.shared.logInfo(
            "VolumesModule+BatchOperations - Batch backup delete completed: \(successCount) succeeded, \(failureCount) failed"
        )

        return results
    }

    /// Validate batch operation for volumes
    ///
    /// Performs pre-flight validation to ensure volume resources can be deleted.
    /// Checks for:
    /// - Non-empty resource list
    /// - Valid UUID format for resource IDs
    ///
    /// - Parameter resourceIDs: Array of volume IDs to validate
    /// - Returns: Validation result containing any errors or warnings
    public func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty resource list
        if resourceIDs.isEmpty {
            errors.append("No volume IDs provided for batch operation")
            return BatchOperationValidation(isValid: false, errors: errors, warnings: warnings)
        }

        // Validate UUID format for each resource ID
        let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        for resourceID in resourceIDs {
            if resourceID.range(of: uuidPattern, options: .regularExpression) == nil {
                warnings.append("Resource ID '\(resourceID)' may not be a valid UUID format")
            }
        }

        // Log validation result
        if errors.isEmpty {
            Logger.shared.logDebug(
                "VolumesModule+BatchOperations - Validation passed for \(resourceIDs.count) resources"
            )
        } else {
            Logger.shared.logWarning(
                "VolumesModule+BatchOperations - Validation failed: \(errors.joined(separator: ", "))"
            )
        }

        return BatchOperationValidation(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}
