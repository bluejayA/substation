import Foundation
import OSClient

/// Context Switcher - Manages switching between OpenStack clouds
///
/// Provides context switching functionality for Substation,
/// allowing users to switch between different OpenStack clouds defined
/// in their clouds.yaml configuration file.
///
/// ## Features
///
/// - Parse clouds.yaml from standard OpenStack locations
/// - List available clouds via `:ctx` command
/// - Switch between clouds via `:ctx <cloud-name>` command
/// - Show current cloud in status bar
/// - Handle re-authentication when switching
/// - Invalidate caches on cloud switch
/// - Preserve current view state during switch
///
/// ## Usage
///
/// ```swift
/// let switcher = ContextSwitcher(cloudConfigManager: CloudConfigManager())
///
/// // List available clouds
/// let clouds = await switcher.availableContexts()
///
/// // Switch to a cloud
/// try await switcher.switchTo("production", client: client, tui: tui)
///
/// // Get current cloud
/// if let current = switcher.currentContext {
///     print("Using cloud: \(current)")
/// }
/// ```
///
/// ## Cloud Configuration Locations
///
/// The ContextSwitcher looks for clouds.yaml in the following locations (in order):
/// 1. `~/.config/openstack/clouds.yaml`
/// 2. `/etc/openstack/clouds.yaml`
///
@MainActor
final class ContextSwitcher: @unchecked Sendable {

    // MARK: - Properties

    /// Current active cloud name
    private(set) var currentContext: String?

    /// Cloud configuration manager
    private let cloudConfigManager: CloudConfigManager

    /// Cache of available clouds
    private var availableClouds: [String] = []

    /// Last loaded cloud configurations
    private var cloudConfigs: [String: CloudConfig] = [:]

    /// Configuration file paths to search (in order of priority)
    private let configPaths: [String]

    /// Timestamp of last configuration load
    private var lastConfigLoad: Date?

    /// Configuration cache duration (5 minutes)
    private let configCacheDuration: TimeInterval = 300

    // MARK: - Initialization

    init(cloudConfigManager: CloudConfigManager) {
        self.cloudConfigManager = cloudConfigManager

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        self.configPaths = [
            "\(homeDir)/.config/openstack/clouds.yaml",
            "/etc/openstack/clouds.yaml"
        ]
    }

    // MARK: - Cloud Discovery

    /// Get list of available cloud contexts
    ///
    /// Returns a sorted list of cloud names from all available clouds.yaml files.
    /// Caches results for 5 minutes to avoid excessive file system access.
    ///
    /// - Returns: Array of cloud names, sorted alphabetically
    func availableContexts() async -> [String] {
        // Check if cache is still valid
        if let lastLoad = lastConfigLoad,
           Date().timeIntervalSince(lastLoad) < configCacheDuration,
           !availableClouds.isEmpty {
            return availableClouds
        }

        // Reload cloud configurations
        await reloadCloudConfigurations()
        return availableClouds
    }

    /// Reload cloud configurations from disk
    ///
    /// Scans all configuration paths and loads available clouds.
    /// Updates internal cache of available clouds.
    private func reloadCloudConfigurations() async {
        var discoveredClouds: Set<String> = []
        var allConfigs: [String: CloudConfig] = [:]

        for path in configPaths {
            guard FileManager.default.fileExists(atPath: path) else {
                continue
            }

            do {
                let cloudsConfig = try await cloudConfigManager.loadCloudsConfig(path: path)

                // Merge clouds from this configuration file
                for (cloudName, config) in cloudsConfig.clouds {
                    discoveredClouds.insert(cloudName)
                    allConfigs[cloudName] = config
                }
            } catch {
                Logger.shared.logError("Failed to load clouds config from \(path): \(error.localizedDescription)")
            }
        }

        availableClouds = Array(discoveredClouds).sorted()
        cloudConfigs = allConfigs
        lastConfigLoad = Date()
    }

