// Sources/Substation/Modules/Core/ModuleRegistrationTypes.swift
import Foundation
import SwiftNCurses

/// Registration for a view provided by a module
struct ModuleViewRegistration {
    let viewMode: ViewMode
    let title: String
    let renderHandler: @MainActor (OpaquePointer?, Int32, Int32, Int32, Int32) async -> Void
    let inputHandler: (@MainActor (Int32, OpaquePointer?) async -> Bool)?
    let category: ViewCategory
}

/// Registration for a form handler provided by a module
struct ModuleFormHandlerRegistration {
    let viewMode: ViewMode
    let handler: @MainActor (Int32, OpaquePointer?) async -> Void
    let formValidation: () -> Bool
}

/// Registration for data refresh handlers
struct ModuleDataRefreshRegistration {
    let identifier: String
    let refreshHandler: @MainActor () async throws -> Void
    let cacheKey: String?
    let refreshInterval: TimeInterval?
}

/// Module health status
struct ModuleHealthStatus {
    let isHealthy: Bool
    let lastCheck: Date
    let errors: [String]
    let metrics: [String: Any]
}

/// View categories for menu organization
enum ViewCategory {
    case compute
    case storage
    case network
    case security
    case management
}

/// Module errors
enum ModuleError: Error {
    case missingDependency(String)
    case loadFailed(String, any Error)
    case configurationFailed(String)
    case incompatibleVersion(String, String)
    case invalidState(String)
}
