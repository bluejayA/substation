# OSClient API Reference

Complete API reference for the OpenStackClient library, service clients, and data models.

## Package Overview

The OSClient library provides a comprehensive Swift API for interacting with OpenStack services with:

- **Type-safe API** using Swift's strong type system
- **Actor-based concurrency** for thread safety
- **Intelligent caching** designed for up to 60-80% API call reduction
- **Comprehensive error handling** with recovery strategies
- **Cross-platform compatibility** (macOS and Linux)

## OpenStackClient

The main entry point for all OpenStack operations.

### Initialization

```swift
@MainActor
public final class OpenStackClient: @unchecked Sendable {
    /// Connect to OpenStack with configuration and credentials
    public static func connect(
        config: OpenStackConfig,
        credentials: OpenStackCredentials,
        logger: OpenStackClientLogger = ConsoleLogger(),
        enablePerformanceEnhancements: Bool = true
    ) async throws -> OpenStackClient
}
```

**Example**:

```swift
import OSClient

let config = OpenStackConfig(
    authUrl: "https://keystone.example.com:5000/v3"
)

let credentials = OpenStackCredentials(
    username: "operator",
    password: "secret",
    projectName: "myproject",
    domainName: "default"
)

let client = try await OpenStackClient.connect(
    config: config,
    credentials: credentials
)
```

### Service Access

```swift
// Service client properties
public var nova: NovaService { get }
public var neutron: NeutronService { get }
public var cinder: CinderService { get }
public var glance: GlanceService { get }
public var keystone: KeystoneService { get }
public var barbican: BarbicanService { get }
public var swift: SwiftService { get }
```

### Configuration

```swift
public struct OpenStackConfig {
    public let authUrl: String
    public let interface: String = "public"
    public let validateCertificates: Bool = true
    public let timeout: TimeInterval = 30
    public let retryCount: Int = 3
}

public struct OpenStackCredentials {
    public let username: String?
    public let password: String?
    public let projectName: String?
    public let domainName: String?
    public let applicationCredentialId: String?
    public let applicationCredentialSecret: String?
    public let token: String?
}
```

## Service Clients

### NovaService (Compute)

Compute service for managing servers, flavors, and keypairs.

```swift
public actor NovaService {
    // Server operations
    /// List servers with optional pagination
    public func listServers(
        options: PaginationOptions = PaginationOptions(),
        forceRefresh: Bool = false
    ) async throws -> ServerListResponse

    /// Get server details
    public func getServer(
        id: String,
        forceRefresh: Bool = false
    ) async throws -> Server

    /// Create a new server
    public func createServer(
        request: CreateServerRequest
    ) async throws -> Server

    /// Delete a server
    public func deleteServer(id: String) async throws

    /// Server actions
    public func startServer(_ id: String) async throws
    public func stopServer(_ id: String) async throws
    public func rebootServer(
        id: String,
        type: RebootType = .soft
    ) async throws
    public func resizeServer(
        id: String,
        flavorRef: String
    ) async throws
    public func confirmResize(id: String) async throws
    public func revertResize(id: String) async throws

    /// Console access
    public func getConsoleOutput(
        id: String,
        length: Int? = nil
    ) async throws -> String
    public func getRemoteConsole(
        id: String,
        protocol: String = "vnc",
        type: String = "novnc"
    ) async throws -> RemoteConsole

    // Flavor operations
    /// List available flavors
    public func listFlavors(
        includePublic: Bool = true,
        options: PaginationOptions = PaginationOptions(),
        forceRefresh: Bool = false
    ) async throws -> [Flavor]

    /// Get flavor details
    public func getFlavor(
        id: String,
        forceRefresh: Bool = false
    ) async throws -> Flavor

    // Key pair operations
    /// List key pairs
    public func listKeyPairs(
        forceRefresh: Bool = false
    ) async throws -> [KeyPair]

    /// Create a key pair
    public func createKeyPair(
        name: String,
        publicKey: String? = nil
    ) async throws -> KeyPair

    /// Delete a key pair
    public func deleteKeyPair(name: String) async throws

    // Server group operations
    /// List server groups
    public func listServerGroups(
        forceRefresh: Bool = false
    ) async throws -> [ServerGroup]

    /// Create a server group
    public func createServerGroup(
        name: String,
        policies: [String]
    ) async throws -> ServerGroup

    /// Delete a server group
    public func deleteServerGroup(id: String) async throws
}
```

