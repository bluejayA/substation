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

// MARK: - Server Group Create Input Handler

@MainActor
extension TUI {

    /// Handle input for server group create form using the universal handler
    internal func handleServerGroupCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = serverGroupCreateFormState
        var localForm = serverGroupCreateForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.serverGroupCreateFormState = formState
                self.serverGroupCreateForm = form
                if let module = ModuleRegistry.shared.module(for: "serverGroups") as? ServerGroupsModule {
                    await module.submitServerGroupCreation(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .serverGroups, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        serverGroupCreateFormState = localFormState
        serverGroupCreateForm = localForm
    }
}

// MARK: - ServerGroupCreateForm Protocol Conformance

extension ServerGroupCreateForm {
    /// Update form from FormBuilderState
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

    /// Adapter for FormValidatable - wraps validate() as validateForm()
    func validateForm() -> [String] {
        return self.validate()
    }
}

// Declare protocol conformance
extension ServerGroupCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
