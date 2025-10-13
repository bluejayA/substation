import Foundation
import MemoryKit
import Crypto
#if canImport(CommonCrypto)
import CommonCrypto
#endif
#if canImport(Security)
import Security
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Combine)
import Combine
#endif

// MARK: - Core Infrastructure

/// Shared resource pool for high performance
internal enum SharedResources {
    nonisolated(unsafe) static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try multiple date formats used by OpenStack
            let formatters = [
                // ISO8601 with microseconds
                createDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
                // ISO8601 with milliseconds
                createDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSS"),
                // Standard ISO8601
                createDateFormatter("yyyy-MM-dd'T'HH:mm:ss"),
                // ISO8601 with Z
                createDateFormatter("yyyy-MM-dd'T'HH:mm:ss'Z'"),
                // ISO8601 with microseconds and Z
                createDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'")
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Could not parse date string: \(dateString)"
            )
        }
        return decoder
    }()

    private static func createDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    static func createURLSession(logger: any OpenStackClientLogger) -> (URLSession, EnhancedSecureURLSessionDelegate) {
        let delegate = EnhancedSecureURLSessionDelegate(logger: logger)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 10
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        return (session, delegate)
    }
}

// MARK: - Configuration and Credentials

public struct OpenStackConfig: Sendable {
    public let authURL: URL
    public let region: String
    public let userDomainName: String
    public let projectDomainName: String
    public let timeout: TimeInterval
    public let retryPolicy: RetryPolicy

    public init(
        authURL: URL,
        region: String = "auto-detect",
        userDomainName: String = "default",
        projectDomainName: String = "default",
        timeout: TimeInterval = 30.0,
        retryPolicy: RetryPolicy = RetryPolicy()
    ) {
        self.authURL = authURL
        self.region = region
        self.userDomainName = userDomainName
        self.projectDomainName = projectDomainName
        self.timeout = timeout
        self.retryPolicy = retryPolicy
    }
}

public enum OpenStackCredentials: Sendable {
    case password(username: String, password: String, projectName: String?, projectID: String? = nil, userDomainName: String? = nil, userDomainID: String? = nil, projectDomainName: String? = nil, projectDomainID: String? = nil)
    case applicationCredential(id: String, secret: String, projectName: String?, projectID: String? = nil)
}

// MARK: - Retry Policy

public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let retryStatusCodes: Set<Int>

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        retryStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryStatusCodes = retryStatusCodes
    }

    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        return min(exponentialDelay, maxDelay)
    }
}

// MARK: - Caching

internal protocol CacheProtocol: Sendable {
    func get(key: String) async -> Data?
    func set(key: String, data: Data) async
    func clear() async
}


// MARK: - Logging

public protocol OpenStackClientLogger: Sendable {
    func logError(_ message: String, context: [String: any Sendable])
    func logInfo(_ message: String, context: [String: any Sendable])
    func logDebug(_ message: String, context: [String: any Sendable])
    func logAPICall(_ method: String, url: String, statusCode: Int?, duration: TimeInterval?)
}

public struct ConsoleLogger: OpenStackClientLogger {
    public init() {}

    public func logError(_ message: String, context: [String: any Sendable] = [:]) {
        let contextStr = context.isEmpty ? "" : " Context: \(context)"
        print("[ERROR] \(message)\(contextStr)")
    }

    public func logInfo(_ message: String, context: [String: any Sendable] = [:]) {
        let contextStr = context.isEmpty ? "" : " Context: \(context)"
        print("[INFO] \(message)\(contextStr)")
    }

    public func logDebug(_ message: String, context: [String: any Sendable] = [:]) {
        let contextStr = context.isEmpty ? "" : " Context: \(context)"
        print("[DEBUG] \(message)\(contextStr)")
    }

    public func logAPICall(_ method: String, url: String, statusCode: Int? = nil, duration: TimeInterval? = nil) {
        var message = "\(method) \(url)"
        if let status = statusCode {
            message += " -> \(status)"
        }
        if let duration = duration {
            message += " (\(String(format: "%.3f", duration))s)"
        }
        print("[API] \(message)")
    }
}

// MARK: - Error Types