### NeutronService (Networking)

Networking service for managing networks, subnets, routers, and security groups.

```swift
public actor NeutronService {
    // Network operations
    /// List networks
    public func listNetworks(
        options: PaginationOptions = PaginationOptions(),
        forceRefresh: Bool = false
    ) async throws -> [Network]

    /// Get network details
    public func getNetwork(
        id: String,
        forceRefresh: Bool = false
    ) async throws -> Network

    /// Create network
    public func createNetwork(
        request: CreateNetworkRequest
    ) async throws -> Network

    /// Update network
    public func updateNetwork(
        id: String,
        request: UpdateNetworkRequest
    ) async throws -> Network

    /// Delete network
    public func deleteNetwork(id: String) async throws

    // Subnet operations
    /// List subnets
    public func listSubnets(
        networkId: String? = nil,
        options: PaginationOptions = PaginationOptions(),
        forceRefresh: Bool = false
    ) async throws -> [Subnet]

    /// Get subnet details
    public func getSubnet(
        id: String,
        forceRefresh: Bool = false
    ) async throws -> Subnet

    /// Create subnet
    public func createSubnet(
        request: CreateSubnetRequest
    ) async throws -> Subnet

    /// Update subnet
    public func updateSubnet(
        id: String,
        request: UpdateSubnetRequest
    ) async throws -> Subnet

    /// Delete subnet
    public func deleteSubnet(id: String) async throws

    // Port operations
    /// List ports
    public func listPorts(
        networkId: String? = nil,
        deviceId: String? = nil,
        options: PaginationOptions = PaginationOptions(),
        forceRefresh: Bool = false
    ) async throws -> [Port]

    /// Get port details
    public func getPort(
        id: String,
        forceRefresh: Bool = false
    ) async throws -> Port

    /// Create port
    public func createPort(
        request: CreatePortRequest
    ) async throws -> Port

    /// Update port
    public func updatePort(
        id: String,
        request: UpdatePortRequest
    ) async throws -> Port

    /// Delete port
    public func deletePort(id: String) async throws

    // Router operations
    /// List routers
    public func listRouters(
        options: PaginationOptions = PaginationOptions(),
        forceRefresh: Bool = false
    ) async throws -> [Router]

    /// Get router details
    public func getRouter(
        id: String,
        forceRefresh: Bool = false
    ) async throws -> Router

    /// Create router
    public func createRouter(
        request: CreateRouterRequest
    ) async throws -> Router

    /// Update router
    public func updateRouter(
        id: String,
        request: UpdateRouterRequest
    ) async throws -> Router

    /// Delete router
    public func deleteRouter(id: String) async throws

    /// Add interface to router
    public func addRouterInterface(
        routerId: String,
        subnetId: String? = nil,
        portId: String? = nil
    ) async throws -> RouterInterface

    /// Remove interface from router
    public func removeRouterInterface(
        routerId: String,
        subnetId: String? = nil,
        portId: String? = nil
    ) async throws

    // Security group operations
    /// List security groups
    public func listSecurityGroups(
        options: PaginationOptions = PaginationOptions(),
        forceRefresh: Bool = false
    ) async throws -> [SecurityGroup]

    /// Get security group details
    public func getSecurityGroup(id: String) async throws -> SecurityGroup

    /// Create security group
    public func createSecurityGroup(
        request: CreateSecurityGroupRequest
    ) async throws -> SecurityGroup

    /// Delete security group
    public func deleteSecurityGroup(id: String) async throws

    /// Create security group rule
    public func createSecurityGroupRule(
        request: CreateSecurityGroupRuleRequest
    ) async throws -> SecurityGroupRule

    /// Delete security group rule
    public func deleteSecurityGroupRule(id: String) async throws

    // Floating IP operations
    /// List floating IPs
    public func listFloatingIPs(
        options: PaginationOptions = PaginationOptions(),
        forceRefresh: Bool = false
    ) async throws -> [FloatingIP]

    /// Get floating IP details
    public func getFloatingIP(id: String) async throws -> FloatingIP

    /// Create floating IP
    public func createFloatingIP(
        networkID: String,
        portID: String? = nil,
        subnetID: String? = nil,
        description: String? = nil
    ) async throws -> FloatingIP

    /// Update floating IP (associate/disassociate)
    public func updateFloatingIP(
        id: String,
        portID: String? = nil,
        fixedIP: String? = nil
    ) async throws -> FloatingIP

    /// Delete floating IP
    public func deleteFloatingIP(id: String) async throws
}
```

