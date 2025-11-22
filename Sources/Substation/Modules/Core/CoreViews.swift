// Sources/Substation/Modules/Core/CoreViews.swift
import Foundation

/// Core system views that are not part of any specific module
///
/// These views represent fundamental application functionality like
/// loading screens, dashboards, help, and other system-level views.
enum CoreViews {
    // MARK: - System Views

    static let loading = DynamicViewIdentifier(
        id: "core.loading",
        moduleId: "core",
        viewType: .dashboard
    )

    static let dashboard = DynamicViewIdentifier(
        id: "core.dashboard",
        moduleId: "core",
        viewType: .dashboard
    )

    static let healthDashboard = DynamicViewIdentifier(
        id: "core.healthDashboard",
        moduleId: "core",
        viewType: .dashboard
    )

    static let healthDashboardServiceDetail = DynamicViewIdentifier(
        id: "core.healthDashboardServiceDetail",
        moduleId: "core",
        viewType: .detail
    )

    static let performanceMetrics = DynamicViewIdentifier(
        id: "core.performanceMetrics",
        moduleId: "core",
        viewType: .dashboard
    )

    // MARK: - Help and Documentation

    static let help = DynamicViewIdentifier(
        id: "core.help",
        moduleId: "core",
        viewType: .help
    )

    static let about = DynamicViewIdentifier(
        id: "core.about",
        moduleId: "core",
        viewType: .help
    )

    static let welcome = DynamicViewIdentifier(
        id: "core.welcome",
        moduleId: "core",
        viewType: .help
    )

    static let tutorial = DynamicViewIdentifier(
        id: "core.tutorial",
        moduleId: "core",
        viewType: .help
    )

    static let shortcuts = DynamicViewIdentifier(
        id: "core.shortcuts",
        moduleId: "core",
        viewType: .help
    )

    static let examples = DynamicViewIdentifier(
        id: "core.examples",
        moduleId: "core",
        viewType: .help
    )

    // MARK: - Utilities

    static let advancedSearch = DynamicViewIdentifier(
        id: "core.advancedSearch",
        moduleId: "core",
        viewType: .dashboard
    )

    // MARK: - All Core Views

    /// All core view identifiers for registration
    static var allViews: [DynamicViewIdentifier] {
        return [
            loading,
            dashboard,
            healthDashboard,
            healthDashboardServiceDetail,
            performanceMetrics,
            help,
            about,
            welcome,
            tutorial,
            shortcuts,
            examples,
            advancedSearch
        ]
    }

    /// Get view identifier by string ID
    static func view(forId id: String) -> DynamicViewIdentifier? {
        return allViews.first { $0.id == id }
    }
}
