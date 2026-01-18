import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OSClient
import MemoryKit
import SwiftNCurses

// MARK: - Substation Logger Implementations

/// Bridge from MemoryKitLogger to Substation Logger
/// This ensures all MemoryKit logs go through the centralized Substation Logger
private final class SubstationLogger: MemoryKitLogger, @unchecked Sendable {
    func logDebug(_ message: String, context: [String: Any]) {
        // Convert [String: Any] to [String: any Sendable]
        let sendableContext = convertContext(context)
        Logger.shared.logDebug(message, context: sendableContext)
    }

    func logInfo(_ message: String, context: [String: Any]) {
        let sendableContext = convertContext(context)
        Logger.shared.logInfo(message, context: sendableContext)
    }

    func logWarning(_ message: String, context: [String: Any]) {
        let sendableContext = convertContext(context)
        Logger.shared.logWarning(message, context: sendableContext)
    }

    func logError(_ message: String, context: [String: Any]) {
        let sendableContext = convertContext(context)
        Logger.shared.logError(message, context: sendableContext)
    }

    private func convertContext(_ context: [String: Any]) -> [String: any Sendable] {
        var sendableContext: [String: any Sendable] = [:]
        for (key, value) in context {
            switch value {
            case let string as String:
                sendableContext[key] = string
            case let int as Int:
                sendableContext[key] = int
            case let double as Double:
                sendableContext[key] = double
            case let bool as Bool:
                sendableContext[key] = bool
            default:
                sendableContext[key] = String(describing: value)
            }
        }
        return sendableContext
    }
}

/// Silent logger implementation for non-debug mode
private final class SilentSubstationLogger: MemoryKitLogger, @unchecked Sendable {
    func logDebug(_ message: String, context: [String: Any]) {}
    func logInfo(_ message: String, context: [String: Any]) {}
    func logWarning(_ message: String, context: [String: Any]) {}
    func logError(_ message: String, context: [String: Any]) {}
}

// MARK: - OSClient Logger Bridge
internal struct LoggerBridge: OpenStackClientLogger {
    func logError(_ message: String, context: [String: any Sendable]) {
        Logger.shared.logError(message, context: context)
    }

    func logInfo(_ message: String, context: [String: any Sendable]) {
        Logger.shared.logInfo(message, context: context)
    }

    func logDebug(_ message: String, context: [String: any Sendable]) {
        Logger.shared.logDebug(message, context: context)
    }

    func logAPICall(_ method: String, url: String, statusCode: Int?, duration: TimeInterval?) {
        Logger.shared.logAPICall(method, url: url, statusCode: statusCode, duration: duration)
    }
}

