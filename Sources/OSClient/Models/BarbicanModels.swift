import Foundation

// MARK: - Secret Models

public struct Secret: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let secretRef: String?
    public let name: String?
    public let secretType: String?
    public let algorithm: String?
    public let bitLength: Int?
    public let mode: String?
    public let expiration: Date?
    public let created: Date?
    public let updated: Date?
    public let status: String?
    public let contentTypes: [String: String]?
    public let creatorId: String?

    public var id: String {
        guard let ref = secretRef else { return "" }
        return String(ref.split(separator: "/").last ?? "")
    }

    public var createdAt: Date? { created }
    public var updatedAt: Date? { updated }

    enum CodingKeys: String, CodingKey {
        case secretRef = "secret_ref"
        case name
        case secretType = "secret_type"
        case algorithm
        case bitLength = "bit_length"
        case mode
        case expiration
        case created
        case updated
        case status
        case contentTypes = "content_types"
        case creatorId = "creator_id"
    }

    public init(
        secretRef: String? = nil,
        name: String? = nil,
        secretType: String? = nil,
        algorithm: String? = nil,
        bitLength: Int? = nil,
        mode: String? = nil,
        expiration: Date? = nil,
        created: Date? = nil,
        updated: Date? = nil,
        status: String? = nil,
        contentTypes: [String: String]? = nil,
        creatorId: String? = nil
    ) {
        self.secretRef = secretRef
        self.name = name
        self.secretType = secretType
        self.algorithm = algorithm
        self.bitLength = bitLength
        self.mode = mode
        self.expiration = expiration
        self.created = created
        self.updated = updated
        self.status = status
        self.contentTypes = contentTypes
        self.creatorId = creatorId
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? id
    }

    public var isExpired: Bool {
        guard let expiration = expiration else { return false }
        return Date() > expiration
    }

    public var isActive: Bool {
        return status?.lowercased() == "active"
    }

    public var type: SecretType? {
        guard let secretType = secretType else { return nil }
        return SecretType(rawValue: secretType.lowercased())
    }

    public var encryptionAlgorithm: EncryptionAlgorithm? {
        guard let algorithm = algorithm else { return nil }
        return EncryptionAlgorithm(rawValue: algorithm.lowercased())
    }

    public var hasContentTypes: Bool {
        return !(contentTypes?.isEmpty ?? true)
    }

    public var keySize: Int {
        return bitLength ?? 0
    }
}

public enum SecretType: String, CaseIterable, Sendable {
    case symmetric = "symmetric"
    case asymmetric = "asymmetric"
    case passphrase = "passphrase"
    case certificate = "certificate"
    case publicKey = "public"
    case privateKey = "private"
    case opaque = "opaque"

    public var displayName: String {
        switch self {
        case .symmetric: return "Symmetric Key"
        case .asymmetric: return "Asymmetric Key"
        case .passphrase: return "Passphrase"
        case .certificate: return "Certificate"
        case .publicKey: return "Public Key"
        case .privateKey: return "Private Key"
        case .opaque: return "Opaque Data"
        }
    }
}

public enum EncryptionAlgorithm: String, CaseIterable, Sendable {
    case aes = "aes"
    case des = "des"
    case desede = "desede"
    case rsa = "rsa"
    case dsa = "dsa"
    case ec = "ec"
    case diffieHellman = "diffie-hellman"
    case hmacSha1 = "hmacsha1"
    case hmacSha256 = "hmacsha256"
    case hmacSha384 = "hmacsha384"
    case hmacSha512 = "hmacsha512"

    public var displayName: String {
        switch self {
        case .aes: return "AES"
        case .des: return "DES"
        case .desede: return "3DES"
        case .rsa: return "RSA"
        case .dsa: return "DSA"
        case .ec: return "Elliptic Curve"
        case .diffieHellman: return "Diffie-Hellman"
        case .hmacSha1: return "HMAC-SHA1"
        case .hmacSha256: return "HMAC-SHA256"
        case .hmacSha384: return "HMAC-SHA384"
        case .hmacSha512: return "HMAC-SHA512"
        }
    }
}

public struct SecretRef: Codable, Sendable {
    public let secretRef: String

    enum CodingKeys: String, CodingKey {
        case secretRef = "secret_ref"
    }

    public init(secretRef: String) {
        self.secretRef = secretRef
    }

    public var secretId: String {
        return String(secretRef.split(separator: "/").last ?? "")
    }
}

// MARK: - Container Models

