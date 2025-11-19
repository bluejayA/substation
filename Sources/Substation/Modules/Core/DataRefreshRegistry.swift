// Sources/Substation/Modules/Core/DataRefreshRegistry.swift
import Foundation

/// Central registry for data refresh handlers provided by modules
@MainActor
final class DataRefreshRegistry {
    static let shared = DataRefreshRegistry()

    private var refreshHandlers: [String: ModuleDataRefreshRegistration] = [:]

    private init() {}

    /// Register a data refresh handler
    func register(_ registration: ModuleDataRefreshRegistration) {
        refreshHandlers[registration.identifier] = registration
        Logger.shared.logDebug("[DataRefreshRegistry] Registered refresh handler: \(registration.identifier)")
    }

    /// Get handler by identifier
    func handler(for identifier: String) -> ModuleDataRefreshRegistration? {
        return refreshHandlers[identifier]
    }

    /// Get all registered refresh handlers
    func allRegistrations() -> [ModuleDataRefreshRegistration] {
        return Array(refreshHandlers.values)
    }

    /// Execute all refresh handlers
    func refreshAll() async {
        for (_, registration) in refreshHandlers {
            do {
                try await registration.refreshHandler()
            } catch {
                Logger.shared.logError("[DataRefreshRegistry] Refresh failed for \(registration.identifier): \(error)")
            }
        }
    }

    /// Clear all registrations (for testing)
    func clear() {
        refreshHandlers.removeAll()
    }
}
