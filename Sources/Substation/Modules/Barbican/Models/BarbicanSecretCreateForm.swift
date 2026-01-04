import Foundation

enum BarbicanSecretCreateField: CaseIterable {
    case name, payloadFilePath, payloadContentType, payloadContentEncoding, secretType, algorithm, bitLength, mode

    var title: String {
        switch self {
        case .name: return "Secret Name"
        case .payloadFilePath: return "Load from File (TAB to complete)"
        case .payloadContentType: return "Payload Content Type"
        case .payloadContentEncoding: return "Payload Content Encoding"
        case .secretType: return "Secret Type"
        case .algorithm: return "Algorithm"
        case .bitLength: return "Bit Length"
        case .mode: return "Mode"
        }
    }
}

enum SecretPayloadContentType: String, CaseIterable {
    case textPlain = "text/plain"
    case applicationOctetStream = "application/octet-stream"
    case applicationPkcs12 = "application/x-pkcs12"
    case applicationPemFile = "application/x-pem-file"

    var title: String {
        return self.rawValue
    }
}

enum SecretPayloadContentEncoding: String, CaseIterable {
    case base64 = "base64"
    case binary = "binary"

    var title: String {
        return self.rawValue
    }
}

enum SecretType: String, CaseIterable {
    case opaque = "opaque"
    case symmetric = "symmetric"
    case publicKey = "public"
    case privateKey = "private"
    case certificate = "certificate"
    case passphrase = "passphrase"

    var title: String {
        return self.rawValue
    }
}

enum SecretAlgorithm: String, CaseIterable {
    case aes = "AES"
    case des = "DES"
    case des3 = "3DES"
    case rsa = "RSA"
    case dsa = "DSA"
    case ec = "EC"

    var title: String {
        return self.rawValue
    }
}

enum SecretMode: String, CaseIterable {
    case cbc = "CBC"
    case ctr = "CTR"

    var title: String {
        return self.rawValue
    }
}

struct BarbicanSecretCreateForm: FormViewModel {
    var secretName: String = ""
    var payloadFilePath: String = ""
    var payload: String = "" // Loaded from file
    var payloadContentType: SecretPayloadContentType = .textPlain
    var payloadContentEncoding: SecretPayloadContentEncoding = .base64
    var secretType: SecretType = .opaque
    var algorithm: SecretAlgorithm = .aes
    var bitLength: Int = 256
    var mode: SecretMode = .cbc

    var currentField: BarbicanSecretCreateField = .name
    var fieldEditMode: Bool = false

    // Form state management
    var errorMessage: String? = nil
    var isLoading: Bool = false

    /// Navigates to the next field in the form
    mutating func nextField() {
        let fields = BarbicanSecretCreateField.allCases
        if let currentIndex = fields.firstIndex(of: currentField) {
            let nextIndex = (currentIndex + 1) % fields.count
            currentField = fields[nextIndex]
        }
        fieldEditMode = false
    }

    /// Navigates to the previous field in the form
    mutating func previousField() {
        let fields = BarbicanSecretCreateField.allCases
        if let currentIndex = fields.firstIndex(of: currentField) {
            let prevIndex = currentIndex == 0 ? fields.count - 1 : currentIndex - 1
            currentField = fields[prevIndex]
        }
        fieldEditMode = false
    }

    mutating func togglePayloadContentType() {
        let types = SecretPayloadContentType.allCases
        if let currentIndex = types.firstIndex(of: payloadContentType) {
            let nextIndex = (currentIndex + 1) % types.count
            payloadContentType = types[nextIndex]
        }
    }

    mutating func togglePayloadContentEncoding() {
        let encodings = SecretPayloadContentEncoding.allCases
        if let currentIndex = encodings.firstIndex(of: payloadContentEncoding) {
            let nextIndex = (currentIndex + 1) % encodings.count
            payloadContentEncoding = encodings[nextIndex]
        }
    }

