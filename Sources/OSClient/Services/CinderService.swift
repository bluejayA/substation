import Foundation

// MARK: - Cinder (Block Storage) Service

public actor CinderService: OpenStackService {
    public let core: OpenStackClientCore
    public let serviceName = "volumev3"

    public init(core: OpenStackClientCore) {
        self.core = core
    }

    // MARK: - Volume Operations

    /// List volumes with optional filtering
    public func listVolumes(options: PaginationOptions = PaginationOptions()) async throws -> [Volume] {
        var path = "/volumes/detail"

        if !options.queryItems.isEmpty {
            let queryString = options.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: VolumeListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.volumes
    }

    /// Get volume details
    public func getVolume(id: String) async throws -> Volume {
        let response: VolumeDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/volumes/\(id)",
            expected: 200
        )
        return response.volume
    }

    /// Create a volume
    public func createVolume(request: CreateVolumeRequest) async throws -> Volume {
        let requestData = try SharedResources.jsonEncoder.encode(["volume": request])
        let response: VolumeDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/volumes",
            body: requestData,
            expected: 202
        )
        return response.volume
    }

    /// Update a volume
    public func updateVolume(id: String, request: UpdateVolumeRequest) async throws -> Volume {
        let requestData = try SharedResources.jsonEncoder.encode(["volume": request])
        let response: VolumeDetailResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/volumes/\(id)",
            body: requestData,
            expected: 200
        )
        return response.volume
    }

    /// Delete a volume
    public func deleteVolume(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/volumes/\(id)",
            expected: 202
        )
    }

    /// Extend a volume
    public func extendVolume(id: String, newSize: Int) async throws {
        let action = ["os-extend": ["new_size": newSize]]
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/volumes/\(id)/action",
            body: requestData,
            expected: 202
        )
    }

    /// Reset volume status
    public func resetVolumeStatus(id: String, status: String) async throws {
        let action = ["os-reset_status": ["status": status]]
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/volumes/\(id)/action",
            body: requestData,
            expected: 202
        )
    }

    /// Attach volume to server
    public func attachVolume(id: String, serverId: String, device: String? = nil) async throws {
        let attachment = VolumeAttachmentRequest(instanceUuid: serverId, mountpoint: device)
        let action = VolumeAttachAction(osAttach: attachment)
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/volumes/\(id)/action",
            body: requestData,
            expected: 202
        )
    }

    /// Detach volume from server
    public func detachVolume(id: String) async throws {
        let action = VolumeDetachAction(osDetach: VolumeDetachmentRequest())
        let requestData = try SharedResources.jsonEncoder.encode(action)
        try await core.requestVoid(
            service: serviceName,
            method: "POST",
            path: "/volumes/\(id)/action",
            body: requestData,
            expected: 202
        )
    }

    // MARK: - Volume Type Operations

    /// List volume types
    public func listVolumeTypes() async throws -> [VolumeType] {
        let response: VolumeTypeListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/types",
            expected: 200
        )
        return response.volumeTypes
    }

    /// Get volume type details
    public func getVolumeType(id: String) async throws -> VolumeType {
        let response: VolumeTypeDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/types/\(id)",
            expected: 200
        )
        return response.volumeType
    }

    /// Create a volume type
    public func createVolumeType(request: CreateVolumeTypeRequest) async throws -> VolumeType {
        let requestData = try SharedResources.jsonEncoder.encode(["volume_type": request])
        let response: VolumeTypeDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/types",
            body: requestData,
            expected: 200
        )
        return response.volumeType
    }

    /// Delete a volume type
    public func deleteVolumeType(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/types/\(id)",
            expected: 202
        )
    }

    // MARK: - Snapshot Operations

    /// List volume snapshots
    public func listSnapshots(volumeId: String? = nil, options: PaginationOptions = PaginationOptions()) async throws -> [VolumeSnapshot] {
        var queryItems = options.queryItems
        if let volumeId = volumeId {
            queryItems.append(URLQueryItem(name: "volume_id", value: volumeId))
        }

        var path = "/snapshots/detail"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: SnapshotListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.snapshots
    }

    /// Get snapshot details
    public func getSnapshot(id: String) async throws -> VolumeSnapshot {
        let response: SnapshotDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/snapshots/\(id)",
            expected: 200
        )
        return response.snapshot
    }

    /// Create a volume snapshot
    public func createSnapshot(request: CreateSnapshotRequest) async throws -> VolumeSnapshot {
        let requestData = try SharedResources.jsonEncoder.encode(["snapshot": request])
        let response: SnapshotDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/snapshots",
            body: requestData,
            expected: 202
        )
        return response.snapshot
    }

    /// Update a snapshot
    public func updateSnapshot(id: String, request: UpdateSnapshotRequest) async throws -> VolumeSnapshot {
        let requestData = try SharedResources.jsonEncoder.encode(["snapshot": request])
        let response: SnapshotDetailResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/snapshots/\(id)",
            body: requestData,
            expected: 200
        )
        return response.snapshot
    }

    /// Delete a snapshot
    public func deleteSnapshot(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/snapshots/\(id)",
            expected: 202
        )
    }

    // MARK: - Backup Operations

    /// List volume backups
    public func listBackups(volumeId: String? = nil, options: PaginationOptions = PaginationOptions()) async throws -> [VolumeBackup] {
        var queryItems = options.queryItems
        if let volumeId = volumeId {
            queryItems.append(URLQueryItem(name: "volume_id", value: volumeId))
        }

        var path = "/backups/detail"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            path += "?" + queryString
        }

        let response: BackupListResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: path,
            expected: 200
        )
        return response.backups
    }

    /// Get backup details
    public func getBackup(id: String) async throws -> VolumeBackup {
        let response: BackupDetailResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/backups/\(id)",
            expected: 200
        )
        return response.backup
    }

    /// Create a volume backup
    public func createBackup(request: CreateBackupRequest) async throws -> VolumeBackup {
        let requestData = try SharedResources.jsonEncoder.encode(["backup": request])
        let response: BackupDetailResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/backups",
            body: requestData,
            expected: 202
        )
        return response.backup
    }

    /// Delete a backup
    public func deleteBackup(id: String) async throws {
        try await core.requestVoid(
            service: serviceName,
            method: "DELETE",
            path: "/backups/\(id)",
            expected: 202
        )
    }

    /// Restore a backup to a volume
    public func restoreBackup(id: String, volumeId: String? = nil) async throws -> VolumeBackupRestore {
        let request = RestoreBackupRequest(volumeId: volumeId)

        let requestData = try SharedResources.jsonEncoder.encode(BackupRestoreWrapper(restore: request))
        let response: BackupRestoreResponse = try await core.request(
            service: serviceName,
            method: "POST",
            path: "/backups/\(id)/restore",
            body: requestData,
            expected: 202
        )
        return response.restore
    }

    // MARK: - Quota Operations

    /// Get volume quotas for project
    public func getQuotas(projectId: String) async throws -> VolumeQuotaSet {
        let response: VolumeQuotaResponse = try await core.request(
            service: serviceName,
            method: "GET",
            path: "/os-quota-sets/\(projectId)",
            expected: 200
        )
        return response.quotaSet
    }

    /// Update volume quotas for project
    public func updateQuotas(projectId: String, quotas: VolumeQuotaSet) async throws -> VolumeQuotaSet {
        let requestData = try SharedResources.jsonEncoder.encode(["quota_set": quotas])
        let response: VolumeQuotaResponse = try await core.request(
            service: serviceName,
            method: "PUT",
            path: "/os-quota-sets/\(projectId)",
            body: requestData,
            expected: 200
        )
        return response.quotaSet
    }
}

