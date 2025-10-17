import Foundation
import OSClient
import SwiftNCurses

extension ServerGroupViews {
    @MainActor
    static func createServerGroupStatusListView() -> StatusListView<ServerGroup> {
        return StatusListView<ServerGroup>(
            title: "Server Groups",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 30,
                    getValue: { serverGroup in
                        serverGroup.name ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "POLICY",
                    width: 18,
                    getValue: { serverGroup in
                        serverGroup.primaryPolicy?.displayName ?? "Unknown"
                    },
                    getStyle: { serverGroup in
                        switch serverGroup.primaryPolicy {
                        case .affinity: return .success
                        case .antiAffinity: return .warning
                        case .softAffinity: return .info
                        case .softAntiAffinity: return .accent
                        case .none: return .secondary
                        }
                    }
                ),
                StatusListColumn(
                    header: "MEMBERS",
                    width: 8,
                    getValue: { serverGroup in
                        String(serverGroup.members.count)
                    }
                ),
                StatusListColumn(
                    header: "PROJECT",
                    width: 36,
                    getValue: { serverGroup in
                        serverGroup.project_id ?? "Unknown"
                    }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { serverGroups, query in
                FilterUtils.filterServerGroups(serverGroups, query: query)
            },
            getItemID: { serverGroup in serverGroup.id }
        )
    }
}
