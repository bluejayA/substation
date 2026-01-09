import Foundation

// MARK: - Cluster Models

/// OpenStack Magnum Cluster resource
///
/// Represents a container orchestration cluster managed by Magnum.
/// Clusters contain master and worker nodes running a COE like Kubernetes.
public struct Cluster: Codable, Sendable, ResourceIdentifiable, Timestamped {
    /// Unique identifier for the cluster
    public let uuid: String

    /// Human-readable name of the cluster
    public let name: String?

    /// Current status of the cluster
    public let status: String?

    /// Detailed reason for the current status
    public let statusReason: String?

    /// UUID of the Heat stack managing this cluster
    public let stackId: String?

    /// UUID of the cluster template used
    public let clusterTemplateId: String

    /// Name of the SSH keypair for node access
    public let keypair: String?

    /// Number of master nodes
    public let masterCount: Int?

    /// Number of worker nodes
    public let nodeCount: Int?

    /// Timeout in minutes for cluster creation
    public let createTimeout: Int?

    /// IP addresses of master nodes
    public let masterAddresses: [String]?

    /// IP addresses of worker nodes
    public let nodeAddresses: [String]?

    /// API endpoint URL for the cluster
    public let apiAddress: String?

    /// Discovery URL for cluster bootstrapping
    public let discoveryUrl: String?

    /// Version of the container orchestration engine
    public let coeVersion: String?

    /// Whether floating IPs are enabled for nodes
    public let floatingIpEnabled: Bool?

    /// Whether master load balancer is enabled
    public let masterLbEnabled: Bool?

    /// Custom labels applied to the cluster
    public let labels: [String: String]?

    /// Creation timestamp
    public let createdAt: Date?

    /// Last update timestamp
    public let updatedAt: Date?

    /// Project (tenant) ID that owns this cluster
    public let projectId: String?

    /// User ID that created this cluster
    public let userId: String?

    /// Links for API navigation
    public let links: [Link]?

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case status
        case statusReason = "status_reason"
        case stackId = "stack_id"
        case clusterTemplateId = "cluster_template_id"
        case keypair
        case masterCount = "master_count"
        case nodeCount = "node_count"
        case createTimeout = "create_timeout"
        case masterAddresses = "master_addresses"
        case nodeAddresses = "node_addresses"
        case apiAddress = "api_address"
        case discoveryUrl = "discovery_url"
        case coeVersion = "coe_version"
        case floatingIpEnabled = "floating_ip_enabled"
        case masterLbEnabled = "master_lb_enabled"
        case labels
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case projectId = "project_id"
        case userId = "user_id"
        case links
    }

    public init(
        uuid: String,
        name: String? = nil,
        status: String? = nil,
        statusReason: String? = nil,
        stackId: String? = nil,
        clusterTemplateId: String,
        keypair: String? = nil,
        masterCount: Int? = nil,
        nodeCount: Int? = nil,
        createTimeout: Int? = nil,
        masterAddresses: [String]? = nil,
        nodeAddresses: [String]? = nil,
        apiAddress: String? = nil,
        discoveryUrl: String? = nil,
        coeVersion: String? = nil,
        floatingIpEnabled: Bool? = nil,
        masterLbEnabled: Bool? = nil,
        labels: [String: String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        projectId: String? = nil,
        userId: String? = nil,
        links: [Link]? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.status = status
        self.statusReason = statusReason
        self.stackId = stackId
        self.clusterTemplateId = clusterTemplateId
        self.keypair = keypair
        self.masterCount = masterCount
        self.nodeCount = nodeCount
        self.createTimeout = createTimeout
        self.masterAddresses = masterAddresses
        self.nodeAddresses = nodeAddresses
        self.apiAddress = apiAddress
        self.discoveryUrl = discoveryUrl
        self.coeVersion = coeVersion
        self.floatingIpEnabled = floatingIpEnabled
        self.masterLbEnabled = masterLbEnabled
        self.labels = labels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectId = projectId
        self.userId = userId
        self.links = links
    }

    // MARK: - ResourceIdentifiable

    public var id: String {
        return uuid
    }

    // MARK: - Computed Properties

    /// Display name for the cluster
    public var displayName: String {
        return name ?? uuid
    }

    /// Check if cluster is in a healthy running state
    public var isActive: Bool {
        guard let status = status?.uppercased() else { return false }
        return status == "CREATE_COMPLETE" || status == "UPDATE_COMPLETE"
    }

    /// Check if cluster is in an error state
    public var hasError: Bool {
        guard let status = status?.uppercased() else { return false }
        return status.contains("FAILED")
    }

    /// Check if cluster is in a transitional state
    public var isTransitional: Bool {
        guard let status = status?.uppercased() else { return false }
        return status.contains("IN_PROGRESS")
    }

    /// Total number of nodes in the cluster
    public var totalNodeCount: Int {
        return (masterCount ?? 0) + (nodeCount ?? 0)
    }
}

