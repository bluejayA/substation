import Foundation
import OSClient
import SwiftTUI

struct KeyPairViews {
    @MainActor
    static func drawDetailedKeyPairList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                      width: Int32, height: Int32, cachedKeyPairs: [KeyPair],
                                      searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.keyPairListMinScreenWidth && height > Self.keyPairListMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.keyPairListBoundsMinWidth, width), height: max(Self.keyPairListBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.keyPairListScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Key Pair List
        var components: [any Component] = []

        // Title - optimized conditional logic for performance
        let titleText: String
        if let query = searchQuery {
            titleText = Self.keyPairListFilteredTitlePrefix + query + Self.keyPairListFilteredTitleSuffix
        } else {
            titleText = Self.keyPairListTitle
        }
        components.append(Text(titleText).emphasis().bold().padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0)))

        // Header
        components.append(Text(Self.keyPairListHeader).muted()
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)).border())

        // Content - get filtered key pairs and create list components
        let filteredKeyPairs = FilterUtils.filterKeyPairs(cachedKeyPairs, query: searchQuery)
        let totalCount = filteredKeyPairs.count

        if totalCount == 0 {
            components.append(Text(Self.keyPairListNoKeyPairsText).info()
                .padding(Self.keyPairListNoKeyPairsEdgeInsets))
        } else {
            // Calculate visible range for simple viewport
            let maxVisibleItems = max(Self.keyPairListMinVisibleItems, Int(height) - Self.keyPairListReservedSpaceForHeaderFooter) // Reserve space for header and footer
            let startIndex = max(0, min(scrollOffset, totalCount - maxVisibleItems))
            let endIndex = min(totalCount, startIndex + maxVisibleItems)

            for i in startIndex..<endIndex {
                let keyPair = filteredKeyPairs[i]
                let isSelected = i == selectedIndex
                let keyPairComponent = createKeyPairListItemComponent(keyPair: keyPair, isSelected: isSelected)
                components.append(keyPairComponent)
            }

            // Scroll indicator if needed - optimized string construction with cached count
            if totalCount > maxVisibleItems {
                let displayStart = startIndex + 1
                let scrollText = Self.keyPairListScrollInfoPrefix + String(displayStart) + Self.keyPairListScrollInfoSeparator + String(endIndex) + Self.keyPairListScrollInfoMiddle + String(totalCount) + Self.keyPairListScrollInfoSuffix
                components.append(Text(scrollText).info()
                    .padding(Self.keyPairListScrollInfoEdgeInsets))
            }
        }

        // Render unified key pair list
        let keyPairListComponent = VStack(spacing: Self.keyPairListComponentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(keyPairListComponent, on: surface, in: bounds)
    }

    // MARK: - Component Creation Functions

    private static func createKeyPairListItemComponent(keyPair: KeyPair, isSelected: Bool) -> any Component {
        // Key pair name (truncated to fit)
        let keyPairName = keyPair.name
        let truncatedName = String((keyPairName ?? "Unnamed").prefix(Self.keyPairListNamePadLength)).padding(toLength: Self.keyPairListNamePadLength, withPad: Self.keyPairListPadCharacter, startingAt: 0)

        // Fingerprint (truncated to fit)
        let fingerprintText: String
        if let fingerprint = keyPair.fingerprint {
            fingerprintText = fingerprint.count > Self.keyPairListFingerprintMaxLength ? String(fingerprint.suffix(Self.keyPairListFingerprintMaxLength)) : fingerprint
        } else {
            fingerprintText = Self.keyPairListUnknownFingerprintText
        }

        // Pre-calculate spaced text for optimal performance
        let spacedName = Self.keyPairListItemTextSpacing + truncatedName
        let spacedFingerprint = Self.keyPairListItemTextSpacing + fingerprintText

        let rowStyle: TextStyle = isSelected ? .accent : .secondary

        return HStack(spacing: 0, children: [
            StatusIcon(status: Self.keyPairListStatusIconActive),
            Text(spacedName).styled(rowStyle),
            Text(spacedFingerprint).styled(rowStyle)
        ]).padding(Self.keyPairListItemEdgeInsets)
    }

    // MARK: - Detail View

    @MainActor
    static func drawKeyPairDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                width: Int32, height: Int32, keyPair: KeyPair) async {

        // Create surface once for optimal performance
        let surface = SwiftTUI.surface(from: screen)

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > Self.keyPairDetailMinScreenWidth && height > Self.keyPairDetailMinScreenHeight else {
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(Self.keyPairDetailBoundsMinWidth, width), height: max(Self.keyPairDetailBoundsMinHeight, height))
            await SwiftTUI.render(Text(Self.keyPairListScreenTooSmallText).error(), on: surface, in: errorBounds)
            return
        }

        // Main Key Pair Detail
        var components: [any Component] = []

        // Title - optimized string construction
        let keyPairName = keyPair.name
        let titleText = Self.keyPairDetailTitlePrefix + Self.keyPairDetailTitle + Self.keyPairDetailFieldValueSeparator + (keyPairName ?? "Unnamed")
        components.append(Text(titleText).accent().bold()
                         .padding(Self.keyPairDetailTitleEdgeInsets))

        // Basic Information Section
        components.append(Text(Self.keyPairDetailBasicInfoTitle).primary().bold())

        var basicInfo: [any Component] = []
        // Pre-calculate common field prefixes for optimal performance
        let fieldPrefix = Self.keyPairDetailInfoFieldIndent
        let fieldSeparator = Self.keyPairDetailFieldValueSeparator
        let namePrefix = fieldPrefix + Self.keyPairDetailNameLabel + fieldSeparator

        // Optimized string construction for basic info fields
        let nameText = namePrefix + (keyPairName ?? "Unnamed")
        basicInfo.append(Text(nameText).secondary())

        if let fingerprint = keyPair.fingerprint {
            let fingerprintPrefix = fieldPrefix + Self.keyPairDetailFingerprintLabel + fieldSeparator
            let fingerprintText = fingerprintPrefix + fingerprint
            basicInfo.append(Text(fingerprintText).secondary())
        }

        if let type = keyPair.type {
            let typePrefix = fieldPrefix + Self.keyPairDetailTypeLabel + fieldSeparator
            let typeText = typePrefix + type
            basicInfo.append(Text(typeText).secondary())
        }

        let basicInfoSection = VStack(spacing: 0, children: basicInfo)
            .padding(Self.keyPairDetailSectionEdgeInsets)
        components.append(basicInfoSection)

        // Public Key Information
        if let publicKey = keyPair.publicKey {
            components.append(Text(Self.keyPairDetailPublicKeyTitle).primary().bold())

            var keyInfo: [any Component] = []
            // Split the public key into multiple lines if needed
            let maxKeyWidth = Int(width) - Self.keyPairDetailKeyWidth
            let keyLines = FormatUtils.wrapText(publicKey, maxWidth: maxKeyWidth)
            let maxDisplayLines = Int(height) - Self.keyPairDetailFooterReservedHeight // Account for title, basic info, and footer
            let displayLines = Array(keyLines.prefix(maxDisplayLines))

            for line in displayLines {
                let lineText = fieldPrefix + line
                keyInfo.append(Text(lineText).secondary())
            }

            if keyLines.count > displayLines.count {
                let truncatedText = fieldPrefix + Self.keyPairDetailTruncatedText
                keyInfo.append(Text(truncatedText).info())
            }

            let keySection = VStack(spacing: 0, children: keyInfo)
                .padding(Self.keyPairDetailSectionEdgeInsets)
            components.append(keySection)
        }

        // Help text
        components.append(Text(Self.keyPairDetailHelpText).info()
            .padding(Self.keyPairDetailHelpEdgeInsets))

        // Render unified key pair detail
        let keyPairDetailComponent = VStack(spacing: Self.keyPairDetailComponentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        await SwiftTUI.render(keyPairDetailComponent, on: surface, in: bounds)
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