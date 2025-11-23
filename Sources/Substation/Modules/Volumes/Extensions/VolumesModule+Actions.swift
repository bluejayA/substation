// Sources/Substation/Modules/Volumes/VolumesModule+Actions.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Action Registration

extension VolumesModule {
    /// Register all volume actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Volume attachment to servers
    /// - Volume server management
    /// - Volume backup creation
    /// - Volume archive deletion
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register attach volume to servers action
        actions.append(ModuleActionRegistration(
            identifier: "volume.attach_to_servers",
            title: "Attach to Server",
            keybinding: "a",
            viewModes: [.volumes],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.attachVolumeToServers(screen: screen)
            },
            description: "Attach volume to a server",
            requiresConfirmation: false,
            category: .storage
        ))

        // Register manage volume servers action
        actions.append(ModuleActionRegistration(
            identifier: "volume.manage_servers",
            title: "Manage Server Attachments",
            keybinding: "m",
            viewModes: [.volumes],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.manageVolumeToServers(screen: screen)
            },
            description: "Manage volume server attachments",
            requiresConfirmation: false,
            category: .storage
        ))

        // Register create volume backup action
        actions.append(ModuleActionRegistration(
            identifier: "volume.create_backup",
            title: "Create Backup",
            keybinding: "b",
            viewModes: [.volumes, .volumeDetail],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.createVolumeBackup(screen: screen)
            },
            description: "Create a backup of the selected volume",
            requiresConfirmation: false,
            category: .storage
        ))

        // Register delete volume archive action
        actions.append(ModuleActionRegistration(
            identifier: "volume.delete_archive",
            title: "Delete Archive",
            keybinding: "d",
            viewModes: [.volumeArchives],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteVolumeArchive(screen: screen)
            },
            description: "Delete the selected volume archive (snapshot or backup)",
            requiresConfirmation: true,
            category: .storage
        ))

        return actions
    }
}

// MARK: - Volume Action Implementations

extension VolumesModule {
    /// Attach volume to servers
    ///
    /// Opens the server management view to attach a volume to a server.
    /// Automatically detects if volume is already attached and sets mode accordingly.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func attachVolumeToServers(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .volumes else { return }

        let filteredVolumes = FilterUtils.filterVolumes(
            tui.cacheManager.cachedVolumes,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredVolumes.count else {
            tui.statusMessage = "No volume selected"
            return
        }

        let volume = filteredVolumes[tui.viewCoordinator.selectedIndex]
        let volumeName = volume.name ?? "Unnamed Volume"

        // Store the selected volume for reference
        tui.viewCoordinator.selectedResource = volume

        // Load attached servers for this volume
        await loadAttachedServersForVolume(volume)

        // Clear previous selections
        tui.selectionManager.selectedServers.removeAll()

        // Check volume attachment status and set appropriate mode
        let isAttached = !(volume.attachments?.isEmpty ?? true)

        if isAttached {
            // If volume is attached, default to detach mode
            // User can toggle with 'T' key in the management view
            tui.selectionManager.attachmentMode = .detach
            tui.statusMessage = "Volume '\(volumeName)' - Select server to detach from (Press 'T' to switch to attach mode)"
        } else {
            // If volume is not attached, use attach mode
            tui.selectionManager.attachmentMode = .attach
            tui.statusMessage = "Select a server to attach volume '\(volumeName)'"
        }

        // Navigate to volume server management view
        tui.changeView(to: .volumeServerManagement, resetSelection: false)
    }

    /// Manage volume server attachments
    ///
    /// Opens the server management view to manage volume attachments.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func manageVolumeToServers(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .volumes else { return }

        let filteredVolumes = FilterUtils.filterVolumes(
            tui.cacheManager.cachedVolumes,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredVolumes.count else {
            tui.statusMessage = "No volume selected"
            return
        }

        let selectedVolume = filteredVolumes[tui.viewCoordinator.selectedIndex]

        // Store the selected volume for reference
        tui.viewCoordinator.selectedResource = selectedVolume

        // Load attached servers for this volume
        await loadAttachedServersForVolume(selectedVolume)

        // Clear previous selections
        tui.selectionManager.selectedServers.removeAll()

        // Reset to attach mode
        tui.selectionManager.attachmentMode = .attach

        // Navigate to volume server management view
        tui.changeView(to: .volumeServerManagement, resetSelection: false)
        tui.statusMessage = "Managing volume '\(selectedVolume.name ?? "Unknown")' server attachments"
    }

    /// Load the servers that have the volume attached
    ///
    /// - Parameter volume: The volume to check attachments for
    private func loadAttachedServersForVolume(_ volume: Volume) async {
        guard let tui = tui else { return }

        tui.selectionManager.attachedServerIds.removeAll()

        // Find servers that have this volume attached
        if let attachments = volume.attachments, !attachments.isEmpty {
            for attachment in attachments {
                if let serverId = attachment.serverId {
                    tui.selectionManager.attachedServerIds.insert(serverId)
                }
            }
        }
    }

