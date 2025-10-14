import Foundation
import OSClient

/// Swift Directory Download Form
/// Downloads all objects within a directory from Swift object storage
struct SwiftDirectoryDownloadForm {
    // Form data
    var destinationPath: String = ""
    var containerName: String = ""
    var directoryPath: String = ""
    var preserveStructure: Bool = true

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Destination path field
        fields.append(.text(FormFieldText(
            id: "destinationPath",
            label: "Destination Path",
            value: destinationPath,
            placeholder: "./\(extractDirectoryName())/",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == "destinationPath",
            isActive: activeFieldId == "destinationPath",
            cursorPosition: formState.getTextFieldCursorPosition("destinationPath"),
            validationError: validateDestinationPath()
        )))

        // Preserve structure checkbox
        fields.append(.checkbox(FormFieldCheckbox(
            id: "preserveStructure",
            label: "Preserve Structure",
            isChecked: preserveStructure,
            isVisible: true,
            isSelected: selectedFieldId == "preserveStructure",
            helpText: "Maintain subdirectory paths (checked) or flatten all files (unchecked)"
        )))

        // Info field
        let directoryName = extractDirectoryName()
        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: "Downloading all objects in directory '\(directoryName)' from container '\(containerName)'",
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
        if let preserve = formState.getCheckboxValue("preserveStructure") {
            preserveStructure = preserve
        }
    }

    // Extract the directory name from the full path
    // For example, "photos/vacation/" returns "vacation"
    func extractDirectoryName() -> String {
        // Remove trailing slash if present
        let trimmedPath = directoryPath.hasSuffix("/") ? String(directoryPath.dropLast()) : directoryPath

        // Get last component
        if let lastSlash = trimmedPath.lastIndex(of: "/") {
            return String(trimmedPath[trimmedPath.index(after: lastSlash)...])
        }

        return trimmedPath
    }

    // Validate destination path
    func validateDestinationPath() -> String? {
        let trimmedPath = destinationPath.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if trimmedPath.isEmpty {
            return "Destination path is required"
        }

        // Expand tilde for home directory
        let expandedPath = NSString(string: trimmedPath).expandingTildeInPath

        // Destination should end with / for directories
        let directoryPath = expandedPath.hasSuffix("/") ? expandedPath : expandedPath + "/"
        let url = URL(fileURLWithPath: directoryPath)
        let parentDirectory = url.deletingLastPathComponent().path
        let fileManager = FileManager.default

        // Check if parent directory exists
        if !fileManager.fileExists(atPath: parentDirectory) {
            return "Parent directory does not exist: \(parentDirectory)"
        }

        // Check if parent directory is writable
        if !fileManager.isWritableFile(atPath: parentDirectory) {
            return "Parent directory is not writable: \(parentDirectory)"
        }

        // Warn if destination directory already exists
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: String(directoryPath.dropLast()), isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return "Warning: Directory already exists (files may be overwritten)"
            }
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

    // Get the final destination path to use for download (without trailing slash)
    func getFinalDestinationPath() -> String {
        let trimmedPath = destinationPath.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let expandedPath = NSString(string: trimmedPath).expandingTildeInPath

        // Remove trailing slash if present for consistency
        return expandedPath.hasSuffix("/") ? String(expandedPath.dropLast()) : expandedPath
    }

    // Check if destination directory already exists
    func directoryExists() -> Bool {
        let finalPath = getFinalDestinationPath()
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: finalPath, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
