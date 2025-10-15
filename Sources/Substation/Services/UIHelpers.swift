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

/// Service layer for UI helper operations
///
/// This service encapsulates UI-related operations including:
/// - Dialog displays (console output, private key, snapshot naming)
/// - Server selection helpers
/// - Batch operation management
/// - Enhanced resource management workflows
@MainActor
final class UIHelpers {
    private let tui: TUI

    init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Convenience Accessors

    private var client: OSClient { tui.client }
    private var dataManager: DataManager { tui.dataManager }
    private var resourceOperations: ResourceOperations { tui.resourceOperations }
    private var batchOperationManager: BatchOperationManager { tui.batchOperationManager }
    private var statusMessage: String? {
        get { tui.statusMessage }
        set { tui.statusMessage = newValue }
    }
    private var errorHandler: OperationErrorHandler { tui.errorHandler }
    private var validator: ValidationService { tui.validator }
    private var currentView: ViewMode {
        get { tui.currentView }
        set { tui.currentView = newValue }
    }
    private var searchQuery: String? { tui.searchQuery }
    private var selectedIndex: Int {
        get { tui.selectedIndex }
        set { tui.selectedIndex = newValue }
    }
    private var selectedResource: Any? {
        get { tui.selectedResource }
        set { tui.selectedResource = newValue }
    }
    private var selectedServers: Set<String> {
        get { tui.selectedServers }
        set { tui.selectedServers = newValue }
    }
    private var attachedServerIds: Set<String> {
        get { tui.attachedServerIds }
        set { tui.attachedServerIds = newValue }
    }
    private var selectedServerId: String? {
        get { tui.selectedServerId }
        set { tui.selectedServerId = newValue }
    }
    private var selectedRouterId: String? {
        get { tui.selectedRouterId }
        set { tui.selectedRouterId = newValue }
    }
    private var attachmentMode: AttachmentMode {
        get { tui.attachmentMode }
        set { tui.attachmentMode = newValue }
    }
    private var screenRows: Int32 { tui.screenRows }
    private var screenCols: Int32 { tui.screenCols }
    private var scrollOffset: Int {
        get { tui.scrollOffset }
        set { tui.scrollOffset = newValue }
    }
    private var resourceResolver: ResourceResolver { tui.resourceResolver }

    // Cache accessors
    private var cachedServers: [Server] {
        get { tui.cachedServers }
        set { tui.cachedServers = newValue }
    }
    private var cachedNetworks: [Network] { tui.cachedNetworks }
    private var cachedSubnets: [Subnet] { tui.cachedSubnets }
    private var cachedPorts: [Port] {
        get { tui.cachedPorts }
        set { tui.cachedPorts = newValue }
    }
    private var cachedRouters: [Router] { tui.cachedRouters }
    private var cachedFloatingIPs: [FloatingIP] {
        get { tui.cachedFloatingIPs }
        set { tui.cachedFloatingIPs = newValue }
    }
    private var cachedVolumes: [Volume] {
        get { tui.cachedVolumes }
        set { tui.cachedVolumes = newValue }
    }
    private var cachedSecurityGroups: [SecurityGroup] {
        get { tui.cachedSecurityGroups }
        set { tui.cachedSecurityGroups = newValue }
    }
    private var cachedFlavors: [Flavor] { tui.cachedFlavors }
    private var cachedVolumeSnapshots: [VolumeSnapshot] { tui.cachedVolumeSnapshots }

    // MARK: - UI Helper Methods

    private func selectServer(screen: OpaquePointer?, title: String) async -> String? {
        guard !cachedServers.isEmpty else {
            return nil
        }

        // Create a simple selection dialog
        var serverSelectedIndex = 0

        while true {
            // Use SwiftTUI to render the server selection dialog
            let surface = SwiftTUI.surface(from: screen)
            let startRow = 5
            let dialogHeight = min(cachedServers.count + 4, Int(screenRows) - 10)
            let dialogWidth = screenCols - 4

            // Clear dialog area
            let dialogBounds = Rect(x: 2, y: Int32(startRow), width: dialogWidth, height: Int32(dialogHeight))
            surface.clear(rect: dialogBounds)

            // Create bordered container with title and server list
            var serverComponents: [any Component] = []

            let maxServersToShow = dialogHeight - 5
            let startIndex = max(0, serverSelectedIndex - maxServersToShow/2)
            let endIndex = min(cachedServers.count, startIndex + maxServersToShow)

            for serverIndex in startIndex..<endIndex {
                let server = cachedServers[serverIndex]
                let isSelected = serverIndex == serverSelectedIndex
                let serverName = server.name ?? "Unnamed Server"
                let truncatedName = String(serverName.prefix(Int(screenCols) - 10))

                let serverText = Text(truncatedName).styled(isSelected ? .primary.reverse() : .secondary)
                serverComponents.append(serverText)
            }

            // Add instructions
            serverComponents.append(Text("Press ENTER to select, ESC to cancel, UP/DOWN to navigate").info())

            let dialogContent = VStack(spacing: 0, children: serverComponents)
                .padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))

            let borderedDialog = BorderedContainer(title: title, content: {
                // Empty content closure since we render manually
            })

            await SwiftTUI.render(borderedDialog, on: surface, in: dialogBounds)
            await SwiftTUI.render(dialogContent, on: surface, in: dialogBounds)