    mutating func toggleSecretType() {
        let types = SecretType.allCases
        if let currentIndex = types.firstIndex(of: secretType) {
            let nextIndex = (currentIndex + 1) % types.count
            secretType = types[nextIndex]
        }
    }

    mutating func toggleAlgorithm() {
        let algorithms = SecretAlgorithm.allCases
        if let currentIndex = algorithms.firstIndex(of: algorithm) {
            let nextIndex = (currentIndex + 1) % algorithms.count
            algorithm = algorithms[nextIndex]
        }
    }

    mutating func toggleMode() {
        let modes = SecretMode.allCases
        if let currentIndex = modes.firstIndex(of: mode) {
            let nextIndex = (currentIndex + 1) % modes.count
            mode = modes[nextIndex]
        }
    }

    mutating func increaseBitLength() {
        let validBitLengths = [128, 192, 256, 512, 1024, 2048, 3072, 4096]
        if let currentIndex = validBitLengths.firstIndex(of: bitLength) {
            let nextIndex = min(currentIndex + 1, validBitLengths.count - 1)
            bitLength = validBitLengths[nextIndex]
        } else {
            // If current value is not in the list, find the next valid one
            bitLength = validBitLengths.first { $0 > bitLength } ?? 4096
        }
    }

    mutating func decreaseBitLength() {
        let validBitLengths = [128, 192, 256, 512, 1024, 2048, 3072, 4096]
        if let currentIndex = validBitLengths.firstIndex(of: bitLength) {
            let prevIndex = max(currentIndex - 1, 0)
            bitLength = validBitLengths[prevIndex]
        } else {
            // If current value is not in the list, find the previous valid one
            bitLength = validBitLengths.last { $0 < bitLength } ?? 128
        }
    }

    /// Exits any active edit mode in the form
    mutating func exitEditMode() {
        fieldEditMode = false
    }

    func validate() -> [String] {
        var errors: [String] = []

        let trimmedName = secretName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append("Secret name is required")
        }

        // Validate file path is provided
        if let filePathError = validateFilePath() {
            errors.append(filePathError)
        }

        // Validate payload was loaded
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPayload.isEmpty {
            errors.append("Secret payload is required (load from file)")
        }

        // Validate bit length
        let validBitLengths = [128, 192, 256, 512, 1024, 2048, 3072, 4096]
        if !validBitLengths.contains(bitLength) {
            errors.append("Bit length must be one of: \(validBitLengths.map(String.init).joined(separator: ", "))")
        }

