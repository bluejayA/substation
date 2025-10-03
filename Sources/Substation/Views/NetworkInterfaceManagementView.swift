import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

struct NetworkInterfaceManagementView {

    // MARK: - Network Interface Management View

    @MainActor
    static func drawDetailedNetworkInterfaceManagement(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                                      width: Int32, height: Int32, form: NetworkInterfaceManagementForm,
                                                      resourceNameCache: ResourceNameCache, resourceResolver: ResourceResolver) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.networkInterfaceManagementMinScreenWidth && height > Self.networkInterfaceManagementMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.networkInterfaceManagementBoundsMinWidth, width), height: max(Self.networkInterfaceManagementBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.networkInterfaceManagementScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Clear area for optimal rendering
        await BaseViewComponents.clearArea(screen: screen, startRow: startRow - Self.networkInterfaceManagementClearOffsetY, startCol: startCol,
                                         width: width, height: height)

        // Server validation with gold standard error handling
        guard form.selectedServer != nil else {
            let errorBounds = Rect(x: startCol + Self.networkInterfaceManagementErrorColOffset, y: startRow + Self.networkInterfaceManagementErrorRowOffset, width: Self.networkInterfaceManagementErrorWidth, height: Self.networkInterfaceManagementErrorHeight)
            await SwiftTUI.render(Text(Self.networkInterfaceManagementNoServerSelectedText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Network Interface Management View
        var components: [any Component] = []

        // Title with server context
        let titleText = Self.networkInterfaceManagementTitle
        components.append(Text(titleText).emphasis().bold())

        // Server information display
        if let server = form.selectedServer {
            let serverText = Self.networkInterfaceManagementServerPrefix + (server.name ?? Self.networkInterfaceManagementUnknownServerText)
            components.append(Text(serverText).primary()
                .padding(Self.networkInterfaceManagementServerInfoEdgeInsets))
        }

        // Error handling with optimized display
        if let errorMessage = form.errorMessage {
            let errorText = Self.networkInterfaceManagementErrorPrefix + errorMessage
            components.append(Text(errorText).error()
                .padding(Self.networkInterfaceManagementErrorMessageEdgeInsets))
            let errorComponent = VStack(spacing: Self.networkInterfaceManagementComponentSpacing, children: components)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: Self.networkInterfaceManagementErrorComponentHeight)
            await SwiftTUI.render(errorComponent, on: surface, in: bounds)
            return
        }

        // Loading state with optimized display
        if form.isLoading {
            components.append(Text(Self.networkInterfaceManagementLoadingText).info()
                .padding(Self.networkInterfaceManagementLoadingEdgeInsets))
            let loadingComponent = VStack(spacing: Self.networkInterfaceManagementComponentSpacing, children: components)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: Self.networkInterfaceManagementLoadingComponentHeight)
            await SwiftTUI.render(loadingComponent, on: surface, in: bounds)
            return
        }

        // Get management items and calculate content dimensions
        let managementItems = form.getManagementItems(for: form.currentViewMode)
        let contentHeight = height - Self.networkInterfaceManagementReservedSpace

        // Empty state handling
        if managementItems.isEmpty {
            let emptyText = form.currentViewMode == .ports ? Self.networkInterfaceManagementNoPortsText : Self.networkInterfaceManagementNoNetworksText
            components.append(Text(emptyText).info()
                .padding(Self.networkInterfaceManagementEmptyStateEdgeInsets))
            let emptyComponent = VStack(spacing: Self.networkInterfaceManagementComponentSpacing, children: components)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftTUI.render(emptyComponent, on: surface, in: bounds)
            return
        }

        // Mode selection display with optimized string concatenation
        let modeText = HStack(spacing: 1, children: [
            Text(Self.networkInterfaceManagementModePrefix).info().bold(),
            Text(form.currentViewMode == .ports ? "[Ports]" : "Ports").primary().bold(),
            Text("/").info(),
            Text(form.currentViewMode == .networks ? "[Networks]" : "Networks").primary().bold()
        ])
        components.append(modeText.padding(Self.networkInterfaceManagementModeSelectionEdgeInsets))


        // Render management items with optimized viewport
        let maxItemsToShow = min(Int(contentHeight) - Self.networkInterfaceManagementContentOffset, managementItems.count)
        let startIndex = max(0, min(form.selectedResourceIndex - maxItemsToShow + Self.networkInterfaceManagementViewportOffset, managementItems.count - maxItemsToShow))

        for i in 0..<maxItemsToShow {
            let itemIndex = startIndex + i
            if itemIndex >= managementItems.count { break }

            let item = managementItems[itemIndex]
            let isSelected = itemIndex == form.selectedResourceIndex
            let itemComponent = Self.createNetworkInterfaceManagementItemComponent(item: item, isSelected: isSelected, form: form, resourceNameCache: resourceNameCache)
            components.append(itemComponent)
        }

        // Pending changes summary with optimized string building
        if form.hasPendingChanges() {
            let changesComponent = Self.createPendingChangesComponent(form: form)
            components.append(changesComponent)
        }

        // Render unified network interface management view
        let managementComponent = VStack(spacing: Self.networkInterfaceManagementComponentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(managementComponent, on: surface, in: bounds)
    }

    // MARK: - Component Creation Functions

    @MainActor
    private static func createNetworkInterfaceManagementItemComponent(item: Any, isSelected: Bool, form: NetworkInterfaceManagementForm, resourceNameCache: ResourceNameCache) -> any Component {
        if let port = item as? Port {
            return createPortManagementItemComponent(port: port, isSelected: isSelected, form: form, resourceNameCache: resourceNameCache)
        } else if let network = item as? Network {
            return createNetworkManagementItemComponent(network: network, isSelected: isSelected, form: form)
        } else {
            // Fallback component for unknown item types
            let itemStyle: TextStyle = isSelected ? .accent : .secondary
            return Text(Self.networkInterfaceManagementUnknownItemText).styled(itemStyle)
                .padding(Self.networkInterfaceManagementItemEdgeInsets)
        }
    }

    @MainActor
    private static func createPortManagementItemComponent(port: Port, isSelected: Bool, form: NetworkInterfaceManagementForm, resourceNameCache: ResourceNameCache) -> any Component {
        // Pre-calculate port attachment status for performance
        let isAttached = form.isPortCurrentlyAttached(port.id)
        let isPendingAdd = form.pendingPortAttachments.contains(port.id)
        let isPendingRemove = form.pendingPortDetachments.contains(port.id)

        // Status indicator with pre-calculated values
        let statusIndicator: String
        if isPendingAdd {
            statusIndicator = Self.networkInterfaceManagementPendingAddIndicator
        } else if isPendingRemove {
            statusIndicator = Self.networkInterfaceManagementPendingRemoveIndicator
        } else if isAttached {
            statusIndicator = Self.networkInterfaceManagementAttachedIndicator
        } else {
            statusIndicator = Self.networkInterfaceManagementAvailableIndicator
        }

        // Port name with standardized fallback
        let portName = port.name ?? (Self.networkInterfaceManagementPortPrefix + String(port.id.prefix(Self.networkInterfaceManagementPortIdTruncateLength)))
        let portID = String(port.id.prefix(Self.networkInterfaceManagementPortIdDisplayLength))

        // Network name resolution with optimized fallback chain
        let networkName: String
        if let cachedName = resourceNameCache.getNetworkName(port.networkId), !cachedName.isEmpty {
            networkName = cachedName
        } else if let network = form.availableNetworks.first(where: { $0.id == port.networkId }) {
            networkName = network.name ?? "Unknown Network"
        } else {
            networkName = Self.networkInterfaceManagementNetworkPrefix + String(port.networkId.prefix(Self.networkInterfaceManagementNetworkIdTruncateLength))
        }

        // IP address with standardized fallback
        let ipAddress = port.fixedIps?.first?.ipAddress ?? Self.networkInterfaceManagementNoIPText

        // Optimized string concatenation for port information
        let portInfo = portName + Self.networkInterfaceManagementPortInfoSeparator +
                       Self.networkInterfaceManagementIdLabel + portID + Self.networkInterfaceManagementPortInfoSeparator +
                       Self.networkInterfaceManagementNetworkLabel + networkName + Self.networkInterfaceManagementPortInfoSeparator +
                       Self.networkInterfaceManagementIPLabel + ipAddress

        let displayName = String(portInfo.prefix(Self.networkInterfaceManagementDisplayNameMaxLength))

        // Pre-calculate spaced text for optimal performance
        let spacedStatusIndicator = statusIndicator + Self.networkInterfaceManagementItemTextSpacing
        let finalDisplayText = spacedStatusIndicator + displayName

        let itemStyle: TextStyle = isSelected ? .accent : .secondary
        return Text(finalDisplayText).styled(itemStyle)
            .padding(Self.networkInterfaceManagementItemEdgeInsets)
    }

    @MainActor
    private static func createNetworkManagementItemComponent(network: Network, isSelected: Bool, form: NetworkInterfaceManagementForm) -> any Component {
        // Pre-calculate network attachment status for performance
        let isAttached = form.isNetworkCurrentlyAttached(network.id)
        let isPendingAdd = form.pendingNetworkAttachments.contains(network.id)
        let isPendingRemove = form.pendingNetworkDetachments.contains(network.id)

        // Status indicator with pre-calculated values
        let statusIndicator: String
        if isPendingAdd {
            statusIndicator = Self.networkInterfaceManagementPendingAddIndicator
        } else if isPendingRemove {
            statusIndicator = Self.networkInterfaceManagementPendingRemoveIndicator
        } else if isAttached {
            statusIndicator = Self.networkInterfaceManagementAttachedIndicator
        } else {
            statusIndicator = Self.networkInterfaceManagementAvailableIndicator
        }

        // Pre-calculate spaced text for optimal performance
        let spacedStatusIndicator = statusIndicator + Self.networkInterfaceManagementItemTextSpacing
        let finalDisplayText = spacedStatusIndicator + (network.name ?? "Unknown Network")

        let itemStyle: TextStyle = isSelected ? .accent : .secondary
        return Text(finalDisplayText).styled(itemStyle)
            .padding(Self.networkInterfaceManagementItemEdgeInsets)
    }

    @MainActor
    private static func createPendingChangesComponent(form: NetworkInterfaceManagementForm) -> any Component {
        // Pre-calculate change counts for performance
        let totalPortAttachments = form.pendingPortAttachments.count
        let totalPortDetachments = form.pendingPortDetachments.count
        let totalNetworkAttachments = form.pendingNetworkAttachments.count
        let totalNetworkDetachments = form.pendingNetworkDetachments.count

        // Optimized string building for pending changes
        var changeText = Self.networkInterfaceManagementPendingPrefix

        // Port changes with optimized concatenation
        let totalPortChanges = totalPortAttachments + totalPortDetachments
        if totalPortChanges > 0 {
            changeText += Self.networkInterfaceManagementPortsLabel + Self.networkInterfaceManagementAddPrefix + String(totalPortAttachments)
            if totalPortDetachments > 0 {
                changeText += Self.networkInterfaceManagementRemovePrefix + String(totalPortDetachments)
            }
            changeText += Self.networkInterfaceManagementChangeSeparator
        }

        // Network changes with optimized concatenation
        let totalNetworkChanges = totalNetworkAttachments + totalNetworkDetachments
        if totalNetworkChanges > 0 {
            changeText += Self.networkInterfaceManagementNetworksLabel + Self.networkInterfaceManagementAddPrefix + String(totalNetworkAttachments)
            if totalNetworkDetachments > 0 {
                changeText += Self.networkInterfaceManagementRemovePrefix + String(totalNetworkDetachments)
            }
            changeText += Self.networkInterfaceManagementChangeSeparator
        }

        changeText += Self.networkInterfaceManagementChangesSuffix

        return Text(changeText).warning()
            .padding(Self.networkInterfaceManagementPendingChangesEdgeInsets)
    }

    // MARK: - Legacy Compatibility Methods

    @MainActor
    static func draw(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                    width: Int32, height: Int32, form: NetworkInterfaceManagementForm,
                    resourceNameCache: ResourceNameCache, resourceResolver: ResourceResolver) async {
        await drawDetailedNetworkInterfaceManagement(screen: screen, startRow: startRow, startCol: startCol,
                                                   width: width, height: height, form: form,
                                                   resourceNameCache: resourceNameCache, resourceResolver: resourceResolver)
    }

    @MainActor
    static func drawServerNetworkInterfaceManagement(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                                   width: Int32, height: Int32, form: NetworkInterfaceManagementForm,
                                                   resourceNameCache: ResourceNameCache, resourceResolver: ResourceResolver) async {
        await drawDetailedNetworkInterfaceManagement(screen: screen, startRow: startRow, startCol: startCol,
                                                   width: width, height: height, form: form,
                                                   resourceNameCache: resourceNameCache, resourceResolver: resourceResolver)
    }

    // MARK: - Network Interface Management View Constants

    // Layout Constants
    private static let networkInterfaceManagementMinScreenWidth: Int32 = 10
    private static let networkInterfaceManagementMinScreenHeight: Int32 = 10
    private static let networkInterfaceManagementBoundsMinWidth: Int32 = 1
    private static let networkInterfaceManagementBoundsMinHeight: Int32 = 1
    private static let networkInterfaceManagementClearOffsetY: Int32 = 1
    private static let networkInterfaceManagementErrorColOffset: Int32 = 2
    private static let networkInterfaceManagementErrorRowOffset: Int32 = 2
    private static let networkInterfaceManagementErrorWidth: Int32 = 30
    private static let networkInterfaceManagementErrorHeight: Int32 = 1
    private static let networkInterfaceManagementReservedSpace: Int32 = 8
    private static let networkInterfaceManagementContentOffset = 2
    private static let networkInterfaceManagementViewportOffset = 1
    private static let networkInterfaceManagementComponentSpacing: Int32 = 0
    private static let networkInterfaceManagementErrorComponentHeight: Int32 = 6
    private static let networkInterfaceManagementLoadingComponentHeight: Int32 = 6

    // Padding Constants
    private static let networkInterfaceManagementServerInfoTopPadding: Int32 = 2
    private static let networkInterfaceManagementServerInfoLeadingPadding: Int32 = 0
    private static let networkInterfaceManagementServerInfoBottomPadding: Int32 = 0
    private static let networkInterfaceManagementServerInfoTrailingPadding: Int32 = 0
    private static let networkInterfaceManagementErrorMessageTopPadding: Int32 = 2
    private static let networkInterfaceManagementErrorMessageLeadingPadding: Int32 = 2
    private static let networkInterfaceManagementErrorMessageBottomPadding: Int32 = 0
    private static let networkInterfaceManagementErrorMessageTrailingPadding: Int32 = 0
    private static let networkInterfaceManagementLoadingTopPadding: Int32 = 2
    private static let networkInterfaceManagementLoadingLeadingPadding: Int32 = 2
    private static let networkInterfaceManagementLoadingBottomPadding: Int32 = 0
    private static let networkInterfaceManagementLoadingTrailingPadding: Int32 = 0
    private static let networkInterfaceManagementEmptyStateTopPadding: Int32 = 2
    private static let networkInterfaceManagementEmptyStateLeadingPadding: Int32 = 2
    private static let networkInterfaceManagementEmptyStateBottomPadding: Int32 = 0
    private static let networkInterfaceManagementEmptyStateTrailingPadding: Int32 = 0
    private static let networkInterfaceManagementModeSelectionTopPadding: Int32 = 2
    private static let networkInterfaceManagementModeSelectionLeadingPadding: Int32 = 0
    private static let networkInterfaceManagementModeSelectionBottomPadding: Int32 = 0
    private static let networkInterfaceManagementModeSelectionTrailingPadding: Int32 = 0
    private static let networkInterfaceManagementItemTopPadding: Int32 = 0
    private static let networkInterfaceManagementItemLeadingPadding: Int32 = 2
    private static let networkInterfaceManagementItemBottomPadding: Int32 = 0
    private static let networkInterfaceManagementItemTrailingPadding: Int32 = 0
    private static let networkInterfaceManagementPendingChangesTopPadding: Int32 = 1
    private static let networkInterfaceManagementPendingChangesLeadingPadding: Int32 = 0
    private static let networkInterfaceManagementPendingChangesBottomPadding: Int32 = 0
    private static let networkInterfaceManagementPendingChangesTrailingPadding: Int32 = 0

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let networkInterfaceManagementServerInfoEdgeInsets = EdgeInsets(top: networkInterfaceManagementServerInfoTopPadding, leading: networkInterfaceManagementServerInfoLeadingPadding, bottom: networkInterfaceManagementServerInfoBottomPadding, trailing: networkInterfaceManagementServerInfoTrailingPadding)
    private static let networkInterfaceManagementErrorMessageEdgeInsets = EdgeInsets(top: networkInterfaceManagementErrorMessageTopPadding, leading: networkInterfaceManagementErrorMessageLeadingPadding, bottom: networkInterfaceManagementErrorMessageBottomPadding, trailing: networkInterfaceManagementErrorMessageTrailingPadding)
    private static let networkInterfaceManagementLoadingEdgeInsets = EdgeInsets(top: networkInterfaceManagementLoadingTopPadding, leading: networkInterfaceManagementLoadingLeadingPadding, bottom: networkInterfaceManagementLoadingBottomPadding, trailing: networkInterfaceManagementLoadingTrailingPadding)
    private static let networkInterfaceManagementEmptyStateEdgeInsets = EdgeInsets(top: networkInterfaceManagementEmptyStateTopPadding, leading: networkInterfaceManagementEmptyStateLeadingPadding, bottom: networkInterfaceManagementEmptyStateBottomPadding, trailing: networkInterfaceManagementEmptyStateTrailingPadding)
    private static let networkInterfaceManagementModeSelectionEdgeInsets = EdgeInsets(top: networkInterfaceManagementModeSelectionTopPadding, leading: networkInterfaceManagementModeSelectionLeadingPadding, bottom: networkInterfaceManagementModeSelectionBottomPadding, trailing: networkInterfaceManagementModeSelectionTrailingPadding)
    private static let networkInterfaceManagementItemEdgeInsets = EdgeInsets(top: networkInterfaceManagementItemTopPadding, leading: networkInterfaceManagementItemLeadingPadding, bottom: networkInterfaceManagementItemBottomPadding, trailing: networkInterfaceManagementItemTrailingPadding)
    private static let networkInterfaceManagementPendingChangesEdgeInsets = EdgeInsets(top: networkInterfaceManagementPendingChangesTopPadding, leading: networkInterfaceManagementPendingChangesLeadingPadding, bottom: networkInterfaceManagementPendingChangesBottomPadding, trailing: networkInterfaceManagementPendingChangesTrailingPadding)

    // Text Constants
    private static let networkInterfaceManagementTitle = "Manage Network Interfaces"
    private static let networkInterfaceManagementScreenTooSmallText = "Screen too small"
    private static let networkInterfaceManagementNoServerSelectedText = "Error: No server selected"
    private static let networkInterfaceManagementServerPrefix = "Server: "
    private static let networkInterfaceManagementUnknownServerText = "Unknown"
    private static let networkInterfaceManagementErrorPrefix = "Error: "
    private static let networkInterfaceManagementLoadingText = "Loading network interfaces..."
    private static let networkInterfaceManagementNoPortsText = "No ports available for management"
    private static let networkInterfaceManagementNoNetworksText = "No networks available for management"
    private static let networkInterfaceManagementModePrefix = "Mode: "

    // Status Indicator Constants
    private static let networkInterfaceManagementPendingAddIndicator = "[+]"
    private static let networkInterfaceManagementPendingRemoveIndicator = "[-]"
    private static let networkInterfaceManagementAttachedIndicator = "[*]"
    private static let networkInterfaceManagementAvailableIndicator = "[ ]"

    // Port Information Constants
    private static let networkInterfaceManagementPortPrefix = "Port-"
    private static let networkInterfaceManagementNetworkPrefix = "Net-"
    private static let networkInterfaceManagementPortIdTruncateLength = 8
    private static let networkInterfaceManagementPortIdDisplayLength = 8
    private static let networkInterfaceManagementNetworkIdTruncateLength = 8
    private static let networkInterfaceManagementNoIPText = "No IP"
    private static let networkInterfaceManagementPortInfoSeparator = " | "
    private static let networkInterfaceManagementIdLabel = "ID: "
    private static let networkInterfaceManagementNetworkLabel = "Net: "
    private static let networkInterfaceManagementIPLabel = "IP: "
    private static let networkInterfaceManagementDisplayNameMaxLength = 90
    private static let networkInterfaceManagementItemTextSpacing = " "
    private static let networkInterfaceManagementUnknownItemText = "Unknown item type"

    // Pending Changes Constants
    private static let networkInterfaceManagementPendingPrefix = "Pending: "
    private static let networkInterfaceManagementPortsLabel = "Ports: "
    private static let networkInterfaceManagementNetworksLabel = "Networks: "
    private static let networkInterfaceManagementAddPrefix = "+"
    private static let networkInterfaceManagementRemovePrefix = " -"
    private static let networkInterfaceManagementChangeSeparator = " "
    private static let networkInterfaceManagementChangesSuffix = "changes"
}