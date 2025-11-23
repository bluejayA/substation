// Sources/Substation/Modules/Swift/Extensions/SwiftModule+Views.swift
import Foundation
import OSClient
import SwiftNCurses

/// View definitions for the Swift module
extension SwiftModule {
    // MARK: - View Identifiers

    /// View identifiers for the Swift module
    enum Views {
        static let containers = DynamicViewIdentifier(id: "swift.containers", moduleId: "swift", viewType: .list)
        static let containerDetail = DynamicViewIdentifier(id: "swift.containerDetail", moduleId: "swift", viewType: .detail)
        static let objectDetail = DynamicViewIdentifier(id: "swift.objectDetail", moduleId: "swift", viewType: .detail)
        static let containerCreate = DynamicViewIdentifier(id: "swift.containerCreate", moduleId: "swift", viewType: .create)
        static let objectUpload = DynamicViewIdentifier(id: "swift.objectUpload", moduleId: "swift", viewType: .create)
        static let containerDownload = DynamicViewIdentifier(id: "swift.containerDownload", moduleId: "swift", viewType: .create)
        static let objectDownload = DynamicViewIdentifier(id: "swift.objectDownload", moduleId: "swift", viewType: .create)
        static let directoryDownload = DynamicViewIdentifier(id: "swift.directoryDownload", moduleId: "swift", viewType: .create)
        static let containerMetadata = DynamicViewIdentifier(id: "swift.containerMetadata", moduleId: "swift", viewType: .create)
        static let objectMetadata = DynamicViewIdentifier(id: "swift.objectMetadata", moduleId: "swift", viewType: .create)
        static let directoryMetadata = DynamicViewIdentifier(id: "swift.directoryMetadata", moduleId: "swift", viewType: .create)
        static let containerWebAccess = DynamicViewIdentifier(id: "swift.webAccess", moduleId: "swift", viewType: .create)
        static let backgroundOperations = DynamicViewIdentifier(id: "swift.backgroundOperations", moduleId: "swift", viewType: .list)
        static let backgroundOperationDetail = DynamicViewIdentifier(id: "swift.backgroundOperationDetail", moduleId: "swift", viewType: .detail)

        static var all: [DynamicViewIdentifier] {
            [containers, containerDetail, objectDetail, containerCreate, objectUpload, containerDownload,
             objectDownload, directoryDownload, containerMetadata, objectMetadata, directoryMetadata,
             containerWebAccess, backgroundOperations, backgroundOperationDetail]
        }
    }

    // MARK: - Enhanced View Registration

