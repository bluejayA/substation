import Foundation
import OSClient

/// Swift Object Download Form
struct SwiftObjectDownloadForm {
    // Form data
    var destinationPath: String = ""
    var containerName: String = ""
    var objectName: String = ""

    // Extract just the filename from a full object path
    // For example, "photos/vacation/beach.jpg" returns "beach.jpg"
    func extractFileName() -> String {
        if let lastSlash = objectName.lastIndex(of: "/") {
            return String(objectName[objectName.index(after: lastSlash)...])
        }
        return objectName
    }

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        let fileName = extractFileName()

        // Destination path field
        fields.append(.text(FormFieldText(
            id: "destinationPath",
            label: "Destination Path",
            value: destinationPath,
            placeholder: "./\(fileName)",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == "destinationPath",
            isActive: activeFieldId == "destinationPath",
            cursorPosition: formState.getTextFieldCursorPosition("destinationPath"),
            validationError: validateDestinationPath()
        )))

        // Info field
        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: "Downloading object '\(objectName)' from container '\(containerName)'",
            isVisible: true,
            style: .info
        )))

        return fields
    }

    // Update form from state
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let path = formState.getTextValue("destinationPath") {
            destinationPath = path
        }
    }

    // Validate destination path
    func validateDestinationPath() -> String? {
        let trimmedPath = destinationPath.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if trimmedPath.isEmpty {
            return "Destination path is required"
        }

        // Expand tilde for home directory
        let expandedPath = NSString(string: trimmedPath).expandingTildeInPath

        // Check if parent directory exists
        let url = URL(fileURLWithPath: expandedPath)
        let parentDirectory = url.deletingLastPathComponent().path
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: parentDirectory) {
            return "Parent directory does not exist: \(parentDirectory)"
        }

        // Check if parent directory is writable
        if !fileManager.isWritableFile(atPath: parentDirectory) {
            return "Parent directory is not writable: \(parentDirectory)"
        }

        // Warn if file already exists
        if fileManager.fileExists(atPath: expandedPath) {
            return "Warning: File already exists and will be overwritten"
        }

        return nil
    }

    // Validate the entire form
    func validateForm() -> [String] {
        var errors: [String] = []

        if let pathError = validateDestinationPath() {
            // Don't treat "already exists" warning as an error
            if !pathError.hasPrefix("Warning:") {
                errors.append(pathError)
            }
        }

        return errors
    }

    // Check if form is valid
    func isValid() -> Bool {
        return validateForm().isEmpty
    }

    // Get the final destination path to use for download
    func getFinalDestinationPath() -> String {
        let trimmedPath = destinationPath.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return NSString(string: trimmedPath).expandingTildeInPath
    }

    // Check if destination file already exists
    func fileExists() -> Bool {
        let finalPath = getFinalDestinationPath()
        return FileManager.default.fileExists(atPath: finalPath)
    }
}
