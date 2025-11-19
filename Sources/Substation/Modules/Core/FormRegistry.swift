// Sources/Substation/Modules/Core/FormRegistry.swift
import Foundation

/// Central registry for form handlers provided by modules
@MainActor
final class FormRegistry {
    static let shared = FormRegistry()

    private var formHandlers: [ViewMode: ModuleFormHandlerRegistration] = [:]

    private init() {}

    /// Register a form handler
    func register(_ registration: ModuleFormHandlerRegistration) {
        formHandlers[registration.viewMode] = registration
        Logger.shared.logDebug("[FormRegistry] Registered form handler for: \(registration.viewMode)")
    }

    /// Get handler for a specific view mode
    func handler(for viewMode: ViewMode) -> ModuleFormHandlerRegistration? {
        return formHandlers[viewMode]
    }

    /// Get all registered form handlers
    func allRegistrations() -> [ModuleFormHandlerRegistration] {
        return Array(formHandlers.values)
    }

    /// Clear all registrations (for testing)
    func clear() {
        formHandlers.removeAll()
    }
}
