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

/// Represents a bit length option for cryptographic key configuration.
/// Provides a set of common bit lengths used in symmetric and asymmetric encryption.
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

// MARK: - ExpirationOption Conformance

/// Represents expiration options for Barbican secrets.
/// Allows users to choose between no expiration or setting a custom expiration date.
enum ExpirationOption: String, CaseIterable, FormSelectableItem, FormSelectorItem {
    case noExpiration = "no-expiration"
    case setCustomDate = "set-custom-date"

    /// The unique identifier for this option
    var id: String {
        return self.rawValue
    }

    /// The display title for this option
    var title: String {
        switch self {
        case .noExpiration:
            return "No Expiration"
        case .setCustomDate:
            return "Set Custom Date"
        }
    }

    /// The sort key for ordering options
    var sortKey: String {
        return self.title
    }

    /// Determines if this option matches the given search query
    /// - Parameter query: The search query string
    /// - Returns: True if the option matches the query
    func matchesSearch(_ query: String) -> Bool {
        return self.title.lowercased().contains(query.lowercased()) ||
               self.rawValue.lowercased().contains(query.lowercased())
    }
}