@main
struct Substation {
    static func main() async {
        // Parse command line arguments
        let arguments = CommandLine.arguments

        // Handle completion subcommand first (before any other parsing)
        if arguments.count >= 2 && arguments[1] == "completion" {
            if arguments.count >= 3 {
                printCompletion(shell: arguments[2])
                return
            } else {
                printCompletionUsage()
                exit(1)
            }
        }

        var cloudName: String?
        var configPath: String?
        var listClouds = false
        var showHelp = false
        var debugMode = false

        // Track whether values came from CLI (higher precedence than env vars)
        var cloudNameFromCLI = false
        var configPathFromCLI = false

        Logger.shared.logDebug("Application started with arguments: \(arguments)")

        // Simple argument parsing - process all arguments first
        var i = 1
        while i < arguments.count {
            let arg = arguments[i]
            switch arg {
            case "--cloud", "-c":
                if i + 1 < arguments.count {
                    cloudName = arguments[i + 1]
                    cloudNameFromCLI = true
                    i += 1
                } else {
                    printError("--cloud option requires a cloud name")
                    printUsage()
                    exit(1)
                }
            case "--config":
                if i + 1 < arguments.count {
                    configPath = arguments[i + 1]
                    configPathFromCLI = true
                    i += 1
                } else {
                    printError("--config option requires a file path")
                    printUsage()
                    exit(1)
                }
            case "--list-clouds":
                listClouds = true
            case "--help", "-h":
                showHelp = true
            case "--wiretap":
                debugMode = true
            default:
                if !arg.hasPrefix("-") && cloudName == nil {
                    cloudName = arg
                    cloudNameFromCLI = true
                } else {
                    printError("Unknown option: \(arg)")
                    printUsage()
                    exit(1)
                }
            }
            i += 1
        }

        // Apply environment variables if not overridden by CLI arguments
        if !cloudNameFromCLI, let osCloud = ProcessInfo.processInfo.environment["OS_CLOUD"] {
            cloudName = osCloud
            Logger.shared.logDebug("Using cloud from OS_CLOUD environment variable: \(osCloud)")
        }

        if !configPathFromCLI, let osConfigFile = ProcessInfo.processInfo.environment["OS_CLIENT_CONFIG_FILE"] {
            configPath = osConfigFile
            Logger.shared.logDebug("Using config file from OS_CLIENT_CONFIG_FILE environment variable: \(osConfigFile)")
        }

        // Configure logger immediately after parsing arguments
        Logger.shared.configure(debugEnabled: debugMode)

        // Log system capabilities for diagnostics
        Logger.shared.logInfo("System capabilities", context: SystemCapabilities.getSystemInfo())

        // Handle special actions after all arguments are parsed
        if showHelp {
            Logger.shared.logDebug("Showing help and exiting")
            printUsage()
            return
        }

        if listClouds {
            Logger.shared.logDebug("Listing clouds and exiting")
            await listCloudsAction(configPath: configPath)
            return
        }

        let configManager = CloudConfigManager()

        // If no cloud specified, try to use first available cloud
        if cloudName == nil {
            Logger.shared.logDebug("No cloud specified, attempting to auto-select")
            do {
                let availableClouds = try await configManager.listAvailableClouds(path: configPath)
                Logger.shared.logDebug("Found \(availableClouds.count) available clouds")
                if availableClouds.isEmpty {
                    Logger.shared.logError("No clouds found in configuration file")
                    printError("No clouds found in configuration file")
                    printUsage()
                    exit(1)
                } else if availableClouds.count == 1 {
                    cloudName = availableClouds.first
                    Logger.shared.logInfo("Auto-selected single available cloud: \(cloudName!)")
                    print("Using cloud: \(cloudName!)")
                } else {
                    Logger.shared.logWarning("Multiple clouds available, user must choose: \(availableClouds)")
                    printError("Multiple clouds available. Please specify one with --cloud option.")
                    print("Available clouds: \(availableClouds.joined(separator: ", "))")
                    printUsage()
                    exit(1)
                }
            } catch {
                Logger.shared.logError("Failed to load clouds configuration", error: error)
                printError("Failed to load clouds configuration: \(error)")
                printUsage()
                exit(1)
            }
        }

        guard let selectedCloud = cloudName else {
            printError("No cloud specified")
            printUsage()
            exit(1)
        }

        // Load cloud configuration
        let cloudConfig: CloudConfig
        do {
            Logger.shared.logDebug("Loading cloud configuration for: \(selectedCloud)")
            cloudConfig = try await configManager.getCloudConfig(selectedCloud, path: configPath)
            Logger.shared.logInfo("Cloud configuration loaded successfully")
        } catch {
            Logger.shared.logError("Failed to load cloud configuration for \(selectedCloud)", error: error)
            printError("Failed to load cloud configuration: \(error)")
            printUsage()
            exit(1)
        }

        // Validate and convert configuration using common utility method
        let authURL: URL
        do {
            authURL = try CloudConfigManager.validateAndNormalizeAuthURL(cloudConfig.auth.auth_url, cloudName: selectedCloud)
        } catch {
            printError("Invalid auth_url in cloud configuration: \(cloudConfig.auth.auth_url)")
            exit(1)
        }

        // Handle region configuration
        let region: String?
        var needsRegionDetection = false

        if let configuredRegion = cloudConfig.primaryRegionName {
            if configuredRegion.isEmpty {
                Logger.shared.logError("Invalid region configuration: region_name cannot be empty")
                printError("Invalid region configuration: region_name cannot be empty")
                exit(1)
            }
            region = configuredRegion
            Logger.shared.logDebug("Using configured region: \(configuredRegion)")
        } else {
            // Region not specified - will need to detect from service catalog
            Logger.shared.logDebug("No region specified in configuration - will auto-detect from service catalog")
            region = nil
            needsRegionDetection = true
        }

        let interface = cloudConfig.interface ?? "public"
        Logger.shared.logDebug("Using interface: \(interface)")

        // Determine authentication method using enhanced system
        let authMethod: AuthenticationManager.DeterminedAuthMethod?
        do {
            Logger.shared.logDebug("Determining authentication method for cloud: \(selectedCloud)")
            authMethod = try await configManager.getAuthenticationMethod(selectedCloud, path: configPath)
        } catch {
            Logger.shared.logError("Failed to determine authentication method", error: error)
            printError("Failed to determine authentication method: \(error)")
            exit(1)
        }

        // Create credentials based on determined authentication method
        guard let method = authMethod else {
            Logger.shared.logError("No supported authentication method found in cloud configuration")
            printError("No supported authentication method found in cloud configuration")
            exit(1)
        }

        Logger.shared.logInfo("Determined authentication method: \(method)")

        // For application credentials, don't set default domains - use what's explicitly provided
        let projectDomain: String
        let userDomain: String

        if case .applicationCredentialById = method {
            projectDomain = cloudConfig.auth.project_domain_name ?? ""
            userDomain = cloudConfig.auth.user_domain_name ?? ""
        } else if case .applicationCredentialByName = method {
            projectDomain = cloudConfig.auth.project_domain_name ?? ""
            userDomain = cloudConfig.auth.user_domain_name ?? ""
        } else {
            // For password/token auth, use defaults
            projectDomain = cloudConfig.auth.project_domain_name ?? "Default"
            userDomain = cloudConfig.auth.user_domain_name ?? "Default"
        }

        // Determine SSL verification setting from cloud configuration
        // Check both 'verify' and 'insecure' fields
        let verifySSL: Bool
        if let insecure = cloudConfig.auth.insecure, insecure {
            verifySSL = false
        } else if let verify = cloudConfig.auth.verify {
            // Handle string values: "False", "false", "0", "no" mean disable verification
            let verifyLower = verify.lowercased()
            verifySSL = !(verifyLower == "false" || verifyLower == "0" || verifyLower == "no")
        } else {
            // Default to true (verify SSL certificates)
            verifySSL = true
        }

        let config = OpenStackConfig(
            authURL: authURL,
            region: region ?? "auto-detect",
            userDomainName: userDomain,
            projectDomainName: projectDomain,
            verifySSL: verifySSL,
            interface: interface
        )

        // Create credentials based on determined authentication method
        let credentials: OpenStackCredentials

        // Validate project_name requirement based on authentication method
        Logger.shared.logDebug("Validating project configuration for authentication method")
        switch method {
        case .password, .token:
            // Password and token authentication require project scoping
            guard cloudConfig.auth.project_name != nil || cloudConfig.auth.project_id != nil else {
                Logger.shared.logError("Either project_name or project_id is required for project-scoped authentication")
                printError("Either project_name or project_id is required for project-scoped authentication")
                exit(1)
            }
            Logger.shared.logDebug("Project validation passed for password/token auth")
        case .applicationCredentialById(_, _, let appCredProjectName), .applicationCredentialByName(_, _, _, _, _, let appCredProjectName):
            // For OSClient compatibility, application credentials may still need the project name
            // that the credential was created for. Check if we have a reasonable project name.
            if let projName = appCredProjectName, !projName.isEmpty && projName != "default" {
                Logger.shared.logDebug("Application credential project validation passed")
            } else if appCredProjectName == nil {
                Logger.shared.logDebug("Application credential: no project name (may be scoped by project_id)")
            } else {
                Logger.shared.logWarning("Application credential using fallback project name '\(appCredProjectName ?? "nil")' - this may cause authentication issues")
            }
            break
        }

        switch method {
        case .password(let username, let password, let projectName, let userDomain, let projectDomain):
            if let projectName = projectName {
                Logger.shared.logInfo("Using password authentication for project: \(projectName)")
            } else {
                Logger.shared.logInfo("Using password authentication (project scoped by ID)")
            }
            // Extract ID-based parameters from cloud config if available
            let projectID = cloudConfig.auth.project_id
            let userDomainID = cloudConfig.auth.user_domain_id
            let projectDomainID = cloudConfig.auth.project_domain_id

            // Log which parameters we're using
            if let projectID = projectID {
                Logger.shared.logInfo("Using project_id: \(projectID)")
            }
            if let userDomainID = userDomainID {
                Logger.shared.logInfo("Using user_domain_id: \(userDomainID)")
            }
            if let projectDomainID = projectDomainID {
                Logger.shared.logInfo("Using project_domain_id: \(projectDomainID)")
            }

            credentials = .password(
                username: username,
                password: password,
                projectName: projectName,
                projectID: projectID,
                userDomainName: userDomain,
                userDomainID: userDomainID,
                projectDomainName: projectDomain,
                projectDomainID: projectDomainID
            )

        case .applicationCredentialById(let id, let secret, let projectName):
            Logger.shared.logInfo("Using application credential authentication")
            Logger.shared.logInfo("Application credential ID: '\(id)'")
            Logger.shared.logInfo("Application credential secret: '\(secret.prefix(10))...'")
            if let projectName = projectName, !projectName.isEmpty {
                Logger.shared.logInfo("Application credential project: '\(projectName)'")
            } else {
                Logger.shared.logInfo("Application credential: unscoped (no project)")
            }

            // Check if project_id is available in cloud config
            let projectID = cloudConfig.auth.project_id
            if let projectID = projectID {
                Logger.shared.logInfo("Using project_id: \(projectID)")
            }

            credentials = .applicationCredential(
                id: id,
                secret: secret,
                projectName: projectName,
                projectID: projectID
            )

        case .applicationCredentialByName(let name, let secret, _, _, _, let projectName):
            Logger.shared.logInfo("Using application credential by name authentication")
            Logger.shared.logDebug("Application credential name: '\(name)'")

            let projectID = cloudConfig.auth.project_id
            if let projectID = projectID {
                Logger.shared.logInfo("Using project_id: \(projectID)")
            }

            credentials = .applicationCredential(
                id: name,
                secret: secret,
                projectName: projectName,
                projectID: projectID
            )

        case .token(let token, let projectName, let projectID):
            if let projectName = projectName {
                Logger.shared.logInfo("Using token authentication for project: \(projectName)")
            } else if let projectID = projectID {
                Logger.shared.logInfo("Using token authentication for project ID: \(projectID)")
            } else {
                Logger.shared.logInfo("Using unscoped token authentication")
            }

            credentials = .token(
                token: token,
                projectName: projectName,
                projectID: projectID,
                userDomainName: userDomain,
                projectDomainName: projectDomain
            )
        }

        // Clean up stale cache files before starting (older than 8 hours)
        // This ensures operators are not presented with stale data when launching Substation
        // Cache files are stored in cloud-specific subdirectories: ~/.config/substation/multi-level-cache/<cloudName>/
        let staleCacheFilesRemoved = MultiLevelCacheManager<String, Data>.cleanupStaleCacheFiles(
            cloudName: selectedCloud
        )
        if staleCacheFilesRemoved > 0 {
            Logger.shared.logInfo("Cleaned up \(staleCacheFilesRemoved) stale cache file(s) older than 8 hours for cloud '\(selectedCloud)'")
        }

        do {
            // Create shared logger for all components - Substation is the authoritative source
            // All logs from MemoryKit, SwiftNCurses, and OSClient adapters route through the SubstationLogger bridge
            let sharedLogger: any MemoryKitLogger
            if debugMode {
                sharedLogger = SubstationLogger()
                Logger.shared.logInfo("Substation logging configured - all components connected", context: [
                    "logFile": "~/substation.log",
                    "debugMode": debugMode
                ])
            } else {
                // In non-debug mode, use silent logging to avoid cluttering output
                sharedLogger = SilentSubstationLogger()
            }

            Logger.shared.logStartup("Application starting with cloud: \(selectedCloud)")
            Logger.shared.logInfo("Auth URL: \(authURL)")
            Logger.shared.logInfo("Region: \(region ?? "auto-detect")")
            Logger.shared.logInfo("Interface: \(interface)")
            Logger.shared.logInfo("Project domain: \(projectDomain)")
            Logger.shared.logInfo("User domain: \(userDomain)")
            Logger.shared.logInfo("Debug mode: \(debugMode)")

            // Phase 1: Pre-warm FloatingIPViews to eliminate cold start penalty
            FloatingIPViews.warmUp()
            Logger.shared.logInfo("Raw config values from clouds.yaml:")
            let regionDisplay = if let regions = cloudConfig.region_name {
                switch regions {
                case .single(let region):
                    region
                case .multiple(let regionList):
                    regionList.joined(separator: ", ")
                }
            } else {
                "nil"
            }
            Logger.shared.logInfo("  - region_name: '\(regionDisplay)'")
            Logger.shared.logInfo("  - interface: '\(cloudConfig.interface ?? "nil")'")
            Logger.shared.logInfo("  - auth.project_name: '\(cloudConfig.auth.project_name ?? "nil")'")
            Logger.shared.logInfo("OpenStackConfig being passed to client:")
            Logger.shared.logInfo("  - authURL: \(config.authURL)")
            Logger.shared.logInfo("  - region: \(config.region)")
            Logger.shared.logInfo("  - userDomainName: \(config.userDomainName)")
            Logger.shared.logInfo("  - projectDomainName: \(config.projectDomainName)")
            Logger.shared.logInfo("Connecting to OpenStack cloud '\(selectedCloud)'")

            // Initialize terminal early to show loading screen during connection
            Logger.shared.logDebug("Initializing terminal for early loading screen")
            let initResult = SwiftNCurses.initializeTerminalSession()
            guard initResult.success, let screen = initResult.screen else {
                let errorMsg = "Failed to initialize terminal session"
                Logger.shared.logError(errorMsg)
                printError(errorMsg)
                exit(1)
            }

            defer {
                SwiftNCurses.cleanupTerminal()
            }

            let screenRows = initResult.rows
            let screenCols = initResult.cols

            // Show loading screen immediately
            await LoadingView.drawLoadingScreen(
                screen: screen.pointer,
                startRow: 0,
                startCol: 0,
                width: screenCols,
                height: screenRows,
                progressStep: 0,
                statusMessage: "Connecting to OpenStack cloud..."
            )
            SwiftNCurses.batchedRefresh(screen)

            let connectionStart = Date().timeIntervalSinceReferenceDate
            var client = try await OSClient.connect(
                config: config,
                credentials: credentials,
                logger: LoggerBridge(),
                cloudName: selectedCloud
            )
            let connectionDuration = Date().timeIntervalSinceReferenceDate - connectionStart
            Logger.shared.logPerformance("OpenStack client connection", duration: connectionDuration)
            Logger.shared.logInfo("Successfully connected to OpenStack cloud")

            // Update loading screen after connection
            await LoadingView.drawLoadingScreen(
                screen: screen.pointer,
                startRow: 0,
                startCol: 0,
                width: screenCols,
                height: screenRows,
                progressStep: 1,
                statusMessage: "Authenticating..."
            )
            SwiftNCurses.batchedRefresh(screen)

            // Auto-detect region if not specified in configuration
            if needsRegionDetection {
                Logger.shared.logInfo("Auto-detecting region from service catalog")
                do {
                    let detectedRegion = try await RegionDetection.detectFromCatalog(
                        authURL: authURL,
                        credentials: credentials,
                        failOnMultiple: true
                    )

                    // If we got a region (will be non-nil or will have thrown), reconnect
                    if let region = detectedRegion {
                        Logger.shared.logInfo("Detected region: \(region)")

                        // Show loading screen during reconnect
                        await LoadingView.drawLoadingScreen(
                            screen: screen.pointer,
                            startRow: 0,
                            startCol: 0,
                            width: screenCols,
                            height: screenRows,
                            progressStep: 2,
                            statusMessage: "Reconnecting with detected region..."
                        )
                        SwiftNCurses.batchedRefresh(screen)

                        // Reconnect with the detected region
                        let reconnectConfig = OpenStackConfig(
                            authURL: authURL,
                            region: region,
                            userDomainName: config.userDomainName,
                            projectDomainName: config.projectDomainName,
                            verifySSL: config.verifySSL
                        )
                        client = try await OSClient.connect(
                            config: reconnectConfig,
                            credentials: credentials,
                            logger: LoggerBridge(),
                            cloudName: selectedCloud
                        )
                        Logger.shared.logInfo("Reconnected with detected region: \(region)")
                    }
                } catch let error as RegionDetectionError {
                    Logger.shared.logError("Region detection failed: \(error)")
                    printError(error.description)
                    exit(1)
                }
            }

            Logger.shared.logDebug("Initializing TUI")
            let tui = try await TUI(client: client, debugMode: debugMode, sharedLogger: sharedLogger, existingScreen: screen.pointer)
            Logger.shared.logInfo("TUI initialized, starting main loop")
            await tui.run()
            Logger.shared.logInfo("TUI main loop exited")
        } catch OpenStackError.authenticationFailed {
            let errorMsg = "Authentication failed. Please check your credentials in the clouds.yaml file."
            Logger.shared.logError(errorMsg)
            printError(errorMsg)
            printUsage()
            exit(1)
        } catch OpenStackError.endpointNotFound {
            let errorMsg = """
            Service endpoint not found. Please check your OpenStack configuration:

            Current configuration:
            - Cloud: \(selectedCloud)
            - Region: '\(region ?? "auto-detect")' (verify this exists in your OpenStack deployment)
            - Interface: '\(interface)' (try 'public', 'internal', or 'admin')
            - Auth URL: \(authURL)

            Troubleshooting steps:
            1. Verify your region name matches your OpenStack deployment
            2. Try different interface values: 'public', 'internal', or 'admin'
            3. Check that your auth_url is accessible and correct

            Use these OpenStack CLI commands to verify your configuration:
              openstack --os-cloud \(selectedCloud) region list
              openstack --os-cloud \(selectedCloud) service list
              openstack --os-cloud \(selectedCloud) endpoint list
            """
            Logger.shared.logError(errorMsg)
            printError(errorMsg)
            exit(1)
        } catch {
            let errorMsg = "Connection error: \(error)"
            Logger.shared.logError("Connection failed", error: error)
            printError(errorMsg)
            exit(1)
        }
    }

