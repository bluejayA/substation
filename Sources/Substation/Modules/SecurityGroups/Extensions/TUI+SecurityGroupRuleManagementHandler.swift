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

    /// Handle input for Security Group Rule Management using universal handler pattern
    /// This is a dual-mode handler: list navigation + form input
    /// - Returns: Bool indicating if the input was handled (true) or should be passed to global handlers (false)
    internal func handleSecurityGroupRuleManagementInput(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        guard var form = securityGroupRuleManagementForm else { return false }

        // Mode detection: list vs form
        if form.shouldShowRulesList() {
            // LIST MODE: Handle list navigation using form's own methods
            switch ch {
            case Int32(259), Int32(107):  // UP arrow or k
                form.moveSelectionUp()
                securityGroupRuleManagementForm = form
                await self.draw(screen: screen)
                return true

            case Int32(258), Int32(106):  // DOWN arrow or j
                form.moveSelectionDown()
                securityGroupRuleManagementForm = form
                await self.draw(screen: screen)
                return true

            default:
                break
            }

            // Handle list-specific keys (A/C for add, SPACE for edit, DELETE, ESC)
            let handled = await handleSecurityGroupRuleListInput(ch, screen: screen, form: &form)
            securityGroupRuleManagementForm = form
            return handled
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

                    if let module = ModuleRegistry.shared.module(for: "securityGroups") as? SecurityGroupsModule {
                        if form.shouldShowCreateForm() {
                            await module.createSecurityGroupRule(screen: screen)
                        } else {
                            await module.updateSecurityGroupRule(screen: screen)
                        }
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

            securityGroupRuleManagementForm = form
            return true  // Form mode handles all input
        }

        securityGroupRuleManagementForm = form
        return false  // Input not handled
    }

    /// Handle list-specific input keys
    /// - Returns: Bool indicating if the input was handled
    private func handleSecurityGroupRuleListInput(_ ch: Int32, screen: OpaquePointer?, form: inout SecurityGroupRuleManagementForm) async -> Bool {
        switch ch {
        case Int32(65), Int32(67): // A or C - Add/Create new rule
            form.enterCreateMode()
            return true

        case Int32(32): // SPACE - Edit selected rule
            form.enterEditMode()
            return true

        case Int32(127), Int32(330): // DELETE - Delete selected rule
            if let module = ModuleRegistry.shared.module(for: "securityGroups") as? SecurityGroupsModule {
                await module.deleteSecurityGroupRule(screen: screen)
            }
            return true

        case Int32(27): // ESC - Back to security groups
            self.changeView(to: .securityGroups, resetSelection: false)
            return true

        default:
            return false  // Allow global handlers (? for help, : for commands)
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
