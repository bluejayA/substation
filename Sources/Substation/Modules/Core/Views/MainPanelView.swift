import Foundation
import SwiftNCurses

enum ViewMode: CaseIterable {
    case loading, dashboard, advancedSearch, healthDashboard, servers, serverGroups, securityGroups,
        volumes, volumeArchives, images, flavors, subnets, ports, routers, floatingIPs, networks,
        barbican, barbicanSecrets, swift, swiftBackgroundOperations,
        performanceMetrics, serverDetail, serverConsole, serverGroupDetail, networkDetail,
        securityGroupDetail, volumeDetail, volumeArchiveDetail, imageDetail, flavorDetail,
        subnetDetail, portDetail, routerDetail, floatingIPDetail, healthDashboardServiceDetail,
        barbicanSecretDetail,
        swiftContainerDetail, swiftObjectDetail, swiftBackgroundOperationDetail, serverCreate,
        serverGroupCreate, networkCreate, securityGroupCreate, securityGroupRuleManagement,
        subnetCreate, volumeCreate, portCreate, routerCreate, floatingIPCreate, keyPairs,
        keyPairDetail, keyPairCreate, help, about, welcome, tutorial, shortcuts, examples, serverSecurityGroups, serverNetworkInterfaces,
        serverGroupManagement, volumeManagement, floatingIPServerSelect, serverSnapshotManagement,
        serverResize, volumeSnapshotManagement, volumeBackupManagement, networkServerAttachment,
        securityGroupServerAttachment, securityGroupServerManagement, networkServerManagement,
        volumeServerManagement, floatingIPServerManagement, floatingIPPortManagement,
        portServerManagement, portAllowedAddressPairManagement, subnetRouterManagement,
        flavorSelection, barbicanSecretCreate,
        swiftContainerCreate, swiftObjectUpload, swiftContainerDownload, swiftObjectDownload,
        swiftDirectoryDownload, swiftContainerMetadata, swiftObjectMetadata, swiftDirectoryMetadata,
        swiftContainerWebAccess

