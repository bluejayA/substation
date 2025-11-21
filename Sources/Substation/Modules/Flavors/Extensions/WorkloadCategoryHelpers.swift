// Sources/Substation/Modules/Flavors/Extensions/WorkloadCategoryHelpers.swift
import Foundation
import OSClient

/// Shared helper functions for workload category generation
/// Ensures consistent category filtering across the application
struct WorkloadCategoryHelpers {

    /// Standard workload definitions with descriptions
    static let workloadDefinitions: [(WorkloadType, String)] = [
        (.balanced, "Well-rounded configuration"),
        (.compute, "High CPU performance"),
        (.memory, "Large RAM allocation"),
        (.storage, "High disk capacity"),
        (.network, "Optimized for network throughput"),
        (.gpu, "GPU acceleration"),
        (.accelerated, "Hardware acceleration with PCI passthrough")
    ]

    /// Generate filtered list of workload types that have available flavors
    /// - Parameter flavors: Array of available flavors
    /// - Returns: Array of WorkloadType values that have at least one recommended flavor, in definition order
    static func generateFilteredWorkloadTypes(from flavors: [Flavor]) -> [WorkloadType] {
        var types: [WorkloadType] = []

        for (workloadType, _) in workloadDefinitions {
            let topFlavors = selectTopFlavorsForWorkload(flavors, workloadType: workloadType, count: 3)
            if !topFlavors.isEmpty {
                types.append(workloadType)
            }
        }

        // Return in the original workloadDefinitions order (no sorting)
        return types
    }

    /// Select top flavors for a specific workload type with size diversity
    /// - Parameters:
    ///   - flavors: Array of available flavors
    ///   - workloadType: The workload type to score flavors for
    ///   - count: Maximum number of flavors to return
    /// - Returns: Array of top-scoring flavors with diverse sizes (small, medium, large)
    static func selectTopFlavorsForWorkload(_ flavors: [Flavor], workloadType: WorkloadType, count: Int) -> [Flavor] {
        // Score all flavors
        let scoredFlavors = flavors.map { flavor in
            (flavor: flavor, score: calculateFlavorScore(flavor, for: workloadType))
        }

        // Filter out zero-scored flavors
        let eligibleFlavors = scoredFlavors.filter { $0.score > 0.0 }

        if eligibleFlavors.isEmpty {
            return []
        }

        // Categorize flavors by size (based on total resource score)
        let categorized = categorizeFlavorsBySize(eligibleFlavors)

        // Select best from each category to provide diversity
        var selected: [Flavor] = []

        // Try to get one from each size category (small, medium, large)
        if let small = categorized.small.first {
            selected.append(small.flavor)
        }

        if let medium = categorized.medium.first {
            selected.append(medium.flavor)
        }

        if let large = categorized.large.first {
            selected.append(large.flavor)
        }

        // If we need more flavors and didn't get 3, fill from best overall
        if selected.count < count {
            let remaining = eligibleFlavors
                .filter { scored in !selected.contains(where: { $0.id == scored.flavor.id }) }
                .sorted { $0.score > $1.score }
                .prefix(count - selected.count)
                .map { $0.flavor }

            selected.append(contentsOf: remaining)
        }

        return Array(selected.prefix(count))
    }

