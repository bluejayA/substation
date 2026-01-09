import Foundation

// MARK: - Magnum (Container Infrastructure) Service

/// Service actor for OpenStack Magnum (Container Infrastructure Management) API
///
/// Provides methods for managing container orchestration clusters, templates,
/// and nodegroups through the Magnum API.
public actor MagnumService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "container-infra"

    public init(core: OpenStackClientCore) {
        self.core = core
    }

    // MARK: - Cluster Operations

    /// List all clusters in the project
    ///
    /// - Returns: Array of Cluster objects
    /// - Throws: OpenStackError if the API request fails
    public func listClusters() async throws -> [Cluster] {
        let response: ClusterListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clusters",
            expected: 200
        )
        return response.clusters
    }

    /// Get details for a specific cluster
    ///
    /// - Parameter id: The cluster UUID or name
    /// - Returns: The Cluster object
    /// - Throws: OpenStackError if the API request fails
    public func getCluster(id: String) async throws -> Cluster {
        let response: Cluster = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clusters/\(id)",
            expected: 200
        )
        return response
    }

    /// Delete a cluster
    ///
    /// - Parameter id: The cluster UUID or name
    /// - Throws: OpenStackError if the API request fails
    public func deleteCluster(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/clusters/\(id)",
            expected: 204
        )
    }

    // MARK: - Cluster Template Operations

    /// List all cluster templates
    ///
    /// - Returns: Array of ClusterTemplate objects
    /// - Throws: OpenStackError if the API request fails
    public func listClusterTemplates() async throws -> [ClusterTemplate] {
        let response: ClusterTemplateListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clustertemplates",
            expected: 200
        )
        return response.clustertemplates
    }

    /// Get details for a specific cluster template
    ///
    /// - Parameter id: The cluster template UUID or name
    /// - Returns: The ClusterTemplate object
    /// - Throws: OpenStackError if the API request fails
    public func getClusterTemplate(id: String) async throws -> ClusterTemplate {
        let response: ClusterTemplate = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clustertemplates/\(id)",
            expected: 200
        )
        return response
    }

    /// Create a new cluster template
    ///
    /// - Parameter request: The cluster template creation request
    /// - Returns: The created ClusterTemplate object
    /// - Throws: OpenStackError if the API request fails
    public func createClusterTemplate(request: ClusterTemplateCreateRequest) async throws -> ClusterTemplate {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: ClusterTemplate = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/clustertemplates",
            body: requestData,
            expected: 201
        )
        return response
    }

    /// Delete a cluster template
    ///
    /// - Parameter id: The cluster template UUID or name
    /// - Throws: OpenStackError if the API request fails
    public func deleteClusterTemplate(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/clustertemplates/\(id)",
            expected: 204
        )
    }

    // MARK: - Nodegroup Operations

    /// List all nodegroups for a cluster
    ///
    /// - Parameter clusterId: The parent cluster UUID or name
    /// - Returns: Array of Nodegroup objects
    /// - Throws: OpenStackError if the API request fails
    public func listNodegroups(clusterId: String) async throws -> [Nodegroup] {
        let response: NodegroupListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clusters/\(clusterId)/nodegroups",
            expected: 200
        )
        return response.nodegroups
    }

    /// Get details for a specific nodegroup
    ///
    /// - Parameters:
    ///   - clusterId: The parent cluster UUID or name
    ///   - nodegroupId: The nodegroup UUID or name
    /// - Returns: The Nodegroup object
    /// - Throws: OpenStackError if the API request fails
    public func getNodegroup(clusterId: String, nodegroupId: String) async throws -> Nodegroup {
        let response: Nodegroup = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clusters/\(clusterId)/nodegroups/\(nodegroupId)",
            expected: 200
        )
        return response
    }

    // MARK: - Cluster Actions

    /// Get the kubeconfig for a cluster
    ///
    /// - Parameter id: The cluster UUID or name
    /// - Returns: The kubeconfig content as a string
    /// - Throws: OpenStackError if the API request fails
    public func getClusterConfig(id: String) async throws -> String {
        let response: Data = try await core.requestRaw(
            service: serviceName,
            method: "GET",
            path: "/clusters/\(id)/config",
            expected: 200
        )
        guard let config = String(data: response, encoding: .utf8) else {
            throw OpenStackError.configurationError("Failed to decode cluster config as UTF-8")
        }
        return config
    }

    /// Create a new cluster
    ///
    /// - Parameter request: The cluster creation request
    /// - Returns: The cluster creation response with UUID
    /// - Throws: OpenStackError if the API request fails
    public func createCluster(request: ClusterCreateRequest) async throws -> ClusterCreateResponse {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: ClusterCreateResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/clusters",
            body: requestData,
            expected: 202
        )
        return response
    }

    /// Resize a cluster (scale worker nodes)
    ///
    /// - Parameters:
    ///   - id: The cluster UUID or name
    ///   - nodeCount: The new number of worker nodes
    /// - Returns: The updated Cluster object
    /// - Throws: OpenStackError if the API request fails
    public func resizeCluster(id: String, nodeCount: Int) async throws -> Cluster {
        let request = ClusterResizeRequest(nodeCount: nodeCount)
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: Cluster = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/clusters/\(id)/actions/resize",
            body: requestData,
            expected: 202
        )
        return response
    }

    /// Upgrade a cluster to a new version
    ///
    /// - Parameters:
    ///   - id: The cluster UUID or name
    ///   - clusterTemplateId: The new cluster template UUID
    /// - Returns: The updated Cluster object
    /// - Throws: OpenStackError if the API request fails
    public func upgradeCluster(id: String, clusterTemplateId: String) async throws -> Cluster {
        let request = ClusterUpgradeRequest(clusterTemplate: clusterTemplateId)
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: Cluster = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/clusters/\(id)/actions/upgrade",
            body: requestData,
            expected: 202
        )
        return response
    }
}
