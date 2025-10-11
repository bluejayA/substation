import Foundation
import OSClient
import SwiftTUI

struct ServerViews {
    // Layout constants
    private static let serverNameWidth = 22
    private static let statusWidth = 11
    private static let ipAddressWidth = 16
    private static let fixedColumnsWidth = 65  // ST + NAME + STATUS + IP columns
    private static let minimumFlavorImageSpace = 20
    private static let scrollIndicatorWidth = 30
    private static let progressBarWidth = 20
    private static let flavorImageSplitRatio = 0.6  // 60/40 split

    // UI Layout constants
    private static let contentVerticalOffset: Int32 = 8  // Header + border + help space
    private static let titleOffset: Int32 = 2
    private static let headerStartRow: Int32 = 3
    private static let separatorRow: Int32 = 4
    private static let listStartRow: Int32 = 5
    private static let scrollBoundsWidth: Int32 = 25
    private static let currentFlavorSectionHeight: Int32 = 8
    private static let flavorSpecMinSpace = 20
    private static let uiPadding: Int32 = 2
    private static let networkAddressPadding: Int32 = 4

    // Standard padding patterns
    private static let standardPadding = EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)
    private static let sectionPadding = EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)
    private static let networkPadding = EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)
    private static let topSpacingPadding = EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0)
    private static let indentedPadding = EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)

    // Header text constants
    private static let serverListHeader = " ST  NAME                   STATUS      IP ADDRESS       FLAVOR/IMAGE"


    @MainActor
    static func drawDetailedServerList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                     width: Int32, height: Int32, cachedServers: [Server],
                                     searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                      cachedFlavors: [Flavor], cachedImages: [Image],
                                     dataManager: DataManager? = nil, virtualScrollManager: VirtualScrollManager<Server>? = nil,
                                     multiSelectMode: Bool = false, selectedItems: Set<String> = []) async {

        let statusListView = createServerStatusListView(cachedFlavors: cachedFlavors, cachedImages: cachedImages)
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedServers,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            dataManager: dataManager,
            virtualScrollManager: virtualScrollManager,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    // MARK: - Detail View

    @MainActor
    static func drawServerDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                               width: Int32, height: Int32, server: Server,
                               cachedVolumes: [Volume],
                               cachedFlavors: [Flavor], cachedImages: [Image], scrollOffset: Int = 0) async {

        var sections: [DetailSection] = []

        // Basic Information Section
        var basicItems: [DetailItem] = []
        basicItems.append(.field(label: "ID", value: server.id, style: .secondary))
        basicItems.append(.field(label: "Name", value: server.name ?? "Unnamed Server", style: .secondary))

        // Status with custom component for icon
        basicItems.append(.customComponent(
            HStack(spacing: 0, children: [
                Text("  Status: ").secondary(),
                StatusIcon.server(status: server.status?.rawValue),
                Text(" " + (server.status?.rawValue ?? "Unknown"))
                    .styled(TextStyle.forStatus(server.status?.rawValue))
            ])
        ))

        if let taskState = server.taskState {
            basicItems.append(.field(label: "Task State", value: taskState, style: .secondary))
        }

        if let powerState = server.powerState {
            let powerStateText = powerState == .running ? "Running" : (powerState == .shutdown ? "Shutdown" : "Unknown")
            basicItems.append(.field(label: "Power State", value: powerStateText, style: .secondary))
        }

        if let az = server.availabilityZone {
            basicItems.append(.field(label: "Availability Zone", value: az, style: .secondary))
        }

        if let keyName = server.keyName {
            basicItems.append(.field(label: "Key Pair", value: keyName, style: .secondary))
        }

        if let hostId = server.hostId, !hostId.isEmpty {
            basicItems.append(.field(label: "Host ID", value: hostId, style: .secondary))
        }

        if let configDrive = server.configDrive, !configDrive.isEmpty {
            basicItems.append(.field(label: "Config Drive", value: configDrive, style: .secondary))
        }

        if let progress = server.progress {
            basicItems.append(.field(label: "Progress", value: "\(progress)%", style: .secondary))
        }

        sections.append(DetailSection(title: "Basic Information", items: basicItems))

        // Server Age / Uptime Section
        let ageItems = calculateServerAge(createdAt: server.createdAt, launchedAt: server.launchedAt)
        if !ageItems.isEmpty {
            sections.append(DetailSection(
                title: "Server Age",
                items: ageItems,
                titleStyle: .accent
            ))
        }

        // Hardware Information Section
        var hardwareItems: [DetailItem] = []

        // Flavor Information with enhanced details
        if let flavor = server.flavor {
            let flavorName = resolveFlavorName(from: server.flavor, cachedFlavors: cachedFlavors)

            // Display flavor name prominently
            hardwareItems.append(.field(label: "Flavor", value: flavorName, style: .primary))

            // Try to get specs from embedded flavor data first (most accurate)
            if let vcpus = flavor.vcpus, let ram = flavor.ram, let disk = flavor.disk {
                // Use embedded FlavorRef specs from API response
                hardwareItems.append(.field(label: "vCPUs", value: String(vcpus), style: .info))
                hardwareItems.append(.field(label: "RAM", value: "\(ram) MB", style: .info))
                hardwareItems.append(.field(label: "Root Disk", value: "\(disk) GB", style: .info))

                if let ephemeral = flavor.ephemeral, ephemeral > 0 {
                    hardwareItems.append(.field(label: "Ephemeral Disk", value: "\(ephemeral) GB", style: .info))
                }

                if let swap = flavor.swap, swap > 0 {
                    hardwareItems.append(.field(label: "Swap", value: "\(swap) MB", style: .info))
                }
            } else if let cachedFlavor = findCachedFlavor(for: server.flavor, in: cachedFlavors) {
                // Fall back to cached flavor if embedded specs not available
                hardwareItems.append(.field(label: "vCPUs", value: String(cachedFlavor.vcpus), style: .info))
                hardwareItems.append(.field(label: "RAM", value: "\(cachedFlavor.ram) MB", style: .info))
                hardwareItems.append(.field(label: "Root Disk", value: "\(cachedFlavor.disk) GB", style: .info))

                if let ephemeral = cachedFlavor.ephemeral, ephemeral > 0 {
                    hardwareItems.append(.field(label: "Ephemeral Disk", value: "\(ephemeral) GB", style: .info))
                }

                if let swap = cachedFlavor.swap, swap > 0 {
                    hardwareItems.append(.field(label: "Swap", value: "\(swap) MB", style: .info))
                }
            }
        }

        // Image Information
        if let image = server.image {
            let imageName = resolveImageName(from: server.image, cachedImages: cachedImages)
            if !hardwareItems.isEmpty {
                hardwareItems.append(.spacer)
            }
            hardwareItems.append(.field(label: "Image ID", value: image.id, style: .secondary))
            hardwareItems.append(.field(label: "Image Name", value: imageName, style: .secondary))
        }

        if !hardwareItems.isEmpty {
            sections.append(DetailSection(title: "Hardware Information", items: hardwareItems))
        }

        // Flavor Metadata Section - Display additional flavor details from cached flavor
        if let cachedFlavor = findCachedFlavor(for: server.flavor, in: cachedFlavors) {
            var flavorMetadataItems: [DetailItem] = []

            // Description
            if let description = cachedFlavor.description, !description.isEmpty {
                flavorMetadataItems.append(.field(label: "Description", value: description, style: .secondary))
            }

            // Network bandwidth factor
            if let rxtxFactor = cachedFlavor.rxtxFactor, rxtxFactor != 1.0 {
                flavorMetadataItems.append(.field(label: "Network Factor", value: String(format: "%.1fx", rxtxFactor), style: .info))
            }

            // Visibility
            if let isPublic = cachedFlavor.isPublic {
                flavorMetadataItems.append(.field(label: "Visibility", value: isPublic ? "Public" : "Private", style: .secondary))
            }

            // Status
            if let disabled = cachedFlavor.disabled {
                flavorMetadataItems.append(.field(label: "Status", value: disabled ? "Disabled" : "Active", style: disabled ? .error : .success))
            }

            if !flavorMetadataItems.isEmpty {
                sections.append(DetailSection(title: "Flavor Metadata", items: flavorMetadataItems))
            }
        }

        // Flavor Extra Specs Section - Display key-value extra specifications
        if let cachedFlavor = findCachedFlavor(for: server.flavor, in: cachedFlavors),
           let extraSpecs = cachedFlavor.extraSpecs, !extraSpecs.isEmpty {
            var extraSpecItems: [DetailItem] = []

            // Sort and display all extra specs
            for (key, value) in extraSpecs.sorted(by: { $0.key < $1.key }) {
                // Format the key for better readability
                let formattedKey = key.replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: ":", with: " ")
                    .capitalized
                extraSpecItems.append(.field(label: formattedKey, value: value, style: .info))
            }

            if !extraSpecItems.isEmpty {
                sections.append(DetailSection(
                    title: "Flavor Extra Specifications",
                    items: extraSpecItems,
                    titleStyle: .accent
                ))
            }
        }

        // Flavor Sizing Analysis Section
        if let cachedFlavor = findCachedFlavor(for: server.flavor, in: cachedFlavors) {
            let sizingItems = analyzeFlavorSizing(flavor: cachedFlavor)
            if !sizingItems.isEmpty {
                sections.append(DetailSection(
                    title: "Flavor Sizing Analysis",
                    items: sizingItems,
                    titleStyle: .accent
                ))
            }
        }

        // Performance Insights Section
        if let cachedFlavor = findCachedFlavor(for: server.flavor, in: cachedFlavors) {
            let performanceItems = analyzePerformanceCharacteristics(flavor: cachedFlavor)
            if !performanceItems.isEmpty {
                sections.append(DetailSection(
                    title: "Performance Insights",
                    items: performanceItems,
                    titleStyle: .accent
                ))
            }
        }

        // Network Information Section
        if let addresses = server.addresses, !addresses.isEmpty {
            var networkItems: [DetailItem] = []
            for (networkName, addressList) in addresses.sorted(by: { $0.key < $1.key }) {
                networkItems.append(.field(label: "Network", value: networkName, style: .secondary))
                for address in addressList {
                    let versionText = address.version == 4 ? "IPv4" : "IPv6"
                    networkItems.append(.field(label: "  \(versionText)", value: address.addr, style: .info))
                }
            }
            sections.append(DetailSection(title: "Network Information", items: networkItems))
        }

        // Storage Information Section
        let attachedVolumes = cachedVolumes.filter { $0.attachments?.contains { $0.serverId == server.id } ?? false }
        if !attachedVolumes.isEmpty {
            var storageItems: [DetailItem] = []
            for volume in attachedVolumes {
                storageItems.append(.field(label: "Volume Name", value: volume.name ?? "Unnamed Volume", style: .secondary))
                storageItems.append(.field(label: "Size", value: "\(volume.size ?? 0) GB", style: .secondary))
                storageItems.append(.customComponent(
                    HStack(spacing: 0, children: [
                        Text("  Status: ").secondary(),
                        Text(volume.status ?? "Unknown")
                            .styled(TextStyle.forStatus(volume.status))
                    ])
                ))
                storageItems.append(.spacer)
            }
            sections.append(DetailSection(title: "Storage Information", items: storageItems))
        }

        // Security Groups Section
        if let securityGroups = server.securityGroups, !securityGroups.isEmpty {
            var sgItems: [DetailItem] = []
            for sg in securityGroups {
                sgItems.append(.field(label: "Group", value: sg.name, style: .secondary))
            }
            sections.append(DetailSection(title: "Security Groups", items: sgItems))
        }

        // Security Posture Analysis Section
        let securityItems = analyzeSecurityPosture(server: server, volumes: cachedVolumes)
        if !securityItems.isEmpty {
            sections.append(DetailSection(
                title: "Security Posture Analysis",
                items: securityItems,
                titleStyle: .accent
            ))
        }

        // Access IPs Section
        let accessIPItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "IPv4", value: server.accessIPv4),
            DetailView.buildFieldItem(label: "IPv6", value: server.accessIPv6)
        ]

        if let accessIPSection = DetailView.buildSection(title: "Access IPs", items: accessIPItems) {
            sections.append(accessIPSection)
        }

        // Project & User Section
        let projectUserItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Project ID", value: server.tenantId),
            DetailView.buildFieldItem(label: "User ID", value: server.userId)
        ]

        if let projectUserSection = DetailView.buildSection(title: "Project & User", items: projectUserItems) {
            sections.append(projectUserSection)
        }

        // Hypervisor Information Section
        let hypervisorItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Hypervisor", value: server.hypervisorHostname),
            DetailView.buildFieldItem(label: "Instance Name", value: server.instanceName),
            DetailView.buildFieldItem(label: "Host Status", value: server.hostStatus)
        ]

        if let hypervisorSection = DetailView.buildSection(title: "Hypervisor Information", items: hypervisorItems) {
            sections.append(hypervisorSection)
        }

        // Metadata Section
        if let metadata = server.metadata, !metadata.isEmpty {
            var metadataItems: [DetailItem] = []
            for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
                metadataItems.append(.field(label: key, value: value, style: .secondary))
            }
            sections.append(DetailSection(title: "Metadata", items: metadataItems))
        }

        // Timestamps Section
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var timestampItems: [DetailItem?] = []
        if let created = server.createdAt {
            timestampItems.append(.field(label: "Created", value: formatter.string(from: created), style: .secondary))
        }
        if let updated = server.updatedAt {
            timestampItems.append(.field(label: "Updated", value: formatter.string(from: updated), style: .secondary))
        }
        if let launched = server.launchedAt {
            timestampItems.append(.field(label: "Launched At", value: formatter.string(from: launched), style: .secondary))
        }
        if let terminated = server.terminatedAt {
            timestampItems.append(.field(label: "Terminated At", value: formatter.string(from: terminated), style: .secondary))
        }

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Fault Information Section
        if let fault = server.fault {
            var faultItems: [DetailItem] = []
            faultItems.append(.field(label: "Code", value: String(fault.code), style: .error))
            faultItems.append(.field(label: "Message", value: fault.message, style: .error))
            if let created = fault.created {
                faultItems.append(.field(label: "Created", value: formatter.string(from: created), style: .error))
            }
            sections.append(DetailSection(title: "Fault Information", items: faultItems, titleStyle: .error))
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Server Details: \(server.name ?? "Unnamed Server")",
            sections: sections,
            helpText: "Press ESC to return to server list",
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



    // MARK: - Helper Functions

    /// Find a cached flavor by matching either the UUID or the flavor name
    /// Since OpenStack can return flavor.id as original_name, we need to match by name as well
    static func findCachedFlavor(for serverFlavor: Server.FlavorInfo?, in cachedFlavors: [Flavor]) -> Flavor? {
        guard let serverFlavor = serverFlavor else { return nil }

        // First try direct ID match (UUID)
        if let match = cachedFlavors.first(where: { $0.id == serverFlavor.id }) {
            return match
        }

        // Try matching by original_name
        if let originalName = serverFlavor.originalName {
            if let match = cachedFlavors.first(where: { $0.name == originalName }) {
                return match
            }
        }

        // Try matching by name
        if let name = serverFlavor.name {
            if let match = cachedFlavors.first(where: { $0.name == name }) {
                return match
            }
        }

        // Try matching serverFlavor.id against cached flavor names
        // (handles case where serverFlavor.id is actually the flavor name)
        if let match = cachedFlavors.first(where: { $0.name == serverFlavor.id }) {
            return match
        }

        return nil
    }

    static func resolveFlavorName(from flavor: Server.FlavorInfo?, cachedFlavors: [Flavor]) -> String {
        guard let flavor = flavor else {
            return ""
        }

        // First try original_name from the flavor ref (standard OpenStack field)
        if let originalName = flavor.originalName, !originalName.isEmpty {
            return originalName
        }

        // Then try the name field
        if let name = flavor.name, !name.isEmpty {
            return name
        }

        // Fall back to cached flavor lookup (by ID or name)
        if let cachedFlavor = findCachedFlavor(for: flavor, in: cachedFlavors),
           let name = cachedFlavor.name, !name.isEmpty {
            return name
        }

        // Last resort: return the raw flavor ID (truncated to 8 chars)
        return String(flavor.id.prefix(8))
    }

    static func resolveImageName(from image: Server.ImageInfo?, cachedImages: [Image]) -> String {
        guard let image = image else { return "Unknown" }

        // First try the name from the image ref itself
        if let name = image.name, !name.isEmpty {
            Logger.shared.logInfo("Using embedded image name: \(name)")
            return name
        }

        // Fall back to cached image lookup
        if let cachedImage = cachedImages.first(where: { $0.id == image.id }) {
            Logger.shared.logInfo("Found image in cache: id=\(image.id), name=\(cachedImage.name ?? "nil")")
            return cachedImage.name ?? "Unnamed Image"
        }

        // Debug: Log when image not found - show some cache IDs for comparison
        let sampleCacheIds = cachedImages.prefix(3).map { $0.id }.joined(separator: ", ")
        Logger.shared.logWarning("Image not found in cache: id=\(image.id), cacheSize=\(cachedImages.count), sampleCacheIds=[\(sampleCacheIds)]")

        // Last resort: show the full ID since it's useful information
        return image.id
    }

    static func formatFlavorImageInfo(flavorName: String, imageName: String, availableWidth: Int) -> String {
        let availableSpace = max(availableWidth, minimumFlavorImageSpace)
        let flavorSpace = Int(Double(availableSpace) * flavorImageSplitRatio)
        let imageSpace = availableSpace - flavorSpace - 1 // -1 for separator

        let truncatedFlavor = String(flavorName.prefix(flavorSpace))
        let truncatedImage = String(imageName.prefix(imageSpace))
        return "\(truncatedFlavor)/\(truncatedImage)"
    }

    static func getServerIP(_ server: Server) -> String? {
        guard let addresses = server.addresses else { return nil }
        for (_, addressList) in addresses.sorted(by: { $0.key < $1.key }) {
            for address in addressList.sorted(by: { $0.addr < $1.addr }) {
                if address.version == 4 {
                    return address.addr
                }
            }
        }
        return nil
    }

    // MARK: - Intelligence Helper Functions

    static func calculateServerAge(createdAt: Date?, launchedAt: Date?) -> [DetailItem] {
        var items: [DetailItem] = []

        let referenceDate = launchedAt ?? createdAt
        guard let referenceDate = referenceDate else {
            return items
        }

        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: referenceDate, to: now)

        if let days = components.day {
            if days > 0 {
                let ageText = "\(days) day\(days == 1 ? "" : "s")"
                items.append(.field(
                    label: "Server Age",
                    value: ageText,
                    style: .info
                ))
            } else if let hours = components.hour, hours > 0 {
                items.append(.field(
                    label: "Server Age",
                    value: "\(hours) hour\(hours == 1 ? "" : "s")",
                    style: .info
                ))
            } else if let minutes = components.minute {
                items.append(.field(
                    label: "Server Age",
                    value: "\(minutes) minute\(minutes == 1 ? "" : "s")",
                    style: .info
                ))
            }

            if launchedAt != nil {
                items.append(.field(
                    label: "  Reference",
                    value: "Time since server was launched",
                    style: .info
                ))
            } else {
                items.append(.field(
                    label: "  Reference",
                    value: "Time since server was created",
                    style: .info
                ))
            }
        }

        return items
    }

    static func analyzeFlavorSizing(flavor: Flavor?) -> [DetailItem] {
        var items: [DetailItem] = []

        guard let flavor = flavor else {
            return items
        }

        items.append(.field(
            label: "vCPUs",
            value: String(flavor.vcpus),
            style: .info
        ))
        items.append(.field(
            label: "RAM",
            value: "\(flavor.ram) MB (\(flavor.ram / 1024) GB)",
            style: .info
        ))
        items.append(.field(
            label: "Disk",
            value: "\(flavor.disk) GB",
            style: .info
        ))

        items.append(.spacer)
        items.append(.field(
            label: "Performance Profile",
            value: getPerformanceProfile(flavor: flavor),
            style: .accent
        ))

        if flavor.vcpus < 2 && flavor.ram < 2048 {
            items.append(.field(
                label: "  Sizing Note",
                value: "Small instance - suitable for light workloads",
                style: .info
            ))
        } else if flavor.vcpus >= 8 || flavor.ram >= 16384 {
            items.append(.field(
                label: "  Sizing Note",
                value: "Large instance - suitable for heavy workloads",
                style: .info
            ))
        }

        return items
    }

    static func getPerformanceProfile(flavor: Flavor) -> String {
        let cpuToRamRatio = Double(flavor.ram) / Double(flavor.vcpus)

        if cpuToRamRatio < 1024 {
            return "CPU-Optimized (High CPU, Lower RAM)"
        } else if cpuToRamRatio > 4096 {
            return "Memory-Optimized (High RAM, Lower CPU)"
        } else {
            return "Balanced (Equal CPU and RAM ratio)"
        }
    }

    static func analyzeSecurityPosture(server: Server, volumes: [Volume]) -> [DetailItem] {
        var items: [DetailItem] = []

        if let keyName = server.keyName {
            items.append(.field(
                label: "SSH Key Authentication",
                value: "Enabled (Key: \(keyName))",
                style: .success
            ))
            items.append(.field(
                label: "  Note",
                value: "SSH key authentication is more secure than passwords",
                style: .info
            ))
        } else {
            items.append(.field(
                label: "SSH Key Authentication",
                value: "Not configured",
                style: .warning
            ))
            items.append(.field(
                label: "  Warning",
                value: "Consider using SSH keys for better security",
                style: .warning
            ))
        }

        items.append(.spacer)

        let attachedVolumes = volumes.filter { $0.attachments?.contains { $0.serverId == server.id } ?? false }
        let encryptedVolumes = attachedVolumes.filter { $0.encrypted == true }

        if !attachedVolumes.isEmpty {
            items.append(.field(
                label: "Volume Encryption",
                value: "\(encryptedVolumes.count) of \(attachedVolumes.count) volumes encrypted",
                style: encryptedVolumes.count == attachedVolumes.count ? .success : .warning
            ))

            if encryptedVolumes.count < attachedVolumes.count {
                items.append(.field(
                    label: "  Warning",
                    value: "Some volumes are not encrypted",
                    style: .warning
                ))
            }
        }

        if let securityGroups = server.securityGroups {
            items.append(.spacer)
            items.append(.field(
                label: "Security Groups",
                value: "\(securityGroups.count) group(s) applied",
                style: securityGroups.count > 0 ? .success : .error
            ))

            if securityGroups.isEmpty {
                items.append(.field(
                    label: "  Critical",
                    value: "No security groups - all traffic allowed",
                    style: .error
                ))
            }
        }

        return items
    }

    static func analyzePerformanceCharacteristics(flavor: Flavor?) -> [DetailItem] {
        var items: [DetailItem] = []

        guard let flavor = flavor else {
            return items
        }

        items.append(.field(
            label: "CPU Type",
            value: flavor.vcpus == 1 ? "Shared vCPU" : "Multi-core vCPU",
            style: .info
        ))

        if flavor.vcpus == 1 {
            items.append(.field(
                label: "  Note",
                value: "Shared CPU - performance may vary with host load",
                style: .info
            ))
        } else {
            items.append(.field(
                label: "  Note",
                value: "Multi-core processing available",
                style: .info
            ))
        }

        items.append(.spacer)

        if let ephemeral = flavor.ephemeral, ephemeral > 0 {
            items.append(.field(
                label: "Ephemeral Storage",
                value: "\(ephemeral) GB available",
                style: .accent
            ))
            items.append(.field(
                label: "  Warning",
                value: "Ephemeral storage is lost on termination",
                style: .warning
            ))
        }

        items.append(.spacer)
        items.append(.field(
            label: "Expected Use Cases",
            value: getFlavorUseCases(flavor: flavor),
            style: .info
        ))

        return items
    }

    static func getFlavorUseCases(flavor: Flavor) -> String {
        let cpuToRamRatio = Double(flavor.ram) / Double(flavor.vcpus)

        if cpuToRamRatio < 1024 {
            return "Compute-intensive: batch processing, CI/CD, encoding"
        } else if cpuToRamRatio > 4096 {
            return "Memory-intensive: databases, caching, big data analytics"
        } else if flavor.vcpus < 2 && flavor.ram < 2048 {
            return "Development, testing, small web applications"
        } else {
            return "General purpose: web servers, app servers, microservices"
        }
    }


    private static func buildFlavorSpecs(flavor: Flavor) -> String {
        var specs: [String] = []

        specs.append("\(flavor.vcpus)vCPU")

        let ramGB = flavor.ram / 1024
        if ramGB > 0 {
            specs.append("\(ramGB)GB")
        } else {
            specs.append("\(flavor.ram)MB")
        }

        if flavor.disk > 0 {
            specs.append("\(flavor.disk)GB disk")
        }

        return specs.isEmpty ? "" : "(\(specs.joined(separator: ", ")))"
    }

    // MARK: - Server Resize Management

    @MainActor
    static func drawServerResizeManagement(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                         width: Int32, height: Int32, serverResizeForm: ServerResizeForm) async {

        let surface = SwiftTUI.surface(from: screen)
        let mainRect = Rect(x: startCol, y: startRow, width: width, height: height)

        // Clear the area
        await surface.fill(rect: mainRect, character: " ", style: .primary)

        // Handle loading state
        if serverResizeForm.isLoading {
            let titleComponent = Text("Resize Server").primary().bold()
            let titleRect = Rect(x: startCol + 2, y: startRow + 1, width: width - 4, height: 1)
            await SwiftTUI.render(titleComponent, on: surface, in: titleRect)

            let loadingComponent = Text("Loading flavors...").info()
            let loadingRect = Rect(x: startCol + 2, y: startRow + 3, width: width - 4, height: 1)
            await SwiftTUI.render(loadingComponent, on: surface, in: loadingRect)
            return
        }

        // Handle error state
        if let errorMessage = serverResizeForm.errorMessage {
            let titleComponent = Text("Resize Server").primary().bold()
            let titleRect = Rect(x: startCol + 2, y: startRow + 1, width: width - 4, height: 1)
            await SwiftTUI.render(titleComponent, on: surface, in: titleRect)

            let errorComponent = Text("Error: \(errorMessage)").error()
            let errorRect = Rect(x: startCol + 2, y: startRow + 3, width: width - 4, height: 1)
            await SwiftTUI.render(errorComponent, on: surface, in: errorRect)
            return
        }

        var components: [any Component] = []

        // Title
        let titleText = serverResizeForm.mode == .confirmOrRevert ? "Confirm or Revert Resize" : "Resize Server"
        components.append(
            Text(titleText).primary().bold()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        )

        // Server name with current flavor
        if let server = serverResizeForm.selectedServer {
            let serverName = server.name ?? "Unknown"
            let serverText: String
            if let currentFlavor = serverResizeForm.getCurrentFlavor() {
                let flavorName = currentFlavor.name ?? "Unknown"
                serverText = "Server: \(serverName) (\(flavorName))"
            } else {
                serverText = "Server: \(serverName)"
            }
            components.append(
                Text(serverText).secondary()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
            )
        }

        // Mode-specific selector
        if serverResizeForm.mode == .selectFlavor {
            // Flavor selection mode - getAvailableFlavors() already excludes current flavor
            let availableFlavors = serverResizeForm.getAvailableFlavors()

            // Clamp the highlighted index to valid range
            let safeHighlightedIndex = min(max(0, serverResizeForm.selectedFlavorIndex), max(0, availableFlavors.count - 1))

            // Build selected IDs set (for pending selection)
            var selectedIds: Set<String> = []
            if let pendingSelection = serverResizeForm.pendingFlavorSelection {
                selectedIds.insert(pendingSelection)
            }

            let selector = FormSelector<Flavor>(
                label: "Select New Flavor",
                tabs: [
                    FormSelectorTab<Flavor>(
                        title: "FLAVORS",
                        columns: [
                            FormSelectorColumn(header: "Flavor Name", width: 20) {
                                String(($0.name ?? "Unknown").prefix(20))
                            },
                            FormSelectorColumn(header: "vCPUs", width: 6) {
                                String($0.vcpus)
                            },
                            FormSelectorColumn(header: "RAM(GB)", width: 8) {
                                String(format: "%.1f", Double($0.ram) / 1024.0)
                            },
                            FormSelectorColumn(header: "Disk(GB)", width: 9) {
                                String($0.disk)
                            }
                        ]
                    )
                ],
                selectedTabIndex: 0,
                items: availableFlavors,
                selectedItemIds: selectedIds,
                highlightedIndex: safeHighlightedIndex,
                checkboxMode: .basic,
                scrollOffset: 0,
                searchQuery: nil,
                maxWidth: Int(width) - 4,
                maxHeight: Int(height) - 10,
                isActive: true
            )
            components.append(selector.render())

            // Show pending selection at bottom if exists
            if let selectedFlavor = serverResizeForm.getSelectedFlavor() {
                components.append(
                    Text("Selected: \(selectedFlavor.name ?? "Unknown") (\(selectedFlavor.vcpus) vCPUs, \(String(format: "%.1f", Double(selectedFlavor.ram) / 1024.0))GB RAM)")
                        .warning()
                        .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
                )
            }
        } else {
            // Confirm/Revert mode
            components.append(
                Text("Status: VERIFY_RESIZE - The server has been resized and is awaiting confirmation.")
                    .warning()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
            )

            let actions: [ResizeAction] = [.confirmResize, .revertResize]
            let selectedActionId = serverResizeForm.selectedAction == .confirmResize ? "confirm" : "revert"

            let selector = FormSelector<ResizeAction>(
                label: "Select Action",
                tabs: [
                    FormSelectorTab<ResizeAction>(
                        title: "ACTIONS",
                        columns: [
                            FormSelectorColumn(header: "Action", width: 20) { $0.name },
                            FormSelectorColumn(header: "Description", width: 45) { $0.description }
                        ]
                    )
                ],
                selectedTabIndex: 0,
                items: actions,
                selectedItemIds: Set([selectedActionId]),
                highlightedIndex: serverResizeForm.selectedAction == .confirmResize ? 0 : 1,
                checkboxMode: .basic,
                scrollOffset: 0,
                searchQuery: nil,
                maxWidth: Int(width) - 4,
                maxHeight: 8,
                isActive: true
            )
            components.append(selector.render())
        }

        // Bottom instructions
        let instructions = serverResizeForm.mode == .confirmOrRevert ?
            "UP/DOWN:navigate SPACE:toggle ENTER:confirm ESC:back" :
            "UP/DOWN:navigate SPACE:select ENTER:confirm ESC:back"
        components.append(
            Text(instructions).muted()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
        )

        // Render all components
        let mainComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(mainComponent, on: surface, in: bounds)
    }

    // MARK: - Pagination and Virtual Scrolling Navigation Helpers

    /// Handle navigation for paginated server list
    @MainActor
    static func handlePaginatedNavigation(dataManager: DataManager?, direction: NavigationDirection) async -> Bool {
        guard let dataManager = dataManager, dataManager.isPaginationEnabled(for: "servers") else {
            return false
        }

        switch direction {
        case .nextPage:
            return await dataManager.nextPage(for: "servers")
        case .previousPage:
            return await dataManager.previousPage(for: "servers")
        case .scrollUp:
            // For individual item scrolling, this would be handled differently
            return false
        case .scrollDown:
            // For individual item scrolling, this would be handled differently
            return false
        }
    }

    /// Handle navigation for virtual scrolling server list
    @MainActor
    static func handleVirtualScrollNavigation(virtualScrollManager: VirtualScrollManager<Server>?, direction: NavigationDirection) async -> Bool {
        guard let virtualScrollManager = virtualScrollManager else {
            return false
        }

        switch direction {
        case .scrollUp:
            await virtualScrollManager.scrollUp()
            return true
        case .scrollDown:
            await virtualScrollManager.scrollDown()
            return true
        case .nextPage:
            await virtualScrollManager.pageDown()
            return true
        case .previousPage:
            await virtualScrollManager.pageUp()
            return true
        }
    }

    /// Get current server list status (pagination or virtual scrolling)
    @MainActor
    static func getServerListStatus(dataManager: DataManager?, virtualScrollManager: VirtualScrollManager<Server>?) -> String? {
        if let virtualScrollManager = virtualScrollManager {
            return "Virtual: \(virtualScrollManager.getScrollInfo())"
        } else if let dataManager = dataManager, dataManager.isPaginationEnabled(for: "servers") {
            if let status = dataManager.getPaginationStatus(for: "servers") {
                return "Pages: \(status)"
            }
        }
        return nil
    }

    /// Check if enhanced scrolling (pagination or virtual) is available
    @MainActor
    static func hasEnhancedScrolling(dataManager: DataManager?, virtualScrollManager: VirtualScrollManager<Server>?) -> Bool {
        return virtualScrollManager != nil || (dataManager?.isPaginationEnabled(for: "servers") == true)
    }

    // Navigation direction enum for cleaner API
    enum NavigationDirection {
        case scrollUp
        case scrollDown
        case nextPage
        case previousPage
    }
}