    var title: String {
        switch self {
        case .loading: return "Loading"
        case .dashboard: return "Dashboard"
        case .servers: return "Servers"
        case .serverDetail: return "Server Details"
        case .serverConsole: return "Server Console"
        case .serverCreate: return "Create Server"
        case .serverSnapshotManagement: return "Create Server Snapshot"
        case .serverResize: return "Resize Server"
        case .serverGroups: return "Server Groups"
        case .serverGroupCreate: return "Create Server Group"
        case .serverGroupDetail: return "Server Group Details"
        case .serverSecurityGroups: return "Manage Security Groups"
        case .serverNetworkInterfaces: return "Manage Network Interfaces"
        case .serverGroupManagement: return "Manage Server Group"
        case .routers: return "Routers"
        case .routerDetail: return "Router Details"
        case .routerCreate: return "Create Router"
        case .networks: return "Networks"
        case .networkDetail: return "Network Details"
        case .networkCreate: return "Create Network"
        case .subnets: return "Subnets"
        case .subnetDetail: return "Subnet Details"
        case .subnetCreate: return "Create Subnet"
        case .floatingIPs: return "Floating IPs"
        case .floatingIPCreate: return "Create Floating IP"
        case .floatingIPDetail: return "Floating IP Details"
        case .floatingIPServerSelect: return "Select Server for Floating IP"
        case .securityGroups: return "Security Groups"
        case .securityGroupDetail: return "Security Group Details"
        case .securityGroupCreate: return "Create Security Group"
        case .securityGroupRuleManagement: return "Manage Security Group Rules"
        case .ports: return "Ports"
        case .portDetail: return "Port Details"
        case .portCreate: return "Create Port"
        case .volumes: return "Volumes"
        case .volumeArchives: return "Volume Archives"
        case .volumeArchiveDetail: return "Archive Details"
        case .volumeDetail: return "Volume Details"
        case .volumeCreate: return "Create Volume"
        case .volumeManagement: return "Manage Volume Attachments"
        case .volumeSnapshotManagement: return "Create Volume Snapshot"
        case .volumeBackupManagement: return "Create Volume Backup"
        case .images: return "Images"
        case .imageDetail: return "Image Details"
        case .flavors: return "Flavors"
        case .flavorDetail: return "Flavor Details"
        case .keyPairs: return "Key Pairs"
        case .keyPairDetail: return "Key Pair Details"
        case .keyPairCreate: return "Create Key Pair"
        case .advancedSearch: return "Search"
        case .healthDashboard: return "Health Dashboard"
        case .healthDashboardServiceDetail: return "Service Details"
        case .barbican: return "Secrets"
        case .barbicanSecrets: return "Secrets"
        case .swift: return "Object Storage"
        case .barbicanSecretDetail: return "Secret Details"
        case .swiftContainerDetail: return "Container Objects"
        case .swiftObjectDetail: return "Object Details"
        case .barbicanSecretCreate: return "Create Secret"
        case .swiftContainerCreate: return "Create Container"
        case .swiftObjectUpload: return "Upload Object"
        case .swiftContainerDownload: return "Download Container"
        case .swiftObjectDownload: return "Download Object"
        case .swiftDirectoryDownload: return "Download Directory"
        case .swiftContainerMetadata: return "Set Container Metadata"
        case .swiftObjectMetadata: return "Set Object Metadata"
        case .swiftDirectoryMetadata: return "Set Directory Metadata"
        case .swiftContainerWebAccess: return "Manage Web Access"
        case .help: return "Help"
        case .about: return "About"
        case .welcome: return "Welcome to Substation"
        case .tutorial: return "Tutorial"
        case .shortcuts: return "Command Shortcuts"
        case .examples: return "Command Examples"
        case .networkServerAttachment: return "Attach Network to Servers"
        case .securityGroupServerAttachment: return "Attach Security Group to Servers"
        case .securityGroupServerManagement: return "Manage Security Group Server Attachments"
        case .networkServerManagement: return "Manage Network Server Attachments"
        case .volumeServerManagement: return "Manage Volume Server Attachments"
        case .floatingIPServerManagement: return "Manage Floating IP Server Assignment"
        case .floatingIPPortManagement: return "Manage Floating IP Port Assignment"
        case .portServerManagement: return "Manage Port Server Attachment"
        case .portAllowedAddressPairManagement: return "Manage Allowed Address Pairs"
        case .subnetRouterManagement: return "Manage Subnet Router Attachment"
        case .flavorSelection: return "Select Server Flavor"
        case .swiftBackgroundOperations: return "Operations"
        case .swiftBackgroundOperationDetail: return "Operation Details"
        case .performanceMetrics: return "Performance Metrics"
        }
    }

    var isDetailView: Bool {
        switch self {
        case .serverDetail, .serverConsole, .serverGroupDetail, .networkDetail,
            .securityGroupDetail, .volumeDetail, .volumeArchiveDetail, .imageDetail, .flavorDetail,
            .subnetDetail, .portDetail, .routerDetail, .floatingIPDetail,
            .healthDashboardServiceDetail, .serverCreate, .serverGroupCreate, .networkCreate,
            .securityGroupCreate, .securityGroupRuleManagement, .subnetCreate, .volumeCreate,
            .portCreate, .routerCreate, .floatingIPCreate, .keyPairDetail, .keyPairCreate,
            .serverSecurityGroups, .serverNetworkInterfaces, .serverGroupManagement,
            .volumeManagement, .floatingIPServerSelect, .serverSnapshotManagement, .serverResize,
            .volumeSnapshotManagement, .volumeBackupManagement, .networkServerAttachment,
            .securityGroupServerAttachment, .securityGroupServerManagement,
            .networkServerManagement, .volumeServerManagement, .floatingIPServerManagement,
            .floatingIPPortManagement, .portServerManagement, .portAllowedAddressPairManagement,
            .subnetRouterManagement, .barbicanSecretDetail,
            .swiftObjectDetail, .swiftBackgroundOperationDetail, .barbicanSecretCreate,
            .swiftContainerCreate, .swiftObjectUpload, .swiftContainerDownload,
            .swiftObjectDownload, .swiftDirectoryDownload, .swiftContainerMetadata,
            .swiftObjectMetadata, .swiftDirectoryMetadata, .performanceMetrics,
            .welcome, .tutorial, .shortcuts, .examples:
            return true
        default:
            return false
        }
    }

