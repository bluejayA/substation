import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - KeyPair Create Input Handler (Universal Pattern)
//
// This is the NEW universal pattern that replaces 133 lines of duplicated code
// with just 53 lines. This handler demonstrates the universal form pattern.

@MainActor
extension TUI {

    /// Handle input for KeyPair create form using the universal handler
    internal func handleKeyPairCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Get local references to avoid actor-isolated inout issues
        var localFormState = keyPairCreateFormState
        var localForm = keyPairCreateForm

        // Custom key handler for KeyPair-specific behavior
        let customHandler: @MainActor @Sendable (Int32, inout FormBuilderState, inout KeyPairCreateForm, OpaquePointer?) async -> Bool = { ch, formState, form, screen in
            // TAB completion for publicKeyFilePath field
            if ch == Int32(9) { // TAB
                if formState.isCurrentFieldActive(),
                   let field = formState.getCurrentField(),
                   case .text(let textField) = field,
                   textField.id == "publicKeyFilePath" {
                    // Perform tab completion
                    let currentPath = form.publicKeyFilePath
                    let (completedPath, hasMultiple) = FilePathCompleter.tabComplete(currentPath)

                    if completedPath != currentPath {
                        // Update the form with the completed path
                        form.publicKeyFilePath = completedPath

                        // Update the text field state with new value and cursor position
                        if var textState = formState.textFieldStates["publicKeyFilePath"] {
                            textState.value = completedPath
                            textState.cursorPosition = completedPath.count
                            formState.textFieldStates["publicKeyFilePath"] = textState
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

            // Loading file when ENTER is pressed on publicKeyFilePath field
            if ch == Int32(10) || ch == Int32(13) { // ENTER
                if formState.isCurrentFieldActive(),
                   let field = formState.getCurrentField(),
                   case .text(let textField) = field,
                   textField.id == "publicKeyFilePath" {
                    // Load public key from file
                    if let error = form.loadPublicKeyFromFile() {
                        self.statusMessage = "Error: \(error)"
                    } else {
                        self.statusMessage = "Public key loaded"
                    }
                    return false // Let universal handler continue with normal ENTER behavior
                }
            }
            return false // Let universal handler process this key
        }

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localForm,
            onSubmit: { formState, form in
                // Receive formState and form as parameters to avoid exclusivity violation
                self.keyPairCreateFormState = formState
                self.keyPairCreateForm = form
                if let module = ModuleRegistry.shared.module(for: "keypairs") as? KeyPairsModule {
                    await module.submitKeyPairCreation(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .keyPairs, resetSelection: false)
            },
            customKeyHandler: customHandler
        )

        // Update actor-isolated properties with modified local copies
        keyPairCreateFormState = localFormState
        keyPairCreateForm = localForm
    }
}

// MARK: - KeyPairCreateForm Protocol Conformance
// KeyPairCreateForm naturally conforms to all three protocols
extension KeyPairCreateForm: FormStateUpdatable, FormStateRebuildable, FormValidatable {}
