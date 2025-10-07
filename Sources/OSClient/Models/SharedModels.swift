import Foundation

// MARK: - Common Resource Models

public protocol ResourceIdentifiable {
    var id: String { get }
    var name: String? { get }
}

public protocol Timestamped {
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
}

public struct ResourceMetadata: Codable, Sendable {
    public let id: String
    public let name: String?
    public let description: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Common Response Wrappers

public struct ListResponse<T: Codable>: Codable {
    public let items: [T]
    public let links: [Link]?

    public init(items: [T], links: [Link]? = nil) {
        self.items = items
        self.links = links
    }
}

public struct Link: Codable, Sendable {
    public let href: String
    public let rel: String
}

// MARK: - Status and State Enums

public enum ServerStatus: String, Codable, CaseIterable, Sendable {
    case active = "ACTIVE"
    case build = "BUILD"
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
    case suspended = "SUSPENDED"
    case unknown = "UNKNOWN"
    case verify = "VERIFY_RESIZE"

    public var isTransitional: Bool {
        switch self {
        case .build, .hardReboot, .password, .reboot, .rebuild, .rescue, .resize, .revertResize, .verify:
            return true
        case .active, .deleted, .error, .paused, .shutoff, .suspended, .unknown:
            return false
        }
    }

    public var isStable: Bool {
        return !isTransitional
    }

    public func lowercased() -> String {
        return rawValue.lowercased()
    }

    public func uppercased() -> String {
        return rawValue.uppercased()
    }

    public func contains(_ string: String) -> Bool {
        return rawValue.lowercased().contains(string.lowercased())
    }
}

public enum PowerState: Int, Codable, CaseIterable, Sendable {
    case noState = 0
    case running = 1
    case paused = 3
    case shutdown = 4
    case crashed = 6
    case suspended = 7

    public var description: String {
        switch self {
        case .noState: return "No State"
        case .running: return "Running"
        case .paused: return "Paused"
        case .shutdown: return "Shutdown"
        case .crashed: return "Crashed"
        case .suspended: return "Suspended"
        }
    }
}

// MARK: - Network Address Models

public struct NetworkAddress: Codable, Sendable, Hashable {
    public let version: Int
    public let addr: String
    public let macAddr: String?
    public let type: String?

    enum CodingKeys: String, CodingKey {
        case version
        case addr
        case macAddr = "OS-EXT-IPS-MAC:mac_addr"
        case type = "OS-EXT-IPS:type"
    }

    public init(version: Int, addr: String, macAddr: String? = nil, type: String? = nil) {
        self.version = version
        self.addr = addr
        self.macAddr = macAddr
        self.type = type
    }
}

// MARK: - Fault Information

public struct Fault: Codable, Sendable {
    public let code: Int
    public let message: String
    public let created: Date?

    public init(code: Int, message: String, created: Date? = nil) {
        self.code = code
        self.message = message
        self.created = created
    }
}

// MARK: - Security Group Models

public struct SecurityGroupRef: Codable, Sendable, Hashable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

// MARK: - Flavor Reference

public struct FlavorRef: Codable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let originalName: String?
    public let vcpus: Int?
    public let ram: Int?
    public let disk: Int?
    public let ephemeral: Int?
    public let swap: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case vcpus
        case ram
        case disk
        case ephemeral
        case swap
    }

    public init(id: String, name: String? = nil, originalName: String? = nil, vcpus: Int? = nil, ram: Int? = nil, disk: Int? = nil, ephemeral: Int? = nil, swap: Int? = nil) {
        self.id = id
        self.name = name
        self.originalName = originalName
        self.vcpus = vcpus
        self.ram = ram
        self.disk = disk
        self.ephemeral = ephemeral
        self.swap = swap
    }
}

// MARK: - Image Reference

public struct ImageRef: Codable, Sendable, Hashable {
    public let id: String
    public let name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

// MARK: - Quota Models

public struct QuotaSet: Codable, Sendable {
    public let cores: Int?
    public let instances: Int?
    public let ram: Int?
    public let floatingIps: Int?
    public let fixedIps: Int?
    public let metadataItems: Int?
    public let injectedFiles: Int?
    public let injectedFileContentBytes: Int?
    public let injectedFilePathBytes: Int?
    public let keyPairs: Int?
    public let securityGroups: Int?
    public let securityGroupRules: Int?
    public let serverGroups: Int?
    public let serverGroupMembers: Int?

