import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

extension PortViews {
    @MainActor
    static func createPortStatusListView() -> StatusListView<Port> {
        return StatusListView<Port>(
            title: "Ports",
            columns: [
                StatusListColumn(
                    header: "NAME/ID",
                    width: 34,
                    getValue: { port in
                        (port.name?.isEmpty == false) ? port.name! : port.id
                    }
                ),
                StatusListColumn(
                    header: "NETWORK ID",
                    width: 29,
                    getValue: { port in
                        port.networkId
                    },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 10,
                    getValue: { port in
                        port.deviceId != nil ? "ACTIVE" : "DOWN"
                    },
                    getStyle: { port in
                        port.deviceId != nil ? .success : .error
                    }
                )
            ],
            getStatusIcon: { port in
                port.deviceId != nil ? "active" : "down"
            },
            filterItems: { ports, query in
                FilterUtils.filterPorts(ports, query: query)
            }
        )
    }
}