### CinderService (Block Storage)

Block storage service for managing volumes and snapshots.

```swift
public actor CinderService {
    // Volume operations
    /// List volumes
    public func listVolumes(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [Volume]

    /// Get volume details
    public func getVolume(id: String) async throws -> Volume

    /// Create volume
    public func createVolume(
        request: CreateVolumeRequest
    ) async throws -> Volume

    /// Update volume
    public func updateVolume(
        id: String,
        request: UpdateVolumeRequest
    ) async throws -> Volume

    /// Delete volume
    public func deleteVolume(id: String) async throws

    /// Extend volume size
    public func extendVolume(
        id: String,
        newSize: Int
    ) async throws

    /// Attach volume to server
    public func attachVolume(
        id: String,
        serverId: String,
        device: String? = nil
    ) async throws

    /// Detach volume from server
    public func detachVolume(id: String) async throws

    // Volume type operations
    /// List volume types
    public func listVolumeTypes() async throws -> [VolumeType]

    /// Get volume type details
    public func getVolumeType(id: String) async throws -> VolumeType

    /// Create volume type
    public func createVolumeType(
        request: CreateVolumeTypeRequest
    ) async throws -> VolumeType

    /// Delete volume type
    public func deleteVolumeType(id: String) async throws

    // Snapshot operations
    /// List volume snapshots
    public func listSnapshots(
        volumeId: String? = nil,
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [VolumeSnapshot]

    /// Get snapshot details
    public func getSnapshot(id: String) async throws -> VolumeSnapshot

    /// Create snapshot
    public func createSnapshot(
        request: CreateSnapshotRequest
    ) async throws -> VolumeSnapshot

    /// Update snapshot
    public func updateSnapshot(
        id: String,
        request: UpdateSnapshotRequest
    ) async throws -> VolumeSnapshot

    /// Delete snapshot
    public func deleteSnapshot(id: String) async throws

    // Backup operations
    /// List volume backups
    public func listBackups(
        volumeId: String? = nil,
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [VolumeBackup]

    /// Get backup details
    public func getBackup(id: String) async throws -> VolumeBackup

    /// Create backup
    public func createBackup(
        request: CreateBackupRequest
    ) async throws -> VolumeBackup

    /// Delete backup
    public func deleteBackup(id: String) async throws

    /// Restore backup
    public func restoreBackup(
        id: String,
        volumeId: String? = nil
    ) async throws -> VolumeBackupRestore
}
```

### GlanceService (Image)

Image service for managing virtual machine images.

