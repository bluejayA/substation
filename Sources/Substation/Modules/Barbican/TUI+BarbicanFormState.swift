// Sources/Substation/Modules/Barbican/TUI+BarbicanFormState.swift
import Foundation

/// Container for Barbican module form state variables
///
/// This struct encapsulates all form state for the Barbican (Key Management) module,
/// reducing the number of properties stored directly in the TUI class.
struct BarbicanFormState {
    // MARK: - Secret Creation

    /// Form for creating new Barbican secrets
    var secretCreateForm = BarbicanSecretCreateForm()

    /// State for Barbican secret create form
    var secretCreateFormState: FormBuilderState = FormBuilderState(fields: [])
}

// MARK: - TUI Extension for Barbican Form State Accessors

/// TUI extension providing computed property accessors for Barbican module form state
///
/// These accessors retrieve form state from the BarbicanModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Barbican module from registry
    private var barbicanModule: BarbicanModule? {
        return ModuleRegistry.shared.module(for: "barbican") as? BarbicanModule
    }

    // MARK: - Secret Creation Accessors

    /// Form for creating new Barbican secrets
    internal var barbicanSecretCreateForm: BarbicanSecretCreateForm {
        get { return barbicanModule?.formState.secretCreateForm ?? BarbicanSecretCreateForm() }
        set { barbicanModule?.formState.secretCreateForm = newValue }
    }

    /// State for Barbican secret create form
    internal var barbicanSecretCreateFormState: FormBuilderState {
        get { return barbicanModule?.formState.secretCreateFormState ?? FormBuilderState(fields: []) }
        set { barbicanModule?.formState.secretCreateFormState = newValue }
    }
}
