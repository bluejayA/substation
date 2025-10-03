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

// MARK: - Volume Snapshot Management Input Handler

@MainActor
extension TUI {

    internal func handleVolumeSnapshotManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if a field is currently active
        let isFieldActive = volumeSnapshotManagementFormState.isCurrentFieldActive()

        // Rebuild form state with current form values
        volumeSnapshotManagementFormState = FormBuilderState(fields: volumeSnapshotManagementForm.buildFields(
            selectedFieldId: volumeSnapshotManagementFormState.getCurrentFieldId(),
            activeFieldId: volumeSnapshotManagementFormState.getActiveFieldId(),
            formState: volumeSnapshotManagementFormState
        ), preservingStateFrom: volumeSnapshotManagementFormState)

        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                volumeSnapshotManagementFormState.nextField()
            }

        case Int32(259): // UP - Navigate to previous field
            if !isFieldActive {
                volumeSnapshotManagementFormState.previousField()
            }

        case Int32(258): // DOWN - Navigate to next field
            if !isFieldActive {
                volumeSnapshotManagementFormState.nextField()
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                volumeSnapshotManagementFormState.deactivateCurrentField()
            } else if volumeSnapshotManagementForm.isValid() {
                // Submit form
                await actions.executeVolumeSnapshotCreation(screen: screen)
                return
            }

        case Int32(32): // SPACE - Activate current field for editing
            if !isFieldActive {
                volumeSnapshotManagementFormState.activateCurrentField()
            } else {
                // Add space character
                volumeSnapshotManagementFormState.handleCharacterInput(" ")
            }

        case Int32(127), Int32(8): // BACKSPACE
            if isFieldActive {
                let _ = volumeSnapshotManagementFormState.handleSpecialKey(ch)
            }

        default:
            // Handle printable characters for text input
            if isFieldActive && ch >= 32 && ch <= 126, let unicodeScalar = UnicodeScalar(Int(ch)) {
                let character = Character(unicodeScalar)
                volumeSnapshotManagementFormState.handleCharacterInput(character)
            }
        }

        // Update form values from state
        volumeSnapshotManagementForm.updateFromFormState(volumeSnapshotManagementFormState)

        needsRedraw = true
    }
}
