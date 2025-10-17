import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Security Group Rule Management Input Handler

@MainActor
extension TUI {

    var securityGroupRuleListNavigationContext: NavigationContext {
        guard let form = securityGroupRuleManagementForm else { return .custom }
        let ruleCount = form.securityGroup.securityGroupRules?.count ?? 0
        return .list(maxIndex: max(0, ruleCount - 1))
    }

    /// Handle input for Security Group Rule Management using universal handler pattern
    /// This is a dual-mode handler: list navigation + form input
    internal func handleSecurityGroupRuleManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        guard var form = securityGroupRuleManagementForm else { return }

        // Mode detection: list vs form
        if form.shouldShowRulesList() {
            // LIST MODE: Handle list navigation
            let context = securityGroupRuleListNavigationContext
            if await handleSecurityGroupRuleListNavigation(ch, context: context) {
                await self.draw(screen: screen)
                return
            }
            // Handle list-specific keys (A/C for add, SPACE for edit, DELETE, ESC)
            await handleSecurityGroupRuleListInput(ch, screen: screen, form: &form)
            securityGroupRuleManagementForm = form
            return
        }

        // FORM MODE: Use universal handler
        if form.shouldShowCreateForm() || form.shouldShowEditForm() {
            var localFormState = form.ruleCreateFormState
            var localFormAdapter = SecurityGroupRuleCreateFormAdapter(form: form.ruleCreateForm)

            await universalFormInputHandler.handleInput(
                ch,
                screen: screen,
                formState: &localFormState,
                form: &localFormAdapter,
                onSubmit: { formState, formAdapter in
                    // Sync state before submission
                    form.ruleCreateFormState = formState
                    form.ruleCreateForm = formAdapter.form

                    if form.shouldShowCreateForm() {
                        await self.resourceOperations.createSecurityGroupRule(screen: screen)
                    } else {
                        await self.resourceOperations.updateSecurityGroupRule(screen: screen)
                    }
                },
                onCancel: {
                    form.returnToListMode()
                }
            )

            // Update form with changes
            form.ruleCreateFormState = localFormState
            form.ruleCreateForm = localFormAdapter.form

            // Rebuild formState after changes
            form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                activeFieldId: nil,
                formState: form.ruleCreateFormState
            ))
        }

        securityGroupRuleManagementForm = form
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

    /// Handle list-specific input keys
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
}

// MARK: - SecurityGroupRuleCreateForm Adapter

/// Adapter to make SecurityGroupRuleCreateForm work with universal handler
/// Form has validateForm() returning (isValid: Bool, errors: [String])
/// but FormValidatable expects validateForm() returning [String]
struct SecurityGroupRuleCreateFormAdapter: FormStateUpdatable, FormStateRebuildable, FormValidatable {
    var form: SecurityGroupRuleCreateForm

    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return form.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: formState)
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        form.updateFromFormState(formState)
    }

    func validateForm() -> [String] {
        let validation = form.validateForm()
        return validation.isValid ? [] : validation.errors
    }
}
