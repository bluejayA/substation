import Foundation

// MARK: - Network Models

public struct Network: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let id: String
    public let name: String?
    public let description: String?
    public let status: String?
    public let adminStateUp: Bool?
    public let shared: Bool?
    public let external: Bool?
    public let subnets: [String]?
    public let tenantId: String?
    public let projectId: String?
    public let providerNetworkType: String?
    public let providerPhysicalNetwork: String?
    public let providerSegmentationId: Int?
    public var routerExternal: Bool? { external }
    public let createdAt: Date?
    public let updatedAt: Date?
    public let revisionNumber: Int?
    public let availabilityZones: [String]?
    public let availabilityZoneHints: [String]?
    public let ipv4AddressScope: String?
    public let ipv6AddressScope: String?
    public let dnsName: String?
    public let dnsDomain: String?
    public let mtu: Int?
    public let portSecurityEnabled: Bool?
    public let qosPolicyId: String?
    public let segments: [NetworkSegment]?
    public let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case status
        case adminStateUp = "admin_state_up"
        case shared
        case external = "router:external"
        case subnets
        case tenantId = "tenant_id"
        case projectId = "project_id"
        case providerNetworkType = "provider:network_type"
        case providerPhysicalNetwork = "provider:physical_network"
        case providerSegmentationId = "provider:segmentation_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revisionNumber = "revision_number"
        case availabilityZones = "availability_zones"
        case availabilityZoneHints = "availability_zone_hints"
        case ipv4AddressScope = "ipv4_address_scope"
        case ipv6AddressScope = "ipv6_address_scope"
        case dnsName = "dns_name"
        case dnsDomain = "dns_domain"
        case mtu
        case portSecurityEnabled = "port_security_enabled"
        case qosPolicyId = "qos_policy_id"
        case segments
        case tags
    }

    public init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        status: String? = nil,
        adminStateUp: Bool? = nil,
        shared: Bool? = nil,
        external: Bool? = nil,
        subnets: [String]? = nil,
        tenantId: String? = nil,
        projectId: String? = nil,
        providerNetworkType: String? = nil,
        providerPhysicalNetwork: String? = nil,
        providerSegmentationId: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        revisionNumber: Int? = nil,
        availabilityZones: [String]? = nil,
        availabilityZoneHints: [String]? = nil,
        ipv4AddressScope: String? = nil,
        ipv6AddressScope: String? = nil,
        dnsName: String? = nil,
        dnsDomain: String? = nil,
        mtu: Int? = nil,
        portSecurityEnabled: Bool? = nil,
        qosPolicyId: String? = nil,
        segments: [NetworkSegment]? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.adminStateUp = adminStateUp
        self.shared = shared
        self.external = external
        self.subnets = subnets
        self.tenantId = tenantId
        self.projectId = projectId
        self.providerNetworkType = providerNetworkType
        self.providerPhysicalNetwork = providerPhysicalNetwork
        self.providerSegmentationId = providerSegmentationId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revisionNumber = revisionNumber
        self.availabilityZones = availabilityZones
        self.availabilityZoneHints = availabilityZoneHints
        self.ipv4AddressScope = ipv4AddressScope
        self.ipv6AddressScope = ipv6AddressScope
        self.dnsName = dnsName
        self.dnsDomain = dnsDomain
        self.mtu = mtu
        self.portSecurityEnabled = portSecurityEnabled
        self.qosPolicyId = qosPolicyId
        self.segments = segments
        self.tags = tags
    }

    // MARK: - Computed Properties

    public var isActive: Bool {
        return status?.lowercased() == "active"
    }

    public var isExternal: Bool {
        return external == true || routerExternal == true
    }

    public var displayName: String {
        return name ?? id
    }
}

public struct NetworkSegment: Codable, Sendable {
    public let providerNetworkType: String?
    public let providerPhysicalNetwork: String?
    public let providerSegmentationId: Int?

    enum CodingKeys: String, CodingKey {
        case providerNetworkType = "provider:network_type"
        case providerPhysicalNetwork = "provider:physical_network"
        case providerSegmentationId = "provider:segmentation_id"
    }
}

// MARK: - Subnet Models

