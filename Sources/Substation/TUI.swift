import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftTUI
import MemoryKit

// MARK: - Default Logger Implementation

/// Default silent logger for TUI when none is provided
private final class DefaultTUILogger: MemoryKitLogger, @unchecked Sendable {
    func logDebug(_ message: String, context: [String: Any]) {}
    func logInfo(_ message: String, context: [String: Any]) {}
    func logWarning(_ message: String, context: [String: Any]) {}
    func logError(_ message: String, context: [String: Any]) {}
}

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
    internal lazy var resourceOperations: ResourceOperations = ResourceOperations(tui: self)
    internal lazy var actions: Actions = Actions(tui: self)
    internal lazy var uiHelpers: UIHelpers = UIHelpers(tui: self)

    // Simplified services for code quality
    internal lazy var errorHandler = OperationErrorHandler(enhancedHandler: enhancedErrorHandler)
    internal let validator = ValidationService()

    // Enhanced TUI components for optimization and security
    internal let memoryContainer: SubstationMemoryContainer
    internal lazy var resourceCache: OpenStackResourceCache = memoryContainer.openStackResourceCache
    internal let userFeedback: UserFeedbackSystem

    // Phase 4.3: Professional User Experience Components
    internal let progressIndicator: ProgressIndicator
    internal let enhancedErrorHandler: EnhancedErrorHandler
    internal let loadingStateManager: LoadingStateManager

    // Phase 5.1: Batch Operations Framework
    internal let batchOperationManager: BatchOperationManager

    // Phase 5.3: Advanced Search System - Now using static methods

    // Performance optimization
    internal var renderOptimizer = RenderOptimizer()
    var performanceMonitor: PerformanceMonitor

    // Notification observers
    private var notificationObservers: [any NSObjectProtocol] = []

    // Virtual list controllers for optimization
    private var virtualListControllers: [String: VirtualListController] = [:]
    internal var searchControllers: [String: ListSearchController] = [:]


    // Session tracking
    private var sessionMetrics = SessionMetrics()
    internal var currentView: ViewMode = .loading
    internal var previousView: ViewMode = .loading
    internal var running = true

    // Phase 2: Render state tracking to prevent background interference
    internal var isFloatingIPViewRendering = false
    internal var scrollOffset = 0
    internal var helpScrollOffset = 0
    internal var detailScrollOffset = 0  // For scrolling within detail views
    internal var quotaScrollOffset = 0   // For scrolling within quota panel on dashboard
    internal var selectedIndex = 0  // Currently selected item in lists
    internal var selectedResource: Any? = nil  // The selected resource for detail view
    internal var selectedServers: Set<String> = Set<String>()  // Selected server IDs for network attachment
    internal var attachedServerIds: Set<String> = Set<String>()  // Server IDs that have the selected resource attached
    internal var attachmentMode: AttachmentMode = .attach  // Current attachment mode (attach/detach)
    // Multi-select mode state
    internal var multiSelectMode: Bool = false  // Whether multi-select mode is enabled
    internal var multiSelectedResourceIDs: Set<String> = Set<String>()  // IDs of selected resources in multi-select mode
    // Floating IP server management (single-select)
    internal var selectedServerId: String? = nil  // Selected server ID for floating IP management
    internal var attachedServerId: String? = nil  // Server ID that has the selected floating IP attached
    // Floating IP port management (single-select)
    internal var selectedPortId: String? = nil  // Selected port ID for floating IP management
    internal var attachedPortId: String? = nil  // Port ID that has the selected floating IP attached
    // Subnet router management (single-select)
    internal var selectedRouterId: String? = nil  // Selected router ID for subnet management
    internal var attachedRouterIds: Set<String> = []  // Router IDs that have the selected subnet attached

    // Search result navigation
    internal var searchSelectedResourceId: String? = nil  // Resource ID selected from search to view in detail

    // Floating IP server selection state
    internal var searchQuery: String?
    internal var statusMessage: String?

    // Unified input state for navigation and search
    internal var unifiedInputState: UnifiedInputView.InputState = UnifiedInputView.InputState()
    internal var showUnifiedInput: Bool = true // Always show the input bar
    internal lazy var commandMode: CommandMode = CommandMode()
    internal lazy var contextSwitcher: ContextSwitcher = ContextSwitcher(cloudConfigManager: CloudConfigManager())

    // Health Dashboard navigation state
    internal lazy var healthDashboardNavState: HealthDashboardView.NavigationState = HealthDashboardView.NavigationState()

    // Telemetry actor for health monitoring
    internal func getTelemetryActor() async -> TelemetryActor? {
        return await client.telemetryActor
    }
    internal var screenRows: Int32 = 0
    internal var screenCols: Int32 = 0
    internal var resourceCounts = ResourceCounts()
    internal var lastRefresh = Date()
    internal var autoRefresh = true // Enabled by default to show live state changes
    // Use system-aware default refresh interval based on CPU cores
    internal var baseRefreshInterval: TimeInterval = SystemCapabilities.optimalRefreshInterval()
    private let availableIntervals: [TimeInterval] = [3.0, 5.0, 7.0, 10.0, 15.0, 30.0]
    private var fastRefreshUntil: Date? = nil // Temporary fast refresh after operations
    internal var lastUserActivityTime = Date() // Track last user input for smart refresh
    private let activityCooldownPeriod: TimeInterval = 3.0 // Wait 3s after activity before auto-refresh

    private var refreshInterval: TimeInterval {
        // Use fast refresh (3s) temporarily after operations to show state transitions
        if let until = fastRefreshUntil, Date() < until {
            return 3.0
        }
        // Use very fast refresh rate for floating IP view to show state changes immediately
        if currentView == .floatingIPs || currentView == .floatingIPServerSelect {
            return 1.0  // 1 second for immediate updates on floating IP changes
        }
        return baseRefreshInterval  // 10 seconds for other views
    }

    // Smart redraw optimization
    internal var needsRedraw = true
    internal var lastDrawTime: Date = Date()
    internal var redrawThrottleInterval: TimeInterval = 0.032 // ~30fps
    internal var lastPerformanceLog: Date = Date()
    internal var performanceLogInterval: TimeInterval = 30.0 // Log every 30 seconds

    // Advanced rendering optimization
    internal var previousScrollOffset = 0

    // Performance tracking for scroll operations
    internal var lastScrollTime: Date = Date()
    internal var scrollEventCount = 0
    internal var scrollBatchTimer: Timer?

    // Adaptive event loop state
    private var lastInputTime: Date = Date()
    private var consecutiveIdlePolls: Int = 0
    private var currentSleepInterval: UInt64 = 5_000_000 // Start at 5ms

    // MARK: - Resource Cache Accessors (MemoryKit-backed)

    // Computed properties that access the MemoryKit-backed resource cache
    internal var cachedServers: [Server] {
        get { resourceCache.servers }
        set { Task { await resourceCache.setServers(newValue) } }
    }
    internal var cachedServerGroups: [ServerGroup] {
        get { resourceCache.serverGroups }
        set { Task { await resourceCache.setServerGroups(newValue) } }
    }
    internal var cachedNetworks: [Network] {
        get { resourceCache.networks }
        set { Task { await resourceCache.setNetworks(newValue) } }
    }
    internal var cachedVolumes: [Volume] {
        get { resourceCache.volumes }
        set { Task { await resourceCache.setVolumes(newValue) } }
    }
    internal var cachedImages: [Image] {
        get { resourceCache.images }
        set { Task { await resourceCache.setImages(newValue) } }
    }
    internal var cachedVolumeTypes: [VolumeType] {
        get { resourceCache.volumeTypes }
        set { Task { await resourceCache.setVolumeTypes(newValue) } }
    }
    internal var cachedPorts: [Port] {
        get { resourceCache.ports }
        set { Task { await resourceCache.setPorts(newValue) } }
    }
    internal var cachedRouters: [Router] {
        get { resourceCache.routers }
        set { Task { await resourceCache.setRouters(newValue) } }
    }
    internal var cachedFloatingIPs: [FloatingIP] {
        get { resourceCache.floatingIPs }
        set { Task { await resourceCache.setFloatingIPs(newValue) } }
    }
    internal var cachedFlavors: [Flavor] {
        get { resourceCache.flavors }
        set { Task { await resourceCache.setFlavors(newValue) } }
    }
    internal var cachedSubnets: [Subnet] {
        get { resourceCache.subnets }
        set { Task { await resourceCache.setSubnets(newValue) } }
    }
    internal var cachedSecurityGroups: [SecurityGroup] {
        get { resourceCache.securityGroups }
        set { Task { await resourceCache.setSecurityGroups(newValue) } }
    }
    internal var cachedKeyPairs: [KeyPair] {
        get { resourceCache.keyPairs }
        set { Task { await resourceCache.setKeyPairs(newValue) } }
    }
    internal var cachedQoSPolicies: [QoSPolicy] {
        get { resourceCache.qosPolicies }
        set { Task { await resourceCache.setQoSPolicies(newValue) } }
    }
    internal var cachedAvailabilityZones: [String] {
        get { resourceCache.availabilityZones }
        set { Task { await resourceCache.setAvailabilityZones(newValue) } }
    }
    internal var cachedSecrets: [Secret] {
        get { resourceCache.secrets }
        set { Task { await resourceCache.setSecrets(newValue) } }
    }
    internal var cachedBarbicanContainers: [BarbicanContainer] {
        get { resourceCache.barbicanContainers }
        set { Task { await resourceCache.setBarbicanContainers(newValue) } }
    }
    internal var cachedLoadBalancers: [LoadBalancer] {
        get { resourceCache.loadBalancers }
        set { Task { await resourceCache.setLoadBalancers(newValue) } }
    }
    internal var cachedSwiftContainers: [SwiftContainer] {
        get { resourceCache.swiftContainers }
        set { Task { await resourceCache.setSwiftContainers(newValue) } }
    }
    internal var cachedSwiftObjects: [SwiftObject]? {
        get { resourceCache.swiftObjects }
        set { Task { await resourceCache.setSwiftObjects(newValue) } }
    }

    // Cached flavor recommendations for all workload types
    internal var cachedFlavorRecommendations: [WorkloadType: [FlavorRecommendation]] {
        get { resourceCache.flavorRecommendations }
        set { Task { await resourceCache.setFlavorRecommendations(newValue) } }
    }
    internal var lastRecommendationsRefresh: Date {
        resourceCache.recommendationsRefreshTime
    }

    // Quota data
    internal var cachedComputeQuotas: ComputeQuotaSet? {
        get { resourceCache.computeQuotas }
        set { Task { await resourceCache.setComputeQuotas(newValue) } }
    }
    internal var cachedNetworkQuotas: NetworkQuotaSet? {
        get { resourceCache.networkQuotas }
        set { Task { await resourceCache.setNetworkQuotas(newValue) } }
    }
    internal var cachedVolumeQuotas: VolumeQuotaSet? {
        get { resourceCache.volumeQuotas }
        set { Task { await resourceCache.setVolumeQuotas(newValue) } }
    }
    internal var cachedComputeLimits: ComputeQuotaSet? {
        get { resourceCache.computeLimits }
        set { Task { await resourceCache.setComputeLimits(newValue) } }
    }

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
    internal var cachedVolumeSnapshots: [VolumeSnapshot] {
        get { resourceCache.volumeSnapshots }
        set { Task { await resourceCache.setVolumeSnapshots(newValue) } }
    }
    internal var cachedVolumeBackups: [VolumeBackup] {
        get { resourceCache.volumeBackups }
        set { Task { await resourceCache.setVolumeBackups(newValue) } }
    }
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

        // Configure SwiftTUI to use the same shared logger
        Logger.shared.logDebug("Configuring SwiftTUI logging")
        SwiftTUI.configureLogging(logger: sharedLogger)

        // Initialize ResourceNameCache with MemoryKit adapter
        Logger.shared.logDebug("Creating resource name cache")
        self.resourceNameCache = self.memoryContainer.createResourceNameCache()

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

        // Initialize PerformanceMonitor without dataManager initially
        Logger.shared.logDebug("Initializing performance monitor")
        self.performanceMonitor = PerformanceMonitor()

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

        // Connect command mode to context switcher for tab completion
        Logger.shared.logDebug("Connecting command mode to context switcher")
        self.commandMode.contextSwitcher = self.contextSwitcher

        Logger.shared.logInfo("TUI initialization completed successfully")
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
        renderOptimizer.reduceAnimationFrequency()
        userFeedback.setStatusMessage("Animations optimized for performance", type: .info)
    }

    @MainActor
    private func handleRenderingOptimization() {
        // Optimize rendering frequency
        renderOptimizer.optimizeRenderingFrequency()
        userFeedback.setStatusMessage("Rendering optimized", type: .info)
    }

    @MainActor
    private func handleUICacheClearing() {
        // Clear UI caches
        virtualListControllers.removeAll()
        searchControllers.removeAll()
        Task { await memoryContainer.clearAllCaches() }
        userFeedback.setStatusMessage("UI caches cleared", type: .info)
    }

    private func handleMemoryPressure() async {
        // Clear caches through the memory container
        await memoryContainer.clearAllCaches()

        // Clear render optimizer caches
        renderOptimizer.markFullScreenDirty()

        // Clear virtual list controllers to reduce memory
        virtualListControllers.removeAll()
        searchControllers.removeAll()

        // Clear MemoryKit-backed resource cache
        await resourceCache.clearAll()

        // Trigger refresh to reload essential data
        await dataManager.refreshAllData()

        // Show user notification
        userFeedback.showInfo("Memory pressure handled - caches cleared")
    }

    // MARK: - Smart Redraw Optimization

    // Mark screen as needing redraw
    internal func markNeedsRedraw() {
        needsRedraw = true
        renderOptimizer.markMainPanelDirty()
    }

    // Check if redraw is needed and throttle if necessary
    internal func shouldRedraw() -> Bool {
        return renderOptimizer.shouldRender(force: needsRedraw)
    }

    // Force immediate redraw (for important updates)
    internal func forceRedraw() {
        needsRedraw = true
        renderOptimizer.markFullScreenDirty()
        lastDrawTime = Date(timeIntervalSince1970: 0) // Force past throttle
    }

    // Mark specific UI components as dirty
    internal func markHeaderDirty() {
        renderOptimizer.markHeaderDirty()
    }

    internal func markSidebarDirty() {
        renderOptimizer.markSidebarDirty()
    }

    internal func markStatusBarDirty() {
        renderOptimizer.markStatusBarDirty()
    }

    // Mark scroll operations for optimized rendering
    internal func markScrollOperation() {
        renderOptimizer.markMainPanelDirty()
        needsRedraw = true
    }

    // Mark view transition for full screen redraw
    internal func markViewTransition() {
        renderOptimizer.markViewTransitionDirty()
        needsRedraw = true
    }

    // Cycle through available refresh intervals
    internal func cycleRefreshInterval() {
        guard let currentIndex = availableIntervals.firstIndex(of: baseRefreshInterval) else {
            baseRefreshInterval = availableIntervals[0]
            markSidebarDirty()
            return
        }

        let nextIndex = (currentIndex + 1) % availableIntervals.count
        baseRefreshInterval = availableIntervals[nextIndex]
        statusMessage = "Refresh interval set to \(Int(baseRefreshInterval)) seconds"
        markSidebarDirty() // Update sidebar to show new interval

        Logger.shared.logUserAction("refresh_interval_changed", details: [
            "newInterval": baseRefreshInterval,
            "availableIntervals": availableIntervals
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
            screenRows = SwiftTUI.getMaxY(screen)
            screenCols = SwiftTUI.getMaxX(screen)
        } else {
            // Initialize terminal using SwiftTUI abstractions
            Logger.shared.logDebug("Initializing new terminal session")
            let initResult = SwiftTUI.initializeTerminalSession()
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
                SwiftTUI.cleanupTerminal()
                Logger.shared.logDebug("Cleaned up terminal")
            }
        }

        if screenRows < 20 || screenCols < 80 {
            let errorMsg = "Terminal too small: need 80x20, got \(screenCols)x\(screenRows)"
            Logger.shared.logError(errorMsg)
            let surface = SwiftTUI.surface(from: screen.pointer)
            let errorBounds = Rect(x: 0, y: 0, width: screenCols, height: 1)
            await SwiftTUI.render(Text("Terminal too small. Need at least 80x20, got \(screenCols)x\(screenRows) - \(errorMsg)").error(), on: surface, in: errorBounds)
            SwiftTUI.batchedRefresh(screen)
            SwiftTUI.waitForInput(screen)
            return
        }

        Logger.shared.logInfo("Substation initialized successfully")

        // Show loading screen immediately before any data operations (if not already shown)
        if existingScreen == nil {
            Logger.shared.logDebug("Rendering initial loading screen")
            currentView = .loading
            loadingProgress = 0
            loadingMessage = "Initializing..."
            await self.draw(screen: screen.pointer)
        } else {
            Logger.shared.logDebug("Skipping initial loading screen (already shown in App.swift)")
            currentView = .loading
        }

        // Initial data fetch with loading progression
        await performInitialDataLoadWithProgress(screen: screen.pointer)

        Logger.shared.logInfo("Starting main event loop")

        // Main event loop with intelligent adaptive polling
        var loopIterations = 0
        var inputProcessingTime: TimeInterval = 0
        var drawTime: TimeInterval = 0
        var totalIdleTime: TimeInterval = 0
        var inputEventCount = 0
        let loopStartTime = Date()

        while running {
            let ch = SwiftTUI.getInput(screen)

            // Handle window resize
            if ch == Int32(410) { // KEY_RESIZE
                Logger.shared.logUserAction("window_resize", details: [
                    "oldSize": "\(screenCols)x\(screenRows)"
                ])
                screenRows = SwiftTUI.getMaxY(screen)
                screenCols = SwiftTUI.getMaxX(screen)
                Logger.shared.logUserAction("window_resized", details: [
                    "newSize": "\(screenCols)x\(screenRows)"
                ])
                SwiftTUI.clear(screen)
                forceRedraw() // Force immediate redraw for resize
                await self.draw(screen: screen.pointer)

                // Reset adaptive polling after resize
                consecutiveIdlePolls = 0
                currentSleepInterval = 5_000_000
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
                lastInputTime = Date()
                consecutiveIdlePolls = 0
                currentSleepInterval = 5_000_000 // 5ms for active periods
                inputEventCount += 1
            } else {
                // No input - apply intelligent backoff strategy
                let idleStart = Date()
                consecutiveIdlePolls += 1

                // Exponential backoff with caps:
                // 0-5 polls: 5ms (responsive for immediate input)
                // 6-15 polls: 10ms (short idle)
                // 16-30 polls: 20ms (medium idle)
                // 31+ polls: 30ms (long idle, saves CPU)
                if consecutiveIdlePolls <= 5 {
                    currentSleepInterval = 5_000_000 // 5ms
                } else if consecutiveIdlePolls <= 15 {
                    currentSleepInterval = 10_000_000 // 10ms
                } else if consecutiveIdlePolls <= 30 {
                    currentSleepInterval = 20_000_000 // 20ms
                } else {
                    currentSleepInterval = 30_000_000 // 30ms max for deep idle
                }

                try? await Task.sleep(nanoseconds: currentSleepInterval)
                totalIdleTime += Date().timeIntervalSince(idleStart)
            }

            // Auto-refresh check - skip if user is actively navigating
            let timeSinceActivity = Date().timeIntervalSince(lastUserActivityTime)
            let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
            let isUserActive = timeSinceActivity < activityCooldownPeriod

            if autoRefresh && timeSinceRefresh > refreshInterval && !isUserActive {
                Logger.shared.logUserAction("auto_refresh_triggered", details: [
                    "interval": refreshInterval,
                    "timeSinceLastRefresh": timeSinceRefresh,
                    "timeSinceActivity": timeSinceActivity
                ])

                // Run data refresh in background - don't force redraw before data is ready
                let refreshStart = Date()
                await dataManager.refreshAllData()
                let refreshDuration = Date().timeIntervalSince(refreshStart)
                Logger.shared.logPerformance("auto_refresh", duration: refreshDuration)
                lastRefresh = Date()

                // Queue redraw after data is ready (non-blocking)
                markNeedsRedraw()

                // Request refresh for health dashboard if on that view
                if currentView == .healthDashboard {
                    healthDashboardNavState.requestRefresh()
                }
            } else if autoRefresh && isUserActive && timeSinceRefresh > refreshInterval {
                Logger.shared.logDebug("Auto-refresh deferred - user active (\(String(format: "%.1f", timeSinceActivity))s ago)")

                // Update sidebar to show new last refresh time
                markSidebarDirty()

                // Force redraw after data refresh
                forceRedraw()

                // Reset adaptive polling to be responsive after refresh
                consecutiveIdlePolls = 0
                currentSleepInterval = 5_000_000
            }

            // Periodic performance logging with adaptive polling metrics
            if Date().timeIntervalSince(lastPerformanceLog) > performanceLogInterval {
                let totalRunTime = Date().timeIntervalSince(loopStartTime)
                let cpuUtilization = totalRunTime > 0 ? ((totalRunTime - totalIdleTime) / totalRunTime) * 100 : 0
                let avgSleepInterval = currentSleepInterval / 1_000_000 // Convert to ms

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
                    "consecutiveIdlePolls": consecutiveIdlePolls,
                    "idlePollingState": consecutiveIdlePolls <= 5 ? "active" : consecutiveIdlePolls <= 15 ? "short_idle" : consecutiveIdlePolls <= 30 ? "medium_idle" : "deep_idle"
                ])
                lastPerformanceLog = Date()
            }

            if !running { break }

            // Periodic redraw for header clock (once per minute to reduce CPU)
            // Clock updates are not critical for user experience
            let now = Date()
            if now.timeIntervalSince(lastDrawTime) >= 60.0 {
                markHeaderDirty()  // Only redraw header instead of full screen
                lastDrawTime = now

                // Keep polling responsive during regular UI updates
                if consecutiveIdlePolls > 15 {
                    consecutiveIdlePolls = 10
                    currentSleepInterval = 10_000_000
                }
            }

            // Only draw if something changed - provides responsive updates while reducing CPU
            if needsRedraw {
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
                    autoRefresh = false
                    statusMessage = "Session expired. Please restart the application."
                    // Switch back to dashboard view
                    currentView = .dashboard
                    forceRedraw()
                } catch {
                    Logger.shared.logError("Draw cycle failed with error: \(error)")
                    statusMessage = "Error: \(error)"
                }
                drawTime += Date().timeIntervalSince(drawStart)
                needsRedraw = false
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
        if currentView == .loading {
            return
        }
        await inputHandler.handleInput(ch, screen: screen)
    }

    // Helper to get max index based on current view (simplified for sync performance)
    private func getMaxIndexForCurrentView() -> Int {
        switch currentView {
        case .servers: return cachedServers.count
        case .volumes: return cachedVolumes.count
        case .networks: return cachedNetworks.count
        case .images: return cachedImages.count
        case .flavors: return cachedFlavors.count
        case .floatingIPs: return cachedFloatingIPs.count
        case .routers: return cachedRouters.count
        case .securityGroups: return cachedSecurityGroups.count
        case .keyPairs: return cachedKeyPairs.count
        case .ports: return cachedPorts.count
        case .subnets: return cachedSubnets.count
        case .serverGroups: return cachedServerGroups.count
        case .barbicanSecrets: return cachedSecrets.count
        default: return 0
        }
    }

















    internal func getMaxSelectionIndex() -> Int {
        return UIUtils.getMaxSelectionIndex(
            for: currentView,
            cachedServers: cachedServers,
            cachedNetworks: cachedNetworks,
            cachedVolumes: cachedVolumes,
            cachedImages: cachedImages,
            cachedFlavors: cachedFlavors,
            cachedKeyPairs: cachedKeyPairs,
            cachedSubnets: cachedSubnets,
            cachedPorts: cachedPorts,
            cachedRouters: cachedRouters,
            cachedFloatingIPs: cachedFloatingIPs,
            cachedServerGroups: cachedServerGroups,
            cachedSecurityGroups: cachedSecurityGroups,
            cachedSecrets: cachedSecrets,
            cachedVolumeSnapshots: cachedVolumeSnapshots,
            cachedVolumeBackups: cachedVolumeBackups,
            searchQuery: searchQuery,
            resourceResolver: resourceResolver
        )
    }

    internal func calculateMaxDetailScrollOffset() -> Int {
        // For DetailView-based views, we use a generous max scroll value
        // The DetailView itself handles bounds checking and shows "End of details" when appropriate
        // This allows scrolling to work for all detail views without needing specific calculations

        if currentView.isDetailView {
            // Allow scrolling up to 200 lines - DetailView will handle the actual limit
            // This is much simpler than trying to calculate exact line counts for each view type
            return 200
        }

        return 0
    }

    internal func calculateMaxQuotaScrollOffset() -> Int {
        // Check if we're in vertical layout mode for dashboard
        if currentView == .dashboard {
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
        if let computeLimits = cachedComputeLimits {
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
        if cachedNetworkQuotas != nil {
            totalQuotaItems += 1 // Section header
            // NetworkQuotaSet has non-optional Int properties, so we always count them
            totalQuotaItems += 1 // network
            totalQuotaItems += 1 // router
            totalQuotaItems += 1 // port
            totalQuotaItems += 1 // Section separator
        }

        // Count volume quota items
        if cachedVolumeQuotas != nil {
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
        let filteredImages = cachedImages.filter { image in
            if searchQuery?.isEmpty ?? true {
                return true
            }
            let name = image.name ?? ""
            let id = image.id
            let query = searchQuery ?? ""
            return name.localizedCaseInsensitiveContains(query) ||
                   id.localizedCaseInsensitiveContains(query)
        }

        guard selectedIndex < filteredImages.count else { return nil }
        return filteredImages[selectedIndex]
    }

    private func getServerSnapshots() -> [Image] {
        return ResourceFilters.filterServerSnapshots(cachedImages)
    }

    // MARK: - View Management
    internal func changeView(to newView: ViewMode, resetSelection: Bool = true, preserveStatus: Bool = false) {
        if currentView != newView && currentView != .help {
            previousView = currentView
        }
        currentView = newView

        if resetSelection {
            selectedIndex = 0
            scrollOffset = 0
            detailScrollOffset = 0
            quotaScrollOffset = 0
            selectedResource = nil
        }

        // Special handling for flavor selection view to synchronize highlighting with selection
        if newView == .flavorSelection && serverCreateForm.flavorSelectionMode == .workloadBased {
            if !serverCreateForm.flavorRecommendations.isEmpty && serverCreateForm.selectedRecommendationIndex < serverCreateForm.flavorRecommendations.count {
                selectedIndex = serverCreateForm.selectedRecommendationIndex
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
                if cachedSecrets.isEmpty {
                    Logger.shared.logInfo("Loading Barbican secrets data on view change")
                    await dataManager.refreshSecretsData()
                }
            case .images:
                if cachedImages.isEmpty {
                    Logger.shared.logInfo("Loading images data on view change")
                    await dataManager.refreshImageData()
                }
            default:
                break
            }
        }

        // Initialize view-specific state
        if newView == .healthDashboard {
            HealthDashboardView.resetNavigationState(healthDashboardNavState)
        }

        // Force full screen redraw for view transitions to prevent artifacts
        markViewTransition()

        // Ensure security groups are loaded when entering port creation view
        if newView == .portCreate && cachedSecurityGroups.isEmpty {
            Task {
                await dataManager.refreshSecurityGroupData()
            }
        }
    }

    // MARK: - Detail View Management
    internal func openDetailView() {
        guard !currentView.isDetailView else { return }

        let filteredResources: [Any]
        let targetDetailView: ViewMode

        switch currentView {
        case .servers:
            filteredResources = FilterUtils.filterServers(cachedServers, query: searchQuery)
            targetDetailView = .serverDetail
        case .serverGroups:
            filteredResources = FilterUtils.filterServerGroups(cachedServerGroups, query: searchQuery)
            targetDetailView = .serverGroupDetail
        case .networks:
            filteredResources = FilterUtils.filterNetworks(cachedNetworks, query: searchQuery)
            targetDetailView = .networkDetail
        case .securityGroups:
            filteredResources = FilterUtils.filterSecurityGroups(cachedSecurityGroups, query: searchQuery)
            targetDetailView = .securityGroupDetail
        case .volumes:
            filteredResources = FilterUtils.filterVolumes(cachedVolumes, query: searchQuery)
            targetDetailView = .volumeDetail
        case .images:
            filteredResources = FilterUtils.filterImages(cachedImages, query: searchQuery)
            targetDetailView = .imageDetail
        case .flavors:
            filteredResources = FilterUtils.filterFlavors(cachedFlavors, query: searchQuery)
            targetDetailView = .flavorDetail
        case .subnets:
            filteredResources = FilterUtils.filterSubnets(cachedSubnets, query: searchQuery)
            targetDetailView = .subnetDetail
        case .ports:
            filteredResources = FilterUtils.filterPorts(cachedPorts, query: searchQuery)
            targetDetailView = .portDetail
        case .routers:
            filteredResources = FilterUtils.filterRouters(cachedRouters, query: searchQuery)
            targetDetailView = .routerDetail
        case .keyPairs:
            filteredResources = FilterUtils.filterKeyPairs(cachedKeyPairs, query: searchQuery)
            targetDetailView = .keyPairDetail
        case .floatingIPs:
            filteredResources = FilterUtils.filterFloatingIPs(cachedFloatingIPs, query: searchQuery)
            targetDetailView = .floatingIPDetail
        case .healthDashboard:
            // Use the selected service from health dashboard navigation state
            if let selectedService = healthDashboardNavState.selectedService {
                selectedResource = selectedService
                changeView(to: .healthDashboardServiceDetail, resetSelection: false)
                detailScrollOffset = 0
                return
            } else {
                return // No service selected
            }
        case .barbicanSecrets:
            // Apply the same filtering logic as used in UIUtils.swift
            let filteredSecrets = searchQuery?.isEmpty ?? true ? cachedSecrets : cachedSecrets.filter { secret in
                (secret.name?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false) ||
                (secret.secretType?.lowercased().contains(searchQuery?.lowercased() ?? "") ?? false)
            }
            filteredResources = filteredSecrets
            targetDetailView = .barbicanSecretDetail
        case .volumeArchives:
            // Build unified archive list (snapshots + backups + server backups)
            var archives: [Any] = []
            archives.append(contentsOf: cachedVolumeSnapshots)
            archives.append(contentsOf: cachedVolumeBackups)

            // Add server backups (images with image_type == "snapshot")
            let serverBackups = cachedImages.filter { image in
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
        guard !filteredResources.isEmpty && selectedIndex < filteredResources.count else { return }

        // Set the selected resource and change to detail view
        selectedResource = filteredResources[selectedIndex]
        changeView(to: targetDetailView, resetSelection: false)
        detailScrollOffset = 0 // Reset detail scroll when opening
    }    // Immediate refresh for better real-time feedback after operations

    internal func refreshAfterOperation() {
        Task {
            // Enable fast refresh for next 60 seconds to show state transitions
            fastRefreshUntil = Date().addingTimeInterval(60.0)
            await dataManager.refreshAllData()
            lastRefresh = Date()
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
        currentView = .dashboard
        previousView = .dashboard
        needsRedraw = true
        renderOptimizer.markFullScreenDirty()

        Logger.shared.logInfo("Initial data load completed, transitioning to dashboard")
    }

    // Colors are now managed semantically through SwiftTUI.drawStyledText(color: .semantic)

    internal func draw(screen: OpaquePointer?) async {
        // Only redraw if needed and throttle to prevent excessive redraws
        guard shouldRedraw() else { return }

        let drawStartTime = Date()

        Logger.shared.logDebug("Starting optimized screen draw", context: [
            "view": "\(currentView)",
            "screenSize": "\(screenCols)x\(screenRows)"
        ])

        // Get optimized render plan
        var renderPlan = renderOptimizer.getRenderPlan(screenRows: screenRows, screenCols: screenCols)

        // Override render plan for loading screen - only show main panel
        if currentView == .loading {
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
            SwiftTUI.clear(WindowHandle(screen))
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
            await SidebarView.draw(screen: screen, screenCols: screenCols, screenRows: screenRows, currentView: currentView, tui: self)
            componentTimings["sidebar"] = Date().timeIntervalSince(start)
        }

        if renderPlan.renderMainPanel {
            let start = Date()
            await MainPanelView.draw(screen: screen, tui: self, screenCols: screenCols, screenRows: screenRows)
            componentTimings["mainPanel"] = Date().timeIntervalSince(start)
        }

        // Render horizontal separator line above bottom bars
        if renderPlan.renderStatusBar {
            let surface = SwiftTUI.surface(from: screen)
            // When unified input is shown: separator at screenRows - 3 (input at -2, status at -1)
            // When no input: separator at screenRows - 2 (status at -1)
            let separatorRow = showUnifiedInput ? screenRows - 3 : screenRows - 2
            let separatorBounds = Rect(x: 0, y: separatorRow, width: screenCols, height: 1)

            // Create separator line text
            let separatorText = String(repeating: "-", count: Int(screenCols))
            let separatorComponent = Text(separatorText).info()

            await SwiftTUI.render(separatorComponent, on: surface, in: separatorBounds)
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

        // Batched refresh: updates virtual screen then flushes once (reduces syscalls)
        SwiftTUI.batchedRefresh(WindowHandle(screen))

        // Mark render as clean
        renderOptimizer.markClean()
        needsRedraw = false

        let totalDrawDuration = Date().timeIntervalSince(drawStartTime)

        // Log detailed draw performance with component breakdown
        var logContext = [
            "view": "\(currentView)",
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
        let _ = SwiftTUI.setNodelay(WindowHandle(screen), false)
        defer {
            let _ = SwiftTUI.setNodelay(WindowHandle(screen), true)
        }

        let surface = SwiftTUI.surface(from: screen)
        let promptLine = screenRows - 2
        let promptBounds = Rect(x: 0, y: promptLine, width: screenCols, height: 1)

        // Display confirmation prompt using SwiftTUI
        let promptText = " \(state.capitalized) '\(itemName)'? Press Y to confirm, any other key to cancel: "
        let promptComponent = Text(promptText).warning()

        surface.clear(rect: promptBounds)
        await SwiftTUI.render(promptComponent, on: surface, in: promptBounds)

        let ch = SwiftTUI.getInput(WindowHandle(screen))

        // Clear prompt
        surface.clear(rect: promptBounds)

        // Only Y (both uppercase and lowercase) confirms restart
        return ch == Int32(89) || ch == Int32(121) // 'Y' or 'y'
    }

    // Helper function to describe decoding errors in detail
    internal func describingDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing value for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error: \(error.localizedDescription)"
        }
    }

    // MARK: - Enhanced Search and Details Methods

    private func performEnhancedSearch(_ searchQuery: String) {
        self.searchQuery = searchQuery

        switch currentView {
        case .servers:
            searchControllers["servers"]?.updateQuery(searchQuery)
        case .networks:
            searchControllers["networks"]?.updateQuery(searchQuery)
        case .volumes:
            searchControllers["volumes"]?.updateQuery(searchQuery)
        default:
            break
        }

        userFeedback.showInfo("Searching for '\(searchQuery)'")
    }

    private func showServerDetails(_ server: Server) async {
        var details = [
            "Name: \(server.name ?? "Unnamed")",
            "ID: \(server.id)",
            "Status: \(server.status?.rawValue ?? "Unknown")",
            "Flavor: \(server.flavor?.name ?? server.flavor?.id ?? "Unknown")",
            "Image: \(server.image?.name ?? server.image?.id ?? "Unknown")"
        ]

        if let addresses = server.addresses {
            details.append("Addresses:")
            for (network, addressList) in addresses {
                for address in addressList {
                    details.append("  \(network): \(address.addr)")
                }
            }
        }

        userFeedback.showInfo("Server Details:\n\(details.joined(separator: "\n"))")
    }

    private func showNetworkDetails(_ network: Network) async {
        let details = [
            "Name: \(network.name ?? "Unknown")",
            "ID: \(network.id)",
            "Status: \(network.status ?? "Unknown")",
            "Admin State: \(network.adminStateUp ?? false ? "Up" : "Down")",
            "Shared: \(network.shared ?? false ? "Yes" : "No")",
            "External: \(network.external ?? false ? "Yes" : "No")"
        ].joined(separator: "\n")

        userFeedback.showInfo("Network Details:\n\(details)")
    }

    private func showVolumeDetails(_ volume: Volume) async {
        let details = [
            "Name: \(volume.name ?? "Unnamed")",
            "ID: \(volume.id)",
            "Status: \(volume.status ?? "Unknown")",
            "Size: \(volume.size ?? 0) GB",
            "Volume Type: \(volume.volumeType ?? "Unknown")",
            "Bootable: \(volume.bootable == "true" ? "Yes" : "No")",
            "Encrypted: \(volume.encrypted ?? false ? "Yes" : "No")"
        ].joined(separator: "\n")

        userFeedback.showInfo("Volume Details:\n\(details)")
    }

    // MARK: - Batch Operations

    /// Execute a batch server creation operation
    internal func executeBatchServerCreate(configs: [ServerCreateConfig]) async {
        let operationType = OperationType.batchServerCreate(serverCount: configs.count)
        let operationId = UUID().uuidString

        Logger.shared.logInfo("TUI - Starting batch server creation: \(configs.count) servers")

        // Start progress tracking
        progressIndicator.startBatchOperation(
            id: operationId,
            type: operationType,
            name: "Batch Server Creation",
            totalItems: configs.count
        )

        // Execute the batch operation
        let operation = BatchOperationType.serverBulkCreate(configs: configs)
        let result = await batchOperationManager.execute(operation) { @Sendable [weak self] progress in
            Task { @MainActor in
                self?.progressIndicator.updateBatchProgress(progress)
            }
        }

        // Handle results
        await uiHelpers.handleBatchOperationResult(result)
    }

    /// Execute a batch server deletion operation
    internal func executeBatchServerDelete(serverIDs: [String]) async {
        let operationType = OperationType.batchServerDelete(serverCount: serverIDs.count)
        let operationId = UUID().uuidString

        Logger.shared.logInfo("TUI - Starting batch server deletion: \(serverIDs.count) servers")

        // Start progress tracking
        progressIndicator.startBatchOperation(
            id: operationId,
            type: operationType,
            name: "Batch Server Deletion",
            totalItems: serverIDs.count
        )

        // Execute the batch operation
        let operation = BatchOperationType.serverBulkDelete(serverIDs: serverIDs)
        let result = await batchOperationManager.execute(operation) { @Sendable [weak self] progress in
            Task { @MainActor in
                self?.progressIndicator.updateBatchProgress(progress)
            }
        }

        // Handle results
        await uiHelpers.handleBatchOperationResult(result)
    }

    /// Execute a batch volume creation operation
    internal func executeBatchVolumeCreate(configs: [VolumeCreateConfig]) async {
        let operationType = OperationType.batchVolumeCreate(volumeCount: configs.count)
        let operationId = UUID().uuidString

        Logger.shared.logInfo("TUI - Starting batch volume creation: \(configs.count) volumes")

        // Start progress tracking
        progressIndicator.startBatchOperation(
            id: operationId,
            type: operationType,
            name: "Batch Volume Creation",
            totalItems: configs.count
        )

        // Execute the batch operation
        let operation = BatchOperationType.volumeBulkCreate(configs: configs)
        let result = await batchOperationManager.execute(operation) { @Sendable [weak self] progress in
            Task { @MainActor in
                self?.progressIndicator.updateBatchProgress(progress)
            }
        }

        // Handle results
        await uiHelpers.handleBatchOperationResult(result)
    }

    /// Execute a batch volume attachment operation
    internal func executeBatchVolumeAttach(operations: [VolumeAttachmentOperation]) async {
        let operationType = OperationType.batchVolumeAttach(attachmentCount: operations.count)
        let operationId = UUID().uuidString

        Logger.shared.logInfo("TUI - Starting batch volume attachment: \(operations.count) attachments")

        // Start progress tracking
        progressIndicator.startBatchOperation(
            id: operationId,
            type: operationType,
            name: "Batch Volume Attachment",
            totalItems: operations.count
        )

        // Execute the batch operation
        let operation = BatchOperationType.volumeBulkAttach(operations: operations)
        let result = await batchOperationManager.execute(operation) { @Sendable [weak self] progress in
            Task { @MainActor in
                self?.progressIndicator.updateBatchProgress(progress)
            }
        }

        // Handle results
        await uiHelpers.handleBatchOperationResult(result)
    }

    /// Execute a network topology deployment
    internal func executeNetworkTopologyDeployment(topology: NetworkTopologyDeployment) async {
        let operationType = OperationType.batchNetworkTopology(resourceCount: topology.totalResourceCount)
        let operationId = UUID().uuidString

        Logger.shared.logInfo("TUI - Starting network topology deployment: \(topology.name)")

        // Start progress tracking
        progressIndicator.startBatchOperation(
            id: operationId,
            type: operationType,
            name: "Network Topology Deployment",
            totalItems: topology.totalResourceCount
        )

        // Execute the batch operation
        let operation = BatchOperationType.networkTopologyDeploy(topology: topology)
        let result = await batchOperationManager.execute(operation) { @Sendable [weak self] progress in
            Task { @MainActor in
                self?.progressIndicator.updateBatchProgress(progress)
            }
        }

        // Handle results
        await uiHelpers.handleBatchOperationResult(result)
    }

    /// Execute a resource cleanup operation
    internal func executeResourceCleanup(criteria: ResourceCleanupCriteria) async {
        let estimatedResourceCount = 10 // Placeholder - would be calculated based on criteria
        let operationType = OperationType.batchResourceCleanup(resourceCount: estimatedResourceCount)
        let operationId = UUID().uuidString

        Logger.shared.logInfo("TUI - Starting resource cleanup operation")

        // Start progress tracking
        progressIndicator.startBatchOperation(
            id: operationId,
            type: operationType,
            name: "Resource Cleanup",
            totalItems: estimatedResourceCount
        )

        // Execute the batch operation
        let operation = BatchOperationType.resourceCleanup(criteria: criteria)
        let result = await batchOperationManager.execute(operation) { @Sendable [weak self] progress in
            Task { @MainActor in
                self?.progressIndicator.updateBatchProgress(progress)
            }
        }

        // Handle results
        await uiHelpers.handleBatchOperationResult(result)
    }

    /// Handle the results of a batch operation

    /// Get active batch operations for UI display
    internal func getActiveBatchOperations() -> [String: OperationProgress] {
        return progressIndicator.activeOperations
    }

    /// Cancel a batch operation
    internal func cancelBatchOperation(operationId: String) async -> Bool {
        Logger.shared.logInfo("TUI - Cancelling batch operation: \(operationId)")
        let cancelled = await batchOperationManager.cancelOperation(operationID: operationId)

        if cancelled {
            statusMessage = "Batch operation cancelled"
            markNeedsRedraw()
        }

        return cancelled
    }

    // MARK: - Enhanced Resource Management

    // MARK: - Batch Operations Access
    internal func getActiveBatchOperations() async -> [String] {
        return await batchOperationManager.getActiveOperations()
    }

    internal func getBatchOperationStatus(operationID: String) async -> BatchOperationResult? {
        return await batchOperationManager.getOperationStatus(operationID: operationID)
    }


    internal func generateFlavorRecommendations(for workloadType: WorkloadType, screen: OpaquePointer?) async {
        // Check if we have cached recommendations for this workload type
        if let cachedRecs = cachedFlavorRecommendations[workloadType], !cachedRecs.isEmpty {
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
            cachedFlavorRecommendations[workloadType] = sortedRecommendations
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

private struct PerformanceMetrics {
    let averageFPS: Double
    let averageFrameTime: TimeInterval
    let averageRenderTime: TimeInterval
    let memoryUsage: Double
}
