import Foundation

// MARK: - Saved Search Manager

actor SavedSearchManager {
    private var savedSearches: [SavedSearch] = []
    private var searchHistory: [SearchHistoryEntry] = []
    private let maxHistoryEntries = 50
    private let maxSavedSearches = 100

    private let persistenceManager = SearchPersistenceManager()

    nonisolated static let shared = SavedSearchManager()

    private init() {
        Task {
            await loadSavedData()
        }
    }

    // MARK: - Saved Searches

    func saveSearch(
        name: String,
        description: String?,
        query: SearchQuery,
        tags: [String] = []
    ) async throws -> SavedSearch {
        let existingSearch = savedSearches.first { $0.name == name }

        let search = SavedSearch(
            id: existingSearch?.id ?? UUID().uuidString,
            name: name,
            description: description,
            query: query,
            tags: tags,
            createdAt: existingSearch?.createdAt ?? Date(),
            updatedAt: Date(),
            lastUsed: existingSearch?.lastUsed,
            useCount: existingSearch?.useCount ?? 0
        )

        if let existingIndex = savedSearches.firstIndex(where: { $0.id == search.id }) {
            savedSearches[existingIndex] = search
        } else {
            savedSearches.append(search)
        }

        // Maintain limit
        if savedSearches.count > maxSavedSearches {
            // Remove least recently used searches
            savedSearches.sort { ($0.lastUsed ?? $0.createdAt) < ($1.lastUsed ?? $1.createdAt) }
            savedSearches.removeFirst(savedSearches.count - maxSavedSearches)
        }

        try await persistenceManager.saveSavedSearches(savedSearches)

        Logger.shared.logInfo("SavedSearchManager - Saved search '\(name)'")
        return search
    }

    func getSavedSearches(sortBy: SavedSearchSortOption = .lastUsed) async -> [SavedSearch] {
        switch sortBy {
        case .name:
            return savedSearches.sorted { $0.name < $1.name }
        case .createdAt:
            return savedSearches.sorted { $0.createdAt > $1.createdAt }
        case .lastUsed:
            return savedSearches.sorted {
                ($0.lastUsed ?? $0.createdAt) > ($1.lastUsed ?? $1.createdAt)
            }
        case .useCount:
            return savedSearches.sorted { $0.useCount > $1.useCount }
        }
    }

    func getSavedSearch(id: String) async -> SavedSearch? {
        return savedSearches.first { $0.id == id }
    }

    func getSavedSearch(name: String) async -> SavedSearch? {
        return savedSearches.first { $0.name == name }
    }

    func updateLastUsed(searchId: String) async throws {
        guard let index = savedSearches.firstIndex(where: { $0.id == searchId }) else {
            throw SavedSearchError.searchNotFound(searchId)
        }

        savedSearches[index].lastUsed = Date()
        savedSearches[index].useCount += 1

        try await persistenceManager.saveSavedSearches(savedSearches)
    }

    func deleteSearch(id: String) async throws {
        guard let index = savedSearches.firstIndex(where: { $0.id == id }) else {
            throw SavedSearchError.searchNotFound(id)
        }

        let searchName = savedSearches[index].name
        savedSearches.remove(at: index)

        try await persistenceManager.saveSavedSearches(savedSearches)

        Logger.shared.logInfo("SavedSearchManager - Deleted saved search '\(searchName)'")
    }

    func getSavedSearchesByTag(_ tag: String) async -> [SavedSearch] {
        return savedSearches.filter { $0.tags.contains(tag) }
    }

    func getAllTags() async -> [String] {
        var allTags = Set<String>()
        for search in savedSearches {
            allTags.formUnion(search.tags)
        }
        return Array(allTags).sorted()
    }

    // MARK: - Search History

    func addToHistory(query: SearchQuery, resultCount: Int) async {
        let entry = SearchHistoryEntry(
            query: query,
            timestamp: Date(),
            resultCount: resultCount
        )

        // Remove duplicate if exists
        searchHistory.removeAll { $0.query.text == query.text }

        searchHistory.insert(entry, at: 0)

        // Maintain limit
        if searchHistory.count > maxHistoryEntries {
            searchHistory = Array(searchHistory.prefix(maxHistoryEntries))
        }

        try? await persistenceManager.saveSearchHistory(searchHistory)
    }

    func getSearchHistory(limit: Int? = nil) async -> [SearchHistoryEntry] {
        if let limit = limit {
            return Array(searchHistory.prefix(limit))
        }
        return searchHistory
    }

    func clearHistory() async throws {
        searchHistory.removeAll()
        try await persistenceManager.saveSearchHistory(searchHistory)
        Logger.shared.logInfo("SavedSearchManager - Cleared search history")
    }

    func getRecentQueries(limit: Int = 10) async -> [String] {
        return Array(searchHistory.prefix(limit).map { $0.query.text })
    }

    // MARK: - Quick Access & Suggestions

    func getQuickAccessSearches(limit: Int = 5) async -> [SavedSearch] {
        return Array(savedSearches
            .sorted { $0.useCount > $1.useCount }
            .prefix(limit))
    }

    func getSuggestionsFor(partialName: String, limit: Int = 5) async -> [SavedSearch] {
        let lowercaseQuery = partialName.lowercased()

        return savedSearches
            .filter { search in
                search.name.lowercased().contains(lowercaseQuery) ||
                search.description?.lowercased().contains(lowercaseQuery) == true ||
                search.tags.contains { $0.lowercased().contains(lowercaseQuery) }
            }
            .sorted { search1, search2 in
                // Prioritize exact name matches
                let name1Match = search1.name.lowercased().hasPrefix(lowercaseQuery)
                let name2Match = search2.name.lowercased().hasPrefix(lowercaseQuery)

                if name1Match && !name2Match { return true }
                if !name1Match && name2Match { return false }

                // Then by use count
                return search1.useCount > search2.useCount
            }
            .prefix(limit)
            .compactMap { $0 }
    }

    func getAutoCompleteSuggestions(for partialQuery: String, limit: Int = 10) async -> [String] {
        let lowercaseQuery = partialQuery.lowercased()
        var suggestions = Set<String>()

        // From search history
        for entry in searchHistory {
            if entry.query.text.lowercased().hasPrefix(lowercaseQuery) &&
               entry.query.text.lowercased() != lowercaseQuery {
                suggestions.insert(entry.query.text)
            }
        }

        // From saved searches
        for search in savedSearches {
            if search.query.text.lowercased().hasPrefix(lowercaseQuery) &&
               search.query.text.lowercased() != lowercaseQuery {
                suggestions.insert(search.query.text)
            }
        }

        return Array(suggestions)
            .sorted { $0.count < $1.count } // Shorter suggestions first
            .prefix(limit)
            .compactMap { $0 }
    }

    // MARK: - Export & Import

    func exportSearches() async throws -> Data {
        let exportData = SavedSearchExport(
            savedSearches: savedSearches,
            exportedAt: Date(),
            version: "1.0"
        )

        return try JSONEncoder().encode(exportData)
    }

    func importSearches(from data: Data, mergeMode: ImportMergeMode = .replace) async throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importData = try decoder.decode(SavedSearchExport.self, from: data)

        var imported = 0
        var skipped = 0
        let errors: [String] = []

        switch mergeMode {
        case .replace:
            savedSearches = importData.savedSearches
            imported = importData.savedSearches.count

        case .merge:
            for importedSearch in importData.savedSearches {
                if savedSearches.contains(where: { $0.name == importedSearch.name }) {
                    skipped += 1
                } else {
                    savedSearches.append(importedSearch)
                    imported += 1
                }
            }

        case .update:
            for importedSearch in importData.savedSearches {
                if let existingIndex = savedSearches.firstIndex(where: { $0.name == importedSearch.name }) {
                    savedSearches[existingIndex] = importedSearch
                    imported += 1
                } else {
                    savedSearches.append(importedSearch)
                    imported += 1
                }
            }
        }

        try await persistenceManager.saveSavedSearches(savedSearches)

        Logger.shared.logInfo("SavedSearchManager - Imported \(imported) searches, skipped \(skipped)")

        return ImportResult(
            imported: imported,
            skipped: skipped,
            errors: errors
        )
    }

    // MARK: - Statistics

    func getStatistics() async -> SavedSearchStatistics {
        let totalSearches = savedSearches.count
        let totalHistoryEntries = searchHistory.count

        let totalUseCount = savedSearches.reduce(0) { $0 + $1.useCount }
        let averageUseCount = totalSearches > 0 ? Double(totalUseCount) / Double(totalSearches) : 0

        let mostUsedSearch = savedSearches.max { $0.useCount < $1.useCount }
        let oldestSearch = savedSearches.min { $0.createdAt < $1.createdAt }
        let newestSearch = savedSearches.max { $0.createdAt < $1.createdAt }

        return SavedSearchStatistics(
            totalSavedSearches: totalSearches,
            totalHistoryEntries: totalHistoryEntries,
            totalUseCount: totalUseCount,
            averageUseCount: averageUseCount,
            mostUsedSearchName: mostUsedSearch?.name,
            oldestSearchDate: oldestSearch?.createdAt,
            newestSearchDate: newestSearch?.createdAt,
            uniqueTags: await getAllTags().count
        )
    }

    // MARK: - Private Methods

    private func loadSavedData() async {
        do {
            savedSearches = try await persistenceManager.loadSavedSearches()
            searchHistory = try await persistenceManager.loadSearchHistory()
            Logger.shared.logInfo("SavedSearchManager - Loaded \(savedSearches.count) saved searches and \(searchHistory.count) history entries")
        } catch {
            Logger.shared.logError("SavedSearchManager - Failed to load saved data: \(error)")
        }
    }
}

