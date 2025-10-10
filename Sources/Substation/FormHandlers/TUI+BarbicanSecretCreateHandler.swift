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

// MARK: - Barbican Secret Create Input Handler

@MainActor
extension TUI {

    var barbicanSecretCreateNavigationContext: NavigationContext {
        return .form(fieldCount: 8)
    }

    internal func handleBarbicanSecretCreateInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Handle FormSelector-based selection modes
        if barbicanSecretCreateForm.contentTypeSelectionMode {
            let contentTypes = SecretPayloadContentType.wrappedAllCases
            switch ch {
            case Int32(32): // SPACE - Toggle selection
                if barbicanSecretCreateForm.contentTypeSelectionIndex < contentTypes.count {
                    let selected = contentTypes[barbicanSecretCreateForm.contentTypeSelectionIndex]
                    barbicanSecretCreateForm.selectedContentTypeID = selected.id
                    await self.draw(screen: screen)
                }
            case Int32(10), Int32(13): // ENTER - Exit selection mode
                barbicanSecretCreateForm.exitContentTypeSelectionMode()
                await self.draw(screen: screen)
            case Int32(27): // ESC - Exit selection mode
                barbicanSecretCreateForm.contentTypeSelectionMode = false
                await self.draw(screen: screen)
            case Int32(258), Int32(259): // UP/DOWN - Navigate selection
                if ch == Int32(258) {
                    if barbicanSecretCreateForm.contentTypeSelectionIndex < contentTypes.count - 1 {
                        barbicanSecretCreateForm.contentTypeSelectionIndex += 1
                        await self.draw(screen: screen)
                    }
                } else {
                    if barbicanSecretCreateForm.contentTypeSelectionIndex > 0 {
                        barbicanSecretCreateForm.contentTypeSelectionIndex -= 1
                        await self.draw(screen: screen)
                    }
                }
            default: break
            }
            return
        }

        if barbicanSecretCreateForm.encodingSelectionMode {
            let encodings = SecretPayloadContentEncoding.wrappedAllCases
            switch ch {
            case Int32(32): if barbicanSecretCreateForm.encodingSelectionIndex < encodings.count {
                    barbicanSecretCreateForm.selectedEncodingID = encodings[barbicanSecretCreateForm.encodingSelectionIndex].id
                    await self.draw(screen: screen)
                }
            case Int32(10), Int32(13): barbicanSecretCreateForm.exitEncodingSelectionMode(); await self.draw(screen: screen)
            case Int32(27): barbicanSecretCreateForm.encodingSelectionMode = false; await self.draw(screen: screen)
            case Int32(258), Int32(259): // UP/DOWN - Navigate selection
                if ch == Int32(258) {
                    if barbicanSecretCreateForm.encodingSelectionIndex < encodings.count - 1 {
                        barbicanSecretCreateForm.encodingSelectionIndex += 1; await self.draw(screen: screen)
                    }
                } else {
                    if barbicanSecretCreateForm.encodingSelectionIndex > 0 {
                        barbicanSecretCreateForm.encodingSelectionIndex -= 1; await self.draw(screen: screen)
                    }
                }
            default: break
            }
            return
        }

        if barbicanSecretCreateForm.secretTypeSelectionMode {
            let secretTypes = SecretType.wrappedAllCases
            switch ch {
            case Int32(32): if barbicanSecretCreateForm.secretTypeSelectionIndex < secretTypes.count {
                    barbicanSecretCreateForm.selectedSecretTypeID = secretTypes[barbicanSecretCreateForm.secretTypeSelectionIndex].id
                    await self.draw(screen: screen)
                }
            case Int32(10), Int32(13): barbicanSecretCreateForm.exitSecretTypeSelectionMode(); await self.draw(screen: screen)
            case Int32(27): barbicanSecretCreateForm.secretTypeSelectionMode = false; await self.draw(screen: screen)
            case Int32(258), Int32(259): // UP/DOWN - Navigate selection
                if ch == Int32(258) {
                    if barbicanSecretCreateForm.secretTypeSelectionIndex < secretTypes.count - 1 {
                        barbicanSecretCreateForm.secretTypeSelectionIndex += 1; await self.draw(screen: screen)
                    }
                } else {
                    if barbicanSecretCreateForm.secretTypeSelectionIndex > 0 {
                        barbicanSecretCreateForm.secretTypeSelectionIndex -= 1; await self.draw(screen: screen)
                    }
                }
            default: break
            }
            return
        }

