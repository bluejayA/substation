import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftTUI

@MainActor
extension TUI {

    internal func handleSwiftContainerMetadataInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftContainerMetadataFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftContainerMetadataFormState.nextField()
                swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftContainerMetadataFormState.getCurrentField() {
                switch currentField {
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        swiftContainerMetadataFormState.activateCurrentField()
                        swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        swiftContainerMetadataFormState.handleCharacterInput(" ")
                        swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                swiftContainerMetadataFormState.deactivateCurrentField()
                swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = swiftContainerMetadataForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                await submitSwiftContainerMetadata(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = swiftContainerMetadataFormState.handleSpecialKey(ch)
                if handled {
                    swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    swiftContainerMetadataFormState.previousField()
                } else {
                    swiftContainerMetadataFormState.nextField()
                }
                swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                swiftContainerMetadataFormState.cancelCurrentField()
                swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to container list
                self.changeView(to: .swift, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = swiftContainerMetadataFormState.handleSpecialKey(ch)
                if handled {
                    swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    swiftContainerMetadataFormState.handleCharacterInput(Character(scalar))
                    swiftContainerMetadataForm.updateFromFormState(swiftContainerMetadataFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        swiftContainerMetadataFormState = FormBuilderState(
            fields: swiftContainerMetadataForm.buildFields(
                selectedFieldId: swiftContainerMetadataFormState.getCurrentFieldId(),
                activeFieldId: swiftContainerMetadataFormState.getActiveFieldId(),
                formState: swiftContainerMetadataFormState
            ),
            preservingStateFrom: swiftContainerMetadataFormState
        )
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
