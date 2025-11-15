import Foundation

// MARK: - Keystone (Identity) Service

public actor KeystoneService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "identity"

    public init(core: OpenStackClientCore) {
        self.core = core
    }

    // MARK: - Project Operations

    /// List projects
    public func listProjects(options: PaginationOptions = PaginationOptions()) async throws -> [Project] {
        var path = "/projects"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: ProjectListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.projects
    }

    /// Get project details
    public func getProject(id: String) async throws -> Project {
        let response: ProjectDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/projects/\(id)",
            expected: 200
        )
        return response.project
    }

    /// Create a project
    public func createProject(request: CreateProjectRequest) async throws -> Project {
        let requestData = try SharedResources.jsonEncoder.encode(["project": request])
        let response: ProjectDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/projects",
            body: requestData,
            expected: 201
        )
        return response.project
    }

    /// Update a project
    public func updateProject(id: String, request: UpdateProjectRequest) async throws -> Project {
        let requestData = try SharedResources.jsonEncoder.encode(["project": request])
        let response: ProjectDetailResponse = try await core.request(
            service: serviceName,
            method: "PATCH",
            path: "/projects/\(id)",
            body: requestData,
            expected: 200
        )
        return response.project
    }

    /// Delete a project
    public func deleteProject(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/projects/\(id)",
            expected: 204
        )
    }

    // MARK: - User Operations

    /// List users
    public func listUsers(domainId: String? = nil, options: PaginationOptions = PaginationOptions()) async throws -> [User] {
        var queryItems = options.queryItems
        if let domainId = domainId {
            queryItems.append(URLQueryItem(name: "domain_id", value: domainId))
        }

        var path = "/users"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: UserListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.users
    }

    /// Get user details
    public func getUser(id: String) async throws -> User {
        let response: UserDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/users/\(id)",
            expected: 200
        )
        return response.user
    }

    /// Create a user
    public func createUser(request: CreateUserRequest) async throws -> User {
        let requestData = try SharedResources.jsonEncoder.encode(["user": request])
        let response: UserDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/users",
            body: requestData,
            expected: 201
        )
        return response.user
    }

    /// Update a user
    public func updateUser(id: String, request: UpdateUserRequest) async throws -> User {
        let requestData = try SharedResources.jsonEncoder.encode(["user": request])
        let response: UserDetailResponse = try await core.request(
            service: serviceName,
            method: "PATCH",
            path: "/users/\(id)",
            body: requestData,
            expected: 200
        )
        return response.user
    }

    /// Delete a user
    public func deleteUser(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/users/\(id)",
            expected: 204
        )
    }

    /// Change user password
    public func changeUserPassword(id: String, request: ChangePasswordRequest) async throws {
        let requestData = try SharedResources.jsonEncoder.encode(["user": request])
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/users/\(id)/password",
            body: requestData,
            expected: 204
        )
    }

    // MARK: - Group Operations

    /// List groups
    public func listGroups(domainId: String? = nil, options: PaginationOptions = PaginationOptions()) async throws -> [Group] {
        var queryItems = options.queryItems
        if let domainId = domainId {
            queryItems.append(URLQueryItem(name: "domain_id", value: domainId))
        }

        var path = "/groups"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: GroupListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.groups
    }

    /// Get group details
    public func getGroup(id: String) async throws -> Group {
        let response: GroupDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/groups/\(id)",
            expected: 200
        )
        return response.group
    }

    /// Create a group
    public func createGroup(request: CreateGroupRequest) async throws -> Group {
        let requestData = try SharedResources.jsonEncoder.encode(["group": request])
        let response: GroupDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/groups",
            body: requestData,
            expected: 201
        )
        return response.group
    }

    /// Update a group
    public func updateGroup(id: String, request: UpdateGroupRequest) async throws -> Group {
        let requestData = try SharedResources.jsonEncoder.encode(["group": request])
        let response: GroupDetailResponse = try await core.request(
            service: serviceName,
            method: "PATCH",
            path: "/groups/\(id)",
            body: requestData,
            expected: 200
        )
        return response.group
    }

    /// Delete a group
    public func deleteGroup(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/groups/\(id)",
            expected: 204
        )
    }

    /// Add user to group
    public func addUserToGroup(userId: String, groupId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/groups/\(groupId)/users/\(userId)",
            expected: 204
        )
    }

    /// Remove user from group
    public func removeUserFromGroup(userId: String, groupId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/groups/\(groupId)/users/\(userId)",
            expected: 204
        )
    }

    /// List users in group
    public func listUsersInGroup(groupId: String) async throws -> [User] {
        let response: UserListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/groups/\(groupId)/users",
            expected: 200
        )
        return response.users
    }

    /// Check if user is in group
    public func checkUserInGroup(userId: String, groupId: String) async throws -> Bool {
        do {
            try await core.requestVoid(
                service: serviceName,
                method: "HEAD",
                path: "/groups/\(groupId)/users/\(userId)",
                expected: 204
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - Role Operations

    /// List roles
    public func listRoles(options: PaginationOptions = PaginationOptions()) async throws -> [Role] {
        var path = "/roles"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: RoleListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.roles
    }

    /// Get role details
    public func getRole(id: String) async throws -> Role {
        let response: RoleDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/roles/\(id)",
            expected: 200
        )
        return response.role
    }

    /// Create a role
    public func createRole(request: CreateRoleRequest) async throws -> Role {
        let requestData = try SharedResources.jsonEncoder.encode(["role": request])
        let response: RoleDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/roles",
            body: requestData,
            expected: 201
        )
        return response.role
    }

    /// Update a role
    public func updateRole(id: String, request: UpdateRoleRequest) async throws -> Role {
        let requestData = try SharedResources.jsonEncoder.encode(["role": request])
        let response: RoleDetailResponse = try await core.request(
            service: serviceName,
            method: "PATCH",
            path: "/roles/\(id)",
            body: requestData,
            expected: 200
        )
        return response.role
    }

    /// Delete a role
    public func deleteRole(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/roles/\(id)",
            expected: 204
        )
    }

    // MARK: - Role Assignment Operations

    /// Grant role to user on project
    public func grantRoleToUserOnProject(userId: String, projectId: String, roleId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/projects/\(projectId)/users/\(userId)/roles/\(roleId)",
            expected: 204
        )
    }

    /// Revoke role from user on project
    public func revokeRoleFromUserOnProject(userId: String, projectId: String, roleId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/projects/\(projectId)/users/\(userId)/roles/\(roleId)",
            expected: 204
        )
    }

    /// Check role assignment for user on project
    public func checkRoleAssignmentForUserOnProject(userId: String, projectId: String, roleId: String) async throws -> Bool {
        do {
            try await core.requestVoid(
                service: serviceName,
                method: "HEAD",
                path: "/projects/\(projectId)/users/\(userId)/roles/\(roleId)",
                expected: 204
            )
            return true
        } catch {
            return false
        }
    }

    /// Grant role to group on project
    public func grantRoleToGroupOnProject(groupId: String, projectId: String, roleId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/projects/\(projectId)/groups/\(groupId)/roles/\(roleId)",
            expected: 204
        )
    }

    /// Revoke role from group on project
    public func revokeRoleFromGroupOnProject(groupId: String, projectId: String, roleId: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/projects/\(projectId)/groups/\(groupId)/roles/\(roleId)",
            expected: 204
        )
    }

    /// List role assignments
    public func listRoleAssignments(userId: String? = nil, groupId: String? = nil, projectId: String? = nil, domainId: String? = nil, roleId: String? = nil, includeNames: Bool = false) async throws -> [RoleAssignment] {
        var queryItems: [URLQueryItem] = []

        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user.id", value: userId))
        }
        if let groupId = groupId {
            queryItems.append(URLQueryItem(name: "group.id", value: groupId))
        }
        if let projectId = projectId {
            queryItems.append(URLQueryItem(name: "scope.project.id", value: projectId))
        }
        if let domainId = domainId {
            queryItems.append(URLQueryItem(name: "scope.domain.id", value: domainId))
        }
        if let roleId = roleId {
            queryItems.append(URLQueryItem(name: "role.id", value: roleId))
        }
        if includeNames {
            queryItems.append(URLQueryItem(name: "include_names", value: "true"))
        }

        var path = "/role_assignments"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: RoleAssignmentListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.roleAssignments
    }

    // MARK: - Domain Operations

    /// List domains
    public func listDomains(options: PaginationOptions = PaginationOptions()) async throws -> [Domain] {
        var path = "/domains"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: DomainListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.domains
    }

    /// Get domain details
    public func getDomain(id: String) async throws -> Domain {
        let response: DomainDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/domains/\(id)",
            expected: 200
        )
        return response.domain
    }

    /// Create a domain
    public func createDomain(request: CreateDomainRequest) async throws -> Domain {
        let requestData = try SharedResources.jsonEncoder.encode(["domain": request])
        let response: DomainDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/domains",
            body: requestData,
            expected: 201
        )
        return response.domain
    }

    /// Update a domain
    public func updateDomain(id: String, request: UpdateDomainRequest) async throws -> Domain {
        let requestData = try SharedResources.jsonEncoder.encode(["domain": request])
        let response: DomainDetailResponse = try await core.request(
            service: serviceName,
            method: "PATCH",
            path: "/domains/\(id)",
            body: requestData,
            expected: 200
        )
        return response.domain
    }

    /// Delete a domain
    public func deleteDomain(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/domains/\(id)",
            expected: 204
        )
    }

    // MARK: - Service Operations

    /// List services
    public func listCatalog(options: PaginationOptions = PaginationOptions()) async throws -> [Service] {
        var path = "/auth/catalog"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: CatalogResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        return response.catalog.map { entry in
            Service(
                id: entry.id ?? UUID().uuidString,
                name: entry.name,
                type: entry.type,
                description: nil,
                enabled: true
            )
        }
    }

    /// List catalog with full endpoint information
    /// - Returns: Array of TokenCatalogEntry containing service and endpoint details
    public func listCatalogWithEndpoints(options: PaginationOptions = PaginationOptions()) async throws -> [TokenCatalogEntry] {
        var path = "/auth/catalog"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: CatalogResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        return response.catalog
    }

    /// Get service details
    public func getService(id: String) async throws -> Service {
        let response: ServiceDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/services/\(id)",
            expected: 200
        )
        return response.service
    }

    /// Create a service
    public func createService(request: CreateServiceRequest) async throws -> Service {
        let requestData = try SharedResources.jsonEncoder.encode(["service": request])
        let response: ServiceDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/services",
            body: requestData,
            expected: 201
        )
        return response.service
    }

    /// Update a service
    public func updateService(id: String, request: UpdateServiceRequest) async throws -> Service {
        let requestData = try SharedResources.jsonEncoder.encode(["service": request])
        let response: ServiceDetailResponse = try await core.request(
            service: serviceName,
            method: "PATCH",
            path: "/services/\(id)",
            body: requestData,
            expected: 200
        )
        return response.service
    }

    /// Delete a service
    public func deleteService(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/services/\(id)",
            expected: 204
        )
    }

    // MARK: - Endpoint Operations

    /// List endpoints
    public func listEndpoints(serviceId: String? = nil, interface: String? = nil, options: PaginationOptions = PaginationOptions()) async throws -> [Endpoint] {
        var queryItems = options.queryItems
        if let serviceId = serviceId {
            queryItems.append(URLQueryItem(name: "service_id", value: serviceId))
        }
        if let interface = interface {
            queryItems.append(URLQueryItem(name: "interface", value: interface))
        }

        var path = "/endpoints"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: EndpointListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.endpoints
    }

    /// Get endpoint details
    public func getEndpoint(id: String) async throws -> Endpoint {
        let response: EndpointDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/endpoints/\(id)",
            expected: 200
        )
        return response.endpoint
    }

    /// Create an endpoint
    public func createEndpoint(request: CreateEndpointRequest) async throws -> Endpoint {
        let requestData = try SharedResources.jsonEncoder.encode(["endpoint": request])
        let response: EndpointDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/endpoints",
            body: requestData,
            expected: 201
        )
        return response.endpoint
    }

    /// Update an endpoint
    public func updateEndpoint(id: String, request: UpdateEndpointRequest) async throws -> Endpoint {
        let requestData = try SharedResources.jsonEncoder.encode(["endpoint": request])
        let response: EndpointDetailResponse = try await core.request(
            service: serviceName,
            method: "PATCH",
            path: "/endpoints/\(id)",
            body: requestData,
            expected: 200
        )
        return response.endpoint
    }

    /// Delete an endpoint
    public func deleteEndpoint(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/endpoints/\(id)",
            expected: 204
        )
    }

    // MARK: - Token Operations

    /// Validate token
    public func validateToken(token: String) async throws -> TokenInfo {
        let response: TokenInfoResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/auth/tokens",
            headers: ["X-Auth-Token": token, "X-Subject-Token": token],
            expected: 200
        )
        return response.token
    }

    /// Revoke token
    public func revokeToken(token: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/auth/tokens",
            headers: ["X-Subject-Token": token],
            expected: 204
        )
    }
}

