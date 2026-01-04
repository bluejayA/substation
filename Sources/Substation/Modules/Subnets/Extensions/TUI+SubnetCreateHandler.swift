import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Subnet Create Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handle input for Subnet create form using the universal handler
    internal func handleSubnetCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = subnetCreateFormState
        var localForm = subnetCreateForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.subnetCreateFormState = formState
                self.subnetCreateForm = form
                guard let module = ModuleRegistry.shared.module(for: "subnets") as? SubnetsModule else {
                    Logger.shared.logError("Failed to get SubnetsModule from registry", context: [:])
                    self.statusMessage = "Error: Subnets module not available"
                    return
                }
                await module.submitSubnetCreation(screen: screen)
            },
            onCancel: {
                self.changeView(to: .subnets, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        subnetCreateFormState = localFormState
        subnetCreateForm = localForm
    }
}

// MARK: - SubnetCreateForm Protocol Conformance Adapters

extension SubnetCreateForm {
    /// Wrapper to conform to FormValidatable protocol
    func validateForm() -> [String] {
        // Use basic validate() without networks - full validation
        // will be called in the submission handler with cached networks
        return self.validate()
    }

    /// Adapter for FormStateRebuildable - ignores cachedNetworks parameter
    /// since protocol doesn't support it. Forms are initialized with networks once.
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        // Call with empty networks array - the selector state already contains selected IDs
        return self.buildFields(
            selectedFieldId: selectedFieldId,
            activeFieldId: activeFieldId,
            cachedNetworks: [],
            formState: formState
        )
    }

    /// Implementation of FormStateUpdatable protocol
    /// Updates form fields from FormBuilderState
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // IMPORTANT: Get values from textFieldStates/selectorStates, not from fields array
        // The fields array contains the original values, not the user's input

        // Update text fields from textFieldStates
        if let textState = formState.textFieldStates[SubnetCreateFieldId.name.rawValue] {
            self.subnetName = textState.value
        }
        if let textState = formState.textFieldStates[SubnetCreateFieldId.cidr.rawValue] {
            self.cidr = textState.value
        }
        if let textState = formState.textFieldStates[SubnetCreateFieldId.allocationPools.rawValue] {
            self.allocationPools = textState.value
        }
        if let textState = formState.textFieldStates[SubnetCreateFieldId.dns.rawValue] {
            self.dns = textState.value
        }
        if let textState = formState.textFieldStates[SubnetCreateFieldId.hostRoutes.rawValue] {
            self.hostRoutes = textState.value
        }

        // Update checkbox fields from checkboxStates
        if let checkboxState = formState.checkboxStates[SubnetCreateFieldId.gatewayEnabled.rawValue] {
            self.gatewayEnabled = checkboxState.isChecked
        }
        if let checkboxState = formState.checkboxStates[SubnetCreateFieldId.dhcpEnabled.rawValue] {
            self.dhcpEnabled = checkboxState.isChecked
        }

        // Update selector fields from selectorStates
        if let selectorState = formState.selectorStates[SubnetCreateFieldId.network.rawValue] {
            self.selectedNetworkID = selectorState.selectedItemId
        }
        if let selectorState = formState.selectorStates[SubnetCreateFieldId.ipVersion.rawValue],
           let selectedId = selectorState.selectedItemId,
           let version = IPVersion(rawValue: selectedId) {
            self.ipVersion = version
        }

        // Update navigation state
        if let currentFieldId = formState.getCurrentFieldId() {
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

// Declare protocol conformance after adapters are defined
extension SubnetCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}

