import Foundation

// MARK: - Server Models

public struct Server: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let id: String
    public let name: String?
    public let status: ServerStatus?
    public let taskState: String?
    public let powerState: PowerState?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let launchedAt: Date?
    public let terminatedAt: Date?
    public let hostId: String?
    public let userId: String?
    public let tenantId: String?
    public let accessIPv4: String?
    public let accessIPv6: String?
    public let flavor: FlavorRef?
    public let image: ImageRef?
    public let addresses: [String: [NetworkAddress]]?
    public let metadata: [String: String]?
    public let securityGroups: [SecurityGroupRef]?
    public let keyName: String?
    public let configDrive: String?
    public let progress: Int?
    public let fault: Fault?
    public let availabilityZone: String?
    public let hypervisorHostname: String?
    public let instanceName: String?
    public let hostStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case taskState = "OS-EXT-STS:task_state"
        case powerState = "OS-EXT-STS:power_state"
        case createdAt = "created"
        case updatedAt = "updated"
        case launchedAt = "OS-SRV-USG:launched_at"
        case terminatedAt = "OS-SRV-USG:terminated_at"
        case hostId = "hostId"
        case userId = "user_id"
        case tenantId = "tenant_id"
        case accessIPv4 = "accessIPv4"
        case accessIPv6 = "accessIPv6"
        case flavor
        case image
        case addresses
        case metadata
        case securityGroups = "security_groups"
        case keyName = "key_name"
        case configDrive = "config_drive"
        case progress
        case fault
        case availabilityZone = "OS-EXT-AZ:availability_zone"
        case hypervisorHostname = "OS-EXT-SRV-ATTR:hypervisor_hostname"
        case instanceName = "OS-EXT-SRV-ATTR:instance_name"
        case hostStatus = "host_status"
    }

    // Custom decoding to handle field type variations
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Standard fields
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        status = try container.decodeIfPresent(ServerStatus.self, forKey: .status)
        taskState = try container.decodeIfPresent(String.self, forKey: .taskState)
        powerState = try container.decodeIfPresent(PowerState.self, forKey: .powerState)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        launchedAt = try container.decodeIfPresent(Date.self, forKey: .launchedAt)
        terminatedAt = try container.decodeIfPresent(Date.self, forKey: .terminatedAt)
        hostId = try container.decodeIfPresent(String.self, forKey: .hostId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        tenantId = try container.decodeIfPresent(String.self, forKey: .tenantId)
        accessIPv4 = try container.decodeIfPresent(String.self, forKey: .accessIPv4)
        accessIPv6 = try container.decodeIfPresent(String.self, forKey: .accessIPv6)
        addresses = try container.decodeIfPresent([String: [NetworkAddress]].self, forKey: .addresses)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        securityGroups = try container.decodeIfPresent([SecurityGroupRef].self, forKey: .securityGroups)
        keyName = try container.decodeIfPresent(String.self, forKey: .keyName)
        configDrive = try container.decodeIfPresent(String.self, forKey: .configDrive)
        progress = try container.decodeIfPresent(Int.self, forKey: .progress)
        fault = try container.decodeIfPresent(Fault.self, forKey: .fault)
        availabilityZone = try container.decodeIfPresent(String.self, forKey: .availabilityZone)
        hypervisorHostname = try container.decodeIfPresent(String.self, forKey: .hypervisorHostname)
        instanceName = try container.decodeIfPresent(String.self, forKey: .instanceName)
        hostStatus = try container.decodeIfPresent(String.self, forKey: .hostStatus)

        // Handle flavor field - OpenStack returns flavor in multiple formats:
        // 1. Full FlavorRef with id (standard format with flavor links)
        // 2. String ID only (minimal format)
        // 3. Embedded flavor details with original_name but no id (Nova 2024.1+)
        if let flavorDict = try? container.decode(FlavorRef.self, forKey: .flavor) {
            flavor = flavorDict
        } else if let flavorId = try? container.decode(String.self, forKey: .flavor) {
            // Create a minimal FlavorRef with just the ID
            flavor = FlavorRef(id: flavorId)
        } else {
            // OpenStack Nova API can return embedded flavor details without an id field
            // This is standard behavior when the API embeds full flavor specs in the server response
            struct EmbeddedFlavor: Codable {
                let originalName: String?
                let name: String?
                let vcpus: Int?
                let ram: Int?
                let disk: Int?
                let ephemeral: Int?
                let swap: Int?

                enum CodingKeys: String, CodingKey {
                    case originalName = "original_name"
                    case name
                    case vcpus
                    case ram
                    case disk
                    case ephemeral
                    case swap
                }
            }

            if let embeddedFlavor = try? container.decode(EmbeddedFlavor.self, forKey: .flavor) {
                // Use original_name as the identifier (standard OpenStack field)
                if let originalName = embeddedFlavor.originalName {
                    flavor = FlavorRef(
                        id: originalName,
                        name: embeddedFlavor.name,
                        originalName: originalName,
                        vcpus: embeddedFlavor.vcpus,
                        ram: embeddedFlavor.ram,
                        disk: embeddedFlavor.disk,
                        ephemeral: embeddedFlavor.ephemeral,
                        swap: embeddedFlavor.swap
                    )
                } else if let name = embeddedFlavor.name {
                    flavor = FlavorRef(
                        id: name,
                        name: name,
                        vcpus: embeddedFlavor.vcpus,
                        ram: embeddedFlavor.ram,
                        disk: embeddedFlavor.disk,
                        ephemeral: embeddedFlavor.ephemeral,
                        swap: embeddedFlavor.swap
                    )
                } else {
                    flavor = nil
                }
            } else if let meta = try? container.decodeIfPresent([String: String].self, forKey: .metadata),
                      let flavorId = meta["instance_type_id"] ?? meta["flavor_id"] {
                // Fallback: extract flavor from metadata if available
                flavor = FlavorRef(id: flavorId)
            } else {
                flavor = nil
            }
        }

        // Handle image field - can be ImageRef object, String ID, or empty string for volume-backed
        if let imageDict = try? container.decode(ImageRef.self, forKey: .image) {
            image = imageDict
        } else if let imageId = try? container.decode(String.self, forKey: .image), !imageId.isEmpty {
            // Create a minimal ImageRef with just the ID
            image = ImageRef(id: imageId)
        } else {
            // Empty string or null for volume-backed instances
            image = nil
        }
    }

    public init(
        id: String,
        name: String? = nil,
        status: ServerStatus? = nil,
        taskState: String? = nil,
        powerState: PowerState? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        launchedAt: Date? = nil,
        terminatedAt: Date? = nil,
        hostId: String? = nil,
        userId: String? = nil,
        tenantId: String? = nil,
        accessIPv4: String? = nil,
        accessIPv6: String? = nil,
        flavor: FlavorRef? = nil,
        image: ImageRef? = nil,
        addresses: [String: [NetworkAddress]]? = nil,
        metadata: [String: String]? = nil,
        securityGroups: [SecurityGroupRef]? = nil,
        keyName: String? = nil,
        configDrive: String? = nil,
        progress: Int? = nil,
        fault: Fault? = nil,
        availabilityZone: String? = nil,
        hypervisorHostname: String? = nil,
        instanceName: String? = nil,
        hostStatus: String? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.taskState = taskState
        self.powerState = powerState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.launchedAt = launchedAt
        self.terminatedAt = terminatedAt
        self.hostId = hostId
        self.userId = userId
        self.tenantId = tenantId
        self.accessIPv4 = accessIPv4
        self.accessIPv6 = accessIPv6
        self.flavor = flavor
        self.image = image
        self.addresses = addresses
        self.metadata = metadata
        self.securityGroups = securityGroups
        self.keyName = keyName
        self.configDrive = configDrive
        self.progress = progress
        self.fault = fault
        self.availabilityZone = availabilityZone
        self.hypervisorHostname = hypervisorHostname
        self.instanceName = instanceName
        self.hostStatus = hostStatus
    }

    // MARK: - Computed Properties

    public var isActive: Bool {
        return status == .active
    }

    public var isBuilding: Bool {
        return status == .build
    }

    public var isDeleted: Bool {
        return status == .deleted
    }

    public var hasError: Bool {
        return status == .error || fault != nil
    }

    public var isTransitional: Bool {
        return status?.isTransitional ?? false
    }

    public var primaryIPv4: String? {
        return addresses?.values.flatMap { $0 }.first { $0.version == 4 }?.addr
    }

    public var primaryIPv6: String? {
        return addresses?.values.flatMap { $0 }.first { $0.version == 6 }?.addr
    }

    public var allIPAddresses: [String] {
        return addresses?.values.flatMap { $0 }.map { $0.addr } ?? []
    }
}

