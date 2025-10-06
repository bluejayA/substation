import Foundation
import OSClient
import SwiftTUI

extension NetworkViews {
    @MainActor
    static func createNetworkStatusListView() -> StatusListView<Network> {
        return StatusListView<Network>(
            title: "Networks",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 29,
                    getValue: { network in
                        network.name ?? "Unnamed"
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 11,
                    getValue: { network in
                        network.status ?? "Unknown"
                    },
                    getStyle: { network in
                        let status = network.status ?? "Unknown"
                        switch status.lowercased() {
                        case "active": return .success
                        case "down": return .error
                        case "build", "building": return .warning
                        default: return .info
                        }
                    }
                ),
                StatusListColumn(
                    header: "SHARED",
                    width: 7,
                    getValue: { network in
                        network.shared.map { $0 ? "Yes" : "No" } ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "EXTERNAL",
                    width: 8,
                    getValue: { network in
                        network.external.map { $0 ? "Yes" : "No" } ?? "Unknown"
                    }
                )
            ],
            getStatusIcon: { network in
                network.external == true ? "external" : (network.shared == true ? "shared" : "private")
            },
            filterItems: { networks, query in
                FilterUtils.filterNetworks(networks, query: query)
            }
        )
    }
}
