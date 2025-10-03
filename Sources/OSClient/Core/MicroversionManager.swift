import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Microversion Management

/// Manages OpenStack API microversions for all services
public actor MicroversionManager {
    private weak var core: OpenStackClientCore?
    private let logger: any OpenStackClientLogger
    private var detectedVersions: [String: ServiceVersionInfo] = [:]
    private var isDiscoveryInProgress: Set<String> = []

    public init(logger: any OpenStackClientLogger) {
        self.logger = logger
    }

    /// Set the core client reference (called after core initialization)
    public func setCore(_ core: OpenStackClientCore) {
        self.core = core
    }

    /// Get the optimal microversion headers for a service
    public func getVersionHeaders(for service: String) async -> [String: String] {
        // Try to get cached version info first
        if let versionInfo = detectedVersions[service] {
            return versionInfo.headers
        }

        // If discovery is already in progress, wait for it
        if isDiscoveryInProgress.contains(service) {
            // Wait a bit and try again
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return await getVersionHeaders(for: service)
        }

        // Start discovery
        await discoverVersions(for: service)

        // Return discovered version or fallback
        return detectedVersions[service]?.headers ?? getDefaultHeaders(for: service)
    }

    /// Discover supported microversions for a service
    private func discoverVersions(for service: String) async {
        guard !isDiscoveryInProgress.contains(service) else { return }
        isDiscoveryInProgress.insert(service)

        defer {
            isDiscoveryInProgress.remove(service)
        }

        do {
            let versionInfo = try await performVersionDiscovery(for: service)
            detectedVersions[service] = versionInfo

            logger.logInfo("Microversion discovery successful", context: [
                "service": service,
                "current": versionInfo.current,
                "min": versionInfo.min,
                "max": versionInfo.max
            ])
        } catch {
            // Fall back to default versions on discovery failure
            let defaultInfo = getDefaultVersionInfo(for: service)
            detectedVersions[service] = defaultInfo

            logger.logError("Microversion discovery failed, using defaults", context: [
                "service": service,
                "error": error.localizedDescription,
                "default": defaultInfo.current
            ])
        }
    }

    /// Perform actual version discovery by hitting the service endpoint
    private func performVersionDiscovery(for service: String) async throws -> ServiceVersionInfo {
        guard let core = self.core else {
            throw OpenStackError.configurationError("Core client not set")
        }

        // Get the base service URL
        let baseURL = try await core.getEndpoint(for: service)
        guard let url = URL(string: baseURL) else {
            throw OpenStackError.invalidURL(baseURL)
        }

        // Most OpenStack services expose version info at the root endpoint
        let versionURL = url.appendingPathComponent("/")

        var request = URLRequest(url: versionURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add authentication if needed (some services require it)
        let token = try await core.ensureAuthenticated()
        request.setValue(token, forHTTPHeaderField: "X-Auth-Token")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenStackError.invalidResponse
        }

        // Many services return version info even on 300 (multiple choices)
        guard [200, 300].contains(httpResponse.statusCode) else {
            throw OpenStackError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }

        // Parse version information
        return try parseVersionInfo(from: data, for: service)
    }

    /// Parse version information from service response
    private func parseVersionInfo(from data: Data, for service: String) throws -> ServiceVersionInfo {
        let json = try JSONSerialization.jsonObject(with: data, options: [])

        // Try different response formats used by different services
        if let dict = json as? [String: Any] {
            // Format 1: {"versions": {"values": [...]}}
            if let versions = dict["versions"] as? [String: Any],
               let values = versions["values"] as? [[String: Any]] {
                return try parseVersionArray(values, for: service)
            }

            // Format 2: {"versions": [...]}
            if let versions = dict["versions"] as? [[String: Any]] {
                return try parseVersionArray(versions, for: service)
            }

            // Format 3: {"version": {...}} (single version)
            if let version = dict["version"] as? [String: Any] {
                return try parseVersionObject(version, for: service)
            }
        }

        // Fallback to default if parsing fails
        return getDefaultVersionInfo(for: service)
    }

    /// Parse an array of version objects
    private func parseVersionArray(_ versions: [[String: Any]], for service: String) throws -> ServiceVersionInfo {
        // Look for the latest stable version
        var latest: [String: Any]?
        var maxVersion = "0.0"

        for version in versions {
            guard let status = version["status"] as? String,
                  status.lowercased() == "current" || status.lowercased() == "supported",
                  let id = version["id"] as? String else {
                continue
            }

            // Extract version number (e.g., "v2.1" -> "2.1")
            let versionNumber = id.replacingOccurrences(of: "v", with: "")
            if versionNumber.compare(maxVersion, options: .numeric) == .orderedDescending {
                maxVersion = versionNumber
                latest = version
            }
        }

        if let versionObject = latest {
            return try parseVersionObject(versionObject, for: service)
        }

        return getDefaultVersionInfo(for: service)
    }

    /// Parse a single version object
    private func parseVersionObject(_ version: [String: Any], for service: String) throws -> ServiceVersionInfo {
        let id = version["id"] as? String ?? "unknown"
        let min = version["min_version"] as? String
        let max = version["max_version"] as? String ?? version["version"] as? String

        // Extract version number from id (e.g., "v2.1" -> "2.1")
        let current = id.replacingOccurrences(of: "v", with: "")

        return ServiceVersionInfo(
            service: service,
            current: current,
            min: min ?? current,
            max: max ?? current,
            headers: createHeaders(for: service, version: max ?? current)
        )
    }

    /// Create appropriate headers for a service and version
    private func createHeaders(for service: String, version: String) -> [String: String] {
        switch service {
        case "compute":
            return ["X-OpenStack-Nova-API-Version": version]
        case "network":
            return ["X-OpenStack-Neutron-API-Version": version]
        case "volume", "volumev2", "volumev3":
            return ["X-OpenStack-Volume-API-Version": version]
        case "image":
            return ["X-OpenStack-Images-API-Version": version]
        case "identity":
            return ["X-OpenStack-Identity-API-Version": version]
        case "object-store":
            return ["X-OpenStack-Swift-API-Version": version]
        case "orchestration":
            return ["X-OpenStack-Heat-API-Version": version]
        case "key-manager":
            return ["X-OpenStack-Barbican-API-Version": version]
        case "load-balancer":
            return ["X-OpenStack-Octavia-API-Version": version]
        default:
            // Generic microversion header
            return ["X-OpenStack-API-Version": "\(service) \(version)"]
        }
    }

    /// Get default headers when discovery fails
    private func getDefaultHeaders(for service: String) -> [String: String] {
        return getDefaultVersionInfo(for: service).headers
    }

    /// Get default version information for known services
    private func getDefaultVersionInfo(for service: String) -> ServiceVersionInfo {
        switch service {
        case "compute":
            return ServiceVersionInfo(
                service: service,
                current: "2.87",
                min: "2.1",
                max: "2.87",
                headers: ["X-OpenStack-Nova-API-Version": "2.87"]
            )
        case "network":
            return ServiceVersionInfo(
                service: service,
                current: "2.0",
                min: "2.0",
                max: "2.0",
                headers: ["X-OpenStack-Neutron-API-Version": "2.0"]
            )
        case "volume", "volumev2", "volumev3":
            return ServiceVersionInfo(
                service: service,
                current: "3.59",
                min: "3.0",
                max: "3.59",
                headers: ["X-OpenStack-Volume-API-Version": "3.59"]
            )
        case "image":
            return ServiceVersionInfo(
                service: service,
                current: "2.14",
                min: "2.0",
                max: "2.14",
                headers: ["X-OpenStack-Images-API-Version": "2.14"]
            )
        case "identity":
            return ServiceVersionInfo(
                service: service,
                current: "3.14",
                min: "3.0",
                max: "3.14",
                headers: ["X-OpenStack-Identity-API-Version": "3.14"]
            )
        case "orchestration":
            return ServiceVersionInfo(
                service: service,
                current: "1.0",
                min: "1.0",
                max: "1.0",
                headers: ["X-OpenStack-Heat-API-Version": "1.0"]
            )
        case "key-manager":
            return ServiceVersionInfo(
                service: service,
                current: "1.1",
                min: "1.0",
                max: "1.1",
                headers: ["X-OpenStack-Barbican-API-Version": "1.1"]
            )
        case "load-balancer":
            return ServiceVersionInfo(
                service: service,
                current: "2.5",
                min: "2.0",
                max: "2.5",
                headers: ["X-OpenStack-Octavia-API-Version": "2.5"]
            )
        default:
            return ServiceVersionInfo(
                service: service,
                current: "latest",
                min: "latest",
                max: "latest",
                headers: [:]
            )
        }
    }

    /// Clear cached version information (useful for testing or when endpoints change)
    public func clearCache() async {
        detectedVersions.removeAll()
        logger.logInfo("Microversion cache cleared", context: [:])
    }

    /// Get cached version information for debugging
    public func getVersionInfo(for service: String) async -> ServiceVersionInfo? {
        return detectedVersions[service]
    }
}

// MARK: - Supporting Types

/// Information about a service's API version support
public struct ServiceVersionInfo: Sendable {
    public let service: String
    public let current: String
    public let min: String
    public let max: String
    public let headers: [String: String]

    public init(service: String, current: String, min: String, max: String, headers: [String: String]) {
        self.service = service
        self.current = current
        self.min = min
        self.max = max
        self.headers = headers
    }
}

