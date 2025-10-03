import Foundation
import MemoryKit

/// Data manager for volume-related operations with MemoryKit integration
public actor VolumeDataManager {
    private let cinderService: CinderService
    private let logger: any OpenStackClientLogger
    private let memoryManager: MemoryManager

    public init(cinderService: CinderService, logger: any OpenStackClientLogger, memoryManager: MemoryManager) {
        self.cinderService = cinderService
        self.logger = logger
        self.memoryManager = memoryManager
    }

    // MARK: - Volume Operations

    /// List all volumes with caching
    public func listVolumes(forceRefresh: Bool = false) async throws -> [Volume] {
        let cacheKey = "volume_list"

        if !forceRefresh {
            if let cachedVolumes = await memoryManager.retrieve(forKey: cacheKey, as: [Volume].self) {
                return cachedVolumes
            }
        }

        let volumes = try await cinderService.listVolumes()
        await memoryManager.store(volumes, forKey:cacheKey)

        for volume in volumes {
            await memoryManager.store(volume, forKey:"volume_\(volume.id)")
        }

        return volumes
    }

    /// Get a specific volume with caching
    public func getVolume(id: String, forceRefresh: Bool = false) async throws -> Volume {
        let cacheKey = "volume_\(id)"

        if !forceRefresh {
            if let cachedVolume = await memoryManager.retrieve(forKey: cacheKey, as: Volume.self) {
                return cachedVolume
            }
        }

        let volume = try await cinderService.getVolume(id: id)
        await memoryManager.store(volume, forKey:cacheKey)
        return volume
    }

    /// List all volume types
    public func listVolumeTypes() async throws -> [VolumeType] {
        let cacheKey = "volume_type_list"

        if let cachedVolumeTypes = await memoryManager.retrieve(forKey: cacheKey, as: [VolumeType].self) {
            return cachedVolumeTypes
        }

        let volumeTypes = try await cinderService.listVolumeTypes()
        await memoryManager.store(volumeTypes, forKey:cacheKey)

        for volumeType in volumeTypes {
            await memoryManager.store(volumeType, forKey:"volume_type_\(volumeType.id)")
        }

        return volumeTypes
    }

    /// List all volume snapshots
    public func listVolumeSnapshots() async throws -> [VolumeSnapshot] {
        let cacheKey = "volume_snapshot_list"

        if let cachedSnapshots = await memoryManager.retrieve(forKey: cacheKey, as: [VolumeSnapshot].self) {
            return cachedSnapshots
        }

        let snapshots = try await cinderService.listSnapshots()
        await memoryManager.store(snapshots, forKey:cacheKey)

        for snapshot in snapshots {
            await memoryManager.store(snapshot, forKey:"volume_snapshot_\(snapshot.id)")
        }
        return snapshots
    }

    /// Get snapshots for a specific volume
    public func getVolumeSnapshots(volumeID: String) async throws -> [VolumeSnapshot] {
        return try await cinderService.listSnapshots(volumeId: volumeID)
    }

    /// Create a new volume
    public func createVolume(request: CreateVolumeRequest) async throws -> Volume {
        let volume = try await cinderService.createVolume(request: request)
        await memoryManager.store(volume, forKey:"volume_\(volume.id)")
        await memoryManager.clearKey( "volume_list")
        return volume
    }

    /// Create volume snapshot
    public func createVolumeSnapshot(volumeID: String, name: String, description: String? = nil) async throws -> String {
        let request = CreateSnapshotRequest(volumeId: volumeID, name: name, description: description, force: true)
        let snapshot = try await cinderService.createSnapshot(request: request)
        await memoryManager.store(snapshot, forKey:"volume_snapshot_\(snapshot.id)")
        await memoryManager.clearKey( "volume_snapshot_list")
        return snapshot.id
    }

    /// Delete a volume
    public func deleteVolume(id: String) async throws {
        try await cinderService.deleteVolume(id: id)
        await memoryManager.clearKey( "volume_\(id)")
        await memoryManager.clearKey( "volume_list")
    }

    /// Delete a volume snapshot
    public func deleteVolumeSnapshot(snapshotID: String) async throws {
        try await cinderService.deleteSnapshot(id: snapshotID)
        await memoryManager.clearKey( "volume_snapshot_\(snapshotID)")
        await memoryManager.clearKey( "volume_snapshot_list")
    }

    // MARK: - Cache Management

    /// Clear all cached data
    public func clearCache() async {
        await memoryManager.clearAll()
    }

    /// Get memory usage statistics
    public func getMemoryStats() async -> MemoryMetrics {
        return await memoryManager.getMetrics()
    }

    /// Handle memory pressure by clearing cache
    public func handleMemoryPressure() async {
        await clearCache()
    }
}