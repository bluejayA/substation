// Sources/Substation/Modules/Servers/TUI+ServersFormState.swift
import Foundation

/// Container for Servers module form state variables
///
/// This struct encapsulates all form state for the Servers module,
/// reducing the number of properties stored directly in the TUI class.
struct ServersFormState {
    // MARK: - Server Creation

    /// Form for creating new servers
    var createForm = ServerCreateForm()

    /// State for server create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Server Resize

    /// Form for resizing servers
    var resizeForm = ServerResizeForm()

    // MARK: - Snapshot Management

    /// Form for managing server snapshots
    var snapshotManagementForm = SnapshotManagementForm()

    /// State for snapshot management form
    var snapshotManagementFormState: FormBuilderState = FormBuilderState(fields: [])
}

// MARK: - TUI Extension for Servers Form State Accessors

/// TUI extension providing computed property accessors for Servers module form state
///
/// These accessors retrieve form state from the ServersModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Servers module from registry
    private var serversModule: ServersModule? {
        return ModuleRegistry.shared.module(for: "servers") as? ServersModule
    }

    // MARK: - Server Creation Accessors

    /// Form for creating new servers
    internal var serverCreateForm: ServerCreateForm {
        get { return serversModule?.formState.createForm ?? ServerCreateForm() }
        set { serversModule?.formState.createForm = newValue }
    }

    /// State for server create form
    internal var serverCreateFormState: FormBuilderState {
        get { return serversModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { serversModule?.formState.createFormState = newValue }
    }

    // MARK: - Server Resize Accessors

    /// Form for resizing servers
    internal var serverResizeForm: ServerResizeForm {
        get { return serversModule?.formState.resizeForm ?? ServerResizeForm() }
        set { serversModule?.formState.resizeForm = newValue }
    }

    // MARK: - Snapshot Management Accessors

    /// Form for managing server snapshots
    internal var snapshotManagementForm: SnapshotManagementForm {
        get { return serversModule?.formState.snapshotManagementForm ?? SnapshotManagementForm() }
        set { serversModule?.formState.snapshotManagementForm = newValue }
    }

    /// State for snapshot management form
    internal var snapshotManagementFormState: FormBuilderState {
        get { return serversModule?.formState.snapshotManagementFormState ?? FormBuilderState(fields: []) }
        set { serversModule?.formState.snapshotManagementFormState = newValue }
    }
}
