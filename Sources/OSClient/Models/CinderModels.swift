import Foundation

// MARK: - Volume Models

public struct Volume: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let id: String
    public let name: String?
    public let description: String?
    public let size: Int?
    public let status: String?
    public let volumeType: String?
    public let bootable: String?
    public let encrypted: Bool?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let availabilityZone: String?
    public let attachments: [VolumeAttachment]?
    public let metadata: [String: String]?
    public let sourceVolid: String?
    public let snapshotId: String?
    public let imageId: String?
    public let hostAttr: String?
    public let projectId: String?
    public let userId: String?
    public let multiattach: Bool?
    public let replicationStatus: String?
    public let migrationStatus: String?
    public let consistencygroupId: String?
    public let groupId: String?
    public let providerId: String?
    public let serviceUuid: String?
    public let sharedTargets: Bool?
    public let clusterName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case size
        case status
        case volumeType = "volume_type"
        case bootable
        case encrypted
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case availabilityZone = "availability_zone"
        case attachments
        case metadata
        case sourceVolid = "source_volid"
        case snapshotId = "snapshot_id"
        case imageId = "image_id"
        case hostAttr = "os-vol-host-attr:host"
        case projectId = "os-vol-tenant-attr:tenant_id"
        case userId = "user_id"
        case multiattach
        case replicationStatus = "replication_status"
        case migrationStatus = "migration_status"
        case consistencygroupId = "consistencygroup_id"
        case groupId = "group_id"
        case providerId = "provider_id"
        case serviceUuid = "service_uuid"
        case sharedTargets = "shared_targets"
        case clusterName = "cluster_name"
    }

    public init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        size: Int? = nil,
        status: String? = nil,
        volumeType: String? = nil,
        bootable: String? = nil,
        encrypted: Bool? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        availabilityZone: String? = nil,
        attachments: [VolumeAttachment]? = nil,
        metadata: [String: String]? = nil,
        sourceVolid: String? = nil,
        snapshotId: String? = nil,
        imageId: String? = nil,
        hostAttr: String? = nil,
        projectId: String? = nil,
        userId: String? = nil,
        multiattach: Bool? = nil,
        replicationStatus: String? = nil,
        migrationStatus: String? = nil,
        consistencygroupId: String? = nil,
        groupId: String? = nil,
        providerId: String? = nil,
        serviceUuid: String? = nil,
        sharedTargets: Bool? = nil,
        clusterName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.size = size
        self.status = status
        self.volumeType = volumeType
        self.bootable = bootable
        self.encrypted = encrypted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.availabilityZone = availabilityZone
        self.attachments = attachments
        self.metadata = metadata
        self.sourceVolid = sourceVolid
        self.snapshotId = snapshotId
        self.imageId = imageId
        self.hostAttr = hostAttr
        self.projectId = projectId
        self.userId = userId
        self.multiattach = multiattach
        self.replicationStatus = replicationStatus
        self.migrationStatus = migrationStatus
        self.consistencygroupId = consistencygroupId
        self.groupId = groupId
        self.providerId = providerId
        self.serviceUuid = serviceUuid
        self.sharedTargets = sharedTargets
        self.clusterName = clusterName
    }

    // MARK: - Computed Properties

    public var isAvailable: Bool {
        return status?.lowercased() == "available"
    }

    public var isInUse: Bool {
        return status?.lowercased() == "in-use"
    }

    public var isAttached: Bool {
        return !(attachments?.isEmpty ?? true)
    }

    public var isBootable: Bool {
        return bootable?.lowercased() == "true"
    }

    public var displayName: String {
        return name ?? id
    }

    public var sizeGB: Int {
        return size ?? 0
    }

    public var isEncrypted: Bool {
        return encrypted ?? false
    }

    public var hasMultiAttach: Bool {
        return multiattach ?? false
    }

    public var attachedServers: [String] {
        return attachments?.compactMap { $0.serverId } ?? []
    }

    public var volumeStatus: VolumeStatus? {
        guard let status = status else { return nil }
        return VolumeStatus(rawValue: status.lowercased())
    }
}

public struct VolumeAttachment: Codable, Sendable {
    public let id: String?
    public let attachmentId: String?
    public let volumeId: String?
    public let serverId: String?
    public let hostName: String?
    public let device: String?
    public let attachedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case attachmentId = "attachment_id"
        case volumeId = "volume_id"
        case serverId = "server_id"
        case hostName = "host_name"
        case device
        case attachedAt = "attached_at"
    }

    public init(
        id: String? = nil,
        attachmentId: String? = nil,
        volumeId: String? = nil,
        serverId: String? = nil,
        hostName: String? = nil,
        device: String? = nil,
        attachedAt: Date? = nil
    ) {
        self.id = id
        self.attachmentId = attachmentId
        self.volumeId = volumeId
        self.serverId = serverId
        self.hostName = hostName
        self.device = device
        self.attachedAt = attachedAt
    }
}