    /// Get information about a specific cloud context
    ///
    /// - Parameter cloudName: Name of the cloud to query
    /// - Returns: CloudInfo with configuration details, or nil if not found
    func getContextInfo(_ cloudName: String) async -> CloudInfo? {
        // Ensure we have loaded configurations
        if availableClouds.isEmpty {
            await reloadCloudConfigurations()
        }

        // Try each configuration path
        for path in configPaths {
            do {
                return try await cloudConfigManager.getCloudInfo(cloudName, path: path)
            } catch {
                continue
            }
        }

        return nil
    }

    // MARK: - Context Switching

    /// Switch to a different cloud context
    ///
    /// This performs the following operations:
    /// 1. Validates cloud exists in configuration
    /// 2. Loads cloud configuration
    /// 3. Re-authenticates OSClient with new cloud
    /// 4. Invalidates all caches
    /// 5. Refreshes current view data
    /// 6. Preserves current view state
    ///
    /// - Parameters:
    ///   - cloudName: Name of the cloud to switch to
    ///   - client: OSClient instance to re-authenticate
    ///   - tui: TUI instance for cache invalidation and view refresh
    /// - Throws: ContextSwitchError if switch fails
    func switchTo(_ cloudName: String, client: OSClient, tui: TUI) async throws {
        // Ensure cloud exists
        let clouds = await availableContexts()
        guard clouds.contains(cloudName) else {
            throw ContextSwitchError.cloudNotFound(cloudName, available: clouds)
        }

        // Load cloud configuration
        var cloudConfig: CloudConfig?
        var loadError: (any Error)?

        for path in configPaths {
            do {
                cloudConfig = try await cloudConfigManager.getCloudConfig(cloudName, path: path)
                break
            } catch {
                loadError = error
                continue
            }
        }

        guard let config = cloudConfig else {
            throw ContextSwitchError.configurationLoadFailed(
                cloudName,
                underlyingError: loadError
            )
        }

        // Store the previous context and client for rollback if needed
        let previousContext = currentContext
        let previousClient = client

        do {
            // Validate authentication config
            try await reauthenticate(client: client, config: config, cloudName: cloudName)

            // Create new OSClient with the new cloud configuration
            Logger.shared.logInfo("Creating new OSClient instance for cloud: \(cloudName)")

            // Build OSClient configuration from CloudConfig
            let newClient = try await createOSClient(from: config, cloudName: cloudName)

            // Replace the client in TUI
            tui.client = newClient

            // Update DataManager's client reference
            tui.dataManager = DataManager(client: newClient, tui: tui)

            // Update BatchOperationManager with new client
            tui.batchOperationManager = BatchOperationManager(
                client: newClient,
                maxConcurrency: 10
            )

            // Update ResourceResolver with new client
            tui.resourceResolver = ResourceResolver(
                cachedServers: tui.resourceCache.servers,
                cachedNetworks: tui.resourceCache.networks,
                cachedImages: tui.resourceCache.images,
                cachedFlavors: tui.resourceCache.flavors,
                cachedSubnets: tui.resourceCache.subnets,
                cachedSecurityGroups: tui.resourceCache.securityGroups,
                resourceNameCache: tui.resourceNameCache,
                client: newClient
            )

            // Initialize project ID for the new client
            await tui.dataManager.initializeProjectID()

            // Update current context
            currentContext = cloudName

            // Invalidate all caches
            await invalidateCaches(tui: tui)

            // Refresh current view
            await refreshView(tui: tui)

            Logger.shared.logInfo("Successfully switched to cloud context: \(cloudName)")

        } catch {
            // Rollback on failure - restore all client-dependent managers
            currentContext = previousContext
            tui.client = previousClient
            tui.dataManager = DataManager(client: previousClient, tui: tui)
            tui.batchOperationManager = BatchOperationManager(
                client: previousClient,
                maxConcurrency: 10
            )
            tui.resourceResolver = ResourceResolver(
                cachedServers: tui.resourceCache.servers,
                cachedNetworks: tui.resourceCache.networks,
                cachedImages: tui.resourceCache.images,
                cachedFlavors: tui.resourceCache.flavors,
                cachedSubnets: tui.resourceCache.subnets,
                cachedSecurityGroups: tui.resourceCache.securityGroups,
                resourceNameCache: tui.resourceNameCache,
                client: previousClient
            )

            throw ContextSwitchError.switchFailed(
                cloudName,
                underlyingError: error
            )
        }
    }

