import Foundation

// MARK: - Glance (Image) Service

public actor GlanceService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "image"

    public init(core: OpenStackClientCore) {
        self.core = core
    }

    // MARK: - Image Operations

    /// List images with automatic pagination support
    public func listImages(options: PaginationOptions = PaginationOptions()) async throws -> [Image] {
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

        return allImages
    }

    /// Get image details
    public func getImage(id: String) async throws -> Image {
        let response: Image = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/v2/images/\(id)",
            expected: 200
        )
        return response
    }

    /// Create a new image
    public func createImage(request: CreateImageRequest) async throws -> Image {
        let requestData = try SharedResources.jsonEncoder.encode(request)
        let response: Image = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/v2/images",
            body: requestData,
            expected: 201
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

    /// Delete an image
    public func deleteImage(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/v2/images/\(id)",
            expected: 204
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