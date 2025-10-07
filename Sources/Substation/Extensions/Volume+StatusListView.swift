import Foundation
import OSClient
import SwiftTUI

extension VolumeViews {
    @MainActor
    static func createVolumeStatusListView() -> StatusListView<Volume> {
        return StatusListView<Volume>(
            title: "Volumes",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 23,
                    getValue: { volume in
                        volume.name ?? "Unnamed"
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 12,
                    getValue: { volume in
                        volume.status ?? "Unknown"
                    },
                    getStyle: { volume in
                        let status = volume.status ?? "Unknown"
                        switch status.lowercased() {
                        case "available": return .success
                        case "in-use": return .accent
                        case "error": return .error
                        case "creating": return .warning
                        default: return .info
                        }
                    }
                ),
                StatusListColumn(
                    header: "SIZE",
                    width: 8,
                    getValue: { volume in
                        "\(volume.size ?? 0)GB"
                    },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "ATTACHED TO",
                    width: 25,
                    getValue: { volume in
                        if !(volume.attachments?.isEmpty ?? true) {
                            let serverNames = volume.attachments?.compactMap { $0.serverId } ?? []
                            return serverNames.isEmpty ? "Attached" : String(serverNames.first?.prefix(25) ?? "")
                        } else {
                            return "Not attached"
                        }
                    }
                )
            ],
            getStatusIcon: { volume in
                volume.status ?? "unknown"
            },
            filterItems: { volumes, query in
                FilterUtils.filterVolumes(volumes, query: query)
            },
            getItemID: { volume in
                volume.id
            }
        )
    }
}
