import Foundation
import OSClient
import SwiftTUI

struct ImageViews {

    // MARK: - Image List View (Gold Standard Pattern following RouterViews)

    @MainActor
    static func drawDetailedImageList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                    width: Int32, height: Int32, cachedImages: [Image],
                                    searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

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
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Image Detail View (Gold Standard Pattern)

    // Detail View Layout Constants
    private static let imageDetailTopPadding: Int32 = 2
    private static let imageDetailBottomPadding: Int32 = 2
    private static let imageDetailLeadingPadding: Int32 = 0
    private static let imageDetailTrailingPadding: Int32 = 0
    private static let imageDetailBasicInfoSpacing: Int32 = 0
    private static let imageDetailTechnicalInfoSpacing: Int32 = 0
    private static let imageDetailSectionSpacing: Int32 = 1
    private static let imageDetailMinScreenWidth: Int32 = 40
    private static let imageDetailMinScreenHeight: Int32 = 15
    private static let imageDetailBoundsMinWidth: Int32 = 1
    private static let imageDetailBoundsMinHeight: Int32 = 1
    private static let imageDetailComponentSpacing: Int32 = 0

    // Detail View Layout Constants (Matching Gold Standard)
    private static let imageDetailTitleTopPadding: Int32 = 0
    private static let imageDetailTitleLeadingPadding: Int32 = 0
    private static let imageDetailTitleBottomPadding: Int32 = 2
    private static let imageDetailTitleTrailingPadding: Int32 = 0
    private static let imageDetailSectionTopPadding: Int32 = 0
    private static let imageDetailSectionLeadingPadding: Int32 = 4
    private static let imageDetailSectionBottomPadding: Int32 = 1
    private static let imageDetailSectionTrailingPadding: Int32 = 0
    private static let imageDetailInfoFieldIndent = "  "
    private static let imageDetailFieldValueSeparator = ": "

    // Detail View EdgeInsets (Pre-calculated for Performance)
    private static let imageDetailTitleEdgeInsets = EdgeInsets(top: imageDetailTitleTopPadding, leading: imageDetailTitleLeadingPadding, bottom: imageDetailTitleBottomPadding, trailing: imageDetailTitleTrailingPadding)
    private static let imageDetailSectionEdgeInsets = EdgeInsets(top: imageDetailSectionTopPadding, leading: imageDetailSectionLeadingPadding, bottom: imageDetailSectionBottomPadding, trailing: imageDetailSectionTrailingPadding)

    // Detail View Layout Constants (Extended)
    private static let imageDetailReservedSpace: Int32 = 8
    private static let imageDetailPropertyKeyMaxLength = 25
    private static let imageDetailPropertyValueMaxLength = 40
    private static let imageDetailTagsMaxLineWidth = 70
    private static let imageDetailChecksumMaxLength = 50
    private static let imageDetailScrollThreshold = 15

