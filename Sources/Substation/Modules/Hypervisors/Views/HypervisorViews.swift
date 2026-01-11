// Sources/Substation/Modules/Hypervisors/Views/HypervisorViews.swift
import Foundation
import OSClient
import SwiftNCurses

/// View rendering for the Hypervisors module
///
/// Provides static methods for drawing hypervisor list and detail views
/// using SwiftNCurses components.
struct HypervisorViews {

    // MARK: - List View

    /// Create StatusListView for hypervisor list
    ///
    /// - Returns: Configured StatusListView for Hypervisor resources
    @MainActor
    static func createHypervisorStatusListView() -> StatusListView<Hypervisor> {
        return StatusListView<Hypervisor>(
            title: "Hypervisors",
            columns: [
                StatusListColumn(
                    header: "HOSTNAME",
                    width: 28,
                    getValue: { hypervisor in
                        hypervisor.hypervisorHostname ?? "Unknown"
                    }
                ),
                StatusListColumn(
                    header: "STATE",
                    width: 8,
                    getValue: { hypervisor in
                        hypervisor.state?.uppercased() ?? "N/A"
                    },
                    getStyle: { hypervisor in
                        if hypervisor.state?.lowercased() == "up" {
                            return .success
                        } else {
                            return .error
                        }
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 10,
                    getValue: { hypervisor in
                        hypervisor.status?.capitalized ?? "N/A"
                    },
                    getStyle: { hypervisor in
                        if hypervisor.status?.lowercased() == "enabled" {
                            return .success
                        } else {
                            return .warning
                        }
                    }
                ),
                StatusListColumn(
                    header: "VMs",
                    width: 6,
                    getValue: { hypervisor in
                        String(hypervisor.runningVms ?? 0)
                    },
                    getStyle: { _ in .info }
                ),
                StatusListColumn(
                    header: "vCPUs",
                    width: 12,
                    getValue: { hypervisor in
                        let used = hypervisor.vcpusUsed ?? 0
                        let total = hypervisor.vcpus ?? 0
                        return "\(used)/\(total)"
                    },
                    getStyle: { _ in .accent }
                ),
                StatusListColumn(
                    header: "MEMORY",
                    width: 14,
                    getValue: { hypervisor in
                        let usedGb = (hypervisor.memoryMbUsed ?? 0) / 1024
                        let totalGb = (hypervisor.memoryMb ?? 0) / 1024
                        return "\(usedGb)/\(totalGb)GB"
                    },
                    getStyle: { _ in .warning }
                )
            ],
            getStatusIcon: { hypervisor in
                if hypervisor.state?.lowercased() == "up" && hypervisor.status?.lowercased() == "enabled" {
                    return "active"
                } else if hypervisor.state?.lowercased() == "down" {
                    return "error"
                } else {
                    return "warning"
                }
            },
            filterItems: { hypervisors, query in
                FilterUtils.filterHypervisors(hypervisors, query: query)
            }
        )
    }

    /// Draw hypervisor list view
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - startRow: Starting row for rendering
    ///   - startCol: Starting column for rendering
    ///   - width: Available width
    ///   - height: Available height
    ///   - cachedHypervisors: Array of cached hypervisors
    ///   - searchQuery: Optional search query for filtering
    ///   - scrollOffset: Current scroll offset
    ///   - selectedIndex: Currently selected index
    @MainActor
    static func drawDetailedHypervisorList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        cachedHypervisors: [Hypervisor],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int
    ) async {
        let statusListView = createHypervisorStatusListView()

        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedHypervisors,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Detail View

    /// Draw hypervisor detail view
    ///
    /// - Parameters:
    ///   - screen: NCurses screen pointer
    ///   - startRow: Starting row for rendering
    ///   - startCol: Starting column for rendering
    ///   - width: Available width
    ///   - height: Available height
    ///   - hypervisor: Hypervisor to display
    ///   - scrollOffset: Current scroll offset for detail view
    @MainActor
    static func drawHypervisorDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        hypervisor: Hypervisor,
        scrollOffset: Int
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        var basicItems: [DetailItem] = []
        basicItems.append(.field(label: "ID", value: hypervisor.id))
        basicItems.append(.field(label: "Hostname", value: hypervisor.hypervisorHostname ?? "Unknown"))

        if let hostIp = hypervisor.hostIp {
            basicItems.append(.field(label: "Host IP", value: hostIp))
        }
        if let hypervisorType = hypervisor.hypervisorType {
            basicItems.append(.field(label: "Type", value: hypervisorType))
        }
        if let hypervisorVersion = hypervisor.hypervisorVersion {
            basicItems.append(.field(label: "Version", value: String(hypervisorVersion)))
        }
        if let serviceId = hypervisor.serviceId {
            basicItems.append(.field(label: "Service ID", value: serviceId))
        }

        sections.append(DetailSection(title: "Basic Information", items: basicItems))

        // State and Status Section
        var stateItems: [DetailItem] = []
        let stateValue = hypervisor.state?.uppercased() ?? "Unknown"
        let stateStyle: TextStyle = hypervisor.state?.lowercased() == "up" ? .success : .error
        stateItems.append(.field(label: "State", value: stateValue, style: stateStyle))

        let statusValue = hypervisor.status?.capitalized ?? "Unknown"
        let statusStyle: TextStyle = hypervisor.status?.lowercased() == "enabled" ? .success : .warning
        stateItems.append(.field(label: "Status", value: statusValue, style: statusStyle))

        let operationalValue = hypervisor.isOperational ? "Yes" : "No"
        let operationalStyle: TextStyle = hypervisor.isOperational ? .success : .warning
        stateItems.append(.field(label: "Operational", value: operationalValue, style: operationalStyle))

        sections.append(DetailSection(title: "State and Status", items: stateItems))

        // Resource Usage Section
        var resourceItems: [DetailItem] = []

        // vCPU usage
        let vcpuUsed = hypervisor.vcpusUsed ?? 0
        let vcpuTotal = hypervisor.vcpus ?? 0
        let vcpuPercent = hypervisor.vcpuUsagePercent
        let vcpuValue = "\(vcpuUsed) / \(vcpuTotal) (\(String(format: "%.1f", vcpuPercent))%)"
        resourceItems.append(.field(label: "vCPUs", value: vcpuValue))

        // Memory usage
        let memUsedGb = Int(hypervisor.memoryGbUsed)
        let memTotalGb = Int(hypervisor.memoryGb)
        let memPercent = hypervisor.memoryUsagePercent
        let memValue = "\(memUsedGb) / \(memTotalGb) GB (\(String(format: "%.1f", memPercent))%)"
        resourceItems.append(.field(label: "Memory", value: memValue))

        // Disk usage
        let diskUsed = hypervisor.localGbUsed ?? 0
        let diskTotal = hypervisor.localGb ?? 0
        let diskPercent = hypervisor.diskUsagePercent
        let diskValue = "\(diskUsed) / \(diskTotal) GB (\(String(format: "%.1f", diskPercent))%)"
        resourceItems.append(.field(label: "Local Disk", value: diskValue))

        sections.append(DetailSection(title: "Resource Usage", items: resourceItems))

        // Instance Information Section
        var instanceItems: [DetailItem] = []
        instanceItems.append(.field(
            label: "Running VMs",
            value: String(hypervisor.runningVms ?? 0),
            style: .info
        ))
        if let currentWorkload = hypervisor.currentWorkload {
            instanceItems.append(.field(label: "Current Workload", value: String(currentWorkload)))
        }

        sections.append(DetailSection(title: "Instance Information", items: instanceItems))

        // Available Resources Section
        var availableItems: [DetailItem] = []
        if let freeRamMb = hypervisor.freeRamMb {
            let freeRamGb = freeRamMb / 1024
            availableItems.append(.field(label: "Free Memory", value: "\(freeRamGb) GB"))
        }
        if let freeDiskGb = hypervisor.freeDiskGb {
            availableItems.append(.field(label: "Free Disk", value: "\(freeDiskGb) GB"))
        }
        if let diskAvailableLeast = hypervisor.diskAvailableLeast {
            availableItems.append(.field(label: "Disk Available Least", value: "\(diskAvailableLeast) GB"))
        }

        if !availableItems.isEmpty {
            sections.append(DetailSection(title: "Available Resources", items: availableItems))
        }

        // Create and draw detail view
        let detailView = DetailView(
            title: "Hypervisor: \(hypervisor.hypervisorHostname ?? hypervisor.id)",
            sections: sections,
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
