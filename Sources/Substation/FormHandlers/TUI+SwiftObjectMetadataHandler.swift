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

    internal func handleSwiftObjectMetadataInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftObjectMetadataFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftObjectMetadataFormState.nextField()
                swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftObjectMetadataFormState.getCurrentField() {
                switch currentField {
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        swiftObjectMetadataFormState.activateCurrentField()
                        swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        swiftObjectMetadataFormState.handleCharacterInput(" ")
                        swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                swiftObjectMetadataFormState.deactivateCurrentField()
                swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = swiftObjectMetadataForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                await submitSwiftObjectMetadata(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = swiftObjectMetadataFormState.handleSpecialKey(ch)
                if handled {
                    swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    swiftObjectMetadataFormState.previousField()
                } else {
                    swiftObjectMetadataFormState.nextField()
                }
                swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                swiftObjectMetadataFormState.cancelCurrentField()
                swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to object list
                self.changeView(to: .swiftContainerDetail, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = swiftObjectMetadataFormState.handleSpecialKey(ch)
                if handled {
                    swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    swiftObjectMetadataFormState.handleCharacterInput(Character(scalar))
                    swiftObjectMetadataForm.updateFromFormState(swiftObjectMetadataFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        swiftObjectMetadataFormState = FormBuilderState(
            fields: swiftObjectMetadataForm.buildFields(
                selectedFieldId: swiftObjectMetadataFormState.getCurrentFieldId(),
                activeFieldId: swiftObjectMetadataFormState.getActiveFieldId(),
                formState: swiftObjectMetadataFormState
            ),
            preservingStateFrom: swiftObjectMetadataFormState
        )
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
