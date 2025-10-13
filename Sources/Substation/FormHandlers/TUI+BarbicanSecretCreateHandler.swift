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

// MARK: - Barbican Secret Create Input Handler

@MainActor
extension TUI {

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

        let isFieldActive = self.barbicanSecretCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                self.barbicanSecretCreateFormState.nextField()
                self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)

                // Rebuild fields
                self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                    selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.barbicanSecretCreateFormState
                ))

                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                self.barbicanSecretCreateFormState.previousField()
                self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)

                // Rebuild fields
                self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                    selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.barbicanSecretCreateFormState
                ))

                await self.draw(screen: screen)
            }

        case 258, 259: // DOWN/UP - Navigate within active field or between fields
            if isFieldActive {
                // Navigate within active selector
                if let currentField = self.barbicanSecretCreateFormState.getCurrentField() {
                    if case .selector(let selectorField) = currentField {
                        if var state = self.barbicanSecretCreateFormState.selectorStates[selectorField.id] {
                            if ch == 258 { // DOWN
                                state.moveDown()
                            } else { // UP
                                state.moveUp()
                            }
                            self.barbicanSecretCreateFormState.selectorStates[selectorField.id] = state

                            // Rebuild fields with updated highlightedIndex
                            self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                                selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                                activeFieldId: selectorField.id,
                                formState: self.barbicanSecretCreateFormState
                            ))

                            await self.draw(screen: screen)
                        }
                    }
                }
            } else {
                // Navigate between fields
                if ch == 258 { // DOWN
                    self.barbicanSecretCreateFormState.nextField()
                } else { // UP
                    self.barbicanSecretCreateFormState.previousField()
                }
                self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)

                // Rebuild fields
                self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                    selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.barbicanSecretCreateFormState
                ))

                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field or select item
            if !isFieldActive {
                // Check if this is a special field that needs custom handling
                if let currentField = self.barbicanSecretCreateFormState.getCurrentField() {
                    if case .text(let textField) = currentField,
                       textField.id == BarbicanSecretCreateFieldId.payload.rawValue {
                        // Enter payload edit mode (full-screen editor)
                        self.barbicanSecretCreateForm.payloadEditMode = true
                        await self.draw(screen: screen)
                        return
                    } else if case .info(let infoField) = currentField,
                              infoField.id == BarbicanSecretCreateFieldId.expirationDate.rawValue {
                        // Enter legacy date selection mode
                        self.barbicanSecretCreateForm.enterSelectionMode()
                        await self.draw(screen: screen)
                        return
                    }
                }

                // Activate current field
                self.barbicanSecretCreateFormState.activateCurrentField()
                self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)

                // Rebuild fields with active field ID to ensure selector renders correctly
                self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                    selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                    activeFieldId: self.barbicanSecretCreateFormState.getActiveFieldId(),
                    formState: self.barbicanSecretCreateFormState
                ))

                await self.draw(screen: screen)
            } else {
                // In active mode, handle based on field type
                if let currentField = self.barbicanSecretCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        // For text fields, add space as character
                        self.barbicanSecretCreateFormState.handleCharacterInput(" ")
                        self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)
                        await self.draw(screen: screen)
                    case .selector:
                        // For selector, SPACE selects the highlighted item
                        self.barbicanSecretCreateFormState.toggleCurrentField()
                        self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)

                        // Deactivate the selector after selection
                        self.barbicanSecretCreateFormState.deactivateCurrentField()

                        // Rebuild fields
                        self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                            selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                            activeFieldId: nil,
                            formState: self.barbicanSecretCreateFormState
                        ))

                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Submit or deactivate field
            if isFieldActive {
                // Deactivate field
                if let currentField = self.barbicanSecretCreateFormState.getCurrentField() {
                    if case .selector = currentField {
                        // For selector, ENTER confirms selection
                        self.barbicanSecretCreateFormState.toggleCurrentField()
                    } else if case .text(let textField) = currentField,
                              textField.id == BarbicanSecretCreateFieldId.payloadFilePath.rawValue {
                        // For file path field, load file on ENTER
                        if let error = self.barbicanSecretCreateForm.loadPayloadFromFile() {
                            self.statusMessage = error
                        } else {
                            self.statusMessage = "File loaded successfully"
                        }
                    }
                }

                self.barbicanSecretCreateFormState.deactivateCurrentField()
                self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)

                // Rebuild fields
                self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                    selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.barbicanSecretCreateFormState
                ))

                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = self.barbicanSecretCreateForm.validate()
                if errors.isEmpty {
                    await self.resourceOperations.createSecret(screen: screen)
                } else {
                    self.barbicanSecretCreateFormState.showValidationErrors = true
                    self.statusMessage = "Error: \(errors.first!)"
                    await self.draw(screen: screen)
                }
            }

        case Int32(27): // ESC - Cancel or deactivate
            if isFieldActive {
                self.barbicanSecretCreateFormState.deactivateCurrentField()
                self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)

                // Rebuild fields
                self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                    selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.barbicanSecretCreateFormState
                ))

                await self.draw(screen: screen)
            } else {
                self.changeView(to: .barbicanSecrets, resetSelection: false)
            }

        case Int32(127), Int32(8), Int32(263): // BACKSPACE/DELETE
            if isFieldActive {
                if let currentField = self.barbicanSecretCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        let handled = self.barbicanSecretCreateFormState.handleSpecialKey(ch)
                        if handled {
                            self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)
                            await self.draw(screen: screen)
                        }
                    case .selector(let selectorField):
                        // BACKSPACE removes last search character
                        if var state = self.barbicanSecretCreateFormState.selectorStates[selectorField.id] {
                            state.removeLastSearchCharacter()
                            self.barbicanSecretCreateFormState.selectorStates[selectorField.id] = state

                            // Rebuild fields
                            self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                                selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                                activeFieldId: selectorField.id,
                                formState: self.barbicanSecretCreateFormState
                            ))

                            await self.draw(screen: screen)
                        }
                    default:
                        break
                    }
                }
            }

        default:
            // Handle character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    if let currentField = self.barbicanSecretCreateFormState.getCurrentField() {
                        switch currentField {
                        case .text:
                            self.barbicanSecretCreateFormState.handleCharacterInput(char)
                            self.barbicanSecretCreateForm.updateFromFormState(self.barbicanSecretCreateFormState)
                            await self.draw(screen: screen)
                        case .selector(let selectorField):
                            // Add to search query
                            if var state = self.barbicanSecretCreateFormState.selectorStates[selectorField.id] {
                                state.appendToSearch(char)
                                self.barbicanSecretCreateFormState.selectorStates[selectorField.id] = state

                                // Rebuild fields
                                self.barbicanSecretCreateFormState = FormBuilderState(fields: self.barbicanSecretCreateForm.buildFields(
                                    selectedFieldId: self.barbicanSecretCreateFormState.getCurrentFieldId(),
                                    activeFieldId: selectorField.id,
                                    formState: self.barbicanSecretCreateFormState
                                ))

                                await self.draw(screen: screen)
                            }
                        default:
                            break
                        }
                    }
                }
            }
        }
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
