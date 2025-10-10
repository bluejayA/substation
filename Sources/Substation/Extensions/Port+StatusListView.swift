import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

extension PortViews {
    @MainActor
    static func createPortStatusListView(networks: [Network], servers: [Server]) -> StatusListView<Port> {
        return StatusListView<Port>(
            title: "Ports",
            columns: [
                StatusListColumn(
                    header: "NAME/ID",
                    width: 22,
                    getValue: { port in
                        if let name = port.name, !name.isEmpty {
                            return name.truncated(to: 22)
                        }
                        return port.id.truncated(to: 22)
                    }
                ),
                StatusListColumn(
                    header: "NETWORK",
                    width: 18,
                    getValue: { port in
                        if let network = networks.first(where: { $0.id == port.networkId }) {
                            if let name = network.name, !name.isEmpty {
                                return name.truncated(to: 18)
                            }
                        }
                        return port.networkId.truncated(to: 18)
                    },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "IP ADDRESS",
                    width: 15,
                    getValue: { port in
                        if let fixedIps = port.fixedIps, !fixedIps.isEmpty {
                            return fixedIps[0].ipAddress
                        }
                        return "N/A"
                    },
                    getStyle: { _ in .accent }
                ),
                StatusListColumn(
                    header: "ATTACHMENT",
                    width: 18,
                    getValue: { port in
                        if let deviceId = port.deviceId, !deviceId.isEmpty {
                            if let server = servers.first(where: { $0.id == deviceId }) {
                                if let name = server.name, !name.isEmpty {
                                    return name.truncated(to: 18)
                                }
                            }
                            return deviceId.truncated(to: 18)
                        }
                        return "Unattached"
                    },
                    getStyle: { port in
                        port.deviceId != nil ? .success : .warning
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 8,
                    getValue: { port in
                        port.status?.uppercased() ?? "UNKNOWN"
                    },
                    getStyle: { port in
                        switch port.status?.lowercased() {
                        case "active": return .success
                        case "down": return .error
                        case "build": return .warning
                        default: return .info
                        }
                    }
                )
            ],
            getStatusIcon: { port in
                port.status?.lowercased() ?? "unknown"
            },
            filterItems: { ports, query in
                FilterUtils.filterPorts(ports, query: query)
            },
            getItemID: { port in port.id }
        )
    }
}

private extension String {
    func truncated(to length: Int) -> String {
        if self.count <= length {
            return self
        }
        let truncateIndex = self.index(self.startIndex, offsetBy: length - 3)
        return String(self[..<truncateIndex]) + "..."
    }
}
