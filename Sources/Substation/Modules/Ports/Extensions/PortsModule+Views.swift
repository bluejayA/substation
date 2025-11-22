// Sources/Substation/Modules/Ports/Extensions/PortsModule+Views.swift
import Foundation
import OSClient
import struct OSClient.Port
import SwiftNCurses

/// View definitions for the Ports module
extension PortsModule {
    // MARK: - View Identifiers

    enum Views {
        static let list = DynamicViewIdentifier(id: "ports.list", moduleId: "ports", viewType: .list)
        static let detail = DynamicViewIdentifier(id: "ports.detail", moduleId: "ports", viewType: .detail)
        static let create = DynamicViewIdentifier(id: "ports.create", moduleId: "ports", viewType: .create)
        static let serverManagement = DynamicViewIdentifier(id: "ports.serverManagement", moduleId: "ports", viewType: .management)
        static let allowedAddressPairs = DynamicViewIdentifier(id: "ports.allowedAddressPairs", moduleId: "ports", viewType: .management)

        static var all: [DynamicViewIdentifier] { [list, detail, create, serverManagement, allowedAddressPairs] }
    }

    // MARK: - Enhanced View Registration

    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            ViewMetadata(
                identifier: Views.list,
                title: "Ports",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await PortViews.drawDetailedPortList(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        cachedPorts: tui.cacheManager.cachedPorts,
                        cachedNetworks: tui.cacheManager.cachedNetworks,
                        cachedServers: tui.cacheManager.cachedServers,
                        searchQuery: tui.searchQuery,
                        scrollOffset: tui.viewCoordinator.scrollOffset,
                        selectedIndex: tui.viewCoordinator.selectedIndex,
                        multiSelectMode: tui.selectionManager.multiSelectMode,
                        selectedItems: tui.selectionManager.multiSelectedResourceIDs
                    )
                },
                inputHandler: { [weak self, weak tui] ch, screen in
                    guard let self = self, let tui = tui else { return false }

                    switch ch {
                    case Int32(77):  // M - Manage server assignment
                        Logger.shared.logUserAction("manage_port_server_assignment", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.managePortServerAssignment(screen: screen)
                        return true

                    case Int32(69):  // E - Manage allowed address pairs
                        Logger.shared.logUserAction("manage_port_allowed_address_pairs", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.managePortAllowedAddressPairs(screen: screen)
                        return true

                    default:
                        return false
                    }
                }
            ),
            ViewMetadata(
                identifier: Views.detail,
                title: "Port Details",
                parentViewId: Views.list.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    guard let port = tui.viewCoordinator.selectedResource as? Port else { return }
                    await PortViews.drawPortDetail(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        port: port,
                        cachedNetworks: tui.cacheManager.cachedNetworks,
                        cachedSubnets: tui.cacheManager.cachedSubnets,
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // Port Create Form View
            ViewMetadata(
                identifier: Views.create,
                title: "Create Port",
                parentViewId: Views.list.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await PortViews.drawPortCreateForm(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        portCreateForm: tui.portCreateForm,
                        portCreateFormState: tui.portCreateFormState,
                        cachedNetworks: tui.cacheManager.cachedNetworks,
                        cachedSecurityGroups: tui.cacheManager.cachedSecurityGroups,
                        cachedQoSPolicies: tui.cacheManager.cachedQoSPolicies
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handlePortCreateInput(ch, screen: screen)
                    return true
                }
            ),

            // Port Server Management View
            ViewMetadata(
                identifier: Views.serverManagement,
                title: "Server Management",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let port = tui.viewCoordinator.selectedResource as? Port {
                        await PortServerManagementView.draw(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            port: port,
                            servers: tui.cacheManager.cachedServers,
                            attachedServerId: tui.selectionManager.attachedServerId,
                            selectedServerId: tui.selectionManager.selectedServerId,
                            searchQuery: tui.searchQuery,
                            scrollOffset: tui.viewCoordinator.scrollOffset,
                            selectedIndex: tui.viewCoordinator.selectedIndex,
                            mode: tui.selectionManager.attachmentMode,
                            resourceResolver: tui.resourceResolver
                        )
                    }
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    return await tui.handlePortServerManagementInput(ch, screen: screen)
                }
            ),

            // Port Allowed Address Pair Management View
            ViewMetadata(
                identifier: Views.allowedAddressPairs,
                title: "Allowed Address Pairs",
                parentViewId: Views.detail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .network,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let form = tui.allowedAddressPairForm {
                        await AllowedAddressPairManagementView.drawAllowedAddressPairManagement(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            form: form,
                            resourceNameCache: tui.resourceNameCache
                        )
                    }
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    return await tui.handleAllowedAddressPairManagementInput(ch, screen: screen)
                }
            )
        ]
    }
}