// MARK: - Cluster Template Models

/// OpenStack Magnum Cluster Template resource
///
/// Defines the configuration template for creating clusters including
/// COE type, image, flavor, and networking settings.
public struct ClusterTemplate: Codable, Sendable, ResourceIdentifiable, Timestamped {
    /// Unique identifier for the template
    public let uuid: String

    /// Human-readable name
    public let name: String?

    /// Type of container orchestration engine (kubernetes, swarm, mesos)
    public let coe: String

    /// Image ID for cluster nodes
    public let imageId: String

    /// Default flavor for worker nodes
    public let flavorId: String?

    /// Flavor for master nodes (if different from workers)
    public let masterFlavorId: String?

    /// External network ID for floating IPs
    public let externalNetworkId: String?

    /// Fixed network ID for cluster internal network
    public let fixedNetwork: String?

    /// Fixed subnet ID for cluster internal network
    public let fixedSubnet: String?

    /// DNS nameserver for the cluster
    public let dnsNameserver: String?

    /// SSH keypair for node access
    public let keypairId: String?

    /// Docker volume size in GB
    public let dockerVolumeSize: Int?

    /// Docker storage driver (overlay, overlay2, devicemapper)
    public let dockerStorageDriver: String?

    /// Volume driver for persistent storage
    public let volumeDriver: String?

    /// Network driver (flannel, calico, etc.)
    public let networkDriver: String?

    /// Whether TLS is disabled
    public let tlsDisabled: Bool?

    /// Whether template is public
    public let isPublic: Bool?

    /// Whether template is hidden
    public let hidden: Bool?

    /// Whether registry is enabled
    public let registryEnabled: Bool?

    /// Insecure registry URL
    public let insecureRegistry: String?

    /// Server type (vm or baremetal)
    public let serverType: String?

    /// Cluster distribution (fedora-atomic, coreos, ubuntu)
    public let clusterDistro: String?

    /// HTTP proxy URL
    public let httpProxy: String?

    /// HTTPS proxy URL
    public let httpsProxy: String?

    /// No proxy list
    public let noProxy: String?

    /// API server port
    public let apiserverPort: Int?

    /// Whether floating IPs are enabled
    public let floatingIpEnabled: Bool?

    /// Whether master load balancer is enabled
    public let masterLbEnabled: Bool?

    /// Custom labels
    public let labels: [String: String]?

    /// Custom tags
    public let tags: [String]?

    /// Creation timestamp
    public let createdAt: Date?

    /// Last update timestamp
    public let updatedAt: Date?