    /// Apply server volume operation (attach or detach)
    ///
    /// Executes the volume attach/detach operation using selectionManager state.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func applyServerVolumeOperation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        guard let volume = tui.viewCoordinator.selectedResource as? Volume else {
            tui.statusMessage = "No volume selected"
            return
        }

        let selectedServerIds = tui.selectionManager.selectedServers
        guard !selectedServerIds.isEmpty else {
            tui.statusMessage = "No servers selected"
            return
        }

        let volumeName = volume.name ?? "Unnamed Volume"
        let mode = tui.selectionManager.attachmentMode
        let operationName = mode == .attach ? "Attaching" : "Detaching"

        tui.statusMessage = "\(operationName) volume '\(volumeName)' \(mode == .attach ? "to" : "from") \(selectedServerIds.count) server(s)..."
        await tui.draw(screen: screen)

        var successCount = 0
        var failureCount = 0

        for serverId in selectedServerIds {
            do {
                if mode == .attach {
                    try await tui.client.attachVolume(volumeId: volume.id, serverId: serverId)
                } else {
                    try await tui.client.detachVolume(serverId: serverId, volumeId: volume.id)
                }
                successCount += 1
            } catch {
                failureCount += 1
                Logger.shared.logError(
                    "Failed to \(mode == .attach ? "attach" : "detach") volume",
                    error: error,
                    context: ["volumeId": volume.id, "serverId": serverId]
                )
            }
        }

        // Clear selections
        tui.selectionManager.selectedServers.removeAll()

        // Build status message
        if failureCount == 0 {
            let action = mode == .attach ? "attached to" : "detached from"
            tui.statusMessage = "Volume '\(volumeName)' \(action) \(successCount) server(s) successfully"
        } else if successCount == 0 {
            let action = mode == .attach ? "attach" : "detach"
            tui.statusMessage = "Failed to \(action) volume '\(volumeName)' to any servers"
        } else {
            let action = mode == .attach ? "attached to" : "detached from"
            tui.statusMessage = "Volume '\(volumeName)' \(action) \(successCount) server(s), \(failureCount) failed"
        }

        // Refresh data and return to volumes view
        tui.refreshAfterOperation()
        tui.changeView(to: .volumes, resetSelection: false)
    }

    /// Open volume management form for a specific operation
    ///
    /// Opens the volume management view for attach or view operations.
    ///
    /// - Parameters:
    ///   - operation: The volume operation to perform
    ///   - screen: The ncurses screen pointer
    internal func openVolumeManagement(
        for operation: VolumeManagementForm.VolumeOperation,
        screen: OpaquePointer?
    ) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .volumes else { return }

        let filteredVolumes = FilterUtils.filterVolumes(
            tui.cacheManager.cachedVolumes,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredVolumes.count else {
            tui.statusMessage = "No volume selected"
            return
        }

        let volume = filteredVolumes[tui.viewCoordinator.selectedIndex]

        // Reset and configure the form
        tui.volumeManagementForm.reset()
        tui.volumeManagementForm.selectedVolume = volume
        tui.volumeManagementForm.availableServers = tui.cacheManager.cachedServers
        tui.volumeManagementForm.selectedOperation = operation

        // Validate operation
        switch operation {
        case .attach:
            if !(volume.attachments?.isEmpty ?? true) {
                tui.statusMessage = "Volume '\(volume.name ?? "Unnamed")' is already attached to a server"
                return
            }
            if tui.cacheManager.cachedServers.isEmpty {
                tui.statusMessage = "No servers available to attach volume to"
                return
            }
        case .view:
            break // View mode is always valid
        }

        // Switch to volume management view
        tui.changeView(to: .volumeManagement, resetSelection: false)
    }

    /// Apply volume attachment to a server
    ///
    /// Executes the volume attachment operation using the current form state.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func applyVolumeAttachment(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        guard let volume = tui.volumeManagementForm.selectedVolume,
              let serverToAttach = tui.volumeManagementForm.pendingAttachments.first else {
            tui.statusMessage = "No server selected for attachment"
            return
        }

        let volumeName = volume.name ?? "Unnamed Volume"
        let serverName = tui.volumeManagementForm.availableServers.first { $0.id == serverToAttach }?.name ?? "Unknown Server"

        tui.volumeManagementForm.isLoading = true
        tui.statusMessage = "Attaching volume '\(volumeName)' to server '\(serverName)'..."
        await tui.draw(screen: screen) // Refresh UI to show progress

        do {
            try await tui.client.attachVolume(volumeId: volume.id, serverId: serverToAttach)

            tui.statusMessage = "Volume '\(volumeName)' attached to server '\(serverName)' successfully"

            // Refresh data and return to volumes view
            tui.refreshAfterOperation()
            tui.changeView(to: .volumes, resetSelection: false)

        } catch let error as OpenStackError {
            tui.volumeManagementForm.isLoading = false
            let baseMsg = "Failed to attach volume '\(volumeName)' to server '\(serverName)'"
            switch error {
            case .authenticationFailed:
                tui.volumeManagementForm.errorMessage = "Authentication failed - check credentials"
            case .endpointNotFound:
                tui.volumeManagementForm.errorMessage = "Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.volumeManagementForm.errorMessage = "Unexpected response from server"
            case .httpError(let code, _):
                tui.volumeManagementForm.errorMessage = "HTTP error \(code)"
            case .networkError(let error):
                tui.volumeManagementForm.errorMessage = "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                tui.volumeManagementForm.errorMessage = "Data decoding error: \(error.localizedDescription)"
            case .encodingError(let error):
                tui.volumeManagementForm.errorMessage = "Data encoding error: \(error.localizedDescription)"
            case .configurationError(let message):
                tui.volumeManagementForm.errorMessage = "Configuration error: \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.volumeManagementForm.errorMessage = "Performance enhancements not available"
            case .missingRequiredField(let field):
                tui.volumeManagementForm.errorMessage = "Missing required field: \(field)"
            case .invalidResponse:
                tui.volumeManagementForm.errorMessage = "Invalid response from server"
            case .invalidURL:
                tui.volumeManagementForm.errorMessage = "Invalid URL configuration"
            }
            tui.statusMessage = baseMsg
        } catch {
            tui.volumeManagementForm.isLoading = false
            tui.volumeManagementForm.errorMessage = error.localizedDescription
            tui.statusMessage = "Failed to attach volume '\(volumeName)' to server '\(serverName)': \(error.localizedDescription)"
        }
    }

    /// Create a backup of the selected volume
    ///
    /// Opens the volume backup management form for creating a new backup.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func createVolumeBackup(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .volumes ||
              tui.viewCoordinator.currentView == .volumeDetail else { return }

        var volume: Volume?

        if tui.viewCoordinator.currentView == .volumes {
            // From volume list - get selected volume
            let filteredVolumes = FilterUtils.filterVolumes(
                tui.cacheManager.cachedVolumes,
                query: tui.searchQuery
            )
            guard tui.viewCoordinator.selectedIndex < filteredVolumes.count else {
                tui.statusMessage = "No volume selected for backup creation"
                return
            }
            volume = filteredVolumes[tui.viewCoordinator.selectedIndex]
        } else if tui.viewCoordinator.currentView == .volumeDetail {
            // From volume detail view - use the currently selected resource
            volume = tui.viewCoordinator.selectedResource as? Volume
        }

        guard let selectedVolume = volume else {
            tui.statusMessage = "No volume selected for backup creation"
            return
        }

        let volumeName = selectedVolume.name ?? "Unnamed Volume"

        // Initialize the volume backup management form and switch to the view
        tui.volumeBackupManagementForm.reset()
        tui.volumeBackupManagementForm.selectedVolume = selectedVolume
        tui.volumeBackupManagementForm.generateDefaultBackupName()

        // Load existing backups for this volume to check if incremental is allowed
        do {
            let backups = try await tui.client.getVolumeBackups(volumeId: selectedVolume.id)
            tui.volumeBackupManagementForm.availableBackups = backups
        } catch {
            // If we can't load backups, assume no full backup exists (incremental will be disabled)
            Logger.shared.logError(
                "Failed to load volume backups for incremental check",
                error: error,
                context: ["volumeID": selectedVolume.id]
            )
            tui.volumeBackupManagementForm.availableBackups = []
        }

        // Initialize form state with fields
        tui.volumeBackupManagementFormState = FormBuilderState(fields: tui.volumeBackupManagementForm.buildFields(
            selectedFieldId: nil,
            activeFieldId: nil,
            formState: nil
        ))

        // Switch to the volume backup management view
        tui.statusMessage = "Creating backup for volume '\(volumeName)'"
        tui.changeView(to: .volumeBackupManagement, resetSelection: false)
    }

    /// Execute the volume backup creation
    ///
    /// Creates a backup of the volume using the current form state.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func executeVolumeBackupCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

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
        tui.statusMessage = "Creating backup '\(backupName)' for volume '\(volume.name ?? "Unnamed Volume")'..."
        await tui.draw(screen: screen)

        do {
            let backupID = try await tui.client.createVolumeBackup(
                volumeID: volume.id,
                name: backupName,
                description: backupDescription.isEmpty ? nil : backupDescription,
                incremental: incremental,
                force: true
            )

            // Success - update form state
            tui.volumeBackupManagementForm.isLoading = false
            tui.volumeBackupManagementForm.successMessage = "Volume backup '\(backupName)' created successfully (ID: \(backupID))"
            tui.statusMessage = "[SUCCESS] Volume backup '\(backupName)' created successfully (ID: \(backupID))"

            // Show success message briefly
            await tui.draw(screen: screen)
            usleep(2_000_000) // Show success message for 2 seconds

            // Reset form and return to volumes view
            tui.volumeBackupManagementForm.reset()
            Logger.shared.logNavigation(
                ".volumeBackupManagement",
                to: ".volumes",
                details: ["action": "backup_created_success"]
            )
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
            tui.statusMessage = "[ERROR] \(tui.volumeBackupManagementForm.errorMessage ?? baseMsg)"
            Logger.shared.logError(
                "volume_backup_creation_failed",
                error: error,
                context: ["volumeID": volume.id]
            )
        } catch {
            tui.volumeBackupManagementForm.isLoading = false
            tui.volumeBackupManagementForm.errorMessage = "Failed to create volume backup '\(backupName)': \(error.localizedDescription)"
            tui.statusMessage = "[ERROR] \(tui.volumeBackupManagementForm.errorMessage ?? "")"
            Logger.shared.logError(
                "volume_backup_creation_failed",
                error: error,
                context: ["volumeID": volume.id]
            )
        }
    }

    /// Delete a volume archive (snapshot or backup)
    ///
    /// Deletes the selected volume archive from the archives list view.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteVolumeArchive(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .volumeArchives else { return }

        // Build the unified archive list (same logic as openDetailView)
        var archives: [Any] = []
        archives.append(contentsOf: tui.cacheManager.cachedVolumeSnapshots)
        archives.append(contentsOf: tui.cacheManager.cachedVolumeBackups)

        // Add server backups
        let serverBackups = tui.cacheManager.cachedImages.filter { image in
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
            let aDate = ArchiveUtilities.getArchiveCreationDate(a)
            let bDate = ArchiveUtilities.getArchiveCreationDate(b)
            return aDate > bDate
        }

        // Apply search filter
        if let query = tui.searchQuery, !query.isEmpty {
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

        guard tui.viewCoordinator.selectedIndex < archives.count else {
            tui.statusMessage = "No archive selected for deletion"
            return
        }

        let archive = archives[tui.viewCoordinator.selectedIndex]

        // Determine archive type and delete accordingly
        if let snapshot = archive as? VolumeSnapshot {
            let snapshotName = snapshot.name ?? "Unnamed"

            // Confirm deletion
            guard await ViewUtils.confirmDelete(
                snapshotName,
                screen: screen,
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            ) else {
                tui.statusMessage = "Volume snapshot deletion cancelled"
                return
            }

            tui.statusMessage = "Deleting volume snapshot '\(snapshotName)'..."
            await tui.draw(screen: screen)

            do {
                try await tui.client.deleteVolumeSnapshot(snapshotId: snapshot.id)
                tui.statusMessage = "[SUCCESS] Volume snapshot '\(snapshot.name ?? "Unnamed")' deleted successfully"
                Logger.shared.logInfo("Volume snapshot deleted", context: ["snapshotID": snapshot.id])

                // Refresh data
                _ = await self.loadAllVolumeSnapshots()
            } catch let error as OpenStackError {
                let baseMsg = "Failed to delete volume snapshot"
                switch error {
                case .authenticationFailed:
                    tui.statusMessage = "\(baseMsg): Authentication failed"
                case .httpError(let code, let message):
                    tui.statusMessage = "\(baseMsg): HTTP \(code) - \(message ?? "No details")"
                default:
                    tui.statusMessage = "\(baseMsg): \(error)"
                }
                Logger.shared.logError(
                    "volume_snapshot_delete_failed",
                    error: error,
                    context: ["snapshotID": snapshot.id]
                )
            } catch {
                tui.statusMessage = "[ERROR] Failed to delete volume snapshot: \(error.localizedDescription)"
                Logger.shared.logError(
                    "volume_snapshot_delete_failed",
                    error: error,
                    context: ["snapshotID": snapshot.id]
                )
            }
        } else if let backup = archive as? VolumeBackup {
            let backupName = backup.name ?? "Unnamed"

            // Confirm deletion
            guard await ViewUtils.confirmDelete(
                backupName,
                screen: screen,
                screenRows: tui.screenRows,
                screenCols: tui.screenCols
            ) else {
                tui.statusMessage = "Volume backup deletion cancelled"
                return
            }

            tui.statusMessage = "Deleting volume backup '\(backupName)'..."
            await tui.draw(screen: screen)

            do {
                try await tui.client.deleteVolumeBackup(backupId: backup.id)
                tui.statusMessage = "[SUCCESS] Volume backup '\(backup.name ?? "Unnamed")' deleted successfully"
                Logger.shared.logInfo("Volume backup deleted", context: ["backupID": backup.id])

                // Refresh data
                _ = await self.loadAllVolumeBackups()
            } catch let error as OpenStackError {
                let baseMsg = "Failed to delete volume backup"
                switch error {
                case .authenticationFailed:
                    tui.statusMessage = "\(baseMsg): Authentication failed"
                case .httpError(let code, let message):
                    tui.statusMessage = "\(baseMsg): HTTP \(code) - \(message ?? "No details")"
                default:
                    tui.statusMessage = "\(baseMsg): \(error)"
                }
                Logger.shared.logError(
                    "volume_backup_delete_failed",
                    error: error,
                    context: ["backupID": backup.id]
                )
            } catch {
                tui.statusMessage = "[ERROR] Failed to delete volume backup: \(error.localizedDescription)"
                Logger.shared.logError(
                    "volume_backup_delete_failed",
                    error: error,
                    context: ["backupID": backup.id]
                )
            }
        } else {
            tui.statusMessage = "Cannot delete server backups from Volume Archives view"
        }
    }

    /// Execute volume snapshot creation
    ///
    /// Creates a snapshot of the selected volume.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func executeVolumeSnapshotCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        let form = tui.volumeSnapshotManagementForm

        guard let volume = form.selectedVolume else {
            tui.statusMessage = "No volume selected for snapshot"
            return
        }

        let snapshotName = form.snapshotName.isEmpty ? "\(volume.name ?? "volume")-snapshot" : form.snapshotName

        tui.statusMessage = "Creating volume snapshot '\(snapshotName)'..."

        do {
            _ = try await tui.client.createVolumeSnapshot(
                volumeID: volume.id,
                name: snapshotName,
                description: form.snapshotDescription
            )
            tui.statusMessage = "Volume snapshot '\(snapshotName)' created successfully"

            // Refresh volume data
            let _ = await DataProviderRegistry.shared.fetchData(for: "volumes", priority: .onDemand, forceRefresh: true)

            // Return to volumes view
            tui.changeView(to: .volumes)
        } catch {
            tui.statusMessage = "Failed to create snapshot: \(error.localizedDescription)"
        }
    }

    /// Load all volume snapshots and update cache
    ///
    /// - Returns: Array of volume snapshots
    internal func loadAllVolumeSnapshots() async -> [VolumeSnapshot] {
        guard let tui = tui else { return [] }

        do {
            let snapshots = try await tui.client.getAllVolumeSnapshots()
            tui.cacheManager.cachedVolumeSnapshots = snapshots
            return snapshots
        } catch {
            tui.statusMessage = "Failed to load volume snapshots: \(error.localizedDescription)"
            return []
        }
    }

    /// Load all volume backups and update cache
    ///
    /// - Returns: Array of volume backups
    internal func loadAllVolumeBackups() async -> [VolumeBackup] {
        guard let tui = tui else { return [] }

        do {
            let backups = try await tui.client.getAllVolumeBackups()
            tui.cacheManager.cachedVolumeBackups = backups
            return backups
        } catch {
            tui.statusMessage = "Failed to load volume backups: \(error.localizedDescription)"
            return []
        }
    }

    /// Load all volume types and update cache
    ///
    /// - Returns: Array of volume types
    internal func loadVolumeTypes() async -> [VolumeType] {
        guard let tui = tui else { return [] }

        do {
            let volumeTypes = try await tui.client.listVolumeTypes()
            tui.cacheManager.cachedVolumeTypes = volumeTypes
            return volumeTypes
        } catch {
            Logger.shared.logError("Failed to load volume types", error: error)
            return []
        }
    }

    // MARK: - Volume CRUD Operations

    /// Delete the currently selected volume
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func deleteVolume(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .volumes else { return }

        let filteredVolumes = FilterUtils.filterVolumes(tui.cacheManager.cachedVolumes, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredVolumes.count else {
            tui.statusMessage = "No volume selected"
            return
        }

        let volume = filteredVolumes[tui.viewCoordinator.selectedIndex]
        let volumeName = volume.name ?? "Unnamed Volume"

        // Check if volume is attached to any servers
        if !(volume.attachments?.isEmpty ?? true) {
            tui.statusMessage = "Cannot delete volume '\(volumeName)': Volume is attached to server(s)"
            return
        }

        // Confirm deletion
        guard await ViewUtils.confirmDelete(volumeName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Volume deletion cancelled"
            return
        }

        // Show deletion in progress
        tui.statusMessage = "Deleting volume '\(volumeName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.deleteVolume(id: volume.id)

            // Remove from cached volumes
            if let index = tui.cacheManager.cachedVolumes.firstIndex(where: { $0.id == volume.id }) {
                tui.cacheManager.cachedVolumes.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredVolumes.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Volume '\(volumeName)' deleted successfully"

            // Refresh data to get updated volume list
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete volume '\(volumeName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, let message):
                if let message = message {
                    tui.statusMessage = "\(baseMsg): \(message)"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                }
            case .networkError(let error):
                tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                tui.statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                tui.statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            tui.statusMessage = "Failed to delete volume '\(volumeName)': \(error.localizedDescription)"
        }
    }

    /// Create a snapshot from a volume
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func createVolumeSnapshot(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        var volume: Volume?

        if tui.viewCoordinator.currentView == .volumes {
            // From volume list - get selected volume
            let filteredVolumes = FilterUtils.filterVolumes(tui.cacheManager.cachedVolumes, query: tui.searchQuery)
            guard tui.viewCoordinator.selectedIndex < filteredVolumes.count else {
                tui.statusMessage = "No volume selected for snapshot creation"
                return
            }
            volume = filteredVolumes[tui.viewCoordinator.selectedIndex]
        } else if tui.viewCoordinator.currentView == .volumeDetail {
            // From volume detail view - use the currently selected resource
            volume = tui.viewCoordinator.selectedResource as? Volume
        }

        guard let selectedVolume = volume else {
            tui.statusMessage = "No volume selected for snapshot creation"
            return
        }

        // Initialize the volume snapshot management form and switch to the new view
        tui.volumeSnapshotManagementForm.reset()
        tui.volumeSnapshotManagementForm.selectedVolume = selectedVolume
        tui.volumeSnapshotManagementForm.generateDefaultSnapshotName()

        // Initialize form state with fields
        tui.volumeSnapshotManagementFormState = FormBuilderState(fields: tui.volumeSnapshotManagementForm.buildFields(
            selectedFieldId: nil,
            activeFieldId: nil,
            formState: nil
        ))

        // Switch to the volume snapshot management view
        tui.changeView(to: .volumeSnapshotManagement, resetSelection: false)
    }

    /// Delete selected volume snapshots
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func deleteSelectedVolumeSnapshots(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        guard !tui.selectedSnapshotsForDeletion.isEmpty else {
            tui.statusMessage = "No snapshots selected for deletion"
            return
        }

        let snapshotsToDelete = tui.cacheManager.cachedVolumeSnapshots.filter { tui.selectedSnapshotsForDeletion.contains($0.id) }
        let snapshotNames = snapshotsToDelete.map { $0.name ?? "Unnamed" }.joined(separator: ", ")

        // Confirm deletion
        guard await ViewUtils.confirmDelete("snapshots: \(snapshotNames)", screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Snapshot deletion cancelled"
            return
        }

        tui.statusMessage = "Deleting \(tui.selectedSnapshotsForDeletion.count) snapshots..."
        await tui.draw(screen: screen)

        var deletedCount = 0
        var errors: [String] = []

        for snapshotId in tui.selectedSnapshotsForDeletion {
            do {
                try await tui.client.deleteVolumeSnapshot(snapshotId: snapshotId)
                deletedCount += 1
            } catch {
                let snapshotName = snapshotsToDelete.first { $0.id == snapshotId }?.name ?? snapshotId
                errors.append("\(snapshotName): \(error.localizedDescription)")
            }
        }

        // Clear selection and reload snapshots
        tui.selectedSnapshotsForDeletion.removeAll()
        if tui.selectedVolumeForSnapshots != nil {
            let _ = await DataProviderRegistry.shared.fetchData(for: "volumes", priority: .onDemand, forceRefresh: true)
        }

        // Update status message
        if errors.isEmpty {
            tui.statusMessage = "Successfully deleted \(deletedCount) snapshots"
        } else {
            tui.statusMessage = "Deleted \(deletedCount) snapshots, \(errors.count) failed"
        }

        // Reset selection if we deleted the currently selected item
        if tui.viewCoordinator.selectedIndex >= tui.cacheManager.cachedVolumeSnapshots.count {
            tui.viewCoordinator.selectedIndex = max(0, tui.cacheManager.cachedVolumeSnapshots.count - 1)
        }
    }

    /// Submit volume creation from the volume create form
    /// - Parameter screen: The ncurses screen pointer for UI operations
    internal func submitVolumeCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Validate the form
        let validationErrors = tui.volumeCreateForm.validate()
        if !validationErrors.isEmpty {
            tui.statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let volumeNameBase = tui.volumeCreateForm.volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let volumeSizeString = tui.volumeCreateForm.volumeSize.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse and validate maxVolumes
        guard let maxVolumesCount = Int(tui.volumeCreateForm.maxVolumes.trimmingCharacters(in: .whitespacesAndNewlines)), maxVolumesCount >= 1 else {
            tui.statusMessage = "Max volumes must be a valid number >= 1"
            return
        }

        // Convert volume size to integer
        guard let volumeSize = Int(volumeSizeString), volumeSize > 0 else {
            tui.statusMessage = "Invalid volume size: must be a positive integer"
            return
        }

        // Capture form values before going async
        let sourceType = tui.volumeCreateForm.sourceType
        let volumeTypeId = tui.volumeCreateForm.selectedVolumeTypeID
        let selectedImageID = tui.volumeCreateForm.selectedImageID
        let selectedSnapshotID = tui.volumeCreateForm.selectedSnapshotID

        // Create operation tracker for volume creation
        let operation = SwiftBackgroundOperation(
            type: .bulkCreate,
            resourceType: "Volumes",
            itemsTotal: maxVolumesCount
        )
        tui.swiftBackgroundOps.addOperation(operation)
        operation.status = .queued

        // Show creation starting
        tui.statusMessage = maxVolumesCount > 1 ? "Starting creation of \(maxVolumesCount) volumes..." : "Creating volume '\(volumeNameBase)'..."

        // Return to volumes view immediately
        tui.changeView(to: .volumes, resetSelection: false)
        await tui.draw(screen: screen)

        // Run creation in background task
        Task { @MainActor in
            operation.status = .running

            do {
                // Create volumes with indexed names if maxVolumesCount > 1
                for i in 0..<maxVolumesCount {
                    let volumeName = maxVolumesCount > 1 ? "\(volumeNameBase)-\(i)" : volumeNameBase

                    switch sourceType {
                    case .blank:
                        _ = try await tui.client.createBlankVolume(
                            name: volumeName,
                            size: volumeSize,
                            volumeType: volumeTypeId
                        )

                    case .image:
                        guard let imageID = selectedImageID else {
                            throw NSError(domain: "VolumeCreate", code: 1, userInfo: [NSLocalizedDescriptionKey: "No image selected"])
                        }

                        _ = try await tui.client.createVolumeFromImage(
                            name: volumeName,
                            size: volumeSize,
                            imageRef: imageID,
                            volumeType: volumeTypeId
                        )

                    case .snapshot:
                        guard let snapshotID = selectedSnapshotID else {
                            throw NSError(domain: "VolumeCreate", code: 1, userInfo: [NSLocalizedDescriptionKey: "No snapshot selected"])
                        }

                        _ = try await tui.client.createVolumeFromSnapshot(
                            name: volumeName,
                            size: volumeSize,
                            snapshotId: snapshotID,
                            volumeType: volumeTypeId
                        )
                    }

                    // Update operation progress after each volume
                    operation.itemsCompleted = i + 1
                    operation.progress = Double(i + 1) / Double(maxVolumesCount)
                    tui.markNeedsRedraw()
                }

                let successMessage = maxVolumesCount > 1
                    ? "Created \(maxVolumesCount) volumes with name pattern '\(volumeNameBase)-N'"
                    : "Volume '\(volumeNameBase)' created successfully"
                tui.statusMessage = successMessage

                // Mark operation as complete
                operation.itemsCompleted = maxVolumesCount
                operation.markCompleted()
                operation.progress = 1.0

                // Refresh volume cache
                let _ = await DataProviderRegistry.shared.fetchData(for: "volumes", priority: .onDemand, forceRefresh: true)

            } catch let error as OpenStackError {
                let baseMsg = "Failed to create volume '\(volumeNameBase)'"
                switch error {
                case .authenticationFailed:
                    tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
                case .endpointNotFound:
                    tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
                case .unexpectedResponse:
                    tui.statusMessage = "\(baseMsg): Unexpected response from server"
                case .httpError(let code, _):
                    tui.statusMessage = "\(baseMsg): HTTP error \(code)"
                case .networkError(let error):
                    tui.statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
                case .decodingError(let error):
                    tui.statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
                case .encodingError(let error):
                    tui.statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
                case .configurationError(let message):
                    tui.statusMessage = "\(baseMsg): Configuration error - \(message)"
                case .performanceEnhancementsNotAvailable:
                    tui.statusMessage = "\(baseMsg): Performance enhancements not available"
                case .missingRequiredField(let field):
                    tui.statusMessage = "\(baseMsg): Missing required field: \(field)"
                case .invalidResponse:
                    tui.statusMessage = "\(baseMsg): Invalid response from server"
                case .invalidURL:
                    tui.statusMessage = "\(baseMsg): Invalid URL configuration"
                }
                // Mark operation as failed
                operation.markFailed(error: tui.statusMessage ?? "Unknown error")
            } catch {
                tui.statusMessage = "Failed to create volume '\(volumeNameBase)': \(error.localizedDescription)"
                // Mark operation as failed
                operation.markFailed(error: tui.statusMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Batch Volume Operations

    /// Perform batch volume attachment to selected servers
    ///
    /// Attaches the currently selected volume to multiple selected servers.
    /// This operation iterates through all selected servers and attempts to
    /// attach the volume to each one, tracking successes and failures.
    ///
    /// - Note: This function requires servers to be pre-selected via the
    ///         selection manager before calling.
    internal func performBatchVolumeAttachment() async {
        guard let tui = tui else { return }

        guard !tui.selectionManager.selectedServers.isEmpty else {
            tui.statusMessage = "No servers selected for volume attachment"
            return
        }

        guard let selectedVolume = tui.viewCoordinator.selectedResource as? Volume else {
            tui.statusMessage = "No volume selected for attachment"
            return
        }

        let volumeName = selectedVolume.name ?? "Unknown"
        let serverCount = tui.selectionManager.selectedServers.count
        tui.statusMessage = "Attaching volume '\(volumeName)' to \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        var successCount = 0
        var errorCount = 0
        var errors: [String] = []

        for serverId in tui.selectionManager.selectedServers {
            // Find the server object
            guard let server = tui.cacheManager.cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                errors.append("Server with ID \(serverId) not found")
                continue
            }

            do {
                // Attach volume to server
                try await tui.client.attachVolume(volumeId: selectedVolume.id, serverId: serverId)
                successCount += 1
                Logger.shared.logUserAction("volume_attached_to_server", details: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "volumeId": selectedVolume.id,
                    "volumeName": volumeName
                ])
            } catch {
                errorCount += 1
                let serverName = server.name ?? "Unknown"
                let errorMessage = "Failed to attach volume to '\(serverName)': \(error.localizedDescription)"
                errors.append(errorMessage)
                Logger.shared.logError("Failed to attach volume to server", error: error, context: [
                    "serverId": serverId,
                    "serverName": serverName,
                    "volumeId": selectedVolume.id,
                    "volumeName": volumeName
                ])
            }
        }

        // Update status message with results
        if errorCount == 0 {
            tui.statusMessage = "Successfully attached volume '\(volumeName)' to \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            tui.statusMessage = "Failed to attach volume to any servers. See logs for details."
        } else {
            tui.statusMessage = "Attached volume to \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed. See logs for details."
        }

        // Clear selections and return to volumes view
        tui.selectionManager.selectedServers.removeAll()
        tui.changeView(to: .volumes, resetSelection: false)

        // Refresh server data to show updated volume attachments
        tui.refreshAfterOperation()
    }

    /// Perform enhanced volume management operations
    ///
    /// Handles both attach and detach operations for a volume to/from multiple
    /// selected servers. The operation mode is determined by the selection
    /// manager's attachment mode.
    ///
    /// - Note: This function requires servers to be pre-selected via the
    ///         selection manager before calling.
    internal func performEnhancedVolumeManagement() async {
        guard let tui = tui else { return }

        guard !tui.selectionManager.selectedServers.isEmpty else {
            tui.statusMessage = "No servers selected for volume \(tui.selectionManager.attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }

        guard let selectedVolume = tui.viewCoordinator.selectedResource as? Volume else {
            tui.statusMessage = "No volume selected for \(tui.selectionManager.attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }

        let volumeName = selectedVolume.name ?? "Unknown"
        let serverCount = tui.selectionManager.selectedServers.count
        let action = tui.selectionManager.attachmentMode == .attach ? "attaching" : "detaching"
        tui.statusMessage = "\(action.capitalized) volume '\(volumeName)' \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        // Force immediate UI update to show status message
        tui.forceRedraw()

        var successCount = 0
        var errorCount = 0

        for serverId in tui.selectionManager.selectedServers {
            guard let server = tui.cacheManager.cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                continue
            }

            do {
                if tui.selectionManager.attachmentMode == .attach {
                    try await tui.client.attachVolume(volumeId: selectedVolume.id, serverId: serverId)
                } else {
                    try await tui.client.detachVolume(serverId: serverId, volumeId: selectedVolume.id)
                }
                successCount += 1
            } catch {
                errorCount += 1
                Logger.shared.logError("Failed to \(tui.selectionManager.attachmentMode == .attach ? "attach" : "detach") volume", error: error, context: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "volumeId": selectedVolume.id,
                    "volumeName": volumeName
                ])
            }
        }

        if errorCount == 0 {
            tui.statusMessage = "Successfully \(tui.selectionManager.attachmentMode == .attach ? "attached" : "detached") volume '\(volumeName)' \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            tui.statusMessage = "Failed to \(tui.selectionManager.attachmentMode == .attach ? "attach" : "detach") volume \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") any servers"
        } else {
            tui.statusMessage = "\(tui.selectionManager.attachmentMode == .attach ? "Attached" : "Detached") volume \(tui.selectionManager.attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed"
        }

        tui.selectionManager.selectedServers.removeAll()
        tui.changeView(to: .volumes, resetSelection: false)
        tui.refreshAfterOperation()
    }
}
