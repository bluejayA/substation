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

// MARK: - Volume Snapshot Management Input Handler

@MainActor
extension TUI {

    /// Handle input for volume snapshot management form using the universal handler
    internal func handleVolumeSnapshotManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = volumeSnapshotManagementFormState
        var localForm = volumeSnapshotManagementForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.volumeSnapshotManagementFormState = formState
                self.volumeSnapshotManagementForm = form
                await self.actions.executeVolumeSnapshotCreation(screen: screen)
            },
            onCancel: {
                self.changeView(to: .volumeSnapshotManagement, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        volumeSnapshotManagementFormState = localFormState
        volumeSnapshotManagementForm = localForm
    }
}

// MARK: - VolumeSnapshotManagementForm Protocol Conformance

extension VolumeSnapshotManagementForm {
    /// Adapter for FormStateRebuildable - makes formState non-optional
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return self.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: Optional.some(formState))
    }

    /// Validate the form and return error messages
    func validateForm() -> [String] {
        if let error = getValidationError() {
            return [error]
        }
        return []
    }
}

// Declare protocol conformance
extension VolumeSnapshotManagementForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
