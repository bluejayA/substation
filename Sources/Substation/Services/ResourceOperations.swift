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

/// Service layer for OpenStack resource CRUD operations
///
/// This service encapsulates all create, read, update, and delete operations
/// for OpenStack resources, providing a clean API for the TUI.
@MainActor
final class ResourceOperations {
    private let tui: TUI

    init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Convenience Accessors

    private var client: OSClient { tui.client }
    private var dataManager: DataManager { tui.dataManager }
    private var errorHandler: OperationErrorHandler { tui.errorHandler }
    private var validator: ValidationService { tui.validator }
    private var statusMessage: String? {
        get { tui.statusMessage }
        set { tui.statusMessage = newValue }
    }
    private var currentView: ViewMode {
        get { tui.currentView }
        set { tui.currentView = newValue }
    }
    private var searchQuery: String? { tui.searchQuery }
    private var selectedIndex: Int {
        get { tui.selectedIndex }
        set { tui.selectedIndex = newValue }
    }
    private var screenRows: Int32 { tui.screenRows }
    private var screenCols: Int32 { tui.screenCols }
    private var resourceResolver: ResourceResolver { tui.resourceResolver }

    // Cache accessors
    private var cachedServers: [Server] {
        get { tui.cachedServers }
        set { tui.cachedServers = newValue }
    }
    private var cachedNetworks: [Network] {
        get { tui.cachedNetworks }
        set { tui.cachedNetworks = newValue }
    }
    private var cachedSubnets: [Subnet] {
        get { tui.cachedSubnets }
        set { tui.cachedSubnets = newValue }
    }
    private var cachedPorts: [Port] {
        get { tui.cachedPorts }
        set { tui.cachedPorts = newValue }
    }
    private var cachedRouters: [Router] {
        get { tui.cachedRouters }
        set { tui.cachedRouters = newValue }
    }
    private var cachedFloatingIPs: [FloatingIP] {
        get { tui.cachedFloatingIPs }
        set { tui.cachedFloatingIPs = newValue }
    }
    private var cachedVolumes: [Volume] {
        get { tui.cachedVolumes }
        set { tui.cachedVolumes = newValue }
    }
    private var cachedVolumeSnapshots: [VolumeSnapshot] {
        get { tui.cachedVolumeSnapshots }
        set { tui.cachedVolumeSnapshots = newValue }
    }
    private var cachedKeyPairs: [KeyPair] {
        get { tui.cachedKeyPairs }
        set { tui.cachedKeyPairs = newValue }
    }
    private var cachedSecrets: [Secret] {
        get { tui.cachedSecrets }
        set { tui.cachedSecrets = newValue }
    }
    private var cachedImages: [Image] {
        get { tui.cachedImages }
        set { tui.cachedImages = newValue }
    }
    private var cachedServerGroups: [ServerGroup] {
        get { tui.cachedServerGroups }
        set { tui.cachedServerGroups = newValue }
    }
    private var cachedSecurityGroups: [SecurityGroup] {
        get { tui.cachedSecurityGroups }
        set { tui.cachedSecurityGroups = newValue }
    }
    private var cachedFlavors: [Flavor] { tui.cachedFlavors }
    private var cachedVolumeTypes: [VolumeType] { tui.cachedVolumeTypes }
    private var cachedQoSPolicies: [QoSPolicy] { tui.cachedQoSPolicies }

    // Form accessors
    private var serverCreateForm: ServerCreateForm {
        get { tui.serverCreateForm }
        set { tui.serverCreateForm = newValue }
    }
    private var keyPairCreateForm: KeyPairCreateForm {
        get { tui.keyPairCreateForm }
        set { tui.keyPairCreateForm = newValue }
    }
    private var volumeCreateForm: VolumeCreateForm {
        get { tui.volumeCreateForm }
        set { tui.volumeCreateForm = newValue }
    }
    private var networkCreateForm: NetworkCreateForm {
        get { tui.networkCreateForm }
        set { tui.networkCreateForm = newValue }
    }
    private var subnetCreateForm: SubnetCreateForm {
        get { tui.subnetCreateForm }
        set { tui.subnetCreateForm = newValue }
    }
    private var routerCreateForm: RouterCreateForm {
        get { tui.routerCreateForm }
        set { tui.routerCreateForm = newValue }
    }
    private var portCreateForm: PortCreateForm {
        get { tui.portCreateForm }
        set { tui.portCreateForm = newValue }
    }
    private var floatingIPCreateForm: FloatingIPCreateForm {
        get { tui.floatingIPCreateForm }
        set { tui.floatingIPCreateForm = newValue }
    }
    private var serverGroupCreateForm: ServerGroupCreateForm {
        get { tui.serverGroupCreateForm }
        set { tui.serverGroupCreateForm = newValue }
    }
    private var securityGroupCreateForm: SecurityGroupCreateForm {
        get { tui.securityGroupCreateForm }
        set { tui.securityGroupCreateForm = newValue }
    }
    private var snapshotManagementForm: SnapshotManagementForm {
        get { tui.snapshotManagementForm }
        set { tui.snapshotManagementForm = newValue }
    }
    private var volumeSnapshotManagementForm: VolumeSnapshotManagementForm {
        get { tui.volumeSnapshotManagementForm }
        set { tui.volumeSnapshotManagementForm = newValue }
    }
    private var selectedSnapshotsForDeletion: Set<String> {
        get { tui.selectedSnapshotsForDeletion }
        set { tui.selectedSnapshotsForDeletion = newValue }
    }
    private var selectedResource: Any? {
        get { tui.selectedResource }
        set { tui.selectedResource = newValue }
    }
    private var resourceCounts: ResourceCounts {
        get { tui.resourceCounts }
        set { tui.resourceCounts = newValue }
    }
    private var lastRefresh: Date {
        get { tui.lastRefresh }
        set { tui.lastRefresh = newValue }
    }

    // MARK: - CRUD Operations