    // Detail View Text Constants
    private static let imageDetailTitle = "Image Details"
    private static let imageDetailBasicInfoTitle = "Basic Information"
    private static let imageDetailTechnicalInfoTitle = "Technical Information"
    private static let imageDetailServerSnapshotTitle = "Server Snapshot"
    private static let imageDetailOperatingSystemTitle = "Operating System"
    private static let imageDetailArchitectureTitle = "Architecture"
    private static let imageDetailVirtualizationTitle = "Virtualization"
    private static let imageDetailSecurityTitle = "Security"
    private static let imageDetailStorageTitle = "Storage"
    private static let imageDetailCloudTitle = "Cloud"
    private static let imageDetailTagsTitle = "Tags"
    private static let imageDetailOtherPropertiesTitle = "Other Properties"
    private static let imageDetailAdditionalInfoTitle = "Additional Information"
    private static let imageDetailTimestampsTitle = "Timestamps"
    private static let imageDetailNameLabel = "Name"
    private static let imageDetailIdLabel = "ID"
    private static let imageDetailStatusLabel = "Status"
    private static let imageDetailVisibilityLabel = "Visibility"
    private static let imageDetailSizeLabel = "Size"
    private static let imageDetailDiskFormatLabel = "Disk Format"
    private static let imageDetailContainerFormatLabel = "Container Format"
    private static let imageDetailMinDiskLabel = "Minimum Disk"
    private static let imageDetailMinRamLabel = "Minimum RAM"
    private static let imageDetailOwnerLabel = "Owner"
    private static let imageDetailProtectedLabel = "Protected"
    private static let imageDetailChecksumLabel = "Checksum"
    private static let imageDetailCreatedLabel = "Created"
    private static let imageDetailUpdatedLabel = "Updated"
    private static let imageDetailSourceServerLabel = "Source Server"
    private static let imageDetailSourceServerIdLabel = "Source Server ID"
    private static let imageDetailSnapshotCreatedByLabel = "Created by"
    private static let imageDetailSnapshotCreatedAtLabel = "Snapshot Created"
    private static let imageDetailUnnamedText = "Unnamed Image"
    private static let imageDetailUnknownText = "Unknown"
    private static let imageDetailNoOwnerText = "No owner"
    private static let imageDetailNoChecksumText = "No checksum"
    private static let imageDetailNoTagsText = "No tags"
    private static let imageDetailProtectedYes = "Yes"
    private static let imageDetailProtectedNo = "No"
    private static let imageDetailSizeFormat = "%.2f GB"
    private static let imageDetailMinDiskFormat = "%d GB"
    private static let imageDetailMinRamFormat = "%d MB"
    private static let imageDetailScreenTooSmallText = "Screen too small"
    private static let imageDetailSizeConversionFactor: Double = 1024 * 1024 * 1024
    private static let imageDetailPropertyKeySuffix = ":"
    private static let imageDetailTruncationSuffix = "..."
    private static let imageDetailTagSeparator = ", "
    private static let imageDetailScrollIndicatorPrefix = "["
    private static let imageDetailScrollIndicatorSeparator = "-"
    private static let imageDetailScrollIndicatorMiddle = "/"
    private static let imageDetailScrollIndicatorSuffix = "] - Scroll: UP/DOWN"

