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

// MARK: - Volume Create Input Handler

@MainActor
extension TUI {

    internal func handleVolumeCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if a field is currently active
        let isFieldActive = volumeCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field or cycle select options
            if isFieldActive {
                if let currentField = volumeCreateFormState.getCurrentField() {
                    switch currentField {
                    case .select:
                        // For select fields, cycle through options
                        volumeCreateFormState.toggleCurrentField()
                        volumeCreateForm.updateFromFormState(volumeCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            } else {
                volumeCreateFormState.nextField()
                volumeCreateForm.updateFromFormState(volumeCreateFormState)
                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field or cycle select options backwards
            if isFieldActive {
                if let currentField = volumeCreateFormState.getCurrentField() {
                    if case .select = currentField {
                        volumeCreateFormState.cyclePreviousOption()
                        volumeCreateForm.updateFromFormState(volumeCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            } else {
                volumeCreateFormState.previousField()
                volumeCreateForm.updateFromFormState(volumeCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field or add space character
            if !isFieldActive {
                // Not active: activate the field
                volumeCreateFormState.activateCurrentField()
                volumeCreateForm.updateFromFormState(volumeCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Active: check field type to determine behavior
                if let currentField = volumeCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text, .number:
                        // For text/number fields, add space as character
                        volumeCreateFormState.handleCharacterInput(" ")
                        volumeCreateForm.updateFromFormState(volumeCreateFormState)
                        await self.draw(screen: screen)
                    case .toggle, .select:
                        // For toggle/select fields, space toggles
                        volumeCreateFormState.toggleCurrentField()
                        volumeCreateForm.updateFromFormState(volumeCreateFormState)
                        await self.draw(screen: screen)
                    case .selector, .multiSelect:
                        // For selector/multiselect fields, space toggles selection
                        volumeCreateFormState.toggleCurrentField()
                        volumeCreateForm.updateFromFormState(volumeCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            needsRedraw = true
            if isFieldActive {
                // Exit field editing/selection mode
                volumeCreateFormState.deactivateCurrentField()
                volumeCreateForm.updateFromFormState(volumeCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form if valid
                if volumeCreateForm.isValid() {
                    await resourceOperations.submitVolumeCreation(screen: screen)
                } else {
                    let errors = volumeCreateForm.validate()
                    statusMessage = "Validation failed: \(errors.first ?? "Unknown error")"
                    await self.draw(screen: screen)
                }
            }

        case Int32(27): // ESC - Cancel field editing or cancel creation
            if isFieldActive {
                // Normal deactivation
                volumeCreateFormState.deactivateCurrentField()
                volumeCreateForm.updateFromFormState(volumeCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Cancel and return to volume list
                self.changeView(to: .volumes, resetSelection: false)
            }

        case Int32(127), Int32(8): // BACKSPACE - Delete character
            if isFieldActive {
                let handled = volumeCreateFormState.handleSpecialKey(ch)
                if handled {
                    volumeCreateForm.updateFromFormState(volumeCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        case 258, 259: // DOWN/UP - Navigate within active field or between fields
            if isFieldActive {
                // Normal navigation within active field
                let handled = volumeCreateFormState.handleSpecialKey(ch)
                if handled {
                    volumeCreateForm.updateFromFormState(volumeCreateFormState)
                    await self.draw(screen: screen)
                }
            } else {
                // Navigate between fields
                if ch == 258 { // DOWN
                    volumeCreateFormState.nextField()
                } else { // UP
                    volumeCreateFormState.previousField()
                }
                volumeCreateForm.updateFromFormState(volumeCreateFormState)
                await self.draw(screen: screen)
            }

        default:
            // Handle character input for text fields (excluding SPACE which is handled above)
            if isFieldActive && ch > 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    volumeCreateFormState.handleCharacterInput(char)
                    volumeCreateForm.updateFromFormState(volumeCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        // IMPORTANT: Pass previous state to preserve navigation, search, and activation state
        volumeCreateFormState = FormBuilderState(
            fields: volumeCreateForm.buildFields(
                selectedFieldId: volumeCreateFormState.getCurrentFieldId(),
                activeFieldId: volumeCreateFormState.getActiveFieldId(),
                formState: volumeCreateFormState
            ),
            preservingStateFrom: volumeCreateFormState
        )
    }
}
