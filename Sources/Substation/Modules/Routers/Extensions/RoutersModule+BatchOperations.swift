// Sources/Substation/Modules/Routers/Extensions/RoutersModule+BatchOperations.swift
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

/// Extension providing batch operation support for RoutersModule
///
/// This extension enables bulk router operations including batch deletion
/// with proper cleanup of interfaces and external gateways. Routers are
/// assigned a deletion priority of 5 (mid-level) because they must be
/// deleted after ports but before subnets.
///
/// ## Router Deletion Process
///
/// Before a router can be deleted, all attached resources must be removed:
/// 1. Remove all router interfaces (subnet detachments)
/// 2. Clear external gateway if present
/// 3. Delete the router itself
///
/// ## Dependency Ordering
///
/// Routers have priority 5 in the deletion order:
/// - Floating IPs (priority 3) - deleted first
/// - Ports (priority 4) - deleted before routers
/// - Routers (priority 5) - this module
/// - Subnets (priority 6) - deleted after routers
/// - Networks (priority 7) - deleted last
///
/// ## Error Handling
///
/// The batch delete operation treats HTTP 404 errors as success to ensure
/// idempotent behavior. This allows retry operations to succeed even if
/// the resource was already deleted.
extension RoutersModule: BatchOperationProvider {
    // MARK: - BatchOperationProvider Properties

    /// Supported batch operation types for routers
    ///
    /// Currently supports:
    /// - `routerBulkDelete`: Delete multiple routers in a batch
    var supportedBatchOperationTypes: Set<String> { ["routerBulkDelete"] }

    /// Deletion priority for dependency ordering
    ///
    /// Routers have priority 5 (mid-level) because they depend on networks
    /// but ports and floating IPs depend on them. They must be deleted
    /// after ports but before subnets and networks.
    var deletionPriority: Int { 5 }

    // MARK: - Batch Delete Implementation

    /// Execute batch deletion of routers
    ///
    /// Deletes multiple routers by their IDs with proper cleanup of
    /// interfaces and external gateways. Each deletion is tracked
    /// individually and HTTP 404 errors are treated as success for
    /// idempotent behavior.
    ///
    /// The deletion process for each router:
    /// 1. Fetch fresh router details with all current interfaces
    /// 2. Remove all router interfaces (by port ID or subnet ID)
    /// 3. Clear external gateway if present
    /// 4. Delete the router
    ///
    /// - Parameters:
    ///   - resourceIDs: Array of router IDs to delete
    ///   - client: OSClient instance for making API calls
    /// - Returns: Array of individual operation results, one per router ID
    func executeBatchDelete(
        resourceIDs: [String],
        client: OSClient
    ) async -> [IndividualOperationResult] {
        var results: [IndividualOperationResult] = []

        Logger.shared.logInfo(
            "RoutersModule - Starting batch delete for \(resourceIDs.count) routers"
        )

        for routerID in resourceIDs {
            do {
                Logger.shared.logDebug(
                    "RoutersModule - Deleting router: \(routerID)"
                )

                // Step 1: Fetch fresh router details to get all current interfaces
                let router = try await client.getRouter(id: routerID, forceRefresh: true)

                // Step 2: Remove all router interfaces (subnet detachments)
                if let interfaces = router.interfaces, !interfaces.isEmpty {
                    Logger.shared.logDebug(
                        "RoutersModule - Removing \(interfaces.count) router interfaces for \(routerID)"
                    )
                    for interface in interfaces {
                        do {
                            // Use port_id if available (more specific), otherwise subnet_id
                            if let portId = interface.portId {
                                try await client.removeRouterInterface(
                                    routerId: routerID,
                                    portId: portId
                                )
                            } else if let subnetId = interface.subnetId {
                                try await client.removeRouterInterface(
                                    routerId: routerID,
                                    subnetId: subnetId
                                )
                            }
                        } catch let interfaceError as OpenStackError {
                            // Treat 404 as success - interface already removed
                            if case .httpError(404, _) = interfaceError {
                                Logger.shared.logDebug(
                                    "RoutersModule - Router interface already removed (404)"
                                )
                            } else {
                                // Log but continue - try to delete anyway
                                Logger.shared.logWarning(
                                    "RoutersModule - Failed to remove router interface: \(interfaceError)"
                                )
                            }
                        }
                    }
                }

                // Step 3: Clear external gateway if present
                if router.externalGatewayInfo != nil {
                    Logger.shared.logDebug(
                        "RoutersModule - Clearing external gateway for router \(routerID)"
                    )
                    do {
                        let clearGatewayRequest = UpdateRouterRequest(
                            name: nil,
                            description: nil,
                            adminStateUp: nil,
                            externalGatewayInfo: nil,
                            routes: nil
                        )
                        _ = try await client.updateRouter(
                            id: routerID,
                            request: clearGatewayRequest
                        )
                    } catch let gatewayError as OpenStackError {
                        // Treat 404 as success - router may be gone
                        if case .httpError(404, _) = gatewayError {
                            Logger.shared.logDebug(
                                "RoutersModule - Router \(routerID) not found when clearing gateway (404)"
                            )
                        } else {
                            // Log but continue - try to delete anyway
                            Logger.shared.logWarning(
                                "RoutersModule - Failed to clear external gateway: \(gatewayError)"
                            )
                        }
                    }
                }

                // Step 4: Delete the router
                try await client.deleteRouter(id: routerID)

                Logger.shared.logDebug(
                    "RoutersModule - Successfully deleted router: \(routerID)"
                )

                results.append(.success(resourceID: routerID))

            } catch let error as OpenStackError {
                // Treat 404 as success - resource already deleted (idempotent)
                if case .httpError(404, _) = error {
                    Logger.shared.logDebug(
                        "RoutersModule - Router \(routerID) already deleted (404)"
                    )
                    results.append(.success(resourceID: routerID))
                } else {
                    Logger.shared.logError(
                        "RoutersModule - Failed to delete router \(routerID): \(error)"
                    )
                    results.append(.failure(
                        resourceID: routerID,
                        error: error.localizedDescription
                    ))
                }
            } catch {
                Logger.shared.logError(
                    "RoutersModule - Unexpected error deleting router \(routerID): \(error)"
                )
                results.append(.failure(
                    resourceID: routerID,
                    error: error.localizedDescription
                ))
            }
        }

        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.filter { !$0.success }.count

        Logger.shared.logInfo(
            "RoutersModule - Batch delete completed: \(successCount) succeeded, \(failureCount) failed"
        )

        return results
    }

