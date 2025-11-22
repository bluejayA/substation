// Sources/Substation/Modules/Barbican/BarbicanModule+Actions.swift
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

extension BarbicanModule {
    /// Register all Barbican actions with the ActionRegistry
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register delete secret action
        actions.append(ModuleActionRegistration(
            identifier: "barbican.delete",
            title: "Delete Secret",
            keybinding: "d",
            viewModes: [.barbicanSecrets, .barbican],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteSecret(screen: screen)
            },
            description: "Delete the selected secret",
            requiresConfirmation: true,
            category: .security
        ))

        return actions
    }
}

// MARK: - Barbican Action Implementations

extension BarbicanModule {
    /// Delete the selected secret
    ///
    /// Prompts for confirmation before deleting the secret from Barbican.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteSecret(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .barbicanSecrets || tui.viewCoordinator.currentView == .barbican else { return }

        let cachedSecrets = tui.cacheManager.cachedSecrets
        let filteredSecrets = tui.searchQuery?.isEmpty ?? true ? cachedSecrets : cachedSecrets.filter { secret in
            (secret.name?.lowercased().contains(tui.searchQuery?.lowercased() ?? "") ?? false) ||
            (secret.secretType?.lowercased().contains(tui.searchQuery?.lowercased() ?? "") ?? false)
        }
        guard tui.viewCoordinator.selectedIndex < filteredSecrets.count else {
            tui.statusMessage = "No secret selected"
            return
        }

        let secret = filteredSecrets[tui.viewCoordinator.selectedIndex]
        let secretName = secret.name ?? "Unnamed Secret"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(secretName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Secret deletion cancelled"
            return
        }

        // Show deletion in progress
        tui.statusMessage = "Deleting secret '\(secretName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.barbican.deleteSecret(id: secret.id)

            // Adjust selection if needed
            let newSecretCount = filteredSecrets.count - 1
            if tui.viewCoordinator.selectedIndex >= newSecretCount && newSecretCount > 0 {
                tui.viewCoordinator.selectedIndex = newSecretCount - 1
            } else if newSecretCount == 0 {
                tui.viewCoordinator.selectedIndex = 0
            }

            tui.statusMessage = "Secret '\(secretName)' deleted successfully"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete secret '\(secretName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 404 {
                    tui.statusMessage = "\(baseMsg): Secret not found"
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
                tui.statusMessage = "\(baseMsg): Missing required field - \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL configuration"
            }
        } catch {
            tui.statusMessage = "Failed to delete secret '\(secretName)': \(error.localizedDescription)"
        }
    }

    /// Create a new secret in Barbican
    ///
    /// Creates a new secret using the form data in barbicanSecretCreateForm.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func createSecret(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .barbicanSecretCreate else { return }

        let secretName = tui.barbicanSecretCreateForm.secretName.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = tui.barbicanSecretCreateForm.payload.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show creation in progress
        tui.statusMessage = "Creating secret '\(secretName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let expiration = tui.barbicanSecretCreateForm.getExpirationDate()

            let request = CreateSecretRequest(
                name: secretName,
                secretType: tui.barbicanSecretCreateForm.secretType.rawValue,
                algorithm: tui.barbicanSecretCreateForm.algorithm.rawValue,
                bitLength: tui.barbicanSecretCreateForm.bitLength,
                mode: tui.barbicanSecretCreateForm.mode.rawValue,
                payload: payload,
                payloadContentType: tui.barbicanSecretCreateForm.payloadContentType.rawValue,
                payloadContentEncoding: tui.barbicanSecretCreateForm.payloadContentEncoding.rawValue,
                expiration: expiration
            )

            _ = try await tui.client.barbican.createSecret(request: request)

            tui.statusMessage = "Secret '\(secretName)' created successfully"

            // Trigger accelerated refresh to show state transitions
            tui.refreshAfterOperation()
            tui.changeView(to: .barbicanSecrets, resetSelection: false)
            tui.barbicanSecretCreateForm = BarbicanSecretCreateForm() // Reset form

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create secret '\(secretName)'"
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
                tui.statusMessage = "\(baseMsg): Decoding error - \(error.localizedDescription)"
            case .encodingError(let error):
                tui.statusMessage = "\(baseMsg): Encoding error - \(error.localizedDescription)"
            case .configurationError(let error):
                tui.statusMessage = "\(baseMsg): Configuration error - \(error)"
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
            tui.statusMessage = "Failed to create secret '\(secretName)': \(error.localizedDescription)"
        }
    }
}
