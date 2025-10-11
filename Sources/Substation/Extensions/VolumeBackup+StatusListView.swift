import Foundation
import OSClient
import SwiftTUI

extension VolumeArchiveViews {
    @MainActor
    static func createVolumeArchiveStatusListView() -> StatusListView<VolumeArchiveItem> {
        return StatusListView<VolumeArchiveItem>(
            title: "Volume Archives",
            columns: [
                StatusListColumn(
                    header: "TYPE",
                    width: 18,
                    getValue: { item in
                        item.type
                    }
                ),
                StatusListColumn(
                    header: "NAME",
                    width: 22,
                    getValue: { item in
                        item.name
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 12,
                    getValue: { item in
                        item.status
                    },
                    getStyle: { item in
                        switch item.status.lowercased() {
                        case "available", "active": return .success
                        case "error": return .error
                        case "creating", "queued", "saving": return .warning
                        default: return .info
                        }
                    }
                ),
                StatusListColumn(
                    header: "SIZE",
                    width: 9,
                    getValue: { item in
                        item.size
                    },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "CREATED",
                    width: 16,
                    getValue: { item in
                        if let created = item.createdAt {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd HH:mm"
                            return formatter.string(from: created)
                        }
                        return "N/A"
                    }
                )
            ],
            getStatusIcon: { item in
                item.status.lowercased()
            },
            filterItems: { items, query in
                guard let query = query, !query.isEmpty else { return items }
                let lowercaseQuery = query.lowercased()
                return items.filter { item in
                    item.name.lowercased().contains(lowercaseQuery) ||
                    item.type.lowercased().contains(lowercaseQuery) ||
                    item.status.lowercased().contains(lowercaseQuery)
                }
            },
            getItemID: { item in
                item.id
            }
        )
    }
}

struct VolumeArchiveItem: Sendable {
    enum ItemType {
        case volumeSnapshot(VolumeSnapshot)
        case volumeBackup(VolumeBackup)
        case serverBackup(Image)
    }

    let itemType: ItemType

    var name: String {
        switch itemType {
        case .volumeSnapshot(let snapshot):
            return snapshot.name ?? "Unnamed Snapshot"
        case .volumeBackup(let backup):
            return backup.name ?? "Unnamed Backup"
        case .serverBackup(let image):
            return image.name ?? "Unnamed Backup"
        }
    }

    var type: String {
        switch itemType {
        case .volumeSnapshot:
            return "Volume Snapshot"
        case .volumeBackup:
            return "Volume Backup"
        case .serverBackup:
            return "Server Backup"
        }
    }

    var status: String {
        switch itemType {
        case .volumeSnapshot(let snapshot):
            return snapshot.status ?? "Unknown"
        case .volumeBackup(let backup):
            return backup.status ?? "Unknown"
        case .serverBackup(let image):
            return image.status ?? "Unknown"
        }
    }

    var size: String {
        switch itemType {
        case .volumeSnapshot(let snapshot):
            if let size = snapshot.size {
                return "\(size)GB"
            }
            return "N/A"
        case .volumeBackup(let backup):
            if let size = backup.size {
                return "\(size)GB"
            }
            return "N/A"
        case .serverBackup(let image):
            if let size = image.size {
                let gb = Double(size) / (1024.0 * 1024.0 * 1024.0)
                return String(format: "%.2fGB", gb)
            }
            return "N/A"
        }
    }

    var createdAt: Date? {
        switch itemType {
        case .volumeSnapshot(let snapshot):
            return snapshot.createdAt
        case .volumeBackup(let backup):
            return backup.createdAt
        case .serverBackup(let image):
            return image.createdAt
        }
    }

    var id: String {
        switch itemType {
        case .volumeSnapshot(let snapshot):
            return snapshot.id
        case .volumeBackup(let backup):
            return backup.id
        case .serverBackup(let image):
            return image.id
        }
    }
}
