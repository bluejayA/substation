import Foundation
import OSClient

// MARK: - Template System Core

/// Template parameter validation and type information
public struct TemplateParameter: Sendable, Hashable, Codable {
    public let name: String
    public let type: ParameterType
    public let description: String
    public let defaultValue: String?
    public let required: Bool
    public let validation: ParameterValidation?

    public init(
        name: String,
        type: ParameterType,
        description: String,
        defaultValue: String? = nil,
        required: Bool = false,
        validation: ParameterValidation? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.defaultValue = defaultValue
        self.required = required
        self.validation = validation
    }
}

/// Parameter types supported by the template system
public enum ParameterType: String, Sendable, CaseIterable, Codable {
    case string = "string"
    case integer = "integer"
    case boolean = "boolean"
    case array = "array"
    case object = "object"
    case flavor = "flavor"
    case image = "image"
    case network = "network"
    case securityGroup = "securityGroup"
    case keyPair = "keyPair"
    case availabilityZone = "availabilityZone"

    public var displayName: String {
        switch self {
        case .string: return "Text"
        case .integer: return "Number"
        case .boolean: return "Yes/No"
        case .array: return "List"
        case .object: return "Configuration"
        case .flavor: return "Server Flavor"
        case .image: return "VM Image"
        case .network: return "Network"
        case .securityGroup: return "Security Group"
        case .keyPair: return "SSH Key Pair"
        case .availabilityZone: return "Availability Zone"
        }
    }
}

/// Parameter validation rules
public struct ParameterValidation: Sendable, Hashable, Codable {
    public let minLength: Int?
    public let maxLength: Int?
    public let minValue: Int?
    public let maxValue: Int?
    public let pattern: String?
    public let allowedValues: [String]?

    public init(
        minLength: Int? = nil,
        maxLength: Int? = nil,
        minValue: Int? = nil,
        maxValue: Int? = nil,
        pattern: String? = nil,
        allowedValues: [String]? = nil
    ) {
        self.minLength = minLength
        self.maxLength = maxLength
        self.minValue = minValue
        self.maxValue = maxValue
        self.pattern = pattern
        self.allowedValues = allowedValues
    }
}

/// Resource definition within a template
public struct TemplateResource: Sendable, Hashable, Codable {
    public let id: String
    public let type: TemplateResourceType
    public let name: String
    public let configuration: [String: String]
    public let dependsOn: [String]
    public let tags: [String: String]

    public init(
        id: String,
        type: TemplateResourceType,
        name: String,
        configuration: [String: String],
        dependsOn: [String] = [],
        tags: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.configuration = configuration
        self.dependsOn = dependsOn
        self.tags = tags
    }
}

/// Resource types supported in templates
public enum TemplateResourceType: String, Sendable, CaseIterable, Codable {
    case server = "server"
    case network = "network"
    case subnet = "subnet"
    case router = "router"
    case volume = "volume"
    case floatingIP = "floatingIP"
    case securityGroup = "securityGroup"
    case keyPair = "keyPair"
    case port = "port"

    public var displayName: String {
        switch self {
        case .server: return "Virtual Server"
        case .network: return "Network"
        case .subnet: return "Subnet"
        case .router: return "Router"
        case .volume: return "Block Storage"
        case .floatingIP: return "Floating IP"
        case .securityGroup: return "Security Group"
        case .keyPair: return "SSH Key Pair"
        case .port: return "Network Port"
        }
    }
}

/// Template resource dependency relationship
public struct TemplateDependency: Sendable, Hashable, Codable {
    public let resourceID: String
    public let dependsOn: String
    public let dependencyType: DependencyType

    public init(resourceID: String, dependsOn: String, dependencyType: DependencyType) {
        self.resourceID = resourceID
        self.dependsOn = dependsOn
        self.dependencyType = dependencyType
    }
}

/// Types of resource dependencies
public enum DependencyType: String, Sendable, CaseIterable, Codable {
    case hardDependency = "hard"     // Must complete before this resource can start
    case softDependency = "soft"     // Preferred order but can run in parallel
    case references = "references"    // This resource references the other

    public var description: String {
        switch self {
        case .hardDependency: return "Required prerequisite"
        case .softDependency: return "Preferred order"
        case .references: return "Resource reference"
        }
    }
}

