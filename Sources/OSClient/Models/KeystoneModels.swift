import Foundation

// MARK: - Metadata Wrapper for Keystone

public struct KeystoneMetadataWrapper: Codable, Sendable {
    private let data: Data

    public init(_ dictionary: [String: String]) {
        self.data = (try? JSONSerialization.data(withJSONObject: dictionary)) ?? Data()
    }

    public init(_ dictionary: [String: Any]) {
        self.data = (try? JSONSerialization.data(withJSONObject: dictionary)) ?? Data()
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let anyDict = try container.decode([String: String].self)
        self.data = (try? JSONSerialization.data(withJSONObject: anyDict)) ?? Data()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            try container.encode(dict)
        } else {
            try container.encode([String: String]())
        }
    }

    public func asDictionary() -> [String: String] {
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: String] ?? [:]
    }
}

// MARK: - Project Models

public struct Project: Codable, Sendable {
    public let id: String
    public let name: String?
    public let description: String?
    public let enabled: Bool?
    public let domainId: String?
    public let parentId: String?
    public let isDomain: Bool?
    public let tags: [String]?
    public let options: KeystoneMetadataWrapper?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case enabled
        case domainId = "domain_id"
        case parentId = "parent_id"
        case isDomain = "is_domain"
        case tags
        case options
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        domainId = try container.decodeIfPresent(String.self, forKey: .domainId)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        isDomain = try container.decodeIfPresent(Bool.self, forKey: .isDomain)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        options = try container.decodeIfPresent(KeystoneMetadataWrapper.self, forKey: .options)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(domainId, forKey: .domainId)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encodeIfPresent(isDomain, forKey: .isDomain)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(options, forKey: .options)
    }

    public init(
        id: String,
        name: String,
        description: String? = nil,
        enabled: Bool? = nil,
        domainId: String? = nil,
        parentId: String? = nil,
        isDomain: Bool? = nil,
        tags: [String]? = nil,
        options: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.enabled = enabled
        self.domainId = domainId
        self.parentId = parentId
        self.isDomain = isDomain
        self.tags = tags
        self.options = options.map(KeystoneMetadataWrapper.init)
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? "Unnamed Project"
    }

    public var isEnabled: Bool {
        return enabled ?? true
    }

    public var isRootProject: Bool {
        return parentId == nil
    }

    public var hasTags: Bool {
        return !(tags?.isEmpty ?? true)
    }

    public var isProjectDomain: Bool {
        return isDomain ?? false
    }
}

// MARK: - ResourceIdentifiable Extensions for Keystone Models

extension Project: ResourceIdentifiable {}

// MARK: - User Models

public struct User: Codable, Sendable {
    public let id: String
    public let name: String?
    public let description: String?
    public let email: String?
    public let enabled: Bool?
    public let domainId: String?
    public let defaultProjectId: String?
    public let passwordExpiresAt: Date?
    public let options: KeystoneMetadataWrapper?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case email
        case enabled
        case domainId = "domain_id"
        case defaultProjectId = "default_project_id"
        case passwordExpiresAt = "password_expires_at"
        case options
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        domainId = try container.decodeIfPresent(String.self, forKey: .domainId)
        defaultProjectId = try container.decodeIfPresent(String.self, forKey: .defaultProjectId)
        passwordExpiresAt = try container.decodeIfPresent(Date.self, forKey: .passwordExpiresAt)
        options = try container.decodeIfPresent(KeystoneMetadataWrapper.self, forKey: .options)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(domainId, forKey: .domainId)
        try container.encodeIfPresent(defaultProjectId, forKey: .defaultProjectId)
        try container.encodeIfPresent(passwordExpiresAt, forKey: .passwordExpiresAt)
        try container.encodeIfPresent(options, forKey: .options)
    }

    public init(
        id: String,
        name: String,
        description: String? = nil,
        email: String? = nil,
        enabled: Bool? = nil,
        domainId: String? = nil,
        defaultProjectId: String? = nil,
        passwordExpiresAt: Date? = nil,
        options: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.email = email
        self.enabled = enabled
        self.domainId = domainId
        self.defaultProjectId = defaultProjectId
        self.passwordExpiresAt = passwordExpiresAt
        self.options = options.map(KeystoneMetadataWrapper.init)
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? "Unnamed User"
    }

    public var isEnabled: Bool {
        return enabled ?? true
    }

    public var hasEmail: Bool {
        return email != nil && !(email?.isEmpty ?? true)
    }

    public var hasDefaultProject: Bool {
        return defaultProjectId != nil
    }

    public var isPasswordExpired: Bool {
        guard let expiresAt = passwordExpiresAt else { return false }
        return Date() > expiresAt
    }
}

