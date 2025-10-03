import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftTUI
import MemoryKit

// MARK: - Floating IP Create Input Handler

@MainActor
extension TUI {

    internal func handleFloatingIPCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = self.floatingIPCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Next field
            if !isFieldActive {
                self.floatingIPCreateFormState.nextField()
                self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Previous field
            if !isFieldActive {
                self.floatingIPCreateFormState.previousField()
                self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field or add space character
            if let currentField = self.floatingIPCreateFormState.getCurrentField() {
                switch currentField {
                case .text:
                    if !isFieldActive {
                        self.floatingIPCreateFormState.activateCurrentField()
                        self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                        await self.draw(screen: screen)
                    } else {
                        self.floatingIPCreateFormState.handleCharacterInput(" ")
                        self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                        await self.draw(screen: screen)
                    }
                case .selector:
                    if isFieldActive {
                        self.floatingIPCreateFormState.toggleCurrentField()
                        self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                        self.floatingIPCreateFormState = FormBuilderState(
                            fields: self.floatingIPCreateForm.buildFields(
                                externalNetworks: self.cachedNetworks.filter { $0.external == true },
                                subnets: self.cachedSubnets,
                                selectedFieldId: self.floatingIPCreateFormState.getCurrentFieldId(),
                                activeFieldId: self.floatingIPCreateFormState.getActiveFieldId(),
                                formState: self.floatingIPCreateFormState
                            ),
                            preservingStateFrom: self.floatingIPCreateFormState
                        )
                        await self.draw(screen: screen)
                    } else {
                        self.floatingIPCreateFormState.activateCurrentField()
                        self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                        await self.draw(screen: screen)
                    }
                default:
                    if !isFieldActive {
                        self.floatingIPCreateFormState.activateCurrentField()
                        self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            needsRedraw = true
            if isFieldActive {
                self.floatingIPCreateFormState.deactivateCurrentField()
                self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                self.floatingIPCreateFormState = FormBuilderState(
                    fields: self.floatingIPCreateForm.buildFields(
                        externalNetworks: self.cachedNetworks.filter { $0.external == true },
                        subnets: self.cachedSubnets,
                        selectedFieldId: self.floatingIPCreateFormState.getCurrentFieldId(),
                        activeFieldId: self.floatingIPCreateFormState.getActiveFieldId(),
                        formState: self.floatingIPCreateFormState
                    ),
                    preservingStateFrom: self.floatingIPCreateFormState
                )
                await self.draw(screen: screen)
            } else {
                if self.floatingIPCreateFormState.validateForm() {
                    await self.resourceOperations.submitFloatingIPCreation(screen: screen)
                } else {
                    self.statusMessage = "Validation failed. Please check the form for errors."
                    await self.draw(screen: screen)
                }
            }

        case Int32(27): // ESC - Exit field edit mode or cancel creation
            if isFieldActive {
                self.floatingIPCreateFormState.cancelCurrentField()
                self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                await self.draw(screen: screen)
            } else {
                self.currentView = .floatingIPs
                self.floatingIPCreateForm = FloatingIPCreateForm()
                self.floatingIPCreateFormState = FormBuilderState(
                    fields: self.floatingIPCreateForm.buildFields(
                        externalNetworks: self.cachedNetworks.filter { $0.external == true },
                        subnets: self.cachedSubnets,
                        selectedFieldId: nil
                    )
                )
                await self.draw(screen: screen)
            }

        case 258: // DOWN - Navigate down in form or selector
            if !isFieldActive {
                self.floatingIPCreateFormState.nextField()
                self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                await self.draw(screen: screen)
            } else {
                if self.floatingIPCreateFormState.handleSpecialKey(ch) {
                    self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        case 259: // UP - Navigate up in form or selector
            if !isFieldActive {
                self.floatingIPCreateFormState.previousField()
                self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                await self.draw(screen: screen)
            } else {
                if self.floatingIPCreateFormState.handleSpecialKey(ch) {
                    self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        case Int32(127), Int32(8): // BACKSPACE
            if isFieldActive {
                if self.floatingIPCreateFormState.handleSpecialKey(ch) {
                    self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            if isFieldActive {
                if ch >= 32 && ch < 127 {
                    let char = Character(UnicodeScalar(Int(ch))!)
                    self.floatingIPCreateFormState.handleCharacterInput(char)
                    self.floatingIPCreateForm.updateFromFormState(self.floatingIPCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}
