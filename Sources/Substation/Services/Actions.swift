import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftNCurses
import MemoryKit

/// Service layer for resource management operations
///
/// This service encapsulates all resource action operations including:
/// - Server lifecycle (start, stop, restart, resize)
/// - Snapshot management (server and volume snapshots)
/// - Network interface management
/// - Security group management
/// - Volume attachment management
/// - Floating IP management
/// - Router attachment management
@MainActor
final class Actions {
    internal let tui: TUI

    init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Convenience Accessors

    internal var client: OSClient { tui.client }
    internal var dataManager: DataManager { tui.dataManager }
    internal var resourceOperations: ResourceOperations { tui.resourceOperations }
    internal var errorHandler: OperationErrorHandler { tui.errorHandler }
    internal var validator: ValidationService { tui.validator }
    internal var statusMessage: String? {
        get { tui.statusMessage }
        set { tui.statusMessage = newValue }
    }
    internal var currentView: ViewMode {
        get { tui.currentView }
        set { tui.currentView = newValue }
    }
    internal var searchQuery: String? { tui.searchQuery }
    internal var selectedIndex: Int {
        get { tui.selectedIndex }
        set { tui.selectedIndex = newValue }
    }
    internal var selectedResource: Any? {
        get { tui.selectedResource }
        set { tui.selectedResource = newValue }
    }
    internal var selectedServers: Set<String> {
        get { tui.selectedServers }
        set { tui.selectedServers = newValue }
    }
    internal var attachedServerIds: Set<String> {
        get { tui.attachedServerIds }
        set { tui.attachedServerIds = newValue }
    }
    internal var selectedServerId: String? {
        get { tui.selectedServerId }
        set { tui.selectedServerId = newValue }
    }
    internal var attachedServerId: String? {
        get { tui.attachedServerId }
        set { tui.attachedServerId = newValue }
    }
    internal var selectedRouterId: String? {
        get { tui.selectedRouterId }
        set { tui.selectedRouterId = newValue }
    }
    internal var attachedRouterIds: Set<String> {
        get { tui.attachedRouterIds }
        set { tui.attachedRouterIds = newValue }
    }
    internal var attachmentMode: AttachmentMode {
        get { tui.attachmentMode }
        set { tui.attachmentMode = newValue }
    }
    internal var screenRows: Int32 { tui.screenRows }
    internal var screenCols: Int32 { tui.screenCols }
    internal var resourceResolver: ResourceResolver { tui.resourceResolver }
    internal var progressIndicator: ProgressIndicator { tui.progressIndicator }
    internal var enhancedErrorHandler: EnhancedErrorHandler { tui.enhancedErrorHandler }
    internal var loadingStateManager: LoadingStateManager { tui.loadingStateManager }
    internal var scrollOffset: Int {
        get { tui.scrollOffset }
        set { tui.scrollOffset = newValue }
    }

    // Cache accessors
    internal var cachedServers: [Server] {
        get { tui.cachedServers }
        set { tui.cachedServers = newValue }
    }
    internal var cachedNetworks: [Network] { tui.cachedNetworks }
    internal var cachedSubnets: [Subnet] { tui.cachedSubnets }
    internal var cachedPorts: [Port] {
        get { tui.cachedPorts }
        set { tui.cachedPorts = newValue }
    }
    internal var cachedRouters: [Router] { tui.cachedRouters }
    internal var cachedFloatingIPs: [FloatingIP] {
        get { tui.cachedFloatingIPs }
        set { tui.cachedFloatingIPs = newValue }
    }
    internal var cachedVolumes: [Volume] {
        get { tui.cachedVolumes }
        set { tui.cachedVolumes = newValue }
    }
    internal var cachedSecurityGroups: [SecurityGroup] {
        get { tui.cachedSecurityGroups }
        set { tui.cachedSecurityGroups = newValue }
    }
    internal var cachedFlavors: [Flavor] { tui.cachedFlavors }

    // Form accessors
    internal var securityGroupForm: SecurityGroupManagementForm {
        get { tui.securityGroupForm }
        set { tui.securityGroupForm = newValue }
    }
    internal var networkInterfaceForm: NetworkInterfaceManagementForm {
        get { tui.networkInterfaceForm }
        set { tui.networkInterfaceForm = newValue }
    }
    internal var volumeManagementForm: VolumeManagementForm {
        get { tui.volumeManagementForm }
        set { tui.volumeManagementForm = newValue }
    }
    internal var serverResizeForm: ServerResizeForm {
        get { tui.serverResizeForm }
        set { tui.serverResizeForm = newValue }
    }
    internal var snapshotManagementForm: SnapshotManagementForm {
        get { tui.snapshotManagementForm }
        set { tui.snapshotManagementForm = newValue }
    }
    internal var volumeSnapshotManagementForm: VolumeSnapshotManagementForm {
        get { tui.volumeSnapshotManagementForm }
        set { tui.volumeSnapshotManagementForm = newValue }
    }

    // MARK: - Server Action Methods



}