    enum CodingKeys: String, CodingKey {
        case cores
        case instances
        case ram
        case floatingIps = "floating_ips"
        case fixedIps = "fixed_ips"
        case metadataItems = "metadata_items"
        case injectedFiles = "injected_files"
        case injectedFileContentBytes = "injected_file_content_bytes"
        case injectedFilePathBytes = "injected_file_path_bytes"
        case keyPairs = "key_pairs"
        case securityGroups = "security_groups"
        case securityGroupRules = "security_group_rules"
        case serverGroups = "server_groups"
        case serverGroupMembers = "server_group_members"
    }
}

// MARK: - Pagination Support

public struct PaginationOptions: Sendable {
    public let limit: Int?
    public let marker: String?
    public let sortKey: String?
    public let sortDirection: SortDirection?

    public init(limit: Int? = nil, marker: String? = nil, sortKey: String? = nil, sortDirection: SortDirection? = nil) {
        self.limit = limit
        self.marker = marker
        self.sortKey = sortKey
        self.sortDirection = sortDirection
    }

    public var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        if let marker = marker {
            items.append(URLQueryItem(name: "marker", value: marker))
        }

        if let sortKey = sortKey {
            items.append(URLQueryItem(name: "sort_key", value: sortKey))
        }

        if let sortDirection = sortDirection {
            items.append(URLQueryItem(name: "sort_dir", value: sortDirection.rawValue))
        }

        return items
    }
}

public enum SortDirection: String, Codable, CaseIterable, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

// MARK: - Operation Results

public struct OperationResult<T: Sendable>: Sendable {
    public let success: Bool
    public let data: T?
    public let error: OpenStackError?
    public let operationId: String

    public init(success: Bool, data: T? = nil, error: OpenStackError? = nil, operationId: String = UUID().uuidString) {
        self.success = success
        self.data = data
        self.error = error
        self.operationId = operationId
    }

    public static func success(_ data: T, operationId: String = UUID().uuidString) -> OperationResult<T> {
        return OperationResult(success: true, data: data, operationId: operationId)
    }

    public static func failure(_ error: OpenStackError, operationId: String = UUID().uuidString) -> OperationResult<T> {
        return OperationResult(success: false, error: error, operationId: operationId)
    }
}

// MARK: - Service Protocol

public protocol OpenStackService: Actor {
    var core: OpenStackClientCore { get }
    var serviceName: String { get }
}

// MARK: - Validation Helpers

public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [String]

    public init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }

    public static let valid = ValidationResult(isValid: true)

    public static func invalid(_ errors: [String]) -> ValidationResult {
        return ValidationResult(isValid: false, errors: errors)
    }

    public static func invalid(_ error: String) -> ValidationResult {
        return ValidationResult(isValid: false, errors: [error])
    }
}

// MARK: - Utilities

extension String {
    public var isValidUUID: Bool {
        return UUID(uuidString: self) != nil
    }

    public var isValidIPAddress: Bool {
        let parts = self.components(separatedBy: ".")
        guard parts.count == 4 else { return false }

        return parts.allSatisfy { part in
            guard let num = Int(part), num >= 0, num <= 255 else { return false }
            return true
        }
    }

    public var isValidEmail: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        #if canImport(Foundation) && canImport(ObjectiveC)
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
        #else
        // Fallback regex implementation for Linux
        let pattern = try? NSRegularExpression(pattern: emailRegex, options: [])
        let range = NSRange(location: 0, length: self.utf16.count)
        return pattern?.firstMatch(in: self, options: [], range: range) != nil
        #endif
    }
}

extension Collection {
    public func chunked(into size: Int) -> [[Element]] {
        guard !isEmpty && size > 0 else { return [] }

        return stride(from: 0, to: count, by: size).map {
            let startIdx = index(startIndex, offsetBy: $0)
            let endOffset = Swift.min($0 + size, count)
            let endIdx = index(startIndex, offsetBy: endOffset)

            // Ensure valid range
            guard startIdx < endIdx else { return [] }

            return Array(self[startIdx..<endIdx])
        }
    }
}

