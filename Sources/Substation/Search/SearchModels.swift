import Foundation
import OSClient
import struct OSClient.Port

// MARK: - Core Search Models

public struct SearchQuery: Codable, Sendable, Equatable {
    let text: String
    let filters: [SearchFilter]
    let resourceTypes: [SearchResourceType]
    let sorting: SearchSorting
    let pagination: SearchPagination
    let fuzzySearch: Bool
    let includeRelationships: Bool

    public init(
        text: String = "",
        filters: [SearchFilter] = [],
        resourceTypes: [SearchResourceType] = [],
        sorting: SearchSorting = .relevance,
        pagination: SearchPagination = SearchPagination(),
        fuzzySearch: Bool = false,
        includeRelationships: Bool = false
    ) {
        self.text = text
        self.filters = filters
        self.resourceTypes = resourceTypes
        self.sorting = sorting
        self.pagination = pagination
        self.fuzzySearch = fuzzySearch
        self.includeRelationships = includeRelationships
    }

    public static func == (lhs: SearchQuery, rhs: SearchQuery) -> Bool {
        return lhs.text == rhs.text &&
               lhs.filters == rhs.filters &&
               lhs.resourceTypes == rhs.resourceTypes &&
               lhs.sorting == rhs.sorting &&
               lhs.pagination == rhs.pagination &&
               lhs.fuzzySearch == rhs.fuzzySearch &&
               lhs.includeRelationships == rhs.includeRelationships
    }
}

public struct SearchResults: Codable, Sendable {
    let query: SearchQuery
    let items: [SearchResult]
    let totalCount: Int
    let searchTime: TimeInterval
    let suggestions: [SearchSuggestion]

    public init(
        query: SearchQuery,
        items: [SearchResult],
        totalCount: Int,
        searchTime: TimeInterval,
        suggestions: [SearchSuggestion] = []
    ) {
        self.query = query
        self.items = items
        self.totalCount = totalCount
        self.searchTime = searchTime
        self.suggestions = suggestions
    }
}

public struct SearchResult: Codable, Sendable, Identifiable {
    public let id: UUID
    public let resourceId: String
    public let resourceType: SearchResourceType
    public let name: String?
    public let description: String?
    public let status: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let ipAddresses: [String]
    public let metadata: [String: String]
    public let tags: [String]
    public var relevanceScore: Double
    public var matchHighlights: [TextRange]
    public var relationships: [ResourceRelationship]

    public init(
        id: UUID = UUID(),
        resourceId: String,
        resourceType: SearchResourceType,
        name: String?,
        description: String?,
        status: String?,
        createdAt: Date?,
        updatedAt: Date?,
        ipAddresses: [String],
        metadata: [String: String],
        tags: [String],
        relevanceScore: Double,
        matchHighlights: [TextRange],
        relationships: [ResourceRelationship] = []
    ) {
        self.id = id
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.name = name
        self.description = description
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.ipAddresses = ipAddresses
        self.metadata = metadata
        self.tags = tags
        self.relevanceScore = relevanceScore
        self.matchHighlights = matchHighlights
        self.relationships = relationships
    }
}

// MARK: - Search Filters

public struct SearchFilter: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let type: FilterType
    public let enabled: Bool

    public init(
        id: String = UUID().uuidString,
        type: FilterType,
        enabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.enabled = enabled
    }

    public var description: String {
        switch type {
        case .status(let statuses):
            return "Status: \(statuses.joined(separator: ", "))"
        case .dateRange(let from, let to):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "Date: \(formatter.string(from: from)) - \(formatter.string(from: to))"
        case .ipAddress(let pattern):
            return "IP: \(pattern)"
        case .metadata(let key, let value, let op):
            return "Metadata: \(key) \(op.symbol) \(value)"
        case .tags(let tags):
            return "Tags: \(tags.joined(separator: ", "))"
        case .resourceType(let types):
            return "Type: \(types.map { $0.displayName }.joined(separator: ", "))"
        }
    }

    public static func == (lhs: SearchFilter, rhs: SearchFilter) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.enabled == rhs.enabled
    }
}