    /// Categorize flavors by size (small, medium, large) based on total resources
    private static func categorizeFlavorsBySize(_ scoredFlavors: [(flavor: Flavor, score: Double)]) -> (small: [(flavor: Flavor, score: Double)], medium: [(flavor: Flavor, score: Double)], large: [(flavor: Flavor, score: Double)]) {
        // Calculate resource magnitude for each flavor
        let withMagnitude = scoredFlavors.map { scored -> (flavor: Flavor, score: Double, magnitude: Double) in
            let vcpuMag = Double(scored.flavor.vcpus) / 100.0
            let ramMag = Double(scored.flavor.ram) / 65536.0
            let diskMag = Double(scored.flavor.disk) / 1000.0
            let magnitude = vcpuMag + ramMag + diskMag
            return (scored.flavor, scored.score, magnitude)
        }

        // Sort by magnitude
        let sorted = withMagnitude.sorted { $0.magnitude < $1.magnitude }

        guard sorted.count >= 3 else {
            // If we have less than 3 flavors, just categorize what we have
            if sorted.count == 1 {
                return ([(sorted[0].flavor, sorted[0].score)], [], [])
            } else if sorted.count == 2 {
                return ([(sorted[0].flavor, sorted[0].score)], [(sorted[1].flavor, sorted[1].score)], [])
            } else {
                return ([], [], [])
            }
        }

        // Divide into thirds by magnitude
        let third = sorted.count / 3

        let smallSlice = sorted[0..<third]
        let mediumSlice = sorted[third..<(third * 2)]
        let largeSlice = sorted[(third * 2)...]

        let smallFlavors = smallSlice.map { ($0.flavor, $0.score) }.sorted(by: { $0.1 > $1.1 })
        let mediumFlavors = mediumSlice.map { ($0.flavor, $0.score) }.sorted(by: { $0.1 > $1.1 })
        let largeFlavors = largeSlice.map { ($0.flavor, $0.score) }.sorted(by: { $0.1 > $1.1 })

        return (smallFlavors, mediumFlavors, largeFlavors)
    }

