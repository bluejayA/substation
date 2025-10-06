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

    // MARK: - Server Detail View Constants
    // Detail View Constants
    private static let serverDetailTitle = "Server Details"
    private static let serverDetailBasicInfoTitle = "Basic Information"
    private static let serverDetailHardwareInfoTitle = "Hardware Information"
    private static let serverDetailNetworkInfoTitle = "Network Information"
    private static let serverDetailStorageInfoTitle = "Storage Information"
    private static let serverDetailTimestampsTitle = "Timestamps"
    private static let serverDetailIdLabel = "ID"
    private static let serverDetailNameLabel = "Name"
    private static let serverDetailStatusLabel = "Status"
    private static let serverDetailFlavorIdLabel = "Flavor ID"
    private static let serverDetailFlavorNameLabel = "Flavor Name"
    private static let serverDetailImageIdLabel = "Image ID"
    private static let serverDetailImageNameLabel = "Image Name"
    private static let serverDetailNetworkLabel = "Network"
    private static let serverDetailVolumeNameLabel = "Volume Name"
    private static let serverDetailVolumeSizeLabel = "Size"
    private static let serverDetailVolumeStatusLabel = "Status"
    private static let serverDetailCreatedLabel = "Created"
    private static let serverDetailUpdatedLabel = "Updated"
    private static let serverDetailFieldValueSeparator = ": "
    private static let serverDetailUnnamedServerText = "Unnamed Server"
    private static let serverDetailUnknownStatusText = "Unknown"
    private static let serverDetailUnnamedVolumeText = "Unnamed Volume"
    private static let serverDetailIpv4Text = "IPv4"
    private static let serverDetailIpv6Text = "IPv6"
    private static let serverDetailGbSuffix = " GB"
    private static let serverDetailHelpText = "Press ESC to return to server list"
    private static let serverDetailScreenTooSmallText = "Screen too small"
    private static let serverDetailScrolledToEndText = "End of server details"

    // Detail View Layout Constants
    private static let serverDetailMinScreenWidth: Int32 = 10
    private static let serverDetailMinScreenHeight: Int32 = 10
    private static let serverDetailBoundsMinWidth: Int32 = 1
    private static let serverDetailBoundsMinHeight: Int32 = 1
    private static let serverDetailTitleTopPadding: Int32 = 0
    private static let serverDetailTitleLeadingPadding: Int32 = 0
    private static let serverDetailTitleBottomPadding: Int32 = 2
    private static let serverDetailTitleTrailingPadding: Int32 = 0
    private static let serverDetailSectionTopPadding: Int32 = 0
    private static let serverDetailSectionLeadingPadding: Int32 = 4
    private static let serverDetailSectionBottomPadding: Int32 = 1
    private static let serverDetailSectionTrailingPadding: Int32 = 0
    private static let serverDetailHelpTopPadding: Int32 = 1
    private static let serverDetailHelpLeadingPadding: Int32 = 0
    private static let serverDetailHelpBottomPadding: Int32 = 0
    private static let serverDetailHelpTrailingPadding: Int32 = 0
    private static let serverDetailInfoFieldIndent = "  "
    private static let serverDetailComponentSpacing: Int32 = 0
    private static let serverDetailItemTextSpacing = " "

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let serverDetailTitleEdgeInsets = EdgeInsets(top: serverDetailTitleTopPadding, leading: serverDetailTitleLeadingPadding, bottom: serverDetailTitleBottomPadding, trailing: serverDetailTitleTrailingPadding)
    private static let serverDetailSectionEdgeInsets = EdgeInsets(top: serverDetailSectionTopPadding, leading: serverDetailSectionLeadingPadding, bottom: serverDetailSectionBottomPadding, trailing: serverDetailSectionTrailingPadding)
    private static let serverDetailHelpEdgeInsets = EdgeInsets(top: serverDetailHelpTopPadding, leading: serverDetailHelpLeadingPadding, bottom: serverDetailHelpBottomPadding, trailing: serverDetailHelpTrailingPadding)

    @MainActor
    static func drawDetailedServerList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                     width: Int32, height: Int32, cachedServers: [Server],
                                     searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                      cachedFlavors: [Flavor], cachedImages: [Image],
                                     dataManager: DataManager? = nil, virtualScrollManager: VirtualScrollManager<Server>? = nil) async {

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
            virtualScrollManager: virtualScrollManager
        )
    }

    // MARK: - Detail View

    @MainActor
    static func drawServerDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                               width: Int32, height: Int32, server: Server,
                               cachedVolumes: [Volume],
                               cachedFlavors: [Flavor], cachedImages: [Image], scrollOffset: Int = 0) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.serverDetailMinScreenWidth && height > Self.serverDetailMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.serverDetailBoundsMinWidth, width), height: max(Self.serverDetailBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.serverDetailScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Server Detail
        var components: [any Component] = []

        // Title - optimized string construction
        let serverName = server.name ?? Self.serverDetailUnnamedServerText
        let titleText = Self.serverDetailTitle + Self.serverDetailFieldValueSeparator + serverName
        components.append(Text(titleText).accent().bold()
                         .padding(Self.serverDetailTitleEdgeInsets))

        // Basic Information Section
        components.append(Text(Self.serverDetailBasicInfoTitle).primary().bold())

        var basicInfo: [any Component] = []
        // Pre-calculate common field prefixes for optimal performance
        let fieldPrefix = Self.serverDetailInfoFieldIndent
        let fieldSeparator = Self.serverDetailFieldValueSeparator
        let idPrefix = fieldPrefix + Self.serverDetailIdLabel + fieldSeparator
        let namePrefix = fieldPrefix + Self.serverDetailNameLabel + fieldSeparator
        let statusPrefix = fieldPrefix + Self.serverDetailStatusLabel + fieldSeparator

        // Optimized string construction for basic info fields
        let idText = idPrefix + server.id
        let nameText = namePrefix + serverName

        basicInfo.append(Text(idText).secondary())
        basicInfo.append(Text(nameText).secondary())

        basicInfo.append(HStack(spacing: 0, children: [
            Text(statusPrefix).secondary(),
            StatusIcon.server(status: server.status?.rawValue),
            Text(Self.serverDetailItemTextSpacing + (server.status?.rawValue ?? Self.serverDetailUnknownStatusText)).styled(TextStyle.forStatus(server.status?.rawValue))
        ]))

        // Task State
        if let taskState = server.taskState {
            basicInfo.append(Text(fieldPrefix + "Task State" + fieldSeparator + taskState).secondary())
        }

        // Power State
        if let powerState = server.powerState {
            let powerStateText = powerState == .running ? "Running" : (powerState == .shutdown ? "Shutdown" : "Unknown")
            basicInfo.append(Text(fieldPrefix + "Power State" + fieldSeparator + powerStateText).secondary())
        }

        // Availability Zone
        if let az = server.availabilityZone {
            basicInfo.append(Text(fieldPrefix + "Availability Zone" + fieldSeparator + az).secondary())
        }

        // Key Pair
        if let keyName = server.keyName {
            basicInfo.append(Text(fieldPrefix + "Key Pair" + fieldSeparator + keyName).secondary())
        }

        // Host ID
        if let hostId = server.hostId, !hostId.isEmpty {
            basicInfo.append(Text(fieldPrefix + "Host ID" + fieldSeparator + hostId).secondary())
        }

        // Config Drive
        if let configDrive = server.configDrive, !configDrive.isEmpty {
            basicInfo.append(Text(fieldPrefix + "Config Drive" + fieldSeparator + configDrive).secondary())
        }

        // Progress
        if let progress = server.progress {
            basicInfo.append(Text(fieldPrefix + "Progress" + fieldSeparator + String(progress) + "%").secondary())
        }

        let basicInfoSection = VStack(spacing: 0, children: basicInfo)
            .padding(Self.serverDetailSectionEdgeInsets)
        components.append(basicInfoSection)

        // Hardware Information Section
        var hasHardwareInfo = false
        var hardwareInfo: [any Component] = []

        // Flavor Information
        if let flavor = server.flavor {
            hasHardwareInfo = true
            let flavorName = resolveFlavorName(from: server.flavor, cachedFlavors: cachedFlavors)
            let flavorIdPrefix = fieldPrefix + Self.serverDetailFlavorIdLabel + fieldSeparator
            let flavorNamePrefix = fieldPrefix + Self.serverDetailFlavorNameLabel + fieldSeparator
            let flavorIdText = flavorIdPrefix + (flavor.id ?? "N/A")
            let flavorNameText = flavorNamePrefix + flavorName
            hardwareInfo.append(Text(flavorIdText).secondary())
            hardwareInfo.append(Text(flavorNameText).secondary())
        }

        // Image Information
        if let image = server.image {
            hasHardwareInfo = true
            let imageName = resolveImageName(from: server.image, cachedImages: cachedImages)
            let imageIdPrefix = fieldPrefix + Self.serverDetailImageIdLabel + fieldSeparator
            let imageNamePrefix = fieldPrefix + Self.serverDetailImageNameLabel + fieldSeparator
            let imageIdText = imageIdPrefix + image.id
            let imageNameText = imageNamePrefix + imageName
            hardwareInfo.append(Text(imageIdText).secondary())
            hardwareInfo.append(Text(imageNameText).secondary())
        }

        if hasHardwareInfo {
            components.append(Text(Self.serverDetailHardwareInfoTitle).primary().bold())
            let hardwareSection = VStack(spacing: 0, children: hardwareInfo)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(hardwareSection)
        }

        // Network Information Section
        if let addresses = server.addresses, !addresses.isEmpty {
            components.append(Text(Self.serverDetailNetworkInfoTitle).primary().bold())
            var networkComponents: [any Component] = []
            for (networkName, addressList) in addresses {
                let networkPrefix = fieldPrefix + Self.serverDetailNetworkLabel + fieldSeparator
                let networkText = networkPrefix + networkName
                networkComponents.append(Text(networkText).secondary())
                for address in addressList {
                    let versionText = address.version == 4 ? Self.serverDetailIpv4Text : Self.serverDetailIpv6Text
                    let addressPrefix = fieldPrefix + fieldPrefix + versionText + fieldSeparator
                    let addressText = addressPrefix + address.addr
                    networkComponents.append(Text(addressText).info())
                }
            }
            let networkSection = VStack(spacing: 0, children: networkComponents)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(networkSection)
        }

        // Storage Information Section
        let attachedVolumes = cachedVolumes.filter { $0.attachments?.contains { $0.serverId == server.id } ?? false }
        if !attachedVolumes.isEmpty {
            components.append(Text(Self.serverDetailStorageInfoTitle).primary().bold())
            var storageComponents: [any Component] = []
            for volume in attachedVolumes {
                let volumeNamePrefix = fieldPrefix + Self.serverDetailVolumeNameLabel + fieldSeparator
                let volumeSizePrefix = fieldPrefix + Self.serverDetailVolumeSizeLabel + fieldSeparator
                let volumeStatusPrefix = fieldPrefix + Self.serverDetailVolumeStatusLabel + fieldSeparator

                let volumeNameText = volumeNamePrefix + (volume.name ?? Self.serverDetailUnnamedVolumeText)
                let volumeSizeText = volumeSizePrefix + String(volume.size ?? 0) + Self.serverDetailGbSuffix
                let volumeStatusText = volumeStatusPrefix + (volume.status ?? Self.serverDetailUnknownStatusText)

                storageComponents.append(Text(volumeNameText).secondary())
                storageComponents.append(Text(volumeSizeText).secondary())
                storageComponents.append(Text(volumeStatusText).styled(TextStyle.forStatus(volume.status)))
                storageComponents.append(Text("").secondary()) // Spacer between volumes
            }
            let storageSection = VStack(spacing: 0, children: storageComponents)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(storageSection)
        }

        // Security Groups Section
        if let securityGroups = server.securityGroups, !securityGroups.isEmpty {
            components.append(Text("Security Groups").primary().bold())
            var sgComponents: [any Component] = []
            for sg in securityGroups {
                sgComponents.append(Text(fieldPrefix + sg.name).secondary())
            }
            let sgSection = VStack(spacing: 0, children: sgComponents)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(sgSection)
        }

        // Access IPs Section
        if (server.accessIPv4 != nil && !server.accessIPv4!.isEmpty) || (server.accessIPv6 != nil && !server.accessIPv6!.isEmpty) {
            components.append(Text("Access IPs").primary().bold())
            var accessIPComponents: [any Component] = []
            if let ipv4 = server.accessIPv4, !ipv4.isEmpty {
                accessIPComponents.append(Text(fieldPrefix + "IPv4" + fieldSeparator + ipv4).secondary())
            }
            if let ipv6 = server.accessIPv6, !ipv6.isEmpty {
                accessIPComponents.append(Text(fieldPrefix + "IPv6" + fieldSeparator + ipv6).secondary())
            }
            let accessIPSection = VStack(spacing: 0, children: accessIPComponents)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(accessIPSection)
        }

        // IDs Section
        components.append(Text("Project & User").primary().bold())
        var idsComponents: [any Component] = []
        if let tenantId = server.tenantId {
            idsComponents.append(Text(fieldPrefix + "Project ID" + fieldSeparator + tenantId).secondary())
        }
        if let userId = server.userId {
            idsComponents.append(Text(fieldPrefix + "User ID" + fieldSeparator + userId).secondary())
        }
        let idsSection = VStack(spacing: 0, children: idsComponents)
            .padding(Self.serverDetailSectionEdgeInsets)
        components.append(idsSection)

        // Hypervisor Information Section
        if server.hypervisorHostname != nil || server.instanceName != nil || server.hostStatus != nil {
            components.append(Text("Hypervisor Information").primary().bold())
            var hypervisorComponents: [any Component] = []
            if let hypervisorHostname = server.hypervisorHostname {
                hypervisorComponents.append(Text(fieldPrefix + "Hypervisor" + fieldSeparator + hypervisorHostname).secondary())
            }
            if let instanceName = server.instanceName {
                hypervisorComponents.append(Text(fieldPrefix + "Instance Name" + fieldSeparator + instanceName).secondary())
            }
            if let hostStatus = server.hostStatus {
                hypervisorComponents.append(Text(fieldPrefix + "Host Status" + fieldSeparator + hostStatus).secondary())
            }
            let hypervisorSection = VStack(spacing: 0, children: hypervisorComponents)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(hypervisorSection)
        }

        // Metadata Section
        if let metadata = server.metadata, !metadata.isEmpty {
            components.append(Text("Metadata").primary().bold())
            var metadataComponents: [any Component] = []
            for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
                metadataComponents.append(Text(fieldPrefix + key + fieldSeparator + value).secondary())
            }
            let metadataSection = VStack(spacing: 0, children: metadataComponents)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(metadataSection)
        }

        // Timestamps Section
        if server.createdAt != nil || server.updatedAt != nil || server.launchedAt != nil || server.terminatedAt != nil {
            components.append(Text(Self.serverDetailTimestampsTitle).primary().bold())
            var timestampComponents: [any Component] = []
            if let created = server.createdAt {
                let createdPrefix = fieldPrefix + Self.serverDetailCreatedLabel + fieldSeparator
                let createdText = createdPrefix + String(describing: created)
                timestampComponents.append(Text(createdText).secondary())
            }
            if let updated = server.updatedAt {
                let updatedPrefix = fieldPrefix + Self.serverDetailUpdatedLabel + fieldSeparator
                let updatedText = updatedPrefix + String(describing: updated)
                timestampComponents.append(Text(updatedText).secondary())
            }
            if let launched = server.launchedAt {
                timestampComponents.append(Text(fieldPrefix + "Launched At" + fieldSeparator + String(describing: launched)).secondary())
            }
            if let terminated = server.terminatedAt {
                timestampComponents.append(Text(fieldPrefix + "Terminated At" + fieldSeparator + String(describing: terminated)).secondary())
            }
            let timestampSection = VStack(spacing: 0, children: timestampComponents)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(timestampSection)
        }

        // Fault Information (if any)
        if let fault = server.fault {
            components.append(Text("Fault Information").error().bold())
            var faultComponents: [any Component] = []
            faultComponents.append(Text(fieldPrefix + "Code" + fieldSeparator + String(fault.code)).error())
            faultComponents.append(Text(fieldPrefix + "Message" + fieldSeparator + fault.message).error())
            if let created = fault.created {
                faultComponents.append(Text(fieldPrefix + "Created" + fieldSeparator + String(describing: created)).error())
            }
            let faultSection = VStack(spacing: 0, children: faultComponents)
                .padding(Self.serverDetailSectionEdgeInsets)
            components.append(faultSection)
        }

        // Help text
        components.append(Text(Self.serverDetailHelpText).info()
            .padding(Self.serverDetailHelpEdgeInsets))

        // Apply scroll offset for large server details
        let visibleComponents: [any Component]
        if scrollOffset > 0 && scrollOffset < components.count {
            visibleComponents = Array(components.dropFirst(scrollOffset))
        } else if scrollOffset >= components.count {
            visibleComponents = [Text(Self.serverDetailScrolledToEndText).info()]
        } else {
            visibleComponents = components
        }

        // Render unified server detail
        let serverDetailComponent = VStack(spacing: Self.serverDetailComponentSpacing, children: visibleComponents)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(serverDetailComponent, on: surface, in: bounds)
    }


    @MainActor
    private static func createServerDetailComponent(
        server: Server,
        cachedVolumes: [Volume],

        cachedFlavors: [Flavor],
        cachedImages: [Image],
        scrollOffset: Int = 0
    ) async -> any Component {
        var components: [any Component] = []

        // Basic Information
        components.append(Text("Basic Information").accent().bold())
        components.append(Text("ID: \(server.id)").primary().padding(standardPadding))
        components.append(
            HStack {
                StatusIcon.server(status: server.status?.rawValue)
                Text("Status: \(server.status?.rawValue ?? "Unknown")").styled(TextStyle.forStatus(server.status?.rawValue))
            }.padding(sectionPadding)
        )

        // Flavor Information
        if let flavor = server.flavor {
            components.append(Text("Flavor").accent().bold())
            components.append(Text("ID: \(flavor.id ?? "N/A")").primary().padding(standardPadding))

            let flavorName = resolveFlavorName(from: server.flavor, cachedFlavors: cachedFlavors)
            components.append(Text("Name: \(flavorName)").primary().padding(sectionPadding))
        }

        // Image Information
        if let image = server.image {
            components.append(Text("Image").accent().bold())
            components.append(Text("ID: \(image.id)").primary().padding(standardPadding))
            let imageName = resolveImageName(from: server.image, cachedImages: cachedImages)
            components.append(Text("Name: \(imageName)").primary().padding(sectionPadding))
        }

        // Network Addresses
        if let addresses = server.addresses, !addresses.isEmpty {
            components.append(Text("Network Addresses").accent().bold())
            for (networkName, addressList) in addresses {
                components.append(Text("Network: \(networkName)").primary().padding(standardPadding))
                for address in addressList {
                    let versionText = address.version == 4 ? "IPv4" : "IPv6"
                    components.append(Text("\(versionText): \(address.addr)").secondary().padding(networkPadding))
                }
            }
        }

        // Attached Volumes
        let attachedVolumes = cachedVolumes.filter { $0.attachments?.contains { $0.serverId == server.id } ?? false }
        if !attachedVolumes.isEmpty {
            components.append(Text("Attached Volumes").accent().bold())
            for volume in attachedVolumes {
                components.append(Text("Name: \(volume.name ?? "Unnamed")").primary().padding(standardPadding))
                components.append(Text("Size: \(volume.size ?? 0) GB").primary().padding(standardPadding))
                components.append(Text("Status: \(volume.status ?? "Unknown")").styled(TextStyle.forStatus(volume.status)).padding(sectionPadding))
            }
        }

        // Timestamps
        if server.createdAt != nil || server.updatedAt != nil {
            components.append(Text("Timestamps").accent().bold())
            if let created = server.createdAt {
                components.append(Text("Created: \(String(describing: created))").primary().padding(standardPadding))
            }
            if let updated = server.updatedAt {
                components.append(Text("Updated: \(String(describing: updated))").primary().padding(standardPadding))
            }
        }

        // Apply scroll offset to show only visible components
        let visibleComponents: [any Component]
        if scrollOffset > 0 && scrollOffset < components.count {
            visibleComponents = Array(components.dropFirst(scrollOffset))
        } else if scrollOffset >= components.count {
            visibleComponents = []  // Scrolled past the end
        } else {
            visibleComponents = components  // No scrolling or negative offset
        }

        return VStack(spacing: 0, children: visibleComponents)
    }

    // MARK: - Helper Functions

    static func resolveFlavorName(from flavor: Server.FlavorInfo?, cachedFlavors: [Flavor]) -> String {
        guard let flavor = flavor else { return "Unknown" }

        // First try original_name from the flavor ref (API format)
        if let originalName = flavor.originalName, !originalName.isEmpty {
            return originalName
        }

        // Then try the name field
        if let name = flavor.name, !name.isEmpty {
            return name
        }

        // Fall back to cached flavor lookup by ID
        if let id = flavor.id, let cachedFlavor = cachedFlavors.first(where: { $0.id == id }) {
            return cachedFlavor.name ?? "Unknown Flavor"
        }

        // Last resort: show ID if available
        if let id = flavor.id {
            return id
        }

        return "Unknown"
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

    @MainActor
    private static func drawCurrentFlavorSection(screen: OpaquePointer?, startRow: inout Int32, startCol: Int32,
                                               width: Int32, height: Int32, serverResizeForm: ServerResizeForm) async {

        // Current Flavor Section using SwiftTUI
        let surface = SwiftTUI.surface(from: screen)

        let titleBounds = Rect(x: startCol + 2, y: startRow, width: width - 4, height: 1)
        await SwiftTUI.render(Text("Currently Assigned:").accent().bold(), on: surface, in: titleBounds)
        startRow += 1

        // Draw border for current flavor section
        await BaseViewComponents.drawBorder(screen: screen, startRow: startRow, startCol: startCol + 2,
                                    width: width - 4, height: 7, title: "Current Flavor")
        startRow += 1

        if let currentFlavor = serverResizeForm.getCurrentFlavor() {
            var flavorComponents: [any Component] = [
                Text("Name: \(currentFlavor.name ?? "Unknown")").secondary(),
                Text("ID: \(currentFlavor.id)").secondary()
            ]

            flavorComponents.append(Text("vCPUs: \(currentFlavor.vcpus)").secondary())

            flavorComponents.append(Text("RAM: \(currentFlavor.ram) MB").secondary())

            flavorComponents.append(Text("Disk: \(currentFlavor.disk) GB").secondary())

            let flavorSection = VStack(spacing: 0, children: flavorComponents)
                .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))

            let flavorBounds = Rect(x: startCol + 2, y: startRow, width: width - 4, height: Int32(flavorComponents.count))
            await SwiftTUI.render(flavorSection, on: surface, in: flavorBounds)
            startRow += Int32(flavorComponents.count)
        } else {
            let noBounds = Rect(x: startCol + 4, y: startRow, width: width - 8, height: 1)
            await SwiftTUI.render(Text("No current flavor information available").warning(), on: surface, in: noBounds)
            startRow += 1
        }
    }

    @MainActor
    private static func drawFlavorManagementSection(screen: OpaquePointer?, startRow: inout Int32, startCol: Int32,
                                                  width: Int32, height: Int32, serverResizeForm: ServerResizeForm) async {
        // Instructions and Available Flavors Header using SwiftTUI
        let surface = SwiftTUI.surface(from: screen)

        let instructionBounds = Rect(x: startCol + 2, y: startRow, width: width - 4, height: 1)
        let instruction = "SPACE: toggle | UP/DOWN: navigate | ENTER: apply changes"
        await SwiftTUI.render(Text(instruction).info(), on: surface, in: instructionBounds)
        startRow += 2

        let headerBounds = Rect(x: startCol + 2, y: startRow, width: width - 4, height: 1)
        await SwiftTUI.render(Text("Available Flavors:").accent().bold(), on: surface, in: headerBounds)
        startRow += 1

        let availableFlavors = serverResizeForm.getAvailableFlavors()
        guard !availableFlavors.isEmpty else {
            let noFlavorsBounds = Rect(x: startCol + 2, y: startRow, width: width - 4, height: 1)
            await SwiftTUI.render(Text("No flavors available").warning(), on: surface, in: noFlavorsBounds)
            return
        }

        let listHeight = height - 3
        let visibleCount = Int(listHeight)
        let selectedIndex = serverResizeForm.selectedFlavorIndex

        // Calculate scroll position
        let scrollOffset = max(0, selectedIndex - visibleCount / 2)
        let endIndex = min(availableFlavors.count, scrollOffset + visibleCount)

        // Draw flavors list using SwiftTUI
        for i in scrollOffset..<endIndex {
            let flavor = availableFlavors[i]
            let isSelected = (i == selectedIndex)
            let isCurrent = serverResizeForm.isCurrentFlavor(flavor.id)
            let isPending = serverResizeForm.isFlavorSelected(flavor.id)

            // Selection indicators following SecurityGroupManagementView pattern
            let indicator: String
            if isCurrent && isPending {
                indicator = "[X]" // Current flavor marked for change (will remove current)
            } else if isPending {
                indicator = "[*]" // Will change to this flavor
            } else if isCurrent {
                indicator = "[+]" // Current flavor (no change)
            } else {
                indicator = "[ ]" // Available but not selected
            }

            // Display flavor information
            let displayText = "\(indicator) \(flavor.name ?? "Unknown")"
            let availableWidth = Int(width) - 6
            var finalText = String(displayText.prefix(availableWidth))

            // Add specs if space allows
            if finalText.count < availableWidth - flavorSpecMinSpace {
                let specs = buildFlavorSpecs(flavor: flavor)
                if !specs.isEmpty {
                    finalText += " \(specs)"
                }
            }

            let rowStyle: TextStyle = isSelected ? .primary : .secondary
            let flavorRow = Text(finalText).styled(rowStyle)

            let rowBounds = Rect(x: startCol + 2, y: startRow, width: width - 4, height: 1)
            // Clear and render row with SwiftTUI selection highlighting
            if isSelected {
                await surface.fill(rect: rowBounds, character: " ", style: .accent)
            }
            await SwiftTUI.render(flavorRow, on: surface, in: rowBounds)

            startRow += 1
        }

        // Show scroll indicators if needed using SwiftTUI
        if scrollOffset > 0 {
            let upBounds = Rect(x: startCol + width - 3, y: startRow + 1, width: 1, height: 1)
            await SwiftTUI.render(Text("^").info(), on: surface, in: upBounds)
        }

        if endIndex < availableFlavors.count {
            let downBounds = Rect(x: startCol + width - 3, y: startRow + height - 2, width: 1, height: 1)
            await SwiftTUI.render(Text("v").info(), on: surface, in: downBounds)
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
                multiSelect: false,
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
                multiSelect: false,
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