import Foundation

// MARK: - Swift (Object Storage) Service

public actor SwiftService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "object-store"

    private let maxConcurrentOperations = 5
    private let largeObjectThreshold = 5 * 1024 * 1024 * 1024 // 5GB
    private let segmentSize = 1024 * 1024 * 1024 // 1GB segments

    public init(core: OpenStackClientCore) {
        self.core = core
    }

    // MARK: - Container Operations

    /// List all containers in the account
    public func listContainers(limit: Int? = nil, marker: String? = nil, prefix: String? = nil) async throws -> [SwiftContainer] {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "format", value: "json")]

        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let marker = marker {
            queryItems.append(URLQueryItem(name: "marker", value: marker))
        }
        if let prefix = prefix {
            queryItems.append(URLQueryItem(name: "prefix", value: prefix))
        }

        let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        let path = queryString.isEmpty ? "/" : "/?\(queryString)"

        let response: [SwiftContainer] = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        return response
    }

    /// Get container metadata
    public func getContainerMetadata(containerName: String) async throws -> SwiftContainerMetadataResponse {
        let encodedContainer = containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName
        let path = "/\(encodedContainer)"

        let (_, headers) = try await core.requestWithHeaders(
            service: serviceName,
            method: "HEAD",
            path: path,
            expected: 204
        )

        // Extract metadata from headers
        var metadata: [String: String] = [:]
        var objectCount = 0
        var bytesUsed = 0
        var readACL: String? = nil
        var writeACL: String? = nil

        for (key, value) in headers {
            let lowerKey = key.lowercased()
            if lowerKey.hasPrefix("x-container-meta-") {
                let metaKey = String(key.dropFirst("X-Container-Meta-".count))
                metadata[metaKey] = value
            } else if lowerKey == "x-container-object-count" {
                objectCount = Int(value) ?? 0
            } else if lowerKey == "x-container-bytes-used" {
                bytesUsed = Int(value) ?? 0
            } else if lowerKey == "x-container-read" {
                readACL = value
            } else if lowerKey == "x-container-write" {
                writeACL = value
            }
        }

        return SwiftContainerMetadataResponse(
            containerName: containerName,
            objectCount: objectCount,
            bytesUsed: bytesUsed,
            metadata: metadata,
            readACL: readACL,
            writeACL: writeACL
        )
    }

    /// Create a container
    public func createContainer(request: CreateSwiftContainerRequest) async throws {
        var headers: [String: String] = [:]

        // Add metadata headers
        for (key, value) in request.metadata {
            headers["X-Container-Meta-\(key)"] = value
        }

        if let readACL = request.readACL {
            headers["X-Container-Read"] = readACL
        }
        if let writeACL = request.writeACL {
            headers["X-Container-Write"] = writeACL
        }

        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: "/\(request.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.name)",
            headers: headers,
            expected: 201
        )
    }

    /// Update container metadata
    public func updateContainerMetadata(containerName: String, request: UpdateSwiftContainerMetadataRequest) async throws {
        var headers: [String: String] = [:]

        // Add new/updated metadata
        for (key, value) in request.metadata {
            headers["X-Container-Meta-\(key)"] = value
        }

        // Remove metadata by setting empty value
        for key in request.removeMetadataKeys {
            headers["X-Remove-Container-Meta-\(key)"] = "x"
        }

        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/\(containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName)",
            headers: headers,
            expected: 204
        )
    }

    /// Delete a container (must be empty)
    public func deleteContainer(containerName: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/\(containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName)",
            expected: 204
        )
    }

    // MARK: - Object Operations

    /// List objects in a container
    public func listObjects(containerName: String, limit: Int? = nil, marker: String? = nil, prefix: String? = nil, delimiter: String? = nil) async throws -> [SwiftObject] {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "format", value: "json")]

        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let marker = marker {
            queryItems.append(URLQueryItem(name: "marker", value: marker))
        }
        if let prefix = prefix {
            queryItems.append(URLQueryItem(name: "prefix", value: prefix))
        }
        if let delimiter = delimiter {
            queryItems.append(URLQueryItem(name: "delimiter", value: delimiter))
        }

        let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        let path = "/\(containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName)?\(queryString)"

        let response: [SwiftObject] = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )

        return response
    }

    /// Get object metadata
    public func getObjectMetadata(containerName: String, objectName: String) async throws -> SwiftObjectMetadataResponse {
        let encodedContainer = containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName
        let encodedObject = objectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectName
        let path = "/\(encodedContainer)/\(encodedObject)"

        let (_, headers) = try await core.requestWithHeaders(
            service: serviceName,
            method: "HEAD",
            path: path,
            expected: 200
        )

        // Extract metadata from headers
        var metadata: [String: String] = [:]
        var contentLength = 0
        var contentType: String? = nil
        var etag: String? = nil
        var lastModified: Date? = nil

        for (key, value) in headers {
            let lowerKey = key.lowercased()
            if lowerKey.hasPrefix("x-object-meta-") {
                let metaKey = String(key.dropFirst("X-Object-Meta-".count))
                metadata[metaKey] = value
            } else if lowerKey == "content-length" {
                contentLength = Int(value) ?? 0
            } else if lowerKey == "content-type" {
                contentType = value
            } else if lowerKey == "etag" {
                etag = value
            } else if lowerKey == "last-modified" {
                // Parse HTTP date format
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                lastModified = dateFormatter.date(from: value)
            }
        }

        return SwiftObjectMetadataResponse(
            objectName: objectName,
            contentLength: contentLength,
            contentType: contentType,
            etag: etag,
            lastModified: lastModified,
            metadata: metadata
        )
    }

    /// Upload an object to a container
    public func uploadObject(request: UploadSwiftObjectRequest) async throws {
        let encodedContainer = request.containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.containerName
        let encodedObject = request.objectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.objectName
        let path = "/\(encodedContainer)/\(encodedObject)"

        var headers: [String: String] = [:]

        if let contentType = request.contentType {
            headers["Content-Type"] = contentType
        }

        // Add metadata headers
        for (key, value) in request.metadata {
            headers["X-Object-Meta-\(key)"] = value
        }

        if let deleteAfter = request.deleteAfter {
            headers["X-Delete-After"] = String(deleteAfter)
        }

        if let deleteAt = request.deleteAt {
            headers["X-Delete-At"] = String(Int(deleteAt.timeIntervalSince1970))
        }

        // For large objects, use segmented upload
        if request.data.count > largeObjectThreshold {
            try await uploadLargeObject(
                containerName: request.containerName,
                objectName: request.objectName,
                data: request.data,
                contentType: request.contentType,
                metadata: request.metadata
            )
        } else {
            // Standard upload for smaller objects
            try await core.requestVoid(
                service: serviceName,
                method: "PUT",
                path: path,
                body: request.data,
                headers: headers,
                expected: 201
            )
        }
    }

    /// Download an object from a container
    public func downloadObject(containerName: String, objectName: String) async throws -> Data {
        let encodedContainer = containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName
        let encodedObject = objectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectName
        let path = "/\(encodedContainer)/\(encodedObject)"

        let responseData = try await core.requestRaw(
            service: serviceName,
            method: "GET",
            path: path,
            headers: [:],
            expected: 200
        )

        return responseData
    }

    /// Copy an object
    public func copyObject(request: CopySwiftObjectRequest) async throws {
        let encodedDestContainer = request.destinationContainer.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.destinationContainer
        let encodedDestObject = request.destinationObject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.destinationObject
        let path = "/\(encodedDestContainer)/\(encodedDestObject)"

        let sourceHeader = "/\(request.sourceContainer)/\(request.sourceObject)"
        var headers: [String: String] = [
            "X-Copy-From": sourceHeader
        ]

        // Add metadata if provided
        if !request.metadata.isEmpty {
            for (key, value) in request.metadata {
                headers["X-Object-Meta-\(key)"] = value
            }
        }

        if request.freshMetadata {
            headers["X-Fresh-Metadata"] = "true"
        }

        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: path,
            headers: headers,
            expected: 201
        )
    }

    /// Update object metadata
    public func updateObjectMetadata(containerName: String, objectName: String, request: UpdateSwiftObjectMetadataRequest) async throws {
        let encodedContainer = containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName
        let encodedObject = objectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectName
        let path = "/\(encodedContainer)/\(encodedObject)"

        var headers: [String: String] = [:]

        // Add new/updated metadata
        for (key, value) in request.metadata {
            headers["X-Object-Meta-\(key)"] = value
        }

        // Remove metadata
        for key in request.removeMetadataKeys {
            headers["X-Remove-Object-Meta-\(key)"] = "x"
        }

        if let contentType = request.contentType {
            headers["Content-Type"] = contentType
        }

        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: path,
            headers: headers,
            expected: 202
        )
    }

    /// Delete an object
    public func deleteObject(containerName: String, objectName: String) async throws {
        let encodedContainer = containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName
        let encodedObject = objectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectName
        let path = "/\(encodedContainer)/\(encodedObject)"

        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: path,
            expected: 204
        )
    }

    // MARK: - Bulk Operations

    /// Bulk delete objects
    public func bulkDelete(request: BulkDeleteRequest) async throws -> BulkDeleteResponse {
        var deletePaths: [String] = []

        if let containerName = request.containerName {
            // Delete specific objects in container
            for objectName in request.objectNames {
                deletePaths.append("/\(containerName)/\(objectName)")
            }
        } else {
            // Assume object names contain full paths
            deletePaths = request.objectNames
        }

        let deleteBody = deletePaths.joined(separator: "\n")
        let bodyData = deleteBody.data(using: .utf8) ?? Data()

        let headers = [
            "Content-Type": "text/plain"
        ]

        let responseData = try await core.requestRaw(
            service: serviceName,
            method: "POST",
            path: "/?bulk-delete",
            body: bodyData,
            headers: headers,
            expected: 200
        )

        // Parse bulk delete response
        let bulkResponse: BulkDeleteResponse = try SharedResources.jsonDecoder.decode(
            BulkDeleteResponse.self,
            from: responseData
        )

        return bulkResponse
    }

    /// Bulk upload objects with multiprocessing support
    public func bulkUpload(
        containerName: String,
        objects: [(name: String, data: Data, contentType: String?)],
        progressCallback: ((Int, Int) -> Void)? = nil
    ) async throws -> BulkUploadResult {
        var successCount = 0
        var failureCount = 0
        var errors: [BulkUploadError] = []

        // Process uploads with concurrency limit
        await withTaskGroup(of: (String, Result<Void, any Error>).self) { group in
            var activeTaskCount = 0
            var pendingObjects = objects

            while !pendingObjects.isEmpty || activeTaskCount > 0 {
                // Add tasks up to concurrency limit
                while activeTaskCount < maxConcurrentOperations && !pendingObjects.isEmpty {
                    let object = pendingObjects.removeFirst()
                    activeTaskCount += 1

                    group.addTask {
                        let uploadRequest = UploadSwiftObjectRequest(
                            containerName: containerName,
                            objectName: object.name,
                            data: object.data,
                            contentType: object.contentType
                        )

                        do {
                            try await self.uploadObject(request: uploadRequest)
                            return (object.name, .success(()))
                        } catch {
                            return (object.name, .failure(error))
                        }
                    }
                }

                // Wait for next task to complete
                if let result = await group.next() {
                    activeTaskCount -= 1
                    let (objectName, uploadResult) = result

                    switch uploadResult {
                    case .success:
                        successCount += 1
                    case .failure(let error):
                        failureCount += 1
                        errors.append(BulkUploadError(
                            objectName: objectName,
                            error: error.localizedDescription
                        ))
                    }

                    progressCallback?(successCount + failureCount, objects.count)
                }
            }
        }

        return BulkUploadResult(
            successCount: successCount,
            failureCount: failureCount,
            totalCount: objects.count,
            errors: errors
        )
    }

    // MARK: - Account Operations

    /// Get account information
    public func getAccountInfo() async throws -> SwiftAccountInfo {
        let (_, headers) = try await core.requestWithHeaders(
            service: serviceName,
            method: "HEAD",
            path: "/",
            expected: 204
        )

        // Extract account info from headers
        var metadata: [String: String] = [:]
        var containerCount = 0
        var objectCount = 0
        var bytesUsed = 0

        for (key, value) in headers {
            let lowerKey = key.lowercased()
            if lowerKey.hasPrefix("x-account-meta-") {
                let metaKey = String(key.dropFirst("X-Account-Meta-".count))
                metadata[metaKey] = value
            } else if lowerKey == "x-account-container-count" {
                containerCount = Int(value) ?? 0
            } else if lowerKey == "x-account-object-count" {
                objectCount = Int(value) ?? 0
            } else if lowerKey == "x-account-bytes-used" {
                bytesUsed = Int(value) ?? 0
            }
        }

        return SwiftAccountInfo(
            containerCount: containerCount,
            objectCount: objectCount,
            bytesUsed: bytesUsed,
            metadata: metadata
        )
    }

    // MARK: - Large Object Support

    /// Upload a large object using segmented upload (Dynamic Large Object)
    private func uploadLargeObject(
        containerName: String,
        objectName: String,
        data: Data,
        contentType: String?,
        metadata: [String: String]
    ) async throws {
        // Create segments container if it doesn't exist
        let segmentsContainer = "\(containerName)_segments"
        do {
            try await createContainer(
                request: CreateSwiftContainerRequest(name: segmentsContainer)
            )
        } catch {
            // Container may already exist, continue
        }

        // Calculate number of segments
        let segmentCount = (data.count + segmentSize - 1) / segmentSize

        // Upload segments concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for segmentIndex in 0..<segmentCount {
                group.addTask {
                    let startOffset = segmentIndex * self.segmentSize
                    let endOffset = min(startOffset + self.segmentSize, data.count)
                    let segmentData = data.subdata(in: startOffset..<endOffset)

                    let segmentName = String(format: "\(objectName)/%08d", segmentIndex)
                    let segmentRequest = UploadSwiftObjectRequest(
                        containerName: segmentsContainer,
                        objectName: segmentName,
                        data: segmentData,
                        contentType: "application/octet-stream"
                    )

                    try await self.uploadObject(request: segmentRequest)
                }
            }

            try await group.waitForAll()
        }

        // Create manifest object
        let manifestPath = "/\(segmentsContainer)/\(objectName)/"
        var headers: [String: String] = [
            "X-Object-Manifest": manifestPath
        ]

        if let contentType = contentType {
            headers["Content-Type"] = contentType
        }

        for (key, value) in metadata {
            headers["X-Object-Meta-\(key)"] = value
        }

        let encodedContainer = containerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? containerName
        let encodedObject = objectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectName
        let path = "/\(encodedContainer)/\(encodedObject)"

        try await core.requestVoid(
            service: serviceName,
            method: "PUT",
            path: path,
            body: Data(),
            headers: headers,
            expected: 201
        )
    }

    // MARK: - Helper Methods
    // Note: Helper methods for header extraction will be implemented
    // once OpenStackClientCore supports requestWithHeaders method

    // MARK: - Batch Operations Support

    /// Batch create containers
    public func batchCreateContainers(
        requests: [CreateSwiftContainerRequest],
        progressCallback: ((Int, Int) -> Void)? = nil
    ) async throws -> (successCount: Int, failureCount: Int, errors: [(String, any Error)]) {
        var successCount = 0
        var failureCount = 0
        var errors: [(String, any Error)] = []

        for (index, request) in requests.enumerated() {
            do {
                try await createContainer(request: request)
                successCount += 1
            } catch {
                failureCount += 1
                errors.append((request.name, error))
            }

            progressCallback?(index + 1, requests.count)
        }

        return (successCount, failureCount, errors)
    }

    /// Batch delete containers
    public func batchDeleteContainers(
        containerNames: [String],
        progressCallback: ((Int, Int) -> Void)? = nil
    ) async throws -> (successCount: Int, failureCount: Int, errors: [(String, any Error)]) {
        var successCount = 0
        var failureCount = 0
        var errors: [(String, any Error)] = []

        for (index, containerName) in containerNames.enumerated() {
            do {
                try await deleteContainer(containerName: containerName)
                successCount += 1
            } catch {
                failureCount += 1
                errors.append((containerName, error))
            }

            progressCallback?(index + 1, containerNames.count)
        }

        return (successCount, failureCount, errors)
    }

    /// Batch download objects
    public func batchDownload(
        containerName: String,
        objectNames: [String],
        progressCallback: ((Int, Int) -> Void)? = nil
    ) async throws -> [(name: String, data: Data?, error: (any Error)?)] {
        var results: [(name: String, data: Data?, error: (any Error)?)] = []

        await withTaskGroup(of: (String, Data?, (any Error)?).self) { group in
            var activeTaskCount = 0
            var pendingObjects = objectNames

            while !pendingObjects.isEmpty || activeTaskCount > 0 {
                while activeTaskCount < maxConcurrentOperations && !pendingObjects.isEmpty {
                    let objectName = pendingObjects.removeFirst()
                    activeTaskCount += 1

                    group.addTask {
                        do {
                            let data = try await self.downloadObject(
                                containerName: containerName,
                                objectName: objectName
                            )
                            return (objectName, data, nil)
                        } catch {
                            return (objectName, nil, error)
                        }
                    }
                }

                if let result = await group.next() {
                    activeTaskCount -= 1
                    results.append(result)
                    progressCallback?(results.count, objectNames.count)
                }
            }
        }

        return results
    }
}