    func registerViewsEnhanced() -> [ViewMetadata] {
        guard let tui = tui else { return [] }

        return [
            ViewMetadata(
                identifier: Views.containers,
                title: "Swift Containers",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: true,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerListView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak self, weak tui] ch, screen in
                    guard let self = self, let tui = tui else { return false }

                    // Filter containers based on search query to match displayed list
                    let filteredContainers: [SwiftContainer]
                    if let query = tui.searchQuery, !query.isEmpty {
                        filteredContainers = tui.cacheManager.cachedSwiftContainers.filter {
                            $0.name?.localizedCaseInsensitiveContains(query) ?? false
                        }
                    } else {
                        filteredContainers = tui.cacheManager.cachedSwiftContainers
                    }

                    switch ch {
                    case Int32(32):  // SPACEBAR - Navigate into container
                        Logger.shared.logUserAction("swift_navigate_into_container", details: [
                            "selectedIndex": tui.viewCoordinator.selectedIndex,
                            "containerCount": filteredContainers.count,
                            "cacheCount": tui.cacheManager.cachedSwiftContainers.count,
                            "searchQuery": tui.searchQuery ?? "nil"
                        ])
                        guard tui.viewCoordinator.selectedIndex < filteredContainers.count else {
                            tui.statusMessage = "No container selected (index: \(tui.viewCoordinator.selectedIndex), count: \(filteredContainers.count))"
                            return true
                        }
                        let container = filteredContainers[tui.viewCoordinator.selectedIndex]
                        guard let containerName = container.name else {
                            tui.statusMessage = "Invalid container"
                            return true
                        }

                        // Set loading state before fetching (only if cache is not fresh)
                        let cacheFresh = tui.cacheManager.isSwiftObjectsCacheFresh(forContainer: containerName)
                        if !cacheFresh {
                            tui.viewCoordinator.isLoadingSwiftObjects = true
                        }

                        // Clear VirtualScrollManager before navigating to new container
                        tui.viewCoordinator.swiftNavState.clearVirtualScrollManager()

                        tui.viewCoordinator.swiftNavState.navigateIntoContainer(containerName)
                        tui.changeView(to: .swiftContainerDetail, resetSelection: true)
                        // Set selectedResource AFTER changeView because resetSelection clears it
                        tui.viewCoordinator.selectedResource = container

                        // Clear screen and force redraw to prevent artifacts
                        SwiftNCurses.clear(WindowHandle(screen))
                        tui.renderCoordinator.renderOptimizer.markFullScreenDirty()
                        await tui.draw(screen: screen)

                        // Fetch will use cache if fresh, otherwise fetch from server
                        await self.fetchSwiftObjectsPaginated(containerName: containerName, marker: nil, limit: 100, priority: "interactive", forceRefresh: false)
                        return true

                    case Int32(10):  // ENTER - Show container metadata/details
                        Logger.shared.logUserAction("show_container_metadata", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        guard tui.viewCoordinator.selectedIndex < filteredContainers.count else {
                            tui.statusMessage = "No container selected"
                            return true
                        }
                        let container = filteredContainers[tui.viewCoordinator.selectedIndex]
                        await self.showContainerMetadata(container: container, screen: screen)
                        return true

                    case Int32(87):  // W - Manage web access
                        Logger.shared.logUserAction("manage_container_web_access", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleManageContainerWebAccess(screen: screen)
                        return true

                    case Int32(77):  // M - Manage container metadata
                        Logger.shared.logUserAction("manage_container_metadata", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleManageContainerMetadata(screen: screen)
                        return true

                    case Int32(85):  // U - Upload object to container
                        Logger.shared.logUserAction("upload_object_to_container", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleUploadObjectToContainer(screen: screen)
                        return true

                    case Int32(68):  // D - Download container
                        Logger.shared.logUserAction("download_container", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleDownloadContainer(screen: screen)
                        return true

                    default:
                        return false
                    }
                }
            ),
            ViewMetadata(
                identifier: Views.containerDetail,
                title: "Container Details",
                parentViewId: Views.containers.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerDetailView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak self, weak tui] ch, screen in
                    guard let self = self, let tui = tui else { return false }

                    switch ch {
                    case Int32(32):  // SPACEBAR - Navigate into directory or open object detail
                        Logger.shared.logUserAction("swift_navigate_into_item", details: [
                            "selectedIndex": tui.viewCoordinator.selectedIndex,
                            "currentPath": tui.viewCoordinator.swiftNavState.currentPathString
                        ])
                        guard let allObjects = tui.cacheManager.cachedSwiftObjects else {
                            tui.statusMessage = "No objects loaded"
                            return true
                        }
                        let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
                        let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)
                        guard tui.viewCoordinator.selectedIndex < treeItems.count else {
                            tui.statusMessage = "No item selected"
                            return true
                        }
                        let selectedItem = treeItems[tui.viewCoordinator.selectedIndex]
                        switch selectedItem {
                        case .object(let object):
                            tui.viewCoordinator.selectedResource = object
                            tui.changeView(to: .swiftObjectDetail, resetSelection: false)
                        case .directory(let name, _, _):
                            // Navigate into subdirectory - no loading state needed since all objects are cached
                            tui.viewCoordinator.swiftNavState.navigateIntoDirectory(name)
                            tui.viewCoordinator.selectedIndex = 0
                            tui.viewCoordinator.scrollOffset = 0

                            // Clear screen and redraw with new directory contents
                            SwiftNCurses.clear(WindowHandle(screen))
                            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()
                            tui.markNeedsRedraw()
                        }
                        return true

                    case Int32(77):  // M - Manage tree item metadata
                        Logger.shared.logUserAction("manage_tree_item_metadata", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleSwiftTreeItemMetadata(screen: screen)
                        return true

                    case Int32(85):  // U - Upload object
                        Logger.shared.logUserAction("upload_object_to_container_from_detail", details: ["container": tui.viewCoordinator.swiftNavState.currentContainer ?? "unknown"])
                        await self.handleUploadObjectToContainer(screen: screen)
                        return true

                    case Int32(68):  // D - Download object
                        Logger.shared.logUserAction("download_object", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        await self.handleDownloadObject(screen: screen)
                        return true

                    case Int32(27):  // ESC - Navigate up in hierarchy or back to container list
                        // Check if we can navigate up within the hierarchy
                        if tui.viewCoordinator.swiftNavState.canNavigateUp() && !tui.viewCoordinator.swiftNavState.isAtContainerRoot {
                            // Navigate up one directory level
                            Logger.shared.logUserAction("swift_navigate_up", details: [
                                "fromPath": tui.viewCoordinator.swiftNavState.currentPathString,
                                "depth": tui.viewCoordinator.swiftNavState.depth
                            ])

                            tui.viewCoordinator.swiftNavState.navigateUp()

                            // Reset selection to top
                            tui.viewCoordinator.selectedIndex = 0
                            tui.viewCoordinator.scrollOffset = 0

                            // Clear screen and redraw to prevent artifacts
                            SwiftNCurses.clear(WindowHandle(screen))
                            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()
                            tui.markNeedsRedraw()

                            Logger.shared.logInfo("Navigated up to path: \(tui.viewCoordinator.swiftNavState.currentPathString)")
                            return true
                        } else {
                            // Navigate back to container list
                            Logger.shared.logNavigation("swiftContainerDetail", to: "swift", details: [
                                "action": "escape_container",
                                "containerName": tui.viewCoordinator.swiftNavState.currentContainer ?? "unknown"
                            ])

                            // Restore selection to the container that was opened
                            if let containerName = tui.viewCoordinator.swiftNavState.currentContainer,
                               let index = tui.cacheManager.cachedSwiftContainers.firstIndex(where: { $0.name == containerName }) {
                                tui.viewCoordinator.selectedIndex = index
                                // Ensure the selected item is visible in the viewport
                                let visibleItems = Int(tui.screenRows) - 10
                                if index < tui.viewCoordinator.scrollOffset {
                                    tui.viewCoordinator.scrollOffset = index
                                } else if index >= tui.viewCoordinator.scrollOffset + visibleItems {
                                    tui.viewCoordinator.scrollOffset = max(0, index - visibleItems + 1)
                                }
                            }

                            // Reset navigation state
                            tui.viewCoordinator.swiftNavState.reset()

                            // Clear screen to prevent artifacts
                            SwiftNCurses.clear(WindowHandle(screen))
                            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()

                            // Return to container list view
                            tui.changeView(to: .swift, resetSelection: false)
                            tui.viewCoordinator.selectedResource = nil
                            return true
                        }

                    default:
                        return false
                    }
                }
            ),
            ViewMetadata(
                identifier: Views.objectDetail,
                title: "Object Details",
                parentViewId: Views.containerDetail.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectDetailView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }

                    switch ch {
                    case Int32(27):  // ESC - Return to container detail with selection restored
                        Logger.shared.logNavigation("swiftObjectDetail", to: "swiftContainerDetail", details: ["action": "escape_detail"])

                        // Restore selection to the object that was opened
                        if let object = tui.viewCoordinator.selectedResource as? SwiftObject,
                           let objectName = object.name,
                           let objects = tui.cacheManager.cachedSwiftObjects,
                           let index = objects.firstIndex(where: { $0.name == objectName }) {
                            tui.viewCoordinator.selectedIndex = index
                            // Ensure the selected item is visible in the viewport
                            let visibleItems = Int(tui.screenRows) - 10
                            if index < tui.viewCoordinator.scrollOffset {
                                tui.viewCoordinator.scrollOffset = index
                            } else if index >= tui.viewCoordinator.scrollOffset + visibleItems {
                                tui.viewCoordinator.scrollOffset = max(0, index - visibleItems + 1)
                            }
                        }

                        // Clear screen to prevent artifacts
                        SwiftNCurses.clear(WindowHandle(screen))
                        tui.renderCoordinator.renderOptimizer.markFullScreenDirty()

                        tui.changeView(to: .swiftContainerDetail, resetSelection: false)
                        tui.viewCoordinator.selectedResource = nil
                        return true

                    default:
                        return false
                    }
                }
            ),
            ViewMetadata(
                identifier: Views.containerCreate,
                title: "Create Container",
                parentViewId: Views.containers.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerCreateView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftContainerCreateInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.objectUpload,
                title: "Upload Object",
                parentViewId: Views.containers.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectUploadView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftObjectUploadInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.containerDownload,
                title: "Download Container",
                parentViewId: Views.containers.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerDownloadView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftContainerDownloadInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.objectDownload,
                title: "Download Object",
                parentViewId: Views.containerDetail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectDownloadView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftObjectDownloadInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.directoryDownload,
                title: "Download Directory",
                parentViewId: Views.containerDetail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftDirectoryDownloadView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftDirectoryDownloadInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.containerMetadata,
                title: "Set Container Metadata",
                parentViewId: Views.containers.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerMetadataView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftContainerMetadataInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.objectMetadata,
                title: "Set Object Metadata",
                parentViewId: Views.containerDetail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftObjectMetadataView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftObjectMetadataInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.directoryMetadata,
                title: "Set Directory Metadata",
                parentViewId: Views.containerDetail.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftDirectoryMetadataView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftDirectoryMetadataInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.containerWebAccess,
                title: "Manage Web Access",
                parentViewId: Views.containers.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftContainerWebAccessView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }
                    await tui.handleSwiftContainerWebAccessInput(ch, screen: screen)
                    return true
                }
            ),
            ViewMetadata(
                identifier: Views.backgroundOperations,
                title: "Background Operations",
                parentViewId: Views.containers.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftBackgroundOperationsView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }

