// Sources/OSClient/Models/HypervisorModels.swift
import Foundation

// MARK: - Hypervisor Models

/// OpenStack compute hypervisor resource
///
/// Represents a hypervisor host in the OpenStack compute infrastructure.
/// Hypervisors run virtual machine instances and report resource usage.
///
/// Note: Hypervisor management requires administrative privileges.
public struct Hypervisor: Codable, Sendable, ResourceIdentifiable {
    /// Unique identifier for the hypervisor
    public let id: String

    /// Hostname of the hypervisor
    public let hypervisorHostname: String?

    /// Type of hypervisor (e.g., "QEMU", "KVM", "VMware")
    public let hypervisorType: String?

    /// Version of the hypervisor software
    public let hypervisorVersion: Int?

    /// IP address of the hypervisor host
    public let hostIp: String?

    /// Operational state of the hypervisor ("up" or "down")
    public let state: String?

    /// Administrative status of the hypervisor ("enabled" or "disabled")
    public let status: String?

    /// Total number of virtual CPUs available
    public let vcpus: Int?

    /// Number of virtual CPUs currently in use
    public let vcpusUsed: Int?

    /// Total memory in megabytes
    public let memoryMb: Int?

    /// Memory currently in use in megabytes
    public let memoryMbUsed: Int?

    /// Total local disk space in gigabytes
    public let localGb: Int?

    /// Local disk space currently in use in gigabytes
    public let localGbUsed: Int?

    /// Number of running virtual machine instances
    public let runningVms: Int?

    /// Current workload metric
    public let currentWorkload: Int?

    /// Available disk space in gigabytes
    public let freeDiskGb: Int?

    /// Available memory in megabytes
    public let freeRamMb: Int?

    /// Minimum available disk space accounting for thin provisioning
    public let diskAvailableLeast: Int?

    /// JSON-encoded CPU information string
    public let cpuInfo: String?

