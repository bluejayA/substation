import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftTUI
import MemoryKit

// MARK: - Volume Actions

@MainActor
extension Actions {

    internal func attachVolumeToServers(screen: OpaquePointer?) async {
        guard currentView == .volumes else { return }

        let filteredVolumes = FilterUtils.filterVolumes(cachedVolumes, query: searchQuery)
        guard selectedIndex < filteredVolumes.count else {
            statusMessage = "No volume selected"
            return
        }

        let volume = filteredVolumes[selectedIndex]
        let volumeName = volume.name ?? "Unnamed Volume"

        // Store the selected volume for reference
        selectedResource = volume

        // Load attached servers for this volume
        await loadAttachedServersForVolume(volume)

        // Clear previous selections
        selectedServers.removeAll()

        // Check volume attachment status and set appropriate mode
        let isAttached = !(volume.attachments?.isEmpty ?? true)

        if isAttached {
            // If volume is attached, default to detach mode
            // User can toggle with 'T' key in the management view
            attachmentMode = .detach
            statusMessage = "Volume '\(volumeName)' - Select server to detach from (Press 'T' to switch to attach mode)"
        } else {
            // If volume is not attached, use attach mode
            attachmentMode = .attach
            statusMessage = "Select a server to attach volume '\(volumeName)'"
        }

        // Navigate to volume server management view
        tui.changeView(to: .volumeServerManagement, resetSelection: false)
    }

    internal func manageVolumeToServers(screen: OpaquePointer?) async {
        guard currentView == .volumes else { return }
        let filteredVolumes = ResourceFilters.filterVolumes(cachedVolumes, query: searchQuery)
        guard selectedIndex < filteredVolumes.count else {
            statusMessage = "No volume selected"
            return
        }
        let selectedVolume = filteredVolumes[selectedIndex]
        // Store the selected volume for reference
        selectedResource = selectedVolume
        // Load attached servers for this volume
        await loadAttachedServersForVolume(selectedVolume)
        // Clear previous selections
        selectedServers.removeAll()
        // Reset to attach mode
        attachmentMode = .attach
        // Navigate to volume server management view
        tui.changeView(to: .volumeServerManagement, resetSelection: false)
        statusMessage = "Managing volume '\(selectedVolume.name ?? "Unknown")' server attachments"
    }

    internal func loadAttachedServersForVolume(_ volume: Volume) async {
        attachedServerIds.removeAll()
        // Find servers that have this volume attached
        if let attachments = volume.attachments, !attachments.isEmpty {
            for attachment in attachments {
                if let serverId = attachment.serverId {
                    attachedServerIds.insert(serverId)
                }
            }
        }
    }

    internal func openVolumeManagement(for operation: VolumeManagementForm.VolumeOperation, screen: OpaquePointer?) async {
        guard currentView == .volumes else { return }

        let filteredVolumes = FilterUtils.filterVolumes(cachedVolumes, query: searchQuery)
        guard selectedIndex < filteredVolumes.count else {
            statusMessage = "No volume selected"
            return
        }

        let volume = filteredVolumes[selectedIndex]

        // Reset and configure the form
        volumeManagementForm.reset()
        volumeManagementForm.selectedVolume = volume
        volumeManagementForm.availableServers = cachedServers
        volumeManagementForm.selectedOperation = operation

        // Validate operation
        switch operation {
        case .attach:
            if !(volume.attachments?.isEmpty ?? true) {
                statusMessage = "Volume '\(volume.name ?? "Unnamed")' is already attached to a server"
                return
            }
            if cachedServers.isEmpty {
                statusMessage = "No servers available to attach volume to"
                return
            }
        case .view:
            break // View mode is always valid
        }

        // Switch to volume management view
        tui.changeView(to: .volumeManagement, resetSelection: false)
    }

