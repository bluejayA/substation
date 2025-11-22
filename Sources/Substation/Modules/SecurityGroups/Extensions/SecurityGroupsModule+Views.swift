// Sources/Substation/Modules/SecurityGroups/Extensions/SecurityGroupsModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the SecurityGroups module
///
/// This extension defines all view identifiers and metadata registration
/// for the SecurityGroups module using the new ViewIdentifier system.
extension SecurityGroupsModule {
    // MARK: - View Identifiers

    /// View identifiers for the SecurityGroups module
    enum Views {
        /// Security group list view
        static let list = DynamicViewIdentifier(
            id: "securitygroups.list",
            moduleId: "securitygroups",
            viewType: .list
        )

        /// Security group detail view
        static let detail = DynamicViewIdentifier(
            id: "securitygroups.detail",
            moduleId: "securitygroups",
            viewType: .detail
        )

        /// Security group create view
        static let create = DynamicViewIdentifier(
            id: "securitygroups.create",
            moduleId: "securitygroups",
            viewType: .create
        )

        /// Security group rule management view
        static let ruleManagement = DynamicViewIdentifier(
            id: "securitygroups.ruleManagement",
            moduleId: "securitygroups",
            viewType: .management
        )

        /// Security group server attachment view
        static let serverAttachment = DynamicViewIdentifier(
            id: "securitygroups.serverAttachment",
            moduleId: "securitygroups",
            viewType: .management
        )

        /// Security group server management view
        static let serverManagement = DynamicViewIdentifier(
            id: "securitygroups.serverManagement",
            moduleId: "securitygroups",
            viewType: .management
        )

        /// All view identifiers
        static var all: [DynamicViewIdentifier] {
            return [list, detail, create, ruleManagement, serverAttachment, serverManagement]
        }
    }

    // MARK: - Enhanced View Registration

    /// Register all security group views with metadata
    ///
    /// This method returns ViewMetadata for registration with the enhanced
    /// ViewRegistry system. It provides complete view information including
    /// parent views for navigation and multi-select support flags.
    ///
    /// - Returns: Array of ViewMetadata for all module views
    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            // Security Groups List View
            ViewMetadata(
                identifier: Views.list,
                title: "Security Groups",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await SecurityGroupViews.drawDetailedSecurityGroupList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedSecurityGroups: tui.cacheManager.cachedSecurityGroups,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: { [weak self, weak tui] ch, _ in
                    guard let self = self, let tui = tui else { return false }

                    switch ch {
                    case Int32(77):  // M - Manage security group rules
                        Logger.shared.logUserAction("manage_security_group_rules", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.manageSecurityGroupRules(screen: nil)
                        return true

                    default:
                        return false
                    }
                }
            ),

            // Security Group Detail View
            ViewMetadata(
                identifier: Views.detail,
                title: "Security Group Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let securityGroup = tui.viewCoordinator.selectedResource as? SecurityGroup else {
                        let surface = SwiftNCurses.surface(from: screen)
                        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
                        await SwiftNCurses.render(Text("No security group selected").error(), on: surface, in: bounds)
                        return
                    }
                    await SecurityGroupViews.drawSecurityGroupDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        securityGroup: securityGroup,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // Security Group Create View
            ViewMetadata(
                identifier: Views.create,
                title: "Create Security Group",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await SecurityGroupViews.drawSecurityGroupCreateForm(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.securityGroupCreateForm,
                        formState: tui.securityGroupCreateFormState
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSecurityGroupCreateInput(ch, screen: screen)
                    return true
                }
            ),

            // Security Group Server Attachment View
            ViewMetadata(
                identifier: Views.serverAttachment,
                title: "Attach Servers",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await SecurityGroupServerAttachmentView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        servers: tui.cacheManager.cachedServers,
                        selectedServers: tui.selectionManager.selectedServers,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex
                    )
                },
                inputHandler: nil
            ),

            // Security Group Server Management View
            ViewMetadata(
                identifier: Views.serverManagement,
                title: "Server Management",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let securityGroup = tui.viewCoordinator.selectedResource as? SecurityGroup {
                        await SecurityGroupServerManagementView.draw(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            securityGroup: securityGroup,
                            servers: tui.cacheManager.cachedServers,
                            attachedServerIds: tui.selectionManager.attachedServerIds,
                            selectedServers: tui.selectionManager.selectedServers,
                            searchQuery: tui.searchQuery,
                            scrollOffset: tui.viewCoordinator.scrollOffset,
                            selectedIndex: tui.viewCoordinator.selectedIndex,
                            mode: tui.selectionManager.attachmentMode,
                            resourceResolver: tui.resourceResolver
                        )
                    }
                },
                inputHandler: nil
            ),

            // Security Group Rule Management View
            ViewMetadata(
                identifier: Views.ruleManagement,
                title: "Manage Security Group Rules",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await SecurityGroupViews.drawSecurityGroupRuleManagement(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: tui.securityGroupRuleManagementForm!,
                        cachedSecurityGroups: tui.cacheManager.cachedSecurityGroups
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    return await tui.handleSecurityGroupRuleManagementInput(ch, screen: screen)
                }
            )
        ]
    }
}
