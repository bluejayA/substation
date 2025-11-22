// Sources/Substation/Modules/Swift/SwiftModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Swift (Object Storage) module implementation
/// Provides comprehensive object storage management capabilities including containers,
/// objects, metadata management, and background operations tracking.
@MainActor
final class SwiftModule: OpenStackModule {

    // MARK: - OpenStackModule Protocol Properties

    let identifier: String = "swift"
    let displayName: String = "Object Storage (Swift)"
    let version: String = "1.0.0"
    let dependencies: [String] = []

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    // MARK: - Initialization

    /// Initialize the Swift module with TUI context
    /// - Parameter tui: The main TUI instance providing access to OpenStack client and UI state
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("SwiftModule initialized", context: [
            "version": version,
            "identifier": identifier
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    /// Performs any necessary setup, validation, and initialization tasks
    func configure() async throws {
        guard tui != nil else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("SwiftModule configuration started", context: [:])

        // Module configured successfully
        // Swift service availability will be checked during actual API calls
        Logger.shared.logInfo("SwiftModule configuration completed", context: [:])

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .swift,
            detailViewMode: .swiftContainerDetail
        )

        // Register as data provider
        let dataProvider = SwiftDataProvider(module: self, tui: tui!)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)
    }

    // MARK: - View Registration

