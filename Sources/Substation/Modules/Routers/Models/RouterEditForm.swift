import Foundation
import OSClient

/// Field identifiers for the router edit form
enum RouterEditFieldId: String, CaseIterable {
    case name = "name"
    case description = "description"
    case adminStateUp = "adminStateUp"
    case externalGateway = "externalGateway"
    case externalNetwork = "externalNetwork"

    var title: String {
        switch self {
        case .name:
            return "Router Name"
        case .description:
            return "Description"
        case .adminStateUp:
            return "Admin State"
        case .externalGateway:
            return "External Gateway"
        case .externalNetwork:
            return "External Network"
        }
    }
}

/// Form model for editing an existing router
///
/// This form allows users to modify router properties including:
/// - Router name and description
/// - Admin state (up/down)
/// - External gateway configuration
struct RouterEditForm {
    // MARK: - Constants

    private static let routerNamePlaceholder = "Enter router name"
    private static let routerDescriptionPlaceholder = "Enter description"
    private static let routerNameRequiredError = "Router name is required"
    private static let routerNameInvalidCharsError = "Router name can only contain letters, numbers, spaces, and @._- characters"
    private static let externalNetworkRequiredError = "External network is required when external gateway is enabled"
    private static let noExternalNetworksError = "No external networks available for gateway"
    private static let adminStateUpLabel = "Up"
    private static let adminStateDownLabel = "Down"
    private static let externalGatewayEnabledLabel = "Enabled"
    private static let externalGatewayDisabledLabel = "Disabled"

    // MARK: - Properties

    /// The ID of the router being edited
    var routerId: String = ""

    /// Router name
    var routerName: String = ""

    /// Router description
    var routerDescription: String = ""

    /// Admin state (true = up, false = down)
    var adminStateUp: Bool = true

    /// External gateway enabled
    var externalGatewayEnabled: Bool = false

    /// Selected external network ID
    var selectedExternalNetworkId: String?

    /// Error message if any
    var errorMessage: String? = nil

    /// Loading state
    var isLoading: Bool = false

    // MARK: - Initialization

    /// Initialize an empty edit form
    init() {}

    /// Initialize the edit form with an existing router's values
    ///
    /// - Parameter router: The router to edit
    init(router: Router) {
        self.routerId = router.id
        self.routerName = router.name ?? ""
        self.routerDescription = router.description ?? ""
        self.adminStateUp = router.adminStateUp ?? true
        self.externalGatewayEnabled = router.externalGatewayInfo != nil
        self.selectedExternalNetworkId = router.externalGatewayInfo?.networkId
    }

    // MARK: - Field Building