public enum FilterType: Codable, Sendable, Equatable {
    case status([String])
    case dateRange(from: Date, to: Date)
    case ipAddress(String)
    case metadata(key: String, value: String, operator: FilterOperator)
    case tags([String])
    case resourceType([SearchResourceType])

    public static func == (lhs: FilterType, rhs: FilterType) -> Bool {
        switch (lhs, rhs) {
        case (.status(let a), .status(let b)):
            return a == b
        case (.dateRange(let a1, let a2), .dateRange(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.ipAddress(let a), .ipAddress(let b)):
            return a == b
        case (.metadata(let a1, let a2, let a3), .metadata(let b1, let b2, let b3)):
            return a1 == b1 && a2 == b2 && a3 == b3
        case (.tags(let a), .tags(let b)):
            return a == b
        case (.resourceType(let a), .resourceType(let b)):
            return a == b
        default:
            return false
        }
    }
}

public enum FilterOperator: String, Codable, CaseIterable, Sendable {
    case equals = "equals"
    case contains = "contains"
    case startsWith = "starts_with"
    case endsWith = "ends_with"

    public var displayName: String {
        switch self {
        case .equals: return "Equals"
        case .contains: return "Contains"
        case .startsWith: return "Starts With"
        case .endsWith: return "Ends With"
        }
    }

    public var symbol: String {
        switch self {
        case .equals: return "="
        case .contains: return "~"
        case .startsWith: return "^"
        case .endsWith: return "$"
        }
    }
}

// MARK: - Search Sorting

public enum SearchSorting: Codable, Sendable, Equatable {
    case relevance
    case name(SortDirection)
    case createdAt(SortDirection)
    case resourceType

    public var displayName: String {
        switch self {
        case .relevance: return "Relevance"
        case .name(let direction): return "Name (\(direction.symbol))"
        case .createdAt(let direction): return "Date Created (\(direction.symbol))"
        case .resourceType: return "Resource Type"
        }
    }

    public static func == (lhs: SearchSorting, rhs: SearchSorting) -> Bool {
        switch (lhs, rhs) {
        case (.relevance, .relevance), (.resourceType, .resourceType):
            return true
        case (.name(let a), .name(let b)):
            return a == b
        case (.createdAt(let a), .createdAt(let b)):
            return a == b
        default:
            return false
        }
    }
}

public enum SortDirection: String, Codable, CaseIterable, Sendable {
    case ascending = "asc"
    case descending = "desc"

    public var symbol: String {
        switch self {
        case .ascending: return "[UP]"
        case .descending: return "[DOWN]"
        }
    }

    public var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
}

// MARK: - Search Pagination

public struct SearchPagination: Codable, Sendable, Equatable {
    let offset: Int
    let limit: Int

    public init(offset: Int = 0, limit: Int = 50) {
        self.offset = offset
        self.limit = limit
    }

    public var hasNextPage: Bool {
        return limit > 0
    }

    public func nextPage() -> SearchPagination {
        return SearchPagination(offset: offset + limit, limit: limit)
    }

    public func previousPage() -> SearchPagination {
        return SearchPagination(offset: max(0, offset - limit), limit: limit)
    }

    public static func == (lhs: SearchPagination, rhs: SearchPagination) -> Bool {
        return lhs.offset == rhs.offset && lhs.limit == rhs.limit
    }
}

// MARK: - Resource Types

public enum SearchResourceType: String, Codable, CaseIterable, Sendable {
    case server = "server"
    case network = "network"
    case subnet = "subnet"
    case port = "port"
    case router = "router"
    case volume = "volume"
    case image = "image"
    case flavor = "flavor"
    case securityGroup = "security_group"
    case keyPair = "key_pair"
    case floatingIP = "floating_ip"
    case serverGroup = "server_group"
    case volumeSnapshot = "volume_snapshot"
    case volumeBackup = "volume_backup"
    case barbicanSecret = "barbican_secret"
    case barbicanContainer = "barbican_container"
    case loadBalancer = "load_balancer"
    case swiftContainer = "swift_container"
    case swiftObject = "swift_object"

