// Sources/Substation/Modules/Core/Protocols/ActionProvider.swift
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2025 Kevin Carter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - Action Provider Protocol

/// Protocol for modules that provide command actions
///
/// Modules conforming to this protocol can register their available actions
/// and provide execution logic for those actions. This enables resource-specific
/// action handling while maintaining a consistent command interface.
///
/// ## Overview
///
/// The `ActionProvider` protocol extends `OpenStackModule` to add command action
/// capabilities. Each module declares its supported actions for list and detail
/// views, and implements execution handlers for delete and manage operations.
///
/// ## Example
///
/// ```swift
/// extension ServersModule: ActionProvider {
///     var listViewActions: [ActionType] {
///         [.create, .delete, .refresh, .start, .stop, .restart, .clearCache]
///     }
///
///     var detailViewActions: [ActionType] {
///         [.delete, .start, .stop, .restart, .refresh, .clearCache]
///     }
///
///     var createViewMode: ViewMode? { .serverCreate }
///
///     func executeDelete(screen: OpaquePointer?) async {
///         await deleteServer(screen: screen)
///     }
/// }
/// ```
@MainActor
protocol ActionProvider: OpenStackModule {
    /// Actions available in the list view for this module
    ///
    /// These actions appear when the user is viewing the resource list.
    var listViewActions: [ActionType] { get }

    /// Actions available in the detail view for this module
    ///
    /// These actions appear when viewing a single resource's details.
    var detailViewActions: [ActionType] { get }

    /// The view mode for creating a new resource
    ///
    /// Returns nil if create is not supported.
    var createViewMode: ViewMode? { get }

    /// Execute an action for this module
    ///
    /// This is the primary entry point for action execution. Modules implement
    /// this to handle all their supported actions in one place.
    ///
    /// - Parameters:
    ///   - action: The action type to execute
    ///   - screen: Screen pointer for dialogs
    ///   - tui: The TUI instance for view changes and status updates
    /// - Returns: True if the action was handled
    func executeAction(_ action: ActionType, screen: OpaquePointer?, tui: TUI) async -> Bool
}

/// Default implementations for ActionProvider
extension ActionProvider {
    /// Default detail view actions
    var detailViewActions: [ActionType] {
        [.delete, .refresh, .clearCache]
    }

    /// Default nil create view mode (no create support)
    var createViewMode: ViewMode? { nil }
}

// MARK: - Action Provider Registry

/// Registry for action providers
///
/// Maintains a collection of all modules that support command actions,
/// allowing the CommandActionHandler to discover and invoke actions dynamically.
///
/// This is a singleton that should be populated during application startup
/// as modules are registered.
///
/// ## Usage
///
/// ```swift
/// // Register a provider
/// ActionProviderRegistry.shared.register(serversModule)
///
/// // Get provider for a view mode
/// if let provider = ActionProviderRegistry.shared.provider(for: .servers) {
///     let actions = provider.listViewActions
/// }
/// ```
@MainActor
final class ActionProviderRegistry {
    /// Shared singleton instance
    static let shared = ActionProviderRegistry()

    /// Map of view modes to their action providers
    private var providers: [ViewMode: any ActionProvider] = [:]

    /// Map of module identifiers to view modes for lookup
    private var moduleViewModes: [String: (list: ViewMode, detail: ViewMode?)] = [:]

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Register a module as an action provider with its view modes
    ///
    /// - Parameters:
    ///   - provider: The module conforming to ActionProvider
    ///   - listViewMode: The list view mode for this module
    ///   - detailViewMode: The detail view mode for this module (optional)
    func register(
        _ provider: any ActionProvider,
        listViewMode: ViewMode,
        detailViewMode: ViewMode? = nil
    ) {
        providers[listViewMode] = provider
        if let detailMode = detailViewMode {
            providers[detailMode] = provider
        }
        moduleViewModes[provider.identifier] = (list: listViewMode, detail: detailViewMode)
        Logger.shared.logInfo("ActionProviderRegistry - Registered provider: \(provider.identifier) for \(listViewMode)")
    }

    /// Get provider for a view mode
    ///
    /// - Parameter viewMode: The view mode to look up
    /// - Returns: The action provider, or nil if not registered
    func provider(for viewMode: ViewMode) -> (any ActionProvider)? {
        return providers[viewMode]
    }

    /// Check if a view mode has a registered provider
    ///
    /// - Parameter viewMode: The view mode to check
    /// - Returns: True if a provider is registered
    func hasProvider(for viewMode: ViewMode) -> Bool {
        return providers[viewMode] != nil
    }

    /// Check if a view mode is a detail view for its provider
    ///
    /// - Parameter viewMode: The view mode to check
    /// - Returns: True if this is a detail view
    func isDetailView(_ viewMode: ViewMode) -> Bool {
        guard let provider = providers[viewMode] else { return false }
        if let viewModes = moduleViewModes[provider.identifier] {
            return viewModes.detail == viewMode
        }
        return false
    }

    /// Get all registered view modes
    ///
    /// - Returns: Set of all registered view modes
    func allRegisteredViewModes() -> Set<ViewMode> {
        return Set(providers.keys)
    }

    /// Get the count of registered providers
    var providerCount: Int {
        return providers.count
    }

    /// Clear all registered providers
    ///
    /// Primarily used for testing purposes.
    func clearAll() {
        providers.removeAll()
        moduleViewModes.removeAll()
        Logger.shared.logInfo("ActionProviderRegistry - Cleared all providers")
    }
}
