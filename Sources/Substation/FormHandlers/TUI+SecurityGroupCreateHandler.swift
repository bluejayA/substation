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

// MARK: - Security Group Create Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handle input for SecurityGroup create form using the universal handler
    internal func handleSecurityGroupCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = securityGroupCreateFormState

        // Wrap form in adapter since SecurityGroupCreateForm.validateForm() returns tuple
        var localFormAdapter = SecurityGroupCreateFormAdapter(form: securityGroupCreateForm)

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localFormAdapter,
            onSubmit: { formState, formAdapter in
                // Receive formState and formAdapter as parameters to avoid exclusivity violation
                self.securityGroupCreateFormState = formState
                self.securityGroupCreateForm = formAdapter.form
                await self.resourceOperations.submitSecurityGroupCreation(screen: screen)
            },
            onCancel: {
                self.changeView(to: .securityGroups, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        securityGroupCreateFormState = localFormState
        securityGroupCreateForm = localFormAdapter.form
    }
}

// MARK: - SecurityGroupCreateForm Adapter

/// Adapter to make SecurityGroupCreateForm work with universal handler
/// SecurityGroupCreateForm has validateForm() -> (isValid: Bool, errors: [String])
/// but FormValidatable expects validateForm() -> [String]
struct SecurityGroupCreateFormAdapter: FormStateUpdatable, FormStateRebuildable, FormValidatable {
    var form: SecurityGroupCreateForm

    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return form.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: formState)
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Extract values from form state and update form
        if let name = formState.getTextValue(SecurityGroupCreateFieldId.name.rawValue) {
            form.securityGroupName = name
        }
        if let description = formState.getTextValue(SecurityGroupCreateFieldId.description.rawValue) {
            form.securityGroupDescription = description
        }

        // Update navigation state based on current field
        if let currentFieldId = formState.getCurrentFieldId() {
            switch currentFieldId {
            case SecurityGroupCreateFieldId.name.rawValue:
                form.currentField = .name
            case SecurityGroupCreateFieldId.description.rawValue:
                form.currentField = .description
            default:
                break
            }
        }

        // Update edit mode based on active field
        form.fieldEditMode = formState.isCurrentFieldActive()
    }

    func validateForm() -> [String] {
        let validation = form.validateForm()
        return validation.isValid ? [] : validation.errors
    }
}