    // MARK: - Authentication

    /// Re-authenticate OSClient with new cloud configuration
    ///
    /// - Parameters:
    ///   - client: OSClient to re-authenticate (will be replaced with new instance)
    ///   - config: Cloud configuration
    ///   - cloudName: Name of the cloud being switched to
    /// - Throws: ContextSwitchError if authentication fails
    private func reauthenticate(
        client: OSClient,
        config: CloudConfig,
        cloudName: String
    ) async throws {
        // Extract authentication parameters from config
        let auth = config.auth

        // Validate required fields
        guard !auth.auth_url.isEmpty else {
            throw ContextSwitchError.invalidConfiguration(
                cloudName,
                reason: "Missing auth_url"
            )
        }

        // Create new OSClient instance for the new cloud
        // OSClient is initialized with the auth configuration during creation
        // The existing client will be replaced by the caller (switchTo method)

        Logger.shared.logInfo("Creating new OSClient for cloud: \(cloudName)")
        Logger.shared.logInfo("Auth URL: \(auth.auth_url)")
        Logger.shared.logInfo("Project: \(auth.project_name ?? "default")")

        // Note: The actual OSClient creation and authentication happens in switchTo()
        // This method validates that we have the required auth configuration
    }

    /// Create a new OSClient from CloudConfig
    ///
    /// - Parameters:
    ///   - config: Cloud configuration
    ///   - cloudName: Name of the cloud
    /// - Returns: Authenticated OSClient instance
    /// - Throws: ContextSwitchError if client creation fails
    private func createOSClient(from config: CloudConfig, cloudName: String) async throws -> OSClient {
        let auth = config.auth

        // Build auth URL using common utility method
        let authURL: URL
        do {
            authURL = try CloudConfigManager.validateAndNormalizeAuthURL(auth.auth_url, cloudName: cloudName)
        } catch {
            throw ContextSwitchError.invalidConfiguration(
                cloudName,
                reason: "Invalid auth_url: \(auth.auth_url)"
            )
        }

        // Determine region
        let configuredRegion = config.primaryRegionName

        // If no region configured, try to extract from auth URL
        var region = configuredRegion
        if region == nil {
            // Try to extract region from URL (e.g., "sjc3" from "keystone.api.sjc3.rackspacecloud.com")
            if let host = authURL.host {
                let components = host.split(separator: ".")
                if components.count >= 3, components[1] == "api" {
                    region = String(components[2]).uppercased()
                    Logger.shared.logInfo("Extracted region from auth URL: \(region!)")
                }
            }
        }

        let finalRegion = region ?? "RegionOne"
        Logger.shared.logInfo("ContextSwitcher - Region config: configured=\(configuredRegion ?? "nil"), detected=\(region ?? "nil"), using=\(finalRegion)")

        // Determine domains
        let projectDomain = auth.project_domain_name ?? "Default"
        let userDomain = auth.user_domain_name ?? "Default"

        // Determine SSL verification setting from cloud configuration
        let verifySSL: Bool
        if let insecure = auth.insecure, insecure {
            verifySSL = false
        } else if let verify = auth.verify {
            let verifyLower = verify.lowercased()
            verifySSL = !(verifyLower == "false" || verifyLower == "0" || verifyLower == "no")
        } else {
            verifySSL = true
        }

        // Build OSClient config
        let osConfig = OpenStackConfig(
            authURL: authURL,
            region: finalRegion,
            userDomainName: userDomain,
            projectDomainName: projectDomain,
            verifySSL: verifySSL
        )

        // Determine credentials type
        let credentials: OpenStackCredentials

        if let appCredID = auth.application_credential_id, let appCredSecret = auth.application_credential_secret {
            // Application credential by ID
            Logger.shared.logInfo("Using application credential (by ID) for cloud: \(cloudName)")
            credentials = .applicationCredential(
                id: appCredID,
                secret: appCredSecret,
                projectName: auth.project_name,
                projectID: auth.project_id
            )
        } else if let username = auth.username, let password = auth.password {
            // Password authentication
            Logger.shared.logInfo("Using password authentication for cloud: \(cloudName)")
            credentials = .password(
                username: username,
                password: password,
                projectName: auth.project_name,
                projectID: auth.project_id,
                userDomainName: userDomain,
                userDomainID: auth.user_domain_id,
                projectDomainName: projectDomain,
                projectDomainID: auth.project_domain_id
            )
        } else {
            throw ContextSwitchError.invalidConfiguration(
                cloudName,
                reason: "No valid authentication method found (need username/password or application_credential_id/secret)"
            )
        }

        // Create and authenticate client
        do {
            Logger.shared.logInfo("Attempting to connect and authenticate with cloud: \(cloudName)")
            var client = try await OSClient.connect(
                config: osConfig,
                credentials: credentials,
                logger: LoggerBridge()
            )

            // Verify authentication succeeded
            let isAuth = client.isAuthenticated
            Logger.shared.logInfo("OSClient.connect() completed - isAuthenticated: \(isAuth)")

            if !isAuth {
                Logger.shared.logError("OSClient created but not authenticated!")
                throw ContextSwitchError.switchFailed(
                    cloudName,
                    underlyingError: OpenStackError.authenticationFailed
                )
            }

            // If region was not configured or extracted from URL, try to detect from catalog
            if configuredRegion == nil && region == nil {
                Logger.shared.logInfo("No region configured or detected from URL, attempting catalog detection")
                if let detectedRegion = try? await RegionDetection.detectFromCatalog(
                    authURL: authURL,
                    credentials: credentials,
                    failOnMultiple: false
                ) {
                    Logger.shared.logInfo("Detected region from catalog: \(detectedRegion)")

                    // Reconnect with the detected region
                    let newConfig = OpenStackConfig(
                        authURL: authURL,
                        region: detectedRegion,
                        userDomainName: userDomain,
                        projectDomainName: projectDomain,
                        verifySSL: verifySSL
                    )

                    client = try await OSClient.connect(
                        config: newConfig,
                        credentials: credentials,
                        logger: LoggerBridge()
                    )

                    Logger.shared.logInfo("Reconnected with detected region: \(detectedRegion)")
                }
            }

            Logger.shared.logInfo("Successfully authenticated with cloud: \(cloudName) with region: \(finalRegion)")
            return client
        } catch {
            Logger.shared.logError("Failed to create/authenticate OSClient: \(error)")
            throw ContextSwitchError.switchFailed(
                cloudName,
                underlyingError: error
            )
        }
    }

