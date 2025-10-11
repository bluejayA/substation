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

// MARK: - Volume Backup Management Input Handler

@MainActor
extension TUI {

    var volumeBackupManagementNavigationContext: NavigationContext {
        let fieldCount = volumeBackupManagementFormState.fields.count
        return .form(fieldCount: fieldCount)
    }

    internal func handleVolumeBackupManagementInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Check if a field is currently active
        let isFieldActive = volumeBackupManagementFormState.isCurrentFieldActive()

        // Rebuild form state with current form values
        volumeBackupManagementFormState = FormBuilderState(fields: volumeBackupManagementForm.buildFields(
            selectedFieldId: volumeBackupManagementFormState.getCurrentFieldId(),
            activeFieldId: volumeBackupManagementFormState.getActiveFieldId(),
            formState: volumeBackupManagementFormState
        ), preservingStateFrom: volumeBackupManagementFormState)

        // Try common navigation when NOT in field edit mode
        if !isFieldActive {
            if await handleCommonNavigation(ch, screen: screen, context: volumeBackupManagementNavigationContext) {
                return
            }
        }

        // Handle view-specific input
        await handleVolumeBackupManagementSpecificInput(ch, screen: screen, isFieldActive: isFieldActive)
    }

    private func handleVolumeBackupManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?, isFieldActive: Bool) async {
        switch ch {
        case Int32(9): // TAB - Navigate to next field
            if !isFieldActive {
                volumeBackupManagementFormState.nextField()
            }

        case Int32(10), Int32(13): // ENTER
            if isFieldActive {
                // Deactivate field
                volumeBackupManagementFormState.deactivateCurrentField()
            } else if volumeBackupManagementForm.isValid() {
                // Submit form
                await actions.executeVolumeBackupCreation(screen: screen)
                return
            }

        case Int32(32): // SPACE - Activate field or toggle checkbox
            if !isFieldActive {
                // Check if current field is a checkbox
                let currentFieldId = volumeBackupManagementFormState.getCurrentFieldId()
                if currentFieldId == VolumeBackupFieldId.incremental.rawValue {
                    // Only toggle if checkbox is not disabled (i.e., full backup exists)
                    if volumeBackupManagementForm.canCreateIncrementalBackup() {
                        volumeBackupManagementFormState.toggleCurrentCheckbox()
                    }
                } else {
                    // Activate text field for editing
                    volumeBackupManagementFormState.activateCurrentField()
                }
            } else {
                // Add space character when in text editing mode
                volumeBackupManagementFormState.handleCharacterInput(" ")
            }

        case Int32(127), Int32(8): // BACKSPACE
            if isFieldActive {
                let _ = volumeBackupManagementFormState.handleSpecialKey(ch)
            }

        default:
            // Handle printable characters for text input
            if isFieldActive && ch >= 32 && ch <= 126, let unicodeScalar = UnicodeScalar(Int(ch)) {
                let character = Character(unicodeScalar)
                volumeBackupManagementFormState.handleCharacterInput(character)
            }
        }

        // Update form values from state
        volumeBackupManagementForm.updateFromFormState(volumeBackupManagementFormState)

        needsRedraw = true
    }
}