                    switch ch {
                    case Int32(32):  // SPACEBAR - Open operation detail
                        let operations = tui.swiftBackgroundOps.getAllOperations()
                        guard tui.viewCoordinator.selectedIndex < operations.count else {
                            tui.statusMessage = "No operation selected"
                            return true
                        }

                        let operation = operations[tui.viewCoordinator.selectedIndex]
                        tui.viewCoordinator.selectedResource = operation
                        tui.changeView(to: .swiftBackgroundOperationDetail, resetSelection: false)
                        tui.viewCoordinator.detailScrollOffset = 0
                        return true

                    case Int32(77):  // M - Show performance metrics
                        Logger.shared.logUserAction("show_performance_metrics", details: ["view": "swiftBackgroundOperations"])
                        Logger.shared.logNavigation("swiftBackgroundOperations", to: "performanceMetrics")
                        tui.viewCoordinator.scrollOffset = 0
                        tui.changeView(to: .performanceMetrics, resetSelection: false)
                        return true

                    case Int32(127), Int32(330):  // DELETE/BACKSPACE - Cancel or remove operation
                        let operations = tui.swiftBackgroundOps.getAllOperations()
                        guard tui.viewCoordinator.selectedIndex < operations.count else {
                            tui.statusMessage = "No operation selected"
                            await tui.draw(screen: screen)
                            return true
                        }

                        let operation = operations[tui.viewCoordinator.selectedIndex]

                        // Context-aware behavior based on operation status
                        if operation.status.isActive {
                            // Active operation: Cancel it
                            let operationDesc = operation.displayName
                            let confirmed = await ViewUtils.confirmOperation(
                                title: "Cancel Operation",
                                message: "Cancel '\(operationDesc)'?",
                                details: [
                                    "Type: \(operation.type.displayName)",
                                    "Status: \(operation.status.displayName)",
                                    "Progress: \(operation.progressPercentage)%"
                                ],
                                screen: screen,
                                screenRows: tui.screenRows,
                                screenCols: tui.screenCols
                            )

                            guard confirmed else {
                                tui.statusMessage = "Cancellation aborted"
                                await tui.draw(screen: screen)
                                return true
                            }

                            operation.cancel()
                            tui.statusMessage = "Operation cancelled: \(operation.displayName)"
                            Logger.shared.logUserAction("cancel_background_operation", details: [
                                "operationId": operation.id.uuidString,
                                "type": "\(operation.type)",
                                "objectName": operation.objectName ?? "unknown"
                            ])
                        } else {
                            // Inactive operation: Remove from history
                            let operationDesc = operation.displayName
                            let confirmed = await ViewUtils.confirmOperation(
                                title: "Remove Operation",
                                message: "Remove '\(operationDesc)' from history?",
                                details: [
                                    "Type: \(operation.type.displayName)",
                                    "Status: \(operation.status.displayName)"
                                ],
                                screen: screen,
                                screenRows: tui.screenRows,
                                screenCols: tui.screenCols
                            )

                            guard confirmed else {
                                tui.statusMessage = "Removal aborted"
                                await tui.draw(screen: screen)
                                return true
                            }

                            tui.swiftBackgroundOps.removeOperation(id: operation.id)

                            // Reset selection immediately after removal
                            let remainingOps = tui.swiftBackgroundOps.getAllOperations()
                            if tui.viewCoordinator.selectedIndex >= remainingOps.count {
                                tui.viewCoordinator.selectedIndex = max(0, remainingOps.count - 1)
                            }

                            // Force full screen refresh to immediately show the removal
                            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()

                            tui.statusMessage = "Removed operation: \(operation.displayName)"
                            Logger.shared.logUserAction("remove_background_operation", details: [
                                "operationId": operation.id.uuidString,
                                "type": "\(operation.type)",
                                "status": "\(operation.status)",
                                "objectName": operation.objectName ?? "unknown"
                            ])
                        }

                        await tui.draw(screen: screen)
                        return true

                    default:
                        return false
                    }
                }
            ),
            ViewMetadata(
                identifier: Views.backgroundOperationDetail,
                title: "Operation Details",
                parentViewId: Views.backgroundOperations.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .storage,
                renderHandler: { [weak self, weak tui] screen, startRow, startCol, width, height in
                    guard let self = self, let tui = tui else { return }
                    await self.renderSwiftBackgroundOperationDetailView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, screen in
                    guard let tui = tui else { return false }

                    switch ch {
                    case Int32(127), Int32(330):  // DELETE/BACKSPACE - Cancel or remove operation
                        guard let operation = tui.viewCoordinator.selectedResource as? SwiftBackgroundOperation else {
                            tui.statusMessage = "No operation selected"
                            await tui.draw(screen: screen)
                            return true
                        }

                        // Context-aware behavior based on operation status
                        if operation.status.isActive {
                            // Active operation: Cancel it
                            let operationDesc = operation.displayName
                            let confirmed = await ViewUtils.confirmOperation(
                                title: "Cancel Operation",
                                message: "Cancel '\(operationDesc)'?",
                                details: [
                                    "Type: \(operation.type.displayName)",
                                    "Status: \(operation.status.displayName)",
                                    "Progress: \(operation.progressPercentage)%"
                                ],
                                screen: screen,
                                screenRows: tui.screenRows,
                                screenCols: tui.screenCols
                            )

                            guard confirmed else {
                                tui.statusMessage = "Cancellation aborted"
                                await tui.draw(screen: screen)
                                return true
                            }

                            operation.cancel()
                            tui.statusMessage = "Operation cancelled: \(operation.displayName)"
                            Logger.shared.logUserAction("cancel_background_operation_detail", details: [
                                "operationId": operation.id.uuidString,
                                "type": "\(operation.type)",
                                "objectName": operation.objectName ?? "unknown"
                            ])
                        } else {
                            // Inactive operation: Remove from history and return to list
                            let operationDesc = operation.displayName
                            let confirmed = await ViewUtils.confirmOperation(
                                title: "Remove Operation",
                                message: "Remove '\(operationDesc)' from history?",
                                details: [
                                    "Type: \(operation.type.displayName)",
                                    "Status: \(operation.status.displayName)"
                                ],
                                screen: screen,
                                screenRows: tui.screenRows,
                                screenCols: tui.screenCols
                            )

                            guard confirmed else {
                                tui.statusMessage = "Removal aborted"
                                await tui.draw(screen: screen)
                                return true
                            }

                            tui.swiftBackgroundOps.removeOperation(id: operation.id)

                            // Reset selection immediately after removal
                            let remainingOps = tui.swiftBackgroundOps.getAllOperations()
                            if tui.viewCoordinator.selectedIndex >= remainingOps.count {
                                tui.viewCoordinator.selectedIndex = max(0, remainingOps.count - 1)
                            }

                            tui.statusMessage = "Removed operation: \(operation.displayName)"
                            Logger.shared.logUserAction("remove_background_operation_detail", details: [
                                "operationId": operation.id.uuidString,
                                "type": "\(operation.type)",
                                "status": "\(operation.status)",
                                "objectName": operation.objectName ?? "unknown"
                            ])

                            // Return to operations list
                            tui.changeView(to: .swiftBackgroundOperations, resetSelection: false)

                            // Force full screen refresh to immediately show the removal
                            tui.renderCoordinator.renderOptimizer.markFullScreenDirty()
                        }

                        await tui.draw(screen: screen)
                        return true

                    default:
                        return false
                    }
                }
            )
        ]
    }
}