public enum VolumeStatus: String, CaseIterable, Sendable {
    case available = "available"
    case inUse = "in-use"
    case attaching = "attaching"
    case detaching = "detaching"
    case creating = "creating"
    case deleting = "deleting"
    case error = "error"
    case errorDeleting = "error_deleting"
    case backingUp = "backing-up"
    case restoringBackup = "restoring-backup"
    case errorBackingUp = "error_backing-up"
    case errorRestoring = "error_restoring"
    case errorExtending = "error_extending"
    case extending = "extending"
    case downloading = "downloading"
    case uploading = "uploading"
    case retyping = "retyping"
    case reserved = "reserved"
    case maintenance = "maintenance"
    case awaiting_transfer = "awaiting-transfer"

    public var isTransitional: Bool {
        switch self {
        case .creating, .deleting, .attaching, .detaching, .backingUp, .restoringBackup, .extending, .downloading, .uploading, .retyping:
            return true
        case .available, .inUse, .error, .errorDeleting, .errorBackingUp, .errorRestoring, .errorExtending, .reserved, .maintenance, .awaiting_transfer:
            return false
        }
    }

    public var isError: Bool {
        switch self {
        case .error, .errorDeleting, .errorBackingUp, .errorRestoring, .errorExtending:
            return true
        default:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .available: return "Available"
        case .inUse: return "In Use"
        case .attaching: return "Attaching"
        case .detaching: return "Detaching"
        case .creating: return "Creating"
        case .deleting: return "Deleting"
        case .error: return "Error"
        case .errorDeleting: return "Error Deleting"
        case .backingUp: return "Backing Up"
        case .restoringBackup: return "Restoring Backup"
        case .errorBackingUp: return "Error Backing Up"
        case .errorRestoring: return "Error Restoring"
        case .errorExtending: return "Error Extending"
        case .extending: return "Extending"
        case .downloading: return "Downloading"
        case .uploading: return "Uploading"
        case .retyping: return "Retyping"
        case .reserved: return "Reserved"
        case .maintenance: return "Maintenance"
        case .awaiting_transfer: return "Awaiting Transfer"
        }
    }
}

// MARK: - Volume Type Models

public struct VolumeType: Codable, Sendable, ResourceIdentifiable, Identifiable {
    public let id: String
    public let name: String?
    public let description: String?
    public let extraSpecs: [String: String]?
    public let isPublic: Bool?
    public let qosSpecsId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case extraSpecs = "extra_specs"
        case isPublic = "is_public"
        case qosSpecsId = "qos_specs_id"
    }

    public init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        extraSpecs: [String: String]? = nil,
        isPublic: Bool? = nil,
        qosSpecsId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.extraSpecs = extraSpecs
        self.isPublic = isPublic
        self.qosSpecsId = qosSpecsId
    }

    // MARK: - Computed Properties

    public var displayName: String {
        return name ?? id
    }

    public var isAvailable: Bool {
        return isPublic ?? true
    }

    public var hasQoSSpecs: Bool {
        return qosSpecsId != nil
    }

    public var capabilities: [String] {
        return extraSpecs?.keys.sorted() ?? []
    }
}

// MARK: - Snapshot Models

public struct VolumeSnapshot: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let id: String
    public let name: String?
    public let description: String?
    public let volumeId: String
    public let status: String?
    public let size: Int?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let metadata: [String: String]?
    public let progress: String?
    public let projectId: String?
    public let userId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case volumeId = "volume_id"
        case status
        case size
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
        case progress
        case projectId = "os-extended-snapshot-attributes:project_id"
        case userId = "user_id"
    }

    public init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        volumeId: String,
        status: String? = nil,
        size: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        metadata: [String: String]? = nil,
        progress: String? = nil,
        projectId: String? = nil,
        userId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.volumeId = volumeId
        self.status = status
        self.size = size
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.progress = progress
        self.projectId = projectId
        self.userId = userId
    }

    // MARK: - Computed Properties

    public var isAvailable: Bool {
        return status?.lowercased() == "available"
    }

    public var displayName: String {
        return name ?? id
    }

    public var sizeGB: Int {
        return size ?? 0
    }

    public var progressPercentage: Int? {
        guard let progress = progress, !progress.isEmpty else { return nil }
        if progress.hasSuffix("%") {
            let percentStr = String(progress.dropLast())
            return Int(percentStr)
        }
        return Int(progress)
    }
}