    @MainActor
    static func drawImageDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                              width: Int32, height: Int32, image: Image, scrollOffset: Int = 0) async {

        // Create surface for optimal performance (EXACT Gold Standard Pattern)
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > imageDetailMinScreenWidth && height > imageDetailMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow),
                                   width: max(imageDetailBoundsMinWidth, width),
                                   height: max(imageDetailBoundsMinHeight, height))
            await SwiftTUI.render(Text(imageDetailScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Image Detail (following EXACT RouterViews pattern)
        var components: [any Component] = []

        // Title - EXACT RouterViews pattern
        let imageName = image.name ?? imageDetailUnnamedText
        let titleText = imageDetailTitle + imageDetailFieldValueSeparator + imageName
        components.append(Text(titleText).accent().bold()
                         .padding(imageDetailTitleEdgeInsets))

        // Basic Information Section - Individual components for proper scrolling
        components.append(Text(imageDetailBasicInfoTitle).primary().bold())
        components.append(contentsOf: createBasicInfoComponents(image: image))

        // Technical Information Section
        components.append(Text(imageDetailTechnicalInfoTitle).primary().bold())
        components.append(contentsOf: createTechnicalInfoComponents(image: image))

        // Classified Properties Sections (preserve rich metadata)
        let classifiedProperties = classifyImageProperties(image: image)
        let classifiedSections = createClassifiedPropertySections(classifiedProperties: classifiedProperties)
        components.append(contentsOf: classifiedSections)

        // Server Snapshot Section
        let serverSnapshotComponents = createServerSnapshotComponents(image: image)
        if !serverSnapshotComponents.isEmpty {
            components.append(Text(imageDetailServerSnapshotTitle).primary().bold())
            components.append(contentsOf: serverSnapshotComponents)
        }

        // Tags Section
        let tagsComponents = createTagsComponents(image: image)
        if !tagsComponents.isEmpty {
            components.append(Text(imageDetailTagsTitle).primary().bold())
            components.append(contentsOf: tagsComponents)
        }

        // Additional Information Section
        let additionalInfoComponents = createAdditionalInfoComponents(image: image)
        if !additionalInfoComponents.isEmpty {
            components.append(Text(imageDetailAdditionalInfoTitle).primary().bold())
            components.append(contentsOf: additionalInfoComponents)
        }

        // Timestamps Section
        let timestampComponents = createTimestampComponents(image: image)
        if !timestampComponents.isEmpty {
            components.append(Text(imageDetailTimestampsTitle).primary().bold())
            components.append(contentsOf: timestampComponents)
        }

        // Apply scrolling and render visible components
        let maxVisibleComponents = max(1, Int(height) - Int(imageDetailReservedSpace))
        let startIndex = max(0, min(scrollOffset, components.count - maxVisibleComponents))
        let endIndex = min(components.count, startIndex + maxVisibleComponents)
        let visibleComponents = Array(components[startIndex..<endIndex])

        // DEBUG: Log scrolling info to see what's happening
        Logger.shared.logInfo("ImageViews Debug - scrollOffset: \(scrollOffset), components.count: \(components.count), maxVisibleComponents: \(maxVisibleComponents), startIndex: \(startIndex), endIndex: \(endIndex), height: \(height), reservedSpace: \(imageDetailReservedSpace)")


        // Render using EXACT RouterViews pattern with scrolling
        let imageDetailComponent = VStack(spacing: imageDetailComponentSpacing, children: visibleComponents)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(imageDetailComponent, on: surface, in: bounds)

        // Add scroll indicators if needed
        if components.count > maxVisibleComponents {
            let scrollText = imageDetailScrollIndicatorPrefix + String(startIndex + 1) + imageDetailScrollIndicatorSeparator + String(endIndex) + imageDetailScrollIndicatorMiddle + String(components.count) + imageDetailScrollIndicatorSuffix
            let scrollBounds = Rect(x: startCol, y: startRow + height - 1, width: width, height: 1)
            await SwiftTUI.render(Text(scrollText).info(), on: surface, in: scrollBounds)
        }
    }

    // MARK: - Gold Standard Component Creation Functions (EXACT RouterViews Pattern)

    private static func createBasicInfoComponents(image: Image) -> [any Component] {
        var components: [any Component] = []

        // Pre-calculate common field prefixes for optimal performance (RouterViews pattern)
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        // Name
        let imageName = image.name ?? imageDetailUnnamedText
        let nameText = fieldPrefix + imageDetailNameLabel + fieldSeparator + imageName
        components.append(Text(nameText).secondary())

        // ID
        let idText = fieldPrefix + imageDetailIdLabel + fieldSeparator + image.id
        components.append(Text(idText).secondary())

        // Status - with color coding like RouterViews
        let status = image.status ?? imageDetailUnknownText
        let statusText = fieldPrefix + imageDetailStatusLabel + fieldSeparator + status
        if status.lowercased() == "active" {
            components.append(Text(statusText).success())
        } else if status.lowercased().contains("error") {
            components.append(Text(statusText).error())
        } else {
            components.append(Text(statusText).secondary())
        }

        // Visibility
        if let visibility = image.visibility {
            let visibilityText = fieldPrefix + imageDetailVisibilityLabel + fieldSeparator + visibility
            components.append(Text(visibilityText).secondary())
        }

        return components
    }

    private static func createTechnicalInfoComponents(image: Image) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        // Size
        if let size = image.size {
            let sizeGB = Double(size) / imageDetailSizeConversionFactor
            let sizeText = fieldPrefix + imageDetailSizeLabel + fieldSeparator + String(format: imageDetailSizeFormat, sizeGB)
            components.append(Text(sizeText).secondary())
        }

        // Disk Format
        if let diskFormat = image.diskFormat {
            let diskFormatText = fieldPrefix + imageDetailDiskFormatLabel + fieldSeparator + diskFormat
            components.append(Text(diskFormatText).secondary())
        }

        // Container Format
        if let containerFormat = image.containerFormat {
            let containerFormatText = fieldPrefix + imageDetailContainerFormatLabel + fieldSeparator + containerFormat
            components.append(Text(containerFormatText).secondary())
        }

        // Min Disk
        if let minDisk = image.minDisk, minDisk > 0 {
            let minDiskText = fieldPrefix + imageDetailMinDiskLabel + fieldSeparator + String(format: imageDetailMinDiskFormat, minDisk)
            components.append(Text(minDiskText).secondary())
        }

        // Min RAM
        if let minRam = image.minRam, minRam > 0 {
            let minRamText = fieldPrefix + imageDetailMinRamLabel + fieldSeparator + String(format: imageDetailMinRamFormat, minRam)
            components.append(Text(minRamText).secondary())
        }

        return components
    }

    private static func createClassifiedPropertySections(classifiedProperties: ClassifiedProperties) -> [any Component] {
        var components: [any Component] = []

        // Operating System Properties
        if !classifiedProperties.operatingSystem.isEmpty {
            components.append(Text(imageDetailOperatingSystemTitle).primary().bold())
            let osComponents = createPropertyComponents(properties: classifiedProperties.operatingSystem)
            let osSection = VStack(spacing: 0, children: osComponents).padding(imageDetailSectionEdgeInsets)
            components.append(osSection)
        }

        // Architecture Properties
        if !classifiedProperties.architecture.isEmpty {
            components.append(Text(imageDetailArchitectureTitle).primary().bold())
            let archComponents = createPropertyComponents(properties: classifiedProperties.architecture)
            let archSection = VStack(spacing: 0, children: archComponents).padding(imageDetailSectionEdgeInsets)
            components.append(archSection)
        }

        // Virtualization Properties
        if !classifiedProperties.virtualization.isEmpty {
            components.append(Text(imageDetailVirtualizationTitle).primary().bold())
            let virtComponents = createPropertyComponents(properties: classifiedProperties.virtualization)
            let virtSection = VStack(spacing: 0, children: virtComponents).padding(imageDetailSectionEdgeInsets)
            components.append(virtSection)
        }

        // Security Properties
        if !classifiedProperties.security.isEmpty {
            components.append(Text(imageDetailSecurityTitle).primary().bold())
            let secComponents = createPropertyComponents(properties: classifiedProperties.security)
            let secSection = VStack(spacing: 0, children: secComponents).padding(imageDetailSectionEdgeInsets)
            components.append(secSection)
        }

        // Storage Properties
        if !classifiedProperties.storage.isEmpty {
            components.append(Text(imageDetailStorageTitle).primary().bold())
            let storageComponents = createPropertyComponents(properties: classifiedProperties.storage)
            let storageSection = VStack(spacing: 0, children: storageComponents).padding(imageDetailSectionEdgeInsets)
            components.append(storageSection)
        }

        // Cloud Properties
        if !classifiedProperties.cloud.isEmpty {
            components.append(Text(imageDetailCloudTitle).primary().bold())
            let cloudComponents = createPropertyComponents(properties: classifiedProperties.cloud)
            let cloudSection = VStack(spacing: 0, children: cloudComponents).padding(imageDetailSectionEdgeInsets)
            components.append(cloudSection)
        }

        // Other Properties
        if !classifiedProperties.other.isEmpty {
            components.append(Text(imageDetailOtherPropertiesTitle).primary().bold())
            let otherComponents = createPropertyComponents(properties: classifiedProperties.other)
            let otherSection = VStack(spacing: 0, children: otherComponents).padding(imageDetailSectionEdgeInsets)
            components.append(otherSection)
        }

        return components
    }

    private static func createPropertyComponents(properties: [String: String]) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            let propertyText = fieldPrefix + key + fieldSeparator + value
            components.append(Text(propertyText).secondary())
        }

        return components
    }

    private static func createServerSnapshotComponents(image: Image) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        guard let metadata = image.metadata else { return components }

        // Source Server Name
        if let sourceServerName = metadata["source_server_name"] {
            let serverText = fieldPrefix + imageDetailSourceServerLabel + fieldSeparator + sourceServerName
            components.append(Text(serverText).secondary())
        }

        // Source Server ID
        if let sourceServerId = metadata["source_server_id"] {
            let serverIdText = fieldPrefix + imageDetailSourceServerIdLabel + fieldSeparator + sourceServerId
            components.append(Text(serverIdText).secondary())
        }

        // Snapshot Created By
        if let createdBy = metadata["snapshot_created_by"] {
            let createdByText = fieldPrefix + imageDetailSnapshotCreatedByLabel + fieldSeparator + createdBy
            components.append(Text(createdByText).secondary())
        }

        // Snapshot Created At
        if let snapshotCreatedAt = metadata["snapshot_created_at"] {
            let snapshotCreatedText = fieldPrefix + imageDetailSnapshotCreatedAtLabel + fieldSeparator + snapshotCreatedAt
            components.append(Text(snapshotCreatedText).secondary())
        }

        return components
    }

    private static func createTagsComponents(image: Image) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent

        guard let tags = image.tags, !tags.isEmpty else { return components }

        let tagsString = tags.joined(separator: imageDetailTagSeparator)
        let tagsText = fieldPrefix + tagsString
        components.append(Text(tagsText).secondary())

        return components
    }

    private static func createAdditionalInfoComponents(image: Image) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        // Owner
        if let owner = image.owner {
            let ownerText = fieldPrefix + imageDetailOwnerLabel + fieldSeparator + owner
            components.append(Text(ownerText).secondary())
        }

        // Protected status
        if let protected = image.protected {
            let protectedValue = protected ? imageDetailProtectedYes : imageDetailProtectedNo
            let protectedText = fieldPrefix + imageDetailProtectedLabel + fieldSeparator + protectedValue
            if protected {
                components.append(Text(protectedText).success())
            } else {
                components.append(Text(protectedText).secondary())
            }
        }

        // Checksum
        if let checksum = image.checksum {
            let checksumText = fieldPrefix + imageDetailChecksumLabel + fieldSeparator + checksum
            components.append(Text(checksumText).secondary())
        }

        return components
    }

    private static func createTimestampComponents(image: Image) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = imageDetailInfoFieldIndent
        let fieldSeparator = imageDetailFieldValueSeparator

        // Created At
        if let created = image.createdAt {
            let createdText = fieldPrefix + imageDetailCreatedLabel + fieldSeparator + created.description
            components.append(Text(createdText).secondary())
        }

        // Updated At
        if let updated = image.updatedAt {
            let updatedText = fieldPrefix + imageDetailUpdatedLabel + fieldSeparator + updated.description
            components.append(Text(updatedText).secondary())
        }

        return components
    }

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


    // MARK: - Compact Detail Layout (Gold Standard Pattern)

    @MainActor
    private static func drawCompactImageDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                             width: Int32, height: Int32, image: Image,
                                             classifiedProperties: ClassifiedProperties) async {

        let surface = SwiftTUI.surface(from: screen)
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
        await SwiftTUI.render(imageDetailComponent, on: surface, in: bounds)
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

    private static func needsScrollableLayout(image: Image, classifiedProperties: ClassifiedProperties, availableHeight: Int32) -> Bool {
        // Estimate component count for layout decision
        var estimatedComponents = imageDetailScrollThreshold // Base components (title, basic info, technical info)

        // Add metadata sections
        if !classifiedProperties.operatingSystem.isEmpty { estimatedComponents += classifiedProperties.operatingSystem.count + 1 }
        if !classifiedProperties.architecture.isEmpty { estimatedComponents += classifiedProperties.architecture.count + 1 }
        if !classifiedProperties.virtualization.isEmpty { estimatedComponents += classifiedProperties.virtualization.count + 1 }
        if !classifiedProperties.security.isEmpty { estimatedComponents += classifiedProperties.security.count + 1 }
        if !classifiedProperties.storage.isEmpty { estimatedComponents += classifiedProperties.storage.count + 1 }
        if !classifiedProperties.cloud.isEmpty { estimatedComponents += classifiedProperties.cloud.count + 1 }
        if !classifiedProperties.other.isEmpty { estimatedComponents += classifiedProperties.other.count + 1 }

        // Add server snapshot info if available
        if let metadata = image.metadata, metadata["source_server_id"] != nil {
            estimatedComponents += 5
        }

        // Add tags if available
        if let tags = image.tags, !tags.isEmpty {
            estimatedComponents += 3
        }

        return estimatedComponents > Int(availableHeight)
    }

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
}