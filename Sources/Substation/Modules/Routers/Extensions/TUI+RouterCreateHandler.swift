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

// MARK: - Router Create Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handle input for Router create form using the universal handler
    internal func handleRouterCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = routerCreateFormState
        var localForm = routerCreateForm

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.routerCreateFormState = formState
                self.routerCreateForm = form
                if let module = ModuleRegistry.shared.module(for: "routers") as? RoutersModule {
                    await module.submitRouterCreation(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .routers, resetSelection: false)
            }
        )

        // Update actor-isolated properties with modified local copies
        routerCreateFormState = localFormState
        routerCreateForm = localForm
    }
}

// MARK: - RouterCreateForm Protocol Conformance Adapters

extension RouterCreateForm {
    /// Adapter for FormStateRebuildable - ignores context parameters
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        // Call the original method with empty arrays - the form state already contains selections
        return buildFields(
            selectedFieldId: selectedFieldId,
            activeFieldId: activeFieldId,
            formState: formState,
            availabilityZones: [],
            externalNetworks: []
        )
    }

    /// Adapter for FormValidatable - provides empty context
    func validateForm() -> [String] {
        return validateForm(availabilityZones: [], externalNetworks: [])
    }
}

// Declare protocol conformance after adapters
extension RouterCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