public struct Subnet: Codable, Sendable, ResourceIdentifiable, Timestamped, Identifiable {
    public let id: String
    public let name: String?
    public let description: String?
    public let networkId: String
    public let ipVersion: Int
    public let cidr: String
    public let gatewayIp: String?
    public let dhcpEnabled: Bool?
    public let dnsNameservers: [String]?
    public let allocationPools: [AllocationPool]?
    public let hostRoutes: [HostRoute]?
    public let enableDhcp: Bool?
    public let tenantId: String?
    public let projectId: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let revisionNumber: Int?
    public let subnetpoolId: String?
    public let useDefaultSubnetpool: Bool?
    public let ipv6AddressMode: String?
    public let ipv6RaMode: String?
    public let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case networkId = "network_id"
        case ipVersion = "ip_version"
        case cidr
        case gatewayIp = "gateway_ip"
        case dhcpEnabled = "dhcp_enabled"
        case dnsNameservers = "dns_nameservers"
        case allocationPools = "allocation_pools"
        case hostRoutes = "host_routes"
        case enableDhcp = "enable_dhcp"
        case tenantId = "tenant_id"
        case projectId = "project_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revisionNumber = "revision_number"
        case subnetpoolId = "subnetpool_id"
        case useDefaultSubnetpool = "use_default_subnetpool"
        case ipv6AddressMode = "ipv6_address_mode"
        case ipv6RaMode = "ipv6_ra_mode"
        case tags
    }
}

public struct AllocationPool: Codable, Sendable {
    public let start: String
    public let end: String

    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }
}

public struct HostRoute: Codable, Sendable {
    public let destination: String
    public let nexthop: String

    public init(destination: String, nexthop: String) {
        self.destination = destination
        self.nexthop = nexthop
    }
}

// MARK: - Port Models

public struct Port: Codable, Sendable, ResourceIdentifiable, Timestamped, Identifiable {
    public let id: String
    public let name: String?
    public let description: String?
    public let networkId: String
    public let adminStateUp: Bool?
    public let status: String?
    public let macAddress: String?
    public let fixedIps: [FixedIP]?
    public let deviceId: String?
    public let deviceOwner: String?
    public let tenantId: String?
    public let projectId: String?
    public let securityGroups: [String]?
    public let allowedAddressPairs: [AddressPair]?
    public let extraDhcpOpts: [DhcpOption]?
    public let bindingHostId: String?
    public let bindingProfile: [String: String]?
    public let bindingVifDetails: [String: String]?
    public let bindingVifType: String?
    public let bindingVnicType: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let revisionNumber: Int?
    public let portSecurityEnabled: Bool?
    public let qosPolicyId: String?
    public let tags: [String]?
    public let propagateUplinkStatus: Bool?
    public let resourceRequest: ResourceRequest?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case networkId = "network_id"
        case adminStateUp = "admin_state_up"
        case status
        case macAddress = "mac_address"
        case fixedIps = "fixed_ips"
        case deviceId = "device_id"
        case deviceOwner = "device_owner"
        case tenantId = "tenant_id"
        case projectId = "project_id"
        case securityGroups = "security_groups"
        case allowedAddressPairs = "allowed_address_pairs"
        case extraDhcpOpts = "extra_dhcp_opts"
        case bindingHostId = "binding:host_id"
        case bindingProfile = "binding:profile"
        case bindingVifDetails = "binding:vif_details"
        case bindingVifType = "binding:vif_type"
        case bindingVnicType = "binding:vnic_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revisionNumber = "revision_number"
        case portSecurityEnabled = "port_security_enabled"
        case qosPolicyId = "qos_policy_id"
        case tags
        case propagateUplinkStatus = "propagate_uplink_status"
        case resourceRequest = "resource_request"
    }
}

public struct FixedIP: Codable, Sendable {
    public let subnetId: String
    public let ipAddress: String

    enum CodingKeys: String, CodingKey {
        case subnetId = "subnet_id"
        case ipAddress = "ip_address"
    }

    public init(subnetId: String, ipAddress: String) {
        self.subnetId = subnetId
        self.ipAddress = ipAddress
    }
}

public struct AddressPair: Codable, Sendable {
    public let ipAddress: String
    public let macAddress: String?

