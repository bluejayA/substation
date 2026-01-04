// Sources/Substation/Modules/Images/ImagesModule+Actions.swift
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

extension ImagesModule {
    /// Register all image actions with the ActionRegistry
    ///
    /// - Returns: Array of action registrations
    func registerActions() -> [ModuleActionRegistration] {
        guard tui != nil else {
            return []
        }

        var actions: [ModuleActionRegistration] = []

        // Register create image action (SHIFT-C)
        actions.append(ModuleActionRegistration(
            identifier: "image.create",
            title: "Create Image",
            keybinding: "C",
            viewModes: [.images],
            handler: { [weak self] screen in
                guard let self = self, let tui = self.tui else { return }
                tui.imageCreateForm = ImageCreateForm()
                tui.imageCreateFormState = FormBuilderState(fields: tui.imageCreateForm.buildFields(
                    selectedFieldId: ImageCreateFieldId.name.rawValue,
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                ))
                tui.changeView(to: .imageCreate, resetSelection: true)
            },
            description: "Create a new image",
            requiresConfirmation: false,
            category: .general
        ))

        // Register delete image action
        actions.append(ModuleActionRegistration(
            identifier: "image.delete",
            title: "Delete Image",
            keybinding: "d",
            viewModes: [.images],
            handler: { [weak self] screen in
                guard let self = self else { return }
                await self.deleteImage(screen: screen)
            },
            description: "Delete the selected image",
            requiresConfirmation: true,
            category: .general
        ))

        return actions
    }
}

// MARK: - Image Action Implementations

extension ImagesModule {
    /// Create a new image from the form data
    ///
    /// Creates the image metadata first, then uploads the image file.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func createImage(screen: OpaquePointer?) async {
        guard let tui = tui else { return }

        // Validate the form
        let errors = tui.imageCreateForm.validateForm()
        if !errors.isEmpty {
            tui.imageCreateFormState.showValidationErrors = true
            tui.statusMessage = "Please fix validation errors"
            return
        }

        let imageName = tui.imageCreateForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let filePath = FilePathCompleter.expandPath(tui.imageCreateForm.imageFilePath)

        // Show creation in progress
        tui.statusMessage = "Creating image '\(imageName)'..."
        tui.renderCoordinator.needsRedraw = true
        await tui.draw(screen: screen)

        do {
            // Build the create request
            let request = tui.imageCreateForm.buildCreateRequest()

            // Create the image metadata
            let createdImage = try await tui.client.glance.createImage(request: request)

            tui.statusMessage = "Image created, uploading file..."
            tui.renderCoordinator.needsRedraw = true
            await tui.draw(screen: screen)

            // Read and upload the image file
            let fileURL = URL(fileURLWithPath: filePath)
            let imageData = try Data(contentsOf: fileURL)

            try await tui.client.glance.uploadImageData(id: createdImage.id, data: imageData)

            // Add to cached images
            tui.cacheManager.cachedImages.insert(createdImage, at: 0)

            tui.statusMessage = "Image '\(imageName)' created and uploaded successfully"

            // Reset form and navigate back
            tui.imageCreateForm = ImageCreateForm()
            tui.imageCreateFormState = FormBuilderState(fields: [])
            tui.changeView(to: .images, resetSelection: false)
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to create image '\(imageName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Glance endpoint not found"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, let message):
                if code == 409 {
                    tui.statusMessage = "\(baseMsg): Image with this name already exists"
                } else if code == 413 {
                    tui.statusMessage = "\(baseMsg): Image file too large"
                } else {
                    tui.statusMessage = "\(baseMsg): HTTP \(code) - \(message ?? "Unknown error")"
                }
            case .networkError(let err):
                tui.statusMessage = "\(baseMsg): Network error - \(err.localizedDescription)"
            case .decodingError(let err):
                tui.statusMessage = "\(baseMsg): Data error - \(err.localizedDescription)"
            case .encodingError(let err):
                tui.statusMessage = "\(baseMsg): Encoding error - \(err.localizedDescription)"
            case .configurationError(let msg):
                tui.statusMessage = "\(baseMsg): Configuration error - \(msg)"
            case .missingRequiredField(let field):
                tui.statusMessage = "\(baseMsg): Missing field - \(field)"
            case .invalidResponse:
                tui.statusMessage = "\(baseMsg): Invalid response from server"
            case .invalidURL:
                tui.statusMessage = "\(baseMsg): Invalid URL"
            case .performanceEnhancementsNotAvailable:
                tui.statusMessage = "\(baseMsg): Service unavailable"
            }
        } catch {
            tui.statusMessage = "Failed to create image '\(imageName)': \(error.localizedDescription)"
        }
    }

    /// Delete the selected image
    ///
    /// Prompts for confirmation before deleting the image from OpenStack.
    ///
    /// - Parameter screen: The ncurses screen pointer
    internal func deleteImage(screen: OpaquePointer?) async {
        guard let tui = tui else { return }
        guard tui.viewCoordinator.currentView == .images else { return }

        let filteredImages = FilterUtils.filterImages(tui.cacheManager.cachedImages, query: tui.searchQuery)
        guard tui.viewCoordinator.selectedIndex < filteredImages.count else {
            tui.statusMessage = "No image selected"
            return
        }

        let image = filteredImages[tui.viewCoordinator.selectedIndex]
        let imageName = image.name ?? "Unnamed image"

        // Confirm deletion
        guard await ViewUtils.confirmDelete(imageName, screen: screen, screenRows: tui.screenRows, screenCols: tui.screenCols) else {
            tui.statusMessage = "Image deletion cancelled"
            return
        }

        // Show deletion in progress
        tui.statusMessage = "Deleting image '\(imageName)'..."
        tui.renderCoordinator.needsRedraw = true

        do {
            try await tui.client.deleteImage(id: image.id)

            // Remove from cached images
            if let index = tui.cacheManager.cachedImages.firstIndex(where: { $0.id == image.id }) {
                tui.cacheManager.cachedImages.remove(at: index)
            }

            // Adjust selection if needed
            let newMaxIndex = max(0, filteredImages.count - 2)
            tui.viewCoordinator.selectedIndex = min(tui.viewCoordinator.selectedIndex, newMaxIndex)

            tui.statusMessage = "Image '\(imageName)' deleted successfully"
            tui.refreshAfterOperation()

        } catch let error as OpenStackError {
            let baseMsg = "Failed to delete image '\(imageName)'"
            switch error {
            case .authenticationFailed:
                tui.statusMessage = "\(baseMsg): Authentication failed - check credentials"
            case .endpointNotFound:
                tui.statusMessage = "\(baseMsg): Endpoint not found - check service configuration"
            case .unexpectedResponse:
                tui.statusMessage = "\(baseMsg): Unexpected response from server"
            case .httpError(let code, _):
                if code == 409 {
                    tui.statusMessage = "\(baseMsg): Image is in use and cannot be deleted"
                } else if code == 404 {
                    tui.statusMessage = "\(baseMsg): Image not found"
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
            tui.statusMessage = "Failed to delete image '\(imageName)': \(error.localizedDescription)"
        }
    }
}
