import Foundation

// MARK: - Telemetry Models

public struct Metric: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: MetricType
    public let value: Double
    public let tags: [String: String]
    public let context: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: MetricType,
        value: Double,
        tags: [String: String] = [:],
        context: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.value = value
        self.tags = tags
        self.context = context
    }
}

public enum MetricType: String, Codable, CaseIterable, Sendable {
    case apiCallDuration = "api_call_duration"
    case apiCallCount = "api_call_count"
    case cacheHitRate = "cache_hit_rate"
    case cacheMissRate = "cache_miss_rate"
    case memoryUsage = "memory_usage"
    case cpuUsage = "cpu_usage"
    case networkLatency = "network_latency"
    case errorRate = "error_rate"
    case resourceCount = "resource_count"
    case operationSuccess = "operation_success"
}

public struct HealthScore: Codable, Sendable {
    public let overall: Double
    public let components: [String: Double]
    public let timestamp: Date
    public let status: HealthStatus

    public init(overall: Double, components: [String: Double], timestamp: Date = Date(), status: HealthStatus) {
        self.overall = overall
        self.components = components
        self.timestamp = timestamp
        self.status = status
    }
}

public enum HealthStatus: String, Codable, CaseIterable, Sendable {
    case healthy = "healthy"
    case degraded = "degraded"
    case unhealthy = "unhealthy"
    case unknown = "unknown"
}

public struct Alert: Codable, Sendable {
    public let id: UUID
    public let type: AlertType
    public let severity: AlertSeverity
    public let message: String
    public let timestamp: Date
    public let acknowledged: Bool
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        type: AlertType,
        severity: AlertSeverity,
        message: String,
        timestamp: Date = Date(),
        acknowledged: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.message = message
        self.timestamp = timestamp
        self.acknowledged = acknowledged
        self.metadata = metadata
    }
}

public enum AlertType: String, Codable, CaseIterable, Sendable {
    case performanceThreshold = "performance_threshold"
    case errorRateSpike = "error_rate_spike"
    case resourceExhaustion = "resource_exhaustion"
    case serviceDown = "service_down"
    case connectionIssue = "connection_issue"
    case securityEvent = "security_event"
}

public enum AlertSeverity: String, Codable, CaseIterable, Sendable {
    case critical = "critical"
    case warning = "warning"
    case info = "info"
}

// MARK: - Search Models

public struct SearchQuery: Codable, Sendable {
    public let query: String
    public let filters: [SearchFilter]
    public let sortBy: SortCriteria?
    public let limit: Int
    public let offset: Int

    public init(
        query: String,
        filters: [SearchFilter] = [],
        sortBy: SortCriteria? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.query = query
        self.filters = filters
        self.sortBy = sortBy
        self.limit = limit
        self.offset = offset
    }
}

public struct SearchFilter: Codable, Sendable {
    public let field: String
    public let `operator`: FilterOperator
    public let value: String

    public init(field: String, operator: FilterOperator, value: String) {
        self.field = field
        self.`operator` = `operator`
        self.value = value
    }
}

public enum FilterOperator: String, Codable, CaseIterable, Sendable {
    case equals = "eq"
    case notEquals = "ne"
    case contains = "contains"
    case startsWith = "starts_with"
    case endsWith = "ends_with"
    case greaterThan = "gt"
    case lessThan = "lt"
    case greaterThanOrEqual = "gte"
    case lessThanOrEqual = "lte"
}

public struct SortCriteria: Codable, Sendable {
    public let field: String
    public let direction: SortDirection

    public init(field: String, direction: SortDirection) {
        self.field = field
        self.direction = direction
    }
}

public struct SearchResult: Codable, Sendable {
    public let items: [ResourceReference]
    public let totalCount: Int
    public let hasMore: Bool
    public let searchTime: TimeInterval
    public let facets: [SearchFacet]

    public init(
        items: [ResourceReference],
        totalCount: Int,
        hasMore: Bool,
        searchTime: TimeInterval,
        facets: [SearchFacet] = []
    ) {
        self.items = items
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.searchTime = searchTime
        self.facets = facets
    }
}

public struct ResourceReference: Codable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let type: String
    public let properties: [String: String]
    public let score: Double?

    public init(
        id: String,
        name: String?,
        type: String,
        properties: [String: String] = [:],
        score: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.properties = properties
        self.score = score
    }
}

public struct SearchFacet: Codable, Sendable {
    public let field: String
    public let values: [FacetValue]