    public var displayName: String {
        switch self {
        case .server: return "Server"
        case .network: return "Network"
        case .subnet: return "Subnet"
        case .port: return "Port"
        case .router: return "Router"
        case .volume: return "Volume"
        case .image: return "Image"
        case .flavor: return "Flavor"
        case .securityGroup: return "Security Group"
        case .keyPair: return "Key Pair"
        case .floatingIP: return "Floating IP"
        case .serverGroup: return "Server Group"
        case .volumeSnapshot: return "Volume Snapshot"
        case .volumeBackup: return "Volume Backup"
        case .barbicanSecret: return "Secret"
        case .barbicanContainer: return "Secret Container"
        case .loadBalancer: return "Load Balancer"
        case .swiftContainer: return "Object Container"
        case .swiftObject: return "Object"
        }
    }

    public var pluralDisplayName: String {
        switch self {
        case .server: return "Servers"
        case .network: return "Networks"
        case .subnet: return "Subnets"
        case .port: return "Ports"
        case .router: return "Routers"
        case .volume: return "Volumes"
        case .image: return "Images"
        case .flavor: return "Flavors"
        case .securityGroup: return "Security Groups"
        case .keyPair: return "Key Pairs"
        case .floatingIP: return "Floating IPs"
        case .serverGroup: return "Server Groups"
        case .volumeSnapshot: return "Volume Snapshots"
        case .volumeBackup: return "Volume Backups"
        case .barbicanSecret: return "Secrets"
        case .barbicanContainer: return "Secret Containers"
        case .loadBalancer: return "Load Balancers"
        case .swiftContainer: return "Object Containers"
        case .swiftObject: return "Objects"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .server: return "[SERVER]"
        case .network: return "[NET]"
        case .subnet: return "[PRIV]"
        case .port: return "[PORT]"
        case .router: return "[ROUTER]"
        case .volume: return "[VOL]"
        case .image: return "[IMG]"
        case .flavor: return "[CONF]"
        case .securityGroup: return "[SEC]"
        case .keyPair: return "[KEY]"
        case .floatingIP: return "[LINK]"
        case .serverGroup: return "[GROUP]"
        case .volumeSnapshot: return "[SNAP]"
        case .volumeBackup: return "[BACKUP]"
        case .barbicanSecret: return "[SECRET]"
        case .barbicanContainer: return "[VAULT]"
        case .loadBalancer: return "[LB]"
        case .swiftContainer: return "[BUCKET]"
        case .swiftObject: return "[FILE]"
        }
    }
}

// MARK: - Searchable Resources Container

public struct SearchableResources: Sendable {
    let servers: [Server]
    let networks: [Network]
    let subnets: [Subnet]
    let ports: [Port]
    let routers: [Router]
    let volumes: [Volume]
    let images: [Image]
    let flavors: [Flavor]
    let securityGroups: [SecurityGroup]
    let keyPairs: [KeyPair]
    let floatingIPs: [FloatingIP]
    let serverGroups: [ServerGroup]
    let volumeSnapshots: [VolumeSnapshot]
    let volumeBackups: [VolumeBackup]
    let barbicanSecrets: [Secret]
    let barbicanContainers: [BarbicanContainer]
    let loadBalancers: [LoadBalancer]
    let swiftContainers: [SwiftContainer]
    let swiftObjects: [SwiftObject]

    public init(
        servers: [Server] = [],
        networks: [Network] = [],
        subnets: [Subnet] = [],
        ports: [Port] = [],
        routers: [Router] = [],
        volumes: [Volume] = [],
        images: [Image] = [],
        flavors: [Flavor] = [],
        securityGroups: [SecurityGroup] = [],
        keyPairs: [KeyPair] = [],
        floatingIPs: [FloatingIP] = [],
        serverGroups: [ServerGroup] = [],
        volumeSnapshots: [VolumeSnapshot] = [],
        volumeBackups: [VolumeBackup] = [],
        barbicanSecrets: [Secret] = [],
        barbicanContainers: [BarbicanContainer] = [],
        loadBalancers: [LoadBalancer] = [],
        swiftContainers: [SwiftContainer] = [],
        swiftObjects: [SwiftObject] = []
    ) {
        self.servers = servers
        self.networks = networks
        self.subnets = subnets
        self.ports = ports
        self.routers = routers
        self.volumes = volumes
        self.images = images
        self.flavors = flavors
        self.securityGroups = securityGroups
        self.keyPairs = keyPairs
        self.floatingIPs = floatingIPs
        self.serverGroups = serverGroups
        self.volumeSnapshots = volumeSnapshots
        self.volumeBackups = volumeBackups
        self.barbicanSecrets = barbicanSecrets
        self.barbicanContainers = barbicanContainers
        self.loadBalancers = loadBalancers
        self.swiftContainers = swiftContainers
        self.swiftObjects = swiftObjects
    }

