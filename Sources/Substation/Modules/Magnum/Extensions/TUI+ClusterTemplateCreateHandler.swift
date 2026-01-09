// Sources/Substation/Modules/Magnum/Extensions/TUI+ClusterTemplateCreateHandler.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses

// MARK: - Cluster Template Create Form Input Handler

@MainActor
extension TUI {
    /// Handle input for Cluster Template create form using universal handler
    ///
    /// - Parameters:
    ///   - ch: The key code pressed
    ///   - screen: The ncurses screen pointer
    internal func handleClusterTemplateCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        var localFormState = clusterTemplateCreateFormState
        var localForm = clusterTemplateCreateForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Sync state before submission
                self.clusterTemplateCreateFormState = formState
                self.clusterTemplateCreateForm = form
                guard let module = ModuleRegistry.shared.module(for: "magnum") as? MagnumModule else {
                    Logger.shared.logError("Failed to get MagnumModule from registry", context: [:])
                    self.statusMessage = "Error: Magnum module not available"
                    return
                }
                await module.submitClusterTemplateCreate(tui: self)
            },
            onCancel: {
                self.viewCoordinator.currentView = .clusterTemplates
                self.clusterTemplateCreateForm = ClusterTemplateCreateForm()
                self.clusterTemplateCreateFormState = FormBuilderState(fields: [])
            },
            customKeyHandler: nil
        )

        // Always rebuild after universal handler to reflect any changes
        localFormState = FormBuilderState(
            fields: localForm.buildFields(
                selectedFieldId: localFormState.getCurrentFieldId(),
                activeFieldId: localFormState.getActiveFieldId(),
                formState: localFormState
            ),
            preservingStateFrom: localFormState
        )

        // Update actor-isolated properties
        clusterTemplateCreateFormState = localFormState
        clusterTemplateCreateForm = localForm
    }
}