    public init(field: String, values: [FacetValue]) {
        self.field = field
        self.values = values
    }
}

public struct FacetValue: Codable, Sendable {
    public let value: String
    public let count: Int

    public init(value: String, count: Int) {
        self.value = value
        self.count = count
    }
}

public struct Relationship: Codable, Sendable {
    public let fromResource: String
    public let toResource: String
    public let type: RelationshipType
    public let strength: Double

    public init(fromResource: String, toResource: String, type: RelationshipType, strength: Double = 1.0) {
        self.fromResource = fromResource
        self.toResource = toResource
        self.type = type
        self.strength = strength
    }
}

public enum RelationshipType: String, Codable, CaseIterable, Sendable {
    case dependsOn = "depends_on"
    case contains = "contains"
    case connectedTo = "connected_to"
    case attachedTo = "attached_to"
    case rulesFor = "rules_for"
}

public struct ResourceRelationshipMap: Codable, Sendable {
    public private(set) var relationships: [String: [Relationship]] = [:]

    public init() {}

    public mutating func add(resource: ResourceReference, relationships: [Relationship]) {
        self.relationships[resource.id] = relationships
    }

    public func getRelationships(for resourceId: String) -> [Relationship] {
        return relationships[resourceId] ?? []
    }
}

// MARK: - Template Models

public struct Template: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let version: String
    public let description: String?
    public let parameters: [EnterpriseTemplateParameter]
    public let resources: [TemplateResource]
    public let outputs: [TemplateOutput]
    public let metadata: [String: String]
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        version: String,
        description: String? = nil,
        parameters: [EnterpriseTemplateParameter] = [],
        resources: [TemplateResource] = [],
        outputs: [TemplateOutput] = [],
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.parameters = parameters
        self.resources = resources
        self.outputs = outputs
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct EnterpriseTemplateParameter: Codable, Sendable {
    public let name: String
    public let type: ParameterType
    public let defaultValue: String?
    public let description: String?
    public let required: Bool
    public let constraints: [EnterpriseParameterConstraint]

    public init(
        name: String,
        type: ParameterType,
        defaultValue: String? = nil,
        description: String? = nil,
        required: Bool = true,
        constraints: [EnterpriseParameterConstraint] = []
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
        self.required = required
        self.constraints = constraints
    }
}

public enum ParameterType: String, Codable, CaseIterable, Sendable {
    case string
    case integer
    case boolean
    case array
    case object
}

public struct EnterpriseParameterConstraint: Codable, Sendable {
    public let type: ConstraintType
    public let value: String

    public init(type: ConstraintType, value: String) {
        self.type = type
        self.value = value
    }
}

public enum ConstraintType: String, Codable, CaseIterable, Sendable {
    case minLength = "min_length"
    case maxLength = "max_length"
    case minimum = "minimum"
    case maximum = "maximum"
    case pattern = "pattern"
    case allowedValues = "allowed_values"
}

public struct TemplateResource: Codable, Sendable {
    public let id: String
    public let type: String
    public let properties: [String: TemplateValue]
    public let dependsOn: [String]

    public init(id: String, type: String, properties: [String: TemplateValue], dependsOn: [String] = []) {
        self.id = id
        self.type = type
        self.properties = properties
        self.dependsOn = dependsOn
    }
}

public enum TemplateValue: Codable, Sendable {
    case string(String)
    case integer(Int)
    case boolean(Bool)
    case reference(String)
    case parameter(String)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            if stringValue.hasPrefix("${") && stringValue.hasSuffix("}") {
                let paramName = String(stringValue.dropFirst(2).dropLast(1))
                if paramName.contains(".") {
                    self = .reference(paramName)
                } else {
                    self = .parameter(paramName)
                }
            } else {
                self = .string(stringValue)
            }
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else {
            throw DecodingError.typeMismatch(
                TemplateValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported template value type")
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .reference(let ref):
            try container.encode("${\(ref)}")
        case .parameter(let param):
            try container.encode("${\(param)}")
        }
    }
}

public struct TemplateOutput: Codable, Sendable {
    public let name: String
    public let value: TemplateValue
    public let description: String?

    public init(name: String, value: TemplateValue, description: String? = nil) {
        self.name = name
        self.value = value
        self.description = description
    }
}

public struct ResolvedTemplate: Codable, Sendable {
    public let originalTemplate: Template
    public let resolvedResources: [ResolvedResource]
    public let outputs: [String: String]

