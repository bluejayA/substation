import Foundation
import struct OSClient.Port
import OSClient

@MainActor
struct UIUtils {

    static func getDynamicHelpText(for currentView: ViewMode) -> String {
        let baseCommands = "^c:quit UP/DOWN:select ?:help a:auto-refresh c:refresh"
        let dashboardCommands = "^c:quit UP/DOWN:select a:auto-refresh A:interval c:refresh"

        switch currentView {
        case .loading:
            return "Loading..."  // No commands available during loading
        case .dashboard:
            return "\(dashboardCommands)"
        case .servers:
            return "\(baseCommands) SPACE:details C:create P:snapshot R:restart Z:resize S:start T:stop L:logs DELETE:delete /:search ESC:back"
        case .networks:
            return "\(baseCommands) SPACE:details C:create A:attach/detach DELETE:delete /:search ESC:back"
        case .volumes:
            return "\(baseCommands) SPACE:details C:create DELETE:delete A:attach/detach B:backup P:snapshot /:search ESC:back"
        case .volumeArchives:
            return "\(baseCommands) SPACE:details DELETE:delete /:search ESC:back"
        case .images:
            return "\(baseCommands) SPACE:details DELETE:delete /:search ESC:back"
        case .flavors:
            return "\(baseCommands) SPACE:details /:search ESC:back"
        case .keyPairs:
            return "\(baseCommands) SPACE:details C:create DELETE:delete /:search ESC:back"
        case .subnets:
            return "\(baseCommands) SPACE:details C:create A:attach DELETE:delete /:search ESC:back"
        case .ports:
            return "\(baseCommands) SPACE:details C:create M:manage P:allowed-address-pairs DELETE:delete /:search ESC:back"
        case .floatingIPs:
            return "\(baseCommands) SPACE:details C:create M:manage DELETE:delete /:search ESC:back"
        case .routers:
            return "\(baseCommands) SPACE:details C:create DELETE:delete /:search ESC:back"
        case .healthDashboard:
            return "^c:quit UP/DOWN:navigate a:auto-refresh SPACE:service-details ESC:back ?:help"
        case .serverDetail, .networkDetail, .volumeDetail, .volumeArchiveDetail, .imageDetail, .flavorDetail, .keyPairDetail, .subnetDetail, .portDetail, .floatingIPDetail, .routerDetail, .healthDashboardServiceDetail:
            return "\(baseCommands) ESC:back"
        case .serverResize:
            return "\(baseCommands) ENTER:select ESC:back"
        case .serverCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change ENTER:create ESC:cancel"
        case .networkCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change ENTER:create ESC:cancel"
        case .keyPairCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change ENTER:create ESC:cancel"
        case .volumeCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change ENTER:create ESC:cancel"
        case .subnetCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change ENTER:create ESC:cancel"
        case .portCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change SPACE:edit/toggle ENTER:create ESC:cancel"
        case .floatingIPCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change SPACE:edit/toggle ENTER:create ESC:cancel"
        case .routerCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change SPACE:edit ENTER:create ESC:cancel"
        case .serverSecurityGroups:
            return "\(baseCommands) SPACE:toggle ENTER:apply ESC:back"
        case .serverSnapshotManagement:
            return "\(baseCommands) ENTER:create ESC:back"
        case .volumeSnapshotManagement:
            return "\(baseCommands) TAB:navigate ENTER:create ESC:back"
        case .volumeBackupManagement:
            return "\(baseCommands) TAB:navigate ENTER:create ESC:back"
        case .serverNetworkInterfaces:
            return "\(baseCommands) TAB:mode SPACE:toggle ENTER:apply ESC:back"
        case .volumeManagement:
            return "\(baseCommands) TAB:operation SPACE:toggle ENTER:apply ESC:back"
        case .floatingIPServerSelect:
            return "\(baseCommands) ENTER:attach ESC:cancel"
        case .serverGroups:
            return "\(baseCommands) SPACE:details C:create DELETE:delete /:search ESC:back"
        case .serverGroupDetail:
            return "\(baseCommands) M:manage ESC:back"
        case .serverGroupCreate:
            return "\(baseCommands) TAB:navigate LEFT/RIGHT:change SPACE:edit ENTER:create ESC:cancel"
        case .serverGroupManagement:
            return "\(baseCommands) TAB:operation SPACE:toggle ENTER:apply ESC:back"
        case .securityGroups:
            return "\(baseCommands) SPACE:details C:create A:attach/detach M:manage-rules DELETE:delete /:search ESC:back"
        case .securityGroupDetail:
            return "\(baseCommands) ESC:back"
        case .securityGroupCreate:
            return "\(baseCommands) TAB:navigate ENTER:edit ESC:cancel"
        case .securityGroupRuleManagement:
            return "\(baseCommands) TAB:mode SPACE:toggle ENTER:apply C:create E:edit DELETE:delete ESC:back"
        case .help:
            return "\(baseCommands) ESC:back"
        case .about:
            return "\(baseCommands) ESC:back"
        case .advancedSearch:
            return "\(baseCommands) TAB:navigate ENTER:search /:filter ESC:back"
        case .barbican:
            return "\(baseCommands) SPACE:details C:create DELETE:delete /:search ESC:back"
        case .barbicanSecrets:
            return "\(baseCommands) SPACE:details C:create DELETE:delete /:search ESC:back"
        case .barbicanContainers:
            return "\(baseCommands) SPACE:details C:create /:search ESC:back"
        case .octavia:
            return "\(baseCommands) SPACE:details C:create /:search ESC:back"
        case .swift:
            return "\(baseCommands) SPACE:details C:create M:metadata DELETE:delete /:search ESC:back"
        case .barbicanSecretDetail:
            return "\(baseCommands) ESC:back"
        case .barbicanContainerDetail:
            return "\(baseCommands) ESC:back"
        case .octaviaLoadBalancerDetail:
            return "\(baseCommands) ESC:back"
        case .swiftContainerDetail:
            return "\(baseCommands) M:metadata DELETE:delete ESC:back"
        case .swiftObjectDetail:
            return "\(baseCommands) ESC:back"
        case .barbicanSecretCreate:
            return "\(baseCommands) TAB/UP/DOWN:navigate ENTER:create ESC:cancel"
        case .barbicanContainerCreate:
            return "\(baseCommands) TAB:navigate ENTER:create ESC:cancel"
        case .octaviaLoadBalancerCreate:
            return "\(baseCommands) TAB:navigate ENTER:create ESC:cancel"
        case .swiftContainerCreate:
            return "\(baseCommands) TAB:navigate ENTER:create ESC:cancel"
        case .swiftContainerMetadata:
            return "\(baseCommands) TAB:navigate SPACE:edit ENTER:save ESC:cancel"
        case .swiftObjectMetadata:
            return "\(baseCommands) TAB:navigate SPACE:edit ENTER:save ESC:cancel"
        case .swiftUpload:
            return "\(baseCommands) TAB:navigate ENTER:upload ESC:cancel"
        case .networkServerAttachment:
            return "\(baseCommands) SPACE:select/deselect ENTER:attach-to-selected ESC:back"
        case .securityGroupServerAttachment:
            return "\(baseCommands) SPACE:select/deselect ENTER:attach-to-selected ESC:back"
        case .securityGroupServerManagement:
            return "\(baseCommands) TAB:mode SPACE:select/deselect ENTER:apply ESC:back"
        case .networkServerManagement:
            return "\(baseCommands) TAB:mode SPACE:select/deselect ENTER:apply ESC:back"
        case .volumeServerManagement:
            return "\(baseCommands) TAB:mode SPACE:select/deselect ENTER:apply ESC:back"
        case .floatingIPServerManagement:
            return "\(baseCommands) TAB:mode SPACE:select ENTER:apply ESC:back"
        case .floatingIPPortManagement:
            return "\(baseCommands) TAB:mode SPACE:select ENTER:apply ESC:back"
        case .portServerManagement:
            return "\(baseCommands) TAB:mode SPACE:select ENTER:apply ESC:back"
        case .portAllowedAddressPairManagement:
            return "\(baseCommands) A:add D:delete SPACE:edit ENTER:save ESC:back"
        case .subnetRouterManagement:
            return "\(baseCommands) TAB:mode SPACE:select ENTER:apply ESC:back"
        case .flavorSelection:
            return "\(baseCommands) TAB:switch-mode SPACE:select ENTER:confirm ESC:back"
        }
    }