    public var totalResourceCount: Int {
        let count1 = servers.count + networks.count + subnets.count + ports.count
        let count2 = routers.count + volumes.count + images.count + flavors.count
        let count3 = securityGroups.count + keyPairs.count + floatingIPs.count + serverGroups.count
        let count4 = volumeSnapshots.count + volumeBackups.count + barbicanSecrets.count + barbicanContainers.count
        let count5 = loadBalancers.count + swiftContainers.count + swiftObjects.count
        return count1 + count2 + count3 + count4 + count5
    }

    public func resourcesOfType(_ type: SearchResourceType) -> Int {
        switch type {
        case .server: return servers.count
        case .network: return networks.count
        case .subnet: return subnets.count
        case .port: return ports.count
        case .router: return routers.count
        case .volume: return volumes.count
        case .image: return images.count
        case .flavor: return flavors.count
        case .securityGroup: return securityGroups.count
        case .keyPair: return keyPairs.count
        case .floatingIP: return floatingIPs.count
        case .serverGroup: return serverGroups.count
        case .volumeSnapshot: return volumeSnapshots.count
        case .volumeBackup: return volumeBackups.count
        case .barbicanSecret: return barbicanSecrets.count
        case .barbicanContainer: return barbicanContainers.count
        case .loadBalancer: return loadBalancers.count
        case .swiftContainer: return swiftContainers.count
        case .swiftObject: return swiftObjects.count
        }
    }
}

// MARK: - Search Context

public struct SearchContext: Sendable {
    let currentView: String?
    let selectedResourceId: String?
    let selectedResourceType: SearchResourceType?
    let userPreferences: SearchPreferences

    public init(
        currentView: String? = nil,
        selectedResourceId: String? = nil,
        selectedResourceType: SearchResourceType? = nil,
        userPreferences: SearchPreferences = SearchPreferences()
    ) {
        self.currentView = currentView
        self.selectedResourceId = selectedResourceId
        self.selectedResourceType = selectedResourceType
        self.userPreferences = userPreferences
    }
}

public struct SearchPreferences: Codable, Sendable {
    let defaultSorting: SearchSorting
    let defaultPageSize: Int
    let enableFuzzySearch: Bool
    let enableAutoComplete: Bool
    let enableRelationships: Bool
    let maxHistoryEntries: Int

    public init(
        defaultSorting: SearchSorting = .relevance,
        defaultPageSize: Int = 50,
        enableFuzzySearch: Bool = true,
        enableAutoComplete: Bool = true,
        enableRelationships: Bool = false,
        maxHistoryEntries: Int = 50
    ) {
        self.defaultSorting = defaultSorting
        self.defaultPageSize = defaultPageSize
        self.enableFuzzySearch = enableFuzzySearch
        self.enableAutoComplete = enableAutoComplete
        self.enableRelationships = enableRelationships
        self.maxHistoryEntries = maxHistoryEntries
    }
}

// MARK: - Search Analytics

public struct SearchAnalytics: Sendable {
    let totalSearches: Int
    let averageSearchTime: TimeInterval
    let mostSearchedTerms: [String: Int]
    let mostFilteredTypes: [SearchResourceType: Int]
    let searchSuccessRate: Double
    let cacheHitRate: Double

