// Sources/Substation/Framework/ViewModeBridge.swift
import Foundation

/// Bridge between legacy ViewMode enum and new ViewIdentifier system
///
/// This extension provides backward compatibility during migration from
/// the static ViewMode enum to the dynamic ViewIdentifier protocol system.
/// This will be removed once migration is complete.
extension ViewMode {
    /// Convert ViewMode to a view identifier string
    ///
    /// Maps legacy ViewMode cases to the new string-based identifier format
    /// used by the ViewIdentifier system.
    var viewIdentifierId: String {
        switch self {
        // Core views
        case .loading: return CoreViews.loading.id
        case .dashboard: return CoreViews.dashboard.id
        case .healthDashboard: return CoreViews.healthDashboard.id
        case .healthDashboardServiceDetail: return CoreViews.healthDashboardServiceDetail.id
        case .performanceMetrics: return CoreViews.performanceMetrics.id
        case .help: return CoreViews.help.id
        case .about: return CoreViews.about.id
        case .welcome: return CoreViews.welcome.id
        case .tutorial: return CoreViews.tutorial.id
        case .shortcuts: return CoreViews.shortcuts.id
        case .examples: return CoreViews.examples.id
        case .advancedSearch: return CoreViews.advancedSearch.id

        // Servers module
        case .servers: return "servers.list"
        case .serverDetail: return "servers.detail"
        case .serverCreate: return "servers.create"
        case .serverConsole: return "servers.console"
        case .serverResize: return "servers.resize"
        case .serverSnapshotManagement: return "servers.snapshotManagement"
        case .serverSecurityGroups: return "servers.securityGroups"
        case .serverNetworkInterfaces: return "servers.networkInterfaces"
        case .serverGroupManagement: return "servers.groupManagement"

        // Server Groups module
        case .serverGroups: return "servergroups.list"
        case .serverGroupDetail: return "servergroups.detail"
        case .serverGroupCreate: return "servergroups.create"

        // Networks module
        case .networks: return "networks.list"
        case .networkDetail: return "networks.detail"
        case .networkCreate: return "networks.create"
        case .networkServerAttachment: return "networks.serverAttachment"
        case .networkServerManagement: return "networks.serverManagement"

        // Subnets module
        case .subnets: return "subnets.list"
        case .subnetDetail: return "subnets.detail"
        case .subnetCreate: return "subnets.create"
        case .subnetRouterManagement: return "subnets.routerManagement"

        // Routers module
        case .routers: return "routers.list"
        case .routerDetail: return "routers.detail"
        case .routerCreate: return "routers.create"
        case .routerEdit: return "routers.edit"
        case .routerSubnetManagement: return "routers.subnetManagement"

        // Ports module
        case .ports: return "ports.list"
        case .portDetail: return "ports.detail"
        case .portCreate: return "ports.create"
        case .portServerManagement: return "ports.serverManagement"
        case .portAllowedAddressPairManagement: return "ports.allowedAddressPairs"

        // Floating IPs module
        case .floatingIPs: return "floatingips.list"
        case .floatingIPDetail: return "floatingips.detail"
        case .floatingIPCreate: return "floatingips.create"
        case .floatingIPServerSelect: return "floatingips.serverSelect"
        case .floatingIPServerManagement: return "floatingips.serverManagement"
        case .floatingIPPortManagement: return "floatingips.portManagement"

        // Security Groups module
        case .securityGroups: return "securitygroups.list"
        case .securityGroupDetail: return "securitygroups.detail"
        case .securityGroupCreate: return "securitygroups.create"
        case .securityGroupRuleManagement: return "securitygroups.ruleManagement"
        case .securityGroupServerAttachment: return "securitygroups.serverAttachment"
        case .securityGroupServerManagement: return "securitygroups.serverManagement"

        // Volumes module
        case .volumes: return "volumes.list"
        case .volumeDetail: return "volumes.detail"
        case .volumeCreate: return "volumes.create"
        case .volumeArchives: return "volumes.archives"
        case .volumeArchiveDetail: return "volumes.archiveDetail"
        case .volumeManagement: return "volumes.management"
        case .volumeServerManagement: return "volumes.serverManagement"
        case .volumeSnapshotManagement: return "volumes.snapshotManagement"
        case .volumeBackupManagement: return "volumes.backupManagement"

        // Images module
        case .images: return "images.list"
        case .imageDetail: return "images.detail"
        case .imageCreate: return "images.create"

        // Flavors module
        case .flavors: return "flavors.list"
        case .flavorDetail: return "flavors.detail"
        case .flavorSelection: return "flavors.selection"

        // Key Pairs module
        case .keyPairs: return "keypairs.list"
        case .keyPairDetail: return "keypairs.detail"
        case .keyPairCreate: return "keypairs.create"

        // Barbican module
        case .barbican: return "barbican.list"
        case .barbicanSecrets: return "barbican.secrets"
        case .barbicanSecretDetail: return "barbican.secretDetail"
        case .barbicanSecretCreate: return "barbican.secretCreate"

        // Swift module
        case .swift: return "swift.containers"
        case .swiftContainerDetail: return "swift.containerDetail"
        case .swiftObjectDetail: return "swift.objectDetail"
        case .swiftContainerCreate: return "swift.containerCreate"
        case .swiftObjectUpload: return "swift.objectUpload"
        case .swiftContainerDownload: return "swift.containerDownload"
        case .swiftObjectDownload: return "swift.objectDownload"
        case .swiftDirectoryDownload: return "swift.directoryDownload"
        case .swiftContainerMetadata: return "swift.containerMetadata"
        case .swiftObjectMetadata: return "swift.objectMetadata"
        case .swiftDirectoryMetadata: return "swift.directoryMetadata"
        case .swiftContainerWebAccess: return "swift.webAccess"
        case .swiftBackgroundOperations: return "swift.backgroundOperations"
        case .swiftBackgroundOperationDetail: return "swift.backgroundOperationDetail"
        }
    }

