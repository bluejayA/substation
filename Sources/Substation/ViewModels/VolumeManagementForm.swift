import OSClient

struct VolumeManagementForm {
    var selectedVolume: Volume?
    var availableServers: [Server] = []
    var selectedResourceIndex: Int = 0
    var selectedOperation: VolumeOperation = .view
    var pendingAttachments: Set<String> = [] // Server IDs to attach volume to
    var isLoading: Bool = false
    var errorMessage: String?

    enum VolumeOperation: CaseIterable {
        case view, attach

        var title: String {
            switch self {
            case .view: return "View Current"
            case .attach: return "Attach to Server"
            }
        }
    }

    mutating func reset() {
        selectedResourceIndex = 0
        selectedOperation = .view
        pendingAttachments.removeAll()
        isLoading = false
        errorMessage = nil
    }

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

    func isServerSelected(_ serverID: String) -> Bool {
        switch selectedOperation {
        case .attach:
            return pendingAttachments.contains(serverID)
        case .view:
            // In view mode, show current attachments
            return selectedVolume?.attachments?.contains { $0.serverId == serverID } ?? false
        }
    }

    func isServerCurrentlyAttached(_ serverID: String) -> Bool {
        return selectedVolume?.attachments?.contains { $0.serverId == serverID } ?? false
    }

    func getAvailableServersForAttach() -> [Server] {
        guard let volume = selectedVolume else { return [] }

        // Volume is not attached, can attach to any server
        if volume.attachments?.isEmpty ?? true {
            return availableServers
        }

        // Volume is already attached, can't attach to more servers (OpenStack limitation)
        return []
    }


    func hasPendingChanges() -> Bool {
        return !pendingAttachments.isEmpty
    }

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

    func getVolumeStatus() -> String {
        guard let volume = selectedVolume else { return "No volume selected" }

        if volume.attachments?.isEmpty ?? true {
            return "Available (not attached)"
        } else {
            return "In-use (attached to \(volume.attachments?.count ?? 0) server(s))"
        }
    }

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