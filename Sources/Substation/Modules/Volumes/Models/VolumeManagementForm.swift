import OSClient

// MARK: - Volume Management Form
//
// This form manages the state for volume attachment operations.
// It tracks available servers, pending attachments, and the current operation mode.
// Navigation state (selectedIndex, scrollOffset) is managed by TUI.viewCoordinator.

/// Form state for managing volume server attachments
///
/// This struct holds the data and state for the volume management view,
/// which allows users to view current attachments and attach volumes to servers.
/// Navigation index is managed externally by `TUI.viewCoordinator.selectedIndex`
/// to integrate with the core navigation system.
struct VolumeManagementForm {
    /// The volume being managed
    var selectedVolume: Volume?

    /// All available servers that can be attached to
    var availableServers: [Server] = []

    /// Current operation mode (view or attach)
    var selectedOperation: VolumeOperation = .view

    /// Server IDs selected for pending attachment
    var pendingAttachments: Set<String> = []

    /// Loading state indicator
    var isLoading: Bool = false

    /// Error message to display
    var errorMessage: String?

    /// Available operations for volume management
    enum VolumeOperation: CaseIterable {
        /// View current server attachments
        case view
        /// Attach volume to a server
        case attach

        /// Display title for the operation
        var title: String {
            switch self {
            case .view: return "View Current"
            case .attach: return "Attach to Server"
            }
        }
    }

    /// Reset the form to its initial state
    ///
    /// Clears all pending attachments and resets to view mode.
    /// Note: This does not reset viewCoordinator.selectedIndex which is managed externally.
    mutating func reset() {
        selectedOperation = .view
        pendingAttachments.removeAll()
        isLoading = false
        errorMessage = nil
    }

    /// Toggle server selection for attachment
    ///
    /// In attach mode, this toggles the server in the pending attachments set.
    /// Only one server can be selected at a time due to OpenStack volume limitations.
    /// In view mode, this operation is ignored.
    ///
    /// - Parameter serverID: The ID of the server to toggle
    mutating func toggleServer(_ serverID: String) {
        switch selectedOperation {
        case .attach:
            if pendingAttachments.contains(serverID) {
                pendingAttachments.remove(serverID)
            } else {
                // Only allow one server attachment for volumes
                pendingAttachments.removeAll()
                pendingAttachments.insert(serverID)
            }
        case .view:
            break // No toggling in view mode
        }
    }

    /// Check if a server is currently selected
    ///
    /// In attach mode, checks if server is in pending attachments.
    /// In view mode, checks if server is currently attached to the volume.
    ///
    /// - Parameter serverID: The ID of the server to check
    /// - Returns: True if the server is selected
    func isServerSelected(_ serverID: String) -> Bool {
        switch selectedOperation {
        case .attach:
            return pendingAttachments.contains(serverID)
        case .view:
            // In view mode, show current attachments
            return selectedVolume?.attachments?.contains { $0.serverId == serverID } ?? false
        }
    }

    /// Check if a server currently has this volume attached
    ///
    /// - Parameter serverID: The ID of the server to check
    /// - Returns: True if the volume is attached to the server
    func isServerCurrentlyAttached(_ serverID: String) -> Bool {
        return selectedVolume?.attachments?.contains { $0.serverId == serverID } ?? false
    }

    /// Get servers available for attachment
    ///
    /// Returns all available servers if the volume is not attached.
    /// Returns empty array if volume is already attached (OpenStack limitation).
    ///
    /// - Returns: Array of servers available for attachment
    func getAvailableServersForAttach() -> [Server] {
        guard let volume = selectedVolume else { return [] }

        // Volume is not attached, can attach to any server
        if volume.attachments?.isEmpty ?? true {
            return availableServers
        }

        // Volume is already attached, can't attach to more servers (OpenStack limitation)
        return []
    }

    /// Check if there are pending changes to apply
    ///
    /// - Returns: True if there are servers selected for attachment
    func hasPendingChanges() -> Bool {
        return !pendingAttachments.isEmpty
    }

    /// Get the current list of servers to display based on operation mode
    ///
    /// In view mode, returns servers that have the volume attached.
    /// In attach mode, returns servers available for attachment.
    ///
    /// - Returns: Array of servers to display
    func getCurrentDisplayItems() -> [Server] {
        switch selectedOperation {
        case .view:
            // Show servers that have this volume attached
            guard let volume = selectedVolume else { return [] }
            let attachedServerIDs = Set(volume.attachments?.compactMap { $0.serverId } ?? [])
            return availableServers.filter { attachedServerIDs.contains($0.id) }
        case .attach:
            return getAvailableServersForAttach()
        }
    }

    /// Get a human-readable status string for the volume
    ///
    /// - Returns: Status string describing the volume's attachment state
    func getVolumeStatus() -> String {
        guard let volume = selectedVolume else { return "No volume selected" }

        if volume.attachments?.isEmpty ?? true {
            return "Available (not attached)"
        } else {
            return "In-use (attached to \(volume.attachments?.count ?? 0) server(s))"
        }
    }

    /// Get attachment information for display
    ///
    /// - Returns: String describing current attachments, or nil if not attached
    func getAttachmentInfo() -> String? {
        guard let volume = selectedVolume, !(volume.attachments?.isEmpty ?? true) else { return nil }

        let attachments = volume.attachments ?? []
        if attachments.count == 1 {
            let attachment = attachments[0]
            let serverName = availableServers.first { $0.id == attachment.serverId }?.name ?? "Unknown Server"
            let device = attachment.device ?? "unknown device"
            return "Attached to: \(serverName) (device: \(device))"
        } else {
            return "Attached to \(attachments.count) servers"
        }
    }
}