public enum OpenStackError: Error, LocalizedError, Sendable {
    case authenticationFailed
    case endpointNotFound(service: String)
    case unexpectedResponse
    case httpError(Int, String? = nil)
    case networkError(any Error)
    case decodingError(any Error)
    case encodingError(any Error)
    case configurationError(String)
    case performanceEnhancementsNotAvailable
    case missingRequiredField(String)
    case invalidResponse
    case invalidURL(String)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed"
        case .endpointNotFound(let service):
            return "Endpoint not found for service: \(service)"
        case .unexpectedResponse:
            return "Unexpected response from server"
        case .httpError(let code, let message):
            return "HTTP error: \(code)" + (message.map { " - \($0)" } ?? "")
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .performanceEnhancementsNotAvailable:
            return "Performance enhancements are not available or not initialized"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        }
    }
}

// MARK: - Security Infrastructure

public final class SecureBuffer: @unchecked Sendable {
    private var data: Data

    public init(capacity: Int) {
        self.data = Data(count: capacity)
    }

    deinit {
        // Zero the data
        data.resetBytes(in: 0..<data.count)
    }

    public func withUnsafeBytes<T>(_ body: (UnsafeBufferPointer<UInt8>) throws -> T) rethrows -> T {
        return try data.withUnsafeBytes { rawBuffer in
            let typedBuffer = rawBuffer.bindMemory(to: UInt8.self)
            return try body(typedBuffer)
        }
    }

    public func withUnsafeMutableBytes<T>(_ body: (UnsafeMutableBufferPointer<UInt8>) throws -> T) rethrows -> T {
        return try data.withUnsafeMutableBytes { rawBuffer in
            let typedBuffer = rawBuffer.bindMemory(to: UInt8.self)
            return try body(typedBuffer)
        }
    }

    /// Securely clear the buffer
    public func clear() {
        data.resetBytes(in: 0..<data.count)
    }

    public var count: Int {
        return data.count
    }
}

public struct SecureString: Sendable {
    private let buffer: SecureBuffer
    private let length: Int

    public init(_ string: String) {
        let utf8Data = string.utf8
        self.length = utf8Data.count
        self.buffer = SecureBuffer(capacity: length)

        let utf8Array = Array(utf8Data)
        buffer.withUnsafeMutableBytes { bufferPtr in
            for (index, byte) in utf8Array.enumerated() {
                if index < bufferPtr.count {
                    bufferPtr[index] = byte
                }
            }
        }
    }

    public init() {
        self.length = 0
        self.buffer = SecureBuffer(capacity: 1)
    }

    public func withUnsafeString<T>(_ body: (String) throws -> T) rethrows -> T {
        return try buffer.withUnsafeBytes { bufferPtr in
            let data = Data(bufferPtr.prefix(length))
            let string = String(data: data, encoding: .utf8) ?? ""
            return try body(string)
        }
    }

    public var isEmpty: Bool {
        return length == 0
    }
}

public final class CredentialEncryption: @unchecked Sendable {
    private let key: Data

    public init() {
        // Generate a random encryption key for this session (32 bytes for AES-256)
        var keyData = Data(count: 32)
        keyData.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            #if canImport(Security)
            _ = SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
            #else
            // Fallback for platforms without Security framework
            for i in 0..<32 {
                bytes[i] = UInt8.random(in: 0...255)
            }
            #endif
        }
        self.key = keyData
    }

    /// Encrypt sensitive data using AES-256-GCM encryption (cross-platform via swift-crypto)
    public func encrypt(_ data: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        return sealedBox.combined!
    }

    /// Decrypt previously encrypted data using AES-256-GCM (cross-platform via swift-crypto)
    public func decrypt(_ encryptedData: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    /// Encrypt a string and return secure encrypted storage
    public func encryptString(_ string: String) throws -> Data {
        let data = string.data(using: .utf8) ?? Data()
        return try encrypt(data)
    }

    /// Decrypt and return a SecureString
    public func decryptToSecureString(_ encryptedData: Data) throws -> SecureString {
        let decryptedData = try decrypt(encryptedData)
        let string = String(data: decryptedData, encoding: .utf8) ?? ""
        return SecureString(string)
    }
}