    /// Build form fields for rendering
    ///
    /// - Parameters:
    ///   - selectedFieldId: Currently selected field ID
    ///   - activeFieldId: Currently active (editing) field ID
    ///   - formState: Form builder state for cursor positions and selector states
    ///   - externalNetworks: Available external networks
    /// - Returns: Array of form fields
    func buildFields(
        selectedFieldId: String?,
        activeFieldId: String? = nil,
        formState: FormBuilderState? = nil,
        externalNetworks: [Network]
    ) -> [FormField] {
        var fields: [FormField] = []

        // Router Name
        let nameId = RouterEditFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameId,
            label: RouterEditFieldId.name.title,
            value: routerName,
            placeholder: Self.routerNamePlaceholder,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.getTextFieldCursorPosition(nameId),
            validationError: getNameValidationError()
        )))

        // Description
        let descriptionId = RouterEditFieldId.description.rawValue
        fields.append(.text(FormFieldText(
            id: descriptionId,
            label: RouterEditFieldId.description.title,
            value: routerDescription,
            placeholder: Self.routerDescriptionPlaceholder,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == descriptionId,
            isActive: activeFieldId == descriptionId,
            cursorPosition: formState?.getTextFieldCursorPosition(descriptionId)
        )))

        // Admin State
        let adminStateId = RouterEditFieldId.adminStateUp.rawValue
        fields.append(.toggle(FormFieldToggle(
            id: adminStateId,
            label: RouterEditFieldId.adminStateUp.title,
            value: adminStateUp,
            isVisible: true,
            isSelected: selectedFieldId == adminStateId,
            enabledLabel: Self.adminStateUpLabel,
            disabledLabel: Self.adminStateDownLabel
        )))

        // External Gateway Toggle
        let externalGatewayId = RouterEditFieldId.externalGateway.rawValue
        fields.append(.toggle(FormFieldToggle(
            id: externalGatewayId,
            label: RouterEditFieldId.externalGateway.title,
            value: externalGatewayEnabled,
            isVisible: true,
            isSelected: selectedFieldId == externalGatewayId,
            enabledLabel: Self.externalGatewayEnabledLabel,
            disabledLabel: Self.externalGatewayDisabledLabel
        )))

        // External Network Selector (only shown when gateway is enabled)
        if externalGatewayEnabled {
            let externalNetworkId = RouterEditFieldId.externalNetwork.rawValue
            let networkItems = externalNetworks.filter { $0.external == true }
            fields.append(.selector(FormFieldSelector(
                id: externalNetworkId,
                label: RouterEditFieldId.externalNetwork.title,
                items: networkItems,
                selectedItemId: selectedExternalNetworkId,
                isRequired: true,
                isVisible: true,
                isSelected: selectedFieldId == externalNetworkId,
                isActive: activeFieldId == externalNetworkId,
                validationError: getExternalNetworkValidationError(externalNetworks: externalNetworks),
                columns: [
                    FormSelectorItemColumn(header: "NETWORK NAME", width: 30) { item in
                        (item as? Network)?.name ?? "Unnamed"
                    },
                    FormSelectorItemColumn(header: "NETWORK ID", width: 36) { item in
                        (item as? Network)?.id ?? ""
                    }
                ],
                searchQuery: formState?.selectorStates[externalNetworkId]?.searchQuery,
                highlightedIndex: formState?.selectorStates[externalNetworkId]?.highlightedIndex ?? 0,
                scrollOffset: formState?.selectorStates[externalNetworkId]?.scrollOffset ?? 0
            )))
        }

        return fields
    }

    // MARK: - Validation

    private func getNameValidationError() -> String? {
        let trimmedName = routerName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return Self.routerNameRequiredError
        }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@._- ")
        if trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return Self.routerNameInvalidCharsError
        }

        return nil
    }

    private func getExternalNetworkValidationError(externalNetworks: [Network]) -> String? {
        guard externalGatewayEnabled else { return nil }

        let externalOnly = externalNetworks.filter { $0.external == true }
        if externalOnly.isEmpty {
            return Self.noExternalNetworksError
        }

        if selectedExternalNetworkId == nil {
            return Self.externalNetworkRequiredError
        }

        return nil
    }

    /// Validate the form and return any errors
    ///
    /// - Parameter externalNetworks: Available external networks for validation
    /// - Returns: Array of validation error messages
    func validateForm(externalNetworks: [Network]) -> [String] {
        var errors: [String] = []

        if let nameError = getNameValidationError() {
            errors.append(nameError)
        }

        if let networkError = getExternalNetworkValidationError(externalNetworks: externalNetworks) {
            errors.append(networkError)
        }

        return errors
    }

    // MARK: - State Updates

    /// Update form values from form builder state
    ///
    /// - Parameter formState: The form builder state to read values from
    mutating func updateFromFormState(_ formState: FormBuilderState) {
        if let name = formState.getTextValue(RouterEditFieldId.name.rawValue) {
            routerName = name
        }

        if let description = formState.getTextValue(RouterEditFieldId.description.rawValue) {
            routerDescription = description
        }

        if let adminState = formState.getToggleValue(RouterEditFieldId.adminStateUp.rawValue) {
            adminStateUp = adminState
        }

        if let gatewayEnabled = formState.getToggleValue(RouterEditFieldId.externalGateway.rawValue) {
            externalGatewayEnabled = gatewayEnabled
        }

        if let networkId = formState.selectorStates[RouterEditFieldId.externalNetwork.rawValue]?.selectedItemId {
            selectedExternalNetworkId = networkId
        }
    }

    // MARK: - Helpers

    /// Get trimmed router name
    func getTrimmedName() -> String {
        return routerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get trimmed description
    func getTrimmedDescription() -> String {
        return routerDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
