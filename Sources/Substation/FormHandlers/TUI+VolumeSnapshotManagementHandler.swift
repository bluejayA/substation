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

        // Step 1: Try common navigation (only when field is NOT active)
        if !isFieldActive {
            if await handleVolumeSnapshotManagementCommonNavigation(ch) {
                volumeSnapshotManagementForm.updateFromFormState(volumeSnapshotManagementFormState)
                needsRedraw = true
                return
            }
        }

        // Step 2: Handle view-specific keys (form input and text editing)
        await handleVolumeSnapshotManagementSpecificInput(ch, screen: screen, isFieldActive: isFieldActive)

        // Update form values from state
        volumeSnapshotManagementForm.updateFromFormState(volumeSnapshotManagementFormState)
        needsRedraw = true
    }

    // MARK: - Common Navigation

    private func handleVolumeSnapshotManagementCommonNavigation(_ ch: Int32) async -> Bool {
        // Handle UP/DOWN navigation between form fields when no field is active
        // Note: ESC handling is done in the specific input handler for form-based views
        switch ch {
        case Int32(259): // KEY_UP
            volumeSnapshotManagementFormState.previousField()
            return true

        case Int32(258): // KEY_DOWN
            volumeSnapshotManagementFormState.nextField()
            return true

        case Int32(27): // ESC
            return await handleVolumeSnapshotManagementEscape()

        default:
            return false
        }
    }

    // MARK: - View-Specific Input

    private func handleVolumeSnapshotManagementSpecificInput(_ ch: Int32, screen: OpaquePointer?, isFieldActive: Bool) async {
        switch ch {
        case Int32(9): // TAB - Navigate to next field
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

        case Int32(32): // SPACE - Activate current field for editing or add space character
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
    }

    // MARK: - ESC Handling

    private func handleVolumeSnapshotManagementEscape() async -> Bool {
        // Use centralized ESC handling
        return await NavigationInputHandler.handleEscapeKey(tui: self)
    }
}
