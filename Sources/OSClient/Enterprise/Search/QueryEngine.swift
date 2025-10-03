import Foundation

public struct QueryEngine {

    public init() {}

    public func executeQuery(_ query: SearchQuery, index: SearchIndexManager) throws -> QueryResult {
        let tokens = tokenizeQuery(query.query)
        let matchedIds = index.search(tokens: tokens)

        var resources: [ResourceReference] = []
        for id in matchedIds {
            if let resource = index.getDocument(id: id) {
                resources.append(resource)
            }
        }

        resources = applyFilters(resources, filters: query.filters)

        if let sortBy = query.sortBy {
            resources = applySorting(resources, sortBy: sortBy)
        }

        let totalCount = resources.count
        let offset = max(0, query.offset)
        let limit = max(1, query.limit)

        let paginatedResources = Array(resources.dropFirst(offset).prefix(limit))
        let hasMore = offset + limit < totalCount

        let facets = generateFacets(resources)

        return QueryResult(
            items: paginatedResources,
            totalCount: totalCount,
            hasMore: hasMore,
            facets: facets
        )
    }

    private func tokenizeQuery(_ query: String) -> [String] {
        return query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    private func applyFilters(_ resources: [ResourceReference], filters: [SearchFilter]) -> [ResourceReference] {
        return resources.filter { resource in
            filters.allSatisfy { filter in
                applyFilter(filter, to: resource)
            }
        }
    }

    private func applyFilter(_ filter: SearchFilter, to resource: ResourceReference) -> Bool {
        let fieldValue: String

        switch filter.field.lowercased() {
        case "name":
            fieldValue = resource.name?.lowercased() ?? ""
        case "type":
            fieldValue = resource.type.lowercased()
        case "id":
            fieldValue = resource.id.lowercased()
        default:
            fieldValue = resource.properties[filter.field]?.lowercased() ?? ""
        }

        let filterValue = filter.value.lowercased()

        switch filter.`operator` {
        case .equals:
            return fieldValue == filterValue
        case .notEquals:
            return fieldValue != filterValue
        case .contains:
            return fieldValue.contains(filterValue)
        case .startsWith:
            return fieldValue.hasPrefix(filterValue)
        case .endsWith:
            return fieldValue.hasSuffix(filterValue)
        case .greaterThan:
            if let fieldNum = Double(fieldValue), let filterNum = Double(filterValue) {
                return fieldNum > filterNum
            }
            return false
        case .lessThan:
            if let fieldNum = Double(fieldValue), let filterNum = Double(filterValue) {
                return fieldNum < filterNum
            }
            return false
        case .greaterThanOrEqual:
            if let fieldNum = Double(fieldValue), let filterNum = Double(filterValue) {
                return fieldNum >= filterNum
            }
            return false
        case .lessThanOrEqual:
            if let fieldNum = Double(fieldValue), let filterNum = Double(filterValue) {
                return fieldNum <= filterNum
            }
            return false
        }
    }

    private func applySorting(_ resources: [ResourceReference], sortBy: SortCriteria) -> [ResourceReference] {
        return resources.sorted { resource1, resource2 in
            let value1 = getSortValue(from: resource1, field: sortBy.field)
            let value2 = getSortValue(from: resource2, field: sortBy.field)

            switch sortBy.direction {
            case .ascending:
                return value1 < value2
            case .descending:
                return value1 > value2
            }
        }
    }

    private func getSortValue(from resource: ResourceReference, field: String) -> String {
        switch field.lowercased() {
        case "name":
            return resource.name?.lowercased() ?? ""
        case "type":
            return resource.type.lowercased()
        case "id":
            return resource.id.lowercased()
        default:
            return resource.properties[field]?.lowercased() ?? ""
        }
    }

    private func generateFacets(_ resources: [ResourceReference]) -> [SearchFacet] {
        var typeCounts: [String: Int] = [:]

        for resource in resources {
            let type = resource.type
            typeCounts[type, default: 0] += 1
        }

        let typeValues = typeCounts.map { key, value in
            FacetValue(value: key, count: value)
        }.sorted { $0.count > $1.count }

        return [
            SearchFacet(field: "type", values: typeValues)
        ]
    }
}

public struct QueryResult {
    public let items: [ResourceReference]
    public let totalCount: Int
    public let hasMore: Bool
    public let facets: [SearchFacet]

    public init(items: [ResourceReference], totalCount: Int, hasMore: Bool, facets: [SearchFacet]) {
        self.items = items
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.facets = facets
    }
}