public struct BarbicanContainer: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let containerRef: String?
    public let name: String?
    public let type: String?
    public let status: String?
    public let created: Date?
    public let updated: Date?
    public let creatorId: String?
    public let secretRefs: [ContainerSecretRef]?
    public let consumers: [ContainerConsumer]?

    public var id: String {
        guard let ref = containerRef else { return "" }
        return String(ref.split(separator: "/").last ?? "")
    }

    public var createdAt: Date? { created }
    public var updatedAt: Date? { updated }

    enum CodingKeys: String, CodingKey {
        case containerRef = "container_ref"
        case name
        case type
        case status
        case created
        case updated
        case creatorId = "creator_id"
        case secretRefs = "secret_refs"
        case consumers
    }

    public init(
        containerRef: String? = nil,
        name: String? = nil,
        type: String? = nil,
        status: String? = nil,
        created: Date? = nil,
        updated: Date? = nil,
        creatorId: String? = nil,
        secretRefs: [ContainerSecretRef]? = nil,
        consumers: [ContainerConsumer]? = nil
    ) {
        self.containerRef = containerRef
        self.name = name
        self.type = type
        self.status = status
        self.created = created
        self.updated = updated
        self.creatorId = creatorId
        self.secretRefs = secretRefs
        self.consumers = consumers
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? id
    }

    public var isActive: Bool {
        return status?.lowercased() == "active"
    }

    public var containerType: ContainerType? {
        guard let type = type else { return nil }
        return ContainerType(rawValue: type.lowercased())
    }

    public var secretCount: Int {
        return secretRefs?.count ?? 0
    }

    public var consumerCount: Int {
        return consumers?.count ?? 0
    }

    public var hasSecrets: Bool {
        return secretCount > 0
    }

    public var hasConsumers: Bool {
        return consumerCount > 0
    }
}

public enum ContainerType: String, CaseIterable, Sendable {
    case generic = "generic"
    case rsa = "rsa"
    case certificate = "certificate"

    public var displayName: String {
        switch self {
        case .generic: return "Generic"
        case .rsa: return "RSA Key Pair"
        case .certificate: return "Certificate"
        }
    }
}

public struct ContainerSecretRef: Codable, Sendable {
    public let name: String?
    public let secretRef: String

    enum CodingKeys: String, CodingKey {
        case name
        case secretRef = "secret_ref"
    }

    public init(name: String? = nil, secretRef: String) {
        self.name = name
        self.secretRef = secretRef
    }

    public var secretId: String {
        return String(secretRef.split(separator: "/").last ?? "")
    }
}

public struct ContainerConsumer: Codable, Sendable {
    public let name: String?
    public let url: String?

    public init(name: String? = nil, url: String? = nil) {
        self.name = name
        self.url = url
    }
}

public struct ContainerRef: Codable, Sendable {
    public let containerRef: String

    enum CodingKeys: String, CodingKey {
        case containerRef = "container_ref"
    }

    public init(containerRef: String) {
        self.containerRef = containerRef
    }

    public var containerId: String {
        return String(containerRef.split(separator: "/").last ?? "")
    }
}

// MARK: - Certificate Authority Models

public struct CertificateAuthority: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let caRef: String?
    public let name: String?
    public let description: String?
    public let status: String?
    public let created: Date?
    public let updated: Date?
    public let creatorId: String?
    public let pluginName: String?
    public let pluginCaId: String?
    public let expirationTime: Date?
    public let metaData: [String: String]?

    public var id: String {
        guard let ref = caRef else { return "" }
        return String(ref.split(separator: "/").last ?? "")
    }

    public var createdAt: Date? { created }
    public var updatedAt: Date? { updated }

    enum CodingKeys: String, CodingKey {
        case caRef = "ca_ref"
        case name
        case description
        case status
        case created
        case updated
        case creatorId = "creator_id"
        case pluginName = "plugin_name"
        case pluginCaId = "plugin_ca_id"
        case expirationTime = "expiration_time"
        case metaData = "meta_data"
    }

    public init(
        caRef: String? = nil,
        name: String? = nil,
        description: String? = nil,
        status: String? = nil,
        created: Date? = nil,
        updated: Date? = nil,
        creatorId: String? = nil,
        pluginName: String? = nil,
        pluginCaId: String? = nil,
        expirationTime: Date? = nil,
        metaData: [String: String]? = nil
    ) {
        self.caRef = caRef
        self.name = name
        self.description = description
        self.status = status
        self.created = created
        self.updated = updated
        self.creatorId = creatorId
        self.pluginName = pluginName
        self.pluginCaId = pluginCaId
        self.expirationTime = expirationTime
        self.metaData = metaData
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? id
    }

    public var isActive: Bool {
        return status?.lowercased() == "active"
    }

    public var isExpired: Bool {
        guard let expiration = expirationTime else { return false }
        return Date() > expiration
    }

    public var hasMetadata: Bool {
        return !(metaData?.isEmpty ?? true)
    }
}

