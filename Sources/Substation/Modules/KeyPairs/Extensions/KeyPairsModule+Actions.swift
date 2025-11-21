// Sources/Substation/Modules/KeyPairs/KeyPairsModule+Actions.swift
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

extension KeyPairsModule {
    /// Register all key pair actions with the ActionRegistry
    ///
    /// This method creates ModuleActionRegistration entries for:
    /// - Key pair deletion
    /// - Key pair creation/import
    /// - Private key file saving
    /// - Public key file saving
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard let tui = tui else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register delete key pair action
        actions.append(ModuleActionRegistration(
            identifier: "keypair.delete",
            title: "Delete Key Pair",
            keybinding: "d",
            viewModes: [.keyPairs],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteKeyPair(screen: screen)
            },
            description: "Delete the selected SSH key pair",
            requiresConfirmation: true,
            category: .security
        ))

        // Register create/import key pair action
        actions.append(ModuleActionRegistration(
            identifier: "keypair.create",
            title: "Import Key Pair",
            keybinding: "c",
            viewModes: [.keyPairs],
            handler: { [weak tui] screen in
                guard let tui = tui else { return }
                tui.changeView(to: .keyPairCreate)
                tui.keyPairCreateForm = KeyPairCreateForm()
                tui.keyPairCreateFormState = FormBuilderState(fields: tui.keyPairCreateForm.buildFields(
                    selectedFieldId: nil,
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                ))
            },
            description: "Import a new SSH key pair from public key",
            requiresConfirmation: false,
            category: .security
        ))

        // Register view key pair detail action
        actions.append(ModuleActionRegistration(
            identifier: "keypair.view_detail",
            title: "View Details",
            keybinding: nil,
            viewModes: [.keyPairs],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.viewKeyPairDetail(screen: screen)
            },
            description: "View detailed information about the selected key pair",
            requiresConfirmation: false,
            category: .security
        ))

        // Register save private key action
        actions.append(ModuleActionRegistration(
            identifier: "keypair.save_private_key",
            title: "Save Private Key",
            keybinding: nil,
            viewModes: [.keyPairDetail],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.savePrivateKeyAction(screen: screen)
            },
            description: "Save the private key to ~/.ssh directory",
            requiresConfirmation: false,
            category: .security
        ))

        // Register save public key action
        actions.append(ModuleActionRegistration(
            identifier: "keypair.save_public_key",
            title: "Save Public Key",
            keybinding: nil,
            viewModes: [.keyPairDetail],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.savePublicKeyAction(screen: screen)
            },
            description: "Save the public key to ~/.ssh directory",
            requiresConfirmation: false,
            category: .security
        ))

        // Register submit keypair creation action
        actions.append(ModuleActionRegistration(
            identifier: "keypair.submit_creation",
            title: "Submit Key Pair Creation",
            keybinding: nil,
            viewModes: [.keyPairCreate],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.submitKeyPairCreation(screen: screen)
            },
            description: "Submit the key pair creation form",
            requiresConfirmation: false,
            category: .security
        ))

        return actions
    }
}

// MARK: - Key Pair Action Implementations

extension KeyPairsModule {
    /// Delete the selected key pair
    ///
    /// Prompts for confirmation before deleting the key pair from OpenStack.
    /// Updates the UI and refreshes the key pair cache after successful deletion.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteKeyPair(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .keyPairs else { return }

