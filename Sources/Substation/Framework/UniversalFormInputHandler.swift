import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - UniversalFormInputHandler
//
// This universal input handler replaces 40+ individual form input handlers with a single,
// type-safe, reusable implementation. It eliminates ~7,000 lines of duplicate code.
//
// **Key Features:**
// - Works with any form using FormBuilderState
// - Handles all field types (text, number, selector, multiSelect, toggle, checkbox, select)
// - Delegates submission to form-specific closures
// - Consistent input behavior across all forms
// - Single source of truth for form input logic
//
// **Usage Pattern:**
// ```swift
// // In TUI extension:
// internal func handleMyFormInput(_ ch: Int32, screen: OpaquePointer?) async {
//     await universalFormInputHandler.handleInput(
//         ch,
//         screen: screen,
//         formState: &myFormState,
//         form: myForm,
//         onSubmit: { await resourceOperations.submitMyFormCreation(screen: screen) },
//         onCancel: { self.changeView(to: .myResourceList, resetSelection: false) }
//     )
// }
// ```

@MainActor
final class UniversalFormInputHandler {
    // MARK: - Properties

    weak var tui: TUI?

    /// Callback to sync state before drawing - receives the current formState and form (type-erased)
    private var syncCallback: (@MainActor (FormBuilderState, Any) -> Void)?

    // MARK: - Initialization

    init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Universal Input Handling

    /// Handles all form input with a universal pattern
    /// - Parameters:
    ///   - ch: The input character code
    ///   - screen: The ncurses screen pointer
    ///   - formState: The form builder state (inout for mutation)
    ///   - form: The form that needs to be updated when state changes (inout for mutation)
    ///   - onSubmit: Closure to execute when form is submitted (ENTER on inactive field)
    ///               Receives the current formState and form as parameters to avoid exclusivity violations
    ///   - onCancel: Closure to execute when form is cancelled (ESC on inactive field)
    ///   - customKeyHandler: Optional custom key handler for form-specific keys (return true if handled)
    ///   - syncStateBeforeDraw: Optional callback to sync state before drawing. Receives current formState
    ///                          and form as parameters to avoid stale capture issues with @Sendable closures
    func handleInput<Form: FormStateUpdatable & FormStateRebuildable & FormValidatable>(
        _ ch: Int32,
        screen: OpaquePointer?,
        formState: inout FormBuilderState,
        form: inout Form,
        onSubmit: @MainActor @escaping (FormBuilderState, Form) async -> Void,
        onCancel: @escaping () -> Void,
        customKeyHandler: (@MainActor @Sendable (Int32, inout FormBuilderState, inout Form, OpaquePointer?) async -> Bool)? = nil,
        syncStateBeforeDraw: (@MainActor (FormBuilderState, Form) -> Void)? = nil
    ) async {
        // Store sync callback with type erasure - called with current formState and form before each draw
        if let callback = syncStateBeforeDraw {
            self.syncCallback = { formState, anyForm in
                if let typedForm = anyForm as? Form {
                    callback(formState, typedForm)
                }
            }
        } else {
            self.syncCallback = nil
        }
        let isFieldActive = formState.isCurrentFieldActive()

        // Give custom handler first priority
        if let customHandler = customKeyHandler {
            let handled = await customHandler(ch, &formState, &form, screen)
            if handled {
                updateFormFromState(&formState, form: &form)
                await draw(screen: screen, formState: formState, form: form)
                return
            }
        }

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                formState.nextField()
                updateFormFromState(&formState, form: &form)
                await draw(screen: screen, formState: formState, form: form)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                formState.previousField()
                updateFormFromState(&formState, form: &form)
                await draw(screen: screen, formState: formState, form: form)
            }

        case Int32(32): // SPACE - Activate field, toggle, or add space character
            await handleSpaceKey(ch, screen: screen, formState: &formState, form: &form, isFieldActive: isFieldActive)

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            await handleEnterKey(ch, screen: screen, formState: &formState, form: &form, isFieldActive: isFieldActive, onSubmit: onSubmit)

        case Int32(260), Int32(261): // KEY_LEFT/RIGHT - Navigate in text field
            if isFieldActive {
                let handled = formState.handleSpecialKey(ch)
                if handled {
                    updateFormFromState(&formState, form: &form)
                    await draw(screen: screen, formState: formState, form: form)
                }
            }

        case Int32(259), Int32(258): // KEY_UP/DOWN
            await handleUpDownKey(ch, screen: screen, formState: &formState, form: &form, isFieldActive: isFieldActive)

