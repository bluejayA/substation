import Foundation
import OSClient
import SwiftTUI

import struct OSClient.Port

enum ViewMode: CaseIterable {
    case loading, dashboard, advancedSearch, healthDashboard, servers, serverGroups, securityGroups,
        volumes, volumeArchives, images, flavors, subnets, ports, routers, floatingIPs, networks,
        barbican, barbicanSecrets, barbicanContainers, octavia, swift, swiftBackgroundOperations,
        performanceMetrics, serverDetail, serverConsole, serverGroupDetail, networkDetail,
        securityGroupDetail, volumeDetail, volumeArchiveDetail, imageDetail, flavorDetail,
        subnetDetail, portDetail, routerDetail, floatingIPDetail, healthDashboardServiceDetail,
        barbicanSecretDetail, barbicanContainerDetail, octaviaLoadBalancerDetail,
        swiftContainerDetail, swiftObjectDetail, swiftBackgroundOperationDetail, serverCreate,
        serverGroupCreate, networkCreate, securityGroupCreate, securityGroupRuleManagement,
        subnetCreate, volumeCreate, portCreate, routerCreate, floatingIPCreate, keyPairs,
        keyPairDetail, keyPairCreate, help, about, welcome, tutorial, shortcuts, examples, serverSecurityGroups, serverNetworkInterfaces,
        serverGroupManagement, volumeManagement, floatingIPServerSelect, serverSnapshotManagement,
        serverResize, volumeSnapshotManagement, volumeBackupManagement, networkServerAttachment,
        securityGroupServerAttachment, securityGroupServerManagement, networkServerManagement,
        volumeServerManagement, floatingIPServerManagement, floatingIPPortManagement,
        portServerManagement, portAllowedAddressPairManagement, subnetRouterManagement,
        flavorSelection, barbicanSecretCreate, barbicanContainerCreate, octaviaLoadBalancerCreate,
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
        case .barbicanContainers: return "Secret Containers"
        case .octavia: return "Load Balancers"
        case .swift: return "Object Storage"
        case .barbicanSecretDetail: return "Secret Details"
        case .barbicanContainerDetail: return "Container Details"
        case .octaviaLoadBalancerDetail: return "Load Balancer Details"
        case .swiftContainerDetail: return "Container Objects"
        case .swiftObjectDetail: return "Object Details"
        case .barbicanSecretCreate: return "Create Secret"
        case .barbicanContainerCreate: return "Create Container"
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
            .subnetRouterManagement, .barbicanSecretDetail, .barbicanContainerDetail, .octaviaLoadBalancerDetail,
            .swiftObjectDetail, .swiftBackgroundOperationDetail, .barbicanSecretCreate, .barbicanContainerCreate, .octaviaLoadBalancerCreate,
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
        case .barbican, .barbicanSecrets, .barbicanContainers, .octavia, .swift,
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
        case .barbicanContainers: return .barbican
        case .barbicanSecretDetail: return .barbicanSecrets
        case .barbicanContainerDetail: return .barbicanContainers
        case .barbicanSecretCreate: return .barbicanSecrets
        case .barbicanContainerCreate: return .barbicanContainers
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
        let surface = SwiftTUI.surface(from: screen)
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
        switch tui.currentView {
        case .loading:
            await LoadingView.drawLoadingScreen(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, progressStep: tui.loadingProgress,
                statusMessage: tui.loadingMessage)
        case .dashboard:
            await DashboardView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, resourceCounts: tui.resourceCounts,
                cachedServers: tui.cachedServers, cachedNetworks: tui.cachedNetworks,
                cachedVolumes: tui.cachedVolumes, cachedPorts: tui.cachedPorts,
                cachedRouters: tui.cachedRouters, cachedComputeLimits: tui.cachedComputeLimits,
                cachedNetworkQuotas: tui.cachedNetworkQuotas,
                cachedVolumeQuotas: tui.cachedVolumeQuotas,
                quotaScrollOffset: tui.quotaScrollOffset, tui: tui)
        case .healthDashboard:
            let telemetryActor = await tui.getTelemetryActor()
            await HealthDashboardView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, telemetryActor: telemetryActor,
                navigationState: tui.healthDashboardNavState, dataManager: tui.dataManager,
                performanceMonitor: tui.performanceMonitor)
        case .servers:
            await ServerViews.drawDetailedServerList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedServers: tui.cachedServers, searchQuery: tui.searchQuery,
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                cachedFlavors: tui.cachedFlavors, cachedImages: tui.cachedImages,
                multiSelectMode: tui.multiSelectMode, selectedItems: tui.multiSelectedResourceIDs)
        case .serverGroups:
            await ServerGroupViews.drawDetailedServerGroupList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedServerGroups: tui.cachedServerGroups,
                searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, multiSelectMode: tui.multiSelectMode,
                selectedItems: tui.multiSelectedResourceIDs)
        case .networks:
            await NetworkViews.drawDetailedNetworkList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedNetworks: tui.cachedNetworks,
                searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, multiSelectMode: tui.multiSelectMode,
                selectedItems: tui.multiSelectedResourceIDs)
        case .securityGroups:
            await SecurityGroupViews.drawDetailedSecurityGroupList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedSecurityGroups: tui.cachedSecurityGroups,
                searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, multiSelectMode: tui.multiSelectMode,
                selectedItems: tui.multiSelectedResourceIDs)
        case .volumes:
            await VolumeViews.drawDetailedVolumeList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedVolumes: tui.cachedVolumes, searchQuery: tui.searchQuery,
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                multiSelectMode: tui.multiSelectMode, selectedItems: tui.multiSelectedResourceIDs)
        case .volumeArchives:
            await VolumeArchiveViews.drawArchiveList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedVolumeSnapshots: tui.cachedVolumeSnapshots,
                cachedVolumeBackups: tui.cachedVolumeBackups, cachedImages: tui.cachedImages,
                searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, multiSelectMode: tui.multiSelectMode,
                selectedItems: tui.multiSelectedResourceIDs)
        case .images:
            await ImageViews.drawDetailedImageList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedImages: tui.cachedImages, searchQuery: tui.searchQuery,
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                multiSelectMode: tui.multiSelectMode, selectedItems: tui.multiSelectedResourceIDs)
        case .flavors:
            await FlavorViews.drawDetailedFlavorList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedFlavors: tui.cachedFlavors, searchQuery: tui.searchQuery,
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .keyPairs:
            await KeyPairViews.drawDetailedKeyPairList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedKeyPairs: tui.cachedKeyPairs,
                searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, multiSelectMode: tui.multiSelectMode,
                selectedItems: tui.multiSelectedResourceIDs)
        case .keyPairDetail:
            if let keyPair = tui.selectedResource as? KeyPair {
                await KeyPairViews.drawKeyPairDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, keyPair: keyPair,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .serverDetail:
            if let server = tui.selectedResource as? Server {
                await ServerViews.drawServerDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, server: server,
                    cachedVolumes: tui.cachedVolumes, cachedFlavors: tui.cachedFlavors,
                    cachedImages: tui.cachedImages, scrollOffset: tui.detailScrollOffset)
            }
        case .serverConsole:
            if let console = tui.selectedResource as? RemoteConsole {
                let serverName = tui.previousSelectedResourceName ?? "Unknown Server"
                await ServerViews.drawServerConsole(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, console: console, serverName: serverName,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .serverGroupDetail:
            if let serverGroup = tui.selectedResource as? ServerGroup {
                await ServerGroupViews.drawServerGroupDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, serverGroup: serverGroup,
                    cachedServers: tui.cachedServers, scrollOffset: tui.detailScrollOffset)
            }
        case .networkDetail:
            if let network = tui.selectedResource as? Network {
                await NetworkViews.drawNetworkDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, network: network,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .securityGroupDetail:
            if let securityGroup = tui.selectedResource as? SecurityGroup {
                await SecurityGroupViews.drawSecurityGroupDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, securityGroup: securityGroup,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .volumeDetail:
            if let volume = tui.selectedResource as? Volume {
                await VolumeViews.drawVolumeDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, volume: volume,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .volumeArchiveDetail:
            if let snapshot = tui.selectedResource as? VolumeSnapshot {
                await VolumeArchiveViews.drawVolumeSnapshotDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, snapshot: snapshot,
                    scrollOffset: tui.detailScrollOffset)
            } else if let backup = tui.selectedResource as? VolumeBackup {
                await VolumeArchiveViews.drawVolumeBackupDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, backup: backup,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .imageDetail:
            if let image = tui.selectedResource as? Image {
                await ImageViews.drawImageDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, image: image,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .flavorDetail:
            if let flavor = tui.selectedResource as? Flavor {
                await FlavorViews.drawFlavorDetailGoldStandard(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, flavor: flavor,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .healthDashboardServiceDetail:
            if let service = tui.selectedResource as? HealthDashboardService {
                await HealthDashboardView.drawServiceDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, service: service,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .serverCreate:
            await ServerCreateView.drawServerCreateForm(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.serverCreateForm, formState: tui.serverCreateFormState
            )
        case .networkCreate:
            await NetworkViews.drawNetworkCreate(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, networkCreateForm: tui.networkCreateForm,
                networkCreateFormState: tui.networkCreateFormState)
        case .securityGroupCreate:
            await SecurityGroupViews.drawSecurityGroupCreateForm(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.securityGroupCreateForm,
                formState: tui.securityGroupCreateFormState)
        case .securityGroupRuleManagement:
            if let form = tui.securityGroupRuleManagementForm {
                await SecurityGroupViews.drawSecurityGroupRuleManagement(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, form: form,
                    cachedSecurityGroups: tui.cachedSecurityGroups)
            }
        case .subnetCreate:
            await SubnetViews.drawSubnetCreate(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, subnetCreateForm: tui.subnetCreateForm,
                cachedNetworks: tui.cachedNetworks, formState: tui.subnetCreateFormState)
        case .serverSecurityGroups:
            await SecurityGroupViews.drawServerSecurityGroupManagement(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.securityGroupForm)
        case .serverResize:
            await ServerViews.drawServerResizeManagement(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, serverResizeForm: tui.serverResizeForm)
        case .serverSnapshotManagement:
            await SnapshotManagementView.drawServerSnapshotManagement(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.snapshotManagementForm,
                formBuilderState: tui.snapshotManagementFormState)
        case .volumeSnapshotManagement:
            await VolumeSnapshotManagementView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.volumeSnapshotManagementForm,
                formBuilderState: tui.volumeSnapshotManagementFormState)
        case .volumeBackupManagement:
            await VolumeBackupManagementView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.volumeBackupManagementForm,
                formBuilderState: tui.volumeBackupManagementFormState)
        case .serverNetworkInterfaces:
            await NetworkInterfaceManagementView.drawServerNetworkInterfaceManagement(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.networkInterfaceForm,
                resourceNameCache: tui.resourceNameCache, resourceResolver: tui.resourceResolver)
        case .volumeManagement:
            await VolumeManagementView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.volumeManagementForm,
                resourceNameCache: tui.resourceNameCache)
        case .keyPairCreate:
            await KeyPairViews.drawKeyPairCreate(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, keyPairCreateForm: tui.keyPairCreateForm,
                keyPairCreateFormState: tui.keyPairCreateFormState)
        case .volumeCreate:
            await VolumeViews.drawVolumeCreate(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.volumeCreateFormState)

        case .subnets:
            await SubnetViews.drawDetailedSubnetList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedSubnets: tui.cachedSubnets, searchQuery: tui.searchQuery,
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                multiSelectMode: tui.multiSelectMode, selectedItems: tui.multiSelectedResourceIDs)
        case .subnetDetail:
            if let subnet = tui.selectedResource as? Subnet {
                await SubnetViews.drawSubnetDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, subnet: subnet,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .ports:
            await PortViews.drawDetailedPortList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedPorts: tui.cachedPorts,
                cachedNetworks: tui.cachedNetworks, cachedServers: tui.cachedServers,
                searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, multiSelectMode: tui.multiSelectMode,
                selectedItems: tui.multiSelectedResourceIDs)
        case .portDetail:
            if let port = tui.selectedResource as? Port {
                await PortViews.drawPortDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, port: port,
                    cachedNetworks: tui.cachedNetworks, cachedSubnets: tui.cachedSubnets,
                    cachedSecurityGroups: tui.cachedSecurityGroups,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .portCreate:
            await PortViews.drawPortCreateForm(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, portCreateForm: tui.portCreateForm,
                portCreateFormState: tui.portCreateFormState, cachedNetworks: tui.cachedNetworks,
                cachedSecurityGroups: tui.cachedSecurityGroups,
                cachedQoSPolicies: tui.cachedQoSPolicies, selectedIndex: tui.selectedIndex)
        case .routers:
            await RouterViews.drawDetailedRouterList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedRouters: tui.cachedRouters, searchQuery: tui.searchQuery,
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                multiSelectMode: tui.multiSelectMode, selectedItems: tui.multiSelectedResourceIDs)
        case .routerDetail:
            if let selectedRouter = tui.selectedResource as? Router {
                // Find the updated router from cached routers to get latest interface data
                var routerWithInterfaces =
                    tui.cachedRouters.first { $0.id == selectedRouter.id } ?? selectedRouter

                // If the cached router has no interfaces, force fetch detailed router information
                if routerWithInterfaces.interfaces == nil
                    || routerWithInterfaces.interfaces?.isEmpty == true
                {
                    Logger.shared.logInfo(
                        "Router has no interface data, force fetching detailed info",
                        context: [
                            "routerId": selectedRouter.id,
                            "routerName": selectedRouter.name ?? "Unknown",
                        ])

                    do {
                        // Force fetch detailed router information with interfaces
                        let detailedRouter = try await tui.dataManager.getDetailedRouter(
                            id: selectedRouter.id)
                        routerWithInterfaces = detailedRouter

                        Logger.shared.logInfo(
                            "Successfully fetched detailed router",
                            context: [
                                "routerId": detailedRouter.id,
                                "routerName": detailedRouter.name ?? "Unknown",
                                "interfaceCount": detailedRouter.interfaces?.count ?? 0,
                                "interfaceSubnetIds": detailedRouter.interfaces?.compactMap {
                                    $0.subnetId
                                } ?? [],
                            ])
                    } catch {
                        Logger.shared.logError(
                            "Failed to fetch detailed router info",
                            context: [
                                "routerId": selectedRouter.id,
                                "error": "\(error)",
                            ])
                    }
                }

                // Log router interface information for debugging
                Logger.shared.logInfo(
                    "Router detail view rendering",
                    context: [
                        "selectedRouterId": selectedRouter.id,
                        "foundInCache": tui.cachedRouters.contains { $0.id == selectedRouter.id },
                        "interfaceCount": routerWithInterfaces.interfaces?.count ?? 0,
                        "interfaceSubnetIds": routerWithInterfaces.interfaces?.compactMap {
                            $0.subnetId
                        } ?? [],
                    ])

                await RouterViews.drawRouterDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, router: routerWithInterfaces,
                    cachedSubnets: tui.cachedSubnets, scrollOffset: tui.detailScrollOffset)
            }
        case .routerCreate:
            await RouterViews.drawRouterCreateForm(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, routerCreateForm: tui.routerCreateForm,
                routerCreateFormState: tui.routerCreateFormState,
                availabilityZones: tui.cachedAvailabilityZones, externalNetworks: tui.cachedNetworks
            )
        case .floatingIPs:
            // Phase 2: Set render flag to prevent background task interference
            tui.isFloatingIPViewRendering = true
            defer { tui.isFloatingIPViewRendering = false }

            await FloatingIPViews.drawDetailedFloatingIPList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, cachedFloatingIPs: tui.cachedFloatingIPs,
                searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, cachedServers: tui.cachedServers,
                cachedPorts: tui.cachedPorts, cachedNetworks: tui.cachedNetworks,
                multiSelectMode: tui.multiSelectMode, selectedItems: tui.multiSelectedResourceIDs)
        case .floatingIPDetail:
            if let floatingIP = tui.selectedResource as? FloatingIP {
                await FloatingIPViews.drawFloatingIPDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, floatingIP: floatingIP,
                    cachedServers: tui.cachedServers, cachedPorts: tui.cachedPorts,
                    cachedNetworks: tui.cachedNetworks, scrollOffset: tui.detailScrollOffset)
            }
        case .floatingIPCreate:
            let externalNetworks = tui.cachedNetworks.filter { $0.external == true }
            await FloatingIPViews.drawFloatingIPCreateForm(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, floatingIPCreateForm: tui.floatingIPCreateForm,
                floatingIPCreateFormState: tui.floatingIPCreateFormState,
                cachedNetworks: externalNetworks, cachedSubnets: tui.cachedSubnets)

        case .serverGroupCreate:
            await ServerGroupViews.drawServerGroupCreateForm(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.serverGroupCreateForm,
                formState: tui.serverGroupCreateFormState)
        case .serverGroupManagement:
            await ServerGroupViews.drawServerGroupManagement(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.serverGroupManagementForm)

        case .help:
            let contextView = tui.previousView != .help ? tui.previousView : .dashboard
            await MiscViews.drawHelp(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, scrollOffset: tui.helpScrollOffset, currentView: contextView)
        case .about:
            await MiscViews.drawAbout(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, scrollOffset: tui.helpScrollOffset)
        case .welcome:
            let sections = WelcomeScreen.shared.getWelcomeSections()
            let detailView = DetailView(
                title: "Welcome to Substation",
                sections: sections,
                helpText: "Press ESC to return",
                scrollOffset: tui.detailScrollOffset
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
                scrollOffset: tui.detailScrollOffset
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
                scrollOffset: tui.detailScrollOffset
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
                scrollOffset: tui.detailScrollOffset
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
        case .barbican, .barbicanSecrets:
            await BarbicanViews.drawBarbicanSecretList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, secrets: tui.cachedSecrets, searchQuery: tui.searchQuery ?? "",
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                filterCache: tui.resourceNameCache, multiSelectMode: tui.multiSelectMode,
                selectedItems: tui.multiSelectedResourceIDs)
        case .barbicanContainers:
            await BarbicanViews.drawBarbicanContainerList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, containers: tui.cachedBarbicanContainers,
                searchQuery: tui.searchQuery ?? "", scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, filterCache: tui.resourceNameCache)
        case .barbicanSecretDetail:
            if let secret = tui.selectedResource as? Secret {
                await BarbicanViews.drawBarbicanSecretDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, secret: secret,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .barbicanContainerDetail:
            if let container = tui.selectedResource as? BarbicanContainer {
                await BarbicanViews.drawBarbicanContainerDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, container: container)
            }
        case .barbicanSecretCreate:
            await BarbicanViews.drawBarbicanSecretCreateForm(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, form: tui.barbicanSecretCreateForm,
                formState: tui.barbicanSecretCreateFormState)
        case .barbicanContainerCreate:
            await MiscViews.drawSimpleCenteredMessage(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, message: "Create Container - Coming Soon")

        // Octavia views
        case .octavia:
            await OctaviaViews.drawOctaviaLoadBalancerList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, loadBalancers: tui.cachedLoadBalancers,
                searchQuery: tui.searchQuery ?? "", scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, filterCache: tui.resourceNameCache)
        case .octaviaLoadBalancerDetail:
            if let lb = tui.selectedResource as? LoadBalancer {
                await OctaviaViews.drawOctaviaLoadBalancerDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, loadBalancer: lb)
            }
        case .octaviaLoadBalancerCreate:
            await OctaviaViews.drawOctaviaLoadBalancerCreate(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight)

        // Swift views
        case .swift:
            await SwiftViews.drawSwiftContainerList(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, containers: tui.cachedSwiftContainers,
                searchQuery: tui.searchQuery ?? "", scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex, multiSelectMode: tui.multiSelectMode,
                selectedItems: tui.multiSelectedResourceIDs)
        case .swiftContainerDetail:
            if let objects = tui.cachedSwiftObjects,
                let containerName = tui.swiftNavState.currentContainer
            {
                let currentPath = tui.swiftNavState.currentPathString
                await SwiftViews.drawSwiftObjectList(
                    screen: screen,
                    startRow: mainStartRow,
                    startCol: mainStartCol,
                    width: mainWidth,
                    height: mainHeight,
                    objects: objects,
                    containerName: containerName,
                    currentPath: currentPath,
                    searchQuery: tui.searchQuery ?? "",
                    scrollOffset: tui.scrollOffset,
                    selectedIndex: tui.selectedIndex,
                    navState: tui.swiftNavState,
                    multiSelectMode: tui.multiSelectMode,
                    selectedItems: tui.multiSelectedResourceIDs
                )
            }
        case .swiftObjectDetail:
            if let object = tui.selectedResource as? SwiftObject {
                await SwiftViews.drawSwiftObjectDetail(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, object: object,
                    containerName: "Container", metadata: nil)
            }
        case .swiftContainerCreate:
            await SwiftViews.drawSwiftContainerCreate(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftContainerCreateFormState)
        case .swiftContainerMetadata:
            await SwiftViews.drawSwiftContainerMetadata(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftContainerMetadataFormState)
        case .swiftObjectMetadata:
            await SwiftViews.drawSwiftObjectMetadata(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftObjectMetadataFormState)
        case .swiftContainerWebAccess:
            await SwiftViews.drawSwiftContainerWebAccess(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftContainerWebAccessFormState)
        case .swiftDirectoryMetadata:
            await SwiftViews.drawSwiftDirectoryMetadata(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftDirectoryMetadataFormState)
        case .swiftObjectUpload:
            await SwiftViews.drawSwiftObjectUpload(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftObjectUploadFormState)
        case .swiftContainerDownload:
            await SwiftViews.drawSwiftContainerDownload(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftContainerDownloadFormState)
        case .swiftObjectDownload:
            await SwiftViews.drawSwiftObjectDownload(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftObjectDownloadFormState)
        case .swiftDirectoryDownload:
            await SwiftViews.drawSwiftDirectoryDownload(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, formBuilderState: tui.swiftDirectoryDownloadFormState)
        case .swiftBackgroundOperations:
            let operations = tui.swiftBackgroundOps.getAllOperations()
            await SwiftBackgroundOperationsView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, operations: operations, scrollOffset: tui.scrollOffset,
                selectedIndex: tui.selectedIndex)
        case .swiftBackgroundOperationDetail:
            if let operation = tui.selectedResource as? SwiftBackgroundOperation {
                await SwiftBackgroundOperationDetailView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, operation: operation,
                    scrollOffset: tui.detailScrollOffset)
            }
        case .networkServerAttachment:
            await NetworkServerAttachmentView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, servers: tui.cachedServers,
                selectedServers: tui.selectedServers, searchQuery: tui.searchQuery,
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .securityGroupServerAttachment:
            await SecurityGroupServerAttachmentView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, servers: tui.cachedServers,
                selectedServers: tui.selectedServers, searchQuery: tui.searchQuery,
                scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .securityGroupServerManagement:
            if let securityGroup = tui.selectedResource as? SecurityGroup {
                await SecurityGroupServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, securityGroup: securityGroup,
                    servers: tui.cachedServers, attachedServerIds: tui.attachedServerIds,
                    selectedServers: tui.selectedServers, searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                    mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .networkServerManagement:
            if let network = tui.selectedResource as? Network {
                await NetworkServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, network: network,
                    servers: tui.cachedServers, attachedServerIds: tui.attachedServerIds,
                    selectedServers: tui.selectedServers, searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                    mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .volumeServerManagement:
            if let volume = tui.selectedResource as? Volume {
                await VolumeServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, volume: volume,
                    servers: tui.cachedServers, attachedServerIds: tui.attachedServerIds,
                    selectedServers: tui.selectedServers, searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                    mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .floatingIPServerManagement:
            if let floatingIP = tui.selectedResource as? FloatingIP {
                await FloatingIPServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, floatingIP: floatingIP,
                    servers: tui.cachedServers, attachedServerId: tui.attachedServerId,
                    selectedServerId: tui.selectedServerId, searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                    mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .floatingIPPortManagement:
            if let floatingIP = tui.selectedResource as? FloatingIP {
                await FloatingIPPortManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, floatingIP: floatingIP,
                    ports: tui.cachedPorts, attachedPortId: tui.attachedPortId,
                    selectedPortId: tui.selectedPortId, searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                    mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .floatingIPServerSelect:
            if let floatingIP = tui.selectedResource as? FloatingIP {
                await FloatingIPViews.drawServerSelectionView(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, floatingIP: floatingIP,
                    cachedServers: tui.cachedServers, cachedPorts: tui.cachedPorts,
                    scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
            }
        case .portServerManagement:
            if let port = tui.selectedResource as? Port {
                await PortServerManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, port: port, servers: tui.cachedServers,
                    attachedServerId: tui.attachedServerId, selectedServerId: tui.selectedServerId,
                    searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset,
                    selectedIndex: tui.selectedIndex, mode: tui.attachmentMode,
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
            if let subnet = tui.selectedResource as? Subnet {
                await SubnetRouterManagementView.draw(
                    screen: screen, startRow: mainStartRow, startCol: mainStartCol,
                    width: mainWidth, height: mainHeight, subnet: subnet,
                    routers: tui.cachedRouters, attachedRouterIds: tui.attachedRouterIds,
                    selectedRouterId: tui.selectedRouterId, searchQuery: tui.searchQuery,
                    scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex,
                    mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .flavorSelection:
            await FlavorSelectionView.draw(
                screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth,
                height: mainHeight, flavors: tui.cachedFlavors,
                workloadType: tui.serverCreateForm.workloadType,
                flavorRecommendations: tui.serverCreateForm.flavorRecommendations,
                selectedFlavorId: tui.serverCreateForm.selectedFlavorID,
                selectedRecommendationIndex: tui.serverCreateForm.selectedRecommendationIndex,
                selectedIndex: tui.selectedIndex, mode: tui.serverCreateForm.flavorSelectionMode,
                scrollOffset: tui.scrollOffset, searchQuery: tui.searchQuery,
                selectedCategoryIndex: tui.serverCreateForm.selectedCategoryIndex)
        case .performanceMetrics:
            // Get operations from background operations manager
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
                scrollOffset: tui.scrollOffset
            )
        @unknown default:
            break
        }
    }

}
