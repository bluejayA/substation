import Foundation
import CrossPlatformTimer
import MemoryKit
#if canImport(Combine)
import Combine
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Test Response Type

private struct EmptyTestResponse: Codable {
    // Empty response for connection testing
}

// MARK: - Main OpenStack Client

/// Consolidated OpenStack client combining core functionality with UI state management
/// Provides a single interface for all OpenStack operations with UI compatibility
@MainActor
public final class OpenStackClient: @unchecked Sendable {
    private let core: OpenStackClientCore

    // UI State Management
    public private(set) var isAuthenticated = false {
        didSet { notifyObservers() }
    }
    public private(set) var authenticationError: (any Error)? {
        didSet { notifyObservers() }
    }
    public private(set) var isConnecting = false {
        didSet { notifyObservers() }
    }
    public private(set) var timeUntilTokenExpiration: TimeInterval? {
        didSet { notifyObservers() }
    }

    private var observers: [() -> Void] = []
    private var refreshTimer: AnyObject?

    // Service clients - lazy initialization
    private var _nova: NovaService?
    private var _neutron: NeutronService?
    private var _cinder: CinderService?
    private var _keystone: KeystoneService?
    private var _barbican: BarbicanService?
    private var _glance: GlanceService?

    // Data managers - lazy initialization
    private var _serverDataManager: ServerDataManager?
    private var _networkDataManager: NetworkDataManager?
    private var _volumeDataManager: VolumeDataManager?
    private var _imageDataManager: ImageDataManager?
    private var _dataManagerFactory: ServiceDataManagerFactory?

    private init(core: OpenStackClientCore) {
        self.core = core
        startTokenExpirationTimer()
    }

    // MARK: - Observer Pattern for UI State Management

    public func addObserver(_ observer: @escaping () -> Void) {
        observers.append(observer)
    }

    private func notifyObservers() {
        for observer in observers {
            observer()
        }
    }

    /// Convenience initializer for logger-only initialization (creates placeholder config)
    public convenience init(logger: any OpenStackClientLogger) {
        // Create a placeholder configuration - this client won't be functional until properly configured
        let placeholderURL = URL(string: "https://placeholder.example.com:5000/v3")!
        let placeholderConfig = OpenStackConfig(authURL: placeholderURL)
        let placeholderCredentials = OpenStackCredentials.password(username: "", password: "", projectName: "")
        let core = OpenStackClientCore(config: placeholderConfig, credentials: placeholderCredentials, logger: logger)

        self.init(core: core)
    }

    deinit {
        // Timer will be automatically cleaned up when the class is deallocated
        // Manual cleanup is not safe in nonisolated deinit with @MainActor properties
    }

    // MARK: - Factory Method

    /// Create a new OpenStack client with the provided configuration and credentials
    public static func connect(
        config: OpenStackConfig,
        credentials: OpenStackCredentials,
        logger: any OpenStackClientLogger = ConsoleLogger(),
        enablePerformanceEnhancements: Bool = true
    ) async throws -> OpenStackClient {
        let core = OpenStackClientCore(config: config, credentials: credentials, logger: logger)
        let client = OpenStackClient(core: core)

        // Initialize performance enhancements if enabled
        if enablePerformanceEnhancements {
            await client.initializePerformanceManager(logger: logger)
        }

        // Perform connection and authentication
        await client.connect()

        return client
    }

    // MARK: - Connection Management

    public func connect() async {
        isConnecting = true
        authenticationError = nil

        do {
            // Test connectivity by attempting to authenticate
            let _: EmptyTestResponse = try await core.request(
                service: "compute",
                method: "GET",
                path: "/",
                expected: 200
            )

            self.isAuthenticated = true
            self.authenticationError = nil
            updateTokenExpiration()

        } catch {
            self.isAuthenticated = false
            self.authenticationError = error

            await core.clientLogger.logError("Failed to connect to OpenStack", context: ["error": error.localizedDescription])
        }

        isConnecting = false
    }

    public func disconnect() {
        isAuthenticated = false
        authenticationError = nil
        resetServices()
    }

    public func clearAuthCache() async {
        await core.clearCache()
        updateTokenExpiration()
    }

    // MARK: - Token Expiration Management

    private func startTokenExpirationTimer() {
        refreshTimer = createCompatibleTimer(interval: 30.0, repeats: true, action: { [weak self] in
            Task { @MainActor in
                self?.updateTokenExpiration()
            }
        })
    }

    private func updateTokenExpiration() {
        Task {
            let expiration = await core.timeUntilTokenExpiration
            self.timeUntilTokenExpiration = expiration
        }
    }

    // MARK: - Service Access with Token Refresh