    public init(
        totalSearches: Int = 0,
        averageSearchTime: TimeInterval = 0,
        mostSearchedTerms: [String: Int] = [:],
        mostFilteredTypes: [SearchResourceType: Int] = [:],
        searchSuccessRate: Double = 0,
        cacheHitRate: Double = 0
    ) {
        self.totalSearches = totalSearches
        self.averageSearchTime = averageSearchTime
        self.mostSearchedTerms = mostSearchedTerms
        self.mostFilteredTypes = mostFilteredTypes
        self.searchSuccessRate = searchSuccessRate
        self.cacheHitRate = cacheHitRate
    }
}

// MARK: - Advanced Search Options

public struct AdvancedSearchOptions: Codable, Sendable {
    let searchScope: SearchScope
    let timeRange: SearchTimeRange?
    let includeDeleted: Bool
    let includeHidden: Bool
    let maxResults: Int?
    let highlightMatches: Bool

    public init(
        searchScope: SearchScope = .all,
        timeRange: SearchTimeRange? = nil,
        includeDeleted: Bool = false,
        includeHidden: Bool = false,
        maxResults: Int? = nil,
        highlightMatches: Bool = true
    ) {
        self.searchScope = searchScope
        self.timeRange = timeRange
        self.includeDeleted = includeDeleted
        self.includeHidden = includeHidden
        self.maxResults = maxResults
        self.highlightMatches = highlightMatches
    }
}

public enum SearchScope: String, Codable, CaseIterable, Sendable {
    case all = "all"
    case currentProject = "current_project"
    case currentView = "current_view"
    case favorites = "favorites"

    public var displayName: String {
        switch self {
        case .all: return "All Resources"
        case .currentProject: return "Current Project"
        case .currentView: return "Current View"
        case .favorites: return "Favorites"
        }
    }
}

public struct SearchTimeRange: Codable, Sendable {
    let from: Date
    let to: Date

    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }

    public static var last24Hours: SearchTimeRange {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        return SearchTimeRange(from: yesterday, to: now)
    }

    public static var lastWeek: SearchTimeRange {
        let now = Date()
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        return SearchTimeRange(from: lastWeek, to: now)
    }

    public static var lastMonth: SearchTimeRange {
        let now = Date()
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        return SearchTimeRange(from: lastMonth, to: now)
    }
}

// MARK: - Text Range (for highlighting)
// TextRange is defined in SearchIndexes.swift with Codable conformance

// MARK: - Search Builder Helper

public struct SearchQueryBuilder {
    private var query = SearchQuery()

    public mutating func text(_ text: String) -> SearchQueryBuilder {
        query = SearchQuery(
            text: text,
            filters: query.filters,
            resourceTypes: query.resourceTypes,
            sorting: query.sorting,
            pagination: query.pagination,
            fuzzySearch: query.fuzzySearch,
            includeRelationships: query.includeRelationships
        )
        return self
    }

    public mutating func filter(_ filter: SearchFilter) -> SearchQueryBuilder {
        var newFilters = query.filters
        newFilters.append(filter)
        query = SearchQuery(
            text: query.text,
            filters: newFilters,
            resourceTypes: query.resourceTypes,
            sorting: query.sorting,
            pagination: query.pagination,
            fuzzySearch: query.fuzzySearch,
            includeRelationships: query.includeRelationships
        )
        return self
    }

    public mutating func resourceType(_ type: SearchResourceType) -> SearchQueryBuilder {
        var newTypes = query.resourceTypes
        if !newTypes.contains(type) {
            newTypes.append(type)
        }
        query = SearchQuery(
            text: query.text,
            filters: query.filters,
            resourceTypes: newTypes,
            sorting: query.sorting,
            pagination: query.pagination,
            fuzzySearch: query.fuzzySearch,
            includeRelationships: query.includeRelationships
        )
        return self
    }

    public mutating func sorting(_ sorting: SearchSorting) -> SearchQueryBuilder {
        query = SearchQuery(
            text: query.text,
            filters: query.filters,
            resourceTypes: query.resourceTypes,
            sorting: sorting,
            pagination: query.pagination,
            fuzzySearch: query.fuzzySearch,
            includeRelationships: query.includeRelationships
        )
        return self
    }

