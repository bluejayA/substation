import Foundation

public actor SearchActor {
    private var searchIndexManager: SearchIndexManager
    private let queryEngine: QueryEngine

    public init() {
        self.searchIndexManager = SearchIndexManager()
        self.queryEngine = QueryEngine()
    }

    public func executeSearch(_ query: SearchQuery) throws -> SearchResult {
        let startTime = Date()

        let results = try queryEngine.executeQuery(query, index: searchIndexManager)

        let searchTime = Date().timeIntervalSince(startTime)

        return SearchResult(
            items: results.items,
            totalCount: results.totalCount,
            hasMore: results.hasMore,
            searchTime: searchTime,
            facets: results.facets
        )
    }

    public func indexResource(_ resource: ResourceReference) {
        searchIndexManager.indexResource(resource)
    }

    public func removeResource(id: String) {
        searchIndexManager.removeResource(id: id)
    }

    public func updateResource(_ resource: ResourceReference) {
        searchIndexManager.updateResource(resource)
    }

    public func rebuildIndex(resources: [ResourceReference]) {
        searchIndexManager.rebuildIndex(resources: resources)
    }
}