        let filteredKeyPairs = FilterUtils.filterKeyPairs(
            tui.cacheManager.cachedKeyPairs,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredKeyPairs.count else {
            tui.statusMessage = "No key pair selected"
            return
        }

        let keyPair = filteredKeyPairs[tui.viewCoordinator.selectedIndex]
        let keyPairName = keyPair.name ?? "Unknown"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(
            keyPairName,
            screen: screen,
            screenRows: tui.screenRows,
            screenCols: tui.screenCols
        ) else {
            tui.statusMessage = "Key pair deletion cancelled"
            return
        }

        // Show deletion in progress
        tui.statusMessage = "Deleting key pair '\(keyPairName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let client = tui.client

            try await client.deleteKeyPair(name: keyPairName)
            tui.statusMessage = "Key pair '\(keyPairName)' deleted successfully"

            // Adjust selection if we deleted the last item
            let newKeyPairCount = filteredKeyPairs.count - 1
            if tui.viewCoordinator.selectedIndex >= newKeyPairCount && newKeyPairCount > 0 {
                tui.viewCoordinator.selectedIndex = newKeyPairCount - 1
            } else if newKeyPairCount == 0 {
                tui.viewCoordinator.selectedIndex = 0
            }

            // Refresh keypair cache
            let _ = await DataProviderRegistry.shared.fetchData(for: "keypairs", priority: .onDemand, forceRefresh: true)

            // Clear screen to remove graphical artifacts from deleted keypair
            SwiftNCurses.clear(WindowHandle(screen))
            await tui.draw(screen: screen)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete key pair '\(keyPairName)'"
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
            tui.statusMessage = "Failed to delete key pair '\(keyPairName)': \(error.localizedDescription)"
        }
    }

    /// View key pair detail
    ///
    /// Navigates to the key pair detail view for the selected key pair.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func viewKeyPairDetail(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .keyPairs else { return }

        let filteredKeyPairs = FilterUtils.filterKeyPairs(
            tui.cacheManager.cachedKeyPairs,
            query: tui.searchQuery
        )
        guard tui.viewCoordinator.selectedIndex < filteredKeyPairs.count else {
            tui.statusMessage = "No key pair selected"
            return
        }

        let keyPair = filteredKeyPairs[tui.viewCoordinator.selectedIndex]
        tui.viewCoordinator.selectedResource = keyPair
        tui.changeView(to: .keyPairDetail, resetSelection: false)
    }

    /// Save the private key to a file
    ///
    /// Saves the private key to ~/.ssh/<keyPairName> with proper permissions (600).
    /// Creates the .ssh directory if it doesn't exist with permissions (700).
    ///
    /// - Parameter privateKey: The private key content to save
    /// - Parameter keyPairName: The name of the key pair (used as filename)
    /// - Returns: True if save was successful, false otherwise
    internal func savePrivateKeyToFile(privateKey: String, keyPairName: String) async -> Bool {
        do {
            // Get the user's home directory
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let sshDirURL = homeURL.appendingPathComponent(".ssh")

            // Create .ssh directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: sshDirURL.path) {
                try FileManager.default.createDirectory(at: sshDirURL, withIntermediateDirectories: true, attributes: nil)
                // Set proper permissions for .ssh directory (700)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sshDirURL.path)
            }

            // Create private key file path
            let privateKeyURL = sshDirURL.appendingPathComponent(keyPairName)

            // Write the private key to file
            try privateKey.write(to: privateKeyURL, atomically: true, encoding: .utf8)

            // Set proper permissions for private key file (600)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyURL.path)

            return true
        } catch {
            // Log error but don't fail the whole operation
            return false
        }
    }

    /// Save the public key to a file
    ///
    /// Saves the public key to ~/.ssh/<keyPairName>.pub with proper permissions (644).
    /// Creates the .ssh directory if it doesn't exist with permissions (700).
    ///
    /// - Parameter publicKey: The public key content to save
    /// - Parameter keyPairName: The name of the key pair (used as filename base)
    /// - Returns: True if save was successful, false otherwise
    internal func savePublicKeyToFile(publicKey: String, keyPairName: String) async -> Bool {
        do {
            // Get the user's home directory
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let sshDirURL = homeURL.appendingPathComponent(".ssh")

            // Create .ssh directory if it doesn't exist (should already exist from private key saving)
            if !FileManager.default.fileExists(atPath: sshDirURL.path) {
                try FileManager.default.createDirectory(at: sshDirURL, withIntermediateDirectories: true, attributes: nil)
                // Set proper permissions for .ssh directory (700)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sshDirURL.path)
            }

            // Create public key file path with .pub extension
            let publicKeyURL = sshDirURL.appendingPathComponent("\(keyPairName).pub")

            // Write the public key to file
            try publicKey.write(to: publicKeyURL, atomically: true, encoding: .utf8)

            // Set proper permissions for public key file (644 - readable by others)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: publicKeyURL.path)

            return true
        } catch {
            // Log error but don't fail the whole operation
            return false
        }
    }

    /// Action handler for saving private key
    ///
    /// Gets the selected key pair and saves its private key to a file.
    ///
    /// - Parameter screen: The ncurses screen pointer
    private func savePrivateKeyAction(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard let keyPair = tui.viewCoordinator.selectedResource as? KeyPair else {
            tui.statusMessage = "No key pair selected"
            return
        }

        guard let privateKey = keyPair.privateKey, !privateKey.isEmpty else {
            tui.statusMessage = "No private key available for this key pair"
            return
        }

        let keyPairName = keyPair.name ?? "unknown_key"
        let success = await savePrivateKeyToFile(privateKey: privateKey, keyPairName: keyPairName)

        if success {
            tui.statusMessage = "Private key saved to ~/.ssh/\(keyPairName)"
        } else {
            tui.statusMessage = "Failed to save private key"
        }
    }

    /// Action handler for saving public key
    ///
    /// Gets the selected key pair and saves its public key to a file.
    ///
    /// - Parameter screen: The ncurses screen pointer
    private func savePublicKeyAction(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard let keyPair = tui.viewCoordinator.selectedResource as? KeyPair else {
            tui.statusMessage = "No key pair selected"
            return
        }

        guard let publicKey = keyPair.publicKey, !publicKey.isEmpty else {
            tui.statusMessage = "No public key available for this key pair"
            return
        }

        let keyPairName = keyPair.name ?? "unknown_key"
        let success = await savePublicKeyToFile(publicKey: publicKey, keyPairName: keyPairName)

        if success {
            tui.statusMessage = "Public key saved to ~/.ssh/\(keyPairName).pub"
        } else {
            tui.statusMessage = "Failed to save public key"
        }
    }

    /// Submit key pair creation from the key pair create form
    ///
    /// Validates the form data and creates/imports a new key pair in OpenStack.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func submitKeyPairCreation(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Validate the form
        let validationErrors = tui.keyPairCreateForm.validateForm()
        if !validationErrors.isEmpty {
            tui.statusMessage = "Validation errors: \(validationErrors.joined(separator: "; "))"
            return
        }

        let keyPairName = tui.keyPairCreateForm.keyPairName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Show creation in progress
        tui.statusMessage = "Creating key pair '\(keyPairName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            let trimmedKey = tui.keyPairCreateForm.publicKey.trimmingCharacters(in: .whitespacesAndNewlines)

            // Validate and potentially fix public key format
            var formattedKey = trimmedKey

            // Check if the key is properly formatted (has spaces between components)
            let keyComponents = trimmedKey.components(separatedBy: " ")
            if keyComponents.count < 2 {
                // Key might be missing spaces - try to insert them
                if trimmedKey.starts(with: "ssh-rsa") {
                    let keyData = String(trimmedKey.dropFirst(7))
                    formattedKey = "ssh-rsa \(keyData)"
                } else if trimmedKey.starts(with: "ssh-ed25519") {
                    let keyData = String(trimmedKey.dropFirst(11))
                    formattedKey = "ssh-ed25519 \(keyData)"
                } else if trimmedKey.starts(with: "ecdsa-sha2-nistp256") {
                    let keyData = String(trimmedKey.dropFirst(19))
                    formattedKey = "ecdsa-sha2-nistp256 \(keyData)"
                } else if trimmedKey.starts(with: "ecdsa-sha2-nistp384") {
                    let keyData = String(trimmedKey.dropFirst(19))
                    formattedKey = "ecdsa-sha2-nistp384 \(keyData)"
                } else if trimmedKey.starts(with: "ecdsa-sha2-nistp521") {
                    let keyData = String(trimmedKey.dropFirst(19))
                    formattedKey = "ecdsa-sha2-nistp521 \(keyData)"
                } else if trimmedKey.starts(with: "ssh-dss") {
                    let keyData = String(trimmedKey.dropFirst(7))
                    formattedKey = "ssh-dss \(keyData)"
                }
            }

            // Additional validation
            let components = formattedKey.components(separatedBy: " ")
            if components.count >= 2 {
                let keyData = components[1]
                // Validate minimum key lengths for different types
                if formattedKey.starts(with: "ssh-ed25519") && keyData.count < 68 {
                    tui.statusMessage = "WARNING - ed25519 key data seems too short (expected ~68 chars, got \(keyData.count))"
                } else if formattedKey.starts(with: "ssh-rsa") && keyData.count < 300 {
                    tui.statusMessage = "WARNING - RSA key data seems too short (expected ~300+ chars, got \(keyData.count))"
                }
            } else {
                tui.statusMessage = "Invalid public key format"
                return
            }

            _ = try await tui.client.createKeyPair(
                name: keyPairName,
                publicKey: formattedKey
            )

            tui.statusMessage = "Key pair '\(keyPairName)' created successfully"

            // Refresh keypair cache and return to list
            let _ = await DataProviderRegistry.shared.fetchData(for: "keypairs", priority: .onDemand, forceRefresh: true)
            tui.changeView(to: .keyPairs, resetSelection: false)

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create key pair '\(keyPairName)'"
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
            tui.statusMessage = "Failed to create key pair '\(keyPairName)': \(error.localizedDescription)"
        }
    }
}