// MARK: - Type Aliases for Backward Compatibility

// Quota type aliases for backward compatibility
public typealias ComputeLimits = ComputeQuotaSet
public typealias NetworkQuotas = NetworkQuotaSet
public typealias VolumeQuotas = VolumeQuotaSet

// Server nested type aliases for backward compatibility
extension Server {
    public typealias FlavorInfo = FlavorRef
    public typealias ImageInfo = ImageRef
}

// MARK: - Batch Operations Models

public struct BatchOperation: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let operations: [ResourceOperation]
    public let failureMode: FailureMode
    public let createdAt: Date
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        operations: [ResourceOperation],
        failureMode: FailureMode = .continueOnError,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.operations = operations
        self.failureMode = failureMode
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

public struct ResourceOperation: Codable, Sendable, Equatable {
    public let id: UUID
    public let type: OperationType
    public let resourceType: String
    public let resourceId: String?
    public let properties: [String: String]
    public let dependencies: [String]
    public let rollbackType: RollbackType?

    private enum CodingKeys: String, CodingKey {
        case id, type, resourceType, resourceId, dependencies, rollbackType
        case propertiesData = "properties"
    }

    public init(
        id: UUID = UUID(),
        type: OperationType,
        resourceType: String,
        resourceId: String? = nil,
        properties: [String: String] = [:],
        dependencies: [String] = [],
        rollbackType: RollbackType? = nil
    ) {
        self.id = id
        self.type = type
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.properties = properties
        self.dependencies = dependencies
        self.rollbackType = rollbackType
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(OperationType.self, forKey: .type)
        resourceType = try container.decode(String.self, forKey: .resourceType)
        resourceId = try container.decodeIfPresent(String.self, forKey: .resourceId)
        dependencies = try container.decode([String].self, forKey: .dependencies)
        rollbackType = try container.decodeIfPresent(RollbackType.self, forKey: .rollbackType)

        let propertiesData = try container.decode(Data.self, forKey: .propertiesData)
        properties = try JSONSerialization.jsonObject(with: propertiesData) as? [String: String] ?? [:]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(resourceType, forKey: .resourceType)
        try container.encodeIfPresent(resourceId, forKey: .resourceId)
        try container.encode(dependencies, forKey: .dependencies)
        try container.encodeIfPresent(rollbackType, forKey: .rollbackType)

        let propertiesData = try JSONSerialization.data(withJSONObject: properties)
        try container.encode(propertiesData, forKey: .propertiesData)
    }
}

public enum OperationType: String, Codable, CaseIterable, Sendable {
    case create
    case update
    case delete
}


public enum FailureMode: String, Codable, CaseIterable, Sendable {
    case stopOnFirstError = "stop_on_first_error"
    case continueOnError = "continue_on_error"
}

public enum RollbackType: String, Codable, CaseIterable, Sendable {
    case delete
    case restore
    case none
}



public struct ResourceDependency: Codable, Sendable {
    public let resourceId: String
    public let dependsOn: String
    public let dependencyType: DependencyType

    public init(resourceId: String, dependsOn: String, dependencyType: DependencyType) {
        self.resourceId = resourceId
        self.dependsOn = dependsOn
        self.dependencyType = dependencyType
    }
}

public enum DependencyType: String, Codable, CaseIterable, Sendable {
    case hard
    case soft
}

public struct ExecutionPlan: Codable, Sendable {
    public let operationId: UUID
    public let phases: [ExecutionPhase]
    public let estimatedDuration: TimeInterval

    public init(operationId: UUID, phases: [ExecutionPhase], estimatedDuration: TimeInterval) {
        self.operationId = operationId
        self.phases = phases
        self.estimatedDuration = estimatedDuration
    }
}

public struct ExecutionPhase: Codable, Sendable, Equatable {
    public let operations: [ResourceOperation]
    public let estimatedDuration: TimeInterval

    public init(operations: [ResourceOperation], estimatedDuration: TimeInterval = 30.0) {
        self.operations = operations
        self.estimatedDuration = estimatedDuration
    }

    public static func == (lhs: ExecutionPhase, rhs: ExecutionPhase) -> Bool {
        return lhs.operations == rhs.operations && lhs.estimatedDuration == rhs.estimatedDuration
    }
}