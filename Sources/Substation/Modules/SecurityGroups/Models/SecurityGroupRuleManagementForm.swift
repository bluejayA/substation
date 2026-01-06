import Foundation
import OSClient

/// Mode enumeration for security group rule management
///
/// Tracks the current state of the rule management interface:
/// - list: Viewing and selecting rules
/// - create: Creating a new rule
/// - edit: Editing an existing rule
enum SecurityGroupRuleManagementMode {
    case list
    case create
    case edit(SecurityGroupRule)
}

/// Form model for managing security group rules
///
/// This form handles the dual-mode interface for security group rule management,
/// supporting both list navigation and rule creation/editing. It maintains proper
/// state separation between modes to prevent corruption during transitions.
///
/// **Usage Pattern:**
/// 1. Initialize with security group and available groups
/// 2. Use list navigation methods in list mode
/// 3. Enter create/edit mode with enterCreateMode()/enterEditMode()
/// 4. Return to list with returnToListMode()
struct SecurityGroupRuleManagementForm {
    // MARK: - Management State

    /// The security group being managed
    var securityGroup: SecurityGroup

    /// Current management mode (list, create, or edit)
    var mode: SecurityGroupRuleManagementMode = .list

    /// Index of selected rule in list mode
    ///
    /// This is a computed property that mirrors `highlightedRuleIndex` to ensure
    /// consistent state management. Both properties always remain synchronized,
    /// eliminating index divergence issues in navigation.
    var selectedRuleIndex: Int {
        get { highlightedRuleIndex }
        set { highlightedRuleIndex = newValue }
    }

    /// Scroll offset for rule list
    var scrollOffset: Int = 0

    // MARK: - FormSelector State for Rule List

    /// Set of selected rule IDs for batch operations
    var selectedRuleIds: Set<String> = []

    /// Index of currently highlighted rule in list
    var highlightedRuleIndex: Int = 0

    /// Search query for filtering rules
    var ruleSearchQuery: String? = nil

    /// Scroll offset for rule list display
    var ruleScrollOffset: Int = 0

    // MARK: - Rule Creation/Editing State

    /// Form for creating or editing rules
    var ruleCreateForm: SecurityGroupRuleCreateForm = SecurityGroupRuleCreateForm()

    /// FormBuilder state for rule creation/editing
    var ruleCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Available security groups for remote type selection
    var availableSecurityGroups: [SecurityGroup] = []

    /// Available address groups for remote type selection
    var availableAddressGroups: [AddressGroup] = []

    // MARK: - Initialization

    /// Initialize the rule management form
    ///
    /// - Parameters:
    ///   - securityGroup: The security group to manage rules for
    ///   - availableSecurityGroups: Available security groups for remote type selection
    ///   - availableAddressGroups: Available address groups for remote type selection
    init(securityGroup: SecurityGroup, availableSecurityGroups: [SecurityGroup] = [], availableAddressGroups: [AddressGroup] = []) {
        self.securityGroup = securityGroup
        self.availableSecurityGroups = availableSecurityGroups
        self.availableAddressGroups = availableAddressGroups
        self.ruleCreateForm.remoteSecurityGroups = availableSecurityGroups
        self.ruleCreateForm.remoteAddressGroups = availableAddressGroups
    }

    // MARK: - Rule List Management

    /// Move selection up in the rule list
    ///
    /// Decrements the highlighted rule index while ensuring it does not go below zero.
    /// The `selectedRuleIndex` computed property automatically stays synchronized.
    mutating func moveSelectionUp() {
        highlightedRuleIndex = max(0, highlightedRuleIndex - 1)
    }

    /// Move selection down in the rule list
    ///
    /// Increments the highlighted rule index while ensuring it does not exceed
    /// the maximum valid index. The `selectedRuleIndex` computed property
    /// automatically stays synchronized.
    mutating func moveSelectionDown() {
        let maxIndex = max(0, (securityGroup.securityGroupRules?.count ?? 0) - 1)
        highlightedRuleIndex = min(maxIndex, highlightedRuleIndex + 1)
    }

    /// Toggle selection state of the currently highlighted rule
    mutating func toggleRuleSelection() {
        guard let rule = getHighlightedRule() else { return }
        if selectedRuleIds.contains(rule.id) {
            selectedRuleIds.remove(rule.id)
        } else {
            selectedRuleIds.insert(rule.id)
        }
    }

    /// Clear all rule selections
    mutating func clearRuleSelection() {
        selectedRuleIds.removeAll()
    }

    /// Get the currently highlighted rule
    /// - Returns: The highlighted security group rule or nil
    func getHighlightedRule() -> SecurityGroupRule? {
        guard highlightedRuleIndex < (securityGroup.securityGroupRules?.count ?? 0) else {
            return nil
        }
        return securityGroup.securityGroupRules?[highlightedRuleIndex]
    }

