// Sources/Substation/Modules/Core/ViewRegistry.swift
import Foundation

/// Central registry for view handlers provided by modules
@MainActor
final class ViewRegistry {
    static let shared = ViewRegistry()

    private var viewHandlers: [ViewMode: ModuleViewRegistration] = [:]

    private init() {}

    /// Register a view handler
    func register(_ registration: ModuleViewRegistration) {
        viewHandlers[registration.viewMode] = registration
        Logger.shared.logDebug("[ViewRegistry] Registered view: \(registration.viewMode) -> \(registration.title)")
    }

    /// Get handler for a specific view mode
    func handler(for viewMode: ViewMode) -> ModuleViewRegistration? {
        return viewHandlers[viewMode]
    }

    /// Get all registered views
    func allRegistrations() -> [ModuleViewRegistration] {
        return Array(viewHandlers.values)
    }

    /// Get views in a specific category
    func registrations(in category: ViewCategory) -> [ModuleViewRegistration] {
        return viewHandlers.values.filter { $0.category == category }
    }

    /// Clear all registrations (for testing)
    func clear() {
        viewHandlers.removeAll()
    }
}
