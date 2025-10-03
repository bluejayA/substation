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

// MARK: - Security Group Rule Management Input Handler

@MainActor
extension TUI {

    internal func handleSecurityGroupRuleManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard var form = securityGroupRuleManagementForm else { return }

        // Handle list mode separately (no FormBuilder)
        if form.shouldShowRulesList() {
            switch ch {
            case Int32(259): // UP
                form.moveSelectionUp()
                securityGroupRuleManagementForm = form

            case Int32(258): // DOWN
                form.moveSelectionDown()
                securityGroupRuleManagementForm = form

            case Int32(65), Int32(67): // A or C - Add/Create new rule
                form.enterCreateMode()
                securityGroupRuleManagementForm = form

            case Int32(32): // SPACE - Edit selected rule
                form.enterEditMode()
                securityGroupRuleManagementForm = form

            case Int32(127), Int32(330): // DELETE - Delete selected rule
                await resourceOperations.deleteSecurityGroupRule(screen: screen)

            case Int32(27): // ESC - Back to security groups
                self.changeView(to: .securityGroups, resetSelection: false)

            default:
                break
            }
            return
        }

        // Handle create/edit mode with FormBuilder
        if form.shouldShowCreateForm() || form.shouldShowEditForm() {
            let isFieldActive = form.ruleCreateFormState.isCurrentFieldActive()

            switch ch {
            case Int32(9): // TAB - Navigate to next field
                if !isFieldActive {
                    form.ruleCreateFormState.nextField()
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)

                    // Rebuild fields if protocol changed (affects visible fields)
                    form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                        selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: form.ruleCreateFormState
                    ))

                    securityGroupRuleManagementForm = form
                    await self.draw(screen: screen)
                }

            case 353: // SHIFT+TAB - Navigate to previous field
                if !isFieldActive {
                    form.ruleCreateFormState.previousField()
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)

                    // Rebuild fields if protocol changed (affects visible fields)
                    form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                        selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: form.ruleCreateFormState
                    ))

                    securityGroupRuleManagementForm = form
                    await self.draw(screen: screen)
                }

            case Int32(32): // SPACE - Activate field or add space
                if !isFieldActive {
                    // Activate the field
                    form.ruleCreateFormState.activateCurrentField()
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                    securityGroupRuleManagementForm = form
                    await self.draw(screen: screen)
                } else {
                    // Active: check field type
                    if let currentField = form.ruleCreateFormState.getCurrentField() {
                        switch currentField {
                        case .text:
                            // Add space as character
                            form.ruleCreateFormState.handleCharacterInput(" ")
                            form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                            securityGroupRuleManagementForm = form
                            await self.draw(screen: screen)
                        case .selector:
                            // Toggle selector
                            form.ruleCreateFormState.toggleCurrentField()
                            form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                            securityGroupRuleManagementForm = form
                            await self.draw(screen: screen)
                        default:
                            break
                        }
                    }
                }

            case Int32(10), Int32(13): // ENTER - Deactivate field or submit
                needsRedraw = true
                if isFieldActive {
                    // Deactivate field
                    form.ruleCreateFormState.deactivateCurrentField()
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)

                    // Rebuild fields if protocol/portType/remoteType changed (affects visible fields)
                    form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                        selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: form.ruleCreateFormState
                    ))

                    securityGroupRuleManagementForm = form
                    await self.draw(screen: screen)
                } else {
                    // Submit rule
                    if form.shouldShowCreateForm() {
                        await resourceOperations.createSecurityGroupRule(screen: screen)
                    } else {
                        await resourceOperations.updateSecurityGroupRule(screen: screen)
                    }
                }

            case Int32(259), Int32(258): // UP/DOWN - Navigate in selector or between fields
                if isFieldActive {
                    let handled = form.ruleCreateFormState.handleSpecialKey(ch)
                    if handled {
                        form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                        securityGroupRuleManagementForm = form
                        await self.draw(screen: screen)
                    }
                } else {
                    if ch == Int32(259) {
                        form.ruleCreateFormState.previousField()
                    } else {
                        form.ruleCreateFormState.nextField()
                    }
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)

                    // Rebuild fields if protocol changed
                    form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                        selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: form.ruleCreateFormState
                    ))

                    securityGroupRuleManagementForm = form
                    await self.draw(screen: screen)
                }

            case Int32(27): // ESC - Deactivate field or cancel
                if isFieldActive {
                    form.ruleCreateFormState.deactivateCurrentField()
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                    securityGroupRuleManagementForm = form
                    await self.draw(screen: screen)
                } else {
                    // Cancel and return to list
                    form.returnToListMode()
                    securityGroupRuleManagementForm = form
                    await self.draw(screen: screen)
                }

            case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE
                if isFieldActive {
                    let handled = form.ruleCreateFormState.handleSpecialKey(ch)
                    if handled {
                        form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                        securityGroupRuleManagementForm = form
                        await self.draw(screen: screen)
                    }
                }

            default:
                // Handle character input
                if isFieldActive && ch >= 32 && ch < 127 {
                    if let scalar = UnicodeScalar(Int(ch)) {
                        let char = Character(scalar)
                        form.ruleCreateFormState.handleCharacterInput(char)
                        form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                        securityGroupRuleManagementForm = form
                        await self.draw(screen: screen)
                    }
                }
            }
        }
    }
}
