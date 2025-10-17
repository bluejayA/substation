import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses

/// Centralized handler for all form-based input handling
/// This class eliminates duplicate input handling code across 30+ FormHandlers by:
/// 1. Delegating basic navigation (UP/DOWN/PAGE/HOME/END/ESC) to NavigationInputHandler
/// 2. Providing reusable patterns for form-specific operations (TAB/SPACE/ENTER)
/// 3. Supporting both FormBuilder-based and simple management-based handlers
/// 4. Implements NavigationHandlerProtocol for standardized navigation
@MainActor
final class FormInputHandler: NavigationHandlerProtocol {
    weak var tui: TUI?
    private let navigationHandler: NavigationInputHandler

    /// Navigation context - defaults to custom, can be overridden by callers
    var navigationContext: NavigationContext = .custom

    init(tui: TUI) {
        self.tui = tui
        self.navigationHandler = NavigationInputHandler(tui: tui)
    }

    /// Handle view-specific input (not used in FormInputHandler, delegation is done manually)
    func handleViewSpecificInput(_ ch: Int32, screen: OpaquePointer?) async -> Bool {
        // FormInputHandler uses custom delegation patterns
        return false
    }

    // MARK: - Management-based Input Handling (Simple UP/DOWN selection with SPACE toggle)

    /// Handle input for simple management views (SecurityGroup, Volume, Network management)
    /// These views use UP/DOWN for selection and SPACE for toggling
    func handleManagementInput(
        _ ch: Int32,
        screen: OpaquePointer?,
        itemCount: Int,
        onToggle: () async -> Void,
        onEnter: () async -> Void,
        additionalHandling: ((Int32) async -> Bool)? = nil
    ) async -> Bool {
        // Try additional custom handling first (for TAB, search, etc.)
        if let handler = additionalHandling, await handler(ch) {
            return true
        }

        // Try navigation using static methods
        guard let tui = tui else { return false }
        if await NavigationInputHandler.handleManagementNavigation(ch, itemCount: itemCount, tui: tui) {
            return true
        }

        // Handle ESC key
        if ch == Int32(27) {
            if await NavigationInputHandler.handleEscapeKey(tui: tui) {
                return true
            }
        }

        switch ch {
        case Int32(32): // SPACE - Toggle selection
            await onToggle()
            return true

        case Int32(10), Int32(13): // ENTER - Apply changes
            await onEnter()
            return true

        default:
            return false
        }
    }

    // MARK: - FormBuilder-based Input Handling (Complex forms with field navigation)

    /// Handle input for FormBuilder-based creation/edit forms
    /// These forms use FormBuilderState for field navigation and editing
    func handleFormBuilderInput(
        _ ch: Int32,
        screen: OpaquePointer?,
        formState: inout FormBuilderState,
        form: Any,
        onSubmit: () async -> Void,
        onCancel: () -> Void,
        updateFormState: (FormBuilderState) -> FormBuilderState
    ) async -> Bool {
        let isFieldActive = formState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                formState.nextField()
                formState = updateFormState(formState)
                guard let tui = tui else { return true }
                await tui.draw(screen: screen)
            }
            return true

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                formState.previousField()
                formState = updateFormState(formState)
                guard let tui = tui else { return true }
                await tui.draw(screen: screen)
            }
            return true

        case Int32(32): // SPACE - Activate field, toggle, or add space character
            return await handleSpaceKey(ch, screen: screen, formState: &formState, updateFormState: updateFormState)

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            guard let tui = tui else { return true }
            tui.needsRedraw = true
            if isFieldActive {
                formState.deactivateCurrentField()
                formState = updateFormState(formState)
                await tui.draw(screen: screen)
            } else {
                await onSubmit()
            }
            return true

        case Int32(260), Int32(261): // KEY_LEFT/RIGHT - Navigate in text field
            if isFieldActive {
                let handled = formState.handleSpecialKey(ch)
                if handled {
                    guard let tui = tui else { return true }
                    await tui.draw(screen: screen)
                }
            }
            return true

        case Int32(259), Int32(258): // KEY_UP/DOWN - Navigate between fields or within selector
            if isFieldActive {
                // When field is active, delegate to field-specific handling (e.g., selector navigation)
                let handled = formState.handleSpecialKey(ch)
                if handled {
                    guard let tui = tui else { return true }
                    await tui.draw(screen: screen)
                }
            } else {
                // When field is not active, navigate between fields
                if ch == Int32(259) {
                    formState.previousField()
                } else {
                    formState.nextField()
                }
                guard let tui = tui else { return true }
                await tui.draw(screen: screen)
            }
            return true

        case Int32(27): // ESC - Exit edit mode or cancel creation
            if isFieldActive {
                formState.deactivateCurrentField()
                guard let tui = tui else { return true }
                await tui.draw(screen: screen)
            } else {
                onCancel()
            }
            return true

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE - Remove character
            if isFieldActive {
                let handled = formState.handleSpecialKey(ch)
                if handled {
                    guard let tui = tui else { return true }
                    await tui.draw(screen: screen)
                }
            }
            return true

        default:
            // Handle character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    formState.handleCharacterInput(char)
                    guard let tui = tui else { return true }
                    await tui.draw(screen: screen)
                }
            }
            return false
        }
    }

    // MARK: - Specialized Input Handling

    /// Handle SPACE key for FormBuilder forms
    private func handleSpaceKey(
        _ ch: Int32,
        screen: OpaquePointer?,
        formState: inout FormBuilderState,
        updateFormState: (FormBuilderState) -> FormBuilderState
    ) async -> Bool {
        guard let tui = tui else { return true }
        let isFieldActive = formState.isCurrentFieldActive()

        if !isFieldActive {
            if let currentField = formState.getCurrentField() {
                switch currentField {
                case .toggle:
                    formState.toggleCurrentField()
                    formState = updateFormState(formState)
                    await tui.draw(screen: screen)
                default:
                    formState.activateCurrentField()
                    await tui.draw(screen: screen)
                }
            }
        } else {
            if let currentField = formState.getCurrentField() {
                switch currentField {
                case .text:
                    formState.handleCharacterInput(" ")
                    await tui.draw(screen: screen)
                case .selector, .multiSelect:
                    formState.toggleCurrentField()
                    formState = updateFormState(formState)
                    await tui.draw(screen: screen)
                default:
                    break
                }
            }
        }
        return true
    }

    /// Handle TAB key for mode switching (e.g., attach/detach toggle)
    func handleModeSwitch(
        _ mode: inout AttachmentMode,
        resetSelection: () -> Void
    ) {
        mode = (mode == .attach) ? .detach : .attach
        resetSelection()
    }
}
