// Sources/Substation/Modules/ServerGroups/TUI+ServerGroupsFormState.swift
import Foundation

/// Container for Server Groups module form state variables
///
/// This struct encapsulates all form state for the Server Groups module,
/// reducing the number of properties stored directly in the TUI class.
struct ServerGroupsFormState {
    // MARK: - Server Group Creation

    /// Form for creating new server groups
    var createForm = ServerGroupCreateForm()

    /// State for server group create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Server Group Management

    /// Form for managing server groups
    var managementForm = ServerGroupManagementForm()
}

// MARK: - TUI Extension for Server Groups Form State Accessors

/// TUI extension providing computed property accessors for Server Groups module form state
///
/// These accessors retrieve form state from the ServerGroupsModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get ServerGroups module from registry
    private var serverGroupsModule: ServerGroupsModule? {
        return ModuleRegistry.shared.module(for: "servergroups") as? ServerGroupsModule
    }

    // MARK: - Server Group Creation Accessors

    /// Form for creating new server groups
    internal var serverGroupCreateForm: ServerGroupCreateForm {
        get { return serverGroupsModule?.formState.createForm ?? ServerGroupCreateForm() }
        set { serverGroupsModule?.formState.createForm = newValue }
    }

    /// State for server group create form
    internal var serverGroupCreateFormState: FormBuilderState {
        get { return serverGroupsModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { serverGroupsModule?.formState.createFormState = newValue }
    }

    // MARK: - Server Group Management Accessors

    /// Form for managing server groups
    internal var serverGroupManagementForm: ServerGroupManagementForm {
        get { return serverGroupsModule?.formState.managementForm ?? ServerGroupManagementForm() }
        set { serverGroupsModule?.formState.managementForm = newValue }
    }
}