    public mutating func fuzzy(_ enabled: Bool = true) -> SearchQueryBuilder {
        query = SearchQuery(
            text: query.text,
            filters: query.filters,
            resourceTypes: query.resourceTypes,
            sorting: query.sorting,
            pagination: query.pagination,
            fuzzySearch: enabled,
            includeRelationships: query.includeRelationships
        )
        return self
    }

    public mutating func includeRelationships(_ enabled: Bool = true) -> SearchQueryBuilder {
        query = SearchQuery(
            text: query.text,
            filters: query.filters,
            resourceTypes: query.resourceTypes,
            sorting: query.sorting,
            pagination: query.pagination,
            fuzzySearch: query.fuzzySearch,
            includeRelationships: enabled
        )
        return self
    }

    public func build() -> SearchQuery {
        return query
    }

    public static func create() -> SearchQueryBuilder {
        return SearchQueryBuilder()
    }
}

// MARK: - Global Search Models for Unified Search

public struct GlobalSearchQuery: Codable, Sendable, Equatable {
    let text: String
    let filters: [SearchFilter]
    let resourceTypes: [SearchResourceType]
    let sorting: SearchSorting
    let pagination: SearchPagination
    let fuzzySearch: Bool
    let includeRelationships: Bool
    let crossServiceEnabled: Bool
    let parallelSearchEnabled: Bool
    let searchScope: SearchScope
    let timeRange: SearchTimeRange?
    let maxResultsPerService: Int
    let includeServiceMetrics: Bool

    public init(
        text: String = "",
        filters: [SearchFilter] = [],
        resourceTypes: [SearchResourceType] = [],
        sorting: SearchSorting = .relevance,
        pagination: SearchPagination = SearchPagination(),
        fuzzySearch: Bool = true,
        includeRelationships: Bool = false,
        crossServiceEnabled: Bool = true,
        parallelSearchEnabled: Bool = true,
        searchScope: SearchScope = .all,
        timeRange: SearchTimeRange? = nil,
        maxResultsPerService: Int = 100,
        includeServiceMetrics: Bool = false
    ) {
        self.text = text
        self.filters = filters
        self.resourceTypes = resourceTypes
        self.sorting = sorting
        self.pagination = pagination
        self.fuzzySearch = fuzzySearch
        self.includeRelationships = includeRelationships
        self.crossServiceEnabled = crossServiceEnabled
        self.parallelSearchEnabled = parallelSearchEnabled
        self.searchScope = searchScope
        self.timeRange = timeRange
        self.maxResultsPerService = maxResultsPerService
        self.includeServiceMetrics = includeServiceMetrics
    }

    public func toSearchQuery() -> SearchQuery {
        return SearchQuery(
            text: text,
            filters: filters,
            resourceTypes: resourceTypes,
            sorting: sorting,
            pagination: pagination,
            fuzzySearch: fuzzySearch,
            includeRelationships: includeRelationships
        )
    }

    public static func == (lhs: GlobalSearchQuery, rhs: GlobalSearchQuery) -> Bool {
        return lhs.text == rhs.text &&
               lhs.filters == rhs.filters &&
               lhs.resourceTypes == rhs.resourceTypes &&
               lhs.sorting == rhs.sorting &&
               lhs.pagination == rhs.pagination &&
               lhs.fuzzySearch == rhs.fuzzySearch &&
               lhs.includeRelationships == rhs.includeRelationships &&
               lhs.crossServiceEnabled == rhs.crossServiceEnabled &&
               lhs.parallelSearchEnabled == rhs.parallelSearchEnabled &&
               lhs.searchScope == rhs.searchScope &&
               lhs.timeRange?.from == rhs.timeRange?.from &&
               lhs.timeRange?.to == rhs.timeRange?.to &&
               lhs.maxResultsPerService == rhs.maxResultsPerService &&
               lhs.includeServiceMetrics == rhs.includeServiceMetrics
    }
}

public struct UnifiedSearchResults: Codable, Sendable {
    let query: GlobalSearchQuery
    let serviceResults: [ServiceSearchResults]
    let aggregatedItems: [SearchResult]
    let totalCount: Int
    let searchTime: TimeInterval
    let serviceMetrics: [ServiceSearchMetrics]
    let suggestions: [SearchSuggestion]
    let cacheHitRate: Double

