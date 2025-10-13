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

// Legacy wrapper for backward compatibility
struct SecretPayloadContentTypeWrapper: FormSelectableItem {
    let type: SecretPayloadContentType

    var id: String {
        return type.rawValue
    }

    var sortKey: String {
        return type.title
    }

    func matchesSearch(_ query: String) -> Bool {
        return type.title.lowercased().contains(query.lowercased())
    }
}

extension SecretPayloadContentType {
    var wrapped: SecretPayloadContentTypeWrapper {
        return SecretPayloadContentTypeWrapper(type: self)
    }

    static var wrappedAllCases: [SecretPayloadContentTypeWrapper] {
        return allCases.map { $0.wrapped }
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

// Legacy wrapper for backward compatibility
struct SecretPayloadContentEncodingWrapper: FormSelectableItem {
    let type: SecretPayloadContentEncoding

    var id: String {
        return type.rawValue
    }

    var sortKey: String {
        return type.title
    }

    func matchesSearch(_ query: String) -> Bool {
        return type.title.lowercased().contains(query.lowercased())
    }
}

extension SecretPayloadContentEncoding {
    var wrapped: SecretPayloadContentEncodingWrapper {
        return SecretPayloadContentEncodingWrapper(type: self)
    }

    static var wrappedAllCases: [SecretPayloadContentEncodingWrapper] {
        return allCases.map { $0.wrapped }
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

// Legacy wrapper for backward compatibility
struct SecretTypeWrapper: FormSelectableItem {
    let type: SecretType

    var id: String {
        return type.rawValue
    }

    var sortKey: String {
        return type.title
    }

    func matchesSearch(_ query: String) -> Bool {
        return type.title.lowercased().contains(query.lowercased())
    }
}

extension SecretType {
    var wrapped: SecretTypeWrapper {
        return SecretTypeWrapper(type: self)
    }

    static var wrappedAllCases: [SecretTypeWrapper] {
        return allCases.map { $0.wrapped }
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

// Legacy wrapper for backward compatibility
struct SecretAlgorithmWrapper: FormSelectableItem {
    let type: SecretAlgorithm

    var id: String {
        return type.rawValue
    }

    var sortKey: String {
        return type.title
    }

    func matchesSearch(_ query: String) -> Bool {
        return type.title.lowercased().contains(query.lowercased())
    }
}

extension SecretAlgorithm {
    var wrapped: SecretAlgorithmWrapper {
        return SecretAlgorithmWrapper(type: self)
    }

    static var wrappedAllCases: [SecretAlgorithmWrapper] {
        return allCases.map { $0.wrapped }
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

// Legacy wrapper for backward compatibility
struct SecretModeWrapper: FormSelectableItem {
    let type: SecretMode

    var id: String {
        return type.rawValue
    }

    var sortKey: String {
        return type.title
    }

    func matchesSearch(_ query: String) -> Bool {
        return type.title.lowercased().contains(query.lowercased())
    }
}

extension SecretMode {
    var wrapped: SecretModeWrapper {
        return SecretModeWrapper(type: self)
    }

    static var wrappedAllCases: [SecretModeWrapper] {
        return allCases.map { $0.wrapped }
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