/// Template deployment progress tracking
public struct TemplateDeploymentProgress: Sendable {
    public let templateID: String
    public let status: DeploymentStatus
    public let currentStage: String
    public let currentResource: String?
    public let completedResources: Int
    public let totalResources: Int
    public let estimatedTimeRemaining: TimeInterval?
    public let errors: [DeploymentError]
    public let warnings: [String]

    public init(
        templateID: String,
        status: DeploymentStatus,
        currentStage: String,
        currentResource: String? = nil,
        completedResources: Int,
        totalResources: Int,
        estimatedTimeRemaining: TimeInterval? = nil,
        errors: [DeploymentError] = [],
        warnings: [String] = []
    ) {
        self.templateID = templateID
        self.status = status
        self.currentStage = currentStage
        self.currentResource = currentResource
        self.completedResources = completedResources
        self.totalResources = totalResources
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.errors = errors
        self.warnings = warnings
    }
}

/// Deployment status states
public enum DeploymentStatus: String, Sendable, CaseIterable, Codable {
    case preparing = "preparing"
    case validating = "validating"
    case deploying = "deploying"
    case completed = "completed"
    case failed = "failed"
    case rollingBack = "rollingBack"
    case cancelled = "cancelled"

    public var displayName: String {
        switch self {
        case .preparing: return "Preparing"
        case .validating: return "Validating"
        case .deploying: return "Deploying"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .rollingBack: return "Rolling Back"
        case .cancelled: return "Cancelled"
        }
    }
}

/// Template deployment errors
public struct DeploymentError: Sendable, Error, Codable {
    public let resourceID: String?
    public let errorCode: String
    public let message: String
    public let timestamp: Date
    public let recoverable: Bool

    public init(
        resourceID: String? = nil,
        errorCode: String,
        message: String,
        timestamp: Date = Date(),
        recoverable: Bool = false
    ) {
        self.resourceID = resourceID
        self.errorCode = errorCode
        self.message = message
        self.timestamp = timestamp
        self.recoverable = recoverable
    }
}

/// Template deployment result
public struct TemplateDeploymentResult: Sendable {
    public let templateID: String
    public let deploymentID: String
    public let status: DeploymentStatus
    public let resources: [String: String] // Resource ID -> OpenStack resource ID mapping
    public let duration: TimeInterval
    public let errors: [DeploymentError]
    public let warnings: [String]
    public let metadata: [String: String]

    public init(
        templateID: String,
        deploymentID: String,
        status: DeploymentStatus,
        resources: [String: String],
        duration: TimeInterval,
        errors: [DeploymentError] = [],
        warnings: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.templateID = templateID
        self.deploymentID = deploymentID
        self.status = status
        self.resources = resources
        self.duration = duration
        self.errors = errors
        self.warnings = warnings
        self.metadata = metadata
    }
}

// MARK: - Template Manager

