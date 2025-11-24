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

// MARK: - Snapshot Management Input Handler

@MainActor
extension TUI {

    var snapshotManagementNavigationContext: NavigationContext {
        let fieldCount = snapshotManagementFormState.fields.count
        return .form(fieldCount: fieldCount)
    }

    /// Handle input for snapshot management form using the universal handler
    internal func handleSnapshotManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = snapshotManagementFormState
        var localForm = snapshotManagementForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.snapshotManagementFormState = formState
                self.snapshotManagementForm = form
                guard let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule else {
                    Logger.shared.logError("Failed to get ServersModule from registry", context: [:])
                    self.statusMessage = "Error: Servers module not available"
                    return
                }
                await module.executeSnapshotCreation(screen: screen)
            },
            onCancel: {
                self.changeView(to: .serverSnapshotManagement, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        snapshotManagementFormState = localFormState
        snapshotManagementForm = localForm
    }
}

// MARK: - SnapshotManagementForm Protocol Conformance

extension SnapshotManagementForm {
    /// Adapter for FormStateRebuildable - makes formState non-optional
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return self.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: Optional.some(formState))
    }

    /// Update form from FormBuilderState
    mutating func updateFromFormState(_ state: FormBuilderState) {
        if let nameState = state.textFieldStates[SnapshotFieldId.name.rawValue] {
            self.snapshotName = nameState.value
        }
        if let descState = state.textFieldStates[SnapshotFieldId.description.rawValue] {
            self.snapshotDescription = descState.value
        }
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
extension SnapshotManagementForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
