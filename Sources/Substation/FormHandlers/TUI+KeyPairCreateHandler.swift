import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftTUI
import MemoryKit

@MainActor
extension TUI {

    internal func handleKeyPairCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = keyPairCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB
            if !isFieldActive {
                keyPairCreateFormState.nextField()
                keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE
            if let currentField = keyPairCreateFormState.getCurrentField() {
                switch currentField {
                case .selector:
                    if !isFieldActive {
                        // Open selector
                        keyPairCreateFormState.activateCurrentField()
                        keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Toggle selection
                        keyPairCreateFormState.toggleCurrentField()
                        keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                        await self.draw(screen: screen)
                    }
                case .text:
                    if !isFieldActive {
                        // Activate text field
                        keyPairCreateFormState.activateCurrentField()
                        keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                        await self.draw(screen: screen)
                    } else {
                        // Add space character
                        keyPairCreateFormState.handleCharacterInput(" ")
                        keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    break
                }
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                keyPairCreateFormState.deactivateCurrentField()
                keyPairCreateForm.updateFromFormState(keyPairCreateFormState)

                // If was file path field, load the file
                if let field = keyPairCreateFormState.getCurrentField(),
                   case .text(let textField) = field,
                   textField.id == "publicKeyFilePath" {
                    if let error = keyPairCreateForm.loadPublicKeyFromFile() {
                        statusMessage = "Error: \(error)"
                    } else {
                        statusMessage = "Public key loaded"
                    }
                }

                await self.draw(screen: screen)
            } else {
                // Submit form
                let errors = keyPairCreateForm.validateForm()
                if !errors.isEmpty {
                    statusMessage = "Errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                    return
                }

                await resourceOperations.submitKeyPairCreation(screen: screen)
            }

        case Int32(259), Int32(258): // UP/DOWN
            if isFieldActive {
                let handled = keyPairCreateFormState.handleSpecialKey(ch)
                if handled {
                    keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    keyPairCreateFormState.previousField()
                } else {
                    keyPairCreateFormState.nextField()
                }
                keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC
            if isFieldActive {
                keyPairCreateFormState.cancelCurrentField()
                keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                await self.draw(screen: screen)
            } else {
                self.changeView(to: .keyPairs, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE
            if isFieldActive {
                let handled = keyPairCreateFormState.handleSpecialKey(ch)
                if handled {
                    keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            // Character input
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    keyPairCreateFormState.handleCharacterInput(Character(scalar))
                    keyPairCreateForm.updateFromFormState(keyPairCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}
