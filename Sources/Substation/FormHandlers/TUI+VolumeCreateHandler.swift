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

// MARK: - Volume Create Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handle input for Volume create form using the universal handler
    internal func handleVolumeCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = volumeCreateFormState
        var localForm = volumeCreateForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.volumeCreateFormState = formState
                self.volumeCreateForm = form
                await self.resourceOperations.submitVolumeCreation(screen: screen)
            },
            onCancel: {
                self.changeView(to: .volumes, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        volumeCreateFormState = localFormState
        volumeCreateForm = localForm
    }
}

// MARK: - VolumeCreateForm Protocol Conformance Adapters

extension VolumeCreateForm {
    /// Adapter for FormStateRebuildable - makes formState non-optional
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        // Call the original method with Optional.some
        return self.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: Optional.some(formState))
    }

    /// Adapter for FormValidatable - wraps validate() as validateForm()
    func validateForm() -> [String] {
        return self.validate()
    }
}

// Declare protocol conformance after adapters
extension VolumeCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