    /// Get the currently selected rule (alias for getHighlightedRule)
    /// - Returns: The selected security group rule or nil
    func getSelectedRule() -> SecurityGroupRule? {
        return getHighlightedRule()
    }

    /// Get all selected rules for batch operations
    /// - Returns: Array of selected security group rules
    func getSelectedRules() -> [SecurityGroupRule] {
        return securityGroup.securityGroupRules?.filter { selectedRuleIds.contains($0.id) } ?? []
    }

    // MARK: - Mode Management

    /// Enter create mode for adding a new rule
    ///
    /// Resets the rule form and initializes FormBuilderState for a new rule.
    /// This properly separates state from list mode to prevent corruption.
    mutating func enterCreateMode() {
        mode = .create
        ruleCreateForm.reset()
        ruleCreateForm.remoteSecurityGroups = availableSecurityGroups
        ruleCreateForm.remoteAddressGroups = availableAddressGroups

        // Initialize FormBuilderState with form fields
        ruleCreateFormState = FormBuilderState(fields: ruleCreateForm.buildFields(
            selectedFieldId: nil,
            activeFieldId: nil,
            formState: FormBuilderState(fields: [])
        ))
    }

    /// Enter edit mode for modifying the selected rule
    ///
    /// Populates the form with the selected rule's data and initializes
    /// FormBuilderState for editing. Returns early if no rule is selected.
    mutating func enterEditMode() {
        guard let rule = getSelectedRule() else { return }
        mode = .edit(rule)
        populateFormFromRule(rule)

        // Initialize FormBuilderState with form fields
        ruleCreateFormState = FormBuilderState(fields: ruleCreateForm.buildFields(
            selectedFieldId: nil,
            activeFieldId: nil,
            formState: FormBuilderState(fields: [])
        ))
    }

    /// Return to list mode from create or edit mode
    ///
    /// Resets the form state and switches back to list mode.
    /// This is typically called when canceling a create/edit operation.
    mutating func returnToListMode() {
        mode = .list
        ruleCreateForm.reset()
        // Clear FormBuilderState to prevent stale state
        ruleCreateFormState = FormBuilderState(fields: [])
    }

    // MARK: - Form Population from Existing Rule

    private mutating func populateFormFromRule(_ rule: SecurityGroupRule) {
        ruleCreateForm.reset()

        // Set direction
        if let direction = rule.directionEnum {
            ruleCreateForm.direction = direction
        }

        // Set protocol
        if let protocolValue = rule.protocolEnum {
            ruleCreateForm.ruleProtocol = protocolValue
        }

        // Set ether type
        if let etherType = rule.ethertypeEnum {
            ruleCreateForm.ethertype = etherType
        }

        // Set port information
        if ruleCreateForm.ruleProtocol == .tcp || ruleCreateForm.ruleProtocol == .udp {
            if let portMin = rule.portRangeMin, let portMax = rule.portRangeMax {
                if portMin == 1 && portMax == 65535 {
                    ruleCreateForm.portType = .all
                } else {
                    ruleCreateForm.portType = .custom
                    ruleCreateForm.portRangeMin = String(portMin)
                    if portMin != portMax {
                        ruleCreateForm.portRangeMax = String(portMax)
                    }
                }
            } else {
                ruleCreateForm.portType = .all
            }
        }

        // Set remote information
        if let remoteIPPrefix = rule.remoteIpPrefix, !remoteIPPrefix.isEmpty {
            ruleCreateForm.remoteType = .cidr
            ruleCreateForm.remoteValue = remoteIPPrefix
        } else if let remoteGroupId = rule.remoteGroupId, !remoteGroupId.isEmpty {
            ruleCreateForm.remoteType = .securityGroup
            // Find the security group by ID
            if let index = availableSecurityGroups.firstIndex(where: { $0.id == remoteGroupId }) {
                ruleCreateForm.selectedRemoteSecurityGroupIndex = index
            }
        } else if let remoteAddressGroupId = rule.remoteAddressGroupId, !remoteAddressGroupId.isEmpty {
            ruleCreateForm.remoteType = .addressGroup
            // Find the address group by ID
            if let index = availableAddressGroups.firstIndex(where: { $0.id == remoteAddressGroupId }) {
                ruleCreateForm.selectedRemoteAddressGroupIndex = index
            }
        } else {
            ruleCreateForm.remoteType = .cidr
            ruleCreateForm.remoteValue = ruleCreateForm.ethertype == .ipv4 ? "0.0.0.0/0" : "::/0"
        }

        ruleCreateForm.remoteSecurityGroups = availableSecurityGroups
        ruleCreateForm.remoteAddressGroups = availableAddressGroups
    }

    // MARK: - Rule Creation/Update Data

