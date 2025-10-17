import Foundation
import OSClient
import SwiftNCurses

struct VolumeArchiveViews {

    // MARK: - Modern Archive List View (Using StatusListView)

    @MainActor
    static func drawArchiveList(
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
        selectedIndex: Int,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        var archiveItems: [VolumeArchiveItem] = []

        for snapshot in cachedVolumeSnapshots {
            archiveItems.append(VolumeArchiveItem(itemType: .volumeSnapshot(snapshot)))
        }

        for backup in cachedVolumeBackups {
            archiveItems.append(VolumeArchiveItem(itemType: .volumeBackup(backup)))
        }

        let serverBackups = cachedImages.filter { image in
            if let properties = image.properties,
               let imageType = properties["image_type"],
               imageType == "snapshot" {
                return true
            }
            return false
        }

        for backup in serverBackups {
            archiveItems.append(VolumeArchiveItem(itemType: .serverBackup(backup)))
        }

        archiveItems.sort { a, b in
            guard let dateA = a.createdAt, let dateB = b.createdAt else {
                return a.createdAt != nil
            }
            return dateA > dateB
        }

        let statusListView = createVolumeArchiveStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: archiveItems,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

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
            let surface = SwiftNCurses.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftNCurses.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftNCurses.surface(from: screen)
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
        await SwiftNCurses.render(archiveListComponent, on: surface, in: bounds)
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
            createdText = created.compactFormatted()
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
        snapshot: VolumeSnapshot,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let status = snapshot.status ?? "Unknown"
        let statusStyle: TextStyle = status.lowercased() == "available" ? .success :
                                   status.lowercased() == "creating" ? .warning :
                                   (status.lowercased().contains("error") ? .error : .info)

        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: snapshot.id),
            DetailView.buildFieldItem(label: "Name", value: snapshot.name),
            DetailView.buildFieldItem(label: "Description", value: snapshot.description),
            .field(label: "Status", value: status, style: statusStyle),
            snapshot.size.map { .field(label: "Size", value: "\($0) GB", style: .accent) }
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Source Volume Section
        let volumeItems: [DetailItem?] = [
            .field(label: "Volume ID", value: snapshot.volumeId, style: .secondary),
            .field(label: "Description", value: "Snapshot of this volume", style: .info)
        ]

        if let volumeSection = DetailView.buildSection(title: "Source Volume", items: volumeItems) {
            sections.append(volumeSection)
        }

        // Progress Analysis Section
        if let progress = snapshot.progress {
            let progressAnalysisItems = analyzeSnapshotProgress(progress: progress)
            if !progressAnalysisItems.isEmpty {
                sections.append(DetailSection(
                    title: "Snapshot Progress Analysis",
                    items: progressAnalysisItems,
                    titleStyle: .accent
                ))
            }
        }

        // Restore Time Estimate Section
        let restoreTimeItems = getRestoreTimeEstimate(size: snapshot.size)
        if !restoreTimeItems.isEmpty {
            sections.append(DetailSection(
                title: "Restore Information",
                items: restoreTimeItems,
                titleStyle: .accent
            ))
        }

        // Metadata Section
        if let metadata = snapshot.metadata, !metadata.isEmpty {
            let metadataItems = metadata.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Metadata", items: metadataItems))
        }

        // Ownership Section
        var ownershipItems: [DetailItem?] = []

        if let projectId = snapshot.projectId {
            ownershipItems.append(.field(label: "Project ID", value: projectId, style: .secondary))
        }

        if let userId = snapshot.userId {
            ownershipItems.append(.field(label: "User ID", value: userId, style: .secondary))
        }

        if let ownershipSection = DetailView.buildSection(title: "Ownership", items: ownershipItems) {
            sections.append(ownershipSection)
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: snapshot.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: snapshot.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Volume Snapshot Details: \(snapshot.name ?? "Unnamed Snapshot")",
            sections: sections,
            helpText: "Press ESC to return to archive list",
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
    }

    // MARK: - Intelligence Helper Functions

