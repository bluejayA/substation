import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import OSClient
import SwiftTUI

// MARK: - Server Create Form Input Handler

@MainActor
extension TUI {

    internal func handleServerCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if a field is currently active (being edited)
        let isFieldActive = serverCreateFormState.isCurrentFieldActive()

        switch ch {
        case Int32(9): // TAB - Cycle select options, switch source mode, or navigate to next field
            if isFieldActive {
                if let currentField = serverCreateFormState.getCurrentField() {
                    switch currentField {
                    case .select:
                        // For select fields, cycle through options
                        serverCreateFormState.toggleCurrentField()
                        serverCreateForm.updateFromFormState(serverCreateFormState)
                        await self.draw(screen: screen)
                    case .selector(let selectorField) where selectorField.id == ServerCreateFieldId.source.rawValue:
                        // For source selector, TAB toggles between image/volume mode
                        serverCreateForm.toggleBootSource()
                        // Clear selection when switching modes
                        if serverCreateForm.bootSource == .image {
                            serverCreateForm.selectedVolumeID = nil
                        } else {
                            serverCreateForm.selectedImageID = nil
                        }
                        // Rebuild state to reflect mode change
                        serverCreateFormState = FormBuilderState(fields: serverCreateForm.buildFields(
                            selectedFieldId: serverCreateFormState.getCurrentFieldId(),
                            activeFieldId: serverCreateFormState.getActiveFieldId(),
                            formState: serverCreateFormState
                        ))
                        await self.draw(screen: screen)
                    case .selector(let selectorField) where selectorField.id == ServerCreateFieldId.flavor.rawValue:
                        // For flavor selector, TAB toggles between manual/workload-based mode
                        serverCreateForm.toggleFlavorSelectionMode()
                        // Rebuild state to reflect mode change
                        serverCreateFormState = FormBuilderState(fields: serverCreateForm.buildFields(
                            selectedFieldId: serverCreateFormState.getCurrentFieldId(),
                            activeFieldId: serverCreateFormState.getActiveFieldId(),
                            formState: serverCreateFormState
                        ))
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            } else {
                serverCreateFormState.nextField()
                serverCreateForm.updateFromFormState(serverCreateFormState)
                await self.draw(screen: screen)
            }

        case 353: // SHIFT+TAB - Cycle select options backwards or navigate to previous field
            if isFieldActive {
                // If current field is select type, cycle options backwards
                if let currentField = serverCreateFormState.getCurrentField() {
                    if case .select = currentField {
                        serverCreateFormState.cyclePreviousOption()
                        serverCreateForm.updateFromFormState(serverCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            } else {
                serverCreateFormState.previousField()
                serverCreateForm.updateFromFormState(serverCreateFormState)
                await self.draw(screen: screen)
            }

        case Int32(32): // SPACE - Activate field or add space character
            if !isFieldActive {
                // Not active: activate the field
                serverCreateFormState.activateCurrentField()
                serverCreateForm.updateFromFormState(serverCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Active: check field type to determine behavior
                if let currentField = serverCreateFormState.getCurrentField() {
                    switch currentField {
                    case .text, .number:
                        // For text/number fields, add space as character
                        serverCreateFormState.handleCharacterInput(" ")
                        serverCreateForm.updateFromFormState(serverCreateFormState)
                        await self.draw(screen: screen)
                    case .toggle, .select:
                        // For toggle/select fields, space toggles
                        serverCreateFormState.toggleCurrentField()
                        serverCreateForm.updateFromFormState(serverCreateFormState)
                        await self.draw(screen: screen)
                    case .selector(let selectorField):
                        // Special handling for source selector
                        if selectorField.id == ServerCreateFieldId.source.rawValue {
                            // Get the highlighted item from the filtered and sorted list
                            if let state = serverCreateFormState.selectorStates[selectorField.id] {
                                let filteredItems = state.getFilteredItems()
                                let highlightedIndex = state.highlightedIndex

                                if serverCreateForm.bootSource == .image {
                                    // Sort images alphabetically (same as SourceSelectionView)
                                    let sortedImages = filteredItems.compactMap { $0 as? Image }.sorted {
                                        ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
                                    }
                                    if highlightedIndex < sortedImages.count {
                                        let selectedImage = sortedImages[highlightedIndex]
                                        serverCreateForm.selectedImageID = selectedImage.id
                                        serverCreateForm.selectedVolumeID = nil
                                        // Update the state
                                        if var state = serverCreateFormState.selectorStates[selectorField.id] {
                                            state.selectedItemId = selectedImage.id
                                            serverCreateFormState.selectorStates[selectorField.id] = state
                                        }
                                        await self.draw(screen: screen)
                                    }
                                } else {
                                    // Boot from volume - sort volumes alphabetically (same as SourceSelectionView)
                                    let sortedVolumes = filteredItems.compactMap { $0 as? Volume }.sorted {
                                        ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
                                    }
                                    if highlightedIndex < sortedVolumes.count {
                                        let selectedVolume = sortedVolumes[highlightedIndex]
                                        serverCreateForm.selectedVolumeID = selectedVolume.id
                                        serverCreateForm.selectedImageID = nil
                                        // Update the state
                                        if var state = serverCreateFormState.selectorStates[selectorField.id] {
                                            state.selectedItemId = selectedVolume.id
                                            serverCreateFormState.selectorStates[selectorField.id] = state
                                        }
                                        await self.draw(screen: screen)
                                    }
                                }
                            }
                        } else if selectorField.id == ServerCreateFieldId.flavor.rawValue &&
                           serverCreateForm.flavorSelectionMode == .workloadBased {
                            // Special handling for flavor selector in workload mode
                            if serverCreateForm.selectedCategoryIndex == nil {
                                // Drill into the highlighted category
                                serverCreateForm.selectedCategoryIndex = serverCreateFormState.selectorStates[selectorField.id]?.highlightedIndex
                                await self.draw(screen: screen)
                            } else {
                                // In category detail: select the highlighted flavor
                                let highlightedIndex = serverCreateFormState.selectorStates[selectorField.id]?.highlightedIndex ?? 0
                                // Get the category and its flavors
                                let categories = FlavorSelectionView.generateWorkloadRecommendations(flavors: serverCreateForm.flavors)
                                if let categoryIdx = serverCreateForm.selectedCategoryIndex,
                                   categoryIdx < categories.count {
                                    let category = categories[categoryIdx]
                                    if highlightedIndex < category.flavors.count {
                                        let selectedFlavor = category.flavors[highlightedIndex]
                                        serverCreateForm.selectedFlavorID = selectedFlavor.id
                                        // Also update the state so it's marked as selected
                                        if var state = serverCreateFormState.selectorStates[selectorField.id] {
                                            state.selectedItemId = selectedFlavor.id
                                            serverCreateFormState.selectorStates[selectorField.id] = state
                                        }
                                        await self.draw(screen: screen)
                                    }
                                }
                            }
                        } else {
                            // Normal selection behavior
                            serverCreateFormState.toggleCurrentField()
                            serverCreateForm.updateFromFormState(serverCreateFormState)
                            await self.draw(screen: screen)
                        }
                    case .multiSelect:
                        // For multiselect fields, space toggles selection
                        serverCreateFormState.toggleCurrentField()
                        serverCreateForm.updateFromFormState(serverCreateFormState)
                        await self.draw(screen: screen)
                    default:
                        break
                    }
                }
            }

        case Int32(10), Int32(13): // ENTER - Deactivate field or submit form
            needsRedraw = true
            if isFieldActive {
                // Exit field editing/selection mode
                // Special handling for flavor selector in workload mode
                if let currentField = serverCreateFormState.getCurrentField(),
                   case .selector(let selectorField) = currentField,
                   selectorField.id == ServerCreateFieldId.flavor.rawValue,
                   serverCreateForm.flavorSelectionMode == .workloadBased {
                    // Clear category selection when exiting
                    serverCreateForm.selectedCategoryIndex = nil
                }
                serverCreateFormState.deactivateCurrentField()
                serverCreateForm.updateFromFormState(serverCreateFormState)
                await self.draw(screen: screen)
            } else {
                // Submit form if valid
                if serverCreateForm.isValid() {
                    await resourceOperations.createServer()
                } else {
                    let errors = serverCreateForm.validate()
                    statusMessage = "Validation failed: \(errors.first ?? "Unknown error")"
                    await self.draw(screen: screen)
                }
            }

        case Int32(27): // ESC - Cancel field editing or cancel creation
            if isFieldActive {
                // Check if we're in a category detail view and should go back to category list
                if let currentField = serverCreateFormState.getCurrentField(),
                   case .selector(let selectorField) = currentField,
                   selectorField.id == ServerCreateFieldId.flavor.rawValue,
                   serverCreateForm.flavorSelectionMode == .workloadBased,
                   serverCreateForm.selectedCategoryIndex != nil {
                    // Go back to category list
                    serverCreateForm.selectedCategoryIndex = nil
                    await self.draw(screen: screen)
                } else {
                    // Normal deactivation
                    serverCreateFormState.deactivateCurrentField()
                    serverCreateForm.updateFromFormState(serverCreateFormState)
                    await self.draw(screen: screen)
                }
            } else {
                // Cancel and return to server list
                currentView = .servers
                serverCreateForm.reset()
                serverCreateFormState = FormBuilderState(fields: [])
                await self.draw(screen: screen)
            }

        case Int32(127), Int32(8): // BACKSPACE - Delete character
            if isFieldActive {
                let handled = serverCreateFormState.handleSpecialKey(ch)
                if handled {
                    serverCreateForm.updateFromFormState(serverCreateFormState)
                    await self.draw(screen: screen)
                }
            }

        case 258, 259: // DOWN/UP - Navigate within active field or between fields
            if isFieldActive {
                // Special bounds checking for flavor selector in category detail mode
                if let currentField = serverCreateFormState.getCurrentField(),
                   case .selector(let selectorField) = currentField,
                   selectorField.id == ServerCreateFieldId.flavor.rawValue,
                   serverCreateForm.flavorSelectionMode == .workloadBased,
                   let categoryIdx = serverCreateForm.selectedCategoryIndex {
                    // In category detail: limit navigation to category's flavor count
                    let categories = FlavorSelectionView.generateWorkloadRecommendations(flavors: serverCreateForm.flavors)
                    if categoryIdx < categories.count {
                        let category = categories[categoryIdx]
                        let maxIndex = category.flavors.count - 1
                        if var state = serverCreateFormState.selectorStates[selectorField.id] {
                            let currentIndex = state.highlightedIndex
                            if ch == 258 { // DOWN
                                state.highlightedIndex = min(currentIndex + 1, maxIndex)
                            } else { // UP
                                state.highlightedIndex = max(currentIndex - 1, 0)
                            }
                            serverCreateFormState.selectorStates[selectorField.id] = state
                            await self.draw(screen: screen)
                        }
                    }
                } else {
                    // Normal navigation
                    let handled = serverCreateFormState.handleSpecialKey(ch)
                    if handled {
                        serverCreateForm.updateFromFormState(serverCreateFormState)
                        await self.draw(screen: screen)
                    }
                }
            } else {
                // Navigate between fields
                if ch == 258 { // DOWN
                    serverCreateFormState.nextField()
                } else { // UP
                    serverCreateFormState.previousField()
                }
                serverCreateForm.updateFromFormState(serverCreateFormState)
                await self.draw(screen: screen)
            }

        default:
            // Handle character input for text fields (excluding SPACE which is handled above)
            if isFieldActive && ch > 32 && ch < 127 {
                if let scalar = UnicodeScalar(Int(ch)) {
                    let char = Character(scalar)
                    serverCreateFormState.handleCharacterInput(char)
                    serverCreateForm.updateFromFormState(serverCreateFormState)
                    await self.draw(screen: screen)
                }
            }
        }

        // Rebuild form state to reflect any changes in form fields
        // IMPORTANT: Pass previous state to preserve navigation, search, and activation state
        serverCreateFormState = FormBuilderState(
            fields: serverCreateForm.buildFields(
                selectedFieldId: serverCreateFormState.getCurrentFieldId(),
                activeFieldId: serverCreateFormState.getActiveFieldId(),
                formState: serverCreateFormState
            ),
            preservingStateFrom: serverCreateFormState
        )
    }
}