    internal func applyVolumeAttachment(screen: OpaquePointer?) async {
        guard let volume = volumeManagementForm.selectedVolume,
              let serverToAttach = volumeManagementForm.pendingAttachments.first else {
            statusMessage = "No server selected for attachment"
            return
        }

        let volumeName = volume.name ?? "Unnamed Volume"
        let serverName = volumeManagementForm.availableServers.first { $0.id == serverToAttach }?.name ?? "Unknown Server"

        volumeManagementForm.isLoading = true
        statusMessage = "Attaching volume '\(volumeName)' to server '\(serverName)'..."
        await tui.draw(screen: screen) // Refresh UI to show progress

        do {
            try await client.attachVolume(volumeId: volume.id, serverId: serverToAttach)

            statusMessage = "Volume '\(volumeName)' attached to server '\(serverName)' successfully"

            // Refresh data and return to volumes view
            tui.refreshAfterOperation()
            tui.changeView(to: .volumes, resetSelection: false)

        } catch let error as OpenStackError {
            volumeManagementForm.isLoading = false
            let baseMsg = "Failed to attach volume '\(volumeName)' to server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                volumeManagementForm.errorMessage = "Authentication failed - check credentials"
            case .endpointNotFound:
                volumeManagementForm.errorMessage = "Endpoint not found - check service configuration"
            case .unexpectedResponse:
                volumeManagementForm.errorMessage = "Unexpected response from server"
            case .httpError(let code, _):
                volumeManagementForm.errorMessage = "HTTP error \(code)"
            case .networkError(let error):
                volumeManagementForm.errorMessage = "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                volumeManagementForm.errorMessage = "Data decoding error: \(error.localizedDescription)"
            case .encodingError(let error):
                volumeManagementForm.errorMessage = "Data encoding error: \(error.localizedDescription)"
            case .configurationError(let message):
                volumeManagementForm.errorMessage = "Configuration error: \(message)"
            case .performanceEnhancementsNotAvailable:
                volumeManagementForm.errorMessage = "Performance enhancements not available"
            case .missingRequiredField(let field):
                volumeManagementForm.errorMessage = "Missing required field: \(field)"
            case .invalidResponse:
                volumeManagementForm.errorMessage = "Invalid response from server"
            case .invalidURL:
                volumeManagementForm.errorMessage = "Invalid URL configuration"
            }
            statusMessage = baseMsg
        } catch {
            volumeManagementForm.isLoading = false
            volumeManagementForm.errorMessage = error.localizedDescription
            statusMessage = "Failed to attach volume '\(volumeName)' to server '\(serverName)': \(error.localizedDescription)"
        }
    }

    internal func createVolumeBackup(screen: OpaquePointer?) async {
        guard currentView == .volumes || currentView == .volumeDetail else { return }

        var volume: Volume?

        if currentView == .volumes {
            // From volume list - get selected volume
            let filteredVolumes = FilterUtils.filterVolumes(cachedVolumes, query: searchQuery)
            guard selectedIndex < filteredVolumes.count else {
                statusMessage = "No volume selected for backup creation"
                return
            }
            volume = filteredVolumes[selectedIndex]
        } else if currentView == .volumeDetail {
            // From volume detail view - use the currently selected resource
            volume = selectedResource as? Volume
        }

        guard let selectedVolume = volume else {
            statusMessage = "No volume selected for backup creation"
            return
        }

        let volumeName = selectedVolume.name ?? "Unnamed Volume"

        // Initialize the volume backup management form and switch to the view
        tui.volumeBackupManagementForm.reset()
        tui.volumeBackupManagementForm.selectedVolume = selectedVolume
        tui.volumeBackupManagementForm.generateDefaultBackupName()

        // Load existing backups for this volume to check if incremental is allowed
        do {
            let backups = try await client.getVolumeBackups(volumeId: selectedVolume.id)
            tui.volumeBackupManagementForm.availableBackups = backups
        } catch {
            // If we can't load backups, assume no full backup exists (incremental will be disabled)
            Logger.shared.logError("Failed to load volume backups for incremental check", error: error, context: ["volumeID": selectedVolume.id])
            tui.volumeBackupManagementForm.availableBackups = []
        }

        // Switch to the volume backup management view
        statusMessage = "Creating backup for volume '\(volumeName)'"
        tui.changeView(to: .volumeBackupManagement, resetSelection: false)
    }

    internal func executeVolumeBackupCreation(screen: OpaquePointer?) async {
        guard let volume = tui.volumeBackupManagementForm.selectedVolume else {
            tui.volumeBackupManagementForm.errorMessage = "No volume selected"
            return
        }

        let backupName = tui.volumeBackupManagementForm.backupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let backupDescription = tui.volumeBackupManagementForm.backupDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let incremental = tui.volumeBackupManagementForm.incremental

        // Set loading state
        tui.volumeBackupManagementForm.isLoading = true
        tui.volumeBackupManagementForm.errorMessage = nil
        statusMessage = "Creating backup '\(backupName)' for volume '\(volume.name ?? "Unnamed Volume")'..."
        await tui.draw(screen: screen)

        do {
            let backupID = try await client.createVolumeBackup(
                volumeID: volume.id,
                name: backupName,
                description: backupDescription.isEmpty ? nil : backupDescription,
                incremental: incremental,
                force: true
            )

            // Success - update form state
            tui.volumeBackupManagementForm.isLoading = false
            tui.volumeBackupManagementForm.successMessage = "Volume backup '\(backupName)' created successfully (ID: \(backupID))"
            statusMessage = "[SUCCESS] Volume backup '\(backupName)' created successfully (ID: \(backupID))"

            // Show success message briefly
            await tui.draw(screen: screen)
            usleep(2_000_000) // Show success message for 2 seconds

            // Reset form and return to volumes view
            tui.volumeBackupManagementForm.reset()
            Logger.shared.logNavigation(".volumeBackupManagement", to: ".volumes", details: ["action": "backup_created_success"])
            tui.changeView(to: .volumes, resetSelection: false, preserveStatus: true)

        } catch let error as OpenStackError {
            tui.volumeBackupManagementForm.isLoading = false
            let baseMsg = "Failed to create volume backup '\(backupName)'"
            switch error {
            case .authenticationFailed:
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Endpoint not found"
            case .unexpectedResponse:
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Unexpected response"
            case .networkError(_):
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Network error"
            case .decodingError(_):
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Response decoding error"
            case .encodingError(_):
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Request encoding error"
            case .configurationError(_):
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Configuration error"
            case .performanceEnhancementsNotAvailable:
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Performance enhancements not available"
            case .httpError(let code, let message):
                let errorDetail = message ?? "No details"
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): HTTP \(code) - \(errorDetail)"
            case .missingRequiredField(let field):
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Missing required field \(field)"
            case .invalidResponse:
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Invalid response"
            case .invalidURL:
                tui.volumeBackupManagementForm.errorMessage = "\(baseMsg): Invalid URL"
            }
            statusMessage = "[ERROR] \(tui.volumeBackupManagementForm.errorMessage ?? baseMsg)"
            Logger.shared.logError("volume_backup_creation_failed", error: error, context: ["volumeID": volume.id])
        } catch {
            tui.volumeBackupManagementForm.isLoading = false
            tui.volumeBackupManagementForm.errorMessage = "Failed to create volume backup '\(backupName)': \(error.localizedDescription)"
            statusMessage = "[ERROR] \(tui.volumeBackupManagementForm.errorMessage ?? "")"
            Logger.shared.logError("volume_backup_creation_failed", error: error, context: ["volumeID": volume.id])
        }
    }

    internal func deleteVolumeArchive(screen: OpaquePointer?) async {
        guard currentView == .volumeArchives else { return }

        // Build the unified archive list (same logic as openDetailView)
        var archives: [Any] = []
        archives.append(contentsOf: tui.cachedVolumeSnapshots)
        archives.append(contentsOf: tui.cachedVolumeBackups)

        // Add server backups
        let serverBackups = tui.cachedImages.filter { image in
            if let properties = image.properties,
               let imageType = properties["image_type"],
               imageType == "snapshot" {
                return true
            }
            return false
        }
        archives.append(contentsOf: serverBackups)

        // Sort by creation date
        archives.sort { (a, b) -> Bool in
            let aDate = getArchiveCreationDate(a)
            let bDate = getArchiveCreationDate(b)
            return aDate > bDate
        }

        // Apply search filter
        if let query = searchQuery, !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            archives = archives.filter { archive in
                if let snapshot = archive as? VolumeSnapshot {
                    return (snapshot.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                           (snapshot.status?.lowercased().contains(lowercaseQuery) ?? false)
                } else if let backup = archive as? VolumeBackup {
                    return (backup.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                           (backup.status?.lowercased().contains(lowercaseQuery) ?? false)
                } else if let image = archive as? Image {
                    return (image.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                           (image.status?.lowercased().contains(lowercaseQuery) ?? false)
                }
                return false
            }
        }

        guard selectedIndex < archives.count else {
            statusMessage = "No archive selected for deletion"
            return
        }

        let archive = archives[selectedIndex]

        // Determine archive type and delete accordingly
        if let snapshot = archive as? VolumeSnapshot {
            let snapshotName = snapshot.name ?? "Unnamed"

            // Confirm deletion
            guard await ViewUtils.confirmDelete(snapshotName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
                statusMessage = "Volume snapshot deletion cancelled"
                return
            }

            statusMessage = "Deleting volume snapshot '\(snapshotName)'..."
            await tui.draw(screen: screen)

            do {
                try await client.deleteVolumeSnapshot(snapshotId: snapshot.id)
                statusMessage = "[SUCCESS] Volume snapshot '\(snapshot.name ?? "Unnamed")' deleted successfully"
                Logger.shared.logInfo("Volume snapshot deleted", context: ["snapshotID": snapshot.id])

                // Refresh data
                await tui.actions.loadAllVolumeSnapshots()
            } catch let error as OpenStackError {
                let baseMsg = "Failed to delete volume snapshot"
                switch error {
                case .authenticationFailed:
                    statusMessage = "\(baseMsg): Authentication failed"
                case .httpError(let code, let message):
                    statusMessage = "\(baseMsg): HTTP \(code) - \(message ?? "No details")"
                default:
                    statusMessage = "\(baseMsg): \(error)"
                }
                Logger.shared.logError("volume_snapshot_delete_failed", error: error, context: ["snapshotID": snapshot.id])
            } catch {
                statusMessage = "[ERROR] Failed to delete volume snapshot: \(error.localizedDescription)"
                Logger.shared.logError("volume_snapshot_delete_failed", error: error, context: ["snapshotID": snapshot.id])
            }
        } else if let backup = archive as? VolumeBackup {
            let backupName = backup.name ?? "Unnamed"

            // Confirm deletion
            guard await ViewUtils.confirmDelete(backupName, screen: screen, screenRows: screenRows, screenCols: screenCols) else {
                statusMessage = "Volume backup deletion cancelled"
                return
            }

            statusMessage = "Deleting volume backup '\(backupName)'..."
            await tui.draw(screen: screen)

            do {
                try await client.deleteVolumeBackup(backupId: backup.id)
                statusMessage = "[SUCCESS] Volume backup '\(backup.name ?? "Unnamed")' deleted successfully"
                Logger.shared.logInfo("Volume backup deleted", context: ["backupID": backup.id])

                // Refresh data
                await tui.actions.loadAllVolumeBackups()
            } catch let error as OpenStackError {
                let baseMsg = "Failed to delete volume backup"
                switch error {
                case .authenticationFailed:
                    statusMessage = "\(baseMsg): Authentication failed"
                case .httpError(let code, let message):
                    statusMessage = "\(baseMsg): HTTP \(code) - \(message ?? "No details")"
                default:
                    statusMessage = "\(baseMsg): \(error)"
                }
                Logger.shared.logError("volume_backup_delete_failed", error: error, context: ["backupID": backup.id])
            } catch {
                statusMessage = "[ERROR] Failed to delete volume backup: \(error.localizedDescription)"
                Logger.shared.logError("volume_backup_delete_failed", error: error, context: ["backupID": backup.id])
            }
        } else {
            statusMessage = "Cannot delete server backups from Volume Archives view"
        }
    }

    // Helper function to get creation date from archive item
    private func getArchiveCreationDate(_ archive: Any) -> Date {
        if let snapshot = archive as? VolumeSnapshot {
            return snapshot.createdAt ?? Date.distantPast
        } else if let backup = archive as? VolumeBackup {
            return backup.createdAt ?? Date.distantPast
        } else if let image = archive as? Image {
            return image.createdAt ?? Date.distantPast
        }
        return Date.distantPast
    }
}
