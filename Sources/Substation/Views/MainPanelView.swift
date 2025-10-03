import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

enum ViewMode: CaseIterable {
    case loading, dashboard, servers, serverGroups, networks, securityGroups, volumes, volumeArchives, images, flavors, topology, advancedSearch, healthDashboard
    case subnets, ports, routers, floatingIPs
    // OpenStack Services
    case barbican, barbicanSecrets, barbicanContainers, octavia, swift
    case serverDetail, serverGroupDetail, networkDetail, securityGroupDetail, volumeDetail, volumeArchiveDetail, imageDetail, flavorDetail, subnetDetail, portDetail, routerDetail, floatingIPDetail, healthDashboardServiceDetail
    // OpenStack Services Details
    case barbicanSecretDetail, barbicanContainerDetail, octaviaLoadBalancerDetail, swiftContainerDetail, swiftObjectDetail
    case serverCreate, serverGroupCreate, networkCreate, securityGroupCreate, securityGroupRuleManagement, subnetCreate, volumeCreate, portCreate, routerCreate, floatingIPCreate, keyPairs, keyPairDetail, keyPairCreate, help, about, serverSecurityGroups, serverNetworkInterfaces, serverGroupManagement, volumeManagement, floatingIPServerSelect, serverSnapshotManagement, serverResize, volumeSnapshotManagement, volumeBackupManagement, networkServerAttachment, securityGroupServerAttachment, securityGroupServerManagement, networkServerManagement, volumeServerManagement, floatingIPServerManagement, subnetRouterManagement, flavorSelection
    // OpenStack Services Create Forms
    case barbicanSecretCreate, barbicanContainerCreate, octaviaLoadBalancerCreate, swiftContainerCreate, swiftUpload

    var title: String {
        switch self {
            case .loading: return "Loading"
            case .dashboard: return "Dashboard"
            case .servers: return "Servers"
            case .serverDetail: return "Server Details"
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
            case .keyPairs: return "SSH Key Pairs"
            case .keyPairDetail: return "Key Pair Details"
            case .keyPairCreate: return "Create Key Pair"
            case .topology: return "Topology"
            case .advancedSearch: return "Advanced Search"
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
            case .swiftUpload: return "Upload Objects"
            case .help: return "Help"
            case .about: return "About"
            case .networkServerAttachment: return "Attach Network to Servers"
            case .securityGroupServerAttachment: return "Attach Security Group to Servers"
            case .securityGroupServerManagement: return "Manage Security Group Server Attachments"
            case .networkServerManagement: return "Manage Network Server Attachments"
            case .volumeServerManagement: return "Manage Volume Server Attachments"
            case .floatingIPServerManagement: return "Manage Floating IP Server Assignment"
            case .subnetRouterManagement: return "Manage Subnet Router Attachment"
            case .flavorSelection: return "Select Server Flavor"
        }
    }

