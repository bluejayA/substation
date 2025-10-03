import Foundation
import OSClient

/// Boot source type for server creation
enum BootSource: String, CaseIterable {
    case image
    case volume
}

/// Flavor selection mode for server creation
enum FlavorSelectionMode: String, CaseIterable {
    case manual
    case workloadBased
}

/// Field identifiers for ServerCreate FormBuilder
enum ServerCreateFieldId: String, CaseIterable {
    case name = "name"
    case source = "source"
    case flavor = "flavor"
    case network = "network"
    case securityGroup = "securityGroup"
    case serverGroup = "serverGroup"
    case keyPair = "keyPair"

    var title: String {
        switch self {
        case .name:
            return "Server Name"
        case .source:
            return "Source"
        case .flavor:
            return "Flavor"
        case .network:
            return "Networks"
        case .securityGroup:
            return "Security Groups"
        case .serverGroup:
            return "Server Group"
        case .keyPair:
            return "SSH Key Pair"
        }
    }
}

/// ServerCreateForm using FormBuilder architecture
/// This replaces the old manual form implementation with the unified FormBuilder component
struct ServerCreateForm {
    // MARK: - Constants

    private static let serverNamePlaceholder = "Enter server name"
    private static let serverNameRequiredError = "Server name is required"
    private static let imageSelectionRequiredError = "Image selection is required"
    private static let volumeSelectionRequiredError = "Volume selection is required"
    private static let flavorSelectionRequiredError = "Flavor selection is required"
    private static let networkSelectionRequiredError = "At least one network is required"

    // MARK: - Properties

    var serverName: String = ""
    var bootSource: BootSource = .image

    // Source selection (images and volumes)
    var selectedImageID: String? = nil
    var selectedVolumeID: String? = nil

    // Flavor selection
    var selectedFlavorID: String? = nil
    var flavorSelectionMode: FlavorSelectionMode = .manual
    var workloadType: WorkloadType = .balanced
    var flavorRecommendations: [FlavorRecommendation] = []
    var selectedRecommendationIndex: Int = 0
    var selectedCategoryIndex: Int? = nil
    var optimizationBudget: Budget? = nil

    // Network and security
    var selectedNetworks: Set<String> = []
    var selectedSecurityGroups: Set<String> = []

    // Optional selections
    var selectedKeyPairName: String? = nil
    var selectedServerGroupID: String? = nil

    // Form state
    var errorMessage: String? = nil
    var isLoading: Bool = false

    // Cached data
    var images: [Image] = []
    var volumes: [Volume] = []
    var flavors: [Flavor] = []
    var networks: [Network] = []
    var securityGroups: [SecurityGroup] = []
    var keyPairs: [KeyPair] = []
    var serverGroups: [ServerGroup] = []

    // MARK: - Field Generation