    /// Associated compute service ID
    public let serviceId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case hypervisorHostname = "hypervisor_hostname"
        case hypervisorType = "hypervisor_type"
        case hypervisorVersion = "hypervisor_version"
        case hostIp = "host_ip"
        case state
        case status
        case vcpus
        case vcpusUsed = "vcpus_used"
        case memoryMb = "memory_mb"
        case memoryMbUsed = "memory_mb_used"
        case localGb = "local_gb"
        case localGbUsed = "local_gb_used"
        case runningVms = "running_vms"
        case currentWorkload = "current_workload"
        case freeDiskGb = "free_disk_gb"
        case freeRamMb = "free_ram_mb"
        case diskAvailableLeast = "disk_available_least"
        case cpuInfo = "cpu_info"
        case serviceId = "service_id"
    }

    /// Custom decoding to handle id field type variations
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle id as either String or Int
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: [CodingKeys.id],
                    debugDescription: "Expected String or Int for id"
                )
            )
        }

        hypervisorHostname = try container.decodeIfPresent(String.self, forKey: .hypervisorHostname)
        hypervisorType = try container.decodeIfPresent(String.self, forKey: .hypervisorType)
        hypervisorVersion = try container.decodeIfPresent(Int.self, forKey: .hypervisorVersion)
        hostIp = try container.decodeIfPresent(String.self, forKey: .hostIp)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        vcpus = try container.decodeIfPresent(Int.self, forKey: .vcpus)
        vcpusUsed = try container.decodeIfPresent(Int.self, forKey: .vcpusUsed)
        memoryMb = try container.decodeIfPresent(Int.self, forKey: .memoryMb)
        memoryMbUsed = try container.decodeIfPresent(Int.self, forKey: .memoryMbUsed)
        localGb = try container.decodeIfPresent(Int.self, forKey: .localGb)
        localGbUsed = try container.decodeIfPresent(Int.self, forKey: .localGbUsed)
        runningVms = try container.decodeIfPresent(Int.self, forKey: .runningVms)
        currentWorkload = try container.decodeIfPresent(Int.self, forKey: .currentWorkload)
        freeDiskGb = try container.decodeIfPresent(Int.self, forKey: .freeDiskGb)
        freeRamMb = try container.decodeIfPresent(Int.self, forKey: .freeRamMb)
        diskAvailableLeast = try container.decodeIfPresent(Int.self, forKey: .diskAvailableLeast)

        // Handle cpuInfo - can be String, Dictionary, or missing
        // The API may return cpu_info as a JSON string or as a raw JSON object
        // Since this field is not critical for display, we gracefully handle all cases
        cpuInfo = try? container.decodeIfPresent(String.self, forKey: .cpuInfo)

        // Handle serviceId as either String or Int
        if let serviceIdString = try? container.decode(String.self, forKey: .serviceId) {
            serviceId = serviceIdString
        } else if let serviceIdInt = try? container.decode(Int.self, forKey: .serviceId) {
            serviceId = String(serviceIdInt)
        } else {
            serviceId = nil
        }
    }

    /// Memberwise initializer
    public init(
        id: String,
        hypervisorHostname: String? = nil,
        hypervisorType: String? = nil,
        hypervisorVersion: Int? = nil,
        hostIp: String? = nil,
        state: String? = nil,
        status: String? = nil,
        vcpus: Int? = nil,
        vcpusUsed: Int? = nil,
        memoryMb: Int? = nil,
        memoryMbUsed: Int? = nil,
        localGb: Int? = nil,
        localGbUsed: Int? = nil,
        runningVms: Int? = nil,
        currentWorkload: Int? = nil,
        freeDiskGb: Int? = nil,
        freeRamMb: Int? = nil,
        diskAvailableLeast: Int? = nil,
        cpuInfo: String? = nil,
        serviceId: String? = nil
    ) {
        self.id = id
        self.hypervisorHostname = hypervisorHostname
        self.hypervisorType = hypervisorType
        self.hypervisorVersion = hypervisorVersion
        self.hostIp = hostIp
        self.state = state
        self.status = status
        self.vcpus = vcpus
        self.vcpusUsed = vcpusUsed
        self.memoryMb = memoryMb
        self.memoryMbUsed = memoryMbUsed
        self.localGb = localGb
        self.localGbUsed = localGbUsed
        self.runningVms = runningVms
        self.currentWorkload = currentWorkload
        self.freeDiskGb = freeDiskGb
        self.freeRamMb = freeRamMb
        self.diskAvailableLeast = diskAvailableLeast
        self.cpuInfo = cpuInfo
        self.serviceId = serviceId
    }

    // MARK: - ResourceIdentifiable

    /// Display name for the hypervisor (uses hostname)
    public var name: String? {
        return hypervisorHostname
    }

    // MARK: - Computed Properties

    /// Whether the hypervisor is operationally up
    public var isUp: Bool {
        return state?.lowercased() == "up"
    }

    /// Whether the hypervisor is administratively enabled
    public var isEnabled: Bool {
        return status?.lowercased() == "enabled"
    }

    /// Whether the hypervisor is fully operational (up and enabled)
    public var isOperational: Bool {
        return isUp && isEnabled
    }

    /// Total memory in gigabytes
    public var memoryGb: Double {
        guard let mb = memoryMb else { return 0 }
        return Double(mb) / 1024.0
    }

    /// Used memory in gigabytes
    public var memoryGbUsed: Double {
        guard let mb = memoryMbUsed else { return 0 }
        return Double(mb) / 1024.0
    }

    /// Memory usage percentage
    public var memoryUsagePercent: Double {
        guard let total = memoryMb, total > 0, let used = memoryMbUsed else { return 0 }
        return (Double(used) / Double(total)) * 100.0
    }

    /// vCPU usage percentage
    public var vcpuUsagePercent: Double {
        guard let total = vcpus, total > 0, let used = vcpusUsed else { return 0 }
        return (Double(used) / Double(total)) * 100.0
    }

    /// Disk usage percentage
    public var diskUsagePercent: Double {
        guard let total = localGb, total > 0, let used = localGbUsed else { return 0 }
        return (Double(used) / Double(total)) * 100.0
    }
}

// MARK: - Compute Service Models

/// OpenStack compute service resource
///
/// Represents a compute service running on a host. Used to enable/disable
/// hypervisors and monitor service health.
public struct ComputeService: Codable, Sendable, ResourceIdentifiable {
    /// Unique identifier for the service
    public let id: String

    /// Binary name of the service (e.g., "nova-compute")
    public let binary: String?

    /// Reason for disabling the service (if disabled)
    public let disabledReason: String?

    /// Whether the service is forced down
    public let forcedDown: Bool?

    /// Hostname where the service runs
    public let host: String?

    /// Operational state of the service ("up" or "down")
    public let state: String?

    /// Administrative status ("enabled" or "disabled")
    public let status: String?

    /// Availability zone
    public let zone: String?

