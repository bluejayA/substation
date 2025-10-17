import Foundation
import SwiftNCurses

// MARK: - Form Field Configuration

/// Configuration for a form field's display properties
struct FormFieldConfiguration {
    let title: String
    let isRequired: Bool
    let isSelected: Bool
    let isActive: Bool
    let hasError: Bool
    let errorMessage: String?
    let placeholder: String?
    let value: String?
    let maxWidth: Int?
    let fieldType: FormFieldType
    let selectionMode: Bool
    let selectionInfo: SelectionInfo?

    init(title: String,
         isRequired: Bool = false,
         isSelected: Bool = false,
         isActive: Bool = false,
         hasError: Bool = false,
         errorMessage: String? = nil,
         placeholder: String? = nil,
         value: String? = nil,
         maxWidth: Int? = nil,
         fieldType: FormFieldType = .text,
         selectionMode: Bool = false,
         selectionInfo: SelectionInfo? = nil) {
        self.title = title
        self.isRequired = isRequired
        self.isSelected = isSelected
        self.isActive = isActive
        self.hasError = hasError
        self.errorMessage = errorMessage
        self.placeholder = placeholder
        self.value = value
        self.maxWidth = maxWidth
        self.fieldType = fieldType
        self.selectionMode = selectionMode
        self.selectionInfo = selectionInfo
    }
}

/// Types of form fields
enum FormFieldType {
    case text
    case selection
    case enumeration
    case multiSelection
    case textArea
}

/// Selection information for dropdown/selection fields
struct SelectionInfo {
    let selectedIndex: Int
    let totalItems: Int
    let selectedItemName: String?
    let hasMultipleOptions: Bool

    init(selectedIndex: Int, totalItems: Int, selectedItemName: String? = nil) {
        self.selectedIndex = selectedIndex
        self.totalItems = totalItems
        self.selectedItemName = selectedItemName
        self.hasMultipleOptions = totalItems > 1
    }
}

/// Form validation state
struct FormValidationState {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]

    init(isValid: Bool = true, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

// MARK: - FormViewModel Protocol

protocol FormViewModel {

    /// Get configuration for all form fields
    func getFieldConfigurations() -> [FormFieldConfiguration]

    /// Get current validation state
    func getValidationState() -> FormValidationState

    /// Get form title
    func getFormTitle() -> String

    /// Get navigation help text
    func getNavigationHelp() -> String

    /// Check if form is in a special mode (like selection mode)
    func isInSpecialMode() -> Bool
}