    func getRuleCreationData() -> (direction: SecurityGroupDirection,
                                  protocol: SecurityGroupProtocol,
                                  ethertype: SecurityGroupEtherType,
                                  portMin: Int?,
                                  portMax: Int?,
                                  remoteIPPrefix: String?,
                                  remoteGroupID: String?,
                                  remoteAddressGroupID: String?) {

        var portMin: Int? = nil
        var portMax: Int? = nil
        var remoteIPPrefix: String? = nil
        var remoteGroupID: String? = nil
        var remoteAddressGroupID: String? = nil

        // Handle port information
        if ruleCreateForm.ruleProtocol == .tcp || ruleCreateForm.ruleProtocol == .udp {
            if ruleCreateForm.portType == .custom {
                portMin = ruleCreateForm.getPortRangeMinValue()
                portMax = ruleCreateForm.getPortRangeMaxValue() ?? portMin
            } else {
                // All ports
                portMin = 1
                portMax = 65535
            }
        }

        // Handle remote information
        switch ruleCreateForm.remoteType {
        case .cidr:
            remoteIPPrefix = ruleCreateForm.remoteValue.isEmpty ?
                (ruleCreateForm.ethertype == .ipv4 ? "0.0.0.0/0" : "::/0") :
                ruleCreateForm.remoteValue
        case .securityGroup:
            remoteGroupID = ruleCreateForm.getSelectedRemoteSecurityGroup()?.id
        case .addressGroup:
            remoteAddressGroupID = ruleCreateForm.getSelectedRemoteAddressGroup()?.id
        }

        return (
            direction: ruleCreateForm.direction,
            protocol: ruleCreateForm.ruleProtocol,
            ethertype: ruleCreateForm.ethertype,
            portMin: portMin,
            portMax: portMax,
            remoteIPPrefix: remoteIPPrefix,
            remoteGroupID: remoteGroupID,
            remoteAddressGroupID: remoteAddressGroupID
        )
    }

    // MARK: - Validation

    func validateCurrentForm() -> (isValid: Bool, errors: [String]) {
        return ruleCreateForm.validateForm()
    }

    // MARK: - UI Helpers

    func getTitle() -> String {
        switch mode {
        case .list:
            return "Manage Security Group Rules - \(securityGroup.name ?? "Unnamed Group")"
        case .create:
            return "Create New Rule - \(securityGroup.name ?? "Unnamed Group")"
        case .edit(let rule):
            return "Edit Rule - \(rule.id)"
        }
    }

    /// Get contextual help text for the current mode
    ///
    /// Returns keyboard shortcuts and actions available based on the current mode:
    /// - List mode: Navigation, edit, create, delete, and back to security groups
    /// - Create/Edit mode: Delegates to rule create form navigation help
    ///
    /// - Returns: Help text string with available keyboard shortcuts
    func getHelpText() -> String {
        switch mode {
        case .list:
            return "UP/DOWN Navigate | SPACE Edit | C Create | DEL Delete | ESC Return to Security Groups"
        case .create, .edit:
            return ruleCreateForm.getNavigationHelp()
        }
    }

    func shouldShowRulesList() -> Bool {
        if case .list = mode {
            return true
        }
        return false
    }

    func shouldShowCreateForm() -> Bool {
        if case .create = mode {
            return true
        }
        return false
    }

    func shouldShowEditForm() -> Bool {
        if case .edit = mode {
            return true
        }
        return false
    }

    // MARK: - Data Updates

    /// Update the security group with new data
    ///
    /// Updates the managed security group and adjusts the selection index if rules
    /// were removed. Automatically returns to list mode after create/edit operations.
    ///
    /// - Parameter updatedSecurityGroup: The updated security group data
    mutating func updateSecurityGroup(_ updatedSecurityGroup: SecurityGroup) {
        self.securityGroup = updatedSecurityGroup

        // Adjust selection if rules were removed
        let maxIndex = max(0, (securityGroup.securityGroupRules?.count ?? 0) - 1)
        highlightedRuleIndex = min(highlightedRuleIndex, maxIndex)

        // Return to list mode after operations
        if case .create = mode {
            returnToListMode()
        } else if case .edit = mode {
            returnToListMode()
        }
    }

    mutating func updateAvailableSecurityGroups(_ groups: [SecurityGroup]) {
        self.availableSecurityGroups = groups
        self.ruleCreateForm.remoteSecurityGroups = groups
    }

    mutating func updateAvailableAddressGroups(_ groups: [AddressGroup]) {
        self.availableAddressGroups = groups
        self.ruleCreateForm.remoteAddressGroups = groups
    }
}

// MARK: - Extensions for SecurityGroupRule

extension SecurityGroupRule {
    var ethertypeEnum: SecurityGroupEtherType? {
        guard let ethertype = ethertype else { return nil }
        return SecurityGroupEtherType(rawValue: ethertype)
    }
}