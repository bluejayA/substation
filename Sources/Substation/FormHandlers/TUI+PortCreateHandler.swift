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

// MARK: - Port Create Input Handler

@MainActor
extension TUI {

    internal func handlePortCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = self.portCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                self.portCreateFormState.nextField()
                self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)

                // Rebuild fields if port security or QoS changed (affects visible fields)
                self.portCreateFormState = FormBuilderState(fields: self.portCreateForm.buildFields(
                    selectedFieldId: self.portCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.portCreateFormState,
                    networks: self.cachedNetworks,
                    securityGroups: self.cachedSecurityGroups,
                    qosPolicies: self.cachedQoSPolicies
                ))

                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                self.portCreateFormState.previousField()
                self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)

                // Rebuild fields if port security or QoS changed (affects visible fields)
                self.portCreateFormState = FormBuilderState(fields: self.portCreateForm.buildFields(
                    selectedFieldId: self.portCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.portCreateFormState,
                    networks: self.cachedNetworks,
                    securityGroups: self.cachedSecurityGroups,
                    qosPolicies: self.cachedQoSPolicies
                ))

                await self.draw(screen: screen)
            }

        case 258, 259: // DOWN/UP - Navigate within active field or between fields
            if isFieldActive {
                // Navigate within active selector/multiselect
                if let currentField = self.portCreateFormState.getCurrentField() {
                    if case .selector(let selectorField) = currentField {
                        if var state = self.portCreateFormState.selectorStates[selectorField.id] {
                            let itemCount = selectorField.items.count
                            let currentIndex = state.highlightedIndex

                            if ch == 258 { // DOWN
                                state.highlightedIndex = min(currentIndex + 1, itemCount - 1)
                            } else { // UP
                                state.highlightedIndex = max(currentIndex - 1, 0)
                            }
                            self.portCreateFormState.selectorStates[selectorField.id] = state

                            // Rebuild fields with updated highlightedIndex
                            self.portCreateFormState = FormBuilderState(fields: self.portCreateForm.buildFields(
                                selectedFieldId: self.portCreateFormState.getCurrentFieldId(),
                                activeFieldId: selectorField.id,
                                formState: self.portCreateFormState,
                                networks: self.cachedNetworks,
                                securityGroups: self.cachedSecurityGroups,
                                qosPolicies: self.cachedQoSPolicies
                            ))

                            await self.draw(screen: screen)
                        }
                    } else if case .multiSelect(let multiSelectField) = currentField {
                        if var state = self.portCreateFormState.selectorStates[multiSelectField.id] {
                            let itemCount = multiSelectField.items.count
                            let currentIndex = state.highlightedIndex

                            if ch == 258 { // DOWN
                                state.highlightedIndex = min(currentIndex + 1, itemCount - 1)
                            } else { // UP
                                state.highlightedIndex = max(currentIndex - 1, 0)
                            }
                            self.portCreateFormState.selectorStates[multiSelectField.id] = state

                            // Rebuild fields with updated highlightedIndex
                            self.portCreateFormState = FormBuilderState(fields: self.portCreateForm.buildFields(
                                selectedFieldId: self.portCreateFormState.getCurrentFieldId(),
                                activeFieldId: multiSelectField.id,
                                formState: self.portCreateFormState,
                                networks: self.cachedNetworks,
                                securityGroups: self.cachedSecurityGroups,
                                qosPolicies: self.cachedQoSPolicies
                            ))

                            await self.draw(screen: screen)
                        }
                    }
                }
            } else {
                // Navigate between fields
                if ch == 258 { // DOWN
                    self.portCreateFormState.nextField()
                } else { // UP
                    self.portCreateFormState.previousField()
                }
                self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)

                // Rebuild fields if port security or QoS changed (affects visible fields)
                self.portCreateFormState = FormBuilderState(fields: self.portCreateForm.buildFields(
                    selectedFieldId: self.portCreateFormState.getCurrentFieldId(),
                    activeFieldId: nil,
                    formState: self.portCreateFormState,
                    networks: self.cachedNetworks,
                    securityGroups: self.cachedSecurityGroups,
                    qosPolicies: self.cachedQoSPolicies
                ))

                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Toggle selection or activate field
            if !isFieldActive {
                // Handle toggle fields
                if let currentField = self.portCreateFormState.getCurrentField() {
                    if case .toggle = currentField {
                        self.portCreateFormState.toggleCurrentField()
                        self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)

                        // Rebuild fields since toggle changed (may affect visible fields)
                        self.portCreateFormState = FormBuilderState(fields: self.portCreateForm.buildFields(
                            selectedFieldId: self.portCreateFormState.getCurrentFieldId(),
                            activeFieldId: nil,
                            formState: self.portCreateFormState,
                            networks: self.cachedNetworks,
                            securityGroups: self.cachedSecurityGroups,
                            qosPolicies: self.cachedQoSPolicies
                        ))

                        await self.draw(screen: screen)
                        return
                    }
                }

                // Activate current field for selectors and text fields
                self.portCreateFormState.activateCurrentField()
                self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)

                // Rebuild fields with active field ID to ensure selector renders correctly
                self.portCreateFormState = FormBuilderState(fields: self.portCreateForm.buildFields(
                    selectedFieldId: self.portCreateFormState.getCurrentFieldId(),
                    activeFieldId: self.portCreateFormState.getActiveFieldId(),
                    formState: self.portCreateFormState,
                    networks: self.cachedNetworks,
                    securityGroups: self.cachedSecurityGroups,
                    qosPolicies: self.cachedQoSPolicies
                ))

                await self.draw(screen: screen)
            } else {
                // In active mode, handle based on field type
                if let currentField = self.portCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        // For text fields, add space as character
                        self.portCreateFormState.handleCharacterInput(" ")
                        self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)
                        await self.draw(screen: screen)
                    case .selector:
                        // For single-select selectors, SPACE does nothing (use ENTER to confirm)
                        break
                    case .multiSelect(let multiSelectField):
                        // For multiselect, toggle the highlighted item
                        if let state = self.portCreateFormState.selectorStates[multiSelectField.id] {
                            let highlightedIndex = state.highlightedIndex
                            if highlightedIndex < multiSelectField.items.count {
                                let item = multiSelectField.items[highlightedIndex]

                                // Toggle selection
                                var selectedIds = multiSelectField.selectedItemIds
                                if selectedIds.contains(item.id) {
                                    selectedIds.remove(item.id)
                                } else {
                                    selectedIds.insert(item.id)
                                }

                                // Update the field with new selection
                                var fields = self.portCreateFormState.fields
                                for i in 0..<fields.count {
                                    if case .multiSelect(var field) = fields[i], field.id == multiSelectField.id {
                                        field.selectedItemIds = selectedIds
                                        fields[i] = .multiSelect(field)
                                        self.portCreateFormState = FormBuilderState(fields: fields)
                                        self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)
                                        await self.draw(screen: screen)
                                        break
                                    }
                                }
                            }
                        }
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Confirm selection or create port
            if isFieldActive {
                // Confirm selection in selector
                if let currentField = self.portCreateFormState.getCurrentField() {
                    if case .selector(let selectorField) = currentField {
                        // Select the highlighted item
                        if let state = self.portCreateFormState.selectorStates[selectorField.id] {
                            let highlightedIndex = state.highlightedIndex
                            if highlightedIndex < selectorField.items.count {
                                let selectedItem = selectorField.items[highlightedIndex]

                                // Update the field with the selected item
                                var fields = self.portCreateFormState.fields
                                for i in 0..<fields.count {
                                    if case .selector(var field) = fields[i], field.id == selectorField.id {
                                        field.selectedItemId = selectedItem.id
                                        fields[i] = .selector(field)
                                        self.portCreateFormState = FormBuilderState(fields: fields)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }

                // Deactivate the field
                self.portCreateFormState.deactivateCurrentField()
                self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)
                await self.draw(screen: screen)
            } else {
                // Create port if form is valid
                let errors = self.portCreateForm.validate(networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups)
                if errors.isEmpty {
                    await self.resourceOperations.submitPortCreation(screen: screen)
                } else {
                    self.statusMessage = "Error: \(errors.first!)"
                    await self.draw(screen: screen)
                }
            }

        case Int32(27): // ESC - Deactivate field or cancel
            if isFieldActive {
                self.portCreateFormState.deactivateCurrentField()
                self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)
                await self.draw(screen: screen)
            } else {
                self.changeView(to: .ports, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE
            if isFieldActive {
                let handled = self.portCreateFormState.handleSpecialKey(ch)
                if handled {
                    self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Handle character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    self.portCreateFormState.handleCharacterInput(char)
                    self.portCreateForm.updateFromFormState(self.portCreateFormState, networks: self.cachedNetworks, securityGroups: self.cachedSecurityGroups, qosPolicies: self.cachedQoSPolicies)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}