    /// Links for API navigation
    public let links: [Link]?

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case coe
        case imageId = "image_id"
        case flavorId = "flavor_id"
        case masterFlavorId = "master_flavor_id"
        case externalNetworkId = "external_network_id"
        case fixedNetwork = "fixed_network"
        case fixedSubnet = "fixed_subnet"
        case dnsNameserver = "dns_nameserver"
        case keypairId = "keypair_id"
        case dockerVolumeSize = "docker_volume_size"
        case dockerStorageDriver = "docker_storage_driver"
        case volumeDriver = "volume_driver"
        case networkDriver = "network_driver"
        case tlsDisabled = "tls_disabled"
        case isPublic = "public"
        case hidden
        case registryEnabled = "registry_enabled"
        case insecureRegistry = "insecure_registry"
        case serverType = "server_type"
        case clusterDistro = "cluster_distro"
        case httpProxy = "http_proxy"
        case httpsProxy = "https_proxy"
        case noProxy = "no_proxy"
        case apiserverPort = "apiserver_port"
        case floatingIpEnabled = "floating_ip_enabled"
        case masterLbEnabled = "master_lb_enabled"
        case labels
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case links
    }

    public init(
        uuid: String,
        name: String? = nil,
        coe: String,
        imageId: String,
        flavorId: String? = nil,
        masterFlavorId: String? = nil,
        externalNetworkId: String? = nil,
        fixedNetwork: String? = nil,
        fixedSubnet: String? = nil,
        dnsNameserver: String? = nil,
        keypairId: String? = nil,
        dockerVolumeSize: Int? = nil,
        dockerStorageDriver: String? = nil,
        volumeDriver: String? = nil,
        networkDriver: String? = nil,
        tlsDisabled: Bool? = nil,
        isPublic: Bool? = nil,
        hidden: Bool? = nil,
        registryEnabled: Bool? = nil,
        insecureRegistry: String? = nil,
        serverType: String? = nil,
        clusterDistro: String? = nil,
        httpProxy: String? = nil,
        httpsProxy: String? = nil,
        noProxy: String? = nil,
        apiserverPort: Int? = nil,
        floatingIpEnabled: Bool? = nil,
        masterLbEnabled: Bool? = nil,
        labels: [String: String]? = nil,
        tags: [String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        links: [Link]? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.coe = coe
        self.imageId = imageId
        self.flavorId = flavorId
        self.masterFlavorId = masterFlavorId
        self.externalNetworkId = externalNetworkId
        self.fixedNetwork = fixedNetwork
        self.fixedSubnet = fixedSubnet
        self.dnsNameserver = dnsNameserver
        self.keypairId = keypairId
        self.dockerVolumeSize = dockerVolumeSize
        self.dockerStorageDriver = dockerStorageDriver
        self.volumeDriver = volumeDriver
        self.networkDriver = networkDriver
        self.tlsDisabled = tlsDisabled
        self.isPublic = isPublic
        self.hidden = hidden
        self.registryEnabled = registryEnabled
        self.insecureRegistry = insecureRegistry
        self.serverType = serverType
        self.clusterDistro = clusterDistro
        self.httpProxy = httpProxy
        self.httpsProxy = httpsProxy
        self.noProxy = noProxy
        self.apiserverPort = apiserverPort
        self.floatingIpEnabled = floatingIpEnabled
        self.masterLbEnabled = masterLbEnabled
        self.labels = labels
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.links = links
    }

    // MARK: - ResourceIdentifiable

    public var id: String {
        return uuid
    }

    // MARK: - Computed Properties

    /// Display name for the template
    public var displayName: String {
        return name ?? uuid
    }

    /// Formatted COE type for display
    public var coeDisplayName: String {
        switch coe.lowercased() {
        case "kubernetes": return "Kubernetes"
        case "swarm": return "Docker Swarm"
        case "mesos": return "Apache Mesos"
        default: return coe.capitalized
        }
    }
}

// MARK: - Nodegroup Models

/// OpenStack Magnum Nodegroup resource
///
/// Represents a group of nodes within a cluster with specific configuration.
/// Nodegroups allow heterogeneous node configurations within a single cluster.
public struct Nodegroup: Codable, Sendable, ResourceIdentifiable {
    /// Unique identifier for the nodegroup
    public let uuid: String