    enum CodingKeys: String, CodingKey {
        case ipAddress = "ip_address"
        case macAddress = "mac_address"
    }

    public init(ipAddress: String, macAddress: String? = nil) {
        self.ipAddress = ipAddress
        self.macAddress = macAddress
    }
}

public struct DhcpOption: Codable, Sendable {
    public let optName: String
    public let optValue: String

    enum CodingKeys: String, CodingKey {
        case optName = "opt_name"
        case optValue = "opt_value"
    }

    public init(optName: String, optValue: String) {
        self.optName = optName
        self.optValue = optValue
    }
}

public struct ResourceRequest: Codable, Sendable {
    public let requiredNeutronResources: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case requiredNeutronResources = "required_neutron_resources"
    }
}

// MARK: - Router Models

public struct Router: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let id: String
    public let name: String?
    public let description: String?
    public let status: String?
    public let adminStateUp: Bool?
    public let distributed: Bool?
    public let ha: Bool?
    public let externalGatewayInfo: ExternalGatewayInfo?
    public let tenantId: String?
    public let projectId: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let revisionNumber: Int?
    public let routes: [Route]?
    public let flavor_id: String?
    public let service_type_id: String?
    public let tags: [String]?
    public let conntrackHelpers: [ConntrackHelper]?

    // Router interface information (populated from interfaces_info or separately)
    public var interfaces: [RouterInterface]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case status
        case adminStateUp = "admin_state_up"
        case distributed
        case ha
        case externalGatewayInfo = "external_gateway_info"
        case tenantId = "tenant_id"
        case projectId = "project_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revisionNumber = "revision_number"
        case routes
        case flavor_id
        case service_type_id
        case tags
        case conntrackHelpers = "conntrack_helpers"
        case interfaces = "interfaces_info"
    }
}

public struct ExternalGatewayInfo: Codable, Sendable {
    public let networkId: String?
    public let enableSnat: Bool?
    public let externalFixedIps: [ExternalFixedIP]?

    enum CodingKeys: String, CodingKey {
        case networkId = "network_id"
        case enableSnat = "enable_snat"
        case externalFixedIps = "external_fixed_ips"
    }

    public init(
        networkId: String? = nil,
        enableSnat: Bool? = nil,
        externalFixedIps: [ExternalFixedIP]? = nil
    ) {
        self.networkId = networkId
        self.enableSnat = enableSnat
        self.externalFixedIps = externalFixedIps
    }
}

public struct ExternalFixedIP: Codable, Sendable {
    public let subnetId: String?
    public let ipAddress: String?

    enum CodingKeys: String, CodingKey {
        case subnetId = "subnet_id"
        case ipAddress = "ip_address"
    }
}

public struct Route: Codable, Sendable {
    public let destination: String
    public let nexthop: String

    public init(destination: String, nexthop: String) {
        self.destination = destination
        self.nexthop = nexthop
    }
}

public struct ConntrackHelper: Codable, Sendable {
    public let helper: String
    public let port: Int
    public let `protocol`: String

    public init(helper: String, port: Int, protocol: String) {
        self.helper = helper
        self.port = port
        self.`protocol` = `protocol`
    }
}

public struct RouterInterface: Codable, Sendable {
    public let subnetId: String?
    public let portId: String?
    public let ipAddress: String?

    public init(subnetId: String?, portId: String?, ipAddress: String?) {
        self.subnetId = subnetId
        self.portId = portId
        self.ipAddress = ipAddress
    }

    enum CodingKeys: String, CodingKey {
        case subnetId = "subnet_id"
        case portId = "port_id"
        case ipAddress = "ip_address"
    }
}

// MARK: - Security Group Models

public struct SecurityGroup: Codable, Sendable, ResourceIdentifiable, Timestamped, Identifiable {
    public let id: String
    public let name: String?
    public let description: String?
    public let tenantId: String?
    public let projectId: String?
    public let securityGroupRules: [SecurityGroupRule]?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let revisionNumber: Int?
    public let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case tenantId = "tenant_id"
        case projectId = "project_id"
        case securityGroupRules = "security_group_rules"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revisionNumber = "revision_number"
        case tags
    }
}