extension User: ResourceIdentifiable {}

// MARK: - Group Models

public struct Group: Codable, Sendable {
    public let id: String
    public let name: String?
    public let description: String?
    public let domainId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case domainId = "domain_id"
    }

    public init(
        id: String,
        name: String,
        description: String? = nil,
        domainId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.domainId = domainId
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? "Unnamed Group"
    }
}

extension Group: ResourceIdentifiable {}

// MARK: - Role Models

public struct Role: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let domainId: String?
    public let options: KeystoneMetadataWrapper?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case domainId = "domain_id"
        case options
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        domainId = try container.decodeIfPresent(String.self, forKey: .domainId)
        options = try container.decodeIfPresent(KeystoneMetadataWrapper.self, forKey: .options)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(domainId, forKey: .domainId)
        try container.encodeIfPresent(options, forKey: .options)
    }

    public init(
        id: String,
        name: String,
        description: String? = nil,
        domainId: String? = nil,
        options: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.domainId = domainId
        self.options = options.map(KeystoneMetadataWrapper.init)
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name
    }

    public var isDomainRole: Bool {
        return domainId != nil
    }
}

// MARK: - Role Assignment Models

public struct RoleAssignment: Codable, Sendable {
    public let role: RoleAssignmentRole
    public let scope: RoleAssignmentScope?
    public let user: RoleAssignmentUser?
    public let group: RoleAssignmentGroup?
    public let links: RoleAssignmentLinks?

    public init(
        role: RoleAssignmentRole,
        scope: RoleAssignmentScope? = nil,
        user: RoleAssignmentUser? = nil,
        group: RoleAssignmentGroup? = nil,
        links: RoleAssignmentLinks? = nil
    ) {
        self.role = role
        self.scope = scope
        self.user = user
        self.group = group
        self.links = links
    }

    // MARK: - Computed Properties

    public var isUserAssignment: Bool {
        return user != nil
    }

    public var isGroupAssignment: Bool {
        return group != nil
    }

    public var scopeType: String? {
        if scope?.project != nil {
            return "project"
        } else if scope?.domain != nil {
            return "domain"
        }
        return nil
    }
}

public struct RoleAssignmentRole: Codable, Sendable {
    public let id: String
    public let name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

public struct RoleAssignmentScope: Codable, Sendable {
    public let project: RoleAssignmentProject?
    public let domain: RoleAssignmentDomain?

    public init(project: RoleAssignmentProject? = nil, domain: RoleAssignmentDomain? = nil) {
        self.project = project
        self.domain = domain
    }
}

public struct RoleAssignmentProject: Codable, Sendable {
    public let id: String
    public let name: String?
    public let domainId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case domainId = "domain_id"
    }

    public init(id: String, name: String? = nil, domainId: String? = nil) {
        self.id = id
        self.name = name
        self.domainId = domainId
    }
}

public struct RoleAssignmentDomain: Codable, Sendable {
    public let id: String
    public let name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

public struct RoleAssignmentUser: Codable, Sendable {
    public let id: String
    public let name: String?
    public let domainId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case domainId = "domain_id"
    }

    public init(id: String, name: String? = nil, domainId: String? = nil) {
        self.id = id
        self.name = name
        self.domainId = domainId
    }
}

public struct RoleAssignmentGroup: Codable, Sendable {
    public let id: String
    public let name: String?
    public let domainId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case domainId = "domain_id"
    }

    public init(id: String, name: String? = nil, domainId: String? = nil) {
        self.id = id
        self.name = name
        self.domainId = domainId
    }
}

public struct RoleAssignmentLinks: Codable, Sendable {
    public let assignment: String?

    public init(assignment: String? = nil) {
        self.assignment = assignment
    }
}

// MARK: - Domain Models

