import Foundation
import OSClient

enum SecurityGroupRuleManagementMode {
    case list
    case create
    case edit(SecurityGroupRule)
}

struct SecurityGroupRuleManagementForm {
    // Management state
    var securityGroup: SecurityGroup
    var mode: SecurityGroupRuleManagementMode = .list
    var selectedRuleIndex: Int = 0
    var scrollOffset: Int = 0

    // FormSelector state for rule list
    var selectedRuleIds: Set<String> = []
    var highlightedRuleIndex: Int = 0
    var ruleSearchQuery: String? = nil
    var ruleScrollOffset: Int = 0

    // Rule creation/editing form
    var ruleCreateForm: SecurityGroupRuleCreateForm = SecurityGroupRuleCreateForm()

    // FormBuilder state for rule creation/editing
    var ruleCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    // Available security groups for remote type selection
    var availableSecurityGroups: [SecurityGroup] = []

    init(securityGroup: SecurityGroup, availableSecurityGroups: [SecurityGroup] = []) {
        self.securityGroup = securityGroup
        self.availableSecurityGroups = availableSecurityGroups
        self.ruleCreateForm.remoteSecurityGroups = availableSecurityGroups
    }

    // MARK: - Rule List Management

    mutating func moveSelectionUp() {
        highlightedRuleIndex = max(0, highlightedRuleIndex - 1)
        selectedRuleIndex = highlightedRuleIndex
    }

    mutating func moveSelectionDown() {
        let maxIndex = max(0, (securityGroup.securityGroupRules?.count ?? 0) - 1)
        highlightedRuleIndex = min(maxIndex, highlightedRuleIndex + 1)
        selectedRuleIndex = highlightedRuleIndex
    }

    mutating func toggleRuleSelection() {
        guard let rule = getHighlightedRule() else { return }
        if selectedRuleIds.contains(rule.id) {
            selectedRuleIds.remove(rule.id)
        } else {
            selectedRuleIds.insert(rule.id)
        }
    }

    mutating func clearRuleSelection() {
        selectedRuleIds.removeAll()
    }

    func getHighlightedRule() -> SecurityGroupRule? {
        guard highlightedRuleIndex < (securityGroup.securityGroupRules?.count ?? 0) else {
            return nil
        }
        return securityGroup.securityGroupRules?[highlightedRuleIndex]
    }

    func getSelectedRule() -> SecurityGroupRule? {
        return getHighlightedRule()
    }

    func getSelectedRules() -> [SecurityGroupRule] {
        return securityGroup.securityGroupRules?.filter { selectedRuleIds.contains($0.id) } ?? []
    }

    // MARK: - Mode Management

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

    mutating func returnToListMode() {
        mode = .list
        ruleCreateForm.reset()
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