    /// Calculate flavor score for a specific workload type
    /// - Parameters:
    ///   - flavor: The flavor to score
    ///   - workloadType: The workload type to score against
    /// - Returns: Score value (higher is better)
    static func calculateFlavorScore(_ flavor: Flavor, for workloadType: WorkloadType) -> Double {
        // Normalized component scores
        let vcpuScore = Double(flavor.vcpus) / 100.0
        let ramScore = Double(flavor.ram) / 65536.0
        let diskScore = Double(flavor.disk) / 1000.0

        // Analyze extra specs for hardware capabilities
        let hasGPU = checkExtraSpecs(flavor, for: ["gpu", "pci_passthrough:alias", "resources:VGPU"])
        let hasNVME = checkExtraSpecs(flavor, for: ["disk_type:nvme", "hw:storage_type:nvme"])
        let hasHighNetworkIO = checkExtraSpecs(flavor, for: ["hw:vif_multiqueue_enabled", "hw:cpu_policy:dedicated"])
        let hasCPUPinning = checkExtraSpecs(flavor, for: ["hw:cpu_policy:dedicated", "hw:cpu_thread_policy"])

        // Extract IOPS and network bandwidth limits
        let diskReadIOPS = getIntExtraSpec(flavor, keys: ["quota:disk_read_iops_sec"])
        let diskWriteIOPS = getIntExtraSpec(flavor, keys: ["quota:disk_write_iops_sec"])
        let networkBandwidth = getIntExtraSpec(flavor, keys: ["quota:vif_outbound_average", "quota:vif_outbound_peak"])

        // Calculate CPU to RAM ratio for balance assessment
        let cpuRamRatio = Double(flavor.vcpus) / max(1.0, Double(flavor.ram) / 1024.0)

        // Ephemeral storage bonus
        let ephemeralBonus = (flavor.ephemeral ?? 0) > 0 ? 0.1 : 0.0

        var baseScore: Double
        var bonusScore: Double = 0.0

        switch workloadType {
        case .compute:
            // Don't recommend GPU/accelerated flavors for general compute workloads
            if hasGPU { return 0.0 }

            // High CPU, moderate RAM, CPU pinning is valuable
            baseScore = vcpuScore * 0.7 + ramScore * 0.2 + diskScore * 0.1
            if hasCPUPinning { bonusScore += 0.3 }
            if cpuRamRatio > 0.125 { bonusScore += 0.2 } // Favor CPU-heavy ratios

        case .memory:
            // Don't recommend GPU/accelerated flavors for memory workloads
            if hasGPU { return 0.0 }

            // High RAM, moderate CPU, large memory allocation matters
            baseScore = ramScore * 0.7 + vcpuScore * 0.2 + diskScore * 0.1
            if cpuRamRatio < 0.0625 { bonusScore += 0.2 } // Favor RAM-heavy ratios
            if flavor.ram >= 32768 { bonusScore += 0.15 } // Bonus for 32GB+

        case .storage:
            // Don't recommend GPU/accelerated flavors for storage workloads
            if hasGPU { return 0.0 }

            // High disk, IOPS limits, NVMe bonus, ephemeral storage valuable
            baseScore = diskScore * 0.7 + vcpuScore * 0.15 + ramScore * 0.15
            if hasNVME { bonusScore += 0.4 }
            // High IOPS limits indicate better storage performance
            if diskReadIOPS > 20000 { bonusScore += 0.2 }
            if diskWriteIOPS > 10000 { bonusScore += 0.15 }
            bonusScore += ephemeralBonus

        case .balanced:
            // Don't recommend GPU/accelerated flavors for balanced workloads
            if hasGPU { return 0.0 }

            // Well-rounded resources, optimal CPU:RAM ratio around 1:8
            baseScore = (vcpuScore + ramScore + diskScore) / 3.0
            let optimalRatio = 0.125 // 1 vCPU per 8GB RAM
            let ratioDiff = abs(cpuRamRatio - optimalRatio)
            if ratioDiff < 0.05 { bonusScore += 0.2 } // Close to optimal ratio

        case .network:
            // Don't recommend GPU/accelerated flavors for network workloads
            if hasGPU { return 0.0 }

            // Moderate CPU and RAM, network bandwidth crucial
            baseScore = (vcpuScore + ramScore) / 2.0
            if hasHighNetworkIO { bonusScore += 0.4 }
            if hasCPUPinning { bonusScore += 0.2 } // Helps with network processing
            // High network bandwidth limits
            if networkBandwidth > 500000 { bonusScore += 0.25 } // 500+ Kbps

        case .gpu:
            // GPU presence is critical, supporting CPU/RAM also important
            if hasGPU {
                baseScore = vcpuScore * 0.4 + ramScore * 0.4 + diskScore * 0.2
                bonusScore += 0.5 // Major bonus for having GPU
            } else {
                baseScore = 0.0 // No GPU = not suitable
            }

        case .accelerated:
            // PCI passthrough or specialized hardware
            if hasGPU || hasCPUPinning {
                baseScore = vcpuScore * 0.5 + ramScore * 0.5
                bonusScore += 0.3
            } else {
                baseScore = 0.0 // No specialized hardware = not suitable
            }
        }

        return min(1.0, baseScore + bonusScore) // Cap at 1.0
    }

    /// Check if flavor has specific capabilities in extra_specs
    private static func checkExtraSpecs(_ flavor: Flavor, for keys: [String]) -> Bool {
        guard let extraSpecs = flavor.extraSpecs else { return false }

        return keys.contains { key in
            // Check exact key match
            if extraSpecs[key] != nil { return true }

            // Check if any extra_specs key contains the search term
            return extraSpecs.keys.contains { $0.lowercased().contains(key.lowercased()) }
        }
    }

    /// Extract integer value from extra_specs for given keys
    private static func getIntExtraSpec(_ flavor: Flavor, keys: [String]) -> Int {
        guard let extraSpecs = flavor.extraSpecs else { return 0 }

        for key in keys {
            if let value = extraSpecs[key], let intValue = Int(value) {
                return intValue
            }
        }

        return 0
    }

    /// Extract string value from extra_specs for given keys
    static func getStringExtraSpec(_ flavor: Flavor, keys: [String]) -> String? {
        guard let extraSpecs = flavor.extraSpecs else { return nil }

        for key in keys {
            if let value = extraSpecs[key] {
                return value
            }
        }

        return nil
    }
}