public struct Domain: Codable, Sendable {
    public let id: String
    public let name: String?
    public let description: String?
    public let enabled: Bool?
    public let tags: [String]?
    public let options: KeystoneMetadataWrapper?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case enabled
        case tags
        case options
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        options = try container.decodeIfPresent(KeystoneMetadataWrapper.self, forKey: .options)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(options, forKey: .options)
    }

    public init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        enabled: Bool? = nil,
        tags: [String]? = nil,
        options: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.enabled = enabled
        self.tags = tags
        self.options = options.map(KeystoneMetadataWrapper.init)
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? "Unnamed Domain"
    }

    public var isEnabled: Bool {
        return enabled ?? true
    }

    public var hasTags: Bool {
        return !(tags?.isEmpty ?? true)
    }
}

extension Domain: ResourceIdentifiable {}

// MARK: - Service Models

public struct Service: Codable, Sendable, ResourceIdentifiable {
    public let id: String
    public let name: String?
    public let type: String
    public let description: String?
    public let enabled: Bool?

    public init(
        id: String,
        name: String? = nil,
        type: String,
        description: String? = nil,
        enabled: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.enabled = enabled
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? type
    }

    public var isEnabled: Bool {
        return enabled ?? true
    }
}

// MARK: - Endpoint Models

public struct Endpoint: Codable, Sendable, ResourceIdentifiable {
    public let id: String
    public let serviceId: String
    public let interface: String
    public let url: String
    public let region: String?
    public let regionId: String?
    public let enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case serviceId = "service_id"
        case interface
        case url
        case region
        case regionId = "region_id"
        case enabled
    }

    public init(
        id: String,
        serviceId: String,
        interface: String,
        url: String,
        region: String? = nil,
        regionId: String? = nil,
        enabled: Bool? = nil
    ) {
        self.id = id
        self.serviceId = serviceId
        self.interface = interface
        self.url = url
        self.region = region
        self.regionId = regionId
        self.enabled = enabled
    }

    // MARK: - Computed Properties

    public var name: String? {
        return "\(interface) endpoint"
    }

    public var displayName: String {
        return name ?? id
    }

    public var isEnabled: Bool {
        return enabled ?? true
    }

    public var endpointType: EndpointType? {
        return EndpointType(rawValue: interface.lowercased())
    }
}

public enum EndpointType: String, CaseIterable, Sendable {
    case publicEndpoint = "public"
    case internalEndpoint = "internal"
    case adminEndpoint = "admin"

    public var displayName: String {
        switch self {
        case .publicEndpoint: return "Public"
        case .internalEndpoint: return "Internal"
        case .adminEndpoint: return "Admin"
        }
    }
}

// MARK: - Token Models

public struct TokenInfo: Codable, Sendable {
    public let methods: [String]?
    public let expiresAt: Date?
    public let extras: KeystoneMetadataWrapper?
    public let user: TokenUser?
    public let auditIds: [String]?
    public let issuedAt: Date?
    public let project: TokenProject?
    public let domain: TokenDomain?
    public let roles: [TokenRole]?
    public let catalog: [TokenCatalogEntry]?

    enum CodingKeys: String, CodingKey {
        case methods
        case expiresAt = "expires_at"
        case extras
        case user
        case auditIds = "audit_ids"
        case issuedAt = "issued_at"
        case project
        case domain
        case roles
        case catalog
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        methods = try container.decodeIfPresent([String].self, forKey: .methods)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        user = try container.decodeIfPresent(TokenUser.self, forKey: .user)
        auditIds = try container.decodeIfPresent([String].self, forKey: .auditIds)
        issuedAt = try container.decodeIfPresent(Date.self, forKey: .issuedAt)
        project = try container.decodeIfPresent(TokenProject.self, forKey: .project)
        domain = try container.decodeIfPresent(TokenDomain.self, forKey: .domain)
        roles = try container.decodeIfPresent([TokenRole].self, forKey: .roles)
        catalog = try container.decodeIfPresent([TokenCatalogEntry].self, forKey: .catalog)
        extras = try container.decodeIfPresent(KeystoneMetadataWrapper.self, forKey: .extras)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(methods, forKey: .methods)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(auditIds, forKey: .auditIds)
        try container.encodeIfPresent(issuedAt, forKey: .issuedAt)
        try container.encodeIfPresent(project, forKey: .project)
        try container.encodeIfPresent(domain, forKey: .domain)
        try container.encodeIfPresent(roles, forKey: .roles)
        try container.encodeIfPresent(catalog, forKey: .catalog)
        try container.encodeIfPresent(extras, forKey: .extras)
    }

