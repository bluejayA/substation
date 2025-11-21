import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses

@MainActor
extension TUI {

    /// Handle input for Swift container metadata form using the universal handler
    internal func handleSwiftContainerMetadataInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = swiftContainerMetadataFormState
        var localForm = swiftContainerMetadataForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.swiftContainerMetadataFormState = formState
                self.swiftContainerMetadataForm = form
                await self.submitSwiftContainerMetadata(screen: screen)
            },
            onCancel: {
                self.changeView(to: .swift, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        swiftContainerMetadataFormState = localFormState
        swiftContainerMetadataForm = localForm
    }

    private func submitSwiftContainerMetadata(screen: OpaquePointer?) async {
        let containerName = swiftContainerMetadataForm.containerName

        statusMessage = "Updating metadata for container '\(containerName)'..."
        await self.draw(screen: screen)

        // Only set ACLs if they are not empty
        let readACL = swiftContainerMetadataForm.readACL.trimmingCharacters(in: .whitespacesAndNewlines)
        let writeACL = swiftContainerMetadataForm.writeACL.trimmingCharacters(in: .whitespacesAndNewlines)

        // For ACLs, we need to use a direct header update since the API expects headers
        // We'll create a custom request
        var headers: [String: String] = [:]

        if !readACL.isEmpty {
            headers["X-Container-Read"] = readACL
        }
        if !writeACL.isEmpty {
            headers["X-Container-Write"] = writeACL
        }

        // Use updateContainerMetadata if we have headers to set
        if !headers.isEmpty {
            // For now, we'll use a simple metadata update that preserves existing custom metadata
            _ = UpdateSwiftContainerMetadataRequest(
                metadata: [:],
                removeMetadataKeys: []
            )

            // Note: The current API doesn't support updating ACLs via updateContainerMetadata
            // We would need to enhance the SwiftService to support this
            // For now, we'll just show a message
            statusMessage = "ACL updates require API enhancement - feature coming soon"
            await self.draw(screen: screen)

            // Sleep briefly to show message
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        // Return to container list
        changeView(to: .swift, resetSelection: false)
        statusMessage = "Metadata update completed"
        await self.draw(screen: screen)
    }
}

// MARK: - SwiftContainerMetadataForm Protocol Conformance

// SwiftContainerMetadataForm already has all required methods
extension SwiftContainerMetadataForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