    static func listCloudsAction(configPath: String?) async {
        let configManager = CloudConfigManager()
        do {
            Logger.shared.logDebug("Listing available clouds")
            let cloudsConfig = try await configManager.loadCloudsConfig(path: configPath)
            let clouds = Array(cloudsConfig.clouds.keys).sorted()
            Logger.shared.logInfo("Found \(clouds.count) clouds in configuration")

            // Display validation warnings first, if any
            if !cloudsConfig.validationWarnings.isEmpty {
                print("Configuration Warnings:")
                for (cloudName, warning) in cloudsConfig.validationWarnings.sorted(by: { $0.key < $1.key }) {
                    print("  \(cloudName): \(warning) [SKIPPED]")
                }
                print("")
            }

            if clouds.isEmpty {
                Logger.shared.logWarning("No valid clouds found in configuration")
                print("No valid clouds found in configuration.")
                return
            }

            print("Available clouds:")
            for cloud in clouds {
                do {
                    Logger.shared.logDebug("Retrieving info for cloud: \(cloud)")
                    let cloudInfo = try await configManager.getCloudInfo(cloud, path: configPath)
                    print("  \(cloud):")
                    print("    Auth URL: \(cloudInfo.config.auth.auth_url)")
                    let regionDisplay = if let regions = cloudInfo.config.region_name {
                        switch regions {
                        case .single(let region):
                            region
                        case .multiple(let regionList):
                            regionList.joined(separator: ", ")
                        }
                    } else {
                        "Not specified"
                    }
                    print("    Region: \(regionDisplay)")
                    print("    Interface: \(cloudInfo.config.interface ?? "Not specified")")

                    if let authMethod = cloudInfo.authenticationMethod {
                        switch authMethod {
                        case .password:
                            print("    Authentication: Password")
                        case .applicationCredentialById:
                            print("    Authentication: Application Credential (by ID)")
                        case .applicationCredentialByName:
                            print("    Authentication: Application Credential (by name)")
                        case .token:
                            print("    Authentication: Token")
                        }
                    } else {
                        print("    Authentication: Unable to determine")
                    }

                    if cloudInfo.hasEnvironmentVariables {
                        print("    Uses environment variables: Yes")
                    }

                    if !cloudInfo.validationErrors.isEmpty {
                        Logger.shared.logWarning("Cloud '\(cloud)' has validation errors: \(cloudInfo.validationErrors)")
                        print("    Validation warnings:")
                        for error in cloudInfo.validationErrors {
                            print("      - \(error)")
                        }
                    }
                } catch {
                    Logger.shared.logError("Error loading configuration for cloud '\(cloud)'", error: error)
                    print("  \(cloud): Error loading configuration - \(error)")
                }
            }
        } catch {
            Logger.shared.logError("Failed to list clouds", error: error)
            printError("Failed to list clouds: \(error)")
            exit(1)
        }
    }

