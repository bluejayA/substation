import Foundation

public struct SearchIndexManager {
    private var index: [String: Set<String>] = [:]
    private var documents: [String: ResourceReference] = [:]

    public init() {}

    public mutating func indexResource(_ resource: ResourceReference) {
        documents[resource.id] = resource

        let tokens = tokenize(resource)
        for token in tokens {
            if index[token] == nil {
                index[token] = Set<String>()
            }
            index[token]?.insert(resource.id)
        }
    }

    public mutating func removeResource(id: String) {
        guard let resource = documents[id] else { return }

        let tokens = tokenize(resource)
        for token in tokens {
            index[token]?.remove(id)
            if index[token]?.isEmpty == true {
                index.removeValue(forKey: token)
            }
        }

        documents.removeValue(forKey: id)
    }

    public mutating func updateResource(_ resource: ResourceReference) {
        removeResource(id: resource.id)
        indexResource(resource)
    }

    public mutating func rebuildIndex(resources: [ResourceReference]) {
        index.removeAll()
        documents.removeAll()

        for resource in resources {
            indexResource(resource)
        }
    }

    public func search(tokens: [String]) -> Set<String> {
        guard !tokens.isEmpty else { return Set(documents.keys) }

        var result = index[tokens[0]] ?? Set<String>()

        for token in tokens.dropFirst() {
            let tokenResults = index[token] ?? Set<String>()
            result = result.intersection(tokenResults)
        }

        return result
    }

    public func getDocument(id: String) -> ResourceReference? {
        return documents[id]
    }

    private func tokenize(_ resource: ResourceReference) -> [String] {
        var tokens: [String] = []

        if let name = resource.name {
            tokens.append(contentsOf: name.lowercased().components(separatedBy: .whitespacesAndNewlines))
        }

        tokens.append(resource.type.lowercased())
        tokens.append(resource.id.lowercased())

        for (key, value) in resource.properties {
            tokens.append(key.lowercased())
            tokens.append(value.lowercased())
        }

        return tokens.filter { !$0.isEmpty }
    }
}