import Foundation
import OSClient
import SwiftTUI

struct NetworkViews {
    @MainActor
    static func drawDetailedNetworkList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                      width: Int32, height: Int32, cachedNetworks: [Network],
                                      searchQuery: String?, scrollOffset: Int, selectedIndex: Int,
                                       dataManager: DataManager? = nil,
                                      virtualScrollManager: VirtualScrollManager<Network>? = nil) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Main Network List
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        let titleText = searchQuery.map { "Networks (filtered: \($0))" } ?? "Networks"
        components.append(Text(titleText).emphasis().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        // Header
        components.append(Text(" ST  NAME                         STATUS      SHARED  EXTERNAL").muted()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)).border())

        // Content - enhanced with pagination and virtual scrolling support
        await renderNetworkList(
            components: &components,
            cachedNetworks: cachedNetworks,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex,
            height: height,
            dataManager: dataManager,
            virtualScrollManager: virtualScrollManager
        )

        // Render unified network list
        let networkListComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(networkListComponent, on: surface, in: bounds)
    }

    // MARK: - Component Creation Functions

    private static func createNetworkListItemComponent(network: Network, isSelected: Bool) -> any Component {
        // Network name with formatting (29 chars to match header)
        let networkName = String((network.name ?? "Unnamed").prefix(29)).padding(toLength: 29, withPad: " ", startingAt: 0)

        // Enhanced status with color coding (11 chars to match header)
        let status = network.status ?? "Unknown"
        let statusStyle: TextStyle = {
            switch status.lowercased() {
            case "active": return .success
            case "down": return .error
            case "build", "building": return .warning
            default: return .info
            }
        }()
        let statusText = String(status.prefix(11)).padding(toLength: 11, withPad: " ", startingAt: 0)

        // Shared and External flags (7 chars each to match header)
        let sharedDisplay = network.shared.map { $0 ? "Yes" : "No" } ?? "Unknown"
        let sharedText = String(sharedDisplay.prefix(7)).padding(toLength: 7, withPad: " ", startingAt: 0)

        let externalDisplay = network.external.map { $0 ? "Yes" : "No" } ?? "Unknown"
        let externalText = String(externalDisplay.prefix(8)).padding(toLength: 8, withPad: " ", startingAt: 0)

        let rowStyle: TextStyle = isSelected ? .accent : .secondary

        // Status icon for networks
        let networkStatus = network.external == true ? "external" : (network.shared == true ? "shared" : "private")

        return HStack(spacing: 0, children: [
            StatusIcon(status: networkStatus),
            Text(" \(networkName)").styled(rowStyle),
            Text(" \(statusText)").styled(statusStyle),
            Text(" \(sharedText)").styled(rowStyle),
            Text(" \(externalText)").styled(rowStyle)
        ]).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
    }

    // MARK: - Enhanced Rendering with Pagination Support

    @MainActor
    private static func renderNetworkList(
        components: inout [any Component],
        cachedNetworks: [Network],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        height: Int32,
        
        dataManager: DataManager?,
        virtualScrollManager: VirtualScrollManager<Network>?
    ) async {
        // Determine which rendering approach to use based on available systems
        if let virtualScrollManager = virtualScrollManager {
            await renderWithVirtualScrolling(
                components: &components,
                virtualScrollManager: virtualScrollManager,
                selectedIndex: selectedIndex,
                height: height
            )
        } else if let dataManager = dataManager, dataManager.isPaginationEnabled(for: "networks") {
            await renderWithPagination(
                components: &components,
                dataManager: dataManager,
                selectedIndex: selectedIndex,
                height: height
            )
        } else {
            // Fallback to traditional rendering
            await renderTraditional(
                components: &components,
                cachedNetworks: cachedNetworks,
                searchQuery: searchQuery,
                scrollOffset: scrollOffset,
                selectedIndex: selectedIndex,
                height: height
            )
        }
    }

    @MainActor
    private static func renderWithVirtualScrolling(
        components: inout [any Component],
        virtualScrollManager: VirtualScrollManager<Network>,
        selectedIndex: Int,
        height: Int32
    ) async {
        let maxVisibleItems = max(1, Int(height) - 10)
        let renderableItems = virtualScrollManager.getRenderableItems(
            startRow: 5, // Network list start row
            endRow: 5 + Int32(maxVisibleItems)
        )

        if renderableItems.isEmpty {
            components.append(Text("No networks found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            for (network, _, index) in renderableItems {
                let isSelected = index == selectedIndex
                let networkComponent = createNetworkListItemComponent(
                    network: network,
                    isSelected: isSelected
                )
                components.append(networkComponent)
            }

            // Virtual scrolling status
            let scrollInfo = virtualScrollManager.getScrollInfo()
            components.append(Text("Virtual: \(scrollInfo)").info()
                .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
        }
    }

    @MainActor
    private static func renderWithPagination(
        components: inout [any Component],
        dataManager: DataManager,
        selectedIndex: Int,
        height: Int32
    ) async {
        let paginatedNetworks: [Network] = await dataManager.getPaginatedItems(for: "networks", type: Network.self)

        if paginatedNetworks.isEmpty {
            components.append(Text("No networks found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            let maxVisibleItems = max(1, Int(height) - 10)
            let endIndex = min(paginatedNetworks.count, maxVisibleItems)

            for i in 0..<endIndex {
                let network = paginatedNetworks[i]
                let isSelected = i == selectedIndex
                let networkComponent = createNetworkListItemComponent(
                    network: network,
                    isSelected: isSelected
                )
                components.append(networkComponent)
            }

            // Pagination status
            if let paginationStatus = dataManager.getPaginationStatus(for: "networks") {
                components.append(Text("Paginated: \(paginationStatus)").info()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
            }
        }
    }

    @MainActor
    private static func renderTraditional(
        components: inout [any Component],
        cachedNetworks: [Network],
        searchQuery: String?,
        scrollOffset: Int,
        selectedIndex: Int,
        height: Int32
    ) async {
        let filteredNetworks = FilterUtils.filterNetworks(cachedNetworks, query: searchQuery)

        if filteredNetworks.isEmpty {
            components.append(Text("No networks found").info()
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 0, trailing: 0)))
        } else {
            // Calculate visible range for simple viewport
            let maxVisibleItems = max(1, Int(height) - 10) // Reserve space for header and footer
            let startIndex = max(0, min(scrollOffset, filteredNetworks.count - maxVisibleItems))
            let endIndex = min(filteredNetworks.count, startIndex + maxVisibleItems)

            for i in startIndex..<endIndex {
                let network = filteredNetworks[i]
                let isSelected = i == selectedIndex
                let networkComponent = createNetworkListItemComponent(network: network, isSelected: isSelected)
                components.append(networkComponent)
            }

            // Traditional scroll indicator
            if filteredNetworks.count > maxVisibleItems {
                let scrollText = "[\(startIndex + 1)-\(endIndex)/\(filteredNetworks.count)]"
                components.append(Text(scrollText).info()
                    .padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))
            }
        }
    }

    // MARK: - Network Detail View (Gold Standard Pattern)

    // Detail View Layout Constants (Matching Gold Standard)
    private static let networkDetailMinScreenWidth: Int32 = 40
    private static let networkDetailMinScreenHeight: Int32 = 15
    private static let networkDetailBoundsMinWidth: Int32 = 1
    private static let networkDetailBoundsMinHeight: Int32 = 1
    private static let networkDetailComponentSpacing: Int32 = 0
    private static let networkDetailReservedSpace: Int32 = 8

    // Detail View Layout Constants (Exact Gold Standard)
    private static let networkDetailTitleTopPadding: Int32 = 0
    private static let networkDetailTitleLeadingPadding: Int32 = 0
    private static let networkDetailTitleBottomPadding: Int32 = 2
    private static let networkDetailTitleTrailingPadding: Int32 = 0
    private static let networkDetailSectionTopPadding: Int32 = 0
    private static let networkDetailSectionLeadingPadding: Int32 = 4
    private static let networkDetailSectionBottomPadding: Int32 = 1
    private static let networkDetailSectionTrailingPadding: Int32 = 0

    // Detail View EdgeInsets (Pre-calculated for Performance)
    private static let networkDetailTitleEdgeInsets = EdgeInsets(top: networkDetailTitleTopPadding, leading: networkDetailTitleLeadingPadding, bottom: networkDetailTitleBottomPadding, trailing: networkDetailTitleTrailingPadding)
    private static let networkDetailSectionEdgeInsets = EdgeInsets(top: networkDetailSectionTopPadding, leading: networkDetailSectionLeadingPadding, bottom: networkDetailSectionBottomPadding, trailing: networkDetailSectionTrailingPadding)

    // Detail View Text Constants
    private static let networkDetailTitle = "Network Details"
    private static let networkDetailBasicInfoTitle = "Basic Information"
    private static let networkDetailConfigurationTitle = "Configuration"
    private static let networkDetailSubnetsTitle = "Subnets"
    private static let networkDetailNameLabel = "Name"
    private static let networkDetailIdLabel = "ID"
    private static let networkDetailStatusLabel = "Status"
    private static let networkDetailAdminStateLabel = "Admin State"
    private static let networkDetailSharedLabel = "Shared"
    private static let networkDetailExternalLabel = "External"
    private static let networkDetailUnnamedText = "Unnamed Network"
    private static let networkDetailUnknownText = "Unknown"
    private static let networkDetailYesText = "Yes"
    private static let networkDetailNoText = "No"
    private static let networkDetailUpText = "UP"
    private static let networkDetailDownText = "DOWN"
    private static let networkDetailInfoFieldIndent = "  "
    private static let networkDetailFieldValueSeparator = ": "
    private static let networkDetailScreenTooSmallText = "Screen too small"
    private static let networkDetailScrollIndicatorPrefix = "["
    private static let networkDetailScrollIndicatorSeparator = "-"
    private static let networkDetailScrollIndicatorMiddle = "/"
    private static let networkDetailScrollIndicatorSuffix = "] - Scroll: UP/DOWN"

    @MainActor
    static func drawNetworkDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                width: Int32, height: Int32, network: Network, scrollOffset: Int32 = 0) async {

        // Create surface for optimal performance (EXACT Gold Standard Pattern)
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > networkDetailMinScreenWidth && height > networkDetailMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow),
                                   width: max(networkDetailBoundsMinWidth, width),
                                   height: max(networkDetailBoundsMinHeight, height))
            await SwiftTUI.render(Text(networkDetailScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Network Detail (following EXACT RouterViews pattern)
        var components: [any Component] = []

        // Title - EXACT RouterViews pattern
        let networkName = (network.name?.isEmpty != false) ? networkDetailUnnamedText : network.name!
        let titleText = networkDetailTitle + networkDetailFieldValueSeparator + networkName
        components.append(Text(titleText).accent().bold()
                         .padding(networkDetailTitleEdgeInsets))

        // Basic Information Section - EXACT RouterViews pattern
        components.append(Text(networkDetailBasicInfoTitle).primary().bold())
        let basicInfoComponents = createBasicInfoComponents(network: network)
        let basicInfoSection = VStack(spacing: 0, children: basicInfoComponents)
            .padding(networkDetailSectionEdgeInsets)
        components.append(basicInfoSection)

        // Configuration Section
        components.append(Text(networkDetailConfigurationTitle).primary().bold())
        let configurationComponents = createConfigurationComponents(network: network)
        let configurationSection = VStack(spacing: 0, children: configurationComponents)
            .padding(networkDetailSectionEdgeInsets)
        components.append(configurationSection)

        // Subnets Section
        let subnetComponents = createSubnetComponents(network: network)
        if !subnetComponents.isEmpty {
            components.append(Text(networkDetailSubnetsTitle).primary().bold())
            let subnetsSection = VStack(spacing: 0, children: subnetComponents)
                .padding(networkDetailSectionEdgeInsets)
            components.append(subnetsSection)
        }

        // Apply scrolling and render visible components
        let maxVisibleComponents = max(1, Int(height) - Int(networkDetailReservedSpace))
        let startIndex = max(0, min(Int(scrollOffset), components.count - maxVisibleComponents))
        let endIndex = min(components.count, startIndex + maxVisibleComponents)
        let visibleComponents = Array(components[startIndex..<endIndex])

        // Render using EXACT RouterViews pattern with scrolling
        let networkDetailComponent = VStack(spacing: networkDetailComponentSpacing, children: visibleComponents)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(networkDetailComponent, on: surface, in: bounds)

        // Add scroll indicators if needed
        if components.count > maxVisibleComponents {
            let scrollText = networkDetailScrollIndicatorPrefix + String(startIndex + 1) + networkDetailScrollIndicatorSeparator + String(endIndex) + networkDetailScrollIndicatorMiddle + String(components.count) + networkDetailScrollIndicatorSuffix
            let scrollBounds = Rect(x: startCol, y: startRow + height - 1, width: width, height: 1)
            await SwiftTUI.render(Text(scrollText).info(), on: surface, in: scrollBounds)
        }
    }

    // MARK: - Gold Standard Component Creation Functions (EXACT RouterViews Pattern)

    private static func createBasicInfoComponents(network: Network) -> [any Component] {
        var components: [any Component] = []

        // Pre-calculate common field prefixes for optimal performance (RouterViews pattern)
        let fieldPrefix = networkDetailInfoFieldIndent
        let fieldSeparator = networkDetailFieldValueSeparator

        // Name
        let networkName = (network.name?.isEmpty != false) ? networkDetailUnnamedText : network.name!
        let nameText = fieldPrefix + networkDetailNameLabel + fieldSeparator + networkName
        components.append(Text(nameText).secondary())

        // ID
        let idText = fieldPrefix + networkDetailIdLabel + fieldSeparator + network.id
        components.append(Text(idText).secondary())

        // Status - with color coding like RouterViews
        let status = network.status ?? networkDetailUnknownText
        let statusText = fieldPrefix + networkDetailStatusLabel + fieldSeparator + status
        if status.lowercased() == "active" {
            components.append(Text(statusText).success())
        } else if status.lowercased().contains("down") || status.lowercased().contains("error") {
            components.append(Text(statusText).error())
        } else {
            components.append(Text(statusText).secondary())
        }

        // Admin State
        if let adminStateUp = network.adminStateUp {
            let adminStateValue = adminStateUp ? networkDetailUpText : networkDetailDownText
            let adminStateText = fieldPrefix + networkDetailAdminStateLabel + fieldSeparator + adminStateValue
            components.append(Text(adminStateText).secondary())
        }

        return components
    }

    private static func createConfigurationComponents(network: Network) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = networkDetailInfoFieldIndent
        let fieldSeparator = networkDetailFieldValueSeparator

        // Shared
        if let shared = network.shared {
            let sharedValue = shared ? networkDetailYesText : networkDetailNoText
            let sharedText = fieldPrefix + networkDetailSharedLabel + fieldSeparator + sharedValue
            components.append(Text(sharedText).secondary())
        }

        // External
        if let external = network.external {
            let externalValue = external ? networkDetailYesText : networkDetailNoText
            let externalText = fieldPrefix + networkDetailExternalLabel + fieldSeparator + externalValue
            components.append(Text(externalText).secondary())
        }

        return components
    }

    private static func createSubnetComponents(network: Network) -> [any Component] {
        var components: [any Component] = []
        let fieldPrefix = networkDetailInfoFieldIndent

        guard let subnets = network.subnets, !subnets.isEmpty else { return components }

        for subnet in subnets {
            let subnetText = fieldPrefix + "- " + subnet
            components.append(Text(subnetText).secondary())
        }

        return components
    }

    // MARK: - Network Create View

    // Layout Constants
    private static let componentTopPadding: Int32 = 1
    private static let statusMessageTopPadding: Int32 = 2
    private static let statusMessageLeadingPadding: Int32 = 2
    private static let validationErrorLeadingPadding: Int32 = 2
    private static let loadingErrorBoundsHeight: Int32 = 6
    private static let fieldActiveSpacing = "                      "

    // Text Constants
    private static let formTitle = "Create New Network"
    private static let creatingNetworkText = "Creating network..."
    private static let errorPrefix = "Error: "
    private static let requiredFieldSuffix = ": *"
    private static let optionalFieldSuffix = " (optional)"

    // Field Display Constants
    private static let validationErrorsTitle = "Validation Errors:"
    private static let validationErrorPrefix = "- "
    private static let checkboxSelectedText = "[X]"
    private static let checkboxUnselectedText = "[ ]"
    private static let editPromptText = "Press SPACE to edit..."
    private static let togglePromptText = "Press SPACE to toggle"

    // Field Label Constants
    private static let networkNameFieldLabel = "Network Name"
    private static let descriptionFieldLabel = "Description"
    private static let mtuFieldLabel = "MTU"
    private static let portSecurityFieldLabel = "Port Security"

    // Placeholder Constants
    private static let networkNamePlaceholder = "[Enter network name]"
    private static let descriptionPlaceholder = "[Optional description]"
    private static let mtuPlaceholder = "[Enter MTU (68-9000)]"

    // UI Component Constants
    private static let selectedIndicator = "> "
    private static let unselectedIndicator = "  "
    private static let componentSpacing: Int32 = 0
    private static let networkCreateMinScreenWidth: Int32 = 10
    private static let networkCreateMinScreenHeight: Int32 = 10
    private static let networkCreateBoundsMinWidth: Int32 = 1
    private static let networkCreateBoundsMinHeight: Int32 = 1
    private static let networkCreateScreenTooSmallText = "Screen too small for network create form"
    private static let networkCreateFormTitle = "Create New Network"

    @MainActor
    static func drawNetworkCreate(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                width: Int32, height: Int32, networkCreateForm: NetworkCreateForm,
                                networkCreateFormState: FormBuilderState) async {

        let surface = SwiftTUI.surface(from: screen)

        guard width > Self.networkCreateMinScreenWidth && height > Self.networkCreateMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.networkCreateBoundsMinWidth, width), height: max(Self.networkCreateBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.networkCreateScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        let fields = networkCreateForm.buildFields(
            selectedFieldId: networkCreateFormState.getCurrentFieldId(),
            activeFieldId: networkCreateFormState.getActiveFieldId(),
            formState: networkCreateFormState
        )

        let validationErrors = networkCreateForm.validateForm()

        let formBuilder = FormBuilder(
            title: Self.networkCreateFormTitle,
            fields: fields,
            selectedFieldId: networkCreateFormState.getCurrentFieldId(),
            validationErrors: validationErrors,
            showValidationErrors: !validationErrors.isEmpty
        )

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)
    }

    // MARK: - Pagination and Virtual Scrolling Navigation Helpers

    /// Handle navigation for paginated network list
    @MainActor
    static func handlePaginatedNavigation(dataManager: DataManager?, direction: NavigationDirection) async -> Bool {
        guard let dataManager = dataManager, dataManager.isPaginationEnabled(for: "networks") else {
            return false
        }

        switch direction {
        case .nextPage:
            return await dataManager.nextPage(for: "networks")
        case .previousPage:
            return await dataManager.previousPage(for: "networks")
        case .scrollUp, .scrollDown:
            // Individual item scrolling handled differently for networks
            return false
        }
    }

    /// Handle navigation for virtual scrolling network list
    @MainActor
    static func handleVirtualScrollNavigation(virtualScrollManager: VirtualScrollManager<Network>?, direction: NavigationDirection) async -> Bool {
        guard let virtualScrollManager = virtualScrollManager else {
            return false
        }

        switch direction {
        case .scrollUp:
            await virtualScrollManager.scrollUp()
            return true
        case .scrollDown:
            await virtualScrollManager.scrollDown()
            return true
        case .nextPage:
            await virtualScrollManager.pageDown()
            return true
        case .previousPage:
            await virtualScrollManager.pageUp()
            return true
        }
    }

    /// Get current network list status (pagination or virtual scrolling)
    @MainActor
    static func getNetworkListStatus(dataManager: DataManager?, virtualScrollManager: VirtualScrollManager<Network>?) -> String? {
        if let virtualScrollManager = virtualScrollManager {
            return "Virtual: \(virtualScrollManager.getScrollInfo())"
        } else if let dataManager = dataManager, dataManager.isPaginationEnabled(for: "networks") {
            if let status = dataManager.getPaginationStatus(for: "networks") {
                return "Pages: \(status)"
            }
        }
        return nil
    }

    /// Check if enhanced scrolling (pagination or virtual) is available
    @MainActor
    static func hasEnhancedScrolling(dataManager: DataManager?, virtualScrollManager: VirtualScrollManager<Network>?) -> Bool {
        return virtualScrollManager != nil || (dataManager?.isPaginationEnabled(for: "networks") == true)
    }

    // Navigation direction enum for cleaner API
    enum NavigationDirection {
        case scrollUp
        case scrollDown
        case nextPage
        case previousPage
    }
}