import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Security Group Management Input Handler

@MainActor
extension TUI {

    internal func handleSecurityGroupInput(_ ch: Int32, screen: OpaquePointer?) async {
        let managementGroups = securityGroupForm.getManagementGroups()

        let _ = await formInputHandler.handleManagementInput(
            ch,
            screen: screen,
            itemCount: managementGroups.count,
            onToggle: {
                if self.securityGroupForm.selectedSecurityGroupIndex < managementGroups.count {
                    let selectedGroup = managementGroups[self.securityGroupForm.selectedSecurityGroupIndex]
                    self.securityGroupForm.toggleSecurityGroupManagement(selectedGroup.id)
                }
            },
            onEnter: {
                self.renderCoordinator.needsRedraw = true
                if self.securityGroupForm.hasPendingChanges() {
                    if let module = ModuleRegistry.shared.module(for: "securitygroups") as? SecurityGroupsModule {
                        await module.applySecurityGroupChanges(screen: screen)
                    }
                }
            }
        )
    }
}