/// Actor-based template manager for parameter validation and deployment orchestration
actor TemplateManager {

    // MARK: - Properties

    private let client: OSClient
    private let deploymentEngine: DeploymentEngine
    private let templateLibrary: TemplateLibrary
    private let maxConcurrency: Int

    // Active deployments tracking
    private var activeDeployments: [String: TemplateDeploymentExecution] = [:]
    private var deploymentHistory: [String: TemplateDeploymentResult] = [:]

    // Progress tracking
    private var progressCallbacks: [String: (TemplateDeploymentProgress) -> Void] = [:]

    // Cancellation support
    private var cancellationTokens: [String: Bool] = [:]

    // MARK: - Internal Types

    private struct TemplateDeploymentExecution {
        let template: any ResourceTemplate
        let parameters: [String: Any]
        let deploymentID: String
        let startTime: Date
        var currentStage: String
        var completedResources: Int
        var totalResources: Int
    }

    // MARK: - Initialization

    public init(client: OSClient, maxConcurrency: Int = 5) {
        self.client = client
        self.maxConcurrency = maxConcurrency
        self.deploymentEngine = DeploymentEngine(client: client, maxConcurrency: maxConcurrency)
        self.templateLibrary = TemplateLibrary()
        Logger.shared.logInfo("TemplateManager - Initialized with maxConcurrency=\(maxConcurrency)")
    }

    // MARK: - Public Interface

    /// Get all available templates
    public func getAvailableTemplates() -> [any ResourceTemplate] {
        return templateLibrary.getAllTemplates()
    }

    /// Get a specific template by ID
    public func getTemplate(id: String) -> (any ResourceTemplate)? {
        return templateLibrary.getTemplate(id: id)
    }

    /// Validate template parameters
    public func validateParameters(
        templateID: String,
        parameters: [String: Any]
    ) throws -> ParameterValidationResult {
        guard let template = templateLibrary.getTemplate(id: templateID) else {
            throw TemplateError.templateNotFound(templateID)
        }

        let startTime = Date()
        var validationErrors: [ParameterValidationError] = []
        var validatedParameters: [String: String] = [:]

        // Check required parameters
        for templateParam in template.parameters {
            if templateParam.required && parameters[templateParam.name] == nil {
                validationErrors.append(ParameterValidationError(
                    parameterName: templateParam.name,
                    errorType: .required,
                    message: "Parameter '\(templateParam.name)' is required but not provided"
                ))
                continue
            }

            // Get parameter value (use default if not provided)
            let paramValue: Any?
            if let providedValue = parameters[templateParam.name] {
                paramValue = providedValue
            } else if let defaultValue = templateParam.defaultValue {
                paramValue = defaultValue
            } else {
                paramValue = nil
            }

            guard let value = paramValue else {
                continue // Optional parameter not provided and no default
            }

            // Type validation
            do {
                let validatedValue = try validateParameterType(value: value, expectedType: templateParam.type)

                // Custom validation rules
                if let validation = templateParam.validation {
                    try validateParameterRules(value: validatedValue, rules: validation, parameterName: templateParam.name)
                }

                validatedParameters[templateParam.name] = String(describing: validatedValue)
            } catch let error as ParameterValidationError {
                validationErrors.append(error)
            } catch {
                validationErrors.append(ParameterValidationError(
                    parameterName: templateParam.name,
                    errorType: .validation,
                    message: "Validation error: \(error.localizedDescription)"
                ))
            }
        }

        // Check for unexpected parameters
        for (paramName, _) in parameters {
            if !template.parameters.contains(where: { $0.name == paramName }) {
                validationErrors.append(ParameterValidationError(
                    parameterName: paramName,
                    errorType: .unknown,
                    message: "Unknown parameter '\(paramName)'"
                ))
            }
        }

        let validationTime = Date().timeIntervalSince(startTime)
        Logger.shared.logInfo("TemplateManager - Parameter validation completed in \(String(format: "%.2f", validationTime))s for template '\(templateID)'")

        return ParameterValidationResult(
            isValid: validationErrors.isEmpty,
            validatedParameters: validatedParameters,
            errors: validationErrors,
            validationTime: validationTime
        )
    }

    /// Deploy a template with the given parameters
    public func deployTemplate(
        templateID: String,
        parameters: [String: Any],
        onProgress: @escaping (TemplateDeploymentProgress) -> Void
    ) async -> TemplateDeploymentResult {
        let deploymentID = UUID().uuidString
        let startTime = Date()

        Logger.shared.logInfo("TemplateManager - Starting template deployment: \(templateID)")

        // Store progress callback
        progressCallbacks[deploymentID] = onProgress

        do {
            // Phase 1: Get template
            guard let template = templateLibrary.getTemplate(id: templateID) else {
                throw TemplateError.templateNotFound(templateID)
            }

            await updateProgress(
                deploymentID: deploymentID,
                templateID: templateID,
                status: .preparing,
                stage: "Preparing deployment",
                completedResources: 0,
                totalResources: template.resources.count
            )

            // Phase 2: Validate parameters
            let validationResult = try validateParameters(templateID: templateID, parameters: parameters)

            await updateProgress(
                deploymentID: deploymentID,
                templateID: templateID,
                status: .validating,
                stage: "Validating parameters",
                completedResources: 0,
                totalResources: template.resources.count
            )

            if !validationResult.isValid {
                let errorMessages = validationResult.errors.map { $0.message }
                throw TemplateError.parameterValidation(errorMessages.joined(separator: ", "))
            }

            // Phase 3: Create deployment execution context
            let execution = TemplateDeploymentExecution(
                template: template,
                parameters: validationResult.validatedParameters,
                deploymentID: deploymentID,
                startTime: startTime,
                currentStage: "Deploying resources",
                completedResources: 0,
                totalResources: template.resources.count
            )

            activeDeployments[deploymentID] = execution

            await updateProgress(
                deploymentID: deploymentID,
                templateID: templateID,
                status: .deploying,
                stage: "Deploying resources",
                completedResources: 0,
                totalResources: template.resources.count
            )

            // Phase 4: Execute deployment via deployment engine
            let engine = deploymentEngine
            let deploymentResult = await engine.deployTemplate(
                template: template,
                parameters: validationResult.validatedParameters,
                onProgress: { @Sendable progress in
                    // Progress callback - DeploymentEngine is not yet implemented
                    // This will be properly implemented when DeploymentEngine is built
                    // For now, just a placeholder to satisfy the interface
                }
            )

            // Phase 5: Complete deployment
            activeDeployments.removeValue(forKey: deploymentID)
            progressCallbacks.removeValue(forKey: deploymentID)

            let finalResult = TemplateDeploymentResult(
                templateID: templateID,
                deploymentID: deploymentID,
                status: deploymentResult.status,
                resources: deploymentResult.resources,
                duration: Date().timeIntervalSince(startTime),
                errors: deploymentResult.errors,
                warnings: deploymentResult.warnings,
                metadata: deploymentResult.metadata
            )

            deploymentHistory[deploymentID] = finalResult

            await updateProgress(
                deploymentID: deploymentID,
                templateID: templateID,
                status: finalResult.status,
                stage: finalResult.status == .completed ? "Deployment completed" : "Deployment failed",
                completedResources: finalResult.status == .completed ? template.resources.count : 0,
                totalResources: template.resources.count
            )

            Logger.shared.logInfo("TemplateManager - Template deployment completed: \(templateID) in \(String(format: "%.2f", finalResult.duration))s")

            return finalResult

        } catch {
            // Handle deployment failure
            activeDeployments.removeValue(forKey: deploymentID)
            progressCallbacks.removeValue(forKey: deploymentID)

            let failureResult = TemplateDeploymentResult(
                templateID: templateID,
                deploymentID: deploymentID,
                status: .failed,
                resources: [:],
                duration: Date().timeIntervalSince(startTime),
                errors: [DeploymentError(
                    errorCode: "DEPLOYMENT_FAILED",
                    message: error.localizedDescription
                )],
                warnings: []
            )

            deploymentHistory[deploymentID] = failureResult

            await updateProgress(
                deploymentID: deploymentID,
                templateID: templateID,
                status: .failed,
                stage: "Deployment failed",
                completedResources: 0,
                totalResources: 0
            )

            Logger.shared.logError("TemplateManager - Template deployment failed: \(templateID) - \(error.localizedDescription)")

            return failureResult
        }
    }

    /// Cancel an active deployment
    public func cancelDeployment(deploymentID: String) async -> Bool {
        guard activeDeployments[deploymentID] != nil else {
            return false
        }

        cancellationTokens[deploymentID] = true

        // Forward cancellation to deployment engine
        let engine = deploymentEngine
        let cancelled = await engine.cancelDeployment(deploymentID: deploymentID)

        if cancelled {
            activeDeployments.removeValue(forKey: deploymentID)
            progressCallbacks.removeValue(forKey: deploymentID)
            cancellationTokens.removeValue(forKey: deploymentID)

            Logger.shared.logInfo("TemplateManager - Deployment cancelled: \(deploymentID)")
        }

        return cancelled
    }

    /// Get deployment history
    public func getDeploymentHistory() -> [TemplateDeploymentResult] {
        return Array(deploymentHistory.values).sorted { $0.templateID < $1.templateID }
    }

    /// Get active deployments
    public func getActiveDeployments() -> [String] {
        return Array(activeDeployments.keys)
    }

    // MARK: - Private Methods

    private func validateParameterType(value: Any, expectedType: ParameterType) throws -> Any {
        switch expectedType {
        case .string:
            guard let stringValue = value as? String else {
                throw ParameterValidationError(
                    parameterName: "",
                    errorType: .type,
                    message: "Expected string value"
                )
            }
            return stringValue

        case .integer:
            if let intValue = value as? Int {
                return intValue
            } else if let stringValue = value as? String, let intValue = Int(stringValue) {
                return intValue
            } else {
                throw ParameterValidationError(
                    parameterName: "",
                    errorType: .type,
                    message: "Expected integer value"
                )
            }

        case .boolean:
            if let boolValue = value as? Bool {
                return boolValue
            } else if let stringValue = value as? String {
                switch stringValue.lowercased() {
                case "true", "yes", "1":
                    return true
                case "false", "no", "0":
                    return false
                default:
                    throw ParameterValidationError(
                        parameterName: "",
                        errorType: .type,
                        message: "Expected boolean value"
                    )
                }
            } else {
                throw ParameterValidationError(
                    parameterName: "",
                    errorType: .type,
                    message: "Expected boolean value"
                )
            }

        case .array:
            guard let arrayValue = value as? [Any] else {
                throw ParameterValidationError(
                    parameterName: "",
                    errorType: .type,
                    message: "Expected array value"
                )
            }
            return arrayValue

        case .object:
            guard let objectValue = value as? [String: Any] else {
                throw ParameterValidationError(
                    parameterName: "",
                    errorType: .type,
                    message: "Expected object value"
                )
            }
            return objectValue

        case .flavor, .image, .network, .securityGroup, .keyPair, .availabilityZone:
            guard let stringValue = value as? String, !stringValue.isEmpty else {
                throw ParameterValidationError(
                    parameterName: "",
                    errorType: .type,
                    message: "Expected non-empty string for \(expectedType.displayName)"
                )
            }
            return stringValue
        }
    }

    private func validateParameterRules(
        value: Any,
        rules: ParameterValidation,
        parameterName: String
    ) throws {
        // String validation
        if let stringValue = value as? String {
            if let minLength = rules.minLength, stringValue.count < minLength {
                throw ParameterValidationError(
                    parameterName: parameterName,
                    errorType: .validation,
                    message: "Minimum length is \(minLength) characters"
                )
            }

            if let maxLength = rules.maxLength, stringValue.count > maxLength {
                throw ParameterValidationError(
                    parameterName: parameterName,
                    errorType: .validation,
                    message: "Maximum length is \(maxLength) characters"
                )
            }

            if let pattern = rules.pattern {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: stringValue.utf16.count)
                if regex.firstMatch(in: stringValue, options: [], range: range) == nil {
                    throw ParameterValidationError(
                        parameterName: parameterName,
                        errorType: .validation,
                        message: "Value does not match required pattern"
                    )
                }
            }

            if let allowedValues = rules.allowedValues, !allowedValues.contains(stringValue) {
                throw ParameterValidationError(
                    parameterName: parameterName,
                    errorType: .validation,
                    message: "Value must be one of: \(allowedValues.joined(separator: ", "))"
                )
            }
        }

        // Integer validation
        if let intValue = value as? Int {
            if let minValue = rules.minValue, intValue < minValue {
                throw ParameterValidationError(
                    parameterName: parameterName,
                    errorType: .validation,
                    message: "Minimum value is \(minValue)"
                )
            }

            if let maxValue = rules.maxValue, intValue > maxValue {
                throw ParameterValidationError(
                    parameterName: parameterName,
                    errorType: .validation,
                    message: "Maximum value is \(maxValue)"
                )
            }
        }
    }

    private func updateProgress(
        deploymentID: String,
        templateID: String,
        status: DeploymentStatus,
        stage: String,
        completedResources: Int,
        totalResources: Int,
        currentResource: String? = nil,
        errors: [DeploymentError] = [],
        warnings: [String] = []
    ) async {
        guard let callback = progressCallbacks[deploymentID] else { return }

        let estimatedTimeRemaining: TimeInterval?
        if status == .deploying && completedResources > 0 {
            let avgTimePerResource = Date().timeIntervalSince(activeDeployments[deploymentID]?.startTime ?? Date()) / Double(completedResources)
            estimatedTimeRemaining = avgTimePerResource * Double(totalResources - completedResources)
        } else {
            estimatedTimeRemaining = nil
        }

        let progress = TemplateDeploymentProgress(
            templateID: templateID,
            status: status,
            currentStage: stage,
            currentResource: currentResource,
            completedResources: completedResources,
            totalResources: totalResources,
            estimatedTimeRemaining: estimatedTimeRemaining,
            errors: errors,
            warnings: warnings
        )

        callback(progress)
    }

    private func forwardEngineProgress(deploymentID: String, engineProgress: Any) async {
        // Forward progress from deployment engine to template progress
        // This would be implemented based on the specific DeploymentEngine progress format
        // For now, we'll just update the stage
        if var execution = activeDeployments[deploymentID] {
            execution.currentStage = "Processing resources"
            activeDeployments[deploymentID] = execution
        }
    }
}

