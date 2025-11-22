// Sources/Substation/Modules/Core/ViewRegistry.swift
import Foundation

/// Central registry for view handlers provided by modules
@MainActor
final class ViewRegistry {
    static let shared = ViewRegistry()

    // MARK: - Legacy ViewMode-based storage (for backward compatibility)

    private var viewHandlers: [ViewMode: ModuleViewRegistration] = [:]

    // MARK: - New metadata-based storage

    private var viewMetadata: [String: ViewMetadata] = [:]
    private var viewsByModule: [String: Set<String>] = [:]

    private init() {}

    // MARK: - Legacy Registration (ViewMode-based)

    /// Register a view handler (legacy method)
    func register(_ registration: ModuleViewRegistration) {
        viewHandlers[registration.viewMode] = registration
        Logger.shared.logDebug("[ViewRegistry] Registered view: \(registration.viewMode) -> \(registration.title)")
    }

    /// Get handler for a specific view mode (legacy method)
    func handler(for viewMode: ViewMode) -> ModuleViewRegistration? {
        return viewHandlers[viewMode]
    }

    /// Get all registered views (legacy method)
    func allRegistrations() -> [ModuleViewRegistration] {
        return Array(viewHandlers.values)
    }

    /// Get views in a specific category (legacy method)
    func registrations(in category: ViewCategory) -> [ModuleViewRegistration] {
        return viewHandlers.values.filter { $0.category == category }
    }

    // MARK: - New Metadata-based Registration

    /// Register a view with full metadata
    ///
    /// - Parameter metadata: Complete view metadata including identifier and handlers
    func register(metadata: ViewMetadata) {
        let id = metadata.identifier.id
        viewMetadata[id] = metadata

        // Track by module
        var moduleViews = viewsByModule[metadata.identifier.moduleId] ?? Set()
        moduleViews.insert(id)
        viewsByModule[metadata.identifier.moduleId] = moduleViews

        Logger.shared.logDebug(
            "[ViewRegistry] Registered metadata view: \(id) -> \(metadata.title)"
        )
    }

    /// Register multiple views with metadata
    ///
    /// - Parameter metadataList: Array of view metadata to register
    func register(metadataList: [ViewMetadata]) {
        for metadata in metadataList {
            register(metadata: metadata)
        }
    }

    /// Get metadata for a view identifier
    ///
    /// - Parameter identifier: The view identifier
    /// - Returns: View metadata if registered
    func metadata(for identifier: any ViewIdentifier) -> ViewMetadata? {
        return viewMetadata[identifier.id]
    }

    /// Get metadata by string ID
    ///
    /// - Parameter id: The view identifier string
    /// - Returns: View metadata if registered
    func metadata(forId id: String) -> ViewMetadata? {
        return viewMetadata[id]
    }

    /// Get all view IDs for a module
    ///
    /// - Parameter moduleId: The module identifier
    /// - Returns: Set of view IDs owned by the module
    func viewIds(for moduleId: String) -> Set<String> {
        return viewsByModule[moduleId] ?? Set()
    }

    /// Get all metadata for views in a category
    ///
    /// - Parameter category: The view category
    /// - Returns: Array of view metadata in the category
    func metadata(in category: ViewCategory) -> [ViewMetadata] {
        return viewMetadata.values.filter { $0.category == category }
    }

    /// Get all registered view metadata
    ///
    /// - Returns: Array of all registered view metadata
    func allMetadata() -> [ViewMetadata] {
        return Array(viewMetadata.values)
    }

    /// Check if a view is registered
    ///
    /// - Parameter id: The view identifier string
    /// - Returns: True if the view is registered
    func isRegistered(id: String) -> Bool {
        return viewMetadata[id] != nil
    }

    /// Get parent view ID for navigation
    ///
    /// - Parameter id: The current view identifier string
    /// - Returns: Parent view ID if defined
    func parentViewId(for id: String) -> String? {
        return viewMetadata[id]?.parentViewId
    }

    /// Check if a view supports multi-selection
    ///
    /// - Parameter id: The view identifier string
    /// - Returns: True if multi-select is supported
    func supportsMultiSelect(id: String) -> Bool {
        return viewMetadata[id]?.supportsMultiSelect ?? false
    }

    /// Check if a view is a detail view
    ///
    /// - Parameter id: The view identifier string
    /// - Returns: True if this is a detail view
    func isDetailView(id: String) -> Bool {
        return viewMetadata[id]?.isDetailView ?? false
    }

    /// Get title for a view
    ///
    /// - Parameter id: The view identifier string
    /// - Returns: View title if registered
    func title(for id: String) -> String? {
        return viewMetadata[id]?.title
    }

    // MARK: - Clear

    /// Clear all registrations (for testing)
    func clear() {
        viewHandlers.removeAll()
        viewMetadata.removeAll()
        viewsByModule.removeAll()
    }

    /// Clear only metadata registrations (for testing)
    func clearMetadata() {
        viewMetadata.removeAll()
        viewsByModule.removeAll()
    }

    // MARK: - Diagnostics

    /// Get registration status for all ViewMode cases
    ///
    /// Returns a dictionary mapping each ViewMode to its registration status.
    /// Useful for debugging and ensuring all views are properly registered.
    ///
    /// - Returns: Dictionary of ViewMode identifiers to registration status
    func registrationDiagnostics() -> [String: Bool] {
        var results: [String: Bool] = [:]
        for viewMode in ViewMode.allCases {
            let viewId = viewMode.viewIdentifierId
            results[viewId] = viewMetadata[viewId] != nil
        }
        return results
    }

    /// Get list of unregistered ViewMode cases
    ///
    /// Returns the view identifiers for ViewMode cases that don't have
    /// registered metadata.
    ///
    /// - Returns: Array of unregistered view identifier strings
    func unregisteredViews() -> [String] {
        return ViewMode.allCases
            .map { $0.viewIdentifierId }
            .filter { viewMetadata[$0] == nil }
    }

    /// Log registration status for all views
    ///
    /// Logs the registration status of all ViewMode cases at debug level,
    /// and logs warnings for any unregistered views.
    func logRegistrationStatus() {
        let totalViews = ViewMode.allCases.count
        let registeredCount = viewMetadata.count
        let unregistered = unregisteredViews()

        Logger.shared.logDebug("View Registration Status: \(registeredCount)/\(totalViews) views registered")

        if unregistered.isEmpty {
            Logger.shared.logDebug("All views are registered with metadata")
        } else {
            Logger.shared.logWarning("Unregistered views: \(unregistered.joined(separator: ", "))")
        }

        // Log by module
        for (moduleId, viewIds) in viewsByModule.sorted(by: { $0.key < $1.key }) {
            Logger.shared.logDebug("Module '\(moduleId)': \(viewIds.count) views")
        }
    }
}