    /// Register all Swift-related views with the TUI system
    /// - Returns: Array of view registrations for containers, objects, metadata, and operations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register views - TUI reference is nil", context: [:])
            return []
        }

        return [
            // Main container list view
            ModuleViewRegistration(
                viewMode: .swift,
                title: "Swift Containers",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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

                    switch ch {
                    case Int32(32):  // SPACEBAR - Navigate into container
                        Logger.shared.logUserAction("swift_navigate_into_container", details: ["selectedIndex": tui.viewCoordinator.selectedIndex])
                        let containers = tui.cacheManager.cachedSwiftContainers
                        guard tui.viewCoordinator.selectedIndex < containers.count else {
                            tui.statusMessage = "No container selected"
                            return true
                        }
                        let container = containers[tui.viewCoordinator.selectedIndex]
                        guard let containerName = container.name else {
                            tui.statusMessage = "Invalid container"
                            return true
                        }
                        tui.viewCoordinator.swiftNavState.navigateIntoContainer(containerName)
                        tui.viewCoordinator.selectedResource = container
                        tui.changeView(to: .swiftContainerDetail, resetSelection: true)
                        await self.fetchSwiftObjects(containerName: containerName, priority: "interactive", forceRefresh: false)
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
                },
                category: .storage
            ),

            // Container detail view
            ModuleViewRegistration(
                viewMode: .swiftContainerDetail,
                title: "Container Details",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                            tui.viewCoordinator.swiftNavState.navigateIntoDirectory(name)
                            tui.viewCoordinator.selectedIndex = 0
                            tui.viewCoordinator.scrollOffset = 0
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

                            // Stay in the same view (swiftContainerDetail)
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

                            // Return to container list view
                            tui.changeView(to: .swift, resetSelection: false)
                            tui.viewCoordinator.selectedResource = nil
                            return true
                        }

                    default:
                        return false
                    }
                },
                category: .storage
            ),

            // Object detail view
            ModuleViewRegistration(
                viewMode: .swiftObjectDetail,
                title: "Object Details",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await self.renderSwiftObjectDetailView(
                        tui: tui,
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: { [weak tui] ch, _ in
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

                        tui.changeView(to: .swiftContainerDetail, resetSelection: false)
                        tui.viewCoordinator.selectedResource = nil
                        return true

                    default:
                        return false
                    }
                },
                category: .storage
            ),

            // Container create form
            ModuleViewRegistration(
                viewMode: .swiftContainerCreate,
                title: "Create Container",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Object upload form
            ModuleViewRegistration(
                viewMode: .swiftObjectUpload,
                title: "Upload Object",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Container download form
            ModuleViewRegistration(
                viewMode: .swiftContainerDownload,
                title: "Download Container",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Object download form
            ModuleViewRegistration(
                viewMode: .swiftObjectDownload,
                title: "Download Object",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Directory download form
            ModuleViewRegistration(
                viewMode: .swiftDirectoryDownload,
                title: "Download Directory",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Container metadata form
            ModuleViewRegistration(
                viewMode: .swiftContainerMetadata,
                title: "Set Container Metadata",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Object metadata form
            ModuleViewRegistration(
                viewMode: .swiftObjectMetadata,
                title: "Set Object Metadata",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Directory metadata form
            ModuleViewRegistration(
                viewMode: .swiftDirectoryMetadata,
                title: "Set Directory Metadata",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Container web access form
            ModuleViewRegistration(
                viewMode: .swiftContainerWebAccess,
                title: "Manage Web Access",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Background operations list
            ModuleViewRegistration(
                viewMode: .swiftBackgroundOperations,
                title: "Background Operations",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            ),

            // Background operation detail
            ModuleViewRegistration(
                viewMode: .swiftBackgroundOperationDetail,
                title: "Operation Details",
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
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
                },
                category: .storage
            )
        ]
    }

    // MARK: - Form Handler Registration

    /// Register form input handlers for Swift operations
    /// - Returns: Array of form handler registrations for create, upload, and metadata forms
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        return [
            ModuleFormHandlerRegistration(
                viewMode: .swiftContainerCreate,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftContainerCreateInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftContainerCreateForm.containerName.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftObjectUpload,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftObjectUploadInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftObjectUploadForm.filePath.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftContainerDownload,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftContainerDownloadInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftContainerDownloadForm.destinationPath.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftObjectDownload,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftObjectDownloadInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftObjectDownloadForm.destinationPath.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftDirectoryDownload,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftDirectoryDownloadInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    guard let tui = tui else { return false }
                    return !tui.swiftDirectoryDownloadForm.destinationPath.isEmpty
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftContainerMetadata,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftContainerMetadataInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    _ = tui
                    // Metadata forms are always valid - can set or clear metadata
                    return true
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftObjectMetadata,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftObjectMetadataInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    _ = tui
                    return true
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftDirectoryMetadata,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftDirectoryMetadataInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    _ = tui
                    return true
                }
            ),
            ModuleFormHandlerRegistration(
                viewMode: .swiftContainerWebAccess,
                handler: { [weak tui] ch, screen in
                    guard let tui = tui else { return }
                    await tui.handleSwiftContainerWebAccessInput(ch, screen: screen)
                },
                formValidation: { [weak tui] in
                    _ = tui
                    return true
                }
            )
        ]
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for Swift resources
    /// - Returns: Array of refresh handler registrations for containers and objects
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard tui != nil else {
            Logger.shared.logError("Cannot register data refresh handlers - TUI reference is nil", context: [:])
            return []
        }

        return [
            // Object list refresh for current container
            ModuleDataRefreshRegistration(
                identifier: "swift.objects",
                refreshHandler: { [weak self] in
                    guard let self = self else { return }
                    guard let containerName = self.tui?.viewCoordinator.swiftNavState.currentContainer else {
                        Logger.shared.logDebug("No container selected for object refresh")
                        return
                    }
                    await self.fetchSwiftObjects(
                        containerName: containerName,
                        priority: "user-initiated",
                        forceRefresh: true
                    )
                },
                cacheKey: nil, // Dynamic based on container
                refreshInterval: 15.0
            )
        ]
    }

    // MARK: - Cleanup

    /// Cleanup module resources when unloading
    func cleanup() async {
        Logger.shared.logInfo("SwiftModule cleanup started", context: [:])

        // Clear any cached Swift data
        if let tui = tui {
            tui.cacheManager.cachedSwiftContainers = []
            // Reset navigation state
            tui.viewCoordinator.swiftNavState.reset()
        }

        Logger.shared.logInfo("SwiftModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform health check on Swift module
    /// - Returns: Health status including service availability and metrics
    func healthCheck() async -> ModuleHealthStatus {
        var errors: [String] = []
        var metrics: [String: Any] = [:]

        guard let tui = tui else {
            return ModuleHealthStatus(
                isHealthy: false,
                lastCheck: Date(),
                errors: ["TUI reference is nil"],
                metrics: [:]
            )
        }

        // Check if we have Swift containers loaded
        let containerCount = tui.cacheManager.cachedSwiftContainers.count
        metrics["cached_containers"] = containerCount
        metrics["service_available"] = containerCount > 0

        if containerCount == 0 {
            errors.append("No Swift containers loaded - service may be unavailable")
        }

        if let currentContainer = tui.viewCoordinator.swiftNavState.currentContainer,
           let objects = tui.cacheManager.cachedSwiftObjects {
            metrics["cached_objects"] = objects.count
            metrics["current_container"] = currentContainer
        }

        // Navigation state metrics
        metrics["navigation_depth"] = tui.viewCoordinator.swiftNavState.depth
        metrics["is_at_container_list"] = tui.viewCoordinator.swiftNavState.isAtContainerList

        return ModuleHealthStatus(
            isHealthy: errors.isEmpty,
            lastCheck: Date(),
            errors: errors,
            metrics: metrics
        )
    }

    // MARK: - Computed Properties

    /// Get all cached Swift containers
    ///
    /// Returns all Swift containers from the cache manager.
    /// Used for container listing, filtering, and selection operations.
    var swiftContainers: [SwiftContainer] {
        return tui?.cacheManager.cachedSwiftContainers ?? []
    }

    /// Get cached Swift objects by container
    ///
    /// Returns all Swift objects organized by container name from the resource cache.
    /// Used for object listing and management across multiple containers.
    var swiftObjectsByContainer: [String: [SwiftObject]] {
        return tui?.cacheManager.resourceCache.swiftObjectsByContainer ?? [:]
    }

    /// Get Swift objects for a specific container from cache
    ///
    /// - Parameter containerName: Name of the container
    /// - Returns: Array of Swift objects, or nil if not cached
    func getSwiftObjects(forContainer containerName: String) -> [SwiftObject]? {
        return tui?.cacheManager.resourceCache.getSwiftObjects(forContainer: containerName)
    }

    /// Set Swift objects in cache for a specific container
    ///
    /// - Parameters:
    ///   - objects: Array of Swift objects
    ///   - containerName: Name of the container
    func setSwiftObjects(_ objects: [SwiftObject], forContainer containerName: String) async {
        await tui?.cacheManager.resourceCache.setSwiftObjects(objects, forContainer: containerName)
    }

    // MARK: - Render Methods

    /// Render the Swift container list view
    func renderSwiftContainerListView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        let containers = tui.cacheManager.cachedSwiftContainers
        let searchQuery = tui.searchQuery ?? ""

        await SwiftViews.drawSwiftContainerList(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            containers: containers,
            searchQuery: searchQuery,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex,
            dataManager: tui.dataManager,
            virtualScrollManager: nil,
            multiSelectMode: tui.selectionManager.multiSelectMode,
            selectedItems: tui.selectionManager.multiSelectedResourceIDs
        )
    }

    /// Render the Swift container detail view
    func renderSwiftContainerDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let container = tui.viewCoordinator.selectedResource as? SwiftContainer else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No container selected").error(), on: surface, in: bounds)
            return
        }

        // Fetch container metadata from the Swift service
        var metadata: SwiftContainerMetadataResponse? = nil
        if let containerName = container.name {
            do {
                metadata = try await tui.client.swift.getContainerMetadata(containerName: containerName)
            } catch {
                Logger.shared.logDebug("Failed to fetch container metadata: \(error.localizedDescription)")
                // Continue without metadata - the view will handle nil gracefully
            }
        }

        await SwiftViews.drawSwiftContainerDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            container: container,
            metadata: metadata,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }

    /// Render the Swift object detail view
    func renderSwiftObjectDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let object = tui.viewCoordinator.selectedResource as? SwiftObject else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No object selected").error(), on: surface, in: bounds)
            return
        }

        guard let containerName = tui.viewCoordinator.swiftNavState.currentContainer else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No container context").error(), on: surface, in: bounds)
            return
        }

        // Fetch object metadata from the Swift service
        var metadata: SwiftObjectMetadataResponse? = nil
        if let objectName = object.name {
            do {
                metadata = try await tui.client.swift.getObjectMetadata(
                    containerName: containerName,
                    objectName: objectName
                )
            } catch {
                Logger.shared.logDebug("Failed to fetch object metadata: \(error.localizedDescription)")
                // Continue without metadata - the view will handle nil gracefully
            }
        }

        await SwiftViews.drawSwiftObjectDetail(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            object: object,
            containerName: containerName,
            metadata: metadata,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }

    /// Render container create form view
    func renderSwiftContainerCreateView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftContainerCreate(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftContainerCreateFormState
        )
    }

    /// Render object upload form view
    func renderSwiftObjectUploadView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftObjectUpload(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftObjectUploadFormState
        )
    }

    /// Render container download form view
    func renderSwiftContainerDownloadView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftContainerDownload(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftContainerDownloadFormState
        )
    }

    /// Render object download form view
    func renderSwiftObjectDownloadView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftObjectDownload(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftObjectDownloadFormState
        )
    }

    /// Render directory download form view
    func renderSwiftDirectoryDownloadView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftDirectoryDownload(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftDirectoryDownloadFormState
        )
    }

    /// Render container metadata form view
    func renderSwiftContainerMetadataView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftContainerMetadata(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftContainerMetadataFormState
        )
    }

    /// Render object metadata form view
    func renderSwiftObjectMetadataView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftObjectMetadata(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftObjectMetadataFormState
        )
    }

    /// Render directory metadata form view
    func renderSwiftDirectoryMetadataView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftDirectoryMetadata(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftDirectoryMetadataFormState
        )
    }

    /// Render container web access form view
    func renderSwiftContainerWebAccessView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await SwiftViews.drawSwiftContainerWebAccess(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            formBuilderState: tui.swiftContainerWebAccessFormState
        )
    }

    /// Render background operations list view
    func renderSwiftBackgroundOperationsView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        // Get all background operations from the manager
        let operations = tui.swiftBackgroundOps.getAllOperations()

        await SwiftBackgroundOperationsView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            operations: operations,
            scrollOffset: tui.viewCoordinator.scrollOffset,
            selectedIndex: tui.viewCoordinator.selectedIndex
        )
    }

    /// Render background operation detail view
    func renderSwiftBackgroundOperationDetailView(
        tui: TUI,
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        guard let operation = tui.viewCoordinator.selectedResource as? SwiftBackgroundOperation else {
            let surface = SwiftNCurses.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftNCurses.render(Text("No operation selected").error(), on: surface, in: bounds)
            return
        }

        await SwiftBackgroundOperationDetailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            operation: operation,
            scrollOffset: tui.viewCoordinator.detailScrollOffset
        )
    }

    // MARK: - Swift Object Operations

    /// Fetch Swift objects for a specific container
    ///
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - priority: Fetch priority
    ///   - forceRefresh: Whether to bypass cache
    public func fetchSwiftObjects(containerName: String, priority: String, forceRefresh: Bool = false) async {
        guard let tui = tui else { return }

        // Check if objects are already cached (unless forceRefresh is true)
        if !forceRefresh {
            if let cachedObjects = self.getSwiftObjects(forContainer: containerName) {
                Logger.shared.logDebug("SwiftModule - Using cached Swift objects for container '\(containerName)' (\(cachedObjects.count) objects)")
                return
            }
        }

        Logger.shared.logDebug("SwiftModule - Fetching Swift objects for container '\(containerName)' (\(priority) priority)...")

        do {
            let apiStart = Date().timeIntervalSinceReferenceDate
            let objects = try await tui.client.swift.listObjects(containerName: containerName)
            let apiDuration = Date().timeIntervalSinceReferenceDate - apiStart
            Logger.shared.logDebug("SwiftModule - Fetched \(objects.count) Swift objects in \(String(format: "%.2f", apiDuration))s")
            await self.setSwiftObjects(objects, forContainer: containerName)
        } catch let error as OpenStackError {
            switch error {
            case .httpError(403, _):
                Logger.shared.logDebug("Swift object access requires permissions (HTTP 403)")
            case .httpError(404, _):
                Logger.shared.logDebug("Swift container not found (HTTP 404)")
            default:
                Logger.shared.logError("Failed to fetch Swift objects: \(error)")
            }
        } catch {
            Logger.shared.logError("Failed to fetch Swift objects: \(error)")
        }
    }
}