public struct CertificateAuthorityRef: Codable, Sendable {
    public let caRef: String

    enum CodingKeys: String, CodingKey {
        case caRef = "ca_ref"
    }

    public init(caRef: String) {
        self.caRef = caRef
    }

    public var caId: String {
        return String(caRef.split(separator: "/").last ?? "")
    }
}

// MARK: - Metadata Wrapper

public struct MetadataWrapper: Codable, Sendable {
    private let data: Data

    public init(_ dictionary: [String: String]) {
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

// MARK: - Certificate Order Models

public struct CertificateOrder: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let orderRef: String?
    public let type: String?
    public let status: String?
    public let errorReason: String?
    public let errorStatusCode: String?
    public let meta: MetadataWrapper?
    public let created: Date?
    public let updated: Date?
    public let creatorId: String?
    public let containerRef: String?
    public let subStatus: String?
    public let subStatusMessage: String?

    public var id: String {
        guard let ref = orderRef else { return "" }
        return String(ref.split(separator: "/").last ?? "")
    }

    public var name: String? { id }
    public var createdAt: Date? { created }
    public var updatedAt: Date? { updated }

    enum CodingKeys: String, CodingKey {
        case orderRef = "order_ref"
        case type
        case status
        case errorReason = "error_reason"
        case errorStatusCode = "error_status_code"
        case meta
        case created
        case updated
        case creatorId = "creator_id"
        case containerRef = "container_ref"
        case subStatus = "sub_status"
        case subStatusMessage = "sub_status_message"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderRef = try container.decodeIfPresent(String.self, forKey: .orderRef)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        errorReason = try container.decodeIfPresent(String.self, forKey: .errorReason)
        errorStatusCode = try container.decodeIfPresent(String.self, forKey: .errorStatusCode)
        created = try container.decodeIfPresent(Date.self, forKey: .created)
        updated = try container.decodeIfPresent(Date.self, forKey: .updated)
        creatorId = try container.decodeIfPresent(String.self, forKey: .creatorId)
        containerRef = try container.decodeIfPresent(String.self, forKey: .containerRef)
        subStatus = try container.decodeIfPresent(String.self, forKey: .subStatus)
        subStatusMessage = try container.decodeIfPresent(String.self, forKey: .subStatusMessage)
        meta = try container.decodeIfPresent(MetadataWrapper.self, forKey: .meta)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(orderRef, forKey: .orderRef)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(errorReason, forKey: .errorReason)
        try container.encodeIfPresent(errorStatusCode, forKey: .errorStatusCode)
        try container.encodeIfPresent(created, forKey: .created)
        try container.encodeIfPresent(updated, forKey: .updated)
        try container.encodeIfPresent(creatorId, forKey: .creatorId)
        try container.encodeIfPresent(containerRef, forKey: .containerRef)
        try container.encodeIfPresent(subStatus, forKey: .subStatus)
        try container.encodeIfPresent(subStatusMessage, forKey: .subStatusMessage)
        try container.encodeIfPresent(meta, forKey: .meta)
    }

    public init(
        orderRef: String? = nil,
        type: String? = nil,
        status: String? = nil,
        errorReason: String? = nil,
        errorStatusCode: String? = nil,
        meta: MetadataWrapper? = nil,
        created: Date? = nil,
        updated: Date? = nil,
        creatorId: String? = nil,
        containerRef: String? = nil,
        subStatus: String? = nil,
        subStatusMessage: String? = nil
    ) {
        self.orderRef = orderRef
        self.type = type
        self.status = status
        self.errorReason = errorReason
        self.errorStatusCode = errorStatusCode
        self.meta = meta
        self.created = created
        self.updated = updated
        self.creatorId = creatorId
        self.containerRef = containerRef
        self.subStatus = subStatus
        self.subStatusMessage = subStatusMessage
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return id
    }

    public var isActive: Bool {
        return status?.lowercased() == "active"
    }

    public var isError: Bool {
        return status?.lowercased() == "error"
    }

    public var isPending: Bool {
        return status?.lowercased() == "pending"
    }

    public var orderType: CertificateOrderType? {
        guard let type = type else { return nil }
        return CertificateOrderType(rawValue: type.lowercased())
    }

    public var hasError: Bool {
        return errorReason != nil || errorStatusCode != nil
    }

    public var hasContainer: Bool {
        return containerRef != nil
    }
}

public enum CertificateOrderType: String, CaseIterable, Sendable {
    case certificate = "certificate"
    case asymmetric = "asymmetric"
    case key = "key"