        return errors
    }

    // Validate file path - required field
    func validateFilePath() -> String? {
        return FilePathCompleter.validatePublicKeyPath(payloadFilePath)
    }

    // Load payload from file
    mutating func loadPayloadFromFile() -> String? {
        let trimmed = payloadFilePath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "File path is required"
        }

        let expanded = FilePathCompleter.expandPath(trimmed)

        // Check file exists
        guard FileManager.default.fileExists(atPath: expanded) else {
            return "File not found: \(trimmed)"
        }

        // Check it's not a directory
        if FilePathCompleter.isDirectory(at: expanded) {
            return "Path is a directory, not a file"
        }

        // Read file
        do {
            let contents = try String(contentsOfFile: expanded, encoding: .utf8)
            payload = contents
            return nil
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }

    // Get payload preview for form display
    func getPayloadPreview() -> String {
        if payload.isEmpty {
            return "No file loaded"
        }

        // Show preview of loaded content
        let charCount = payload.count
        let lineCount = payload.components(separatedBy: "\n").count
        let preview = payload.prefix(30).replacingOccurrences(of: "\n", with: " ")
        return "\(charCount) chars, \(lineCount) lines: \(preview)..."
    }

    // MARK: - FormViewModel Implementation

    func getFieldConfigurations() -> [FormFieldConfiguration] {
        return BarbicanSecretCreateField.allCases.map { field in
            getFieldConfiguration(for: field)
        }
    }

    func getValidationState() -> FormValidationState {
        let errors = validate()
        return FormValidationState(isValid: errors.isEmpty, errors: errors)
    }

    func getFormTitle() -> String {
        return "Create New Secret"
    }

    func getNavigationHelp() -> String {
        if fieldEditMode {
            if currentField == .payloadFilePath {
                return "ESC: Exit editing | TAB: Complete path | ENTER: Load file"
            }
            return "ESC: Exit editing | Type to enter value"
        } else {
            return "TAB/UP/DOWN: Navigate fields | SPACE: Edit/Select | ENTER: Create | ESC: Cancel"
        }
    }

    /// Determines if the form is currently in a special input mode
    func isInSpecialMode() -> Bool {
        return fieldEditMode
    }

    private func getFieldConfiguration(for field: BarbicanSecretCreateField) -> FormFieldConfiguration {
        let isSelected = (currentField == field)
        let isActive = isSelected && fieldEditMode

        switch field {
        case .name:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: true,
                isSelected: isSelected,
                isActive: isActive,
                placeholder: "Press SPACE to edit...",
                value: secretName.isEmpty ? nil : secretName,
                maxWidth: 50,
                fieldType: .text
            )

        case .payloadFilePath:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: true,
                isSelected: isSelected,
                isActive: isActive,
                placeholder: "~/path/to/secret.txt (TAB to complete)",
                value: payloadFilePath.isEmpty ? nil : payloadFilePath,
                maxWidth: 60,
                fieldType: .text
            )

        case .payloadContentType:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: false,
                value: payloadContentType.title,
                fieldType: .enumeration
            )

        case .payloadContentEncoding:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: false,
                value: payloadContentEncoding.title,
                fieldType: .enumeration
            )

        case .secretType:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: false,
                value: secretType.title,
                fieldType: .enumeration
            )

        case .algorithm:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: false,
                value: algorithm.title,
                fieldType: .enumeration
            )

        case .bitLength:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: false,
                value: "\(bitLength) bits",
                fieldType: .enumeration
            )

        case .mode:
            return FormFieldConfiguration(
                title: field.title,
                isRequired: false,
                isSelected: isSelected,
                isActive: false,
                value: mode.title,
                fieldType: .enumeration
            )
        }
    }

    // MARK: - FormBuilder Integration

    func buildFields(
        selectedFieldId: String?,
        activeFieldId: String?,
        formState: FormBuilderState
    ) -> [FormField] {
        var fields: [FormField] = []

        // Secret Name Field
        let nameFieldId = BarbicanSecretCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameFieldId,
            label: BarbicanSecretCreateField.name.title,
            value: secretName,
            placeholder: "Enter secret name",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameFieldId,
            isActive: activeFieldId == nameFieldId,
            cursorPosition: formState.textFieldStates[nameFieldId]?.cursorPosition,
            validationError: nil,
            maxWidth: 50,
            maxLength: 255
        )))

        // Payload File Path (Text) - Required field with TAB completion
        let filePathFieldId = BarbicanSecretCreateFieldId.payloadFilePath.rawValue
        fields.append(.text(FormFieldText(
            id: filePathFieldId,
            label: BarbicanSecretCreateField.payloadFilePath.title,
            value: payloadFilePath,
            placeholder: "~/path/to/secret.txt",
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == filePathFieldId,
            isActive: activeFieldId == filePathFieldId,
            cursorPosition: formState.textFieldStates[filePathFieldId]?.cursorPosition,
            validationError: validateFilePath(),
            maxWidth: 60,
            maxLength: nil
        )))

        // Payload Preview (Info field - shows loaded content)
        if !payload.isEmpty {
            fields.append(.info(FormFieldInfo(
                id: "payload-preview",
                label: "Loaded Content",
                value: getPayloadPreview(),
                isVisible: true,
                style: .info
            )))
        }

        // Payload Content Type (Selector)
        let contentTypeFieldId = BarbicanSecretCreateFieldId.payloadContentType.rawValue
        let contentTypeItems = SecretPayloadContentType.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: contentTypeFieldId,
            label: BarbicanSecretCreateField.payloadContentType.title,
            items: contentTypeItems,
            selectedItemId: payloadContentType.rawValue,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == contentTypeFieldId,
            isActive: activeFieldId == contentTypeFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "CONTENT TYPE", width: 30) { item in
                    (item as? SecretPayloadContentType)?.title ?? ""
                }
            ],
            searchQuery: formState.selectorStates[contentTypeFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[contentTypeFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[contentTypeFieldId]?.scrollOffset ?? 0
        )))

        // Payload Content Encoding (Selector)
        let encodingFieldId = BarbicanSecretCreateFieldId.payloadContentEncoding.rawValue
        let encodingItems = SecretPayloadContentEncoding.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: encodingFieldId,
            label: BarbicanSecretCreateField.payloadContentEncoding.title,
            items: encodingItems,
            selectedItemId: payloadContentEncoding.rawValue,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == encodingFieldId,
            isActive: activeFieldId == encodingFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "ENCODING", width: 20) { item in
                    (item as? SecretPayloadContentEncoding)?.title ?? ""
                }
            ],
            searchQuery: formState.selectorStates[encodingFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[encodingFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[encodingFieldId]?.scrollOffset ?? 0
        )))

        // Secret Type (Selector)
        let secretTypeFieldId = BarbicanSecretCreateFieldId.secretType.rawValue
        let secretTypeItems = SecretType.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: secretTypeFieldId,
            label: BarbicanSecretCreateField.secretType.title,
            items: secretTypeItems,
            selectedItemId: secretType.rawValue,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == secretTypeFieldId,
            isActive: activeFieldId == secretTypeFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "SECRET TYPE", width: 20) { item in
                    (item as? SecretType)?.title ?? ""
                }
            ],
            searchQuery: formState.selectorStates[secretTypeFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[secretTypeFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[secretTypeFieldId]?.scrollOffset ?? 0
        )))

        // Algorithm (Selector)
        let algorithmFieldId = BarbicanSecretCreateFieldId.algorithm.rawValue
        let algorithmItems = SecretAlgorithm.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: algorithmFieldId,
            label: BarbicanSecretCreateField.algorithm.title,
            items: algorithmItems,
            selectedItemId: algorithm.rawValue,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == algorithmFieldId,
            isActive: activeFieldId == algorithmFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "ALGORITHM", width: 20) { item in
                    (item as? SecretAlgorithm)?.title ?? ""
                }
            ],
            searchQuery: formState.selectorStates[algorithmFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[algorithmFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[algorithmFieldId]?.scrollOffset ?? 0
        )))

        // Bit Length (Selector)
        let bitLengthFieldId = BarbicanSecretCreateFieldId.bitLength.rawValue
        let bitLengthItems = BitLengthOption.commonBitLengths.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: bitLengthFieldId,
            label: BarbicanSecretCreateField.bitLength.title,
            items: bitLengthItems,
            selectedItemId: "\(bitLength)",
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == bitLengthFieldId,
            isActive: activeFieldId == bitLengthFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "BIT LENGTH", width: 20) { item in
                    (item as? BitLengthOption)?.id ?? ""
                }
            ],
            searchQuery: formState.selectorStates[bitLengthFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[bitLengthFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[bitLengthFieldId]?.scrollOffset ?? 0
        )))

        // Mode (Selector)
        let modeFieldId = BarbicanSecretCreateFieldId.mode.rawValue
        let modeItems = SecretMode.allCases.map { $0 as any FormSelectorItem }
        fields.append(.selector(FormFieldSelector(
            id: modeFieldId,
            label: BarbicanSecretCreateField.mode.title,
            items: modeItems,
            selectedItemId: mode.rawValue,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == modeFieldId,
            isActive: activeFieldId == modeFieldId,
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "MODE", width: 20) { item in
                    (item as? SecretMode)?.title ?? ""
                }
            ],
            searchQuery: formState.selectorStates[modeFieldId]?.searchQuery,
            highlightedIndex: formState.selectorStates[modeFieldId]?.highlightedIndex ?? 0,
            scrollOffset: formState.selectorStates[modeFieldId]?.scrollOffset ?? 0
        )))

        return fields
    }
}

