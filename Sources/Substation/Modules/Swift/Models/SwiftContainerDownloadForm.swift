import Foundation
import OSClient

/// Swift Container Download Form
struct SwiftContainerDownloadForm {
    // Form data
    var destinationPath: String = ""
    var containerName: String = ""
    var preserveDirectoryStructure: Bool = true

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Destination path field
        fields.append(.text(FormFieldText(
            id: "destinationPath",
            label: "Destination Path",
            value: destinationPath,
            placeholder: "./\(containerName)/",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == "destinationPath",
            isActive: activeFieldId == "destinationPath",
            cursorPosition: formState.getTextFieldCursorPosition("destinationPath"),
            validationError: validateDestinationPath()
        )))

        // Preserve directory structure option
        fields.append(.checkbox(FormFieldCheckbox(
            id: "preserveDirectoryStructure",
            label: "Preserve Directory Structure",
            isChecked: preserveDirectoryStructure,
            isVisible: true,
            isSelected: selectedFieldId == "preserveDirectoryStructure"
        )))

        // Info field
        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: "Downloading all objects from container '\(containerName)'",
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
        if let checkboxState = formState.checkboxStates["preserveDirectoryStructure"] {
            preserveDirectoryStructure = checkboxState.isChecked
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

        // Check if parent directory exists (for the container directory we'll create)
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

        // Warn if directory already exists
        if fileManager.fileExists(atPath: expandedPath) {
            return "Warning: Directory already exists, files may be overwritten"
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

    // Check if destination directory already exists
    func directoryExists() -> Bool {
        let finalPath = getFinalDestinationPath()
        return FileManager.default.fileExists(atPath: finalPath)
    }
}