    /// Human-readable name
    public let name: String?

    /// UUID of the parent cluster
    public let clusterUuid: String

    /// Role of the nodegroup (master or worker)
    public let role: String?

    /// Current status
    public let status: String?

    /// Detailed status reason
    public let statusReason: String?

    /// Flavor ID for nodes in this group
    public let flavorId: String?

    /// Image ID for nodes in this group
    public let imageId: String?

    /// Current number of nodes
    public let nodeCount: Int?

    /// Minimum number of nodes (for autoscaling)
    public let minNodeCount: Int?

    /// Maximum number of nodes (for autoscaling)
    public let maxNodeCount: Int?

    /// Docker volume size in GB
    public let dockerVolumeSize: Int?

    /// IP addresses of nodes
    public let nodeAddresses: [String]?

    /// Custom labels
    public let labels: [String: String]?

    /// Project ID that owns this nodegroup
    public let projectId: String?

    /// Creation timestamp
    public let createdAt: Date?

    /// Last update timestamp
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case clusterUuid = "cluster_uuid"
        case role
        case status
        case statusReason = "status_reason"
        case flavorId = "flavor_id"
        case imageId = "image_id"
        case nodeCount = "node_count"
        case minNodeCount = "min_node_count"
        case maxNodeCount = "max_node_count"
        case dockerVolumeSize = "docker_volume_size"
        case nodeAddresses = "node_addresses"
        case labels
        case projectId = "project_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        uuid: String,
        name: String? = nil,
        clusterUuid: String,
        role: String? = nil,
        status: String? = nil,
        statusReason: String? = nil,
        flavorId: String? = nil,
        imageId: String? = nil,
        nodeCount: Int? = nil,
        minNodeCount: Int? = nil,
        maxNodeCount: Int? = nil,
        dockerVolumeSize: Int? = nil,
        nodeAddresses: [String]? = nil,
        labels: [String: String]? = nil,
        projectId: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.clusterUuid = clusterUuid
        self.role = role
        self.status = status
        self.statusReason = statusReason
        self.flavorId = flavorId
        self.imageId = imageId
        self.nodeCount = nodeCount
        self.minNodeCount = minNodeCount
        self.maxNodeCount = maxNodeCount
        self.dockerVolumeSize = dockerVolumeSize
        self.nodeAddresses = nodeAddresses
        self.labels = labels
        self.projectId = projectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - ResourceIdentifiable

    public var id: String {
        return uuid
    }

    // MARK: - Computed Properties

    /// Display name for the nodegroup
    public var displayName: String {
        return name ?? uuid
    }

    /// Whether this is a master nodegroup
    public var isMaster: Bool {
        return role?.lowercased() == "master"
    }

    /// Whether this is a worker nodegroup
    public var isWorker: Bool {
        return role?.lowercased() == "worker"
    }

    /// Check if nodegroup is healthy
    public var isActive: Bool {
        guard let status = status?.uppercased() else { return false }
        return status == "CREATE_COMPLETE" || status == "UPDATE_COMPLETE"
    }
}

// MARK: - Response Wrappers

/// Response wrapper for cluster list API
public struct ClusterListResponse: Codable, Sendable {
    public let clusters: [Cluster]

    public init(clusters: [Cluster]) {
        self.clusters = clusters
    }
}

/// Response wrapper for cluster template list API
public struct ClusterTemplateListResponse: Codable, Sendable {
    public let clustertemplates: [ClusterTemplate]

    public init(clustertemplates: [ClusterTemplate]) {
        self.clustertemplates = clustertemplates
    }
}

/// Response wrapper for nodegroup list API
public struct NodegroupListResponse: Codable, Sendable {
    public let nodegroups: [Nodegroup]

    public init(nodegroups: [Nodegroup]) {
        self.nodegroups = nodegroups
    }
}

// MARK: - Request DTOs

/// Request body for creating a new cluster
public struct ClusterCreateRequest: Codable, Sendable {
    /// Name for the new cluster
    public let name: String

