import Foundation

// Wrapper for SecretPayloadContentType
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

// Wrapper for SecretPayloadContentEncoding
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

// Wrapper for SecretType
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

// Wrapper for SecretAlgorithm
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

// Wrapper for SecretMode
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

// Wrapper for Bit Length (not an enum, but we'll create options)
struct BitLengthOption: FormSelectableItem {
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
        BitLengthOption(value: 4096)
    ]
}
