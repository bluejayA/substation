import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Swift Container Create Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handles input for the Swift container create form using the universal handler
    ///
    /// This handler manages the container creation form which allows users to specify
    /// a name for the new Swift storage container. It uses the UniversalFormInputHandler
    /// for consistent form navigation and input handling.
    ///
    /// - Parameters:
    ///   - ch: The input character code from ncurses
    ///   - screen: The ncurses screen pointer for rendering
    internal func handleSwiftContainerCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = swiftContainerCreateFormState
        var localForm = swiftContainerCreateForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.swiftContainerCreateFormState = formState
                self.swiftContainerCreateForm = form
                await self.submitSwiftContainerCreation(screen: screen)
            },
            onCancel: {
                self.changeView(to: .swift, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        swiftContainerCreateFormState = localFormState
        swiftContainerCreateForm = localForm
    }

    private func submitSwiftContainerCreation(screen: OpaquePointer?) async {
        let containerName = swiftContainerCreateForm.containerName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        statusMessage = "Creating container '\(containerName)'..."
        await self.draw(screen: screen)

        do {
            let request = CreateSwiftContainerRequest(
                name: containerName,
                metadata: [:],
                readACL: nil,
                writeACL: nil
            )

            try await client.swift.createContainer(request: request)

            // Refresh container list
            await dataManager.refreshAllData()

            // Return to container list
            statusMessage = "Container '\(containerName)' created successfully"
            changeView(to: .swift, resetSelection: false)
            await self.draw(screen: screen)
        } catch {
            statusMessage = "Failed to create container: \(error.localizedDescription)"
            await self.draw(screen: screen)
        }
    }
}

// MARK: - SwiftContainerCreateForm Protocol Conformance

// SwiftContainerCreateForm naturally conforms to all three protocols through its
// existing methods: updateFromFormState, buildFields, and validateForm
extension SwiftContainerCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
