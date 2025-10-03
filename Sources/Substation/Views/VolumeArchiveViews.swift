import Foundation
import OSClient
import SwiftTUI

struct VolumeArchiveViews {

    // MARK: - Unified Archive Item

    private enum ArchiveItem {
        case volumeSnapshot(VolumeSnapshot)
        case volumeBackup(VolumeBackup)
        case serverBackup(Image)

        var name: String {
            switch self {
            case .volumeSnapshot(let snapshot):
                return snapshot.name ?? "Unnamed Snapshot"
            case .volumeBackup(let backup):
                return backup.name ?? "Unnamed Backup"
            case .serverBackup(let image):
                return image.name ?? "Unnamed Backup"
            }
        }

        var type: String {
            switch self {
            case .volumeSnapshot:
                return "Volume Snapshot"
            case .volumeBackup:
                return "Volume Backup"
            case .serverBackup:
                return "Server Backup"
            }
        }

        var status: String {
            switch self {
            case .volumeSnapshot(let snapshot):
                return snapshot.status ?? "Unknown"
            case .volumeBackup(let backup):
                return backup.status ?? "Unknown"
            case .serverBackup(let image):
                return image.status ?? "Unknown"
            }
        }

        var size: String {
            switch self {
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
            switch self {
            case .volumeSnapshot(let snapshot):
                return snapshot.createdAt
            case .volumeBackup(let backup):
                return backup.createdAt
            case .serverBackup(let image):
                return image.createdAt
            }
        }

        var id: String {
            switch self {
            case .volumeSnapshot(let snapshot):
                return snapshot.id
            case .volumeBackup(let backup):
                return backup.id
            case .serverBackup(let image):
                return image.id
            }
        }
    }

    // MARK: - Archive List View

    @MainActor
    static func drawDetailedArchiveList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        cachedVolumeSnapshots: [VolumeSnapshot],
        cachedVolumeBackups: [VolumeBackup],
        cachedImages: [Image],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int
    ) async {
        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        let titleText = searchQuery.map { "Volume Archives (filtered: \($0))" } ?? "Volume Archives"
        components.append(Text(titleText).emphasis().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        // Header
        components.append(Text(" ST  TYPE               NAME                   STATUS       SIZE      CREATED").muted()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)).border())

        // Build unified archive list
        var archives: [ArchiveItem] = []

        // Add volume snapshots
        for snapshot in cachedVolumeSnapshots {
            archives.append(.volumeSnapshot(snapshot))
        }

        // Add volume backups
        for backup in cachedVolumeBackups {
            archives.append(.volumeBackup(backup))
        }

        // Add server image backups (images with image_type == "snapshot")
        let serverBackups = cachedImages.filter { image in
            if let properties = image.properties,
               let imageType = properties["image_type"],
               imageType == "snapshot" {
                return true
            }
            return false
        }

        for backup in serverBackups {
            archives.append(.serverBackup(backup))
        }

        // Sort by created date (newest first)
        archives.sort { a, b in
            guard let dateA = a.createdAt, let dateB = b.createdAt else {
                return a.createdAt != nil
            }
            return dateA > dateB
        }

