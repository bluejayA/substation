import Foundation
import OSClient
import SwiftTUI

extension FlavorViews {
    @MainActor
    static func createFlavorStatusListView() -> StatusListView<Flavor> {
        return StatusListView<Flavor>(
            title: "Flavors",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 32,
                    getValue: { flavor in
                        flavor.name ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "VCPUS",
                    width: 7,
                    getValue: { flavor in
                        String(flavor.vcpus)
                    },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "RAM",
                    width: 10,
                    getValue: { flavor in
                        "\(flavor.ram)MB"
                    },
                    getStyle: { _ in .accent }
                ),
                StatusListColumn(
                    header: "DISK",
                    width: 8,
                    getValue: { flavor in
                        "\(flavor.disk)GB"
                    },
                    getStyle: { _ in .warning }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { flavors, query in
                FilterUtils.filterFlavors(flavors, query: query)
            }
        )
    }
}
