// Sources/Substation/Modules/Magnum/TUI+MagnumFormState.swift
import Foundation
import OSClient

/// Container for Magnum module form state variables
///
/// This struct encapsulates all form state for the Magnum module,
/// reducing the number of properties stored directly in the TUI class.
struct MagnumFormState {
    // MARK: - Cluster Creation

    /// Form state for cluster creation
    var createFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Form data for cluster creation
    var createForm: ClusterCreateForm = ClusterCreateForm()

    // MARK: - Cluster Resize

    /// Form state for cluster resize operation
    var resizeFormState: ClusterResizeFormState?

    // MARK: - Cluster Template Creation

    /// Form state for cluster template creation
    var templateCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Form data for cluster template creation
    var templateCreateForm: ClusterTemplateCreateForm = ClusterTemplateCreateForm()
}

// MARK: - Cluster Resize Form State

/// State for cluster resize form
///
/// Tracks the current cluster being resized and the new node count.
@MainActor
class ClusterResizeFormState {
    /// UUID of the cluster being resized
    let clusterUUID: String

    /// Name of the cluster being resized
    let clusterName: String

    /// Current number of worker nodes
    let currentNodeCount: Int

    /// New number of worker nodes
    var newNodeCount: Int

    /// Whether resize operation is being submitted
    var isSubmitting: Bool = false

    /// Error message if resize failed
    var errorMessage: String?

    /// Minimum allowed node count
    let minNodeCount: Int = 1

    /// Maximum allowed node count
    let maxNodeCount: Int = 100

    /// Whether the new node count differs from current
    var needsResize: Bool {
        newNodeCount != currentNodeCount
    }

    /// Initialize resize form state
    init(clusterUUID: String, clusterName: String, currentNodeCount: Int) {
        self.clusterUUID = clusterUUID
        self.clusterName = clusterName
        self.currentNodeCount = currentNodeCount
        self.newNodeCount = currentNodeCount
    }

    /// Increment node count
    func incrementNodes() {
        if newNodeCount < maxNodeCount {
            newNodeCount += 1
        }
    }

    /// Decrement node count
    func decrementNodes() {
        if newNodeCount > minNodeCount {
            newNodeCount -= 1
        }
    }
}

// MARK: - TUI Extension for Magnum Form State Accessors