```swift
public actor GlanceService {
    // Image operations
    /// List images
    public func listImages(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [Image]

    /// Get image details
    public func getImage(id: String) async throws -> Image

    /// Create image
    public func createImage(
        request: CreateImageRequest
    ) async throws -> Image

    /// Update image metadata
    public func updateImage(
        id: String,
        request: UpdateImageRequest
    ) async throws -> Image

    /// Delete image
    public func deleteImage(id: String) async throws

    /// Upload image data
    public func uploadImageData(
        id: String,
        data: Data
    ) async throws

    /// Download image data
    public func downloadImageData(id: String) async throws -> Data

    /// Add tag to image
    public func addImageTag(
        id: String,
        tag: String
    ) async throws

    /// Remove tag from image
    public func removeImageTag(
        id: String,
        tag: String
    ) async throws

    /// Set image visibility
    public func setImageVisibility(
        id: String,
        visibility: String
    ) async throws -> Image

    /// Set image protection
    public func setImageProtection(
        id: String,
        protected: Bool
    ) async throws -> Image
}
```

### KeystoneService (Identity)

Identity service for managing projects, users, roles, and authentication.

```swift
public actor KeystoneService {
    // Project operations
    /// List projects
    public func listProjects(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [Project]

    /// Get project details
    public func getProject(id: String) async throws -> Project

    /// Create project
    public func createProject(
        request: CreateProjectRequest
    ) async throws -> Project

    /// Update project
    public func updateProject(
        id: String,
        request: UpdateProjectRequest
    ) async throws -> Project

    /// Delete project
    public func deleteProject(id: String) async throws

    // User operations
    /// List users
    public func listUsers(
        domainId: String? = nil,
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [User]

    /// Get user details
    public func getUser(id: String) async throws -> User

    /// Create user
    public func createUser(
        request: CreateUserRequest
    ) async throws -> User

    /// Update user
    public func updateUser(
        id: String,
        request: UpdateUserRequest
    ) async throws -> User

    /// Delete user
    public func deleteUser(id: String) async throws

    /// Change user password
    public func changeUserPassword(
        id: String,
        request: ChangePasswordRequest
    ) async throws

    // Role operations
    /// List roles
    public func listRoles(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [Role]

    /// Get role details
    public func getRole(id: String) async throws -> Role

    /// Create role
    public func createRole(
        request: CreateRoleRequest
    ) async throws -> Role

    /// Grant role to user on project
    public func grantRoleToUserOnProject(
        userId: String,
        projectId: String,
        roleId: String
    ) async throws

    /// Revoke role from user on project
    public func revokeRoleFromUserOnProject(
        userId: String,
        projectId: String,
        roleId: String
    ) async throws

    // Domain operations
    /// List domains
    public func listDomains(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [Domain]

    /// Get domain details
    public func getDomain(id: String) async throws -> Domain

    /// Create domain
    public func createDomain(
        request: CreateDomainRequest
    ) async throws -> Domain
}
```

### BarbicanService (Key Management)

Key management service for secrets, certificates, and encryption keys.

```swift
public actor BarbicanService {
    // Secret operations
    /// List secrets
    public func listSecrets(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [Secret]

    /// Get secret details
    public func getSecret(id: String) async throws -> SecretDetailResponse

    /// Create secret
    public func createSecret(
        request: CreateSecretRequest
    ) async throws -> SecretRef

    /// Delete secret
    public func deleteSecret(id: String) async throws

    /// Get secret payload
    public func getSecretPayload(
        id: String,
        payloadContentType: String? = nil
    ) async throws -> Data

    /// Store secret payload
    public func storeSecretPayload(
        id: String,
        payload: Data,
        contentType: String
    ) async throws

    // Container operations
    /// List containers
    public func listContainers(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [BarbicanContainer]

    /// Get container details
    public func getContainer(id: String) async throws -> BarbicanContainer

    /// Create container
    public func createContainer(
        request: BarbicanCreateContainerRequest
    ) async throws -> ContainerRef

    /// Delete container
    public func deleteContainer(id: String) async throws

    // Certificate operations
    /// List certificate authorities
    public func listCertificateAuthorities(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [CertificateAuthority]

    /// Get certificate authority details
    public func getCertificateAuthority(
        id: String
    ) async throws -> CertificateAuthority

    /// List certificate orders
    public func listCertificateOrders(
        options: PaginationOptions = PaginationOptions()
    ) async throws -> [CertificateOrder]

    /// Create certificate order
    public func createCertificateOrder(
        request: CreateCertificateOrderRequest
    ) async throws -> CertificateOrderRef
}
```

