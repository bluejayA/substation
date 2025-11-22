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

// MARK: - Network Create Input Handler (Universal Pattern)
//
// This is the NEW universal pattern that replaces 165 lines of duplicated code
// with just 36 lines. This demonstrates the power of the universal form handler.

@MainActor
extension TUI {

    /// Handle input for Network create form using the universal handler
    internal func handleNetworkCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = networkCreateFormState
        var localForm = networkCreateForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Make sure form state is synced before submission
                self.networkCreateFormState = formState
                self.networkCreateForm = form
                if let module = ModuleRegistry.shared.module(for: "networks") as? NetworksModule {
                    await module.submitNetworkCreation(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .networks, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        networkCreateFormState = localFormState
        networkCreateForm = localForm
    }
}

// MARK: - NetworkCreateForm Protocol Conformance Adapters

extension NetworkCreateForm {
    /// Adapter for FormStateRebuildable protocol
    ///
    /// This adapter wraps the form's buildFields method to make the formState parameter
    /// required instead of optional, conforming to the FormStateRebuildable protocol.
    ///
    /// - Parameters:
    ///   - selectedFieldId: The ID of the currently selected field
    ///   - activeFieldId: The ID of the currently active (editing) field
    ///   - formState: The current form builder state
    /// - Returns: Array of form fields for rendering
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        // Call the original method with named parameter to avoid recursion
        return buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: Optional(formState))
    }
}

// MARK: - Protocol Conformance Declaration
// NetworkCreateForm naturally conforms to FormStateUpdatable and FormValidatable
// through its existing methods. FormStateRebuildable is satisfied via the adapter above.
extension NetworkCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