    public init(
        methods: [String]? = nil,
        expiresAt: Date? = nil,
        extras: [String: Any]? = nil,
        user: TokenUser? = nil,
        auditIds: [String]? = nil,
        issuedAt: Date? = nil,
        project: TokenProject? = nil,
        domain: TokenDomain? = nil,
        roles: [TokenRole]? = nil,
        catalog: [TokenCatalogEntry]? = nil
    ) {
        self.methods = methods
        self.expiresAt = expiresAt
        self.extras = extras.map { KeystoneMetadataWrapper($0) }
        self.user = user
        self.auditIds = auditIds
        self.issuedAt = issuedAt
        self.project = project
        self.domain = domain
        self.roles = roles
        self.catalog = catalog
    }

    // MARK: - Computed Properties

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    public var isValid: Bool {
        return !isExpired
    }

    public var hasProject: Bool {
        return project != nil
    }

    public var hasDomain: Bool {
        return domain != nil
    }

    public var scopeType: String? {
        if project != nil {
            return "project"
        } else if domain != nil {
            return "domain"
        }
        return "unscoped"
    }
}

public struct TokenUser: Codable, Sendable {
    public let id: String
    public let name: String?
    public let domain: TokenDomain?
    public let passwordExpiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case domain
        case passwordExpiresAt = "password_expires_at"
    }

    public init(
        id: String,
        name: String? = nil,
        domain: TokenDomain? = nil,
        passwordExpiresAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.passwordExpiresAt = passwordExpiresAt
    }
}

public struct TokenProject: Codable, Sendable {
    public let id: String
    public let name: String?
    public let domain: TokenDomain?

    public init(
        id: String,
        name: String? = nil,
        domain: TokenDomain? = nil
    ) {
        self.id = id
        self.name = name
        self.domain = domain
    }
}

public struct TokenDomain: Codable, Sendable {
    public let id: String
    public let name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

public struct TokenRole: Codable, Sendable {
    public let id: String
    public let name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

public struct TokenCatalogEntry: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let type: String
    public let endpoints: [TokenEndpoint]

    public init(
        id: String? = nil,
        name: String? = nil,
        type: String,
        endpoints: [TokenEndpoint]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.endpoints = endpoints
    }
}

public struct TokenEndpoint: Codable, Sendable {
    public let id: String?
    public let interface: String
    public let regionId: String?
    public let region: String?
    public let url: String

    enum CodingKeys: String, CodingKey {
        case id
        case interface
        case regionId = "region_id"
        case region
        case url
    }

    public init(
        id: String? = nil,
        interface: String,
        regionId: String? = nil,
        region: String? = nil,
        url: String
    ) {
        self.id = id
        self.interface = interface
        self.regionId = regionId
        self.region = region
        self.url = url
    }
}

// MARK: - Request Models

public struct CreateProjectRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let enabled: Bool?
    public let domainId: String?
    public let parentId: String?
    public let isDomain: Bool?
    public let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case enabled
        case domainId = "domain_id"
        case parentId = "parent_id"
        case isDomain = "is_domain"
        case tags
    }

    public init(
        name: String,
        description: String? = nil,
        enabled: Bool? = nil,
        domainId: String? = nil,
        parentId: String? = nil,
        isDomain: Bool? = nil,
        tags: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.enabled = enabled
        self.domainId = domainId
        self.parentId = parentId
        self.isDomain = isDomain
        self.tags = tags
    }
}

public struct UpdateProjectRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let enabled: Bool?
    public let tags: [String]?

    public init(
        name: String? = nil,
        description: String? = nil,
        enabled: Bool? = nil,
        tags: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.enabled = enabled
        self.tags = tags
    }
}

public struct CreateUserRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let email: String?
    public let password: String?
    public let enabled: Bool?
    public let domainId: String?
    public let defaultProjectId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case email
        case password
        case enabled
        case domainId = "domain_id"
        case defaultProjectId = "default_project_id"
    }

    public init(
        name: String,
        description: String? = nil,
        email: String? = nil,
        password: String? = nil,
        enabled: Bool? = nil,
        domainId: String? = nil,
        defaultProjectId: String? = nil
    ) {
        self.name = name
        self.description = description
        self.email = email
        self.password = password
        self.enabled = enabled
        self.domainId = domainId
        self.defaultProjectId = defaultProjectId
    }
}