    static func printError(_ message: String) {
        FileHandle.standardError.write(Data("ERROR: \(message)\n".utf8))
    }

    static func printUsage() {
        let usage = """

        Substation - OpenStack Terminal User Interface

        Usage:
          substation [options] [cloud-name]
          substation --list-clouds

        Options:
          -c, --cloud <name>     Specify cloud name from clouds.yaml
          --config <path>        Path to clouds.yaml file (default: ~/.config/openstack/clouds.yaml)
          --list-clouds          List available clouds in configuration
          --wiretap              Enable debug mode and log to ~/substation.log
          -h, --help             Show this help message

        Environment Variables:
          OS_CLOUD               Cloud name to use (overridden by --cloud or positional argument)
          OS_CLIENT_CONFIG_FILE  Path to clouds.yaml file (overridden by --config)

        Configuration:
          Substation uses the standard OpenStack clouds.yaml configuration file.
          Default location: ~/.config/openstack/clouds.yaml

        Example clouds.yaml:
          clouds:
            mycloud:
              auth:
                auth_url: https://identity.example.com:5000/v3
                username: admin
                password: secretpassword
                project_name: admin
                user_domain_name: Default
                project_domain_name: Default
              region_name: RegionOne

        Examples:
          substation                            # Use first/only cloud in configuration
          substation mycloud                    # Use specific cloud
          substation --cloud mycloud            # Use specific cloud (alternative syntax)
          substation --list-clouds              # List available clouds
          substation --config ./my-clouds.yaml  # Use custom config file

        Commands:
          completion <shell>     Generate shell completion script (bash, zsh, fish)

        Completion Examples:
          # Installing bash completion on macOS using homebrew
          ## If running via homebrew, completions may work automatically
          ## Otherwise, add to your completion directory:
          substation completion bash > $(brew --prefix)/etc/bash_completion.d/substation

          # Installing bash completion on Linux
          ## Install bash-completion package if not already installed
          ## Load completion into current shell:
          source <(substation completion bash)
          ## Or add to your profile for persistence:
          substation completion bash > ~/.substation_completion.bash.inc
          printf "
          # substation shell completion
          source '$HOME/.substation_completion.bash.inc'
          " >> $HOME/.bash_profile
          source $HOME/.bash_profile

          # Installing zsh completion (requires zsh >= 5.2)
          ## Load into current shell:
          source <(substation completion zsh)
          ## Or install permanently:
          substation completion zsh > "${fpath[1]}/_substation"

          # Installing fish completion
          substation completion fish > ~/.config/fish/completions/substation.fish

        """
        print(usage)
    }