// MARK: - Flavor Models

public struct Flavor: Codable, Sendable, ResourceIdentifiable, Identifiable {
    public let id: String
    public let name: String?
    public let vcpus: Int
    public let ram: Int
    public let disk: Int
    public let ephemeral: Int?
    public let swap: Int?
    public let rxtxFactor: Double?
    public let isPublic: Bool?
    public let disabled: Bool?
    public let description: String?
    public let extraSpecs: [String: String]?
    public let links: [Link]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case vcpus
        case ram
        case disk
        case ephemeral = "OS-FLV-EXT-DATA:ephemeral"
        case swap
        case rxtxFactor = "rxtx_factor"
        case isPublic = "os-flavor-access:is_public"
        case disabled = "OS-FLV-DISABLED:disabled"
        case description
        case extraSpecs = "extra_specs"
        case links
    }

    // Custom decoding to handle field type variations
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Standard fields that should always be consistent
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        vcpus = try container.decode(Int.self, forKey: .vcpus)
        ram = try container.decode(Int.self, forKey: .ram)
        disk = try container.decode(Int.self, forKey: .disk)

        // Handle ephemeral - can be Int or String
        if let ephemeralInt = try? container.decode(Int.self, forKey: .ephemeral) {
            ephemeral = ephemeralInt
        } else if let ephemeralString = try? container.decode(String.self, forKey: .ephemeral),
                  let ephemeralValue = Int(ephemeralString) {
            ephemeral = ephemeralValue
        } else {
            ephemeral = nil
        }

        // Handle swap - can be Int or String (Rackspace returns String)
        if let swapInt = try? container.decode(Int.self, forKey: .swap) {
            swap = swapInt
        } else if let swapString = try? container.decode(String.self, forKey: .swap) {
            // Handle "0", "", or numeric strings
            if swapString.isEmpty {
                swap = 0
            } else {
                swap = Int(swapString) ?? 0
            }
        } else {
            swap = nil
        }

        // Handle rxtxFactor - can be Double or String
        if let factorDouble = try? container.decode(Double.self, forKey: .rxtxFactor) {
            rxtxFactor = factorDouble
        } else if let factorString = try? container.decode(String.self, forKey: .rxtxFactor),
                  let factorValue = Double(factorString) {
            rxtxFactor = factorValue
        } else {
            rxtxFactor = nil
        }

        // Standard optional fields
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic)
        disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        // Decode properties field
        extraSpecs = try container.decodeIfPresent([String: String].self, forKey: .extraSpecs)
        links = try container.decodeIfPresent([Link].self, forKey: .links)
    }

    // Custom encoding
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(vcpus, forKey: .vcpus)
        try container.encode(ram, forKey: .ram)
        try container.encode(disk, forKey: .disk)
        try container.encodeIfPresent(ephemeral, forKey: .ephemeral)
        try container.encodeIfPresent(swap, forKey: .swap)
        try container.encodeIfPresent(rxtxFactor, forKey: .rxtxFactor)
        try container.encodeIfPresent(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(disabled, forKey: .disabled)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(extraSpecs, forKey: .extraSpecs)
        try container.encodeIfPresent(links, forKey: .links)
    }

    public init(
        id: String,
        name: String? = nil,
        vcpus: Int,
        ram: Int,
        disk: Int,
        ephemeral: Int? = nil,
        swap: Int? = nil,
        rxtxFactor: Double? = nil,
        isPublic: Bool? = nil,
        disabled: Bool? = nil,
        description: String? = nil,
        extraSpecs: [String: String]? = nil,
        links: [Link]? = nil
    ) {
        self.id = id
        self.name = name
        self.vcpus = vcpus
        self.ram = ram
        self.disk = disk
        self.ephemeral = ephemeral
        self.swap = swap
        self.rxtxFactor = rxtxFactor
        self.isPublic = isPublic
        self.disabled = disabled
        self.description = description
        self.extraSpecs = extraSpecs
        self.links = links
    }

    // MARK: - Computed Properties

    public var totalDisk: Int {
        return disk + (ephemeral ?? 0)
    }

    public var ramGB: Double {
        return Double(ram) / 1024.0
    }

    public var displayName: String {
        return name ?? id
    }

    public var isAvailable: Bool {
        return !(disabled ?? false)
    }

    public var price: Double {
        guard let priceString = extraSpecs?[":price"] else { return 0.0 }
        return Double(priceString) ?? 0.0
    }
}



