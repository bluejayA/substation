import Foundation
import OSClient
import SwiftNCurses

/// Views for OpenStack Magnum (Container Infrastructure) resources
struct MagnumViews {

    // MARK: - Cluster List View

    /// Draw the cluster list view
    @MainActor
    static func drawClusterList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        cachedClusters: [Cluster],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        let statusListView = createClusterStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedClusters,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    /// Create the StatusListView for clusters
    @MainActor
    static func createClusterStatusListView() -> StatusListView<Cluster> {
        return StatusListView<Cluster>(
            title: "Clusters",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 25,
                    getValue: { cluster in
                        cluster.name ?? cluster.uuid
                    }
                ),
                StatusListColumn(
                    header: "STATUS",
                    width: 20,
                    getValue: { cluster in
                        cluster.status ?? "Unknown"
                    },
                    getStyle: { cluster in
                        guard let status = cluster.status?.uppercased() else { return .secondary }
                        if status.contains("COMPLETE") && !status.contains("FAILED") {
                            return .success
                        } else if status.contains("FAILED") {
                            return .error
                        } else if status.contains("IN_PROGRESS") {
                            return .warning
                        }
                        return .secondary
                    }
                ),
                StatusListColumn(
                    header: "NODES",
                    width: 8,
                    getValue: { cluster in
                        let total = (cluster.masterCount ?? 0) + (cluster.nodeCount ?? 0)
                        return String(total)
                    }
                ),
                StatusListColumn(
                    header: "MASTERS",
                    width: 8,
                    getValue: { cluster in
                        String(cluster.masterCount ?? 0)
                    }
                ),
                StatusListColumn(
                    header: "WORKERS",
                    width: 8,
                    getValue: { cluster in
                        String(cluster.nodeCount ?? 0)
                    }
                )
            ],
            getStatusIcon: { cluster in
                guard let status = cluster.status?.uppercased() else { return "unknown" }
                if status.contains("COMPLETE") && !status.contains("FAILED") {
                    return "active"
                } else if status.contains("FAILED") {
                    return "error"
                } else if status.contains("IN_PROGRESS") {
                    return "building"
                }
                return "unknown"
            },
            filterItems: { clusters, query in
                FilterUtils.filterClusters(clusters, query: query)
            },
            getItemID: { cluster in cluster.uuid }
        )
    }

    // MARK: - Cluster Detail View

    /// Draw the cluster detail view
    @MainActor
    static func drawClusterDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        cluster: Cluster,
        nodegroups: [Nodegroup],
        clusterTemplate: ClusterTemplate?,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "UUID", value: cluster.uuid),
            DetailView.buildFieldItem(label: "Name", value: cluster.name),
            cluster.status.map {
                .field(
                    label: "Status",
                    value: $0,
                    style: getStatusStyle(status: $0)
                )
            },
            cluster.statusReason.map { .field(label: "Status Reason", value: $0, style: .muted) }
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Cluster Configuration Section
        var configItems: [DetailItem?] = []

        if let template = clusterTemplate {
            configItems.append(.field(label: "Template", value: template.name ?? template.uuid, style: .secondary))
            configItems.append(.field(label: "COE", value: template.coeDisplayName, style: .info))
        } else {
            configItems.append(.field(label: "Template ID", value: cluster.clusterTemplateId, style: .muted))
        }

        if let keypair = cluster.keypair {
            configItems.append(.field(label: "Keypair", value: keypair, style: .secondary))
        }

        if let coeVersion = cluster.coeVersion {
            configItems.append(.field(label: "COE Version", value: coeVersion, style: .secondary))
        }

        if let timeout = cluster.createTimeout {
            configItems.append(.field(label: "Create Timeout", value: "\(timeout) minutes", style: .secondary))
        }

        if let configSection = DetailView.buildSection(title: "Configuration", items: configItems, titleStyle: .accent) {
            sections.append(configSection)
        }

        // Node Count Section
        var nodeItems: [DetailItem?] = []

        let totalNodes = (cluster.masterCount ?? 0) + (cluster.nodeCount ?? 0)
        nodeItems.append(.field(label: "Total Nodes", value: String(totalNodes), style: .info))

        if let masterCount = cluster.masterCount {
            nodeItems.append(.field(label: "Master Nodes", value: String(masterCount), style: .secondary))
        }

        if let nodeCount = cluster.nodeCount {
            nodeItems.append(.field(label: "Worker Nodes", value: String(nodeCount), style: .secondary))
        }

        if let nodeSection = DetailView.buildSection(title: "Node Counts", items: nodeItems, titleStyle: .accent) {
            sections.append(nodeSection)
        }

        // Node Addresses Section
        if let masterAddresses = cluster.masterAddresses, !masterAddresses.isEmpty {
            var masterItems: [DetailItem] = []
            for (index, address) in masterAddresses.enumerated() {
                masterItems.append(.field(label: "Master \(index + 1)", value: address, style: .secondary))
            }
            sections.append(DetailSection(title: "Master Addresses", items: masterItems))
        }

        if let nodeAddresses = cluster.nodeAddresses, !nodeAddresses.isEmpty {
            var workerItems: [DetailItem] = []
            for (index, address) in nodeAddresses.enumerated() {
                workerItems.append(.field(label: "Worker \(index + 1)", value: address, style: .secondary))
            }
            sections.append(DetailSection(title: "Worker Addresses", items: workerItems))
        }

        // API Endpoint Section
        if let apiAddress = cluster.apiAddress {
            let apiItems: [DetailItem?] = [
                .field(label: "API Endpoint", value: apiAddress, style: .info)
            ]
            if let apiSection = DetailView.buildSection(title: "API Access", items: apiItems, titleStyle: .accent) {
                sections.append(apiSection)
            }
        }

        // Nodegroups Section
        if !nodegroups.isEmpty {
            var nodegroupItems: [DetailItem] = []
            for nodegroup in nodegroups {
                let role = nodegroup.role ?? "worker"
                let count = nodegroup.nodeCount ?? 0
                let status = nodegroup.status ?? "unknown"
                let nodegroupName = nodegroup.name ?? nodegroup.uuid
                nodegroupItems.append(.field(
                    label: "\(nodegroupName) (\(role))",
                    value: "\(count) nodes - \(status)",
                    style: nodegroup.isActive ? .success : .warning
                ))
            }
            sections.append(DetailSection(title: "Nodegroups", items: nodegroupItems))
        }

        // Network Configuration Section
        var networkItems: [DetailItem?] = []

        if let floatingIp = cluster.floatingIpEnabled {
            networkItems.append(.field(label: "Floating IP", value: floatingIp ? "Enabled" : "Disabled", style: floatingIp ? .success : .secondary))
        }

        if let masterLb = cluster.masterLbEnabled {
            networkItems.append(.field(label: "Master Load Balancer", value: masterLb ? "Enabled" : "Disabled", style: masterLb ? .success : .secondary))
        }

        if let networkSection = DetailView.buildSection(title: "Network Configuration", items: networkItems, titleStyle: .accent) {
            sections.append(networkSection)
        }

        // Labels Section
        if let labels = cluster.labels, !labels.isEmpty {
            var labelItems: [DetailItem] = []
            for (key, value) in labels.sorted(by: { $0.key < $1.key }) {
                labelItems.append(.field(label: key, value: value, style: .secondary))
            }
            sections.append(DetailSection(title: "Labels", items: labelItems))
        }

        // Infrastructure Section
        var infraItems: [DetailItem?] = []

        if let stackId = cluster.stackId {
            infraItems.append(.field(label: "Heat Stack ID", value: stackId, style: .muted))
        }

        if let discoveryUrl = cluster.discoveryUrl {
            infraItems.append(.field(label: "Discovery URL", value: discoveryUrl, style: .muted))
        }

        if let infraSection = DetailView.buildSection(title: "Infrastructure", items: infraItems, titleStyle: .accent) {
            sections.append(infraSection)
        }

        // Ownership Section
        var ownerItems: [DetailItem?] = []

        if let projectId = cluster.projectId {
            ownerItems.append(.field(label: "Project ID", value: projectId, style: .muted))
        }

        if let userId = cluster.userId {
            ownerItems.append(.field(label: "User ID", value: userId, style: .muted))
        }

        if let ownerSection = DetailView.buildSection(title: "Ownership", items: ownerItems, titleStyle: .accent) {
            sections.append(ownerSection)
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: cluster.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: cluster.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Cluster Details: \(cluster.displayName)",
            sections: sections,
            helpText: "Press ESC to return to clusters list",
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

    // MARK: - Cluster Template List View

    /// Draw the cluster template list view
    ///
    /// Renders the list of cluster templates with support for multi-select mode.
    ///
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - startRow: Starting row position
    ///   - startCol: Starting column position
    ///   - width: Available width
    ///   - height: Available height
    ///   - cachedTemplates: Array of cluster templates to display
    ///   - searchQuery: Optional search query for filtering
    ///   - scrollOffset: Current scroll offset
    ///   - selectedIndex: Currently selected index
    ///   - multiSelectMode: Whether multi-select mode is active
    ///   - selectedItems: Set of selected item IDs for multi-select
    @MainActor
    static func drawClusterTemplateList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        cachedTemplates: [ClusterTemplate],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
    ) async {
        let statusListView = createClusterTemplateStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedTemplates,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
        )
    }

    /// Create the StatusListView for cluster templates
    @MainActor
    static func createClusterTemplateStatusListView() -> StatusListView<ClusterTemplate> {
        return StatusListView<ClusterTemplate>(
            title: "Cluster Templates",
            columns: [
                StatusListColumn(
                    header: "NAME",
                    width: 28,
                    getValue: { template in
                        template.name ?? template.uuid
                    }
                ),
                StatusListColumn(
                    header: "COE",
                    width: 12,
                    getValue: { template in
                        template.coeDisplayName
                    },
                    getStyle: { template in
                        switch template.coe.lowercased() {
                        case "kubernetes": return .success
                        case "swarm": return .info
                        case "mesos": return .warning
                        default: return .secondary
                        }
                    }
                ),
                StatusListColumn(
                    header: "NETWORK",
                    width: 12,
                    getValue: { template in
                        template.networkDriver ?? "default"
                    }
                ),
                StatusListColumn(
                    header: "SERVER",
                    width: 10,
                    getValue: { template in
                        template.serverType ?? "vm"
                    }
                ),
                StatusListColumn(
                    header: "PUBLIC",
                    width: 8,
                    getValue: { template in
                        template.isPublic == true ? "Yes" : "No"
                    },
                    getStyle: { template in
                        template.isPublic == true ? .info : .secondary
                    }
                )
            ],
            getStatusIcon: { _ in "active" },
            filterItems: { templates, query in
                FilterUtils.filterClusterTemplates(templates, query: query)
            },
            getItemID: { template in template.uuid }
        )
    }

    // MARK: - Cluster Template Detail View

    /// Draw the cluster template detail view
    @MainActor
    static func drawClusterTemplateDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        template: ClusterTemplate,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "UUID", value: template.uuid),
            DetailView.buildFieldItem(label: "Name", value: template.name),
            .field(label: "COE", value: template.coeDisplayName, style: .info),
            template.isPublic.map { .field(label: "Public", value: $0 ? "Yes" : "No", style: $0 ? .info : .secondary) },
            template.hidden.map { .field(label: "Hidden", value: $0 ? "Yes" : "No", style: $0 ? .warning : .secondary) }
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Compute Configuration Section
        var computeItems: [DetailItem?] = []

        computeItems.append(.field(label: "Image ID", value: template.imageId, style: .secondary))

        if let flavorId = template.flavorId {
            computeItems.append(.field(label: "Worker Flavor", value: flavorId, style: .secondary))
        }

        if let masterFlavorId = template.masterFlavorId {
            computeItems.append(.field(label: "Master Flavor", value: masterFlavorId, style: .secondary))
        }

        if let serverType = template.serverType {
            computeItems.append(.field(label: "Server Type", value: serverType, style: .secondary))
        }

        if let distro = template.clusterDistro {
            computeItems.append(.field(label: "Distribution", value: distro, style: .secondary))
        }

        if let computeSection = DetailView.buildSection(title: "Compute Configuration", items: computeItems, titleStyle: .accent) {
            sections.append(computeSection)
        }

        // Network Configuration Section
        var networkItems: [DetailItem?] = []

        if let networkDriver = template.networkDriver {
            networkItems.append(.field(label: "Network Driver", value: networkDriver, style: .secondary))
        }

        if let externalNetwork = template.externalNetworkId {
            networkItems.append(.field(label: "External Network", value: externalNetwork, style: .secondary))
        }

        if let fixedNetwork = template.fixedNetwork {
            networkItems.append(.field(label: "Fixed Network", value: fixedNetwork, style: .secondary))
        }

        if let fixedSubnet = template.fixedSubnet {
            networkItems.append(.field(label: "Fixed Subnet", value: fixedSubnet, style: .secondary))
        }

        if let dns = template.dnsNameserver {
            networkItems.append(.field(label: "DNS Nameserver", value: dns, style: .secondary))
        }

        if let floatingIp = template.floatingIpEnabled {
            networkItems.append(.field(label: "Floating IPs", value: floatingIp ? "Enabled" : "Disabled", style: floatingIp ? .success : .secondary))
        }

        if let masterLb = template.masterLbEnabled {
            networkItems.append(.field(label: "Master LB", value: masterLb ? "Enabled" : "Disabled", style: masterLb ? .success : .secondary))
        }

        if let networkSection = DetailView.buildSection(title: "Network Configuration", items: networkItems, titleStyle: .accent) {
            sections.append(networkSection)
        }

        // Storage Configuration Section
        var storageItems: [DetailItem?] = []

        if let dockerVolumeSize = template.dockerVolumeSize {
            storageItems.append(.field(label: "Docker Volume Size", value: "\(dockerVolumeSize) GB", style: .secondary))
        }

        if let dockerStorageDriver = template.dockerStorageDriver {
            storageItems.append(.field(label: "Docker Storage Driver", value: dockerStorageDriver, style: .secondary))
        }

        if let volumeDriver = template.volumeDriver {
            storageItems.append(.field(label: "Volume Driver", value: volumeDriver, style: .secondary))
        }

        if let storageSection = DetailView.buildSection(title: "Storage Configuration", items: storageItems, titleStyle: .accent) {
            sections.append(storageSection)
        }

        // Security Configuration Section
        var securityItems: [DetailItem?] = []

        if let keypairId = template.keypairId {
            securityItems.append(.field(label: "Keypair", value: keypairId, style: .secondary))
        }

        if let tlsDisabled = template.tlsDisabled {
            securityItems.append(.field(label: "TLS", value: tlsDisabled ? "Disabled" : "Enabled", style: tlsDisabled ? .warning : .success))
        }

        if let registryEnabled = template.registryEnabled {
            securityItems.append(.field(label: "Registry", value: registryEnabled ? "Enabled" : "Disabled", style: registryEnabled ? .success : .secondary))
        }

        if let insecureRegistry = template.insecureRegistry {
            securityItems.append(.field(label: "Insecure Registry", value: insecureRegistry, style: .warning))
        }

        if let securitySection = DetailView.buildSection(title: "Security Configuration", items: securityItems, titleStyle: .accent) {
            sections.append(securitySection)
        }

        // Proxy Configuration Section
        var proxyItems: [DetailItem?] = []

        if let httpProxy = template.httpProxy {
            proxyItems.append(.field(label: "HTTP Proxy", value: httpProxy, style: .secondary))
        }

        if let httpsProxy = template.httpsProxy {
            proxyItems.append(.field(label: "HTTPS Proxy", value: httpsProxy, style: .secondary))
        }

        if let noProxy = template.noProxy {
            proxyItems.append(.field(label: "No Proxy", value: noProxy, style: .secondary))
        }

        if let proxySection = DetailView.buildSection(title: "Proxy Configuration", items: proxyItems, titleStyle: .accent) {
            sections.append(proxySection)
        }

        // Labels Section
        if let labels = template.labels, !labels.isEmpty {
            var labelItems: [DetailItem] = []
            for (key, value) in labels.sorted(by: { $0.key < $1.key }) {
                labelItems.append(.field(label: key, value: value, style: .secondary))
            }
            sections.append(DetailSection(title: "Labels", items: labelItems))
        }

        // Tags Section
        if let tags = template.tags, !tags.isEmpty {
            let tagItems = tags.map { DetailItem.field(label: "Tag", value: $0, style: .secondary) }
            sections.append(DetailSection(title: "Tags", items: tagItems))
        }

        // Timestamps Section
        let timestampItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Created", value: template.createdAt?.formatted(date: .abbreviated, time: .shortened)),
            DetailView.buildFieldItem(label: "Updated", value: template.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        ]

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Cluster Template Details: \(template.displayName)",
            sections: sections,
            helpText: "Press ESC to return to cluster templates list",
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

    // MARK: - Cluster Create View

    /// Draw the cluster create form view
    @MainActor
    static func drawClusterCreateForm(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formState: FormBuilderState,
        templates: [ClusterTemplate],
        keypairs: [KeyPair]
    ) async {
        let surface = SwiftNCurses.surface(from: screen)
        let mainRect = Rect(x: startCol, y: startRow, width: width, height: height)

        // Clear the area
        await surface.fill(rect: mainRect, character: " ", style: .primary)

        var components: [any Component] = []

        // Title
        components.append(
            Text("Create Kubernetes Cluster").primary().bold()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        )

        // Info text
        components.append(
            Text("Configure a new container orchestration cluster").secondary()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
        )

        // Render form fields manually from FormBuilderState
        for (index, field) in formState.fields.enumerated() {
            let isSelected = formState.selectedFieldIndex == index
            let isActive = field.isActive
            let fieldStyle: TextStyle = isSelected ? (isActive ? .info : .emphasis) : .secondary

            switch field {
            case .text(let textField):
                let value = formState.textFieldStates[textField.id]?.value ?? ""
                let displayValue = value.isEmpty ? textField.placeholder : value
                let labelText = Text(textField.label + ": ").styled(fieldStyle)
                let valueText = Text(displayValue).styled(value.isEmpty ? .muted : fieldStyle)
                components.append(
                    HStack(spacing: 0) {
                        labelText
                        valueText
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
                )

            case .number(let numberField):
                let value = formState.textFieldStates[numberField.id]?.value ?? ""
                let displayValue = value.isEmpty ? numberField.placeholder : value
                let labelText = Text(numberField.label + ": ").styled(fieldStyle)
                let valueText = Text(displayValue).styled(value.isEmpty ? .muted : fieldStyle)
                components.append(
                    HStack(spacing: 0) {
                        labelText
                        valueText
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
                )

            case .selector(let selectorField):
                let selectorState = formState.selectorStates[selectorField.id]
                let selectedId = selectorState?.selectedItemId
                let selectedItem = selectorField.items.first { $0.id == selectedId }
                let displayValue = selectedItem.map { item -> String in
                    (item as? ClusterTemplate)?.displayName ?? (item as? KeyPair)?.name ?? "Selected"
                } ?? "None selected"
                let labelText = Text(selectorField.label + ": ").styled(fieldStyle)
                let valueText = Text(displayValue).styled(selectedItem != nil ? fieldStyle : .muted)
                components.append(
                    HStack(spacing: 0) {
                        labelText
                        valueText
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
                )

            default:
                break
            }
        }

        // Separator
        components.append(
            Text(String(repeating: "-", count: Int(width) - 6)).muted()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        )

        // Submit button hint
        components.append(
            Text("Press ENTER to create cluster").info()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
        )

        // Build the content
        let content = VStack(spacing: 0, children: components)

        // Render content
        let contentRect = Rect(x: startCol + 2, y: startRow, width: width - 4, height: height - 2)
        await SwiftNCurses.render(content, on: surface, in: contentRect)

        // Help text at bottom
        let isFieldActive = formState.isCurrentFieldActive()
        let helpText = isFieldActive
            ? "Type to edit | ENTER: Confirm | ESC: Cancel edit"
            : "TAB: Navigate | SPACE: Edit | ENTER: Submit | ESC: Cancel"
        let helpComponent = Text(helpText).muted()
        let helpRect = Rect(x: startCol + 2, y: startRow + height - 2, width: width - 4, height: 1)
        await SwiftNCurses.render(helpComponent, on: surface, in: helpRect)
    }

    // MARK: - Cluster Resize View

    /// Draw the cluster resize view
    @MainActor
    static func drawClusterResizeForm(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        resizeState: ClusterResizeFormState
    ) async {
        let surface = SwiftNCurses.surface(from: screen)
        let mainRect = Rect(x: startCol, y: startRow, width: width, height: height)

        // Clear the area
        await surface.fill(rect: mainRect, character: " ", style: .primary)

        var components: [any Component] = []

        // Title
        components.append(
            Text("Resize Cluster").primary().bold()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        )

        // Cluster name
        components.append(
            Text("Cluster: \(resizeState.clusterName)").secondary()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
        )

        // Current node count
        components.append(
            Text("Current Worker Nodes: \(resizeState.currentNodeCount)").secondary()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
        )

        // Separator
        components.append(
            Text(String(repeating: "-", count: Int(width) - 6)).muted()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
        )

        // New node count input area
        let nodeCountStyle: TextStyle = resizeState.needsResize ? .success : .secondary
        components.append(
            Text("New Worker Nodes: \(resizeState.newNodeCount)").styled(nodeCountStyle)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
        )

        // Change indicator
        if resizeState.needsResize {
            let changeText = resizeState.newNodeCount > resizeState.currentNodeCount
                ? "Scale UP by \(resizeState.newNodeCount - resizeState.currentNodeCount) node(s)"
                : "Scale DOWN by \(resizeState.currentNodeCount - resizeState.newNodeCount) node(s)"
            components.append(
                Text(changeText).info()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
            )
        }

        // Error message if any
        if let error = resizeState.errorMessage {
            components.append(
                Text("Error: \(error)").error()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
            )
        }

        // Submitting indicator
        if resizeState.isSubmitting {
            components.append(
                Text("Submitting resize request...").warning()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0))
            )
        }

        // Build the content
        let content = VStack(spacing: 0, children: components)

        // Render content
        let contentRect = Rect(x: startCol + 2, y: startRow, width: width - 4, height: height - 2)
        await SwiftNCurses.render(content, on: surface, in: contentRect)

        // Help text at bottom
        let helpText = "+/-: Adjust count | ENTER: Submit resize | ESC: Cancel"
        let helpComponent = Text(helpText).muted()
        let helpRect = Rect(x: startCol + 2, y: startRow + height - 2, width: width - 4, height: 1)
        await SwiftNCurses.render(helpComponent, on: surface, in: helpRect)
    }

    // MARK: - Cluster Template Create View

    /// Draw the cluster template create form view
    ///
    /// Renders the form for creating a new cluster template with fields for:
    /// - Template name, COE selection, image, network, flavor configurations
    /// - Docker volume size, network driver, floating IP and master LB toggles
    ///
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - startRow: Starting row position
    ///   - startCol: Starting column position
    ///   - width: Available width
    ///   - height: Available height
    ///   - formState: The form builder state containing field values
    @MainActor
    static func drawClusterTemplateCreateForm(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        formState: FormBuilderState
    ) async {
        let surface = SwiftNCurses.surface(from: screen)
        let mainRect = Rect(x: startCol, y: startRow, width: width, height: height)

        // Clear the area
        await surface.fill(rect: mainRect, character: " ", style: .primary)

        var components: [any Component] = []

        // Title
        components.append(
            Text("Create Cluster Template").primary().bold()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        )

        // Info text
        components.append(
            Text("Configure a new cluster template for container orchestration").secondary()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
        )

        // Render form fields manually from FormBuilderState
        for (index, field) in formState.fields.enumerated() {
            let isSelected = formState.selectedFieldIndex == index
            let isActive = field.isActive
            let fieldStyle: TextStyle = isSelected ? (isActive ? .info : .emphasis) : .secondary

            switch field {
            case .text(let textField):
                let value = formState.textFieldStates[textField.id]?.value ?? ""
                let displayValue = value.isEmpty ? textField.placeholder : value
                let labelText = Text(textField.label + ": ").styled(fieldStyle)
                let valueText = Text(displayValue).styled(value.isEmpty ? .muted : fieldStyle)
                components.append(
                    HStack(spacing: 0) {
                        labelText
                        valueText
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
                )

            case .number(let numberField):
                let value = formState.textFieldStates[numberField.id]?.value ?? ""
                let displayValue = value.isEmpty ? numberField.placeholder : value
                let unit = numberField.unit ?? ""
                let labelText = Text(numberField.label + ": ").styled(fieldStyle)
                let valueText = Text(displayValue + (unit.isEmpty ? "" : " " + unit)).styled(value.isEmpty ? .muted : fieldStyle)
                components.append(
                    HStack(spacing: 0) {
                        labelText
                        valueText
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
                )

            case .selector(let selectorField):
                let selectorState = formState.selectorStates[selectorField.id]
                let selectedId = selectorState?.selectedItemId
                let selectedItem = selectorField.items.first { $0.id == selectedId }
                let displayValue = getDisplayValue(for: selectedItem, fieldId: selectorField.id)
                let labelText = Text(selectorField.label + ": ").styled(fieldStyle)
                let valueText = Text(displayValue).styled(selectedItem != nil ? fieldStyle : .muted)
                components.append(
                    HStack(spacing: 0) {
                        labelText
                        valueText
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
                )

            case .toggle(let toggleField):
                let value = formState.getToggleValue(toggleField.id) ?? toggleField.value
                let labelText = Text(toggleField.label + ": ").styled(fieldStyle)
                let valueText = Text(value ? "Yes" : "No").styled(value ? .success : .secondary)
                components.append(
                    HStack(spacing: 0) {
                        labelText
                        valueText
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
                )

            default:
                break
            }
        }

        // Separator
        components.append(
            Text(String(repeating: "-", count: Int(width) - 6)).muted()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        )

        // Submit button hint
        components.append(
            Text("Press ENTER to create template").info()
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
        )

        // Build the content
        let content = VStack(spacing: 0, children: components)

        // Render content
        let contentRect = Rect(x: startCol + 2, y: startRow, width: width - 4, height: height - 2)
        await SwiftNCurses.render(content, on: surface, in: contentRect)

        // Help text at bottom
        let isFieldActive = formState.isCurrentFieldActive()
        let helpText = isFieldActive
            ? "Type to edit | ENTER: Confirm | ESC: Cancel edit"
            : "TAB: Navigate | SPACE: Edit/Toggle | ENTER: Submit | ESC: Cancel"
        let helpComponent = Text(helpText).muted()
        let helpRect = Rect(x: startCol + 2, y: startRow + height - 2, width: width - 4, height: 1)
        await SwiftNCurses.render(helpComponent, on: surface, in: helpRect)
    }

    /// Get display value for a selector field item
    ///
    /// - Parameters:
    ///   - item: The selected item (can be various types)
    ///   - fieldId: The field identifier for context
    /// - Returns: Display string for the item
    private static func getDisplayValue(for item: (any FormSelectorItem)?, fieldId: String) -> String {
        guard let item = item else { return "None selected" }

        // Try to get display name based on item type
        if let image = item as? Image {
            return image.name ?? "Unknown"
        } else if let network = item as? Network {
            return network.name ?? "Unknown"
        } else if let flavor = item as? Flavor {
            return flavor.name ?? "Unknown"
        } else if let keypair = item as? KeyPair {
            return keypair.name ?? "Unknown"
        } else if let template = item as? ClusterTemplate {
            return template.displayName
        }

        return "Selected"
    }

    // MARK: - Helper Functions

    /// Get the text style for a cluster status
    private static func getStatusStyle(status: String) -> TextStyle {
        let upper = status.uppercased()
        if upper.contains("COMPLETE") && !upper.contains("FAILED") {
            return .success
        } else if upper.contains("FAILED") {
            return .error
        } else if upper.contains("IN_PROGRESS") {
            return .warning
        }
        return .secondary
    }
}