    /// UUID of the cluster template to use
    public let clusterTemplateId: String

    /// Name of the SSH keypair for node access
    public let keypair: String?

    /// Number of master nodes (default: 1)
    public let masterCount: Int?

    /// Number of worker nodes (default: 1)
    public let nodeCount: Int?

    /// Timeout for cluster creation in minutes
    public let createTimeout: Int?

    /// Custom labels to apply to the cluster
    public let labels: [String: String]?

    /// Discovery URL for cluster bootstrapping (optional)
    public let discoveryUrl: String?

    /// Docker volume size in GB (optional)
    public let dockerVolumeSize: Int?

    /// Override flavor for master nodes
    public let masterFlavorId: String?

    /// Override flavor for worker nodes
    public let flavorId: String?

    /// Fixed network ID (optional)
    public let fixedNetwork: String?

    /// Fixed subnet ID (optional)
    public let fixedSubnet: String?

    /// Whether to enable floating IPs
    public let floatingIpEnabled: Bool?

    /// Whether to enable master load balancer
    public let masterLbEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case clusterTemplateId = "cluster_template_id"
        case keypair
        case masterCount = "master_count"
        case nodeCount = "node_count"
        case createTimeout = "create_timeout"
        case labels
        case discoveryUrl = "discovery_url"
        case dockerVolumeSize = "docker_volume_size"
        case masterFlavorId = "master_flavor_id"
        case flavorId = "flavor_id"
        case fixedNetwork = "fixed_network"
        case fixedSubnet = "fixed_subnet"
        case floatingIpEnabled = "floating_ip_enabled"
        case masterLbEnabled = "master_lb_enabled"
    }

    public init(
        name: String,
        clusterTemplateId: String,
        keypair: String? = nil,
        masterCount: Int? = nil,
        nodeCount: Int? = nil,
        createTimeout: Int? = nil,
        labels: [String: String]? = nil,
        discoveryUrl: String? = nil,
        dockerVolumeSize: Int? = nil,
        masterFlavorId: String? = nil,
        flavorId: String? = nil,
        fixedNetwork: String? = nil,
        fixedSubnet: String? = nil,
        floatingIpEnabled: Bool? = nil,
        masterLbEnabled: Bool? = nil
    ) {
        self.name = name
        self.clusterTemplateId = clusterTemplateId
        self.keypair = keypair
        self.masterCount = masterCount
        self.nodeCount = nodeCount
        self.createTimeout = createTimeout
        self.labels = labels
        self.discoveryUrl = discoveryUrl
        self.dockerVolumeSize = dockerVolumeSize
        self.masterFlavorId = masterFlavorId
        self.flavorId = flavorId
        self.fixedNetwork = fixedNetwork
        self.fixedSubnet = fixedSubnet
        self.floatingIpEnabled = floatingIpEnabled
        self.masterLbEnabled = masterLbEnabled
    }
}

/// Response from cluster creation (202 Accepted)
///
/// The Magnum API returns a minimal response with just the UUID when a cluster
/// creation request is accepted.
public struct ClusterCreateResponse: Codable, Sendable {
    /// UUID of the newly created cluster
    public let uuid: String

    /// Name of the cluster (may be included)
    public let name: String?

    /// Status of the cluster (typically "CREATE_IN_PROGRESS")
    public let status: String?

    /// Status reason
    public let statusReason: String?

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case status
        case statusReason = "status_reason"
    }

    /// Display name for UI
    public var displayName: String {
        name ?? uuid
    }
}

/// Request body for resizing a cluster
public struct ClusterResizeRequest: Codable, Sendable {
    /// New number of worker nodes
    public let nodeCount: Int

    /// Specific nodegroup to resize (optional)
    public let nodegroupId: String?

    /// Nodes to remove when scaling down (optional)
    public let nodesToRemove: [String]?

