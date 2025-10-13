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
        filterCache: ResourceNameCache?,
        multiSelectMode: Bool = false,
        selectedItems: Set<String> = []
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
            selectedIndex: selectedIndex,
            multiSelectMode: multiSelectMode,
            selectedItems: selectedItems
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
        secret: Secret,
        scrollOffset: Int = 0
    ) async {
        var sections: [DetailSection] = []

        // Basic Information Section
        let secretId = secret.id.isEmpty ? (secret.secretRef ?? "Unknown") : secret.id
        var basicItems: [DetailItem] = []
        basicItems.append(.field(label: "ID", value: secretId, style: .secondary))
        basicItems.append(.field(label: "Name", value: secret.name ?? "Unnamed Secret", style: .secondary))

        // Status with custom component for styling
        let status = secret.status ?? "Unknown"
        let statusStyle: TextStyle = status.lowercased() == "active" ? .success :
                                   (status.lowercased().contains("error") ? .error : .accent)
        basicItems.append(.customComponent(
            HStack(spacing: 0, children: [
                Text("  Status: ").secondary(),
                Text(status).styled(statusStyle)
            ])
        ))

        if let secretType = secret.secretType {
            basicItems.append(.field(label: "Type", value: secretType, style: .secondary))
        }

        if let creatorId = secret.creatorId {
            basicItems.append(.field(label: "Creator ID", value: creatorId, style: .secondary))
        }

        sections.append(DetailSection(title: "Basic Information", items: basicItems))

        // Cryptographic Information Section - Enhanced!
        var cryptoItems: [DetailItem?] = []

        if let algorithm = secret.algorithm {
            cryptoItems.append(.field(label: "Algorithm", value: algorithm, style: .secondary))

            // Add algorithm description for common types
            let algorithmDesc = getAlgorithmDescription(algorithm)
            if !algorithmDesc.isEmpty {
                cryptoItems.append(.field(label: "  Description", value: algorithmDesc, style: .info))
            }
        }

        if let bitLength = secret.bitLength {
            cryptoItems.append(.field(label: "Key Length", value: "\(bitLength) bits", style: .secondary))

            // Add security strength indicator
            let strengthIndicator = getKeyStrengthIndicator(bitLength)
            if !strengthIndicator.isEmpty {
                cryptoItems.append(.field(label: "  Strength", value: strengthIndicator, style: strengthIndicator.contains("Strong") ? .success : .warning))
            }
        }

        if let mode = secret.mode {
            cryptoItems.append(.field(label: "Mode", value: mode, style: .secondary))

            // Add mode description
            let modeDesc = getModeDescription(mode)
            if !modeDesc.isEmpty {
                cryptoItems.append(.field(label: "  Description", value: modeDesc, style: .info))
            }
        }

        if let cryptoSection = DetailView.buildSection(title: "Cryptographic Information", items: cryptoItems, titleStyle: .accent) {
            sections.append(cryptoSection)
        }

        // Content Types Section
        if let contentTypes = secret.contentTypes, !contentTypes.isEmpty {
            var contentItems: [DetailItem] = []
            for (key, value) in contentTypes.sorted(by: { $0.key < $1.key }) {
                contentItems.append(.field(label: key, value: value, style: .secondary))
            }
            sections.append(DetailSection(title: "Content Types", items: contentItems))
        }

        // Expiration Information Section - Enhanced!
        if let expiration = secret.expiration {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let now = Date()
            let isExpired = expiration < now
            let timeInterval = expiration.timeIntervalSince(now)

            var expirationItems: [DetailItem] = []

            if isExpired {
                expirationItems.append(.field(label: "Status", value: "EXPIRED", style: .error))
                expirationItems.append(.field(label: "Expired At", value: formatter.string(from: expiration), style: .error))

                // Calculate how long ago it expired
                let daysExpired = Int(-timeInterval / 86400)
                if daysExpired > 0 {
                    expirationItems.append(.field(label: "Expired", value: "\(daysExpired) day(s) ago", style: .error))
                }
            } else {
                expirationItems.append(.field(label: "Status", value: "Active", style: .success))
                expirationItems.append(.field(label: "Expires At", value: formatter.string(from: expiration), style: .secondary))

                // Calculate time until expiration
                let daysUntilExpiration = Int(timeInterval / 86400)
                if daysUntilExpiration <= 7 {
                    expirationItems.append(.field(label: "Warning", value: "Expires in \(daysUntilExpiration) day(s)!", style: .warning))
                } else if daysUntilExpiration <= 30 {
                    expirationItems.append(.field(label: "Notice", value: "Expires in \(daysUntilExpiration) day(s)", style: .info))
                } else {
                    expirationItems.append(.field(label: "Time Remaining", value: "\(daysUntilExpiration) day(s)", style: .secondary))
                }
            }

            let titleStyle: TextStyle = isExpired ? .error : (timeInterval <= 604800 ? .warning : .primary) // 7 days = 604800 seconds
            sections.append(DetailSection(title: "Expiration Information", items: expirationItems, titleStyle: titleStyle))
        } else {
            // No expiration set
            let noExpirationSection = DetailSection(
                title: "Expiration Information",
                items: [.field(label: "Status", value: "No expiration set (secret never expires)", style: .success)]
            )
            sections.append(noExpirationSection)
        }

        // Timestamps Section
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var timestampItems: [DetailItem?] = []
        if let created = secret.created {
            timestampItems.append(.field(label: "Created", value: formatter.string(from: created), style: .secondary))
        }
        if let updated = secret.updated {
            timestampItems.append(.field(label: "Updated", value: formatter.string(from: updated), style: .secondary))
        }

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // API Reference Section
        if let secretRef = secret.secretRef {
            let refSection = DetailSection(
                title: "API Reference",
                items: [.field(label: "Secret Ref", value: secretRef, style: .secondary)]
            )
            sections.append(refSection)
        }

        // Security Best Practices Section - NEW!
        var securityItems: [DetailItem] = []
        securityItems.append(.field(label: "Recommendation", value: "Secrets should be rotated regularly", style: .info))

        if secret.expiration == nil {
            securityItems.append(.field(label: "Warning", value: "Consider setting an expiration date", style: .warning))
        }

        if let bitLength = secret.bitLength, bitLength < 2048 {
            securityItems.append(.field(label: "Warning", value: "Key length below recommended 2048 bits", style: .warning))
        }

        sections.append(DetailSection(title: "Security Best Practices", items: securityItems, titleStyle: .accent))

        // Create and render DetailView
        let detailView = DetailView(
            title: "Secret Details: \(secret.name ?? "Unnamed Secret")",
            sections: sections,
            helpText: "Press ESC to return to secrets list",
            scrollOffset: scrollOffset
        )

        await detailView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height
        )
    }

    // MARK: - Helper Functions for Enhanced Information

    private static func getAlgorithmDescription(_ algorithm: String) -> String {
        switch algorithm.uppercased() {
        case "AES": return "Advanced Encryption Standard - Symmetric block cipher"
        case "RSA": return "Rivest-Shamir-Adleman - Asymmetric encryption"
        case "DES": return "Data Encryption Standard - Legacy symmetric cipher"
        case "3DES": return "Triple DES - Enhanced DES with triple encryption"
        case "HMAC": return "Hash-based Message Authentication Code"
        case "DSA": return "Digital Signature Algorithm"
        case "EC": return "Elliptic Curve - Modern asymmetric cryptography"
        default: return ""
        }
    }

    private static func getKeyStrengthIndicator(_ bitLength: Int) -> String {
        switch bitLength {
        case ..<128: return "Weak (below modern standards)"
        case 128..<256: return "Moderate (128-bit security)"
        case 256..<512: return "Strong (256-bit security)"
        case 512..<1024: return "Strong (512-bit key)"
        case 1024..<2048: return "Moderate (consider 2048+ for RSA)"
        case 2048..<4096: return "Strong (2048-bit RSA standard)"
        case 4096...: return "Very Strong (4096+ bit key)"
        default: return ""
        }
    }

    private static func getModeDescription(_ mode: String) -> String {
        switch mode.uppercased() {
        case "CBC": return "Cipher Block Chaining - Standard block cipher mode"
        case "ECB": return "Electronic Codebook - Not recommended (no IV)"
        case "CTR": return "Counter - Converts block cipher to stream cipher"
        case "GCM": return "Galois/Counter Mode - Provides authentication"
        case "CFB": return "Cipher Feedback - Stream cipher mode"
        case "OFB": return "Output Feedback - Stream cipher mode"
        default: return ""
        }
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
        formState: FormBuilderState
    ) async {
        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 20 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Handle special payload editing mode (full-screen editor)
        if form.payloadEditMode {
            await drawPayloadEditor(screen: screen, startRow: startRow, startCol: startCol,
                                  width: width, height: height, form: form)
            return
        }

        // Handle legacy date selection mode
        if form.dateSelectionMode {
            await drawDateSelectionWindow(screen: screen, startRow: startRow, startCol: startCol,
                                        width: width, height: height, form: form)
            return
        }

        // Handle legacy selection mode
        if form.selectionMode {
            await drawSelectionWindow(screen: screen, startRow: startRow, startCol: startCol,
                                    width: width, height: height, form: form)
            return
        }

        let surface = SwiftTUI.surface(from: screen)

        // Build form fields
        let fields = form.buildFields(
            selectedFieldId: formState.getCurrentFieldId(),
            activeFieldId: formState.getActiveFieldId(),
            formState: formState
        )

        // Create FormBuilder
        let formBuilder = FormBuilder(
            title: "Create New Secret",
            fields: fields,
            selectedFieldId: formState.getCurrentFieldId(),
            validationErrors: form.validate(),
            showValidationErrors: formState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)

        // If a selector field is active, render overlay using FormSelectorRenderer
        if let currentField = formState.getCurrentField() {
            switch currentField {
            case .selector(let selectorField) where selectorField.isActive:
                await renderSelectorOverlay(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    field: selectorField,
                    selectorState: formState.selectorStates[selectorField.id] ?? FormSelectorFieldState(items: selectorField.items)
                )
            default:
                break
            }
        }
    }

    // MARK: - Overlay Rendering

    @MainActor
    private static func renderSelectorOverlay(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        field: FormFieldSelector,
        selectorState: FormSelectorFieldState
    ) async {
        let surface = SwiftTUI.surface(from: screen)

        // Use FormSelectorRenderer for standard selector rendering
        if let selectorComponent = FormSelectorRenderer.renderSelector(
            label: field.label,
            items: field.items,
            selectedItemId: field.selectedItemId,
            highlightedIndex: selectorState.highlightedIndex,
            scrollOffset: selectorState.scrollOffset,
            searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
            columns: field.columns,
            maxHeight: Int(height)
        ) {
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
            surface.clear(rect: bounds)
            await SwiftTUI.render(selectorComponent, on: surface, in: bounds)
        }
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