### SwiftService (Object Storage)

Object storage service for managing containers and objects.

```swift
public actor SwiftService {
    // Container operations
    /// List containers
    public func listContainers(
        limit: Int? = nil,
        marker: String? = nil,
        prefix: String? = nil
    ) async throws -> [SwiftContainer]

    /// Get container metadata
    public func getContainerMetadata(
        containerName: String
    ) async throws -> SwiftContainerMetadataResponse

    /// Create container
    public func createContainer(
        request: CreateSwiftContainerRequest
    ) async throws

    /// Update container metadata
    public func updateContainerMetadata(
        containerName: String,
        request: UpdateSwiftContainerMetadataRequest
    ) async throws

    /// Delete container
    public func deleteContainer(
        containerName: String
    ) async throws

    // Object operations
    /// List objects in container
    public func listObjects(
        containerName: String,
        limit: Int? = nil,
        marker: String? = nil,
        prefix: String? = nil,
        delimiter: String? = nil
    ) async throws -> [SwiftObject]

    /// Get object metadata
    public func getObjectMetadata(
        containerName: String,
        objectName: String
    ) async throws -> SwiftObjectMetadataResponse

    /// Upload object
    public func uploadObject(
        request: UploadSwiftObjectRequest
    ) async throws

    /// Download object
    public func downloadObject(
        containerName: String,
        objectName: String
    ) async throws -> Data

    /// Copy object
    public func copyObject(
        request: CopySwiftObjectRequest
    ) async throws

    /// Update object metadata
    public func updateObjectMetadata(
        containerName: String,
        objectName: String,
        request: UpdateSwiftObjectMetadataRequest
    ) async throws

    /// Delete object
    public func deleteObject(
        containerName: String,
        objectName: String
    ) async throws

    // Bulk operations
    /// Bulk delete objects
    public func bulkDelete(
        request: BulkDeleteRequest
    ) async throws -> BulkDeleteResponse

    /// Bulk upload objects
    public func bulkUpload(
        containerName: String,
        objects: [(name: String, data: Data, contentType: String?)],
        progressCallback: ((Int, Int) -> Void)? = nil
    ) async throws -> BulkUploadResult

    // Account operations
    /// Get account information
    public func getAccountInfo() async throws -> SwiftAccountInfo
}
```

## Data Models

### Server Model

```swift
public struct Server: Codable, Identifiable {
    public let id: String
    public let name: String
    public let status: ServerStatus
    public let flavor: FlavorRef
    public let image: ImageRef?
    public let addresses: [String: [Address]]
    public let created: Date
    public let updated: Date
    public let metadata: [String: String]
    public let securityGroups: [SecurityGroupRef]
    public let volumesAttached: [String]

    public enum ServerStatus: String, Codable {
        case active = "ACTIVE"
        case building = "BUILD"
        case deleted = "DELETED"
        case error = "ERROR"
        case hardReboot = "HARD_REBOOT"
        case password = "PASSWORD"
        case paused = "PAUSED"
        case reboot = "REBOOT"
        case rebuild = "REBUILD"
        case rescue = "RESCUE"
        case resize = "RESIZE"
        case revertResize = "REVERT_RESIZE"
        case shutoff = "SHUTOFF"
        case softDeleted = "SOFT_DELETED"
        case stopped = "STOPPED"
        case suspended = "SUSPENDED"
        case unknown = "UNKNOWN"
        case verifyResize = "VERIFY_RESIZE"
    }
}
```

### Network Model

```swift
public struct Network: Codable, Identifiable {
    public let id: String
    public let name: String
    public let status: String
    public let shared: Bool
    public let external: Bool
    public let subnets: [String]
    public let adminStateUp: Bool
    public let mtu: Int?
    public let portSecurityEnabled: Bool
    public let providerNetworkType: String?
    public let providerSegmentationId: Int?
}
```

