import Foundation

// MARK: - Barbican (Key Management) Service

public actor BarbicanService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "key-manager"

    public init(core: OpenStackClientCore) {
        self.core = core
    }

    // MARK: - Secret Operations

    /// List secrets
    public func listSecrets(options: PaginationOptions = PaginationOptions()) async throws -> [Secret] {
        var path = "/v1/secrets"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: SecretListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.secrets
    }

    /// Get secret details
    public func getSecret(id: String) async throws -> SecretDetailResponse {
        let response: SecretDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v1/secrets/\(id)",
            expected: 200
        )
        return response
    }

    /// Create a secret
    public func createSecret(request: CreateSecretRequest) async throws -> SecretRef {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: SecretRef = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v1/secrets",
            body: requestData,
            expected: 201
        )
        return response
    }

    /// Update a secret
    public func updateSecret(id: String, request: UpdateSecretRequest) async throws {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/v1/secrets/\(id)",
            body: requestData,
            expected: 204
        )
    }

    /// Delete a secret
    public func deleteSecret(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v1/secrets/\(id)",
            expected: 204
        )
    }

    /// Get secret payload
    public func getSecretPayload(id: String, payloadContentType: String? = nil) async throws -> Data {
        var headers: [String: String] = [:]
        if let contentType = payloadContentType {
            headers["Accept"] = contentType
        }

        let data: Data = try await core.requestRaw(
            service: serviceName,
            method: "GET",
            path: "/v1/secrets/\(id)/payload",
            headers: headers.isEmpty ? nil : headers,
            expected: 200
        )
        return data
    }

    /// Store secret payload
    public func storeSecretPayload(id: String, payload: Data, contentType: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/v1/secrets/\(id)",
            body: payload,
            headers: ["Content-Type": contentType],
            expected: 204
        )
    }

    // MARK: - Container Operations

    /// List containers
    public func listContainers(options: PaginationOptions = PaginationOptions()) async throws -> [BarbicanContainer] {
        var path = "/v1/containers"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: BarbicanContainerListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.containers
    }

    /// Get container details
    public func getContainer(id: String) async throws -> BarbicanContainer {
        let response: BarbicanContainer = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v1/containers/\(id)",
            expected: 200
        )
        return response
    }

    /// Create a container
    public func createContainer(request: BarbicanCreateContainerRequest) async throws -> ContainerRef {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: ContainerRef = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v1/containers",
            body: requestData,
            expected: 201
        )
        return response
    }

    /// Delete a container
    public func deleteContainer(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v1/containers/\(id)",
            expected: 204
        )
    }

    // MARK: - Certificate Authority Operations

    /// List certificate authorities
    public func listCertificateAuthorities(options: PaginationOptions = PaginationOptions()) async throws -> [CertificateAuthority] {
        var path = "/v1/cas"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: CertificateAuthorityListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.cas
    }

    /// Get certificate authority details
    public func getCertificateAuthority(id: String) async throws -> CertificateAuthority {
        let response: CertificateAuthority = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v1/cas/\(id)",
            expected: 200
        )
        return response
    }

    /// Create a certificate authority
    public func createCertificateAuthority(request: CreateCertificateAuthorityRequest) async throws -> CertificateAuthorityRef {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: CertificateAuthorityRef = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v1/cas",
            body: requestData,
            expected: 201
        )
        return response
    }

    /// Delete a certificate authority
    public func deleteCertificateAuthority(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v1/cas/\(id)",
            expected: 204
        )
    }

    /// Get certificate authority signing certificate
    public func getCertificateAuthoritySigningCert(id: String) async throws -> String {
        let data: Data = try await core.requestRaw(
            service: serviceName,
            method: "GET",
            path: "/v1/cas/\(id)/signing-certificate",
            expected: 200
        )
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Get certificate authority certificate chain
    public func getCertificateAuthorityCertificateChain(id: String) async throws -> String {
        let data: Data = try await core.requestRaw(
            service: serviceName,
            method: "GET",
            path: "/v1/cas/\(id)/certificate-chain",
            expected: 200
        )
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Certificate Order Operations

    /// List certificate orders
    public func listCertificateOrders(options: PaginationOptions = PaginationOptions()) async throws -> [CertificateOrder] {
        var path = "/v1/orders"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: CertificateOrderListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.orders
    }

    /// Get certificate order details
    public func getCertificateOrder(id: String) async throws -> CertificateOrder {
        let response: CertificateOrder = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v1/orders/\(id)",
            expected: 200
        )
        return response
    }

    /// Create a certificate order
    public func createCertificateOrder(request: CreateCertificateOrderRequest) async throws -> CertificateOrderRef {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: CertificateOrderRef = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v1/orders",
            body: requestData,
            expected: 202
        )
        return response
    }

    /// Delete a certificate order
    public func deleteCertificateOrder(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v1/orders/\(id)",
            expected: 204
        )
    }

    // MARK: - ACL Operations

    /// Get secret ACL
    public func getSecretACL(secretId: String) async throws -> ACL {
        let response: ACL = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v1/secrets/\(secretId)/acl",
            expected: 200
        )
        return response
    }

    /// Update secret ACL
    public func updateSecretACL(secretId: String, request: UpdateACLRequest) async throws -> ACL {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: ACL = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v1/secrets/\(secretId)/acl",
            body: requestData,
            expected: 200
        )
        return response
    }

    /// Delete secret ACL
    public func deleteSecretACL(secretId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v1/secrets/\(secretId)/acl",
            expected: 200
        )
    }

    /// Get container ACL
    public func getContainerACL(containerId: String) async throws -> ACL {
        let response: ACL = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v1/containers/\(containerId)/acl",
            expected: 200
        )
        return response
    }

    /// Update container ACL
    public func updateContainerACL(containerId: String, request: UpdateACLRequest) async throws -> ACL {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: ACL = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v1/containers/\(containerId)/acl",
            body: requestData,
            expected: 200
        )
        return response
    }

    /// Delete container ACL
    public func deleteContainerACL(containerId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v1/containers/\(containerId)/acl",
            expected: 200
        )
    }

    // MARK: - Quota Operations

    /// Get project quotas
    public func getProjectQuotas(projectId: String) async throws -> ProjectQuota {
        let response: ProjectQuotaResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v1/project-quotas/\(projectId)",
            expected: 200
        )
        return response.projectQuotas
    }

    /// List project quotas
    public func listProjectQuotas(options: PaginationOptions = PaginationOptions()) async throws -> [ProjectQuota] {
        var path = "/v1/project-quotas"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: ProjectQuotaListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.projectQuotas
    }

    /// Update project quotas
    public func updateProjectQuotas(projectId: String, request: UpdateProjectQuotaRequest) async throws -> ProjectQuota {
        let requestData = try SharedResources.jsonEncoder.encode(["project_quotas": request])
        let response: ProjectQuotaResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/v1/project-quotas/\(projectId)",
            body: requestData,
            expected: 200
        )
        return response.projectQuotas
    }

    /// Delete project quotas (reset to defaults)
    public func deleteProjectQuotas(projectId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v1/project-quotas/\(projectId)",
            expected: 204
        )
    }
}