/// TUI extension providing computed property accessors for Magnum module form state
///
/// These accessors retrieve form state from the MagnumModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Magnum module from registry
    private var magnumModule: MagnumModule? {
        return ModuleRegistry.shared.module(for: "magnum") as? MagnumModule
    }

    // MARK: - Cluster Creation Accessors

    /// State for cluster create form
    internal var clusterCreateFormState: FormBuilderState {
        get { return magnumModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { magnumModule?.formState.createFormState = newValue }
    }

    /// Form data for cluster creation
    internal var clusterCreateForm: ClusterCreateForm {
        get { return magnumModule?.formState.createForm ?? ClusterCreateForm() }
        set { magnumModule?.formState.createForm = newValue }
    }

    // MARK: - Cluster Resize Accessors

    /// State for cluster resize form
    internal var clusterResizeFormState: ClusterResizeFormState? {
        get { return magnumModule?.formState.resizeFormState }
        set { magnumModule?.formState.resizeFormState = newValue }
    }

    // MARK: - Cluster Template Creation Accessors

    /// State for cluster template create form
    internal var clusterTemplateCreateFormState: FormBuilderState {
        get { return magnumModule?.formState.templateCreateFormState ?? FormBuilderState(fields: []) }
        set { magnumModule?.formState.templateCreateFormState = newValue }
    }

    /// Form data for cluster template creation
    internal var clusterTemplateCreateForm: ClusterTemplateCreateForm {
        get { return magnumModule?.formState.templateCreateForm ?? ClusterTemplateCreateForm() }
        set { magnumModule?.formState.templateCreateForm = newValue }
    }

    /// Initialize the cluster create form with template selection
    ///
    /// Sets up the form fields for creating a new cluster.
    ///
    /// - Returns: The initialized FormBuilderState
    func initializeClusterCreateForm() -> FormBuilderState {
        // Create form with cached data
        var form = ClusterCreateForm()
        form.templates = cacheManager.cachedClusterTemplates
        form.keypairs = cacheManager.cachedKeyPairs

        // Set default selections if available
        form.selectedTemplateId = form.templates.first?.uuid
        form.selectedKeypairId = form.keypairs.first?.id

        // Store the form
        clusterCreateForm = form

        // Build initial fields and create state
        let fields = form.buildFields(
            selectedFieldId: ClusterCreateFieldId.name.rawValue,
            activeFieldId: nil,
            formState: nil
        )

        let state = FormBuilderState(fields: fields)
        clusterCreateFormState = state
        return state
    }

    /// Initialize the cluster template create form
    ///
    /// Sets up the form data and state for creating a new cluster template.
    ///
    /// - Returns: The initialized FormBuilderState
    func initializeClusterTemplateCreateForm() -> FormBuilderState {
        // Create form with cached data
        var form = ClusterTemplateCreateForm()
        form.images = cacheManager.cachedImages
        form.flavors = cacheManager.cachedFlavors
        form.networks = cacheManager.cachedNetworks
        form.keypairs = cacheManager.cachedKeyPairs

        // Set default selections if available
        form.selectedImageId = form.images.first?.id
        let externalNetworks = form.networks.filter { $0.isExternal == true }
        form.selectedExternalNetworkId = externalNetworks.first?.id
        form.selectedFlavorId = form.flavors.first?.id
        form.selectedMasterFlavorId = form.flavors.first?.id
        form.selectedKeypairId = form.keypairs.first?.id

        // Store the form
        clusterTemplateCreateForm = form

        // Build initial fields and create state
        let fields = form.buildFields(
            selectedFieldId: ClusterTemplateCreateFieldId.name.rawValue,
            activeFieldId: nil,
            formState: nil
        )

        let state = FormBuilderState(fields: fields)
        clusterTemplateCreateFormState = state
        return state
    }
}

// MARK: - COE Option for Select Field

/// Container Orchestration Engine option for form select
struct COEOption {
    let id: String
    let displayName: String
    let description: String

    /// Convert to FormSelectOption for use in select fields
    var asSelectOption: FormSelectOption {
        FormSelectOption(id: id, title: displayName, description: description)
    }

    static let kubernetes = COEOption(
        id: "kubernetes",
        displayName: "Kubernetes",
        description: "Production-grade container orchestration"
    )

    static let swarm = COEOption(
        id: "swarm",
        displayName: "Docker Swarm",
        description: "Native Docker clustering"
    )

    static let allOptions: [COEOption] = [kubernetes, swarm]

    /// All cases as FormSelectOptions for select field
    static var allSelectOptions: [FormSelectOption] {
        allOptions.map { $0.asSelectOption }
    }
}

// MARK: - Network Driver Option for Select Field

/// Network driver option for form select
struct NetworkDriverOption {
    let id: String
    let displayName: String
    let description: String

    /// Convert to FormSelectOption for use in select fields
    var asSelectOption: FormSelectOption {
        FormSelectOption(id: id, title: displayName, description: description)
    }

    static let flannel = NetworkDriverOption(
        id: "flannel",
        displayName: "Flannel",
        description: "Simple overlay network for Kubernetes"
    )

    static let calico = NetworkDriverOption(
        id: "calico",
        displayName: "Calico",
        description: "Network policy and security for Kubernetes"
    )

    static let allOptions: [NetworkDriverOption] = [flannel, calico]

    /// All cases as FormSelectOptions for select field
    static var allSelectOptions: [FormSelectOption] {
        allOptions.map { $0.asSelectOption }
    }
}