        case Int32(27): // ESC - Exit edit mode or cancel form
            if isFieldActive {
                formState.deactivateCurrentField()
                updateFormFromState(&formState, form: &form)
                await draw(screen: screen, formState: formState, form: form)
            } else {
                onCancel()
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE - Remove character
            if isFieldActive {
                let handled = formState.handleSpecialKey(ch)
                if handled {
                    updateFormFromState(&formState, form: &form)
                    await draw(screen: screen, formState: formState, form: form)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    formState.handleCharacterInput(char)
                    updateFormFromState(&formState, form: &form)
                    await draw(screen: screen, formState: formState, form: form)
                }
            }
        }
    }

    // MARK: - Key Handlers

    private func handleSpaceKey<Form: FormStateUpdatable & FormStateRebuildable & FormValidatable>(
        _ ch: Int32,
        screen: OpaquePointer?,
        formState: inout FormBuilderState,
        form: inout Form,
        isFieldActive: Bool
    ) async {
        if !isFieldActive {
            if let currentField = formState.getCurrentField() {
                switch currentField {
                case .toggle:
                    // Toggle fields toggle immediately without activation
                    formState.toggleCurrentField()
                    updateFormFromState(&formState, form: &form)

                    // Note: Rebuilding disabled by default - forms with conditional visibility
                    // should handle this via custom key handlers that have access to TUI data
                    // rebuildFormState(&formState, form: &form)

                    await draw(screen: screen, formState: formState, form: form)

                case .checkbox:
                    // Checkbox fields toggle immediately without activation
                    formState.toggleCurrentField()
                    updateFormFromState(&formState, form: &form)
                    await draw(screen: screen, formState: formState, form: form)

                case .select:
                    // Select fields cycle immediately without activation
                    formState.toggleCurrentField()
                    updateFormFromState(&formState, form: &form)

                    // Note: Rebuilding disabled by default - forms with conditional visibility
                    // should handle this via custom key handlers that have access to TUI data
                    // rebuildFormState(&formState, form: &form)

                    await draw(screen: screen, formState: formState, form: form)

                default:
                    // Other fields activate for editing
                    formState.activateCurrentField()
                    updateFormFromState(&formState, form: &form)
                    await draw(screen: screen, formState: formState, form: form)
                }
            }
        } else {
            if let currentField = formState.getCurrentField() {
                switch currentField {
                case .text:
                    // Add space character
                    formState.handleCharacterInput(" ")
                    updateFormFromState(&formState, form: &form)
                    await draw(screen: screen, formState: formState, form: form)

                case .selector, .multiSelect:
                    // Toggle selection
                    formState.toggleCurrentField()
                    updateFormFromState(&formState, form: &form)
                    await draw(screen: screen, formState: formState, form: form)

                default:
                    break
                }
            }
        }
    }

    private func handleEnterKey<Form: FormStateUpdatable & FormStateRebuildable & FormValidatable>(
        _ ch: Int32,
        screen: OpaquePointer?,
        formState: inout FormBuilderState,
        form: inout Form,
        isFieldActive: Bool,
        onSubmit: @MainActor @escaping (FormBuilderState, Form) async -> Void
    ) async {
        guard let tui = tui else { return }

        tui.renderCoordinator.needsRedraw = true

        if isFieldActive {
            // Deactivate field
            formState.deactivateCurrentField()
            updateFormFromState(&formState, form: &form)

            // Note: Rebuilding disabled by default - forms with conditional visibility
            // should handle this via custom key handlers that have access to TUI data
            // rebuildFormState(&formState, form: &form)

            await draw(screen: screen, formState: formState, form: form)
        } else {
            // Sync form with state before validation/submission
            updateFormFromState(&formState, form: &form)

            // Validate form
            let errors = form.validateForm()
            if errors.isEmpty {
                // Submit form - pass formState and form as parameters to avoid exclusivity violation
                // This prevents the closure from needing to capture inout parameters
                await onSubmit(formState, form)
            } else {
                // Show validation errors
                tui.statusMessage = "Validation errors: \(errors.joined(separator: ", "))"
                await draw(screen: screen, formState: formState, form: form)
            }
        }
    }

    private func handleUpDownKey<Form: FormStateUpdatable & FormStateRebuildable & FormValidatable>(
        _ ch: Int32,
        screen: OpaquePointer?,
        formState: inout FormBuilderState,
        form: inout Form,
        isFieldActive: Bool
    ) async {
        if !isFieldActive {
            // Navigate between fields
            if ch == Int32(259) {
                formState.previousField()
            } else {
                formState.nextField()
            }
            updateFormFromState(&formState, form: &form)
            await draw(screen: screen, formState: formState, form: form)
        } else {
            // Handle up/down within active field (selectors, etc.)
            let handled = formState.handleSpecialKey(ch)
            if handled {
                updateFormFromState(&formState, form: &form)
                await draw(screen: screen, formState: formState, form: form)
            }
        }
    }

    // MARK: - Form Update Helpers

    /// Updates the form from the current state
    private func updateFormFromState<Form: FormStateUpdatable & FormStateRebuildable & FormValidatable>(
        _ formState: inout FormBuilderState,
        form: inout Form
    ) {
        form.updateFromFormState(formState)
    }

    /// Rebuilds the form state to reflect conditional field visibility changes
    private func rebuildFormState<Form: FormStateUpdatable & FormStateRebuildable & FormValidatable>(
        _ formState: inout FormBuilderState,
        form: inout Form
    ) {
        formState = FormBuilderState(
            fields: form.buildFields(
                selectedFieldId: formState.getCurrentFieldId(),
                activeFieldId: formState.getActiveFieldId(),
                formState: formState
            ),
            preservingStateFrom: formState
        )
    }

    // MARK: - Drawing Helper

    private func draw<Form: FormStateUpdatable>(screen: OpaquePointer?, formState: FormBuilderState, form: Form) async {
        guard let tui = tui else { return }
        // Sync state before drawing (if callback provided)
        // formState and form are passed as parameters so the callback gets CURRENT values, not stale captured copies
        syncCallback?(formState, form)
        await tui.draw(screen: screen)
    }
}

// MARK: - Form Protocols

/// Protocol for forms that can update from FormBuilderState
protocol FormStateUpdatable {
    mutating func updateFromFormState(_ state: FormBuilderState)
}

/// Protocol for forms that can rebuild their fields dynamically
protocol FormStateRebuildable {
    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField]
}

/// Protocol for forms that can validate themselves
protocol FormValidatable {
    func validateForm() -> [String]
}

// MARK: - Universal Protocol Conformance
//
// Protocol conformance is declared in individual handler files after adapters are created.
// Each form handler creates necessary adapters for their specific form's method signatures.