    // MARK: - Shell Completion

    /// Prints usage information for the completion subcommand
    static func printCompletionUsage() {
        let usage = """

        Usage: substation completion <shell>

        Generate shell completion script for the specified shell.

        Supported shells:
          bash    Bash completion (requires bash >= 4.0)
          zsh     Zsh completion (requires zsh >= 5.2)
          fish    Fish completion

        Examples:
          # Installing bash completion on macOS using homebrew
          ## If running via homebrew, completions may work automatically
          ## Otherwise, add to your completion directory:
          substation completion bash > $(brew --prefix)/etc/bash_completion.d/substation

          # Installing bash completion on Linux
          ## Install bash-completion package if not already installed
          ## Load completion into current shell:
          source <(substation completion bash)
          ## Or add to your profile for persistence:
          substation completion bash > ~/.substation_completion.bash.inc
          printf "
          # substation shell completion
          source '$HOME/.substation_completion.bash.inc'
          " >> $HOME/.bash_profile
          source $HOME/.bash_profile

          # Installing zsh completion (requires zsh >= 5.2)
          ## Load into current shell:
          source <(substation completion zsh)
          ## Or install permanently:
          substation completion zsh > "${fpath[1]}/_substation"

          # Installing fish completion
          substation completion fish > ~/.config/fish/completions/substation.fish

        """
        print(usage)
    }

