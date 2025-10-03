import Foundation
import OSClient

/// Validation result type
enum FieldValidationResult {
    case valid
    case invalid(String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .invalid(let message) = self { return message }
        return nil
    }
}

/// Simplified validation service for operations
///
/// This service eliminates redundant guard statements by providing
/// reusable validation rules that can be composed and chained.
@MainActor
final class ValidationService {

    // MARK: - Resource Selection Validation

    /// Validate that a resource is selected
    func validateSelection<T>(_ resource: T?, resourceType: String) -> FieldValidationResult {
        guard let _ = resource else {
            return .invalid("No \(resourceType) selected")
        }
        return .valid
    }

    /// Validate server selection
    func validateServerSelection(_ server: Server?) -> FieldValidationResult {
        return validateSelection(server, resourceType: "server")
    }

    /// Validate network selection
    func validateNetworkSelection(_ network: Network?) -> FieldValidationResult {
        return validateSelection(network, resourceType: "network")
    }

    // MARK: - View State Validation

    /// Validate that we're in the expected view
    func validateView(_ currentView: ViewMode, expected: ViewMode) -> FieldValidationResult {
        guard currentView == expected else {
            return .invalid("Invalid view state")
        }
        return .valid
    }

    /// Validate that we're in one of the expected views
    func validateViews(_ currentView: ViewMode, expectedViews: [ViewMode]) -> FieldValidationResult {
        guard expectedViews.contains(currentView) else {
            return .invalid("Invalid view state")
        }
        return .valid
    }

    // MARK: - String Validation

    /// Validate that a string is not empty
    func validateNotEmpty(_ value: String?, fieldName: String) -> FieldValidationResult {
        guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("\(fieldName) cannot be empty")
        }
        return .valid
    }

    /// Validate string length
    func validateLength(_ value: String?, min: Int? = nil, max: Int? = nil, fieldName: String) -> FieldValidationResult {
        guard let value = value else {
            return .invalid("\(fieldName) is required")
        }

        if let min = min, value.count < min {
            return .invalid("\(fieldName) must be at least \(min) characters")
        }

        if let max = max, value.count > max {
            return .invalid("\(fieldName) must not exceed \(max) characters")
        }

        return .valid
    }

    // MARK: - Collection Validation

    /// Validate that a collection is not empty
    func validateNotEmpty<T>(_ collection: [T], collectionName: String) -> FieldValidationResult {
        guard !collection.isEmpty else {
            return .invalid("No \(collectionName) available")
        }
        return .valid
    }

    /// Validate that at least one item is selected
    func validateSelection<T>(_ selected: Set<T>, itemType: String) -> FieldValidationResult {
        guard !selected.isEmpty else {
            return .invalid("No \(itemType) selected")
        }
        return .valid
    }

    // MARK: - Numeric Validation

    /// Validate that a number is within range
    func validateRange(_ value: Int, min: Int, max: Int, fieldName: String) -> FieldValidationResult {
        guard value >= min && value <= max else {
            return .invalid("\(fieldName) must be between \(min) and \(max)")
        }
        return .valid
    }

    // MARK: - Composite Validation

    /// Validate multiple conditions, returning the first failure or success
    func validateAll(_ validations: FieldValidationResult...) -> FieldValidationResult {
        for validation in validations {
            if case .invalid = validation {
                return validation
            }
        }
        return .valid
    }

    /// Perform validation and execute action only if valid
    func validateAndExecute(
        _ validation: FieldValidationResult,
        onInvalid: (String) -> Void,
        action: () async -> Void
    ) async {
        switch validation {
        case .valid:
            await action()
        case .invalid(let message):
            onInvalid(message)
        }
    }

    /// Perform validation and return result
    func validateAndReturn<T: Sendable>(
        _ validation: FieldValidationResult,
        onValid: @Sendable () async throws -> T,
        onInvalid: @Sendable (String) -> T
    ) async rethrows -> T {
        switch validation {
        case .valid:
            return try await onValid()
        case .invalid(let message):
            return onInvalid(message)
        }
    }
}
