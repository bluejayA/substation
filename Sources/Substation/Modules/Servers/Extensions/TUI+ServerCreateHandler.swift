import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses

// MARK: - Server Create Form Input Handler

@MainActor
extension TUI {

    /// Handle input for Server create form using universal handler
    /// Server form has custom TAB behavior for boot source and flavor mode switching
    internal func handleServerCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        var localFormState = serverCreateFormState
        var localForm = serverCreateForm

        // Custom key handler for TAB mode switching
        let customHandler: @MainActor @Sendable (Int32, inout FormBuilderState, inout ServerCreateForm, OpaquePointer?) async -> Bool = { ch, formState, form, screen in
            // Intercept TAB when in active mode for source and flavor fields
            if ch == Int32(9) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField() {
                    if case .selector(let selector) = field {
                        // Source field: Toggle boot source mode (image/volume)
                        if selector.id == ServerCreateFieldId.source.rawValue {
                            form.toggleBootSource()
                            if form.bootSource == .image {
                                form.selectedVolumeID = nil
                            } else {
                                form.selectedImageID = nil
                            }
                            // Rebuild state to reflect mode change
                            formState = FormBuilderState(fields: form.buildFields(
                                selectedFieldId: formState.getCurrentFieldId(),
                                activeFieldId: formState.getActiveFieldId(),
                                formState: formState
                            ))
                            await self.draw(screen: screen)
                            return true // Handled
                        }
                        // Flavor field: Toggle flavor selection mode (manual/workload-based)
                        else if selector.id == ServerCreateFieldId.flavor.rawValue {
                            form.toggleFlavorSelectionMode()
                            formState = FormBuilderState(fields: form.buildFields(
                                selectedFieldId: formState.getCurrentFieldId(),
                                activeFieldId: formState.getActiveFieldId(),
                                formState: formState
                            ))
                            await self.draw(screen: screen)
                            return true // Handled
                        }
                    }
                }
            }

            // Special handling for ESC in flavor category detail view
            if ch == Int32(27) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField(),
                   case .selector(let selector) = field,
                   selector.id == ServerCreateFieldId.flavor.rawValue,
                   form.flavorSelectionMode == .workloadBased,
                   form.selectedCategoryIndex != nil {
                    // Go back to category list
                    form.selectedCategoryIndex = nil
                    await self.draw(screen: screen)
                    return true // Handled
                }
            }

            // Special handling for SPACE in flavor workload mode
            if ch == Int32(32) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField(),
                   case .selector(let selector) = field,
                   selector.id == ServerCreateFieldId.flavor.rawValue,
                   form.flavorSelectionMode == .workloadBased {
                    if form.selectedCategoryIndex == nil {
                        // Drill into category
                        form.selectedCategoryIndex = formState.selectorStates[selector.id]?.highlightedIndex
                        await self.draw(screen: screen)
                        return true // Handled
                    } else {
                        // Select flavor in category
                        let highlightedIndex = formState.selectorStates[selector.id]?.highlightedIndex ?? 0
                        let categories = FlavorSelectionView.generateWorkloadRecommendations(flavors: form.flavors)
                        if let categoryIdx = form.selectedCategoryIndex,
                           categoryIdx < categories.count {
                            let category = categories[categoryIdx]
                            if highlightedIndex < category.flavors.count {
                                let selectedFlavor = category.flavors[highlightedIndex]
                                form.selectedFlavorID = selectedFlavor.id
                                if var state = formState.selectorStates[selector.id] {
                                    state.selectedItemId = selectedFlavor.id
                                    formState.selectorStates[selector.id] = state
                                }
                                await self.draw(screen: screen)
                                return true // Handled
                            }
                        }
                    }
                }
            }

            // Special handling for ENTER in flavor category detail view
            if (ch == Int32(10) || ch == Int32(13)) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField(),
                   case .selector(let selector) = field,
                   selector.id == ServerCreateFieldId.flavor.rawValue,
                   form.flavorSelectionMode == .workloadBased {
                    // Clear category selection when exiting
                    form.selectedCategoryIndex = nil
                }
            }

            return false // Let universal handler process
        }

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Sync state before submission
                self.serverCreateFormState = formState
                self.serverCreateForm = form
                guard let module = ModuleRegistry.shared.module(for: "servers") as? ServersModule else {
                    Logger.shared.logError("Failed to get ServersModule from registry", context: [:])
                    self.statusMessage = "Error: Servers module not available"
                    return
                }
                await module.createServer()
            },
            onCancel: {
                self.viewCoordinator.currentView = .servers
                self.serverCreateForm.reset()
                self.serverCreateFormState = FormBuilderState(fields: [])
            },
            customKeyHandler: customHandler
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
        serverCreateFormState = localFormState
        serverCreateForm = localForm
    }
}

// MARK: - ServerCreateForm Protocol Conformance Adapters

extension ServerCreateForm {
    /// Adapter for FormStateRebuildable - makes formState non-optional
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return self.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: Optional.some(formState))
    }

    /// Adapter for FormValidatable
    func validateForm() -> [String] {
        return self.validate()
    }
}

// Declare protocol conformance
extension ServerCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