        if barbicanSecretCreateForm.algorithmSelectionMode {
            let algorithms = SecretAlgorithm.wrappedAllCases
            switch ch {
            case Int32(32): if barbicanSecretCreateForm.algorithmSelectionIndex < algorithms.count {
                    barbicanSecretCreateForm.selectedAlgorithmID = algorithms[barbicanSecretCreateForm.algorithmSelectionIndex].id
                    await self.draw(screen: screen)
                }
            case Int32(10), Int32(13): barbicanSecretCreateForm.exitAlgorithmSelectionMode(); await self.draw(screen: screen)
            case Int32(27): barbicanSecretCreateForm.algorithmSelectionMode = false; await self.draw(screen: screen)
            case Int32(258), Int32(259): // UP/DOWN - Navigate selection
                if ch == Int32(258) {
                    if barbicanSecretCreateForm.algorithmSelectionIndex < algorithms.count - 1 {
                        barbicanSecretCreateForm.algorithmSelectionIndex += 1; await self.draw(screen: screen)
                    }
                } else {
                    if barbicanSecretCreateForm.algorithmSelectionIndex > 0 {
                        barbicanSecretCreateForm.algorithmSelectionIndex -= 1; await self.draw(screen: screen)
                    }
                }
            default: break
            }
            return
        }

        if barbicanSecretCreateForm.modeSelectionMode {
            let modes = SecretMode.wrappedAllCases
            switch ch {
            case Int32(32): if barbicanSecretCreateForm.modeSelectionIndex < modes.count {
                    barbicanSecretCreateForm.selectedModeID = modes[barbicanSecretCreateForm.modeSelectionIndex].id
                    await self.draw(screen: screen)
                }
            case Int32(10), Int32(13): barbicanSecretCreateForm.exitModeSelectionMode(); await self.draw(screen: screen)
            case Int32(27): barbicanSecretCreateForm.modeSelectionMode = false; await self.draw(screen: screen)
            case Int32(258), Int32(259): // UP/DOWN - Navigate selection
                if ch == Int32(258) {
                    if barbicanSecretCreateForm.modeSelectionIndex < modes.count - 1 {
                        barbicanSecretCreateForm.modeSelectionIndex += 1; await self.draw(screen: screen)
                    }
                } else {
                    if barbicanSecretCreateForm.modeSelectionIndex > 0 {
                        barbicanSecretCreateForm.modeSelectionIndex -= 1; await self.draw(screen: screen)
                    }
                }
            default: break
            }
            return
        }

        if barbicanSecretCreateForm.bitLengthSelectionMode {
            let bitLengths = BitLengthOption.commonBitLengths
            switch ch {
            case Int32(32): if barbicanSecretCreateForm.bitLengthSelectionIndex < bitLengths.count {
                    barbicanSecretCreateForm.selectedBitLengthID = bitLengths[barbicanSecretCreateForm.bitLengthSelectionIndex].id
                    await self.draw(screen: screen)
                }
            case Int32(10), Int32(13): barbicanSecretCreateForm.exitBitLengthSelectionMode(); await self.draw(screen: screen)
            case Int32(27): barbicanSecretCreateForm.bitLengthSelectionMode = false; await self.draw(screen: screen)
            case Int32(258), Int32(259): // UP/DOWN - Navigate selection
                if ch == Int32(258) {
                    if barbicanSecretCreateForm.bitLengthSelectionIndex < bitLengths.count - 1 {
                        barbicanSecretCreateForm.bitLengthSelectionIndex += 1; await self.draw(screen: screen)
                    }
                } else {
                    if barbicanSecretCreateForm.bitLengthSelectionIndex > 0 {
                        barbicanSecretCreateForm.bitLengthSelectionIndex -= 1; await self.draw(screen: screen)
                    }
                }
            default: break
            }
            return
        }

        // Check if we're in field edit mode
        let isFieldActive = barbicanSecretCreateForm.fieldEditMode || barbicanSecretCreateForm.payloadEditMode

        // Try common navigation when NOT in field edit mode
        if !isFieldActive {
            if await handleCommonNavigation(ch, screen: screen, context: barbicanSecretCreateNavigationContext) {
                return
            }
        }

