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
    var selectedRuleIndex: Int = 0

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

    // MARK: - Initialization

    /// Initialize the rule management form
    ///
    /// - Parameters:
    ///   - securityGroup: The security group to manage rules for
    ///   - availableSecurityGroups: Available security groups for remote type selection
    init(securityGroup: SecurityGroup, availableSecurityGroups: [SecurityGroup] = []) {
        self.securityGroup = securityGroup
        self.availableSecurityGroups = availableSecurityGroups
        self.ruleCreateForm.remoteSecurityGroups = availableSecurityGroups
    }

    // MARK: - Rule List Management

    /// Move selection up in the rule list
    mutating func moveSelectionUp() {
        highlightedRuleIndex = max(0, highlightedRuleIndex - 1)
        selectedRuleIndex = highlightedRuleIndex
    }

    /// Move selection down in the rule list
    mutating func moveSelectionDown() {
        let maxIndex = max(0, (securityGroup.securityGroupRules?.count ?? 0) - 1)
        highlightedRuleIndex = min(maxIndex, highlightedRuleIndex + 1)
        selectedRuleIndex = highlightedRuleIndex
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
        } else {
            ruleCreateForm.remoteType = .cidr
            ruleCreateForm.remoteValue = ruleCreateForm.ethertype == .ipv4 ? "0.0.0.0/0" : "::/0"
        }

        ruleCreateForm.remoteSecurityGroups = availableSecurityGroups
    }

    // MARK: - Rule Creation/Update Data

    func getRuleCreationData() -> (direction: SecurityGroupDirection,
                                  protocol: SecurityGroupProtocol,
                                  ethertype: SecurityGroupEtherType,
                                  portMin: Int?,
                                  portMax: Int?,
                                  remoteIPPrefix: String?,
                                  remoteGroupID: String?) {

        var portMin: Int? = nil
        var portMax: Int? = nil
        var remoteIPPrefix: String? = nil
        var remoteGroupID: String? = nil

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
        }

        return (
            direction: ruleCreateForm.direction,
            protocol: ruleCreateForm.ruleProtocol,
            ethertype: ruleCreateForm.ethertype,
            portMin: portMin,
            portMax: portMax,
            remoteIPPrefix: remoteIPPrefix,
            remoteGroupID: remoteGroupID
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

    func getHelpText() -> String {
        switch mode {
        case .list:
            return "UP/DOWN Navigate | SPACE Edit | C Create | DEL Delete | ESC Back"
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

    mutating func updateSecurityGroup(_ updatedSecurityGroup: SecurityGroup) {
        self.securityGroup = updatedSecurityGroup

        // Adjust selection if rules were removed
        let maxIndex = max(0, (securityGroup.securityGroupRules?.count ?? 0) - 1)
        selectedRuleIndex = min(selectedRuleIndex, maxIndex)

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
}

// MARK: - Extensions for SecurityGroupRule

extension SecurityGroupRule {
    var ethertypeEnum: SecurityGroupEtherType? {
        guard let ethertype = ethertype else { return nil }
        return SecurityGroupEtherType(rawValue: ethertype)
    }
}