// MARK: - Search Persistence Manager

private actor SearchPersistenceManager {
    private let savedSearchesFilename = "saved_searches.json"
    private let searchHistoryFilename = "search_history.json"

    private var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var savedSearchesURL: URL {
        return documentsDirectory.appendingPathComponent(savedSearchesFilename)
    }

    private var searchHistoryURL: URL {
        return documentsDirectory.appendingPathComponent(searchHistoryFilename)
    }

    func saveSavedSearches(_ searches: [SavedSearch]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(searches)
        try data.write(to: savedSearchesURL)
    }

    func loadSavedSearches() async throws -> [SavedSearch] {
        guard FileManager.default.fileExists(atPath: savedSearchesURL.path) else {
            return []
        }

        let data = try Data(contentsOf: savedSearchesURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([SavedSearch].self, from: data)
    }

    func saveSearchHistory(_ history: [SearchHistoryEntry]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(history)
        try data.write(to: searchHistoryURL)
    }

    func loadSearchHistory() async throws -> [SearchHistoryEntry] {
        guard FileManager.default.fileExists(atPath: searchHistoryURL.path) else {
            return []
        }

        let data = try Data(contentsOf: searchHistoryURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([SearchHistoryEntry].self, from: data)
    }
}

// MARK: - Supporting Types

struct SavedSearch: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let query: SearchQuery
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    var lastUsed: Date?
    var useCount: Int

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        query: SearchQuery,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsed: Date? = nil,
        useCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.query = query
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsed = lastUsed
        self.useCount = useCount
    }
}

