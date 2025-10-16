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

// MARK: - Floating IP Create Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handle input for FloatingIP create form using the universal handler
    internal func handleFloatingIPCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Create local copies to pass as inout parameters
        // These are NOT captured by closures - closures access self properties directly
        var localFormState = floatingIPCreateFormState
        var localForm = floatingIPCreateForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters (not captured) to avoid exclusivity violation
                // Sync to self before submission so submitFloatingIPCreation can access the values
                self.floatingIPCreateFormState = formState
                self.floatingIPCreateForm = form
                await self.resourceOperations.submitFloatingIPCreation(screen: screen)
            },
            onCancel: {
                // Access self properties directly, don't capture local variables
                self.changeView(to: .floatingIPs, resetSelection: false)
            },
            customKeyHandler: { ch, formState, form, screen in
                // Handle form rebuilding when External Network selection changes
                let isFieldActive = formState.isCurrentFieldActive()

                // When ENTER is pressed on the External Network field while active
                if ch == 10 || ch == 13 {
                    if isFieldActive {
                        if let currentField = formState.getCurrentField() {
                            if case .selector(let field) = currentField,
                               field.id == FloatingIPCreateFieldId.floatingNetwork.rawValue {
                                // Deactivate the field first
                                formState.deactivateCurrentField()
                                form.updateFromFormState(formState)

                                // Rebuild the form with updated networks/subnets
                                let externalNetworks = self.resourceCache.networks.filter { $0.external == true }
                                let newFields = form.buildFields(
                                    externalNetworks: externalNetworks,
                                    subnets: self.resourceCache.subnets,
                                    selectedFieldId: formState.getCurrentFieldId(),
                                    activeFieldId: formState.getActiveFieldId(),
                                    formState: formState
                                )
                                // Create new form state with rebuilt fields, preserving existing state
                                formState = FormBuilderState(fields: newFields, preservingStateFrom: formState)

                                // Mark for redraw - don't call draw directly to avoid re-entry
                                self.needsRedraw = true
                                return true
                            }
                        }
                    }
                }

                return false
            }
        )

        // Sync changes back to actor-isolated properties
        floatingIPCreateFormState = localFormState
        floatingIPCreateForm = localForm
    }
}

// MARK: - FloatingIPCreateForm Protocol Conformance Adapters

extension FloatingIPCreateForm {
    /// Adapter for FormStateRebuildable - adds formState parameter
    /// Note: This adapter is not used by FloatingIP form because we use a custom key handler
    /// that rebuilds the form with proper network/subnet context
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        // This is a stub adapter - FloatingIP form uses custom rebuild logic
        // Return minimal fields to satisfy protocol, but real rebuilding happens in custom handler
        return [
            .text(FormFieldText(
                id: FloatingIPCreateFieldId.description.rawValue,
                label: "Description",
                value: description,
                placeholder: "Optional description",
                isRequired: false,
                isVisible: true,
                isSelected: false,
                isActive: false,
                cursorPosition: nil,
                validationError: nil
            ))
        ]
    }
}

// Declare protocol conformance after adapters
extension FloatingIPCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
