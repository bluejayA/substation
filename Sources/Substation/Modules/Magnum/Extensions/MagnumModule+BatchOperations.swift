// Sources/Substation/Modules/Magnum/Extensions/MagnumModule+BatchOperations.swift
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

/// Extension providing batch operation support for MagnumModule
///
/// This extension enables bulk Magnum operations including batch deletion
/// of clusters and cluster templates with proper error handling and
/// idempotent behavior. Clusters are assigned a deletion priority of 4
/// (early deletion) because they are high-level resources that don't
/// have direct dependencies from other OpenStack resources.
///
/// ## Supported Operations
///
/// - `clusterBulkDelete`: Delete multiple clusters in a batch
/// - `clusterTemplateBulkDelete`: Delete multiple cluster templates in a batch
///
/// ## Error Handling
///
/// The batch delete operations treat HTTP 404 errors as success to ensure
/// idempotent behavior. This allows retry operations to succeed even if
/// the resource was already deleted.
extension MagnumModule: BatchOperationProvider {
    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for Magnum resources
    ///
    /// Currently supports:
    /// - `clusterBulkDelete`: Delete multiple clusters in a batch
    /// - `clusterTemplateBulkDelete`: Delete multiple cluster templates in a batch
    var supportedBatchOperationTypes: Set<String> {
        ["clusterBulkDelete", "clusterTemplateBulkDelete"]
    }

    /// Deletion priority for dependency ordering
    ///
    /// Clusters have priority 4 (early deletion) because they are
    /// high-level resources managed by Magnum and don't have direct
    /// dependencies from other OpenStack resources.
    var deletionPriority: Int { 4 }

    // MARK: - Batch Delete Implementation

    /// Execute batch deletion of Magnum resources
    ///
    /// Deletes multiple resources by their IDs. Each deletion is tracked
    /// individually and HTTP 404 errors are treated as success for
    /// idempotent behavior.
    ///
    /// The method determines whether to delete clusters or cluster templates
    /// based on the current view mode.
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of resource IDs to delete
    ///   - client: OSClient instance for making API calls
    /// - Returns: Array of individual operation results, one per resource ID
    func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        guard let tui = tui else {
            return resourceIDs.map {
                IndividualOperationResult.failure(resourceID: $0, error: "TUI reference unavailable")
            }
        }

