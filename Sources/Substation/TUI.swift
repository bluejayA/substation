import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Imports for separated modules
// Data models, view components, and utilities are now in separate files

@MainActor
final class TUI {
    // Core client with enhanced security features
    internal var client: OSClient

    // Enhanced data management
    internal lazy var dataManager: DataManager = DataManager(client: client, tui: self)
    internal lazy var inputHandler: InputHandler = InputHandler(tui: self)
    internal lazy var formInputHandler: FormInputHandler = FormInputHandler(tui: self)
    internal lazy var universalFormInputHandler: UniversalFormInputHandler = UniversalFormInputHandler(tui: self)
    internal lazy var resourceOperations: ResourceOperations = ResourceOperations(tui: self)
    internal lazy var uiHelpers: UIHelpers = UIHelpers(tui: self)

    // Selection state management
    internal let selectionManager: SelectionManager = SelectionManager()

    // View coordination management
    internal let viewCoordinator: ViewCoordinator = ViewCoordinator()

    // Refresh management
    internal let refreshManager: RefreshManager

    // Simplified services for code quality
    internal lazy var errorHandler = OperationErrorHandler(enhancedHandler: enhancedErrorHandler)
    internal let validator = ValidationService()

    // Enhanced TUI components for optimization and security
    internal let memoryContainer: SubstationMemoryContainer
    internal lazy var resourceCache: OpenStackResourceCache = memoryContainer.openStackResourceCache
    internal let userFeedback: UserFeedbackSystem

    // Cache management (MemoryKit-backed)
    internal var cacheManager: CacheManager!

    // Phase 4.3: Professional User Experience Components
    internal let progressIndicator: ProgressIndicator
    internal let enhancedErrorHandler: EnhancedErrorHandler
    internal let loadingStateManager: LoadingStateManager

    // Phase 5.1: Batch Operations Framework
    internal var batchOperationManager: BatchOperationManager

    // Phase 5.3: Advanced Search System - Now using static methods

    // Module system
    internal let moduleOrchestrator: ModuleOrchestrator

    // Render coordination - manages rendering optimization, performance monitoring, and UI caching
    internal let renderCoordinator: RenderCoordinator

    // Notification observers
    private var notificationObservers: [any NSObjectProtocol] = []


    // Session tracking
    private var sessionMetrics = SessionMetrics()
    internal var running = true

    // Phase 2: Render state tracking to prevent background interference
    internal var isFloatingIPViewRendering = false

    // Floating IP server selection state
    internal var searchQuery: String?
    internal var statusMessage: String?

    // Unified input state for navigation and search
    internal var unifiedInputState: UnifiedInputView.InputState = UnifiedInputView.InputState()
    internal var showUnifiedInput: Bool = true // Always show the input bar
    internal lazy var commandMode: CommandMode = CommandMode()
    internal lazy var contextSwitcher: ContextSwitcher = ContextSwitcher(cloudConfigManager: CloudConfigManager())

    // Background operations tracking
    internal lazy var swiftBackgroundOps: SwiftBackgroundOperationsManager = SwiftBackgroundOperationsManager()

    // Active upload tracking (for status bar display)
    internal var activeUploadMessage: String? = nil
    internal var activeUploadTask: Task<Void, Never>? = nil

    // Active download tracking (for status bar display)
    internal var activeDownloadMessage: String? = nil
    internal var activeDownloadTask: Task<Void, Never>? = nil

    // Telemetry actor for health monitoring
    internal func getTelemetryActor() async -> TelemetryActor? {
        return await client.telemetryActor
    }
    internal var screenRows: Int32 = 0
    internal var screenCols: Int32 = 0
    internal var resourceCounts = ResourceCounts()

    // MARK: - Resource Cache Accessors (MemoryKit-backed)

    // Resource name cache for UUID resolution
    internal var resourceNameCache: ResourceNameCache

    // Loading state management
    internal var loadingProgress: Int = 0
    internal var loadingMessage: String?
    internal var initialDataLoaded = false

    // Server creation form state
    internal var serverCreateForm = ServerCreateForm()
    internal var serverCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Network creation form state
    internal var networkCreateForm = NetworkCreateForm()
    internal var networkCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Security group creation form state
    internal var securityGroupCreateForm = SecurityGroupCreateForm()
    internal var securityGroupCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Subnet creation form state
    internal var subnetCreateForm = SubnetCreateForm()
    internal var subnetCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Server resize form state
    internal var serverResizeForm = ServerResizeForm()

    // Security group management form state
    internal var securityGroupForm = SecurityGroupManagementForm()
    internal var securityGroupRuleManagementForm: SecurityGroupRuleManagementForm?

    // Snapshot management form state
    internal var snapshotManagementForm = SnapshotManagementForm()
    internal var snapshotManagementFormState: FormBuilderState = FormBuilderState(fields: [])

    // Volume snapshot management form state
    internal var volumeSnapshotManagementForm = VolumeSnapshotManagementForm()
    internal var volumeSnapshotManagementFormState: FormBuilderState = FormBuilderState(fields: [])

    // Volume backup management form state
    internal var volumeBackupManagementForm = VolumeBackupManagementForm()
    internal var volumeBackupManagementFormState: FormBuilderState = FormBuilderState(fields: [])

    // Network interface management form state
    internal var networkInterfaceForm = NetworkInterfaceManagementForm()

    // Volume management form state
    internal var volumeManagementForm = VolumeManagementForm()

    // Allowed address pair management form state
    internal var allowedAddressPairForm: AllowedAddressPairManagementForm?

    // Volume snapshot list state
    internal var selectedVolumeForSnapshots: Volume? = nil
    internal var selectedSnapshotsForDeletion: Set<String> = []

    // Key pair creation form state
    internal var keyPairCreateForm = KeyPairCreateForm()
    internal var keyPairCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Volume creation form state
    internal var volumeCreateForm = VolumeCreateForm()
    internal var volumeCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Port creation form state
    internal var portCreateForm = PortCreateForm()
    internal var portCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Floating IP creation form state
    internal var floatingIPCreateForm = FloatingIPCreateForm()
    internal var floatingIPCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Router creation form state
    internal var routerCreateForm = RouterCreateForm()
    internal var routerCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Server group creation form state
    internal var serverGroupCreateForm = ServerGroupCreateForm()
    internal var serverGroupCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Server group management form state
    internal var serverGroupManagementForm = ServerGroupManagementForm()

    // Barbican secret creation form state
    internal var barbicanSecretCreateForm = BarbicanSecretCreateForm()
    internal var barbicanSecretCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Swift container creation form state
    internal var swiftContainerCreateForm = SwiftContainerCreateForm()
    internal var swiftContainerCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Swift container metadata form state
    internal var swiftContainerMetadataForm = SwiftContainerMetadataForm()
    internal var swiftContainerMetadataFormState: FormBuilderState = FormBuilderState(fields: [])

    // Swift container web access form state
    internal var swiftContainerWebAccessForm = SwiftContainerWebAccessForm()
    internal var swiftContainerWebAccessFormState: FormBuilderState = FormBuilderState(fields: [])

    // Swift object metadata form state
    internal var swiftObjectMetadataForm = SwiftObjectMetadataForm()
    internal var swiftObjectMetadataFormState: FormBuilderState = FormBuilderState(fields: [])

    // Swift directory metadata form state
    internal var swiftDirectoryMetadataForm = SwiftDirectoryMetadataForm()
    internal var swiftDirectoryMetadataFormState: FormBuilderState = FormBuilderState(fields: [])