/// Enhanced URL session delegate with comprehensive certificate validation
public final class EnhancedSecureURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let logger: any OpenStackClientLogger

    public init(logger: any OpenStackClientLogger = ConsoleLogger()) {
        self.logger = logger
        super.init()
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        #if canImport(Security)
        // Check server trust authentication method
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger.logError("No server trust available", context: [:])
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Use Security framework for certificate validation on Apple platforms
        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        guard isValid else {
            let errorDescription = error?.localizedDescription ?? "Unknown error"
            logger.logError("Certificate validation failed", context: [
                "host": challenge.protectionSpace.host,
                "error": errorDescription
            ])
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        logger.logInfo("Certificate validation successful", context: [
            "host": challenge.protectionSpace.host
        ])

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
        #else
        // On Linux, rely on URLSession's default certificate validation
        // This uses the system's certificate store and validates the chain properly
        logger.logInfo("Using system certificate validation", context: [
            "host": challenge.protectionSpace.host
        ])

        // Perform default handling which includes proper certificate validation
        // This will validate against the system's CA bundle
        completionHandler(.performDefaultHandling, nil)
        #endif
    }
}

public actor CoreTokenManager {
    private var encryptedToken: Data?
    private var tokenExpiry: Date?
    private var refreshTask: Task<String, any Error>?
    private let refreshThreshold: TimeInterval = 300 // 5 minutes
    private let encryption = CredentialEncryption()
    private let logger: any OpenStackClientLogger

    public init(logger: any OpenStackClientLogger = ConsoleLogger()) {
        self.logger = logger
    }

    public var token: String? {
        guard let encryptedToken = encryptedToken else { return nil }
        return try? encryption.decryptToSecureString(encryptedToken).withUnsafeString { $0 }
    }

    public var expiry: Date? {
        return tokenExpiry
    }

    public func setToken(_ token: String, expiresAt: Date) {
        do {
            self.encryptedToken = try encryption.encryptString(token)
            self.tokenExpiry = expiresAt
            refreshTask?.cancel()
            refreshTask = nil
            logger.logInfo("Token stored securely", context: ["expires": expiresAt.description])
        } catch {
            logger.logError("Failed to encrypt token", context: ["error": error.localizedDescription])
        }
    }

    public func getValidToken(refreshHandler: @escaping () async throws -> (String, Date)) async throws -> String {
        // Check if we have a valid token
        if let encryptedToken = encryptedToken,
           let expiry = tokenExpiry,
           Date() < expiry.addingTimeInterval(-refreshThreshold) {
            do {
                return try encryption.decryptToSecureString(encryptedToken).withUnsafeString { $0 }
            } catch {
                logger.logError("Failed to decrypt token", context: ["error": error.localizedDescription])
                // Fall through to refresh
            }
        }

        // If there's already a refresh in progress, wait for it
        if let refreshTask = refreshTask {
            return try await refreshTask.value
        }

        // Start a new refresh
        let task = Task {
            logger.logInfo("Refreshing authentication token", context: [:])
            let (newToken, newExpiry) = try await refreshHandler()
            setToken(newToken, expiresAt: newExpiry)
            logger.logInfo("Token refreshed successfully", context: ["newExpiration": newExpiry.description])
            return newToken
        }

        refreshTask = task
        return try await task.value
    }

    public func clearToken() {
        encryptedToken = nil
        tokenExpiry = nil
        refreshTask?.cancel()
        refreshTask = nil
        logger.logInfo("Token cleared from memory", context: [:])
    }

    public var isTokenValid: Bool {
        guard let expiry = tokenExpiry, encryptedToken != nil else { return false }
        return Date() < expiry.addingTimeInterval(-refreshThreshold)
    }

    /// Get time until token expiration
    public var timeUntilExpiration: TimeInterval? {
        return tokenExpiry?.timeIntervalSinceNow
    }
}

// MARK: - Base Client

