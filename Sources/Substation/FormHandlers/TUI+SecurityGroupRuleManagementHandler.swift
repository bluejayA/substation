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

    var securityGroupRuleListNavigationContext: NavigationContext {
        guard let form = securityGroupRuleManagementForm else { return .custom }
        let ruleCount = form.securityGroup.securityGroupRules?.count ?? 0
        return .list(maxIndex: max(0, ruleCount - 1))
    }

    internal func handleSecurityGroupRuleManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard var form = securityGroupRuleManagementForm else { return }

        // Handle list mode separately (no FormBuilder)
        if form.shouldShowRulesList() {
            // Try common navigation first
            let context = securityGroupRuleListNavigationContext
            if await handleSecurityGroupRuleListNavigation(ch, context: context) {
                await self.draw(screen: screen)
                return
            }

            // Handle view-specific keys
            await handleSecurityGroupRuleListInput(ch, screen: screen, form: &form)
            securityGroupRuleManagementForm = form
            return
        }

        // Handle create/edit mode with FormBuilder
        if form.shouldShowCreateForm() || form.shouldShowEditForm() {
            let isFieldActive = form.ruleCreateFormState.isCurrentFieldActive()

            // Try common navigation when NOT in field edit mode
            if !isFieldActive {
                let fieldCount = form.ruleCreateFormState.fields.count
                if await NavigationInputHandler.handleFormNavigation(ch, fieldCount: fieldCount, tui: self) {
                    await self.draw(screen: screen)
                    return
                }
            }

            // Handle view-specific form input
            await handleSecurityGroupRuleFormInput(ch, screen: screen, form: &form, isFieldActive: isFieldActive)
            securityGroupRuleManagementForm = form
        }
    }

    /// Handle common navigation for rule list
    private func handleSecurityGroupRuleListNavigation(_ ch: Int32, context: NavigationContext) async -> Bool {
        switch context {
        case .list(let maxIndex):
            return await NavigationInputHandler.handleListNavigation(ch, maxIndex: maxIndex, tui: self)
        default:
            return false
        }
    }

    private func handleSecurityGroupRuleListInput(_ ch: Int32, screen: OpaquePointer?, form: inout SecurityGroupRuleManagementForm) async {
        switch ch {
        case Int32(65), Int32(67): // A or C - Add/Create new rule
            form.enterCreateMode()

        case Int32(32): // SPACE - Edit selected rule
            form.enterEditMode()

        case Int32(127), Int32(330): // DELETE - Delete selected rule
            await resourceOperations.deleteSecurityGroupRule(screen: screen)

        case Int32(27): // ESC - Back to security groups
            self.changeView(to: .securityGroups, resetSelection: false)

        default:
            break
        }
    }

    private func handleSecurityGroupRuleFormInput(_ ch: Int32, screen: OpaquePointer?, form: inout SecurityGroupRuleManagementForm, isFieldActive: Bool) async {
        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                form.ruleCreateFormState.nextField()
                form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                    selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: form.ruleCreateFormState
                ))
                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                form.ruleCreateFormState.previousField()
                form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                    selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: form.ruleCreateFormState
                ))
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field or add space
            if !isFieldActive {
                form.ruleCreateFormState.activateCurrentField()
                form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                await self.draw(screen: screen)
            } else {
                if let currentField = form.ruleCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        form.ruleCreateFormState.handleCharacterInput(" ")
                        form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                        await self.draw(screen: screen)
                    case .selector:
                        form.ruleCreateFormState.toggleCurrentField()
                        form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit
            needsRedraw = true
            if isFieldActive {
                form.ruleCreateFormState.deactivateCurrentField()
                form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                    selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: form.ruleCreateFormState
                ))
                await self.draw(screen: screen)
            } else {
                if form.shouldShowCreateForm() {
                    await resourceOperations.createSecurityGroupRule(screen: screen)
                } else {
                    await resourceOperations.updateSecurityGroupRule(screen: screen)
                }
            }

        case Int32(259), Int32(258): // UP/DOWN - Navigate in selector when active
            if isFieldActive {
                let handled = form.ruleCreateFormState.handleSpecialKey(ch)
                if handled {
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        case Int32(27): // ESC - Deactivate field or cancel
            if isFieldActive {
                form.ruleCreateFormState.deactivateCurrentField()
                form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                await self.draw(screen: screen)
            } else {
                form.returnToListMode()
                await self.draw(screen: screen)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE
            if isFieldActive {
                let handled = form.ruleCreateFormState.handleSpecialKey(ch)
                if handled {
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    form.ruleCreateFormState.handleCharacterInput(char)
                    form.ruleCreateForm.updateFromFormState(form.ruleCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}
