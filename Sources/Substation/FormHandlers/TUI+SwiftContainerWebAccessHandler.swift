import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient

// MARK: - Swift Container Web Access Form Handler

extension TUI {

    internal func handleSwiftContainerWebAccessInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftContainerWebAccessFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftContainerWebAccessFormState.nextField()
                swiftContainerWebAccessForm.updateFromFormState(swiftContainerWebAccessFormState)
                forceRedraw()
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftContainerWebAccessFormState.getCurrentField() {
                switch currentField {
                case .selector(let selectorField):
                    // For this simple 2-option selector, toggle directly without activation
                    // Get current state
                    let currentState = swiftContainerWebAccessFormState.getSelectorState(selectorField.id)
                    let currentSelectedId = currentState?.selectedItemId ?? selectorField.selectedItemId ?? "disabled"

                    // Toggle between "enabled" and "disabled"
                    let newSelectedId = currentSelectedId == "enabled" ? "disabled" : "enabled"

                    // Update selector state directly
                    if var state = swiftContainerWebAccessFormState.selectorStates[selectorField.id] {
                        state.selectedItemId = newSelectedId
                        // Update highlightedIndex to match the new selection
                        if let newIndex = selectorField.items.firstIndex(where: { $0.id == newSelectedId }) {
                            state.highlightedIndex = newIndex
                        }
                        swiftContainerWebAccessFormState.selectorStates[selectorField.id] = state
                    }

                    // Sync to form model
                    swiftContainerWebAccessForm.updateFromFormState(swiftContainerWebAccessFormState)

                    // Rebuild fields to reflect the updated selector state and info text
                    swiftContainerWebAccessFormState = FormBuilderState(
                        fields: swiftContainerWebAccessForm.buildFields(
                            selectedFieldId: swiftContainerWebAccessFormState.getCurrentFieldId(),
                            activeFieldId: swiftContainerWebAccessFormState.getActiveFieldId(),
                            formState: swiftContainerWebAccessFormState
                        ),
                        preservingStateFrom: swiftContainerWebAccessFormState
                    )

                    forceRedraw()
                    await self.draw(screen: screen)
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            // Submit form - container name is stored in the form
            let containerName = swiftContainerWebAccessForm.containerName
            guard !containerName.isEmpty else {
                statusMessage = "No container selected"
                changeView(to: .swift)
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
                changeView(to: .swift)
            } catch {
                statusMessage = "Failed to update web access: \(error.localizedDescription)"
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                // Navigate within the active selector
                let handled = swiftContainerWebAccessFormState.handleSpecialKey(ch)
                if handled {
                    swiftContainerWebAccessForm.updateFromFormState(swiftContainerWebAccessFormState)
                    forceRedraw()
                    await self.draw(screen: screen)
                }
            } else {
                // Navigate between fields
                if ch == Int32(259) {
                    swiftContainerWebAccessFormState.previousField()
                } else {
                    swiftContainerWebAccessFormState.nextField()
                }
                swiftContainerWebAccessForm.updateFromFormState(swiftContainerWebAccessFormState)
                forceRedraw()
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            // Cancel and return to container list
            changeView(to: .swift)

        default:
            break
        }
    }
}
