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
                await self.resourceOperations.submitNetworkCreation(screen: screen)
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
    /// Adapter for FormStateRebuildable - makes formState required instead of optional
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        // Call the original method with named parameter to avoid recursion
        return buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: Optional(formState))
    }
}

// Declare protocol conformance after adapters
extension NetworkCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
