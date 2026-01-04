import Foundation
import OSClient
import SwiftNCurses

struct ImageViews {

    // MARK: - Image List View (Gold Standard Pattern following RouterViews)

    @MainActor
    static func drawDetailedImageList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                    width: Int32, height: Int32, cachedImages: [Image],
                                    searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                    multiSelectMode: Bool = false, selectedItems: Set<String> = []) async {

        let statusListView = createImageStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedImages,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Image Detail View

    @MainActor
    static func drawImageDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        image: Image,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: image.id),
            DetailView.buildFieldItem(label: "Name", value: image.name),
            image.status.map { .field(label: "Status", value: $0, style: $0.lowercased() == "active" ? .success : $0.lowercased().contains("error") ? .error : .warning) },
            DetailView.buildFieldItem(label: "Visibility", value: image.visibility)
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Technical Information Section
        var technicalItems: [DetailItem?] = []

        if let size = image.size {
            let sizeGB = Double(size) / (1024 * 1024 * 1024)
            technicalItems.append(.field(label: "Size", value: String(format: "%.2f GB", sizeGB), style: .secondary))
        }

        if let virtualSize = image.virtualSize {
            let virtualSizeGB = Double(virtualSize) / (1024 * 1024 * 1024)
            technicalItems.append(.field(label: "Virtual Size", value: String(format: "%.2f GB", virtualSizeGB), style: .secondary))

            // Show size efficiency if both sizes are available
            if let size = image.size {
                let efficiency = (Double(size) / Double(virtualSize)) * 100
                technicalItems.append(.field(label: "  Efficiency", value: String(format: "%.1f%% (sparse file)", efficiency), style: .info))
            }
        }

        if let diskFormat = image.diskFormat {
            technicalItems.append(.field(label: "Disk Format", value: diskFormat, style: .secondary))
            let formatDescription = getDiskFormatDescription(diskFormat)
            if !formatDescription.isEmpty {
                technicalItems.append(.field(label: "  Description", value: formatDescription, style: .info))
            }
        }

        if let containerFormat = image.containerFormat {
            technicalItems.append(.field(label: "Container Format", value: containerFormat, style: .secondary))
            let containerDescription = getContainerFormatDescription(containerFormat)
            if !containerDescription.isEmpty {
                technicalItems.append(.field(label: "  Description", value: containerDescription, style: .info))
            }
        }

        if let minDisk = image.minDisk, minDisk > 0 {
            technicalItems.append(.field(label: "Minimum Disk", value: "\(minDisk) GB", style: .secondary))
        }

        if let minRam = image.minRam, minRam > 0 {
            technicalItems.append(.field(label: "Minimum RAM", value: "\(minRam) MB", style: .secondary))
        }

        if let technicalSection = DetailView.buildSection(title: "Technical Information", items: technicalItems, titleStyle: .accent) {
            sections.append(technicalSection)
        }

        // Classified Properties Sections (preserve intelligent classification)
        let classifiedProperties = classifyImageProperties(image: image)

        // Operating System Section
        if !classifiedProperties.operatingSystem.isEmpty {
            let osItems = classifiedProperties.operatingSystem.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Operating System", items: osItems))
        }

        // Architecture Section
        if !classifiedProperties.architecture.isEmpty {
            let archItems = classifiedProperties.architecture.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Architecture", items: archItems))
        }

        // Virtualization Section
        if !classifiedProperties.virtualization.isEmpty {
            let virtItems = classifiedProperties.virtualization.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Virtualization", items: virtItems))
        }

        // Security Section
        if !classifiedProperties.security.isEmpty {
            let secItems = classifiedProperties.security.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Security", items: secItems))
        }

        // Storage Section
        if !classifiedProperties.storage.isEmpty {
            let storageItems = classifiedProperties.storage.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Storage", items: storageItems))
        }

        // Cloud Section
        if !classifiedProperties.cloud.isEmpty {
            let cloudItems = classifiedProperties.cloud.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Cloud", items: cloudItems))
        }

        // Other Properties Section
        if !classifiedProperties.other.isEmpty {
            let otherItems = classifiedProperties.other.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Other Properties", items: otherItems))
        }

        // Server Snapshot Section
        if let metadata = image.metadata {
            var snapshotItems: [DetailItem?] = []

            if let sourceServerName = metadata["source_server_name"] {
                snapshotItems.append(.field(label: "Source Server", value: sourceServerName, style: .secondary))
            }

            if let sourceServerId = metadata["source_server_id"] {
                snapshotItems.append(.field(label: "Source Server ID", value: sourceServerId, style: .muted))
            }

            if let createdBy = metadata["snapshot_created_by"] {
                snapshotItems.append(.field(label: "Created by", value: createdBy, style: .secondary))
            }

            if let snapshotCreatedAt = metadata["snapshot_created_at"] {
                snapshotItems.append(.field(label: "Snapshot Created", value: snapshotCreatedAt, style: .secondary))
            }

            if let snapshotSection = DetailView.buildSection(title: "Server Snapshot", items: snapshotItems) {
                sections.append(snapshotSection)
            }
        }

        // Progress Section
        if let progress = image.progress, progress < 100 {
            let progressItems: [DetailItem?] = [
                .field(label: "Upload Progress", value: "\(progress)%", style: progress >= 75 ? .success : progress >= 50 ? .info : .warning)
            ]

            if let progressSection = DetailView.buildSection(title: "Upload Status", items: progressItems) {
                sections.append(progressSection)
            }
        }

        // Protection and Ownership Section
        var protectionItems: [DetailItem?] = []

        if let owner = image.owner {
            protectionItems.append(.field(label: "Owner", value: owner, style: .secondary))
        }

        if let protected = image.protected {
            protectionItems.append(.field(label: "Protected", value: protected ? "Yes" : "No", style: protected ? .success : .secondary))
            if protected {
                protectionItems.append(.field(label: "  Warning", value: "Image cannot be deleted while protected", style: .warning))
            }
        }

        if let isPublic = image.isPublic {
            protectionItems.append(.field(label: "Public", value: isPublic ? "Yes" : "No", style: isPublic ? .info : .secondary))
        }

        if let checksum = image.checksum {
            protectionItems.append(.field(label: "Checksum", value: checksum, style: .muted))
        }

        if let protectionSection = DetailView.buildSection(title: "Protection and Ownership", items: protectionItems) {
            sections.append(protectionSection)
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: image.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: image.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Tags Section
        if let tags = image.tags, !tags.isEmpty {
            let tagItems = tags.map { DetailItem.field(label: "Tag", value: $0, style: .secondary) }
            sections.append(DetailSection(title: "Tags", items: tagItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Image Details: \(image.name ?? "Unnamed Image")",
            sections: sections,
            helpText: "Press ESC to return to images list",
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

    // MARK: - Helper Functions for Enhanced Image Information

    private static func getDiskFormatDescription(_ diskFormat: String) -> String {
        switch diskFormat.lowercased() {
        case "qcow2": return "QEMU Copy-On-Write v2 (compressed, snapshots)"
        case "raw": return "Raw disk image (no compression)"
        case "vdi": return "VirtualBox Disk Image"
        case "vmdk": return "VMware Virtual Machine Disk"
        case "vhd": return "Virtual Hard Disk (Hyper-V)"
        case "vhdx": return "Virtual Hard Disk v2 (Hyper-V)"
        case "iso": return "ISO 9660 optical disc image"
        case "aki": return "Amazon Kernel Image"
        case "ari": return "Amazon Ramdisk Image"
        case "ami": return "Amazon Machine Image"
        default: return ""
        }
    }

    private static func getContainerFormatDescription(_ containerFormat: String) -> String {
        switch containerFormat.lowercased() {
        case "bare": return "No container, just the disk format"
        case "ovf": return "Open Virtualization Format"
        case "ova": return "Open Virtual Appliance (OVF + files)"
        case "ami": return "Amazon Machine Image container"
        case "aki": return "Amazon Kernel Image container"
        case "ari": return "Amazon Ramdisk Image container"
        case "docker": return "Docker container format"
        default: return ""
        }
    }

    // MARK: - Legacy Constants for Gold Standard Line Generation Functions

    private static let imageDetailInfoFieldIndent = "  "
    private static let imageDetailFieldValueSeparator = ": "
    private static let imageDetailUnnamedText = "Unnamed Image"
    private static let imageDetailUnknownText = "Unknown"
    private static let imageDetailNameLabel = "Name"
    private static let imageDetailIdLabel = "ID"
    private static let imageDetailStatusLabel = "Status"
    private static let imageDetailVisibilityLabel = "Visibility"
    private static let imageDetailSizeLabel = "Size"
    private static let imageDetailDiskFormatLabel = "Disk Format"
    private static let imageDetailContainerFormatLabel = "Container Format"
    private static let imageDetailMinDiskLabel = "Minimum Disk"
    private static let imageDetailMinRamLabel = "Minimum RAM"
    private static let imageDetailSizeConversionFactor: Double = 1024 * 1024 * 1024
    private static let imageDetailSizeFormat = "%.2f GB"
    private static let imageDetailMinDiskFormat = "%d GB"
    private static let imageDetailMinRamFormat = "%d MB"
    private static let imageDetailOperatingSystemTitle = "Operating System"
    private static let imageDetailArchitectureTitle = "Architecture"
    private static let imageDetailVirtualizationTitle = "Virtualization"
    private static let imageDetailSecurityTitle = "Security"
    private static let imageDetailStorageTitle = "Storage"
    private static let imageDetailCloudTitle = "Cloud"
    private static let imageDetailOtherPropertiesTitle = "Other Properties"
    private static let imageDetailPropertyKeyMaxLength = 25
    private static let imageDetailPropertyValueMaxLength = 40
    private static let imageDetailTruncationSuffix = "..."
    private static let imageDetailSourceServerLabel = "Source Server"
    private static let imageDetailSourceServerIdLabel = "Source Server ID"
    private static let imageDetailSnapshotCreatedByLabel = "Created by"
    private static let imageDetailSnapshotCreatedAtLabel = "Snapshot Created"
    private static let imageDetailOwnerLabel = "Owner"
    private static let imageDetailProtectedLabel = "Protected"
    private static let imageDetailChecksumLabel = "Checksum"
    private static let imageDetailProtectedYes = "Yes"
    private static let imageDetailProtectedNo = "No"
    private static let imageDetailChecksumMaxLength = 50
    private static let imageDetailCreatedLabel = "Created"
    private static let imageDetailUpdatedLabel = "Updated"
    private static let imageDetailTagsMaxLineWidth = 70
    private static let imageDetailTitle = "Image Details"
    private static let imageDetailBasicInfoTitle = "Basic Information"
    private static let imageDetailTechnicalInfoTitle = "Technical Information"
    private static let imageDetailTimestampsTitle = "Timestamps"
    private static let imageDetailTitleEdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)
    private static let imageDetailSectionEdgeInsets = EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0)
    private static let imageDetailComponentSpacing: Int32 = 0
    private static let imageDetailScrollThreshold = 15

    // MARK: - Gold Standard Line Generation Functions

    public static func generateGoldStandardBasicInfoLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        let imageName = image.name ?? imageDetailUnnamedText
        let nameText = imageDetailInfoFieldIndent + imageDetailNameLabel + imageDetailFieldValueSeparator + imageName
        lines.append((nameText, 6)) // .secondary() like RouterViews

        let idText = imageDetailInfoFieldIndent + imageDetailIdLabel + imageDetailFieldValueSeparator + image.id
        lines.append((idText, 6)) // .secondary() like RouterViews

        let status = image.status ?? imageDetailUnknownText
        let statusColor: Int32 = status.lowercased() == "active" ? 5 : (status.lowercased().contains("error") ? 7 : 6)
        let statusText = imageDetailInfoFieldIndent + imageDetailStatusLabel + imageDetailFieldValueSeparator + status
        lines.append((statusText, statusColor)) // Success for active, error for errors, secondary for others

        if let visibility = image.visibility {
            let visibilityText = imageDetailInfoFieldIndent + imageDetailVisibilityLabel + imageDetailFieldValueSeparator + visibility
            lines.append((visibilityText, 6)) // .secondary() like RouterViews
        }

        return lines
    }

    public static func generateGoldStandardTechnicalInfoLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let size = image.size {
            let sizeGB = Double(size) / imageDetailSizeConversionFactor
            let sizeText = imageDetailInfoFieldIndent + imageDetailSizeLabel + imageDetailFieldValueSeparator + String(format: imageDetailSizeFormat, sizeGB)
            lines.append((sizeText, 6)) // .secondary() like RouterViews
        }

        if let diskFormat = image.diskFormat {
            let diskFormatText = imageDetailInfoFieldIndent + imageDetailDiskFormatLabel + imageDetailFieldValueSeparator + diskFormat
            lines.append((diskFormatText, 6)) // .secondary() like RouterViews
        }

        if let containerFormat = image.containerFormat {
            let containerFormatText = imageDetailInfoFieldIndent + imageDetailContainerFormatLabel + imageDetailFieldValueSeparator + containerFormat
            lines.append((containerFormatText, 6)) // .secondary() like RouterViews
        }

        if let minDisk = image.minDisk, minDisk > 0 {
            let minDiskText = imageDetailInfoFieldIndent + imageDetailMinDiskLabel + imageDetailFieldValueSeparator + String(format: imageDetailMinDiskFormat, minDisk)
            lines.append((minDiskText, 6)) // .secondary() like RouterViews
        }

        if let minRam = image.minRam, minRam > 0 {
            let minRamText = imageDetailInfoFieldIndent + imageDetailMinRamLabel + imageDetailFieldValueSeparator + String(format: imageDetailMinRamFormat, minRam)
            lines.append((minRamText, 6)) // .secondary() like RouterViews
        }

        return lines
    }

    public static func generateGoldStandardClassifiedPropertySections(classifiedProperties: ClassifiedProperties) -> [Section] {
        var sections: [Section] = []

        if !classifiedProperties.operatingSystem.isEmpty {
            sections.append(Section(title: imageDetailOperatingSystemTitle,
                                  lines: generateGoldStandardPropertyLines(properties: classifiedProperties.operatingSystem),
                                  priority: 2))
        }

        if !classifiedProperties.architecture.isEmpty {
            sections.append(Section(title: imageDetailArchitectureTitle,
                                  lines: generateGoldStandardPropertyLines(properties: classifiedProperties.architecture),
                                  priority: 2))
        }

        if !classifiedProperties.virtualization.isEmpty {
            sections.append(Section(title: imageDetailVirtualizationTitle,
                                  lines: generateGoldStandardPropertyLines(properties: classifiedProperties.virtualization),
                                  priority: 2))
        }

        if !classifiedProperties.security.isEmpty {
            sections.append(Section(title: imageDetailSecurityTitle,
                                  lines: generateGoldStandardPropertyLines(properties: classifiedProperties.security),
                                  priority: 2))
        }

        if !classifiedProperties.storage.isEmpty {
            sections.append(Section(title: imageDetailStorageTitle,
                                  lines: generateGoldStandardPropertyLines(properties: classifiedProperties.storage),
                                  priority: 2))
        }

        if !classifiedProperties.cloud.isEmpty {
            sections.append(Section(title: imageDetailCloudTitle,
                                  lines: generateGoldStandardPropertyLines(properties: classifiedProperties.cloud),
                                  priority: 2))
        }

        if !classifiedProperties.other.isEmpty {
            sections.append(Section(title: imageDetailOtherPropertiesTitle,
                                  lines: generateGoldStandardPropertyLines(properties: classifiedProperties.other),
                                  priority: 3))
        }

        return sections
    }

    private static func generateGoldStandardPropertyLines(properties: [String: String]) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            let truncatedKey = key.count > imageDetailPropertyKeyMaxLength ?
                String(key.prefix(imageDetailPropertyKeyMaxLength - 3)) + imageDetailTruncationSuffix : key
            let truncatedValue = value.count > imageDetailPropertyValueMaxLength ?
                String(value.prefix(imageDetailPropertyValueMaxLength - 3)) + imageDetailTruncationSuffix : value
            let propertyText = imageDetailInfoFieldIndent + truncatedKey + imageDetailFieldValueSeparator + truncatedValue
            lines.append((propertyText, 6)) // .secondary() like RouterViews
        }

        return lines
    }

    public static func generateGoldStandardServerSnapshotLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        guard let metadata = image.metadata, metadata["source_server_id"] != nil else {
            return lines
        }

        if let sourceServerName = metadata["source_server_name"] {
            let serverText = imageDetailInfoFieldIndent + imageDetailSourceServerLabel + imageDetailFieldValueSeparator + sourceServerName
            lines.append((serverText, 6)) // .secondary() like RouterViews
        }

        if let sourceServerId = metadata["source_server_id"] {
            let serverIdText = imageDetailInfoFieldIndent + imageDetailSourceServerIdLabel + imageDetailFieldValueSeparator + sourceServerId
            lines.append((serverIdText, 6)) // .secondary() like RouterViews
        }

        if let createdBy = metadata["snapshot_created_by"] {
            let createdByText = imageDetailInfoFieldIndent + imageDetailSnapshotCreatedByLabel + imageDetailFieldValueSeparator + createdBy
            lines.append((createdByText, 6)) // .secondary() like RouterViews
        }

        if let snapshotCreatedAt = metadata["snapshot_created_at"] {
            let snapshotCreatedText = imageDetailInfoFieldIndent + imageDetailSnapshotCreatedAtLabel + imageDetailFieldValueSeparator + snapshotCreatedAt
            lines.append((snapshotCreatedText, 6)) // .secondary() like RouterViews
        }

        return lines
    }

    public static func generateGoldStandardTagsLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        guard let tags = image.tags, !tags.isEmpty else {
            return lines
        }

        let tagsString = tags.joined(separator: ", ")

        if tagsString.count <= imageDetailTagsMaxLineWidth {
            let tagsText = imageDetailInfoFieldIndent + tagsString
            lines.append((tagsText, 6)) // .secondary() like RouterViews
        } else {
            // Split long tag lists across multiple lines
            var remainingTags = tagsString
            while !remainingTags.isEmpty {
                let lineWidth = min(remainingTags.count, imageDetailTagsMaxLineWidth - 2) // Account for indent
                let lineEnd = remainingTags.index(remainingTags.startIndex, offsetBy: lineWidth)
                var line = String(remainingTags[..<lineEnd])

                // Try to break at a comma if possible
                if remainingTags.count > lineWidth, let lastComma = line.lastIndex(of: ",") {
                    line = String(line[..<lastComma])
                    remainingTags = String(remainingTags[line.index(after: line.endIndex)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    remainingTags = String(remainingTags[lineEnd...])
                }

                let lineText = imageDetailInfoFieldIndent + line
                lines.append((lineText, 6)) // .secondary() like RouterViews
            }
        }

        return lines
    }

    public static func generateGoldStandardAdditionalInfoLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let owner = image.owner {
            let ownerText = imageDetailInfoFieldIndent + imageDetailOwnerLabel + imageDetailFieldValueSeparator + owner
            lines.append((ownerText, 6)) // .secondary() like RouterViews
        }

        if let protected = image.protected {
            let protectedValue = protected ? imageDetailProtectedYes : imageDetailProtectedNo
            let protectedText = imageDetailInfoFieldIndent + imageDetailProtectedLabel + imageDetailFieldValueSeparator + protectedValue
            lines.append((protectedText, 6)) // .secondary() like RouterViews
        }

        if let checksum = image.checksum {
            let truncatedChecksum = checksum.count > imageDetailChecksumMaxLength ?
                String(checksum.prefix(imageDetailChecksumMaxLength - 3)) + imageDetailTruncationSuffix : checksum
            let checksumText = imageDetailInfoFieldIndent + imageDetailChecksumLabel + imageDetailFieldValueSeparator + truncatedChecksum
            lines.append((checksumText, 6)) // .secondary() like RouterViews
        }

        return lines
    }

    public static func generateGoldStandardTimestampLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let created = image.createdAt {
            let createdText = imageDetailInfoFieldIndent + imageDetailCreatedLabel + imageDetailFieldValueSeparator + created.description
            lines.append((createdText, 6)) // .secondary() like RouterViews
        }

        if let updated = image.updatedAt {
            let updatedText = imageDetailInfoFieldIndent + imageDetailUpdatedLabel + imageDetailFieldValueSeparator + updated.description
            lines.append((updatedText, 6)) // .secondary() like RouterViews
        }

        return lines
    }


    // MARK: - Legacy Helper Functions for Compact Detail Layout

    private static func createBasicInfoComponents(image: Image) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        let imageName = image.name ?? imageDetailUnnamedText
        components.append(Text(fieldPrefix + imageDetailNameLabel + fieldSeparator + imageName).secondary())
        components.append(Text(fieldPrefix + imageDetailIdLabel + fieldSeparator + image.id).secondary())

        let status = image.status ?? imageDetailUnknownText
        let statusText = fieldPrefix + imageDetailStatusLabel + fieldSeparator + status
        if status.lowercased() == "active" {
            components.append(Text(statusText).success())
        } else if status.lowercased().contains("error") {
            components.append(Text(statusText).error())
        } else {
            components.append(Text(statusText).secondary())
        }

        if let visibility = image.visibility {
            components.append(Text(fieldPrefix + imageDetailVisibilityLabel + fieldSeparator + visibility).secondary())
        }

        return components
    }

    private static func createTechnicalInfoComponents(image: Image) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        if let size = image.size {
            let sizeGB = Double(size) / imageDetailSizeConversionFactor
            components.append(Text(fieldPrefix + imageDetailSizeLabel + fieldSeparator + String(format: imageDetailSizeFormat, sizeGB)).secondary())
        }

        if let diskFormat = image.diskFormat {
            components.append(Text(fieldPrefix + imageDetailDiskFormatLabel + fieldSeparator + diskFormat).secondary())
        }

        if let containerFormat = image.containerFormat {
            components.append(Text(fieldPrefix + imageDetailContainerFormatLabel + fieldSeparator + containerFormat).secondary())
        }

        if let minDisk = image.minDisk, minDisk > 0 {
            components.append(Text(fieldPrefix + imageDetailMinDiskLabel + fieldSeparator + String(format: imageDetailMinDiskFormat, minDisk)).secondary())
        }

        if let minRam = image.minRam, minRam > 0 {
            components.append(Text(fieldPrefix + imageDetailMinRamLabel + fieldSeparator + String(format: imageDetailMinRamFormat, minRam)).secondary())
        }

        return components
    }

    private static func createPropertyComponents(properties: [String: String]) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            components.append(Text(fieldPrefix + key + fieldSeparator + value).secondary())
        }

        return components
    }

    private static func createTimestampComponents(image: Image) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        if let created = image.createdAt {
            components.append(Text(fieldPrefix + imageDetailCreatedLabel + fieldSeparator + created.description).secondary())
        }

        if let updated = image.updatedAt {
            components.append(Text(fieldPrefix + imageDetailUpdatedLabel + fieldSeparator + updated.description).secondary())
        }

        return components
    }

    // MARK: - Compact Detail Layout (Gold Standard Pattern)

    @MainActor
    private static func drawCompactImageDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                             width: Int32, height: Int32, image: Image,
                                             classifiedProperties: ClassifiedProperties) async {

        let surface = SwiftNCurses.surface(from: screen)
        var components: [any Component] = []

        // Title Section (Following Gold Standard)
        let imageName = image.name ?? imageDetailUnnamedText
        let titleText = imageDetailTitle + imageDetailFieldValueSeparator + imageName
        components.append(Text(titleText).accent().bold()
            .padding(imageDetailTitleEdgeInsets))

        // Basic Information Section
        components.append(Text(imageDetailBasicInfoTitle).primary().bold())
        components.append(contentsOf: createBasicInfoComponents(image: image))

        // Technical Information Section
        components.append(Text(imageDetailTechnicalInfoTitle).primary().bold())
        components.append(contentsOf: createTechnicalInfoComponents(image: image))

        // Most important classified properties (OS and Architecture)
        if !classifiedProperties.operatingSystem.isEmpty {
            components.append(Text(imageDetailOperatingSystemTitle).primary().bold())
            components.append(contentsOf: createPropertyComponents(properties: classifiedProperties.operatingSystem))
        }

        if !classifiedProperties.architecture.isEmpty {
            components.append(Text(imageDetailArchitectureTitle).primary().bold())
            components.append(contentsOf: createPropertyComponents(properties: classifiedProperties.architecture))
        }

        // Timestamps Section
        let timestampComponents = createTimestampComponents(image: image)
        if !timestampComponents.isEmpty {
            components.append(Text(imageDetailTimestampsTitle).primary().bold())
            components.append(contentsOf: timestampComponents)
        }

        // Render the compact image detail view using gold standard pattern
        let imageDetailComponent = VStack(spacing: imageDetailComponentSpacing, children: components)
            .padding(imageDetailSectionEdgeInsets)

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftNCurses.render(imageDetailComponent, on: surface, in: bounds)
    }

    // MARK: - Property Classification

    public static func classifyImageProperties(image: Image) -> ClassifiedProperties {
        var classified = ClassifiedProperties()

        // Combine properties and metadata for classification
        var allProperties: [String: String] = [:]

        // Add properties
        if let properties = image.properties {
            for (key, value) in properties {
                allProperties[key] = value.description
            }
        }

        // Add metadata (excluding server snapshot metadata which is handled separately)
        if let metadata = image.metadata {
            for (key, value) in metadata {
                if !key.starts(with: "source_server") && !key.starts(with: "snapshot_") {
                    allProperties[key] = value
                }
            }
        }

        // Classify properties
        for (key, value) in allProperties {
            let lowercaseKey = key.lowercased()

            if operatingSystemKeys.contains(where: { lowercaseKey.contains($0) }) {
                classified.operatingSystem[key] = value
            } else if architectureKeys.contains(where: { lowercaseKey.contains($0) }) {
                classified.architecture[key] = value
            } else if virtualizationKeys.contains(where: { lowercaseKey.contains($0) }) {
                classified.virtualization[key] = value
            } else if securityKeys.contains(where: { lowercaseKey.contains($0) }) {
                classified.security[key] = value
            } else if storageKeys.contains(where: { lowercaseKey.contains($0) }) {
                classified.storage[key] = value
            } else if cloudKeys.contains(where: { lowercaseKey.contains($0) }) {
                classified.cloud[key] = value
            } else {
                classified.other[key] = value
            }
        }

        return classified
    }

    // MARK: - Component Creation Functions (Gold Standard Pattern)


    // MARK: - Legacy Helper Functions (Maintained for Compatibility)

    // MARK: - Image List View Constants
    // Layout Constants
    private static let imageListMinScreenWidth: Int32 = 10
    private static let imageListMinScreenHeight: Int32 = 10
    private static let imageListHeaderTopPadding: Int32 = 2
    private static let imageListHeaderLeadingPadding: Int32 = 0
    private static let imageListHeaderBottomPadding: Int32 = 0
    private static let imageListHeaderTrailingPadding: Int32 = 0
    private static let imageListNoImagesTopPadding: Int32 = 2
    private static let imageListNoImagesLeadingPadding: Int32 = 2
    private static let imageListNoImagesBottomPadding: Int32 = 0
    private static let imageListNoImagesTrailingPadding: Int32 = 0
    private static let imageListScrollInfoTopPadding: Int32 = 1
    private static let imageListScrollInfoLeadingPadding: Int32 = 0
    private static let imageListScrollInfoBottomPadding: Int32 = 0
    private static let imageListScrollInfoTrailingPadding: Int32 = 0
    private static let imageListItemTopPadding: Int32 = 0
    private static let imageListItemLeadingPadding: Int32 = 2
    private static let imageListItemBottomPadding: Int32 = 0
    private static let imageListItemTrailingPadding: Int32 = 0
    private static let imageListBoundsMinWidth: Int32 = 1
    private static let imageListBoundsMinHeight: Int32 = 1
    private static let imageListMinVisibleItems = 1
    private static let imageListReservedSpace = 10

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let imageListHeaderEdgeInsets = EdgeInsets(top: imageListHeaderTopPadding, leading: imageListHeaderLeadingPadding, bottom: imageListHeaderBottomPadding, trailing: imageListHeaderTrailingPadding)
    private static let imageListNoImagesEdgeInsets = EdgeInsets(top: imageListNoImagesTopPadding, leading: imageListNoImagesLeadingPadding, bottom: imageListNoImagesBottomPadding, trailing: imageListNoImagesTrailingPadding)
    private static let imageListScrollInfoEdgeInsets = EdgeInsets(top: imageListScrollInfoTopPadding, leading: imageListScrollInfoLeadingPadding, bottom: imageListScrollInfoBottomPadding, trailing: imageListScrollInfoTrailingPadding)
    private static let imageListItemEdgeInsets = EdgeInsets(top: imageListItemTopPadding, leading: imageListItemLeadingPadding, bottom: imageListItemBottomPadding, trailing: imageListItemTrailingPadding)

    // Text Constants
    private static let imageListTitle = "Images"
    private static let imageListFilteredTitlePrefix = "Images (filtered: "
    private static let imageListFilteredTitleSuffix = ")"
    private static let imageListHeader = " ST  NAME                         STATUS               VISIBILITY   SIZE"
    private static let imageListScreenTooSmallText = "Screen too small"
    private static let imageListNoImagesText = "No images found"
    private static let imageListScrollIndicatorPrefix = "["
    private static let imageListScrollIndicatorSeparator = "-"
    private static let imageListScrollIndicatorMiddle = "/"
    private static let imageListScrollIndicatorSuffix = "]"

    // Formatting Constants
    private static let imageListNamePadLength = 28
    private static let imageListStatusPadLength = 20
    private static let imageListVisibilityPadLength = 12
    private static let imageListPadCharacter = " "
    private static let imageListItemTextSpacing = " "
    private static let imageListSizeConversionFactor: Double = 1024 * 1024 * 1024
    private static let imageListSizeFormat = "%.1fGB"

    // Status Constants
    private static let imageListActiveStatus = "active"
    private static let imageListErrorStatus = "error"
    private static let imageListStatusIconActive = "active"
    private static let imageListUnnamedImageText = "Unnamed Image"
    private static let imageListUnknownStatusText = "Unknown"
    private static let imageListUnknownVisibilityText = "Unknown"
    private static let imageListUnknownSizeText = "Unknown"

    // Property classification keywords
    private static let operatingSystemKeys = ["os", "distro", "distribution", "version", "release", "kernel", "windows", "linux", "ubuntu", "centos", "rhel", "debian", "fedora", "suse"]
    private static let architectureKeys = ["arch", "architecture", "cpu", "processor", "x86", "amd64", "arm", "aarch64"]
    private static let virtualizationKeys = ["hypervisor", "virt", "virtualization", "vm", "kvm", "xen", "vmware", "hyper-v"]
    private static let securityKeys = ["sec", "security", "encryption", "cipher", "ssl", "tls", "cert", "key", "auth"]
    private static let storageKeys = ["storage", "disk", "volume", "filesystem", "fs", "mount", "raid"]
    private static let cloudKeys = ["cloud", "aws", "azure", "gcp", "openstack", "provider", "region", "zone"]

    public struct ClassifiedProperties {
        var operatingSystem: [String: String] = [:]
        var architecture: [String: String] = [:]
        var virtualization: [String: String] = [:]
        var security: [String: String] = [:]
        var storage: [String: String] = [:]
        var cloud: [String: String] = [:]
        var other: [String: String] = [:]
    }

    public struct Section {
        let title: String
        let lines: [(String, Int32)]
        let priority: Int
    }

    // MARK: - Content Generation Methods

    public static func generateBasicInfoLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        lines.append(("ID: \(image.id)", 6))

        if let name = image.name {
            lines.append(("Name: \(name)", 6))
        }

        let status = image.status ?? "Unknown"
        let statusColor: Int32 = status.lowercased() == "active" ? 5 :
                              (status.lowercased().contains("error") ? 7 : 2)
        lines.append(("Status: \(status)", statusColor))

        if let visibility = image.visibility {
            lines.append(("Visibility: \(visibility)", 6))
        }

        return lines
    }

    public static func generateTechnicalInfoLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let size = image.size {
            let sizeGB = Double(size) / (1024 * 1024 * 1024)
            lines.append((String(format: "Size: %.2f GB", sizeGB), 6))
        }

        if let diskFormat = image.diskFormat {
            lines.append(("Disk Format: \(diskFormat)", 6))
        }

        if let containerFormat = image.containerFormat {
            lines.append(("Container Format: \(containerFormat)", 6))
        }

        if let minDisk = image.minDisk, minDisk > 0 {
            lines.append(("Minimum Disk: \(minDisk) GB", 6))
        }

        if let minRam = image.minRam, minRam > 0 {
            lines.append(("Minimum RAM: \(minRam) MB", 6))
        }

        return lines
    }

    public static func generateServerSnapshotLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let metadata = image.metadata, metadata["source_server_id"] != nil {
            if let sourceServerName = metadata["source_server_name"] {
                lines.append(("Source Server: \(sourceServerName)", 6))
            }

            if let sourceServerId = metadata["source_server_id"] {
                lines.append(("Source Server ID: \(sourceServerId)", 6))
            }

            if let createdBy = metadata["snapshot_created_by"] {
                lines.append(("Created by: \(createdBy)", 5))
            }

            if let snapshotCreatedAt = metadata["snapshot_created_at"] {
                lines.append(("Snapshot Created: \(snapshotCreatedAt)", 6))
            }
        }

        return lines
    }

    public static func generateTagsLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let tags = image.tags, !tags.isEmpty {
            let tagsString = tags.joined(separator: ", ")
            let maxLineWidth = 70

            if tagsString.count <= maxLineWidth {
                lines.append((tagsString, 5))
            } else {
                // Split long tag lists across multiple lines
                var remainingTags = tagsString
                while !remainingTags.isEmpty {
                    let lineWidth = min(remainingTags.count, maxLineWidth)
                    let lineEnd = remainingTags.index(remainingTags.startIndex, offsetBy: lineWidth)
                    var line = String(remainingTags[..<lineEnd])

                    // Try to break at a comma if possible
                    if remainingTags.count > lineWidth, let lastComma = line.lastIndex(of: ",") {
                        line = String(line[..<lastComma])
                        remainingTags = String(remainingTags[line.index(after: line.endIndex)...]).trimmingCharacters(in: .whitespaces)
                    } else {
                        remainingTags = String(remainingTags[lineEnd...])
                    }

                    lines.append((line, 5))
                }
            }
        }

        return lines
    }

    public static func generateAdditionalInfoLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let checksum = image.checksum {
            let truncatedChecksum = checksum.count > 50 ? String(checksum.prefix(47)) + "..." : checksum
            lines.append(("Checksum: \(truncatedChecksum)", 6))
        }

        if let owner = image.owner {
            lines.append(("Owner: \(owner)", 6))
        }

        if let protected = image.protected {
            let protectedColor: Int32 = protected ? 7 : 5
            lines.append(("Protected: \(protected ? "Yes" : "No")", protectedColor))
        }

        return lines
    }

    public static func generateTimestampLines(image: Image) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let created = image.createdAt {
            lines.append(("Created: \(created)", 6))
        }

        if let updated = image.updatedAt {
            lines.append(("Updated: \(updated)", 6))
        }

        return lines
    }

    // MARK: - Multi-Column Layout Functions

    public static func generateClassifiedPropertySections(classifiedProperties: ClassifiedProperties) -> [Section] {
        var sections: [Section] = []

        if !classifiedProperties.operatingSystem.isEmpty {
            sections.append(Section(title: "Operating System",
                                  lines: generatePropertyLines(properties: classifiedProperties.operatingSystem),
                                  priority: 1))
        }

        if !classifiedProperties.architecture.isEmpty {
            sections.append(Section(title: "Architecture",
                                  lines: generatePropertyLines(properties: classifiedProperties.architecture),
                                  priority: 1))
        }

        if !classifiedProperties.virtualization.isEmpty {
            sections.append(Section(title: "Virtualization",
                                  lines: generatePropertyLines(properties: classifiedProperties.virtualization),
                                  priority: 2))
        }

        if !classifiedProperties.security.isEmpty {
            sections.append(Section(title: "Security",
                                  lines: generatePropertyLines(properties: classifiedProperties.security),
                                  priority: 2))
        }

        if !classifiedProperties.storage.isEmpty {
            sections.append(Section(title: "Storage",
                                  lines: generatePropertyLines(properties: classifiedProperties.storage),
                                  priority: 2))
        }

        if !classifiedProperties.cloud.isEmpty {
            sections.append(Section(title: "Cloud",
                                  lines: generatePropertyLines(properties: classifiedProperties.cloud),
                                  priority: 2))
        }

        if !classifiedProperties.other.isEmpty {
            sections.append(Section(title: "Other Properties",
                                  lines: generatePropertyLines(properties: classifiedProperties.other),
                                  priority: 3))
        }

        return sections
    }

    private static func generatePropertyLines(properties: [String: String]) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            let truncatedKey = key.count > 25 ? String(key.prefix(22)) + "..." : key
            let truncatedValue = value.count > 40 ? String(value.prefix(37)) + "..." : value
            lines.append(("  \(truncatedKey): \(truncatedValue)", 6))
        }
        return lines
    }


    public static func calculateTotalLinesForSections(sections: [Section], useMultiColumn: Bool) -> Int {
        if useMultiColumn {
            let highPrioritySections = sections.filter { $0.priority == 1 }
            let mediumPrioritySections = sections.filter { $0.priority == 2 }
            let lowPrioritySections = sections.filter { $0.priority == 3 }

            var leftColumnLines = 0
            var rightColumnLines = 0

            // Count lines for left column (high priority + low priority)
            for section in highPrioritySections + lowPrioritySections {
                if !section.lines.isEmpty {
                    leftColumnLines += 1 + section.lines.count + 1 // title + lines + blank
                }
            }

            // Count lines for right column (medium priority)
            for section in mediumPrioritySections {
                if !section.lines.isEmpty {
                    rightColumnLines += 1 + section.lines.count + 1 // title + lines + blank
                }
            }

            return max(leftColumnLines, rightColumnLines)
        } else {
            var totalLines = 0
            for section in sections {
                if !section.lines.isEmpty {
                    totalLines += 1 + section.lines.count + 1 // title + lines + blank
                }
            }
            return totalLines
        }
    }

    // MARK: - Image Create Form View

    /// Draw the image create form
    @MainActor
    static func drawImageCreateForm(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: ImageCreateForm,
        formState: FormBuilderState
    ) async {
        // Defensive bounds checking
        guard width > 20 && height > 10 else {
            let surface = SwiftNCurses.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftNCurses.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftNCurses.surface(from: screen)

        // Build form fields
        let fields = form.buildFields(
            selectedFieldId: formState.getCurrentFieldId(),
            activeFieldId: formState.getActiveFieldId(),
            formState: formState
        )

        // Create FormBuilder
        let formBuilder = FormBuilder(
            title: "Create New Image",
            fields: fields,
            selectedFieldId: formState.getCurrentFieldId(),
            validationErrors: form.validateForm(),
            showValidationErrors: formState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftNCurses.render(formBuilder.render(), on: surface, in: bounds)
    }
}