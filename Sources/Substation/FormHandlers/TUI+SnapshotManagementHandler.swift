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

// MARK: - Snapshot Management Input Handler

@MainActor
extension TUI {

    var snapshotManagementNavigationContext: NavigationContext {
        let fieldCount = snapshotManagementFormState.fields.count
        return .form(fieldCount: fieldCount)
    }

    internal func handleSnapshotManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if a field is currently active
        let isFieldActive = snapshotManagementFormState.isCurrentFieldActive()

        // Rebuild form state with current form values
        snapshotManagementFormState = FormBuilderState(fields: snapshotManagementForm.buildFields(
            selectedFieldId: snapshotManagementFormState.getCurrentFieldId(),
            activeFieldId: snapshotManagementFormState.getActiveFieldId(),
            formState: snapshotManagementFormState
        ))

        // Try common navigation when NOT in field edit mode
        if !isFieldActive {
            if await handleCommonNavigation(ch, screen: screen, context: snapshotManagementNavigationContext) {
                return
            }
        }

        // Handle view-specific input
        await handleSnapshotManagementSpecificInput(ch, screen: screen, isFieldActive: isFieldActive)
    }

    private func handleSnapshotManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?, isFieldActive: Bool) async {
        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                snapshotManagementFormState.nextField()
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                snapshotManagementFormState.deactivateCurrentField()
            } else if snapshotManagementForm.isValid() {
                // Submit form
                await actions.executeSnapshotCreation(screen: screen)
                return
            }

        case Int32(32): // SPACE - Activate current field for editing
            if !isFieldActive {
                snapshotManagementFormState.activateCurrentField()
            } else {
                // Add space character
                snapshotManagementFormState.handleCharacterInput(" ")
            }

        case Int32(127), Int32(8): // BACKSPACE
            if isFieldActive {
                let _ = snapshotManagementFormState.handleSpecialKey(ch)
            }

        default:
            // Handle printable characters for text input
            if isFieldActive && ch >= 32 && ch <= 126, let unicodeScalar = UnicodeScalar(Int(ch)) {
                let character = Character(unicodeScalar)
                snapshotManagementFormState.handleCharacterInput(character)
            }
        }

        // Update form values from state
        if let nameState = snapshotManagementFormState.textFieldStates[SnapshotFieldId.name.rawValue] {
            snapshotManagementForm.snapshotName = nameState.value
        }
        if let descState = snapshotManagementFormState.textFieldStates[SnapshotFieldId.description.rawValue] {
            snapshotManagementForm.snapshotDescription = descState.value
        }

        needsRedraw = true
    }
}