    public init(originalTemplate: Template, resolvedResources: [ResolvedResource], outputs: [String: String]) {
        self.originalTemplate = originalTemplate
        self.resolvedResources = resolvedResources
        self.outputs = outputs
    }
}

public struct ResolvedResource: Codable, Sendable {
    public let id: String
    public let type: String
    public let properties: [String: String]

    public init(id: String, type: String, properties: [String: String]) {
        self.id = id
        self.type = type
        self.properties = properties
    }
}

public struct DeploymentResult: Codable, Sendable {
    public let deploymentId: UUID
    public let status: DeploymentStatus
    public let resources: [DeployedResource]
    public let outputs: [String: String]
    public let error: String?

    public init(
        deploymentId: UUID,
        status: DeploymentStatus,
        resources: [DeployedResource],
        outputs: [String: String],
        error: String? = nil
    ) {
        self.deploymentId = deploymentId
        self.status = status
        self.resources = resources
        self.outputs = outputs
        self.error = error
    }
}

public enum DeploymentStatus: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case inProgress = "in_progress"
    case success = "success"
    case failed = "failed"
    case rolledBack = "rolled_back"
}

public struct DeployedResource: Codable, Sendable {
    public let templateId: String
    public let resourceId: String
    public let type: String
    public let status: DeploymentResourceStatus

    public init(templateId: String, resourceId: String, type: String, status: DeploymentResourceStatus) {
        self.templateId = templateId
        self.resourceId = resourceId
        self.type = type
        self.status = status
    }
}

public enum DeploymentResourceStatus: String, Codable, CaseIterable, Sendable {
    case creating = "creating"
    case created = "created"
    case failed = "failed"
    case deleting = "deleting"
    case deleted = "deleted"
}

public struct DeploymentProgress: Codable, Sendable {
    public let deploymentId: UUID
    public let totalResources: Int
    public let completedResources: Int
    public let failedResources: Int
    public let currentPhase: String
    public let percentComplete: Double

    public init(
        deploymentId: UUID,
        totalResources: Int,
        completedResources: Int,
        failedResources: Int,
        currentPhase: String,
        percentComplete: Double
    ) {
        self.deploymentId = deploymentId
        self.totalResources = totalResources
        self.completedResources = completedResources
        self.failedResources = failedResources
        self.currentPhase = currentPhase
        self.percentComplete = percentComplete
    }
}

// MARK: - Configuration Models

public struct ConfigurationPackage: Codable, Sendable {
    public let version: String
    public let metadata: ConfigurationMetadata
    public let resources: ConfigurationResources
    public let relationships: [Relationship]

    public init(
        version: String,
        metadata: ConfigurationMetadata,
        resources: ConfigurationResources,
        relationships: [Relationship] = []
    ) {
        self.version = version
        self.metadata = metadata
        self.resources = resources
        self.relationships = relationships
    }
}

public struct ConfigurationMetadata: Codable, Sendable {
    public let exportedAt: Date
    public let environment: String
    public let openStackVersion: String
    public let description: String?

    public init(exportedAt: Date, environment: String, openStackVersion: String, description: String? = nil) {
        self.exportedAt = exportedAt
        self.environment = environment
        self.openStackVersion = openStackVersion
        self.description = description
    }
}

public struct ConfigurationResources: Codable, Sendable {
    public let servers: [String: [String: String]]
    public let networks: [String: [String: String]]
    public let securityGroups: [String: [String: String]]

    private enum CodingKeys: String, CodingKey {
        case servers, networks, securityGroups = "security_groups"
    }

    public init(
        servers: [String: [String: String]] = [:],
        networks: [String: [String: String]] = [:],
        securityGroups: [String: [String: String]] = [:]
    ) {
        self.servers = servers
        self.networks = networks
        self.securityGroups = securityGroups
    }
}

public struct ImportOptions: Codable, Sendable {
    public let overwriteExisting: Bool
    public let dryRun: Bool
    public let validateOnly: Bool

    public init(overwriteExisting: Bool = false, dryRun: Bool = false, validateOnly: Bool = false) {
        self.overwriteExisting = overwriteExisting
        self.dryRun = dryRun
        self.validateOnly = validateOnly
    }
}

public struct ImportResult: Codable, Sendable {
    public let success: Bool
    public let importedResources: [String]
    public let skippedResources: [String]
    public let errors: [String]

    public init(success: Bool, importedResources: [String], skippedResources: [String], errors: [String]) {
        self.success = success
        self.importedResources = importedResources
        self.skippedResources = skippedResources
        self.errors = errors
    }
}