    // MARK: - Batch Validation

    /// Validate routers before batch deletion
    ///
    /// Performs pre-flight validation to check that:
    /// - At least one router ID is provided
    /// - Router IDs appear to be valid UUIDs
    /// - Warns about routers with external gateways or multiple interfaces
    ///
    /// Note: Full dependency checking is performed during execution when
    /// the router details are fetched with forceRefresh.
    ///
    /// - Parameter resourceIDs: Array of router IDs to validate
    /// - Returns: Validation result with any errors or warnings
    func validateBatchOperation(
        resourceIDs: [String]
    ) async -> BatchOperationValidation {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for empty resource list
        if resourceIDs.isEmpty {
            errors.append("No router IDs provided for batch deletion")
            return BatchOperationValidation(
                isValid: false,
                errors: errors,
                warnings: warnings
            )
        }

        // Validate UUID format for each router ID
        for routerID in resourceIDs {
            if UUID(uuidString: routerID) == nil {
                warnings.append("Router ID '\(routerID)' may not be a valid UUID")
            }
        }

        // Check for potential issues with routers in cache
        if let tui = tui {
            let routers = tui.resourceCache.routers
            for routerID in resourceIDs {
                if let router = routers.first(where: { $0.id == routerID }) {
                    // Warn about routers with external gateways
                    if router.externalGatewayInfo != nil {
                        warnings.append(
                            "Router '\(router.name ?? routerID)' has an external gateway that will be cleared"
                        )
                    }

                    // Warn about routers with multiple interfaces
                    if let interfaces = router.interfaces, interfaces.count > 1 {
                        warnings.append(
                            "Router '\(router.name ?? routerID)' has \(interfaces.count) interfaces that will be removed"
                        )
                    }

                    // Warn about HA or distributed routers
                    if router.ha == true {
                        warnings.append(
                            "Router '\(router.name ?? routerID)' is a high-availability router"
                        )
                    }
                    if router.distributed == true {
                        warnings.append(
                            "Router '\(router.name ?? routerID)' is a distributed virtual router"
                        )
                    }
                }
            }
        }

        Logger.shared.logDebug(
            "RoutersModule - Batch validation completed: \(errors.count) errors, \(warnings.count) warnings"
        )

        return BatchOperationValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}
