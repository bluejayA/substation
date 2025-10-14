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

    internal func handleSwiftContainerCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = swiftContainerCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                swiftContainerCreateFormState.nextField()
                swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = swiftContainerCreateFormState.getCurrentField() {
                switch currentField {
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        swiftContainerCreateFormState.activateCurrentField()
                        swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        swiftContainerCreateFormState.handleCharacterInput(" ")
                        swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                swiftContainerCreateFormState.deactivateCurrentField()
                swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = swiftContainerCreateForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                await submitSwiftContainerCreation(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = swiftContainerCreateFormState.handleSpecialKey(ch)
                if handled {
                    swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    swiftContainerCreateFormState.previousField()
                } else {
                    swiftContainerCreateFormState.nextField()
                }
                swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                swiftContainerCreateFormState.cancelCurrentField()
                swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to container list
                self.changeView(to: .swift, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = swiftContainerCreateFormState.handleSpecialKey(ch)
                if handled {
                    swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    swiftContainerCreateFormState.handleCharacterInput(Character(scalar))
                    swiftContainerCreateForm.updateFromFormState(swiftContainerCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        swiftContainerCreateFormState = FormBuilderState(
            fields: swiftContainerCreateForm.buildFields(
                selectedFieldId: swiftContainerCreateFormState.getCurrentFieldId(),
                activeFieldId: swiftContainerCreateFormState.getActiveFieldId(),
                formState: swiftContainerCreateFormState
            ),
            preservingStateFrom: swiftContainerCreateFormState
        )
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