public struct SecurityGroupRule: Codable, Sendable, ResourceIdentifiable {
    public let id: String
    public let securityGroupId: String
    public let direction: String
    public let ethertype: String?
    public let `protocol`: String?
    public let portRangeMin: Int?
    public let portRangeMax: Int?
    public let remoteIpPrefix: String?
    public let remoteGroupId: String?
    public let tenantId: String?
    public let projectId: String?
    public let description: String?
    public let revisionNumber: Int?
    public let tags: [String]?

    public var name: String? { return description }

    // Enum conversion properties for backward compatibility
    public var directionEnum: SecurityGroupDirection? {
        return SecurityGroupDirection(rawValue: direction)
    }

    public var protocolEnum: SecurityGroupProtocol? {
        guard let protocolStr = `protocol` else { return nil }
        return SecurityGroupProtocol(rawValue: protocolStr)
    }

    public var ethertypeEnum: SecurityGroupEtherType? {
        guard let ethertypeStr = ethertype else { return nil }
        return SecurityGroupEtherType(rawValue: ethertypeStr)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case securityGroupId = "security_group_id"
        case direction
        case ethertype
        case `protocol`
        case portRangeMin = "port_range_min"
        case portRangeMax = "port_range_max"
        case remoteIpPrefix = "remote_ip_prefix"
        case remoteGroupId = "remote_group_id"
        case tenantId = "tenant_id"
        case projectId = "project_id"
        case description
        case revisionNumber = "revision_number"
        case tags
    }
}

// MARK: - Floating IP Models

public struct FloatingIP: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let id: String
    public let floatingNetworkId: String
    public let floatingIpAddress: String?
    public let fixedIpAddress: String?
    public let portId: String?
    public let status: String?
    public let tenantId: String?
    public let projectId: String?
    public let description: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let revisionNumber: Int?
    public let routerId: String?
    public let portDetails: PortDetails?
    public let dnsName: String?
    public let dnsDomain: String?
    public let tags: [String]?
    public let qosPolicyId: String?

    public var name: String? { return description }

    enum CodingKeys: String, CodingKey {
        case id
        case floatingNetworkId = "floating_network_id"
        case floatingIpAddress = "floating_ip_address"
        case fixedIpAddress = "fixed_ip_address"
        case portId = "port_id"
        case status
        case tenantId = "tenant_id"
        case projectId = "project_id"
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revisionNumber = "revision_number"
        case routerId = "router_id"
        case portDetails = "port_details"
        case dnsName = "dns_name"
        case dnsDomain = "dns_domain"
        case tags
        case qosPolicyId = "qos_policy_id"
    }
}

public struct PortDetails: Codable, Sendable {
    public let name: String?
    public let networkId: String?
    public let macAddress: String?
    public let adminStateUp: Bool?
    public let status: String?
    public let deviceId: String?
    public let deviceOwner: String?

    enum CodingKeys: String, CodingKey {
        case name
        case networkId = "network_id"
        case macAddress = "mac_address"
        case adminStateUp = "admin_state_up"
        case status
        case deviceId = "device_id"
        case deviceOwner = "device_owner"
    }
}

// MARK: - Request Models

public struct CreateNetworkRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let adminStateUp: Bool?
    public let shared: Bool?
    public let external: Bool?
    public let providerNetworkType: String?
    public let providerPhysicalNetwork: String?
    public let providerSegmentationId: Int?
    public let segments: [NetworkSegment]?
    public let mtu: Int?
    public let portSecurityEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case adminStateUp = "admin_state_up"
        case shared
        case external = "router:external"
        case providerNetworkType = "provider:network_type"
        case providerPhysicalNetwork = "provider:physical_network"
        case providerSegmentationId = "provider:segmentation_id"
        case segments
        case mtu
        case portSecurityEnabled = "port_security_enabled"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        adminStateUp: Bool? = nil,
        shared: Bool? = nil,
        external: Bool? = nil,
        providerNetworkType: String? = nil,
        providerPhysicalNetwork: String? = nil,
        providerSegmentationId: Int? = nil,
        segments: [NetworkSegment]? = nil,
        mtu: Int? = nil,
        portSecurityEnabled: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.adminStateUp = adminStateUp
        self.shared = shared
        self.external = external
        self.providerNetworkType = providerNetworkType
        self.providerPhysicalNetwork = providerPhysicalNetwork
        self.providerSegmentationId = providerSegmentationId
        self.segments = segments
        self.mtu = mtu
        self.portSecurityEnabled = portSecurityEnabled
    }
}

