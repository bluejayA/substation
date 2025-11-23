// Sources/Substation/Modules/Networks/TUI+NetworksFormState.swift
import Foundation

/// Container for Networks module form state variables
///
/// This struct encapsulates all form state for the Networks module,
/// reducing the number of properties stored directly in the TUI class.
struct NetworksFormState {
    // MARK: - Network Creation

    /// Form for creating new networks
    var createForm = NetworkCreateForm()

    /// State for network create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Network Interface Management

    /// Form for managing network interfaces
    var interfaceForm = NetworkInterfaceManagementForm()
}

// MARK: - TUI Extension for Networks Form State Accessors

/// TUI extension providing computed property accessors for Networks module form state
///
/// These accessors retrieve form state from the NetworksModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Networks module from registry
    private var networksModule: NetworksModule? {
        return ModuleRegistry.shared.module(for: "networks") as? NetworksModule
    }

    // MARK: - Network Creation Accessors

    /// Form for creating new networks
    internal var networkCreateForm: NetworkCreateForm {
        get { return networksModule?.formState.createForm ?? NetworkCreateForm() }
        set { networksModule?.formState.createForm = newValue }
    }

    /// State for network create form
    internal var networkCreateFormState: FormBuilderState {
        get { return networksModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { networksModule?.formState.createFormState = newValue }
    }

    // MARK: - Network Interface Management Accessors

    /// Form for managing network interfaces
    internal var networkInterfaceForm: NetworkInterfaceManagementForm {
        get { return networksModule?.formState.interfaceForm ?? NetworkInterfaceManagementForm() }
        set { networksModule?.formState.interfaceForm = newValue }
    }
}
