import OSClient

struct NetworkInterfaceManagementForm {
    var selectedServer: Server?
    var availablePorts: [Port] = []
    var availableNetworks: [Network] = []
    var serverInterfaces: [InterfaceAttachment] = []
    var selectedResourceIndex: Int = 0
    var selectedOperation: NetworkInterfaceOperation = .view
    var attachmentMode: AttachmentMode = .ports
    var currentViewMode: AttachmentMode = .ports  // Mode for the bottom selection area
    var pendingPortAttachments: Set<String> = []
    var pendingPortDetachments: Set<String> = []
    var pendingNetworkAttachments: Set<String> = []
    var pendingNetworkDetachments: Set<String> = []
    var isLoading: Bool = false
    var errorMessage: String?

    enum NetworkInterfaceOperation: CaseIterable {
        case view, attach, detach

        var title: String {
            switch self {
            case .view: return "View Current"
            case .attach: return "Attach"
            case .detach: return "Detach"
            }
        }
    }

    enum AttachmentMode: CaseIterable {
        case ports, networks

        var title: String {
            switch self {
            case .ports: return "Ports"
            case .networks: return "Networks"
            }
        }
    }

    mutating func reset() {
        selectedResourceIndex = 0
        selectedOperation = .view
        attachmentMode = .ports
        currentViewMode = .ports
        pendingPortAttachments.removeAll()
        pendingPortDetachments.removeAll()
        pendingNetworkAttachments.removeAll()
        pendingNetworkDetachments.removeAll()
        isLoading = false
        errorMessage = nil
    }

    mutating func toggleViewMode() {
        currentViewMode = currentViewMode == .ports ? .networks : .ports
        selectedResourceIndex = 0 // Reset selection when switching modes
    }

    // New intelligent toggle for the unified management interface
    mutating func togglePortManagement(_ portId: String) {
        let isCurrentlyAttached = isPortCurrentlyAttached(portId)

        if isCurrentlyAttached {
            // Port is currently attached - toggle detach
            if pendingPortDetachments.contains(portId) {
                pendingPortDetachments.remove(portId)
            } else {
                pendingPortDetachments.insert(portId)
                pendingPortAttachments.remove(portId) // Remove from attachments if present
            }
        } else {
            // Port is not attached - toggle attach
            if pendingPortAttachments.contains(portId) {
                pendingPortAttachments.remove(portId)
            } else {
                pendingPortAttachments.insert(portId)
                pendingPortDetachments.remove(portId) // Remove from detachments if present
            }
        }
    }

    mutating func toggleNetworkManagement(_ networkID: String) {
        let isCurrentlyAttached = isNetworkCurrentlyAttached(networkID)

        if isCurrentlyAttached {
            // Network is currently attached - toggle detach
            if pendingNetworkDetachments.contains(networkID) {
                pendingNetworkDetachments.remove(networkID)
            } else {
                pendingNetworkDetachments.insert(networkID)
                pendingNetworkAttachments.remove(networkID) // Remove from attachments if present
            }
        } else {
            // Network is not attached - toggle attach
            if pendingNetworkAttachments.contains(networkID) {
                pendingNetworkAttachments.remove(networkID)
            } else {
                pendingNetworkAttachments.insert(networkID)
                pendingNetworkDetachments.remove(networkID) // Remove from detachments if present
            }
        }
    }

    mutating func togglePort(_ portId: String) {
        switch selectedOperation {
        case .attach:
            if pendingPortAttachments.contains(portId) {
                pendingPortAttachments.remove(portId)
            } else {
                pendingPortAttachments.insert(portId)
                pendingPortDetachments.remove(portId) // Remove from detachments if present
            }
        case .detach:
            if pendingPortDetachments.contains(portId) {
                pendingPortDetachments.remove(portId)
            } else {
                pendingPortDetachments.insert(portId)
                pendingPortAttachments.remove(portId) // Remove from attachments if present
            }
        case .view:
            break // No action in view mode
        }
    }

    mutating func toggleNetwork(_ networkID: String) {
        switch selectedOperation {
        case .attach:
            if pendingNetworkAttachments.contains(networkID) {
                pendingNetworkAttachments.remove(networkID)
            } else {
                pendingNetworkAttachments.insert(networkID)
                pendingNetworkDetachments.remove(networkID) // Remove from detachments if present
            }
        case .detach:
            if pendingNetworkDetachments.contains(networkID) {
                pendingNetworkDetachments.remove(networkID)
            } else {
                pendingNetworkDetachments.insert(networkID)
                pendingNetworkAttachments.remove(networkID) // Remove from attachments if present
            }
        case .view:
            break // No action in view mode
        }
    }

