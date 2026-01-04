import Foundation
import OSClient

/// Creation type options for SSH key pair
enum KeyPairCreationType: String, CaseIterable, FormSelectorItem, FormSelectableItem {
    case importKey

    var id: String {
        return rawValue
    }

    var sortKey: String {
        return title
    }

    var title: String {
        switch self {
        case .importKey:
            return "Import Existing Public Key"
        }
    }

    var description: String {
        switch self {
        case .importKey:
            return "Import an existing public key from a file on your system."
        }
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return title.lowercased().contains(lowercasedQuery) ||
               description.lowercased().contains(lowercasedQuery)
    }
}

/// Simple KeyPairCreateForm
struct KeyPairCreateForm {
    // Form data
    var keyPairName: String = ""
    var creationType: KeyPairCreationType = .importKey
    var publicKeyFilePath: String = ""
    var publicKey: String = ""

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Name field
        fields.append(.text(FormFieldText(
            id: "name",
            label: "Key Pair Name",
            value: keyPairName,
            placeholder: "my-keypair",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == "name",
            isActive: activeFieldId == "name",
            cursorPosition: formState.getTextFieldCursorPosition("name"),
            validationError: validateName()
        )))

        // Public key file path
        fields.append(.text(FormFieldText(
            id: "publicKeyFilePath",
            label: "Public Key File Path (TAB to complete)",
            value: publicKeyFilePath,
            placeholder: "~/.ssh/id_rsa.pub",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == "publicKeyFilePath",
            isActive: activeFieldId == "publicKeyFilePath",
            cursorPosition: formState.getTextFieldCursorPosition("publicKeyFilePath"),
            validationError: validateFilePath()
        )))

        // Info field
        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: "Import an existing public key from a file on your system.",
            isVisible: true,
            style: .info
        )))

        return fields
    }

    // Update form from state
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let name = formState.getTextValue("name") {
            keyPairName = name
        }
        if let filePath = formState.getTextValue("publicKeyFilePath") {
            publicKeyFilePath = filePath
        }
    }

    // Validate name
    func validateName() -> String? {
        let trimmed = keyPairName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Name is required"
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@._- ")
        if trimmed.rangeOfCharacter(from: allowed.inverted) != nil {
            return "Name can only contain letters, numbers, @._- and spaces"
        }
        return nil
    }

    // Validate file path
    func validateFilePath() -> String? {
        return FilePathCompleter.validatePublicKeyPath(publicKeyFilePath)
    }

    // Validate entire form
    func validateForm() -> [String] {
        var errors: [String] = []
        if let nameError = validateName() {
            errors.append(nameError)
        }
        if let pathError = validateFilePath() {
            errors.append(pathError)
        }
        return errors
    }

    // Load public key from file
    mutating func loadPublicKeyFromFile() -> String? {
        let trimmed = publicKeyFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "File path is required"
        }

        // Expand tilde
        let expanded: String
        if trimmed.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            expanded = trimmed.replacingOccurrences(of: "~", with: home, options: .anchored)
        } else {
            expanded = trimmed
        }

        // Check file exists
        guard FileManager.default.fileExists(atPath: expanded) else {
            return "File not found: \(expanded)"
        }

        // Read file
        do {
            let contents = try String(contentsOfFile: expanded, encoding: .utf8)
            publicKey = contents.trimmingCharacters(in: .whitespacesAndNewlines)

            // Basic validation
            if !publicKey.starts(with: "ssh-") && !publicKey.starts(with: "ecdsa-") {
                return "Invalid public key format"
            }

            return nil
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}
