import OSClient

struct ServerGroupManagementForm {
    var selectedServerGroup: ServerGroup?
    var availableServers: [Server] = []
    var selectedResourceIndex: Int = 0
    var pendingAdditions: Set<String> = [] // Server IDs to be added to group
    var pendingRemovals: Set<String> = [] // Server IDs to be removed from group
    var isLoading: Bool = false
    var errorMessage: String?

    mutating func reset() {
        selectedResourceIndex = 0
        pendingAdditions.removeAll()
        pendingRemovals.removeAll()
        isLoading = false
        errorMessage = nil
    }

    mutating func toggleServer(_ serverID: String) {
        let isCurrentlyInGroup = isServerCurrentlyInGroup(serverID)

        if isCurrentlyInGroup {
            // Server is currently in group
            if pendingRemovals.contains(serverID) {
                // Cancel removal - server stays in group
                pendingRemovals.remove(serverID)
            } else {
                // Mark for removal
                pendingRemovals.insert(serverID)
                // Remove from additions if it was there
                pendingAdditions.remove(serverID)
            }
        } else {
            // Server is not currently in group
            if pendingAdditions.contains(serverID) {
                // Cancel addition - server stays out of group
                pendingAdditions.remove(serverID)
            } else {
                // Mark for addition
                pendingAdditions.insert(serverID)
                // Remove from removals if it was there
                pendingRemovals.remove(serverID)
            }
        }
    }

    func getServerStatus(_ serverID: String) -> ServerStatus {
        let isCurrentlyInGroup = isServerCurrentlyInGroup(serverID)
        return isCurrentlyInGroup ? .inGroup : .notInGroup
    }

    enum ServerStatus {
        case inGroup        // Currently in group
        case notInGroup     // Not in group

        var checkboxDisplay: String {
            switch self {
            case .inGroup: return "[X]"
            case .notInGroup: return "[ ]"
            }
        }

        var description: String {
            switch self {
            case .inGroup: return "Member"
            case .notInGroup: return "Not Member"
            }
        }
    }

    func isServerCurrentlyInGroup(_ serverID: String) -> Bool {
        return selectedServerGroup?.members.contains(serverID) ?? false
    }

    func getAllServers() -> [Server] {
        // Return all available servers sorted by name
        return availableServers.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    func hasPendingChanges() -> Bool {
        return !pendingAdditions.isEmpty || !pendingRemovals.isEmpty
    }

    func getServerGroupStatus() -> String {
        guard let serverGroup = selectedServerGroup else { return "No server group selected" }

        let memberCount = serverGroup.members.count
        if memberCount == 0 {
            return "Empty (no members)"
        } else {
            return "\(memberCount) member(s)"
        }
    }

    func getServerGroupInfo() -> String {
        guard let serverGroup = selectedServerGroup else { return "No server group selected" }

        let policies = serverGroup.policies?.joined(separator: ", ") ?? ""
        return "Policies: \(policies.isEmpty ? "None" : policies)"
    }

    func getPendingChangesInfo() -> String? {
        let addCount = pendingAdditions.count
        let removeCount = pendingRemovals.count

        guard addCount > 0 || removeCount > 0 else { return nil }

        var changes: [String] = []
        if addCount > 0 {
            changes.append("Add \(addCount) server\(addCount == 1 ? "" : "s")")
        }
        if removeCount > 0 {
            changes.append("Remove \(removeCount) server\(removeCount == 1 ? "" : "s")")
        }

        return "Ready to \(changes.joined(separator: " and "))"
    }

    func getOperationConfirmationMessage() -> String? {
        let addCount = pendingAdditions.count
        let removeCount = pendingRemovals.count

        guard addCount > 0 || removeCount > 0 else { return nil }

        var message = "Apply changes to server group?\n\n"

        if addCount > 0 {
            let addNames = pendingAdditions.compactMap { serverID in
                availableServers.first { $0.id == serverID }?.name ?? serverID
            }.joined(separator: ", ")
            message += "Add \(addCount) server\(addCount == 1 ? "" : "s"): \(addNames)\n"
        }

        if removeCount > 0 {
            let removeNames = pendingRemovals.compactMap { serverID in
                availableServers.first { $0.id == serverID }?.name ?? serverID
            }.joined(separator: ", ")
            message += "Remove \(removeCount) server\(removeCount == 1 ? "" : "s"): \(removeNames)\n"
        }

        return message
    }

    mutating func setError(_ message: String) {
        errorMessage = message
        isLoading = false
    }

    mutating func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
        }
    }

    mutating func clearError() {
        errorMessage = nil
    }

    mutating func clearPendingOperations() {
        pendingAdditions.removeAll()
        pendingRemovals.removeAll()
    }

    // Server navigation
    mutating func moveToNextServer() {
        let servers = getAllServers()
        if !servers.isEmpty {
            selectedResourceIndex = min(selectedResourceIndex + 1, servers.count - 1)
        }
    }

    mutating func moveToPreviousServer() {
        selectedResourceIndex = max(selectedResourceIndex - 1, 0)
    }

    func getSelectedServer() -> Server? {
        let servers = getAllServers()
        guard selectedResourceIndex < servers.count else { return nil }
        return servers[selectedResourceIndex]
    }

    func getNavigationHelp() -> String {
        return "UP/DOWN: Navigate servers | ENTER/ESC: Back to server groups"
    }
}