public struct UpdateUserRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let email: String?
    public let enabled: Bool?
    public let defaultProjectId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case email
        case enabled
        case defaultProjectId = "default_project_id"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        email: String? = nil,
        enabled: Bool? = nil,
        defaultProjectId: String? = nil
    ) {
        self.name = name
        self.description = description
        self.email = email
        self.enabled = enabled
        self.defaultProjectId = defaultProjectId
    }
}

public struct ChangePasswordRequest: Codable, Sendable {
    public let originalPassword: String?
    public let password: String

    enum CodingKeys: String, CodingKey {
        case originalPassword = "original_password"
        case password
    }

    public init(originalPassword: String? = nil, password: String) {
        self.originalPassword = originalPassword
        self.password = password
    }
}

public struct CreateGroupRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let domainId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case domainId = "domain_id"
    }

    public init(name: String, description: String? = nil, domainId: String? = nil) {
        self.name = name
        self.description = description
        self.domainId = domainId
    }
}

public struct UpdateGroupRequest: Codable, Sendable {
    public let name: String?
    public let description: String?

    public init(name: String? = nil, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct CreateRoleRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let domainId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case domainId = "domain_id"
    }

    public init(name: String, description: String? = nil, domainId: String? = nil) {
        self.name = name
        self.description = description
        self.domainId = domainId
    }
}

public struct UpdateRoleRequest: Codable, Sendable {
    public let name: String?
    public let description: String?

    public init(name: String? = nil, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct CreateDomainRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let enabled: Bool?
    public let tags: [String]?

    public init(
        name: String,
        description: String? = nil,
        enabled: Bool? = nil,
        tags: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.enabled = enabled
        self.tags = tags
    }
}

public struct UpdateDomainRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let enabled: Bool?
    public let tags: [String]?

    public init(
        name: String? = nil,
        description: String? = nil,
        enabled: Bool? = nil,
        tags: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.enabled = enabled
        self.tags = tags
    }
}

public struct CreateServiceRequest: Codable, Sendable {
    public let name: String?
    public let type: String
    public let description: String?
    public let enabled: Bool?

    public init(
        name: String? = nil,
        type: String,
        description: String? = nil,
        enabled: Bool? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.enabled = enabled
    }
}

public struct UpdateServiceRequest: Codable, Sendable {
    public let name: String?
    public let type: String?
    public let description: String?
    public let enabled: Bool?

    public init(
        name: String? = nil,
        type: String? = nil,
        description: String? = nil,
        enabled: Bool? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.enabled = enabled
    }
}

public struct CreateEndpointRequest: Codable, Sendable {
    public let serviceId: String
    public let interface: String
    public let url: String
    public let region: String?
    public let enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case interface
        case url
        case region
        case enabled
    }

    public init(
        serviceId: String,
        interface: String,
        url: String,
        region: String? = nil,
        enabled: Bool? = nil
    ) {
        self.serviceId = serviceId
        self.interface = interface
        self.url = url
        self.region = region
        self.enabled = enabled
    }
}

public struct UpdateEndpointRequest: Codable, Sendable {
    public let serviceId: String?
    public let interface: String?
    public let url: String?
    public let region: String?
    public let enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case interface
        case url
        case region
        case enabled
    }

    public init(
        serviceId: String? = nil,
        interface: String? = nil,
        url: String? = nil,
        region: String? = nil,
        enabled: Bool? = nil
    ) {
        self.serviceId = serviceId
        self.interface = interface
        self.url = url
        self.region = region
        self.enabled = enabled
    }
}

// MARK: - Validation Extensions

extension CreateProjectRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Project name cannot be empty")
        }

        if let domainId = domainId, !domainId.isValidUUID {
            errors.append("Domain ID must be a valid UUID")
        }

        if let parentId = parentId, !parentId.isValidUUID {
            errors.append("Parent ID must be a valid UUID")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

extension CreateUserRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("User name cannot be empty")
        }

        if let email = email, !email.isEmpty && !email.isValidEmail {
            errors.append("Email must be a valid email address")
        }

        if let domainId = domainId, !domainId.isValidUUID {
            errors.append("Domain ID must be a valid UUID")
        }

        if let defaultProjectId = defaultProjectId, !defaultProjectId.isValidUUID {
            errors.append("Default project ID must be a valid UUID")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

extension CreateEndpointRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if !serviceId.isValidUUID {
            errors.append("Service ID must be a valid UUID")
        }

        if interface.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Interface cannot be empty")
        }

        if let url = URL(string: url), url.scheme == nil {
            errors.append("URL must include a scheme (http/https)")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}