    enum CodingKeys: String, CodingKey {
        case nodeCount = "node_count"
        case nodegroupId = "nodegroup"
        case nodesToRemove = "nodes_to_remove"
    }

    public init(
        nodeCount: Int,
        nodegroupId: String? = nil,
        nodesToRemove: [String]? = nil
    ) {
        self.nodeCount = nodeCount
        self.nodegroupId = nodegroupId
        self.nodesToRemove = nodesToRemove
    }
}

/// Request body for upgrading a cluster
public struct ClusterUpgradeRequest: Codable, Sendable {
    /// UUID of the new cluster template
    public let clusterTemplate: String

    /// Maximum number of nodes to drain at once (optional)
    public let maxBatchSize: Int?

    /// Specific nodegroup to upgrade (optional)
    public let nodegroupId: String?

    enum CodingKeys: String, CodingKey {
        case clusterTemplate = "cluster_template"
        case maxBatchSize = "max_batch_size"
        case nodegroupId = "nodegroup"
    }

    public init(
        clusterTemplate: String,
        maxBatchSize: Int? = nil,
        nodegroupId: String? = nil
    ) {
        self.clusterTemplate = clusterTemplate
        self.maxBatchSize = maxBatchSize
        self.nodegroupId = nodegroupId
    }
}

/// Request body for creating a new cluster template
public struct ClusterTemplateCreateRequest: Codable, Sendable {
    /// Name for the template (required)
    public let name: String

    /// Container orchestration engine: kubernetes, swarm, mesos (required)
    public let coe: String

    /// Image ID for cluster nodes (required)
    public let imageId: String

    /// External network ID for floating IPs
    public let externalNetworkId: String?

    /// Default flavor for worker nodes
    public let flavorId: String?

    /// Flavor for master nodes
    public let masterFlavorId: String?

    /// SSH keypair for node access
    public let keypairId: String?

    /// Fixed network ID
    public let fixedNetwork: String?

    /// Fixed subnet ID
    public let fixedSubnet: String?

    /// Network driver (flannel, calico, etc.)
    public let networkDriver: String?

    /// Volume driver for persistent storage
    public let volumeDriver: String?

    /// Docker volume size in GB
    public let dockerVolumeSize: Int?

    /// DNS nameserver for the cluster
    public let dnsNameserver: String?

    /// Whether floating IPs are enabled
    public let floatingIpEnabled: Bool?

    /// Whether master load balancer is enabled
    public let masterLbEnabled: Bool?

    /// Whether TLS is disabled
    public let tlsDisabled: Bool?

    /// Whether template is public
    public let isPublic: Bool?

    /// Whether registry is enabled
    public let registryEnabled: Bool?

    /// HTTP proxy URL
    public let httpProxy: String?

    /// HTTPS proxy URL
    public let httpsProxy: String?

    /// No proxy list
    public let noProxy: String?

    /// Custom labels
    public let labels: [String: String]?

    enum CodingKeys: String, CodingKey {
        case name
        case coe
        case imageId = "image_id"
        case externalNetworkId = "external_network_id"
        case flavorId = "flavor_id"
        case masterFlavorId = "master_flavor_id"
        case keypairId = "keypair_id"
        case fixedNetwork = "fixed_network"
        case fixedSubnet = "fixed_subnet"
        case networkDriver = "network_driver"
        case volumeDriver = "volume_driver"
        case dockerVolumeSize = "docker_volume_size"
        case dnsNameserver = "dns_nameserver"
        case floatingIpEnabled = "floating_ip_enabled"
        case masterLbEnabled = "master_lb_enabled"
        case tlsDisabled = "tls_disabled"
        case isPublic = "public"
        case registryEnabled = "registry_enabled"
        case httpProxy = "http_proxy"
        case httpsProxy = "https_proxy"
        case noProxy = "no_proxy"
        case labels
    }