    func isPortSelected(_ portId: String) -> Bool {
        switch selectedOperation {
        case .attach:
            return pendingPortAttachments.contains(portId)
        case .detach:
            return pendingPortDetachments.contains(portId)
        case .view:
            return serverInterfaces.contains { $0.portId == portId }
        }
    }

    func isNetworkSelected(_ networkID: String) -> Bool {
        switch selectedOperation {
        case .attach:
            return pendingNetworkAttachments.contains(networkID)
        case .detach:
            return pendingNetworkDetachments.contains(networkID)
        case .view:
            return isNetworkCurrentlyAttached(networkID)
        }
    }

    func isPortCurrentlyAttached(_ portId: String) -> Bool {
        return serverInterfaces.contains { $0.portId == portId }
    }

    func isNetworkCurrentlyAttached(_ networkID: String) -> Bool {
        // Check if any of the server's ports are on this network
        let attachedNetworkIDs = Set(serverInterfaces.compactMap { interface in
            availablePorts.first { $0.id == interface.portId }?.networkId
        })
        return attachedNetworkIDs.contains(networkID)
    }

    func getAvailablePortsForAttach() -> [Port] {
        let currentPortIDs = Set(serverInterfaces.map { $0.portId })
        return availablePorts.filter { !currentPortIDs.contains($0.id) }
    }

    func getAvailableNetworksForAttach() -> [Network] {
        let attachedNetworkIDs = Set(serverInterfaces.compactMap { interface in
            availablePorts.first { $0.id == interface.portId }?.networkId
        })
        return availableNetworks.filter { !attachedNetworkIDs.contains($0.id) }
    }

    func getPortsForDetach() -> [Port] {
        let currentPortIDs = Set(serverInterfaces.map { $0.portId })
        return availablePorts.filter { currentPortIDs.contains($0.id) }
    }

    func hasPendingChanges() -> Bool {
        return !pendingPortAttachments.isEmpty || !pendingPortDetachments.isEmpty || !pendingNetworkAttachments.isEmpty || !pendingNetworkDetachments.isEmpty
    }

    func getPortForInterface(_ interface: InterfaceAttachment) -> Port? {
        return availablePorts.first { $0.id == interface.portId }
    }

    // Get currently attached items for the top display
    func getCurrentlyAttachedItems(for mode: AttachmentMode) -> [Any] {
        switch mode {
        case .ports:
            return serverInterfaces.compactMap { interface in
                getPortForInterface(interface)
            }
        case .networks:
            let attachedNetworkIDs = Set(serverInterfaces.compactMap { interface in
                availablePorts.first { $0.id == interface.portId }?.networkId
            })
            return availableNetworks.filter { attachedNetworkIDs.contains($0.id) }
        }
    }

    // Get all available items for attach/detach with attached items sorted to top
    func getManagementItems(for mode: AttachmentMode) -> [Any] {
        switch mode {
        case .ports:
            let currentPortIDs = Set(serverInterfaces.map { $0.portId })
            let attachedPorts = availablePorts.filter { currentPortIDs.contains($0.id) }
            let unattachedPorts = availablePorts.filter { !currentPortIDs.contains($0.id) }
            return attachedPorts + unattachedPorts
        case .networks:
            let attachedNetworkIDs = Set(serverInterfaces.compactMap { interface in
                availablePorts.first { $0.id == interface.portId }?.networkId
            })
            let attachedNetworks = availableNetworks.filter { attachedNetworkIDs.contains($0.id) }
            let unattachedNetworks = availableNetworks.filter { !attachedNetworkIDs.contains($0.id) }
            return attachedNetworks + unattachedNetworks
        }
    }

    func getCurrentDisplayItems() -> [Any] {
        switch (selectedOperation, attachmentMode) {
        case (.view, .ports):
            return serverInterfaces.compactMap { interface in
                getPortForInterface(interface)
            }
        case (.attach, .ports):
            return getAvailablePortsForAttach()
        case (.attach, .networks):
            return getAvailableNetworksForAttach()
        case (.detach, .ports):
            return getPortsForDetach()
        case (.detach, .networks):
            // Show networks that have attached interfaces for detachment
            let attachedNetworkIDs = Set(serverInterfaces.compactMap { interface in
                availablePorts.first { $0.id == interface.portId }?.networkId
            })
            return availableNetworks.filter { attachedNetworkIDs.contains($0.id) }
        case (.view, .networks):
            // Show networks that have attached interfaces
            let attachedNetworkIDs = Set(serverInterfaces.compactMap { interface in
                availablePorts.first { $0.id == interface.portId }?.networkId
            })
            return availableNetworks.filter { attachedNetworkIDs.contains($0.id) }
        }
    }
}