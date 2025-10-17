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

        // Special handling for legacy date selection mode
        if barbicanSecretCreateForm.dateSelectionMode {
            await handleDateSelectionInput(ch, screen: screen)
            return
        }

        // Special handling for legacy selection mode
        if barbicanSecretCreateForm.selectionMode {
            await handleLegacySelectionInput(ch, screen: screen)
            return
        }

        // Normal form handling with universal handler
        var localFormState = barbicanSecretCreateFormState
        var localFormAdapter = BarbicanSecretCreateFormAdapter(form: barbicanSecretCreateForm)

        // Custom key handler for special field behaviors
        let customHandler: @MainActor @Sendable (Int32, inout FormBuilderState, inout BarbicanSecretCreateFormAdapter, OpaquePointer?) async -> Bool = { ch, formState, formAdapter, screen in
            // SPACE on special fields enters their special modes
            if ch == Int32(32) && !formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField() {
                    if case .text(let textField) = field,
                       textField.id == BarbicanSecretCreateFieldId.payload.rawValue {
                        formAdapter.form.payloadEditMode = true
                        await self.draw(screen: screen)
                        return true
                    } else if case .info(let infoField) = field,
                              infoField.id == BarbicanSecretCreateFieldId.expirationDate.rawValue {
                        formAdapter.form.enterSelectionMode()
                        await self.draw(screen: screen)
                        return true
                    }
                }
            }

            // ENTER on file path field loads file
            if (ch == Int32(10) || ch == Int32(13)) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField(),
                   case .text(let textField) = field,
                   textField.id == BarbicanSecretCreateFieldId.payloadFilePath.rawValue {
                    if let error = formAdapter.form.loadPayloadFromFile() {
                        self.statusMessage = error
                    } else {
                        self.statusMessage = "File loaded successfully"
                    }
                    return false // Let universal handler continue with deactivation
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
                // Receive formState and formAdapter as parameters to avoid exclusivity violation
                self.barbicanSecretCreateFormState = formState
                self.barbicanSecretCreateForm = formAdapter.form
                await self.resourceOperations.createSecret(screen: screen)
            },
            onCancel: {
                self.changeView(to: .barbicanSecrets, resetSelection: false)
            },
            customKeyHandler: customHandler
        )

        // Rebuild after universal handler to ensure field visibility is correct
        localFormState = FormBuilderState(fields: localFormAdapter.form.buildFields(
            selectedFieldId: localFormState.getCurrentFieldId(),
            activeFieldId: nil,
            formState: localFormState
        ))

        // Update actor-isolated properties
        barbicanSecretCreateFormState = localFormState
        barbicanSecretCreateForm = localFormAdapter.form
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

    // MARK: - Legacy Date Selection Input Handler

    private func handleDateSelectionInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(9), Int32(258): // TAB or DOWN - Next date field
            self.barbicanSecretCreateForm.nextDateField()
            await self.draw(screen: screen)

        case 353, Int32(259): // SHIFT+TAB or UP - Previous date field
            self.barbicanSecretCreateForm.previousDateField()
            await self.draw(screen: screen)

        case Int32(261), Int32(43): // RIGHT or + - Increase value
            self.barbicanSecretCreateForm.increaseDateFieldValue()
            await self.draw(screen: screen)

        case Int32(260), Int32(45): // LEFT or - - Decrease value
            self.barbicanSecretCreateForm.decreaseDateFieldValue()
            await self.draw(screen: screen)

        case Int32(10), Int32(13): // ENTER - Confirm date
            self.barbicanSecretCreateForm.exitDateSelectionMode()
            await self.draw(screen: screen)

        case Int32(27): // ESC - Cancel date selection
            self.barbicanSecretCreateForm.hasExpiration = false
            self.barbicanSecretCreateForm.exitDateSelectionMode()
            await self.draw(screen: screen)

        default:
            break
        }
    }

    // MARK: - Legacy Selection Input Handler

    private func handleLegacySelectionInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(258): // DOWN
            self.barbicanSecretCreateForm.nextSelectionItem()
            await self.draw(screen: screen)

        case Int32(259): // UP
            self.barbicanSecretCreateForm.previousSelectionItem()
            await self.draw(screen: screen)

        case Int32(32): // SPACE - Toggle selection
            self.barbicanSecretCreateForm.toggleSelectionConfirmation()
            await self.draw(screen: screen)

        case Int32(10), Int32(13): // ENTER - Confirm selection
            self.barbicanSecretCreateForm.confirmSelection()
            await self.draw(screen: screen)

        case Int32(27): // ESC - Cancel selection
            self.barbicanSecretCreateForm.exitSelectionMode()
            await self.draw(screen: screen)

        default:
            break
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