    /// Create a DynamicViewIdentifier from this ViewMode
    var toViewIdentifier: DynamicViewIdentifier {
        let id = self.viewIdentifierId
        let moduleId = id.split(separator: ".").first.map(String.init) ?? "core"
        let viewType = self.isDetailView ? ViewType.detail : (id.contains("create") ? .create : .list)

        return DynamicViewIdentifier(
            id: id,
            moduleId: moduleId,
            viewType: viewType
        )
    }
}

// MARK: - ViewIdentifier to ViewMode Bridge

extension ViewIdentifier {
    /// Try to convert a ViewIdentifier to the legacy ViewMode
    ///
    /// Returns nil if no matching ViewMode exists. This is useful during
    /// migration when some code still expects ViewMode values.
    var toViewMode: ViewMode? {
        // Use a static lookup for efficiency
        return ViewModeBridge.viewModeForId(self.id)
    }
}

/// Helper for ViewMode/ViewIdentifier conversions
enum ViewModeBridge {
    /// Mapping from view identifier strings to ViewMode
    private static let idToViewMode: [String: ViewMode] = {
        var mapping: [String: ViewMode] = [:]
        for viewMode in ViewMode.allCases {
            mapping[viewMode.viewIdentifierId] = viewMode
        }
        return mapping
    }()

    /// Get ViewMode for a view identifier string
    ///
    /// - Parameter id: The view identifier string
    /// - Returns: Corresponding ViewMode if exists
    static func viewModeForId(_ id: String) -> ViewMode? {
        return idToViewMode[id]
    }

    /// Get ViewMode for a ViewIdentifier
    ///
    /// - Parameter identifier: The view identifier
    /// - Returns: Corresponding ViewMode if exists
    static func viewMode(for identifier: any ViewIdentifier) -> ViewMode? {
        return idToViewMode[identifier.id]
    }
}
