import Foundation
import OSClient
import SwiftTUI

extension SubnetViews {
    @MainActor
    static func createSubnetStatusListView() -> StatusListView<Subnet> {
        return StatusListView<Subnet>(
            title: "Subnets",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 25,
                    getValue: { subnet in
                        subnet.name ?? "Unnamed"
                    }
                ),
                StatusListColumn(
                    header: "NETWORK ID",
                    width: 36,
                    getValue: { subnet in
                        subnet.networkId
                    },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "SUBNET ID",
                    width: 36,
                    getValue: { subnet in
                        subnet.id
                    },
                    getStyle: { _ in .info }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { subnets, query in
                FilterUtils.filterSubnets(subnets, query: query)
            }
        )
    }
}
