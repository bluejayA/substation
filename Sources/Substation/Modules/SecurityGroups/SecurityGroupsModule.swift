// Sources/Substation/Modules/SecurityGroups/SecurityGroupsModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// OpenStack Security Groups module implementation
///
/// This module provides comprehensive security group management capabilities including:
/// - Security group listing and browsing
/// - Security group detail views with rule analysis
/// - Security group creation and configuration
/// - Security group rule management (create, edit, delete)
/// - Server attachment and management operations
///
/// The module integrates with the TUI system through the OpenStackModule protocol
/// and delegates rendering to SecurityGroupViews for consistent UI presentation.
@MainActor
final class SecurityGroupsModule: OpenStackModule {

    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Security Groups module
    let identifier: String = "securitygroups"

    /// Display name shown in the UI
    let displayName: String = "Security Groups"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies (Security Groups has no dependencies)
    let dependencies: [String] = []

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    // MARK: - Initialization

    /// Initialize the Security Groups module with TUI context
    /// - Parameter tui: The main TUI instance
    required init(tui: TUI) {
        self.tui = tui
        Logger.shared.logInfo("SecurityGroupsModule initialized", context: [
            "version": version,
            "identifier": identifier
        ])
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs any necessary setup for the Security Groups module.
    /// Verifies that the Neutron network service is available for security group operations.
    func configure() async throws {
        guard tui != nil else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        Logger.shared.logInfo("SecurityGroupsModule configuration started", context: [:])

        // SecurityGroupsModule configuration completed
        Logger.shared.logInfo("SecurityGroupsModule configuration completed", context: [:])

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .securityGroups,
            detailViewMode: .securityGroupDetail
        )

        // Register as data provider
        let dataProvider = SecurityGroupsDataProvider(module: self, tui: tui!)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        // Register enhanced views with metadata
        let viewMetadata = registerViewsEnhanced()
        ViewRegistry.shared.register(metadataList: viewMetadata)

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all Security Groups views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .securityGroups: List view of all security groups
    /// - .securityGroupDetail: Detail view for a selected security group
    /// - .securityGroupCreate: Form for creating new security groups
    /// - .securityGroupRuleManagement: Interface for managing security group rules
    /// - .securityGroupServerAttachment: Form for attaching security groups to servers
    /// - .securityGroupServerManagement: Interface for managing server security group attachments
    ///
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register views - TUI reference is nil", context: [:])
            return []
        }

        var registrations: [ModuleViewRegistration] = []

        // Register security groups list view
        registrations.append(ModuleViewRegistration(
            viewMode: .securityGroups,
            title: "Security Groups",
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
            inputHandler: nil, // Default system handles input
            category: .network
        ))

