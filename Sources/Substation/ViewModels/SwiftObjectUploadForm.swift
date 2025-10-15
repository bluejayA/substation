import Foundation
import OSClient

/// Swift Object Upload Form
struct SwiftObjectUploadForm {
    // Form data
    var filePath: String = ""
    var objectName: String = ""
    var contentType: String = ""
    var containerName: String = ""
    var prefix: String = ""
    var recursive: Bool = true
    var backgroundUpload: Bool = true  // Default to background uploads

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Detect if path is a directory
        let isDir = isDirectory()
        let pathType = isDir ? "Directory" : (filePath.isEmpty ? "File or Directory" : "File")

        // File/Directory path field
        fields.append(.text(FormFieldText(
            id: "filePath",
            label: "File/Directory Path",
            value: filePath,
            placeholder: "/path/to/file.txt or /path/to/directory",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == "filePath",
            isActive: activeFieldId == "filePath",
            cursorPosition: formState.getTextFieldCursorPosition("filePath"),
            validationError: validateFilePath()
        )))

        // Info field showing detected type
        if !filePath.isEmpty {
            fields.append(.info(FormFieldInfo(
                id: "pathType",
                label: "Detected Type",
                value: pathType,
                isVisible: true,
                style: .info
            )))
        }

        // Prefix field (only relevant for directories)
        fields.append(.text(FormFieldText(
            id: "prefix",
            label: "Prefix (for directories)",
            value: prefix,
            placeholder: "Optional prefix for object names",
            isRequired: false,
            isVisible: isDir || filePath.isEmpty,
            isSelected: selectedFieldId == "prefix",
            isActive: activeFieldId == "prefix",
            cursorPosition: formState.getTextFieldCursorPosition("prefix"),
            validationError: nil
        )))

        // Object name field (only for single files)
        fields.append(.text(FormFieldText(
            id: "objectName",
            label: "Object Name (for single files)",
            value: objectName,
            placeholder: "Leave empty to use filename",
            isRequired: false,
            isVisible: !isDir || filePath.isEmpty,
            isSelected: selectedFieldId == "objectName",
            isActive: activeFieldId == "objectName",
            cursorPosition: formState.getTextFieldCursorPosition("objectName"),
            validationError: validateObjectName()
        )))

        // Content type field (only for single files)
        fields.append(.text(FormFieldText(
            id: "contentType",
            label: "Content-Type (for single files)",
            value: contentType,
            placeholder: "Leave empty for auto-detection",
            isRequired: false,
            isVisible: !isDir || filePath.isEmpty,
            isSelected: selectedFieldId == "contentType",
            isActive: activeFieldId == "contentType",
            cursorPosition: formState.getTextFieldCursorPosition("contentType"),
            validationError: nil
        )))

        // Recursive checkbox (only for directories)
        fields.append(.checkbox(FormFieldCheckbox(
            id: "recursive",
            label: "Recursive (for directories)",
            isChecked: recursive,
            isVisible: isDir || filePath.isEmpty,
            isSelected: selectedFieldId == "recursive"
        )))

        // Background upload checkbox
        fields.append(.checkbox(FormFieldCheckbox(
            id: "backgroundUpload",
            label: "Background Upload",
            isChecked: backgroundUpload,
            isVisible: true,
            isSelected: selectedFieldId == "backgroundUpload"
        )))

        // Info field
        let infoMessage: String
        if isDir {
            if backgroundUpload {
                infoMessage = "Directory will be uploaded in background to container: \(containerName)"
            } else {
                infoMessage = "Directory will be uploaded to container: \(containerName)"
            }
        } else {
            if backgroundUpload {
                infoMessage = "File will be uploaded in background to container: \(containerName)"
            } else {
                infoMessage = "File will be uploaded to container: \(containerName)"
            }
        }
        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: infoMessage,
            isVisible: true,
            style: .info
        )))

        return fields
    }

    // Update form from state
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let path = formState.getTextValue("filePath") {
            filePath = path
        }
        if let name = formState.getTextValue("objectName") {
            objectName = name
        }
        if let type = formState.getTextValue("contentType") {
            contentType = type
        }
        if let pre = formState.getTextValue("prefix") {
            prefix = pre
        }
        if let rec = formState.getCheckboxValue("recursive") {
            recursive = rec
        }
        if let bg = formState.getCheckboxValue("backgroundUpload") {
            backgroundUpload = bg
        }
    }

    // Check if path is a directory
    func isDirectory() -> Bool {
        let trimmedPath = filePath.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmedPath.isEmpty {
            return false
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: trimmedPath, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }

        return false
    }

    // Validate file path
    func validateFilePath() -> String? {
        let trimmedPath = filePath.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if trimmedPath.isEmpty {
            return "File or directory path is required"
        }

        // Check if path exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: trimmedPath) {
            return "Path does not exist"
        }

        // Check if readable
        if !fileManager.isReadableFile(atPath: trimmedPath) {
            return "Path is not readable"
        }

        return nil
    }

    // Validate object name
    func validateObjectName() -> String? {
        // Object name is optional - if empty, we'll use the filename
        if objectName.isEmpty {
            return nil
        }

        let trimmedName = objectName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Check for invalid characters (Swift object names should not contain certain characters)
        if trimmedName.isEmpty {
            return nil // Empty is OK - will use filename
        }

        return nil
    }

    // Validate the entire form
    func validateForm() -> [String] {
        var errors: [String] = []

        if let pathError = validateFilePath() {
            errors.append(pathError)
        }

        if let nameError = validateObjectName() {
            errors.append(nameError)
        }

        return errors
    }

    // Check if form is valid
    func isValid() -> Bool {
        return validateForm().isEmpty
    }

    // Get the final object name to use for upload
    func getFinalObjectName() -> String {
        let trimmedName = objectName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        // Use filename from path
        let url = URL(fileURLWithPath: filePath)
        return url.lastPathComponent
    }

    // Detect content type from file extension
    func detectContentType() -> String? {
        if !contentType.isEmpty {
            return contentType
        }

        let url = URL(fileURLWithPath: filePath)
        return SwiftStorageHelpers.detectContentType(for: url)
    }
}