            SwiftTUI.batchedRefresh(WindowHandle(screen))

            let ch = SwiftTUI.getInput(WindowHandle(screen))

            switch ch {
            case Int32(259), Int32(258): // UP/DOWN - Navigate server list
                if ch == Int32(259) {
                    if serverSelectedIndex > 0 {
                        serverSelectedIndex -= 1
                    }
                } else {
                    if serverSelectedIndex < cachedServers.count - 1 {
                        serverSelectedIndex += 1
                    }
                }
            case 10, 13: // Enter key
                await tui.draw(screen: screen) // Redraw main interface
                return cachedServers[serverSelectedIndex].id
            case 27: // ESC key
                await tui.draw(screen: screen) // Redraw main interface
                return nil
            default:
                break
            }
        }
    }

    private func showSnapshotNameDialog(serverName: String, screen: OpaquePointer?) async -> String? {
        var snapshotName = "\(serverName)-snapshot-\(Int(Date().timeIntervalSince1970))"
        var cursorPosition = snapshotName.count

        // Disable nodelay for dialog interaction
        let _ = SwiftTUI.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftTUI.setNodelay(WindowHandle(screen), true)
        }

        while true {
            // Clear screen
            SwiftTUI.clear(WindowHandle(screen))

            // Draw the snapshot dialog
            let dialogWidth: Int32 = 60
            let dialogHeight: Int32 = 10
            let dialogStartRow = (screenRows - dialogHeight) / 2
            let dialogStartCol = (screenCols - dialogWidth) / 2

            // Draw dialog box using SwiftTUI
            let surface = SwiftTUI.surface(from: screen)
            let dialogBounds = Rect(x: dialogStartCol, y: dialogStartRow, width: dialogWidth, height: dialogHeight)
            await surface.fill(rect: dialogBounds, character: " ", style: .accent)

            // Draw border using SwiftTUI
            let topBorderBounds = Rect(x: dialogStartCol, y: dialogStartRow, width: dialogWidth, height: 1)
            let bottomBorderBounds = Rect(x: dialogStartCol, y: dialogStartRow + dialogHeight - 1, width: dialogWidth, height: 1)
            await SwiftTUI.render(Text(String(repeating: "-", count: Int(dialogWidth))).muted(), on: surface, in: topBorderBounds)
            await SwiftTUI.render(Text(String(repeating: "-", count: Int(dialogWidth))).muted(), on: surface, in: bottomBorderBounds)

            // Create dialog content using SwiftTUI
            let dialogComponents: [any Component] = [
                Text(""),  // Spacer for top border
                Text("  Create Server Snapshot").accent().bold(),
                Text(""),  // Spacer
                Text("  Server: \(serverName)").secondary(),
                Text(""),  // Spacer
                Text("  Snapshot Name:").secondary(),
                Text("  \(String(snapshotName.prefix(Int(dialogWidth) - 6)))").primary(),
                Text(""),  // Spacer
                Text("  ENTER: Create snapshot  ESC: Cancel").info()
            ]

            let dialogContent = VStack(spacing: 0, children: dialogComponents)
            let contentBounds = Rect(x: dialogStartCol, y: dialogStartRow, width: dialogWidth, height: dialogHeight)
            await SwiftTUI.render(dialogContent, on: surface, in: contentBounds)

            // Position cursor manually for input field
            let displayName = String(snapshotName.prefix(Int(dialogWidth) - 6))
            let cursorCol = dialogStartCol + 2 + Int32(min(cursorPosition, displayName.count))
            SwiftTUI.moveCursor(WindowHandle(screen), to: Point(x: cursorCol, y: dialogStartRow + 6))

            SwiftTUI.batchedRefresh(WindowHandle(screen))

            let ch = SwiftTUI.getInput(WindowHandle(screen))

            switch ch {
            case Int32(27): // ESC - Cancel
                return nil
            case Int32(10), Int32(13): // ENTER - Confirm
                tui.needsRedraw = true
                if !snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return snapshotName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case Int32(127), Int32(8): // Backspace
                if cursorPosition > 0 {
                    snapshotName.remove(at: snapshotName.index(snapshotName.startIndex, offsetBy: cursorPosition - 1))
                    cursorPosition -= 1
                }
            case Int32(260): // KEY_LEFT
                cursorPosition = max(0, cursorPosition - 1)
            case Int32(261): // KEY_RIGHT
                cursorPosition = min(snapshotName.count, cursorPosition + 1)
            default:
                // Handle printable characters
                if ch >= 32 && ch <= 126 {
                    let character = Character(UnicodeScalar(Int(ch))!)
                    snapshotName.insert(character, at: snapshotName.index(snapshotName.startIndex, offsetBy: cursorPosition))
                    cursorPosition += 1
                }
            }
        }
    }

    internal func showConsoleOutputDialog(serverName: String, output: String, screen: OpaquePointer?) async {
        // Disable nodelay for dialog interaction
        let _ = SwiftTUI.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftTUI.setNodelay(WindowHandle(screen), true)
        }

        var verticalScrollOffset = 0
        var horizontalScrollOffset = 0
        let lines = output.components(separatedBy: .newlines)
        let totalLines = lines.count

        // Calculate maximum line width for horizontal scrolling
        let maxLineWidth = lines.map { $0.count }.max() ?? 0

        while true {
            // Fill background with consistent secondary styling to match other views
            let surface = SwiftTUI.surface(from: screen)
            let fullScreenBounds = Rect(x: 0, y: 0, width: screenCols, height: screenRows)
            await surface.fill(rect: fullScreenBounds, character: " ", style: .secondary)

            // Full screen dialog dimensions
            let dialogWidth = screenCols
            let dialogHeight = screenRows

            // Title bar using SwiftTUI
            let titleBounds = Rect(x: 0, y: 0, width: screenCols, height: 1)
            let titleComponent = Text("Console Output: \(serverName)").accent().bold()
            await SwiftTUI.render(titleComponent, on: surface, in: titleBounds)

            // Help bar at bottom using SwiftTUI
            let helpBounds = Rect(x: 0, y: screenRows - 1, width: screenCols, height: 1)
            let helpComponent = Text("UP/DOWN,j/k:scroll vertical  LEFT/RIGHT,h/l:scroll horizontal  PgUp/PgDn,Home/End  ESC:close").info()
            await SwiftTUI.render(helpComponent, on: surface, in: helpBounds)

            // Console output content area
            let contentHeight = Int(dialogHeight - 2) // Leave space for title and help bars
            let contentWidth = Int(dialogWidth)

            // Create console content components
            var contentComponents: [any Component] = []

            for i in 0..<contentHeight {
                let lineIndex = verticalScrollOffset + i
                if lineIndex < totalLines {
                    let fullLine = lines[lineIndex]
                    // Apply horizontal scrolling
                    let startPos = horizontalScrollOffset
                    let endPos = min(startPos + contentWidth, fullLine.count)

                    let visibleLine: String
                    if startPos < fullLine.count {
                        let startIndex = fullLine.index(fullLine.startIndex, offsetBy: startPos)
                        let endIndex = fullLine.index(fullLine.startIndex, offsetBy: endPos)
                        visibleLine = String(fullLine[startIndex..<endIndex])
                    } else {
                        visibleLine = ""
                    }

                    contentComponents.append(Text(visibleLine).info())
                } else {
                    contentComponents.append(Text("").info())
                }
            }

            // Render console content
            let contentBounds = Rect(x: 0, y: 1, width: screenCols, height: Int32(contentHeight))
            let contentView = VStack(spacing: 0, children: contentComponents)
            await SwiftTUI.render(contentView, on: surface, in: contentBounds)

            // Scroll indicators using SwiftTUI
            if totalLines > contentHeight {
                let scrollInfo = "Line \(verticalScrollOffset + 1)/\(totalLines)"
                let scrollBounds = Rect(x: screenCols - 20, y: screenRows - 2, width: 20, height: 1)
                await SwiftTUI.render(Text(scrollInfo).accent(), on: surface, in: scrollBounds)
            }

            if maxLineWidth > contentWidth {
                let maxHorizontalScroll = maxLineWidth - contentWidth
                if maxHorizontalScroll > 0 {
                    let scrollInfo = "Col \(horizontalScrollOffset + 1)/\(maxLineWidth)"
                    let scrollBounds = Rect(x: 2, y: screenRows - 2, width: 20, height: 1)
                    await SwiftTUI.render(Text(scrollInfo).accent(), on: surface, in: scrollBounds)
                }
            }

            SwiftTUI.batchedRefresh(WindowHandle(screen))

            let ch = SwiftTUI.getInput(WindowHandle(screen))

            switch ch {
            case Int32(27): // ESC - Close dialog
                // Clear screen before returning to prevent artifacts
                SwiftTUI.clear(WindowHandle(screen))
                tui.forceRedraw()
                return
            case Int32(259), Int32(258): // UP/DOWN - Scroll vertical
                if ch == Int32(259) {
                    verticalScrollOffset = max(0, verticalScrollOffset - 1)
                } else {
                    verticalScrollOffset = min(max(0, totalLines - contentHeight), verticalScrollOffset + 1)
                }
            case Int32(260), Int32(261): // LEFT/RIGHT - Scroll horizontal
                if ch == Int32(260) {
                    horizontalScrollOffset = max(0, horizontalScrollOffset - 5)
                } else {
                    let maxHorizontalScroll = max(0, maxLineWidth - contentWidth)
                    horizontalScrollOffset = min(maxHorizontalScroll, horizontalScrollOffset + 5)
                }
            case Int32(338), Int32(339): // PAGE_DOWN/PAGE_UP
                if ch == Int32(338) {
                    verticalScrollOffset = min(max(0, totalLines - contentHeight), verticalScrollOffset + contentHeight)
                } else {
                    verticalScrollOffset = max(0, verticalScrollOffset - contentHeight)
                }
            case Int32(262), Int32(360): // HOME/END
                if ch == Int32(262) {
                    verticalScrollOffset = 0
                    horizontalScrollOffset = 0
                } else {
                    verticalScrollOffset = max(0, totalLines - contentHeight)
                    let maxHorizontalScroll = max(0, maxLineWidth - contentWidth)
                    horizontalScrollOffset = maxHorizontalScroll
                }
            default:
                break
            }
        }
    }

    internal func showPrivateKeyDialog(privateKey: String, keyPairName: String, screen: OpaquePointer?, savedPath: String? = nil) async {
        // Disable nodelay for dialog interaction
        let _ = SwiftTUI.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftTUI.setNodelay(WindowHandle(screen), true)
        }

        var verticalScrollOffset = 0
        var horizontalScrollOffset = 0
        let lines = privateKey.components(separatedBy: .newlines)
        let totalLines = lines.count

        // Calculate maximum line width for horizontal scrolling
        let maxLineWidth = lines.map { $0.count }.max() ?? 0

        while true {
            // Clear screen
            SwiftTUI.clear(WindowHandle(screen))

            // Full screen dialog - use entire screen
            let dialogWidth = screenCols
            let dialogHeight = screenRows
            let dialogStartRow: Int32 = 0
            let dialogStartCol: Int32 = 0

            // Draw title bar at top
            let title: String
            if let savedPath = savedPath {
                title = "PRIVATE KEY for '\(keyPairName)' - SAVED TO: \(savedPath)"
            } else {
                title = "PRIVATE KEY for '\(keyPairName)' - SAVE THIS NOW! (It won't be shown again)"
            }
            let titlePadding = String(repeating: " ", count: Int(screenCols) - title.count)
            SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: 0, col: 0), text: title + titlePadding, color: .error)

            // Draw help bar at bottom
            let helpText: String
            if savedPath != nil {
                helpText = "UP/DOWN,j/k:scroll vertical  LEFT/RIGHT,h/l:scroll horizontal  ESC:close  Private key saved to ~/.ssh/"
            } else {
                helpText = "UP/DOWN,j/k:scroll vertical  LEFT/RIGHT,h/l:scroll horizontal  ESC:close  IMPORTANT: Save this private key now!"
            }
            let helpPadding = String(repeating: " ", count: Int(screenCols) - helpText.count)
            SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: screenRows - 1, col: 0), text: helpText + helpPadding, color: .accent)

            // Draw private key content (full screen minus title and help bars)
            let contentHeight = Int(dialogHeight - 2) // Leave space for title and help bars
            let contentWidth = Int(dialogWidth)

            for i in 0..<contentHeight {
                let lineIndex = verticalScrollOffset + i
                if lineIndex < totalLines {
                    let fullLine = lines[lineIndex]
                    // Apply horizontal scrolling
                    let startPos = horizontalScrollOffset
                    let endPos = min(startPos + contentWidth, fullLine.count)

                    let visibleLine: String
                    if startPos < fullLine.count {
                        let startIndex = fullLine.index(fullLine.startIndex, offsetBy: startPos)
                        let endIndex = fullLine.index(fullLine.startIndex, offsetBy: endPos)
                        visibleLine = String(fullLine[startIndex..<endIndex])
                    } else {
                        visibleLine = ""
                    }

                    SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: dialogStartRow + 1 + Int32(i), col: dialogStartCol), text: visibleLine, color: .info)

                    // Clear the rest of the line to avoid artifacts
                    SwiftTUI.clearToEndOfLine(WindowHandle(screen))
                }
            }

            SwiftTUI.batchedRefresh(WindowHandle(screen))

            let ch = SwiftTUI.getInput(WindowHandle(screen))

            switch ch {
            case Int32(27): // ESC - Close dialog
                return
            case Int32(259), Int32(107): // UP or 'k' - Scroll up
                verticalScrollOffset = max(0, verticalScrollOffset - 1)
            case Int32(258), Int32(106): // DOWN or 'j' - Scroll down
                verticalScrollOffset = min(max(0, totalLines - contentHeight), verticalScrollOffset + 1)
            case Int32(260), Int32(104): // LEFT or 'h' - Scroll left
                horizontalScrollOffset = max(0, horizontalScrollOffset - 5)
            case Int32(261), Int32(108): // RIGHT or 'l' - Scroll right
                let maxHorizontalScroll = max(0, maxLineWidth - contentWidth)
                horizontalScrollOffset = min(maxHorizontalScroll, horizontalScrollOffset + 5)
            default:
                break
            }
        }
    }

    internal func handleBatchOperationResult(_ result: BatchOperationResult) async {
        let successRate = result.successRate * 100.0
        let duration = result.duration ?? 0

        Logger.shared.logInfo("TUI - Batch operation completed: \(result.type.description)")
        Logger.shared.logInfo("TUI - Success rate: \(String(format: "%.1f", successRate))%, Duration: \(String(format: "%.1f", duration))s")

        // Update UI with result message
        let message: String
        if result.successfulOperations == result.totalOperations {
            message = "Batch operation completed successfully: \(result.successfulOperations)/\(result.totalOperations) operations"
        } else if result.successfulOperations > 0 {
            message = "Batch operation partially completed: \(result.successfulOperations)/\(result.totalOperations) operations succeeded"
        } else {
            message = "Batch operation failed: All \(result.totalOperations) operations failed"
        }

        statusMessage = message

        // Trigger data refresh to show updated state
        await dataManager.refreshAllData()
        tui.markNeedsRedraw()

        // Show detailed results if there were failures
        if result.failedOperations > 0 {
            Logger.shared.logWarning("TUI - Batch operation had \(result.failedOperations) failures:")
            for (index, operationResult) in result.results.enumerated() {
                if operationResult.status == .failed {
                    Logger.shared.logWarning("TUI - Operation \(index): \(operationResult.resourceType) - \(operationResult.error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    internal func performBatchNetworkAttachment() async {
        guard !selectedServers.isEmpty else {
            statusMessage = "No servers selected for network attachment"
            return
        }

        guard let selectedNetwork = selectedResource as? Network else {
            statusMessage = "No network selected for attachment"
            return
        }

        let networkName = selectedNetwork.name ?? "Unknown"
        let serverCount = selectedServers.count

        // Create network interface operations for each selected server
        let operations = Array(selectedServers).map { serverId in
            NetworkInterfaceOperation(
                serverID: serverId,
                networkID: selectedNetwork.id,
                portID: nil,
                fixedIPs: []
            )
        }

        statusMessage = "Starting batch attachment of network '\(networkName)' to \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        // Execute the batch operation
        let batchOperation = BatchOperationType.networkInterfaceBulkAttach(operations: operations)

        let result = await batchOperationManager.execute(batchOperation) { @Sendable progress in
            Task { @MainActor in
                let percentage = Int(progress.completionPercentage * 100)
                self.statusMessage = "Attaching network: \(progress.currentOperation)/\(progress.totalOperations) (\(percentage)%)"
            }
        }

        // Update status message with results
        switch result.status {
        case .completed:
            if result.failedOperations == 0 {
                statusMessage = "Successfully attached network '\(networkName)' to \(result.successfulOperations) server\(result.successfulOperations == 1 ? "" : "s")"
            } else {
                statusMessage = "Attached network to \(result.successfulOperations) server\(result.successfulOperations == 1 ? "" : "s"), \(result.failedOperations) failed. Check logs for details."
            }
        case .failed:
            statusMessage = "Failed to attach network to servers. See logs for details."
        case .cancelled:
            statusMessage = "Network attachment operation was cancelled"
        case .executing, .planning, .validating:
            statusMessage = "Network attachment operation in progress..."
        case .pending:
            statusMessage = "Network attachment operation pending..."
        case .rollingBack:
            statusMessage = "Rolling back network attachment operation..."
        case .rolledBack:
            statusMessage = "Network attachment operation rolled back"
        }

        // Clear selections and return to networks view
        selectedServers.removeAll()
        tui.changeView(to: .networks, resetSelection: false)

        // Refresh server data to show updated network attachments
        tui.refreshAfterOperation()
    }

    internal func performBatchSecurityGroupAttachment() async {
        guard !selectedServers.isEmpty else {
            statusMessage = "No servers selected for security group attachment"
            return
        }

        guard let selectedSecurityGroup = selectedResource as? SecurityGroup else {
            statusMessage = "No security group selected for attachment"
            return
        }

        let securityGroupName = selectedSecurityGroup.name ?? "Unknown"
        let serverCount = selectedServers.count

        statusMessage = "Attaching security group '\(securityGroupName)' to \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        var successCount = 0
        var errorCount = 0
        var errors: [String] = []

        for serverId in selectedServers {
            // Find the server object
            guard let server = cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                errors.append("Server with ID \(serverId) not found")
                continue
            }

            do {
                // Attach security group to server
                try await client.addSecurityGroup(serverID: serverId, securityGroupName: selectedSecurityGroup.name ?? selectedSecurityGroup.id)
                successCount += 1
                Logger.shared.logUserAction("security_group_attached_to_server", details: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "securityGroupId": selectedSecurityGroup.id,
                    "securityGroupName": securityGroupName
                ])
            } catch {
                errorCount += 1
                let serverName = server.name ?? "Unknown"
                let errorMessage = "Failed to attach security group to '\(serverName)': \(error.localizedDescription)"
                errors.append(errorMessage)
                Logger.shared.logError("Failed to attach security group to server", error: error, context: [
                    "serverId": serverId,
                    "serverName": serverName,
                    "securityGroupId": selectedSecurityGroup.id,
                    "securityGroupName": securityGroupName
                ])
            }
        }

        // Update status message with results
        if errorCount == 0 {
            statusMessage = "Successfully attached security group '\(securityGroupName)' to \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            statusMessage = "Failed to attach security group to any servers. See logs for details."
        } else {
            statusMessage = "Attached security group to \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed. See logs for details."
        }

        // Clear selections and return to security groups view
        selectedServers.removeAll()
        tui.changeView(to: .securityGroups, resetSelection: false)

        // Refresh server data to show updated security group attachments
        tui.refreshAfterOperation()
    }

    internal func performBatchVolumeAttachment() async {
        guard !selectedServers.isEmpty else {
            statusMessage = "No servers selected for volume attachment"
            return
        }
        guard let selectedVolume = selectedResource as? Volume else {
            statusMessage = "No volume selected for attachment"
            return
        }
        let volumeName = selectedVolume.name ?? "Unknown"
        let serverCount = selectedServers.count
        statusMessage = "Attaching volume '\(volumeName)' to \(serverCount) server\(serverCount == 1 ? "" : "s")..."
        var successCount = 0
        var errorCount = 0
        var errors: [String] = []
        for serverId in selectedServers {
            // Find the server object
            guard let server = cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                errors.append("Server with ID \(serverId) not found")
                continue
            }
            do {
                // Attach volume to server
                try await client.attachVolume(volumeId: selectedVolume.id, serverId: serverId)
                successCount += 1
                Logger.shared.logUserAction("volume_attached_to_server", details: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "volumeId": selectedVolume.id,
                    "volumeName": volumeName
                ])
            } catch {
                errorCount += 1
                let serverName = server.name ?? "Unknown"
                let errorMessage = "Failed to attach volume to '\(serverName)': \(error.localizedDescription)"
                errors.append(errorMessage)
                Logger.shared.logError("Failed to attach volume to server", error: error, context: [
                    "serverId": serverId,
                    "serverName": serverName,
                    "volumeId": selectedVolume.id,
                    "volumeName": volumeName
                ])
            }
        }
        // Update status message with results
        if errorCount == 0 {
            statusMessage = "Successfully attached volume '\(volumeName)' to \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            statusMessage = "Failed to attach volume to any servers. See logs for details."
        } else {
            statusMessage = "Attached volume to \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed. See logs for details."
        }
        // Clear selections and return to volumes view
        selectedServers.removeAll()
        tui.changeView(to: .volumes, resetSelection: false)
        // Refresh server data to show updated volume attachments
        tui.refreshAfterOperation()
    }

    internal func performEnhancedSecurityGroupManagement() async {
        guard !selectedServers.isEmpty else {
            statusMessage = "No servers selected for security group \(attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }
        guard let selectedSecurityGroup = selectedResource as? SecurityGroup else {
            statusMessage = "No security group selected for \(attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }

        let groupName = selectedSecurityGroup.name ?? "Unknown"
        let serverCount = selectedServers.count
        let action = attachmentMode == .attach ? "attaching" : "detaching"
        statusMessage = "\(action.capitalized) security group '\(groupName)' \(attachmentMode == .attach ? "to" : "from") \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        var successCount = 0
        var errorCount = 0

        for serverId in selectedServers {
            guard let server = cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                continue
            }

            do {
                if attachmentMode == .attach {
                    try await client.addSecurityGroup(serverID: serverId, securityGroupName: selectedSecurityGroup.name ?? selectedSecurityGroup.id)
                } else {
                    try await client.removeSecurityGroup(serverID: serverId, securityGroupName: selectedSecurityGroup.name ?? selectedSecurityGroup.id)
                }
                successCount += 1
            } catch {
                errorCount += 1
                Logger.shared.logError("Failed to \(attachmentMode == .attach ? "attach" : "detach") security group", error: error, context: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "securityGroupId": selectedSecurityGroup.id,
                    "securityGroupName": groupName
                ])
            }
        }

        if errorCount == 0 {
            statusMessage = "Successfully \(attachmentMode == .attach ? "attached" : "detached") security group '\(groupName)' \(attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            statusMessage = "Failed to \(attachmentMode == .attach ? "attach" : "detach") security group \(attachmentMode == .attach ? "to" : "from") any servers"
        } else {
            statusMessage = "\(attachmentMode == .attach ? "Attached" : "Detached") security group \(attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed"
        }

        selectedServers.removeAll()
        tui.changeView(to: .securityGroups, resetSelection: false)
        tui.refreshAfterOperation()
    }

    internal func performEnhancedNetworkManagement() async {
        guard !selectedServers.isEmpty else {
            statusMessage = "No servers selected for network \(attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }
        guard let selectedNetwork = selectedResource as? Network else {
            statusMessage = "No network selected for \(attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }

        let networkName = selectedNetwork.name ?? "Unknown"
        let serverCount = selectedServers.count
        let action = attachmentMode == .attach ? "connecting" : "disconnecting"
        statusMessage = "\(action.capitalized) network '\(networkName)' \(attachmentMode == .attach ? "to" : "from") \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        // Force immediate UI update to show status message
        tui.forceRedraw()

        var successCount = 0
        var errorCount = 0

        for serverId in selectedServers {
            guard let server = cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                continue
            }

            do {
                if attachmentMode == .attach {
                    let port = try await client.createPort(
                        name: "server-\(serverId)-network-\(selectedNetwork.id)",
                        description: "Auto-created port for enhanced management",
                        networkID: selectedNetwork.id,
                        subnetID: nil,
                        securityGroups: nil,
                        qosPolicyID: nil
                    )
                    try await client.attachPort(serverID: serverId, portID: port.id)
                } else {
                    // Find and delete the port connecting this server to the network
                    let ports = try await client.listPorts()
                    if let port = ports.first(where: { $0.deviceId == serverId && $0.networkId == selectedNetwork.id }) {
                        try await client.deletePort(id: port.id)
                    }
                }
                successCount += 1
            } catch {
                errorCount += 1
                Logger.shared.logError("Failed to \(attachmentMode == .attach ? "attach" : "detach") network", error: error, context: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "networkId": selectedNetwork.id,
                    "networkName": networkName
                ])
            }
        }

        if errorCount == 0 {
            statusMessage = "Successfully \(attachmentMode == .attach ? "connected" : "disconnected") network '\(networkName)' \(attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            statusMessage = "Failed to \(attachmentMode == .attach ? "connect" : "disconnect") network \(attachmentMode == .attach ? "to" : "from") any servers"
        } else {
            statusMessage = "\(attachmentMode == .attach ? "Connected" : "Disconnected") network \(attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed"
        }

        selectedServers.removeAll()
        tui.changeView(to: .networks, resetSelection: false)
        tui.refreshAfterOperation()
    }

    internal func performEnhancedVolumeManagement() async {
        guard !selectedServers.isEmpty else {
            statusMessage = "No servers selected for volume \(attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }
        guard let selectedVolume = selectedResource as? Volume else {
            statusMessage = "No volume selected for \(attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }

        let volumeName = selectedVolume.name ?? "Unknown"
        let serverCount = selectedServers.count
        let action = attachmentMode == .attach ? "attaching" : "detaching"
        statusMessage = "\(action.capitalized) volume '\(volumeName)' \(attachmentMode == .attach ? "to" : "from") \(serverCount) server\(serverCount == 1 ? "" : "s")..."

        // Force immediate UI update to show status message
        tui.forceRedraw()

        var successCount = 0
        var errorCount = 0

        for serverId in selectedServers {
            guard let server = cachedServers.first(where: { $0.id == serverId }) else {
                errorCount += 1
                continue
            }

            do {
                if attachmentMode == .attach {
                    try await client.attachVolume(volumeId: selectedVolume.id, serverId: serverId)
                } else {
                    try await client.detachVolume(serverId: serverId, volumeId: selectedVolume.id)
                }
                successCount += 1
            } catch {
                errorCount += 1
                Logger.shared.logError("Failed to \(attachmentMode == .attach ? "attach" : "detach") volume", error: error, context: [
                    "serverId": serverId,
                    "serverName": server.name ?? "Unknown",
                    "volumeId": selectedVolume.id,
                    "volumeName": volumeName
                ])
            }
        }

        if errorCount == 0 {
            statusMessage = "Successfully \(attachmentMode == .attach ? "attached" : "detached") volume '\(volumeName)' \(attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s")"
        } else if successCount == 0 {
            statusMessage = "Failed to \(attachmentMode == .attach ? "attach" : "detach") volume \(attachmentMode == .attach ? "to" : "from") any servers"
        } else {
            statusMessage = "\(attachmentMode == .attach ? "Attached" : "Detached") volume \(attachmentMode == .attach ? "to" : "from") \(successCount) server\(successCount == 1 ? "" : "s"), \(errorCount) failed"
        }

        selectedServers.removeAll()
        tui.changeView(to: .volumes, resetSelection: false)
        tui.refreshAfterOperation()
    }

    internal func performFloatingIPServerManagement() async {
        guard let selectedId = selectedServerId else {
            statusMessage = "No server selected for floating IP \(attachmentMode == .attach ? "assignment" : "unassignment")"
            return
        }
        guard let selectedFloatingIP = selectedResource as? FloatingIP else {
            statusMessage = "No floating IP selected for \(attachmentMode == .attach ? "assignment" : "unassignment")"
            return
        }
        guard let selectedServer = cachedServers.first(where: { $0.id == selectedId }) else {
            statusMessage = "Selected server not found"
            return
        }

        let floatingIPAddress = selectedFloatingIP.floatingIpAddress ?? "Unknown"
        let serverName = selectedServer.name ?? "Unknown"
        let action = attachmentMode == .attach ? "assigning" : "unassigning"
        statusMessage = "\(action.capitalized) floating IP '\(floatingIPAddress)' \(attachmentMode == .attach ? "to" : "from") server '\(serverName)'..."

        // Force immediate UI update to show status message
        tui.forceRedraw()

        do {
            if attachmentMode == .attach {
                // Find the first port for this server to attach the floating IP
                guard let targetPort = cachedPorts.first(where: { $0.deviceId == selectedServer.id }) else {
                    statusMessage = "No ports found for server '\(serverName)'"
                    tui.forceRedraw()
                    return
                }
                _ = try await client.updateFloatingIP(id: selectedFloatingIP.id, portID: targetPort.id)
                statusMessage = "Successfully assigned floating IP '\(floatingIPAddress)' to server '\(serverName)'"
            } else {
                _ = try await client.updateFloatingIP(id: selectedFloatingIP.id, portID: nil)
                statusMessage = "Successfully unassigned floating IP '\(floatingIPAddress)' from server '\(serverName)'"
            }

            selectedServerId = nil
            tui.changeView(to: .floatingIPs, resetSelection: false)
            tui.refreshAfterOperation()
        } catch {
            statusMessage = "Failed to \(attachmentMode == .attach ? "assign" : "unassign") floating IP: \(error.localizedDescription)"
            tui.forceRedraw()
            Logger.shared.logError("Failed to \(attachmentMode == .attach ? "assign" : "unassign") floating IP", error: error, context: [
                "serverId": selectedId,
                "serverName": serverName,
                "floatingIPId": selectedFloatingIP.id,
                "floatingIPAddress": floatingIPAddress
            ])
        }
    }

    internal func showConsoleDialog(console: RemoteConsole, serverName: String, screen: OpaquePointer?) async {
        // Disable nodelay for dialog interaction
        let _ = SwiftTUI.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftTUI.setNodelay(WindowHandle(screen), true)
        }

        // Calculate main panel dimensions (matching MainPanelView layout)
        let sidebarWidth: Int32 = 20
        let mainStartCol: Int32 = sidebarWidth > 0 ? sidebarWidth + 1 : 0
        let mainWidth = max(10, screenCols - mainStartCol - 1)
        let mainStartRow: Int32 = 2
        let bottomReserved: Int32 = 3
        let mainHeight = max(5, screenRows - mainStartRow - bottomReserved)

        while true {
            // Draw the full UI to maintain context
            await tui.draw(screen: screen)

            // Draw console information in main panel area
            var row: Int32 = mainStartRow

            let title = "Server Console: \(serverName)"
            SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: title, color: .accent)
            row += 2

            SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: "Protocol: \(console.protocol)", color: .info)
            row += 1

            SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: "Type: \(console.type)", color: .info)
            row += 2

            SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: "Console URL:", color: .accent)
            row += 1

            // Word wrap the URL to fit in main panel
            let url = console.url
            let contentWidth = Int(mainWidth - 2)
            let urlLines = wrapText(url, maxWidth: contentWidth)
            for line in urlLines {
                if row < mainStartRow + mainHeight - 3 {
                    SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: line, color: .success)
                    row += 1
                }
            }

            // Draw help text at bottom of main panel
            row = mainStartRow + mainHeight - 2
            let helpText: String
            if console.type.lowercased() == "novnc" {
                helpText = "Press O to open in browser, ESC to close"
            } else {
                helpText = "Press ESC to close"
            }
            SwiftTUI.drawStyledText(WindowHandle(screen), at: Position(row: row, col: mainStartCol), text: helpText, color: .warning)

            SwiftTUI.batchedRefresh(WindowHandle(screen))

            let ch = SwiftTUI.getInput(WindowHandle(screen))

            switch ch {
            case Int32(27): // ESC - Close dialog
                return
            case Int32(79), Int32(111): // 'O' or 'o' - Open in browser
                if console.type.lowercased() == "novnc" {
                    await openURLInBrowser(console.url)
                    tui.statusMessage = "Opening console in default browser..."
                }
            default:
                break
            }
        }
    }

    private func wrapText(_ text: String, maxWidth: Int) -> [String] {
        var lines: [String] = []
        var currentLine = ""

        for char in text {
            if currentLine.count >= maxWidth {
                lines.append(currentLine)
                currentLine = String(char)
            } else {
                currentLine.append(char)
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }

    private func openURLInBrowser(_ url: String) async {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
        #elseif os(Linux)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        process.arguments = [url]
        try? process.run()
        #endif
    }

    internal func performSubnetRouterManagement() async {
        guard let selectedId = selectedRouterId else {
            statusMessage = "No router selected for subnet \(attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }
        guard let selectedSubnet = selectedResource as? Subnet else {
            statusMessage = "No subnet selected for \(attachmentMode == .attach ? "attachment" : "detachment")"
            return
        }
        guard let selectedRouter = cachedRouters.first(where: { $0.id == selectedId }) else {
            statusMessage = "Selected router not found"
            return
        }

        let routerName = selectedRouter.name ?? "Unknown"
        let subnetName = selectedSubnet.name ?? "Unknown"
        let action = attachmentMode == .attach ? "attaching" : "detaching"
        statusMessage = "\(action.capitalized) router '\(routerName)' \(attachmentMode == .attach ? "to" : "from") subnet '\(subnetName)'..."

        // Force immediate UI update to show status message
        tui.forceRedraw()

        do {
            // Validate before attempting operation
            let isCurrentlyAttached = tui.attachedRouterIds.contains(selectedRouter.id)

            if attachmentMode == .attach {
                if isCurrentlyAttached {
                    statusMessage = "Router '\(routerName)' is already attached to subnet '\(subnetName)'"
                    return
                }

                // Validate subnet and router compatibility
                if let network = cachedNetworks.first(where: { $0.id == selectedSubnet.networkId }) {
                    // Check if router is already on the same network via external gateway
                    if let routerNetwork = selectedRouter.externalGatewayInfo?.networkId, routerNetwork == network.id {
                        // This is acceptable - router can have both external gateway and internal interfaces on same network
                    }
                }

                // Add router interface
                _ = try await client.neutron.addRouterInterface(routerId: selectedRouter.id, subnetId: selectedSubnet.id)
                statusMessage = "Successfully attached router '\(routerName)' to subnet '\(subnetName)'"
            } else {
                if !isCurrentlyAttached {
                    statusMessage = "Router '\(routerName)' is not attached to subnet '\(subnetName)'"
                    return
                }

                // Remove router interface
                _ = try await client.neutron.removeRouterInterface(routerId: selectedRouter.id, subnetId: selectedSubnet.id)
                statusMessage = "Successfully detached router '\(routerName)' from subnet '\(subnetName)'"
            }

            selectedRouterId = nil
            tui.changeView(to: .subnets, resetSelection: false)
            tui.refreshAfterOperation()
        } catch {
            let errorMsg = error.localizedDescription
            let specificError = if errorMsg.contains("400") {
                "Bad Request: \(errorMsg)"
            } else if errorMsg.contains("404") {
                "Not Found: Router or subnet not found"
            } else if errorMsg.contains("409") {
                "Conflict: \(errorMsg)"
            } else {
                errorMsg
            }

            statusMessage = "Failed to \(attachmentMode == .attach ? "attach" : "detach") router: \(specificError)"
            Logger.shared.logError("Failed to \(attachmentMode == .attach ? "attach" : "detach") router", error: error, context: [
                "routerId": selectedRouter.id,
                "routerName": routerName,
                "subnetId": selectedSubnet.id,
                "subnetName": subnetName,
                "subnetNetworkId": selectedSubnet.networkId,
                "routerExternalGateway": selectedRouter.externalGatewayInfo?.networkId ?? "none",
                "currentlyAttached": tui.attachedRouterIds.contains(selectedRouter.id)
            ])
        }
    }

}