    /// Outputs the shell completion script for the specified shell
    /// - Parameter shell: The shell type (bash, zsh, or fish)
    static func printCompletion(shell: String) {
        switch shell.lowercased() {
        case "bash":
            print(bashCompletionScript())
        case "zsh":
            print(zshCompletionScript())
        case "fish":
            print(fishCompletionScript())
        default:
            printError("Unknown shell: \(shell)")
            printError("Supported shells: bash, zsh, fish")
            exit(1)
        }
    }

    /// Generates the bash completion script
    /// - Returns: The complete bash completion script as a string
    static func bashCompletionScript() -> String {
        return """
        # Bash completion script for substation
        # Generated by: substation completion bash
        #
        # Installation:
        #   # macOS with homebrew:
        #   substation completion bash > $(brew --prefix)/etc/bash_completion.d/substation
        #
        #   # Linux:
        #   source <(substation completion bash)
        #   # Or add to ~/.bashrc for persistence

        _substation_get_clouds() {
            local config_file="${OS_CLIENT_CONFIG_FILE:-$HOME/.config/openstack/clouds.yaml}"
            if [[ -f "${config_file}" ]]; then
                # Extract cloud names from clouds.yaml (keys under 'clouds:' section)
                grep -E '^  [a-zA-Z0-9_-]+:$' "${config_file}" 2>/dev/null | sed 's/://g' | tr -d ' '
            fi
        }

        _substation_completions() {
            local cur prev opts clouds
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"

            # All available options
            opts="--cloud -c --config --list-clouds --wiretap --help -h completion"

            # Handle completion subcommand
            if [[ "${COMP_WORDS[1]}" == "completion" ]]; then
                if [[ ${COMP_CWORD} -eq 2 ]]; then
                    COMPREPLY=($(compgen -W "bash zsh fish" -- "${cur}"))
                fi
                return 0
            fi

            # Handle option arguments
            case "${prev}" in
                --cloud|-c)
                    # Complete with cloud names
                    clouds=$(_substation_get_clouds)
                    COMPREPLY=($(compgen -W "${clouds}" -- "${cur}"))
                    return 0
                    ;;
                --config)
                    # Complete with file paths
                    COMPREPLY=($(compgen -f -- "${cur}"))
                    return 0
                    ;;
            esac

            # Default completion
            if [[ "${cur}" == -* ]]; then
                # Complete options
                COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
            else
                # Complete with options and cloud names
                clouds=$(_substation_get_clouds)
                COMPREPLY=($(compgen -W "${opts} ${clouds}" -- "${cur}"))
            fi
        }

        complete -F _substation_completions substation
        """
    }