// MARK: - Supporting Types

/// Parameter validation result
public struct ParameterValidationResult: Sendable {
    public let isValid: Bool
    public let validatedParameters: [String: String]
    public let errors: [ParameterValidationError]
    public let validationTime: TimeInterval

    public init(
        isValid: Bool,
        validatedParameters: [String: String],
        errors: [ParameterValidationError],
        validationTime: TimeInterval
    ) {
        self.isValid = isValid
        self.validatedParameters = validatedParameters
        self.errors = errors
        self.validationTime = validationTime
    }
}

/// Parameter validation error
public struct ParameterValidationError: Sendable, Error {
    public let parameterName: String
    public let errorType: ValidationErrorType
    public let message: String

    public init(parameterName: String, errorType: ValidationErrorType, message: String) {
        self.parameterName = parameterName
        self.errorType = errorType
        self.message = message
    }
}

/// Validation error types
public enum ValidationErrorType: String, Sendable, CaseIterable {
    case required = "required"
    case type = "type"
    case validation = "validation"
    case unknown = "unknown"

    public var description: String {
        switch self {
        case .required: return "Required parameter missing"
        case .type: return "Type mismatch"
        case .validation: return "Validation rule failed"
        case .unknown: return "Unknown parameter"
        }
    }
}

/// Template system errors
public enum TemplateError: Error, Sendable {
    case templateNotFound(String)
    case parameterValidation(String)
    case deploymentFailed(String)
    case configurationError(String)