// MARK: - Key Pair Models

public struct KeyPair: Codable, Sendable, ResourceIdentifiable {
    public let name: String?
    public let publicKey: String?
    public let privateKey: String?
    public let userID: String?
    public let fingerprint: String?
    public let type: String?

    enum CodingKeys: String, CodingKey {
        case name
        case publicKey = "public_key"
        case privateKey = "private_key"
        case userID = "user_id"
        case fingerprint
        case type
    }

    public init(
        name: String? = nil,
        publicKey: String? = nil,
        privateKey: String? = nil,
        userID: String? = nil,
        fingerprint: String? = nil,
        type: String? = nil
    ) {
        self.name = name
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.userID = userID
        self.fingerprint = fingerprint
        self.type = type
    }

    // MARK: - ResourceIdentifiable

    public var id: String {
        return name ?? ""
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? "Unknown"
    }

    public var keyType: KeyType? {
        guard let type = type else { return nil }
        return KeyType(rawValue: type)
    }
}

public enum KeyType: String, CaseIterable, Sendable {
    case ssh = "ssh"
    case x509 = "x509"

    public var displayName: String {
        switch self {
        case .ssh: return "SSH Key"
        case .x509: return "X.509 Certificate"
        }
    }
}

// MARK: - Server Group Models

public struct ServerGroup: Codable, Sendable, ResourceIdentifiable {
    public let id: String
    public let name: String?
    /// Single policy (newer API microversion 2.64+)
    public let policy: String?
    /// Multiple policies (older API, deprecated)
    public let policies: [String]?
    public let members: [String]
    public let metadata: [String: String]?
    public let project_id: String?
    public let user_id: String?