        // Handle view-specific input
        await handleBarbicanSecretCreateSpecificInput(ch, screen: screen)
    }

    private func handleBarbicanSecretCreateSpecificInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(9): // TAB - Next field
            if !barbicanSecretCreateForm.fieldEditMode && !barbicanSecretCreateForm.payloadEditMode {
                barbicanSecretCreateForm.nextField()
                await self.draw(screen: screen)
            }
        case 353: // SHIFT+TAB - Previous field
            if !barbicanSecretCreateForm.fieldEditMode && !barbicanSecretCreateForm.payloadEditMode {
                barbicanSecretCreateForm.previousField()
                await self.draw(screen: screen)
            }
        case Int32(10), Int32(13): // ENTER - Edit field, confirm selection, or handle current field
            needsRedraw = true
            if barbicanSecretCreateForm.selectionMode {
                // Confirm selection and exit selection mode
                barbicanSecretCreateForm.confirmSelection()
                await self.draw(screen: screen)
            } else if barbicanSecretCreateForm.fieldEditMode || barbicanSecretCreateForm.payloadEditMode {
                // Exit edit mode
                barbicanSecretCreateForm.exitEditMode()
                await self.draw(screen: screen)
            } else {
                // Handle based on current field
                switch barbicanSecretCreateForm.currentField {
                case .name:
                    barbicanSecretCreateForm.fieldEditMode = true
                case .payload:
                    barbicanSecretCreateForm.payloadEditMode = true
                case .payloadContentType, .payloadContentEncoding, .secretType, .algorithm, .mode, .bitLength:
                    barbicanSecretCreateForm.enterSelectionMode()
                case .expirationDate:
                    barbicanSecretCreateForm.enterSelectionMode()
                }
                await self.draw(screen: screen)
            }
        case Int32(32): // SPACEBAR - Enter selection mode or edit field
            if !barbicanSecretCreateForm.fieldEditMode && !barbicanSecretCreateForm.payloadEditMode {
                switch barbicanSecretCreateForm.currentField {
                case .name:
                    barbicanSecretCreateForm.fieldEditMode = true
                case .payload:
                    barbicanSecretCreateForm.payloadEditMode = true
                case .payloadContentType:
                    barbicanSecretCreateForm.enterContentTypeSelectionMode()
                case .payloadContentEncoding:
                    barbicanSecretCreateForm.enterEncodingSelectionMode()
                case .secretType:
                    barbicanSecretCreateForm.enterSecretTypeSelectionMode()
                case .algorithm:
                    barbicanSecretCreateForm.enterAlgorithmSelectionMode()
                case .mode:
                    barbicanSecretCreateForm.enterModeSelectionMode()
                case .bitLength:
                    barbicanSecretCreateForm.enterBitLengthSelectionMode()
                case .expirationDate:
                    barbicanSecretCreateForm.enterSelectionMode()
                }
                await self.draw(screen: screen)
            }
        case Int32(27): // ESC - Exit selection mode, edit mode, or cancel creation
            if barbicanSecretCreateForm.selectionMode {
                barbicanSecretCreateForm.exitSelectionMode()
                await self.draw(screen: screen)
            } else if barbicanSecretCreateForm.fieldEditMode || barbicanSecretCreateForm.payloadEditMode {
                barbicanSecretCreateForm.exitEditMode()
                await self.draw(screen: screen)
            } else {
                self.changeView(to: .barbicanSecrets, resetSelection: false)
            }
        case Int32(127), Int32(330): // DELETE - Handle text deletion
            if barbicanSecretCreateForm.fieldEditMode {
                if !barbicanSecretCreateForm.secretName.isEmpty {
                    barbicanSecretCreateForm.secretName.removeLast()
                }
                await self.draw(screen: screen)
            } else if barbicanSecretCreateForm.payloadEditMode {
                barbicanSecretCreateForm.removeFromPayloadBuffer()
                await self.draw(screen: screen)
            }
        default:
            if barbicanSecretCreateForm.fieldEditMode {
                if let character = UnicodeScalar(UInt32(ch))?.description.first {
                    barbicanSecretCreateForm.secretName.append(character)
                    await self.draw(screen: screen)
                }
            } else if barbicanSecretCreateForm.payloadEditMode {
                if let character = UnicodeScalar(UInt32(ch))?.description.first {
                    barbicanSecretCreateForm.addToPayloadBuffer(character)
                    // Only redraw if not in paste mode to prevent character-by-character slowdown
                    if !barbicanSecretCreateForm.isPasteMode {
                        await self.draw(screen: screen)
                    }
                }
            }
        }
    }
}
