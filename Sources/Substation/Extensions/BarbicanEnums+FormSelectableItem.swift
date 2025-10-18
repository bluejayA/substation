import Foundation

// MARK: - SecretPayloadContentType Conformance

extension SecretPayloadContentType: FormSelectableItem, FormSelectorItem {
    public var id: String {
        return self.rawValue
    }

    public var sortKey: String {
        return self.title
    }

    public func matchesSearch(_ query: String) -> Bool {
        return self.title.lowercased().contains(query.lowercased()) ||
               self.rawValue.lowercased().contains(query.lowercased())
    }
}

// MARK: - SecretPayloadContentEncoding Conformance

extension SecretPayloadContentEncoding: FormSelectableItem, FormSelectorItem {
    public var id: String {
        return self.rawValue
    }

    public var sortKey: String {
        return self.title
    }

    public func matchesSearch(_ query: String) -> Bool {
        return self.title.lowercased().contains(query.lowercased()) ||
               self.rawValue.lowercased().contains(query.lowercased())
    }
}

// MARK: - SecretType Conformance

extension SecretType: FormSelectableItem, FormSelectorItem {
    public var id: String {
        return self.rawValue
    }

    public var sortKey: String {
        return self.title
    }

    public func matchesSearch(_ query: String) -> Bool {
        return self.title.lowercased().contains(query.lowercased()) ||
               self.rawValue.lowercased().contains(query.lowercased())
    }
}

// MARK: - SecretAlgorithm Conformance

extension SecretAlgorithm: FormSelectableItem, FormSelectorItem {
    public var id: String {
        return self.rawValue
    }

    public var sortKey: String {
        return self.title
    }

    public func matchesSearch(_ query: String) -> Bool {
        return self.title.lowercased().contains(query.lowercased()) ||
               self.rawValue.lowercased().contains(query.lowercased())
    }
}

// MARK: - SecretMode Conformance

extension SecretMode: FormSelectableItem, FormSelectorItem {
    public var id: String {
        return self.rawValue
    }

    public var sortKey: String {
        return self.title
    }

    public func matchesSearch(_ query: String) -> Bool {
        return self.title.lowercased().contains(query.lowercased()) ||
               self.rawValue.lowercased().contains(query.lowercased())
    }
}

// MARK: - BitLengthOption Conformance

struct BitLengthOption: FormSelectableItem, FormSelectorItem {
    let value: Int

    var id: String {
        return "\(value)"
    }

    var sortKey: String {
        return String(format: "%04d", value)
    }

    func matchesSearch(_ query: String) -> Bool {
        return "\(value)".contains(query)
    }

    static let commonBitLengths: [BitLengthOption] = [
        BitLengthOption(value: 128),
        BitLengthOption(value: 192),
        BitLengthOption(value: 256),
        BitLengthOption(value: 512),
        BitLengthOption(value: 1024),
        BitLengthOption(value: 2048),
        BitLengthOption(value: 3072),
        BitLengthOption(value: 4096)
    ]
}
