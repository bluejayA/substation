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

// MARK: - Router Create Input Handler

@MainActor
extension TUI {

    internal func handleRouterCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        let isFieldActive = routerCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                routerCreateFormState.nextField()
                routerCreateForm.updateFromFormState(routerCreateFormState)

                routerCreateFormState = FormBuilderState(
                    fields: routerCreateForm.buildFields(
                        selectedFieldId: routerCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: routerCreateFormState,
                        availabilityZones: dataManager.availabilityZones,
                        externalNetworks: dataManager.externalNetworks
                    ),
                    preservingStateFrom: routerCreateFormState
                )

                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Navigate to previous field
            if !isFieldActive {
                routerCreateFormState.previousField()
                routerCreateForm.updateFromFormState(routerCreateFormState)

                routerCreateFormState = FormBuilderState(
                    fields: routerCreateForm.buildFields(
                        selectedFieldId: routerCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: routerCreateFormState,
                        availabilityZones: dataManager.availabilityZones,
                        externalNetworks: dataManager.externalNetworks
                    ),
                    preservingStateFrom: routerCreateFormState
                )

                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field, toggle, or add space character
            if !isFieldActive {
                if let currentField = routerCreateFormState.getCurrentField() {
                    switch currentField {
                    case .toggle:
                        routerCreateFormState.toggleCurrentField()
                        routerCreateForm.updateFromFormState(routerCreateFormState)
                        routerCreateFormState = FormBuilderState(
                            fields: routerCreateForm.buildFields(
                                selectedFieldId: routerCreateFormState.getCurrentFieldId(),
                                activeFieldId: routerCreateFormState.getActiveFieldId(),
                                formState: routerCreateFormState,
                                availabilityZones: dataManager.availabilityZones,
                                externalNetworks: dataManager.externalNetworks
                            ),
                            preservingStateFrom: routerCreateFormState
                        )
                        await self.draw(screen: screen)
                    default:
                        routerCreateFormState.activateCurrentField()
                        routerCreateForm.updateFromFormState(routerCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            } else {
                if let currentField = routerCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text:
                        routerCreateFormState.handleCharacterInput(" ")
                        routerCreateForm.updateFromFormState(routerCreateFormState)
                        await self.draw(screen: screen)
                    case .selector:
                        routerCreateFormState.toggleCurrentField()
                        routerCreateForm.updateFromFormState(routerCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            needsRedraw = true
            if isFieldActive {
                routerCreateFormState.deactivateCurrentField()
                routerCreateForm.updateFromFormState(routerCreateFormState)

                routerCreateFormState = FormBuilderState(
                    fields: routerCreateForm.buildFields(
                        selectedFieldId: routerCreateFormState.getCurrentFieldId(),
                        activeFieldId: nil,
                        formState: routerCreateFormState,
                        availabilityZones: dataManager.availabilityZones,
                        externalNetworks: dataManager.externalNetworks
                    ),
                    preservingStateFrom: routerCreateFormState
                )

                await self.draw(screen: screen)
            } else {
                let errors = routerCreateForm.validateForm(
                    availabilityZones: dataManager.availabilityZones,
                    externalNetworks: dataManager.externalNetworks
                )
                if errors.isEmpty {
                    await resourceOperations.submitRouterCreation(screen: screen)
                } else {
                    statusMessage = "Validation errors: \(errors.joined(separator: ", "))"
                    await self.draw(screen: screen)
                }
            }

        case Int32(260), Int32(261): // KEY_LEFT/RIGHT - Navigate in text field or selector
            if isFieldActive {
                let handled = routerCreateFormState.handleSpecialKey(ch)
                if handled {
                    routerCreateForm.updateFromFormState(routerCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        case Int32(259), Int32(258): // KEY_UP/DOWN - Navigate in selector or between fields
            if isFieldActive {
                let handled = routerCreateFormState.handleSpecialKey(ch)
                if handled {
                    routerCreateForm.updateFromFormState(routerCreateFormState)
                    await self.draw(screen: screen)
                }
            } else {
                if ch == Int32(259) {
                    routerCreateFormState.previousField()
                } else {
                    routerCreateFormState.nextField()
                }
                routerCreateForm.updateFromFormState(routerCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(27): // ESC - Exit edit mode or cancel creation
            if isFieldActive {
                routerCreateFormState.deactivateCurrentField()
                routerCreateForm.updateFromFormState(routerCreateFormState)
                await self.draw(screen: screen)
            } else {
                self.changeView(to: .routers, resetSelection: false)
            }

        case Int32(8), Int32(127), Int32(263): // BACKSPACE/DELETE - Remove character
            if isFieldActive {
                let handled = routerCreateFormState.handleSpecialKey(ch)
                if handled {
                    routerCreateForm.updateFromFormState(routerCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        default:
            if isFieldActive && ch >= 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    routerCreateFormState.handleCharacterInput(char)
                    routerCreateForm.updateFromFormState(routerCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }
    }
}