    var supportsMultiSelect: Bool {
        switch self {
        // Main resource list views
        case .servers, .volumes, .networks, .subnets, .routers, .ports, .floatingIPs,
            .securityGroups, .serverGroups, .keyPairs, .images:
            return true
        // Service list views (barbicanSecrets and volumeArchives support multi-select)
        case .barbican, .barbicanSecrets, .swift,
            .swiftContainerDetail, .volumeArchives:
            return true
        // Note: flavors excluded - read-only, managed by cloud admin
        default:
            return false
        }
    }

    var parentView: ViewMode {
        switch self {
        case .serverDetail: return .servers
        case .serverConsole: return .servers
        case .serverGroupDetail: return .serverGroups
        case .networkDetail: return .networks
        case .securityGroupDetail: return .securityGroups
        case .volumeDetail: return .volumes
        case .volumeArchiveDetail: return .volumeArchives
        case .imageDetail: return .images
        case .flavorDetail: return .flavors
        case .subnetDetail: return .subnets
        case .portDetail: return .ports
        case .routerDetail: return .routers
        case .floatingIPDetail: return .floatingIPs
        case .serverCreate: return .servers
        case .serverGroupCreate: return .serverGroups
        case .networkCreate: return .networks
        case .securityGroupCreate: return .securityGroups
        case .subnetCreate: return .subnets
        case .volumeCreate: return .volumes
        case .portCreate: return .ports
        case .routerCreate: return .routers
        case .floatingIPCreate: return .floatingIPs
        case .floatingIPServerSelect: return .floatingIPs
        case .keyPairDetail: return .keyPairs
        case .keyPairCreate: return .keyPairs
        case .serverSecurityGroups: return .servers
        case .serverNetworkInterfaces: return .servers
        case .serverGroupManagement: return .serverGroups
        case .volumeManagement: return .volumes
        case .serverSnapshotManagement: return .servers
        case .serverResize: return .servers
        case .volumeSnapshotManagement: return .volumes
        case .volumeBackupManagement: return .volumes
        case .healthDashboardServiceDetail: return .healthDashboard
        case .barbicanSecrets: return .barbican
        case .barbicanSecretDetail: return .barbicanSecrets
        case .barbicanSecretCreate: return .barbicanSecrets
        case .swiftContainerDetail: return .swift
        case .swiftObjectDetail: return .swiftContainerDetail
        case .swiftBackgroundOperationDetail: return .swiftBackgroundOperations
        case .swiftContainerCreate: return .swift
        case .swiftObjectUpload: return .swift
        case .swiftContainerDownload: return .swift
        case .swiftObjectDownload: return .swiftContainerDetail
        case .swiftDirectoryDownload: return .swiftContainerDetail
        case .swiftContainerMetadata: return .swift
        case .swiftObjectMetadata: return .swiftContainerDetail
        case .swiftDirectoryMetadata: return .swiftContainerDetail
        case .swiftContainerWebAccess: return .swift
        case .networkServerAttachment: return .networks
        case .securityGroupServerAttachment: return .securityGroups
        case .securityGroupServerManagement: return .securityGroups
        case .networkServerManagement: return .networks
        case .volumeServerManagement: return .volumes
        case .floatingIPServerManagement: return .floatingIPs
        case .floatingIPPortManagement: return .floatingIPs
        case .portServerManagement: return .ports
        case .portAllowedAddressPairManagement: return .ports
        case .subnetRouterManagement: return .subnets
        case .flavorSelection: return .serverCreate
        case .performanceMetrics: return .swiftBackgroundOperations
        default: return self
        }
    }
}

