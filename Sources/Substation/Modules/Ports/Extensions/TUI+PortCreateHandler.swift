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

// MARK: - Port Create Input Handler

@MainActor
extension TUI {

    /// Handle input for Port create form using universal handler
    /// Port form requires context parameters: networks, securityGroups, qosPolicies
    internal func handlePortCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        var localFormState = portCreateFormState
        var localFormAdapter = PortCreateFormAdapter(
            form: portCreateForm,
            networks: cacheManager.cachedNetworks,
            securityGroups: cacheManager.cachedSecurityGroups,
            qosPolicies: cacheManager.cachedQoSPolicies
        )

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localFormAdapter,
            onSubmit: { formState, formAdapter in
                // Sync state before submission
                self.portCreateFormState = formState
                self.portCreateForm = formAdapter.form
                if let module = ModuleRegistry.shared.module(for: "ports") as? PortsModule {
                    await module.submitPortCreation(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .ports, resetSelection: false)
            }
        )

        // Always rebuild with context after handling to ensure field visibility is correct
        localFormState = FormBuilderState(fields: localFormAdapter.form.buildFields(
            selectedFieldId: localFormState.getCurrentFieldId(),
            activeFieldId: localFormState.getActiveFieldId(),
            formState: localFormState,
            networks: cacheManager.cachedNetworks,
            securityGroups: cacheManager.cachedSecurityGroups,
            qosPolicies: cacheManager.cachedQoSPolicies
        ))

        // Update actor-isolated properties
        portCreateFormState = localFormState
        portCreateForm = localFormAdapter.form
    }
}

// MARK: - PortCreateForm Adapter

/// Adapter to make PortCreateForm work with universal handler
/// Form requires context parameters (networks, securityGroups, qosPolicies) for all methods
struct PortCreateFormAdapter: FormStateUpdatable, FormStateRebuildable, FormValidatable {
    var form: PortCreateForm
    let networks: [Network]
    let securityGroups: [SecurityGroup]
    let qosPolicies: [QoSPolicy]

    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return form.buildFields(
            selectedFieldId: selectedFieldId,
            activeFieldId: activeFieldId,
            formState: formState,
            networks: networks,
            securityGroups: securityGroups,
            qosPolicies: qosPolicies
        )
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        form.updateFromFormState(formState, networks: networks, securityGroups: securityGroups, qosPolicies: qosPolicies)
    }

    func validateForm() -> [String] {
        return form.validate(networks: networks, securityGroups: securityGroups)
    }
}
