import Foundation
import OSClient
import SwiftTUI

extension RouterViews {
    @MainActor
    static func createRouterStatusListView() -> StatusListView<Router> {
        return StatusListView<Router>(
            title: "Routers",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 30,
                    getValue: { router in
                        router.name ?? "Unnamed"
                    }
                ),
                StatusListColumn(
                    header: "ID",
                    width: 36,
                    getValue: { router in
                        router.id
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 10,
                    getValue: { _ in
                        "ACTIVE"
                    },
                    getStyle: { _ in .success }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { routers, query in
                FilterUtils.filterRouters(routers, query: query)
            },
            getItemID: { router in router.id }
        )
    }
}