    public init(
        query: GlobalSearchQuery,
        serviceResults: [ServiceSearchResults],
        aggregatedItems: [SearchResult],
        totalCount: Int,
        searchTime: TimeInterval,
        serviceMetrics: [ServiceSearchMetrics] = [],
        suggestions: [SearchSuggestion] = [],
        cacheHitRate: Double = 0.0
    ) {
        self.query = query
        self.serviceResults = serviceResults
        self.aggregatedItems = aggregatedItems
        self.totalCount = totalCount
        self.searchTime = searchTime
        self.serviceMetrics = serviceMetrics
        self.suggestions = suggestions
        self.cacheHitRate = cacheHitRate
    }

    public var fastestService: String? {
        return serviceMetrics.min(by: { $0.searchTime < $1.searchTime })?.serviceName
    }

    public var slowestService: String? {
        return serviceMetrics.max(by: { $0.searchTime < $1.searchTime })?.serviceName
    }

    public var averageSearchTime: TimeInterval {
        guard !serviceMetrics.isEmpty else { return searchTime }
        return serviceMetrics.reduce(0) { $0 + $1.searchTime } / Double(serviceMetrics.count)
    }
}

public struct ServiceSearchResults: Codable, Sendable {
    let serviceName: String
    let items: [SearchResult]
    let totalCount: Int
    let searchTime: TimeInterval
    let error: String?
    let cacheHit: Bool

    public init(
        serviceName: String,
        items: [SearchResult],
        totalCount: Int,
        searchTime: TimeInterval,
        error: String? = nil,
        cacheHit: Bool = false
    ) {
        self.serviceName = serviceName
        self.items = items
        self.totalCount = totalCount
        self.searchTime = searchTime
        self.error = error
        self.cacheHit = cacheHit
    }

    public var isSuccessful: Bool {
        return error == nil
    }
}

public struct ServiceSearchMetrics: Codable, Sendable {
    let serviceName: String
    let searchTime: TimeInterval
    let resultCount: Int
    let cacheHit: Bool
    let error: String?
    let memoryUsage: Int
    let indexSize: Int

    public init(
        serviceName: String,
        searchTime: TimeInterval,
        resultCount: Int,
        cacheHit: Bool,
        error: String? = nil,
        memoryUsage: Int = 0,
        indexSize: Int = 0
    ) {
        self.serviceName = serviceName
        self.searchTime = searchTime
        self.resultCount = resultCount
        self.cacheHit = cacheHit
        self.error = error
        self.memoryUsage = memoryUsage
        self.indexSize = indexSize
    }
}

// MARK: - Cross-Service Resource Relationships

public struct CrossServiceRelationship: Codable, Sendable {
    let sourceResourceId: String
    let sourceResourceType: SearchResourceType
    let targetResourceId: String
    let targetResourceType: SearchResourceType
    let relationshipType: CrossServiceRelationshipType
    let strength: Double

    public init(
        sourceResourceId: String,
        sourceResourceType: SearchResourceType,
        targetResourceId: String,
        targetResourceType: SearchResourceType,
        relationshipType: CrossServiceRelationshipType,
        strength: Double = 1.0
    ) {
        self.sourceResourceId = sourceResourceId
        self.sourceResourceType = sourceResourceType
        self.targetResourceId = targetResourceId
        self.targetResourceType = targetResourceType
        self.relationshipType = relationshipType
        self.strength = strength
    }
}

public enum CrossServiceRelationshipType: String, Codable, CaseIterable, Sendable {
    case contains = "contains"
    case attachedTo = "attached_to"
    case uses = "uses"
    case dependsOn = "depends_on"
    case belongsTo = "belongs_to"
    case routes = "routes"
    case secures = "secures"

    public var displayName: String {
        switch self {
        case .contains: return "Contains"
        case .attachedTo: return "Attached To"
        case .uses: return "Uses"
        case .dependsOn: return "Depends On"
        case .belongsTo: return "Belongs To"
        case .routes: return "Routes"
        case .secures: return "Secures"
        }
    }
}