    internal func executeWithTokenRefresh<T: Sendable>(_ operation: @escaping () async throws -> T) async throws -> T {
        guard isAuthenticated else {
            throw OpenStackError.authenticationFailed
        }

        do {
            return try await operation()
        } catch OpenStackError.authenticationFailed {
            // Try to reconnect once
            await connect()

            guard isAuthenticated else {
                throw OpenStackError.authenticationFailed
            }

            return try await operation()
        }
    }

    private func initializePerformanceManager(logger: any OpenStackClientLogger) async {
        logger.logInfo("Initializing OpenStack client performance monitoring", context: [:])

    }

    // MARK: - Service Access

    /// Access to Nova (Compute) service
    public var nova: NovaService {
        get async {
            if let existing = _nova {
                return existing
            }
            let service = NovaService(core: core, logger: await core.clientLogger)
            // Performance manager integration temporarily disabled
            // if let perfManager = performanceManager {
            //     await service.setPerformanceManager(perfManager)
            // }
            _nova = service
            return service
        }
    }

    /// Access to Neutron (Network) service
    public var neutron: NeutronService {
        get async {
            if let existing = _neutron {
                return existing
            }
            let service = NeutronService(core: core, logger: await core.clientLogger)
            _neutron = service
            return service
        }
    }

    /// Access to Cinder (Block Storage) service
    public var cinder: CinderService {
        get async {
            if let existing = _cinder {
                return existing
            }
            let service = CinderService(core: core)
            _cinder = service
            return service
        }
    }

    /// Access to Keystone (Identity) service
    public var keystone: KeystoneService {
        get async {
            if let existing = _keystone {
                return existing
            }
            let service = KeystoneService(core: core)
            _keystone = service
            return service
        }
    }

    /// Access to Barbican (Key Management) service
    public var barbican: BarbicanService {
        get async {
            if let existing = _barbican {
                return existing
            }
            let service = BarbicanService(core: core)
            _barbican = service
            return service
        }
    }

    /// Access to Glance (Image) service
    public var glance: GlanceService {
        get async {
            if let existing = _glance {
                return existing
            }
            let service = GlanceService(core: core)
            _glance = service
            return service
        }
    }

    // MARK: - Data Manager Access

    /// Access to the data manager factory
    public var dataManagerFactory: ServiceDataManagerFactory {
        get async {
            if let existing = _dataManagerFactory {
                return existing
            }
            let factory = await ServiceDataManagerFactory(logger: core.clientLogger, memoryManager: core.clientMemoryManager)
            _dataManagerFactory = factory
            return factory
        }
    }

    /// Access to server data manager with caching and incremental loading
    public var serverDataManager: ServerDataManager {
        get async {
            if let existing = _serverDataManager {
                return existing
            }
            let factory = await dataManagerFactory
            let manager = await factory.createServerDataManager(novaService: await nova)
            _serverDataManager = manager
            return manager
        }
    }

    /// Access to network data manager with caching and incremental loading
    public var networkDataManager: NetworkDataManager {
        get async {
            if let existing = _networkDataManager {
                return existing
            }
            let factory = await dataManagerFactory
            let manager = await factory.createNetworkDataManager(neutronService: await neutron)
            _networkDataManager = manager
            return manager
        }
    }

    /// Access to volume data manager with caching and incremental loading
    public var volumeDataManager: VolumeDataManager {
        get async {
            if let existing = _volumeDataManager {
                return existing
            }
            let factory = await dataManagerFactory
            let manager = await factory.createVolumeDataManager(cinderService: await cinder)
            _volumeDataManager = manager
            return manager
        }
    }

    /// Access to image data manager with caching and incremental loading
    public var imageDataManager: ImageDataManager {
        get async {
            if let existing = _imageDataManager {
                return existing
            }
            let factory = await dataManagerFactory
            let manager = await factory.createImageDataManager(glanceService: await glance)
            _imageDataManager = manager
            return manager
        }
    }

    // MARK: - Configuration Access

    /// The configured region for this client
    public var region: String {
        get async {
            await core.clientConfig.region
        }
    }

    /// The configured project domain name for this client
    public var projectDomainName: String {
        get async {
            await core.clientConfig.projectDomainName
        }
    }

    /// The configured project name for this client
    public var projectName: String? {
        get async {
            switch await core.clientCredentials {
            case .password(_, _, let projectName, _, _, _, _, _):
                return projectName
            case .applicationCredential(_, _, let projectName, _):
                return projectName
            }
        }
    }

    /// The project ID for this client (if available)
    public var projectID: String? {
        get async {
            // Get project ID from the core authentication token
            await core.projectId
        }
    }

