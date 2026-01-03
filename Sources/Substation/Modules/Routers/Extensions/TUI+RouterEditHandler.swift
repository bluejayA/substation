import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Router Edit Input Handler (Universal Pattern)

@MainActor
extension TUI {

    /// Handle input for Router edit form using the universal handler
    internal func handleRouterEditInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = routerEditFormState
        var localForm = routerEditForm

        // Get cached data for form rebuilding
        let externalNetworks = cacheManager.cachedNetworks.filter { $0.external == true }

        // Custom key handler for toggle and ENTER (validation needs real data)
        let customHandler: @MainActor @Sendable (Int32, inout FormBuilderState, inout RouterEditForm, OpaquePointer?) async -> Bool = { [externalNetworks] ch, formState, form, screen in
            // Handle SPACE on toggle fields - need to rebuild form for external gateway toggle
            if ch == Int32(32) && !formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField() {
                    if case .toggle(let toggle) = field,
                       toggle.id == RouterEditFieldId.externalGateway.rawValue {
                        // Toggle the value
                        formState.toggleCurrentField()
                        form.updateFromFormState(formState)

                        // Rebuild form state with actual data to show/hide external network selector
                        formState = FormBuilderState(
                            fields: form.buildFields(
                                selectedFieldId: formState.getCurrentFieldId(),
                                activeFieldId: formState.getActiveFieldId(),
                                formState: formState,
                                externalNetworks: externalNetworks
                            ),
                            preservingStateFrom: formState
                        )

                        await self.draw(screen: screen)
                        return true // Handled
                    }
                }
            }

            // Handle ENTER for form submission - validate with real data
            if (ch == Int32(10) || ch == Int32(13)) && !formState.isCurrentFieldActive() {
                // Sync form with state before validation
                form.updateFromFormState(formState)

                // Validate with actual cached data
                let errors = form.validateForm(externalNetworks: externalNetworks)
                if errors.isEmpty {
                    // Update TUI state and submit
                    self.routerEditFormState = formState
                    self.routerEditForm = form
                    guard let module = ModuleRegistry.shared.module(for: "routers") as? RoutersModule else {
                        Logger.shared.logError("Failed to get RoutersModule from registry", context: [:])
                        self.statusMessage = "Error: Routers module not available"
                        return true
                    }
                    await module.submitRouterEdit(screen: screen)
                } else {
                    // Show validation errors
                    self.statusMessage = "Validation errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                }
                return true // Handled
            }

            return false // Let universal handler process
        }

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // This won't be called since we handle ENTER in customHandler
                self.routerEditFormState = formState
                self.routerEditForm = form
            },
            onCancel: {
                self.changeView(to: .routers, resetSelection: false)
            },
            customKeyHandler: customHandler
        )

        // Always rebuild after universal handler to ensure form reflects current state
        localFormState = FormBuilderState(
            fields: localForm.buildFields(
                selectedFieldId: localFormState.getCurrentFieldId(),
                activeFieldId: localFormState.getActiveFieldId(),
                formState: localFormState,
                externalNetworks: externalNetworks
            ),
            preservingStateFrom: localFormState
        )

        // Update actor-isolated properties with modified local copies
        routerEditFormState = localFormState
        routerEditForm = localForm
    }
}

// MARK: - RouterEditForm Protocol Conformance Adapters

extension RouterEditForm {
    /// Adapter for FormStateRebuildable - ignores context parameters
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return buildFields(
            selectedFieldId: selectedFieldId,
            activeFieldId: activeFieldId,
            formState: formState,
            externalNetworks: []
        )
    }

    /// Adapter for FormValidatable - provides empty context
    func validateForm() -> [String] {
        return validateForm(externalNetworks: [])
    }
}

// Declare protocol conformance after adapters
extension RouterEditForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