// MARK: - Field Identifiers

enum BarbicanSecretCreateFieldId: String {
    case name = "secret-name"
    case payloadFilePath = "payload-file-path"
    case payloadContentType = "payload-content-type"
    case payloadContentEncoding = "payload-content-encoding"
    case secretType = "secret-type"
    case algorithm = "algorithm"
    case bitLength = "bit-length"
    case mode = "mode"
}

// MARK: - BarbicanSecretCreateForm FormState Integration

extension BarbicanSecretCreateForm {
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // IMPORTANT: Get values from textFieldStates/selectorStates, not from fields array
        // The fields array contains the original values, not the user's input

        // Update text fields from textFieldStates
        if let textState = formState.textFieldStates[BarbicanSecretCreateFieldId.name.rawValue] {
            self.secretName = textState.value
        }
        if let textState = formState.textFieldStates[BarbicanSecretCreateFieldId.payloadFilePath.rawValue] {
            self.payloadFilePath = textState.value
        }

        // Update selector fields from selectorStates
        if let selectorState = formState.selectorStates[BarbicanSecretCreateFieldId.payloadContentType.rawValue],
           let selectedId = selectorState.selectedItemId,
           let contentType = SecretPayloadContentType(rawValue: selectedId) {
            self.payloadContentType = contentType
        }
        if let selectorState = formState.selectorStates[BarbicanSecretCreateFieldId.payloadContentEncoding.rawValue],
           let selectedId = selectorState.selectedItemId,
           let encoding = SecretPayloadContentEncoding(rawValue: selectedId) {
            self.payloadContentEncoding = encoding
        }
        if let selectorState = formState.selectorStates[BarbicanSecretCreateFieldId.secretType.rawValue],
           let selectedId = selectorState.selectedItemId,
           let type = SecretType(rawValue: selectedId) {
            self.secretType = type
        }
        if let selectorState = formState.selectorStates[BarbicanSecretCreateFieldId.algorithm.rawValue],
           let selectedId = selectorState.selectedItemId,
           let alg = SecretAlgorithm(rawValue: selectedId) {
            self.algorithm = alg
        }
        if let selectorState = formState.selectorStates[BarbicanSecretCreateFieldId.bitLength.rawValue],
           let selectedId = selectorState.selectedItemId,
           let length = Int(selectedId) {
            self.bitLength = length
        }
        if let selectorState = formState.selectorStates[BarbicanSecretCreateFieldId.mode.rawValue],
           let selectedId = selectorState.selectedItemId,
           let m = SecretMode(rawValue: selectedId) {
            self.mode = m
        }

        // Update navigation state
        if let currentFieldId = formState.getCurrentFieldId() {
            // Map field ID back to BarbicanSecretCreateField enum
            switch currentFieldId {
            case BarbicanSecretCreateFieldId.name.rawValue:
                self.currentField = .name
            case BarbicanSecretCreateFieldId.payloadFilePath.rawValue:
                self.currentField = .payloadFilePath
            case BarbicanSecretCreateFieldId.payloadContentType.rawValue:
                self.currentField = .payloadContentType
            case BarbicanSecretCreateFieldId.payloadContentEncoding.rawValue:
                self.currentField = .payloadContentEncoding
            case BarbicanSecretCreateFieldId.secretType.rawValue:
                self.currentField = .secretType
            case BarbicanSecretCreateFieldId.algorithm.rawValue:
                self.currentField = .algorithm
            case BarbicanSecretCreateFieldId.bitLength.rawValue:
                self.currentField = .bitLength
            case BarbicanSecretCreateFieldId.mode.rawValue:
                self.currentField = .mode
            default:
                break
            }
        }

        // Update edit mode based on active field
        self.fieldEditMode = formState.isCurrentFieldActive()
    }
}