    /// Generates the zsh completion script
    /// - Returns: The complete zsh completion script as a string
    static func zshCompletionScript() -> String {
        return """
        #compdef substation
        # Zsh completion script for substation
        # Generated by: substation completion zsh
        #
        # Installation:
        #   # Load into current shell:
        #   source <(substation completion zsh)
        #
        #   # Or install permanently:
        #   substation completion zsh > "${fpath[1]}/_substation"
        #
        # Requires zsh >= 5.2

        _substation_get_clouds() {
            local config_file="${OS_CLIENT_CONFIG_FILE:-$HOME/.config/openstack/clouds.yaml}"
            if [[ -f "${config_file}" ]]; then
                grep -E '^  [a-zA-Z0-9_-]+:$' "${config_file}" 2>/dev/null | sed 's/://g' | tr -d ' '
            fi
        }

        _substation() {
            local -a commands
            local -a options
            local -a clouds
            local -a shells

            commands=(
                'completion:Generate shell completion script'
            )

            options=(
                '(-c --cloud)'{-c,--cloud}'[Specify cloud name from clouds.yaml]:cloud name:->clouds'
                '--config[Path to clouds.yaml file]:config file:_files'
                '--list-clouds[List available clouds in configuration]'
                '--wiretap[Enable debug mode and log to ~/substation.log]'
                '(-h --help)'{-h,--help}'[Show help message]'
            )

            shells=(
                'bash:Bash completion (requires bash >= 4.0)'
                'zsh:Zsh completion (requires zsh >= 5.2)'
                'fish:Fish completion'
            )

            # Check if we are completing the 'completion' subcommand
            if [[ "${words[2]}" == "completion" ]]; then
                if [[ ${CURRENT} -eq 3 ]]; then
                    _describe -t shells 'shell' shells
                fi
                return
            fi

            # Check if first argument (could be cloud name or subcommand)
            if [[ ${CURRENT} -eq 2 ]]; then
                # Offer both subcommands and options
                _describe -t commands 'command' commands
                _arguments -S : $options
                # Also offer cloud names as positional argument
                local cloud_list=($(_substation_get_clouds))
                if [[ -n "${cloud_list}" ]]; then
                    _describe -t clouds 'cloud name' cloud_list
                fi
                return
            fi

            # Complete options and cloud names
            case "$state" in
                clouds)
                    local cloud_list=($(_substation_get_clouds))
                    _describe -t clouds 'cloud name' cloud_list
                    ;;
                *)
                    _arguments -S : $options
                    ;;
            esac
        }

        _substation "$@"
        """
    }