public actor OpenStackClientCore {
    private let config: OpenStackConfig
    private let credentials: OpenStackCredentials
    private let logger: any OpenStackClientLogger
    private let memoryManager: MemoryManager
    private let tokenManager: CoreTokenManager
    private let urlSession: URLSession
    private let urlSessionDelegate: EnhancedSecureURLSessionDelegate
    private var serviceCatalog: [String: URL] = [:]
    private var currentProjectId: String?
    private var currentProjectName: String?
    private let microversionManager: MicroversionManager

    internal init(config: OpenStackConfig, credentials: OpenStackCredentials, logger: any OpenStackClientLogger) {
        self.config = config
        self.credentials = credentials
        self.logger = logger
        self.memoryManager = MemoryManager(configuration: MemoryManager.Configuration(
            maxCacheSize: 5000, // Increased for OpenStack API data density
            maxMemoryBudget: 120 * 1024 * 1024, // 120MB optimized for OpenStack Core
            cleanupInterval: 300.0, // Reduced frequency to lower CPU usage
            pressureThreshold: 0.85, // Higher threshold for core operations
            logger: OpenStackClientLoggerAdapter(clientLogger: logger)
        ))
        self.tokenManager = CoreTokenManager(logger: logger)
        let (session, delegate) = SharedResources.createURLSession(logger: logger)
        self.urlSession = session
        self.urlSessionDelegate = delegate
        self.microversionManager = MicroversionManager(logger: logger)

        // Initialize memory management and monitoring asynchronously
        Task { [weak self] in
            guard let self = self else { return }
            await self.initializeMemoryManagement()
            await self.microversionManager.setCore(self)
        }
    }

    // MARK: - Public Configuration Access

    /// Access to the configuration for this client
    public var clientConfig: OpenStackConfig {
        config
    }

    /// Access to the credentials for this client
    public var clientCredentials: OpenStackCredentials {
        credentials
    }

    /// Access to the logger for this client
    public var clientLogger: any OpenStackClientLogger {
        logger
    }

    /// Access to the memory manager for this client
    public var clientMemoryManager: MemoryManager {
        memoryManager
    }

    /// Access to the current project ID
    public var projectId: String? {
        currentProjectId
    }

    /// Access to the current project name (from token)
    public var projectName: String? {
        currentProjectName
    }

    // MARK: - Authentication

    public func ensureAuthenticated() async throws -> String {
        let manager = tokenManager
        return try await manager.getValidToken { [weak self] in
            guard let self = self else { throw OpenStackError.authenticationFailed }
            try await self.performAuthentication()
            guard let token = await manager.token,
                  let expiry = await manager.expiry else {
                throw OpenStackError.authenticationFailed
            }
            return (token, expiry)
        }
    }

    private func createAuthenticationData() -> (Identity, AuthScope?) {
        switch credentials {
        case .password(let username, let password, let projectName, let projectID, let userDomainName, let userDomainID, let projectDomainName, let projectDomainID):
            // Build user domain - prefer ID over name
            let userDomain: AuthDomain
            if let userDomainID = userDomainID {
                userDomain = AuthDomain(id: userDomainID, name: nil)
            } else if let userDomainName = userDomainName {
                userDomain = AuthDomain(name: userDomainName)
            } else {
                userDomain = AuthDomain(name: "default")
            }

            let identity = Identity(
                methods: ["password"],
                password: AuthPassword(
                    user: AuthUser(
                        name: username,
                        domain: userDomain,
                        password: password
                    )
                ),
                applicationCredential: nil
            )

            // Build project scope - prefer ID over name
            let scope: AuthScope
            if let projectID = projectID {
                scope = AuthScope(project: AuthProject(id: projectID, name: nil, domain: nil))
            } else if let projectName = projectName {
                // Build project domain - prefer ID over name
                let projectDomain: AuthDomain?
                if let projectDomainID = projectDomainID {
                    projectDomain = AuthDomain(id: projectDomainID, name: nil)
                } else if let projectDomainName = projectDomainName {
                    projectDomain = AuthDomain(name: projectDomainName)
                } else {
                    projectDomain = AuthDomain(name: "default")
                }
                scope = AuthScope(project: AuthProject(name: projectName, domain: projectDomain))
            } else {
                // No project scoping - unscoped token
                scope = AuthScope(project: nil)
            }
            return (identity, scope)

        case .applicationCredential(let id, let secret, let projectName, let projectID):
            let identity = Identity(
                methods: ["application_credential"],
                password: nil,
                applicationCredential: AuthApplicationCredential(
                    id: id,
                    secret: secret
                )
            )
            // For application credentials, create scope if project info is provided
            let scope: AuthScope?
            if let projectID = projectID {
                scope = AuthScope(project: AuthProject(id: projectID, name: nil, domain: nil))
            } else if let projectName = projectName, !projectName.isEmpty {
                scope = AuthScope(project: AuthProject(name: projectName, domain: nil))
            } else {
                scope = nil
            }
            return (identity, scope)
        }
    }

    private func performAuthentication() async throws {
        let (identity, scope) = createAuthenticationData()
        let authRequest = AuthRequest(
            auth: AuthMethod(
                identity: identity,
                scope: scope
            )
        )

        let requestData = try SharedResources.jsonEncoder.encode(authRequest)

        // Debug: Log the authentication JSON request
        if let jsonString = String(data: requestData, encoding: .utf8) {
            logger.logInfo("Auth request JSON: \(jsonString)", context: [:])
        }

        let authURL = config.authURL.appendingPathComponent("/auth/tokens")
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData

        let startTime = Date()

        do {
            // Check if task was cancelled before making request
            try Task.checkCancellation()

            let (data, response) = try await urlSession.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenStackError.unexpectedResponse
            }

            logger.logAPICall("POST", url: request.url?.absoluteString ?? "", statusCode: httpResponse.statusCode, duration: duration)

            guard httpResponse.statusCode == 201 else {
                throw OpenStackError.httpError(httpResponse.statusCode)
            }

            guard let token = httpResponse.value(forHTTPHeaderField: "X-Subject-Token") else {
                throw OpenStackError.authenticationFailed
            }

            let authResponse = try SharedResources.jsonDecoder.decode(AuthResponse.self, from: data)

            // Store project ID and name if available
            self.currentProjectId = authResponse.token.project?.id
            self.currentProjectName = authResponse.token.project?.name

            await tokenManager.setToken(token, expiresAt: authResponse.token.expiresAt)

            // Build service catalog
            self.serviceCatalog = [:]
            for service in authResponse.token.catalog {
                for endpoint in service.endpoints {
                    if endpoint.region == config.region && endpoint.interface == "public" {
                        serviceCatalog[service.type] = URL(string: endpoint.url)
                    }
                }
            }

            logger.logInfo("Authentication successful", context: ["region": config.region])

        } catch {
            logger.logError("Authentication failed", context: ["error": error.localizedDescription])
            throw OpenStackError.networkError(error)
        }
    }

    // MARK: - Request Handling

    public func request<T: Decodable>(
        service: String,
        method: String,
        path: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        expected: Int
    ) async throws -> T {
        let requestStartTime = Date()
        let token = try await ensureAuthenticated()

        guard let baseURL = serviceCatalog[service] else {
            throw OpenStackError.endpointNotFound(service: service)
        }

        let url: URL
        if path.contains("?") {
            let pathParts = path.split(separator: "?", maxSplits: 1)
            let pathComponent = String(pathParts[0])
            let queryString = pathParts.count > 1 ? String(pathParts[1]) : ""
            var components = URLComponents(url: baseURL.appendingPathComponent(pathComponent), resolvingAgainstBaseURL: false)!
            components.percentEncodedQuery = queryString
            url = components.url!
        } else {
            url = baseURL.appendingPathComponent(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Auth-Token")

        // Get optimal microversion headers for this service
        let microversionHeaders = await microversionManager.getVersionHeaders(for: service)
        for (key, value) in microversionHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add custom headers (these can override microversion headers if needed)
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let body = body {
            request.httpBody = body
        }

        do {
            let result: T = try await performRequest(request: request, expected: expected)

            // Record successful API call metric
            let duration = Date().timeIntervalSince(requestStartTime) * 1000.0 // Convert to milliseconds
            await SharedTelemetryActor.shared.recordMetric(Metric(
                timestamp: Date(),
                type: .apiCallDuration,
                value: duration,
                context: [
                    "service": service,
                    "method": method,
                    "path": path,
                    "success": "true"
                ]
            ))

            return result
        } catch {
            // Record failed API call metric
            let duration = Date().timeIntervalSince(requestStartTime) * 1000.0
            await SharedTelemetryActor.shared.recordMetric(Metric(
                timestamp: Date(),
                type: .apiCallDuration,
                value: duration,
                context: [
                    "service": service,
                    "method": method,
                    "path": path,
                    "success": "false",
                    "error": "\(error)"
                ]
            ))
            throw error
        }
    }

    public func requestVoid(
        service: String,
        method: String,
        path: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        expected: Int
    ) async throws {
        let _: EmptyResponse = try await request(
            service: service,
            method: method,
            path: path,
            body: body,
            headers: headers,
            expected: expected
        )
    }

    public func requestRaw(
        service: String,
        method: String,
        path: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        expected: Int
    ) async throws -> Data {
        let token = try await ensureAuthenticated()

        guard let baseURL = serviceCatalog[service] else {
            throw OpenStackError.endpointNotFound(service: service)
        }

        let url: URL
        if path.contains("?") {
            let pathParts = path.split(separator: "?", maxSplits: 1)
            let pathComponent = String(pathParts[0])
            let queryString = pathParts.count > 1 ? String(pathParts[1]) : ""
            var components = URLComponents(url: baseURL.appendingPathComponent(pathComponent), resolvingAgainstBaseURL: false)!
            components.percentEncodedQuery = queryString
            url = components.url!
        } else {
            url = baseURL.appendingPathComponent(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "X-Auth-Token")

        // Get optimal microversion headers for this service
        let microversionHeaders = await microversionManager.getVersionHeaders(for: service)
        for (key, value) in microversionHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add custom headers (these can override microversion headers if needed)
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let body = body {
            request.httpBody = body
        }

        return try await performRawRequest(request: request, expected: expected)
    }

    public func requestWithHeaders(
        service: String,
        method: String,
        path: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        expected: Int
    ) async throws -> (data: Data, headers: [String: String]) {
        let token = try await ensureAuthenticated()

        guard let baseURL = serviceCatalog[service] else {
            throw OpenStackError.endpointNotFound(service: service)
        }

        let url: URL
        if path.contains("?") {
            let pathParts = path.split(separator: "?", maxSplits: 1)
            let pathComponent = String(pathParts[0])
            let queryString = pathParts.count > 1 ? String(pathParts[1]) : ""
            var components = URLComponents(url: baseURL.appendingPathComponent(pathComponent), resolvingAgainstBaseURL: false)!
            components.percentEncodedQuery = queryString
            url = components.url!
        } else {
            url = baseURL.appendingPathComponent(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "X-Auth-Token")

        // Get optimal microversion headers for this service
        let microversionHeaders = await microversionManager.getVersionHeaders(for: service)
        for (key, value) in microversionHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add custom headers (these can override microversion headers if needed)
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let body = body {
            request.httpBody = body
        }

        return try await performRawRequestWithHeaders(request: request, expected: expected)
    }

    /// Get endpoint URL for a service
    public func getEndpoint(for service: String) async throws -> String {
        guard let baseURL = serviceCatalog[service] else {
            throw OpenStackError.endpointNotFound(service: service)
        }
        return baseURL.absoluteString
    }

    /// Get microversion information for a service
    public func getMicroversionInfo(for service: String) async -> ServiceVersionInfo? {
        return await microversionManager.getVersionInfo(for: service)
    }

    /// Clear microversion cache (useful for testing)
    public func clearMicroversionCache() async {
        await microversionManager.clearCache()
    }

    private func performRequest<T: Decodable>(request: URLRequest, expected: Int) async throws -> T {
        var lastError: (any Error)?

        for attempt in 1...config.retryPolicy.maxAttempts {
            let startTime = Date()

            do {
                // Check if task was cancelled before making request
                try Task.checkCancellation()

                let (data, response) = try await urlSession.data(for: request)
                let duration = Date().timeIntervalSince(startTime)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenStackError.unexpectedResponse
                }

                logger.logAPICall(
                    request.httpMethod ?? "GET",
                    url: request.url?.absoluteString ?? "",
                    statusCode: httpResponse.statusCode,
                    duration: duration
                )

                if httpResponse.statusCode == expected {
                    if T.self == EmptyResponse.self {
                        return EmptyResponse() as! T
                    }

                    do {
                        return try SharedResources.jsonDecoder.decode(T.self, from: data)
                    } catch {
                        throw OpenStackError.decodingError(error)
                    }
                }

                if config.retryPolicy.retryStatusCodes.contains(httpResponse.statusCode) && attempt < config.retryPolicy.maxAttempts {
                    let delay = config.retryPolicy.delay(for: attempt)
                    logger.logInfo("Retrying request", context: [
                        "attempt": attempt,
                        "statusCode": httpResponse.statusCode,
                        "delay": delay
                    ])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // Log error response body for debugging and extract error message
                var errorMessage: String? = nil
                if let errorBody = String(data: data, encoding: .utf8) {
                    logger.logDebug("API Error Response", context: [
                        "statusCode": httpResponse.statusCode,
                        "body": errorBody
                    ])

                    // Try to parse OpenStack error response
                    errorMessage = parseOpenStackError(from: data)
                }

                throw OpenStackError.httpError(httpResponse.statusCode, errorMessage)

            } catch {
                lastError = error

                if attempt < config.retryPolicy.maxAttempts {
                    let delay = config.retryPolicy.delay(for: attempt)
                    logger.logInfo("Retrying request due to error", context: [
                        "attempt": attempt,
                        "error": error.localizedDescription,
                        "delay": delay
                    ])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                throw OpenStackError.networkError(error)
            }
        }

        throw lastError ?? OpenStackError.unexpectedResponse
    }

    private func performRawRequest(request: URLRequest, expected: Int) async throws -> Data {
        var lastError: (any Error)?

        for attempt in 1...config.retryPolicy.maxAttempts {
            let startTime = Date()

            do {
                // Check if task was cancelled before making request
                try Task.checkCancellation()

                let (data, response) = try await urlSession.data(for: request)
                let duration = Date().timeIntervalSince(startTime)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenStackError.unexpectedResponse
                }

                logger.logAPICall(
                    request.httpMethod ?? "GET",
                    url: request.url?.absoluteString ?? "",
                    statusCode: httpResponse.statusCode,
                    duration: duration
                )

                if httpResponse.statusCode == expected {
                    return data
                }

                if config.retryPolicy.retryStatusCodes.contains(httpResponse.statusCode) && attempt < config.retryPolicy.maxAttempts {
                    let delay = config.retryPolicy.delay(for: attempt)
                    logger.logInfo("Retrying request", context: [
                        "attempt": attempt,
                        "statusCode": httpResponse.statusCode,
                        "delay": delay
                    ])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // Log error response body for debugging and extract error message
                var errorMessage: String? = nil
                if let errorBody = String(data: data, encoding: .utf8) {
                    logger.logDebug("API Error Response", context: [
                        "statusCode": httpResponse.statusCode,
                        "body": errorBody
                    ])

                    // Try to parse OpenStack error response
                    errorMessage = parseOpenStackError(from: data)
                }

                throw OpenStackError.httpError(httpResponse.statusCode, errorMessage)

            } catch {
                lastError = error

                if attempt < config.retryPolicy.maxAttempts {
                    let delay = config.retryPolicy.delay(for: attempt)
                    logger.logInfo("Retrying request due to error", context: [
                        "attempt": attempt,
                        "error": error.localizedDescription,
                        "delay": delay
                    ])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                throw OpenStackError.networkError(error)
            }
        }

        throw lastError ?? OpenStackError.unexpectedResponse
    }

    private func performRawRequestWithHeaders(request: URLRequest, expected: Int) async throws -> (data: Data, headers: [String: String]) {
        var lastError: (any Error)?

        for attempt in 1...config.retryPolicy.maxAttempts {
            let startTime = Date()

            do {
                // Check if task was cancelled before making request
                try Task.checkCancellation()

                let (data, response) = try await urlSession.data(for: request)
                let duration = Date().timeIntervalSince(startTime)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenStackError.unexpectedResponse
                }

                logger.logAPICall(
                    request.httpMethod ?? "GET",
                    url: request.url?.absoluteString ?? "",
                    statusCode: httpResponse.statusCode,
                    duration: duration
                )

                if httpResponse.statusCode == expected {
                    // Extract all HTTP headers
                    var headers: [String: String] = [:]
                    for (key, value) in httpResponse.allHeaderFields {
                        if let keyString = key as? String, let valueString = value as? String {
                            headers[keyString] = valueString
                        }
                    }
                    return (data, headers)
                }

                if config.retryPolicy.retryStatusCodes.contains(httpResponse.statusCode) && attempt < config.retryPolicy.maxAttempts {
                    let delay = config.retryPolicy.delay(for: attempt)
                    logger.logInfo("Retrying request", context: [
                        "attempt": attempt,
                        "statusCode": httpResponse.statusCode,
                        "delay": delay
                    ])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // Log error response body for debugging and extract error message
                var errorMessage: String? = nil
                if let errorBody = String(data: data, encoding: .utf8) {
                    logger.logDebug("API Error Response", context: [
                        "statusCode": httpResponse.statusCode,
                        "body": errorBody
                    ])

                    // Try to parse OpenStack error response
                    errorMessage = parseOpenStackError(from: data)
                }

                throw OpenStackError.httpError(httpResponse.statusCode, errorMessage)

            } catch {
                lastError = error

                if attempt < config.retryPolicy.maxAttempts {
                    let delay = config.retryPolicy.delay(for: attempt)
                    logger.logInfo("Retrying request due to error", context: [
                        "attempt": attempt,
                        "error": error.localizedDescription,
                        "delay": delay
                    ])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                throw OpenStackError.networkError(error)
            }
        }

        throw lastError ?? OpenStackError.unexpectedResponse
    }

    // MARK: - Cache Access

    internal func getCached(key: String) async -> Data? {
        let result = await memoryManager.retrieve(forKey: key, as: Data.self)
        logger.logInfo("[DEBUG] Cache lookup", context: [
            "key": key,
            "hit": result != nil
        ])
        return result
    }

    internal func setCached(key: String, data: Data) async {
        logger.logInfo("[DEBUG] Caching data", context: [
            "key": key,
            "size": data.count
        ])
        await memoryManager.store(data, forKey: key)
    }

    internal func clearCache() async {
        logger.logInfo("Clearing all caches", context: [:])
        await memoryManager.clearAll()
        await tokenManager.clearToken()
        logger.logInfo("All caches cleared", context: [:])
    }

    // Note: getCacheStats removed - use memoryManager.getCacheStats() directly if needed

    /// Initialize memory pressure monitoring
    internal func initializeMemoryManagement() {
        // MemoryKit provides its own monitoring and cleanup
        // No additional setup needed
    }

    /// Get time until token expiration for UI display
    public var timeUntilTokenExpiration: TimeInterval? {
        get async {
            return await tokenManager.timeUntilExpiration
        }
    }

    /// Cleanup and invalidate URLSession to prevent dangling references
    deinit {
        urlSession.invalidateAndCancel()
    }
}

// MARK: - Response Helpers

internal struct EmptyResponse: Codable {}

// MARK: - Authentication Models

private struct AuthRequest: Codable {
    let auth: AuthMethod
}

private struct AuthMethod: Codable {
    let identity: Identity
    let scope: AuthScope?
}

private struct Identity: Codable {
    let methods: [String]
    let password: AuthPassword?
    let applicationCredential: AuthApplicationCredential?

    enum CodingKeys: String, CodingKey {
        case methods
        case password
        case applicationCredential = "application_credential"
    }
}

private struct AuthPassword: Codable {
    let user: AuthUser
}

private struct AuthApplicationCredential: Codable {
    let id: String
    let secret: String
}

private struct AuthUser: Codable {
    let name: String
    let domain: AuthDomain
    let password: String
}

private struct AuthDomain: Codable {
    let id: String?
    let name: String?

    init(id: String? = nil, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

private struct AuthScope: Codable {
    let project: AuthProject?
}

private struct AuthProject: Codable {
    let id: String?
    let name: String?
    let domain: AuthDomain?

    init(id: String? = nil, name: String? = nil, domain: AuthDomain? = nil) {
        self.id = id
        self.name = name
        self.domain = domain
    }
}

private struct AuthResponse: Codable {
    let token: Token
}

private struct Token: Codable {
    let expiresAt: Date
    let catalog: [ServiceCatalog]
    let project: AuthTokenProject?

    enum CodingKeys: String, CodingKey {
        case expiresAt = "expires_at"
        case catalog
        case project
    }
}

private struct AuthTokenProject: Codable {
    let id: String
    let name: String
    let domain: AuthTokenDomain
}

private struct AuthTokenDomain: Codable {
    let id: String
    let name: String
}

private struct ServiceCatalog: Codable {
    let type: String
    let endpoints: [AuthEndpoint]
}

private struct AuthEndpoint: Codable {
    let region: String
    let url: String
    let interface: String
}

// MARK: - Error Parsing

/// Parse OpenStack error responses to extract user-friendly error messages
private func parseOpenStackError(from data: Data) -> String? {
    // OpenStack services use different error response formats
    // Try common formats: NeutronError, ComputeError, etc.

    struct NeutronErrorResponse: Codable {
        let NeutronError: ErrorDetail
    }

    struct ComputeErrorResponse: Codable {
        let badRequest: ErrorDetail?
        let forbidden: ErrorDetail?
        let itemNotFound: ErrorDetail?
        let conflict: ErrorDetail?
    }

    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let detail: String?
    }

    // Try Neutron error format
    if let neutronError = try? JSONDecoder().decode(NeutronErrorResponse.self, from: data) {
        return neutronError.NeutronError.message
    }

    // Try Compute/Nova error format
    if let computeError = try? JSONDecoder().decode(ComputeErrorResponse.self, from: data) {
        if let error = computeError.badRequest ?? computeError.forbidden ?? computeError.itemNotFound ?? computeError.conflict {
            return error.message
        }
    }

    // Try generic error format
    struct GenericError: Codable {
        let error: ErrorDetail
    }

    if let genericError = try? JSONDecoder().decode(GenericError.self, from: data) {
        return genericError.error.message
    }

    return nil
}