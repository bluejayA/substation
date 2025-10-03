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

// MARK: - Security Group Create Input Handler

@MainActor
extension TUI {

    internal func handleSecurityGroupCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if a field is currently active (being edited)
        let isFieldActive = securityGroupCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                securityGroupCreateFormState.nextField()
                securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                securityGroupCreateFormState.previousField()
                securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field or add space
            if !isFieldActive {
                // Not active: activate the field
                securityGroupCreateFormState.activateCurrentField()
                securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Active: add space as character for text fields
                if let currentField = securityGroupCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        securityGroupCreateFormState.handleCharacterInput(" ")
                        securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
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
                securityGroupCreateFormState.deactivateCurrentField()
                securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Create security group if form is valid
                let validation = securityGroupCreateForm.validateForm()
                if validation.isValid {
                    await resourceOperations.submitSecurityGroupCreation(screen: screen)
                } else {
                    securityGroupCreateFormState.showValidationErrors = true
                    statusMessage = "Error: \(validation.errors.first!)"
                    await self.draw(screen: screen)
                }
            }

        case Int32(259), Int32(258): // KEY_UP/DOWN - Navigate between fields
            if !isFieldActive {
                if ch == Int32(259) {
                    securityGroupCreateFormState.previousField()
                } else {
                    securityGroupCreateFormState.nextField()
                }
                securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC - Deactivate field or cancel creation
            if isFieldActive {
                securityGroupCreateFormState.deactivateCurrentField()
                securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
                await self.draw(screen: screen)
            } else {
                self.changeView(to: .securityGroups, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE - Remove character
            if isFieldActive {
                let handled = securityGroupCreateFormState.handleSpecialKey(ch)
                if handled {
                    securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Handle character input for text fields
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    securityGroupCreateFormState.handleCharacterInput(char)
                    securityGroupCreateForm.updateFromFormState(securityGroupCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}

// MARK: - SecurityGroupCreateForm FormState Integration

extension SecurityGroupCreateForm {
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Update form data from FormBuilderState
        let fields = formState.fields

        for field in fields {
            switch field {
            case .text(let textField):
                if textField.id == SecurityGroupCreateFieldId.name.rawValue {
                    self.securityGroupName = textField.value
                } else if textField.id == SecurityGroupCreateFieldId.description.rawValue {
                    self.securityGroupDescription = textField.value
                }
            default:
                break
            }
        }

        // Update navigation state
        if let currentFieldId = formState.getCurrentFieldId() {
            // Map field ID back to SecurityGroupCreateField enum
            switch currentFieldId {
            case SecurityGroupCreateFieldId.name.rawValue:
                self.currentField = .name
            case SecurityGroupCreateFieldId.description.rawValue:
                self.currentField = .description
            default:
                break
            }
        }

        // Update edit mode based on active field
        self.fieldEditMode = formState.isCurrentFieldActive()
    }
}
