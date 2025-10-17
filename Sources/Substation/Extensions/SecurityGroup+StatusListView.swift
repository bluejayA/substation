import Foundation
import OSClient
import SwiftNCurses

extension SecurityGroupViews {
    @MainActor
    static func createSecurityGroupStatusListView() -> StatusListView<SecurityGroup> {
        return StatusListView<SecurityGroup>(
            title: "Security Groups",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 30,
                    getValue: { securityGroup in
                        securityGroup.name ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "RULES",
                    width: 9,
                    getValue: { securityGroup in
                        let count = securityGroup.securityGroupRules?.count ?? 0
                        return "\(count) rule\(count == 1 ? "" : "s")"
                    }
                ),
                StatusListColumn(
                    header: "DESCRIPTION",
                    width: 50,
                    getValue: { securityGroup in
                        securityGroup.description ?? "No description"
                    }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { securityGroups, query in
                FilterUtils.filterSecurityGroups(securityGroups, query: query)
            },
            getItemID: { securityGroup in securityGroup.id }
        )
    }
}
