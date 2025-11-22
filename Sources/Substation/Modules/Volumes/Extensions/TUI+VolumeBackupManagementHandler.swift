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

// MARK: - Volume Backup Management Input Handler

@MainActor
extension TUI {

    var volumeBackupManagementNavigationContext: NavigationContext {
        let fieldCount = volumeBackupManagementFormState.fields.count
        return .form(fieldCount: fieldCount)
    }

    /// Handle input for volume backup management form using the universal handler
    internal func handleVolumeBackupManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = volumeBackupManagementFormState
        var localForm = volumeBackupManagementForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.volumeBackupManagementFormState = formState
                self.volumeBackupManagementForm = form
                if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                    await module.executeVolumeBackupCreation(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .volumes, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        volumeBackupManagementFormState = localFormState
        volumeBackupManagementForm = localForm
    }
}

// MARK: - VolumeBackupManagementForm Protocol Conformance

extension VolumeBackupManagementForm {
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
extension VolumeBackupManagementForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
