import Foundation
import struct OSClient.Port
import OSClient
import SwiftTUI

struct AllowedAddressPairManagementView {

    // MARK: - Layout Constants

    private static let minScreenWidth: Int32 = 10
    private static let minScreenHeight: Int32 = 10
    private static let clearOffsetY: Int32 = 1
    private static let componentSpacing: Int32 = 0
    private static let reservedSpace: Int32 = 12

    // MARK: - Text Constants

    private static let title = "Add Allowed Address Pair to Ports"
    private static let sourcePortPrefix = "Source Port: "
    private static let screenTooSmallText = "Screen too small"
    private static let noAvailablePortsText = "No other ports available to add this allowed address pair to."
    private static let helpTextSelectPorts = "SPACE: Toggle ([*]=already has [X]=will add [-]=will remove) | ENTER: Apply | ESC: Back"

    // MARK: - Edge Insets

    private static let portInfoEdgeInsets = EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)
    private static let warningEdgeInsets = EdgeInsets(top: 0, leading: 2, bottom: 1, trailing: 0)
    private static let emptyStateEdgeInsets = EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)
    private static let helpTextEdgeInsets = EdgeInsets(top: 1, leading: 2, bottom: 0, trailing: 0)

    // MARK: - Main Draw Function

    @MainActor
    static func drawAllowedAddressPairManagement(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: AllowedAddressPairManagementForm,
        resourceNameCache: ResourceNameCache
    ) async {

        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking
        guard width > minScreenWidth && height > minScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text(screenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Clear area
        await BaseViewComponents.clearArea(screen: screen, startRow: startRow - clearOffsetY, startCol: startCol,
                                         width: width, height: height)

        var components: [any Component] = []

        // Title
        components.append(Text(title).emphasis().bold())

        // Source port information
        let sourcePortName = form.getSourcePortDisplayName()
        let sourcePortIP = form.getSourcePortIPAddress()
        let portText = sourcePortPrefix + "\(sourcePortName) (\(sourcePortIP))"
        components.append(Text(portText).primary().padding(portInfoEdgeInsets))

        // Render port selection view
        await renderPortSelector(
            surface: surface,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            form: form,
            resourceNameCache: resourceNameCache,
            components: &components
        )
    }

    // MARK: - Port Selector View

    @MainActor
    private static func renderPortSelector(
        surface: some Surface,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: AllowedAddressPairManagementForm,
        resourceNameCache: ResourceNameCache,
        components: inout [any Component]
    ) async {

        if form.availablePorts.isEmpty {
            // No ports available
            components.append(Text(noAvailablePortsText).info().padding(emptyStateEdgeInsets))
            components.append(Text(helpTextSelectPorts).info().padding(helpTextEdgeInsets))
            let emptyComponent = VStack(spacing: componentSpacing, children: components)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftTUI.render(emptyComponent, on: surface, in: bounds)
        } else {
            let contentHeight = height - reservedSpace

            // Clamp highlighted index
            let safeHighlightedIndex = min(max(0, form.highlightedPortIndex), max(0, form.availablePorts.count - 1))

            let portSelector = FormSelector<Port>(
                label: "Select Target Ports to Receive Source Port as Allowed Address Pair",
                tabs: [
                    FormSelectorTab<Port>(
                        title: "TARGET PORTS",
                        columns: [
                            FormSelectorColumn(header: "Port Name/ID", width: 24) { port in
                                String((port.name ?? port.id).prefix(24))
                            },
                            FormSelectorColumn(header: "IP Address", width: 16) { port in
                                port.fixedIps?.first?.ipAddress ?? "N/A"
                            },
                            FormSelectorColumn(header: "Server", width: 24) { port in
                                if let deviceId = port.deviceId, !deviceId.isEmpty {
                                    if let serverName = resourceNameCache.getServerName(deviceId) {
                                        return String(serverName.prefix(24))
                                    }
                                    return String(deviceId.prefix(24))
                                }
                                return "(unattached)"
                            },
                            FormSelectorColumn(header: "Network", width: 24) { port in
                                if let networkName = resourceNameCache.getNetworkName(port.networkId) {
                                    return String(networkName.prefix(24))
                                }
                                return String(port.networkId.prefix(24))
                            }
                        ],
                        description: "Select ports that will receive the source port's IP/MAC as an allowed address pair"
                    )
                ],
                selectedTabIndex: 0,
                items: form.availablePorts,
                selectedItemIds: [],
                highlightedIndex: safeHighlightedIndex,
                checkboxMode: .multiFunctional,
                scrollOffset: form.scrollOffsetPorts,
                searchQuery: nil,
                maxWidth: Int(width) - 4,
                maxHeight: Int(contentHeight),
                isActive: true,
                statusProvider: { port in
                    switch form.getPortSelectionStatus(port.id) {
                    case .available:
                        return "[ ]"
                    case .currentlyUsed:
                        return "[*]"
                    case .pendingAddition:
                        return "[X]"
                    case .pendingRemoval:
                        return "[-]"
                    }
                }
            )

            components.append(portSelector.render())

            components.append(Text(helpTextSelectPorts).info().padding(helpTextEdgeInsets))

            // Show pending changes count
            if form.hasPendingChanges() {
                var statusParts: [String] = []
                if form.getPendingAdditionsCount() > 0 {
                    statusParts.append("+\(form.getPendingAdditionsCount()) to add")
                }
                if form.getPendingRemovalsCount() > 0 {
                    statusParts.append("-\(form.getPendingRemovalsCount()) to remove")
                }
                let statusText = "Pending: " + statusParts.joined(separator: ", ")
                components.append(Text(statusText).accent().padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
            }

            let selectorComponent = VStack(spacing: componentSpacing, children: components)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            await SwiftTUI.render(selectorComponent, on: surface, in: bounds)
        }
    }
}
