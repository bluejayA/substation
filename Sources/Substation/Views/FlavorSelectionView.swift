import Foundation
import SwiftTUI
import OSClient

@MainActor
struct FlavorSelectionView {

    /// Draw flavor selection - either manual mode, category list, or category detail
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        flavors: [Flavor],
        workloadType: WorkloadType,
        flavorRecommendations: [FlavorRecommendation],
        selectedFlavorId: String?,
        selectedRecommendationIndex: Int,
        selectedIndex: Int,
        mode: FlavorSelectionMode,
        scrollOffset: Int,
        searchQuery: String?,
        selectedCategoryIndex: Int? = nil
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        let mainRect = Rect(x: startCol, y: startRow, width: width, height: height)

        if mode == .manual {
            // Manual mode: Show all flavors in a list
            await drawManualMode(
                surface: surface,
                rect: mainRect,
                flavors: flavors,
                selectedFlavorId: selectedFlavorId,
                selectedIndex: selectedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                width: width,
                height: height
            )
        } else if let categoryIndex = selectedCategoryIndex {
            // Category detail mode: Show recommended flavors for selected category
            let categories = generateWorkloadRecommendations(flavors: flavors)
            if categoryIndex >= 0 && categoryIndex < categories.count {
                await drawCategoryDetail(
                    surface: surface,
                    rect: mainRect,
                    category: categories[categoryIndex],
                    selectedFlavorId: selectedFlavorId,
                    selectedIndex: selectedIndex,
                    scrollOffset: scrollOffset,
                    searchQuery: searchQuery ?? "",
                    width: width,
                    height: height
                )
            }
        } else {
            // Workload mode: Show category list
            await drawCategoryList(
                surface: surface,
                rect: mainRect,
                flavors: flavors,
                selectedIndex: selectedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery ?? "",
                width: width,
                height: height
            )
        }
    }

    // MARK: - Helper Methods

    private static func extractPrice(from flavor: Flavor) -> String {
        // Check extraSpecs for price-related keys
        if let extraSpecs = flavor.extraSpecs {
            // Common price keys in OpenStack flavor extra_specs (including colon-prefixed metadata)
            let priceKeys = [":price", "price", "cost", "hourly_price", "monthly_price", "price_hourly", "price_monthly", ":cost", ":hourly_price"]
            for key in priceKeys {
                if let priceValue = extraSpecs[key] {
                    // Try to parse as a number and format it
                    if let price = Double(priceValue) {
                        return String(format: "$%.3f", price)
                    }
                    // If it's already formatted, return as-is
                    return priceValue
                }
            }
        }
        return "-"
    }

    // MARK: - Draw Methods

    private static func drawManualMode(
        surface: any Surface,
        rect: Rect,
        flavors: [Flavor],
        selectedFlavorId: String?,
        selectedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        width: Int32,
        height: Int32
    ) async {
        // Flavors are already sorted by the form, use them as-is
        let selector = FormSelector(
            label: "Select Server Flavor",
            tabs: [
                FormSelectorTab<Flavor>(
                    title: "MANUAL",
                    columns: [
                        FormSelectorColumn(header: "Flavor Name", width: 20) { String(($0.name ?? "Unknown").prefix(20)) },
                        FormSelectorColumn(header: "vCPUs", width: 6) { String($0.vcpus) },
                        FormSelectorColumn(header: "RAM(GB)", width: 8) { String(format: "%.1f", Double($0.ram) / 1024.0) },
                        FormSelectorColumn(header: "Disk(GB)", width: 9) { String($0.disk) },
                        FormSelectorColumn(header: "Price/hr", width: 9) { extractPrice(from: $0) },
                        FormSelectorColumn(header: "Public", width: 6) { ($0.isPublic ?? true) ? "Yes" : "No" }
                    ],
                    description: "TAB: switch to recommendations"
                )
            ],
            selectedTabIndex: 0,
            items: flavors,
            selectedItemIds: selectedFlavorId != nil ? [selectedFlavorId!] : [],
            highlightedIndex: selectedIndex,
            multiSelect: false,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxWidth: Int(width) - 4,
            maxHeight: Int(height)
        )

        surface.clear(rect: rect)
        await SwiftTUI.render(selector.render(), on: surface, in: rect)
    }

    private static func drawCategoryList(
        surface: any Surface,
        rect: Rect,
        flavors: [Flavor],
        selectedIndex: Int,
        scrollOffset: Int,
        searchQuery: String,
        width: Int32,
        height: Int32
    ) async {
        let categories = generateWorkloadRecommendations(flavors: flavors)

        let selector = FormSelector(
            label: "Select Workload Category",
            tabs: [
                FormSelectorTab<WorkloadCategory>(
                    title: "RECOMMENDATIONS",
                    columns: [
                        FormSelectorColumn(header: "Category", width: 20) { $0.workloadType.displayName },
                        FormSelectorColumn(header: "Description", width: 60) { $0.description }
                    ],
                    description: "TAB: switch to manual mode"
                )
            ],
            selectedTabIndex: 0,
            items: categories,
            selectedItemIds: [],
            highlightedIndex: selectedIndex,
            multiSelect: false,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            maxWidth: Int(width) - 4,
            maxHeight: Int(height)
        )

        surface.clear(rect: rect)
        await SwiftTUI.render(selector.render(), on: surface, in: rect)
    }

    private static func drawCategoryDetail(
        surface: any Surface,
        rect: Rect,
        category: WorkloadCategory,
        selectedFlavorId: String?,
        selectedIndex: Int,
        scrollOffset: Int,
        searchQuery: String,
        width: Int32,
        height: Int32
    ) async {
        // Determine size labels for the flavors
        let sizeLabels = determineSizeLabels(for: category.flavors)

        let selector = FormSelector(
            label: "Recommended Flavors for \(category.workloadType.displayName)",
            tabs: [
                FormSelectorTab<Flavor>(
                    title: category.workloadType.displayName.uppercased(),
                    columns: [
                        FormSelectorColumn(header: "Size", width: 4) { flavor in
                            sizeLabels[flavor.id] ?? "MD"
                        },
                        FormSelectorColumn(header: "Flavor Name", width: 20) { String(($0.name ?? "Unknown").prefix(20)) },
                        FormSelectorColumn(header: "vCPUs", width: 6) { String($0.vcpus) },
                        FormSelectorColumn(header: "RAM(GB)", width: 8) { String(format: "%.1f", Double($0.ram) / 1024.0) },
                        FormSelectorColumn(header: "Disk(GB)", width: 9) { String($0.disk) },
                        FormSelectorColumn(header: "Price/hr", width: 9) { extractPrice(from: $0) },
                        FormSelectorColumn(header: "Score", width: 6) {
                            let score = calculateFlavorScore($0, for: category.workloadType)
                            return String(format: "%.0f%%", score * 100)
                        }
                    ],
                    description: "Small/Medium/Large options for budget flexibility. SPACE: select, ENTER: confirm, ESC: back"
                )
            ],
            selectedTabIndex: 0,
            items: category.flavors,
            selectedItemIds: selectedFlavorId != nil ? [selectedFlavorId!] : [],
            highlightedIndex: selectedIndex,
            multiSelect: false,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            maxWidth: Int(width) - 4,
            maxHeight: Int(height)
        )

        surface.clear(rect: rect)
        await SwiftTUI.render(selector.render(), on: surface, in: rect)
    }

    private static func determineSizeLabels(for flavors: [Flavor]) -> [String: String] {
        guard !flavors.isEmpty else { return [:] }

        // Calculate magnitude for each flavor
        let withMagnitude = flavors.map { flavor -> (id: String, magnitude: Double) in
            let vcpuMag = Double(flavor.vcpus) / 100.0
            let ramMag = Double(flavor.ram) / 65536.0
            let diskMag = Double(flavor.disk) / 1000.0
            return (flavor.id, vcpuMag + ramMag + diskMag)
        }

        // Sort by magnitude
        let sorted = withMagnitude.sorted { $0.magnitude < $1.magnitude }

        var labels: [String: String] = [:]

        // Assign labels based on position - use short consistent labels
        if sorted.count >= 3 {
            labels[sorted[0].id] = "SM"
            labels[sorted[1].id] = "MD"
            labels[sorted[2].id] = "LG"
        } else if sorted.count == 2 {
            labels[sorted[0].id] = "SM"
            labels[sorted[1].id] = "LG"
        } else if sorted.count == 1 {
            labels[sorted[0].id] = "MD"
        }

        return labels
    }

    // MARK: - Workload Recommendation Generation

    static func generateWorkloadRecommendations(flavors: [Flavor]) -> [WorkloadCategory] {
        var categories: [WorkloadCategory] = []

        for (workloadType, description) in WorkloadCategoryHelpers.workloadDefinitions {
            let topFlavors = WorkloadCategoryHelpers.selectTopFlavorsForWorkload(flavors, workloadType: workloadType, count: 3)
            if !topFlavors.isEmpty {
                categories.append(WorkloadCategory(workloadType: workloadType, flavors: topFlavors, description: description))
            }
        }

        return categories
    }

    private static func calculateFlavorScore(_ flavor: Flavor, for workloadType: WorkloadType) -> Double {
        return WorkloadCategoryHelpers.calculateFlavorScore(flavor, for: workloadType)
    }

    private static func generateExplanation(flavor: Flavor, workloadType: WorkloadType) -> String {
        let vcpus = flavor.vcpus
        let ramGB = Double(flavor.ram) / 1024.0
        let diskGB = flavor.disk
        let cpuRamRatio = Double(vcpus) / max(1.0, ramGB)

        // Analyze extra specs for enhanced explanation
        let extraSpecs = flavor.extraSpecs ?? [:]
        let hasGPU = extraSpecs.keys.contains { $0.lowercased().contains("gpu") || $0.lowercased().contains("vgpu") }
        let hasNVME = extraSpecs.keys.contains { $0.lowercased().contains("nvme") }
        let hasCPUPinning = extraSpecs.keys.contains { $0.lowercased().contains("cpu_policy:dedicated") }
        let hasNetworkOptimization = extraSpecs.keys.contains { $0.lowercased().contains("multiqueue") }
        let ephemeralGB = (flavor.ephemeral ?? 0)

        // Extract performance limits
        let diskReadIOPS = WorkloadCategoryHelpers.getStringExtraSpec(flavor, keys: ["quota:disk_read_iops_sec"])
        let diskWriteIOPS = WorkloadCategoryHelpers.getStringExtraSpec(flavor, keys: ["quota:disk_write_iops_sec"])
        let networkMbps = WorkloadCategoryHelpers.getStringExtraSpec(flavor, keys: ["quota:vif_outbound_average", "quota:vif_outbound_peak"])
        let architecture = WorkloadCategoryHelpers.getStringExtraSpec(flavor, keys: [":architecture"])
        let category = WorkloadCategoryHelpers.getStringExtraSpec(flavor, keys: [":category"])

        var explanation = ""
        var highlights: [String] = []

        switch workloadType {
        case .compute:
            explanation = "This flavor provides \(vcpus) vCPUs with \(String(format: "%.1f", ramGB))GB RAM"
            if hasCPUPinning {
                highlights.append("dedicated CPU cores for consistent performance")
            }
            if cpuRamRatio > 0.125 {
                highlights.append("CPU-optimized ratio for compute-heavy tasks")
            }
            if !highlights.isEmpty {
                explanation += " featuring " + highlights.joined(separator: " and ")
            }
            explanation += ". Ideal for batch processing, scientific computing, video encoding, and CPU-intensive simulations."

        case .memory:
            explanation = "This flavor offers \(String(format: "%.1f", ramGB))GB RAM with \(vcpus) vCPUs"
            if cpuRamRatio < 0.0625 {
                highlights.append("memory-optimized ratio (1:\(Int(ramGB / Double(vcpus))))")
            }
            if ramGB >= 32.0 {
                highlights.append("large memory allocation for data-intensive workloads")
            }
            if !highlights.isEmpty {
                explanation += " featuring " + highlights.joined(separator: " and ")
            }
            explanation += ". Perfect for in-memory databases (Redis, Memcached), big data analytics, and high-performance caching layers."

        case .storage:
            explanation = "This flavor provides \(diskGB)GB disk storage"
            if hasNVME {
                highlights.append("NVMe SSD for high IOPS")
            }
            if let readIOPS = diskReadIOPS, let writeIOPS = diskWriteIOPS {
                highlights.append("\(readIOPS) read/\(writeIOPS) write IOPS")
            }
            if ephemeralGB > 0 {
                highlights.append("\(ephemeralGB)GB ephemeral storage")
            }
            if !highlights.isEmpty {
                explanation += " with " + highlights.joined(separator: ", ")
            }
            explanation += ". Backed by \(vcpus) vCPUs and \(String(format: "%.1f", ramGB))GB RAM. Ideal for file servers, backup systems, media streaming, and log aggregation."

        case .balanced:
            let ratio = Int(ramGB / Double(vcpus))
            explanation = "This balanced flavor offers \(vcpus) vCPUs, \(String(format: "%.1f", ramGB))GB RAM (1:\(ratio) ratio), and \(diskGB)GB disk"
            if abs(cpuRamRatio - 0.125) < 0.05 {
                highlights.append("optimal resource balance")
            }
            if let arch = architecture {
                highlights.append(arch.replacingOccurrences(of: "_", with: " "))
            }
            if let cat = category {
                highlights.append(cat.replacingOccurrences(of: "_", with: " "))
            }
            if !highlights.isEmpty {
                explanation += " (" + highlights.joined(separator: ", ") + ")"
            }
            explanation += ". Suitable for web applications, development environments, and mixed workloads requiring versatile resources."

        case .network:
            explanation = "This flavor provides \(vcpus) vCPUs and \(String(format: "%.1f", ramGB))GB RAM"
            if hasNetworkOptimization {
                highlights.append("multi-queue network optimization")
            }
            if let bandwidth = networkMbps, let bwInt = Int(bandwidth) {
                let mbps = bwInt / 1000 // Convert Kbps to Mbps
                highlights.append("\(mbps) Mbps network bandwidth")
            }
            if hasCPUPinning {
                highlights.append("dedicated CPU cores for low-latency")
            }
            if !highlights.isEmpty {
                explanation += " with " + highlights.joined(separator: ", ")
            }
            explanation += ". Ideal for load balancers, web servers, API gateways, VPN endpoints, and high-throughput network services."

        case .gpu:
            if hasGPU {
                explanation = "This GPU-accelerated flavor offers \(vcpus) vCPUs and \(String(format: "%.1f", ramGB))GB RAM with GPU hardware acceleration"
                if let gpuInfo = extraSpecs.first(where: { $0.key.lowercased().contains("gpu") }) {
                    highlights.append(gpuInfo.value)
                }
                if !highlights.isEmpty {
                    explanation += " (\(highlights.joined(separator: ", ")))"
                }
                explanation += ". Perfect for machine learning training, AI inference, 3D rendering, video transcoding, and scientific simulations."
            } else {
                explanation = "Note: This flavor (\(vcpus) vCPUs, \(String(format: "%.1f", ramGB))GB RAM) does not have GPU capabilities. For GPU workloads, ensure your cloud provider offers GPU-enabled flavors."
            }

        case .accelerated:
            explanation = "This hardware-accelerated flavor provides \(vcpus) vCPUs and \(String(format: "%.1f", ramGB))GB RAM"
            if hasCPUPinning || hasGPU {
                if hasCPUPinning { highlights.append("CPU pinning") }
                if hasGPU { highlights.append("GPU passthrough") }
                explanation += " with " + highlights.joined(separator: " and ")
            }
            explanation += ". Ideal for PCI device passthrough, FPGA workloads, specialized accelerators, and latency-sensitive applications."
        }

        return explanation
    }
}

