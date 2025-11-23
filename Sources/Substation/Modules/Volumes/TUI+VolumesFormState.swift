// Sources/Substation/Modules/Volumes/TUI+VolumesFormState.swift
import Foundation
import OSClient

/// Container for Volumes module form state variables
///
/// This struct encapsulates all form state for the Volumes module,
/// reducing the number of properties stored directly in the TUI class.
struct VolumesFormState {
    // MARK: - Volume Creation

    /// Form for creating new volumes
    var createForm = VolumeCreateForm()

    /// State for volume create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Volume Management

    /// Form for managing volumes
    var managementForm = VolumeManagementForm()

    // MARK: - Snapshot Management

    /// Form for managing volume snapshots
    var snapshotManagementForm = VolumeSnapshotManagementForm()

    /// State for volume snapshot management form
    var snapshotManagementFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Backup Management

    /// Form for managing volume backups
    var backupManagementForm = VolumeBackupManagementForm()

    /// State for volume backup management form
    var backupManagementFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Selection State

    /// Currently selected volume for snapshot operations
    var selectedVolumeForSnapshots: Volume? = nil

    /// Set of snapshot IDs selected for deletion
    var selectedSnapshotsForDeletion: Set<String> = []
}

// MARK: - TUI Extension for Volumes Form State Accessors

/// TUI extension providing computed property accessors for Volumes module form state
///
/// These accessors retrieve form state from the VolumesModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Volumes module from registry
    private var volumesModule: VolumesModule? {
        return ModuleRegistry.shared.module(for: "volumes") as? VolumesModule
    }

    // MARK: - Volume Creation Accessors

    /// Form for creating new volumes
    internal var volumeCreateForm: VolumeCreateForm {
        get { return volumesModule?.formState.createForm ?? VolumeCreateForm() }
        set { volumesModule?.formState.createForm = newValue }
    }

    /// State for volume create form
    internal var volumeCreateFormState: FormBuilderState {
        get { return volumesModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { volumesModule?.formState.createFormState = newValue }
    }

    // MARK: - Volume Management Accessors

    /// Form for managing volumes
    internal var volumeManagementForm: VolumeManagementForm {
        get { return volumesModule?.formState.managementForm ?? VolumeManagementForm() }
        set { volumesModule?.formState.managementForm = newValue }
    }

    // MARK: - Snapshot Management Accessors

    /// Form for managing volume snapshots
    internal var volumeSnapshotManagementForm: VolumeSnapshotManagementForm {
        get { return volumesModule?.formState.snapshotManagementForm ?? VolumeSnapshotManagementForm() }
        set { volumesModule?.formState.snapshotManagementForm = newValue }
    }

    /// State for volume snapshot management form
    internal var volumeSnapshotManagementFormState: FormBuilderState {
        get { return volumesModule?.formState.snapshotManagementFormState ?? FormBuilderState(fields: []) }
        set { volumesModule?.formState.snapshotManagementFormState = newValue }
    }

    // MARK: - Backup Management Accessors

    /// Form for managing volume backups
    internal var volumeBackupManagementForm: VolumeBackupManagementForm {
        get { return volumesModule?.formState.backupManagementForm ?? VolumeBackupManagementForm() }
        set { volumesModule?.formState.backupManagementForm = newValue }
    }

    /// State for volume backup management form
    internal var volumeBackupManagementFormState: FormBuilderState {
        get { return volumesModule?.formState.backupManagementFormState ?? FormBuilderState(fields: []) }
        set { volumesModule?.formState.backupManagementFormState = newValue }
    }

    // MARK: - Selection State Accessors

    /// Currently selected volume for snapshot operations
    internal var selectedVolumeForSnapshots: Volume? {
        get { return volumesModule?.formState.selectedVolumeForSnapshots }
        set { volumesModule?.formState.selectedVolumeForSnapshots = newValue }
    }

    /// Set of snapshot IDs selected for deletion
    internal var selectedSnapshotsForDeletion: Set<String> {
        get { return volumesModule?.formState.selectedSnapshotsForDeletion ?? [] }
        set { volumesModule?.formState.selectedSnapshotsForDeletion = newValue }
    }
}
