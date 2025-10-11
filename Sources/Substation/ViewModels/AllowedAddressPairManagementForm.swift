import Foundation
import struct OSClient.Port
import OSClient

enum AllowedAddressPairManagementMode: Equatable {
    case listExisting        // Show existing allowed address pairs on the target port
    case selectPorts         // Select ports to add as allowed address pairs
}

enum PortSelectionStatus {
    case available        // [ ] - Port is not used as allowed address pair
    case currentlyUsed    // [*] - Port is currently used as allowed address pair
    case pendingAddition  // [X] - Port will be added as allowed address pair
    case pendingRemoval   // [-] - Port will be removed from allowed address pairs
}

struct AllowedAddressPairManagementForm {
    // Source port (the port whose IP/MAC will be added to other ports)
    var sourcePort: Port

    // Available ports to add the source port TO (target ports)
    var availablePorts: [Port] = []

    // Management state
    var mode: AllowedAddressPairManagementMode = .selectPorts

    // List state (for existing pairs)
    var highlightedPairIndex: Int = 0
    var scrollOffsetPairs: Int = 0

    // Port selection state (for selecting target ports)
    var highlightedPortIndex: Int = 0
    var scrollOffsetPorts: Int = 0
    var selectedTargetPorts: Set<String> = []  // Ports that will have source port added as allowed address pair

    init(sourcePort: Port, availablePorts: [Port] = []) {
        self.sourcePort = sourcePort
        // Filter out the source port itself and only include ports with port security enabled
        self.availablePorts = availablePorts.filter {
            $0.id != sourcePort.id && ($0.portSecurityEnabled ?? false)
        }
    }

    // MARK: - Mode Management

    mutating func reset() {
        selectedTargetPorts.removeAll()
        highlightedPortIndex = 0
        scrollOffsetPorts = 0
    }

    // MARK: - Port Selection Navigation

    mutating func movePortSelectionUp() {
        highlightedPortIndex = max(0, highlightedPortIndex - 1)
    }

    mutating func movePortSelectionDown() {
        let maxIndex = max(0, availablePorts.count - 1)
        highlightedPortIndex = min(maxIndex, highlightedPortIndex + 1)
    }

    func getHighlightedPort() -> Port? {
        guard highlightedPortIndex < availablePorts.count else {
            return nil
        }
        return availablePorts[highlightedPortIndex]
    }

    mutating func togglePortSelection() {
        guard let port = getHighlightedPort() else { return }

        // Toggle selection for this target port
        if selectedTargetPorts.contains(port.id) {
            selectedTargetPorts.remove(port.id)
        } else {
            selectedTargetPorts.insert(port.id)
        }
    }

    func getPortSelectionStatus(_ portId: String) -> PortSelectionStatus {
        // Check if this port already has the source port's IP as an allowed address pair
        let alreadyHasSourceIP = portAlreadyHasSourceIPAsAllowedPair(portId)

        if alreadyHasSourceIP {
            if selectedTargetPorts.contains(portId) {
                return .pendingRemoval  // [−] - Will remove source IP from this port
            } else {
                return .currentlyUsed   // [*] - Already has source IP
            }
        } else {
            if selectedTargetPorts.contains(portId) {
                return .pendingAddition // [X] - Will add source IP to this port
            } else {
                return .available       // [ ] - Does not have source IP
            }
        }
    }

    private func portAlreadyHasSourceIPAsAllowedPair(_ portId: String) -> Bool {
        // Get the source port's IP address
        guard let sourceIpAddress = sourcePort.fixedIps?.first?.ipAddress else { return false }

        // Find the target port
        guard let targetPort = availablePorts.first(where: { $0.id == portId }) else { return false }

        // Check if target port's allowed address pairs contain the source IP
        guard let pairs = targetPort.allowedAddressPairs else { return false }
        return pairs.contains(where: { $0.ipAddress == sourceIpAddress })
    }

    // MARK: - Address Pair Operations

    func getSourceAddressPair() -> AddressPair? {
        // Create address pair from source port's IP and MAC
        guard let sourceIp = sourcePort.fixedIps?.first?.ipAddress else { return nil }
        return AddressPair(
            ipAddress: sourceIp,
            macAddress: sourcePort.macAddress
        )
    }

    func getTargetPortsToAdd() -> [Port] {
        // Get ports that need the source IP added (selected but don't already have it)
        return availablePorts.filter { port in
            selectedTargetPorts.contains(port.id) && !portAlreadyHasSourceIPAsAllowedPair(port.id)
        }
    }

    func getTargetPortsToRemove() -> [Port] {
        // Get ports that need the source IP removed (selected and already have it)
        return availablePorts.filter { port in
            selectedTargetPorts.contains(port.id) && portAlreadyHasSourceIPAsAllowedPair(port.id)
        }
    }

    func getAllowedAddressPairsForPort(_ portId: String, adding: Bool) -> [AddressPair] {
        guard let targetPort = availablePorts.first(where: { $0.id == portId }) else { return [] }
        guard let sourcePair = getSourceAddressPair() else { return targetPort.allowedAddressPairs ?? [] }

        var pairs = targetPort.allowedAddressPairs ?? []

        if adding {
            // Add source IP if not already present
            if !pairs.contains(where: { $0.ipAddress == sourcePair.ipAddress }) {
                pairs.append(sourcePair)
            }
        } else {
            // Remove source IP
            pairs.removeAll(where: { $0.ipAddress == sourcePair.ipAddress })
        }

        return pairs
    }

    // MARK: - Helpers

    func getSourcePortDisplayName() -> String {
        return sourcePort.name ?? sourcePort.id
    }

    func getSourcePortIPAddress() -> String {
        return sourcePort.fixedIps?.first?.ipAddress ?? "N/A"
    }

    func hasPendingChanges() -> Bool {
        return !selectedTargetPorts.isEmpty
    }

    func getPendingChangesCount() -> Int {
        return selectedTargetPorts.count
    }

    func getPendingAdditionsCount() -> Int {
        return getTargetPortsToAdd().count
    }

    func getPendingRemovalsCount() -> Int {
        return getTargetPortsToRemove().count
    }

    // MARK: - Port Filtering

    func getFilteredAvailablePorts(searchQuery: String?) -> [Port] {
        guard let query = searchQuery, !query.isEmpty else {
            return availablePorts
        }

        let lowercaseQuery = query.lowercased()
        return availablePorts.filter { port in
            if let name = port.name, name.lowercased().contains(lowercaseQuery) {
                return true
            }
            if port.id.lowercased().contains(lowercaseQuery) {
                return true
            }
            if let fixedIps = port.fixedIps {
                for fixedIp in fixedIps {
                    if fixedIp.ipAddress.lowercased().contains(lowercaseQuery) {
                        return true
                    }
                }
            }
            if let macAddress = port.macAddress, macAddress.lowercased().contains(lowercaseQuery) {
                return true
            }
            return false
        }
    }
}
