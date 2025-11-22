// Sources/Substation/Modules/Core/Extensions/CoreViews+Metadata.swift
import Foundation
import SwiftNCurses

/// Metadata registration for core system views
extension CoreViews {
    /// Register all core views with their render handlers
    ///
    /// - Parameter tui: The TUI instance for accessing state
    /// - Returns: Array of ViewMetadata for core views
    @MainActor
    static func registerViewsEnhanced(tui: TUI) -> [ViewMetadata] {
        return [
            // MARK: - Loading View
            ViewMetadata(
                identifier: loading,
                title: "Loading",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await LoadingView.drawLoadingScreen(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        progressStep: tui.loadingProgress,
                        statusMessage: tui.loadingMessage
                    )
                },
                inputHandler: nil
            ),

            // MARK: - Dashboard View
            ViewMetadata(
                identifier: dashboard,
                title: "Dashboard",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await DashboardView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        resourceCounts: tui.resourceCounts,
                        cachedServers: tui.cacheManager.cachedServers,
                        cachedNetworks: tui.cacheManager.cachedNetworks,
                        cachedVolumes: tui.cacheManager.cachedVolumes,
                        cachedPorts: tui.cacheManager.cachedPorts,
                        cachedRouters: tui.cacheManager.cachedRouters,
                        cachedComputeLimits: tui.cacheManager.cachedComputeLimits,
                        cachedNetworkQuotas: tui.cacheManager.cachedNetworkQuotas,
                        cachedVolumeQuotas: tui.cacheManager.cachedVolumeQuotas,
                        quotaScrollOffset: tui.viewCoordinator.quotaScrollOffset,
                        tui: tui
                    )
                },
                inputHandler: { [weak tui] ch, _ in
                    guard let tui = tui else { return false }

                    switch ch {
                    case Int32(259), Int32(107):  // UP arrow or k - Scroll quotas up
                        tui.viewCoordinator.quotaScrollOffset = max(tui.viewCoordinator.quotaScrollOffset - 1, 0)
                        return true

                    case Int32(258), Int32(106):  // DOWN arrow or j - Scroll quotas down
                        let maxQuotaScroll = tui.calculateMaxQuotaScrollOffset()
                        tui.viewCoordinator.quotaScrollOffset = min(tui.viewCoordinator.quotaScrollOffset + 1, maxQuotaScroll)
                        return true

                    default:
                        return false
                    }
                }
            ),

            // MARK: - Health Dashboard View
            ViewMetadata(
                identifier: healthDashboard,
                title: "Health Dashboard",
                parentViewId: dashboard.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    let telemetryActor = await tui.getTelemetryActor()
                    await HealthDashboardView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        telemetryActor: telemetryActor,
                        navigationState: tui.viewCoordinator.healthDashboardNavState,
                        dataManager: tui.dataManager,
                        performanceMonitor: tui.renderCoordinator.performanceMonitor
                    )
                },
                inputHandler: { [weak tui] ch, _ in
                    guard let tui = tui else { return false }
                    let telemetryActor = await tui.getTelemetryActor()
                    let handled = await HealthDashboardView.handleInput(
                        ch,
                        navigationState: tui.viewCoordinator.healthDashboardNavState,
                        telemetryActor: telemetryActor,
                        dataManager: tui.dataManager
                    )
                    if handled {
                        tui.forceRedraw()
                    }
                    return handled
                }
            ),

            // MARK: - Health Dashboard Service Detail View
            ViewMetadata(
                identifier: healthDashboardServiceDetail,
                title: "Service Details",
                parentViewId: healthDashboard.id,
                isDetailView: true,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    if let service = tui.viewCoordinator.selectedResource as? HealthDashboardService {
                        await HealthDashboardView.drawServiceDetail(
                            screen: screen,
                            startRow: startRow,
                            startCol: startCol,
                            width: width,
                            height: height,
                            service: service,
                            scrollOffset: tui.viewCoordinator.detailScrollOffset
                        )
                    }
                },
                inputHandler: nil
            ),

            // MARK: - Help View
            ViewMetadata(
                identifier: help,
                title: "Help",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    let contextView = tui.viewCoordinator.previousView != .help
                        ? tui.viewCoordinator.previousView
                        : .dashboard
                    await MiscViews.drawHelp(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        scrollOffset: tui.viewCoordinator.helpScrollOffset,
                        currentView: contextView
                    )
                },
                inputHandler: nil
            ),

            // MARK: - About View
            ViewMetadata(
                identifier: about,
                title: "About",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await MiscViews.drawAbout(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        scrollOffset: tui.viewCoordinator.helpScrollOffset
                    )
                },
                inputHandler: nil
            ),

            // MARK: - Welcome View
            ViewMetadata(
                identifier: welcome,
                title: "Welcome",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    let sections = WelcomeScreen.shared.getWelcomeSections()
                    let detailView = DetailView(
                        title: "Welcome to Substation",
                        sections: sections,
                        helpText: "Press ESC to return",
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                    await detailView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: nil
            ),

            // MARK: - Tutorial View
            ViewMetadata(
                identifier: tutorial,
                title: "Tutorial",
                parentViewId: welcome.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    let sections = WelcomeScreen.shared.getTutorialSections()
                    let detailView = DetailView(
                        title: "Interactive Tutorial",
                        sections: sections,
                        helpText: "Press ESC to return",
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                    await detailView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: nil
            ),

            // MARK: - Shortcuts View
            ViewMetadata(
                identifier: shortcuts,
                title: "Shortcuts",
                parentViewId: welcome.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    let sections = WelcomeScreen.shared.getShortcutsSections()
                    let detailView = DetailView(
                        title: "Command Shortcuts Reference",
                        sections: sections,
                        helpText: "Press ESC to return",
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                    await detailView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: nil
            ),

            // MARK: - Examples View
            ViewMetadata(
                identifier: examples,
                title: "Examples",
                parentViewId: welcome.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    let sections = WelcomeScreen.shared.getExamplesSections()
                    let detailView = DetailView(
                        title: "Command Workflow Examples",
                        sections: sections,
                        helpText: "Press ESC to return",
                        scrollOffset: tui.viewCoordinator.detailScrollOffset
                    )
                    await detailView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height
                    )
                },
                inputHandler: nil
            ),

            // MARK: - Advanced Search View
            ViewMetadata(
                identifier: advancedSearch,
                title: "Advanced Search",
                parentViewId: nil,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    await AdvancedSearchView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        tui: tui
                    )
                },
                inputHandler: { ch, _ in
                    return AdvancedSearchView.handleInput(ch)
                }
            ),

            // MARK: - Performance Metrics View
            ViewMetadata(
                identifier: performanceMetrics,
                title: "Performance Metrics",
                parentViewId: dashboard.id,
                isDetailView: false,
                supportsMultiSelect: false,
                category: .compute,
                renderHandler: { [weak tui] screen, startRow, startCol, width, height in
                    guard let tui = tui else { return }
                    let operations = tui.swiftBackgroundOps.getAllOperations()
                    let metricsService = PerformanceMetrics()
                    let summary = metricsService.calculate(from: operations)
                    await PerformanceMetricsView.draw(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        summary: summary,
                        scrollOffset: tui.viewCoordinator.scrollOffset
                    )
                },
                inputHandler: nil
            )
        ]
    }
}