    /// Generates the fish completion script
    /// - Returns: The complete fish completion script as a string
    static func fishCompletionScript() -> String {
        return """
        # Fish completion script for substation
        # Generated by: substation completion fish
        #
        # Installation:
        #   substation completion fish > ~/.config/fish/completions/substation.fish

        # Function to get cloud names from clouds.yaml
        function __substation_get_clouds
            set -l config_file "$HOME/.config/openstack/clouds.yaml"
            if set -q OS_CLIENT_CONFIG_FILE
                set config_file "$OS_CLIENT_CONFIG_FILE"
            end
            if test -f "$config_file"
                grep -E '^  [a-zA-Z0-9_-]+:$' "$config_file" 2>/dev/null | sed 's/://g' | tr -d ' '
            end
        end

        # Function to check if completion subcommand is being used
        function __substation_using_completion
            set -l cmd (commandline -opc)
            if test (count $cmd) -ge 2
                if test "$cmd[2]" = "completion"
                    return 0
                end
            end
            return 1
        end

        # Function to check if no subcommand is specified yet
        function __substation_needs_command
            set -l cmd (commandline -opc)
            if test (count $cmd) -eq 1
                return 0
            end
            return 1
        end

        # Disable file completions by default
        complete -c substation -f

        # Subcommand: completion
        complete -c substation -n '__substation_needs_command' -a 'completion' -d 'Generate shell completion script'

        # Shell types for completion subcommand
        complete -c substation -n '__substation_using_completion' -a 'bash' -d 'Bash completion (requires bash >= 4.0)'
        complete -c substation -n '__substation_using_completion' -a 'zsh' -d 'Zsh completion (requires zsh >= 5.2)'
        complete -c substation -n '__substation_using_completion' -a 'fish' -d 'Fish completion'

        # Options
        complete -c substation -n 'not __substation_using_completion' -s c -l cloud -d 'Specify cloud name' -xa '(__substation_get_clouds)'
        complete -c substation -n 'not __substation_using_completion' -l config -d 'Path to clouds.yaml file' -r
        complete -c substation -n 'not __substation_using_completion' -l list-clouds -d 'List available clouds'
        complete -c substation -n 'not __substation_using_completion' -l wiretap -d 'Enable debug mode'
        complete -c substation -n 'not __substation_using_completion' -s h -l help -d 'Show help message'

        # Cloud names as positional arguments
        complete -c substation -n 'not __substation_using_completion' -a '(__substation_get_clouds)' -d 'Cloud name'
        """
    }
}
