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

// MARK: - Server Group Create Input Handler

@MainActor
extension TUI {

    internal func handleServerGroupCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if a field is currently active (being edited)
        let isFieldActive = serverGroupCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                serverGroupCreateFormState.nextField()
                serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                serverGroupCreateFormState.previousField()
                serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field or toggle selector
            if !isFieldActive {
                // Not active: activate the field
                serverGroupCreateFormState.activateCurrentField()
                serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Active: check field type to determine behavior
                if let currentField = serverGroupCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text, .number:
                        // For text/number fields, add space as character
                        serverGroupCreateFormState.handleCharacterInput(" ")
                        serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                        await self.draw(screen: screen)
                    case .selector:
                        // For selector fields in active state, space toggles selection
                        serverGroupCreateFormState.toggleCurrentField()
                        serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            needsRedraw = true
            if isFieldActive {
                // Deactivate the current field
                serverGroupCreateFormState.deactivateCurrentField()
                serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Create server group if form is valid
                let errors = serverGroupCreateForm.validate()
                if errors.isEmpty {
                    await resourceOperations.submitServerGroupCreation()
                } else {
                    serverGroupCreateFormState.showValidationErrors = true
                    statusMessage = "Error: \(errors.first!)"
                    await self.draw(screen: screen)
                }
            }

        case Int32(259), Int32(258): // KEY_UP/DOWN - Navigate in selector or between fields
            if isFieldActive {
                let handled = serverGroupCreateFormState.handleSpecialKey(ch)
                if handled {
                    serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    serverGroupCreateFormState.previousField()
                } else {
                    serverGroupCreateFormState.nextField()
                }
                serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC - Deactivate field or cancel creation
            if isFieldActive {
                serverGroupCreateFormState.deactivateCurrentField()
                serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                await self.draw(screen: screen)
            } else {
                self.changeView(to: .serverGroups, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE - Remove character
            if isFieldActive {
                let handled = serverGroupCreateFormState.handleSpecialKey(ch)
                if handled {
                    serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Handle character input for text fields
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    serverGroupCreateFormState.handleCharacterInput(char)
                    serverGroupCreateForm.updateFromFormState(serverGroupCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}

// MARK: - ServerGroupCreateForm FormState Integration

extension ServerGroupCreateForm {
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Update form data from FormBuilderState
        let fields = formState.fields

        for field in fields {
            switch field {
            case .text(let textField):
                if textField.id == ServerGroupCreateFieldId.name.rawValue {
                    self.serverGroupName = textField.value
                }
            case .selector(let selectorField):
                if selectorField.id == ServerGroupCreateFieldId.policy.rawValue {
                    if let selectedId = selectorField.selectedItemId,
                       let policy = ServerGroupPolicy(rawValue: selectedId) {
                        self.selectedPolicy = policy
                    }
                }
            default:
                break
            }
        }

        // Update navigation state
        if let currentFieldId = formState.getCurrentFieldId() {
            // Map field ID back to ServerGroupCreateField enum
            switch currentFieldId {
            case ServerGroupCreateFieldId.name.rawValue:
                self.currentField = .name
            case ServerGroupCreateFieldId.policy.rawValue:
                self.currentField = .policy
            default:
                break
            }
        }

        // Update edit mode based on active field
        self.fieldEditMode = formState.isCurrentFieldActive()

        // Update policy selection mode based on selector state
        if let currentField = formState.getCurrentField(),
           case .selector(let selectorField) = currentField,
           selectorField.id == ServerGroupCreateFieldId.policy.rawValue {
            self.policySelectionMode = selectorField.isActive
            if let selectorState = formState.selectorStates[selectorField.id] {
                self.selectedPolicyIndex = selectorState.highlightedIndex
            }
        } else {
            self.policySelectionMode = false
        }
    }
}
