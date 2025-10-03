import Foundation

// MARK: - Image Models

public struct Image: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let id: String
    public let name: String?
    public let status: String?
    public let progress: Int?
    public let minRam: Int?
    public let minDisk: Int?
    public let visibility: String?
    public let size: Int?
    public let virtualSize: Int?
    public let diskFormat: String?
    public let containerFormat: String?
    public let checksum: String?
    public let owner: String?
    public let isPublic: Bool?
    public let protected: Bool?
    public let tags: [String]?
    public let properties: [String: String]?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let metadata: [String: String]?
    public let server: ServerRef?
    public let links: [Link]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case progress
        case minRam = "minRam"
        case minDisk = "minDisk"
        case visibility
        case size
        case virtualSize = "virtual_size"
        case diskFormat = "disk_format"
        case containerFormat = "container_format"
        case checksum
        case owner
        case isPublic = "is_public"
        case protected
        case tags
        case properties
        case createdAt = "created"
        case updatedAt = "updated"
        case metadata
        case server
        case links
    }

    public init(
        id: String,
        name: String? = nil,
        status: String? = nil,
        progress: Int? = nil,
        minRam: Int? = nil,
        minDisk: Int? = nil,
        visibility: String? = nil,
        size: Int? = nil,
        virtualSize: Int? = nil,
        diskFormat: String? = nil,
        containerFormat: String? = nil,
        checksum: String? = nil,
        owner: String? = nil,
        isPublic: Bool? = nil,
        protected: Bool? = nil,
        tags: [String]? = nil,
        properties: [String: String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        metadata: [String: String]? = nil,
        server: ServerRef? = nil,
        links: [Link]? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.progress = progress
        self.minRam = minRam
        self.minDisk = minDisk
        self.visibility = visibility
        self.size = size
        self.virtualSize = virtualSize
        self.diskFormat = diskFormat
        self.containerFormat = containerFormat
        self.checksum = checksum
        self.owner = owner
        self.isPublic = isPublic
        self.protected = protected
        self.tags = tags
        self.properties = properties
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.server = server
        self.links = links
    }

    // MARK: - Computed Properties

    public var isActive: Bool {
        return status?.lowercased() == "active"
    }

    public var displayName: String {
        return name ?? id
    }

    public var operatingSystem: String? {
        return metadata?["os_type"] ?? metadata?["os_distro"]
    }

    public var architecture: String? {
        return metadata?["architecture"]
    }
}

// MARK: - Supporting Types

public struct ServerRef: Codable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

// MARK: - Glance-specific Request Models

public struct CreateImageRequest: Codable, Sendable {
    public let name: String
    public let visibility: String?
    public let diskFormat: String?
    public let containerFormat: String?
    public let minDisk: Int?
    public let minRam: Int?
    public let protected: Bool?
    public let tags: [String]?
    public let properties: [String: String]?

    enum CodingKeys: String, CodingKey {
        case name
        case visibility
        case diskFormat = "disk_format"
        case containerFormat = "container_format"
        case minDisk = "min_disk"
        case minRam = "min_ram"
        case protected
        case tags
        case properties
    }

    public init(
        name: String,
        visibility: String? = "private",
        diskFormat: String? = "qcow2",
        containerFormat: String? = "bare",
        minDisk: Int? = 0,
        minRam: Int? = 0,
        protected: Bool? = false,
        tags: [String]? = nil,
        properties: [String: String]? = nil
    ) {
        self.name = name
        self.visibility = visibility
        self.diskFormat = diskFormat
        self.containerFormat = containerFormat
        self.minDisk = minDisk
        self.minRam = minRam
        self.protected = protected
        self.tags = tags
        self.properties = properties
    }
}

public struct UpdateImageRequest: Codable, Sendable {
    public let name: String?
    public let visibility: String?
    public let minDisk: Int?
    public let minRam: Int?
    public let protected: Bool?
    public let tags: [String]?
    public let properties: [String: String]?

    enum CodingKeys: String, CodingKey {
        case name
        case visibility
        case minDisk = "min_disk"
        case minRam = "min_ram"
        case protected
        case tags
        case properties
    }

    public init(
        name: String? = nil,
        visibility: String? = nil,
        minDisk: Int? = nil,
        minRam: Int? = nil,
        protected: Bool? = nil,
        tags: [String]? = nil,
        properties: [String: String]? = nil
    ) {
        self.name = name
        self.visibility = visibility
        self.minDisk = minDisk
        self.minRam = minRam
        self.protected = protected
        self.tags = tags
        self.properties = properties
    }
}

// MARK: - Glance Response Models

public struct ImageListResponse: Codable, Sendable {
    public let images: [Image]
    public let first: String?
    public let next: String?
    public let schema: String?

    public init(images: [Image], first: String? = nil, next: String? = nil, schema: String? = nil) {
        self.images = images
        self.first = first
        self.next = next
        self.schema = schema
    }
}

public struct ImageDetailResponse: Codable, Sendable {
    public let image: Image

    public init(image: Image) {
        self.image = image
    }
}

// MARK: - Image Action Models

public struct CreateNovaImageAction: Codable, Sendable {
    public let createImage: ImageNovaCreateRequest

    public init(name: String, metadata: [String: String]? = nil) {
        self.createImage = ImageNovaCreateRequest(name: name, metadata: metadata)
    }

    enum CodingKeys: String, CodingKey {
        case createImage = "createImage"
    }
}

public struct ImageNovaCreateRequest: Codable, Sendable {
    public let name: String
    public let metadata: [String: String]

    public init(name: String, metadata: [String: String]? = nil) {
        self.name = name
        self.metadata = metadata ?? [:]
    }
}