    public init(
        name: String,
        coe: String,
        imageId: String,
        externalNetworkId: String? = nil,
        flavorId: String? = nil,
        masterFlavorId: String? = nil,
        keypairId: String? = nil,
        fixedNetwork: String? = nil,
        fixedSubnet: String? = nil,
        networkDriver: String? = nil,
        volumeDriver: String? = nil,
        dockerVolumeSize: Int? = nil,
        dnsNameserver: String? = nil,
        floatingIpEnabled: Bool? = nil,
        masterLbEnabled: Bool? = nil,
        tlsDisabled: Bool? = nil,
        isPublic: Bool? = nil,
        registryEnabled: Bool? = nil,
        httpProxy: String? = nil,
        httpsProxy: String? = nil,
        noProxy: String? = nil,
        labels: [String: String]? = nil
    ) {
        self.name = name
        self.coe = coe
        self.imageId = imageId
        self.externalNetworkId = externalNetworkId
        self.flavorId = flavorId
        self.masterFlavorId = masterFlavorId
        self.keypairId = keypairId
        self.fixedNetwork = fixedNetwork
        self.fixedSubnet = fixedSubnet
        self.networkDriver = networkDriver
        self.volumeDriver = volumeDriver
        self.dockerVolumeSize = dockerVolumeSize
        self.dnsNameserver = dnsNameserver
        self.floatingIpEnabled = floatingIpEnabled
        self.masterLbEnabled = masterLbEnabled
        self.tlsDisabled = tlsDisabled
        self.isPublic = isPublic
        self.registryEnabled = registryEnabled
        self.httpProxy = httpProxy
        self.httpsProxy = httpsProxy
        self.noProxy = noProxy
        self.labels = labels
    }
}

// MARK: - Cluster Status Enum

/// Known status values for Magnum clusters
public enum ClusterStatus: String, CaseIterable, Sendable {
    case createInProgress = "CREATE_IN_PROGRESS"
    case createComplete = "CREATE_COMPLETE"
    case createFailed = "CREATE_FAILED"
    case updateInProgress = "UPDATE_IN_PROGRESS"
    case updateComplete = "UPDATE_COMPLETE"
    case updateFailed = "UPDATE_FAILED"
    case deleteInProgress = "DELETE_IN_PROGRESS"
    case deleteComplete = "DELETE_COMPLETE"
    case deleteFailed = "DELETE_FAILED"
    case resumeInProgress = "RESUME_IN_PROGRESS"
    case resumeComplete = "RESUME_COMPLETE"
    case resumeFailed = "RESUME_FAILED"
    case restoreInProgress = "RESTORE_IN_PROGRESS"
    case restoreComplete = "RESTORE_COMPLETE"
    case rollbackInProgress = "ROLLBACK_IN_PROGRESS"
    case rollbackComplete = "ROLLBACK_COMPLETE"
    case rollbackFailed = "ROLLBACK_FAILED"
    case snapshotInProgress = "SNAPSHOT_IN_PROGRESS"
    case snapshotComplete = "SNAPSHOT_COMPLETE"
    case adoptInProgress = "ADOPT_IN_PROGRESS"
    case adoptComplete = "ADOPT_COMPLETE"
    case adoptFailed = "ADOPT_FAILED"
    case checkInProgress = "CHECK_IN_PROGRESS"
    case checkComplete = "CHECK_COMPLETE"
    case checkFailed = "CHECK_FAILED"

    /// Whether this status indicates the cluster is healthy and operational
    public var isHealthy: Bool {
        switch self {
        case .createComplete, .updateComplete, .resumeComplete, .restoreComplete,
             .rollbackComplete, .snapshotComplete, .adoptComplete, .checkComplete:
            return true
        default:
            return false
        }
    }

    /// Whether this status indicates an operation is in progress
    public var isInProgress: Bool {
        return rawValue.contains("IN_PROGRESS")
    }

    /// Whether this status indicates a failure
    public var isFailed: Bool {
        return rawValue.contains("FAILED")
    }

    /// Display-friendly status text
    public var displayText: String {
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
