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

// MARK: - Subnet Create Input Handler

@MainActor
extension TUI {

    internal func handleSubnetCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if a field is currently active (being edited)
        let isFieldActive = subnetCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Cycle select options or navigate to next field
            if isFieldActive {
                if let currentField = subnetCreateFormState.getCurrentField() {
                    switch currentField {
                    case .select:
                        // For select fields (IP version), cycle through options
                        subnetCreateFormState.toggleCurrentField()
                        subnetCreateForm.updateFromFormState(subnetCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            } else {
                subnetCreateFormState.nextField()
                subnetCreateForm.updateFromFormState(subnetCreateFormState)
                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Cycle select options backwards or navigate to previous field
            if isFieldActive {
                if let currentField = subnetCreateFormState.getCurrentField() {
                    if case .select = currentField {
                        subnetCreateFormState.cyclePreviousOption()
                        subnetCreateForm.updateFromFormState(subnetCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            } else {
                subnetCreateFormState.previousField()
                subnetCreateForm.updateFromFormState(subnetCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Toggle checkbox, activate field, or add space character
            // Check if current field is a checkbox - checkboxes toggle directly without activation
            if let currentField = subnetCreateFormState.getCurrentField(), case .checkbox = currentField {
                subnetCreateFormState.toggleCurrentField()
                subnetCreateForm.updateFromFormState(subnetCreateFormState)
                await self.draw(screen: screen)
            } else if !isFieldActive {
                // Not active: activate the field
                subnetCreateFormState.activateCurrentField()
                subnetCreateForm.updateFromFormState(subnetCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Active: check field type to determine behavior
                if let currentField = subnetCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text, .number:
                        // For text/number fields, add space as character
                        subnetCreateFormState.handleCharacterInput(" ")
                        subnetCreateForm.updateFromFormState(subnetCreateFormState)
                        await self.draw(screen: screen)
                    case .toggle, .select:
                        // For toggle/select fields, space toggles
                        subnetCreateFormState.toggleCurrentField()
                        subnetCreateForm.updateFromFormState(subnetCreateFormState)
                        await self.draw(screen: screen)
                    case .selector:
                        // For selector fields in active state, space toggles selection
                        subnetCreateFormState.toggleCurrentField()
                        subnetCreateForm.updateFromFormState(subnetCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            needsRedraw = true
            if isFieldActive {
                // Deactivate the current field
                subnetCreateFormState.deactivateCurrentField()
                subnetCreateForm.updateFromFormState(subnetCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Create subnet if form is valid
                let errors = subnetCreateForm.validate(availableNetworks: cachedNetworks)
                if errors.isEmpty {
                    await resourceOperations.submitSubnetCreation(screen: screen)
                } else {
                    subnetCreateFormState.showValidationErrors = true
                    statusMessage = "Error: \(errors.first!)"
                    await self.draw(screen: screen)
                }
            }

        case Int32(260): // KEY_LEFT - Navigate left in select fields
            if isFieldActive {
                if let currentField = subnetCreateFormState.getCurrentField() {
                    if case .select = currentField {
                        subnetCreateFormState.cyclePreviousOption()
                        subnetCreateForm.updateFromFormState(subnetCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            }

        case Int32(261): // KEY_RIGHT - Navigate right in select fields
            if isFieldActive {
                if let currentField = subnetCreateFormState.getCurrentField() {
                    if case .select = currentField {
                        subnetCreateFormState.toggleCurrentField()
                        subnetCreateForm.updateFromFormState(subnetCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            }

        case Int32(259), Int32(258): // KEY_UP/DOWN - Navigate in selector or between fields
            if isFieldActive {
                let handled = subnetCreateFormState.handleSpecialKey(ch)
                if handled {
                    subnetCreateForm.updateFromFormState(subnetCreateFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    subnetCreateFormState.previousField()
                } else {
                    subnetCreateFormState.nextField()
                }
                subnetCreateForm.updateFromFormState(subnetCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC - Deactivate field or cancel creation
            if isFieldActive {
                subnetCreateFormState.deactivateCurrentField()
                subnetCreateForm.updateFromFormState(subnetCreateFormState)
                await self.draw(screen: screen)
            } else {
                self.changeView(to: .subnets, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE - Remove character
            if isFieldActive {
                let handled = subnetCreateFormState.handleSpecialKey(ch)
                if handled {
                    subnetCreateForm.updateFromFormState(subnetCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        case Int32(47): // "/" - Search in selector or input in text field
            if isFieldActive {
                if let currentField = subnetCreateFormState.getCurrentField() {
                    switch currentField {
                    case .selector:
                        // For selector fields, "/" is used for search
                        subnetCreateFormState.handleCharacterInput("/")
                        await self.draw(screen: screen)
                    case .text, .number:
                        // For text/number fields, "/" is a regular character
                        subnetCreateFormState.handleCharacterInput("/")
                        subnetCreateForm.updateFromFormState(subnetCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        default:
            // Handle character input for text fields
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    subnetCreateFormState.handleCharacterInput(char)
                    subnetCreateForm.updateFromFormState(subnetCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}

// MARK: - SubnetCreateForm FormState Integration

extension SubnetCreateForm {
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Update form data from FormBuilderState
        let fields = formState.fields

        for field in fields {
            switch field {
            case .text(let textField):
                switch textField.id {
                case SubnetCreateFieldId.name.rawValue:
                    self.subnetName = textField.value
                case SubnetCreateFieldId.cidr.rawValue:
                    self.cidr = textField.value
                case SubnetCreateFieldId.allocationPools.rawValue:
                    self.allocationPools = textField.value
                case SubnetCreateFieldId.dns.rawValue:
                    self.dns = textField.value
                case SubnetCreateFieldId.hostRoutes.rawValue:
                    self.hostRoutes = textField.value
                default:
                    break
                }
            case .checkbox(let checkboxField):
                switch checkboxField.id {
                case SubnetCreateFieldId.gatewayEnabled.rawValue:
                    self.gatewayEnabled = checkboxField.isChecked
                case SubnetCreateFieldId.dhcpEnabled.rawValue:
                    self.dhcpEnabled = checkboxField.isChecked
                default:
                    break
                }
            case .selector(let selectorField):
                if selectorField.id == SubnetCreateFieldId.network.rawValue {
                    self.selectedNetworkID = selectorField.selectedItemId
                } else if selectorField.id == SubnetCreateFieldId.ipVersion.rawValue {
                    if let selectedId = selectorField.selectedItemId,
                       let version = IPVersion(rawValue: selectedId) {
                        self.ipVersion = version
                    }
                }
            default:
                break
            }
        }

        // Update navigation state
        if let currentFieldId = formState.getCurrentFieldId() {
            // Map field ID back to SubnetCreateField enum
            switch currentFieldId {
            case SubnetCreateFieldId.name.rawValue:
                self.currentField = .name
            case SubnetCreateFieldId.network.rawValue:
                self.currentField = .network
            case SubnetCreateFieldId.ipVersion.rawValue:
                self.currentField = .ipVersion
            case SubnetCreateFieldId.cidr.rawValue:
                self.currentField = .cidr
            case SubnetCreateFieldId.gatewayEnabled.rawValue:
                self.currentField = .gatewayEnabled
            case SubnetCreateFieldId.dhcpEnabled.rawValue:
                self.currentField = .dhcpEnabled
            case SubnetCreateFieldId.allocationPools.rawValue:
                self.currentField = .allocationPools
            case SubnetCreateFieldId.dns.rawValue:
                self.currentField = .dns
            case SubnetCreateFieldId.hostRoutes.rawValue:
                self.currentField = .hostRoutes
            default:
                break
            }
        }

        // Update edit mode based on active field
        self.fieldEditMode = formState.isCurrentFieldActive()

        // Update network selection mode based on selector state
        if let currentField = formState.getCurrentField(),
           case .selector(let selectorField) = currentField,
           selectorField.id == SubnetCreateFieldId.network.rawValue {
            self.networkSelectionMode = selectorField.isActive
            if let selectorState = formState.getSelectorState(selectorField.id) {
                self.selectedNetworkIndex = selectorState.highlightedIndex
            }
        } else {
            self.networkSelectionMode = false
        }
    }
}
