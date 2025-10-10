import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftTUI
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

        let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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

        // Show deletion in progress
        statusMessage = "Deleting router '\(routerName)'..."
        await tui.draw(screen: screen) // Refresh UI to show progress message

        do {
            try await client.deleteRouter(id: router.id)

            // Remove from cached routers
            if let index = cachedRouters.firstIndex(where: { $0.id == router.id }) {
                cachedRouters.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredRouters.count - 2) // -1 for removed item, -1 for 0-based
            selectedIndex = min(selectedIndex, newMaxIndex)

            statusMessage = "Router '\(routerName)' deleted successfully"

            // Refresh data to get updated router list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete router '\(routerName)'"
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
            statusMessage = "Failed to delete router '\(routerName)': \(error.localizedDescription)"
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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
            let filteredServers = ResourceFilters.filterServers(cachedServers, query: searchQuery, getServerIP: resourceResolver.getServerIP)
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
            let filteredVolumes = ResourceFilters.filterVolumes(cachedVolumes, query: searchQuery)
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

        let filteredKeyPairs = ResourceFilters.filterKeyPairs(cachedKeyPairs, query: searchQuery)
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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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

            // Refresh network cache and return to list
            tui.refreshAfterOperation()
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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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
        await tui.draw(screen: screen) // Refresh UI to show progress message

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

}
