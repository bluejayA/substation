import Foundation

// MARK: - Text Index

actor TextIndex {
    private var entries: [String: [SearchResult]] = [:]
    private var wordIndex: [String: Set<String>] = [:] // word -> set of entry keys
    private var fuzzyIndex: FuzzyIndex = FuzzyIndex()

    func addEntry(_ text: String, result: SearchResult) async {
        let normalizedText = text.lowercased()
        let key = "\(result.resourceType.rawValue):\(result.resourceId)"

        // Add to main index
        if entries[key] == nil {
            entries[key] = []
        }
        entries[key]?.append(result)

        // Add words to word index
        let words = extractWords(from: normalizedText)
        for word in words {
            if wordIndex[word] == nil {
                wordIndex[word] = Set<String>()
            }
            wordIndex[word]?.insert(key)
        }

        // Add to fuzzy index
        await fuzzyIndex.addEntry(normalizedText, key: key, result: result)
    }

    func search(_ query: String, fuzzy: Bool = false) async -> [SearchResult] {
        let normalizedQuery = query.lowercased()

        if fuzzy {
            return await searchFuzzy(normalizedQuery)
        } else {
            return searchExact(normalizedQuery)
        }
    }

    func getSuggestions(for partialQuery: String, limit: Int) async -> [SearchSuggestion] {
        let normalizedQuery = partialQuery.lowercased()
        var suggestions: [SearchSuggestion] = []

        // Find words that start with the query
        for word in wordIndex.keys {
            if word.hasPrefix(normalizedQuery) && word != normalizedQuery {
                let score = calculateWordScore(word, query: normalizedQuery)
                suggestions.append(SearchSuggestion(text: word, type: .text, score: score))
            }
        }

        // Sort by score and limit
        suggestions.sort { $0.score > $1.score }
        return Array(suggestions.prefix(limit))
    }

    func clear() async {
        entries.removeAll()
        wordIndex.removeAll()
        await fuzzyIndex.clear()
    }

    private func searchExact(_ query: String) -> [SearchResult] {
        var results: [SearchResult] = []
        let queryWords = extractWords(from: query)

        // Find entries that contain all query words
        var candidateKeys: Set<String>?

        for word in queryWords {
            if let wordKeys = wordIndex[word] {
                if let existing = candidateKeys {
                    candidateKeys = existing.intersection(wordKeys)
                } else {
                    candidateKeys = wordKeys
                }
            } else {
                // Word not found, no results possible
                return []
            }
        }

        guard let keys = candidateKeys else { return [] }

        for key in keys {
            if let entryResults = entries[key] {
                for var result in entryResults {
                    result.relevanceScore = calculateRelevanceScore(result: result, query: query)
                    result.matchHighlights = findMatchHighlights(in: result, query: query)
                    results.append(result)
                }
            }
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func searchFuzzy(_ query: String) async -> [SearchResult] {
        return await fuzzyIndex.search(query)
    }

    private func extractWords(from text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
                   .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                   .filter { !$0.isEmpty && $0.count >= 2 }
    }

    private func calculateRelevanceScore(result: SearchResult, query: String) -> Double {
        var score = 0.0

        // Name match has higher weight
        if let name = result.name?.lowercased(), name.contains(query.lowercased()) {
            if name == query.lowercased() {
                score += 10.0 // Exact name match
            } else if name.hasPrefix(query.lowercased()) {
                score += 8.0  // Name starts with query
            } else {
                score += 5.0  // Name contains query
            }
        }

        // ID match
        if result.resourceId.lowercased().contains(query.lowercased()) {
            score += 3.0
        }

        // Status match
        if let status = result.status?.lowercased(), status.contains(query.lowercased()) {
            score += 2.0
        }

        // Description match
        if let description = result.description?.lowercased(), description.contains(query.lowercased()) {
            score += 1.0
        }

        return score
    }

    private func findMatchHighlights(in result: SearchResult, query: String) -> [TextRange] {
        var highlights: [TextRange] = []

        // Find highlights in name
        if let name = result.name {
            highlights.append(contentsOf: findRanges(in: name, query: query))
        }

        // Find highlights in description
        if let description = result.description {
            highlights.append(contentsOf: findRanges(in: description, query: query))
        }

        return highlights
    }

    private func findRanges(in text: String, query: String) -> [TextRange] {
        var ranges: [TextRange] = []
        let lowercaseText = text.lowercased()
        let lowercaseQuery = query.lowercased()

        var searchStartIndex = lowercaseText.startIndex

        while let range = lowercaseText.range(of: lowercaseQuery, range: searchStartIndex..<lowercaseText.endIndex) {
            let startOffset = lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound)
            let length = lowercaseQuery.count

            ranges.append(TextRange(start: startOffset, length: length))

            searchStartIndex = range.upperBound
        }

        return ranges
    }

    private func calculateWordScore(_ word: String, query: String) -> Double {
        if word.hasPrefix(query) {
            return Double(query.count) / Double(word.count)
        }
        return 0.0
    }
}

// MARK: - IP Index

actor IPIndex {
    private var entries: [String: [SearchResult]] = [:]

    func addEntries(_ ipAddresses: [String], result: SearchResult) async {
        for ip in ipAddresses {
            let normalizedIP = ip.lowercased()
            if entries[normalizedIP] == nil {
                entries[normalizedIP] = []
            }
            entries[normalizedIP]?.append(result)
        }
    }

    func search(_ query: String) async -> [SearchResult] {
        let normalizedQuery = query.lowercased()
        var results: [SearchResult] = []

        // Exact IP match
        if let exactMatches = entries[normalizedQuery] {
            for var result in exactMatches {
                result.relevanceScore = 10.0 // Exact IP match gets highest score
                results.append(result)
            }
        }

        // Partial IP matches
        for (ip, ipResults) in entries {
            if ip != normalizedQuery && ip.contains(normalizedQuery) {
                for var result in ipResults {
                    result.relevanceScore = 5.0 // Partial match
                    results.append(result)
                }
            }
        }

        // CIDR range matches (if query looks like CIDR)
        if normalizedQuery.contains("/") {
            let cidrResults = searchCIDR(normalizedQuery)
            results.append(contentsOf: cidrResults)
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    func clear() async {
        entries.removeAll()
    }

    private func searchCIDR(_ cidr: String) -> [SearchResult] {
        var results: [SearchResult] = []

        let components = cidr.components(separatedBy: "/")
        guard components.count == 2,
              let prefixLength = Int(components[1]) else {
            return results
        }

        let networkIP = components[0]

        for (ip, ipResults) in entries {
            if isIPInCIDR(ip: ip, networkIP: networkIP, prefixLength: prefixLength) {
                for var result in ipResults {
                    result.relevanceScore = 7.0 // CIDR match
                    results.append(result)
                }
            }
        }

        return results
    }

    private func isIPInCIDR(ip: String, networkIP: String, prefixLength: Int) -> Bool {
        // Simplified CIDR matching for IPv4
        let ipComponents = ip.components(separatedBy: ".")
        let networkComponents = networkIP.components(separatedBy: ".")

        guard ipComponents.count == 4, networkComponents.count == 4 else {
            return false
        }

        let bytesToCheck = prefixLength / 8
        let bitsInLastByte = prefixLength % 8

        // Check full bytes
        for i in 0..<bytesToCheck {
            if ipComponents[i] != networkComponents[i] {
                return false
            }
        }

        // Check partial byte if needed
        if bitsInLastByte > 0 && bytesToCheck < 4 {
            guard let ipByte = Int(ipComponents[bytesToCheck]),
                  let networkByte = Int(networkComponents[bytesToCheck]) else {
                return false
            }

            let mask = (0xFF << (8 - bitsInLastByte)) & 0xFF
            if (ipByte & mask) != (networkByte & mask) {
                return false
            }
        }

        return true
    }
}

// MARK: - Metadata Index

actor MetadataIndex {
    private var entries: [String: [SearchResult]] = [:]
    private var keyIndex: [String: Set<String>] = [:] // metadata key -> set of result keys

    func addEntries(_ metadata: [String: String], result: SearchResult) async {
        let resultKey = "\(result.resourceType.rawValue):\(result.resourceId)"

        for (key, value) in metadata {
            let normalizedKey = key.lowercased()
            let normalizedValue = value.lowercased()
            let metadataKey = "\(normalizedKey):\(normalizedValue)"

            if entries[metadataKey] == nil {
                entries[metadataKey] = []
            }
            entries[metadataKey]?.append(result)

            // Add to key index
            if keyIndex[normalizedKey] == nil {
                keyIndex[normalizedKey] = Set<String>()
            }
            keyIndex[normalizedKey]?.insert(resultKey)
        }
    }

    func search(_ query: String) async -> [SearchResult] {
        let normalizedQuery = query.lowercased()
        var results: [SearchResult] = []

        // Search in metadata values
        for (metadataKey, metadataResults) in entries {
            if metadataKey.contains(normalizedQuery) {
                for var result in metadataResults {
                    result.relevanceScore = 3.0 // Metadata match
                    results.append(result)
                }
            }
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    func clear() async {
        entries.removeAll()
        keyIndex.removeAll()
    }
}

// MARK: - Tag Index

actor TagIndex {
    private var entries: [String: [SearchResult]] = [:]

    func addEntries(_ tags: [String], result: SearchResult) async {
        for tag in tags {
            let normalizedTag = tag.lowercased()
            if entries[normalizedTag] == nil {
                entries[normalizedTag] = []
            }
            entries[normalizedTag]?.append(result)
        }
    }

    func search(_ query: String) async -> [SearchResult] {
        let normalizedQuery = query.lowercased()
        var results: [SearchResult] = []

        for (tag, tagResults) in entries {
            if tag.contains(normalizedQuery) {
                for var result in tagResults {
                    if tag == normalizedQuery {
                        result.relevanceScore = 8.0 // Exact tag match
                    } else {
                        result.relevanceScore = 4.0 // Partial tag match
                    }
                    results.append(result)
                }
            }
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    func getSuggestions(for partialQuery: String, limit: Int) async -> [SearchSuggestion] {
        let normalizedQuery = partialQuery.lowercased()
        var suggestions: [SearchSuggestion] = []

        for tag in entries.keys {
            if tag.hasPrefix(normalizedQuery) && tag != normalizedQuery {
                let score = Double(normalizedQuery.count) / Double(tag.count)
                suggestions.append(SearchSuggestion(text: tag, type: .tag, score: score))
            }
        }

        suggestions.sort { $0.score > $1.score }
        return Array(suggestions.prefix(limit))
    }

    func clear() async {
        entries.removeAll()
    }
}

// MARK: - Fuzzy Index

actor FuzzyIndex {
    private var entries: [String: SearchResult] = [:]
    private var ngramIndex: [String: Set<String>] = [:] // n-gram -> set of entry keys

    func addEntry(_ text: String, key: String, result: SearchResult) async {
        entries[key] = result

        // Create n-grams for fuzzy matching
        let ngrams = createNGrams(from: text, size: 3)
        for ngram in ngrams {
            if ngramIndex[ngram] == nil {
                ngramIndex[ngram] = Set<String>()
            }
            ngramIndex[ngram]?.insert(key)
        }
    }

    func search(_ query: String) async -> [SearchResult] {
        let queryNGrams = createNGrams(from: query, size: 3)
        var candidateKeys: [String: Int] = [:] // key -> match count

        // Find candidates based on n-gram matches
        for ngram in queryNGrams {
            if let keys = ngramIndex[ngram] {
                for key in keys {
                    candidateKeys[key] = (candidateKeys[key] ?? 0) + 1
                }
            }
        }

        // Calculate fuzzy scores and create results
        var results: [SearchResult] = []

        for (key, matchCount) in candidateKeys {
            if let result = entries[key] {
                let similarity = Double(matchCount) / Double(max(queryNGrams.count, 1))
                if similarity >= 0.3 { // Minimum similarity threshold
                    var fuzzyResult = result
                    fuzzyResult.relevanceScore = similarity * 6.0 // Fuzzy match score
                    results.append(fuzzyResult)
                }
            }
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    func clear() async {
        entries.removeAll()
        ngramIndex.removeAll()
    }

    private func createNGrams(from text: String, size: Int) -> [String] {
        guard text.count >= size else { return [text] }

        var ngrams: [String] = []
        let characters = Array(text.lowercased())

        for i in 0...(characters.count - size) {
            let ngram = String(characters[i..<(i + size)])
            ngrams.append(ngram)
        }

        return ngrams
    }
}

// MARK: - Supporting Types

public struct TextRange: Codable, Sendable {
    public let start: Int
    public let length: Int
}

public struct SearchSuggestion: Codable, Sendable {
    public let text: String
    public let type: SuggestionType
    public let score: Double
}

public enum SuggestionType: String, Codable, CaseIterable, Sendable {
    case text = "text"
    case tag = "tag"
    case metadata = "metadata"
    case ip = "ip"
}