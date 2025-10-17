# OSClient API Reference

Complete API reference for the OpenStackClient library, service clients, and data models.

## Package Overview

The OSClient library provides a comprehensive Swift API for interacting with OpenStack services with:

- **Type-safe API** using Swift's strong type system
- **Actor-based concurrency** for thread safety
- **Intelligent caching** for 60-80% API call reduction
- **Comprehensive error handling** with recovery strategies
- **Cross-platform compatibility** (macOS and Linux)

## OpenStackClient

The main entry point for all OpenStack operations.

### Initialization

```swift
public actor OpenStackClient {
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
public var heat: HeatService { get }
public var barbican: BarbicanService { get }
public var octavia: OctaviaService { get }
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
    public func servers() -> ServerManager
    public func flavors() -> FlavorManager
    public func keypairs() -> KeyPairManager
    public func serverGroups() -> ServerGroupManager
}

public actor ServerManager {
    /// List all servers
    public func list(
        allTenants: Bool = false,
        detailed: Bool = true,
        limit: Int? = nil,
        marker: String? = nil
    ) async throws -> [Server]

    /// Get server details
    public func get(_ id: String) async throws -> Server

    /// Create a new server
    public func create(
        name: String,
        flavorRef: String,
        imageRef: String?,
        networks: [NetworkConfig] = [],
        securityGroups: [String] = [],
        keyName: String? = nil,
        userData: String? = nil,
        blockDeviceMappings: [BlockDeviceMapping] = []
    ) async throws -> Server

    /// Delete a server
    public func delete(_ id: String) async throws

    /// Server actions
    public func start(_ id: String) async throws
    public func stop(_ id: String) async throws
    public func reboot(_ id: String, type: RebootType = .soft) async throws
    public func resize(_ id: String, flavorRef: String) async throws
    public func rebuild(_ id: String, imageRef: String) async throws

    /// Console access
    public func getConsoleOutput(_ id: String, lines: Int? = nil) async throws -> String
    public func getVNCConsole(_ id: String) async throws -> VNCConsole
}
```

### NeutronService (Networking)

Networking service for managing networks, subnets, routers, and security groups.

```swift
public actor NeutronService {
    public func networks() -> NetworkManager
    public func subnets() -> SubnetManager
    public func ports() -> PortManager
    public func routers() -> RouterManager
    public func securityGroups() -> SecurityGroupManager
    public func floatingIPs() -> FloatingIPManager
}

public actor NetworkManager {
    /// List networks
    public func list(
        shared: Bool? = nil,
        external: Bool? = nil
    ) async throws -> [Network]

    /// Create network
    public func create(
        name: String,
        shared: Bool = false,
        external: Bool = false,
        segmentationId: Int? = nil
    ) async throws -> Network

    /// Update network
    public func update(
        _ id: String,
        name: String? = nil,
        shared: Bool? = nil
    ) async throws -> Network

    /// Delete network
    public func delete(_ id: String) async throws
}
```

### CinderService (Block Storage)

Block storage service for managing volumes and snapshots.

```swift
public actor CinderService {
    public func volumes() -> VolumeManager
    public func snapshots() -> SnapshotManager
    public func volumeTypes() -> VolumeTypeManager
}

public actor VolumeManager {
    /// List volumes
    public func list(detailed: Bool = true) async throws -> [Volume]

    /// Create volume
    public func create(
        name: String,
        size: Int,
        volumeType: String? = nil,
        sourceVolId: String? = nil,
        snapshotId: String? = nil,
        imageRef: String? = nil,
        bootable: Bool = false
    ) async throws -> Volume

    /// Attach volume to server
    public func attach(
        _ id: String,
        serverId: String,
        device: String? = nil
    ) async throws -> VolumeAttachment

    /// Detach volume from server
    public func detach(
        _ id: String,
        attachmentId: String
    ) async throws

    /// Extend volume size
    public func extend(
        _ id: String,
        newSize: Int
    ) async throws -> Volume
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
let servers = try await client.nova.servers.list()
```

## Best Practices

### 1. Use Async/Await

```swift
// Good: Using async/await
let servers = try await client.nova.servers.list()

// Avoid: Blocking calls
// let servers = client.nova.servers.listSync() // Don't do this
```

### 2. Handle Errors Properly

```swift
do {
    let server = try await client.nova.servers.create(...)
} catch OpenStackError.quotaExceeded(let message) {
    // Handle quota error
} catch OpenStackError.conflict(let message) {
    // Handle conflict
} catch {
    // Handle other errors
}
```

### 3. Use Data Managers for Complex Operations

```swift
// Use data manager for detailed info
let details = try await client.serverDataManager.getDetailed(serverId)

// Instead of multiple calls
// let server = try await client.nova.servers.get(serverId)
// let volumes = try await client.cinder.volumes.list(serverId: serverId)
// let networks = ...
```

### 4. Configure Caching Appropriately

```swift
// Configure cache for your use case
await client.cacheManager.configure(
    maxSize: 100_000_000, // 100MB
    defaultTTL: 300, // 5 minutes
    resourceTTLs: [
        .servers: 60,
        .networks: 300,
        .images: 3600
    ]
)
```

---

**See Also**:

- [SwiftNCurses Framework API](SwiftNCurses.md) - Terminal UI framework
- [Integration Guide](integration.md) - CrossPlatformTimer and integration examples
- [API Reference Index](index.md) - Quick reference and navigation