    public var displayName: String {
        switch self {
        case .certificate: return "Certificate"
        case .asymmetric: return "Asymmetric Key"
        case .key: return "Key"
        }
    }
}

public struct CertificateOrderRef: Codable, Sendable {
    public let orderRef: String

    enum CodingKeys: String, CodingKey {
        case orderRef = "order_ref"
    }

    public init(orderRef: String) {
        self.orderRef = orderRef
    }

    public var orderId: String {
        return String(orderRef.split(separator: "/").last ?? "")
    }
}

// MARK: - ACL Models

public struct ACL: Codable, Sendable {
    public let read: ACLOperation?
    public let write: ACLOperation?
    public let delete: ACLOperation?
    public let list: ACLOperation?

    public init(
        read: ACLOperation? = nil,
        write: ACLOperation? = nil,
        delete: ACLOperation? = nil,
        list: ACLOperation? = nil
    ) {
        self.read = read
        self.write = write
        self.delete = delete
        self.list = list
    }

    // MARK: - Computed Properties

    public var hasReadAccess: Bool {
        return read != nil
    }

    public var hasWriteAccess: Bool {
        return write != nil
    }

    public var hasDeleteAccess: Bool {
        return delete != nil
    }

    public var hasListAccess: Bool {
        return list != nil
    }
}

public struct ACLOperation: Codable, Sendable {
    public let users: [String]?
    public let projectAccess: Bool?

    enum CodingKeys: String, CodingKey {
        case users
        case projectAccess = "project-access"
    }

    public init(users: [String]? = nil, projectAccess: Bool? = nil) {
        self.users = users
        self.projectAccess = projectAccess
    }

    public var userCount: Int {
        return users?.count ?? 0
    }

    public var hasUsers: Bool {
        return userCount > 0
    }

    public var isProjectAccessible: Bool {
        return projectAccess ?? false
    }
}

// MARK: - Quota Models

public struct ProjectQuota: Codable, Sendable {
    public let projectId: String?
    public let secrets: Int?
    public let orders: Int?
    public let containers: Int?
    public let consumers: Int?
    public let cas: Int?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case secrets
        case orders
        case containers
        case consumers
        case cas
    }

    public init(
        projectId: String? = nil,
        secrets: Int? = nil,
        orders: Int? = nil,
        containers: Int? = nil,
        consumers: Int? = nil,
        cas: Int? = nil
    ) {
        self.projectId = projectId
        self.secrets = secrets
        self.orders = orders
        self.containers = containers
        self.consumers = consumers
        self.cas = cas
    }

    // MARK: - Computed Properties

    public var secretQuota: Int {
        return secrets ?? -1
    }

    public var orderQuota: Int {
        return orders ?? -1
    }

    public var containerQuota: Int {
        return containers ?? -1
    }

    public var consumerQuota: Int {
        return consumers ?? -1
    }

    public var caQuota: Int {
        return cas ?? -1
    }

    public var hasUnlimitedSecrets: Bool {
        return secretQuota == -1
    }

    public var hasUnlimitedOrders: Bool {
        return orderQuota == -1
    }

    public var hasUnlimitedContainers: Bool {
        return containerQuota == -1
    }

    public var hasUnlimitedConsumers: Bool {
        return consumerQuota == -1
    }

    public var hasUnlimitedCAs: Bool {
        return caQuota == -1
    }
}

// MARK: - Request Models

public struct CreateSecretRequest: Codable, Sendable {
    public let name: String?
    public let secretType: String?
    public let algorithm: String?
    public let bitLength: Int?
    public let mode: String?
    public let payload: String?
    public let payloadContentType: String?
    public let payloadContentEncoding: String?
    public let expiration: Date?

    enum CodingKeys: String, CodingKey {
        case name
        case secretType = "secret_type"
        case algorithm
        case bitLength = "bit_length"
        case mode
        case payload
        case payloadContentType = "payload_content_type"
        case payloadContentEncoding = "payload_content_encoding"
        case expiration
    }

    public init(
        name: String? = nil,
        secretType: String? = nil,
        algorithm: String? = nil,
        bitLength: Int? = nil,
        mode: String? = nil,
        payload: String? = nil,
        payloadContentType: String? = nil,
        payloadContentEncoding: String? = nil,
        expiration: Date? = nil
    ) {
        self.name = name
        self.secretType = secretType
        self.algorithm = algorithm
        self.bitLength = bitLength
        self.mode = mode
        self.payload = payload
        self.payloadContentType = payloadContentType
        self.payloadContentEncoding = payloadContentEncoding
        self.expiration = expiration
    }
}

