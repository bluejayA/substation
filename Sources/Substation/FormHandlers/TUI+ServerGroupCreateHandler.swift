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

// MARK: - Server Group Create Input Handler

@MainActor
extension TUI {

    internal func handleServerGroupCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = self.serverGroupCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                self.serverGroupCreateFormState.nextField()
                self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)

                // Rebuild fields
                self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                    selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.serverGroupCreateFormState
                ))

                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                self.serverGroupCreateFormState.previousField()
                self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)

                // Rebuild fields
                self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                    selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.serverGroupCreateFormState
                ))

                await self.draw(screen: screen)
            }

        case 258, 259: // DOWN/UP - Navigate within active field or between fields
            if isFieldActive {
                // Navigate within active selector
                if let currentField = self.serverGroupCreateFormState.getCurrentField() {
                    if case .selector(let selectorField) = currentField {
                        if var state = self.serverGroupCreateFormState.selectorStates[selectorField.id] {
                            if ch == 258 { // DOWN
                                state.moveDown()
                            } else { // UP
                                state.moveUp()
                            }
                            self.serverGroupCreateFormState.selectorStates[selectorField.id] = state

                            // Rebuild fields with updated highlightedIndex
                            self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                                selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                                activeFieldId: selectorField.id,
                                formState: self.serverGroupCreateFormState
                            ))

                            await self.draw(screen: screen)
                        }
                    }
                }
            } else {
                // Navigate between fields
                if ch == 258 { // DOWN
                    self.serverGroupCreateFormState.nextField()
                } else { // UP
                    self.serverGroupCreateFormState.previousField()
                }
                self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)

                // Rebuild fields
                self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                    selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.serverGroupCreateFormState
                ))

                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field or select item
            if !isFieldActive {
                // Activate current field
                self.serverGroupCreateFormState.activateCurrentField()
                self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)

                // Rebuild fields with active field ID to ensure selector renders correctly
                self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                    selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                    activeFieldId: self.serverGroupCreateFormState.getActiveFieldId(),
                    formState: self.serverGroupCreateFormState
                ))

                await self.draw(screen: screen)
            } else {
                // In active mode, handle based on field type
                if let currentField = self.serverGroupCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        // For text fields, add space as character
                        self.serverGroupCreateFormState.handleCharacterInput(" ")
                        self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)
                        await self.draw(screen: screen)
                    case .selector:
                        // For selector, SPACE selects the highlighted item
                        self.serverGroupCreateFormState.toggleCurrentField()
                        self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)

                        // Deactivate the selector after selection
                        self.serverGroupCreateFormState.deactivateCurrentField()

                        // Rebuild fields
                        self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                            selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                            activeFieldId: nil,
                            formState: self.serverGroupCreateFormState
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
                if let currentField = self.serverGroupCreateFormState.getCurrentField() {
                    if case .selector = currentField {
                        // For selector, ENTER confirms selection
                        self.serverGroupCreateFormState.toggleCurrentField()
                    }
                }

                self.serverGroupCreateFormState.deactivateCurrentField()
                self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)

                // Rebuild fields
                self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                    selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.serverGroupCreateFormState
                ))

                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = self.serverGroupCreateForm.validate()
                if errors.isEmpty {
                    await self.resourceOperations.submitServerGroupCreation()
                } else {
                    self.serverGroupCreateFormState.showValidationErrors = true
                    self.statusMessage = "Error: \(errors.first!)"
                    await self.draw(screen: screen)
                }
            }

        case Int32(27): // ESC - Cancel or deactivate
            if isFieldActive {
                self.serverGroupCreateFormState.deactivateCurrentField()
                self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)

                // Rebuild fields
                self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                    selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.serverGroupCreateFormState
                ))

                await self.draw(screen: screen)
            } else {
                self.changeView(to: .serverGroups, resetSelection: false)
            }

        case Int32(127), Int32(8), Int32(263): // BACKSPACE/DELETE
            if isFieldActive {
                if let currentField = self.serverGroupCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        let handled = self.serverGroupCreateFormState.handleSpecialKey(ch)
                        if handled {
                            self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)
                            await self.draw(screen: screen)
                        }
                    case .selector(let selectorField):
                        // BACKSPACE removes last search character
                        if var state = self.serverGroupCreateFormState.selectorStates[selectorField.id] {
                            state.removeLastSearchCharacter()
                            self.serverGroupCreateFormState.selectorStates[selectorField.id] = state

                            // Rebuild fields
                            self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                                selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                                activeFieldId: selectorField.id,
                                formState: self.serverGroupCreateFormState
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
                    if let currentField = self.serverGroupCreateFormState.getCurrentField() {
                        switch currentField {
                        case .text:
                            self.serverGroupCreateFormState.handleCharacterInput(char)
                            self.serverGroupCreateForm.updateFromFormState(self.serverGroupCreateFormState)
                            await self.draw(screen: screen)
                        case .selector(let selectorField):
                            // Add to search query
                            if var state = self.serverGroupCreateFormState.selectorStates[selectorField.id] {
                                state.appendToSearch(char)
                                self.serverGroupCreateFormState.selectorStates[selectorField.id] = state

                                // Rebuild fields
                                self.serverGroupCreateFormState = FormBuilderState(fields: self.serverGroupCreateForm.buildFields(
                                    selectedFieldId: self.serverGroupCreateFormState.getCurrentFieldId(),
                                    activeFieldId: selectorField.id,
                                    formState: self.serverGroupCreateFormState
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
}

// MARK: - ServerGroupCreateForm FormState Integration

extension ServerGroupCreateForm {
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Update form data from FormBuilderState
        let fields = formState.fields

        for field in fields {
            switch field {
            case .text(let textField):
                if textField.id == ServerGroupCreateFieldId.name.rawValue {
                    self.serverGroupName = textField.value
                }
            case .selector(let selectorField):
                if selectorField.id == ServerGroupCreateFieldId.policy.rawValue {
                    if let selectedId = selectorField.selectedItemId,
                       let policy = ServerGroupPolicy(rawValue: selectedId) {
                        self.selectedPolicy = policy
                    }
                }
            default:
                break
            }
        }

        // Update navigation state
        if let currentFieldId = formState.getCurrentFieldId() {
            // Map field ID back to ServerGroupCreateField enum
            switch currentFieldId {
            case ServerGroupCreateFieldId.name.rawValue:
                self.currentField = .name
            case ServerGroupCreateFieldId.policy.rawValue:
                self.currentField = .policy
            default:
                break
            }
        }

        // Update edit mode based on active field
        self.fieldEditMode = formState.isCurrentFieldActive()

        // Update policy selection mode based on selector state
        if let currentField = formState.getCurrentField(),
           case .selector(let selectorField) = currentField,
           selectorField.id == ServerGroupCreateFieldId.policy.rawValue {
            self.policySelectionMode = selectorField.isActive
            if let selectorState = formState.selectorStates[selectorField.id] {
                self.selectedPolicyIndex = selectorState.highlightedIndex
            }
        } else {
            self.policySelectionMode = false
        }
    }
}