// MARK: - Supporting Types

struct WorkloadCategory {
    let workloadType: WorkloadType
    let flavors: [Flavor]
    let description: String

    var id: String {
        workloadType.rawValue
    }
}

// MARK: - WorkloadCategory + FormSelectableItem

extension WorkloadCategory: FormSelectableItem {
    var sortKey: String {
        workloadType.displayName
    }

    func matchesSearch(_ query: String) -> Bool {
        let searchLower = query.lowercased()
        return workloadType.displayName.lowercased().contains(searchLower) ||
               description.lowercased().contains(searchLower)
    }
}

// MARK: - State Management for Flavor Selection

struct FlavorSelectionState {
    var mode: FlavorSelectionMode = .manual
    var manualState: FormSelectorState<Flavor>
    var workloadState: FormSelectorState<Flavor>
    var workloadType: WorkloadType = .balanced

    init(flavors: [Flavor]) {
        self.manualState = FormSelectorState<Flavor>(items: flavors, multiSelect: false)
        self.workloadState = FormSelectorState<Flavor>(items: [], multiSelect: false)
    }

    mutating func switchMode() {
        mode = mode == .manual ? .workloadBased : .manual
    }

    var currentState: FormSelectorState<Flavor> {
        mode == .manual ? manualState : workloadState
    }

    mutating func updateCurrentState(_ state: FormSelectorState<Flavor>) {
        if mode == .manual {
            manualState = state
        } else {
            workloadState = state
        }
    }

    mutating func updateRecommendations(_ recommendations: [FlavorRecommendation]) {
        let recommendedFlavors = recommendations.map { $0.recommendedFlavor }
        workloadState.items = recommendedFlavors
        workloadState.highlightedIndex = 0
        workloadState.scrollOffset = 0
    }

    var selectedFlavor: Flavor? {
        let state = currentState
        guard let firstId = state.selectedItemIds.first else { return nil }
        return state.items.first { $0.id == firstId }
    }
}