    /// The project name for this client (backward compatibility)
    public var project: String {
        get async {
            await projectName ?? ""
        }
    }

    // MARK: - Core API Methods (from SecureOpenStackClient and OSClientAdapter)

    /// List all servers in the project
    public func listServers(forceRefresh: Bool = false) async throws -> [Server] {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            let response = try await nova.listServers(forceRefresh: forceRefresh)
            return response.servers
        }
    }

    /// Get a specific server by ID
    public func getServer(id: String) async throws -> Server {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.getServer(id: id)
        }
    }

    /// List all flavors available
    public func listFlavors(forceRefresh: Bool = false) async throws -> [Flavor] {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.listFlavors(forceRefresh: forceRefresh)
        }
    }

    /// List all images available
    public func listImages() async throws -> [Image] {
        return try await executeWithTokenRefresh {
            let glance = await self.glance
            return try await glance.listImages()
        }
    }

    /// List all networks in the project
    public func listNetworks(forceRefresh: Bool = false) async throws -> [Network] {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.listNetworks(forceRefresh: forceRefresh)
        }
    }

    /// List all subnets in the project
    public func listSubnets(forceRefresh: Bool = false) async throws -> [Subnet] {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.listSubnets(forceRefresh: forceRefresh)
        }
    }

    /// List all ports in the project
    public func listPorts(forceRefresh: Bool = false) async throws -> [Port] {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.listPorts(forceRefresh: forceRefresh)
        }
    }

    /// List all floating IPs in the project
    public func listFloatingIPs(forceRefresh: Bool = false) async throws -> [FloatingIP] {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.listFloatingIPs(forceRefresh: forceRefresh)
        }
    }

    /// List all volumes in the project
    public func listVolumes() async throws -> [Volume] {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            return try await cinder.listVolumes()
        }
    }

    /// List all key pairs in the project
    public func listKeyPairs(forceRefresh: Bool = false) async throws -> [KeyPair] {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.listKeyPairs(forceRefresh: forceRefresh)
        }
    }

    /// List all server groups in the project
    public func listServerGroups(forceRefresh: Bool = false) async throws -> [ServerGroup] {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.listServerGroups(forceRefresh: forceRefresh)
        }
    }

    /// List all security groups in the project
    public func listSecurityGroups(forceRefresh: Bool = false) async throws -> [SecurityGroup] {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.listSecurityGroups(forceRefresh: forceRefresh)
        }
    }

    /// List all routers in the project
    public func listRouters(forceRefresh: Bool = false) async throws -> [Router] {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.listRouters(forceRefresh: forceRefresh)
        }
    }

    /// List all volume types available
    public func listVolumeTypes() async throws -> [VolumeType] {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            return try await cinder.listVolumeTypes()
        }
    }

    /// List all availability zones
    public func listAvailabilityZones() async throws -> [AvailabilityZone] {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.listAvailabilityZones()
        }
    }

    // MARK: - Server Management Operations

    /// Create a new server
    public func createServer(request: CreateServerRequest) async throws -> Server {
        return try await executeWithTokenRefresh {
            let nova = await self.nova
            return try await nova.createServer(request: request)
        }
    }

    /// Create a new server with simplified parameters
    public func createServer(name: String, imageRef: String?, flavorRef: String, networkId: String?, keyName: String? = nil, userData: String? = nil, securityGroups: [String]? = nil, availabilityZone: String? = nil, blockDeviceMappings: [BlockDeviceMapping]? = nil) async throws -> Server {
        let networks: [NetworkRequest]? = networkId.map { [NetworkRequest(uuid: $0, port: nil, fixedIp: nil)] }
        let request = CreateServerRequest(
            name: name,
            imageRef: imageRef,
            flavorRef: flavorRef,
            securityGroups: securityGroups?.map { SecurityGroupRef(name: $0) },
            userData: userData,
            availabilityZone: availabilityZone,
            networks: networks,
            keyName: keyName,
            blockDeviceMapping: blockDeviceMappings
        )

        return try await createServer(request: request)
    }

    /// Delete a server
    public func deleteServer(id: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.deleteServer(id: id)
        }
    }

    /// Start a server
    public func startServer(id: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.startServer(id: id)
        }
    }

    /// Stop a server
    public func stopServer(id: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.stopServer(id: id)
        }
    }

    /// Reboot a server
    public func rebootServer(id: String, type: RebootType = .soft) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.rebootServer(id: id, type: type)
        }
    }

    /// Reboot a server with string type for backward compatibility
    public func rebootServer(id: String, type: String = "SOFT") async throws {
        let rebootType = type.uppercased() == "HARD" ? RebootType.hard : RebootType.soft
        try await rebootServer(id: id, type: rebootType)
    }

    /// Resize a server to a new flavor
    public func resizeServer(id: String, flavorRef: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.resizeServer(id: id, flavorRef: flavorRef)
        }
    }

    /// Confirm a server resize operation
    public func confirmResize(id: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.confirmResize(id: id)
        }
    }

    /// Revert a server resize operation
    public func revertResize(id: String) async throws {
        try await executeWithTokenRefresh {
            let nova = await self.nova
            try await nova.revertResize(id: id)
        }
    }

    // MARK: - Network Management Operations

    /// Create a network
    public func createNetwork(name: String, description: String? = nil, adminStateUp: Bool = true, shared: Bool = false, external: Bool = false, providerNetworkType: String? = nil, providerPhysicalNetwork: String? = nil, providerSegmentationID: Int? = nil) async throws -> Network {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            let request = CreateNetworkRequest(
                name: name,
                description: description,
                adminStateUp: adminStateUp,
                shared: shared,
                external: external,
                providerNetworkType: providerNetworkType,
                providerPhysicalNetwork: providerPhysicalNetwork,
                providerSegmentationId: providerSegmentationID
            )
            return try await neutron.createNetwork(request: request)
        }
    }

    /// Create a network with request object
    public func createNetwork(request: CreateNetworkRequest) async throws -> Network {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.createNetwork(request: request)
        }
    }

    /// Delete a network
    public func deleteNetwork(id: String) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            try await neutron.deleteNetwork(id: id)
        }
    }

    /// Create a subnet
    public func createSubnet(name: String?, networkID: String, cidr: String, ipVersion: Int = 4, gatewayIP: String? = nil, dnsNameservers: [String]? = nil, enableDhcp: Bool = true) async throws -> Subnet {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            let request = CreateSubnetRequest(
                name: name,
                description: nil,
                networkId: networkID,
                ipVersion: ipVersion,
                cidr: cidr,
                gatewayIp: gatewayIP,
                enableDhcp: enableDhcp,
                dnsNameservers: dnsNameservers
            )
            return try await neutron.createSubnet(request: request)
        }
    }

    /// Create a subnet with request object
    public func createSubnet(request: CreateSubnetRequest) async throws -> Subnet {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.createSubnet(request: request)
        }
    }

    /// Delete a subnet
    public func deleteSubnet(id: String) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            try await neutron.deleteSubnet(id: id)
        }
    }

    // MARK: - Security Group Management Operations

    /// Create a security group
    public func createSecurityGroup(name: String, description: String? = nil) async throws -> SecurityGroup {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            let request = CreateSecurityGroupRequest(name: name, description: description)
            return try await neutron.createSecurityGroup(request: request)
        }
    }

    /// Create a security group with request object
    public func createSecurityGroup(request: CreateSecurityGroupRequest) async throws -> SecurityGroup {
        return try await executeWithTokenRefresh {
            let neutron = await self.neutron
            return try await neutron.createSecurityGroup(request: request)
        }
    }

    /// Delete a security group
    public func deleteSecurityGroup(id: String) async throws {
        try await executeWithTokenRefresh {
            let neutron = await self.neutron
            try await neutron.deleteSecurityGroup(id: id)
        }
    }

    // MARK: - Volume Management Operations

    /// Create a volume
    public func createVolume(request: CreateVolumeRequest) async throws -> Volume {
        return try await executeWithTokenRefresh {
            let cinder = await self.cinder
            return try await cinder.createVolume(request: request)
        }
    }

    /// Delete a volume
    public func deleteVolume(id: String) async throws {
        try await executeWithTokenRefresh {
            let cinder = await self.cinder
            try await cinder.deleteVolume(id: id)
        }
    }

    // MARK: - Client Management

    /// Clear all cached service clients and data managers
    public func resetServices() {
        _nova = nil
        _neutron = nil
        _cinder = nil
        _keystone = nil
        _barbican = nil
        _glance = nil

        // Clear data managers
        _serverDataManager = nil
        _networkDataManager = nil
        _volumeDataManager = nil
        _imageDataManager = nil
        _dataManagerFactory = nil
    }

    /// Access to core client for advanced operations
    public var coreClient: OpenStackClientCore {
        return core
    }

    // MARK: - Performance Enhancement Integration

    /// Trigger cleanup across all data managers and caches
    public func performCleanup() async {
        // Basic cleanup
        await core.clearCache()

        await _serverDataManager?.clearCache()
        await _networkDataManager?.clearCache()
        await _volumeDataManager?.clearCache()
        await _imageDataManager?.clearCache()
    }
}
