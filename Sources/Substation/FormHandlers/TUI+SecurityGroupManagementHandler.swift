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

// MARK: - Security Group Management Input Handler

@MainActor
extension TUI {

    internal func handleSecurityGroupInput(_ ch: Int32, screen: OpaquePointer?) async {
        switch ch {
        case Int32(259): // UP
            let managementGroups = securityGroupForm.getManagementGroups()
            if !managementGroups.isEmpty {
                securityGroupForm.selectedSecurityGroupIndex = max(0, securityGroupForm.selectedSecurityGroupIndex - 1)
            }
        case Int32(258): // DOWN
            let managementGroups = securityGroupForm.getManagementGroups()
            if !managementGroups.isEmpty {
                securityGroupForm.selectedSecurityGroupIndex = min(managementGroups.count - 1, securityGroupForm.selectedSecurityGroupIndex + 1)
            }
        case Int32(32): // SPACE - Toggle security group selection with intelligent assign/remove
            let managementGroups = securityGroupForm.getManagementGroups()
            if securityGroupForm.selectedSecurityGroupIndex < managementGroups.count {
                let selectedGroup = managementGroups[securityGroupForm.selectedSecurityGroupIndex]
                securityGroupForm.toggleSecurityGroupManagement(selectedGroup.id)
            }
        case Int32(10), Int32(13): // ENTER - Apply changes
            needsRedraw = true
            if securityGroupForm.hasPendingChanges() {
                await actions.applySecurityGroupChanges(screen: screen)
            }
        default:
            break
        }
    }
}
