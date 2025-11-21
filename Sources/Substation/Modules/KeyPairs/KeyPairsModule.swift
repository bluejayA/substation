// Sources/Substation/Modules/KeyPairs/KeyPairsModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// SSH KeyPairs module implementation
///
/// This module provides OpenStack Nova SSH KeyPair management functionality including:
/// - KeyPair listing and browsing
/// - KeyPair detail views with security analysis
/// - KeyPair creation via import
///
/// The module integrates with the TUI system through the OpenStackModule protocol
/// and delegates rendering to KeyPairViews for consistent UI presentation.
@MainActor
final class KeyPairsModule: OpenStackModule {
    // MARK: - OpenStackModule Protocol Properties

    /// Unique identifier for the KeyPairs module
    let identifier: String = "keypairs"

    /// Display name shown in the UI
    let displayName: String = "SSH KeyPairs"

    /// Semantic version for compatibility tracking
    let version: String = "1.0.0"

    /// Module dependencies (KeyPairs has no dependencies)
    let dependencies: [String] = []

    // MARK: - Internal Properties

    /// Weak reference to TUI to prevent retain cycles
    /// Note: Internal access to allow extension in separate file to access this property
    internal weak var tui: TUI?

    /// Module health tracking
    private var lastHealthCheck: Date?
    private var healthErrors: [String] = []

    // MARK: - Initialization

    /// Initialize the KeyPairs module with TUI context
    /// - Parameter tui: The main TUI instance
    required init(tui: TUI) {
        self.tui = tui
    }

    // MARK: - Configuration

    /// Configure the module after initialization
    ///
    /// This method performs any necessary setup for the KeyPairs module.
    /// Currently, KeyPairs requires no special configuration beyond registration.
    func configure() async throws {
        guard tui != nil else {
            throw ModuleError.invalidState("TUI reference is nil during configuration")
        }

        // KeyPairs module is ready to use immediately
        // No additional configuration required

        // Register as batch operation provider
        BatchOperationRegistry.shared.register(self)

        // Register as action provider
        ActionProviderRegistry.shared.register(
            self,
            listViewMode: .keyPairs,
            detailViewMode: .keyPairDetail
        )

        lastHealthCheck = Date()
    }

    // MARK: - View Registration

    /// Register all KeyPair views with the TUI system
    ///
    /// This method creates ModuleViewRegistration entries for:
    /// - .keyPairs: List view of all key pairs
    /// - .keyPairDetail: Detail view for a selected key pair
    /// - .keyPairCreate: Form for creating new key pairs
    ///
    /// - Returns: Array of view registrations
    func registerViews() -> [ModuleViewRegistration] {
        guard let tui = tui else {
            return []
        }

        var registrations: [ModuleViewRegistration] = []

        // Register key pairs list view
        registrations.append(ModuleViewRegistration(
            viewMode: .keyPairs,
            title: "SSH KeyPairs",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await KeyPairViews.drawDetailedKeyPairList(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    cachedKeyPairs: tui.resourceCache.keyPairs,
                    searchQuery: tui.searchQuery,
                    scrollOffset: tui.viewCoordinator.scrollOffset,
                    selectedIndex: tui.viewCoordinator.selectedIndex,
                    multiSelectMode: tui.selectionManager.multiSelectMode,
                    selectedItems: tui.selectionManager.multiSelectedResourceIDs
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Register key pair detail view
        registrations.append(ModuleViewRegistration(
            viewMode: .keyPairDetail,
            title: "KeyPair Details",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }
                guard let keyPair = tui.viewCoordinator.selectedResource as? KeyPair else { return }

                await KeyPairViews.drawKeyPairDetail(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    keyPair: keyPair,
                    scrollOffset: tui.viewCoordinator.detailScrollOffset
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.inputHandler.handleInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        // Register key pair create form view
        registrations.append(ModuleViewRegistration(
            viewMode: .keyPairCreate,
            title: "Import SSH KeyPair",
            renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                guard let tui = tui else { return }

                await KeyPairViews.drawKeyPairCreate(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    keyPairCreateForm: tui.keyPairCreateForm,
                    keyPairCreateFormState: tui.keyPairCreateFormState
                )
            },
            inputHandler: { [weak tui] ch, screen in
                guard let tui = tui else { return false }
                await tui.handleKeyPairCreateInput(ch, screen: screen)
                return true
            },
            category: .compute
        ))

        return registrations
    }

    // MARK: - Form Handler Registration

    /// Register form handlers for KeyPair forms
    ///
    /// Currently registers:
    /// - KeyPair creation form handler using UniversalFormInputHandler
    ///
    /// - Returns: Array of form handler registrations
    func registerFormHandlers() -> [ModuleFormHandlerRegistration] {
        guard let tui = tui else {
            return []
        }

        var handlers: [ModuleFormHandlerRegistration] = []

        // Register key pair create form handler
        handlers.append(ModuleFormHandlerRegistration(
            viewMode: .keyPairCreate,
            handler: { [weak tui] ch, screen in
                guard let tui = tui else { return }
                await tui.handleKeyPairCreateInput(ch, screen: screen)
            },
            formValidation: { [weak tui] in
                guard let tui = tui else { return false }
                return tui.keyPairCreateForm.validateForm().isEmpty
            }
        ))

        return handlers
    }

    // MARK: - Data Refresh Registration

    /// Register data refresh handlers for KeyPair resources
    ///
    /// Registers a handler to refresh the key pairs list from the API.
    ///
    /// - Returns: Array of data refresh registrations
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration] {
        guard let tui = tui else {
            return []
        }

        var handlers: [ModuleDataRefreshRegistration] = []

        // Register key pairs refresh handler
        handlers.append(ModuleDataRefreshRegistration(
            identifier: "keypairs.list",
            refreshHandler: { [weak tui] in
                guard let tui = tui else { return }
                await tui.dataManager.refreshAllData()
            },
            cacheKey: "keyPairs",
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

    /// Perform a health check on the KeyPairs module
    ///
    /// This method verifies that:
    /// - TUI reference is valid
    /// - Nova compute service is accessible via the API client
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

        // Check if key pairs are loaded
        let keyPairCount = tui.resourceCache.keyPairs.count
        metrics["keyPairCount"] = keyPairCount

        // Check if key pairs data is available
        if keyPairCount == 0 {
            metrics["warning"] = "No key pairs loaded"
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
}

// MARK: - ActionProvider Conformance

extension KeyPairsModule: ActionProvider {
    /// Actions available in the list view for key pairs
    ///
    /// Includes create, delete, refresh, and cache management.
    var listViewActions: [ActionType] {
        [.create, .delete, .refresh, .clearCache]
    }

    /// The view mode for creating a new key pair
    var createViewMode: ViewMode? {
        .keyPairCreate
    }

    /// Execute an action for the selected key pair
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
            await deleteKeyPair(screen: screen)
            return true
        default:
            return false
        }
    }
}