// MARK: - ActionProvider Conformance

extension SwiftModule: ActionProvider {
    /// Actions available in the list view for Swift containers
    ///
    /// Includes create, delete, refresh, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .clearCache]
    }

    /// Actions available in the detail view for Swift containers
    ///
    /// Includes delete, refresh, and cache management.
    var detailViewActions: [ActionType] {
        [.delete, .refresh, .clearCache]
    }

    /// The view mode for creating a new container
    var createViewMode: ViewMode? {
        .swiftContainerCreate
    }

    /// Execute an action for the selected Swift resource
    ///
    /// - Parameters:
    ///   - action: The action type to execute
    ///   - screen: Screen pointer for confirmation dialogs
    ///   - tui: The TUI instance for state management
    /// - Returns: Boolean indicating if the action was handled
    func executeAction(_ action: ActionType, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch action {
        case .create:
            guard let createMode = createViewMode else { return false }

            Logger.shared.logNavigation("\(tui.viewCoordinator.currentView)", to: ".swiftContainerCreate")
            tui.changeView(to: createMode)

            // Initialize Swift container create form
            tui.swiftContainerCreateForm = SwiftContainerCreateForm()
            tui.swiftContainerCreateFormState = FormBuilderState(
                fields: tui.swiftContainerCreateForm.buildFields(
                    selectedFieldId: "containerName",
                    activeFieldId: nil,
                    formState: FormBuilderState(fields: [])
                )
            )

            tui.statusMessage = "Create new container"
            return true
        case .delete:
            await deleteSwiftContainer(screen: screen)
            return true
        default:
            return false
        }
    }

    /// Get the bulk delete operation for selected Swift resources
    ///
    /// Creates a batch operation for deleting multiple containers or objects at once.
    /// The operation type depends on the current view context.
    ///
    /// - Parameters:
    ///   - selectedIDs: Set of resource identifiers to delete
    ///   - tui: The TUI instance for state management
    /// - Returns: BatchOperationType for bulk delete, or nil if not supported
    func getBulkDeleteOperation(selectedIDs: Set<String>, tui: TUI) -> BatchOperationType? {
        if tui.viewCoordinator.currentView == .swiftContainerDetail {
            // Get container name from selected resource
            guard let container = tui.viewCoordinator.selectedResource as? SwiftContainer,
                  let containerName = container.name else {
                return nil
            }
            return .swiftObjectBulkDelete(containerName: containerName, objectNames: Array(selectedIDs))
        }
        return .swiftContainerBulkDelete(containerNames: Array(selectedIDs))
    }

    /// Get the ID of the currently selected Swift resource
    ///
    /// Returns the resource identifier based on the current selection index, accounting for any
    /// search filtering that may be applied. Handles both container list and container detail
    /// views with their respective filtering logic.
    ///
    /// - Parameter tui: The TUI instance for state management
    /// - Returns: Resource identifier string (object ID or container name), or empty string if no valid selection
    func getSelectedResourceId(tui: TUI) -> String {
        if tui.viewCoordinator.currentView == .swiftContainerDetail {
            guard let allObjects = tui.cacheManager.cachedSwiftObjects else { return "" }
            let currentPath = tui.viewCoordinator.swiftNavState.currentPathString
            let treeItems = SwiftTreeItem.buildTree(from: allObjects, currentPath: currentPath)
            let filteredItems = SwiftTreeItem.filterItems(treeItems, query: tui.searchQuery?.isEmpty ?? true ? nil : tui.searchQuery)
            guard tui.viewCoordinator.selectedIndex < filteredItems.count else { return "" }
            return filteredItems[tui.viewCoordinator.selectedIndex].id
        }
        // Swift container list
        let filtered = tui.searchQuery?.isEmpty ?? true ? tui.cacheManager.cachedSwiftContainers : tui.cacheManager.cachedSwiftContainers.filter { container in
            container.name?.lowercased().contains(tui.searchQuery?.lowercased() ?? "") ?? false
        }
        guard tui.viewCoordinator.selectedIndex < filtered.count else { return "" }
        return filtered[tui.viewCoordinator.selectedIndex].name ?? ""
    }
}