    var key: String {
        switch self {
        case .loading: return ""
        case .dashboard: return "[d]"
        case .servers: return "[s]"
        case .serverGroups: return "[g]"
        case .networks: return "[n]"
        case .securityGroups: return "[e]"
        case .volumes: return "[v]"
        case .volumeArchives: return "[m]"
        case .images: return "[i]"
        case .flavors: return "[f]"
        case .topology: return "[t]"
        case .advancedSearch: return "[z]"
        case .healthDashboard: return "[h]"
        case .subnets: return "[u]"
        case .ports: return "[p]"
        case .routers: return "[r]"
        case .floatingIPs: return "[l]"
        case .serverDetail: return ""
        case .serverGroupDetail: return ""
        case .networkDetail: return ""
        case .securityGroupDetail: return ""
        case .volumeDetail: return ""
        case .volumeArchiveDetail: return ""
        case .imageDetail: return ""
        case .flavorDetail: return ""
        case .subnetDetail: return ""
        case .portDetail: return ""
        case .routerDetail: return ""
        case .floatingIPDetail: return ""
        case .healthDashboardServiceDetail: return ""
        case .serverCreate: return ""
        case .serverGroupCreate: return ""
        case .networkCreate: return ""
        case .securityGroupCreate: return ""
        case .securityGroupRuleManagement: return ""
        case .subnetCreate: return ""
        case .volumeCreate: return ""
        case .portCreate: return ""
        case .routerCreate: return ""
        case .floatingIPCreate: return ""
        case .keyPairs: return "[k]"
        case .keyPairDetail: return ""
        case .keyPairCreate: return ""
        // OpenStack Services
        case .barbican: return "[b]"
        case .barbicanSecrets: return ""
        case .barbicanContainers: return ""
        case .octavia: return "[o]"
        case .swift: return "[j]"
        // OpenStack Services Details
        case .barbicanSecretDetail: return ""
        case .barbicanContainerDetail: return ""
        case .octaviaLoadBalancerDetail: return ""
        case .swiftContainerDetail: return ""
        case .swiftObjectDetail: return ""
        // OpenStack Services Create Forms
        case .barbicanSecretCreate: return ""
        case .barbicanContainerCreate: return ""
        case .octaviaLoadBalancerCreate: return ""
        case .swiftContainerCreate: return ""
        case .swiftUpload: return ""
        case .help: return "[?]"
        case .about: return "[@]"
        case .serverSecurityGroups: return ""
        case .serverNetworkInterfaces: return ""
        case .serverGroupManagement: return ""
        case .volumeManagement: return ""
        case .floatingIPServerSelect: return ""
        case .serverSnapshotManagement: return ""
        case .serverResize: return ""
        case .volumeSnapshotManagement: return ""
        case .volumeBackupManagement: return ""
        case .networkServerAttachment: return ""
        case .securityGroupServerAttachment: return ""
        case .securityGroupServerManagement: return ""
        case .networkServerManagement: return ""
        case .volumeServerManagement: return ""
        case .floatingIPServerManagement: return ""
        case .subnetRouterManagement: return ""
        case .flavorSelection: return ""
        }
    }

    var isDetailView: Bool {
        switch self {
        case .serverDetail, .serverGroupDetail, .networkDetail, .securityGroupDetail, .volumeDetail, .volumeArchiveDetail, .imageDetail, .flavorDetail, .subnetDetail, .portDetail, .routerDetail, .floatingIPDetail, .healthDashboardServiceDetail, .serverCreate, .serverGroupCreate, .networkCreate, .securityGroupCreate, .securityGroupRuleManagement, .subnetCreate, .volumeCreate, .portCreate, .routerCreate, .floatingIPCreate, .keyPairDetail, .keyPairCreate, .serverSecurityGroups, .serverNetworkInterfaces, .serverGroupManagement, .volumeManagement, .floatingIPServerSelect, .serverSnapshotManagement, .serverResize, .volumeSnapshotManagement, .volumeBackupManagement, .networkServerAttachment, .securityGroupServerAttachment, .securityGroupServerManagement, .networkServerManagement, .volumeServerManagement, .floatingIPServerManagement, .subnetRouterManagement:
            return true
        // OpenStack Services Detail Views
        case .barbicanSecretDetail, .barbicanContainerDetail, .octaviaLoadBalancerDetail, .swiftContainerDetail, .swiftObjectDetail:
            return true
        // OpenStack Services Create Forms
        case .barbicanSecretCreate, .barbicanContainerCreate, .octaviaLoadBalancerCreate, .swiftContainerCreate, .swiftUpload:
            return true
        default:
            return false
        }
    }

    var parentView: ViewMode {
        switch self {
        case .serverDetail: return .servers
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
        // OpenStack Services Parent Views
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
        case .swiftContainerCreate: return .swift
        case .swiftUpload: return .swiftContainerDetail
        case .networkServerAttachment: return .networks
        case .securityGroupServerAttachment: return .securityGroups
        case .securityGroupServerManagement: return .securityGroups
        case .networkServerManagement: return .networks
        case .volumeServerManagement: return .volumes
        case .floatingIPServerManagement: return .floatingIPs
        case .subnetRouterManagement: return .subnets
        case .flavorSelection: return .serverCreate
        default: return self
        }
    }
}

