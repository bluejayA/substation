import Foundation

// MARK: - Magnum (Container Infrastructure) Service

/// Service actor for OpenStack Magnum (Container Infrastructure Management) API
///
/// Provides methods for managing container orchestration clusters, templates,
/// and nodegroups through the Magnum API.
public actor MagnumService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "container-infra"
    private let cacheManager: OpenStackCacheManager
    private let invalidationManager: IntelligentCacheInvalidation
    private let logger: any OpenStackClientLogger

    /// Initialize the Magnum service with the given OpenStack core and logger.
    ///
    /// - Parameters:
    ///   - core: The OpenStack client core for API communication
    ///   - logger: Logger instance for service operations
    ///   - cloudName: Optional cloud name for consistent cache filenames across restarts
    public init(core: OpenStackClientCore, logger: any OpenStackClientLogger, cloudName: String? = nil) {
        self.core = core
        self.logger = logger
        self.cacheManager = OpenStackCacheManager(
            maxCacheSize: 1500,
            maxMemoryUsage: 15 * 1024 * 1024, // 15MB for container infrastructure
            cacheIdentifier: cloudName,
            logger: logger
        )
        self.invalidationManager = IntelligentCacheInvalidation(
            cacheManager: cacheManager,
            logger: logger
        )
    }

    // MARK: - Cluster Operations

    /// List all clusters in the project with intelligent caching
    ///
    /// - Parameters:
    ///   - forceRefresh: Force refresh from API, bypassing cache
    /// - Returns: Array of Cluster objects
    /// - Throws: OpenStackError if the API request fails
    public func listClusters(forceRefresh: Bool = false) async throws -> [Cluster] {
        let cacheKey = "magnum_cluster_list"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [Cluster].self,
                resourceType: .clusterList
            ) {
                logger.logInfo("Magnum service cache hit - cluster list", context: [
                    "clusterCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Magnum service API call - listing clusters", context: [
            "forceRefresh": forceRefresh
        ])

        let response: ClusterListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clusters",
            expected: 200
        )

        // Cache the cluster list
        await cacheManager.store(
            response.clusters,
            forKey: cacheKey,
            resourceType: .clusterList
        )

        // Cache individual clusters
        for cluster in response.clusters {
            await cacheManager.store(
                cluster,
                forKey: "magnum_cluster_\(cluster.uuid)",
                resourceType: .cluster
            )
        }

        return response.clusters
    }

    /// Get details for a specific cluster with intelligent caching
    ///
    /// - Parameters:
    ///   - id: The cluster UUID or name
    ///   - forceRefresh: Force refresh from API, bypassing cache
    /// - Returns: The Cluster object
    /// - Throws: OpenStackError if the API request fails
    public func getCluster(id: String, forceRefresh: Bool = false) async throws -> Cluster {
        let cacheKey = "magnum_cluster_\(id)"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: Cluster.self,
                resourceType: .cluster
            ) {
                logger.logInfo("Magnum service cache hit - cluster detail", context: [
                    "clusterId": id
                ])
                return cached
            }
        }

        logger.logInfo("Magnum service API call - getting cluster", context: [
            "clusterId": id,
            "forceRefresh": forceRefresh
        ])

        let response: Cluster = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clusters/\(id)",
            expected: 200
        )

        // Cache the cluster
        await cacheManager.store(
            response,
            forKey: cacheKey,
            resourceType: .cluster
        )

        return response
    }

    /// Delete a cluster with intelligent cache invalidation
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

        // Invalidate all related caches
        await invalidationManager.invalidateForOperation(
            .delete,
            resourceType: .cluster,
            resourceId: id
        )
    }

    // MARK: - Cluster Template Operations

    /// List all cluster templates with intelligent caching
    ///
    /// - Parameter forceRefresh: Force refresh from API, bypassing cache
    /// - Returns: Array of ClusterTemplate objects
    /// - Throws: OpenStackError if the API request fails
    public func listClusterTemplates(forceRefresh: Bool = false) async throws -> [ClusterTemplate] {
        let cacheKey = "magnum_cluster_template_list"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [ClusterTemplate].self,
                resourceType: .clusterTemplateList
            ) {
                logger.logInfo("Magnum service cache hit - cluster template list", context: [
                    "templateCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Magnum service API call - listing cluster templates", context: [
            "forceRefresh": forceRefresh
        ])

        let response: ClusterTemplateListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clustertemplates",
            expected: 200
        )

        // Cache the cluster template list
        await cacheManager.store(
            response.clustertemplates,
            forKey: cacheKey,
            resourceType: .clusterTemplateList
        )

        return response.clustertemplates
    }

    /// Get details for a specific cluster template with intelligent caching
    ///
    /// - Parameters:
    ///   - id: The cluster template UUID or name
    ///   - forceRefresh: Force refresh from API, bypassing cache
    /// - Returns: The ClusterTemplate object
    /// - Throws: OpenStackError if the API request fails
    public func getClusterTemplate(id: String, forceRefresh: Bool = false) async throws -> ClusterTemplate {
        let cacheKey = "magnum_cluster_template_\(id)"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: ClusterTemplate.self,
                resourceType: .clusterTemplate
            ) {
                logger.logInfo("Magnum service cache hit - cluster template detail", context: [
                    "templateId": id
                ])
                return cached
            }
        }

        logger.logInfo("Magnum service API call - getting cluster template", context: [
            "templateId": id,
            "forceRefresh": forceRefresh
        ])

        let response: ClusterTemplate = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/clustertemplates/\(id)",
            expected: 200
        )

        // Cache the cluster template
        await cacheManager.store(
            response,
            forKey: cacheKey,
            resourceType: .clusterTemplate
        )

        return response
    }

    /// Create a new cluster template with intelligent cache invalidation
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

        // Cache the new cluster template
        await cacheManager.store(
            response,
            forKey: "magnum_cluster_template_\(response.uuid)",
            resourceType: .clusterTemplate
        )

        // Invalidate cluster template lists
        await invalidationManager.invalidateForOperation(
            .create,
            resourceType: .clusterTemplate,
            resourceId: response.uuid
        )

        return response
    }

    /// Delete a cluster template with intelligent cache invalidation
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

        // Invalidate all related caches
        await invalidationManager.invalidateForOperation(
            .delete,
            resourceType: .clusterTemplate,
            resourceId: id
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