    /// Generate FormField array for FormBuilder
    func buildFields(selectedFieldId: String?, activeFieldId: String? = nil, formState: FormBuilderState? = nil) -> [FormField] {
        var fields: [FormField] = []

        // Server Name (text field)
        let nameId = ServerCreateFieldId.name.rawValue
        fields.append(.text(FormFieldText(
            id: nameId,
            label: ServerCreateFieldId.name.title,
            value: serverName,
            placeholder: Self.serverNamePlaceholder,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == nameId,
            isActive: activeFieldId == nameId,
            cursorPosition: formState?.getTextFieldCursorPosition(nameId),
            validationError: getNameValidationError()
        )))

        // Boot Source (unified selector for image/volume with TAB switching in overlay)
        // Note: SourceSelectionView handles TAB to switch between image and volume modes
        // The collapsed field label shows current mode
        let sourceLabel = bootSource == .image ? "Boot Source (Image)" : "Boot Source (Volume)"
        let sourceValidationError = bootSource == .image ? getImageValidationError() : getVolumeValidationError()

        // Use a combined items list - SourceSelectionView will show both images and volumes with TAB switching
        // The collapsed summary shows based on current bootSource
        let combinedSourceItems: [any FormSelectorItem] = bootSource == .image
            ? images
            : getBootableVolumes()

        let selectedSourceId = bootSource == .image ? selectedImageID : selectedVolumeID

        fields.append(.selector(FormFieldSelector(
            id: ServerCreateFieldId.source.rawValue,
            label: sourceLabel,
            items: combinedSourceItems,
            selectedItemId: selectedSourceId,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ServerCreateFieldId.source.rawValue,
            isActive: activeFieldId == ServerCreateFieldId.source.rawValue,
            validationError: sourceValidationError,
            columns: [
                FormSelectorItemColumn(header: "Name", width: 40) { item in
                    if let image = item as? Image {
                        return image.name ?? "Unknown"
                    } else if let volume = item as? Volume {
                        return volume.name ?? "Unknown"
                    }
                    return "Unknown"
                },
                FormSelectorItemColumn(header: "Size", width: 10) { item in
                    if let image = item as? Image, let minDisk = image.minDisk, minDisk > 0 {
                        return "\(minDisk)GB"
                    } else if let volume = item as? Volume, let size = volume.size {
                        return "\(size)GB"
                    }
                    return ""
                }
            ]
        )))

        // Flavor (selector field)
        fields.append(.selector(FormFieldSelector(
            id: ServerCreateFieldId.flavor.rawValue,
            label: "Flavor",
            items: getFlavorsForSelection(),
            selectedItemId: selectedFlavorID,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ServerCreateFieldId.flavor.rawValue,
            isActive: activeFieldId == ServerCreateFieldId.flavor.rawValue,
            validationError: getFlavorValidationError(),
            columns: [
                FormSelectorItemColumn(header: "Name", width: 30) { item in
                    (item as? Flavor)?.name ?? "Unknown"
                },
                FormSelectorItemColumn(header: "vCPUs", width: 6) { item in
                    if let flavor = item as? Flavor {
                        return "\(flavor.vcpus)"
                    }
                    return ""
                },
                FormSelectorItemColumn(header: "RAM", width: 10) { item in
                    if let flavor = item as? Flavor {
                        return "\(flavor.ram)MB"
                    }
                    return ""
                },
                FormSelectorItemColumn(header: "Disk", width: 10) { item in
                    if let flavor = item as? Flavor {
                        return "\(flavor.disk)GB"
                    }
                    return ""
                }
            ]
        )))

        // Networks (multi-select field)
        fields.append(.multiSelect(FormFieldMultiSelect(
            id: ServerCreateFieldId.network.rawValue,
            label: ServerCreateFieldId.network.title,
            items: networks,
            selectedItemIds: selectedNetworks,
            isRequired: true,
            isVisible: true,
            isSelected: selectedFieldId == ServerCreateFieldId.network.rawValue,
            isActive: activeFieldId == ServerCreateFieldId.network.rawValue,
            validationError: getNetworkValidationError(),
            columns: [
                FormSelectorItemColumn(header: "Name", width: 35) { item in
                    (item as? Network)?.name ?? "Unknown"
                },
                FormSelectorItemColumn(header: "Status", width: 10) { item in
                    if let network = item as? Network {
                        let status = (network.adminStateUp ?? false) ? "UP" : "DOWN"
                        let ext = (network.external ?? false) ? " (Ext)" : ""
                        return status + ext
                    }
                    return ""
                }
            ],
            minSelections: 1
        )))

        // Security Groups (multi-select field, optional)
        fields.append(.multiSelect(FormFieldMultiSelect(
            id: ServerCreateFieldId.securityGroup.rawValue,
            label: ServerCreateFieldId.securityGroup.title,
            items: securityGroups,
            selectedItemIds: selectedSecurityGroups,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == ServerCreateFieldId.securityGroup.rawValue,
            isActive: activeFieldId == ServerCreateFieldId.securityGroup.rawValue,
            columns: [
                FormSelectorItemColumn(header: "Name", width: 40) { item in
                    (item as? SecurityGroup)?.name ?? "Unknown"
                }
            ]
        )))

        // Server Group (selector field, optional)
        fields.append(.selector(FormFieldSelector(
            id: ServerCreateFieldId.serverGroup.rawValue,
            label: ServerCreateFieldId.serverGroup.title,
            items: serverGroups,
            selectedItemId: selectedServerGroupID,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == ServerCreateFieldId.serverGroup.rawValue,
            isActive: activeFieldId == ServerCreateFieldId.serverGroup.rawValue,
            columns: [
                FormSelectorItemColumn(header: "Name", width: 30) { item in
                    (item as? ServerGroup)?.name ?? "Unknown"
                },
                FormSelectorItemColumn(header: "Policy", width: 15) { item in
                    if let group = item as? ServerGroup {
                        return group.primaryPolicy?.displayName ?? "Unknown"
                    }
                    return ""
                },
                FormSelectorItemColumn(header: "Members", width: 10) { item in
                    if let group = item as? ServerGroup {
                        return "\(group.members.count)"
                    }
                    return ""
                }
            ]
        )))

        // SSH Key Pair (selector field, optional)
        fields.append(.selector(FormFieldSelector(
            id: ServerCreateFieldId.keyPair.rawValue,
            label: ServerCreateFieldId.keyPair.title,
            items: keyPairs,
            selectedItemId: selectedKeyPairName,
            isRequired: false,
            isVisible: true,
            isSelected: selectedFieldId == ServerCreateFieldId.keyPair.rawValue,
            isActive: activeFieldId == ServerCreateFieldId.keyPair.rawValue,
            columns: [
                FormSelectorItemColumn(header: "Name", width: 40) { item in
                    (item as? KeyPair)?.name ?? "Unknown"
                }
            ]
        )))

        return fields
    }