public struct UpdateNetworkRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let adminStateUp: Bool?
    public let shared: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case adminStateUp = "admin_state_up"
        case shared
    }
}

public struct CreateSubnetRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let networkId: String
    public let ipVersion: Int
    public let cidr: String
    public let gatewayIp: String?
    public let enableDhcp: Bool?
    public let dnsNameservers: [String]?
    public let allocationPools: [AllocationPool]?
    public let hostRoutes: [HostRoute]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case networkId = "network_id"
        case ipVersion = "ip_version"
        case cidr
        case gatewayIp = "gateway_ip"
        case enableDhcp = "enable_dhcp"
        case dnsNameservers = "dns_nameservers"
        case allocationPools = "allocation_pools"
        case hostRoutes = "host_routes"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        networkId: String,
        ipVersion: Int,
        cidr: String,
        gatewayIp: String? = nil,
        enableDhcp: Bool? = nil,
        dnsNameservers: [String]? = nil,
        allocationPools: [AllocationPool]? = nil,
        hostRoutes: [HostRoute]? = nil
    ) {
        self.name = name
        self.description = description
        self.networkId = networkId
        self.ipVersion = ipVersion
        self.cidr = cidr
        self.gatewayIp = gatewayIp
        self.enableDhcp = enableDhcp
        self.dnsNameservers = dnsNameservers
        self.allocationPools = allocationPools
        self.hostRoutes = hostRoutes
    }
}

public struct UpdateSubnetRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let enableDhcp: Bool?
    public let dnsNameservers: [String]?
    public let hostRoutes: [HostRoute]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case enableDhcp = "enable_dhcp"
        case dnsNameservers = "dns_nameservers"
        case hostRoutes = "host_routes"
    }
}

public struct CreatePortRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let networkId: String
    public let adminStateUp: Bool?
    public let macAddress: String?
    public let fixedIps: [FixedIP]?
    public let deviceId: String?
    public let deviceOwner: String?
    public let securityGroups: [String]?

    public init(
        name: String? = nil,
        description: String? = nil,
        networkId: String,
        adminStateUp: Bool? = nil,
        macAddress: String? = nil,
        fixedIps: [FixedIP]? = nil,
        deviceId: String? = nil,
        deviceOwner: String? = nil,
        securityGroups: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.networkId = networkId
        self.adminStateUp = adminStateUp
        self.macAddress = macAddress
        self.fixedIps = fixedIps
        self.deviceId = deviceId
        self.deviceOwner = deviceOwner
        self.securityGroups = securityGroups
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case networkId = "network_id"
        case adminStateUp = "admin_state_up"
        case macAddress = "mac_address"
        case fixedIps = "fixed_ips"
        case deviceId = "device_id"
        case deviceOwner = "device_owner"
        case securityGroups = "security_groups"
    }
}

public struct UpdatePortRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let adminStateUp: Bool?
    public let fixedIps: [FixedIP]?
    public let deviceId: String?
    public let deviceOwner: String?
    public let securityGroups: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case adminStateUp = "admin_state_up"
        case fixedIps = "fixed_ips"
        case deviceId = "device_id"
        case deviceOwner = "device_owner"
        case securityGroups = "security_groups"
    }
}

public struct CreateRouterRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let adminStateUp: Bool?
    public let distributed: Bool?
    public let ha: Bool?
    public let externalGatewayInfo: ExternalGatewayInfo?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case adminStateUp = "admin_state_up"
        case distributed
        case ha
        case externalGatewayInfo = "external_gateway_info"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        adminStateUp: Bool? = true,
        distributed: Bool? = nil,
        ha: Bool? = nil,
        externalGatewayInfo: ExternalGatewayInfo? = nil
    ) {
        self.name = name
        self.description = description
        self.adminStateUp = adminStateUp
        self.distributed = distributed
        self.ha = ha
        self.externalGatewayInfo = externalGatewayInfo
    }
}