    private static func analyzeSnapshotProgress(progress: String?) -> [DetailItem] {
        var items: [DetailItem] = []

        guard let progress = progress else {
            return items
        }

        if let percentageString = progress.components(separatedBy: "%").first,
           let percentage = Int(percentageString) {
            items.append(.field(
                label: "Completion",
                value: "\(percentage)%",
                style: percentage == 100 ? .success : .warning
            ))

            if percentage < 100 {
                items.append(.field(
                    label: "Status",
                    value: "Snapshot in progress",
                    style: .info
                ))
                items.append(.field(
                    label: "  Note",
                    value: "Wait for completion before using snapshot",
                    style: .warning
                ))
            } else {
                items.append(.field(
                    label: "Status",
                    value: "Snapshot complete and ready",
                    style: .success
                ))
            }
        }

        return items
    }


    private static func getRestoreTimeEstimate(size: Int?) -> [DetailItem] {
        var items: [DetailItem] = []

        guard let size = size else {
            return items
        }

        let estimatedMinutes: Int
        if size <= 10 {
            estimatedMinutes = 2
        } else if size <= 50 {
            estimatedMinutes = 5
        } else if size <= 100 {
            estimatedMinutes = 10
        } else if size <= 500 {
            estimatedMinutes = 30
        } else {
            estimatedMinutes = 60
        }

        items.append(.field(
            label: "Estimated Restore Time",
            value: "\(estimatedMinutes) minutes (approximate)",
            style: .info
        ))
        items.append(.field(
            label: "  Note",
            value: "Actual time depends on storage backend performance",
            style: .info
        ))

        return items
    }

    private static func analyzeBackupType(backup: VolumeBackup) -> [DetailItem] {
        var items: [DetailItem] = []

        guard let isIncremental = backup.isIncremental else {
            return items
        }

        if isIncremental {
            items.append(.field(
                label: "Backup Type",
                value: "Incremental",
                style: .info
            ))
            items.append(.field(
                label: "  Description",
                value: "Only stores changes since last backup",
                style: .info
            ))
            items.append(.spacer)
            items.append(.field(
                label: "Dependency Note",
                value: "Incremental backups may depend on previous backups",
                style: .warning
            ))
            items.append(.field(
                label: "  Warning",
                value: "Restore requires complete backup chain",
                style: .warning
            ))

            if let hasDependent = backup.hasDependent, hasDependent {
                items.append(.spacer)
                items.append(.field(
                    label: "Dependent Backups",
                    value: "Other backups depend on this one",
                    style: .warning
                ))
                items.append(.field(
                    label: "  Caution",
                    value: "Deleting this backup may break backup chain",
                    style: .error
                ))
            }
        } else {
            items.append(.field(
                label: "Backup Type",
                value: "Full",
                style: .success
            ))
            items.append(.field(
                label: "  Description",
                value: "Complete volume backup - no dependencies",
                style: .success
            ))
        }

        return items
    }


    private static func analyzeBackupRetention(backup: VolumeBackup) -> [DetailItem] {
        var items: [DetailItem] = []

        guard let createdAt = backup.createdAt else {
            return items
        }

        let ageInDays = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0

        if ageInDays > 90 {
            items.append(.field(
                label: "Retention Notice",
                value: "Backup is \(ageInDays) days old",
                style: .warning
            ))
            items.append(.field(
                label: "  Recommendation",
                value: "Consider if this backup is still needed",
                style: .info
            ))
        } else if ageInDays > 30 {
            items.append(.field(
                label: "Backup Age",
                value: "\(ageInDays) days old",
                style: .info
            ))
        } else {
            items.append(.field(
                label: "Backup Age",
                value: "\(ageInDays) days old (recent)",
                style: .success
            ))
        }

        return items
    }

