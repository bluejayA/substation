import Foundation
import OSClient
import SwiftTUI

struct FlavorViews {

    // MARK: - Constants (Removed orphaned detail view constants)
    @MainActor
    static func drawDetailedFlavorList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                     width: Int32, height: Int32, cachedFlavors: [Flavor],
                                     searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

        let statusListView = createFlavorStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedFlavors,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Flavor Detail View

    @MainActor
    static func drawFlavorDetailGoldStandard(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        flavor: Flavor,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Flavor analysis for rich metadata display
        let flavorAnalysis = analyzeFlavorCapabilities(flavor: flavor)

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: flavor.id),
            DetailView.buildFieldItem(label: "Name", value: flavor.name),
            DetailView.buildFieldItem(label: "Description", value: flavor.description)
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Resource Specifications Section
        var resourceItems: [DetailItem?] = [
            .field(label: "vCPUs", value: String(flavor.vcpus), style: .accent),
            .field(label: "RAM", value: "\(flavor.ram) MB", style: .accent),
            .field(label: "Root Disk", value: "\(flavor.disk) GB", style: .accent)
        ]

        if let ephemeral = flavor.ephemeral, ephemeral > 0 {
            resourceItems.append(.field(label: "Ephemeral Disk", value: "\(ephemeral) GB", style: .secondary))
        }

        if let swap = flavor.swap, swap > 0 {
            resourceItems.append(.field(label: "Swap", value: "\(swap) MB", style: .secondary))
        }

        if let rxtxFactor = flavor.rxtxFactor {
            resourceItems.append(.field(label: "RX/TX Factor", value: String(rxtxFactor), style: .secondary))
        }

        if let resourceSection = DetailView.buildSection(title: "Resource Specifications", items: resourceItems, titleStyle: .accent) {
            sections.append(resourceSection)
        }

        // Performance Analysis Section
        let performanceItems: [DetailItem?] = [
            .field(label: "Performance Tier", value: flavorAnalysis.performanceTier.rawValue, style: .success),
            .field(label: "CPU/Memory Ratio", value: String(format: "%.1f GB per vCPU", flavorAnalysis.cpuToMemoryRatio), style: .info),
            .field(label: "Storage Type", value: flavorAnalysis.storageType.rawValue, style: .secondary),
            .field(label: "Usage Category", value: flavorAnalysis.usageCategory.rawValue, style: .accent)
        ]

        if let performanceSection = DetailView.buildSection(title: "Performance Analysis", items: performanceItems) {
            sections.append(performanceSection)
        }

        // Usage Recommendations Section
        var usageItems: [DetailItem] = []

        if !flavorAnalysis.recommendedWorkloads.isEmpty {
            usageItems.append(.field(label: "Recommended Workloads", value: "", style: .primary))
            for workload in flavorAnalysis.recommendedWorkloads {
                usageItems.append(.field(label: "  - \(workload)", value: "", style: .success))
            }
        }

        if !flavorAnalysis.limitations.isEmpty {
            usageItems.append(.spacer)
            usageItems.append(.field(label: "Limitations", value: "", style: .warning))
            for limitation in flavorAnalysis.limitations {
                usageItems.append(.field(label: "  - \(limitation)", value: "", style: .warning))
            }
        }

        if !usageItems.isEmpty {
            sections.append(DetailSection(title: "Usage Recommendations", items: usageItems))
        }

        // Access Configuration Section
        var accessItems: [DetailItem?] = []

        if let isPublic = flavor.isPublic {
            accessItems.append(.field(label: "Public", value: isPublic ? "Yes" : "No", style: isPublic ? .success : .secondary))
            if isPublic {
                accessItems.append(.field(label: "  Description", value: "Available to all projects", style: .info))
            } else {
                accessItems.append(.field(label: "  Description", value: "Private to specific projects", style: .info))
            }
        }

        if let disabled = flavor.disabled {
            accessItems.append(.field(label: "Disabled", value: disabled ? "Yes" : "No", style: disabled ? .error : .success))
            if disabled {
                accessItems.append(.field(label: "  Warning", value: "This flavor is disabled and cannot be used", style: .error))
            }
        }

        if let accessSection = DetailView.buildSection(title: "Access Configuration", items: accessItems) {
            sections.append(accessSection)
        }

        // Hardware Properties Section
        if let extraSpecs = flavor.extraSpecs {
            var gpuItems: [DetailItem] = []
            var pciItems: [DetailItem] = []
            var hwTraitItems: [DetailItem] = []

            for (key, value) in extraSpecs.sorted(by: { $0.key < $1.key }) {
                if key.hasPrefix("resources:VGPU") || key.hasPrefix("resources:PGPU") {
                    let description = translateGPUResource(key: key, value: value)
                    gpuItems.append(.field(label: description, value: "", style: .success))
                } else if key.hasPrefix("trait:CUSTOM_HW_GPU") {
                    let description = translateGPUTrait(key: key, value: value)
                    gpuItems.append(.field(label: description, value: "", style: .success))
                } else if key.hasPrefix("pci_passthrough:alias") {
                    let description = translatePCIPassthrough(key: key, value: value)
                    pciItems.append(.field(label: description, value: "", style: .info))
                } else if key.hasPrefix("trait:CUSTOM_HW_") && !key.hasPrefix("trait:CUSTOM_HW_GPU") {
                    let description = translateHardwareTrait(key: key, value: value)
                    hwTraitItems.append(.field(label: description, value: "", style: .info))
                }
            }

            let hardwareItems = gpuItems + pciItems + hwTraitItems
            if !hardwareItems.isEmpty {
                sections.append(DetailSection(title: "Hardware Properties", items: hardwareItems))
            }
        }

        // Resource Quotas Section
        if let extraSpecs = flavor.extraSpecs {
            var networkQuotaItems: [DetailItem] = []
            var storageQuotaItems: [DetailItem] = []
            var cpuQuotaItems: [DetailItem] = []

            for (key, value) in extraSpecs.sorted(by: { $0.key < $1.key }) {
                if key.hasPrefix("quota:vif_") {
                    let description = translateNetworkQuota(key: key, value: value)
                    networkQuotaItems.append(.field(label: description, value: "", style: .accent))
                } else if key.hasPrefix("quota:disk_") {
                    let description = translateStorageQuota(key: key, value: value)
                    storageQuotaItems.append(.field(label: description, value: "", style: .warning))
                } else if key.hasPrefix("quota:cpu_") {
                    let description = translateCPUQuota(key: key, value: value)
                    cpuQuotaItems.append(.field(label: description, value: "", style: .secondary))
                }
            }

            let quotaItems = networkQuotaItems + storageQuotaItems + cpuQuotaItems
            if !quotaItems.isEmpty {
                sections.append(DetailSection(title: "Resource Quotas", items: quotaItems))
            }
        }

        // Extra Specs Section (Raw Properties)
        if let extraSpecs = flavor.extraSpecs, !extraSpecs.isEmpty {
            let extraSpecItems = extraSpecs.sorted(by: { $0.key < $1.key }).map {
                DetailItem.field(label: $0.key, value: $0.value, style: .secondary)
            }
            sections.append(DetailSection(title: "Extra Specs", items: extraSpecItems))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Flavor Details: \(flavor.name ?? "Unknown")",
            sections: sections,
            helpText: "Press ESC to return to flavors list",
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

}