    public init(
        id: String,
        name: String? = nil,
        policy: String? = nil,
        policies: [String]? = nil,
        members: [String] = [],
        metadata: [String: String]? = nil,
        project_id: String? = nil,
        user_id: String? = nil
    ) {
        self.id = id
        self.name = name
        self.policy = policy
        self.policies = policies
        self.members = members
        self.metadata = metadata
        self.project_id = project_id
        self.user_id = user_id
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? id
    }

    public var memberCount: Int {
        return members.count
    }

    /// Returns the primary policy, checking both new (policy) and old (policies) API formats
    public var primaryPolicy: ServerGroupPolicy? {
        // First try the new singular policy field
        if let policy = policy {
            return ServerGroupPolicy(rawValue: policy)
        }
        // Fall back to the old policies array
        guard let policies = policies, let firstPolicy = policies.first else { return nil }
        return ServerGroupPolicy(rawValue: firstPolicy)
    }

    public var allPolicies: [ServerGroupPolicy] {
        // If using new API with singular policy
        if let policy = policy, let parsed = ServerGroupPolicy(rawValue: policy) {
            return [parsed]
        }
        // Fall back to old policies array
        return policies?.compactMap { ServerGroupPolicy(rawValue: $0) } ?? []
    }
}

public enum ServerGroupPolicy: String, CaseIterable, Sendable {
    case affinity = "affinity"
    case antiAffinity = "anti-affinity"
    case softAffinity = "soft-affinity"
    case softAntiAffinity = "soft-anti-affinity"

