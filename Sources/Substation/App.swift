import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OSClient
import MemoryKit

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
struct LoggerBridge: OpenStackClientLogger {
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

        // Validate and convert configuration
        Logger.shared.logDebug("Validating auth URL: \(cloudConfig.auth.auth_url)")
        guard var authURL = URL(string: cloudConfig.auth.auth_url) else {
            Logger.shared.logError("Invalid auth_url in cloud configuration: \(cloudConfig.auth.auth_url)")
            printError("Invalid auth_url in cloud configuration: \(cloudConfig.auth.auth_url)")
            exit(1)
        }

        if authURL.path.isEmpty {
            Logger.shared.logDebug("Auth URL path empty, appending /v3")
            authURL.appendPathComponent("v3")
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

        let config = OTConfig(
            authURL: authURL,
            region: region ?? "auto-detect",
            userDomainName: userDomain,
            projectDomainName: projectDomain
        )

        // Create credentials based on determined authentication method
        let credentials: OTCredentials

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
            let hasValidProject = !appCredProjectName.isEmpty && appCredProjectName != "default"
            if !hasValidProject {
                Logger.shared.logWarning("Application credential using fallback project name '\(appCredProjectName)' - this may cause authentication issues")
            } else {
                Logger.shared.logDebug("Application credential project validation passed")
            }
            break
        }

        switch method {
        case .password(let username, let password, let projectName, let userDomain, let projectDomain):
            Logger.shared.logInfo("Using password authentication for project: \(projectName)")
            credentials = .password(username: username, password: password, projectName: projectName, userDomainName: userDomain, projectDomainName: projectDomain)

        case .applicationCredentialById(let id, let secret, let projectName):
            Logger.shared.logInfo("Using application credential authentication")
            Logger.shared.logInfo("Application credential ID: '\(id)'")
            Logger.shared.logInfo("Application credential secret: '\(secret.prefix(10))...'")
            if !projectName.isEmpty {
                Logger.shared.logInfo("Application credential project: '\(projectName)'")
            } else {
                Logger.shared.logInfo("Application credential: unscoped (no project)")
            }
            // Don't force a default project name for application credentials
            credentials = .applicationCredential(id: id, secret: secret, projectName: projectName)

        case .applicationCredentialByName(let name, let secret, _, _, _, let projectName):
            // Application credential by name requires special handling
            Logger.shared.logInfo("Using application credential by name authentication")
            Logger.shared.logDebug("Application credential name: '\(name)'")
            // For now, use the ID-based approach with the name as ID (this may need OTCredentials enhancement)
            credentials = .applicationCredential(id: name, secret: secret, projectName: projectName)

        case .token(_, _, _):
            // Token-based authentication would require extending OTCredentials
            Logger.shared.logError("Token-based authentication is not yet supported")
            printError("Token-based authentication is not yet supported by the OpenStack client. Please use password or application credential authentication.")
            exit(1)
        }

