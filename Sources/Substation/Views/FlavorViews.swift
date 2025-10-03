import Foundation
import OSClient
import SwiftTUI

struct FlavorViews {

    // MARK: - Constants

    // Layout Constants
    private static let flavorDetailMinScreenWidth: Int32 = 40
    private static let flavorDetailMinScreenHeight: Int32 = 15
    private static let flavorDetailBoundsMinWidth: Int32 = 1
    private static let flavorDetailBoundsMinHeight: Int32 = 1
    private static let flavorDetailComponentSpacing: Int32 = 1
    private static let flavorDetailTopPadding: Int32 = 2
    private static let flavorDetailBottomPadding: Int32 = 2
    private static let flavorDetailLeadingPadding: Int32 = 0
    private static let flavorDetailTrailingPadding: Int32 = 0
    private static let flavorDetailReservedSpace: Int32 = 4

    // Title Constants
    private static let flavorDetailTitleTopPadding: Int32 = 0
    private static let flavorDetailTitleLeadingPadding: Int32 = 0
    private static let flavorDetailTitleBottomPadding: Int32 = 2
    private static let flavorDetailTitleTrailingPadding: Int32 = 0
    private static let flavorDetailTitleEdgeInsets = EdgeInsets(top: flavorDetailTitleTopPadding, leading: flavorDetailTitleLeadingPadding, bottom: flavorDetailTitleBottomPadding, trailing: flavorDetailTitleTrailingPadding)

    // Section Constants
    private static let flavorDetailSectionTopPadding: Int32 = 1
    private static let flavorDetailSectionLeadingPadding: Int32 = 2
    private static let flavorDetailSectionBottomPadding: Int32 = 1
    private static let flavorDetailSectionTrailingPadding: Int32 = 0
    private static let flavorDetailSectionEdgeInsets = EdgeInsets(top: flavorDetailSectionTopPadding, leading: flavorDetailSectionLeadingPadding, bottom: flavorDetailSectionBottomPadding, trailing: flavorDetailSectionTrailingPadding)

    // Section Titles
    private static let flavorDetailTitle = "Flavor Details"
    private static let flavorDetailBasicInfoTitle = "Basic Information"
    private static let flavorDetailResourceTitle = "Resource Specifications"
    private static let flavorDetailPerformanceTitle = "Performance Analysis"
    private static let flavorDetailUsageRecommendationsTitle = "Usage Recommendations"
    private static let flavorDetailAccessTitle = "Access Configuration"
    private static let flavorDetailNetworkingTitle = "Networking"

    // Field Labels
    private static let flavorDetailIdLabel = "ID"
    private static let flavorDetailNameLabel = "Name"
    private static let flavorDetailVCPUsLabel = "vCPUs"
    private static let flavorDetailRAMLabel = "RAM"
    private static let flavorDetailRootDiskLabel = "Root Disk"
    private static let flavorDetailEphemeralDiskLabel = "Ephemeral Disk"
    private static let flavorDetailSwapLabel = "Swap"
    private static let flavorDetailRxtxFactorLabel = "RX/TX Factor"
    private static let flavorDetailPublicLabel = "Public"
    private static let flavorDetailDisabledLabel = "Disabled"
    private static let flavorDetailPerformanceTierLabel = "Performance Tier"
    private static let flavorDetailCpuMemoryRatioLabel = "CPU/Memory Ratio"
    private static let flavorDetailStorageTypeLabel = "Storage Type"
    private static let flavorDetailUsageCategoryLabel = "Usage Category"
    private static let flavorDetailRecommendedWorkloadsLabel = "Recommended Workloads"
    private static let flavorDetailLimitationsLabel = "Limitations"

    // Text Constants
    private static let flavorDetailFieldValueSeparator = ": "
    private static let flavorDetailInfoFieldIndent = "  "
    private static let flavorDetailScreenTooSmallText = "Screen too small"
    private static let flavorDetailMBSuffix = " MB"
    private static let flavorDetailGBSuffix = " GB"
    private static let flavorDetailYesText = "Yes"
    private static let flavorDetailNoText = "No"
    private static let flavorDetailUnknownText = "Unknown"
    private static let flavorDetailNoLimitationsText = "None identified"
    private static let flavorDetailHelpText = "ESC: Return"
    private static let flavorDetailGBPerVCPUFormat = "%.1f GB per vCPU"
    private static let flavorDetailWorkloadSeparator = ", "
    private static let flavorDetailLimitationPrefix = "- "