public struct UpdateRouterRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let adminStateUp: Bool?
    public let externalGatewayInfo: ExternalGatewayInfo?
    public let routes: [Route]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case adminStateUp = "admin_state_up"
        case externalGatewayInfo = "external_gateway_info"
        case routes
    }
}

public struct CreateSecurityGroupRequest: Codable, Sendable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct CreateSecurityGroupRuleRequest: Codable, Sendable {
    public let securityGroupId: String
    public let direction: String
    public let ethertype: String?
    public let `protocol`: String?
    public let portRangeMin: Int?
    public let portRangeMax: Int?
    public let remoteIpPrefix: String?
    public let remoteGroupId: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case securityGroupId = "security_group_id"
        case direction
        case ethertype
        case `protocol`
        case portRangeMin = "port_range_min"
        case portRangeMax = "port_range_max"
        case remoteIpPrefix = "remote_ip_prefix"
        case remoteGroupId = "remote_group_id"
        case description
    }

    public init(
        securityGroupId: String,
        direction: String,
        ethertype: String? = nil,
        protocol: String? = nil,
        portRangeMin: Int? = nil,
        portRangeMax: Int? = nil,
        remoteIpPrefix: String? = nil,
        remoteGroupId: String? = nil,
        description: String? = nil
    ) {
        self.securityGroupId = securityGroupId
        self.direction = direction
        self.ethertype = ethertype
        self.`protocol` = `protocol`
        self.portRangeMin = portRangeMin
        self.portRangeMax = portRangeMax
        self.remoteIpPrefix = remoteIpPrefix
        self.remoteGroupId = remoteGroupId
        self.description = description
    }
}

public struct CreateFloatingIPRequest: Codable, Sendable {
    public let floatingNetworkId: String
    public let portId: String?
    public let subnetId: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case floatingNetworkId = "floating_network_id"
        case portId = "port_id"
        case subnetId = "subnet_id"
        case description
    }

    public init(floatingNetworkId: String, portId: String? = nil, subnetId: String? = nil, description: String? = nil) {
        self.floatingNetworkId = floatingNetworkId
        self.portId = portId
        self.subnetId = subnetId
        self.description = description
    }
}

public struct UpdateFloatingIPRequest: Codable, Sendable {
    public let portId: String?
    public let fixedIpAddress: String?

    enum CodingKeys: String, CodingKey {
        case portId = "port_id"
        case fixedIpAddress = "fixed_ip_address"
    }

    public init(portId: String? = nil, fixedIpAddress: String? = nil) {
        self.portId = portId
        self.fixedIpAddress = fixedIpAddress
    }
}

// MARK: - Request Wrapper Models

public struct FloatingIPWrapper<T: Codable>: Codable, Sendable where T: Sendable {
    public let floatingip: T

    public init(floatingip: T) {
        self.floatingip = floatingip
    }
}

// MARK: - Security Group Enum Types

public enum SecurityGroupDirection: String, CaseIterable, Sendable {
    case ingress = "ingress"
    case egress = "egress"

    public var displayName: String {
        switch self {
        case .ingress: return "Ingress"
        case .egress: return "Egress"
        }
    }
}

public enum SecurityGroupProtocol: String, CaseIterable, Sendable {
    case tcp = "tcp"
    case udp = "udp"
    case icmp = "icmp"
    case any = "any"

    public var displayName: String {
        switch self {
        case .tcp: return "TCP"
        case .udp: return "UDP"
        case .icmp: return "ICMP"
        case .any: return "Any"
        }
    }
}

public enum SecurityGroupEtherType: String, CaseIterable, Sendable {
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"

    public var displayName: String {
        return rawValue
    }
}

public enum SecurityGroupPortType: CaseIterable, Sendable {
    case all
    case custom

    public var displayName: String {
        switch self {
        case .all: return "All Ports"
        case .custom: return "Custom Range"
        }
    }
}

public enum SecurityGroupRemoteType: CaseIterable, Sendable {
    case cidr
    case securityGroup

    public var displayName: String {
        switch self {
        case .cidr: return "CIDR"
        case .securityGroup: return "Security Group"
        }
    }
}