        // Apply search filter
        let filteredArchives: [ArchiveItem]
        if let query = searchQuery, !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            filteredArchives = archives.filter { archive in
                archive.name.lowercased().contains(lowercaseQuery) ||
                archive.type.lowercased().contains(lowercaseQuery) ||
                archive.status.lowercased().contains(lowercaseQuery)
            }
        } else {
            filteredArchives = archives
        }

        // Render archive list
        if filteredArchives.isEmpty {
            components.append(Text("No archives found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            // Calculate visible range for viewport
            let maxVisibleItems = max(1, Int(height) - 10)
            let startIndex = max(0, min(scrollOffset, filteredArchives.count - maxVisibleItems))
            let endIndex = min(filteredArchives.count, startIndex + maxVisibleItems)

            for i in startIndex..<endIndex {
                let archive = filteredArchives[i]
                let isSelected = i == selectedIndex
                let archiveComponent = createArchiveListItemComponent(
                    archive: archive,
                    isSelected: isSelected,
                    width: width
                )
                components.append(archiveComponent)
            }

            // Scroll indicator
            if filteredArchives.count > maxVisibleItems {
                let scrollText = "[\(startIndex + 1)-\(endIndex)/\(filteredArchives.count)]"
                components.append(Text(scrollText).info()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
            }
        }

        // Help text
        components.append(Text("SPACE: View Details | /: Search | UP/DOWN: Navigate | ESC: Back").muted()
            .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        // Render unified archive list
        let archiveListComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(archiveListComponent, on: surface, in: bounds)
    }

    // MARK: - Component Creation

    private static func createArchiveListItemComponent(
        archive: ArchiveItem,
        isSelected: Bool,
        width: Int32
    ) -> any Component {
        // Type (18 chars to match header)
        let typeText = String(archive.type.prefix(18)).padding(toLength: 18, withPad: " ", startingAt: 0)

        // Name (22 chars to match header)
        let nameText = String(archive.name.prefix(22)).padding(toLength: 22, withPad: " ", startingAt: 0)

        // Status with color coding (12 chars to match header)
        let status = archive.status
        let statusStyle: TextStyle = {
            switch status.lowercased() {
            case "available", "active": return .success
            case "error": return .error
            case "creating", "queued", "saving": return .warning
            default: return .info
            }
        }()
        let statusText = String(status.prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)

        // Size (9 chars to match header)
        let sizeText = String(archive.size.prefix(9)).padding(toLength: 9, withPad: " ", startingAt: 0)

        // Created date (formatted)
        let createdText: String
        if let created = archive.createdAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            createdText = formatter.string(from: created)
        } else {
            createdText = "N/A"
        }

        let rowStyle: TextStyle = isSelected ? .accent : .secondary

        return HStack(spacing: 0, children: [
            StatusIcon(status: status.lowercased()),
            Text(" \(typeText)").styled(rowStyle),
            Text(" \(nameText)").styled(rowStyle),
            Text(" \(statusText)").styled(statusStyle),
            Text(" \(sizeText)").styled(.info),
            Text(" \(createdText)").styled(rowStyle)
        ]).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
    }

    // MARK: - Archive Detail Views

    @MainActor
    static func drawVolumeSnapshotDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        snapshot: VolumeSnapshot
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text("Volume Snapshot Details: \(snapshot.name ?? "Unnamed")").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Basic Information
        components.append(Text("Basic Information").primary().bold())
        var basicInfo: [any Component] = []
        basicInfo.append(Text("ID: \(snapshot.id)").secondary())
        basicInfo.append(Text("Name: \(snapshot.name ?? "Unnamed")").secondary())

        let status = snapshot.status ?? "Unknown"
        let statusStyle: TextStyle = status.lowercased() == "available" ? .success :
                                   (status.lowercased().contains("error") ? .error : .accent)
        basicInfo.append(HStack(spacing: 0, children: [
            Text("Status: ").secondary(),
            Text(status).styled(statusStyle)
        ]))

        if let size = snapshot.size {
            basicInfo.append(Text("Size: \(size) GB").secondary())
        }

        basicInfo.append(Text("Volume ID: \(snapshot.volumeId)").secondary())

        if let description = snapshot.description, !description.isEmpty {
            basicInfo.append(Text("Description: \(description)").secondary())
        }

        components.append(VStack(children: basicInfo)
                         .padding(EdgeInsets(top: 0, leading: 2, bottom: 2, trailing: 0)))

        // Timestamps
        components.append(Text("Timestamps").primary().bold())
        var timestamps: [any Component] = []

        if let created = snapshot.createdAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            timestamps.append(Text("Created: \(formatter.string(from: created))").secondary())
        }
        if let updated = snapshot.updatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            timestamps.append(Text("Updated: \(formatter.string(from: updated))").secondary())
        }

        components.append(VStack(children: timestamps)
                         .padding(EdgeInsets(top: 0, leading: 2, bottom: 2, trailing: 0)))

        // Render all components
        let detailStack = VStack(children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(detailStack, on: surface, in: bounds)
    }

    @MainActor
    static func drawVolumeBackupDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        backup: VolumeBackup
    ) async {
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text("Volume Backup Details: \(backup.name ?? "Unnamed")").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Basic Information
        components.append(Text("Basic Information").primary().bold())
        var basicInfo: [any Component] = []
        basicInfo.append(Text("ID: \(backup.id)").secondary())
        basicInfo.append(Text("Name: \(backup.name ?? "Unnamed")").secondary())

        let status = backup.status ?? "Unknown"
        let statusStyle: TextStyle = status.lowercased() == "available" ? .success :
                                   (status.lowercased().contains("error") ? .error : .accent)
        basicInfo.append(HStack(spacing: 0, children: [
            Text("Status: ").secondary(),
            Text(status).styled(statusStyle)
        ]))

        if let size = backup.size {
            basicInfo.append(Text("Size: \(size) GB").secondary())
        }

        if let volumeId = backup.volumeId {
            basicInfo.append(Text("Volume ID: \(volumeId)").secondary())
        }

        if let isIncremental = backup.isIncremental {
            let backupType = isIncremental ? "Incremental" : "Full"
            basicInfo.append(Text("Backup Type: \(backupType)").secondary())
        }

        if let description = backup.description, !description.isEmpty {
            basicInfo.append(Text("Description: \(description)").secondary())
        }

        components.append(VStack(children: basicInfo)
                         .padding(EdgeInsets(top: 0, leading: 2, bottom: 2, trailing: 0)))

        // Timestamps
        components.append(Text("Timestamps").primary().bold())
        var timestamps: [any Component] = []

        if let created = backup.createdAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            timestamps.append(Text("Created: \(formatter.string(from: created))").secondary())
        }
        if let updated = backup.updatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            timestamps.append(Text("Updated: \(formatter.string(from: updated))").secondary())
        }

        components.append(VStack(children: timestamps)
                         .padding(EdgeInsets(top: 0, leading: 2, bottom: 2, trailing: 0)))

        // Render all components
        let detailStack = VStack(children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(detailStack, on: surface, in: bounds)
    }
}
