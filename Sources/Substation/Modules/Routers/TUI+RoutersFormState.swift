// Sources/Substation/Modules/Routers/TUI+RoutersFormState.swift
import Foundation

/// Container for Routers module form state variables
///
/// This struct encapsulates all form state for the Routers module,
/// reducing the number of properties stored directly in the TUI class.
struct RoutersFormState {
    // MARK: - Router Creation

    /// Form for creating new routers
    var createForm = RouterCreateForm()

    /// State for router create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])
}

// MARK: - TUI Extension for Routers Form State Accessors

/// TUI extension providing computed property accessors for Routers module form state
///
/// These accessors retrieve form state from the RoutersModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Routers module from registry
    private var routersModule: RoutersModule? {
        return ModuleRegistry.shared.module(for: "routers") as? RoutersModule
    }

    // MARK: - Router Creation Accessors

    /// Form for creating new routers
    internal var routerCreateForm: RouterCreateForm {
        get { return routersModule?.formState.createForm ?? RouterCreateForm() }
        set { routersModule?.formState.createForm = newValue }
    }

    /// State for router create form
    internal var routerCreateFormState: FormBuilderState {
        get { return routersModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { routersModule?.formState.createFormState = newValue }
    }
}
