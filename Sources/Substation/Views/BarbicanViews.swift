import Foundation
import SwiftTUI
import OSClient

// MARK: - Barbican Views
struct BarbicanViews {
    // MARK: - Secret List View
    @MainActor
    static func drawBarbicanSecretList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        secrets: [Secret],
        searchQuery: String,
        scrollOffset: Int,
        selectedIndex: Int,
        filterCache: ResourceNameCache?
    ) async {
        let statusListView = createBarbicanSecretStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: secrets,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Container List View
    @MainActor
    static func drawBarbicanContainerList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        containers: [BarbicanContainer],
        searchQuery: String,
        scrollOffset: Int,
        selectedIndex: Int,
        filterCache: ResourceNameCache?
    ) async {
        await MiscViews.drawSimpleCenteredMessage(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            message: "Barbican Containers - Implementation Coming Soon"
        )
    }

    // MARK: - Detail Views
    @MainActor
    static func drawBarbicanSecretDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        secret: Secret
    ) async {
        // Defensive bounds checking
        guard width > 20 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        let secretName = secret.name ?? "Unnamed Secret"
        components.append(Text("Secret Details: \(secretName)").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Basic Information Section
        components.append(Text("Basic Information").primary().bold())
        var basicInfo: [any Component] = []

        // Extract secret ID from secretRef
        let secretId = secret.id.isEmpty ? (secret.secretRef ?? "Unknown") : secret.id
        basicInfo.append(Text("ID: \(secretId)").secondary())
        basicInfo.append(Text("Name: \(secretName)").secondary())

        // Status with styling
        let status = secret.status ?? "Unknown"
        let statusStyle: TextStyle = status.lowercased() == "active" ? .success :
                                   (status.lowercased().contains("error") ? .error : .accent)
        basicInfo.append(HStack(spacing: 0, children: [
            Text("Status: ").secondary(),
            Text(status).styled(statusStyle)
        ]))

        if let secretType = secret.secretType {
            basicInfo.append(Text("Type: \(secretType)").secondary())
        }

        if let creatorId = secret.creatorId {
            basicInfo.append(Text("Creator ID: \(creatorId)").secondary())
        }

        let basicInfoSection = VStack(spacing: 0, children: basicInfo)
            .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
        components.append(basicInfoSection)

        // Cryptographic Information Section
        if secret.algorithm != nil || secret.bitLength != nil || secret.mode != nil {
            components.append(Text("Cryptographic Information").primary().bold())
            var cryptoInfo: [any Component] = []

            if let algorithm = secret.algorithm {
                cryptoInfo.append(Text("Algorithm: \(algorithm)").secondary())
            }

            if let bitLength = secret.bitLength {
                cryptoInfo.append(Text("Key Length: \(bitLength) bits").secondary())
            }

            if let mode = secret.mode {
                cryptoInfo.append(Text("Mode: \(mode)").secondary())
            }

            let cryptoSection = VStack(spacing: 0, children: cryptoInfo)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
            components.append(cryptoSection)
        }

        // Timestamps Section
        components.append(Text("Timestamps").primary().bold())
        var timestamps: [any Component] = []

        if let created = secret.created {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            timestamps.append(Text("Created: \(formatter.string(from: created))").secondary())
        }

        if let updated = secret.updated {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            timestamps.append(Text("Updated: \(formatter.string(from: updated))").secondary())
        }

        if let expiration = secret.expiration {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let isExpired = expiration < Date()
            let expirationStyle: TextStyle = isExpired ? .error : .secondary
            let expirationPrefix = isExpired ? "Expired: " : "Expires: "
            timestamps.append(Text("\(expirationPrefix)\(formatter.string(from: expiration))").styled(expirationStyle))
        }

        let timestampsSection = VStack(spacing: 0, children: timestamps)
            .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
        components.append(timestampsSection)

        // Content Types Section
        if let contentTypes = secret.contentTypes, !contentTypes.isEmpty {
            components.append(Text("Content Types").primary().bold())
            var contentInfo: [any Component] = []

            for (key, value) in contentTypes.sorted(by: { $0.key < $1.key }) {
                contentInfo.append(Text("\(key): \(value)").secondary())
            }

            let contentSection = VStack(spacing: 0, children: contentInfo)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
            components.append(contentSection)
        }

        // Secret Reference Section (for API reference)
        if let secretRef = secret.secretRef {
            components.append(Text("API Reference").primary().bold())
            let refSection = VStack(spacing: 0, children: [
                Text("Secret Ref: \(secretRef)").secondary()
            ]).padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0))
            components.append(refSection)
        }

        // Render the final component
        let secretDetailComponent = VStack(spacing: 1, children: components)
            .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(secretDetailComponent, on: surface, in: bounds)
    }

    @MainActor
    static func drawBarbicanContainerDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        container: BarbicanContainer
    ) async {
        await MiscViews.drawSimpleCenteredMessage(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            message: "Container Detail - Implementation Coming Soon"
        )
    }

    // MARK: - Create Views
    @MainActor
    static func drawBarbicanSecretCreateForm(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: BarbicanSecretCreateForm,
        validationErrors: [String] = []
    ) async {
        guard width > 20 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text("Create New Secret").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Handle special payload editing mode
        if form.payloadEditMode {
            await drawPayloadEditor(screen: screen, startRow: startRow, startCol: startCol,
                                  width: width, height: height, form: form)
            return
        }

        // Handle FormSelector-based selection modes
        if form.contentTypeSelectionMode {
            let contentTypes = SecretPayloadContentType.wrappedAllCases
            let selectedIds: Set<String> = form.selectedContentTypeID.map { Set([$0]) } ?? []
            await BarbicanContentTypeSelectionView.drawContentTypeSelection(
                screen: screen, startRow: startRow, startCol: startCol, width: width, height: height,
                contentTypes: contentTypes, selectedIds: selectedIds,
                highlightedIndex: form.contentTypeSelectionIndex, scrollOffset: 0, searchQuery: "",
                title: "Select Payload Content Type"
            )
            return
        }

        if form.encodingSelectionMode {
            let encodings = SecretPayloadContentEncoding.wrappedAllCases
            let selectedIds: Set<String> = form.selectedEncodingID.map { Set([$0]) } ?? []
            await BarbicanEncodingSelectionView.drawEncodingSelection(
                screen: screen, startRow: startRow, startCol: startCol, width: width, height: height,
                encodings: encodings, selectedIds: selectedIds,
                highlightedIndex: form.encodingSelectionIndex, scrollOffset: 0, searchQuery: "",
                title: "Select Payload Content Encoding"
            )
            return
        }

        if form.secretTypeSelectionMode {
            let secretTypes = SecretType.wrappedAllCases
            let selectedIds: Set<String> = form.selectedSecretTypeID.map { Set([$0]) } ?? []
            await BarbicanSecretTypeSelectionView.drawSecretTypeSelection(
                screen: screen, startRow: startRow, startCol: startCol, width: width, height: height,
                secretTypes: secretTypes, selectedIds: selectedIds,
                highlightedIndex: form.secretTypeSelectionIndex, scrollOffset: 0, searchQuery: "",
                title: "Select Secret Type"
            )
            return
        }

        if form.algorithmSelectionMode {
            let algorithms = SecretAlgorithm.wrappedAllCases
            let selectedIds: Set<String> = form.selectedAlgorithmID.map { Set([$0]) } ?? []
            await BarbicanAlgorithmSelectionView.drawAlgorithmSelection(
                screen: screen, startRow: startRow, startCol: startCol, width: width, height: height,
                algorithms: algorithms, selectedIds: selectedIds,
                highlightedIndex: form.algorithmSelectionIndex, scrollOffset: 0, searchQuery: "",
                title: "Select Algorithm"
            )
            return
        }

        if form.modeSelectionMode {
            let modes = SecretMode.wrappedAllCases
            let selectedIds: Set<String> = form.selectedModeID.map { Set([$0]) } ?? []
            await BarbicanModeSelectionView.drawModeSelection(
                screen: screen, startRow: startRow, startCol: startCol, width: width, height: height,
                modes: modes, selectedIds: selectedIds,
                highlightedIndex: form.modeSelectionIndex, scrollOffset: 0, searchQuery: "",
                title: "Select Mode"
            )
            return
        }

        if form.bitLengthSelectionMode {
            let bitLengths = BitLengthOption.commonBitLengths
            let selectedIds: Set<String> = form.selectedBitLengthID.map { Set([$0]) } ?? []
            await BarbicanBitLengthSelectionView.drawBitLengthSelection(
                screen: screen, startRow: startRow, startCol: startCol, width: width, height: height,
                bitLengths: bitLengths, selectedIds: selectedIds,
                highlightedIndex: form.bitLengthSelectionIndex, scrollOffset: 0, searchQuery: "",
                title: "Select Bit Length"
            )
            return
        }

        // Handle special selection mode (legacy)
        if form.selectionMode {
            await drawSelectionWindow(screen: screen, startRow: startRow, startCol: startCol,
                                    width: width, height: height, form: form)
            return
        }

        // Handle date selection mode
        if form.dateSelectionMode {
            await drawDateSelectionWindow(screen: screen, startRow: startRow, startCol: startCol,
                                        width: width, height: height, form: form)
            return
        }

        // Form fields
        let fieldPadding = EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 0)

        // Secret Name
        let nameHighlight: TextStyle = form.currentField == .name ? (form.fieldEditMode ? .accent : .accent) : .secondary
        let nameValue = form.fieldEditMode ? "\(form.secretName)_" : form.secretName.isEmpty ? "Press SPACE to edit..." : form.secretName
        let namePrefix = form.currentField == .name ? ">> " : "   "
        components.append(VStack(spacing: 0, children: [
            Text("\(namePrefix)Secret Name: *").styled(nameHighlight),
            Text("    \(nameValue)").styled(form.fieldEditMode ? .accent : .info)
        ]).padding(fieldPadding))

        // Secret Payload
        let payloadHighlight: TextStyle = form.currentField == .payload ? .accent : .secondary
        let payloadPrefix = form.currentField == .payload ? ">> " : "   "

        // Show optimized view during input to improve performance
        let payloadPreview: String
        if form.isPasteMode {
            let totalLength = form.payload.count + form.payloadBuffer.count
            if totalLength > 4000 {
                payloadPreview = "Large paste operation (\(totalLength) chars) - 4096-bit key detected?"
            } else {
                payloadPreview = "Pasting content... (\(totalLength) chars)"
            }
        } else if form.isBuffering && !form.payloadBuffer.isEmpty {
            let totalLength = form.payload.count + form.payloadBuffer.count
            payloadPreview = "Buffering input... (\(totalLength) characters)"
        } else {
            // Use the optimized preview method
            payloadPreview = form.getPayloadPreview()
        }

        components.append(VStack(spacing: 0, children: [
            Text("\(payloadPrefix)Secret Payload: *").styled(payloadHighlight),
            Text("    \(payloadPreview)").styled(.info)
        ]).padding(fieldPadding))

        // Payload Content Type
        let contentTypeHighlight: TextStyle = form.currentField == .payloadContentType ? .accent : .secondary
        let contentTypePrefix = form.currentField == .payloadContentType ? ">> " : "   "
        components.append(VStack(spacing: 0, children: [
            Text("\(contentTypePrefix)Payload Content Type:").styled(contentTypeHighlight),
            Text("    \(form.payloadContentType.title) (Press SPACE to select)").styled(.info)
        ]).padding(fieldPadding))

        // Payload Content Encoding
        let encodingHighlight: TextStyle = form.currentField == .payloadContentEncoding ? .accent : .secondary
        let encodingPrefix = form.currentField == .payloadContentEncoding ? ">> " : "   "
        components.append(VStack(spacing: 0, children: [
            Text("\(encodingPrefix)Payload Content Encoding:").styled(encodingHighlight),
            Text("    \(form.payloadContentEncoding.title) (Press SPACE to select)").styled(.info)
        ]).padding(fieldPadding))

        // Secret Type
        let secretTypeHighlight: TextStyle = form.currentField == .secretType ? .accent : .secondary
        let secretTypePrefix = form.currentField == .secretType ? ">> " : "   "
        components.append(VStack(spacing: 0, children: [
            Text("\(secretTypePrefix)Secret Type:").styled(secretTypeHighlight),
            Text("    \(form.secretType.title) (Press SPACE to select)").styled(.info)
        ]).padding(fieldPadding))

        // Algorithm
        let algorithmHighlight: TextStyle = form.currentField == .algorithm ? .accent : .secondary
        let algorithmPrefix = form.currentField == .algorithm ? ">> " : "   "
        components.append(VStack(spacing: 0, children: [
            Text("\(algorithmPrefix)Algorithm:").styled(algorithmHighlight),
            Text("    \(form.algorithm.title) (Press SPACE to select)").styled(.info)
        ]).padding(fieldPadding))

        // Bit Length
        let bitLengthHighlight: TextStyle = form.currentField == .bitLength ? .accent : .secondary
        let bitLengthPrefix = form.currentField == .bitLength ? ">> " : "   "
        components.append(VStack(spacing: 0, children: [
            Text("\(bitLengthPrefix)Bit Length:").styled(bitLengthHighlight),
            Text("    \(form.bitLength) bits (Press SPACE to select)").styled(.info)
        ]).padding(fieldPadding))

        // Mode
        let modeHighlight: TextStyle = form.currentField == .mode ? .accent : .secondary
        let modePrefix = form.currentField == .mode ? ">> " : "   "
        components.append(VStack(spacing: 0, children: [
            Text("\(modePrefix)Mode:").styled(modeHighlight),
            Text("    \(form.mode.title) (Press SPACE to select)").styled(.info)
        ]).padding(fieldPadding))

        // Expiration Date field
        let expirationHighlight: TextStyle = form.currentField == .expirationDate ? .accent : .secondary
        let expirationPrefix = form.currentField == .expirationDate ? ">> " : "   "
        let expirationValue = form.hasExpiration ? "Set Custom Date" : "No Expiration"
        components.append(VStack(spacing: 0, children: [
            Text("\(expirationPrefix)Expiration Date (Optional):").styled(expirationHighlight),
            Text("    \(expirationValue) (Press SPACE to select)").styled(.info)
        ]).padding(fieldPadding))

        // Show date selection fields when custom date is enabled
        if form.hasExpiration {
            components.append(Text(""))
            components.append(Text("   Date Components:").styled(.muted))

            // Month
            components.append(VStack(spacing: 0, children: [
                Text("     Month: \(form.expirationMonth)").styled(.info),
                Text("     Day: \(form.expirationDay)").styled(.info),
                Text("     Year: \(form.expirationYear)").styled(.info),
                Text("     Hour: \(form.expirationHour)").styled(.info),
                Text("     Minute: \(form.expirationMinute)").styled(.info)
            ]).padding(fieldPadding))
        }

        // Validation errors
        if !validationErrors.isEmpty {
            components.append(Text(""))
            components.append(Text("Validation Errors:").error().bold())
            for error in validationErrors {
                components.append(Text("  - \(error)").error())
            }
        }

        // Instructions
        components.append(Text(""))
        components.append(Text("Instructions:").primary().bold())
        components.append(Text("  TAB/UP/DOWN: Navigate fields").muted())
        components.append(Text("  SPACE: Edit text fields / Select from options").muted())
        components.append(Text("  ENTER: Create secret").muted())
        components.append(Text("  ESC: Cancel").muted())

        // Render the form
        let formComponent = VStack(spacing: 1, children: components)
            .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2))

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formComponent, on: surface, in: bounds)
    }

    @MainActor
    private static func drawPayloadEditor(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: BarbicanSecretCreateForm
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text(">> Edit Secret Payload").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Instructions
        components.append(Text("Type or paste your secret payload below:").secondary())
        components.append(Text(""))

        // Payload editor area (showing content with cursor)
        let editorHeight = Int(height) - 8 // Reserve space for title and instructions

        // Show optimized view during input operations for better performance
        if form.isPasteMode {
            let totalLength = form.payload.count + form.payloadBuffer.count
            components.append(Text(""))
            components.append(Text("  LARGE CONTENT PASTE DETECTED").accent().bold())
            components.append(Text(""))
            components.append(Text("  Optimizing rendering for maximum performance...").info())
            components.append(Text(""))
            components.append(Text("  Total characters: \(totalLength)").info())
            components.append(Text("  Buffered: \(form.payloadBuffer.count) characters").muted())
            components.append(Text(""))

            // Enhanced detection for common key sizes
            if totalLength > 3800 && totalLength < 4200 {
                components.append(Text("  4096-bit RSA private key detected!").success().bold())
                components.append(Text("  Using specialized large key optimizations").success())
            } else if totalLength > 2000 {
                components.append(Text("  Large content detected - optimizing...").accent())
            } else {
                components.append(Text("  Medium content - buffering for performance").info())
            }
            components.append(Text(""))
            components.append(Text("  Content will appear when paste completes").muted())

            // Performance indicator
            components.append(Text(""))
            components.append(Text("  Performance: OPTIMIZED").success())

            // Fill remaining space
            for _ in 13..<editorHeight {
                components.append(Text("  ").secondary())
            }
        } else if form.isBuffering && !form.payloadBuffer.isEmpty {
            let totalLength = form.payload.count + form.payloadBuffer.count
            components.append(Text(""))
            components.append(Text("  HIGH-SPEED INPUT DETECTED").info().bold())
            components.append(Text(""))
            components.append(Text("  Buffering for optimal performance...").info())
            components.append(Text("  Total: \(totalLength) chars | Buffer: \(form.payloadBuffer.count) chars").muted())
            components.append(Text(""))
            components.append(Text("  Content preview will appear when you pause").muted())

            // Fill remaining space
            for _ in 7..<editorHeight {
                components.append(Text("  ").secondary())
            }
        } else if form.shouldUseOptimizedRendering() {
            // Optimized rendering for large content
            let completePayload = form.getCompletePayload()
            let totalLines = completePayload.split(separator: "\n").count
            components.append(Text(""))
            components.append(Text("  LARGE CONTENT MODE (\(completePayload.count) chars)").accent().bold())
            components.append(Text(""))
            components.append(Text("  Lines: \(totalLines)").info())
            components.append(Text("  Preview: \(String(completePayload.prefix(60)))...").primary())
            components.append(Text(""))
            components.append(Text("  [Content is too large to display in real-time]").muted())
            components.append(Text("  [Press ESC to save and exit editor]").muted())

            // Fill remaining space
            for _ in 8..<editorHeight {
                components.append(Text("  ").secondary())
            }
        } else {
            // Standard rendering for normal-sized content
            let completePayload = form.getCompletePayload()
            let payloadLines = completePayload.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

            for i in 0..<editorHeight {
                if i < payloadLines.count {
                    let line = payloadLines[i]
                    // Truncate very long lines for performance
                    let displayLine = line.count > 120 ? "\(String(line.prefix(117)))..." : line
                    components.append(Text("  \(displayLine)").primary())
                } else if i == payloadLines.count {
                    // Show cursor on the next line
                    components.append(Text("  _").accent())
                } else {
                    components.append(Text("  ").secondary())
                }
            }
        }

        // Footer instructions
        components.append(Text(""))
        components.append(Text("ESC: Save and return to form").muted())

        // Render the editor
        let editorComponent = VStack(spacing: 0, children: components)
            .padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(editorComponent, on: surface, in: bounds)
    }

    @MainActor
    private static func drawSelectionWindow(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: BarbicanSecretCreateForm
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        let fieldTitle = form.currentField.title
        components.append(Text("Select \(fieldTitle)").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Instructions
        components.append(Text("Use UP/DOWN to navigate, SPACE to select, ENTER to confirm, ESC to cancel").secondary())
        components.append(Text(""))

        // Selection options with checkbox syntax
        let options = form.getSelectionOptions()
        let currentValue = form.getCurrentSelectionValue()

        for (index, option) in options.enumerated() {
            let isNavigated = index == form.selectionIndex
            let isCurrent = option == currentValue
            let isConfirmed = form.selectionConfirmed == index

            // Show different states
            let checkbox: String
            if isConfirmed {
                checkbox = "[X]" // Selected for confirmation
            } else if isCurrent {
                checkbox = "[*]" // Current value but not selected
            } else {
                checkbox = "[ ]" // Not selected
            }

            let prefix = isNavigated ? ">> " : "   "
            let style: TextStyle = isNavigated ? .accent :
                                  (isConfirmed ? .success :
                                  (isCurrent ? .info : .secondary))

            components.append(Text("\(prefix)\(checkbox) \(option)").styled(style))
        }

        // Footer
        components.append(Text(""))
        components.append(Text("Current value: \(currentValue)").info())
        if let confirmedIndex = form.selectionConfirmed {
            let confirmedValue = options[confirmedIndex]
            components.append(Text("Selected for confirmation: \(confirmedValue)").success())
        } else {
            components.append(Text("No selection made (press SPACE to select)").muted())
        }

        // Render the selection window
        let selectionComponent = VStack(spacing: 0, children: components)
            .padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(selectionComponent, on: surface, in: bounds)
    }

    @MainActor
    private static func drawDateSelectionWindow(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: BarbicanSecretCreateForm
    ) async {
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text("Set Custom Expiration Date").accent().bold()
                         .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0)))

        // Instructions
        components.append(Text("UP/DOWN: Navigate fields | LEFT/RIGHT or +/-: Adjust values | ENTER: Confirm | ESC: Cancel").secondary())
        components.append(Text(""))

        // Date components
        let dateFields = [
            ("Month (1-12)", form.expirationMonth, 1, 12),
            ("Day (1-31)", form.expirationDay, 1, 31),
            ("Year (2025-9999)", form.expirationYear, 2025, 9999),
            ("Hour (0-23)", form.expirationHour, 0, 23),
            ("Minute (0-59)", form.expirationMinute, 0, 59)
        ]

        for (index, field) in dateFields.enumerated() {
            let (label, value, _, _) = field
            let isSelected = index == form.selectionIndex
            let prefix = isSelected ? ">> " : "   "
            let style: TextStyle = isSelected ? .accent : .secondary
            let valueDisplay = isSelected ? "[\(value)]" : "\(value)" // Highlight selected value

            components.append(Text("\(prefix)\(label): \(valueDisplay)").styled(style))
        }

        // Footer
        components.append(Text(""))
        components.append(Text("Use LEFT/RIGHT arrows or +/- keys to adjust selected value").info())

        let currentDate = form.getExpirationDate()
        if let date = currentDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            components.append(Text("Preview: \(formatter.string(from: date))").success())
        } else {
            components.append(Text("Invalid date combination").error())
        }

        // Render the date selection window
        let dateComponent = VStack(spacing: 0, children: components)
            .padding(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))

        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(dateComponent, on: surface, in: bounds)
    }
}