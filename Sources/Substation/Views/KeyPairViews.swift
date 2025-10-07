import Foundation
import OSClient
import SwiftTUI

struct KeyPairViews {
    @MainActor
    static func drawDetailedKeyPairList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                      width: Int32, height: Int32, cachedKeyPairs: [KeyPair],
                                      searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

        let statusListView = createKeyPairStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedKeyPairs,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex
        )
    }

    // MARK: - Detail View

    @MainActor
    static func drawKeyPairDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                width: Int32, height: Int32, keyPair: KeyPair, scrollOffset: Int = 0) async {

        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "Name", value: keyPair.name, defaultValue: "Unnamed"),
            DetailView.buildFieldItem(label: "User ID", value: keyPair.userID)
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Key Type Analysis Section - Enhanced!
        if let type = keyPair.type {
            var typeItems: [DetailItem] = []
            typeItems.append(.field(label: "Algorithm", value: type, style: .secondary))

            // Add algorithm description
            let typeDesc = getKeyTypeDescription(type)
            if !typeDesc.isEmpty {
                typeItems.append(.field(label: "  Description", value: typeDesc, style: .info))
            }

            // Add security assessment
            let securityAssessment = getKeyTypeSecurityAssessment(type)
            if !securityAssessment.isEmpty {
                let style: TextStyle = securityAssessment.contains("Strong") ? .success :
                                       (securityAssessment.contains("Legacy") || securityAssessment.contains("Deprecated") ? .warning : .secondary)
                typeItems.append(.field(label: "  Security", value: securityAssessment, style: style))
            }

            sections.append(DetailSection(title: "Key Algorithm", items: typeItems, titleStyle: .accent))
        }

        // Fingerprint Analysis Section - Enhanced!
        if let fingerprint = keyPair.fingerprint {
            var fingerprintItems: [DetailItem] = []
            fingerprintItems.append(.field(label: "Fingerprint", value: fingerprint, style: .secondary))

            // Detect fingerprint format
            let fingerprintFormat = detectFingerprintFormat(fingerprint)
            if !fingerprintFormat.isEmpty {
                fingerprintItems.append(.field(label: "  Format", value: fingerprintFormat, style: .info))
            }

            // Calculate fingerprint length for security analysis
            let fingerprintLength = fingerprint.count
            if fingerprintLength > 0 {
                fingerprintItems.append(.field(label: "  Length", value: "\(fingerprintLength) characters", style: .secondary))
            }

            sections.append(DetailSection(title: "Fingerprint Information", items: fingerprintItems))
        }

        // Public Key Section with analysis
        if let publicKey = keyPair.publicKey {
            var keyItems: [DetailItem] = []

            // Analyze public key
            let keyAnalysis = analyzePublicKey(publicKey)

            if !keyAnalysis.keyType.isEmpty {
                keyItems.append(.field(label: "Detected Type", value: keyAnalysis.keyType, style: .info))
            }

            if keyAnalysis.keySize > 0 {
                keyItems.append(.field(label: "Key Size", value: "\(keyAnalysis.keySize) bits (estimated)", style: .secondary))

                // Add key size security assessment
                let sizeAssessment = getKeySizeAssessment(keyAnalysis.keyType, size: keyAnalysis.keySize)
                if !sizeAssessment.isEmpty {
                    let style: TextStyle = sizeAssessment.contains("Strong") ? .success :
                                           (sizeAssessment.contains("Weak") ? .error : .warning)
                    keyItems.append(.field(label: "  Strength", value: sizeAssessment, style: style))
                }
            }

            keyItems.append(.field(label: "Length", value: "\(publicKey.count) characters", style: .secondary))

            if !keyAnalysis.comment.isEmpty {
                keyItems.append(.field(label: "Comment", value: keyAnalysis.comment, style: .info))
            }

            keyItems.append(.spacer)

            // Public key content (first few lines)
            keyItems.append(.field(label: "Key Content", value: "First 100 characters", style: .muted))
            let preview = String(publicKey.prefix(100))
            keyItems.append(.field(label: "", value: preview + "...", style: .secondary))

            sections.append(DetailSection(title: "Public Key", items: keyItems))
        }

        // Security Best Practices Section - NEW!
        var securityItems: [DetailItem] = []

        // General recommendations
        securityItems.append(.field(label: "Recommendation", value: "Rotate SSH keys regularly (every 6-12 months)", style: .info))

        // Type-specific warnings
        if let type = keyPair.type {
            if type.uppercased().contains("DSA") {
                securityItems.append(.field(label: "Warning", value: "DSA is deprecated - migrate to Ed25519 or RSA", style: .error))
            } else if type.uppercased().contains("RSA") {
                securityItems.append(.field(label: "Note", value: "Ensure RSA keys are at least 2048 bits", style: .info))
            } else if type.uppercased().contains("ED25519") {
                securityItems.append(.field(label: "Status", value: "Ed25519 is modern and secure", style: .success))
            }
        }

        // Fingerprint-based recommendations
        if keyPair.fingerprint != nil {
            securityItems.append(.field(label: "Best Practice", value: "Verify fingerprint when adding to servers", style: .info))
        }

        sections.append(DetailSection(title: "Security Best Practices", items: securityItems, titleStyle: .accent))

        // Usage Information Section - NEW!
        var usageItems: [DetailItem] = []
        usageItems.append(.field(label: "SSH Connection", value: "ssh -i /path/to/private_key user@host", style: .info))
        usageItems.append(.field(label: "Add to Agent", value: "ssh-add /path/to/private_key", style: .info))

        if let name = keyPair.name {
            usageItems.append(.field(label: "Key Name", value: name, style: .secondary))
        }

        sections.append(DetailSection(title: "Usage Information", items: usageItems))

        // Create and render DetailView
        let detailView = DetailView(
            title: "SSH Key Pair Details: \(keyPair.name ?? "Unnamed")",
            sections: sections,
            helpText: "Press ESC to return to key pair list",
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

    // MARK: - Helper Functions for Enhanced SSH Key Analysis

    private static func getKeyTypeDescription(_ type: String) -> String {
        switch type.uppercased() {
        case "SSH-RSA", "RSA":
            return "RSA - Widely supported, secure with adequate key size"
        case "SSH-DSS", "DSA":
            return "DSA - Deprecated, limited to 1024 bits"
        case "ECDSA-SHA2-NISTP256", "ECDSA-SHA2-NISTP384", "ECDSA-SHA2-NISTP521", "ECDSA":
            return "ECDSA - Elliptic Curve, compact and efficient"
        case "SSH-ED25519", "ED25519":
            return "Ed25519 - Modern, fast, and highly secure"
        default:
            return ""
        }
    }

    private static func getKeyTypeSecurityAssessment(_ type: String) -> String {
        switch type.uppercased() {
        case "SSH-RSA", "RSA":
            return "Strong (with 2048+ bit keys)"
        case "SSH-DSS", "DSA":
            return "Legacy - Deprecated, migrate to Ed25519"
        case "ECDSA-SHA2-NISTP256", "ECDSA-SHA2-NISTP384", "ECDSA-SHA2-NISTP521", "ECDSA":
            return "Strong - Modern elliptic curve"
        case "SSH-ED25519", "ED25519":
            return "Very Strong - Recommended for new keys"
        default:
            return "Unknown algorithm"
        }
    }

    private static func detectFingerprintFormat(_ fingerprint: String) -> String {
        if fingerprint.contains(":") {
            let colonCount = fingerprint.filter { $0 == ":" }.count
            if colonCount == 15 {
                return "MD5 (hexadecimal with colons)"
            } else if colonCount > 15 {
                return "SHA256 (hexadecimal with colons)"
            }
            return "Hexadecimal with colons"
        } else if fingerprint.hasPrefix("SHA256:") {
            return "SHA256 (Base64)"
        } else if fingerprint.hasPrefix("MD5:") {
            return "MD5 (Base64)"
        } else if fingerprint.count == 43 || fingerprint.count == 44 {
            return "SHA256 (Base64, likely)"
        } else if fingerprint.count == 32 {
            return "MD5 (hexadecimal)"
        }
        return "Unknown format"
    }

    private struct PublicKeyAnalysis {
        var keyType: String = ""
        var keySize: Int = 0
        var comment: String = ""
    }

    private static func analyzePublicKey(_ publicKey: String) -> PublicKeyAnalysis {
        var analysis = PublicKeyAnalysis()

        let parts = publicKey.split(separator: " ").map(String.init)

        if parts.count >= 1 {
            // First part is usually the key type
            let keyType = parts[0]
            if keyType.hasPrefix("ssh-") || keyType.hasPrefix("ecdsa-") {
                analysis.keyType = keyType
            }
        }

        if parts.count >= 2 {
            // Second part is the base64 encoded key - estimate size
            let keyData = parts[1]
            // Very rough estimation based on base64 length
            if analysis.keyType.uppercased().contains("RSA") {
                // RSA key size estimation
                switch keyData.count {
                case ..<400: analysis.keySize = 1024
                case 400..<600: analysis.keySize = 2048
                case 600..<800: analysis.keySize = 3072
                case 800...: analysis.keySize = 4096
                default: break
                }
            } else if analysis.keyType.uppercased().contains("ED25519") {
                analysis.keySize = 256 // Ed25519 is always 256 bits
            } else if analysis.keyType.uppercased().contains("ECDSA") {
                if analysis.keyType.contains("256") {
                    analysis.keySize = 256
                } else if analysis.keyType.contains("384") {
                    analysis.keySize = 384
                } else if analysis.keyType.contains("521") {
                    analysis.keySize = 521
                }
            }
        }

        if parts.count >= 3 {
            // Third part onwards is usually a comment (email, hostname, etc.)
            analysis.comment = parts[2...].joined(separator: " ")
        }

        return analysis
    }

    private static func getKeySizeAssessment(_ keyType: String, size: Int) -> String {
        if keyType.uppercased().contains("RSA") {
            switch size {
            case ..<2048: return "Weak - Below 2048 bits"
            case 2048: return "Adequate - 2048 bits (minimum recommended)"
            case 3072: return "Strong - 3072 bits"
            case 4096...: return "Very Strong - 4096+ bits"
            default: return ""
            }
        } else if keyType.uppercased().contains("ED25519") {
            return "Strong - 256 bits (EdDSA standard)"
        } else if keyType.uppercased().contains("ECDSA") {
            switch size {
            case ..<256: return "Adequate"
            case 256: return "Strong - 256 bits"
            case 384: return "Very Strong - 384 bits"
            case 521...: return "Very Strong - 521 bits"
            default: return ""
            }
        }
        return ""
    }

    // MARK: - Key Pair List View Constants
    // Layout Constants
    private static let keyPairListMinScreenWidth: Int32 = 10
    private static let keyPairListMinScreenHeight: Int32 = 10
    private static let keyPairListHeaderTopPadding: Int32 = 2
    private static let keyPairListHeaderLeadingPadding: Int32 = 0
    private static let keyPairListHeaderBottomPadding: Int32 = 0
    private static let keyPairListHeaderTrailingPadding: Int32 = 0
    private static let keyPairListNoKeyPairsTopPadding: Int32 = 2
    private static let keyPairListNoKeyPairsLeadingPadding: Int32 = 2
    private static let keyPairListNoKeyPairsBottomPadding: Int32 = 0
    private static let keyPairListNoKeyPairsTrailingPadding: Int32 = 0
    private static let keyPairListScrollInfoTopPadding: Int32 = 1
    private static let keyPairListScrollInfoLeadingPadding: Int32 = 0
    private static let keyPairListScrollInfoBottomPadding: Int32 = 0
    private static let keyPairListScrollInfoTrailingPadding: Int32 = 0
    private static let keyPairListReservedSpaceForHeaderFooter = 10
    private static let keyPairListComponentSpacing: Int32 = 0
    private static let keyPairListItemLeadingPadding: Int32 = 2
    private static let keyPairListItemTopPadding: Int32 = 0
    private static let keyPairListItemBottomPadding: Int32 = 0
    private static let keyPairListItemTrailingPadding: Int32 = 0
    private static let keyPairListMinVisibleItems = 1
    private static let keyPairListBoundsMinWidth: Int32 = 1
    private static let keyPairListBoundsMinHeight: Int32 = 1

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let keyPairListHeaderEdgeInsets = EdgeInsets(top: keyPairListHeaderTopPadding, leading: keyPairListHeaderLeadingPadding, bottom: keyPairListHeaderBottomPadding, trailing: keyPairListHeaderTrailingPadding)
    private static let keyPairListNoKeyPairsEdgeInsets = EdgeInsets(top: keyPairListNoKeyPairsTopPadding, leading: keyPairListNoKeyPairsLeadingPadding, bottom: keyPairListNoKeyPairsBottomPadding, trailing: keyPairListNoKeyPairsTrailingPadding)
    private static let keyPairListScrollInfoEdgeInsets = EdgeInsets(top: keyPairListScrollInfoTopPadding, leading: keyPairListScrollInfoLeadingPadding, bottom: keyPairListScrollInfoBottomPadding, trailing: keyPairListScrollInfoTrailingPadding)
    private static let keyPairListItemEdgeInsets = EdgeInsets(top: keyPairListItemTopPadding, leading: keyPairListItemLeadingPadding, bottom: keyPairListItemBottomPadding, trailing: keyPairListItemTrailingPadding)

    // Text Constants
    private static let keyPairListTitle = "Key Pairs"
    private static let keyPairListFilteredTitlePrefix = "Key Pairs (filtered: "
    private static let keyPairListFilteredTitleSuffix = ")"
    private static let keyPairListHeader = "  ST  NAME                         FINGERPRINT"
    private static let keyPairListSeparator = String(repeating: "-", count: Self.keyPairListSeparatorLength)
    private static let keyPairListNoKeyPairsText = "No key pairs found"
    private static let keyPairListScrollInfoPrefix = "["
    private static let keyPairListScrollInfoSeparator = "-"
    private static let keyPairListScrollInfoMiddle = "/"
    private static let keyPairListScrollInfoSuffix = "]"
    private static let keyPairListUnknownFingerprintText = "Unknown"
    private static let keyPairListStatusIconActive = "active"
    private static let keyPairListScreenTooSmallText = "Screen too small"
    private static let keyPairListNamePadLength = 28
    private static let keyPairListFingerprintMaxLength = 20
    private static let keyPairListPadCharacter = " "
    private static let keyPairListSeparatorLength = 60
    private static let keyPairListItemTextSpacing = " "

    // MARK: - Key Pair Detail View Constants
    // Detail View Text Constants
    private static let keyPairDetailTitle = "Key Pair Details"
    private static let keyPairDetailTitlePrefix = "* "
    private static let keyPairDetailFieldValueSeparator = ": "
    private static let keyPairDetailBasicInfoTitle = "Basic Information"
    private static let keyPairDetailPublicKeyTitle = "Public Key"
    private static let keyPairDetailNameLabel = "Name"
    private static let keyPairDetailFingerprintLabel = "Fingerprint"
    private static let keyPairDetailTypeLabel = "Type"
    private static let keyPairDetailTruncatedText = "... (truncated)"
    private static let keyPairDetailHelpText = "Press ESC to return to key pair list"
    private static let keyPairDetailUnnamedKeyPairText = "Unnamed"
    private static let keyPairDetailInfoFieldIndent = "  "

    // Detail View Layout Constants
    private static let keyPairDetailMinScreenWidth: Int32 = 10
    private static let keyPairDetailMinScreenHeight: Int32 = 10
    private static let keyPairDetailBoundsMinWidth: Int32 = 1
    private static let keyPairDetailBoundsMinHeight: Int32 = 1
    private static let keyPairDetailTitleTopPadding: Int32 = 0
    private static let keyPairDetailTitleLeadingPadding: Int32 = 0
    private static let keyPairDetailTitleBottomPadding: Int32 = 2
    private static let keyPairDetailTitleTrailingPadding: Int32 = 0
    private static let keyPairDetailSectionTopPadding: Int32 = 0
    private static let keyPairDetailSectionLeadingPadding: Int32 = 4
    private static let keyPairDetailSectionBottomPadding: Int32 = 1
    private static let keyPairDetailSectionTrailingPadding: Int32 = 0
    private static let keyPairDetailHelpTopPadding: Int32 = 1
    private static let keyPairDetailHelpLeadingPadding: Int32 = 0
    private static let keyPairDetailHelpBottomPadding: Int32 = 0
    private static let keyPairDetailHelpTrailingPadding: Int32 = 0
    private static let keyPairDetailComponentSpacing: Int32 = 0
    private static let keyPairDetailKeyWidth = 6
    private static let keyPairDetailFooterReservedHeight = 8

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let keyPairDetailTitleEdgeInsets = EdgeInsets(top: keyPairDetailTitleTopPadding, leading: keyPairDetailTitleLeadingPadding, bottom: keyPairDetailTitleBottomPadding, trailing: keyPairDetailTitleTrailingPadding)
    private static let keyPairDetailSectionEdgeInsets = EdgeInsets(top: keyPairDetailSectionTopPadding, leading: keyPairDetailSectionLeadingPadding, bottom: keyPairDetailSectionBottomPadding, trailing: keyPairDetailSectionTrailingPadding)
    private static let keyPairDetailHelpEdgeInsets = EdgeInsets(top: keyPairDetailHelpTopPadding, leading: keyPairDetailHelpLeadingPadding, bottom: keyPairDetailHelpBottomPadding, trailing: keyPairDetailHelpTrailingPadding)

    // MARK: - Key Pair Create View

    @MainActor
    static func drawKeyPairCreate(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                 width: Int32, height: Int32, keyPairCreateForm: KeyPairCreateForm,
                                 keyPairCreateFormState: FormBuilderState) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.keyPairCreateMinScreenWidth && height > Self.keyPairCreateMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.keyPairCreateBoundsMinWidth, width), height: max(Self.keyPairCreateBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.keyPairCreateScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Build the form using FormBuilder
        let formBuilder = FormBuilder(
            title: Self.keyPairCreateFormTitle,
            fields: keyPairCreateForm.buildFields(
                selectedFieldId: keyPairCreateFormState.getCurrentFieldId(),
                activeFieldId: keyPairCreateFormState.getActiveFieldId(),
                formState: keyPairCreateFormState
            ),
            selectedFieldId: keyPairCreateFormState.getCurrentFieldId(),
            validationErrors: keyPairCreateFormState.validationErrors,
            showValidationErrors: keyPairCreateFormState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)

        // If a selector field is active, render overlay
        if let currentField = keyPairCreateFormState.getCurrentField() {
            switch currentField {
            case .selector(let selectorField) where selectorField.isActive:
                if let selectorComponent = FormSelectorRenderer.renderSelector(
                    label: selectorField.label,
                    items: selectorField.items,
                    selectedItemId: selectorField.selectedItemId,
                    highlightedIndex: selectorField.highlightedIndex,
                    scrollOffset: selectorField.scrollOffset,
                    searchQuery: (selectorField.searchQuery ?? "").isEmpty ? nil : selectorField.searchQuery,
                    columns: selectorField.columns,
                    maxHeight: Int(height)
                ) {
                    surface.clear(rect: bounds)
                    await SwiftTUI.render(selectorComponent, on: surface, in: bounds)
                }
            default:
                break
            }
        }
    }

    @MainActor

    // MARK: - Key Pair Create View Constants
    // Layout Constants
    private static let keyPairCreateMinScreenWidth: Int32 = 10
    private static let keyPairCreateMinScreenHeight: Int32 = 10
    private static let keyPairCreateBoundsMinWidth: Int32 = 1
    private static let keyPairCreateBoundsMinHeight: Int32 = 1
    private static let keyPairCreateComponentTopPadding: Int32 = 1
    private static let keyPairCreateTitleTopPadding: Int32 = 0
    private static let keyPairCreateTitleLeadingPadding: Int32 = 2
    private static let keyPairCreateTitleBottomPadding: Int32 = 2
    private static let keyPairCreateTitleTrailingPadding: Int32 = 0
    private static let keyPairCreateValidationErrorTopPadding: Int32 = 1
    private static let keyPairCreateValidationErrorLeadingPadding: Int32 = 2
    private static let keyPairCreateValidationErrorBottomPadding: Int32 = 0
    private static let keyPairCreateValidationErrorTrailingPadding: Int32 = 0
    private static let keyPairCreateValidationErrorItemTopPadding: Int32 = 0
    private static let keyPairCreateValidationErrorItemLeadingPadding: Int32 = 2
    private static let keyPairCreateValidationErrorItemBottomPadding: Int32 = 0
    private static let keyPairCreateValidationErrorItemTrailingPadding: Int32 = 0
    private static let keyPairCreateFieldLabelTopPadding: Int32 = 1
    private static let keyPairCreateFieldLabelLeadingPadding: Int32 = 0
    private static let keyPairCreateFieldLabelBottomPadding: Int32 = 0
    private static let keyPairCreateFieldLabelTrailingPadding: Int32 = 0
    private static let keyPairCreateFieldComponentTopPadding: Int32 = 0
    private static let keyPairCreateFieldComponentLeadingPadding: Int32 = 4
    private static let keyPairCreateFieldComponentBottomPadding: Int32 = 1
    private static let keyPairCreateFieldComponentTrailingPadding: Int32 = 0
    private static let keyPairCreateDescriptionTopPadding: Int32 = 0
    private static let keyPairCreateDescriptionLeadingPadding: Int32 = 2
    private static let keyPairCreateDescriptionBottomPadding: Int32 = 0
    private static let keyPairCreateDescriptionTrailingPadding: Int32 = 0
    private static let keyPairCreateComponentSpacing: Int32 = 0
    private static let keyPairCreateMinPublicKeyWidth = 40
    private static let keyPairCreatePublicKeyWidthBuffer = 8

    // Pre-calculated EdgeInsets for nano-level performance optimization
    private static let keyPairCreateTitleEdgeInsets = EdgeInsets(top: keyPairCreateTitleTopPadding, leading: keyPairCreateTitleLeadingPadding, bottom: keyPairCreateTitleBottomPadding, trailing: keyPairCreateTitleTrailingPadding)
    private static let keyPairCreateValidationErrorEdgeInsets = EdgeInsets(top: keyPairCreateValidationErrorTopPadding, leading: keyPairCreateValidationErrorLeadingPadding, bottom: keyPairCreateValidationErrorBottomPadding, trailing: keyPairCreateValidationErrorTrailingPadding)
    private static let keyPairCreateValidationErrorItemEdgeInsets = EdgeInsets(top: keyPairCreateValidationErrorItemTopPadding, leading: keyPairCreateValidationErrorItemLeadingPadding, bottom: keyPairCreateValidationErrorItemBottomPadding, trailing: keyPairCreateValidationErrorItemTrailingPadding)
    private static let keyPairCreateFieldLabelEdgeInsets = EdgeInsets(top: keyPairCreateFieldLabelTopPadding, leading: keyPairCreateFieldLabelLeadingPadding, bottom: keyPairCreateFieldLabelBottomPadding, trailing: keyPairCreateFieldLabelTrailingPadding)
    private static let keyPairCreateFieldComponentEdgeInsets = EdgeInsets(top: keyPairCreateFieldComponentTopPadding, leading: keyPairCreateFieldComponentLeadingPadding, bottom: keyPairCreateFieldComponentBottomPadding, trailing: keyPairCreateFieldComponentTrailingPadding)
    private static let keyPairCreateDescriptionEdgeInsets = EdgeInsets(top: keyPairCreateDescriptionTopPadding, leading: keyPairCreateDescriptionLeadingPadding, bottom: keyPairCreateDescriptionBottomPadding, trailing: keyPairCreateDescriptionTrailingPadding)

    // Text Constants
    private static let keyPairCreateFormTitle = "Create New SSH Key Pair"
    private static let keyPairCreateValidationErrorsTitle = "Validation Errors"
    private static let keyPairCreateValidationErrorPrefix = "* "
    private static let keyPairCreateNameFieldLabel = "Key Pair Name"
    private static let keyPairCreateCreationTypeFieldLabel = "Creation Type"
    private static let keyPairCreatePublicKeyFieldLabel = "Public Key"
    private static let keyPairCreateRequiredFieldSuffix = ": *"
    private static let keyPairCreatePromptSuffix = ": (LEFT/RIGHT)"
    private static let keyPairCreateCharacterCountPrefix = " ("
    private static let keyPairCreateCharacterCountSuffix = " characters)"
    private static let keyPairCreateSelectedIndicator = "> "
    private static let keyPairCreateUnselectedIndicator = "  "
    private static let keyPairCreateEditPromptText = "[Type to edit]"
    private static let keyPairCreateNamePlaceholder = "[Enter key pair name]"
    private static let keyPairCreatePublicKeyPlaceholder = "[Paste public key here]"
    private static let keyPairCreatePublicKeyFilePathPlaceholder = "~/.ssh/id_rsa.pub"
    private static let keyPairCreateFieldTruncationBuffer = 10
    private static let keyPairCreateFieldActiveIndicator = "_"
    private static let keyPairCreateNavigationPrompt = " LEFT/RIGHT"
    private static let keyPairCreatePublicKeyLineContinuation = "  "
    private static let keyPairCreateDescriptionSeparator = "\\n"
    private static let keyPairCreateGenerateDescription = "A new SSH key pair will be generated for you.\\nThe private key will be displayed once - save it immediately!"
    private static let keyPairCreateImportDescription = "Import an existing public key from your local machine.\\nPaste the content of your .pub file above."
    private static let keyPairCreateScreenTooSmallText = "Screen too small"
}