    // Swift object upload form state
    internal var swiftObjectUploadForm = SwiftObjectUploadForm()
    internal var swiftObjectUploadFormState: FormBuilderState = FormBuilderState(fields: [])

    // Swift container download form state
    internal var swiftContainerDownloadForm = SwiftContainerDownloadForm()
    internal var swiftContainerDownloadFormState: FormBuilderState = FormBuilderState(fields: [])

    // Swift object download form state
    internal var swiftObjectDownloadForm = SwiftObjectDownloadForm()
    internal var swiftObjectDownloadFormState: FormBuilderState = FormBuilderState(fields: [])
    internal var swiftDirectoryDownloadForm = SwiftDirectoryDownloadForm()
    internal var swiftDirectoryDownloadFormState: FormBuilderState = FormBuilderState(fields: [])

    // Debug mode flag
    private var debugMode: Bool = false

    // Resource resolver for name lookups
    internal var resourceResolver: ResourceResolver

    // Existing screen from App.swift (if terminal was initialized early)
    private var existingScreen: OpaquePointer?

    init(
        client: OSClient,
        debugMode: Bool = false,
        logger: any OSClientLogger = ConsoleLogger(),
        sharedLogger: any MemoryKitLogger,
        existingScreen: OpaquePointer? = nil
    ) async throws {
        Logger.shared.logDebug("TUI initialization started")
        self.client = client
        self.debugMode = debugMode
        self.existingScreen = existingScreen
        Logger.shared.logDebug("Debug mode: \(debugMode)")
        if existingScreen != nil {
            Logger.shared.logDebug("Using existing screen from early initialization")
        }

        // Initialize Substation Memory Container with MemoryKit integration
        Logger.shared.logDebug("Initializing memory container")
        self.memoryContainer = SubstationMemoryContainer.shared

        // Initialize the memory container with custom configuration
        let memoryConfig = SubstationMemoryManager.Configuration(
            maxCacheSize: 1000,
            maxMemoryBudget: 100 * 1024 * 1024, // 100MB default
            cleanupInterval: 300.0, // 5 minutes
            enableMetrics: true,
            enableLeakDetection: debugMode,
            logger: sharedLogger
        )
        Logger.shared.logInfo("Memory container config: maxCacheSize=\(memoryConfig.maxCacheSize), maxMemoryBudget=\(memoryConfig.maxMemoryBudget), cleanupInterval=\(memoryConfig.cleanupInterval)")

        try await self.memoryContainer.initialize(with: memoryConfig)
        Logger.shared.logDebug("Memory container initialized successfully")

        // Configure SwiftNCurses to use the same shared logger
        Logger.shared.logDebug("Configuring SwiftNCurses logging")
        SwiftNCurses.configureLogging(logger: sharedLogger)

        // Initialize ResourceNameCache with MemoryKit adapter
        Logger.shared.logDebug("Creating resource name cache")
        self.resourceNameCache = self.memoryContainer.createResourceNameCache()

        // Initialize CacheManager with MemoryKit integration
        Logger.shared.logDebug("Creating cache manager")
        self.cacheManager = CacheManager(
            memoryContainer: self.memoryContainer,
            resourceNameCache: self.resourceNameCache
        )

        Logger.shared.logDebug("Initializing user feedback system")
        self.userFeedback = UserFeedbackSystem()

        // Initialize Phase 4.3 professional user experience components
        Logger.shared.logDebug("Initializing professional UX components")
        self.progressIndicator = ProgressIndicator()
        self.enhancedErrorHandler = EnhancedErrorHandler(feedbackSystem: userFeedback, logger: logger)
        self.loadingStateManager = LoadingStateManager()

        // Initialize Phase 5.1 batch operations framework
        Logger.shared.logDebug("Initializing batch operations manager with maxConcurrency=10")
        self.batchOperationManager = BatchOperationManager(
            client: self.client,
            maxConcurrency: 10  // Configurable batch operation concurrency
        )

        Logger.shared.logDebug("Initializing resource resolver")
        // Initialize with empty arrays first (will be populated after data loads)
        self.resourceResolver = ResourceResolver(
            cachedServers: [],
            cachedNetworks: [],
            cachedImages: [],
            cachedFlavors: [],
            cachedSubnets: [],
            cachedSecurityGroups: [],
            resourceNameCache: self.resourceNameCache,
            client: self.client
        )

        // Initialize RenderCoordinator (manages render optimization, performance monitoring, and UI caching)
        Logger.shared.logDebug("Initializing render coordinator")
        self.renderCoordinator = RenderCoordinator()

        // Initialize ModuleOrchestrator
        Logger.shared.logDebug("Initializing module orchestrator")
        self.moduleOrchestrator = ModuleOrchestrator()

        // Initialize RefreshManager with system-aware default interval
        Logger.shared.logDebug("Initializing refresh manager")
        self.refreshManager = RefreshManager(baseRefreshInterval: SystemCapabilities.optimalRefreshInterval())
        self.refreshManager.getCurrentView = { [weak self] in self?.viewCoordinator.currentView ?? .loading }

        // Setup enhanced features
        Logger.shared.logDebug("Setting up enhanced features")
        setupMemoryPressureMonitoring()
        setupPerformanceMonitoring()
        setupUserFeedbackIntegration()

        // Initialize SearchEngine with MemoryKit cache
        Logger.shared.logDebug("Initializing SearchEngine with MemoryKit cache")
        Task {
            await SearchEngine.shared.setSearchIndexCache(memoryContainer.searchIndexCache)
        }

        // Connect to context switcher for tab completion
        Logger.shared.logDebug("Connecting to context switcher")
        self.commandMode.contextSwitcher = self.contextSwitcher

        Logger.shared.logInfo("TUI initialization completed successfully")

        // Set swiftNavState reference on cacheManager for Swift object storage
        self.cacheManager.swiftNavState = self.viewCoordinator.swiftNavState

        // Wire up ViewCoordinator callbacks
        self.viewCoordinator.markNeedsRedraw = { [weak self] in
            self?.markNeedsRedraw()
        }
        self.viewCoordinator.markViewTransition = { [weak self] in
            self?.markViewTransition()
        }
        self.viewCoordinator.getStatusMessage = { [weak self] in
            self?.statusMessage
        }
        self.viewCoordinator.setStatusMessage = { [weak self] message in
            self?.statusMessage = message
        }
        self.viewCoordinator.getSearchQuery = { [weak self] in
            self?.searchQuery
        }
        self.viewCoordinator.setSearchQuery = { [weak self] query in
            self?.searchQuery = query
        }

        // Initialize module system
        do {
            try await self.moduleOrchestrator.initialize(with: self)
        } catch {
            // Module system initialization failed, but we can continue
            // The orchestrator has already logged the error
        }
    }

    // MARK: - Enhanced Setup Methods

    private func setupMemoryPressureMonitoring() {
        // MemoryKit provides its own monitoring and cleanup
        // No additional setup needed
    }

    private func setupPerformanceMonitoring() {
        // Performance monitoring is available but not started automatically
        // to reduce CPU overhead. Call performanceMonitor.startMonitoring()
        // manually if needed for debugging or profiling.
        Logger.shared.logDebug("Performance monitoring configured but not started automatically")

        // Note: Enhanced monitoring features would be added here when
        // PerformanceMonitor supports threshold configuration and alert handlers
    }

