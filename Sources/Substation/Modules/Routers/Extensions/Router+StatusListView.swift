import Foundation
import OSClient
import SwiftNCurses

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
                    getValue: { router in
                        router.status ?? "Unknown"
                    },
                    getStyle: { router in
                        let status = router.status ?? "Unknown"
                        switch status.lowercased() {
                        case "active": return .success
                        case "error": return .error
                        default: return .warning
                        }
                    }
                )
            ],
            getStatusIcon: { router in router.status?.lowercased() ?? "unknown" },
            filterItems: { routers, query in
                FilterUtils.filterRouters(routers, query: query)
            },
            getItemID: { router in router.id }
        )
    }
}
