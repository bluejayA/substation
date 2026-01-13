import Foundation

// MARK: - Glance (Image) Service

public actor GlanceService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "image"
    private let cacheManager: OpenStackCacheManager
    private let invalidationManager: IntelligentCacheInvalidation
    private let logger: any OpenStackClientLogger

    /// Initialize the Glance service with the given OpenStack core and logger.
    ///
    /// - Parameters:
    ///   - core: The OpenStack client core for API communication
    ///   - logger: Logger instance for service operations
    ///   - cloudName: Optional cloud name for consistent cache filenames across restarts
    public init(core: OpenStackClientCore, logger: any OpenStackClientLogger, cloudName: String? = nil) {
        self.core = core
        self.logger = logger
        self.cacheManager = OpenStackCacheManager(
            maxCacheSize: 2000,
            maxMemoryUsage: 20 * 1024 * 1024, // 20MB for image metadata
            cacheIdentifier: cloudName,
            logger: logger
        )
        self.invalidationManager = IntelligentCacheInvalidation(
            cacheManager: cacheManager,
            logger: logger
        )
    }

    // MARK: - Image Operations

    /// List images with automatic pagination support and intelligent caching
    public func listImages(options: PaginationOptions = PaginationOptions(), forceRefresh: Bool = false) async throws -> [Image] {
        let cacheKey = "glance_image_list_\(options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&"))"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: [Image].self,
                resourceType: .imageList
            ) {
                logger.logInfo("Glance service cache hit - image list", context: [
                    "imageCount": cached.count
                ])
                return cached
            }
        }

        logger.logInfo("Glance service API call - listing images", context: [
            "forceRefresh": forceRefresh
        ])

        var allImages: [Image] = []
        var currentMarker: String? = nil
        var hasMore = true

        while hasMore {
            var queryItems: [URLQueryItem] = []

            if let marker = currentMarker {
                queryItems.append(URLQueryItem(name: "marker", value: marker))
            }

            queryItems.append(contentsOf: options.queryItems)

            var path = "/v2/images"
            if !queryItems.isEmpty {
                let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
                path += "?" + queryString
            }

            let response: ImageListResponse = try await core.request(
                service: serviceName,
                method: "GET",
                path: path,
                expected: 200
            )

            allImages.append(contentsOf: response.images)

            if let nextURLString = response.next,
               let nextURL = URL(string: nextURLString),
               let components = URLComponents(url: nextURL, resolvingAgainstBaseURL: false),
               let markerItem = components.queryItems?.first(where: { $0.name == "marker" }),
               let marker = markerItem.value {
                currentMarker = marker
            } else {
                hasMore = false
            }
        }

        // Cache the image list
        await cacheManager.store(
            allImages,
            forKey: cacheKey,
            resourceType: .imageList
        )

        // Cache individual images
        for image in allImages {
            await cacheManager.store(
                image,
                forKey: "glance_image_\(image.id)",
                resourceType: .image
            )
        }

        return allImages
    }

    /// Get image details with intelligent caching
    public func getImage(id: String, forceRefresh: Bool = false) async throws -> Image {
        let cacheKey = "glance_image_\(id)"

        // Try intelligent caching first
        if !forceRefresh {
            if let cached = await cacheManager.retrieve(
                forKey: cacheKey,
                as: Image.self,
                resourceType: .image
            ) {
                logger.logInfo("Glance service cache hit - image detail", context: [
                    "imageId": id
                ])
                return cached
            }
        }

        logger.logInfo("Glance service API call - getting image", context: [
            "imageId": id,
            "forceRefresh": forceRefresh
        ])

        let response: Image = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2/images/\(id)",
            expected: 200
        )

        // Cache the image
        await cacheManager.store(
            response,
            forKey: cacheKey,
            resourceType: .image
        )

        return response
    }

    /// Create a new image with intelligent cache invalidation
    public func createImage(request: CreateImageRequest) async throws -> Image {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: Image = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2/images",
            body: requestData,
            expected: 201
        )

        // Cache the new image
        await cacheManager.store(
            response,
            forKey: "glance_image_\(response.id)",
            resourceType: .image
        )

        // Invalidate image lists
        await invalidationManager.invalidateForOperation(
            .create,
            resourceType: .image,
            resourceId: response.id
        )

        return response
    }

    /// Update image metadata
    public func updateImage(id: String, request: UpdateImageRequest) async throws -> Image {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: Image = try await core.request(
            service: serviceName,
            method: "PATCH",
            path: "/v2/images/\(id)",
            body: requestData,
            headers: ["Content-Type": "application/openstack-images-v2.1-json-patch"],
            expected: 200
        )
        return response
    }

    /// Delete an image with intelligent cache invalidation
    public func deleteImage(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2/images/\(id)",
            expected: 204
        )

        // Invalidate all related caches
        await invalidationManager.invalidateForOperation(
            .delete,
            resourceType: .image,
            resourceId: id
        )
    }

    /// Upload image data
    public func uploadImageData(id: String, data: Data) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/v2/images/\(id)/file",
            body: data,
            headers: ["Content-Type": "application/octet-stream"],
            expected: 204
        )
    }

    /// Download image data
    public func downloadImageData(id: String) async throws -> Data {
        let response: Data = try await core.requestRaw(
            service: serviceName,
            method: "GET",
            path: "/v2/images/\(id)/file",
            expected: 200
        )
        return response
    }

    /// Add tag to image
    public func addImageTag(id: String, tag: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/v2/images/\(id)/tags/\(tag)",
            expected: 204
        )
    }

    /// Remove tag from image
    public func removeImageTag(id: String, tag: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2/images/\(id)/tags/\(tag)",
            expected: 204
        )
    }

    /// Set image visibility (public, private, shared, community)
    public func setImageVisibility(id: String, visibility: String) async throws -> Image {
        let request = UpdateImageRequest(visibility: visibility)
        return try await updateImage(id: id, request: request)
    }

    /// Protect or unprotect image from deletion
    public func setImageProtection(id: String, protected: Bool) async throws -> Image {
        let request = UpdateImageRequest(protected: protected)
        return try await updateImage(id: id, request: request)
    }
}