        // Register security group detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .securityGroupDetail,
            title: "Security Group Details",
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
                    selectedRuleIndex: nil,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: nil, // Default system handles input
            category: .network
        ))

        // Register security group create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .securityGroupCreate,
            title: "Create Security Group",
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
            },
            category: .network
        ))

        // Register security group rule management view
        registrations.append(ModuleViewRegistration(
            viewMode: .securityGroupRuleManagement,
            title: "Manage Security Group Rules",
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
                await tui.handleSecurityGroupRuleManagementInput(ch, screen: screen)
                return true
            },
            category: .network
        ))

        Logger.shared.logInfo("SecurityGroupsModule registered \(registrations.count) views", context: [:])
        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for Security Groups forms
    ///
    /// Registers handlers for:
    /// - Security group creation form using universalFormInputHandler
    /// - Security group rule creation and management
    /// - Server attachment operations
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register form handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register security group create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .securityGroupCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleSecurityGroupCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                let validation = tui.securityGroupCreateForm.validateForm()
                return validation.isValid
            }
        ))

        // Register security group rule management form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .securityGroupRuleManagement,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleSecurityGroupRuleManagementInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                // Rule management form validation depends on current mode
                if tui.securityGroupRuleManagementForm!.shouldShowCreateForm() ||
                   tui.securityGroupRuleManagementForm!.shouldShowEditForm() {
                    let validation = tui.securityGroupRuleManagementForm!.ruleCreateForm.validateForm()
                    return validation.isValid
                }
                return true
            }
        ))

        Logger.shared.logInfo("SecurityGroupsModule registered \(handlers.count) form handlers", context: [:])
        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for Security Groups resources
    ///
    /// Registers a handler to refresh the security groups list from the Neutron API.
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else {
            Logger.shared.logError("Cannot register data refresh handlers - TUI reference is nil", context: [:])
            return []
        }

        var handlers: [ModuleDataRefreshRegistration] = []

        // Register security groups refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "securitygroups.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                await tui.dataManager.refreshAllData()
            },
            cacheKey: "security_groups",
            refreshInterval: 30.0 // Refresh every 30 seconds
        ))

        Logger.shared.logInfo("SecurityGroupsModule registered \(handlers.count) data refresh handlers", context: [:])
        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It ensures proper resource cleanup and state management.
    func cleanup() async {
        Logger.shared.logInfo("SecurityGroupsModule cleanup started", context: [:])

        // Clear any module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil

        // TUI reference will be released naturally via weak reference

        Logger.shared.logInfo("SecurityGroupsModule cleanup completed", context: [:])
    }

    // MARK: - Health Check

    /// Perform a health check on the Security Groups module
    ///
    /// This method verifies that:
    /// - TUI reference is valid
    /// - Neutron service is accessible via the API client
    /// - Security groups data is loaded and accessible
    /// - Core functionality is operational
    ///
    /// - Returns: ModuleHealthStatus indicating module health
    func healthCheck() async -> ModuleHealthStatus {
        var errors: [String] = []
        var metrics: [String: Any] = [:]

        // Check TUI reference
        guard let tui = tui else {
            errors.append("TUI reference is nil")
            return ModuleHealthStatus(
                isHealthy: false,
                lastCheck: Date(),
                errors: errors,
                metrics: metrics
            )
        }

        // Check if security groups are loaded
        let securityGroupCount = tui.cacheManager.cachedSecurityGroups.count
        metrics["securityGroupCount"] = securityGroupCount

        // Check cache state
        metrics["hasCachedData"] = securityGroupCount > 0
        if securityGroupCount == 0 {
            metrics["warning"] = "No security groups loaded"
        }

        // Update health tracking
        lastHealthCheck = Date()
        healthErrors = errors

        return ModuleHealthStatus(
            isHealthy: errors.isEmpty,
            lastCheck: Date(),
            errors: errors,
            metrics: metrics
        )
    }

    // MARK: - Computed Properties

    /// Get all cached security groups
    ///
    /// Returns all security groups from the cache manager.
    /// Used for security group listing, filtering, and selection operations.
    var securityGroups: [SecurityGroup] {
        return tui?.cacheManager.cachedSecurityGroups ?? []
    }
}

// MARK: - ActionProvider Conformance

extension SecurityGroupsModule: ActionProvider {
    /// Actions available in the list view for security groups
    ///
    /// Includes create, delete, refresh, manage, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .manage, .clearCache]
    }

    /// The view mode for creating a new security group
    var createViewMode: ViewMode? {
        .securityGroupCreate
    }

    /// Execute an action for the selected security group
    ///
    /// - Parameters:
    ///   - action: The action type to execute
    ///   - screen: Screen pointer for confirmation dialogs
    ///   - tui: The TUI instance for state management
    /// - Returns: Boolean indicating if the action was handled
    func executeAction(_ action: ActionType, screen: OpaquePointer?, tui: TUI) async -> Bool {
        switch action {
        case .create:
            if let createMode = createViewMode {
                tui.changeView(to: createMode)
                tui.statusMessage = "Opening create form..."
                return true
            }
            return false
        case .delete:
            await deleteSecurityGroup(screen: screen)
            return true
        case .manage:
            await manageSecurityGroupToServers(screen: screen)
            return true
        default:
            return false
        }
    }
}