### Volume Model

```swift
public struct Volume: Codable, Identifiable {
    public let id: String
    public let name: String?
    public let status: VolumeStatus
    public let size: Int
    public let volumeType: String
    public let bootable: Bool
    public let encrypted: Bool
    public let attachments: [VolumeAttachment]
    public let createdAt: Date
    public let updatedAt: Date?

    public enum VolumeStatus: String, Codable {
        case creating = "creating"
        case available = "available"
        case attaching = "attaching"
        case inUse = "in-use"
        case deleting = "deleting"
        case error = "error"
        case errorDeleting = "error_deleting"
        case maintenance = "maintenance"
    }
}
```

## Cache Management

### CacheManager

```swift
public actor CacheManager {
    /// Configure cache settings
    public func configure(
        maxSize: Int,
        defaultTTL: TimeInterval,
        resourceTTLs: [ResourceType: TimeInterval] = [:]
    )

    /// Get cache statistics
    public func statistics() -> CacheStatistics

    /// Clear cache
    public func clear(type: ResourceType? = nil)

    /// Warm cache with frequently used data
    public func warm(resources: [ResourceType])
}

public struct CacheStatistics {
    public let hitRate: Double
    public let missRate: Double
    public let evictionCount: Int
    public let currentSize: Int
    public let maxSize: Int
}
```

**Example**:

```swift
// Configure cache for your environment
await client.cacheManager.configure(
    maxSize: 100_000_000,  // 100MB
    defaultTTL: 300,       // 5 minutes
    resourceTTLs: [
        .servers: 60,      // 1 minute for servers
        .networks: 300,    // 5 minutes for networks
        .images: 3600      // 1 hour for images
    ]
)

// Get cache statistics
let stats = await client.cacheManager.statistics()
print("Cache hit rate: \(stats.hitRate * 100)%")
```

## Error Handling

### Error Types

```swift
public enum OpenStackError: Error {
    case authentication(String)
    case authorization(String)
    case notFound(resource: String, id: String)
    case conflict(String)
    case quotaExceeded(String)
    case serverError(String)
    case timeout(operation: String)
    case networkError(Error)
    case invalidResponse(String)
    case rateLimited(retryAfter: TimeInterval?)
}
```

### Error Recovery

```swift
public protocol ErrorRecoveryStrategy {
    func shouldRetry(error: Error, attempt: Int) -> Bool
    func delayForRetry(attempt: Int) -> TimeInterval
}

public struct ExponentialBackoffStrategy: ErrorRecoveryStrategy {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
}
```

**Example**:

```swift
do {
    let server = try await client.nova.servers.create(...)
} catch OpenStackError.quotaExceeded(let message) {
    // Handle quota error
    print("Quota exceeded: \(message)")
} catch OpenStackError.conflict(let message) {
    // Handle conflict
    print("Conflict: \(message)")
} catch {
    // Handle other errors
    print("Error: \(error)")
}
```

## Data Managers

### ServerDataManager

High-level server operations with related resource management.

```swift
public actor ServerDataManager {
    /// Get detailed server information with related resources
    public func getDetailed(_ id: String) async throws -> DetailedServer

    /// Batch operations
    public func batchDelete(_ ids: [String]) async throws -> BatchResult
    public func batchStop(_ ids: [String]) async throws -> BatchResult
    public func batchStart(_ ids: [String]) async throws -> BatchResult

    /// Advanced queries
    public func search(
        name: String? = nil,
        status: ServerStatus? = nil,
        flavor: String? = nil,
        network: String? = nil
    ) async throws -> [Server]
}
```

### NetworkDataManager

High-level network operations with topology analysis.

```swift
public actor NetworkDataManager {
    /// Get network topology
    public func getTopology() async throws -> NetworkTopology

    /// Find connected resources
    public func getConnectedServers(_ networkId: String) async throws -> [Server]
    public func getConnectedRouters(_ networkId: String) async throws -> [Router]

    /// Network path analysis
    public func findPath(from: String, to: String) async throws -> [NetworkHop]
}
```