    /// Last update timestamp
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case binary
        case disabledReason = "disabled_reason"
        case forcedDown = "forced_down"
        case host
        case state
        case status
        case zone
        case updatedAt = "updated_at"
    }

    /// Custom decoding to handle id field type variations
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle id as either String or Int
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: [CodingKeys.id],
                    debugDescription: "Expected String or Int for id"
                )
            )
        }

        binary = try container.decodeIfPresent(String.self, forKey: .binary)
        disabledReason = try container.decodeIfPresent(String.self, forKey: .disabledReason)
        forcedDown = try container.decodeIfPresent(Bool.self, forKey: .forcedDown)
        host = try container.decodeIfPresent(String.self, forKey: .host)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        zone = try container.decodeIfPresent(String.self, forKey: .zone)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    /// Memberwise initializer
    public init(
        id: String,
        binary: String? = nil,
        disabledReason: String? = nil,
        forcedDown: Bool? = nil,
        host: String? = nil,
        state: String? = nil,
        status: String? = nil,
        zone: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.binary = binary
        self.disabledReason = disabledReason
        self.forcedDown = forcedDown
        self.host = host
        self.state = state
        self.status = status
        self.zone = zone
        self.updatedAt = updatedAt
    }

    // MARK: - ResourceIdentifiable

    /// Display name for the service (uses host)
    public var name: String? {
        return host
    }

    // MARK: - Computed Properties

    /// Whether the service is operationally up
    public var isUp: Bool {
        return state?.lowercased() == "up"
    }

    /// Whether the service is administratively enabled
    public var isEnabled: Bool {
        return status?.lowercased() == "enabled"
    }

    /// Whether this is a nova-compute service
    public var isComputeService: Bool {
        return binary == "nova-compute"
    }
}

// MARK: - Hypervisor Server Models

/// Summary of a server running on a hypervisor
///
/// Represents basic server information returned by the hypervisor servers API.
public struct HypervisorServer: Codable, Sendable {
    /// UUID of the server instance
    public let uuid: String

    /// Name of the server instance
    public let name: String?

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
    }

    /// Memberwise initializer
    public init(uuid: String, name: String? = nil) {
        self.uuid = uuid
        self.name = name
    }
}

// MARK: - Response Models

/// Response wrapper for hypervisor list API
public struct HypervisorListResponse: Codable, Sendable {
    /// List of hypervisors
    public let hypervisors: [Hypervisor]
}

/// Response wrapper for hypervisor detail API
public struct HypervisorDetailResponse: Codable, Sendable {
    /// Single hypervisor
    public let hypervisor: Hypervisor
}

/// Response wrapper for hypervisor servers API
public struct HypervisorServersResponse: Codable, Sendable {
    /// List of hypervisor server wrappers
    public let hypervisors: [HypervisorServersWrapper]
}

/// Wrapper for servers on a hypervisor
public struct HypervisorServersWrapper: Codable, Sendable {
    /// Servers running on the hypervisor
    public let servers: [HypervisorServer]?
}

/// Response wrapper for compute services list API
public struct ComputeServiceListResponse: Codable, Sendable {
    /// List of compute services
    public let services: [ComputeService]
}

/// Response wrapper for compute service update API
public struct ComputeServiceUpdateResponse: Codable, Sendable {
    /// Updated service
    public let service: ComputeService
}

// MARK: - Request Models

/// Request body for enabling a compute service (microversion 2.53+)
///
/// Uses PUT /os-services/{service_id} with status field
public struct ComputeServiceStatusRequest: Codable, Sendable {
    /// Service status ("enabled" or "disabled")
    public let status: String

    /// Optional reason for disabling (only used when status is "disabled")
    public let disabledReason: String?

    /// Force down state (optional)
    public let forcedDown: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case disabledReason = "disabled_reason"
        case forcedDown = "forced_down"
    }

    /// Create an enable request
    public static func enable() -> ComputeServiceStatusRequest {
        return ComputeServiceStatusRequest(status: "enabled", disabledReason: nil, forcedDown: nil)
    }

    /// Create a disable request with optional reason
    public static func disable(reason: String? = nil) -> ComputeServiceStatusRequest {
        return ComputeServiceStatusRequest(status: "disabled", disabledReason: reason, forcedDown: nil)
    }

    public init(status: String, disabledReason: String? = nil, forcedDown: Bool? = nil) {
        self.status = status
        self.disabledReason = disabledReason
        self.forcedDown = forcedDown
    }
}
