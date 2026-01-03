// SelectionManager.swift
// Substation
//
// Manages multi-select and attachment selection state for TUI operations.

import Foundation

/// Manages multi-select and attachment selection state
/// Handles server, port, and router selection modes for resource management operations
@MainActor
final class SelectionManager {

    // MARK: - Multi-Select State

    /// Whether multi-select mode is active
    var multiSelectMode: Bool = false

    /// Set of selected resource IDs in multi-select mode
    var multiSelectedResourceIDs: Set<String> = []

    // MARK: - Server Attachment Selection

    /// Selected servers for batch operations
    var selectedServers: Set<String> = []

    /// Server IDs that already have attachments
    var attachedServerIds: Set<String> = []

    /// Current attachment mode (attach/detach)
    var attachmentMode: AttachmentMode = .attach

    // MARK: - Floating IP Management

    /// Currently selected server ID for floating IP assignment
    var selectedServerId: String?

    /// Server ID that currently has the floating IP attached
    var attachedServerId: String?

    /// Currently selected port ID for floating IP assignment
    var selectedPortId: String?

    /// Port ID that currently has the floating IP attached
    var attachedPortId: String?

    // MARK: - Subnet Router Management

    /// Currently selected router ID for subnet attachment
    var selectedRouterId: String?

    /// Router IDs that are already attached to the subnet
    var attachedRouterIds: Set<String> = []

    // MARK: - Router Subnet Management

    /// Currently selected subnet ID for router interface attachment
    var selectedSubnetId: String?

    /// Subnet IDs that are already attached to the router
    var attachedSubnetIds: Set<String> = []

    // MARK: - Convenience Methods

    /// Toggle multi-select mode on or off
    /// When disabled, clears all multi-select selections
    func toggleMultiSelect() {
        multiSelectMode.toggle()
        if !multiSelectMode {
            multiSelectedResourceIDs.removeAll()
        }
    }

    /// Clear all multi-select selections without disabling multi-select mode
    func clearMultiSelect() {
        multiSelectedResourceIDs.removeAll()
    }

    /// Toggle selection of a resource by ID
    /// - Parameter id: The resource ID to toggle
    func toggleSelection(id: String) {
        if multiSelectedResourceIDs.contains(id) {
            multiSelectedResourceIDs.remove(id)
        } else {
            multiSelectedResourceIDs.insert(id)
        }
    }

    /// Check if a resource is currently selected
    /// - Parameter id: The resource ID to check
    /// - Returns: True if the resource is selected
    func isSelected(id: String) -> Bool {
        return multiSelectedResourceIDs.contains(id)
    }

    /// Select all provided resource IDs
    /// - Parameter ids: Array of resource IDs to select
    func selectAll(ids: [String]) {
        multiSelectedResourceIDs = Set(ids)
    }

    /// Clear server selection state
    /// Resets selectedServers, selectedServerId, and attachedServerId
    func clearServerSelection() {
        selectedServers.removeAll()
        selectedServerId = nil
        attachedServerId = nil
    }

    /// Clear port selection state
    /// Resets selectedPortId and attachedPortId
    func clearPortSelection() {
        selectedPortId = nil
        attachedPortId = nil
    }

    /// Clear router selection state
    /// Resets selectedRouterId and attachedRouterIds
    func clearRouterSelection() {
        selectedRouterId = nil
        attachedRouterIds.removeAll()
    }

    /// Clear subnet selection state
    /// Resets selectedSubnetId and attachedSubnetIds
    func clearSubnetSelection() {
        selectedSubnetId = nil
        attachedSubnetIds.removeAll()
    }

    /// Reset all selection state to initial values
    /// Clears all multi-select, server, port, router, and subnet selections
    func resetAll() {
        multiSelectMode = false
        multiSelectedResourceIDs.removeAll()
        selectedServers.removeAll()
        attachedServerIds.removeAll()
        attachmentMode = .attach
        clearServerSelection()
        clearPortSelection()
        clearRouterSelection()
        clearSubnetSelection()
    }
}
