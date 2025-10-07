import Foundation
import OSClient
import SwiftTUI

struct SecurityGroupViews {
    // MARK: - Analysis Support

    private struct SecurityGroupAnalysis {
        let ingressRules: [SecurityGroupRule]
        let egressRules: [SecurityGroupRule]
        let uniqueProtocols: Set<String>
        let uniquePorts: Set<String>
        let remoteGroups: Set<String>
        let remoteIPs: Set<String>
        let ethertypes: Set<String>
    }

    private static func analyzeSecurityGroup(securityGroup: SecurityGroup) -> SecurityGroupAnalysis {
        let ingressRules = securityGroup.securityGroupRules?.filter { $0.direction == "ingress" } ?? []
        let egressRules = securityGroup.securityGroupRules?.filter { $0.direction == "egress" } ?? []

        var uniqueProtocols = Set<String>()
        var uniquePorts = Set<String>()
        var remoteGroups = Set<String>()
        var remoteIPs = Set<String>()
        var ethertypes = Set<String>()

        for rule in securityGroup.securityGroupRules ?? [] {
            if let protocolValue = rule.protocolEnum?.rawValue {
                uniqueProtocols.insert(protocolValue.uppercased())
            } else {
                uniqueProtocols.insert("ANY")
            }

            let portRange = formatPortRange(rule)
            if !portRange.isEmpty && portRange != "ALL" {
                uniquePorts.insert(formatPortRange(rule))
            }

            ethertypes.insert(rule.ethertype ?? "IPv4")

            // Analyze remote description for groups and IPs
            let remoteDesc = formatRemoteDescription(rule).lowercased()
            if remoteDesc.contains("group") {
                remoteGroups.insert(formatRemoteDescription(rule))
            } else if remoteDesc.contains(".") || remoteDesc.contains(":") {
                remoteIPs.insert(formatRemoteDescription(rule))
            }
        }

        return SecurityGroupAnalysis(
            ingressRules: ingressRules,
            egressRules: egressRules,
            uniqueProtocols: uniqueProtocols,
            uniquePorts: uniquePorts,
            remoteGroups: remoteGroups,
            remoteIPs: remoteIPs,
            ethertypes: ethertypes
        )
    }

    // MARK: - Helper Functions

    // Helper functions for SecurityGroupRule compatibility
    private static func formatPortRange(_ rule: SecurityGroupRule) -> String {
        if let min = rule.portRangeMin, let max = rule.portRangeMax {
            return min == max ? "\(min)" : "\(min)-\(max)"
        } else if let min = rule.portRangeMin {
            return "\(min)"
        } else if let max = rule.portRangeMax {
            return "\(max)"
        }
        return "ALL"
    }

    private static func formatRemoteDescription(_ rule: SecurityGroupRule) -> String {
        if let remoteIp = rule.remoteIpPrefix {
            return remoteIp
        } else if let remoteGroup = rule.remoteGroupId {
            return "sg-\(String(remoteGroup.prefix(8)))"
        }
        return "0.0.0.0/0"
    }

    // Layout Constants
    private static let titleOffset: Int32 = 2
    private static let contentIndent: Int32 = 2
    private static let fieldIndent: Int32 = 2
    private static let itemIndent: Int32 = 2
    private static let clearAreaOffset: Int32 = -1
    private static let rowSpacing: Int32 = 1
    private static let sectionSpacing: Int32 = 2
    private static let componentTopPadding: Int32 = 2
    private static let componentSpacing: Int32 = 0
    private static let headerBottomPadding: Int32 = 2
    private static let pendingChangesTopPadding: Int32 = 1

    // Text Constants
    private static let manageSecurityGroupsTitle = "Manage Security Groups"
    private static let serverLabel = "Server: "
    private static let unknownServerName = "Unknown"
    private static let loadingMessage = "Loading security groups..."
    private static let errorPrefix = "Error: "
    private static let noGroupsAvailableMessage = "No security groups available"
    private static let securityGroupsListTitle = "Security Groups:"
    private static let pendingChangesPrefix = "Pending: "
    private static let pendingChangesAddPrefix = "+"
    private static let pendingChangesRemovePrefix = "-"
    private static let pendingChangesSuffix = " changes"

    // Status Indicators
    private static let statusPendingAdd = "[+]"
    private static let statusPendingRemove = "[-]"
    private static let statusAttached = "[*]"
    private static let statusNotAttached = "[ ]"

    // Dimensions
    private static let loadingComponentHeight: Int32 = 6
    private static let errorComponentHeight: Int32 = 6
    private static let emptyComponentHeight: Int32 = 6
    private static let contentHeightOffset: Int32 = 8
    private static let visibleItemsOffset: Int32 = 2

    // MARK: - Security Groups List View

    @MainActor
    static func drawDetailedSecurityGroupList(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                             width: Int32, height: Int32, cachedSecurityGroups: [SecurityGroup],
                                             searchQuery: String?, scrollOffset: Int, selectedIndex: Int) async {

        let statusListView = createSecurityGroupStatusListView()
        await statusListView.draw(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            items: cachedSecurityGroups,
            searchQuery: searchQuery,
            scrollOffset: scrollOffset,
            selectedIndex: selectedIndex
        )
    }

