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

// MARK: - Snapshot Actions

@MainActor
extension Actions {

    internal func loadVolumeSnapshots(volumeId: String, screen: OpaquePointer?) async {
        statusMessage = "Loading snapshots for volume \(volumeId.prefix(8))..."
        await tui.draw(screen: screen)

        do {
            tui.cachedVolumeSnapshots = try await client.getVolumeSnapshots(volumeId: volumeId)
            if tui.cachedVolumeSnapshots.isEmpty {
                statusMessage = "No snapshots found for this volume"
            } else {
                statusMessage = "Loaded \(tui.cachedVolumeSnapshots.count) snapshots for volume \(volumeId.prefix(8))"
            }
        } catch let error as OpenStackError {
            let baseMsg = "Failed to load snapshots for volume \(volumeId.prefix(8))"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Snapshots endpoint not found"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected API response"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
            tui.cachedVolumeSnapshots = []
        } catch {
            statusMessage = "Failed to load snapshots for volume \(volumeId.prefix(8)): \(error.localizedDescription)"
            tui.cachedVolumeSnapshots = []
        }
    }

    internal func loadAllVolumeSnapshots() async {
        do {
            tui.cachedVolumeSnapshots = try await client.getAllVolumeSnapshots()
            Logger.shared.logInfo("All volume snapshots loaded", context: [
                "totalSnapshots": tui.cachedVolumeSnapshots.count
            ])
        } catch let error as OpenStackError {
            let baseMsg = "Failed to load all volume snapshots"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Snapshots endpoint not found"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected API response"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
            tui.cachedVolumeSnapshots = []
        } catch {
            statusMessage = "Failed to load all volume snapshots: \(error.localizedDescription)"
            tui.cachedVolumeSnapshots = []
        }
    }

    internal func loadAllVolumeBackups() async {
        do {
            tui.cachedVolumeBackups = try await client.getAllVolumeBackups()
            Logger.shared.logInfo("All volume backups loaded", context: [
                "totalBackups": tui.cachedVolumeBackups.count
            ])
        } catch let error as OpenStackError {
            let baseMsg = "Failed to load all volume backups"
            switch error {
            case .authenticationFailed:
                statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                statusMessage = "\(baseMsg): Backups endpoint not found"
            case .unexpectedResponse:
                statusMessage = "\(baseMsg): Unexpected API response"
            case .httpError(let code, _):
                statusMessage = "\(baseMsg): HTTP error \(code)"
            case .networkError(let error):
                statusMessage = "\(baseMsg): Network error - \(error.localizedDescription)"
            case .decodingError(let error):
                statusMessage = "\(baseMsg): Data decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                statusMessage = "\(baseMsg): Data encoding error - \(error.localizedDescription)"
            case .configurationError(let message):
                statusMessage = "\(baseMsg): Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                statusMessage = "\(baseMsg): Performance enhancements not available"
            case .missingRequiredField(let field):
                statusMessage = "\(baseMsg): Missing required field: \(field)"
            case .invalidResponse:
                statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                statusMessage = "\(baseMsg): Invalid URL configuration"
            }
            tui.cachedVolumeBackups = []
        } catch {
            statusMessage = "Failed to load all volume backups: \(error.localizedDescription)"
            tui.cachedVolumeBackups = []
        }
    }