    // MARK: - Cache Management

    /// Invalidate all caches after context switch
    ///
    /// Clears resource caches, search indexes, and topology data
    /// to ensure fresh data from the new cloud.
    ///
    /// - Parameter tui: TUI instance with caches to invalidate
    private func invalidateCaches(tui: TUI) async {
        Logger.shared.logInfo("Invalidating caches after context switch")

        // Clear resource cache
        await tui.resourceCache.clearAll()

        // Clear search indexes
        await tui.memoryContainer.searchIndexCache.clearAll()

        // Clear relationship cache
        await tui.memoryContainer.relationshipCache.clearAll()

        Logger.shared.logInfo("Cache invalidation complete")
    }

    // MARK: - View Refresh

    /// Refresh current view after context switch
    ///
    /// Reloads data for the current view while preserving view state
    /// (selected items, scroll position, etc.)
    ///
    /// - Parameter tui: TUI instance to refresh
    private func refreshView(tui: TUI) async {
        Logger.shared.logInfo("Refreshing view after context switch")

        // Store current view state
        let selectedIndex = tui.viewCoordinator.selectedIndex
        let scrollOffset = tui.viewCoordinator.scrollOffset

        // Trigger data reload for current view
        // This will fetch fresh data from the new cloud
        // Force a full refresh since we've switched clouds (bypass throttle)
        await tui.dataManager.forceFullRefresh()

        // Restore view state (with bounds checking)
        tui.viewCoordinator.selectedIndex = selectedIndex
        tui.viewCoordinator.scrollOffset = scrollOffset

        // Force UI redraw to show new data
        tui.forceRedraw()

        Logger.shared.logInfo("View refresh complete")
    }