    @MainActor
    static func drawVolumeBackupDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        backup: VolumeBackup,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let status = backup.status ?? "Unknown"
        let statusStyle: TextStyle = status.lowercased() == "available" ? .success :
                                   status.lowercased() == "creating" ? .warning :
                                   (status.lowercased().contains("error") ? .error : .info)

        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: backup.id),
            DetailView.buildFieldItem(label: "Name", value: backup.name),
            DetailView.buildFieldItem(label: "Description", value: backup.description),
            .field(label: "Status", value: status, style: statusStyle),
            backup.size.map { .field(label: "Size", value: "\($0) GB", style: .accent) }
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Backup Configuration Section
        var configItems: [DetailItem?] = []

        if let isIncremental = backup.isIncremental {
            let backupType = isIncremental ? "Incremental" : "Full"
            configItems.append(.field(label: "Backup Type", value: backupType, style: isIncremental ? .info : .accent))
            if isIncremental {
                configItems.append(.field(label: "  Description", value: "Only changed blocks since last backup", style: .info))
            } else {
                configItems.append(.field(label: "  Description", value: "Complete volume backup", style: .info))
            }
        }

        if let hasDependent = backup.hasDependent {
            configItems.append(.field(label: "Has Dependents", value: hasDependent ? "Yes" : "No", style: hasDependent ? .warning : .success))
            if hasDependent {
                configItems.append(.field(label: "  Warning", value: "Other backups depend on this one", style: .warning))
            }
        }

        if let configSection = DetailView.buildSection(title: "Backup Configuration", items: configItems, titleStyle: .accent) {
            sections.append(configSection)
        }

        // Source Information Section
        var sourceItems: [DetailItem?] = []

        if let volumeId = backup.volumeId {
            sourceItems.append(.field(label: "Volume ID", value: volumeId, style: .secondary))
        }

        if let snapshotId = backup.snapshotId {
            sourceItems.append(.field(label: "Snapshot ID", value: snapshotId, style: .secondary))
            sourceItems.append(.field(label: "  Type", value: "Backup created from snapshot", style: .info))
        }

        if let sourceSection = DetailView.buildSection(title: "Source Information", items: sourceItems) {
            sections.append(sourceSection)
        }

        // Storage Information Section
        var storageItems: [DetailItem?] = []

        if let container = backup.container {
            storageItems.append(.field(label: "Container", value: container, style: .secondary))
        }

        if let objectCount = backup.objectCount {
            storageItems.append(.field(label: "Object Count", value: String(objectCount), style: .secondary))
            storageItems.append(.field(label: "  Description", value: "Number of objects in backup storage", style: .info))
        }

        if let storageSection = DetailView.buildSection(title: "Storage Information", items: storageItems) {
            sections.append(storageSection)
        }

        // Location Section
        if let availabilityZone = backup.availabilityZone {
            let locationItems: [DetailItem?] = [
                .field(label: "Availability Zone", value: availabilityZone, style: .secondary)
            ]

            if let locationSection = DetailView.buildSection(title: "Location", items: locationItems) {
                sections.append(locationSection)
            }
        }

        // Ownership Section
        var ownershipItems: [DetailItem?] = []

        if let projectId = backup.projectId {
            ownershipItems.append(.field(label: "Project ID", value: projectId, style: .secondary))
        }

        if let userId = backup.userId {
            ownershipItems.append(.field(label: "User ID", value: userId, style: .secondary))
        }

        if let ownershipSection = DetailView.buildSection(title: "Ownership", items: ownershipItems) {
            sections.append(ownershipSection)
        }

        // Backup Type Analysis Section
        let backupTypeItems = analyzeBackupType(backup: backup)
        if !backupTypeItems.isEmpty {
            sections.append(DetailSection(
                title: "Backup Type Analysis",
                items: backupTypeItems,
                titleStyle: .accent
            ))
        }

        // Retention Analysis Section
        let retentionItems = analyzeBackupRetention(backup: backup)
        if !retentionItems.isEmpty {
            sections.append(DetailSection(
                title: "Retention Analysis",
                items: retentionItems,
                titleStyle: .accent
            ))
        }

        // Restore Time Estimate Section
        let restoreTimeItems = getRestoreTimeEstimate(size: backup.size)
        if !restoreTimeItems.isEmpty {
            sections.append(DetailSection(
                title: "Restore Information",
                items: restoreTimeItems,
                titleStyle: .accent
            ))
        }

        // Timestamps Section
        var timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: backup.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: backup.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let dataTimestamp = backup.dataTimestamp {
            timestampItems.append(.field(label: "Data Timestamp", value: dataTimestamp.formatted(date: .abbreviated, time: .shortened), style: .secondary))
            timestampItems.append(.field(label: "  Description", value: "Point-in-time of backed up data", style: .info))
        }

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Volume Backup Details: \(backup.name ?? "Unnamed Backup")",
            sections: sections,
            helpText: "Press ESC to return to archive list",
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
    }
}
