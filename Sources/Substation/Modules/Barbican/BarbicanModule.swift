// Sources/Substation/Modules/Barbican/BarbicanModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// Barbican Key Manager module implementation
///
/// This module provides OpenStack Barbican (Key Manager) functionality including:
/// - Secret listing and browsing
/// - Secret detail views with cryptographic information
/// - Secret creation with advanced configuration options
///
/// The module integrates with the TUI system through the OpenStackModule protocol
/// and delegates rendering to BarbicanViews for consistent UI presentation.
@MainActor
final class BarbicanModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the Barbican module
    let identifier: String = "barbican"

    /// Display name shown in the UI
    let displayName: String = "Key Manager (Barbican)"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies (Barbican has no dependencies)
    let dependencies: [String] = []

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    internal weak var tui: TUI?

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    // MARK: - Initialization

    /// Initialize the Barbican module with TUI context
    /// - Parameter tui: The main TUI instance
    required init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs any necessary setup for the Barbican module.
    /// Currently, Barbican requires no special configuration beyond registration.
    func configure() async throws {
        guard tui != nil else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        // Barbican module is ready to use immediately
        // No additional configuration required

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .barbicanSecrets,
            detailViewMode: .barbicanSecretDetail
        )

        // Register as data provider
        let dataProvider = BarbicanDataProvider(module: self, tui: tui!)
        DataProviderRegistry.shared.register(dataProvider, from: identifier)

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all Barbican views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .barbicanSecrets: List view of all secrets
    /// - .barbicanSecretDetail: Detail view for a selected secret
    /// - .barbicanSecretCreate: Form for creating new secrets
    ///
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            return []
        }

        var registrations: [ModuleViewRegistration] = []

        // Register secrets list view
        registrations.append(ModuleViewRegistration(
            viewMode: .barbicanSecrets,
            title: "Secrets",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                let secrets = tui.cacheManager.cachedSecrets
                await BarbicanViews.drawBarbicanSecretList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    secrets: secrets,
                    searchQuery: tui.searchQuery ?? "",
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    filterCache: tui.resourceNameCache,
                    multiSelectMode: tui.selectionManager.multiSelectMode,
                    selectedItems: tui.selectionManager.multiSelectedResourceIDs
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .security
        ))

        // Register secret detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .barbicanSecretDetail,
            title: "Secret Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let secret = tui.viewCoordinator.selectedResource as? Secret else { return }

                await BarbicanViews.drawBarbicanSecretDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    secret: secret,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .security
        ))

        // Register secret create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .barbicanSecretCreate,
            title: "Create Secret",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await BarbicanViews.drawBarbicanSecretCreateForm(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    form: tui.barbicanSecretCreateForm,
                    formState: tui.barbicanSecretCreateFormState
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .security
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for Barbican forms
    ///
    /// Currently registers:
    /// - Secret creation form handler using universalFormInputHandler
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register secret create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .barbicanSecretCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.inputHandler.handleInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                return tui.barbicanSecretCreateForm.validate().isEmpty
            }
        ))

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for Barbican resources
    ///
    /// Registers a handler to refresh the secrets list from the API.
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else {
            return []
        }

        var handlers: [ModuleDataRefreshRegistration] = []

        // Register secrets refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "barbican.secrets",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                await tui.dataManager.refreshAllData()
            },
            cacheKey: "secrets",
            refreshInterval: 60.0 // Refresh every 60 seconds
        ))

        return handlers
    }

    // MARK: - Cleanup

    /// Cleanup when the module is unloaded
    ///
    /// This method is called when the module is being deactivated or removed.
    /// It ensures proper resource cleanup and state management.
    func cleanup() async {
        // Clear any module-specific state
        healthErrors.removeAll()
        lastHealthCheck = nil

        // TUI reference will be released naturally via weak reference
    }

    // MARK: - Health Check

    /// Perform a health check on the Barbican module
    ///
    /// This method verifies that:
    /// - TUI reference is valid
    /// - Barbican service is accessible via the API client
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

        // Check if secrets are loaded
        let secretCount = tui.cacheManager.cachedSecrets.count
        metrics["secretCount"] = secretCount

        // Check if Barbican service is accessible (inferred from cache)
        if secretCount == 0 {
            metrics["warning"] = "No secrets loaded - service may not be accessible"
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

    /// Get all cached secrets
    ///
    /// Returns all secrets from the cache manager.
    /// Used for secret listing, filtering, and selection operations.
    var secrets: [Secret] {
        return tui?.cacheManager.cachedSecrets ?? []
    }
}

// MARK: - ActionProvider Conformance

extension BarbicanModule: ActionProvider {
    /// Actions available in the list view for secrets
    ///
    /// Includes create, delete, refresh, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .clearCache]
    }

    /// The view mode for creating a new secret
    var createViewMode: ViewMode? {
        .barbicanSecretCreate
    }

    /// Execute an action for the selected secret
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
            await deleteSecret(screen: screen)
            return true
        default:
            return false
        }
    }
}
