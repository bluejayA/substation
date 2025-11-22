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
    ///
    /// This is a dual-mode handler that manages both list navigation and form input modes.
    /// It properly tracks state transitions between modes to prevent state corruption.
    ///
    /// **Mode Behaviors:**
    /// - List mode: Navigate rules with UP/DOWN, edit with SPACE, add with A/C, delete with DEL
    /// - Form mode: Full form input handling via UniversalFormInputHandler
    ///
    /// - Parameters:
    ///   - ch: The input character code
    ///   - screen: The ncurses screen pointer for rendering
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

            // Track if cancel was triggered to properly update state
            var wasCancelled = false

            await universalFormInputHandler.handleInput(
                ch,
                screen: screen,
                formState: &localFormState,
                form: &localFormAdapter,
                onSubmit: { [self] formState, formAdapter in
                    // Create a mutable copy for submission
                    var mutableForm = form
                    mutableForm.ruleCreateFormState = formState
                    mutableForm.ruleCreateForm = formAdapter.form
                    self.securityGroupRuleManagementForm = mutableForm

                    if let module = ModuleRegistry.shared.module(for: "securitygroups") as? SecurityGroupsModule {
                        if mutableForm.shouldShowCreateForm() {
                            await module.createSecurityGroupRule(screen: screen)
                        } else {
                            await module.updateSecurityGroupRule(screen: screen)
                        }
                    }
                },
                onCancel: {
                    wasCancelled = true
                }
            )

            // Handle cancel by returning to list mode
            if wasCancelled {
                form.returnToListMode()
                securityGroupRuleManagementForm = form
                await self.draw(screen: screen)
                return true
            }

            // Update form with changes from input handler
            form.ruleCreateFormState = localFormState
            form.ruleCreateForm = localFormAdapter.form

            // Rebuild formState after changes, preserving active field state
            let currentActiveFieldId = localFormState.getActiveFieldId()
            form.ruleCreateFormState = FormBuilderState(fields: form.ruleCreateForm.buildFields(
                selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                activeFieldId: currentActiveFieldId,
                formState: form.ruleCreateFormState
            ), preservingStateFrom: form.ruleCreateFormState)

            securityGroupRuleManagementForm = form
            return true  // Form mode handles all input
        }

        securityGroupRuleManagementForm = form
        return false  // Input not handled
    }

    /// Handle list-specific input keys for security group rule management
    ///
    /// Processes keyboard input when in list mode for rule navigation and actions.
    /// This method handles mode transitions and delegates to module actions.
    ///
    /// **Supported Keys:**
    /// - A/C: Enter create mode for new rule
    /// - SPACE: Enter edit mode for selected rule
    /// - DELETE/BACKSPACE: Delete selected rule
    /// - ESC: Return to security groups list
    ///
    /// - Parameters:
    ///   - ch: The input character code
    ///   - screen: The ncurses screen pointer for rendering
    ///   - form: The management form (inout for state updates)
    /// - Returns: Bool indicating if the input was handled
    private func handleSecurityGroupRuleListInput(_ ch: Int32, screen: OpaquePointer?, form: inout SecurityGroupRuleManagementForm) async -> Bool {
        switch ch {
        case Int32(65), Int32(67): // A or C - Add/Create new rule
            form.enterCreateMode()
            await self.draw(screen: screen)
            return true

        case Int32(32): // SPACE - Edit selected rule
            form.enterEditMode()
            await self.draw(screen: screen)
            return true

        case Int32(127), Int32(330): // DELETE - Delete selected rule
            if let module = ModuleRegistry.shared.module(for: "securitygroups") as? SecurityGroupsModule {
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