public struct UpdateSecretRequest: Codable, Sendable {
    public let payload: String
    public let payloadContentType: String
    public let payloadContentEncoding: String?

    enum CodingKeys: String, CodingKey {
        case payload
        case payloadContentType = "payload_content_type"
        case payloadContentEncoding = "payload_content_encoding"
    }

    public init(
        payload: String,
        payloadContentType: String,
        payloadContentEncoding: String? = nil
    ) {
        self.payload = payload
        self.payloadContentType = payloadContentType
        self.payloadContentEncoding = payloadContentEncoding
    }
}

public struct BarbicanCreateContainerRequest: Codable, Sendable {
    public let name: String?
    public let type: String
    public let secretRefs: [CreateContainerSecretRef]?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case secretRefs = "secret_refs"
    }

    public init(
        name: String? = nil,
        type: String,
        secretRefs: [CreateContainerSecretRef]? = nil
    ) {
        self.name = name
        self.type = type
        self.secretRefs = secretRefs
    }
}

public struct CreateContainerSecretRef: Codable, Sendable {
    public let name: String
    public let secretRef: String

    enum CodingKeys: String, CodingKey {
        case name
        case secretRef = "secret_ref"
    }

    public init(name: String, secretRef: String) {
        self.name = name
        self.secretRef = secretRef
    }
}

public struct CreateCertificateAuthorityRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let subjectDn: String?
    public let parentCaRef: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case subjectDn = "subject_dn"
        case parentCaRef = "parent_ca_ref"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        subjectDn: String? = nil,
        parentCaRef: String? = nil
    ) {
        self.name = name
        self.description = description
        self.subjectDn = subjectDn
        self.parentCaRef = parentCaRef
    }
}

public struct CreateCertificateOrderRequest: Codable, Sendable {
    public let type: String
    public let meta: MetadataWrapper?

    enum CodingKeys: String, CodingKey {
        case type
        case meta
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        meta = try container.decodeIfPresent(MetadataWrapper.self, forKey: .meta)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(meta, forKey: .meta)
    }

    public init(type: String, meta: MetadataWrapper? = nil) {
        self.type = type
        self.meta = meta
    }
}

public struct UpdateACLRequest: Codable, Sendable {
    public let read: UpdateACLOperation?
    public let write: UpdateACLOperation?
    public let delete: UpdateACLOperation?
    public let list: UpdateACLOperation?

    public init(
        read: UpdateACLOperation? = nil,
        write: UpdateACLOperation? = nil,
        delete: UpdateACLOperation? = nil,
        list: UpdateACLOperation? = nil
    ) {
        self.read = read
        self.write = write
        self.delete = delete
        self.list = list
    }
}

public struct UpdateACLOperation: Codable, Sendable {
    public let users: [String]?
    public let projectAccess: Bool?

    enum CodingKeys: String, CodingKey {
        case users
        case projectAccess = "project-access"
    }

    public init(users: [String]? = nil, projectAccess: Bool? = nil) {
        self.users = users
        self.projectAccess = projectAccess
    }
}

public struct UpdateProjectQuotaRequest: Codable, Sendable {
    public let secrets: Int?
    public let orders: Int?
    public let containers: Int?
    public let consumers: Int?
    public let cas: Int?

    public init(
        secrets: Int? = nil,
        orders: Int? = nil,
        containers: Int? = nil,
        consumers: Int? = nil,
        cas: Int? = nil
    ) {
        self.secrets = secrets
        self.orders = orders
        self.containers = containers
        self.consumers = consumers
        self.cas = cas
    }
}

// MARK: - Validation Extensions

extension CreateSecretRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if let name = name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Secret name cannot be empty")
        }

        if let bitLength = bitLength, bitLength <= 0 {
            errors.append("Bit length must be greater than 0")
        }

        if let payload = payload, payload.isEmpty {
            errors.append("Payload cannot be empty when provided")
        }

        if payload != nil && payloadContentType == nil {
            errors.append("Payload content type must be specified when payload is provided")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

extension BarbicanCreateContainerRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Container type cannot be empty")
        }

        if let name = name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Container name cannot be empty")
        }

        if let refs = secretRefs {
            for ref in refs {
                if ref.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errors.append("Secret reference name cannot be empty")
                }
                if ref.secretRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errors.append("Secret reference URL cannot be empty")
                }
            }
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

extension CreateCertificateOrderRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Order type cannot be empty")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}