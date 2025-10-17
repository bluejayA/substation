import Foundation
import OSClient
import SwiftNCurses

/// Helper to render FormSelector for different OSClient types
/// This works around Swift's generic limitations when dealing with existential types
struct FormSelectorRenderer {

    /// Render a FormSelector for any FormSelectorItem type
    /// Returns nil if the type cannot be rendered with FormSelector
    static func renderSelector(
        label: String,
        items: [any FormSelectorItem],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> (any Component)? {
        // Try to cast to specific types and render with FormSelector
        if let images = items as? [Image] {
            return renderImageSelector(
                label: label,
                items: images,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let volumes = items as? [Volume] {
            return renderVolumeSelector(
                label: label,
                items: volumes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let flavors = items as? [Flavor] {
            return renderFlavorSelector(
                label: label,
                items: flavors,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let networks = items as? [Network] {
            return renderNetworkSelector(
                label: label,
                items: networks,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let securityGroups = items as? [SecurityGroup] {
            return renderSecurityGroupSelector(
                label: label,
                items: securityGroups,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let keyPairs = items as? [KeyPair] {
            return renderKeyPairSelector(
                label: label,
                items: keyPairs,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let serverGroups = items as? [ServerGroup] {
            return renderServerGroupSelector(
                label: label,
                items: serverGroups,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let directions = items as? [SecurityGroupDirection] {
            return renderSecurityGroupDirectionSelector(
                label: label,
                items: directions,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let protocols = items as? [SecurityGroupProtocol] {
            return renderSecurityGroupProtocolSelector(
                label: label,
                items: protocols,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let ethertypes = items as? [SecurityGroupEtherType] {
            return renderSecurityGroupEtherTypeSelector(
                label: label,
                items: ethertypes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let portTypes = items as? [SecurityGroupPortType] {
            return renderSecurityGroupPortTypeSelector(
                label: label,
                items: portTypes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let remoteTypes = items as? [SecurityGroupRemoteType] {
            return renderSecurityGroupRemoteTypeSelector(
                label: label,
                items: remoteTypes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let portTypes = items as? [PortType] {
            return renderPortTypeSelector(
                label: label,
                items: portTypes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let azItems = items as? [AvailabilityZoneItem] {
            return renderAvailabilityZoneSelector(
                label: label,
                items: azItems,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let creationTypes = items as? [KeyPairCreationType] {
            return renderKeyPairCreationTypeSelector(
                label: label,
                items: creationTypes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let policies = items as? [ServerGroupPolicy] {
            return renderServerGroupPolicySelector(
                label: label,
                items: policies,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let contentTypes = items as? [SecretPayloadContentType] {
            return renderSecretPayloadContentTypeSelector(
                label: label,
                items: contentTypes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let encodings = items as? [SecretPayloadContentEncoding] {
            return renderSecretPayloadContentEncodingSelector(
                label: label,
                items: encodings,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let secretTypes = items as? [SecretType] {
            return renderSecretTypeSelector(
                label: label,
                items: secretTypes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let algorithms = items as? [SecretAlgorithm] {
            return renderSecretAlgorithmSelector(
                label: label,
                items: algorithms,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let modes = items as? [SecretMode] {
            return renderSecretModeSelector(
                label: label,
                items: modes,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let bitLengths = items as? [BitLengthOption] {
            return renderBitLengthOptionSelector(
                label: label,
                items: bitLengths,
                selectedItemId: selectedItemId,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        }

        // Default: return nil for unsupported types
        return nil
    }

    private static func renderAvailabilityZoneSelector(
        label: String,
        items: [AvailabilityZoneItem],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<AvailabilityZoneItem>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<AvailabilityZoneItem>(
            title: label,
            columns: selectorColumns
        )

        let selector = FormSelector<AvailabilityZoneItem>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    /// Render a multi-select FormSelector for any FormSelectorItem type
    static func renderMultiSelector(
        label: String,
        items: [any FormSelectorItem],
        selectedItemIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> (any Component)? {
        // Try to cast to specific types and render with FormSelector in multi-select mode
        if let networks = items as? [Network] {
            return renderNetworkMultiSelector(
                label: label,
                items: networks,
                selectedItemIds: selectedItemIds,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        } else if let securityGroups = items as? [SecurityGroup] {
            return renderSecurityGroupMultiSelector(
                label: label,
                items: securityGroups,
                selectedItemIds: selectedItemIds,
                highlightedIndex: highlightedIndex,
                scrollOffset: scrollOffset,
                searchQuery: searchQuery,
                columns: columns,
                maxHeight: maxHeight
            )
        }

        return nil
    }

    // MARK: - Single Select Renderers

    private static func renderImageSelector(
        label: String,
        items: [Image],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<Image>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<Image>(
            title: "Images",
            columns: selectorColumns
        )

        let selector = FormSelector<Image>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderVolumeSelector(
        label: String,
        items: [Volume],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<Volume>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<Volume>(
            title: "Volumes",
            columns: selectorColumns
        )

        let selector = FormSelector<Volume>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderFlavorSelector(
        label: String,
        items: [Flavor],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<Flavor>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<Flavor>(
            title: "Flavors",
            columns: selectorColumns
        )

        let selector = FormSelector<Flavor>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderNetworkSelector(
        label: String,
        items: [Network],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<Network>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<Network>(
            title: "Networks",
            columns: selectorColumns
        )

        let selector = FormSelector<Network>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecurityGroupSelector(
        label: String,
        items: [SecurityGroup],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecurityGroup>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecurityGroup>(
            title: "Security Groups",
            columns: selectorColumns
        )

        let selector = FormSelector<SecurityGroup>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderKeyPairSelector(
        label: String,
        items: [KeyPair],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<KeyPair>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<KeyPair>(
            title: "Key Pairs",
            columns: selectorColumns
        )

        let selector = FormSelector<KeyPair>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderServerGroupSelector(
        label: String,
        items: [ServerGroup],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<ServerGroup>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<ServerGroup>(
            title: "Server Groups",
            columns: selectorColumns
        )

        let selector = FormSelector<ServerGroup>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderServerGroupPolicySelector(
        label: String,
        items: [ServerGroupPolicy],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<ServerGroupPolicy>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<ServerGroupPolicy>(
            title: "Policies",
            columns: selectorColumns
        )

        let selector = FormSelector<ServerGroupPolicy>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecurityGroupDirectionSelector(
        label: String,
        items: [SecurityGroupDirection],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecurityGroupDirection>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecurityGroupDirection>(
            title: "Direction",
            columns: selectorColumns
        )

        let selector = FormSelector<SecurityGroupDirection>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecurityGroupProtocolSelector(
        label: String,
        items: [SecurityGroupProtocol],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecurityGroupProtocol>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecurityGroupProtocol>(
            title: "Protocol",
            columns: selectorColumns
        )

        let selector = FormSelector<SecurityGroupProtocol>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecurityGroupEtherTypeSelector(
        label: String,
        items: [SecurityGroupEtherType],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecurityGroupEtherType>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecurityGroupEtherType>(
            title: "Ether Type",
            columns: selectorColumns
        )

        let selector = FormSelector<SecurityGroupEtherType>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecurityGroupPortTypeSelector(
        label: String,
        items: [SecurityGroupPortType],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecurityGroupPortType>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecurityGroupPortType>(
            title: "Port Configuration",
            columns: selectorColumns
        )

        let selector = FormSelector<SecurityGroupPortType>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecurityGroupRemoteTypeSelector(
        label: String,
        items: [SecurityGroupRemoteType],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecurityGroupRemoteType>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecurityGroupRemoteType>(
            title: "Remote",
            columns: selectorColumns
        )

        let selector = FormSelector<SecurityGroupRemoteType>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderPortTypeSelector(
        label: String,
        items: [PortType],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<PortType>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<PortType>(
            title: "Port Type",
            columns: selectorColumns
        )

        let selector = FormSelector<PortType>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    // MARK: - Multi Select Renderers

    private static func renderNetworkMultiSelector(
        label: String,
        items: [Network],
        selectedItemIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<Network>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<Network>(
            title: "Networks",
            columns: selectorColumns
        )

        let selector = FormSelector<Network>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemIds,
            highlightedIndex: highlightedIndex,
            checkboxMode: .multiSelect,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecurityGroupMultiSelector(
        label: String,
        items: [SecurityGroup],
        selectedItemIds: Set<String>,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecurityGroup>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecurityGroup>(
            title: "Security Groups",
            columns: selectorColumns
        )

        let selector = FormSelector<SecurityGroup>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemIds,
            highlightedIndex: highlightedIndex,
            checkboxMode: .multiSelect,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderKeyPairCreationTypeSelector(
        label: String,
        items: [KeyPairCreationType],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectedItemIds: Set<String> = selectedItemId.map { Set([$0]) } ?? []

        // Convert FormSelectorItemColumn to FormSelectorColumn
        var selectorColumns: [FormSelectorColumn<KeyPairCreationType>] = []
        for column in columns {
            selectorColumns.append(
                FormSelectorColumn<KeyPairCreationType>(
                    header: column.header,
                    width: column.width,
                    getValue: { column.getValue($0) }
                )
            )
        }

        let tab = FormSelectorTab<KeyPairCreationType>(
            title: label,
            columns: selectorColumns
        )

        let selector = FormSelector<KeyPairCreationType>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemIds,
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    // MARK: - Barbican Enum Renderers

    private static func renderSecretPayloadContentTypeSelector(
        label: String,
        items: [SecretPayloadContentType],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecretPayloadContentType>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecretPayloadContentType>(
            title: "Content Types",
            columns: selectorColumns
        )

        let selector = FormSelector<SecretPayloadContentType>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecretPayloadContentEncodingSelector(
        label: String,
        items: [SecretPayloadContentEncoding],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecretPayloadContentEncoding>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecretPayloadContentEncoding>(
            title: "Encodings",
            columns: selectorColumns
        )

        let selector = FormSelector<SecretPayloadContentEncoding>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecretTypeSelector(
        label: String,
        items: [SecretType],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecretType>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecretType>(
            title: "Secret Types",
            columns: selectorColumns
        )

        let selector = FormSelector<SecretType>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecretAlgorithmSelector(
        label: String,
        items: [SecretAlgorithm],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecretAlgorithm>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecretAlgorithm>(
            title: "Algorithms",
            columns: selectorColumns
        )

        let selector = FormSelector<SecretAlgorithm>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderSecretModeSelector(
        label: String,
        items: [SecretMode],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<SecretMode>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<SecretMode>(
            title: "Modes",
            columns: selectorColumns
        )

        let selector = FormSelector<SecretMode>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }

    private static func renderBitLengthOptionSelector(
        label: String,
        items: [BitLengthOption],
        selectedItemId: String?,
        highlightedIndex: Int,
        scrollOffset: Int,
        searchQuery: String?,
        columns: [FormSelectorItemColumn],
        maxHeight: Int?
    ) -> any Component {
        let selectorColumns = columns.map { column in
            FormSelectorColumn<BitLengthOption>(
                header: column.header,
                width: column.width,
                getValue: { column.getValue($0) }
            )
        }

        let tab = FormSelectorTab<BitLengthOption>(
            title: "Bit Lengths",
            columns: selectorColumns
        )

        let selector = FormSelector<BitLengthOption>(
            label: label,
            tabs: [tab],
            selectedTabIndex: 0,
            items: items,
            selectedItemIds: selectedItemId.map { Set([$0]) } ?? [],
            highlightedIndex: highlightedIndex,
            checkboxMode: .basic,
            scrollOffset: scrollOffset,
            searchQuery: searchQuery,
            maxHeight: maxHeight,
            isActive: true
        )

        return selector.render()
    }
}
