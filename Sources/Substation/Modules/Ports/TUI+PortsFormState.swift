// Sources/Substation/Modules/Ports/TUI+PortsFormState.swift
import Foundation

/// Container for Ports module form state variables
///
/// This struct encapsulates all form state for the Ports module,
/// reducing the number of properties stored directly in the TUI class.
struct PortsFormState {
    // MARK: - Port Creation

    /// Form for creating new ports
    var createForm = PortCreateForm()

    /// State for port create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Allowed Address Pair Management

    /// Form for managing allowed address pairs
    var allowedAddressPairForm: AllowedAddressPairManagementForm?
}

// MARK: - TUI Extension for Ports Form State Accessors

/// TUI extension providing computed property accessors for Ports module form state
///
/// These accessors retrieve form state from the PortsModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Ports module from registry
    private var portsModule: PortsModule? {
        return ModuleRegistry.shared.module(for: "ports") as? PortsModule
    }

    // MARK: - Port Creation Accessors

    /// Form for creating new ports
    internal var portCreateForm: PortCreateForm {
        get { return portsModule?.formState.createForm ?? PortCreateForm() }
        set { portsModule?.formState.createForm = newValue }
    }

    /// State for port create form
    internal var portCreateFormState: FormBuilderState {
        get { return portsModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { portsModule?.formState.createFormState = newValue }
    }

    // MARK: - Allowed Address Pair Management Accessors

    /// Form for managing allowed address pairs
    internal var allowedAddressPairForm: AllowedAddressPairManagementForm? {
        get { return portsModule?.formState.allowedAddressPairForm }
        set { portsModule?.formState.allowedAddressPairForm = newValue }
    }
}
