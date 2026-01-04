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

// MARK: - Barbican Secret Create Input Handler

@MainActor
extension TUI {

    /// Handle input for Barbican Secret create form using universal handler
    /// This form has 3 special input modes: payload editor, date selection, legacy selection
    internal func handleBarbicanSecretCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Special handling for payload edit mode (full-screen editor)
        if barbicanSecretCreateForm.payloadEditMode {
            await handlePayloadEditorInput(ch, screen: screen)
            return
        }

        // Normal form handling with universal handler
        var localFormState = barbicanSecretCreateFormState
        var localFormAdapter = BarbicanSecretCreateFormAdapter(form: barbicanSecretCreateForm)

        // Custom key handler for special field behaviors
        let customHandler: @MainActor @Sendable (Int32, inout FormBuilderState, inout BarbicanSecretCreateFormAdapter, OpaquePointer?) async -> Bool = { ch, formState, formAdapter, screen in
            // SPACE on payload field enters payload edit mode
            if ch == Int32(32) && !formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField() {
                    if case .text(let textField) = field,
                       textField.id == BarbicanSecretCreateFieldId.payload.rawValue {
                        formAdapter.form.payloadEditMode = true
                        await self.draw(screen: screen)
                        return true
                    }
                }
            }

            // ENTER on file path field loads the file
            if (ch == Int32(10) || ch == Int32(13)) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField() {
                    if case .text(let textField) = field,
                       textField.id == BarbicanSecretCreateFieldId.payloadFilePath.rawValue {
                        if let error = formAdapter.form.loadPayloadFromFile() {
                            self.statusMessage = error
                        } else {
                            self.statusMessage = "File loaded successfully"
                        }
                        return false // Let universal handler continue with deactivation
                    }
                }
            }

            return false // Let universal handler process
        }

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localFormAdapter,
            onSubmit: { formState, formAdapter in
                // Sync state before submission
                self.barbicanSecretCreateFormState = formState
                self.barbicanSecretCreateForm = formAdapter.form
                if let module = ModuleRegistry.shared.module(for: "barbican") as? BarbicanModule {
                    await module.createSecret(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .barbicanSecrets, resetSelection: false)
            },
            customKeyHandler: customHandler
        )

        // Update actor-isolated properties with modified local copies
        barbicanSecretCreateFormState = localFormState
        barbicanSecretCreateForm = localFormAdapter.form

        // Redraw with updated state to show selector overlays
        await self.draw(screen: screen)
    }

    // MARK: - Payload Editor Input Handler

    private func handlePayloadEditorInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(27): // ESC - Exit payload edit mode
            self.barbicanSecretCreateForm.payloadEditMode = false
            self.barbicanSecretCreateForm.flushPayloadBuffer()
            await self.draw(screen: screen)

        case Int32(127), Int32(330): // DELETE
            self.barbicanSecretCreateForm.removeFromPayloadBuffer()
            await self.draw(screen: screen)

        default:
            if let character = UnicodeScalar(UInt32(ch))?.description.first {
                self.barbicanSecretCreateForm.addToPayloadBuffer(character)
                // Only redraw if not in paste mode to prevent character-by-character slowdown
                if !self.barbicanSecretCreateForm.isPasteMode {
                    await self.draw(screen: screen)
                }
            }
        }
    }

}

// MARK: - BarbicanSecretCreateForm Adapter

/// Adapter to make BarbicanSecretCreateForm work with universal handler
struct BarbicanSecretCreateFormAdapter: FormStateUpdatable, FormStateRebuildable, FormValidatable {
    var form: BarbicanSecretCreateForm

    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return form.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: formState)
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        form.updateFromFormState(formState)
    }

    func validateForm() -> [String] {
        return form.validate()
    }
}
