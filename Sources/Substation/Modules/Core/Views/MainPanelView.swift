import Foundation
import OSClient
import SwiftNCurses

import struct OSClient.Port

enum ViewMode: CaseIterable {
    case loading, dashboard, advancedSearch, healthDashboard, servers, serverGroups, securityGroups,
        volumes, volumeArchives, images, flavors, subnets, ports, routers, floatingIPs, networks,
        barbican, barbicanSecrets, octavia, swift, swiftBackgroundOperations,
        performanceMetrics, serverDetail, serverConsole, serverGroupDetail, networkDetail,
        securityGroupDetail, volumeDetail, volumeArchiveDetail, imageDetail, flavorDetail,
        subnetDetail, portDetail, routerDetail, floatingIPDetail, healthDashboardServiceDetail,
        barbicanSecretDetail, octaviaLoadBalancerDetail,
        swiftContainerDetail, swiftObjectDetail, swiftBackgroundOperationDetail, serverCreate,
        serverGroupCreate, networkCreate, securityGroupCreate, securityGroupRuleManagement,
        subnetCreate, volumeCreate, portCreate, routerCreate, floatingIPCreate, keyPairs,
        keyPairDetail, keyPairCreate, help, about, welcome, tutorial, shortcuts, examples, serverSecurityGroups, serverNetworkInterfaces,
        serverGroupManagement, volumeManagement, floatingIPServerSelect, serverSnapshotManagement,
        serverResize, volumeSnapshotManagement, volumeBackupManagement, networkServerAttachment,
        securityGroupServerAttachment, securityGroupServerManagement, networkServerManagement,
        volumeServerManagement, floatingIPServerManagement, floatingIPPortManagement,
        portServerManagement, portAllowedAddressPairManagement, subnetRouterManagement,
        flavorSelection, barbicanSecretCreate, octaviaLoadBalancerCreate,
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
        case .octavia: return "Load Balancers"
        case .swift: return "Object Storage"
        case .barbicanSecretDetail: return "Secret Details"
        case .octaviaLoadBalancerDetail: return "Load Balancer Details"
        case .swiftContainerDetail: return "Container Objects"
        case .swiftObjectDetail: return "Object Details"
        case .barbicanSecretCreate: return "Create Secret"
        case .octaviaLoadBalancerCreate: return "Create Load Balancer"
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
            .subnetRouterManagement, .barbicanSecretDetail, .octaviaLoadBalancerDetail,
            .swiftObjectDetail, .swiftBackgroundOperationDetail, .barbicanSecretCreate, .octaviaLoadBalancerCreate,
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
        case .barbican, .barbicanSecrets, .octavia, .swift,
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
        case .octaviaLoadBalancerDetail: return .octavia
        case .octaviaLoadBalancerCreate: return .octavia
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