// MARK: - Port Enum Types

public enum PortType: String, CaseIterable, Sendable {
    case normal = "normal"
    case direct = "direct"
    case macvtap = "macvtap"
    case directPhysical = "direct-physical"
    case baremetal = "baremetal"
    case virtioForwarder = "virtio-forwarder"
    case smartNic = "smart-nic"

    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .direct: return "Direct"
        case .macvtap: return "Macvtap"
        case .directPhysical: return "Direct Physical"
        case .baremetal: return "Baremetal"
        case .virtioForwarder: return "Virtio Forwarder"
        case .smartNic: return "Smart NIC"
        }
    }
}

// MARK: - Server Interface Model

public struct ServerInterface: Codable, Sendable {
    public let portID: String
    public let netID: String
    public let macAddr: String
    public let portState: String
    public let fixedIps: [AttachedFixedIP]

    enum CodingKeys: String, CodingKey {
        case portID = "port_id"
        case netID = "net_id"
        case macAddr = "mac_addr"
        case portState = "port_state"
        case fixedIps = "fixed_ips"
    }

    public init(portID: String, netID: String, macAddr: String, portState: String, fixedIps: [AttachedFixedIP]) {
        self.portID = portID
        self.netID = netID
        self.macAddr = macAddr
        self.portState = portState
        self.fixedIps = fixedIps
    }
}

// MARK: - QoS Policy Models

public struct QoSPolicy: Codable, Sendable, ResourceIdentifiable {
    public let id: String
    public let name: String?
    public let description: String?
    public let shared: Bool?
    public let isDefault: Bool?
    public let tenantId: String?
    public let projectId: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let revisionNumber: Int?
    public let rules: [QoSRule]?
    public let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case shared
        case isDefault = "is_default"
        case tenantId = "tenant_id"
        case projectId = "project_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revisionNumber = "revision_number"
        case rules
        case tags
    }

    public init(id: String, name: String? = nil, description: String? = nil,
                shared: Bool? = nil, isDefault: Bool? = nil, tenantId: String? = nil,
                projectId: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil,
                revisionNumber: Int? = nil, rules: [QoSRule]? = nil, tags: [String]? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.shared = shared
        self.isDefault = isDefault
        self.tenantId = tenantId
        self.projectId = projectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revisionNumber = revisionNumber
        self.rules = rules
        self.tags = tags
    }

    public var displayName: String {
        return name ?? id
    }
}

public struct QoSRule: Codable, Sendable {
    public let id: String
    public let type: String?
    public let maxKbps: Int?
    public let maxBurstKbps: Int?
    public let direction: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case maxKbps = "max_kbps"
        case maxBurstKbps = "max_burst_kbps"
        case direction
    }

    public init(id: String, type: String? = nil, maxKbps: Int? = nil,
                maxBurstKbps: Int? = nil, direction: String? = nil) {
        self.id = id
        self.type = type
        self.maxKbps = maxKbps
        self.maxBurstKbps = maxBurstKbps
        self.direction = direction
    }
}

// MARK: - Network Quota Models

public struct NetworkQuotaSet: Codable, Sendable {
    public let network: Int
    public let subnet: Int
    public let port: Int
    public let router: Int
    public let floatingip: Int
    public let securityGroup: Int
    public let securityGroupRule: Int
    public let rbacPolicy: Int
    public let subnetpool: Int

    enum CodingKeys: String, CodingKey {
        case network
        case subnet
        case port
        case router
        case floatingip
        case securityGroup = "security_group"
        case securityGroupRule = "security_group_rule"
        case rbacPolicy = "rbac_policy"
        case subnetpool
    }

    public init(
        network: Int,
        subnet: Int,
        port: Int,
        router: Int,
        floatingip: Int,
        securityGroup: Int,
        securityGroupRule: Int,
        rbacPolicy: Int,
        subnetpool: Int
    ) {
        self.network = network
        self.subnet = subnet
        self.port = port
        self.router = router
        self.floatingip = floatingip
        self.securityGroup = securityGroup
        self.securityGroupRule = securityGroupRule
        self.rbacPolicy = rbacPolicy
        self.subnetpool = subnetpool
    }
}
