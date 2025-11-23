// Sources/Substation/Modules/Subnets/TUI+SubnetsFormState.swift
import Foundation

/// Container for Subnets module form state variables
///
/// This struct encapsulates all form state for the Subnets module,
/// reducing the number of properties stored directly in the TUI class.
struct SubnetsFormState {
    // MARK: - Subnet Creation

    /// Form for creating new subnets
    var createForm = SubnetCreateForm()

    /// State for subnet create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])
}

// MARK: - TUI Extension for Subnets Form State Accessors

/// TUI extension providing computed property accessors for Subnets module form state
///
/// These accessors retrieve form state from the SubnetsModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Subnets module from registry
    private var subnetsModule: SubnetsModule? {
        return ModuleRegistry.shared.module(for: "subnets") as? SubnetsModule
    }

    // MARK: - Subnet Creation Accessors

    /// Form for creating new subnets
    internal var subnetCreateForm: SubnetCreateForm {
        get { return subnetsModule?.formState.createForm ?? SubnetCreateForm() }
        set { subnetsModule?.formState.createForm = newValue }
    }

    /// State for subnet create form
    internal var subnetCreateFormState: FormBuilderState {
        get { return subnetsModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { subnetsModule?.formState.createFormState = newValue }
    }
}