@MainActor
struct MainPanelView {

    static func draw(screen: OpaquePointer?, tui: TUI, screenCols: Int32, screenRows: Int32) async {
        let sidebarWidth = calculateSidebarWidth(screenCols: screenCols)
        let mainStartCol: Int32 = sidebarWidth + 1  // Start immediately after separator to eliminate gap
        let mainWidth = max(10, screenCols - mainStartCol - 1)  // Minimum width check
        let mainStartRow: Int32 = 2
        let mainHeight = max(5, screenRows - mainStartRow - 2)  // Minimum height check

        // Only draw if we have sufficient space
        guard mainWidth > 10 && mainHeight > 5 else { return }

        // Fill main panel background to match header and sidebar styling
        let surface = SwiftTUI.surface(from: screen)
        let mainBounds = Rect(x: mainStartCol, y: mainStartRow, width: mainWidth, height: mainHeight)
        await surface.fill(rect: mainBounds, character: " ", style: .secondary)

        await renderCurrentView(screen: screen, tui: tui, mainStartRow: mainStartRow, mainStartCol: mainStartCol, mainWidth: mainWidth, mainHeight: mainHeight)
    }

    private static func renderCurrentView(screen: OpaquePointer?, tui: TUI, mainStartRow: Int32, mainStartCol: Int32, mainWidth: Int32, mainHeight: Int32) async {
        switch tui.currentView {
        case .loading:
            await LoadingView.drawLoadingScreen(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, progressStep: tui.loadingProgress, statusMessage: tui.loadingMessage)
        case .dashboard:
            await DashboardView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, resourceCounts: tui.resourceCounts, cachedServers: tui.cachedServers, cachedNetworks: tui.cachedNetworks, cachedVolumes: tui.cachedVolumes, cachedPorts: tui.cachedPorts, cachedRouters: tui.cachedRouters, cachedComputeLimits: tui.cachedComputeLimits, cachedNetworkQuotas: tui.cachedNetworkQuotas, cachedVolumeQuotas: tui.cachedVolumeQuotas, quotaScrollOffset: tui.quotaScrollOffset, tui: tui)
        case .healthDashboard:
            let telemetryActor = await tui.getTelemetryActor()
            await HealthDashboardView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, telemetryActor: telemetryActor, navigationState: tui.healthDashboardNavState, dataManager: tui.dataManager, performanceMonitor: tui.performanceMonitor)
        case .servers:
            await ServerViews.drawDetailedServerList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedServers: tui.cachedServers, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, cachedFlavors: tui.cachedFlavors, cachedImages: tui.cachedImages)
        case .serverGroups:
            await ServerGroupViews.drawDetailedServerGroupList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedServerGroups: tui.cachedServerGroups, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .networks:
            await NetworkViews.drawDetailedNetworkList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedNetworks: tui.cachedNetworks, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .securityGroups:
            await SecurityGroupViews.drawDetailedSecurityGroupList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedSecurityGroups: tui.cachedSecurityGroups, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .volumes:
            await VolumeViews.drawDetailedVolumeList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedVolumes: tui.cachedVolumes, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .volumeArchives:
            await VolumeArchiveViews.drawDetailedArchiveList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedVolumeSnapshots: tui.cachedVolumeSnapshots, cachedVolumeBackups: tui.cachedVolumeBackups, cachedImages: tui.cachedImages, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .images:
            await ImageViews.drawDetailedImageList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedImages: tui.cachedImages, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .flavors:
            await FlavorViews.drawDetailedFlavorList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedFlavors: tui.cachedFlavors, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .keyPairs:
            await KeyPairViews.drawDetailedKeyPairList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedKeyPairs: tui.cachedKeyPairs, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .keyPairDetail:
            if let keyPair = tui.selectedResource as? KeyPair {
                await KeyPairViews.drawKeyPairDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, keyPair: keyPair)
            }
        case .topology:
            // Auto-load topology data if not available
            if tui.lastTopology == nil {
                tui.statusMessage = "Loading topology data..."
                tui.lastTopology = await TopologyGraphBuilder.build(client: tui.client)
                tui.statusMessage = "Topology loaded"
            }
            await TopologyViews.drawTopologyView(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, topology: tui.lastTopology, scrollOffset: Int32(tui.detailScrollOffset), mode: tui.currentTopologyMode)
        case .serverDetail:
            if let server = tui.selectedResource as? Server {
                await ServerViews.drawServerDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, server: server, cachedVolumes: tui.cachedVolumes, cachedFlavors: tui.cachedFlavors, cachedImages: tui.cachedImages, scrollOffset: tui.detailScrollOffset)
            }
        case .serverGroupDetail:
            if let serverGroup = tui.selectedResource as? ServerGroup {
                await ServerGroupViews.drawServerGroupDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, serverGroup: serverGroup, cachedServers: tui.cachedServers)
            }
        case .networkDetail:
            if let network = tui.selectedResource as? Network {
                await NetworkViews.drawNetworkDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, network: network)
            }
        case .securityGroupDetail:
            if let securityGroup = tui.selectedResource as? SecurityGroup {
                await SecurityGroupViews.drawSecurityGroupDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, securityGroup: securityGroup)
            }
        case .volumeDetail:
            if let volume = tui.selectedResource as? Volume {
                await VolumeViews.drawVolumeDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, volume: volume)
            }
        case .volumeArchiveDetail:
            if let snapshot = tui.selectedResource as? VolumeSnapshot {
                await VolumeArchiveViews.drawVolumeSnapshotDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, snapshot: snapshot)
            } else if let backup = tui.selectedResource as? VolumeBackup {
                await VolumeArchiveViews.drawVolumeBackupDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, backup: backup)
            }
        case .imageDetail:
            if let image = tui.selectedResource as? Image {
                await ImageViews.drawImageDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, image: image, scrollOffset: tui.detailScrollOffset)
            }
        case .flavorDetail:
            if let flavor = tui.selectedResource as? Flavor {
                await FlavorViews.drawFlavorDetailGoldStandard(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, flavor: flavor, scrollOffset: Int32(tui.detailScrollOffset))
            }
        case .healthDashboardServiceDetail:
            if let service = tui.selectedResource as? HealthDashboardService {
                await HealthDashboardView.drawServiceDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, service: service, scrollOffset: tui.detailScrollOffset)
            }
        case .serverCreate:
            await ServerCreateView.drawServerCreateForm(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.serverCreateForm, formState: tui.serverCreateFormState)
        case .networkCreate:
            await NetworkViews.drawNetworkCreate(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, networkCreateForm: tui.networkCreateForm, networkCreateFormState: tui.networkCreateFormState)
        case .securityGroupCreate:
            await SecurityGroupViews.drawSecurityGroupCreateForm(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.securityGroupCreateForm, formState: tui.securityGroupCreateFormState)
        case .securityGroupRuleManagement:
            if let form = tui.securityGroupRuleManagementForm {
                await SecurityGroupViews.drawSecurityGroupRuleManagement(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: form, cachedSecurityGroups: tui.cachedSecurityGroups)
            }
        case .subnetCreate:
            await SubnetViews.drawSubnetCreate(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, subnetCreateForm: tui.subnetCreateForm, cachedNetworks: tui.cachedNetworks, formState: tui.subnetCreateFormState)
        case .serverSecurityGroups:
            await SecurityGroupViews.drawServerSecurityGroupManagement(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.securityGroupForm)
        case .serverResize:
            await ServerViews.drawServerResizeManagement(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, serverResizeForm: tui.serverResizeForm)
        case .serverSnapshotManagement:
            await SnapshotManagementView.drawServerSnapshotManagement(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.snapshotManagementForm, formBuilderState: tui.snapshotManagementFormState)
        case .volumeSnapshotManagement:
            await VolumeSnapshotManagementView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.volumeSnapshotManagementForm, formBuilderState: tui.volumeSnapshotManagementFormState)
        case .volumeBackupManagement:
            await VolumeBackupManagementView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.volumeBackupManagementForm, formBuilderState: tui.volumeBackupManagementFormState)
        case .serverNetworkInterfaces:
            await NetworkInterfaceManagementView.drawServerNetworkInterfaceManagement(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.networkInterfaceForm, resourceNameCache: tui.resourceNameCache, resourceResolver: tui.resourceResolver)
        case .volumeManagement:
            await VolumeManagementView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.volumeManagementForm, resourceNameCache: tui.resourceNameCache)
        case .keyPairCreate:
            await KeyPairViews.drawKeyPairCreate(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, keyPairCreateForm: tui.keyPairCreateForm, keyPairCreateFormState: tui.keyPairCreateFormState)
        case .volumeCreate:
            await VolumeViews.drawVolumeCreate(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, formBuilderState: tui.volumeCreateFormState)

        case .subnets:
            await SubnetViews.drawDetailedSubnetList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedSubnets: tui.cachedSubnets, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .subnetDetail:
            if let subnet = tui.selectedResource as? Subnet {
                await SubnetViews.drawSubnetDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, subnet: subnet)
            }
        case .ports:
            await PortViews.drawDetailedPortList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedPorts: tui.cachedPorts, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .portDetail:
            if let port = tui.selectedResource as? Port {
                await PortViews.drawPortDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, port: port, cachedNetworks: tui.cachedNetworks, cachedSubnets: tui.cachedSubnets, cachedSecurityGroups: tui.cachedSecurityGroups)
            }
        case .portCreate:
            await PortViews.drawPortCreateForm(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, portCreateForm: tui.portCreateForm, portCreateFormState: tui.portCreateFormState, cachedNetworks: tui.cachedNetworks, cachedSecurityGroups: tui.cachedSecurityGroups, cachedQoSPolicies: tui.cachedQoSPolicies, selectedIndex: tui.selectedIndex)
        case .routers:
            await RouterViews.drawDetailedRouterList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedRouters: tui.cachedRouters, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .routerDetail:
            if let selectedRouter = tui.selectedResource as? Router {
                // Find the updated router from cached routers to get latest interface data
                var routerWithInterfaces = tui.cachedRouters.first { $0.id == selectedRouter.id } ?? selectedRouter

                // If the cached router has no interfaces, force fetch detailed router information
                if routerWithInterfaces.interfaces == nil || routerWithInterfaces.interfaces?.isEmpty == true {
                    Logger.shared.logInfo("Router has no interface data, force fetching detailed info", context: [
                        "routerId": selectedRouter.id,
                        "routerName": selectedRouter.name ?? "Unknown"
                    ])

                    do {
                        // Force fetch detailed router information with interfaces
                        let detailedRouter = try await tui.dataManager.getDetailedRouter(id: selectedRouter.id)
                        routerWithInterfaces = detailedRouter

                        Logger.shared.logInfo("Successfully fetched detailed router", context: [
                            "routerId": detailedRouter.id,
                            "routerName": detailedRouter.name ?? "Unknown",
                            "interfaceCount": detailedRouter.interfaces?.count ?? 0,
                            "interfaceSubnetIds": detailedRouter.interfaces?.compactMap { $0.subnetId } ?? []
                        ])
                    } catch {
                        Logger.shared.logError("Failed to fetch detailed router info", context: [
                            "routerId": selectedRouter.id,
                            "error": "\(error)"
                        ])
                    }
                }

                // Log router interface information for debugging
                Logger.shared.logInfo("Router detail view rendering", context: [
                    "selectedRouterId": selectedRouter.id,
                    "foundInCache": tui.cachedRouters.contains { $0.id == selectedRouter.id },
                    "interfaceCount": routerWithInterfaces.interfaces?.count ?? 0,
                    "interfaceSubnetIds": routerWithInterfaces.interfaces?.compactMap { $0.subnetId } ?? []
                ])

                await RouterViews.drawRouterDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, router: routerWithInterfaces, cachedSubnets: tui.cachedSubnets)
            }
        case .routerCreate:
            await RouterViews.drawRouterCreateForm(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, routerCreateForm: tui.routerCreateForm, routerCreateFormState: tui.routerCreateFormState, availabilityZones: tui.cachedAvailabilityZones, externalNetworks: tui.cachedNetworks)
        case .floatingIPs:
            await FloatingIPViews.drawDetailedFloatingIPList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, cachedFloatingIPs: tui.cachedFloatingIPs, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, cachedServers: tui.cachedServers, cachedPorts: tui.cachedPorts, cachedNetworks: tui.cachedNetworks)
        case .floatingIPDetail:
            if let floatingIP = tui.selectedResource as? FloatingIP {
                await FloatingIPViews.drawFloatingIPDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, floatingIP: floatingIP, cachedServers: tui.cachedServers, cachedPorts: tui.cachedPorts, cachedNetworks: tui.cachedNetworks)
            }
        case .floatingIPCreate:
            let externalNetworks = tui.cachedNetworks.filter { $0.external == true }
            await FloatingIPViews.drawFloatingIPCreateForm(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, floatingIPCreateForm: tui.floatingIPCreateForm, floatingIPCreateFormState: tui.floatingIPCreateFormState, cachedNetworks: externalNetworks, cachedSubnets: tui.cachedSubnets)

        case .serverGroupCreate:
            await ServerGroupViews.drawServerGroupCreateForm(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.serverGroupCreateForm, formState: tui.serverGroupCreateFormState)
        case .serverGroupManagement:
            await ServerGroupViews.drawServerGroupManagement(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.serverGroupManagementForm)

        case .help:
            let contextView = tui.previousView != .help ? tui.previousView : .dashboard
            await MiscViews.drawHelp(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, scrollOffset: tui.helpScrollOffset, currentView: contextView)
        case .about:
            await MiscViews.drawAbout(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, scrollOffset: tui.helpScrollOffset)
        case .advancedSearch:
            await AdvancedSearchView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, tui: tui)

        // Barbican views
        case .barbican, .barbicanSecrets:
            await BarbicanViews.drawBarbicanSecretList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, secrets: tui.cachedSecrets, searchQuery: tui.searchQuery ?? "", scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, filterCache: tui.resourceNameCache)
        case .barbicanContainers:
            await BarbicanViews.drawBarbicanContainerList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, containers: tui.cachedBarbicanContainers, searchQuery: tui.searchQuery ?? "", scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, filterCache: tui.resourceNameCache)
        case .barbicanSecretDetail:
            if let secret = tui.selectedResource as? Secret {
                await BarbicanViews.drawBarbicanSecretDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, secret: secret)
            }
        case .barbicanContainerDetail:
            if let container = tui.selectedResource as? BarbicanContainer {
                await BarbicanViews.drawBarbicanContainerDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, container: container)
            }
        case .barbicanSecretCreate:
            let validationErrors = tui.barbicanSecretCreateForm.validate()
            await BarbicanViews.drawBarbicanSecretCreateForm(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, form: tui.barbicanSecretCreateForm, validationErrors: validationErrors)
        case .barbicanContainerCreate:
            await MiscViews.drawSimpleCenteredMessage(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, message: "Create Container - Coming Soon")

        // Octavia views
        case .octavia:
            await OctaviaViews.drawOctaviaLoadBalancerList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, loadBalancers: tui.cachedLoadBalancers, searchQuery: tui.searchQuery ?? "", scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, filterCache: tui.resourceNameCache)
        case .octaviaLoadBalancerDetail:
            if let lb = tui.selectedResource as? LoadBalancer {
                await OctaviaViews.drawOctaviaLoadBalancerDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, loadBalancer: lb)
            }
        case .octaviaLoadBalancerCreate:
            await OctaviaViews.drawOctaviaLoadBalancerCreate(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight)

        // Swift views
        case .swift:
            await SwiftViews.drawSwiftContainerList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, containers: tui.cachedSwiftContainers, searchQuery: tui.searchQuery ?? "", scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, filterCache: tui.resourceNameCache)
        case .swiftContainerDetail:
            if let objects = tui.cachedSwiftObjects {
                await SwiftViews.drawSwiftObjectList(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, objects: objects, containerName: tui.selectedResource as? String ?? "Container", searchQuery: tui.searchQuery ?? "", scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, filterCache: tui.resourceNameCache)
            }
        case .swiftObjectDetail:
            if let object = tui.selectedResource as? SwiftObject {
                await SwiftViews.drawSwiftObjectDetail(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, object: object)
            }
        case .swiftContainerCreate:
            await SwiftViews.drawSwiftContainerCreate(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight)
        case .swiftUpload:
            await SwiftViews.drawSwiftUpload(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight)
        case .networkServerAttachment:
            await NetworkServerAttachmentView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, servers: tui.cachedServers, selectedServers: tui.selectedServers, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .securityGroupServerAttachment:
            await SecurityGroupServerAttachmentView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, servers: tui.cachedServers, selectedServers: tui.selectedServers, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex)
        case .securityGroupServerManagement:
            if let securityGroup = tui.selectedResource as? SecurityGroup {
                await SecurityGroupServerManagementView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, securityGroup: securityGroup, servers: tui.cachedServers, attachedServerIds: tui.attachedServerIds, selectedServers: tui.selectedServers, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .networkServerManagement:
            if let network = tui.selectedResource as? Network {
                await NetworkServerManagementView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, network: network, servers: tui.cachedServers, attachedServerIds: tui.attachedServerIds, selectedServers: tui.selectedServers, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .volumeServerManagement:
            if let volume = tui.selectedResource as? Volume {
                await VolumeServerManagementView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, volume: volume, servers: tui.cachedServers, attachedServerIds: tui.attachedServerIds, selectedServers: tui.selectedServers, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .floatingIPServerManagement:
            if let floatingIP = tui.selectedResource as? FloatingIP {
                await FloatingIPServerManagementView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, floatingIP: floatingIP, servers: tui.cachedServers, attachedServerId: tui.attachedServerId, selectedServerId: tui.selectedServerId, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .subnetRouterManagement:
            if let subnet = tui.selectedResource as? Subnet {
                await SubnetRouterManagementView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, subnet: subnet, routers: tui.cachedRouters, attachedRouterIds: tui.attachedRouterIds, selectedRouterId: tui.selectedRouterId, searchQuery: tui.searchQuery, scrollOffset: tui.scrollOffset, selectedIndex: tui.selectedIndex, mode: tui.attachmentMode, resourceResolver: tui.resourceResolver)
            }
        case .flavorSelection:
            await FlavorSelectionView.draw(screen: screen, startRow: mainStartRow, startCol: mainStartCol, width: mainWidth, height: mainHeight, flavors: tui.cachedFlavors, workloadType: tui.serverCreateForm.workloadType, flavorRecommendations: tui.serverCreateForm.flavorRecommendations, selectedFlavorId: tui.serverCreateForm.selectedFlavorID, selectedRecommendationIndex: tui.serverCreateForm.selectedRecommendationIndex, selectedIndex: tui.selectedIndex, mode: tui.serverCreateForm.flavorSelectionMode, scrollOffset: tui.scrollOffset, searchQuery: tui.searchQuery, selectedCategoryIndex: tui.serverCreateForm.selectedCategoryIndex)
        case .floatingIPServerSelect:
            // This view has been replaced by the floating IP server management interface
            break

        @unknown default:
            break
        }
    }

    internal static func calculateSidebarWidth(screenCols: Int32) -> Int32 {
        // Responsive sidebar width based on screen size
        if screenCols < 70 {
            return 7  // Compact mode: "[d]" format
        } else {
            return 25 // Full mode: complete text
        }
    }
}