import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftNCurses

// MARK: - Image Create Input Handler

@MainActor
extension TUI {

    /// Handle input for Image create form using universal handler
    internal func handleImageCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        var localFormState = imageCreateFormState
        var localFormAdapter = ImageCreateFormAdapter(form: imageCreateForm)

        // Custom key handler for special field behaviors
        let customHandler: @MainActor @Sendable (Int32, inout FormBuilderState, inout ImageCreateFormAdapter, OpaquePointer?) async -> Bool = { ch, formState, formAdapter, screen in
            // TAB completion for imageFilePath field
            if ch == Int32(9) { // TAB
                if formState.isCurrentFieldActive(),
                   let field = formState.getCurrentField(),
                   case .text(let textField) = field,
                   textField.id == ImageCreateFieldId.imageFilePath.rawValue {
                    // Perform tab completion
                    let currentPath = formAdapter.form.imageFilePath
                    let (completedPath, hasMultiple) = FilePathCompleter.tabComplete(currentPath)

                    if completedPath != currentPath {
                        // Update the form with the completed path
                        formAdapter.form.imageFilePath = completedPath

                        // Update the text field state with new value and cursor position
                        if var textState = formState.textFieldStates[ImageCreateFieldId.imageFilePath.rawValue] {
                            textState.value = completedPath
                            textState.cursorPosition = completedPath.count
                            formState.textFieldStates[ImageCreateFieldId.imageFilePath.rawValue] = textState
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

            return false // Let universal handler process
        }

        await universalFormInputHandler.handleInput(
            ch,
            screen: screen,
            formState: &localFormState,
            form: &localFormAdapter,
            onSubmit: { formState, formAdapter in
                // Sync state before submission
                self.imageCreateFormState = formState
                self.imageCreateForm = formAdapter.form
                if let module = ModuleRegistry.shared.module(for: "images") as? ImagesModule {
                    await module.createImage(screen: screen)
                }
            },
            onCancel: {
                self.changeView(to: .images, resetSelection: false)
            },
            customKeyHandler: customHandler
        )

        // Update actor-isolated properties with modified local copies
        imageCreateFormState = localFormState
        imageCreateForm = localFormAdapter.form

        // Redraw with updated state to show selector overlays
        await self.draw(screen: screen)
    }
}

// MARK: - ImageCreateForm Adapter

/// Adapter to make ImageCreateForm work with universal handler
struct ImageCreateFormAdapter: FormStateUpdatable, FormStateRebuildable, FormValidatable {
    var form: ImageCreateForm

    func buildFields(selectedFieldId: String?, activeFieldId: String?, formState: FormBuilderState) -> [FormField] {
        return form.buildFields(selectedFieldId: selectedFieldId, activeFieldId: activeFieldId, formState: formState)
    }

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        form.updateFromFormState(formState)
    }

    func validateForm() -> [String] {
        return form.validateForm()
    }
}