    private func setupUserFeedbackIntegration() {
        // Configure user feedback system with enhanced error handling
        Logger.shared.logDebug("Configuring user feedback integration")
        userFeedback.setStatusMessage("System initialized", type: .info)

        // Configure feedback preferences for performance
        // Note: These would be implemented when UserFeedbackSystem has these properties
        // userFeedback.maxNotifications = 3 // Limit to prevent UI clutter
        // userFeedback.notificationDuration = 3.0 // Shorter for better UX
        // userFeedback.enableAutoStackManagement = true

        // Create enhanced error handler (for future use)
        let _ = EnhancedErrorHandler(
            feedbackSystem: userFeedback,
            logger: ConsoleLogger()
        )

        // Setup performance optimization notifications
        setupPerformanceOptimizationNotifications()

        // MemoryKit integration complete via SubstationMemoryContainer
        // Error recovery and performance monitoring handled through memoryContainer
        Logger.shared.logDebug("TUI initialization complete - MemoryKit integration active")
    }

    private func setupPerformanceOptimizationNotifications() {
        // Listen for performance optimization events
        let observer1 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PerformanceOptimizationStarted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let optimization = userInfo["optimization"] as? String else { return }

            Task { @MainActor in
                self.userFeedback.showInfo("Auto-tuning: \(optimization)", duration: 3.0)
                self.userFeedback.setStatusMessage("Optimizing performance...", type: .info)
            }
        }
        notificationObservers.append(observer1)

        let observer2 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PerformanceOptimizationCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let optimization = userInfo["optimization"] as? String else { return }