    internal func executeSnapshotCreation(screen: OpaquePointer?) async {
        guard let server = snapshotManagementForm.selectedServer else {
            snapshotManagementForm.errorMessage = "No server selected"
            statusMessage = "Snapshot creation failed: No server selected"
            return
        }

        let snapshotName = snapshotManagementForm.snapshotName.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverName = server.name ?? "Unknown Server"

        // Set loading state and update status line
        snapshotManagementForm.isLoading = true
        snapshotManagementForm.errorMessage = nil
        statusMessage = "Creating snapshot '\(snapshotName)' for server '\(serverName)'..."
        await tui.draw(screen: screen)

        do {
            let metadata = snapshotManagementForm.generateSnapshotMetadata()

            let imageID = try await client.createServerSnapshot(
                serverID: server.id,
                name: snapshotName,
                metadata: metadata
            )

            // Success - update form state and status line
            snapshotManagementForm.isLoading = false
            snapshotManagementForm.successMessage = "Snapshot '\(snapshotName)' created successfully (ID: \(imageID))"
            statusMessage = "[SUCCESS] Snapshot '\(snapshotName)' created successfully for '\(serverName)' (ID: \(imageID))"

            // Show success message briefly
            await tui.draw(screen: screen)
            usleep(2_000_000) // Show success message for 2 seconds

            // Refresh image cache to include the new snapshot
            await dataManager.refreshImageData()

            // Restore success status message after refresh (which may overwrite it)
            statusMessage = "[SUCCESS] Snapshot '\(snapshotName)' created successfully for '\(serverName)' (ID: \(imageID))"

            // Reset form and return to servers view after successful creation
            snapshotManagementForm.reset()
            Logger.shared.logNavigation(".serverSnapshotManagement", to: ".servers", details: ["action": "snapshot_created_success"])
            tui.changeView(to: .servers, resetSelection: false, preserveStatus: true)

        } catch let error as OpenStackError {
            snapshotManagementForm.isLoading = false
            let baseMsg = "Failed to create snapshot '\(snapshotName)'"
            let statusMsg: String
            switch error {
            case .authenticationFailed:
                snapshotManagementForm.errorMessage = "\(baseMsg): Authentication failed"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Authentication failed"
            case .endpointNotFound:
                snapshotManagementForm.errorMessage = "\(baseMsg): Endpoint not found"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Endpoint not found"
            case .unexpectedResponse:
                snapshotManagementForm.errorMessage = "\(baseMsg): Unexpected response"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Unexpected response"
            case .networkError(let underlyingError):
                let errorDetail = underlyingError.localizedDescription
                snapshotManagementForm.errorMessage = "\(baseMsg): Network error - \(errorDetail)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Network error - \(errorDetail)"
            case .decodingError(let underlyingError):
                let errorDetail = underlyingError.localizedDescription
                snapshotManagementForm.errorMessage = "\(baseMsg): Response decoding error - \(errorDetail)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Response decoding error - \(errorDetail)"
            case .encodingError(let underlyingError):
                let errorDetail = underlyingError.localizedDescription
                snapshotManagementForm.errorMessage = "\(baseMsg): Request encoding error - \(errorDetail)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Request encoding error - \(errorDetail)"
            case .configurationError(let message):
                snapshotManagementForm.errorMessage = "\(baseMsg): Configuration error - \(message)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Configuration error - \(message)"
            case .performanceEnhancementsNotAvailable:
                snapshotManagementForm.errorMessage = "\(baseMsg): Performance enhancements not available"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Performance enhancements not available"
            case .httpError(let code, let message):
                let detail = message.map { " - \($0)" } ?? ""
                snapshotManagementForm.errorMessage = "\(baseMsg): HTTP error \(code)\(detail)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': HTTP error \(code)\(detail)"
            case .missingRequiredField(let field):
                snapshotManagementForm.errorMessage = "\(baseMsg): Missing required field \(field)"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Missing required field \(field)"
            case .invalidResponse:
                snapshotManagementForm.errorMessage = "\(baseMsg): Invalid response"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Invalid response"
            case .invalidURL:
                snapshotManagementForm.errorMessage = "\(baseMsg): Invalid URL"
                statusMsg = "[ERROR] \(baseMsg) for '\(serverName)': Invalid URL"
            }
            statusMessage = statusMsg

            // Show error message briefly then return to servers view
            await tui.draw(screen: screen)
            usleep(3_000_000) // Show error message for 3 seconds
            Logger.shared.logError("snapshot_creation_failed", error: error, context: ["serverID": server.id])

            // Reset form and return to servers view
            snapshotManagementForm.reset()
            Logger.shared.logNavigation(".serverSnapshotManagement", to: ".servers", details: ["action": "snapshot_creation_failed"])
            tui.changeView(to: .servers, resetSelection: false, preserveStatus: true)

        } catch {
            snapshotManagementForm.isLoading = false
            snapshotManagementForm.errorMessage = "Failed to create snapshot '\(snapshotName)': \(error.localizedDescription)"
            statusMessage = "[ERROR] Failed to create snapshot '\(snapshotName)' for '\(serverName)': \(error.localizedDescription)"

            // Show error message briefly then return to servers view
            await tui.draw(screen: screen)
            usleep(3_000_000) // Show error message for 3 seconds
            Logger.shared.logError("snapshot_creation_failed", error: error, context: ["serverID": server.id])

            // Reset form and return to servers view
            snapshotManagementForm.reset()
            Logger.shared.logNavigation(".serverSnapshotManagement", to: ".servers", details: ["action": "snapshot_creation_failed"])
            tui.changeView(to: .servers, resetSelection: false, preserveStatus: true)
        }
    }

    internal func executeVolumeSnapshotCreation(screen: OpaquePointer?) async {
        guard let volume = volumeSnapshotManagementForm.selectedVolume else {
            volumeSnapshotManagementForm.errorMessage = "No volume selected"
            return
        }

        let snapshotName = volumeSnapshotManagementForm.snapshotName.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshotDescription = volumeSnapshotManagementForm.snapshotDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        // Set loading state
        volumeSnapshotManagementForm.isLoading = true
        volumeSnapshotManagementForm.errorMessage = nil
        await tui.draw(screen: screen)

        do {
            let _ = volumeSnapshotManagementForm.generateSnapshotMetadata()

            let snapshotID = try await client.createVolumeSnapshot(
                volumeID: volume.id,
                name: snapshotName,
                description: snapshotDescription.isEmpty ? nil : snapshotDescription
            )

            // Success - update form state
            volumeSnapshotManagementForm.isLoading = false
            volumeSnapshotManagementForm.successMessage = "Volume snapshot '\(snapshotName)' created successfully (ID: \(snapshotID))"

            // Note: Volume snapshots are not images, so we don't refresh image cache here
            // In a full implementation, you might want to create a separate cache for volume snapshots

        } catch let error as OpenStackError {
            volumeSnapshotManagementForm.isLoading = false
            let baseMsg = "Failed to create volume snapshot '\(snapshotName)'"
            switch error {
            case .authenticationFailed:
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Endpoint not found"
            case .unexpectedResponse:
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Unexpected response"
            case .networkError(_):
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Network error"
            case .decodingError(_):
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Response decoding error"
            case .encodingError(_):
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Request encoding error"
            case .configurationError(_):
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Configuration error"
            case .performanceEnhancementsNotAvailable:
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Performance enhancements not available"
            case .httpError(let code, let message):
                let errorDetail = message ?? "No details"
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): HTTP \(code) - \(errorDetail)"
            case .missingRequiredField(let field):
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Missing required field \(field)"
            case .invalidResponse:
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Invalid response"
            case .invalidURL:
                volumeSnapshotManagementForm.errorMessage = "\(baseMsg): Invalid URL"
            }
        } catch {
            volumeSnapshotManagementForm.isLoading = false
            volumeSnapshotManagementForm.errorMessage = "Failed to create volume snapshot '\(snapshotName)': \(error.localizedDescription)"
        }
    }
}