// MARK: - Backup Models

public struct VolumeBackup: Codable, Sendable, ResourceIdentifiable, Timestamped {
    public let id: String
    public let name: String?
    public let description: String?
    public let volumeId: String?
    public let status: String?
    public let size: Int?
    public let objectCount: Int?
    public let container: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let dataTimestamp: Date?
    public let snapshotId: String?
    public let isIncremental: Bool?
    public let hasDependent: Bool?
    public let projectId: String?
    public let userId: String?
    public let availabilityZone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case volumeId = "volume_id"
        case status
        case size
        case objectCount = "object_count"
        case container
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case dataTimestamp = "data_timestamp"
        case snapshotId = "snapshot_id"
        case isIncremental = "is_incremental"
        case hasDependent = "has_dependent"
        case projectId = "project_id"
        case userId = "user_id"
        case availabilityZone = "availability_zone"
    }

    public init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        volumeId: String? = nil,
        status: String? = nil,
        size: Int? = nil,
        objectCount: Int? = nil,
        container: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        dataTimestamp: Date? = nil,
        snapshotId: String? = nil,
        isIncremental: Bool? = nil,
        hasDependent: Bool? = nil,
        projectId: String? = nil,
        userId: String? = nil,
        availabilityZone: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.volumeId = volumeId
        self.status = status
        self.size = size
        self.objectCount = objectCount
        self.container = container
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dataTimestamp = dataTimestamp
        self.snapshotId = snapshotId
        self.isIncremental = isIncremental
        self.hasDependent = hasDependent
        self.projectId = projectId
        self.userId = userId
        self.availabilityZone = availabilityZone
    }

    // MARK: - Computed Properties

    public var isAvailable: Bool {
        return status?.lowercased() == "available"
    }

    public var displayName: String {
        return name ?? id
    }

    public var sizeGB: Int {
        return size ?? 0
    }
}

public struct VolumeBackupRestore: Codable, Sendable {
    public let backupId: String
    public let volumeId: String
    public let volumeName: String?

    enum CodingKeys: String, CodingKey {
        case backupId = "backup_id"
        case volumeId = "volume_id"
        case volumeName = "volume_name"
    }

    public init(backupId: String, volumeId: String, volumeName: String? = nil) {
        self.backupId = backupId
        self.volumeId = volumeId
        self.volumeName = volumeName
    }
}

// MARK: - Quota Models

public struct VolumeQuotaSet: Codable, Sendable {
    public let volumes: Int
    public let snapshots: Int
    public let gigabytes: Int
    public let backups: Int
    public let backupGigabytes: Int
    public let groups: Int

    enum CodingKeys: String, CodingKey {
        case volumes
        case snapshots
        case gigabytes
        case backups
        case backupGigabytes = "backup_gigabytes"
        case groups
    }

    public init(
        volumes: Int,
        snapshots: Int,
        gigabytes: Int,
        backups: Int,
        backupGigabytes: Int,
        groups: Int
    ) {
        self.volumes = volumes
        self.snapshots = snapshots
        self.gigabytes = gigabytes
        self.backups = backups
        self.backupGigabytes = backupGigabytes
        self.groups = groups
    }
}

// MARK: - Request Models

public struct CreateVolumeRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let size: Int
    public let volumeType: String?
    public let availabilityZone: String?
    public let sourceVolid: String?
    public let snapshotId: String?
    public let imageRef: String?
    public let metadata: [String: String]?
    public let multiattach: Bool?
    public let bootable: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case size
        case volumeType = "volume_type"
        case availabilityZone = "availability_zone"
        case sourceVolid = "source_volid"
        case snapshotId = "snapshot_id"
        case imageRef = "imageRef"
        case metadata
        case multiattach
        case bootable
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        size: Int,
        volumeType: String? = nil,
        availabilityZone: String? = nil,
        sourceVolid: String? = nil,
        snapshotId: String? = nil,
        imageRef: String? = nil,
        metadata: [String: String]? = nil,
        multiattach: Bool? = nil,
        bootable: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.size = size
        self.volumeType = volumeType
        self.availabilityZone = availabilityZone
        self.sourceVolid = sourceVolid
        self.snapshotId = snapshotId
        self.imageRef = imageRef
        self.metadata = metadata
        self.multiattach = multiattach
        self.bootable = bootable
    }
}

public struct UpdateVolumeRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let metadata: [String: String]?

    public init(
        name: String? = nil,
        description: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.name = name
        self.description = description
        self.metadata = metadata
    }
}