    // Section Management
    struct Section {
        let title: String
        let lines: [(String, Int32)]
        let priority: Int
    }
    @MainActor
    static func drawDetailedFlavorList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                     width: Int32, height: Int32, cachedFlavors: [Flavor],
                                     searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Main Flavor List
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        let titleText = searchQuery.map { "Flavors (filtered: \($0))" } ?? "Flavors"
        components.append(Text(titleText).emphasis().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        // Header
        components.append(Text(" ST  NAME                           VCPUS   RAM        DISK").muted()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)).border())

        // Content - get filtered flavors and create list components
        let filteredFlavors = FilterUtils.filterFlavors(cachedFlavors, query: searchQuery)

        if filteredFlavors.isEmpty {
            components.append(Text("No flavors found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            // Calculate visible range for simple viewport
            let maxVisibleItems = max(1, Int(height) - 10) // Reserve space for header and footer
            let startIndex = max(0, min(scrollOffset, filteredFlavors.count - maxVisibleItems))
            let endIndex = min(filteredFlavors.count, startIndex + maxVisibleItems)

            for i in startIndex..<endIndex {
                let flavor = filteredFlavors[i]
                let isSelected = i == selectedIndex
                let flavorComponent = createFlavorListItemComponent(flavor: flavor, isSelected: isSelected)
                components.append(flavorComponent)
            }

            // Scroll indicator if needed
            if filteredFlavors.count > maxVisibleItems {
                let scrollText = "[\(startIndex + 1)-\(endIndex)/\(filteredFlavors.count)]"
                components.append(Text(scrollText).info()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
            }
        }

        // Render unified flavor list
        let flavorListComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(flavorListComponent, on: surface, in: bounds)
    }

    // MARK: - Component Creation Functions

    private static func createFlavorListItemComponent(flavor: Flavor, isSelected: Bool) -> any Component {
        // Flavor name with formatting
        let flavorName = String((flavor.name ?? "Unknown").prefix(32)).padding(toLength: 32, withPad: " ", startingAt: 0)

        // Resource information
        let vcpusText = String(flavor.vcpus)
        let vcpusDisplay = String(vcpusText.prefix(7)).padding(toLength: 7, withPad: " ", startingAt: 0)

        let ramText = "\(flavor.ram)MB"
        let ramDisplay = String(ramText.prefix(10)).padding(toLength: 10, withPad: " ", startingAt: 0)

        let diskText = "\(flavor.disk)GB"
        let diskDisplay = String(diskText.prefix(8)).padding(toLength: 8, withPad: " ", startingAt: 0)

        let rowStyle: TextStyle = isSelected ? .accent : .secondary

        return HStack(spacing: 0, children: [
            StatusIcon(status: "active"),
            Text(" \(flavorName)").styled(rowStyle),
            Text(" \(vcpusDisplay)").styled(.info),
            Text(" \(ramDisplay)").styled(.accent),
            Text(" \(diskDisplay)").styled(.success)
        ]).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
    }

    // MARK: - Gold Standard Flavor Detail (Enhanced with Rich Metadata)

    @MainActor
    static func drawFlavorDetailGoldStandard(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                           width: Int32, height: Int32, flavor: Flavor, scrollOffset: Int32 = 0) async {

        // Flavor analysis for rich metadata display
        let flavorAnalysis = analyzeFlavorCapabilities(flavor: flavor)

        // Enhanced title using SwiftTUI with gold standard coloring
        let surface = SwiftTUI.surface(from: screen)
        let titleBounds = Rect(x: startCol + 2, y: startRow, width: width - 4, height: 1)
        let titleText = flavorDetailTitle + flavorDetailFieldValueSeparator + (flavor.name ?? "Unknown")
        await SwiftTUI.render(Text(titleText).accent().bold(), on: surface, in: titleBounds)

        let contentHeight = Int(height) - 4  // Reserve space for header and footer
        let contentStartRow = startRow + 2
        let availableWidth = Int(width) - 6  // Account for margins

        // Use multi-column layout if we have enough width
        let useMultiColumn = availableWidth >= 120
        let leftColumnWidth = useMultiColumn ? availableWidth / 2 - 2 : availableWidth
        let rightColumnWidth = useMultiColumn ? availableWidth / 2 - 2 : 0
        let rightColumnStart = startCol + Int32(leftColumnWidth) + 6

        var allSections: [Section] = []

        // Create sections for better organization (using gold standard approach)
        allSections.append(Section(title: flavorDetailBasicInfoTitle,
                                 lines: generateGoldStandardBasicInfoLines(flavor: flavor),
                                 priority: 1))
        allSections.append(Section(title: flavorDetailResourceTitle,
                                 lines: generateGoldStandardResourceLines(flavor: flavor),
                                 priority: 1))

        // Add performance analysis sections
        allSections.append(Section(title: flavorDetailPerformanceTitle,
                                 lines: generateGoldStandardPerformanceLines(analysis: flavorAnalysis),
                                 priority: 2))
        allSections.append(Section(title: flavorDetailUsageRecommendationsTitle,
                                 lines: generateGoldStandardUsageLines(analysis: flavorAnalysis),
                                 priority: 2))
        allSections.append(Section(title: flavorDetailAccessTitle,
                                 lines: generateGoldStandardAccessLines(flavor: flavor),
                                 priority: 2))
        allSections.append(Section(title: flavorDetailNetworkingTitle,
                                 lines: generateGoldStandardNetworkingLines(flavor: flavor),
                                 priority: 3))

        // Add detailed properties section
        allSections.append(Section(title: "Hardware Properties",
                                 lines: generateHardwarePropertiesLines(flavor: flavor),
                                 priority: 2))

        // Add quota specifications section
        allSections.append(Section(title: "Resource Quotas",
                                 lines: generateResourceQuotasLines(flavor: flavor),
                                 priority: 3))

        // Add raw properties section for debugging/reference
        allSections.append(Section(title: "Raw Properties",
                                 lines: generateRawPropertiesLines(flavor: flavor),
                                 priority: 4))

        // Filter out empty sections
        let nonEmptySections = allSections.filter { !$0.lines.isEmpty }

        if useMultiColumn {
            await drawMultiColumnFlavorLayout(screen: screen, sections: nonEmptySections,
                                            startRow: contentStartRow, startCol: startCol,
                                            leftColumnWidth: leftColumnWidth, rightColumnWidth: rightColumnWidth,
                                            rightColumnStart: rightColumnStart, contentHeight: contentHeight,
                                            scrollOffset: scrollOffset)
        } else {
            await drawSingleColumnFlavorLayout(screen: screen, sections: nonEmptySections,
                                             startRow: contentStartRow, startCol: startCol,
                                             columnWidth: leftColumnWidth, contentHeight: contentHeight,
                                             scrollOffset: scrollOffset)
        }

        // Show scroll indicators and navigation help
        let totalLines = calculateTotalLinesForFlavorSections(sections: nonEmptySections, useMultiColumn: useMultiColumn)
        let footerRow = startRow + height - 2
        // Enhanced footer using SwiftTUI
        let canScrollUp = scrollOffset > 0
        let canScrollDown = Int(scrollOffset) + contentHeight < totalLines

        var footerText = "ESC: Return"
        if totalLines > contentHeight {
            footerText += " | UP/DOWN: Scroll"
            if canScrollUp || canScrollDown {
                footerText += " (Line \\(Int(scrollOffset) + 1)/\\(totalLines))"
            }
        }

        let footerBounds = Rect(x: startCol + 2, y: footerRow, width: width - 4, height: 1)
        await SwiftTUI.render(Text(footerText).info(), on: surface, in: footerBounds)
    }

    // MARK: - Flavor Analysis (Rich Metadata)

    struct FlavorAnalysis {
        let performanceTier: PerformanceTier
        let cpuToMemoryRatio: Double
        let storageType: StorageType
        let usageCategory: UsageCategory
        let recommendedWorkloads: [String]
        let limitations: [String]
    }

    enum PerformanceTier: String {
        case nano = "Nano"
        case micro = "Micro"
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        case xlarge = "Extra Large"
        case xxlarge = "XXL"
    }

    enum StorageType: String {
        case noStorage = "No Storage"
        case minimal = "Minimal"
        case balanced = "Balanced"
        case storageOptimized = "Storage Optimized"
    }

    enum UsageCategory: String {
        case development = "Development/Testing"
        case webServers = "Web Servers"
        case databases = "Databases"
        case compute = "Compute Intensive"
        case memory = "Memory Intensive"
        case storage = "Storage Intensive"
        case general = "General Purpose"
    }

    private static func analyzeFlavorCapabilities(flavor: Flavor) -> FlavorAnalysis {
        let vcpus = flavor.vcpus
        let ram = flavor.ram
        let disk = flavor.disk
        let ephemeral = flavor.ephemeral ?? 0

        // Determine performance tier
        let performanceTier: PerformanceTier
        if vcpus <= 1 && ram <= 1024 {
            performanceTier = .nano
        } else if vcpus <= 1 && ram <= 2048 {
            performanceTier = .micro
        } else if vcpus <= 2 && ram <= 4096 {
            performanceTier = .small
        } else if vcpus <= 4 && ram <= 8192 {
            performanceTier = .medium
        } else if vcpus <= 8 && ram <= 16384 {
            performanceTier = .large
        } else if vcpus <= 16 && ram <= 32768 {
            performanceTier = .xlarge
        } else {
            performanceTier = .xxlarge
        }

        // Calculate CPU to memory ratio (GB per vCPU)
        let cpuToMemoryRatio = vcpus > 0 ? Double(ram) / 1024.0 / Double(vcpus) : 0.0

        // Determine storage type
        let totalStorage = disk + ephemeral
        let storageType: StorageType
        if totalStorage == 0 {
            storageType = .noStorage
        } else if totalStorage <= 20 {
            storageType = .minimal
        } else if totalStorage <= 100 {
            storageType = .balanced
        } else {
            storageType = .storageOptimized
        }

        // Determine usage category
        let usageCategory: UsageCategory
        if cpuToMemoryRatio < 1.5 {
            usageCategory = .compute
        } else if cpuToMemoryRatio > 6.0 {
            usageCategory = .memory
        } else if totalStorage > 100 {
            usageCategory = .storage
        } else if vcpus <= 2 && ram <= 4096 {
            usageCategory = .development
        } else if vcpus <= 4 && cpuToMemoryRatio >= 2.0 && cpuToMemoryRatio <= 4.0 {
            usageCategory = .webServers
        } else if cpuToMemoryRatio >= 4.0 && ram >= 8192 {
            usageCategory = .databases
        } else {
            usageCategory = .general
        }

        // Generate recommendations
        var recommendedWorkloads: [String] = []
        var limitations: [String] = []

        switch usageCategory {
        case .development:
            recommendedWorkloads = ["Development environments", "Testing", "Small applications"]
        case .webServers:
            recommendedWorkloads = ["Web servers", "API servers", "Load balancers"]
        case .databases:
            recommendedWorkloads = ["Databases", "In-memory caching", "Data processing"]
        case .compute:
            recommendedWorkloads = ["CPU-intensive tasks", "Scientific computing", "Batch processing"]
        case .memory:
            recommendedWorkloads = ["Memory-intensive applications", "Big data analytics", "Caching layers"]
        case .storage:
            recommendedWorkloads = ["File servers", "Content delivery", "Data archiving"]
        case .general:
            recommendedWorkloads = ["General purpose applications", "Microservices", "Container workloads"]
        }

        if ram < 1024 {
            limitations.append("Limited memory for production workloads")
        }
        if vcpus == 1 {
            limitations.append("Single-threaded performance limitations")
        }
        if totalStorage == 0 {
            limitations.append("No local storage - requires external volumes")
        }

        return FlavorAnalysis(
            performanceTier: performanceTier,
            cpuToMemoryRatio: cpuToMemoryRatio,
            storageType: storageType,
            usageCategory: usageCategory,
            recommendedWorkloads: recommendedWorkloads,
            limitations: limitations
        )
    }

    // MARK: - Gold Standard Line Generation Functions

    private static func generateGoldStandardBasicInfoLines(flavor: Flavor) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        let nameText = flavorDetailInfoFieldIndent + flavorDetailNameLabel + flavorDetailFieldValueSeparator + (flavor.name ?? "Unknown")
        lines.append((nameText, 6)) // .secondary() like RouterViews

        let idText = flavorDetailInfoFieldIndent + flavorDetailIdLabel + flavorDetailFieldValueSeparator + flavor.id
        lines.append((idText, 6)) // .secondary() like RouterViews

        return lines
    }

    private static func generateGoldStandardResourceLines(flavor: Flavor) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        let vcpus = flavor.vcpus
        if vcpus > 0 {
            let vcpusText = flavorDetailInfoFieldIndent + flavorDetailVCPUsLabel + flavorDetailFieldValueSeparator + String(vcpus)
            lines.append((vcpusText, 6)) // .secondary() like RouterViews
        }

        let ram = flavor.ram
        if ram > 0 {
            let ramText = flavorDetailInfoFieldIndent + flavorDetailRAMLabel + flavorDetailFieldValueSeparator + String(ram) + flavorDetailMBSuffix
            lines.append((ramText, 6)) // .secondary() like RouterViews
        }

        let disk = flavor.disk
        if disk > 0 {
            let diskText = flavorDetailInfoFieldIndent + flavorDetailRootDiskLabel + flavorDetailFieldValueSeparator + String(disk) + flavorDetailGBSuffix
            lines.append((diskText, 6)) // .secondary() like RouterViews
        }

        if let ephemeral = flavor.ephemeral, ephemeral > 0 {
            let ephemeralText = flavorDetailInfoFieldIndent + flavorDetailEphemeralDiskLabel + flavorDetailFieldValueSeparator + String(ephemeral) + flavorDetailGBSuffix
            lines.append((ephemeralText, 6)) // .secondary() like RouterViews
        }

        if let swap = flavor.swap, swap > 0 {
            let swapText = flavorDetailInfoFieldIndent + flavorDetailSwapLabel + flavorDetailFieldValueSeparator + String(swap) + flavorDetailMBSuffix
            lines.append((swapText, 6)) // .secondary() like RouterViews
        }

        if let rxtxFactor = flavor.rxtxFactor {
            let factorText = flavorDetailInfoFieldIndent + flavorDetailRxtxFactorLabel + flavorDetailFieldValueSeparator + String(rxtxFactor)
            lines.append((factorText, 6)) // .secondary() like RouterViews
        }

        return lines
    }

    private static func generateGoldStandardPerformanceLines(analysis: FlavorAnalysis) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        let tierText = flavorDetailInfoFieldIndent + flavorDetailPerformanceTierLabel + flavorDetailFieldValueSeparator + analysis.performanceTier.rawValue
        lines.append((tierText, 6)) // .secondary() like RouterViews

        let ratioText = flavorDetailInfoFieldIndent + flavorDetailCpuMemoryRatioLabel + flavorDetailFieldValueSeparator + String(format: flavorDetailGBPerVCPUFormat, analysis.cpuToMemoryRatio)
        lines.append((ratioText, 6)) // .secondary() like RouterViews

        let storageText = flavorDetailInfoFieldIndent + flavorDetailStorageTypeLabel + flavorDetailFieldValueSeparator + analysis.storageType.rawValue
        lines.append((storageText, 6)) // .secondary() like RouterViews

        let categoryText = flavorDetailInfoFieldIndent + flavorDetailUsageCategoryLabel + flavorDetailFieldValueSeparator + analysis.usageCategory.rawValue
        lines.append((categoryText, 6)) // .secondary() like RouterViews

        return lines
    }

    private static func generateGoldStandardUsageLines(analysis: FlavorAnalysis) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if !analysis.recommendedWorkloads.isEmpty {
            let workloadsText = flavorDetailInfoFieldIndent + flavorDetailRecommendedWorkloadsLabel + flavorDetailFieldValueSeparator + analysis.recommendedWorkloads.joined(separator: flavorDetailWorkloadSeparator)
            lines.append((workloadsText, 6)) // .secondary() like RouterViews
        }

        if !analysis.limitations.isEmpty {
            let limitationsTitle = flavorDetailInfoFieldIndent + flavorDetailLimitationsLabel + flavorDetailFieldValueSeparator
            lines.append((limitationsTitle, 6)) // .secondary() like RouterViews
            for limitation in analysis.limitations {
                let limitationText = flavorDetailInfoFieldIndent + flavorDetailLimitationPrefix + limitation
                lines.append((limitationText, 6)) // .secondary() like RouterViews
            }
        } else {
            let noLimitationsText = flavorDetailInfoFieldIndent + flavorDetailLimitationsLabel + flavorDetailFieldValueSeparator + flavorDetailNoLimitationsText
            lines.append((noLimitationsText, 6)) // .secondary() like RouterViews
        }

        return lines
    }

    private static func generateGoldStandardAccessLines(flavor: Flavor) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let isPublic = flavor.isPublic {
            let publicText = isPublic ? flavorDetailYesText : flavorDetailNoText
            let accessText = flavorDetailInfoFieldIndent + flavorDetailPublicLabel + flavorDetailFieldValueSeparator + publicText
            lines.append((accessText, 6)) // .secondary() like RouterViews
        }

        if let disabled = flavor.disabled {
            let disabledText = disabled ? flavorDetailYesText : flavorDetailNoText
            let statusText = flavorDetailInfoFieldIndent + flavorDetailDisabledLabel + flavorDetailFieldValueSeparator + disabledText
            let statusColor: Int32 = disabled ? 7 : 5 // Error for disabled, success for enabled
            lines.append((statusText, statusColor))
        }

        return lines
    }

    private static func generateGoldStandardNetworkingLines(flavor: Flavor) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        if let rxtxFactor = flavor.rxtxFactor {
            let networkingText = flavorDetailInfoFieldIndent + "Network Performance: " + String(rxtxFactor) + "x baseline"
            lines.append((networkingText, 6)) // .secondary() like RouterViews
        }

        return lines
    }

    private static func generateHardwarePropertiesLines(flavor: Flavor) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        guard let properties = flavor.extraSpecs else {
            return lines
        }

        // GPU Properties
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            if key.hasPrefix("resources:VGPU") {
                let description = translateGPUResource(key: key, value: value)
                lines.append((flavorDetailInfoFieldIndent + description, 5)) // .success() for GPU
            } else if key.hasPrefix("resources:PGPU") {
                let description = translateGPUResource(key: key, value: value)
                lines.append((flavorDetailInfoFieldIndent + description, 5)) // .success() for GPU
            } else if key.hasPrefix("trait:CUSTOM_HW_GPU") {
                let description = translateGPUTrait(key: key, value: value)
                lines.append((flavorDetailInfoFieldIndent + description, 5)) // .success() for GPU
            }
        }

        // PCI Passthrough Properties
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            if key.hasPrefix("pci_passthrough:alias") {
                let description = translatePCIPassthrough(key: key, value: value)
                lines.append((flavorDetailInfoFieldIndent + description, 4)) // .info() for PCI
            }
        }

        // Other Hardware Traits
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            if key.hasPrefix("trait:CUSTOM_HW_") && !key.hasPrefix("trait:CUSTOM_HW_GPU") {
                let description = translateHardwareTrait(key: key, value: value)
                lines.append((flavorDetailInfoFieldIndent + description, 4)) // .info() for other HW
            }
        }

        return lines
    }

    private static func generateResourceQuotasLines(flavor: Flavor) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        guard let properties = flavor.extraSpecs else {
            return lines
        }

        // Network Quotas
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            if key.hasPrefix("quota:vif_") {
                let description = translateNetworkQuota(key: key, value: value)
                lines.append((flavorDetailInfoFieldIndent + description, 2)) // .accent() for network
            }
        }

        // Storage Quotas
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            if key.hasPrefix("quota:disk_") {
                let description = translateStorageQuota(key: key, value: value)
                lines.append((flavorDetailInfoFieldIndent + description, 3)) // .warning() for storage
            }
        }

        // CPU Quotas
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            if key.hasPrefix("quota:cpu_") {
                let description = translateCPUQuota(key: key, value: value)
                lines.append((flavorDetailInfoFieldIndent + description, 6)) // .secondary() for CPU
            }
        }

        return lines
    }

    private static func generateRawPropertiesLines(flavor: Flavor) -> [(String, Int32)] {
        var lines: [(String, Int32)] = []

        // Debug info about flavor
        lines.append((flavorDetailInfoFieldIndent + "Debug: Flavor ID = \(flavor.id)", 4)) // .info() for debug

        guard let properties = flavor.extraSpecs else {
            lines.append((flavorDetailInfoFieldIndent + "Properties field is nil", 7)) // .error() for missing
            return lines
        }

        if properties.isEmpty {
            lines.append((flavorDetailInfoFieldIndent + "Properties field exists but is empty", 3)) // .warning() for empty
            return lines
        }

        lines.append((flavorDetailInfoFieldIndent + "Found \(properties.count) properties:", 5)) // .success() for found

        // Sort properties by key for consistent display
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            let propertyLine = flavorDetailInfoFieldIndent + "\(key): \(value)"
            lines.append((propertyLine, 6)) // .secondary() for all raw properties
        }

        return lines
    }

    // MARK: - Property Translation Functions

    private static func translateGPUResource(key: String, value: String) -> String {
        if key.contains("VGPU") {
            return "Virtual GPU: \(value) units available"
        } else if key.contains("PGPU") {
            return "Physical GPU: \(value) units available"
        }
        return "GPU Resource: \(key) = \(value)"
    }

    private static func translateGPUTrait(key: String, value: String) -> String {
        let gpuType = key.replacingOccurrences(of: "trait:CUSTOM_HW_GPU", with: "").replacingOccurrences(of: "_", with: " ")
        let cleanGPUType = gpuType.isEmpty ? "GPU" : gpuType
        let status = (value.lowercased() == "required") ? "Required" : "Available"
        return "GPU Hardware: \(cleanGPUType) (\(status))"
    }

    private static func translatePCIPassthrough(key: String, value: String) -> String {
        let aliasName = key.replacingOccurrences(of: "pci_passthrough:alias", with: "")
        let cleanAlias = aliasName.isEmpty ? value : aliasName
        return "PCI Passthrough: \(cleanAlias) = \(value)"
    }

    private static func translateHardwareTrait(key: String, value: String) -> String {
        let traitName = key.replacingOccurrences(of: "trait:CUSTOM_HW_", with: "").replacingOccurrences(of: "_", with: " ")
        let status = (value.lowercased() == "required") ? "Required" : "Available"
        return "Hardware: \(traitName) (\(status))"
    }

    private static func translateNetworkQuota(key: String, value: String) -> String {
        switch key {
        case "quota:vif_outbound_average":
            let mbps = formatBandwidth(value)
            return "Network Outbound (Avg): \(mbps)"
        case "quota:vif_outbound_burst":
            let mbps = formatBandwidth(value)
            return "Network Outbound (Burst): \(mbps)"
        case "quota:vif_outbound_peak":
            let mbps = formatBandwidth(value)
            return "Network Outbound (Peak): \(mbps)"
        case "quota:vif_inbound_average":
            let mbps = formatBandwidth(value)
            return "Network Inbound (Avg): \(mbps)"
        case "quota:vif_inbound_burst":
            let mbps = formatBandwidth(value)
            return "Network Inbound (Burst): \(mbps)"
        case "quota:vif_inbound_peak":
            let mbps = formatBandwidth(value)
            return "Network Inbound (Peak): \(mbps)"
        default:
            return "Network: \(key.replacingOccurrences(of: "quota:vif_", with: "")) = \(value)"
        }
    }

    private static func translateStorageQuota(key: String, value: String) -> String {
        switch key {
        case "quota:disk_read_iops_sec":
            return "Storage Read IOPS: \(formatIOPS(value))"
        case "quota:disk_write_iops_sec":
            return "Storage Write IOPS: \(formatIOPS(value))"
        case "quota:disk_read_bytes_sec":
            return "Storage Read Bandwidth: \(formatBandwidth(value))"
        case "quota:disk_write_bytes_sec":
            return "Storage Write Bandwidth: \(formatBandwidth(value))"
        case "quota:disk_total_bytes_sec":
            return "Storage Total Bandwidth: \(formatBandwidth(value))"
        case "quota:disk_total_iops_sec":
            return "Storage Total IOPS: \(formatIOPS(value))"
        default:
            return "Storage: \(key.replacingOccurrences(of: "quota:disk_", with: "")) = \(value)"
        }
    }

    private static func translateCPUQuota(key: String, value: String) -> String {
        switch key {
        case "quota:cpu_quota":
            return "CPU Quota: \(value)% of vCPU time"
        case "quota:cpu_period":
            return "CPU Period: \(value) microseconds"
        case "quota:cpu_shares":
            return "CPU Shares: \(value) (relative weight)"
        default:
            return "CPU: \(key.replacingOccurrences(of: "quota:cpu_", with: "")) = \(value)"
        }
    }

    // MARK: - Formatting Helpers

    private static func formatBandwidth(_ value: String) -> String {
        guard let bytes = Int(value) else { return "\(value) bytes/s" }

        if bytes >= 1_000_000_000 {
            return String(format: "%.1f Gbps", Double(bytes) / 125_000_000.0)
        } else if bytes >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(bytes) / 125_000.0)
        } else if bytes >= 1_000 {
            return String(format: "%.1f Kbps", Double(bytes) / 125.0)
        } else {
            return "\(bytes) bytes/s"
        }
    }

    private static func formatIOPS(_ value: String) -> String {
        guard let iops = Int(value) else { return "\(value) IOPS" }

        if iops >= 1_000_000 {
            return String(format: "%.1f M IOPS", Double(iops) / 1_000_000.0)
        } else if iops >= 1_000 {
            return String(format: "%.1f K IOPS", Double(iops) / 1_000.0)
        } else {
            return "\(iops) IOPS"
        }
    }

    // MARK: - Layout Functions

    @MainActor
    private static func drawSingleColumnFlavorLayout(screen: OpaquePointer?, sections: [Section],
                                                   startRow: Int32, startCol: Int32,
                                                   columnWidth: Int, contentHeight: Int,
                                                   scrollOffset: Int32) async {
        var allLines: [(String, Int32)] = []
        for section in sections {
            if !section.lines.isEmpty {
                allLines.append((section.title, 3)) // .warning() for section titles
                allLines.append(contentsOf: section.lines)
                allLines.append(("", 0)) // Blank line for spacing
            }
        }

        let startIndex = Int(scrollOffset)
        let surface = SwiftTUI.surface(from: screen)
        for i in 0..<contentHeight {
            let lineIndex = startIndex + i
            let row = startRow + Int32(i)

            if lineIndex < allLines.count {
                let (text, colorPair) = allLines[lineIndex]
                let truncatedText = String(text.prefix(columnWidth))
                let textStyle = colorPairToStyle(colorPair)
                let textBounds = Rect(x: startCol + 2, y: row, width: Int32(columnWidth), height: 1)
                await SwiftTUI.render(Text(truncatedText).styled(textStyle), on: surface, in: textBounds)
            }
        }
    }

    @MainActor
    private static func drawMultiColumnFlavorLayout(screen: OpaquePointer?, sections: [Section],
                                                  startRow: Int32, startCol: Int32,
                                                  leftColumnWidth: Int, rightColumnWidth: Int,
                                                  rightColumnStart: Int32, contentHeight: Int,
                                                  scrollOffset: Int32) async {
        // Distribute sections between columns based on priority
        let highPrioritySections = sections.filter { $0.priority == 1 }
        let mediumPrioritySections = sections.filter { $0.priority == 2 }
        let lowPrioritySections = sections.filter { $0.priority == 3 }
        let debugPrioritySections = sections.filter { $0.priority == 4 }

        var leftColumnSections: [Section] = []
        var rightColumnSections: [Section] = []

        // Distribute sections evenly, starting with high priority in left column
        leftColumnSections.append(contentsOf: highPrioritySections)
        rightColumnSections.append(contentsOf: mediumPrioritySections)
        leftColumnSections.append(contentsOf: lowPrioritySections)
        rightColumnSections.append(contentsOf: debugPrioritySections)

        // Generate lines for each column
        var leftColumnLines: [(String, Int32)] = []
        var rightColumnLines: [(String, Int32)] = []

        for section in leftColumnSections {
            if !section.lines.isEmpty {
                leftColumnLines.append((section.title, 3))
                leftColumnLines.append(contentsOf: section.lines)
                leftColumnLines.append(("", 0))
            }
        }

        for section in rightColumnSections {
            if !section.lines.isEmpty {
                rightColumnLines.append((section.title, 3))
                rightColumnLines.append(contentsOf: section.lines)
                rightColumnLines.append(("", 0))
            }
        }

        let startIndex = Int(scrollOffset)
        let surface = SwiftTUI.surface(from: screen)
        for i in 0..<contentHeight {
            let lineIndex = startIndex + i
            let row = startRow + Int32(i)

            // Draw left column
            if lineIndex < leftColumnLines.count {
                let (text, colorPair) = leftColumnLines[lineIndex]
                let truncatedText = String(text.prefix(leftColumnWidth))
                let textStyle = colorPairToStyle(colorPair)
                let leftBounds = Rect(x: startCol + 2, y: row, width: Int32(leftColumnWidth), height: 1)
                await SwiftTUI.render(Text(truncatedText).styled(textStyle), on: surface, in: leftBounds)
            }

            // Draw right column
            if lineIndex < rightColumnLines.count {
                let (text, colorPair) = rightColumnLines[lineIndex]
                let truncatedText = String(text.prefix(rightColumnWidth))
                let textStyle = colorPairToStyle(colorPair)
                let rightBounds = Rect(x: rightColumnStart, y: row, width: Int32(rightColumnWidth), height: 1)
                await SwiftTUI.render(Text(truncatedText).styled(textStyle), on: surface, in: rightBounds)
            }
        }
    }

    private static func calculateTotalLinesForFlavorSections(sections: [Section], useMultiColumn: Bool) -> Int {
        if useMultiColumn {
            let highPrioritySections = sections.filter { $0.priority == 1 }
            let mediumPrioritySections = sections.filter { $0.priority == 2 }
            let lowPrioritySections = sections.filter { $0.priority == 3 }
            let debugPrioritySections = sections.filter { $0.priority == 4 }

            var leftColumnLines = 0
            var rightColumnLines = 0

            // Count lines for left column (high priority + low priority)
            for section in highPrioritySections + lowPrioritySections {
                if !section.lines.isEmpty {
                    leftColumnLines += 1 + section.lines.count + 1 // title + lines + blank
                }
            }

            // Count lines for right column (medium priority + debug priority)
            for section in mediumPrioritySections + debugPrioritySections {
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

    // Helper function to convert color pairs to SwiftTUI styles
    private static func colorPairToStyle(_ colorPair: Int32) -> TextStyle {
        switch colorPair {
        case 1: return .primary
        case 2: return .accent
        case 3: return .warning
        case 4: return .info
        case 5: return .success
        case 6: return .secondary
        case 7: return .error
        default: return .secondary
        }
    }
}