@MainActor
struct MainPanelView {

    static func draw(screen: OpaquePointer?, tui: TUI, screenCols: Int32, screenRows: Int32) async {
        let sidebarWidth = LayoutUtilities.shared.calculateSidebarWidth(screenCols: screenCols)
        // When sidebar is hidden (width = 0), start from left edge
        let mainStartCol: Int32 = sidebarWidth > 0 ? sidebarWidth + 1 : 0
        let mainWidth = max(10, screenCols - mainStartCol - 1)  // Minimum width check
        let mainStartRow: Int32 = 2
        // Reserve rows at bottom: separator (1) + input bar (1) + status bar (1) when input shown
        // Or: separator (1) + status bar (1) when input hidden
        let bottomReserved: Int32 = tui.showUnifiedInput ? 3 : 2
        let mainHeight = max(5, screenRows - mainStartRow - bottomReserved)  // Minimum height check

        // Only draw if we have sufficient space
        guard mainWidth > 10 && mainHeight > 5 else { return }

        // Fill main panel background to match header and sidebar styling
        let surface = SwiftNCurses.surface(from: screen)
        let mainBounds = Rect(
            x: mainStartCol, y: mainStartRow, width: mainWidth, height: mainHeight)
        await surface.fill(rect: mainBounds, character: " ", style: .secondary)

        await renderCurrentView(
            screen: screen, tui: tui, mainStartRow: mainStartRow, mainStartCol: mainStartCol,
            mainWidth: mainWidth, mainHeight: mainHeight)
    }

    /// Renders the current view using the module system's ViewRegistry
    ///
    /// Views registered in the ViewRegistry are rendered via their module handlers.
    /// Views not yet migrated to modules use the legacy switch statement fallback.
    ///
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - tui: The TUI instance containing application state
    ///   - mainStartRow: Starting row position for the main panel
    ///   - mainStartCol: Starting column position for the main panel
    ///   - mainWidth: Width of the main panel in characters
    ///   - mainHeight: Height of the main panel in characters
    private static func renderCurrentView(
        screen: OpaquePointer?, tui: TUI, mainStartRow: Int32, mainStartCol: Int32,
        mainWidth: Int32, mainHeight: Int32
    ) async {
        // PRIORITY 1: Check if a module handles this view via ViewRegistry
        if FeatureFlags.useModuleSystem, let registration = ViewRegistry.shared.handler(for: tui.viewCoordinator.currentView) {
            Logger.shared.logDebug("Rendering \(tui.viewCoordinator.currentView) via module: \(registration.title)")
            await registration.renderHandler(screen, mainStartRow, mainStartCol, mainWidth, mainHeight)
            return
        }

        // PRIORITY 2: Check ViewRegistry metadata for dynamic view routing
        let viewId = tui.viewCoordinator.currentView.viewIdentifierId
        if let metadata = ViewRegistry.shared.metadata(forId: viewId) {
            Logger.shared.logDebug("Rendering \(viewId) via metadata: \(metadata.title)")
            await metadata.renderHandler(screen, mainStartRow, mainStartCol, mainWidth, mainHeight)
            return
        }

        // No handler found - log error and display message
        Logger.shared.logError("No render handler found for view: \(viewId)")
        let surface = SwiftNCurses.surface(from: screen)
        let bounds = Rect(x: mainStartCol, y: mainStartRow, width: mainWidth, height: mainHeight)
        await SwiftNCurses.render(
            Text("View not registered: \(viewId)").error(),
            on: surface,
            in: bounds
        )
    }

}