public struct CreateVolumeTypeRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let extraSpecs: [String: String]?
    public let isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case extraSpecs = "extra_specs"
        case isPublic = "is_public"
    }

    public init(
        name: String,
        description: String? = nil,
        extraSpecs: [String: String]? = nil,
        isPublic: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.extraSpecs = extraSpecs
        self.isPublic = isPublic
    }
}

public struct CreateSnapshotRequest: Codable, Sendable {
    public let volumeId: String
    public let name: String?
    public let description: String?
    public let force: Bool?
    public let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case volumeId = "volume_id"
        case name
        case description
        case force
        case metadata
    }

    public init(
        volumeId: String,
        name: String? = nil,
        description: String? = nil,
        force: Bool? = nil,
        metadata: [String: String]? = nil
    ) {
        self.volumeId = volumeId
        self.name = name
        self.description = description
        self.force = force
        self.metadata = metadata
    }
}

public struct UpdateSnapshotRequest: Codable, Sendable {
    public let name: String?
    public let description: String?

    public init(
        name: String? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.description = description
    }
}

public struct CreateBackupRequest: Codable, Sendable {
    public let volumeId: String
    public let name: String?
    public let description: String?
    public let container: String?
    public let incremental: Bool?
    public let force: Bool?
    public let snapshotId: String?

    enum CodingKeys: String, CodingKey {
        case volumeId = "volume_id"
        case name
        case description
        case container
        case incremental
        case force
        case snapshotId = "snapshot_id"
    }

    public init(
        volumeId: String,
        name: String? = nil,
        description: String? = nil,
        container: String? = nil,
        incremental: Bool? = nil,
        force: Bool? = nil,
        snapshotId: String? = nil
    ) {
        self.volumeId = volumeId
        self.name = name
        self.description = description
        self.container = container
        self.incremental = incremental
        self.force = force
        self.snapshotId = snapshotId
    }
}

// MARK: - Validation Extensions

extension CreateVolumeRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if size <= 0 {
            errors.append("Volume size must be greater than 0")
        }

        if size > 16384 { // Common maximum size limit
            errors.append("Volume size cannot exceed 16384 GB")
        }

        if let name = name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Volume name cannot be empty")
        }

        if let volumeType = volumeType, !volumeType.isValidUUID {
            errors.append("Volume type must be a valid UUID")
        }

        if let sourceVolid = sourceVolid, !sourceVolid.isValidUUID {
            errors.append("Source volume ID must be a valid UUID")
        }

        if let snapshotId = snapshotId, !snapshotId.isValidUUID {
            errors.append("Snapshot ID must be a valid UUID")
        }

        if let imageRef = imageRef, !imageRef.isValidUUID {
            errors.append("Image reference must be a valid UUID")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

extension CreateSnapshotRequest {
    public func validate() -> ValidationResult {
        var errors: [String] = []

        if !volumeId.isValidUUID {
            errors.append("Volume ID must be a valid UUID")
        }

        if let name = name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Snapshot name cannot be empty")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

// MARK: - Volume Attachment Models

public struct VolumeAttachmentRequest: Codable, Sendable {
    public let instanceUuid: String
    public let mountpoint: String?

    enum CodingKeys: String, CodingKey {
        case instanceUuid = "instance_uuid"
        case mountpoint
    }

    public init(instanceUuid: String, mountpoint: String? = nil) {
        self.instanceUuid = instanceUuid
        self.mountpoint = mountpoint
    }
}

public struct VolumeAttachAction: Codable, Sendable {
    public let osAttach: VolumeAttachmentRequest

    enum CodingKeys: String, CodingKey {
        case osAttach = "os-attach"
    }

    public init(osAttach: VolumeAttachmentRequest) {
        self.osAttach = osAttach
    }
}

public struct VolumeDetachmentRequest: Codable, Sendable {
    public init() {}
}

public struct VolumeDetachAction: Codable, Sendable {
    public let osDetach: VolumeDetachmentRequest

    enum CodingKeys: String, CodingKey {
        case osDetach = "os-detach"
    }

    public init(osDetach: VolumeDetachmentRequest) {
        self.osDetach = osDetach
    }
}

public struct RestoreBackupRequest: Codable, Sendable {
    public let volumeId: String?

    enum CodingKeys: String, CodingKey {
        case volumeId = "volume_id"
    }

    public init(volumeId: String? = nil) {
        self.volumeId = volumeId
    }
}

public struct BackupRestoreWrapper: Codable, Sendable {
    public let restore: RestoreBackupRequest

    public init(restore: RestoreBackupRequest) {
        self.restore = restore
    }
}
