import Foundation

enum BarbicanSecretCreateField: CaseIterable {
    case name, payload, payloadContentType, payloadContentEncoding, secretType, algorithm, bitLength, mode, expirationDate

    var title: String {
        switch self {
        case .name: return "Secret Name"
        case .payload: return "Secret Payload"
        case .payloadContentType: return "Payload Content Type"
        case .payloadContentEncoding: return "Payload Content Encoding"
        case .secretType: return "Secret Type"
        case .algorithm: return "Algorithm"
        case .bitLength: return "Bit Length"
        case .mode: return "Mode"
        case .expirationDate: return "Expiration Date"
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

struct BarbicanSecretCreateForm {
    var secretName: String = ""
    var payload: String = ""
    var payloadContentType: SecretPayloadContentType = .textPlain
    var payloadContentEncoding: SecretPayloadContentEncoding = .base64
    var secretType: SecretType = .opaque
    var algorithm: SecretAlgorithm = .aes
    var bitLength: Int = 256
    var mode: SecretMode = .cbc

    // Structured expiration date fields
    var expirationMonth: Int = 1
    var expirationDay: Int = 1
    var expirationYear: Int = 2025
    var expirationHour: Int = 0
    var expirationMinute: Int = 0
    var hasExpiration: Bool = false

    var currentField: BarbicanSecretCreateField = .name
    var fieldEditMode: Bool = false
    var payloadEditMode: Bool = false // Special mode for multi-line payload editing
    var selectionMode: Bool = false // Special mode for selection windows (legacy)
    var selectionIndex: Int = 0 // Current selection index in selection mode
    var selectionConfirmed: Int? = nil // Index of item selected for confirmation
    var dateSelectionMode: Bool = false // Special mode for date selection

    // FormSelector-based selection modes
    var contentTypeSelectionMode: Bool = false
    var contentTypeSelectionIndex: Int = 0
    var selectedContentTypeID: String?

    var encodingSelectionMode: Bool = false
    var encodingSelectionIndex: Int = 0
    var selectedEncodingID: String?

    var secretTypeSelectionMode: Bool = false
    var secretTypeSelectionIndex: Int = 0
    var selectedSecretTypeID: String?

    var algorithmSelectionMode: Bool = false
    var algorithmSelectionIndex: Int = 0
    var selectedAlgorithmID: String?

    var modeSelectionMode: Bool = false
    var modeSelectionIndex: Int = 0
    var selectedModeID: String?

    var bitLengthSelectionMode: Bool = false
    var bitLengthSelectionIndex: Int = 0
    var selectedBitLengthID: String?

    // Payload input buffering for performance
    var payloadBuffer: String = ""
    var isBuffering: Bool = false // Flag to indicate when we're in rapid input mode
    var isPasteMode: Bool = false // Flag for extremely rapid input (paste operations)
    var lastBufferFlushTime: Date = Date() // Track when buffer was last flushed
    var renderOptimizationThreshold: Int = 1000 // Characters above which to use optimized rendering
    var lastRenderTime: Date = Date() // Track render timing for optimization

    // Cached payload line data for performance
    private var cachedPayloadLines: [String] = []
    private var cachedPayloadVersion: String = "" // Track when cache is valid
    private var isLargeContent: Bool = false // Flag for content > 4096 chars

    mutating func nextField() {
        let fields = BarbicanSecretCreateField.allCases
        if let currentIndex = fields.firstIndex(of: currentField) {
            let nextIndex = (currentIndex + 1) % fields.count
            currentField = fields[nextIndex]
        }
        fieldEditMode = false
        payloadEditMode = false
        selectionMode = false
    }

    mutating func previousField() {
        let fields = BarbicanSecretCreateField.allCases
        if let currentIndex = fields.firstIndex(of: currentField) {
            let prevIndex = currentIndex == 0 ? fields.count - 1 : currentIndex - 1
            currentField = fields[prevIndex]
        }
        fieldEditMode = false
        payloadEditMode = false
        selectionMode = false
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

    mutating func activateDateSelectionMode() {
        dateSelectionMode = true
        hasExpiration = true
        fieldEditMode = false
        payloadEditMode = false
    }

    mutating func exitEditMode() {
        fieldEditMode = false
        payloadEditMode = false
        selectionMode = false
        dateSelectionMode = false
    }

    mutating func enterSelectionMode() {
        selectionMode = true
        selectionIndex = getCurrentSelectionIndex()
        fieldEditMode = false
        payloadEditMode = false
    }

    mutating func exitSelectionMode() {
        selectionMode = false
        dateSelectionMode = false
        selectionIndex = 0
        selectionConfirmed = nil
    }

    mutating func nextSelectionItem() {
        let maxIndex = getSelectionOptionsCount() - 1
        selectionIndex = min(selectionIndex + 1, maxIndex)
    }

    mutating func previousSelectionItem() {
        selectionIndex = max(selectionIndex - 1, 0)
    }

    mutating func toggleSelectionConfirmation() {
        if selectionConfirmed == selectionIndex {
            selectionConfirmed = nil // Deselect if already selected
        } else {
            selectionConfirmed = selectionIndex // Select current item for confirmation
        }
    }

    mutating func confirmSelection() {
        guard let confirmedIndex = selectionConfirmed else { return }

        switch currentField {
        case .payloadContentType:
            payloadContentType = SecretPayloadContentType.allCases[confirmedIndex]
        case .payloadContentEncoding:
            payloadContentEncoding = SecretPayloadContentEncoding.allCases[confirmedIndex]
        case .secretType:
            secretType = SecretType.allCases[confirmedIndex]
        case .algorithm:
            algorithm = SecretAlgorithm.allCases[confirmedIndex]
        case .mode:
            mode = SecretMode.allCases[confirmedIndex]
        case .bitLength:
            let validBitLengths = [128, 192, 256, 512, 1024, 2048, 3072, 4096]
            bitLength = validBitLengths[confirmedIndex]
        case .expirationDate:
            if confirmedIndex == 0 {
                hasExpiration = false // "No Expiration"
            } else {
                hasExpiration = true // "Set Custom Date"
                dateSelectionMode = true // Enter date selection mode
                selectionMode = false
                selectionIndex = 0 // Start with first date field (month)
                selectionConfirmed = nil
                return // Don't exit selection mode yet, enter date mode
            }
        default:
            break
        }
        exitSelectionMode()
    }

    mutating func selectCurrentItem() {
        // Legacy method - now just confirms current selection immediately
        selectionConfirmed = selectionIndex
        confirmSelection()
    }

    func getSelectionOptionsCount() -> Int {
        switch currentField {
        case .payloadContentType:
            return SecretPayloadContentType.allCases.count
        case .payloadContentEncoding:
            return SecretPayloadContentEncoding.allCases.count
        case .secretType:
            return SecretType.allCases.count
        case .algorithm:
            return SecretAlgorithm.allCases.count
        case .mode:
            return SecretMode.allCases.count
        case .bitLength:
            return 8 // [128, 192, 256, 512, 1024, 2048, 3072, 4096]
        case .expirationDate:
            return 2 // ["No Expiration", "Set Custom Date"]
        default:
            return 0
        }
    }

    func getSelectionOptions() -> [String] {
        switch currentField {
        case .payloadContentType:
            return SecretPayloadContentType.allCases.map { $0.title }
        case .payloadContentEncoding:
            return SecretPayloadContentEncoding.allCases.map { $0.title }
        case .secretType:
            return SecretType.allCases.map { $0.title }
        case .algorithm:
            return SecretAlgorithm.allCases.map { $0.title }
        case .mode:
            return SecretMode.allCases.map { $0.title }
        case .bitLength:
            return ["128", "192", "256", "512", "1024", "2048", "3072", "4096"]
        case .expirationDate:
            return ["No Expiration", "Set Custom Date"]
        default:
            return []
        }
    }

    func getCurrentSelectionValue() -> String {
        switch currentField {
        case .payloadContentType:
            return payloadContentType.title
        case .payloadContentEncoding:
            return payloadContentEncoding.title
        case .secretType:
            return secretType.title
        case .algorithm:
            return algorithm.title
        case .mode:
            return mode.title
        case .bitLength:
            return String(bitLength)
        case .expirationDate:
            return hasExpiration ? "Set Custom Date" : "No Expiration"
        default:
            return ""
        }
    }

    func getCurrentSelectionIndex() -> Int {
        switch currentField {
        case .payloadContentType:
            return SecretPayloadContentType.allCases.firstIndex(of: payloadContentType) ?? 0
        case .payloadContentEncoding:
            return SecretPayloadContentEncoding.allCases.firstIndex(of: payloadContentEncoding) ?? 0
        case .secretType:
            return SecretType.allCases.firstIndex(of: secretType) ?? 0
        case .algorithm:
            return SecretAlgorithm.allCases.firstIndex(of: algorithm) ?? 0
        case .mode:
            return SecretMode.allCases.firstIndex(of: mode) ?? 0
        case .bitLength:
            let validBitLengths = [128, 192, 256, 512, 1024, 2048, 3072, 4096]
            return validBitLengths.firstIndex(of: bitLength) ?? 0
        case .expirationDate:
            return hasExpiration ? 1 : 0 // 0="No Expiration", 1="Set Custom Date"
        default:
            return 0
        }
    }

    func validate() -> [String] {
        var errors: [String] = []

        let trimmedName = secretName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append("Secret name is required")
        }

        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPayload.isEmpty {
            errors.append("Secret payload is required")
        }

        // Validate bit length
        let validBitLengths = [128, 192, 256, 512, 1024, 2048, 3072, 4096]
        if !validBitLengths.contains(bitLength) {
            errors.append("Bit length must be one of: \(validBitLengths.map(String.init).joined(separator: ", "))")
        }

        // Validate expiration date if provided
        if hasExpiration {
            if expirationMonth < 1 || expirationMonth > 12 {
                errors.append("Month must be between 1 and 12")
            }
            if expirationDay < 1 || expirationDay > 31 {
                errors.append("Day must be between 1 and 31")
            }
            if expirationYear < 2025 || expirationYear > 9999 {
                errors.append("Year must be between 2025 and 9999")
            }
            if expirationHour < 0 || expirationHour > 23 {
                errors.append("Hour must be between 0 and 23")
            }
            if expirationMinute < 0 || expirationMinute > 59 {
                errors.append("Minute must be between 0 and 59")
            }

            // Validate actual date exists
            let calendar = Calendar.current
            let dateComponents = DateComponents(year: expirationYear, month: expirationMonth, day: expirationDay, hour: expirationHour, minute: expirationMinute)
            if calendar.date(from: dateComponents) == nil {
                errors.append("Invalid date combination")
            }
        }

        return errors
    }

    func getExpirationDate() -> Date? {
        guard hasExpiration else {
            return nil
        }

        let calendar = Calendar.current
        let dateComponents = DateComponents(year: expirationYear, month: expirationMonth, day: expirationDay, hour: expirationHour, minute: expirationMinute)
        return calendar.date(from: dateComponents)
    }

    // Date selection navigation methods
    mutating func nextDateField() {
        selectionIndex = min(selectionIndex + 1, 4) // 0=month, 1=day, 2=year, 3=hour, 4=minute
    }

    mutating func previousDateField() {
        selectionIndex = max(selectionIndex - 1, 0)
    }

    mutating func increaseDateFieldValue() {
        switch selectionIndex {
        case 0: // Month
            expirationMonth = min(expirationMonth + 1, 12)
        case 1: // Day
            expirationDay = min(expirationDay + 1, 31)
        case 2: // Year
            expirationYear = min(expirationYear + 1, 9999)
        case 3: // Hour
            expirationHour = min(expirationHour + 1, 23)
        case 4: // Minute
            expirationMinute = min(expirationMinute + 1, 59)
        default:
            break
        }
    }

    mutating func decreaseDateFieldValue() {
        switch selectionIndex {
        case 0: // Month
            expirationMonth = max(expirationMonth - 1, 1)
        case 1: // Day
            expirationDay = max(expirationDay - 1, 1)
        case 2: // Year
            expirationYear = max(expirationYear - 1, 2025)
        case 3: // Hour
            expirationHour = max(expirationHour - 1, 0)
        case 4: // Minute
            expirationMinute = max(expirationMinute - 1, 0)
        default:
            break
        }
    }

    mutating func exitDateSelectionMode() {
        dateSelectionMode = false
        selectionIndex = 0
    }

    // Payload buffer management for performance
    mutating func addToPayloadBuffer(_ char: Character) {
        payloadBuffer.append(char)
        isBuffering = true

        // Detect rapid input patterns (paste operations)
        let now = Date()
        if now.timeIntervalSince(lastBufferFlushTime) < 0.05 { // Less than 50ms since last input
            isPasteMode = true
        }
        lastBufferFlushTime = now

        // For paste operations, allow much larger buffers to minimize flushes
        if payloadBuffer.count > 5000 {
            flushPayloadBuffer()
        }
    }

    mutating func flushPayloadBuffer() {
        if !payloadBuffer.isEmpty {
            payload += payloadBuffer
            payloadBuffer = ""
            invalidatePayloadCache() // Invalidate cache when content changes
        }
        isBuffering = false

        // Immediately exit paste mode for instant rendering (no delay)
        isPasteMode = false

        // Check if we now have large content
        let totalLength = getCompletePayload().count
        isLargeContent = totalLength > renderOptimizationThreshold
    }

    mutating func removeFromPayloadBuffer() {
        if !payloadBuffer.isEmpty {
            payloadBuffer.removeLast()
        } else if !payload.isEmpty {
            payload.removeLast()
        }
    }

    func getCompletePayload() -> String {
        return payload + payloadBuffer
    }

    // Invalidate cached payload data when content changes
    private mutating func invalidatePayloadCache() {
        cachedPayloadLines = []
        cachedPayloadVersion = ""
    }

    // Get optimized payload lines for rendering
    mutating func getPayloadLines() -> [String] {
        let completePayload = getCompletePayload()

        // Return cached lines if payload hasn't changed
        if cachedPayloadVersion == completePayload && !cachedPayloadLines.isEmpty {
            return cachedPayloadLines
        }

        // Update cache
        cachedPayloadLines = completePayload.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        cachedPayloadVersion = completePayload

        return cachedPayloadLines
    }

    // Get optimized payload preview for form display
    func getPayloadPreview() -> String {
        let completePayload = getCompletePayload()

        if completePayload.isEmpty {
            return "Press SPACE to edit payload..."
        }

        // For large content, show optimized preview
        if completePayload.count > renderOptimizationThreshold {
            return "Large content (\(completePayload.count) chars) - \(completePayload.prefix(20))..."
        }

        // For normal content, show up to 50 characters
        return completePayload.count > 50 ? "\(String(completePayload.prefix(47)))..." : completePayload
    }

    // Check if content should use optimized rendering
    func shouldUseOptimizedRendering() -> Bool {
        return getCompletePayload().count > renderOptimizationThreshold || isPasteMode
    }

    // Clear paste mode (called from UI when appropriate)
    mutating func clearPasteMode() {
        isPasteMode = false
    }

    // MARK: - FormSelector Helper Methods

    mutating func enterContentTypeSelectionMode() {
        contentTypeSelectionMode = true
    }

    mutating func exitContentTypeSelectionMode() {
        contentTypeSelectionMode = false
        if let selectedID = selectedContentTypeID,
           let selectedType = SecretPayloadContentType.allCases.first(where: { $0.rawValue == selectedID }) {
            payloadContentType = selectedType
        }
    }

    mutating func enterEncodingSelectionMode() {
        encodingSelectionMode = true
    }

    mutating func exitEncodingSelectionMode() {
        encodingSelectionMode = false
        if let selectedID = selectedEncodingID,
           let selectedEncoding = SecretPayloadContentEncoding.allCases.first(where: { $0.rawValue == selectedID }) {
            payloadContentEncoding = selectedEncoding
        }
    }

    mutating func enterSecretTypeSelectionMode() {
        secretTypeSelectionMode = true
    }

    mutating func exitSecretTypeSelectionMode() {
        secretTypeSelectionMode = false
        if let selectedID = selectedSecretTypeID,
           let selectedType = SecretType.allCases.first(where: { $0.rawValue == selectedID }) {
            secretType = selectedType
        }
    }

    mutating func enterAlgorithmSelectionMode() {
        algorithmSelectionMode = true
    }

    mutating func exitAlgorithmSelectionMode() {
        algorithmSelectionMode = false
        if let selectedID = selectedAlgorithmID,
           let selectedAlgorithm = SecretAlgorithm.allCases.first(where: { $0.rawValue == selectedID }) {
            algorithm = selectedAlgorithm
        }
    }

    mutating func enterModeSelectionMode() {
        modeSelectionMode = true
    }

    mutating func exitModeSelectionMode() {
        modeSelectionMode = false
        if let selectedID = selectedModeID,
           let selectedMode = SecretMode.allCases.first(where: { $0.rawValue == selectedID }) {
            mode = selectedMode
        }
    }

    mutating func enterBitLengthSelectionMode() {
        bitLengthSelectionMode = true
    }

    mutating func exitBitLengthSelectionMode() {
        bitLengthSelectionMode = false
        if let selectedID = selectedBitLengthID,
           let selectedValue = Int(selectedID) {
            bitLength = selectedValue
        }
    }
}