    private static func createSecurityGroupRuleItemComponent(rule: SecurityGroupRule, ruleIndex: Int,
                                                           selectedIndices: Set<Int>, currentRuleIndex: Int) -> any Component {
        let isSelected = selectedIndices.contains(ruleIndex)
        let isCurrentRow = ruleIndex == currentRuleIndex

        let prefix = isCurrentRow ? "> " : "  "
        let checkbox = isSelected ? "[X] " : "[ ] "
        let dirDisplay = String(rule.direction.prefix(6)).padding(toLength: 6, withPad: " ", startingAt: 0)
        let protocolDisplay = String((rule.protocolEnum?.rawValue ?? "any").prefix(7)).padding(toLength: 7, withPad: " ", startingAt: 0)
        let portDisplay = String(formatPortRange(rule).prefix(15)).padding(toLength: 15, withPad: " ", startingAt: 0)

        let directionStyle: TextStyle = rule.direction == "ingress" ? .success : .error
        let checkboxStyle: TextStyle = isSelected ? .success : .secondary
        let prefixStyle: TextStyle = isCurrentRow ? .warning : .secondary

        return HStack(spacing: 0, children: [
            Text(prefix).styled(prefixStyle),
            Text(checkbox).styled(checkboxStyle),
            Text(dirDisplay).styled(directionStyle),
            Text(" \(protocolDisplay) \(portDisplay) \(formatRemoteDescription(rule))").secondary()
        ]).padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0))
    }

    // MARK: - Security Group Detail View

    // Detail View Layout Constants
    private static let securityGroupDetailTopPadding: Int32 = 2
    private static let securityGroupDetailBottomPadding: Int32 = 2
    private static let securityGroupDetailLeadingPadding: Int32 = 0
    private static let securityGroupDetailTrailingPadding: Int32 = 0
    private static let securityGroupDetailBasicInfoSpacing: Int32 = 0
    private static let securityGroupDetailRulesSpacing: Int32 = 0
    private static let securityGroupDetailSectionSpacing: Int32 = 1
    private static let securityGroupDetailMinScreenWidth: Int32 = 40
    private static let securityGroupDetailMinScreenHeight: Int32 = 15
    private static let securityGroupDetailBoundsMinWidth: Int32 = 1
    private static let securityGroupDetailBoundsMinHeight: Int32 = 1
    private static let securityGroupDetailComponentSpacing: Int32 = 0
    private static let securityGroupDetailReservedSpace: Int32 = 10
    private static let securityGroupDetailRuleScrollThreshold = 8

    // Detail View EdgeInsets (Pre-calculated for Performance - Gold Standard)
    private static let securityGroupDetailTitleEdgeInsets = EdgeInsets(top: securityGroupDetailTitleTopPadding, leading: securityGroupDetailTitleLeadingPadding, bottom: securityGroupDetailTitleBottomPadding, trailing: securityGroupDetailTitleTrailingPadding)
    private static let securityGroupDetailSectionEdgeInsets = EdgeInsets(top: securityGroupDetailSectionTopPadding, leading: securityGroupDetailSectionLeadingPadding, bottom: securityGroupDetailSectionBottomPadding, trailing: securityGroupDetailSectionTrailingPadding)

    // Detail View Text Constants
    private static let securityGroupDetailTitle = "Security Group Details"
    private static let securityGroupDetailBasicInfoTitle = "Basic Information"
    private static let securityGroupDetailIngressRulesTitle = "Ingress Rules"
    private static let securityGroupDetailEgressRulesTitle = "Egress Rules"
    private static let securityGroupDetailRulesSummaryTitle = "Rules Summary"
    private static let securityGroupDetailNameLabel = "Name"
    private static let securityGroupDetailIdLabel = "ID"
    private static let securityGroupDetailDescriptionLabel = "Description"
    private static let securityGroupDetailNoDescription = "No description"
    private static let securityGroupDetailNoRules = "No rules defined"
    private static let securityGroupDetailNoIngressRules = "No ingress rules"
    private static let securityGroupDetailNoEgressRules = "No egress rules"
    private static let securityGroupDetailRulesTableHeader = "PROTO   PORTS           ETHERTYPE  REMOTE"
    private static let securityGroupDetailRulesTableSeparator = String(repeating: "-", count: 50)
    private static let securityGroupDetailScreenTooSmallText = "Screen too small"
    private static let securityGroupDetailRuleSelectedPrefix = "> "
    private static let securityGroupDetailRuleUnselectedPrefix = "  "
    private static let securityGroupDetailMoreRulesText = "... and %d more rules"
    private static let securityGroupDetailScrollIndicatorText = "[%d-%d/%d] - Scroll: UP/DOWN"
    private static let securityGroupDetailIngressCountText = "Ingress: %d rules"
    private static let securityGroupDetailEgressCountText = "Egress: %d rules"
    private static let securityGroupDetailRuleDetailsTitle = "Rule Details"
    private static let securityGroupDetailRemoteGroupsTitle = "Remote Security Groups"
    private static let securityGroupDetailPortRangesTitle = "Port Ranges"
    private static let securityGroupDetailProtocolsTitle = "Protocols Used"
    private static let securityGroupDetailProjectIdLabel = "Project ID"
    private static let securityGroupDetailCreatedAtLabel = "Created"
    private static let securityGroupDetailUpdatedAtLabel = "Updated"
    private static let securityGroupDetailRuleIdLabel = "Rule ID"
    private static let securityGroupDetailDirectionLabel = "Direction"
    private static let securityGroupDetailProtocolLabel = "Protocol"
    private static let securityGroupDetailEthertypeLabel = "EtherType"
    private static let securityGroupDetailPortRangeLabel = "Port Range"
    private static let securityGroupDetailRemoteIpLabel = "Remote IP"
    private static let securityGroupDetailRemoteGroupLabel = "Remote Group"
    private static let securityGroupDetailNoRemoteGroups = "No remote security groups referenced"
    private static let securityGroupDetailTruncationSuffix = "..."
    private static let securityGroupDetailTotalRulesText = "Total rules: %d"
    private static let securityGroupDetailUniqueProtocolsText = "Protocols: %@"
    private static let securityGroupDetailUniquePortsText = "Port ranges: %@"
    private static let securityGroupDetailInfoFieldIndent = "  "
    private static let securityGroupDetailFieldValueSeparator = ": "
    private static let securityGroupDetailRuleDetailMaxLength = 50
    private static let securityGroupDetailTitleTopPadding: Int32 = 0
    private static let securityGroupDetailTitleLeadingPadding: Int32 = 0
    private static let securityGroupDetailTitleBottomPadding: Int32 = 2
    private static let securityGroupDetailTitleTrailingPadding: Int32 = 0
    private static let securityGroupDetailSectionTopPadding: Int32 = 0
    private static let securityGroupDetailSectionLeadingPadding: Int32 = 4
    private static let securityGroupDetailSectionBottomPadding: Int32 = 1
    private static let securityGroupDetailSectionTrailingPadding: Int32 = 0
    private static let securityGroupDetailHelpText = "Press ESC to return to security group list"

    @MainActor
    static func drawSecurityGroupDetail(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                       width: Int32, height: Int32, securityGroup: SecurityGroup,
                                       selectedRuleIndex: Int? = nil, scrollOffset: Int = 0) async {

        var sections: [DetailSection] = []

        // Basic Information Section
        let basicItems: [DetailItem?] = [
            DetailView.buildFieldItem(label: "ID", value: securityGroup.id),
            DetailView.buildFieldItem(label: "Name", value: securityGroup.name, defaultValue: "Unknown"),
            DetailView.buildFieldItem(label: "Description", value: securityGroup.description, defaultValue: "No description"),
            DetailView.buildFieldItem(label: "Project ID", value: securityGroup.projectId ?? securityGroup.tenantId),
            DetailView.buildFieldItem(label: "Revision Number", value: securityGroup.revisionNumber)
        ]

        if let basicSection = DetailView.buildSection(title: "Basic Information", items: basicItems) {
            sections.append(basicSection)
        }

        // Analyze security group for rich metadata
        let analysis = analyzeSecurityGroup(securityGroup: securityGroup)

        // Rules Summary Section
        var summaryItems: [DetailItem] = []
        summaryItems.append(.field(
            label: "Total Rules",
            value: String(analysis.ingressRules.count + analysis.egressRules.count),
            style: .primary
        ))
        summaryItems.append(.field(
            label: "Ingress Rules",
            value: String(analysis.ingressRules.count),
            style: .success
        ))
        summaryItems.append(.field(
            label: "Egress Rules",
            value: String(analysis.egressRules.count),
            style: .error
        ))

        sections.append(DetailSection(title: "Rules Summary", items: summaryItems))

        // Network Configuration Section - NEW!
        var networkItems: [DetailItem] = []

        if !analysis.uniqueProtocols.isEmpty {
            let protocols = Array(analysis.uniqueProtocols).sorted().joined(separator: ", ")
            networkItems.append(.field(label: "Protocols", value: protocols, style: .secondary))
        }

        if !analysis.ethertypes.isEmpty {
            let ethertypes = Array(analysis.ethertypes).sorted().joined(separator: ", ")
            networkItems.append(.field(label: "EtherTypes", value: ethertypes, style: .secondary))
        }

        if !analysis.uniquePorts.isEmpty {
            let ports = Array(analysis.uniquePorts).sorted().joined(separator: ", ")
            networkItems.append(.field(label: "Port Ranges", value: ports, style: .info))
        }

        if !networkItems.isEmpty {
            sections.append(DetailSection(title: "Network Configuration", items: networkItems))
        }

        // Remote Sources Section - NEW!
        if !analysis.remoteIPs.isEmpty || !analysis.remoteGroups.isEmpty {
            var remoteItems: [DetailItem] = []

            if !analysis.remoteIPs.isEmpty {
                remoteItems.append(.field(label: "Remote IP Prefixes", value: "\(analysis.remoteIPs.count) configured", style: .info))
                for ip in analysis.remoteIPs.sorted().prefix(5) {
                    remoteItems.append(.field(label: "  CIDR", value: ip, style: .secondary))
                }
                if analysis.remoteIPs.count > 5 {
                    remoteItems.append(.field(label: "  Additional", value: "\(analysis.remoteIPs.count - 5) more", style: .muted))
                }
            }

            if !analysis.remoteGroups.isEmpty {
                if !remoteItems.isEmpty {
                    remoteItems.append(.spacer)
                }
                remoteItems.append(.field(label: "Remote Security Groups", value: "\(analysis.remoteGroups.count) referenced", style: .accent))
                for groupRef in analysis.remoteGroups.sorted().prefix(5) {
                    remoteItems.append(.field(label: "  Group", value: groupRef, style: .secondary))
                }
                if analysis.remoteGroups.count > 5 {
                    remoteItems.append(.field(label: "  Additional", value: "\(analysis.remoteGroups.count - 5) more", style: .muted))
                }
            }

            sections.append(DetailSection(title: "Remote Sources", items: remoteItems))
        }

        // Ingress Rules Section with enhanced detail
        if !analysis.ingressRules.isEmpty {
            var ingressItems: [DetailItem] = []

            for rule in analysis.ingressRules {
                // Rule header with protocol
                let protocolDisplay = rule.protocolEnum?.rawValue.uppercased() ?? "ANY"
                ingressItems.append(.customComponent(
                    HStack(spacing: 0, children: [
                        Text("  IN ").success(),
                        Text(protocolDisplay).secondary()
                    ])
                ))

                // Port range
                let portRange = formatPortRange(rule)
                if !portRange.isEmpty && portRange != "ALL" {
                    ingressItems.append(.field(label: "    Ports", value: portRange, style: .secondary))
                }

                // EtherType
                if let ethertype = rule.ethertype {
                    ingressItems.append(.field(label: "    EtherType", value: ethertype, style: .secondary))
                }

                // Remote source
                let remoteDesc = formatRemoteDescription(rule)
                ingressItems.append(.field(label: "    Remote", value: remoteDesc, style: .info))

                // Rule description (if any)
                if let description = rule.description, !description.isEmpty {
                    ingressItems.append(.field(label: "    Description", value: description, style: .muted))
                }

                ingressItems.append(.spacer)
            }

            sections.append(DetailSection(title: "Ingress Rules (\(analysis.ingressRules.count))", items: ingressItems, titleStyle: .success))
        }

        // Egress Rules Section with enhanced detail
        if !analysis.egressRules.isEmpty {
            var egressItems: [DetailItem] = []

            for rule in analysis.egressRules {
                // Rule header with protocol
                let protocolDisplay = rule.protocolEnum?.rawValue.uppercased() ?? "ANY"
                egressItems.append(.customComponent(
                    HStack(spacing: 0, children: [
                        Text("  OUT ").error(),
                        Text(protocolDisplay).secondary()
                    ])
                ))

                // Port range
                let portRange = formatPortRange(rule)
                if !portRange.isEmpty && portRange != "ALL" {
                    egressItems.append(.field(label: "    Ports", value: portRange, style: .secondary))
                }

                // EtherType
                if let ethertype = rule.ethertype {
                    egressItems.append(.field(label: "    EtherType", value: ethertype, style: .secondary))
                }

                // Remote destination
                let remoteDesc = formatRemoteDescription(rule)
                egressItems.append(.field(label: "    Remote", value: remoteDesc, style: .info))

                // Rule description (if any)
                if let description = rule.description, !description.isEmpty {
                    egressItems.append(.field(label: "    Description", value: description, style: .muted))
                }

                egressItems.append(.spacer)
            }

            sections.append(DetailSection(title: "Egress Rules (\(analysis.egressRules.count))", items: egressItems, titleStyle: .error))
        }

        // Tags Section
        if let tags = securityGroup.tags, !tags.isEmpty {
            var tagItems: [DetailItem] = []
            for tag in tags {
                tagItems.append(.field(label: "Tag", value: tag, style: .accent))
            }
            sections.append(DetailSection(title: "Tags", items: tagItems))
        }

        // Timestamps Section
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var timestampItems: [DetailItem?] = []
        if let created = securityGroup.createdAt {
            timestampItems.append(.field(label: "Created", value: formatter.string(from: created), style: .secondary))
        }
        if let updated = securityGroup.updatedAt {
            timestampItems.append(.field(label: "Updated", value: formatter.string(from: updated), style: .secondary))
        }

        if let timestampSection = DetailView.buildSection(title: "Timestamps", items: timestampItems) {
            sections.append(timestampSection)
        }

        // Create and render DetailView
        let detailView = DetailView(
            title: "Security Group Details: \(securityGroup.name ?? "Unknown")",
            sections: sections,
            helpText: "Press ESC to return to security group list",
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

    // MARK: - Security Group Analysis (Rich Metadata)

    // MARK: - Security Group Create View

    // Layout Constants
    private static let sgCreateComponentTopPadding: Int32 = 1
    private static let sgCreateStatusMessageTopPadding: Int32 = 2
    private static let sgCreateStatusMessageLeadingPadding: Int32 = 2
    private static let sgCreateValidationErrorLeadingPadding: Int32 = 2
    private static let sgCreateLoadingErrorBoundsHeight: Int32 = 6
    private static let sgCreateFieldActiveSpacing = "                      "

    // Text Constants
    private static let sgCreateFormTitle = "Create Security Group"
    private static let sgCreateCreatingText = "Creating security group..."
    private static let sgCreateErrorPrefix = "Error: "
    private static let sgCreateRequiredFieldSuffix = ": *"
    private static let sgCreateOptionalFieldSuffix = " (optional)"

    // Field Display Constants
    private static let sgCreateValidationErrorsTitle = "Validation Errors:"
    private static let sgCreateValidationErrorPrefix = "- "
    private static let sgCreateEditPromptText = "Press SPACE to edit..."

    // Field Label Constants
    private static let sgCreateNameFieldLabel = "Security Group Name"
    private static let sgCreateDescriptionFieldLabel = "Description"

    // Placeholder Constants
    private static let sgCreateNamePlaceholder = "[Enter security group name]"
    private static let sgCreateDescriptionPlaceholder = "[Optional description]"

    // UI Component Constants
    private static let sgCreateSelectedIndicator = "> "
    private static let sgCreateUnselectedIndicator = "  "
    private static let sgCreateComponentSpacing: Int32 = 0

    @MainActor
    static func drawSecurityGroupCreateForm(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                           width: Int32, height: Int32, form: SecurityGroupCreateForm,
                                           formState: FormBuilderState) async {

        let surface = SwiftTUI.surface(from: screen)

        // Build form fields with FormBuilder state
        let fields = form.buildFields(
            selectedFieldId: formState.getCurrentFieldId(),
            activeFieldId: formState.getActiveFieldId(),
            formState: formState
        )

        // Create FormBuilder
        let formBuilder = FormBuilder(
            title: Self.sgCreateFormTitle,
            fields: fields,
            selectedFieldId: formState.getCurrentFieldId(),
            validationErrors: form.validateForm().errors,
            showValidationErrors: formState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)
    }


    // MARK: - Security Group Rule Create View

    // Layout Constants
    private static let sgRuleCreateComponentTopPadding: Int32 = 1
    private static let sgRuleCreateStatusMessageTopPadding: Int32 = 2
    private static let sgRuleCreateStatusMessageLeadingPadding: Int32 = 2
    private static let sgRuleCreateValidationErrorLeadingPadding: Int32 = 2
    private static let sgRuleCreateLoadingErrorBoundsHeight: Int32 = 6
    private static let sgRuleCreateFieldActiveSpacing = "                      "

    // Text Constants
    private static let sgRuleCreateFormTitle = "Create Security Group Rule"
    private static let sgRuleCreateCreatingText = "Creating rule..."
    private static let sgRuleCreateErrorPrefix = "Error: "
    private static let sgRuleCreateRequiredFieldSuffix = ": *"
    private static let sgRuleCreateOptionalFieldSuffix = " (optional)"

    // Field Display Constants
    private static let sgRuleCreateValidationErrorsTitle = "Validation Errors:"
    private static let sgRuleCreateValidationErrorPrefix = "- "
    private static let sgRuleCreateEditPromptText = "Press SPACE to edit..."
    private static let sgRuleCreateTogglePromptText = "Press SPACE to change"
    private static let sgRuleCreateSelectPromptText = "Press SPACE to select"

    // Field Label Constants
    private static let sgRuleCreateDirectionFieldLabel = "Direction"
    private static let sgRuleCreateProtocolFieldLabel = "Protocol"
    private static let sgRuleCreatePortTypeFieldLabel = "Port Type"
    private static let sgRuleCreatePortRangeMinFieldLabel = "Port Range Min"
    private static let sgRuleCreatePortRangeMaxFieldLabel = "Port Range Max"
    private static let sgRuleCreateEthertypeFieldLabel = "Ether Type"
    private static let sgRuleCreateRemoteTypeFieldLabel = "Remote Type"
    private static let sgRuleCreateRemoteValueFieldLabel = "Remote Value"

    // Placeholder Constants
    private static let sgRuleCreatePortRangeMinPlaceholder = "[Enter minimum port]"
    private static let sgRuleCreatePortRangeMaxPlaceholder = "[Enter maximum port]"
    private static let sgRuleCreateRemoteValuePlaceholder = "[Enter CIDR block]"
    private static let sgRuleCreateNoSecurityGroupsText = "No security groups available"

    // UI Component Constants
    private static let sgRuleCreateSelectedIndicator = "> "
    private static let sgRuleCreateUnselectedIndicator = "  "
    private static let sgRuleCreateComponentSpacing: Int32 = 0

    @MainActor
    static func drawSecurityGroupRuleCreateForm(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                               width: Int32, height: Int32, form: SecurityGroupRuleCreateForm,
                                               cachedSecurityGroups: [SecurityGroup] = [],
                                               errorMessage: String? = nil) async {

        // Check if we're in security group selection mode
        if form.securityGroupSelectionMode {
            let surface = SwiftTUI.surface(from: screen)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

            // Create FormSelector for multi-select security group selection
            let columns = [
                FormSelectorColumn<SecurityGroup>(
                    header: "Name",
                    width: 40,
                    getValue: { $0.name ?? "Unknown" }
                )
            ]

            let tab = FormSelectorTab<SecurityGroup>(
                title: "Security Groups",
                columns: columns
            )

            let selector = FormSelector<SecurityGroup>(
                label: "Select Remote Security Groups",
                tabs: [tab],
                selectedTabIndex: 0,
                items: form.remoteSecurityGroups,
                selectedItemIds: form.selectedRemoteSecurityGroups,
                highlightedIndex: form.selectedRemoteSecurityGroupIndex,
                multiSelect: true,
                scrollOffset: 0,
                searchQuery: nil,
                maxHeight: Int(height),
                isActive: true
            )

            await SwiftTUI.render(selector.render(), on: surface, in: bounds)
            return
        }

        // Main Security Group Rule Create Form
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = [
            Text(Self.sgRuleCreateFormTitle).emphasis().bold()
        ]

        // Error message display
        if let errorMessage = errorMessage {
            components.append(Text("\(Self.sgRuleCreateErrorPrefix)\(errorMessage)").error().bold()
                .padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)))
        }

        // Build all form fields as components
        let visibleFields = getSGRuleCreateVisibleFields(for: form)

        for (index, field) in visibleFields.enumerated() {
            let isFirstField = index == 0
            let fieldComponent = createSGRuleCreateFieldComponent(field: field, form: form, width: width, isFirstField: isFirstField)
            components.append(fieldComponent)
        }

        // Show validation errors if any
        let validation = form.validateForm()
        if !validation.isValid {
            components.append(Text(Self.sgRuleCreateValidationErrorsTitle).error().bold()
                .padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)))

            for error in validation.errors {
                components.append(Text("\(Self.sgRuleCreateValidationErrorPrefix)\(error)").error()
                    .padding(EdgeInsets(top: 0, leading: Self.sgRuleCreateValidationErrorLeadingPadding, bottom: 0, trailing: 0)))
            }
        }

        // Render the entire form following ServerCreateView pattern
        let formComponent = VStack(spacing: Self.sgRuleCreateComponentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(formComponent, on: surface, in: bounds)
    }

    // MARK: - Component Creation

    private static func getSGRuleCreateVisibleFields(for form: SecurityGroupRuleCreateForm) -> [SecurityGroupRuleCreateField] {
        return form.getVisibleFields()
    }

    private static func createSGRuleCreateFieldComponent(field: SecurityGroupRuleCreateField, form: SecurityGroupRuleCreateForm, width: Int32, isFirstField: Bool) -> any Component {
        let isSelected = form.currentField == field

        switch field {
        case .direction:
            return createSGRuleCreateDirectionField(form: form, isSelected: isSelected, isFirstField: isFirstField)
        case .protocol:
            return createSGRuleCreateProtocolField(form: form, isSelected: isSelected, isFirstField: isFirstField)
        case .portType:
            return createSGRuleCreatePortTypeField(form: form, isSelected: isSelected, isFirstField: isFirstField)
        case .portRangeMin:
            return createSGRuleCreatePortRangeMinField(form: form, isSelected: isSelected, width: width, isFirstField: isFirstField)
        case .portRangeMax:
            return createSGRuleCreatePortRangeMaxField(form: form, isSelected: isSelected, width: width, isFirstField: isFirstField)
        case .ethertype:
            return createSGRuleCreateEthertypeField(form: form, isSelected: isSelected, isFirstField: isFirstField)
        case .remoteType:
            return createSGRuleCreateRemoteTypeField(form: form, isSelected: isSelected, isFirstField: isFirstField)
        case .remoteValue:
            return createSGRuleCreateRemoteValueField(form: form, isSelected: isSelected, width: width, isFirstField: isFirstField)
        }
    }

    // MARK: - Field Creation Functions

    private static func createSGRuleCreateDirectionField(form: SecurityGroupRuleCreateForm, isSelected: Bool, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.sgRuleCreateDirectionFieldLabel)\(Self.sgRuleCreateRequiredFieldSuffix)"
        let indicator = isSelected ? Self.sgRuleCreateSelectedIndicator : Self.sgRuleCreateUnselectedIndicator

        let displayText = isSelected ? "\(form.direction.rawValue.capitalized) (\(Self.sgRuleCreateTogglePromptText))" : form.direction.rawValue.capitalized
        let fieldStyle: TextStyle = isSelected ? .warning : .secondary

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.sgRuleCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createSGRuleCreateProtocolField(form: SecurityGroupRuleCreateForm, isSelected: Bool, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.sgRuleCreateProtocolFieldLabel)\(Self.sgRuleCreateRequiredFieldSuffix)"
        let indicator = isSelected ? Self.sgRuleCreateSelectedIndicator : Self.sgRuleCreateUnselectedIndicator

        let displayText = isSelected ? "\(form.ruleProtocol.rawValue.uppercased()) (\(Self.sgRuleCreateTogglePromptText))" : form.ruleProtocol.rawValue.uppercased()
        let fieldStyle: TextStyle = isSelected ? .warning : .secondary

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.sgRuleCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createSGRuleCreatePortTypeField(form: SecurityGroupRuleCreateForm, isSelected: Bool, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.sgRuleCreatePortTypeFieldLabel)\(Self.sgRuleCreateRequiredFieldSuffix)"
        let indicator = isSelected ? Self.sgRuleCreateSelectedIndicator : Self.sgRuleCreateUnselectedIndicator

        let displayText = isSelected ? "\(form.portType.displayName) (\(Self.sgRuleCreateTogglePromptText))" : form.portType.displayName
        let fieldStyle: TextStyle = isSelected ? .warning : .secondary

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.sgRuleCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createSGRuleCreatePortRangeMinField(form: SecurityGroupRuleCreateForm, isSelected: Bool, width: Int32, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.sgRuleCreatePortRangeMinFieldLabel)\(Self.sgRuleCreateRequiredFieldSuffix)"
        let indicator = isSelected ? Self.sgRuleCreateSelectedIndicator : Self.sgRuleCreateUnselectedIndicator

        let displayText: String
        if form.fieldEditMode && isSelected {
            displayText = form.portRangeMin.isEmpty ? Self.sgRuleCreateEditPromptText : form.portRangeMin + Self.sgRuleCreateFieldActiveSpacing
        } else {
            displayText = form.portRangeMin.isEmpty ? Self.sgRuleCreatePortRangeMinPlaceholder : form.portRangeMin
        }

        let fieldStyle: TextStyle = isSelected ? (form.fieldEditMode ? .primary : .warning) : .secondary
        let truncatedText = String(displayText.prefix(Int(width) - 10))

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(truncatedText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.sgRuleCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createSGRuleCreatePortRangeMaxField(form: SecurityGroupRuleCreateForm, isSelected: Bool, width: Int32, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.sgRuleCreatePortRangeMaxFieldLabel)\(Self.sgRuleCreateRequiredFieldSuffix)"
        let indicator = isSelected ? Self.sgRuleCreateSelectedIndicator : Self.sgRuleCreateUnselectedIndicator

        let displayText: String
        if form.fieldEditMode && isSelected {
            displayText = form.portRangeMax.isEmpty ? Self.sgRuleCreateEditPromptText : form.portRangeMax + Self.sgRuleCreateFieldActiveSpacing
        } else {
            displayText = form.portRangeMax.isEmpty ? Self.sgRuleCreatePortRangeMaxPlaceholder : form.portRangeMax
        }

        let fieldStyle: TextStyle = isSelected ? (form.fieldEditMode ? .primary : .warning) : .secondary
        let truncatedText = String(displayText.prefix(Int(width) - 10))

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(truncatedText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.sgRuleCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createSGRuleCreateEthertypeField(form: SecurityGroupRuleCreateForm, isSelected: Bool, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.sgRuleCreateEthertypeFieldLabel)\(Self.sgRuleCreateRequiredFieldSuffix)"
        let indicator = isSelected ? Self.sgRuleCreateSelectedIndicator : Self.sgRuleCreateUnselectedIndicator

        let displayText = isSelected ? "\(form.ethertype.rawValue) (\(Self.sgRuleCreateTogglePromptText))" : form.ethertype.rawValue
        let fieldStyle: TextStyle = isSelected ? .warning : .secondary

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.sgRuleCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createSGRuleCreateRemoteTypeField(form: SecurityGroupRuleCreateForm, isSelected: Bool, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.sgRuleCreateRemoteTypeFieldLabel)\(Self.sgRuleCreateRequiredFieldSuffix)"
        let indicator = isSelected ? Self.sgRuleCreateSelectedIndicator : Self.sgRuleCreateUnselectedIndicator

        let displayText = isSelected ? "\(form.remoteType.displayName) (\(Self.sgRuleCreateTogglePromptText))" : form.remoteType.displayName
        let fieldStyle: TextStyle = isSelected ? .warning : .secondary

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(displayText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.sgRuleCreateComponentTopPadding, trailing: 0))
        ])
    }

    private static func createSGRuleCreateRemoteValueField(form: SecurityGroupRuleCreateForm, isSelected: Bool, width: Int32, isFirstField: Bool) -> any Component {
        let fieldLabel = "\(Self.sgRuleCreateRemoteValueFieldLabel)\(Self.sgRuleCreateRequiredFieldSuffix)"
        let indicator = isSelected ? Self.sgRuleCreateSelectedIndicator : Self.sgRuleCreateUnselectedIndicator

        let displayText: String
        let fieldStyle: TextStyle

        if form.remoteType == .cidr {
            if form.fieldEditMode && isSelected {
                displayText = form.remoteValue.isEmpty ? Self.sgRuleCreateEditPromptText : form.remoteValue + Self.sgRuleCreateFieldActiveSpacing
            } else {
                displayText = form.remoteValue.isEmpty ? Self.sgRuleCreateRemoteValuePlaceholder : form.remoteValue
            }
            fieldStyle = isSelected ? (form.fieldEditMode ? .primary : .warning) : .secondary
        } else if form.remoteType == .securityGroup {
            if let selectedGroup = form.getSelectedRemoteSecurityGroup() {
                displayText = isSelected && !form.remoteSecurityGroups.isEmpty ? "\(selectedGroup.name ?? "Unknown") (\(Self.sgRuleCreateSelectPromptText))" : (selectedGroup.name ?? "Unknown")
                fieldStyle = isSelected ? .warning : .secondary
            } else {
                displayText = Self.sgRuleCreateNoSecurityGroupsText
                fieldStyle = .error
            }
        } else {
            displayText = ""
            fieldStyle = .secondary
        }

        let truncatedText = String(displayText.prefix(Int(width) - 10))

        let labelComponent: any Component = isFirstField ?
            Text(fieldLabel).accent().bold().padding(EdgeInsets(top: Self.sgRuleCreateComponentTopPadding, leading: 0, bottom: 0, trailing: 0)) :
            Text(fieldLabel).accent().bold()

        return VStack(spacing: 0, children: [
            labelComponent,
            Text("\(indicator)\(truncatedText)").styled(fieldStyle)
                .padding(EdgeInsets(top: 0, leading: 4, bottom: Self.sgRuleCreateComponentTopPadding, trailing: 0))
        ])
    }

    // MARK: - Security Group Rules Management View

    @MainActor
    static func drawSecurityGroupRulesManagement(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                                width: Int32, height: Int32, securityGroup: SecurityGroup,
                                                selectedRuleIndices: Set<Int>, currentRuleIndex: Int) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Main Security Group Rules Management
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text("Manage Rules - \(securityGroup.name ?? "Unknown")").emphasis().bold())

        // Instructions
        components.append(Text("SPACE: toggle selection | A: add rule | DEL: delete selected | ESC: back").info()
            .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)))

        if securityGroup.securityGroupRules?.isEmpty ?? true {
            components.append(Text("No rules defined. Press 'A' to add a rule.").info()
                .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 0)))
        } else {
            // Rules table header
            components.append(Text("    DIR    PROTO   PORTS           REMOTE").accent().bold())
            components.append(Text(String(repeating: "-", count: 46)).border())

            // Display rules using SwiftTUI
            let availableHeight = max(1, Int(height) - 10) // Reserve space for header and footer
            let maxRulesToShow = min(securityGroup.securityGroupRules?.count ?? 0, availableHeight)

            for i in 0..<maxRulesToShow {
                let rule = (securityGroup.securityGroupRules ?? [])[i]
                let ruleComponent = createSecurityGroupRuleItemComponent(rule: rule, ruleIndex: i,
                                                                        selectedIndices: selectedRuleIndices,
                                                                        currentRuleIndex: currentRuleIndex)
                components.append(ruleComponent)
            }

            if (securityGroup.securityGroupRules?.count ?? 0) > maxRulesToShow {
                components.append(Text("... and \((securityGroup.securityGroupRules?.count ?? 0) - maxRulesToShow) more rules").info())
            }

            // Selection summary
            if !selectedRuleIndices.isEmpty {
                let summaryText = "Selected: \(selectedRuleIndices.count) rule\(selectedRuleIndices.count == 1 ? "" : "s")"
                components.append(Text(summaryText).warning()
                    .padding(EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0)))
            }
        }

        // Render unified rules management
        let rulesManagementComponent = VStack(spacing: 0, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(rulesManagementComponent, on: surface, in: bounds)
    }

    @MainActor
    static func drawServerSecurityGroupManagement(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                                 width: Int32, height: Int32, form: SecurityGroupManagementForm) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Main Server Security Group Management
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title
        components.append(Text(Self.manageSecurityGroupsTitle).emphasis().bold())

        // Server information
        if let server = form.selectedServer {
            let serverText = "\(Self.serverLabel)\(server.name ?? Self.unknownServerName)"
            components.append(Text(serverText).primary()
                .padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0)))
        }

        // Status messages (loading, error, or content)
        if form.isLoading {
            components.append(Text(Self.loadingMessage).info()
                .padding(EdgeInsets(top: Self.componentTopPadding, leading: Self.fieldIndent, bottom: 0, trailing: 0)))
        } else if let errorMessage = form.errorMessage {
            components.append(Text("\(Self.errorPrefix)\(errorMessage)").error()
                .padding(EdgeInsets(top: Self.componentTopPadding, leading: Self.fieldIndent, bottom: 0, trailing: 0)))
        } else {
            let managementGroups = form.getManagementGroups()
            let contentHeight = height - Self.contentHeightOffset

            if managementGroups.isEmpty {
                components.append(Text(Self.noGroupsAvailableMessage).info()
                    .padding(EdgeInsets(top: Self.componentTopPadding, leading: Self.fieldIndent, bottom: 0, trailing: 0)))
            } else {
                // Security groups list
                let listComponents = createSecurityGroupsListComponents(form: form, managementGroups: managementGroups, contentHeight: contentHeight)
                components.append(contentsOf: listComponents)

                // Pending changes summary
                if form.hasPendingChanges() {
                    let pendingChangesComponent = createPendingChangesComponent(form: form)
                    components.append(pendingChangesComponent)
                }
            }
        }

        // Render unified component structure
        let managementComponent = VStack(spacing: Self.componentSpacing, children: components)
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftTUI.render(managementComponent, on: surface, in: bounds)
    }

    // MARK: - Component Creation Functions for Security Group Management

    private static func createSecurityGroupsListComponents(form: SecurityGroupManagementForm, managementGroups: [SecurityGroup], contentHeight: Int32) -> [any Component] {
        var components: [any Component] = []

        // List title
        components.append(Text(Self.securityGroupsListTitle).emphasis().bold()
            .padding(EdgeInsets(top: Self.componentTopPadding, leading: 0, bottom: 0, trailing: 0)))

        // Calculate visible items
        let maxItemsToShow = min(Int(contentHeight - Self.visibleItemsOffset), managementGroups.count)
        let startIndex = max(0, min(form.selectedSecurityGroupIndex - maxItemsToShow + 1, managementGroups.count - maxItemsToShow))

        // Create item components
        for i in 0..<maxItemsToShow {
            let groupIndex = startIndex + i
            if groupIndex >= managementGroups.count { break }

            let group = managementGroups[groupIndex]
            let itemComponent = createSecurityGroupItemComponent(group: group, groupIndex: groupIndex, form: form)
            components.append(itemComponent)
        }

        return components
    }

    private static func createSecurityGroupItemComponent(group: SecurityGroup, groupIndex: Int, form: SecurityGroupManagementForm) -> any Component {
        let isSelected = groupIndex == form.selectedSecurityGroupIndex

        // Determine status indicator
        let statusIndicator = getStatusIndicator(for: group, form: form)

        let itemStyle: TextStyle = isSelected ? .accent : .secondary
        return Text("\(statusIndicator) \(group.name ?? "Unknown")").styled(itemStyle)
            .padding(EdgeInsets(top: 0, leading: Self.itemIndent, bottom: 0, trailing: 0))
    }

    private static func getStatusIndicator(for group: SecurityGroup, form: SecurityGroupManagementForm) -> String {
        let isAttached = form.serverSecurityGroups.contains { $0.id == group.id }
        let isPendingAdd = form.pendingAdditions.contains(group.id)
        let isPendingRemove = form.pendingRemovals.contains(group.id)

        if isPendingAdd {
            return Self.statusPendingAdd
        } else if isPendingRemove {
            return Self.statusPendingRemove
        } else if isAttached {
            return Self.statusAttached
        } else {
            return Self.statusNotAttached
        }
    }

    private static func createPendingChangesComponent(form: SecurityGroupManagementForm) -> any Component {
        var changeText = Self.pendingChangesPrefix
        if !form.pendingAdditions.isEmpty {
            changeText += "\(Self.pendingChangesAddPrefix)\(form.pendingAdditions.count) "
        }
        if !form.pendingRemovals.isEmpty {
            changeText += "\(Self.pendingChangesRemovePrefix)\(form.pendingRemovals.count) "
        }
        changeText += Self.pendingChangesSuffix

        return Text(changeText).warning()
            .padding(EdgeInsets(top: Self.pendingChangesTopPadding, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Security Group Rule Management

    // Layout Constants
    private static let sgRuleMgmtComponentTopPadding: Int32 = 1
    private static let sgRuleMgmtStatusMessageTopPadding: Int32 = 2
    private static let sgRuleMgmtStatusMessageLeadingPadding: Int32 = 2
    private static let sgRuleMgmtValidationErrorLeadingPadding: Int32 = 2
    private static let sgRuleMgmtLoadingErrorBoundsHeight: Int32 = 6
    private static let sgRuleMgmtFieldActiveSpacing = "                      "

    // Text Constants
    private static let sgRuleMgmtListTitle = "Security Group Rules"
    private static let sgRuleMgmtCreateTitle = "Create Security Group Rule"
    private static let sgRuleMgmtEditTitle = "Edit Security Group Rule"
    private static let sgRuleMgmtCreatingText = "Creating rule..."
    private static let sgRuleMgmtErrorPrefix = "Error: "
    private static let sgRuleMgmtRequiredFieldSuffix = ": *"
    private static let sgRuleMgmtOptionalFieldSuffix = " (optional)"

    // Field Display Constants
    private static let sgRuleMgmtValidationErrorsTitle = "Validation Errors:"
    private static let sgRuleMgmtValidationErrorPrefix = "- "
    private static let sgRuleMgmtEditPromptText = "Press SPACE to edit..."
    private static let sgRuleMgmtTableHeader = "DIR    PROTO   PORTS           REMOTE"
    private static let sgRuleMgmtTableSeparator = String(repeating: "-", count: 42)

    // Help Text Constants
    private static let sgRuleMgmtListHelpText = "UP/DOWN: navigate | SPACE: edit rule | A: add rule | DEL: delete | ESC: back"
    private static let sgRuleMgmtCreateHelpText = "UP/DOWN: navigate fields | SPACE: edit/select | ENTER: create | ESC: cancel"
    private static let sgRuleMgmtEditHelpText = "UP/DOWN: navigate fields | SPACE: edit/select | ENTER: save | ESC: cancel"

    // UI Component Constants
    private static let sgRuleMgmtSelectedIndicator = "> "
    private static let sgRuleMgmtUnselectedIndicator = "  "
    private static let sgRuleMgmtComponentSpacing: Int32 = 0

    @MainActor
    static func drawSecurityGroupRuleManagement(screen: OpaquePointer?, startRow: Int32, startCol: Int32,
                                               width: Int32, height: Int32, form: SecurityGroupRuleManagementForm,
                                               cachedSecurityGroups: [SecurityGroup] = []) async {

        // Defensive bounds checking to prevent crashes on small terminals
        guard width > 10 && height > 10 else {
            let surface = SwiftTUI.surface(from: screen)
            let errorBounds = Rect(x: max(0, startCol), y: max(0, startRow), width: max(1, width), height: max(1, height))
            await SwiftTUI.render(Text("Screen too small").error(), on: surface, in: errorBounds)
            return
        }

        // Main Security Group Rule Management
        let surface = SwiftTUI.surface(from: screen)
        var components: [any Component] = []

        // Title based on current mode
        let titleText = getSGRuleMgmtTitle(for: form)
        components.append(Text(titleText).emphasis().bold())

        // Content based on current mode
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)

        if form.shouldShowRulesList() {
            // Render FormSelector for rule list
            let selector = createSGRuleMgmtListComponents(form: form, width: width, height: height)
            surface.clear(rect: bounds)
            await SwiftTUI.render(selector.render(), on: surface, in: bounds)
        } else if form.shouldShowCreateForm() || form.shouldShowEditForm() {
            // Check if a selector field is active
            if let currentField = form.ruleCreateFormState.getCurrentField(),
               case .selector(let selectorField) = currentField,
               selectorField.isActive {
                // Render full-screen FormSelector overlay
                if let selectorComponent = FormSelectorRenderer.renderSelector(
                    label: selectorField.label,
                    items: selectorField.items,
                    selectedItemId: selectorField.selectedItemId,
                    highlightedIndex: selectorField.highlightedIndex,
                    scrollOffset: selectorField.scrollOffset,
                    searchQuery: selectorField.searchQuery,
                    columns: selectorField.columns,
                    maxHeight: Int(height)
                ) {
                    surface.clear(rect: bounds)
                    await SwiftTUI.render(selectorComponent, on: surface, in: bounds)
                }
            } else {
                // Render create/edit form with FormBuilder
                let titleText = getSGRuleMgmtTitle(for: form)

                // Build form fields
                let fields = form.ruleCreateForm.buildFields(
                    selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                    activeFieldId: form.ruleCreateFormState.getActiveFieldId(),
                    formState: form.ruleCreateFormState
                )

                // Create FormBuilder
                let formBuilder = FormBuilder(
                    title: titleText,
                    fields: fields,
                    selectedFieldId: form.ruleCreateFormState.getCurrentFieldId(),
                    validationErrors: form.ruleCreateForm.validateForm().errors,
                    showValidationErrors: form.ruleCreateFormState.showValidationErrors
                )

                // Render the form
                surface.clear(rect: bounds)
                await SwiftTUI.render(formBuilder.render(), on: surface, in: bounds)
            }
        }
    }

    // MARK: - Component Creation Functions

    private static func getSGRuleMgmtTitle(for form: SecurityGroupRuleManagementForm) -> String {
        if form.shouldShowCreateForm() {
            return "\(Self.sgRuleMgmtCreateTitle) - \(form.securityGroup.name ?? "Unknown")"
        } else if form.shouldShowEditForm() {
            return "\(Self.sgRuleMgmtEditTitle) - \(form.securityGroup.name ?? "Unknown")"
        } else {
            return "\(Self.sgRuleMgmtListTitle) (\(form.securityGroup.securityGroupRules?.count ?? 0)) - \(form.securityGroup.name ?? "Unknown")"
        }
    }

    private static func getSGRuleMgmtHelpText(for form: SecurityGroupRuleManagementForm) -> String {
        if form.shouldShowCreateForm() {
            return Self.sgRuleMgmtCreateHelpText
        } else if form.shouldShowEditForm() {
            return Self.sgRuleMgmtEditHelpText
        } else {
            return Self.sgRuleMgmtListHelpText
        }
    }

    private static func createSGRuleMgmtListComponents(form: SecurityGroupRuleManagementForm, width: Int32, height: Int32) -> FormSelector<SecurityGroupRule> {
        // Create FormSelector columns
        let dirColumn = FormSelectorColumn<SecurityGroupRule>(
            header: "DIR",
            width: 8
        ) { rule in
            rule.direction.uppercased()
        }

        let protocolColumn = FormSelectorColumn<SecurityGroupRule>(
            header: "PROTOCOL",
            width: 10
        ) { rule in
            rule.protocolEnum?.rawValue.uppercased() ?? "ANY"
        }

        let portsColumn = FormSelectorColumn<SecurityGroupRule>(
            header: "PORTS",
            width: 15
        ) { rule in
            formatPortRange(rule)
        }

        let ethertypeColumn = FormSelectorColumn<SecurityGroupRule>(
            header: "ETHERTYPE",
            width: 10
        ) { rule in
            rule.ethertype ?? "IPv4"
        }

        let remoteColumn = FormSelectorColumn<SecurityGroupRule>(
            header: "REMOTE",
            width: 25
        ) { rule in
            formatRemoteDescription(rule)
        }

        let columns = [dirColumn, protocolColumn, portsColumn, ethertypeColumn, remoteColumn]

        let tab = FormSelectorTab<SecurityGroupRule>(
            title: "Security Group Rules",
            columns: columns
        )

        let rules = form.securityGroup.securityGroupRules ?? []

        return FormSelector<SecurityGroupRule>(
            label: "Security Group Rules (\(rules.count))",
            tabs: [tab],
            selectedTabIndex: 0,
            items: rules,
            selectedItemIds: form.selectedRuleIds,
            highlightedIndex: form.highlightedRuleIndex,
            multiSelect: false,
            scrollOffset: form.ruleScrollOffset,
            searchQuery: form.ruleSearchQuery,
            maxHeight: Int(height),
            isActive: true
        )
    }

    private static func createSGRuleMgmtFormComponents(form: SecurityGroupRuleManagementForm, cachedSecurityGroups: [SecurityGroup], width: Int32) -> [any Component] {
        var components: [any Component] = []

        // Since we're following gold standard, we integrate the rule create/edit form directly here
        // Build all form fields as components using the rule create form
        let ruleForm = form.ruleCreateForm
        let visibleFields = getSGRuleCreateVisibleFields(for: ruleForm)

        for (index, field) in visibleFields.enumerated() {
            let isFirstField = index == 0
            let fieldComponent = createSGRuleCreateFieldComponent(field: field, form: ruleForm, width: width, isFirstField: isFirstField)
            components.append(fieldComponent)
        }

        // Show validation errors if any
        let validation = ruleForm.validateForm()
        if !validation.isValid {
            components.append(Text(Self.sgRuleCreateValidationErrorsTitle).error().bold()
                .padding(EdgeInsets(top: Self.sgRuleMgmtComponentTopPadding, leading: 0, bottom: 0, trailing: 0)))

            for error in validation.errors {
                components.append(Text("\(Self.sgRuleCreateValidationErrorPrefix)\(error)").error()
                    .padding(EdgeInsets(top: 0, leading: Self.sgRuleCreateValidationErrorLeadingPadding, bottom: 0, trailing: 0)))
            }
        }

        return components
    }

}