    public var localizedDescription: String {
        switch self {
        case .templateNotFound(let id):
            return "Template not found: \(id)"
        case .parameterValidation(let message):
            return "Parameter validation failed: \(message)"
        case .deploymentFailed(let message):
            return "Deployment failed: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

// Forward declarations for dependent classes that will be implemented next
final class DeploymentEngine: @unchecked Sendable {
    let client: OSClient
    let maxConcurrency: Int

    init(client: OSClient, maxConcurrency: Int) {
        self.client = client
        self.maxConcurrency = maxConcurrency
    }

    func deployTemplate(
        template: any ResourceTemplate,
        parameters: [String: Any],
        onProgress: @escaping (Any) -> Void
    ) async -> TemplateDeploymentResult {
        // Will be implemented in DeploymentEngine.swift
        return TemplateDeploymentResult(
            templateID: template.id,
            deploymentID: UUID().uuidString,
            status: .failed,
            resources: [:],
            duration: 0,
            errors: [DeploymentError(errorCode: "NOT_IMPLEMENTED", message: "DeploymentEngine not yet implemented")]
        )
    }

    func cancelDeployment(deploymentID: String) async -> Bool {
        // Will be implemented in DeploymentEngine.swift
        return false
    }
}

class TemplateLibrary {
    func getAllTemplates() -> [any ResourceTemplate] {
        // Will be implemented in TemplateLibrary.swift
        return []
    }

    func getTemplate(id: String) -> (any ResourceTemplate)? {
        // Will be implemented in TemplateLibrary.swift
        return nil
    }
}

// Core ResourceTemplate protocol that will be implemented in ResourceTemplates.swift
public protocol ResourceTemplate: Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var version: String { get }
    var category: String { get }
    var tags: [String] { get }
    var parameters: [TemplateParameter] { get }
    var resources: [TemplateResource] { get }
    var dependencies: [TemplateDependency] { get }
    var estimatedDeploymentTime: TimeInterval { get }

    func validate(parameters: [String: Any]) throws
}