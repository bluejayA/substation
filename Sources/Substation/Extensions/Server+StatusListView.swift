import Foundation
import OSClient
import SwiftTUI

extension ServerViews {
    @MainActor
    static func createServerStatusListView(cachedFlavors: [Flavor], cachedImages: [Image]) -> StatusListView<Server> {
        return StatusListView<Server>(
            title: "Servers",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 22,
                    getValue: { server in
                        server.name ?? "Unnamed"
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 11,
                    getValue: { server in
                        server.status?.rawValue ?? "Unknown"
                    },
                    getStyle: { server in
                        let status = server.status?.rawValue ?? "Unknown"
                        switch status.lowercased() {
                        case "active": return .success
                        case "error": return .error
                        case "build", "building": return .warning
                        default: return .info
                        }
                    }
                ),
                StatusListColumn(
                    header: "IP ADDRESS",
                    width: 16,
                    getValue: { server in
                        ServerViews.getServerIP(server) ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "FLAVOR/IMAGE",
                    width: 40,
                    getValue: { server in
                        let flavorName = ServerViews.resolveFlavorName(from: server.flavor, cachedFlavors: cachedFlavors)
                        let imageName = ServerViews.resolveImageName(from: server.image, cachedImages: cachedImages)
                        return ServerViews.formatFlavorImageInfo(
                            flavorName: flavorName,
                            imageName: imageName,
                            availableWidth: 40
                        )
                    },
                    getStyle: { _ in .info }
                )
            ],
            getStatusIcon: { server in
                server.status?.rawValue ?? "unknown"
            },
            filterItems: { servers, query in
                FilterUtils.filterServers(servers, query: query)
            }
        )
    }
}