    internal func createServer() async {
        // Validation
        guard !serverCreateForm.serverName.isEmpty else {
            statusMessage = "Server name is required"
            return
        }

        // Parse and validate maxServers
        guard let maxServersCount = Int(serverCreateForm.maxServers.trimmingCharacters(in: .whitespacesAndNewlines)), maxServersCount >= 1 else {
            statusMessage = "Max servers must be a valid number >= 1"
            return
        }

        // Validate boot source requirements
        var selectedBootSourceId: String = ""
        switch serverCreateForm.bootSource {
        case .image:
            guard let selectedImageId = serverCreateForm.selectedImageID else {
                statusMessage = "Please select an image"
                return
            }
            selectedBootSourceId = selectedImageId
        case .volume:
            guard let selectedVolumeId = serverCreateForm.selectedVolumeID else {
                statusMessage = "Please select a bootable volume"
                return
            }
            selectedBootSourceId = selectedVolumeId
        }

        guard let selectedFlavorId = serverCreateForm.selectedFlavorID else {
            statusMessage = "Please select a flavor"
            return
        }

        guard let selectedFlavor = cachedFlavors.first(where: { $0.id == selectedFlavorId }) else {
            statusMessage = "Selected flavor not found"
            return
        }

        // Get selected network and key pair (optional)
        let selectedNetworkId = serverCreateForm.selectedNetworks.first
        let selectedKeyPairName = serverCreateForm.selectedKeyPairName
        let _ = serverCreateForm.selectedServerGroupID // TODO: Server group support not implemented yet

        // Use the base server name - Nova will append -0, -1, -2, etc. automatically when maxCount > 1
        let serverName = serverCreateForm.serverName

        statusMessage = maxServersCount > 1 ? "Creating \(maxServersCount) servers..." : "Creating server..."

        do {
            let newServer: Server

            switch serverCreateForm.bootSource {
            case .image:
                // Build networks array from selected networks
                let networks: [NetworkRequest]? = if let networkId = selectedNetworkId {
                    [NetworkRequest(uuid: networkId, port: nil, fixedIp: nil)]
                } else {
                    nil
                }

                // Build security groups array
                let securityGroups: [SecurityGroupRef]? = if !serverCreateForm.selectedSecurityGroups.isEmpty {
                    serverCreateForm.selectedSecurityGroups.map { SecurityGroupRef(name: $0) }
                } else {
                    nil
                }

                // Create the request with minCount and maxCount for bulk operations
                let request = CreateServerRequest(
                    name: serverName,
                    imageRef: selectedBootSourceId,
                    flavorRef: selectedFlavor.id,
                    metadata: nil,
                    personality: nil,
                    securityGroups: securityGroups,
                    userData: nil,
                    availabilityZone: nil,
                    networks: networks,
                    keyName: selectedKeyPairName,
                    adminPass: nil,
                    minCount: maxServersCount,
                    maxCount: maxServersCount,
                    returnReservationId: nil,
                    serverGroup: nil,
                    blockDeviceMapping: nil
                )
                newServer = try await client.createServer(request: request)

            case .volume:
                // Use proper block device mapping for volume boot
                guard let selectedVolume = cachedVolumes.first(where: { $0.id == selectedBootSourceId }) else {
                    statusMessage = "Selected volume not found"
                    return
                }

                let blockDeviceMapping = [
                    BlockDeviceMapping(
                        sourceType: "volume",
                        destinationType: "volume",
                        bootIndex: 0, // Primary boot device
                        uuid: selectedVolume.id,
                        volumeSize: nil as Int?, // Use existing volume size
                        deleteOnTermination: false // Preserve volume when server is deleted
                    )
                ]

                // Build networks array from selected networks
                let networks: [NetworkRequest]? = if let networkId = selectedNetworkId {
                    [NetworkRequest(uuid: networkId, port: nil, fixedIp: nil)]
                } else {
                    nil
                }

                // Build security groups array
                let securityGroups: [SecurityGroupRef]? = if !serverCreateForm.selectedSecurityGroups.isEmpty {
                    serverCreateForm.selectedSecurityGroups.map { SecurityGroupRef(name: $0) }
                } else {
                    nil
                }

                // Create the request with minCount and maxCount for bulk operations
                let request = CreateServerRequest(
                    name: serverName,
                    imageRef: nil, // No image when booting from volume
                    flavorRef: selectedFlavor.id,
                    metadata: nil,
                    personality: nil,
                    securityGroups: securityGroups,
                    userData: nil,
                    availabilityZone: nil,
                    networks: networks,
                    keyName: selectedKeyPairName,
                    adminPass: nil,
                    minCount: maxServersCount,
                    maxCount: maxServersCount,
                    returnReservationId: nil,
                    serverGroup: nil,
                    blockDeviceMapping: blockDeviceMapping
                )
                newServer = try await client.createServer(request: request)
            }

            // Add to cached servers and refresh
            cachedServers.append(newServer)
            let successMessage = maxServersCount > 1
                ? "Started creation of \(maxServersCount) servers with name pattern '\(serverName)-N'"
                : "Server '\(serverCreateForm.serverName)' created successfully"
            statusMessage = successMessage

            // Return to servers view
            tui.changeView(to: .servers, resetSelection: false)

            // Refresh data to get updated server list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create server"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Compute service endpoint not found - check cloud config"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response - server may be overloaded"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP \(code) - check image/flavor/network availability"
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch let decodingError as DecodingError {
            let baseMsg = "Failed to create server"
            switch decodingError {
            case .dataCorrupted(let context):
                statusMessage = "\(baseMsg): Data corrupted - \(context.debugDescription)"
            case .keyNotFound(let key, _):
                statusMessage = "\(baseMsg): Missing key '\(key.stringValue)' in response"
            case .typeMismatch(let type, let context):
                statusMessage = "\(baseMsg): Type mismatch for \(type) - \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                statusMessage = "\(baseMsg): Missing value for \(type) - \(context.debugDescription)"
            @unknown default:
                statusMessage = "\(baseMsg): JSON parsing error - \(decodingError.localizedDescription)"
            }
        } catch {
            statusMessage = "Failed to create server: \(error.localizedDescription) - Type: \(type(of: error))"
        }
    }

    internal func deleteServer(screen: OpaquePointer?) async {
        guard currentView == .servers else { return }

        let filteredServers = FilterUtils.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
        guard selectedIndex < filteredServers.count else {
            statusMessage = "No server selected"
            return
        }

        let server = filteredServers[selectedIndex]
        let serverName = server.name ?? "Unnamed Server"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(serverName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Server deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting server '\(serverName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.deleteServer(id: server.id)

            // Remove from cached servers
            if let index = cachedServers.firstIndex(where: { $0.id == server.id }) {
                cachedServers.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredServers.count - 2) // -1 for removed item, -1 for 0-based
            selectedIndex = min(selectedIndex, newMaxIndex)

            statusMessage = "Server '\(serverName)' deleted successfully"

            // Refresh data to get updated server list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to delete server '\(serverName)': \(error.localizedDescription)"
        }
    }

    internal func deleteNetwork(screen: OpaquePointer?) async {
        guard currentView == .networks else { return }

        let filteredNetworks = FilterUtils.filterNetworks(cachedNetworks, query: searchQuery)
        guard selectedIndex < filteredNetworks.count else {
            statusMessage = "No network selected"
            return
        }

        let network = filteredNetworks[selectedIndex]
        let networkName = network.name

        // Confirm deletion
        guard await ViewUtils.confirmDelete(networkName ?? "Unknown Network", screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Network deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting network '\(networkName ?? "Unknown")'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.deleteNetwork(id: network.id)

            // Remove from cached networks
            if let index = cachedNetworks.firstIndex(where: { $0.id == network.id }) {
                cachedNetworks.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredNetworks.count - 2) // -1 for removed item, -1 for 0-based
            selectedIndex = min(selectedIndex, newMaxIndex)

            statusMessage = "Network '\(networkName ?? "Unknown")' deleted successfully"

            // Refresh data to get updated network list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete network '\(networkName ?? "Unknown")'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                // Add specific handling for common network deletion errors
                if code == 409 {
                    statusMessage = "\(baseMsg): Network is in use and cannot be deleted"
                } else if code == 404 {
                    statusMessage = "\(baseMsg): Network not found"
                } else {
                    statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to delete network '\(networkName ?? "Unknown")': \(error.localizedDescription)"
        }
    }

    internal func deleteSubnet(screen: OpaquePointer?) async {
        guard currentView == .subnets else { return }

        let filteredSubnets = FilterUtils.filterSubnets(cachedSubnets, query: searchQuery)
        guard selectedIndex < filteredSubnets.count else {
            statusMessage = "No subnet selected"
            return
        }

        let subnet = filteredSubnets[selectedIndex]
        let subnetName = subnet.name ?? "Unnamed subnet"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(subnetName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Subnet deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting subnet '\(subnetName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.deleteSubnet(id: subnet.id)

            // Remove from cached subnets
            if let index = cachedSubnets.firstIndex(where: { $0.id == subnet.id }) {
                cachedSubnets.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredSubnets.count - 2) // -1 for removed item, -1 for 0-based
            selectedIndex = min(selectedIndex, newMaxIndex)

            statusMessage = "Subnet '\(subnetName)' deleted successfully"

            // Refresh data to get updated subnet list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete subnet '\(subnetName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                // Add specific handling for common subnet deletion errors
                if code == 409 {
                    statusMessage = "\(baseMsg): Subnet is in use and cannot be deleted"
                } else if code == 404 {
                    statusMessage = "\(baseMsg): Subnet not found"
                } else {
                    statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to delete subnet '\(subnetName)': \(error.localizedDescription)"
        }
    }

    internal func deletePort(screen: OpaquePointer?) async {
        guard currentView == .ports else { return }

        let filteredPorts = FilterUtils.filterPorts(cachedPorts, query: searchQuery)
        guard selectedIndex < filteredPorts.count else {
            statusMessage = "No port selected"
            return
        }

        let port = filteredPorts[selectedIndex]
        let portName = port.name ?? "Unnamed port"

        // Check if port is attached to a device
        if let deviceId = port.deviceId, !deviceId.isEmpty {
            statusMessage = "Cannot delete port '\(portName)': Port is attached to device \(deviceId)"
            return
        }

        // Confirm deletion
        guard await ViewUtils.confirmDelete(portName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Port deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting port '\(portName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.deletePort(id: port.id)

            // Remove from cached ports
            if let index = cachedPorts.firstIndex(where: { $0.id == port.id }) {
                cachedPorts.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredPorts.count - 2) // -1 for removed item, -1 for 0-based
            selectedIndex = min(selectedIndex, newMaxIndex)

            statusMessage = "Port '\(portName)' deleted successfully"

            // Refresh data to get updated port list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete port '\(portName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                // Add specific handling for common port deletion errors
                if code == 409 {
                    statusMessage = "\(baseMsg): Port is in use and cannot be deleted"
                } else if code == 404 {
                    statusMessage = "\(baseMsg): Port not found"
                } else {
                    statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to delete port '\(portName)': \(error.localizedDescription)"
        }
    }

    internal func deleteRouter(screen: OpaquePointer?) async {
        guard currentView == .routers else { return }

        let filteredRouters = FilterUtils.filterRouters(cachedRouters, query: searchQuery)
        guard selectedIndex < filteredRouters.count else {
            statusMessage = "No router selected"
            return
        }

        let router = filteredRouters[selectedIndex]
        let routerName = router.name ?? "Unnamed router"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(routerName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Router deletion cancelled"
            return
        }

        // Create background operation for router deletion with dependency cleanup
        let interfaceCount = router.interfaces?.count ?? 0
        let hasGateway = router.externalGatewayInfo != nil
        let totalSteps = interfaceCount + (hasGateway ? 1 : 0) + 1 // interfaces + gateway + delete

        let operation = SwiftBackgroundOperation(
            type: .bulkDelete,
            resourceType: "router",
            itemsTotal: totalSteps
        )
        tui.swiftBackgroundOps.addOperation(operation)

        // Show status and navigate to operations view
        statusMessage = "Started cleanup and deletion of router '\(routerName)'"
        tui.changeView(to: .swiftBackgroundOperations, resetSelection: false)

        // Launch background cleanup task
        Task { @MainActor [weak self, weak operation] in
            guard let self = self, let operation = operation else { return }
            operation.status = .running
            var completedSteps = 0

            do {
                // Step 0: Fetch fresh router details to get all current interfaces
                Logger.shared.logInfo("Fetching fresh router details for cleanup")
                let freshRouter = try await self.client.getRouter(id: router.id, forceRefresh: true)

                // Update total steps based on actual interface count
                let actualInterfaceCount = freshRouter.interfaces?.count ?? 0
                let actualHasGateway = freshRouter.externalGatewayInfo != nil
                let actualTotalSteps = actualInterfaceCount + (actualHasGateway ? 1 : 0) + 1
                operation.itemsTotal = actualTotalSteps

                Logger.shared.logInfo("Router cleanup details", context: [
                    "routerId": router.id,
                    "interfaceCount": actualInterfaceCount,
                    "hasGateway": actualHasGateway,
                    "totalSteps": actualTotalSteps
                ])

                // Step 1: Remove all router interfaces (subnet detachments)
                if let interfaces = freshRouter.interfaces, !interfaces.isEmpty {
                    Logger.shared.logInfo("Removing \(interfaces.count) router interfaces")
                    for (index, interface) in interfaces.enumerated() {
                        Logger.shared.logInfo("Processing interface \(index + 1)/\(interfaces.count)", context: [
                            "subnetId": interface.subnetId ?? "nil",
                            "portId": interface.portId ?? "nil",
                            "ipAddress": interface.ipAddress ?? "nil"
                        ])

                        // Use port_id if available (more specific), otherwise subnet_id
                        if let portId = interface.portId {
                            try await self.client.removeRouterInterface(routerId: router.id, portId: portId)
                            Logger.shared.logInfo("Removed router interface using port ID: \(portId)")
                        } else if let subnetId = interface.subnetId {
                            try await self.client.removeRouterInterface(routerId: router.id, subnetId: subnetId)
                            Logger.shared.logInfo("Removed router interface using subnet ID: \(subnetId)")
                        } else {
                            Logger.shared.logWarning("Interface has neither port ID nor subnet ID, skipping")
                        }
                        completedSteps += 1
                        operation.itemsCompleted = completedSteps
                        operation.progress = Double(completedSteps) / Double(actualTotalSteps)
                    }
                } else {
                    Logger.shared.logInfo("No interfaces found on router")
                }

                // Step 2: Clear external gateway if present
                if freshRouter.externalGatewayInfo != nil {
                    Logger.shared.logInfo("Clearing external gateway for router: \(router.id)")
                    let clearGatewayRequest = UpdateRouterRequest(
                        name: nil,
                        description: nil,
                        adminStateUp: nil,
                        externalGatewayInfo: nil,
                        routes: nil
                    )
                    _ = try await self.client.updateRouter(id: router.id, request: clearGatewayRequest)
                    Logger.shared.logInfo("Cleared external gateway")
                    completedSteps += 1
                    operation.itemsCompleted = completedSteps
                    operation.progress = Double(completedSteps) / Double(actualTotalSteps)
                }

                // Step 3: Delete the router
                Logger.shared.logInfo("Deleting router: \(router.id)")
                try await self.client.deleteRouter(id: router.id)
                completedSteps += 1
                operation.itemsCompleted = completedSteps
                operation.progress = 1.0

                // Mark operation as completed
                operation.markCompleted()

                // Refresh data
                await self.tui.dataManager.refreshAllData()

                Logger.shared.logInfo("Router '\(routerName)' deleted successfully with all dependencies cleaned up")

            } catch {
                Logger.shared.logError("Failed to delete router '\(routerName)': \(error)")
                operation.itemsFailed = totalSteps - completedSteps
                operation.markFailed(error: error.localizedDescription)

                // Refresh data even on failure to show current state
                await self.tui.dataManager.refreshAllData()
            }
        }
    }

    internal func deleteFloatingIP(screen: OpaquePointer?) async {
        guard currentView == .floatingIPs else { return }

        let filteredFloatingIPs = FilterUtils.filterFloatingIPs(cachedFloatingIPs, query: searchQuery)
        guard selectedIndex < filteredFloatingIPs.count else {
            statusMessage = "No floating IP selected"
            return
        }

        let floatingIP = filteredFloatingIPs[selectedIndex]

        // Confirm deletion
        guard await ViewUtils.confirmDelete("delete floating IP \(floatingIP.floatingIpAddress ?? "Unknown")", screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Floating IP deletion cancelled"
            return
        }

        statusMessage = "Deleting floating IP..."
        await tui.draw(screen: screen)

        do {
            try await client.deleteFloatingIP(id: floatingIP.id)

            // Remove from cached floating IPs
            if let index = cachedFloatingIPs.firstIndex(where: { $0.id == floatingIP.id }) {
                cachedFloatingIPs.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredFloatingIPs.count - 2)
            selectedIndex = min(selectedIndex, newMaxIndex)

            statusMessage = "Floating IP deleted successfully"
            tui.refreshAfterOperation()
        } catch {
            statusMessage = "Failed to delete floating IP: \(error.localizedDescription)"
        }
    }

    internal func deleteVolume(screen: OpaquePointer?) async {
        guard currentView == .volumes else { return }

        let filteredVolumes = FilterUtils.filterVolumes(cachedVolumes, query: searchQuery)
        guard selectedIndex < filteredVolumes.count else {
            statusMessage = "No volume selected"
            return
        }

        let volume = filteredVolumes[selectedIndex]
        let volumeName = volume.name ?? "Unnamed Volume"

        // Check if volume is attached to any servers
        if !(volume.attachments?.isEmpty ?? true) {
            statusMessage = "Cannot delete volume '\(volumeName)': Volume is attached to server(s)"
            return
        }

        // Confirm deletion
        guard await ViewUtils.confirmDelete(volumeName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Volume deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting volume '\(volumeName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.deleteVolume(id: volume.id)

            // Remove from cached volumes
            if let index = cachedVolumes.firstIndex(where: { $0.id == volume.id }) {
                cachedVolumes.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredVolumes.count - 2) // -1 for removed item, -1 for 0-based
            selectedIndex = min(selectedIndex, newMaxIndex)

            statusMessage = "Volume '\(volumeName)' deleted successfully"

            // Refresh data to get updated volume list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete volume '\(volumeName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to delete volume '\(volumeName)': \(error.localizedDescription)"
        }
    }

    internal func createServerSnapshot(screen: OpaquePointer?) async {
        var server: Server?

        if currentView == .servers {
            // From servers list view
            let filteredServers = FilterUtils.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
            guard selectedIndex < filteredServers.count else {
                statusMessage = "No server selected"
                return
            }
            server = filteredServers[selectedIndex]
        } else if currentView == .serverDetail {
            // From server detail view - use the currently selected resource
            server = selectedResource as? Server
        }

        guard let selectedServer = server else {
            statusMessage = "No server selected for snapshot creation"
            return
        }

        // Initialize the snapshot management form and switch to the new view
        snapshotManagementForm.reset()
        snapshotManagementForm.selectedServer = selectedServer
        snapshotManagementForm.generateDefaultSnapshotName()

        // Switch to the snapshot management view
        tui.changeView(to: .serverSnapshotManagement, resetSelection: false)
    }

    internal func createVolumeSnapshot(screen: OpaquePointer?) async {
        var volume: Volume?

        if currentView == .volumes {
            // From volume list - get selected volume
            let filteredVolumes = FilterUtils.filterVolumes(cachedVolumes, query: searchQuery)
            guard selectedIndex < filteredVolumes.count else {
                statusMessage = "No volume selected for snapshot creation"
                return
            }
            volume = filteredVolumes[selectedIndex]
        } else if currentView == .volumeDetail {
            // From volume detail view - use the currently selected resource
            volume = selectedResource as? Volume
        }

        guard let selectedVolume = volume else {
            statusMessage = "No volume selected for snapshot creation"
            return
        }

        // Initialize the volume snapshot management form and switch to the new view
        volumeSnapshotManagementForm.reset()
        volumeSnapshotManagementForm.selectedVolume = selectedVolume
        volumeSnapshotManagementForm.generateDefaultSnapshotName()

        // Switch to the volume snapshot management view
        tui.changeView(to: .volumeSnapshotManagement, resetSelection: false)
    }

    internal func deleteSelectedVolumeSnapshots(screen: OpaquePointer?) async {
        guard !selectedSnapshotsForDeletion.isEmpty else {
            statusMessage = "No snapshots selected for deletion"
            return
        }

        let snapshotsToDelete = cachedVolumeSnapshots.filter { selectedSnapshotsForDeletion.contains($0.id) }
        let snapshotNames = snapshotsToDelete.map { $0.name ?? "Unnamed" }.joined(separator: ", ")

        // Confirm deletion
        guard await ViewUtils.confirmDelete("snapshots: \(snapshotNames)", screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Snapshot deletion cancelled"
            return
        }

        statusMessage = "Deleting \(selectedSnapshotsForDeletion.count) snapshots..."
        await tui.draw(screen: screen)

        var deletedCount = 0
        var errors: [String] = []

        for snapshotId in selectedSnapshotsForDeletion {
            do {
                try await client.deleteVolumeSnapshot(snapshotId: snapshotId)
                deletedCount += 1
            } catch {
                let snapshotName = snapshotsToDelete.first { $0.id == snapshotId }?.name ?? snapshotId
                errors.append("\(snapshotName): \(error.localizedDescription)")
            }
        }

        // Clear selection and reload snapshots
        selectedSnapshotsForDeletion.removeAll()
        if let volume = tui.selectedVolumeForSnapshots {
            await tui.actions.loadVolumeSnapshots(volumeId: volume.id, screen: screen)
        }

        // Update status message
        if errors.isEmpty {
            statusMessage = "Successfully deleted \(deletedCount) snapshots"
        } else {
            statusMessage = "Deleted \(deletedCount) snapshots, \(errors.count) failed"
        }

        // Reset selection if we deleted the currently selected item
        if selectedIndex >= cachedVolumeSnapshots.count {
            selectedIndex = max(0, cachedVolumeSnapshots.count - 1)
        }
    }

    internal func deleteKeyPair(screen: OpaquePointer?) async {
        guard currentView == .keyPairs else { return }

        let filteredKeyPairs = FilterUtils.filterKeyPairs(cachedKeyPairs, query: searchQuery)
        guard selectedIndex < filteredKeyPairs.count else {
            statusMessage = "No key pair selected"
            return
        }

        let keyPair = filteredKeyPairs[selectedIndex]
        let keyPairName = keyPair.name ?? "Unknown"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(keyPairName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Key pair deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting key pair '\(keyPairName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.deleteKeyPair(name: keyPairName)
            statusMessage = "Key pair '\(keyPairName)' deleted successfully"

            // Adjust selection if we deleted the last item
            let newKeyPairCount = filteredKeyPairs.count - 1
            if selectedIndex >= newKeyPairCount && newKeyPairCount > 0 {
                selectedIndex = newKeyPairCount - 1
            } else if newKeyPairCount == 0 {
                selectedIndex = 0
            }

            // Refresh keypair cache
            await dataManager.refreshKeyPairData()

            // Clear screen to remove graphical artifacts from deleted keypair
            SwiftNCurses.clear(WindowHandle(screen))
            await tui.draw(screen: screen)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete key pair '\(keyPairName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to delete key pair '\(keyPairName)': \(error.localizedDescription)"
        }
    }

    internal func deleteSecret(screen: OpaquePointer?) async {
        guard currentView == .barbicanSecrets || currentView == .barbican else { return }

        let filteredSecrets = searchQuery?.isEmpty ?? true ? cachedSecrets : cachedSecrets.filter { secret in
            (secret.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false) ||
            (secret.secretType?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false)
        }
        guard selectedIndex < filteredSecrets.count else {
            statusMessage = "No secret selected"
            return
        }

        let secret = filteredSecrets[selectedIndex]
        let secretName = secret.name ?? "Unnamed Secret"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(secretName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Secret deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting secret '\(secretName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.barbican.deleteSecret(id: secret.id)
            statusMessage = "Secret '\(secretName)' deleted successfully"

            // Adjust selection if we deleted the last item
            let newSecretCount = filteredSecrets.count - 1
            if selectedIndex >= newSecretCount && newSecretCount > 0 {
                selectedIndex = newSecretCount - 1
            } else if newSecretCount == 0 {
                selectedIndex = 0
            }

            // Refresh secrets cache
            await dataManager.refreshSecretsData()

            // Clear screen to remove graphical artifacts from deleted secret
            SwiftNCurses.clear(WindowHandle(screen))
            await tui.draw(screen: screen)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete secret '\(secretName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Encoding error - \(error.localizedDescription)"
            case .configurationError(let error):
                statusMessage = "\(baseMsg): Configuration error - \(error)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to delete secret '\(secretName)': \(error.localizedDescription)"
        }
    }

    internal func createSecret(screen: OpaquePointer?) async {
        guard currentView == .barbicanSecretCreate else { return }

        let secretName = tui.barbicanSecretCreateForm.secretName.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = tui.barbicanSecretCreateForm.payload.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show creation in progress
        statusMessage = "Creating secret '\(secretName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            let expiration = tui.barbicanSecretCreateForm.getExpirationDate()

            let request = CreateSecretRequest(
                name: secretName,
                secretType: tui.barbicanSecretCreateForm.secretType.rawValue,
                algorithm: tui.barbicanSecretCreateForm.algorithm.rawValue,
                bitLength: tui.barbicanSecretCreateForm.bitLength,
                mode: tui.barbicanSecretCreateForm.mode.rawValue,
                payload: payload,
                payloadContentType: tui.barbicanSecretCreateForm.payloadContentType.rawValue,
                payloadContentEncoding: tui.barbicanSecretCreateForm.payloadContentEncoding.rawValue,
                expiration: expiration
            )

            _ = try await client.barbican.createSecret(request: request)

            statusMessage = "Secret '\(secretName)' created successfully"

            // Refresh secrets cache and return to list
            await dataManager.refreshSecretsData()
            tui.changeView(to: .barbicanSecrets, resetSelection: false)
            tui.barbicanSecretCreateForm = BarbicanSecretCreateForm() // Reset form

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create secret '\(secretName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Encoding error - \(error.localizedDescription)"
            case .configurationError(let error):
                statusMessage = "\(baseMsg): Configuration error - \(error)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create secret '\(secretName)': \(error.localizedDescription)"
        }
    }

    internal func deleteImage(screen: OpaquePointer?) async {
        guard currentView == .images else { return }

        guard let image = tui.getSelectedImage() else {
            statusMessage = "No image selected"
            return
        }

        let imageName = image.name ?? "Unnamed Image"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(imageName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Image deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting image '\(imageName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.deleteImage(id: image.id)

            // Remove from cached images
            if let index = cachedImages.firstIndex(where: { $0.id == image.id }) {
                cachedImages.remove(at: index)
            }

            // Adjust selection if needed
            if selectedIndex >= cachedImages.count && selectedIndex > 0 {
                selectedIndex = cachedImages.count - 1
            }

            statusMessage = "Image '\(imageName)' deleted successfully"
        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete image '\(imageName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to delete image '\(imageName)': \(error.localizedDescription)"
        }
    }

    internal func submitKeyPairCreation(screen: OpaquePointer?) async {
        // Validate the form
        let validationErrors = keyPairCreateForm.validateForm()
        if !validationErrors.isEmpty {
            statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let keyPairName = keyPairCreateForm.keyPairName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show creation in progress
        statusMessage = "Creating key pair '\(keyPairName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            let trimmedKey = keyPairCreateForm.publicKey.trimmingCharacters(in: .whitespacesAndNewlines)

            // Validate and potentially fix public key format
            var formattedKey = trimmedKey

            // Check if the key is properly formatted (has spaces between components)
            let keyComponents = trimmedKey.components(separatedBy: " ")
            if keyComponents.count < 2 {
                // Key might be missing spaces - try to insert them
                if trimmedKey.starts(with: "ssh-rsa") {
                    let keyData = String(trimmedKey.dropFirst(7)) // Remove "ssh-rsa"
                    formattedKey = "ssh-rsa \(keyData)"
                } else if trimmedKey.starts(with: "ssh-ed25519") {
                    let keyData = String(trimmedKey.dropFirst(11)) // Remove "ssh-ed25519"
                    formattedKey = "ssh-ed25519 \(keyData)"
                } else if trimmedKey.starts(with: "ecdsa-sha2-nistp256") {
                    let keyData = String(trimmedKey.dropFirst(19)) // Remove "ecdsa-sha2-nistp256"
                    formattedKey = "ecdsa-sha2-nistp256 \(keyData)"
                } else if trimmedKey.starts(with: "ecdsa-sha2-nistp384") {
                    let keyData = String(trimmedKey.dropFirst(19)) // Remove "ecdsa-sha2-nistp384"
                    formattedKey = "ecdsa-sha2-nistp384 \(keyData)"
                } else if trimmedKey.starts(with: "ecdsa-sha2-nistp521") {
                    let keyData = String(trimmedKey.dropFirst(19)) // Remove "ecdsa-sha2-nistp521"
                    formattedKey = "ecdsa-sha2-nistp521 \(keyData)"
                } else if trimmedKey.starts(with: "ssh-dss") {
                    let keyData = String(trimmedKey.dropFirst(7)) // Remove "ssh-dss"
                    formattedKey = "ssh-dss \(keyData)"
                }
            }

            // Additional validation
            let components = formattedKey.components(separatedBy: " ")
            if components.count >= 2 {
                let keyData = components[1]
                // Validate minimum key lengths for different types
                if formattedKey.starts(with: "ssh-ed25519") && keyData.count < 68 {
                    statusMessage = "WARNING - ed25519 key data seems too short (expected ~68 chars, got \(keyData.count))"
                } else if formattedKey.starts(with: "ssh-rsa") && keyData.count < 300 {
                    statusMessage = "WARNING - RSA key data seems too short (expected ~300+ chars, got \(keyData.count))"
                }
            } else {
                statusMessage = "Invalid public key format"
                return
            }

            _ = try await client.createKeyPair(
                name: keyPairName,
                publicKey: formattedKey
            )

            statusMessage = "Key pair '\(keyPairName)' created successfully"

            // Refresh keypair cache and return to list
            await dataManager.refreshAllData()
            tui.changeView(to: .keyPairs, resetSelection: false)
            await tui.draw(screen: screen)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create key pair '\(keyPairName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create key pair '\(keyPairName)': \(error.localizedDescription)"
        }
    }

    internal func submitVolumeCreation(screen: OpaquePointer?) async {
        // Validate the form
        let validationErrors = volumeCreateForm.validate()
        if !validationErrors.isEmpty {
            statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let volumeNameBase = volumeCreateForm.volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let volumeSizeString = volumeCreateForm.volumeSize.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse and validate maxVolumes
        guard let maxVolumesCount = Int(volumeCreateForm.maxVolumes.trimmingCharacters(in: .whitespacesAndNewlines)), maxVolumesCount >= 1 else {
            statusMessage = "Max volumes must be a valid number >= 1"
            return
        }

        // Convert volume size to integer
        guard let volumeSize = Int(volumeSizeString), volumeSize > 0 else {
            statusMessage = "Invalid volume size: must be a positive integer"
            return
        }

        // Show creation in progress
        statusMessage = maxVolumesCount > 1 ? "Creating \(maxVolumesCount) volumes..." : "Creating volume '\(volumeNameBase)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            // Create volumes with indexed names if maxVolumesCount > 1
            for i in 0..<maxVolumesCount {
                let volumeName = maxVolumesCount > 1 ? "\(volumeNameBase)-\(i)" : volumeNameBase

                switch volumeCreateForm.sourceType {
                case .blank:
                    // Use the selected volume type ID from the form
                    let volumeTypeId = volumeCreateForm.selectedVolumeTypeID

                    _ = try await client.createBlankVolume(
                        name: volumeName,
                        size: volumeSize,
                        volumeType: volumeTypeId
                    )

                case .image:
                    guard let selectedImageID = volumeCreateForm.selectedImageID,
                          cachedImages.contains(where: { $0.id == selectedImageID }) else {
                        statusMessage = "Please select an image to create volume from"
                        return
                    }

                    // Use the selected volume type ID from the form
                    let volumeTypeId = volumeCreateForm.selectedVolumeTypeID

                    _ = try await client.createVolumeFromImage(
                        name: volumeName,
                        size: volumeSize,
                        imageRef: selectedImageID,
                        volumeType: volumeTypeId
                    )

                case .snapshot:
                    guard let selectedSnapshotID = volumeCreateForm.selectedSnapshotID,
                          cachedVolumeSnapshots.contains(where: { $0.id == selectedSnapshotID }) else {
                        statusMessage = "Please select a snapshot to create volume from"
                        return
                    }

                    // Use the selected volume type ID from the form
                    let volumeTypeId = volumeCreateForm.selectedVolumeTypeID

                    _ = try await client.createVolumeFromSnapshot(
                        name: volumeName,
                        size: volumeSize,
                        snapshotId: selectedSnapshotID,
                        volumeType: volumeTypeId
                    )
                }
            }

            let successMessage = maxVolumesCount > 1
                ? "Created \(maxVolumesCount) volumes with name pattern '\(volumeNameBase)-N'"
                : "Volume '\(volumeNameBase)' created successfully"
            statusMessage = successMessage

            // Refresh volume cache and return to list
            await dataManager.refreshVolumeData()
            tui.changeView(to: .volumes, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create volume '\(volumeNameBase)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create volume '\(volumeNameBase)': \(error.localizedDescription)"
        }
    }

    internal func submitPortCreation(screen: OpaquePointer?) async {
        // Validate the form
        let validationErrors = portCreateForm.validate(networks: cachedNetworks, securityGroups: cachedSecurityGroups)
        if !validationErrors.isEmpty {
            statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let portName = portCreateForm.getTrimmedName()
        let description = portCreateForm.getTrimmedDescription()
        let _ = portCreateForm.getTrimmedMacAddress()  // Not used in current API

        // Get selected network
        guard portCreateForm.selectedNetworkIndex >= 0,
              portCreateForm.selectedNetworkIndex < cachedNetworks.count else {
            statusMessage = "Please select a network for the port"
            return
        }

        let selectedNetwork = cachedNetworks[portCreateForm.selectedNetworkIndex]

        // Show creation in progress
        statusMessage = "Creating port '\(portName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            // Prepare security groups if port security is enabled
            var securityGroupIds: [String]? = nil
            if portCreateForm.portSecurityEnabled && !portCreateForm.selectedSecurityGroupIndices.isEmpty {
                securityGroupIds = portCreateForm.getSelectedSecurityGroupIds(securityGroups: cachedSecurityGroups)
            }

            // Prepare QoS policy if enabled
            var qosPolicyId: String? = nil
            if portCreateForm.qosPolicyEnabled && !cachedQoSPolicies.isEmpty && portCreateForm.selectedQosPolicyIndex < cachedQoSPolicies.count {
                qosPolicyId = cachedQoSPolicies[portCreateForm.selectedQosPolicyIndex].id
            }

            // Create the port
            _ = try await client.createPort(
                name: portName,
                description: description.isEmpty ? nil : description,
                networkID: selectedNetwork.id,
                subnetID: nil,
                securityGroups: securityGroupIds,
                qosPolicyID: qosPolicyId
            )

            statusMessage = "Port '\(portName)' created successfully"

            // Refresh port cache and return to list
            await dataManager.refreshPortData()
            tui.changeView(to: .ports, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create port '\(portName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create port '\(portName)': \(error.localizedDescription)"
        }
    }

    internal func submitFloatingIPCreation(screen: OpaquePointer?) async {
        // Validate the form
        let externalNetworks = cachedNetworks.filter { $0.external == true }
        let validationErrors = floatingIPCreateForm.validateForm()
        if !validationErrors.isEmpty {
            statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        // Get selected external network
        guard let externalNetworkId = floatingIPCreateForm.getSelectedExternalNetworkId(externalNetworks: externalNetworks) else {
            statusMessage = "Please select an external network for the floating IP"
            return
        }

        // Get optional subnet and QoS policy
        let selectedSubnetId = floatingIPCreateForm.getSelectedSubnetId(externalNetworks: externalNetworks, subnets: cachedSubnets)
        let _ = floatingIPCreateForm.getSelectedQosPolicyId(qosPolicies: cachedQoSPolicies)  // QoS not supported in current API
        let description = floatingIPCreateForm.getTrimmedDescription()
        let trimmedDescription = description.isEmpty ? nil : description

        // Show creation in progress
        statusMessage = "Creating floating IP..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            // Create the floating IP with all selected parameters
            _ = try await client.createFloatingIP(
                networkID: externalNetworkId,
                portID: nil,  // Not associating with a port during creation
                subnetID: selectedSubnetId,
                description: trimmedDescription
            )

            statusMessage = "Floating IP created successfully"

            // Refresh floating IP cache and return to list
            await dataManager.refreshAllData()
            lastRefresh = Date()
            tui.changeView(to: .floatingIPs, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create floating IP"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create floating IP: \(error.localizedDescription)"
        }
    }

    internal func submitNetworkCreation(screen: OpaquePointer?) async {
        // Validate the form
        let validationErrors = networkCreateForm.validateForm()
        if !validationErrors.isEmpty {
            statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let networkName = networkCreateForm.getTrimmedName()

        // Show creation in progress
        statusMessage = "Creating network '\(networkName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            // Collect all form data
            let description = networkCreateForm.getTrimmedDescription()
            let _ = networkCreateForm.getMTUValue()  // MTU not supported in current API
            let _ = networkCreateForm.portSecurityEnabled  // Port security not supported in current API

            // Use the createNetwork API
            _ = try await client.createNetwork(
                name: networkName,
                description: description.isEmpty ? nil : description
            )

            statusMessage = "Network '\(networkName)' created successfully"

            // Reset form and FormBuilderState after successful creation
            tui.networkCreateForm = NetworkCreateForm()
            tui.networkCreateFormState = FormBuilderState(fields: [])

            // Refresh network cache immediately before returning to list
            await dataManager.refreshAllData()
            lastRefresh = Date()
            tui.changeView(to: .networks, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create network '\(networkName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create network '\(networkName)': \(error.localizedDescription)"
        }
    }

    internal func submitSecurityGroupCreation(screen: OpaquePointer?) async {
        // Validate the form
        let validation = securityGroupCreateForm.validateForm()
        if !validation.isValid {
            statusMessage = "Validation errors: \(validation.errors.joined(separator: "; "))"
            return
        }

        let securityGroupName = securityGroupCreateForm.securityGroupName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show creation in progress
        statusMessage = "Creating security group '\(securityGroupName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            // Collect all form data
            let description = securityGroupCreateForm.securityGroupDescription.trimmingCharacters(in: .whitespacesAndNewlines)

            // Create security group using the API
            _ = try await client.createSecurityGroup(
                name: securityGroupName,
                description: description.isEmpty ? nil : description
            )

            statusMessage = "Security group '\(securityGroupName)' created successfully"

            // Refresh security group cache and return to list
            tui.refreshAfterOperation()
            tui.changeView(to: .securityGroups, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create security group '\(securityGroupName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create security group '\(securityGroupName)': \(error.localizedDescription)"
        }
    }

    internal func submitSubnetCreation(screen: OpaquePointer?) async {
        // Validate the form
        let validationErrors = subnetCreateForm.validate(availableNetworks: cachedNetworks)
        if !validationErrors.isEmpty {
            statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let subnetName = subnetCreateForm.getTrimmedName()

        // Show creation in progress
        statusMessage = "Creating subnet '\(subnetName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            // Collect all form data - use selected network ID
            guard let networkId = subnetCreateForm.selectedNetworkID else {
                statusMessage = "Failed to create subnet: No network selected"
                return
            }

            let ipVersion = subnetCreateForm.getIPVersionInt()
            let cidr = subnetCreateForm.getTrimmedCIDR()
            let enableDhcp = subnetCreateForm.dhcpEnabled
            let _ = subnetCreateForm.getTrimmedAllocationPools()  // Allocation pools not supported in current API

            // Parse DNS nameservers from comma-separated string
            let dnsString = subnetCreateForm.getTrimmedDNS()
            let dnsNameservers: [String]? = if !dnsString.isEmpty {
                dnsString.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else {
                nil
            }

            let _ = subnetCreateForm.getTrimmedHostRoutes()  // Host routes not supported in current API

            // Determine gateway IP
            // - nil means auto-assign gateway (default behavior)
            // - We don't support manually specifying a gateway IP yet
            // - To disable gateway, we would need to send explicit null in JSON
            let gatewayIP: String? = nil  // Let OpenStack auto-assign for now

            // Use the createSubnet API
            _ = try await client.createSubnet(
                name: subnetName,
                networkID: networkId,
                cidr: cidr,
                ipVersion: ipVersion,
                gatewayIP: gatewayIP,
                dnsNameservers: dnsNameservers,
                enableDhcp: enableDhcp
            )

            statusMessage = "Subnet '\(subnetName)' created successfully"

            // Refresh subnet cache and return to list
            tui.refreshAfterOperation()
            tui.changeView(to: .subnets, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create subnet '\(subnetName)'"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
                    case .networkError(let error):
                        statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                    case .decodingError(let error):
                        statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                    case .encodingError(let error):
                        statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                    case .configurationError(let message):
                        statusMessage = "\(baseMsg): Configuration error - \(message)"
                    case .performanceEnhancementsNotAvailable:
                        statusMessage = "\(baseMsg): Performance enhancements not available"
                    case .missingRequiredField(let field):
                        statusMessage = "\(baseMsg): Missing required field: \(field)"
                    case .invalidResponse:
                        statusMessage = "\(baseMsg): Invalid response from server"
                    case .invalidURL:
                        statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create subnet '\(subnetName)': \(error.localizedDescription)"
        }
    }

    internal func updateResourceCounts() {
        let startTime = Date().timeIntervalSinceReferenceDate

        // Update basic counts (fast operations)
        resourceCounts.servers = cachedServers.count
        resourceCounts.serverGroups = cachedServerGroups.count
        resourceCounts.networks = cachedNetworks.count
        resourceCounts.securityGroups = cachedSecurityGroups.count
        resourceCounts.volumes = cachedVolumes.count
        resourceCounts.images = cachedImages.count
        resourceCounts.keyPairs = cachedKeyPairs.count
        resourceCounts.ports = cachedPorts.count
        resourceCounts.routers = cachedRouters.count
        resourceCounts.subnets = cachedSubnets.count

        // For very large datasets, skip detailed server status counting to prevent hangs
        if cachedServers.count > 500 {
            // Use estimates for large datasets to prevent performance issues
            resourceCounts.activeServers = Int(Double(cachedServers.count) * 0.8) // Assume 80% active
            resourceCounts.errorServers = Int(Double(cachedServers.count) * 0.05) // Assume 5% errors

            Logger.shared.logDebug("Using estimated server counts for \(cachedServers.count) servers (performance optimization)")
        } else {
            // For smaller datasets, do actual counting
            var activeCount = 0
            var errorCount = 0

            for server in cachedServers {
                if let status = server.status?.lowercased() {
                    if status == "active" {
                        activeCount += 1
                    } else if status.contains("error") || status.contains("fault") {
                        errorCount += 1
                    }
                }
            }

            resourceCounts.activeServers = activeCount
            resourceCounts.errorServers = errorCount
        }

        let endTime = Date().timeIntervalSinceReferenceDate
        let duration = (endTime - startTime) * 1000 // Convert to milliseconds

        if duration > 10 { // Log if resource counting takes more than 10ms
            Logger.shared.logDebug("updateResourceCounts() took \(String(format: "%.1f", duration))ms for \(cachedServers.count) servers")
        }
    }

    internal func submitRouterCreation(screen: OpaquePointer?) async {
        let errors = routerCreateForm.validateForm(availabilityZones: dataManager.availabilityZones, externalNetworks: dataManager.externalNetworks)
        guard errors.isEmpty else {
            return
        }

        do {
            let externalNetworkId = routerCreateForm.selectedExternalNetworkId
            let _ = try await client.createRouter(
                name: routerCreateForm.getTrimmedName(),
                description: routerCreateForm.getTrimmedDescription().isEmpty ? nil : routerCreateForm.getTrimmedDescription(),
                adminStateUp: true,
                externalGatewayInfo: externalNetworkId
            )

            Logger.shared.logInfo("Router '\(routerCreateForm.getTrimmedName())' created successfully")
            await dataManager.refreshRouterData()
            currentView = .routers
            routerCreateForm = RouterCreateForm()
            tui.routerCreateFormState = FormBuilderState(fields: [])
            await tui.draw(screen: screen)
        } catch {
            Logger.shared.logError("Failed to create router '\(routerCreateForm.getTrimmedName())': \(error.localizedDescription)")
            statusMessage = "Error: \(error.localizedDescription)"
            await tui.draw(screen: screen)
        }
    }

    internal func submitServerGroupCreation() async {
        let errors = serverGroupCreateForm.validate()
        guard errors.isEmpty else {
            statusMessage = "Validation errors: \(errors.joined(separator: ", "))"
            return
        }

        Task {
            do {
                let newServerGroup = try await client.createServerGroup(
                    name: serverGroupCreateForm.getTrimmedServerGroupName(),
                    policy: serverGroupCreateForm.selectedPolicy.rawValue
                )

                Logger.shared.logInfo("Server group '\(serverGroupCreateForm.getTrimmedServerGroupName())' created successfully")
                await dataManager.refreshServerGroupData()

                // Return to server group list and reset form
                currentView = .serverGroups
                serverGroupCreateForm = ServerGroupCreateForm()
                statusMessage = "Server group '\(newServerGroup.name ?? "Unnamed")' created successfully"
            } catch {
                Logger.shared.logError("Failed to create server group '\(serverGroupCreateForm.getTrimmedServerGroupName())': \(error.localizedDescription)")
                statusMessage = "Failed to create server group: \(error.localizedDescription)"
            }
        }
    }

    internal func deleteServerGroup(screen: OpaquePointer?) async {
        let filteredGroups = FilterUtils.filterServerGroups(cachedServerGroups, query: searchQuery)

        guard selectedIndex < filteredGroups.count else {
            statusMessage = "No server group selected"
            return
        }

        let serverGroup = filteredGroups[selectedIndex]

        // Confirm deletion
        guard await ViewUtils.confirmDelete(serverGroup.name ?? "Unknown", screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Server group deletion cancelled"
            return
        }

        do {
            statusMessage = "Deleting server group '\(serverGroup.name ?? "Unknown")'..."
            await tui.draw(screen: screen)

            try await client.deleteServerGroup(id: serverGroup.id)

            // Refresh data
            await dataManager.refreshServerGroupData()

            // Reset selection if we deleted the last item
            if selectedIndex >= cachedServerGroups.count && selectedIndex > 0 {
                selectedIndex = cachedServerGroups.count - 1
            }

            statusMessage = "Server group '\(serverGroup.name ?? "Unknown")' deleted successfully"
            Logger.shared.logInfo("Deleted server group: \(serverGroup.name ?? "Unknown")")

            // Clear screen to remove graphical artifacts from deleted server group
            SwiftNCurses.clear(WindowHandle(screen))
            await tui.draw(screen: screen)

        } catch {
            statusMessage = "Failed to delete server group: \(error.localizedDescription)"
            Logger.shared.logError("Failed to delete server group '\(serverGroup.name ?? "Unknown")': \(error.localizedDescription)")
        }
    }

    internal func deleteSecurityGroup(screen: OpaquePointer?) async {
        guard currentView == .securityGroups else { return }

        let filteredGroups = FilterUtils.filterSecurityGroups(cachedSecurityGroups, query: searchQuery)
        guard selectedIndex < filteredGroups.count else {
            statusMessage = "No security group selected"
            return
        }

        let securityGroup = filteredGroups[selectedIndex]
        let securityGroupName = securityGroup.name ?? "Unknown"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(securityGroupName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
            statusMessage = "Security group deletion cancelled"
            return
        }

        // Show deletion in progress
        statusMessage = "Deleting security group '\(securityGroupName)'..."
        tui.needsRedraw = true  // Mark for redraw instead of calling draw directly

        do {
            try await client.deleteSecurityGroup(id: securityGroup.id)

            // Remove from cached security groups
            if let index = cachedSecurityGroups.firstIndex(where: { $0.id == securityGroup.id }) {
                cachedSecurityGroups.remove(at: index)
            }

            // Adjust selection if needed
            if selectedIndex >= filteredGroups.count && selectedIndex > 0 {
                selectedIndex = filteredGroups.count - 1
            }

            statusMessage = "Security group '\(securityGroupName)' deleted successfully"
            Logger.shared.logInfo("Deleted security group: \(securityGroupName)")

        } catch {
            statusMessage = "Failed to delete security group: \(error.localizedDescription)"
            Logger.shared.logError("Failed to delete security group '\(securityGroupName)': \(error.localizedDescription)")
        }
    }

    internal func createSecurityGroupRule(screen: OpaquePointer?) async {
        guard var form = tui.securityGroupRuleManagementForm else { return }

        let validation = form.validateCurrentForm()
        guard validation.isValid else {
            statusMessage = "Validation failed: \(validation.errors.first ?? "Unknown error")"
            return
        }

        let ruleData = form.getRuleCreationData()

        statusMessage = "Creating security group rule(s)..."
        await tui.draw(screen: screen)

        do {
            // Handle multiple security groups if remote type is security group
            if form.ruleCreateForm.remoteType == .securityGroup && !form.ruleCreateForm.selectedRemoteSecurityGroups.isEmpty {
                // Create one rule for each selected security group
                for securityGroupId in form.ruleCreateForm.selectedRemoteSecurityGroups {
                    let _ = try await client.createSecurityGroupRule(
                        securityGroupId: form.securityGroup.id,
                        direction: ruleData.direction,
                        protocol: ruleData.protocol,
                        ethertype: ruleData.ethertype,
                        portRangeMin: ruleData.portMin,
                        portRangeMax: ruleData.portMax,
                        remoteIpPrefix: nil,
                        remoteGroupId: securityGroupId
                    )
                }
                statusMessage = "Created \(form.ruleCreateForm.selectedRemoteSecurityGroups.count) security group rule(s) successfully"
            } else {
                // Single rule (CIDR or single security group)
                let _ = try await client.createSecurityGroupRule(
                    securityGroupId: form.securityGroup.id,
                    direction: ruleData.direction,
                    protocol: ruleData.protocol,
                    ethertype: ruleData.ethertype,
                    portRangeMin: ruleData.portMin,
                    portRangeMax: ruleData.portMax,
                    remoteIpPrefix: ruleData.remoteIPPrefix,
                    remoteGroupId: ruleData.remoteGroupID
                )
                statusMessage = "Security group rule created successfully"
            }

            // Refresh security group data
            let updatedSecurityGroup = try await client.getSecurityGroup(id: form.securityGroup.id)
            form.updateSecurityGroup(updatedSecurityGroup)
            tui.securityGroupRuleManagementForm = form

            // Also update cached security groups
            if let index = cachedSecurityGroups.firstIndex(where: { $0.id == form.securityGroup.id }) {
                cachedSecurityGroups[index] = updatedSecurityGroup
            }

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create security group rule"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
            case .networkError(let underlyingError):
                statusMessage = "\(baseMsg): Network error - \(underlyingError.localizedDescription)"
            case .decodingError(let underlyingError):
                statusMessage = "\(baseMsg): Data parsing error - \(underlyingError.localizedDescription)"
            case .encodingError(let underlyingError):
                statusMessage = "\(baseMsg): Data encoding error - \(underlyingError.localizedDescription)"
            case .configurationError(let message):
                statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            statusMessage = "Failed to create security group rule: \(error.localizedDescription)"
        }
    }

    internal func updateSecurityGroupRule(screen: OpaquePointer?) async {
        guard tui.securityGroupRuleManagementForm != nil else { return }

        // For now, we'll delete the old rule and create a new one
        // as OpenStack doesn't typically support rule updates directly
        await deleteSecurityGroupRule(screen: screen, createNew: true)
    }

    internal func deleteSecurityGroupRule(screen: OpaquePointer?, createNew: Bool = false) async {
        guard var form = tui.securityGroupRuleManagementForm else { return }
        guard let rule = form.getSelectedRule() else {
            statusMessage = "No security group rule selected"
            return
        }

        // Confirm deletion unless this is part of an update operation
        if !createNew {
            guard await ViewUtils.confirmDelete("security group rule", screen: screen, screenRows: screenRows, screenCols: screenCols) else {
                statusMessage = "Security group rule deletion cancelled"
                return
            }
        }

        statusMessage = createNew ? "Updating security group rule..." : "Deleting security group rule..."
        await tui.draw(screen: screen)

        do {
            try await client.deleteSecurityGroupRule(id: rule.id)

            // If this is part of an update, create the new rule
            if createNew {
                await createSecurityGroupRule(screen: screen)
                return
            }

            // Refresh security group data
            let updatedSecurityGroup = try await client.getSecurityGroup(id: form.securityGroup.id)
            form.updateSecurityGroup(updatedSecurityGroup)
            tui.securityGroupRuleManagementForm = form

            // Also update cached security groups
            if let index = cachedSecurityGroups.firstIndex(where: { $0.id == form.securityGroup.id }) {
                cachedSecurityGroups[index] = updatedSecurityGroup
            }

            statusMessage = "Security group rule deleted successfully"

        } catch let error as OpenStackError {
            let baseMsg = createNew ? "Failed to update security group rule" : "Failed to delete security group rule"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Endpoint not found"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected response"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
            case .networkError(let description):
                statusMessage = "\(baseMsg): Network error - \(description)"
            case .decodingError(let description):
                statusMessage = "\(baseMsg): Decoding error - \(description)"
            case .encodingError(let description):
                statusMessage = "\(baseMsg): Encoding error - \(description)"
            case .configurationError(let description):
                statusMessage = "\(baseMsg): Configuration error - \(description)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            let baseMsg = createNew ? "update" : "delete"
            statusMessage = "Failed to \(baseMsg) security group rule: \(error.localizedDescription)"
        }
    }

    // MARK: - Swift Object Storage Operations

    internal func deleteSwiftContainer(screen: OpaquePointer?) async {
        guard currentView == .swift else { return }

        let filteredContainers = searchQuery?.isEmpty ?? true ? tui.cachedSwiftContainers : tui.cachedSwiftContainers.filter { container in
            container.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false
        }

        guard selectedIndex < filteredContainers.count else {
            statusMessage = "No container selected"
            return
        }

        let container = filteredContainers[selectedIndex]
        guard let containerName = container.name else {
            statusMessage = "Container has no name"
            return
        }

        // Check if container has objects
        let objectCount = container.count
        let hasObjects = objectCount > 0

        // Show appropriate confirmation based on whether container has objects
        let confirmed: Bool
        if hasObjects {
            confirmed = await ConfirmationModal.show(
                title: "Delete Container with Objects",
                message: "Delete '\(containerName)' and all its contents?",
                details: [
                    "This container contains \(objectCount) object(s)",
                    "All objects will be deleted first",
                    "Then the container will be deleted",
                    "This action cannot be undone"
                ],
                screen: screen,
                screenRows: screenRows,
                screenCols: screenCols
            )
        } else {
            confirmed = await ViewUtils.confirmDelete(containerName, screen: screen, screenRows: screenRows, screenCols: screenCols)
        }

        guard confirmed else {
            statusMessage = "Container deletion cancelled"
            return
        }

        // Create background operation
        let operation = SwiftBackgroundOperation(
            type: .delete,
            containerName: containerName,
            objectName: nil,
            localPath: "",
            totalBytes: 0
        )
        tui.swiftBackgroundOps.addOperation(operation)
        operation.status = .queued

        // Start background deletion task
        let deleteTask = Task { @MainActor in
            await deleteContainerInBackground(containerName: containerName, hasObjects: hasObjects, objectCount: objectCount, operation: operation)
        }
        operation.task = deleteTask

        statusMessage = "Container deletion started in background: \(containerName)"
        Logger.shared.logUserAction("container_delete_started", details: [
            "containerName": containerName,
            "hasObjects": hasObjects,
            "objectCount": objectCount
        ])
    }

    internal func deleteSwiftObject(screen: OpaquePointer?) async {
        guard currentView == .swiftContainerDetail else { return }
        guard let containerName = tui.swiftNavState.currentContainer else {
            statusMessage = "No container selected"
            return
        }
        guard let objects = tui.cachedSwiftObjects else {
            statusMessage = "No objects loaded"
            return
        }

        // Build tree items to determine if we're deleting a directory or object
        let currentPath = tui.swiftNavState.currentPathString
        let treeItems = SwiftTreeItem.buildTree(from: objects, currentPath: currentPath)
        let filteredItems = SwiftTreeItem.filterItems(treeItems, query: searchQuery)

        guard selectedIndex < filteredItems.count else {
            statusMessage = "No item selected"
            return
        }

        let selectedItem = filteredItems[selectedIndex]

        // Check if this is a directory or an object
        switch selectedItem {
        case .directory(let dirName, _, _):
            // Deleting a directory - need to delete all objects with this prefix
            let directoryPath = currentPath + dirName + "/"
            let objectsInDirectory = SwiftTreeItem.getObjectsInDirectory(
                directoryPath: directoryPath,
                allObjects: objects,
                recursive: true
            )

            guard !objectsInDirectory.isEmpty else {
                statusMessage = "Directory is empty"
                return
            }

            // Confirm directory deletion
            let confirmed = await ConfirmationModal.show(
                title: "Delete Directory",
                message: "Delete '\(dirName)' and all its contents?",
                details: [
                    "This directory contains \(objectsInDirectory.count) object(s)",
                    "All objects will be deleted",
                    "This action cannot be undone"
                ],
                screen: screen,
                screenRows: screenRows,
                screenCols: screenCols
            )

            guard confirmed else {
                statusMessage = "Directory deletion cancelled"
                return
            }

            // Create background operation for directory deletion
            let operation = SwiftBackgroundOperation(
                type: .delete,
                containerName: containerName,
                objectName: dirName,
                localPath: directoryPath,
                totalBytes: Int64(objectsInDirectory.count)
            )
            tui.swiftBackgroundOps.addOperation(operation)
            operation.status = .queued

            // Start background deletion task
            let deleteTask = Task { @MainActor in
                await deleteDirectoryInBackground(
                    containerName: containerName,
                    directoryPath: directoryPath,
                    objects: objectsInDirectory,
                    operation: operation
                )
            }
            operation.task = deleteTask

            statusMessage = "Directory deletion started in background: \(dirName)"
            Logger.shared.logUserAction("directory_delete_started", details: [
                "containerName": containerName,
                "directory": dirName,
                "objectCount": objectsInDirectory.count
            ])

        case .object(let swiftObject):
            // Deleting a single object
            guard let objectName = swiftObject.name else {
                statusMessage = "Object has no name"
                return
            }

            guard await ViewUtils.confirmDelete(objectName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
                statusMessage = "Object deletion cancelled"
                return
            }

            // Create background operation for single object deletion
            let operation = SwiftBackgroundOperation(
                type: .delete,
                containerName: containerName,
                objectName: objectName,
                localPath: "",
                totalBytes: 1
            )
            tui.swiftBackgroundOps.addOperation(operation)
            operation.status = .queued

            // Start background deletion task
            let deleteTask = Task { @MainActor in
                await deleteSingleObjectInBackground(
                    containerName: containerName,
                    objectName: objectName,
                    operation: operation
                )
            }
            operation.task = deleteTask

            statusMessage = "Object deletion started in background: \(objectName)"
            Logger.shared.logUserAction("object_delete_started", details: [
                "containerName": containerName,
                "objectName": objectName
            ])
        }
    }

    private func deleteContainerInBackground(containerName: String, hasObjects: Bool, objectCount: Int, operation: SwiftBackgroundOperation) async {
        operation.status = .running

        do {
            // If container has objects, delete them first
            if hasObjects {
                // Fetch objects
                let objects = try await client.swift.listObjects(containerName: containerName)
                let totalObjects = objects.count

                // Update operation total
                operation.totalBytes = Int64(totalObjects)

                var deletedCount = 0
                var failedCount = 0

                // Use TaskGroup for concurrent object deletion
                await withTaskGroup(of: (success: Bool, objectName: String).self) { group in
                    let maxConcurrentDeletes = 10
                    var objectIterator = objects.makeIterator()
                    var activeDeletes = 0

                    // Start initial batch
                    while activeDeletes < maxConcurrentDeletes, let object = objectIterator.next() {
                        guard let objectName = object.name else { continue }
                        group.addTask {
                            do {
                                try Task.checkCancellation()
                                try await self.client.swift.deleteObject(containerName: containerName, objectName: objectName)
                                return (success: true, objectName: objectName)
                            } catch is CancellationError {
                                return (success: false, objectName: objectName)
                            } catch {
                                Logger.shared.logError("Failed to delete object '\(objectName)': \(error)")
                                return (success: false, objectName: objectName)
                            }
                        }
                        activeDeletes += 1
                    }

                    // Process results and start new deletes
                    while let result = await group.next() {
                        // Check for cancellation
                        if operation.status == .cancelled {
                            group.cancelAll()
                            statusMessage = "Container deletion cancelled"
                            return
                        }

                        if result.success {
                            deletedCount += 1
                        } else {
                            failedCount += 1
                        }

                        // Update progress
                        operation.progress = Double(deletedCount + failedCount) / Double(totalObjects)
                        operation.bytesTransferred = Int64(deletedCount + failedCount)
                        tui.markNeedsRedraw()

                        // Start next delete if available
                        if let object = objectIterator.next() {
                            guard let objectName = object.name else { continue }
                            group.addTask {
                                do {
                                    try Task.checkCancellation()
                                    try await self.client.swift.deleteObject(containerName: containerName, objectName: objectName)
                                    return (success: true, objectName: objectName)
                                } catch is CancellationError {
                                    return (success: false, objectName: objectName)
                                } catch {
                                    Logger.shared.logError("Failed to delete object '\(objectName)': \(error)")
                                    return (success: false, objectName: objectName)
                                }
                            }
                        }
                    }
                }

                if failedCount > 0 {
                    Logger.shared.logWarning("Deleted \(deletedCount) objects, \(failedCount) failed")
                }
            }

            // Check for cancellation before deleting container
            if operation.status == .cancelled {
                statusMessage = "Container deletion cancelled"
                return
            }

            // Now delete the container
            try await client.swift.deleteContainer(containerName: containerName)

            // Mark operation as completed
            operation.markCompleted()
            operation.progress = 1.0
            statusMessage = "Container '\(containerName)' deleted successfully"
            tui.markNeedsRedraw()

            // Refresh container cache from server
            let containers = try await client.swift.listContainers()
            tui.cachedSwiftContainers = containers

            Logger.shared.logUserAction("container_deleted", details: [
                "containerName": containerName,
                "objectsDeleted": operation.bytesTransferred
            ])
        } catch {
            operation.markFailed(error: error.localizedDescription)
            statusMessage = "Failed to delete container '\(containerName)': \(error.localizedDescription)"
            tui.markNeedsRedraw()
            Logger.shared.logError("Container deletion failed: \(error)")
        }
    }

    private func deleteSingleObjectInBackground(containerName: String, objectName: String, operation: SwiftBackgroundOperation) async {
        operation.status = .running

        do {
            // Check for cancellation
            if operation.status == .cancelled {
                statusMessage = "Object deletion cancelled"
                return
            }

            try await client.swift.deleteObject(containerName: containerName, objectName: objectName)

            // Mark operation as completed
            operation.markCompleted()
            operation.progress = 1.0
            statusMessage = "Object '\(objectName)' deleted successfully"
            tui.markNeedsRedraw()

            // Refresh object cache from server
            await dataManager.fetchSwiftObjects(containerName: containerName, priority: "interactive", forceRefresh: true)

            Logger.shared.logUserAction("object_deleted", details: [
                "containerName": containerName,
                "objectName": objectName
            ])
        } catch {
            operation.markFailed(error: error.localizedDescription)
            statusMessage = "Failed to delete object '\(objectName)': \(error.localizedDescription)"
            tui.markNeedsRedraw()
            Logger.shared.logError("Object deletion failed: \(error)")
        }
    }

    private func deleteDirectoryInBackground(containerName: String, directoryPath: String, objects: [SwiftObject], operation: SwiftBackgroundOperation) async {
        operation.status = .running

        let totalObjects = objects.count
        var deletedCount = 0
        var failedCount = 0

        // Use TaskGroup for concurrent object deletion
            await withTaskGroup(of: (success: Bool, objectName: String).self) { group in
                let maxConcurrentDeletes = 10
                var objectIterator = objects.makeIterator()
                var activeDeletes = 0

                // Start initial batch
                while activeDeletes < maxConcurrentDeletes, let object = objectIterator.next() {
                    guard let objectName = object.name else { continue }
                    group.addTask {
                        do {
                            try Task.checkCancellation()
                            try await self.client.swift.deleteObject(containerName: containerName, objectName: objectName)
                            return (success: true, objectName: objectName)
                        } catch is CancellationError {
                            return (success: false, objectName: objectName)
                        } catch {
                            Logger.shared.logError("Failed to delete object '\(objectName)': \(error)")
                            return (success: false, objectName: objectName)
                        }
                    }
                    activeDeletes += 1
                }

                // Process results and start new deletes
                while let result = await group.next() {
                    // Check for cancellation
                    if operation.status == .cancelled {
                        group.cancelAll()
                        statusMessage = "Directory deletion cancelled"
                        return
                    }

                    if result.success {
                        deletedCount += 1
                    } else {
                        failedCount += 1
                    }

                    // Update progress
                    operation.progress = Double(deletedCount + failedCount) / Double(totalObjects)
                    operation.bytesTransferred = Int64(deletedCount + failedCount)
                    tui.markNeedsRedraw()

                    // Start next delete if available
                    if let object = objectIterator.next() {
                        guard let objectName = object.name else { continue }
                        group.addTask {
                            do {
                                try Task.checkCancellation()
                                try await self.client.swift.deleteObject(containerName: containerName, objectName: objectName)
                                return (success: true, objectName: objectName)
                            } catch is CancellationError {
                                return (success: false, objectName: objectName)
                            } catch {
                                Logger.shared.logError("Failed to delete object '\(objectName)': \(error)")
                                return (success: false, objectName: objectName)
                            }
                        }
                    }
                }
            }

            // Mark operation as completed
            operation.markCompleted()
            operation.progress = 1.0

            if failedCount > 0 {
                statusMessage = "Directory deleted with \(deletedCount) objects (\(failedCount) failed)"
            } else {
                statusMessage = "Directory deleted successfully (\(deletedCount) objects)"
            }

            tui.markNeedsRedraw()

            // Refresh object cache from server
            await dataManager.fetchSwiftObjects(containerName: containerName, priority: "interactive", forceRefresh: true)

            Logger.shared.logUserAction("directory_deleted", details: [
                "containerName": containerName,
                "directoryPath": directoryPath,
                "objectsDeleted": deletedCount,
                "objectsFailed": failedCount
            ])
    }

}