// MARK: - Response Models

public struct ProjectListResponse: Codable, Sendable {
    public let projects: [Project]
}

public struct ProjectDetailResponse: Codable, Sendable {
    public let project: Project
}

public struct UserListResponse: Codable, Sendable {
    public let users: [User]
}

public struct UserDetailResponse: Codable, Sendable {
    public let user: User
}

public struct GroupListResponse: Codable, Sendable {
    public let groups: [Group]
}

public struct GroupDetailResponse: Codable, Sendable {
    public let group: Group
}

public struct RoleListResponse: Codable, Sendable {
    public let roles: [Role]
}

public struct RoleDetailResponse: Codable, Sendable {
    public let role: Role
}

public struct RoleAssignmentListResponse: Codable, Sendable {
    public let roleAssignments: [RoleAssignment]

    enum CodingKeys: String, CodingKey {
        case roleAssignments = "role_assignments"
    }
}

public struct DomainListResponse: Codable, Sendable {
    public let domains: [Domain]
}

public struct DomainDetailResponse: Codable, Sendable {
    public let domain: Domain
}

public struct ServiceListResponse: Codable, Sendable {
    public let services: [Service]
}

public struct ServiceDetailResponse: Codable, Sendable {
    public let service: Service
}

public struct EndpointListResponse: Codable, Sendable {
    public let endpoints: [Endpoint]
}

public struct EndpointDetailResponse: Codable, Sendable {
    public let endpoint: Endpoint
}

public struct TokenInfoResponse: Codable, Sendable {
    public let token: TokenInfo
}

public struct CatalogResponse: Codable, Sendable {
    public let catalog: [TokenCatalogEntry]
}