            Task { @MainActor in
                self.userFeedback.showSuccess("Optimization completed: \(optimization)", duration: 2.0)
                self.userFeedback.setStatusMessage("Performance optimized", type: .success)
            }
        }
        notificationObservers.append(observer2)

        // Listen for other optimization events
        let observer3 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OptimizeAnimations"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            Task { @MainActor in
                // Reduce animation frequency in the UI
                self.handleAnimationOptimization()
            }
        }
        notificationObservers.append(observer3)

        let observer4 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OptimizeRendering"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            Task { @MainActor in
                // Optimize rendering frequency
                self.handleRenderingOptimization()
            }
        }
        notificationObservers.append(observer4)

        let observer5 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClearUICaches"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            Task { @MainActor in
                // Clear UI-related caches
                self.handleUICacheClearing()
            }
        }
        notificationObservers.append(observer5)
    }

    @MainActor
    private func handleAnimationOptimization() {
        // Reduce animation refresh rates
        renderCoordinator.reduceAnimationFrequency()
        userFeedback.setStatusMessage("Animations optimized for performance", type: .info)
    }

    @MainActor
    private func handleRenderingOptimization() {
        // Optimize rendering frequency
        renderCoordinator.optimizeRenderingFrequency()
        userFeedback.setStatusMessage("Rendering optimized", type: .info)
    }

    @MainActor
    private func handleUICacheClearing() {
        // Clear UI caches
        renderCoordinator.handleUICacheClearing()
        Task { await memoryContainer.clearAllCaches() }
        userFeedback.setStatusMessage("UI caches cleared", type: .info)
    }

    // MARK: - Smart Redraw Optimization

    /// Mark screen as needing redraw
    internal func markNeedsRedraw() {
        renderCoordinator.markNeedsRedraw()
    }

    /// Check if redraw is needed and throttle if necessary
    internal func shouldRedraw() -> Bool {
        return renderCoordinator.shouldRedraw()
    }

    /// Force immediate redraw (for important updates)
    internal func forceRedraw() {
        renderCoordinator.forceRedraw()
    }

    /// Mark specific UI components as dirty
    internal func markHeaderDirty() {
        renderCoordinator.markHeaderDirty()
    }

    internal func markSidebarDirty() {
        renderCoordinator.markSidebarDirty()
    }

    internal func markStatusBarDirty() {
        renderCoordinator.markStatusBarDirty()
    }

    /// Mark scroll operations for optimized rendering
    internal func markScrollOperation() {
        renderCoordinator.markScrollOperation()
    }

    /// Mark view transition for full screen redraw
    internal func markViewTransition() {
        renderCoordinator.markViewTransition()
    }

    // Cycle through available refresh intervals
    internal func cycleRefreshInterval() {
        let message = refreshManager.cycleRefreshInterval()
        statusMessage = message
        markSidebarDirty() // Update sidebar to show new interval

        Logger.shared.logUserAction("refresh_interval_changed", details: [
            "newInterval": refreshManager.baseRefreshInterval
        ])
    }

    func run() async {
        Logger.shared.logInfo("TUI.run() started")

        // Use existing screen if provided, otherwise initialize new one
        let screen: WindowHandle
        let shouldCleanup: Bool

        if let existingScreen = self.existingScreen {
            Logger.shared.logDebug("Using existing screen from early initialization")
            screen = WindowHandle(existingScreen)
            shouldCleanup = false // App.swift will handle cleanup

            // Get current screen dimensions
            screenRows = SwiftNCurses.getMaxY(screen)
            screenCols = SwiftNCurses.getMaxX(screen)
        } else {
            // Initialize terminal using SwiftNCurses abstractions
            Logger.shared.logDebug("Initializing new terminal session")
            let initResult = SwiftNCurses.initializeTerminalSession()
            guard initResult.success, let newScreen = initResult.screen else {
                let errorMsg = "Failed to initialize terminal session"
                Logger.shared.logError(errorMsg)
                print("ERROR: \(errorMsg)")
                return
            }
            screen = newScreen
            shouldCleanup = true

            // Get screen dimensions
            screenRows = initResult.rows
            screenCols = initResult.cols
            Logger.shared.logDebug("Screen dimensions: \(screenCols)x\(screenRows)")
        }

        defer {
            if shouldCleanup {
                SwiftNCurses.cleanupTerminal()
                Logger.shared.logDebug("Cleaned up terminal")
            }
        }

        if screenRows < 20 || screenCols < 80 {
            let errorMsg = "Terminal too small: need 80x20, got \(screenCols)x\(screenRows)"
            Logger.shared.logError(errorMsg)
            let surface = SwiftNCurses.surface(from: screen.pointer)
            let errorBounds = Rect(x: 0, y: 0, width: screenCols, height: 1)
            await SwiftNCurses.render(Text("Terminal too small. Need at least 80x20, got \(screenCols)x\(screenRows) - \(errorMsg)").error(), on: surface, in: errorBounds)
            SwiftNCurses.batchedRefresh(screen)
            SwiftNCurses.waitForInput(screen)
            return
        }

        Logger.shared.logInfo("Substation initialized successfully")

        // Check for first run - will show welcome as first view after loading
        let isFirstRun = WelcomeScreen.shared.isFirstRun()

        // Show loading screen for all users (first-time and existing)
        if existingScreen == nil {
            Logger.shared.logDebug("Rendering initial loading screen")
            viewCoordinator.currentView = .loading
            loadingProgress = 0
            loadingMessage = "Initializing..."
            await self.draw(screen: screen.pointer)
        } else {
            Logger.shared.logDebug("Skipping initial loading screen (already shown in App.swift)")
            viewCoordinator.currentView = .loading
        }

        // Initial data fetch with loading progression
        await performInitialDataLoadWithProgress(screen: screen.pointer)

        // After loading completes, set initial view based on first run
        if isFirstRun {
            // First run: show welcome view instead of dashboard
            Logger.shared.logInfo("First run detected - setting initial view to welcome")
            viewCoordinator.currentView = .welcome
            viewCoordinator.previousView = .welcome
            WelcomeScreen.shared.markWelcomeShown()
        }
        // Existing users: viewCoordinator.currentView remains .dashboard (default)

        Logger.shared.logInfo("Starting main event loop")

        // Main event loop with intelligent adaptive polling
        var loopIterations = 0
        var inputProcessingTime: TimeInterval = 0
        var drawTime: TimeInterval = 0
        var totalIdleTime: TimeInterval = 0
        var inputEventCount = 0
        let loopStartTime = Date()

        while running {
            let ch = SwiftNCurses.getInput(screen)

            // Handle window resize
            if ch == Int32(410) { // KEY_RESIZE
                Logger.shared.logUserAction("window_resize", details: [
                    "oldSize": "\(screenCols)x\(screenRows)"
                ])
                screenRows = SwiftNCurses.getMaxY(screen)
                screenCols = SwiftNCurses.getMaxX(screen)
                Logger.shared.logUserAction("window_resized", details: [
                    "newSize": "\(screenCols)x\(screenRows)"
                ])
                SwiftNCurses.clear(screen)
                forceRedraw() // Force immediate redraw for resize
                await self.draw(screen: screen.pointer)

                // Reset adaptive polling after resize
                renderCoordinator.markInputReceived()
                continue
            }

            // Adaptive polling: adjust sleep interval based on activity
            if ch != TUI_ERR {
                // Input received - process it
                let inputStart = Date()
                await handleInput(ch, screen: screen.pointer)
                inputProcessingTime += Date().timeIntervalSince(inputStart)
                markNeedsRedraw()

                // Reset adaptive polling for responsive input
                renderCoordinator.markInputReceived()
                inputEventCount += 1
            } else {
                // No input - apply intelligent backoff strategy
                let idleStart = Date()
                renderCoordinator.incrementIdlePolls()
                renderCoordinator.updateAdaptiveSleepInterval()

                try? await Task.sleep(nanoseconds: renderCoordinator.getCurrentSleepInterval())
                totalIdleTime += Date().timeIntervalSince(idleStart)
            }

            // Auto-refresh check - skip if user is actively navigating
            let timeSinceActivity = refreshManager.timeSinceActivity()
            let timeSinceRefresh = refreshManager.timeSinceRefresh()
            let isUserActive = refreshManager.isUserActive()

            if refreshManager.autoRefresh && timeSinceRefresh > refreshManager.refreshInterval && !isUserActive {
                Logger.shared.logUserAction("auto_refresh_triggered", details: [
                    "interval": refreshManager.refreshInterval,
                    "timeSinceLastRefresh": timeSinceRefresh,
                    "timeSinceActivity": timeSinceActivity
                ])

                // Run data refresh in background - don't force redraw before data is ready
                let refreshStart = Date()
                await dataManager.refreshAllData()
                let refreshDuration = Date().timeIntervalSince(refreshStart)
                Logger.shared.logPerformance("auto_refresh", duration: refreshDuration)
                refreshManager.markRefreshCompleted()

                // Queue redraw after data is ready (non-blocking)
                markNeedsRedraw()

                // Request refresh for health dashboard if on that view
                if viewCoordinator.currentView == .healthDashboard {
                    viewCoordinator.healthDashboardNavState.requestRefresh()
                }
            } else if refreshManager.autoRefresh && isUserActive && timeSinceRefresh > refreshManager.refreshInterval {
                Logger.shared.logDebug("Auto-refresh deferred - user active (\(String(format: "%.1f", timeSinceActivity))s ago)")

                // Update sidebar to show new last refresh time
                markSidebarDirty()

                // Force redraw after data refresh
                forceRedraw()

                // Reset adaptive polling to be responsive after refresh
                renderCoordinator.markInputReceived()
            }

            // Periodic performance logging with adaptive polling metrics
            if Date().timeIntervalSince(renderCoordinator.lastPerformanceLog) > renderCoordinator.performanceLogInterval {
                let totalRunTime = Date().timeIntervalSince(loopStartTime)
                let cpuUtilization = totalRunTime > 0 ? ((totalRunTime - totalIdleTime) / totalRunTime) * 100 : 0
                let avgSleepInterval = renderCoordinator.getCurrentSleepInterval() / 1_000_000 // Convert to ms
                let idlePolls = renderCoordinator.getConsecutiveIdlePolls()

                Logger.shared.logPerformance("event_loop_summary", duration: totalRunTime, context: [
                    "iterations": loopIterations,
                    "inputEvents": inputEventCount,
                    "avgInputProcessing_ms": inputEventCount > 0 ? String(format: "%.2f", (inputProcessingTime / TimeInterval(inputEventCount)) * 1000) : "0",
                    "totalInputProcessing_ms": String(format: "%.1f", inputProcessingTime * 1000),
                    "avgDrawTime_ms": loopIterations > 0 ? String(format: "%.2f", (drawTime / TimeInterval(loopIterations)) * 1000) : "0",
                    "iterationsPerSecond": String(format: "%.1f", TimeInterval(loopIterations) / totalRunTime),
                    "cpuUtilization_percent": String(format: "%.1f", cpuUtilization),
                    "totalIdleTime_s": String(format: "%.2f", totalIdleTime),
                    "currentSleepInterval_ms": avgSleepInterval,
                    "consecutiveIdlePolls": idlePolls,
                    "idlePollingState": idlePolls <= 5 ? "active" : idlePolls <= 15 ? "short_idle" : idlePolls <= 30 ? "medium_idle" : "deep_idle"
                ])
                renderCoordinator.lastPerformanceLog = Date()
            }

            if !running { break }

            // Periodic redraw for header clock (once per minute to reduce CPU)
            // Clock updates are not critical for user experience
            let now = Date()
            if now.timeIntervalSince(renderCoordinator.lastDrawTime) >= 60.0 {
                markHeaderDirty()  // Only redraw header instead of full screen
                renderCoordinator.lastDrawTime = now

                // Keep polling responsive during regular UI updates
                if renderCoordinator.getConsecutiveIdlePolls() > 15 {
                    renderCoordinator.setConsecutiveIdlePolls(10)
                    renderCoordinator.setCurrentSleepInterval(10_000_000)
                }
            }

            // Only draw if something changed - provides responsive updates while reducing CPU
            if renderCoordinator.needsRedraw {
                let drawStart = Date()
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            await self.draw(screen: screen.pointer)
                        }
                        try await group.next()
                    }
                } catch OpenStackError.authenticationFailed {
                    Logger.shared.logError("Draw cycle failed: Authentication session expired")
                    refreshManager.autoRefresh = false
                    statusMessage = "Session expired. Please restart the application."
                    // Switch back to dashboard view
                    viewCoordinator.currentView = .dashboard
                    forceRedraw()
                } catch {
                    Logger.shared.logError("Draw cycle failed with error: \(error)")
                    statusMessage = "Error: \(error)"
                }
                drawTime += Date().timeIntervalSince(drawStart)
                renderCoordinator.markDrawCompleted()
            }

            loopIterations += 1
            // Intelligent adaptive event loop: 5ms during activity, exponential backoff to 30ms during idle
            // Provides optimal balance of responsiveness and CPU efficiency
        }

        // Log final performance summary
        let totalRunTime = Date().timeIntervalSince(loopStartTime)
        let cpuUtilization = totalRunTime > 0 ? ((totalRunTime - totalIdleTime) / totalRunTime) * 100 : 0
        Logger.shared.logInfo("Main loop ended - Final stats", context: [
            "totalRuntime_s": String(format: "%.1f", totalRunTime),
            "totalIterations": loopIterations,
            "totalInputEvents": inputEventCount,
            "cpuUtilization_percent": String(format: "%.1f", cpuUtilization),
            "avgIterationsPerSecond": String(format: "%.1f", TimeInterval(loopIterations) / totalRunTime)
        ])
    }

    // Main async input handler - delegates to InputHandler which uses NavigationInputHandler for common keys
    internal func handleInput(_ ch: Int32, screen: OpaquePointer?) async {
        // Ignore input during loading screen
        if viewCoordinator.currentView == .loading {
            return
        }
        await inputHandler.handleInput(ch, screen: screen)
    }

    // Helper to get max index based on current view (simplified for sync performance)
    private func getMaxIndexForCurrentView() -> Int {
        switch viewCoordinator.currentView {
        case .servers: return cacheManager.cachedServers.count
        case .volumes: return cacheManager.cachedVolumes.count
        case .networks: return cacheManager.cachedNetworks.count
        case .images: return cacheManager.cachedImages.count
        case .flavors: return cacheManager.cachedFlavors.count
        case .floatingIPs: return cacheManager.cachedFloatingIPs.count
        case .routers: return cacheManager.cachedRouters.count
        case .securityGroups: return cacheManager.cachedSecurityGroups.count
        case .keyPairs: return cacheManager.cachedKeyPairs.count
        case .ports: return cacheManager.cachedPorts.count
        case .subnets: return cacheManager.cachedSubnets.count
        case .serverGroups: return cacheManager.cachedServerGroups.count
        case .barbicanSecrets: return cacheManager.cachedSecrets.count
        case .swift: return cacheManager.cachedSwiftContainers.count
        case .swiftContainerDetail: return cacheManager.cachedSwiftObjects?.count ?? 0
        default: return 0
        }
    }

















    internal func getMaxSelectionIndex() -> Int {
        return UIUtils.getMaxSelectionIndex(
            for: viewCoordinator.currentView,
            cachedServers: cacheManager.cachedServers,
            cachedNetworks: cacheManager.cachedNetworks,
            cachedVolumes: cacheManager.cachedVolumes,
            cachedImages: cacheManager.cachedImages,
            cachedFlavors: cacheManager.cachedFlavors,
            cachedKeyPairs: cacheManager.cachedKeyPairs,
            cachedSubnets: cacheManager.cachedSubnets,
            cachedPorts: cacheManager.cachedPorts,
            cachedRouters: cacheManager.cachedRouters,
            cachedFloatingIPs: cacheManager.cachedFloatingIPs,
            cachedServerGroups: cacheManager.cachedServerGroups,
            cachedSecurityGroups: cacheManager.cachedSecurityGroups,
            cachedSecrets: cacheManager.cachedSecrets,
            cachedVolumeSnapshots: cacheManager.cachedVolumeSnapshots,
            cachedVolumeBackups: cacheManager.cachedVolumeBackups,
            cachedSwiftContainers: cacheManager.cachedSwiftContainers,
            cachedSwiftObjects: cacheManager.cachedSwiftObjects,
            searchQuery: searchQuery,
            resourceResolver: resourceResolver,
            swiftNavState: viewCoordinator.swiftNavState
        )
    }

    internal func calculateMaxDetailScrollOffset() -> Int {
        // For DetailView-based views, we use a generous max scroll value
        // The DetailView itself handles bounds checking and shows "End of details" when appropriate
        // This allows scrolling to work for all detail views without needing specific calculations

        if viewCoordinator.currentView.isDetailView {
            // Allow scrolling up to 200 lines - DetailView will handle the actual limit
            // This is much simpler than trying to calculate exact line counts for each view type
            return 200
        }

        return 0
    }

    internal func calculateMaxQuotaScrollOffset() -> Int {
        // Check if we're in vertical layout mode for dashboard
        if viewCoordinator.currentView == .dashboard {
            let mainWidth = screenCols - LayoutUtilities.shared.calculateSidebarWidth(screenCols: screenCols) - 2  // Account for sidebar + separator
            let mainHeight = screenRows - 4  // Account for header/footer
            let minWidthForGrid = Int32(120)
            let minHeightForGrid = Int32(30)
            let useVerticalLayout = mainWidth < minWidthForGrid || mainHeight < minHeightForGrid

            if useVerticalLayout {
                // Vertical layout - calculate scroll based on total content height vs available height
                let panelHeight = min(mainHeight / 6, Int32(12))
                let panelSpacing = Int32(1)
                let totalPanels = 6
                let totalContentHeight = Int32(totalPanels) * (panelHeight + panelSpacing) + 2
                let availableHeight = mainHeight - 4  // Subtract header/footer space

                return max(0, Int(totalContentHeight - availableHeight))
            }
        }

        // Grid layout or other views - use original quota item calculation
        var totalQuotaItems = 0

        // Count compute quota items
        if let computeLimits = cacheManager.cachedComputeLimits {
            totalQuotaItems += 1 // Section header
            if computeLimits.instances != nil {
                totalQuotaItems += 1
            }
            if computeLimits.cores != nil {
                totalQuotaItems += 1
            }
            if computeLimits.ram != nil {
                totalQuotaItems += 1
            }
            totalQuotaItems += 1 // Section separator
        }

        // Count network quota items
        if cacheManager.cachedNetworkQuotas != nil {
            totalQuotaItems += 1 // Section header
            // NetworkQuotaSet has non-optional Int properties, so we always count them
            totalQuotaItems += 1 // network
            totalQuotaItems += 1 // router
            totalQuotaItems += 1 // port
            totalQuotaItems += 1 // Section separator
        }

        // Count volume quota items
        if cacheManager.cachedVolumeQuotas != nil {
            totalQuotaItems += 1 // Section header
            // VolumeQuotaSet has non-optional Int properties, so we always count them
            totalQuotaItems += 1 // volumes
            totalQuotaItems += 1 // gigabytes
            totalQuotaItems += 1 // snapshots
            totalQuotaItems += 1 // Section separator
        }

        // The available height in the quota panel is roughly 8 lines
        // So max scroll is total items minus visible items, with a minimum of 0
        let visibleQuotaItems = 8
        return max(0, totalQuotaItems - visibleQuotaItems)
    }

    internal func getSelectedImage() -> Image? {
        let filteredImages = cacheManager.cachedImages.filter { image in
            if searchQuery?.isEmpty ?? true {
                return true
            }
            let name = image.name ?? ""
            let id = image.id
            let query = searchQuery ?? ""
            return name.localizedCaseInsensitiveContains(query) ||
                   id.localizedCaseInsensitiveContains(query)
        }

        guard viewCoordinator.selectedIndex < filteredImages.count else { return nil }
        return filteredImages[viewCoordinator.selectedIndex]
    }

    // MARK: - View Management
    internal func changeView(to newView: ViewMode, resetSelection: Bool = true, preserveStatus: Bool = false) {
        if viewCoordinator.currentView != newView && viewCoordinator.currentView != .help {
            viewCoordinator.previousView = viewCoordinator.currentView
        }
        viewCoordinator.currentView = newView

        if resetSelection {
            viewCoordinator.selectedIndex = 0
            viewCoordinator.scrollOffset = 0
            viewCoordinator.detailScrollOffset = 0
            viewCoordinator.quotaScrollOffset = 0
            viewCoordinator.selectedResource = nil
        }

        // Special handling for flavor selection view to synchronize highlighting with selection
        if newView == .flavorSelection && serverCreateForm.flavorSelectionMode == .workloadBased {
            if !serverCreateForm.flavorRecommendations.isEmpty && serverCreateForm.selectedRecommendationIndex < serverCreateForm.flavorRecommendations.count {
                viewCoordinator.selectedIndex = serverCreateForm.selectedRecommendationIndex
            }
        }

        // Clear search when changing views
        searchQuery = nil

        // Clear status message when changing views (unless preserving)
        if !preserveStatus {
            statusMessage = nil
        }

        // Ensure data is loaded for specific views
        Task {
            switch newView {
            case .barbicanSecrets, .barbican:
                if cacheManager.cachedSecrets.isEmpty {
                    Logger.shared.logInfo("Loading Barbican secrets data on view change")
                    let _ = await DataProviderRegistry.shared.fetchData(for: "secrets", priority: .onDemand, forceRefresh: true)
                }
            case .images:
                if cacheManager.cachedImages.isEmpty {
                    Logger.shared.logInfo("Loading images data on view change")
                    let _ = await DataProviderRegistry.shared.fetchData(for: "images", priority: .onDemand, forceRefresh: true)
                }
            case .swiftContainerDetail:
                // Load objects for the selected container using navigation state
                if let containerName = viewCoordinator.swiftNavState.currentContainer {
                    Logger.shared.logInfo("Loading Swift objects for container: \(containerName)")
                    if let swiftModule = ModuleRegistry.shared.module(for: "swift") as? SwiftModule {
                        await swiftModule.fetchSwiftObjects(containerName: containerName, priority: "interactive")
                    }
                }
            default:
                break
            }
        }

        // Initialize view-specific state
        if newView == .healthDashboard {
            HealthDashboardView.resetNavigationState(viewCoordinator.healthDashboardNavState)
        }

        // Force full screen redraw for view transitions to prevent artifacts
        markViewTransition()

        // Ensure security groups are loaded when entering port creation view
        if newView == .portCreate && cacheManager.cachedSecurityGroups.isEmpty {
            Task {
                let _ = await DataProviderRegistry.shared.fetchData(for: "securitygroups", priority: .onDemand, forceRefresh: true)
            }
        }
    }

    // MARK: - Detail View Management
    internal func openDetailView() {
        guard !viewCoordinator.currentView.isDetailView else { return }

        let filteredResources: [Any]
        let targetDetailView: ViewMode

        switch viewCoordinator.currentView {
        case .servers:
            filteredResources = FilterUtils.filterServers(cacheManager.cachedServers, query: searchQuery)
            targetDetailView = .serverDetail
        case .serverGroups:
            filteredResources = FilterUtils.filterServerGroups(cacheManager.cachedServerGroups, query: searchQuery)
            targetDetailView = .serverGroupDetail
        case .networks:
            filteredResources = FilterUtils.filterNetworks(cacheManager.cachedNetworks, query: searchQuery)
            targetDetailView = .networkDetail
        case .securityGroups:
            filteredResources = FilterUtils.filterSecurityGroups(cacheManager.cachedSecurityGroups, query: searchQuery)
            targetDetailView = .securityGroupDetail
        case .volumes:
            filteredResources = FilterUtils.filterVolumes(cacheManager.cachedVolumes, query: searchQuery)
            targetDetailView = .volumeDetail
        case .images:
            filteredResources = FilterUtils.filterImages(cacheManager.cachedImages, query: searchQuery)
            targetDetailView = .imageDetail
        case .flavors:
            filteredResources = FilterUtils.filterFlavors(cacheManager.cachedFlavors, query: searchQuery)
            targetDetailView = .flavorDetail
        case .subnets:
            filteredResources = FilterUtils.filterSubnets(cacheManager.cachedSubnets, query: searchQuery)
            targetDetailView = .subnetDetail
        case .ports:
            filteredResources = FilterUtils.filterPorts(cacheManager.cachedPorts, query: searchQuery)
            targetDetailView = .portDetail
        case .routers:
            filteredResources = FilterUtils.filterRouters(cacheManager.cachedRouters, query: searchQuery)
            targetDetailView = .routerDetail
        case .keyPairs:
            filteredResources = FilterUtils.filterKeyPairs(cacheManager.cachedKeyPairs, query: searchQuery)
            targetDetailView = .keyPairDetail
        case .floatingIPs:
            filteredResources = FilterUtils.filterFloatingIPs(cacheManager.cachedFloatingIPs, query: searchQuery)
            targetDetailView = .floatingIPDetail
        case .healthDashboard:
            // Use the selected service from health dashboard navigation state
            if let selectedService = viewCoordinator.healthDashboardNavState.selectedService {
                viewCoordinator.selectedResource = selectedService
                changeView(to: .healthDashboardServiceDetail, resetSelection: false)
                viewCoordinator.detailScrollOffset = 0
                return
            } else {
                return // No service selected
            }
        case .barbicanSecrets:
            // Apply the same filtering logic as used in UIUtils.swift
            let filteredSecrets = searchQuery?.isEmpty ?? true ? cacheManager.cachedSecrets : cacheManager.cachedSecrets.filter { secret in
                (secret.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false) ||
                (secret.secretType?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false)
            }
            filteredResources = filteredSecrets
            targetDetailView = .barbicanSecretDetail
        case .volumeArchives:
            // Build unified archive list (snapshots + backups + server backups)
            var archives: [Any] = []
            archives.append(contentsOf: cacheManager.cachedVolumeSnapshots)
            archives.append(contentsOf: cacheManager.cachedVolumeBackups)

            // Add server backups (images with image_type == "snapshot")
            let serverBackups = cacheManager.cachedImages.filter { image in
                if let properties = image.properties,
                   let imageType = properties["image_type"],
                   imageType == "snapshot" {
                    return true
                }
                return false
            }
            archives.append(contentsOf: serverBackups)

            // Sort by creation date (newest first)
            archives.sort { (a, b) -> Bool in
                let aDate = getArchiveCreationDate(a)
                let bDate = getArchiveCreationDate(b)
                return aDate > bDate
            }

            // Apply search filter if needed
            if let query = searchQuery, !query.isEmpty {
                let lowercaseQuery = query.lowercased()
                archives = archives.filter { archive in
                    if let snapshot = archive as? VolumeSnapshot {
                        return (snapshot.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                               (snapshot.status?.lowercased().contains(lowercaseQuery) ?? false)
                    } else if let backup = archive as? VolumeBackup {
                        return (backup.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                               (backup.status?.lowercased().contains(lowercaseQuery) ?? false)
                    } else if let image = archive as? Image {
                        return (image.name?.lowercased().contains(lowercaseQuery) ?? false) ||
                               (image.status?.lowercased().contains(lowercaseQuery) ?? false)
                    }
                    return false
                }
            }

            filteredResources = archives
            targetDetailView = .volumeArchiveDetail
        case .swift:
            // Filter Swift containers based on search query
            let filteredContainers = searchQuery?.isEmpty ?? true ? cacheManager.cachedSwiftContainers : cacheManager.cachedSwiftContainers.filter { container in
                container.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false
            }
            filteredResources = filteredContainers
            targetDetailView = .swiftContainerDetail
        case .swiftContainerDetail:
            // When in container detail view, navigating opens object detail
            if let objects = cacheManager.cachedSwiftObjects {
                let filteredObjects = searchQuery?.isEmpty ?? true ? objects : objects.filter { object in
                    object.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false
                }
                filteredResources = filteredObjects
                targetDetailView = .swiftObjectDetail
            } else {
                return
            }
        default:
            return // No detail view available for this view type
        }

        // Helper function to get creation date from archive item
        func getArchiveCreationDate(_ archive: Any) -> Date {
            if let snapshot = archive as? VolumeSnapshot {
                return snapshot.createdAt ?? Date.distantPast
            } else if let backup = archive as? VolumeBackup {
                return backup.createdAt ?? Date.distantPast
            } else if let image = archive as? Image {
                return image.createdAt ?? Date.distantPast
            }
            return Date.distantPast
        }

        // Check if we have resources and a valid selection
        guard !filteredResources.isEmpty && viewCoordinator.selectedIndex < filteredResources.count else { return }

        // Set the selected resource and change to detail view
        viewCoordinator.selectedResource = filteredResources[viewCoordinator.selectedIndex]
        changeView(to: targetDetailView, resetSelection: false)
        viewCoordinator.detailScrollOffset = 0 // Reset detail scroll when opening
    }    // Immediate refresh for better real-time feedback after operations

    internal func refreshAfterOperation() {
        Task {
            // Enable fast refresh for next 60 seconds to show state transitions
            refreshManager.refreshAfterOperation()
            await dataManager.refreshAllData()
            refreshManager.markRefreshCompleted()
            markNeedsRedraw()
        }
    }

    private func performInitialDataLoadWithProgress(screen: OpaquePointer?) async {
        Logger.shared.logInfo("Starting initial data load with loading screen progression")

        // Step 0: Connecting
        loadingProgress = 0
        loadingMessage = "Connecting to OpenStack..."
        await draw(screen: screen)

        // Step 1: Authenticating
        loadingProgress = 1
        loadingMessage = "Authenticating..."
        await draw(screen: screen)
        await dataManager.initializeProjectID()

        // Step 2: Loading resources
        loadingProgress = 3
        loadingMessage = "Loading resources..."
        await draw(screen: screen)
        await dataManager.refreshAllData()

        // Step 4: Complete
        loadingProgress = 4
        loadingMessage = "Ready!"
        await draw(screen: screen)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay

        // Mark initial loading as complete and switch to dashboard
        initialDataLoaded = true
        viewCoordinator.currentView = .dashboard
        viewCoordinator.previousView = .dashboard
        renderCoordinator.forceRedraw()

        Logger.shared.logInfo("Initial data load completed, transitioning to dashboard")
    }

    /// Perform initial data load while displaying welcome view for first-time users
    /// Uses DetailView component with dynamic status updates during data load
    /// - Parameter screen: The screen pointer for rendering

    // Colors are now managed semantically through SwiftNCurses.drawStyledText(color: .semantic)

    internal func draw(screen: OpaquePointer?) async {
        // Only redraw if needed and throttle to prevent excessive redraws
        guard shouldRedraw() else { return }

        let drawStartTime = Date()

        Logger.shared.logDebug("Starting optimized screen draw", context: [
            "view": "\(viewCoordinator.currentView)",
            "screenSize": "\(screenCols)x\(screenRows)"
        ])

        // Get optimized render plan
        var renderPlan = renderCoordinator.getRenderPlan(screenRows: screenRows, screenCols: screenCols)

        // Override render plan for loading screen - only show main panel
        if viewCoordinator.currentView == .loading {
            renderPlan = RenderPlan(
                shouldClearScreen: true,
                renderHeader: false,
                renderSidebar: false,
                renderMainPanel: true,
                renderStatusBar: false,
                scrollOptimization: nil
            )
        }

        // Clear screen only if full redraw is needed
        if renderPlan.shouldClearScreen {
            SwiftNCurses.clear(WindowHandle(screen))
        }

        // Draw layout components based on render plan
        var componentTimings: [String: TimeInterval] = [:]

        if renderPlan.renderHeader {
            let start = Date()
            await HeaderView.draw(screen: screen, client: client, screenCols: screenCols)
            componentTimings["header"] = Date().timeIntervalSince(start)
        }

        if renderPlan.renderSidebar {
            let start = Date()
            await SidebarView.draw(screen: screen, screenCols: screenCols, screenRows: screenRows, currentView: viewCoordinator.currentView, tui: self)
            componentTimings["sidebar"] = Date().timeIntervalSince(start)
        }

        if renderPlan.renderMainPanel {
            let start = Date()
            await MainPanelView.draw(screen: screen, tui: self, screenCols: screenCols, screenRows: screenRows)
            componentTimings["mainPanel"] = Date().timeIntervalSince(start)
        }

        // Render horizontal separator line above bottom bars
        if renderPlan.renderStatusBar {
            let surface = SwiftNCurses.surface(from: screen)
            // When unified input is shown: separator at screenRows - 3 (input at -2, status at -1)
            // When no input: separator at screenRows - 2 (status at -1)
            let separatorRow = showUnifiedInput ? screenRows - 3 : screenRows - 2
            let separatorBounds = Rect(x: 0, y: separatorRow, width: screenCols, height: 1)

            // Create separator line text
            let separatorText = String(repeating: "-", count: Int(screenCols))
            let separatorComponent = Text(separatorText).info()

            await SwiftNCurses.render(separatorComponent, on: surface, in: separatorBounds)
        }

        // Render unified input bar (above status bar)
        if showUnifiedInput && renderPlan.renderStatusBar {
            let start = Date()
            await UnifiedInputBarView.draw(screen: screen, tui: self, screenCols: screenCols, screenRows: screenRows)
            componentTimings["inputBar"] = Date().timeIntervalSince(start)
        }

        if renderPlan.renderStatusBar {
            let start = Date()
            await StatusBarView.draw(screen: screen, tui: self, screenCols: screenCols, screenRows: screenRows)
            componentTimings["statusBar"] = Date().timeIntervalSince(start)
        }

        // Handle scroll optimization if available
        if let scrollOpt = renderPlan.scrollOptimization {
            Logger.shared.logDebug("Applied scroll optimization: rows \(scrollOpt.startRow)-\(scrollOpt.endRow)")
        }

        // Render modal overlay if active
        if let modal = userFeedback.currentModal {
            let start = Date()
            let surface = SwiftNCurses.surface(from: screen)
            let modalBounds = Rect(x: 0, y: 0, width: screenCols, height: screenRows)
            let modalComponent = ModalView(modal: modal)
            await SwiftNCurses.render(modalComponent, on: surface, in: modalBounds)
            componentTimings["modal"] = Date().timeIntervalSince(start)
        }

        // Batched refresh: updates virtual screen then flushes once (reduces syscalls)
        SwiftNCurses.batchedRefresh(WindowHandle(screen))

        // Mark render as clean
        renderCoordinator.markDrawCompleted()

        let totalDrawDuration = Date().timeIntervalSince(drawStartTime)

        // Log detailed draw performance with component breakdown
        var logContext = [
            "view": "\(viewCoordinator.currentView)",
            "total_ms": String(format: "%.1f", totalDrawDuration * 1000),
            "render_plan": renderPlan.description
        ]

        // Add component timings to log
        for (component, timing) in componentTimings {
            logContext["\(component)_ms"] = String(format: "%.1f", timing * 1000)
        }

        Logger.shared.logPerformance("optimized_screen_draw", duration: totalDrawDuration, context: logContext)

        // Track performance degradation
        if totalDrawDuration > 0.05 { // 50ms threshold
            Logger.shared.logWarning("Screen draw exceeded performance target: \(String(format: "%.1f", totalDrawDuration * 1000))ms")
        }
    }

    internal func confirmServer(_ itemName: String, screen: OpaquePointer?, state: String) async -> Bool {
        let _ = SwiftNCurses.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftNCurses.setNodelay(WindowHandle(screen), true)
        }

        let surface = SwiftNCurses.surface(from: screen)
        let promptLine = screenRows - 2
        let promptBounds = Rect(x: 0, y: promptLine, width: screenCols, height: 1)

        // Display confirmation prompt using SwiftNCurses
        let promptText = " \(state.capitalized) '\(itemName)'? Press Y to confirm, any other key to cancel: "
        let promptComponent = Text(promptText).warning()

        surface.clear(rect: promptBounds)
        await SwiftNCurses.render(promptComponent, on: surface, in: promptBounds)

        let ch = SwiftNCurses.getInput(WindowHandle(screen))

        // Clear prompt
        surface.clear(rect: promptBounds)

        // Only Y (both uppercase and lowercase) confirms restart
        return ch == Int32(89) || ch == Int32(121) // 'Y' or 'y'
    }


    internal func generateFlavorRecommendations(for workloadType: WorkloadType, screen: OpaquePointer?) async {
        // Check if we have cached recommendations for this workload type
        if let cachedRecs = cacheManager.cachedFlavorRecommendations[workloadType], !cachedRecs.isEmpty {
            Logger.shared.logDebug("Using cached flavor recommendations for \(workloadType.displayName)")
            serverCreateForm.flavorRecommendations = cachedRecs
            statusMessage = "Loaded \(cachedRecs.count) cached recommendations for \(workloadType.displayName)"
            forceRedraw() // Force immediate UI refresh for cached recommendations
            await self.draw(screen: screen)
            return
        }

        statusMessage = "Generating comprehensive flavor recommendations..."
        await self.draw(screen: screen)

        do {
            var recommendations: [FlavorRecommendation] = []

            // Generate recommendations for different usage scenarios
            let scenarios = generateWorkloadScenarios(for: workloadType)

            for (index, scenario) in scenarios.enumerated() {
                statusMessage = "Analyzing scenario \(index + 1)/\(scenarios.count): \(scenario.name)..."
                await self.draw(screen: screen)

                let recommendation = try await client.suggestOptimalSize(
                    workloadType: workloadType,
                    expectedLoad: scenario.loadProfile,
                    budget: scenario.budget
                )

                // Enhance the recommendation with scenario context
                let enhancedRecommendation = FlavorRecommendation(
                    recommendedFlavor: recommendation.recommendedFlavor,
                    alternativeFlavors: recommendation.alternativeFlavors,
                    reasoningScore: recommendation.reasoningScore,
                    reasoning: "SCENARIO: \(scenario.name)\n\(scenario.description)\n\n\(recommendation.reasoning)",
                    estimatedMonthlyCost: recommendation.estimatedMonthlyCost,
                    performanceProfile: recommendation.performanceProfile
                )

                recommendations.append(enhancedRecommendation)
            }

            // Update the form's workload type to match the selected one
            serverCreateForm.workloadType = workloadType

            // Sort recommendations by score (best first)
            let sortedRecommendations = recommendations.sorted { $0.reasoningScore > $1.reasoningScore }
            serverCreateForm.setFlavorRecommendations(sortedRecommendations)

            // Cache the generated recommendations for future use
            cacheManager.cachedFlavorRecommendations[workloadType] = sortedRecommendations
            Logger.shared.logDebug("Cached \(sortedRecommendations.count) recommendations for \(workloadType.displayName)")

            statusMessage = "Generated \(recommendations.count) flavor recommendations for \(workloadType.displayName)"
        } catch {
            statusMessage = "Failed to generate recommendations: \(error.localizedDescription)"
            serverCreateForm.clearFlavorRecommendations()
        }
        forceRedraw() // Force immediate UI refresh for newly generated recommendations
        await self.draw(screen: screen)
    }

    internal func generateWorkloadScenarios(for workloadType: WorkloadType) -> [(name: String, description: String, loadProfile: LoadProfile, budget: Budget)] {
        let defaultBudget = serverCreateForm.optimizationBudget ?? Budget(
            maxMonthlyCost: 1000.0,
            currency: "USD"
        )

        switch workloadType {
        case .compute:
            return [
                (
                    name: "Light Computing",
                    description: "Basic CPU tasks, development, testing",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.4,
                        diskIOPS: 500,
                        networkThroughput: 50,
                        concurrentUsers: 5
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 0.5, currency: "USD")
                ),
                (
                    name: "Intensive Computing",
                    description: "Heavy calculations, batch processing, compilation",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.9,
                        memoryUtilization: 0.6,
                        diskIOPS: 1000,
                        networkThroughput: 100,
                        concurrentUsers: 20
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "High-Performance Computing",
                    description: "Scientific computing, simulations, rendering",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.95,
                        memoryUtilization: 0.8,
                        diskIOPS: 2000,
                        networkThroughput: 200,
                        concurrentUsers: 50
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 2.0, currency: "USD")
                )
            ]

        case .memory:
            return [
                (
                    name: "Medium Memory Load",
                    description: "Application caching, small databases",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.4,
                        memoryUtilization: 0.7,
                        diskIOPS: 800,
                        networkThroughput: 100,
                        concurrentUsers: 25
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 0.7, currency: "USD")
                ),
                (
                    name: "High Memory Load",
                    description: "In-memory databases, big data analytics",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.5,
                        memoryUtilization: 0.9,
                        diskIOPS: 1500,
                        networkThroughput: 200,
                        concurrentUsers: 100
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "Extreme Memory Load",
                    description: "Large in-memory datasets, real-time analytics",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.95,
                        diskIOPS: 2500,
                        networkThroughput: 500,
                        concurrentUsers: 200
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 2.5, currency: "USD")
                )
            ]

        case .storage:
            return [
                (
                    name: "Moderate I/O",
                    description: "File servers, document storage",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.3,
                        memoryUtilization: 0.4,
                        diskIOPS: 2000,
                        networkThroughput: 200,
                        concurrentUsers: 50
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 0.6, currency: "USD")
                ),
                (
                    name: "High I/O",
                    description: "Database servers, backup systems",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.5,
                        memoryUtilization: 0.6,
                        diskIOPS: 5000,
                        networkThroughput: 500,
                        concurrentUsers: 100
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "Extreme I/O",
                    description: "High-performance databases, distributed storage",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.7,
                        diskIOPS: 10000,
                        networkThroughput: 1000,
                        concurrentUsers: 250
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 2.0, currency: "USD")
                )
            ]

        case .network:
            return [
                (
                    name: "Web Application",
                    description: "Standard web servers, API services",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.5,
                        memoryUtilization: 0.5,
                        diskIOPS: 1000,
                        networkThroughput: 500,
                        concurrentUsers: 100
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 0.7, currency: "USD")
                ),
                (
                    name: "High-Traffic Web",
                    description: "Load balancers, CDN, high-traffic sites",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.6,
                        diskIOPS: 2000,
                        networkThroughput: 2000,
                        concurrentUsers: 500
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "Network Gateway",
                    description: "Routers, gateways, network appliances",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.7,
                        memoryUtilization: 0.4,
                        diskIOPS: 1500,
                        networkThroughput: 5000,
                        concurrentUsers: 1000
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 1.5, currency: "USD")
                )
            ]

        default:
            // Balanced, GPU, Accelerated workloads
            return [
                (
                    name: "Standard Workload",
                    description: "Balanced resource usage, general applications",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.6,
                        memoryUtilization: 0.6,
                        diskIOPS: 1000,
                        networkThroughput: 200,
                        concurrentUsers: 50
                    ),
                    budget: defaultBudget
                ),
                (
                    name: "Heavy Workload",
                    description: "Resource-intensive applications",
                    loadProfile: LoadProfile(
                        cpuUtilization: 0.8,
                        memoryUtilization: 0.8,
                        diskIOPS: 2000,
                        networkThroughput: 500,
                        concurrentUsers: 100
                    ),
                    budget: Budget(maxMonthlyCost: defaultBudget.maxMonthlyCost * 1.5, currency: "USD")
                )
            ]
        }
    }
}

// MARK: - Supporting Types

private struct SessionMetrics {
    var connectionStartTime: Date?
    var connectionSuccessTime: Date?
    var connectionErrors = 0
    var frameCount = 0
}




