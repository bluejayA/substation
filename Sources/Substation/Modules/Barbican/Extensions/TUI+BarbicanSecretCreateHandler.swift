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

// MARK: - Barbican Secret Create Input Handler

@MainActor
extension TUI {

    /// Handle input for Barbican Secret create form using universal handler
    internal func handleBarbicanSecretCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Normal form handling with universal handler
        var localFormState = barbicanSecretCreateFormState
        var localFormAdapter = BarbicanSecretCreateFormAdapter(form: barbicanSecretCreateForm)

        // Custom key handler for special field behaviors
        let customHandler: @MainActor @Sendable (Int32, inout FormBuilderState, inout BarbicanSecretCreateFormAdapter, OpaquePointer?) async -> Bool = { ch, formState, formAdapter, screen in
            // TAB completion for payloadFilePath field
            if ch == Int32(9) { // TAB
                if formState.isCurrentFieldActive(),
                   let field = formState.getCurrentField(),
                   case .text(let textField) = field,
                   textField.id == BarbicanSecretCreateFieldId.payloadFilePath.rawValue {
                    // Perform tab completion
                    let currentPath = formAdapter.form.payloadFilePath
                    let (completedPath, hasMultiple) = FilePathCompleter.tabComplete(currentPath)

                    if completedPath != currentPath {
                        // Update the form with the completed path
                        formAdapter.form.payloadFilePath = completedPath

                        // Update the text field state with new value and cursor position
                        if var textState = formState.textFieldStates[BarbicanSecretCreateFieldId.payloadFilePath.rawValue] {
                            textState.value = completedPath
                            textState.cursorPosition = completedPath.count
                            formState.textFieldStates[BarbicanSecretCreateFieldId.payloadFilePath.rawValue] = textState
                        }

                        if hasMultiple {
                            // Show hint that there are multiple matches
                            let completions = FilePathCompleter.getCompletions(for: completedPath)
                            let displayCount = min(completions.count, 5)
                            let names = completions.prefix(displayCount).map { URL(fileURLWithPath: $0).lastPathComponent }
                            let moreText = completions.count > displayCount ? " ..." : ""
                            self.statusMessage = "Matches: \(names.joined(separator: ", "))\(moreText)"
                        } else {
                            self.statusMessage = ""
                        }
                    } else if hasMultiple {
                        // No progress but multiple matches - show them
                        let completions = FilePathCompleter.getCompletions(for: currentPath)
                        let displayCount = min(completions.count, 5)
                        let names = completions.prefix(displayCount).map { URL(fileURLWithPath: $0).lastPathComponent }
                        let moreText = completions.count > displayCount ? " ..." : ""
                        self.statusMessage = "Matches: \(names.joined(separator: ", "))\(moreText)"
                    }
                    return true // TAB handled, don't pass to universal handler
                }
            }

            // ENTER on file path field loads the file
            if (ch == Int32(10) || ch == Int32(13)) && formState.isCurrentFieldActive() {
                if let field = formState.getCurrentField() {
                    if case .text(let textField) = field,
                       textField.id == BarbicanSecretCreateFieldId.payloadFilePath.rawValue {
                        if let error = formAdapter.form.loadPayloadFromFile() {
                            self.statusMessage = error
                        } else {
                            self.statusMessage = "File loaded successfully"
                        }
                        return false // Let universal handler continue with deactivation
                    }
                }
            }

            return false // Let universal handler process
        }

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localFormAdapter,
            onSubmit: { formState, formAdapter in
                // Sync state before submission
                self.barbicanSecretCreateFormState = formState
                self.barbicanSecretCreateForm = formAdapter.form
                if let module = ModuleRegistry.shared.module(for: "barbican") as? BarbicanModule {
                    await module.createSecret(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .barbicanSecrets, resetSelection: false)
            },
            customKeyHandler: customHandler
        )

        // Update actor-isolated properties with modified local copies
        barbicanSecretCreateFormState = localFormState
        barbicanSecretCreateForm = localFormAdapter.form

        // Redraw with updated state to show selector overlays
        await self.draw(screen: screen)
    }

}

// MARK: - BarbicanSecretCreateForm Adapter

/// Adapter to make BarbicanSecretCreateForm work with universal handler
struct BarbicanSecretCreateFormAdapter: FormStateUpdatable, FormStateRebuildable, FormValidatable {
    var form: BarbicanSecretCreateForm

    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return form.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: formState)
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        form.updateFromFormState(formState)
    }

    func validateForm() -> [String] {
        return form.validate()
    }
}
