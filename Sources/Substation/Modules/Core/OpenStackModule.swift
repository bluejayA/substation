// Sources/Substation/Modules/Core/OpenStackModule.swift
import Foundation
import OSClient
import SwiftNCurses

/// Core protocol that all OpenStack service modules must conform to.
/// This protocol defines the contract between modules and the TUI system.
@MainActor
protocol OpenStackModule {
    /// Unique identifier for the module (e.g., "barbican", "swift")
    var identifier: String { get }

    /// Display name shown in UI (e.g., "Key Management", "Object Storage")
    var displayName: String { get }

    /// Semantic version for compatibility checking
    var version: String { get }

    /// Dependencies on other modules (empty array if none)
    var dependencies: [String] { get }

    /// Initialize with TUI context
    init(tui: TUI)

    /// Configure module after initialization
    func configure() async throws

    /// Register views with TUI system
    func registerViews() -> [ModuleViewRegistration]

    /// Register form handlers with TUI system
    func registerFormHandlers() -> [ModuleFormHandlerRegistration]

    /// Register data refresh handlers
    func registerDataRefreshHandlers() -> [ModuleDataRefreshRegistration]

    /// Cleanup when module is unloaded
    func cleanup() async

    /// Module health check for monitoring
    func healthCheck() async -> ModuleHealthStatus
}
