// Sources/Substation/Modules/KeyPairs/TUI+KeyPairsFormState.swift
import Foundation

/// Container for Key Pairs module form state variables
///
/// This struct encapsulates all form state for the Key Pairs module,
/// reducing the number of properties stored directly in the TUI class.
struct KeyPairsFormState {
    // MARK: - Key Pair Creation

    /// Form for creating new key pairs
    var createForm = KeyPairCreateForm()

    /// State for key pair create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])
}

// MARK: - TUI Extension for Key Pairs Form State Accessors

/// TUI extension providing computed property accessors for Key Pairs module form state
///
/// These accessors retrieve form state from the KeyPairsModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get KeyPairs module from registry
    private var keyPairsModule: KeyPairsModule? {
        return ModuleRegistry.shared.module(for: "keypairs") as? KeyPairsModule
    }

    // MARK: - Key Pair Creation Accessors

    /// Form for creating new key pairs
    internal var keyPairCreateForm: KeyPairCreateForm {
        get { return keyPairsModule?.formState.createForm ?? KeyPairCreateForm() }
        set { keyPairsModule?.formState.createForm = newValue }
    }

    /// State for key pair create form
    internal var keyPairCreateFormState: FormBuilderState {
        get { return keyPairsModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { keyPairsModule?.formState.createFormState = newValue }
    }
}
