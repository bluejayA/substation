import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient

// MARK: - Swift Container Web Access Form Handler

extension TUI {

    /// Handle input for Swift container web access form using the universal handler
    internal func handleSwiftContainerWebAccessInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = swiftContainerWebAccessFormState
        var localForm = swiftContainerWebAccessForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.swiftContainerWebAccessFormState = formState
                self.swiftContainerWebAccessForm = form
                await self.submitSwiftContainerWebAccess(screen: screen)
            },
            onCancel: {
                self.changeView(to: .swift, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        swiftContainerWebAccessFormState = localFormState
        swiftContainerWebAccessForm = localForm
    }

    /// Submit Swift container web access form
    private func submitSwiftContainerWebAccess(screen: OpaquePointer?) async {
        let containerName = swiftContainerWebAccessForm.containerName
        guard !containerName.isEmpty else {
            statusMessage = "No container selected"
            changeView(to: .swift, resetSelection: false)
            return
        }

        do {
            let isEnabling = swiftContainerWebAccessForm.webAccessEnabled == "enabled"

            // When enabling, also set web-index metadata to serve index.html by default
            let metadata = isEnabling ? ["web-index": "index.html"] : [:]

            let updateRequest = UpdateSwiftContainerMetadataRequest(
                metadata: metadata,
                readACL: isEnabling ? ".r:*,.rlistings" : ""
            )

            try await client.swift.updateContainerMetadata(
                containerName: containerName,
                request: updateRequest
            )

            statusMessage = isEnabling ?
                "Web access enabled for '\(containerName)'" :
                "Web access disabled for '\(containerName)'"

            Logger.shared.logUserAction(isEnabling ? "enable_container_web_access" : "disable_container_web_access", details: [
                "containerName": containerName,
                "url": swiftContainerWebAccessForm.webURL
            ])

            // Return to container list
            changeView(to: .swift, resetSelection: false)
            await self.draw(screen: screen)
        } catch {
            statusMessage = "Failed to update web access: \(error.localizedDescription)"
            await self.draw(screen: screen)
        }
    }
}

// MARK: - SwiftContainerWebAccessForm Protocol Conformance

// SwiftContainerWebAccessForm already has all required methods
extension SwiftContainerWebAccessForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