    // MARK: - Validation

    private func getNameValidationError() -> String? {
        if serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Self.serverNameRequiredError
        }
        return nil
    }

    private func getImageValidationError() -> String? {
        guard bootSource == .image else { return nil }
        if images.isEmpty {
            return "No images available"
        }
        if selectedImageID == nil {
            return Self.imageSelectionRequiredError
        }
        if !images.contains(where: { $0.id == selectedImageID }) {
            return "Selected image is invalid"
        }
        return nil
    }

    private func getVolumeValidationError() -> String? {
        guard bootSource == .volume else { return nil }
        let bootableVolumes = getBootableVolumes()
        if bootableVolumes.isEmpty {
            return "No bootable volumes available"
        }
        if selectedVolumeID == nil {
            return Self.volumeSelectionRequiredError
        }
        if !bootableVolumes.contains(where: { $0.id == selectedVolumeID }) {
            return "Selected volume is invalid"
        }
        return nil
    }

    private func getFlavorValidationError() -> String? {
        if flavors.isEmpty {
            return "No flavors available"
        }
        if selectedFlavorID == nil {
            return Self.flavorSelectionRequiredError
        }
        if !flavors.contains(where: { $0.id == selectedFlavorID }) {
            return "Selected flavor is invalid"
        }
        return nil
    }

    private func getNetworkValidationError() -> String? {
        if networks.isEmpty {
            return nil // Auto-assign is acceptable
        }
        if selectedNetworks.isEmpty {
            return Self.networkSelectionRequiredError
        }
        if !selectedNetworks.allSatisfy({ networkID in
            networks.contains(where: { $0.id == networkID })
        }) {
            return "One or more selected networks are invalid"
        }
        return nil
    }

    func validate() -> [String] {
        var errors: [String] = []

        if let error = getNameValidationError() {
            errors.append(error)
        }

        if let error = getImageValidationError() {
            errors.append(error)
        }

        if let error = getVolumeValidationError() {
            errors.append(error)
        }

        if let error = getFlavorValidationError() {
            errors.append(error)
        }

        if let error = getNetworkValidationError() {
            errors.append(error)
        }

        return errors
    }

    func isValid() -> Bool {
        return validate().isEmpty
    }

    // MARK: - Helper Methods

    private func getBootableVolumes() -> [Volume] {
        return volumes.filter { $0.bootable?.lowercased() == "true" }
    }

    private func getFlavorsForSelection() -> [Flavor] {
        if flavorSelectionMode == .workloadBased && !flavorRecommendations.isEmpty {
            // Return recommended flavors
            return flavorRecommendations.map { $0.recommendedFlavor }
        }
        // Sort flavors alphabetically by name
        return flavors.sorted { lhs, rhs in
            (lhs.name ?? lhs.id).localizedCaseInsensitiveCompare(rhs.name ?? rhs.id) == .orderedAscending
        }
    }

    // MARK: - State Management

    mutating func updateFromFormState(_ formState: FormBuilderState) {
        // Update server name
        if let name = formState.getTextValue(ServerCreateFieldId.name.rawValue) {
            serverName = name
        }

        // Note: bootSource is now toggled directly via toggleBootSource() when TAB is pressed in source selector
        // No need to update from form state

        // Update workload type
        if let workloadId = formState.getSelectedOptionId("workloadType"),
           let workload = WorkloadType(rawValue: workloadId) {
            workloadType = workload
        }

        // Update source selection
        if bootSource == .image {
            selectedImageID = formState.getSelectorSelectedId(ServerCreateFieldId.source.rawValue)
            selectedVolumeID = nil
        } else {
            selectedVolumeID = formState.getSelectorSelectedId(ServerCreateFieldId.source.rawValue)
            selectedImageID = nil
        }

        // Update flavor selection
        selectedFlavorID = formState.getSelectorSelectedId(ServerCreateFieldId.flavor.rawValue)

        // Update network selection
        if let networks = formState.getMultiSelectSelectedIds(ServerCreateFieldId.network.rawValue) {
            selectedNetworks = networks
        }

        // Update security groups
        if let groups = formState.getMultiSelectSelectedIds(ServerCreateFieldId.securityGroup.rawValue) {
            selectedSecurityGroups = groups
        }

        // Update server group
        selectedServerGroupID = formState.getSelectorSelectedId(ServerCreateFieldId.serverGroup.rawValue)

        // Update key pair
        selectedKeyPairName = formState.getSelectorSelectedId(ServerCreateFieldId.keyPair.rawValue)
    }

    mutating func reset() {
        serverName = ""
        bootSource = .image
        selectedImageID = nil
        selectedVolumeID = nil
        selectedFlavorID = nil
        flavorSelectionMode = .manual
        workloadType = .balanced
        flavorRecommendations = []
        selectedNetworks.removeAll()
        selectedSecurityGroups.removeAll()
        selectedKeyPairName = nil
        selectedServerGroupID = nil
        errorMessage = nil
        isLoading = false
    }

    mutating func setError(_ message: String) {
        errorMessage = message
        isLoading = false
    }

    mutating func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
        }
    }

    mutating func toggleBootSource() {
        bootSource = bootSource == .image ? .volume : .image
        // Clear selections when switching
        selectedImageID = nil
        selectedVolumeID = nil
    }

    mutating func toggleFlavorSelectionMode() {
        flavorSelectionMode = flavorSelectionMode == .manual ? .workloadBased : .manual
        if flavorSelectionMode == .manual {
            flavorRecommendations = []
        }
        // Reset category selection when switching modes
        selectedCategoryIndex = nil
    }

    mutating func setFlavorRecommendations(_ recommendations: [FlavorRecommendation]) {
        flavorRecommendations = recommendations
        // Auto-select first recommendation if available
        if let first = recommendations.first {
            selectedFlavorID = first.recommendedFlavor.id
        }
    }

    mutating func clearFlavorRecommendations() {
        flavorRecommendations = []
        selectedRecommendationIndex = 0
    }

    mutating func exitFlavorSelection() {
        selectedCategoryIndex = nil
        selectedRecommendationIndex = 0
    }
}