    static func getMaxSelectionIndex(
        for view: ViewMode,
        cachedServers: [Server],
        cachedNetworks: [Network],
        cachedVolumes: [Volume],
        cachedImages: [Image],
        cachedFlavors: [Flavor],
        cachedKeyPairs: [KeyPair],
        cachedSubnets: [Subnet],
        cachedPorts: [Port],
        cachedRouters: [Router],
        cachedFloatingIPs: [FloatingIP],
        cachedServerGroups: [ServerGroup] = [],
        cachedSecurityGroups: [SecurityGroup] = [],
        cachedSecrets: [Secret] = [],
        cachedVolumeSnapshots: [VolumeSnapshot] = [],
        cachedVolumeBackups: [VolumeBackup] = [],
        cachedSwiftContainers: [SwiftContainer] = [],
        cachedSwiftObjects: [SwiftObject]? = nil,
        searchQuery: String?,
        resourceResolver: ResourceResolver
    ) -> Int {
        switch view {
        case .loading:
            return 0  // No selection available during loading
        case .dashboard:
            return 0  // Dashboard has its own navigation
        case .servers:
            return max(0, ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP).count - 1)
        case .networks:
            return max(0, ResourceFilters.filterNetworks(cachedNetworks, query: searchQuery).count - 1)
        case .volumes:
            return max(0, ResourceFilters.filterVolumes(cachedVolumes, query: searchQuery).count - 1)
        case .volumeArchives:
            let serverBackups = cachedImages.filter { image in
                if let properties = image.properties,
                   let imageType = properties["image_type"],
                   imageType == "snapshot" {
                    return true
                }
                return false
            }
            let totalArchives = cachedVolumeSnapshots.count + cachedVolumeBackups.count + serverBackups.count
            let filteredCount: Int
            if let query = searchQuery, !query.isEmpty {
                let lowercaseQuery = query.lowercased()
                let filteredSnapshots = cachedVolumeSnapshots.filter { snapshot in
                    (snapshot.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                    (snapshot.status?.lowercased().contains(lowercaseQuery) ?? false)
                }
                let filteredVolumeBackups = cachedVolumeBackups.filter { backup in
                    (backup.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                    (backup.status?.lowercased().contains(lowercaseQuery) ?? false)
                }
                let filteredServerBackups = serverBackups.filter { image in
                    (image.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                    (image.status?.lowercased().contains(lowercaseQuery) ?? false)
                }
                filteredCount = filteredSnapshots.count + filteredVolumeBackups.count + filteredServerBackups.count
            } else {
                filteredCount = totalArchives
            }
            return max(0, filteredCount - 1)
        case .images:
            return max(0, ResourceFilters.filterImages(cachedImages, query: searchQuery).count - 1)
        case .flavors:
            return max(0, ResourceFilters.filterFlavors(cachedFlavors, query: searchQuery).count - 1)
        case .keyPairs:
            return max(0, ResourceFilters.filterKeyPairs(cachedKeyPairs, query: searchQuery).count - 1)
        case .subnets:
            return max(0, FilterUtils.filterSubnets(cachedSubnets, query: searchQuery).count - 1)
        case .ports:
            return max(0, FilterUtils.filterPorts(cachedPorts, query: searchQuery).count - 1)
        case .routers:
            return max(0, FilterUtils.filterRouters(cachedRouters, query: searchQuery).count - 1)
        case .floatingIPs:
            return max(0, FilterUtils.filterFloatingIPs(cachedFloatingIPs, query: searchQuery).count - 1)
        case .serverGroups:
            return max(0, FilterUtils.filterServerGroups(cachedServerGroups, query: searchQuery).count - 1)
        case .securityGroups:
            return max(0, FilterUtils.filterSecurityGroups(cachedSecurityGroups, query: searchQuery).count - 1)
        case .barbicanSecrets:
            let filteredSecrets = searchQuery?.isEmpty ?? true ? cachedSecrets : cachedSecrets.filter { secret in
                (secret.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false) ||
                (secret.secretType?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false)
            }
            return max(0, filteredSecrets.count - 1)

        case .networkServerManagement, .volumeServerManagement, .floatingIPServerManagement:
            // Management views handle their own filtered server counts
            let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
            return max(0, filteredServers.count - 1)
        case .swift:
            // Swift container list view
            let filteredContainers: [SwiftContainer]
            if let query = searchQuery, !query.isEmpty {
                filteredContainers = cachedSwiftContainers.filter { $0.name?.localizedCaseInsensitiveContains(query) ?? false }
            } else {
                filteredContainers = cachedSwiftContainers
            }
            return max(0, filteredContainers.count - 1)
        case .swiftContainerDetail:
            // Swift object list view
            guard let objects = cachedSwiftObjects else { return 0 }
            let filteredObjects: [SwiftObject]
            if let query = searchQuery, !query.isEmpty {
                filteredObjects = objects.filter { $0.name?.localizedCaseInsensitiveContains(query) ?? false }
            } else {
                filteredObjects = objects
            }
            return max(0, filteredObjects.count - 1)
        default:
            // For detail views and others, no selection
            return 0
        }
    }
}

// MARK: - TUI Navigation Helpers

@MainActor
extension TUI {
    /// Helper method to delegate navigation to NavigationInputHandler with a given context
    /// Returns true if the input was handled by the navigation handler
    func handleCommonNavigation(_ ch: Int32, screen: OpaquePointer?, context: NavigationContext) async -> Bool {
        switch context {
        case .list(let maxIndex):
            return await NavigationInputHandler.handleListNavigation(ch, maxIndex: maxIndex, tui: self)
        case .form(let fieldCount):
            return await NavigationInputHandler.handleFormNavigation(ch, fieldCount: fieldCount, tui: self)
        case .management(let itemCount):
            return await NavigationInputHandler.handleManagementNavigation(ch, itemCount: itemCount, tui: self)
        case .detail(let scrollable):
            return await NavigationInputHandler.handleDetailNavigation(ch, scrollable: scrollable, tui: self)
        case .custom:
            return false
        }
    }
}