        // PRIORITY 2: Fall back to legacy switch statement for views not yet in modules
        Logger.shared.logDebug("Rendering \(tui.viewCoordinator.currentView) via legacy switch statement")
        switch tui.viewCoordinator.currentView {
        case .loading:
            await LoadingView.drawLoadingScreen(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, progressStep: tui.loadingProgress,
                statusMessage: tui.loadingMessage)
        case .dashboard:
            await DashboardView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, resourceCounts: tui.resourceCounts,
                cachedServers: tui.cacheManager.cachedServers, cachedNetworks: tui.cacheManager.cachedNetworks,
                cachedVolumes: tui.cacheManager.cachedVolumes, cachedPorts: tui.cacheManager.cachedPorts,
                cachedRouters: tui.cacheManager.cachedRouters, cachedComputeLimits: tui.cacheManager.cachedComputeLimits,
                cachedNetworkQuotas: tui.cacheManager.cachedNetworkQuotas,
                cachedVolumeQuotas: tui.cacheManager.cachedVolumeQuotas,
                quotaScrollOffset: tui.viewCoordinator.quotaScrollOffset, tui: tui)
        case .healthDashboard:
            let telemetryActor = await tui.getTelemetryActor()
            await HealthDashboardView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, telemetryActor: telemetryActor,
                navigationState: tui.viewCoordinator.healthDashboardNavState, dataManager: tui.dataManager,
                performanceMonitor: tui.renderCoordinator.performanceMonitor)
        case .healthDashboardServiceDetail:
            if let service = tui.viewCoordinator.selectedResource as? HealthDashboardService {
                await HealthDashboardView.drawServiceDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, service: service,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset)
            }
        case .help:
            let contextView = tui.viewCoordinator.previousView != .help ? tui.viewCoordinator.previousView : .dashboard
            await MiscViews.drawHelp(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, scrollOffset: tui.viewCoordinator.helpScrollOffset, currentView: contextView)
        case .about:
            await MiscViews.drawAbout(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, scrollOffset: tui.viewCoordinator.helpScrollOffset)
        case .welcome:
            let sections = WelcomeScreen.shared.getWelcomeSections()
            let detailView = DetailView(
                title: "Welcome to Substation",
                sections: sections,
                helpText: "Press ESC to return",
                scrollOffset: tui.viewCoordinator.detailScrollOffset
            )
            await detailView.draw(
                screen: screen,
                startRow: mainStartRow,
                startCol: mainStartCol,
                width: mainWidth,
                height: mainHeight
            )
        case .tutorial:
            let sections = WelcomeScreen.shared.getTutorialSections()
            let detailView = DetailView(
                title: "Interactive Tutorial",
                sections: sections,
                helpText: "Press ESC to return",
                scrollOffset: tui.viewCoordinator.detailScrollOffset
            )
            await detailView.draw(
                screen: screen,
                startRow: mainStartRow,
                startCol: mainStartCol,
                width: mainWidth,
                height: mainHeight
            )
        case .shortcuts:
            let sections = WelcomeScreen.shared.getShortcutsSections()
            let detailView = DetailView(
                title: "Command Shortcuts Reference",
                sections: sections,
                helpText: "Press ESC to return",
                scrollOffset: tui.viewCoordinator.detailScrollOffset
            )
            await detailView.draw(
                screen: screen,
                startRow: mainStartRow,
                startCol: mainStartCol,
                width: mainWidth,
                height: mainHeight
            )
        case .examples:
            let sections = WelcomeScreen.shared.getExamplesSections()
            let detailView = DetailView(
                title: "Command Workflow Examples",
                sections: sections,
                helpText: "Press ESC to return",
                scrollOffset: tui.viewCoordinator.detailScrollOffset
            )
            await detailView.draw(
                screen: screen,
                startRow: mainStartRow,
                startCol: mainStartCol,
                width: mainWidth,
                height: mainHeight
            )
        case .advancedSearch:
            await AdvancedSearchView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, tui: tui)
        case .octavia:
            await OctaviaViews.drawOctaviaLoadBalancerList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, loadBalancers: tui.cacheManager.cachedLoadBalancers,
                searchQuery: tui.searchQuery ?? "", scrollOffset: tui.viewCoordinator.scrollOffset,
                selectedIndex: tui.viewCoordinator.selectedIndex, filterCache: tui.resourceNameCache)
        case .octaviaLoadBalancerDetail:
            if let lb = tui.viewCoordinator.selectedResource as? LoadBalancer {
                await OctaviaViews.drawOctaviaLoadBalancerDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, loadBalancer: lb)
            }
        case .octaviaLoadBalancerCreate:
            await OctaviaViews.drawOctaviaLoadBalancerCreate(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight)
        case .volumeArchives:
            await VolumeArchiveViews.drawArchiveList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedVolumeSnapshots: tui.cacheManager.cachedVolumeSnapshots,
                cachedVolumeBackups: tui.cacheManager.cachedVolumeBackups, cachedImages: tui.cacheManager.cachedImages,
                searchQuery: tui.searchQuery, scrollOffset: tui.viewCoordinator.scrollOffset,
                selectedIndex: tui.viewCoordinator.selectedIndex, multiSelectMode: tui.selectionManager.multiSelectMode,
                selectedItems: tui.selectionManager.multiSelectedResourceIDs)
        case .volumeArchiveDetail:
            if let snapshot = tui.viewCoordinator.selectedResource as? VolumeSnapshot {
                await VolumeArchiveViews.drawVolumeSnapshotDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, snapshot: snapshot,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset)
            } else if let backup = tui.viewCoordinator.selectedResource as? VolumeBackup {
                await VolumeArchiveViews.drawVolumeBackupDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, backup: backup,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset)
            }
        case .volumeManagement:
            await VolumeManagementView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.volumeManagementForm,
                resourceNameCache: tui.resourceNameCache)
        case .floatingIPServerSelect:
            if let floatingIP = tui.viewCoordinator.selectedResource as? FloatingIP {
                await FloatingIPViews.drawServerSelectionView(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, floatingIP: floatingIP,
                    cachedServers: tui.cacheManager.cachedServers, cachedPorts: tui.cacheManager.cachedPorts,
                    scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex)
            }
        case .networkServerAttachment:
            await NetworkServerAttachmentView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, servers: tui.cacheManager.cachedServers,
                selectedServers: tui.selectionManager.selectedServers, searchQuery: tui.searchQuery,
                scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex)
        case .securityGroupServerAttachment:
            await SecurityGroupServerAttachmentView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, servers: tui.cacheManager.cachedServers,
                selectedServers: tui.selectionManager.selectedServers, searchQuery: tui.searchQuery,
                scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex)
        case .securityGroupServerManagement:
            if let securityGroup = tui.viewCoordinator.selectedResource as? SecurityGroup {
                await SecurityGroupServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, securityGroup: securityGroup,
                    servers: tui.cacheManager.cachedServers, attachedServerIds: tui.selectionManager.attachedServerIds,
                    selectedServers: tui.selectionManager.selectedServers, searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex,
                    mode: tui.selectionManager.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .networkServerManagement:
            if let network = tui.viewCoordinator.selectedResource as? Network {
                await NetworkServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, network: network,
                    servers: tui.cacheManager.cachedServers, attachedServerIds: tui.selectionManager.attachedServerIds,
                    selectedServers: tui.selectionManager.selectedServers, searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex,
                    mode: tui.selectionManager.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .volumeServerManagement:
            if let volume = tui.viewCoordinator.selectedResource as? Volume {
                await VolumeServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, volume: volume,
                    servers: tui.cacheManager.cachedServers, attachedServerIds: tui.selectionManager.attachedServerIds,
                    selectedServers: tui.selectionManager.selectedServers, searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex,
                    mode: tui.selectionManager.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .floatingIPServerManagement:
            if let floatingIP = tui.viewCoordinator.selectedResource as? FloatingIP {
                await FloatingIPServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, floatingIP: floatingIP,
                    servers: tui.cacheManager.cachedServers, attachedServerId: tui.selectionManager.attachedServerId,
                    selectedServerId: tui.selectionManager.selectedServerId, searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex,
                    mode: tui.selectionManager.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .floatingIPPortManagement:
            if let floatingIP = tui.viewCoordinator.selectedResource as? FloatingIP {
                await FloatingIPPortManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, floatingIP: floatingIP,
                    ports: tui.cacheManager.cachedPorts, attachedPortId: tui.selectionManager.attachedPortId,
                    selectedPortId: tui.selectionManager.selectedPortId, searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex,
                    mode: tui.selectionManager.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .portServerManagement:
            if let port = tui.viewCoordinator.selectedResource as? Port {
                await PortServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, port: port, servers: tui.cacheManager.cachedServers,
                    attachedServerId: tui.selectionManager.attachedServerId, selectedServerId: tui.selectionManager.selectedServerId,
                    searchQuery: tui.searchQuery, scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex, mode: tui.selectionManager.attachmentMode,
                    resourceResolver: tui.resourceResolver)
            }
        case .portAllowedAddressPairManagement:
            if let form = tui.allowedAddressPairForm {
                await AllowedAddressPairManagementView.drawAllowedAddressPairManagement(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, form: form,
                    resourceNameCache: tui.resourceNameCache)
            }
        case .subnetRouterManagement:
            if let subnet = tui.viewCoordinator.selectedResource as? Subnet {
                await SubnetRouterManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, subnet: subnet,
                    routers: tui.cacheManager.cachedRouters, attachedRouterIds: tui.selectionManager.attachedRouterIds,
                    selectedRouterId: tui.selectionManager.selectedRouterId, searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset, selectedIndex: tui.viewCoordinator.selectedIndex,
                    mode: tui.selectionManager.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .flavorSelection:
            await FlavorSelectionView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, flavors: tui.cacheManager.cachedFlavors,
                workloadType: tui.serverCreateForm.workloadType,
                flavorRecommendations: tui.serverCreateForm.flavorRecommendations,
                selectedFlavorId: tui.serverCreateForm.selectedFlavorID,
                selectedRecommendationIndex: tui.serverCreateForm.selectedRecommendationIndex,
                selectedIndex: tui.viewCoordinator.selectedIndex, mode: tui.serverCreateForm.flavorSelectionMode,
                scrollOffset: tui.viewCoordinator.scrollOffset, searchQuery: tui.searchQuery,
                selectedCategoryIndex: tui.serverCreateForm.selectedCategoryIndex)
        case .performanceMetrics:
            let operations = tui.swiftBackgroundOps.getAllOperations()
            let metricsService = PerformanceMetrics()
            let summary = metricsService.calculate(from: operations)
            await PerformanceMetricsView.draw(
                screen: screen,
                startRow: mainStartRow,
                startCol: mainStartCol,
                width: mainWidth,
                height: mainHeight,
                summary: summary,
                scrollOffset: tui.viewCoordinator.scrollOffset
            )

        default:
            // All other views are handled by modules via ViewRegistry
            break
        }
    }

}
