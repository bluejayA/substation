import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftTUI
import MemoryKit

// MARK: - Network Create Input Handler

@MainActor
extension TUI {

    internal func handleNetworkCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = networkCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                networkCreateFormState.nextField()
                networkCreateForm.updateFromFormState(networkCreateFormState)

                networkCreateFormState = FormBuilderState(
                    fields: networkCreateForm.buildFields(
                        selectedFieldId: networkCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: networkCreateFormState
                    ),
                    preservingStateFrom: networkCreateFormState
                )

                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                networkCreateFormState.previousField()
                networkCreateForm.updateFromFormState(networkCreateFormState)

                networkCreateFormState = FormBuilderState(
                    fields: networkCreateForm.buildFields(
                        selectedFieldId: networkCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: networkCreateFormState
                    ),
                    preservingStateFrom: networkCreateFormState
                )

                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field, toggle, or add space character
            if !isFieldActive {
                if let currentField = networkCreateFormState.getCurrentField() {
                    switch currentField {
                    case .toggle:
                        networkCreateFormState.toggleCurrentField()
                        networkCreateForm.updateFromFormState(networkCreateFormState)
                        networkCreateFormState = FormBuilderState(
                            fields: networkCreateForm.buildFields(
                                selectedFieldId: networkCreateFormState.getCurrentFieldId(),
                                activeFieldId: networkCreateFormState.getActiveFieldId(),
                                formState: networkCreateFormState
                            ),
                            preservingStateFrom: networkCreateFormState
                        )
                        await self.draw(screen: screen)
                    default:
                        networkCreateFormState.activateCurrentField()
                        networkCreateForm.updateFromFormState(networkCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            } else {
                if let currentField = networkCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        networkCreateFormState.handleCharacterInput(" ")
                        networkCreateForm.updateFromFormState(networkCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            needsRedraw = true
            if isFieldActive {
                networkCreateFormState.deactivateCurrentField()
                networkCreateForm.updateFromFormState(networkCreateFormState)

                networkCreateFormState = FormBuilderState(
                    fields: networkCreateForm.buildFields(
                        selectedFieldId: networkCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: networkCreateFormState
                    ),
                    preservingStateFrom: networkCreateFormState
                )

                await self.draw(screen: screen)
            } else {
                let errors = networkCreateForm.validateForm()
                if errors.isEmpty {
                    await resourceOperations.submitNetworkCreation(screen: screen)
                } else {
                    statusMessage = "Validation errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                }
            }

        case Int32(260), Int32(261): // KEY_LEFT/RIGHT - Navigate in text field
            if isFieldActive {
                let handled = networkCreateFormState.handleSpecialKey(ch)
                if handled {
                    networkCreateForm.updateFromFormState(networkCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        case Int32(259), Int32(258): // KEY_UP/DOWN - Navigate between fields
            if !isFieldActive {
                if ch == Int32(259) {
                    networkCreateFormState.previousField()
                } else {
                    networkCreateFormState.nextField()
                }
                networkCreateForm.updateFromFormState(networkCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC - Exit edit mode or cancel creation
            if isFieldActive {
                networkCreateFormState.deactivateCurrentField()
                networkCreateForm.updateFromFormState(networkCreateFormState)
                await self.draw(screen: screen)
            } else {
                self.changeView(to: .networks, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE - Remove character
            if isFieldActive {
                let handled = networkCreateFormState.handleSpecialKey(ch)
                if handled {
                    networkCreateForm.updateFromFormState(networkCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    networkCreateFormState.handleCharacterInput(char)
                    networkCreateForm.updateFromFormState(networkCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}