    // MARK: - Helper Methods

    /// Validate that a cloud name exists in configuration
    ///
    /// - Parameter cloudName: Cloud name to validate
    /// - Returns: true if cloud exists, false otherwise
    func isValidContext(_ cloudName: String) async -> Bool {
        let clouds = await availableContexts()
        return clouds.contains(cloudName)
    }

    /// Get the default cloud (first alphabetically)
    ///
    /// - Returns: Name of the default cloud, or nil if no clouds available
    func defaultContext() async -> String? {
        let clouds = await availableContexts()
        return clouds.first
    }

    /// Format context list for display
    ///
    /// - Returns: Formatted string showing all available clouds
    func formatContextList() async -> String {
        let clouds = await availableContexts()

        if clouds.isEmpty {
            return "No clouds configured. Please add clouds to ~/.config/openstack/clouds.yaml"
        }

        var output = "Available clouds:\n"
        for cloud in clouds {
            let marker = cloud == currentContext ? "*" : " "
            output += "\(marker) \(cloud)\n"
        }

        if let current = currentContext {
            output += "\nCurrent: \(current)"
        } else {
            output += "\nNo cloud selected"
        }

        return output
    }
}

// MARK: - Context Switch Errors

enum ContextSwitchError: Error, LocalizedError {
    case cloudNotFound(String, available: [String])
    case configurationLoadFailed(String, underlyingError: (any Error)?)
    case invalidConfiguration(String, reason: String)
    case authenticationFailed(String, underlyingError: (any Error)?)
    case switchFailed(String, underlyingError: (any Error)?)
    case cacheInvalidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cloudNotFound(let cloudName, let available):
            if available.isEmpty {
                return "Cloud '\(cloudName)' not found. No clouds are configured."
            } else {
                return "Cloud '\(cloudName)' not found. Available clouds: \(available.joined(separator: ", "))"
            }

        case .configurationLoadFailed(let cloudName, let error):
            if let error = error {
                return "Failed to load configuration for cloud '\(cloudName)': \(error.localizedDescription)"
            } else {
                return "Failed to load configuration for cloud '\(cloudName)'"
            }

        case .invalidConfiguration(let cloudName, let reason):
            return "Invalid configuration for cloud '\(cloudName)': \(reason)"

        case .authenticationFailed(let cloudName, let error):
            if let error = error {
                return "Authentication failed for cloud '\(cloudName)': \(error.localizedDescription)"
            } else {
                return "Authentication failed for cloud '\(cloudName)'"
            }

        case .switchFailed(let cloudName, let error):
            if let error = error {
                return "Failed to switch to cloud '\(cloudName)': \(error.localizedDescription)"
            } else {
                return "Failed to switch to cloud '\(cloudName)'"
            }

        case .cacheInvalidationFailed(let details):
            return "Failed to invalidate caches: \(details)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cloudNotFound(_, let available):
            if available.isEmpty {
                return "Add cloud configurations to ~/.config/openstack/clouds.yaml"
            } else {
                return "Use one of the available clouds: \(available.joined(separator: ", "))"
            }

        case .configurationLoadFailed:
            return "Check that your clouds.yaml file exists and is properly formatted"

        case .invalidConfiguration:
            return "Review and correct the cloud configuration in clouds.yaml"

        case .authenticationFailed:
            return "Verify your credentials and auth_url in clouds.yaml"

        case .switchFailed:
            return "Check network connectivity and cloud configuration"

        case .cacheInvalidationFailed:
            return "Try restarting the application"
        }
    }
}