// MARK: - Response Models

public struct VolumeListResponse: Codable, Sendable {
    public let volumes: [Volume]
}

public struct VolumeDetailResponse: Codable, Sendable {
    public let volume: Volume
}

public struct VolumeTypeListResponse: Codable, Sendable {
    public let volumeTypes: [VolumeType]

    enum CodingKeys: String, CodingKey {
        case volumeTypes = "volume_types"
    }
}

public struct VolumeTypeDetailResponse: Codable, Sendable {
    public let volumeType: VolumeType

    enum CodingKeys: String, CodingKey {
        case volumeType = "volume_type"
    }
}

public struct SnapshotListResponse: Codable, Sendable {
    public let snapshots: [VolumeSnapshot]
}

public struct SnapshotDetailResponse: Codable, Sendable {
    public let snapshot: VolumeSnapshot
}

public struct BackupListResponse: Codable, Sendable {
    public let backups: [VolumeBackup]
}

public struct BackupDetailResponse: Codable, Sendable {
    public let backup: VolumeBackup
}

public struct BackupRestoreResponse: Codable, Sendable {
    public let restore: VolumeBackupRestore
}

public struct VolumeQuotaResponse: Codable, Sendable {
    public let quotaSet: VolumeQuotaSet

    enum CodingKeys: String, CodingKey {
        case quotaSet = "quota_set"
    }
}