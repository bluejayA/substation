import Foundation
import struct OSClient.Port
import OSClient
import SwiftNCurses

extension FloatingIPViews {
    @MainActor
    static func createFloatingIPStatusListView(
        cachedServers: [Server],
        cachedPorts: [Port],
        cachedNetworks: [Network]
    ) -> StatusListView<FloatingIP> {
        // Pre-calculate lookup dictionaries for performance
        let portLookup: [String: Port] = Dictionary(uniqueKeysWithValues: cachedPorts.map { ($0.id, $0) })
        let serverLookup: [String: Server] = Dictionary(uniqueKeysWithValues: cachedServers.map { ($0.id, $0) })
        let externalNetwork = cachedNetworks.first(where: { $0.external == true })

        return StatusListView<FloatingIP>(
            title: "Floating IPs",
            columns: [
                StatusListColumn(
                    header: "IP ADDRESS",
                    width: 16,
                    getValue: { floatingIP in
                        floatingIP.floatingIpAddress ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 12,
                    getValue: { floatingIP in
                        floatingIP.portId != nil ? "ACTIVE" : "DOWN"
                    },
                    getStyle: { floatingIP in
                        floatingIP.portId != nil ? .success : .error
                    }
                ),
                StatusListColumn(
                    header: "INSTANCE",
                    width: 25,
                    getValue: { floatingIP in
                        if let portID = floatingIP.portId {
                            if let port = portLookup[portID],
                               let deviceID = port.deviceId,
                               let server = serverLookup[deviceID] {
                                return server.name ?? "Unnamed"
                            } else {
                                return "Port: " + String(portID.prefix(20))
                            }
                        }
                        return "Unassigned"
                    }
                ),
                StatusListColumn(
                    header: "NETWORK",
                    width: 25,
                    getValue: { _ in
                        externalNetwork?.name ?? "External"
                    }
                )
            ],
            getStatusIcon: { floatingIP in
                floatingIP.portId != nil ? "active" : "down"
            },
            filterItems: { floatingIPs, query in
                FilterUtils.filterFloatingIPs(floatingIPs, query: query)
            },
            getItemID: { floatingIP in floatingIP.id }
        )
    }
}