struct SearchHistoryEntry: Codable, Sendable, Identifiable {
    var id: UUID { UUID() }
    let query: SearchQuery
    let timestamp: Date
    let resultCount: Int
}

struct SavedSearchExport: Codable, Sendable {
    let savedSearches: [SavedSearch]
    let exportedAt: Date
    let version: String
}

struct ImportResult: Sendable {
    let imported: Int
    let skipped: Int
    let errors: [String]
}

struct SavedSearchStatistics: Sendable {
    let totalSavedSearches: Int
    let totalHistoryEntries: Int
    let totalUseCount: Int
    let averageUseCount: Double
    let mostUsedSearchName: String?
    let oldestSearchDate: Date?
    let newestSearchDate: Date?
    let uniqueTags: Int
}

enum SavedSearchSortOption: String, CaseIterable, Sendable {
    case name = "name"
    case createdAt = "created_at"
    case lastUsed = "last_used"
    case useCount = "use_count"

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .createdAt: return "Date Created"
        case .lastUsed: return "Last Used"
        case .useCount: return "Most Used"
        }
    }
}

enum ImportMergeMode: String, CaseIterable, Sendable {
    case replace = "replace"
    case merge = "merge"
    case update = "update"

    var displayName: String {
        switch self {
        case .replace: return "Replace All"
        case .merge: return "Merge (Skip Duplicates)"
        case .update: return "Update Existing"
        }
    }

    var description: String {
        switch self {
        case .replace: return "Replace all saved searches with imported ones"
        case .merge: return "Add new searches, skip existing ones with same name"
        case .update: return "Update existing searches, add new ones"
        }
    }
}

enum SavedSearchError: Error, LocalizedError {
    case searchNotFound(String)
    case invalidSearchData
    case persistenceError(any Error)

    var errorDescription: String? {
        switch self {
        case .searchNotFound(let id):
            return "Saved search with ID '\(id)' not found"
        case .invalidSearchData:
            return "Invalid search data"
        case .persistenceError(let error):
            return "Failed to persist search data: \(error.localizedDescription)"
        }
    }
}