## Performance Monitoring

### PerformanceMonitor

```swift
public actor PerformanceMonitor {
    /// Start monitoring
    public func start()

    /// Get metrics
    public func metrics() -> PerformanceMetrics

    /// Export metrics
    public func export(format: ExportFormat) -> Data
}

public struct PerformanceMetrics {
    public let apiCallCount: Int
    public let averageLatency: TimeInterval
    public let p95Latency: TimeInterval
    public let p99Latency: TimeInterval
    public let cacheHitRate: Double
    public let errorRate: Double
}
```

## Logging

### Logger Protocol

```swift
public protocol OpenStackClientLogger {
    func logDebug(_ message: String)
    func logInfo(_ message: String)
    func logWarning(_ message: String)
    func logError(_ message: String, error: Error?)
}

// Built-in loggers
public struct ConsoleLogger: OpenStackClientLogger { }
public struct FileLogger: OpenStackClientLogger { }
public struct NullLogger: OpenStackClientLogger { }
```

## Extensions

### Async Sequences

```swift
extension ServerManager {
    /// Stream server events
    public func events(_ serverId: String) -> AsyncStream<ServerEvent>

    /// Watch for state changes
    public func watchStatus(
        _ serverId: String,
        until status: ServerStatus,
        timeout: TimeInterval = 300
    ) async throws
}
```

**Example**:

```swift
// Watch for server to become active
try await client.nova.servers.watchStatus(
    serverId,
    until: .active,
    timeout: 600  // 10 minutes
)
```

### Batch Operations

```swift
public protocol BatchOperation {
    associatedtype Resource
    associatedtype Result

    func execute(
        on resources: [Resource],
        concurrency: Int
    ) async throws -> [Result]
}
```

## Migration Guide

### From Python OpenStack SDK

**Python**:

```python
from openstack import connection
conn = connection.Connection(
    auth_url="https://keystone.example.com:5000/v3",
    username="user",
    password="pass",
    project_name="project"
)
servers = conn.compute.servers()
```

**Swift**:

```swift
import OSClient

let client = try await OpenStackClient.connect(
    config: OpenStackConfig(authUrl: "https://keystone.example.com:5000/v3"),
    credentials: OpenStackCredentials(
        username: "user",
        password: "pass",
        projectName: "project"
    )
)
let response = try await client.nova.listServers()
let servers = response.servers
```

## Best Practices

### 1. Use Async/Await

```swift
// Good: Using async/await
let response = try await client.nova.listServers()

// Avoid: Blocking calls
// Not supported - all operations are async
```

### 2. Handle Errors Properly

```swift
do {
    let server = try await client.nova.createServer(request: createRequest)
} catch OpenStackError.quotaExceeded(let message) {
    // Handle quota error
} catch OpenStackError.conflict(let message) {
    // Handle conflict
} catch {
    // Handle other errors
}
```

### 3. Leverage Intelligent Caching

```swift
// First call fetches from API
let servers1 = try await client.nova.listServers()

// Subsequent calls use cache (within TTL)
let servers2 = try await client.nova.listServers()

// Force refresh when needed
let servers3 = try await client.nova.listServers(forceRefresh: true)
```

### 4. Use Request Objects for Complex Operations

```swift
// Create server with detailed configuration
let createRequest = CreateServerRequest(
    name: "my-server",
    imageRef: imageId,
    flavorRef: flavorId,
    networks: [NetworkRequest(uuid: networkId)],
    keyName: "my-keypair"
)

let server = try await client.nova.createServer(request: createRequest)
```

---

**See Also**:

- [SwiftNCurses Framework API](SwiftNCurses.md) - Terminal UI framework
- [Integration Guide](integration.md) - CrossPlatformTimer and integration examples
- [API Reference Index](index.md) - Quick reference and navigation