// MARK: - Response Models

public struct SecretListResponse: Codable, Sendable {
    public let secrets: [Secret]
    public let total: Int?
    public let next: String?
    public let previous: String?

    public init(secrets: [Secret], total: Int? = nil, next: String? = nil, previous: String? = nil) {
        self.secrets = secrets
        self.total = total
        self.next = next
        self.previous = previous
    }
}

public struct SecretDetailResponse: Codable, Sendable {
    public let algorithm: String?
    public let bitLength: Int?
    public let contentTypes: [String: String]?
    public let created: Date?
    public let creatorId: String?
    public let expiration: Date?
    public let mode: String?
    public let name: String?
    public let secretRef: String?
    public let secretType: String?
    public let status: String?
    public let updated: Date?

    enum CodingKeys: String, CodingKey {
        case algorithm
        case bitLength = "bit_length"
        case contentTypes = "content_types"
        case created
        case creatorId = "creator_id"
        case expiration
        case mode
        case name
        case secretRef = "secret_ref"
        case secretType = "secret_type"
        case status
        case updated
    }

    public init(
        algorithm: String? = nil,
        bitLength: Int? = nil,
        contentTypes: [String: String]? = nil,
        created: Date? = nil,
        creatorId: String? = nil,
        expiration: Date? = nil,
        mode: String? = nil,
        name: String? = nil,
        secretRef: String? = nil,
        secretType: String? = nil,
        status: String? = nil,
        updated: Date? = nil
    ) {
        self.algorithm = algorithm
        self.bitLength = bitLength
        self.contentTypes = contentTypes
        self.created = created
        self.creatorId = creatorId
        self.expiration = expiration
        self.mode = mode
        self.name = name
        self.secretRef = secretRef
        self.secretType = secretType
        self.status = status
        self.updated = updated
    }
}

public struct BarbicanContainerListResponse: Codable, Sendable {
    public let containers: [BarbicanContainer]
    public let total: Int?
    public let next: String?
    public let previous: String?

    public init(containers: [BarbicanContainer], total: Int? = nil, next: String? = nil, previous: String? = nil) {
        self.containers = containers
        self.total = total
        self.next = next
        self.previous = previous
    }
}

public struct CertificateAuthorityListResponse: Codable, Sendable {
    public let cas: [CertificateAuthority]
    public let total: Int?
    public let next: String?
    public let previous: String?

    public init(cas: [CertificateAuthority], total: Int? = nil, next: String? = nil, previous: String? = nil) {
        self.cas = cas
        self.total = total
        self.next = next
        self.previous = previous
    }
}

public struct CertificateOrderListResponse: Codable, Sendable {
    public let orders: [CertificateOrder]
    public let total: Int?
    public let next: String?
    public let previous: String?

    public init(orders: [CertificateOrder], total: Int? = nil, next: String? = nil, previous: String? = nil) {
        self.orders = orders
        self.total = total
        self.next = next
        self.previous = previous
    }
}

public struct ProjectQuotaResponse: Codable, Sendable {
    public let projectQuotas: ProjectQuota

    enum CodingKeys: String, CodingKey {
        case projectQuotas = "project_quotas"
    }

    public init(projectQuotas: ProjectQuota) {
        self.projectQuotas = projectQuotas
    }
}

public struct ProjectQuotaListResponse: Codable, Sendable {
    public let projectQuotas: [ProjectQuota]

    enum CodingKeys: String, CodingKey {
        case projectQuotas = "project_quotas"
    }

    public init(projectQuotas: [ProjectQuota]) {
        self.projectQuotas = projectQuotas
    }
}