        // Determine whether we're deleting clusters or templates based on view
        let currentView = tui.viewCoordinator.currentView
        if currentView == .clusterTemplates {
            return await executeBatchDeleteClusterTemplates(resourceIDs: resourceIDs, client: client)
        } else {
            return await executeBatchDeleteClusters(resourceIDs: resourceIDs, client: client)
        }
    }

    /// Execute batch deletion of clusters
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of cluster UUIDs to delete
    ///   - client: OSClient instance for making API calls
    /// - Returns: Array of individual operation results
    private func executeBatchDeleteClusters(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        var results: [IndividualOperationResult] = []

        Logger.shared.logInfo(
            "MagnumModule - Starting batch delete for \(resourceIDs.count) clusters"
        )

        let magnumService = await client.magnum

        for clusterID in resourceIDs {
            do {
                Logger.shared.logDebug(
                    "MagnumModule - Deleting cluster: \(clusterID)"
                )

                try await magnumService.deleteCluster(id: clusterID)

                Logger.shared.logDebug(
                    "MagnumModule - Successfully initiated deletion for cluster: \(clusterID)"
                )

                results.append(.success(resourceID: clusterID))

                // Update cache
                if let tui = tui,
                   let index = tui.cacheManager.cachedClusters.firstIndex(where: { $0.uuid == clusterID }) {
                    tui.cacheManager.cachedClusters.remove(at: index)
                }

            } catch let error as OpenStackError {
                // Treat 404 as success - resource already deleted (idempotent)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "MagnumModule - Cluster \(clusterID) already deleted (404)"
                    )
                    results.append(.success(resourceID: clusterID))
                } else {
                    Logger.shared.logError(
                        "MagnumModule - Failed to delete cluster \(clusterID): \(error)"
                    )
                    results.append(.failure(
                        resourceID: clusterID,
                        error: error.localizedDescription
                    ))
                }
            } catch {
                Logger.shared.logError(
                    "MagnumModule - Unexpected error deleting cluster \(clusterID): \(error)"
                )
                results.append(.failure(
                    resourceID: clusterID,
                    error: error.localizedDescription
                ))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.filter { !$0.success }.count

        Logger.shared.logInfo(
            "MagnumModule - Cluster batch delete completed: \(successCount) succeeded, \(failureCount) failed"
        )

        return results
    }

    /// Execute batch deletion of cluster templates
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of cluster template UUIDs to delete
    ///   - client: OSClient instance for making API calls
    /// - Returns: Array of individual operation results
    private func executeBatchDeleteClusterTemplates(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        var results: [IndividualOperationResult] = []

        Logger.shared.logInfo(
            "MagnumModule - Starting batch delete for \(resourceIDs.count) cluster templates"
        )

        let magnumService = await client.magnum

        for templateID in resourceIDs {
            do {
                Logger.shared.logDebug(
                    "MagnumModule - Deleting cluster template: \(templateID)"
                )

                try await magnumService.deleteClusterTemplate(id: templateID)

                Logger.shared.logDebug(
                    "MagnumModule - Successfully deleted cluster template: \(templateID)"
                )

                results.append(.success(resourceID: templateID))

                // Update cache
                if let tui = tui,
                   let index = tui.cacheManager.cachedClusterTemplates.firstIndex(where: { $0.uuid == templateID }) {
                    tui.cacheManager.cachedClusterTemplates.remove(at: index)
                }

            } catch let error as OpenStackError {
                // Treat 404 as success - resource already deleted (idempotent)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "MagnumModule - Cluster template \(templateID) already deleted (404)"
                    )
                    results.append(.success(resourceID: templateID))
                } else {
                    Logger.shared.logError(
                        "MagnumModule - Failed to delete cluster template \(templateID): \(error)"
                    )
                    results.append(.failure(
                        resourceID: templateID,
                        error: error.localizedDescription
                    ))
                }
            } catch {
                Logger.shared.logError(
                    "MagnumModule - Unexpected error deleting cluster template \(templateID): \(error)"
                )
                results.append(.failure(
                    resourceID: templateID,
                    error: error.localizedDescription
                ))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.filter { !$0.success }.count

        Logger.shared.logInfo(
            "MagnumModule - Cluster template batch delete completed: \(successCount) succeeded, \(failureCount) failed"
        )

        return results
    }

    // MARK: - Batch Validation

    /// Validate resources before batch deletion
    ///
    /// Performs pre-flight validation to check that:
    /// - At least one resource ID is provided
    /// - Resource IDs appear to be valid UUIDs
    /// - Clusters are not in an in-progress state
    ///
    /// - Parameter resourceIDs: Array of resource IDs to validate
    /// - Returns: Validation result with any errors or warnings
    func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty resource list
        if resourceIDs.isEmpty {
            errors.append("No resource IDs provided for batch deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate UUID format for each resource ID
        for resourceID in resourceIDs {
            if UUID(uuidString: resourceID) == nil {
                warnings.append("Resource ID '\(resourceID)' may not be a valid UUID")
            }
        }

        // Check for clusters in progress (only if we're deleting clusters)
        if let tui = tui {
            let currentView = tui.viewCoordinator.currentView
            if currentView == .clusters || currentView == .clusterDetail {
                let clusters = tui.cacheManager.cachedClusters
                for resourceID in resourceIDs {
                    if let cluster = clusters.first(where: { $0.uuid == resourceID }) {
                        if let status = cluster.status?.uppercased() {
                            if status.contains("IN_PROGRESS") {
                                warnings.append(
                                    "Cluster '\(cluster.displayName)' has operation in progress"
                                )
                            }
                            if status.contains("DELETE") {
                                warnings.append(
                                    "Cluster '\(cluster.displayName)' is already being deleted"
                                )
                            }
                        }
                    }
                }
            }

            // Check for cluster templates in use
            if currentView == .clusterTemplates {
                let templates = tui.cacheManager.cachedClusterTemplates
                let clusters = tui.cacheManager.cachedClusters

                for resourceID in resourceIDs {
                    if let template = templates.first(where: { $0.uuid == resourceID }) {
                        // Check if any clusters are using this template
                        let usingClusters = clusters.filter { $0.clusterTemplateId == template.uuid }
                        if !usingClusters.isEmpty {
                            let clusterNames = usingClusters.map { $0.displayName }.joined(separator: ", ")
                            warnings.append(
                                "Template '\(template.displayName)' is in use by clusters: \(clusterNames)"
                            )
                        }
                    }
                }
            }
        }

        Logger.shared.logDebug(
            "MagnumModule - Batch validation completed: \(errors.count) errors, \(warnings.count) warnings"
        )

        return BatchOperationValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}
