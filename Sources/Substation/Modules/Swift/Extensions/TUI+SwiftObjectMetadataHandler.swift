import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Swift Object Metadata Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handles input for the Swift object metadata form using the universal handler
    ///
    /// This handler manages the object metadata form which allows users to update
    /// metadata (such as content type) for a single Swift storage object.
    ///
    /// - Parameters:
    ///   - ch: The input character code from ncurses
    ///   - screen: The ncurses screen pointer for rendering
    internal func handleSwiftObjectMetadataInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = swiftObjectMetadataFormState
        var localForm = swiftObjectMetadataForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.swiftObjectMetadataFormState = formState
                self.swiftObjectMetadataForm = form
                await self.submitSwiftObjectMetadata(screen: screen)
            },
            onCancel: {
                self.changeView(to: .swiftContainerDetail, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        swiftObjectMetadataFormState = localFormState
        swiftObjectMetadataForm = localForm
    }

    private func submitSwiftObjectMetadata(screen: OpaquePointer?) async {
        let containerName = swiftObjectMetadataForm.containerName
        let objectName = swiftObjectMetadataForm.objectName

        statusMessage = "Updating metadata for object '\(objectName)'..."
        await self.draw(screen: screen)

        do {
            // Build update request
            let contentType = swiftObjectMetadataForm.contentType.trimmingCharacters(in: .whitespacesAndNewlines)

            // Create update request
            let request = UpdateSwiftObjectMetadataRequest(
                metadata: [:],
                removeMetadataKeys: [],
                contentType: contentType.isEmpty ? nil : contentType
            )

            try await client.swift.updateObjectMetadata(
                containerName: containerName,
                objectName: objectName,
                request: request
            )

            // Refresh object list
            await dataManager.refreshAllData()

            // Return to object list
            statusMessage = "Object metadata updated successfully"
            changeView(to: .swiftContainerDetail, resetSelection: false)
            await self.draw(screen: screen)
        } catch {
            statusMessage = "Failed to update metadata: \(error.localizedDescription)"
            await self.draw(screen: screen)
        }
    }
}

// MARK: - SwiftObjectMetadataForm Protocol Conformance

// SwiftObjectMetadataForm naturally conforms to all three protocols through its
// existing methods: updateFromFormState, buildFields, and validateForm
extension SwiftObjectMetadataForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