    public var displayName: String {
        switch self {
        case .affinity: return "Affinity"
        case .antiAffinity: return "Anti-Affinity"
        case .softAffinity: return "Soft Affinity"
        case .softAntiAffinity: return "Soft Anti-Affinity"
        }
    }

    public var description: String {
        switch self {
        case .affinity:
            return "Schedule servers on the same host"
        case .antiAffinity:
            return "Schedule servers on different hosts"
        case .softAffinity:
            return "Prefer to schedule servers on the same host"
        case .softAntiAffinity:
            return "Prefer to schedule servers on different hosts"
        }
    }

    public var sortKey: String {
        return displayName
    }
}

// MARK: - Validation Extensions

extension CreateServerRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Server name is required")
        }

        if name.count > 255 {
            errors.append("Server name must be 255 characters or less")
        }

        if let imageRef = imageRef, !imageRef.isValidUUID {
            errors.append("Image reference must be a valid UUID")
        }

        if !flavorRef.isValidUUID {
            errors.append("Flavor reference must be a valid UUID")
        }

        if let networks = networks {
            for network in networks {
                if network.uuid == nil && network.port == nil {
                    errors.append("Network must specify either UUID or port")
                }

                if let uuid = network.uuid, !uuid.isValidUUID {
                    errors.append("Network UUID must be valid")
                }

                if let port = network.port, !port.isValidUUID {
                    errors.append("Port UUID must be valid")
                }

                if let fixedIp = network.fixedIp, !fixedIp.isValidIPAddress {
                    errors.append("Fixed IP must be a valid IP address")
                }
            }
        }

        if let minCount = minCount, minCount < 1 {
            errors.append("Minimum count must be at least 1")
        }

        if let maxCount = maxCount, let minCount = minCount, maxCount < minCount {
            errors.append("Maximum count must be greater than or equal to minimum count")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

extension Server {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if !id.isValidUUID {
            errors.append("Server ID must be a valid UUID")
        }

        if let name = name, name.isEmpty {
            errors.append("Server name cannot be empty")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

// MARK: - Server Action Models

public struct ServerStartAction: Codable, Sendable {
    public let osStart: OSStartAction

    enum CodingKeys: String, CodingKey {
        case osStart = "os-start"
    }

    public init() {
        self.osStart = OSStartAction()
    }
}

public struct OSStartAction: Codable, Sendable {
    public init() {}
}

public struct ServerStopAction: Codable, Sendable {
    public let osStop: OSStopAction

    enum CodingKeys: String, CodingKey {
        case osStop = "os-stop"
    }

    public init() {
        self.osStop = OSStopAction()
    }
}

public struct OSStopAction: Codable, Sendable {
    public init() {}
}

public struct ServerConfirmResizeAction: Codable, Sendable {
    public let confirmResize: ConfirmResizeAction

    public init() {
        self.confirmResize = ConfirmResizeAction()
    }
}

public struct ConfirmResizeAction: Codable, Sendable {
    public init() {}
}

public struct ServerRevertResizeAction: Codable, Sendable {
    public let revertResize: RevertResizeAction

    public init() {
        self.revertResize = RevertResizeAction()
    }
}

public struct RevertResizeAction: Codable, Sendable {
    public init() {}
}

public struct ServerGetConsoleOutputAction: Codable, Sendable {
    public let osGetConsoleOutput: GetConsoleOutputDetails

    enum CodingKeys: String, CodingKey {
        case osGetConsoleOutput = "os-getConsoleOutput"
    }

    public init(length: Int? = nil) {
        self.osGetConsoleOutput = GetConsoleOutputDetails(length: length)
    }
}

public struct GetConsoleOutputDetails: Codable, Sendable {
    public let length: Int?

    public init(length: Int? = nil) {
        self.length = length
    }
}

public struct RemoteConsoleRequest: Codable, Sendable {
    public let remoteConsole: RemoteConsoleDetails

    enum CodingKeys: String, CodingKey {
        case remoteConsole = "remote_console"
    }

    public init(protocol: String, type: String) {
        self.remoteConsole = RemoteConsoleDetails(protocol: `protocol`, type: type)
    }
}

public struct RemoteConsoleDetails: Codable, Sendable {
    public let `protocol`: String
    public let type: String

    public init(protocol: String, type: String) {
        self.`protocol` = `protocol`
        self.type = type
    }
}

public struct RemoteConsoleResponse: Codable, Sendable {
    public let remoteConsole: RemoteConsole

    enum CodingKeys: String, CodingKey {
        case remoteConsole = "remote_console"
    }
}

public struct RemoteConsole: Codable, Sendable {
    public let `protocol`: String
    public let type: String
    public let url: String

    public init(protocol: String, type: String, url: String) {
        self.`protocol` = `protocol`
        self.type = type
        self.url = url
    }
}

public struct CreateKeyPairRequest: Codable, Sendable {
    public let name: String
    public let publicKey: String?

    enum CodingKeys: String, CodingKey {
        case name
        case publicKey = "public_key"
    }

    public init(name: String, publicKey: String? = nil) {
        self.name = name
        self.publicKey = publicKey
    }

    // Custom encoding to omit public_key field when nil (for keypair generation)
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        // Only encode publicKey if it's not nil (for importing existing keys)
        if let publicKey = publicKey {
            try container.encode(publicKey, forKey: .publicKey)
        }
        // If publicKey is nil, the field is omitted entirely (for generating new keys)
    }
}

public struct CreateKeyPairWrapper: Codable, Sendable {
    public let keypair: CreateKeyPairRequest

    public init(keypair: CreateKeyPairRequest) {
        self.keypair = keypair
    }
}

// MARK: - Security Group Action Models

public struct AddSecurityGroupAction: Codable, Sendable {
    public let addSecurityGroup: AddSecurityGroupRequest

    public init(name: String) {
        self.addSecurityGroup = AddSecurityGroupRequest(name: name)
    }

    enum CodingKeys: String, CodingKey {
        case addSecurityGroup = "addSecurityGroup"
    }
}

public struct AddSecurityGroupRequest: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct RemoveSecurityGroupAction: Codable, Sendable {
    public let removeSecurityGroup: RemoveSecurityGroupRequest

    public init(name: String) {
        self.removeSecurityGroup = RemoveSecurityGroupRequest(name: name)
    }

    enum CodingKeys: String, CodingKey {
        case removeSecurityGroup = "removeSecurityGroup"
    }
}

public struct RemoveSecurityGroupRequest: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct ServerSecurityGroupsResponse: Codable, Sendable {
    public let securityGroups: [SecurityGroup]

    enum CodingKeys: String, CodingKey {
        case securityGroups = "security_groups"
    }
}

// MARK: - Interface Attachment Models

public struct AttachInterfaceRequest: Codable, Sendable {
    public let portId: String?
    public let netId: String?
    public let fixedIps: [InterfaceFixedIP]?

    enum CodingKeys: String, CodingKey {
        case portId = "port_id"
        case netId = "net_id"
        case fixedIps = "fixed_ips"
    }

    public init(portId: String? = nil, netId: String? = nil, fixedIps: [InterfaceFixedIP]? = nil) {
        self.portId = portId
        self.netId = netId
        self.fixedIps = fixedIps
    }
}

public struct InterfaceFixedIP: Codable, Sendable {
    public let ipAddress: String?
    public let subnetId: String?

    enum CodingKeys: String, CodingKey {
        case ipAddress = "ip_address"
        case subnetId = "subnet_id"
    }

    public init(ipAddress: String? = nil, subnetId: String? = nil) {
        self.ipAddress = ipAddress
        self.subnetId = subnetId
    }
}

public struct InterfaceAttachment: Codable, Sendable {
    public let portId: String
    public let netId: String
    public let macAddr: String
    public let portState: String
    public let fixedIps: [AttachedFixedIP]

    enum CodingKeys: String, CodingKey {
        case portId = "port_id"
        case netId = "net_id"
        case macAddr = "mac_addr"
        case portState = "port_state"
        case fixedIps = "fixed_ips"
    }
}

public struct AttachedFixedIP: Codable, Sendable {
    public let subnetId: String
    public let ipAddress: String

    enum CodingKeys: String, CodingKey {
        case subnetId = "subnet_id"
        case ipAddress = "ip_address"
    }
}

public struct InterfaceAttachmentResponse: Codable, Sendable {
    public let interfaceAttachment: InterfaceAttachment

    enum CodingKeys: String, CodingKey {
        case interfaceAttachment = "interfaceAttachment"
    }
}

public struct InterfaceAttachmentsResponse: Codable, Sendable {
    public let interfaceAttachments: [InterfaceAttachment]

    enum CodingKeys: String, CodingKey {
        case interfaceAttachments = "interfaceAttachments"
    }
}


// MARK: - Availability Zone Models

public struct AvailabilityZone: Codable, Sendable {
    public let zoneName: String
    public let zoneState: AvailabilityZoneState?
    public let hosts: [String: [String: String]]?

    enum CodingKeys: String, CodingKey {
        case zoneName = "zoneName"
        case zoneState = "zoneState"
        case hosts
    }

    public init(zoneName: String, zoneState: AvailabilityZoneState? = nil, hosts: [String: [String: String]]? = nil) {
        self.zoneName = zoneName
        self.zoneState = zoneState
        self.hosts = hosts
    }
}

public struct AvailabilityZoneState: Codable, Sendable {
    public let available: Bool

    public init(available: Bool) {
        self.available = available
    }
}

public struct AvailabilityZoneListResponse: Codable, Sendable {
    public let availabilityZoneInfo: [AvailabilityZone]

    enum CodingKeys: String, CodingKey {
        case availabilityZoneInfo = "availabilityZoneInfo"
    }

    public init(availabilityZoneInfo: [AvailabilityZone]) {
        self.availabilityZoneInfo = availabilityZoneInfo
    }
}

// MARK: - Compute Quota Models

public struct ComputeQuotaSet: Codable, Sendable {
    public let cores: Int?
    public let instances: Int?
    public let ram: Int?
    public let keyPairs: Int?
    public let securityGroups: Int?
    public let securityGroupRules: Int?
    public let serverGroups: Int?
    public let serverGroupMembers: Int?
    public let floatingIps: Int? // Some deployments return this in compute quotas

    enum CodingKeys: String, CodingKey {
        case cores
        case instances
        case ram
        case keyPairs = "key_pairs"
        case securityGroups = "security_groups"
        case securityGroupRules = "security_group_rules"
        case serverGroups = "server_groups"
        case serverGroupMembers = "server_group_members"
        case floatingIps = "floating_ips"
    }

    public init(cores: Int? = nil, instances: Int? = nil, ram: Int? = nil,
                keyPairs: Int? = nil, securityGroups: Int? = nil,
                securityGroupRules: Int? = nil, serverGroups: Int? = nil,
                serverGroupMembers: Int? = nil, floatingIps: Int? = nil) {
        self.cores = cores
        self.instances = instances
        self.ram = ram
        self.keyPairs = keyPairs
        self.securityGroups = securityGroups
        self.securityGroupRules = securityGroupRules
        self.serverGroups = serverGroups
        self.serverGroupMembers = serverGroupMembers
        self.floatingIps = floatingIps
    }
}