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

        // Custom key handler for source type selector and source field selection
        let customHandler: @MainActor @Sendable (Int32, inout FormBuilderState, inout VolumeCreateForm, OpaquePointer?) async -> Bool = { ch, formState, form, screen in
            // Handle SPACE on selector fields
            if ch == Int32(32) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField() {
                    if case .selector(let selector) = field {
                        // Check if this is the source type selector
                        if selector.id == VolumeCreateFieldId.sourceType.rawValue {
                            // Toggle the selection
                            formState.toggleCurrentField()
                            form.updateFromFormState(formState)

                            // Rebuild form state to show/hide source selector based on new source type
                            formState = FormBuilderState(
                                fields: form.buildFields(
                                    selectedFieldId: formState.getCurrentFieldId(),
                                    activeFieldId: formState.getActiveFieldId(),
                                    formState: formState
                                ),
                                preservingStateFrom: formState
                            )

                            await self.draw(screen: screen)
                            return true // Handled
                        }

                        // Check if this is the source selector (image or snapshot)
                        if selector.id == VolumeCreateFieldId.source.rawValue {
                            // Toggle the selection
                            formState.toggleCurrentField()
                            form.updateFromFormState(formState)
                            await self.draw(screen: screen)
                            return true // Handled
                        }
                    }
                }
            }

            // Handle ENTER to confirm source type or source selection
            if (ch == Int32(10) || ch == Int32(13)) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField() {
                    if case .selector(let selector) = field {
                        // Check if this is the source type selector
                        if selector.id == VolumeCreateFieldId.sourceType.rawValue {
                            // Deactivate and rebuild form to show appropriate source selector
                            formState.deactivateCurrentField()
                            form.updateFromFormState(formState)

                            // Rebuild form state to show/hide source selector
                            formState = FormBuilderState(
                                fields: form.buildFields(
                                    selectedFieldId: formState.getCurrentFieldId(),
                                    activeFieldId: formState.getActiveFieldId(),
                                    formState: formState
                                ),
                                preservingStateFrom: formState
                            )

                            await self.draw(screen: screen)
                            return true // Handled
                        }

                        // Check if this is the source selector (confirming image/snapshot selection)
                        if selector.id == VolumeCreateFieldId.source.rawValue {
                            formState.deactivateCurrentField()
                            form.updateFromFormState(formState)
                            await self.draw(screen: screen)
                            return true // Handled
                        }
                    }
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
                // Receive formState and form as parameters to avoid exclusivity violation
                self.volumeCreateFormState = formState
                self.volumeCreateForm = form
                if let module = ModuleRegistry.shared.module(for: "volumes") as? VolumesModule {
                    await module.submitVolumeCreation(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .volumes, resetSelection: false)
            },
            customKeyHandler: customHandler
        )

        // Always rebuild after universal handler to ensure form reflects current state
        localFormState = FormBuilderState(
            fields: localForm.buildFields(
                selectedFieldId: localFormState.getCurrentFieldId(),
                activeFieldId: localFormState.getActiveFieldId(),
                formState: localFormState
            ),
            preservingStateFrom: localFormState
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
