import Foundation
import OSClient

/// Web access option item for selector
struct WebAccessOption: FormSelectableItem, FormSelectorItem {
    let value: String
    let displayTitle: String

    var id: String {
        return value
    }

    var sortKey: String {
        return value
    }

    func matchesSearch(_ query: String) -> Bool {
        return displayTitle.localizedCaseInsensitiveContains(query) ||
               value.localizedCaseInsensitiveContains(query)
    }
}

/// Swift Container Web Access Form
struct SwiftContainerWebAccessForm {
    // Container info
    var containerName: String = ""
    var webURL: String = ""
    var currentReadACL: String = ""

    // Form data - using "enabled" or "disabled" as the selection value
    var webAccessEnabled: String = "disabled"

    // Build fields for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState) -> [FormField] {
        var fields: [FormField] = []

        // Container name (read-only)
        fields.append(.info(FormFieldInfo(
            id: "containerName",
            label: "Container",
            value: containerName,
            isVisible: true,
            style: .accent
        )))

        // Current status (read-only)
        let currentStatus = currentReadACL.contains(".r:") ? "Enabled" : "Disabled"
        fields.append(.info(FormFieldInfo(
            id: "currentStatus",
            label: "Current Status",
            value: currentStatus,
            isVisible: true,
            style: currentStatus == "Enabled" ? .success : .muted
        )))

        // Web URL (read-only, only shown if currently enabled or if user selects enable)
        let showURL = currentReadACL.contains(".r:") || webAccessEnabled == "enabled"
        if showURL {
            fields.append(.info(FormFieldInfo(
                id: "webURL",
                label: "Public URL",
                value: webURL,
                isVisible: true,
                style: .info
            )))
        }

        // Current Read ACL (if enabled)
        if currentReadACL.contains(".r:") {
            fields.append(.info(FormFieldInfo(
                id: "currentACL",
                label: "Current ACL",
                value: currentReadACL,
                isVisible: true,
                style: .muted
            )))
        }

        // Web access selector
        let webAccessItems: [WebAccessOption] = [
            WebAccessOption(value: "enabled", displayTitle: "Enable (.r:*,.rlistings)"),
            WebAccessOption(value: "disabled", displayTitle: "Disable (remove ACL)")
        ]

        // Find the index of the currently selected item
        let defaultHighlightedIndex = webAccessItems.firstIndex(where: { $0.value == webAccessEnabled }) ?? 0

        fields.append(.selector(FormFieldSelector(
            id: "webAccessEnabled",
            label: "Web Access",
            items: webAccessItems.map { $0 as any FormSelectorItem },
            selectedItemId: webAccessEnabled,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == "webAccessEnabled",
            isActive: activeFieldId == "webAccessEnabled",
            validationError: nil,
            columns: [
                FormSelectorItemColumn(header: "Option", width: 40, getValue: { item in
                    (item as? WebAccessOption)?.displayTitle ?? ""
                })
            ],
            searchQuery: formState.getSelectorState("webAccessEnabled")?.searchQuery,
            highlightedIndex: formState.getSelectorState("webAccessEnabled")?.highlightedIndex ?? defaultHighlightedIndex,
            scrollOffset: formState.getSelectorState("webAccessEnabled")?.scrollOffset ?? 0
        )))

        // Info field
        let infoText = webAccessEnabled == "enabled" ?
            "Enabling will set Read ACL and web-index:index.html metadata" :
            "Disabling will remove Read ACL"

        fields.append(.info(FormFieldInfo(
            id: "info",
            label: "Info",
            value: infoText,
            isVisible: true,
            style: .info
        )))

        // Help text
        fields.append(.info(FormFieldInfo(
            id: "help",
            label: "",
            value: "SPACE:toggle ENTER:confirm ESC:cancel",
            isVisible: true,
            style: .muted
        )))

        return fields
    }

    // Update form from state
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let value = formState.getSelectorSelectedId("webAccessEnabled") {
            webAccessEnabled = value
        }
    }

    // Validate the entire form
    func validateForm() -> [String] {
        let errors: [String] = []

        // No validation needed - selection is always valid

        return errors
    }

    // Check if form is valid
    func isValid() -> Bool {
        return validateForm().isEmpty
    }

    // Initialize from metadata response and endpoint
    mutating func loadFromMetadata(_ metadata: SwiftContainerMetadataResponse, swiftEndpoint: String) {
        self.containerName = metadata.containerName
        self.currentReadACL = metadata.readACL ?? ""
        self.webURL = "\(swiftEndpoint)/\(metadata.containerName)"

        // Set initial selection based on current state
        if metadata.readACL?.contains(".r:") ?? false {
            self.webAccessEnabled = "enabled"
        } else {
            self.webAccessEnabled = "disabled"
        }
    }
}