        do {
            // Create shared logger for all components - Substation is the authoritative source
            // All logs from MemoryKit, SwiftTUI, and OSClient adapters route through the SubstationLogger bridge
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
            Logger.shared.logInfo("OTConfig being passed to client:")
            Logger.shared.logInfo("  - authURL: \(config.authURL)")
            Logger.shared.logInfo("  - region: \(config.region)")
            Logger.shared.logInfo("  - userDomainName: \(config.userDomainName)")
            Logger.shared.logInfo("  - projectDomainName: \(config.projectDomainName)")
            Logger.shared.logInfo("Connecting to OpenStack cloud '\(selectedCloud)'")

            let connectionStart = Date().timeIntervalSinceReferenceDate
            var client = try await OSClient.connect(config: config, credentials: credentials, logger: LoggerBridge())
            let connectionDuration = Date().timeIntervalSinceReferenceDate - connectionStart
            Logger.shared.logPerformance("OpenStack client connection", duration: connectionDuration)
            Logger.shared.logInfo("Successfully connected to OpenStack cloud")

            // Auto-detect region if not specified in configuration
            if needsRegionDetection {
                Logger.shared.logInfo("Auto-detecting region from service catalog")
                let detectedRegion = try await detectRegionFromCatalog(client: client, authURL: authURL, credentials: credentials, config: config)
                Logger.shared.logInfo("Detected region: \(detectedRegion)")

                // Reconnect with the detected region
                let reconnectConfig = OTConfig(
                    authURL: authURL,
                    region: detectedRegion,
                    userDomainName: config.userDomainName,
                    projectDomainName: config.projectDomainName
                )
                client = try await OSClient.connect(config: reconnectConfig, credentials: credentials, logger: LoggerBridge())
                Logger.shared.logInfo("Reconnected with detected region: \(detectedRegion)")
            }

            Logger.shared.logDebug("Initializing TUI")
            let tui = try await TUI(client: client, debugMode: debugMode, sharedLogger: sharedLogger)
            Logger.shared.logInfo("TUI initialized, starting main loop")
            await tui.run()
            Logger.shared.logInfo("TUI main loop exited")
        } catch OTError.authenticationFailed {
            let errorMsg = "Authentication failed. Please check your credentials in the clouds.yaml file."
            Logger.shared.logError(errorMsg)
            printError(errorMsg)
            printUsage()
            exit(1)
        } catch OTError.endpointNotFound {
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

    // Helper structures for token response parsing
    private struct TokenResponse: Codable {
        let token: TokenData
    }

    private struct TokenData: Codable {
        let catalog: [TokenCatalogEntry]?
    }

    private static func buildAuthRequest(credentials: OTCredentials) throws -> [String: Any] {
        switch credentials {
        case .password(let username, let password, let projectName, let userDomain, let projectDomain):
            return [
                "auth": [
                    "identity": [
                        "methods": ["password"],
                        "password": [
                            "user": [
                                "name": username,
                                "password": password,
                                "domain": ["name": userDomain]
                            ]
                        ]
                    ],
                    "scope": [
                        "project": [
                            "name": projectName,
                            "domain": ["name": projectDomain]
                        ]
                    ]
                ]
            ]
        case .applicationCredential(let id, let secret, let projectName):
            var authDict: [String: Any] = [
                "auth": [
                    "identity": [
                        "methods": ["application_credential"],
                        "application_credential": [
                            "id": id,
                            "secret": secret
                        ]
                    ]
                ]
            ]
            if !projectName.isEmpty {
                authDict["auth"] = [
                    "identity": authDict["auth"]!,
                    "scope": [
                        "project": ["name": projectName]
                    ]
                ]
            }
            return authDict
        }
    }

    static func detectRegionFromCatalog(
        client: OSClient,
        authURL: URL,
        credentials: OTCredentials,
        config: OTConfig
    ) async throws -> String {
        // Perform a raw authentication request to get the token catalog
        // This bypasses the client's service catalog building which requires a region
        let authRequest = try buildAuthRequest(credentials: credentials)

        var request = URLRequest(url: authURL.appendingPathComponent("auth/tokens"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: authRequest, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw OTError.authenticationFailed
        }

        // Parse the auth response to get the catalog
        let authResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Extract unique regions from all endpoints in the catalog
        var regions = Set<String>()
        for service in authResponse.token.catalog ?? [] {
            for endpoint in service.endpoints {
                if let region = endpoint.region, !region.isEmpty {
                    regions.insert(region)
                }
            }
        }

        let sortedRegions = regions.sorted()

        if sortedRegions.isEmpty {
            Logger.shared.logError("No regions found in service catalog")
            printError("No regions found in service catalog. Please configure a region_name in your clouds.yaml")
            exit(1)
        } else if sortedRegions.count == 1 {
            Logger.shared.logInfo("Auto-detected single region: \(sortedRegions[0])")
            return sortedRegions[0]
        } else {
            // Multiple regions detected - user must specify
            let regionList = sortedRegions.joined(separator: ", ")
            let errorMsg = """

            Multiple regions detected in service catalog: \(regionList)

            Please update your clouds.yaml configuration to specify which region to use.
            Add the 'region_name' field to your cloud configuration:

            clouds:
              your-cloud-name:
                region_name: <one of: \(regionList)>
                ...

            """
            Logger.shared.logError("Multiple regions detected but no region_name configured")
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
          --wiretap               Enable debug mode and log to ~/substation.log
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

        """
        print(usage)
    }
}
