// Sources/Substation/Modules/Swift/TUI+SwiftFormState.swift
import Foundation

/// Container for Swift module form state variables
///
/// This struct encapsulates all form state and background operation tracking
/// for the Swift Object Storage module, reducing the number of properties
/// stored directly in the TUI class.
@MainActor
struct SwiftFormState {
    // MARK: - Background Operations

    /// Manager for tracking Swift background operations (uploads, downloads, deletions)
    var backgroundOps: SwiftBackgroundOperationsManager = SwiftBackgroundOperationsManager()

    /// Active upload status message for status bar display
    var activeUploadMessage: String? = nil

    /// Active upload task reference
    var activeUploadTask: Task<Void, Never>? = nil

    /// Active download status message for status bar display
    var activeDownloadMessage: String? = nil

    /// Active download task reference
    var activeDownloadTask: Task<Void, Never>? = nil

    // MARK: - Container Forms

    /// Form for creating new Swift containers
    var containerCreateForm = SwiftContainerCreateForm()

    /// State for Swift container create form
    var containerCreateFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Form for editing Swift container metadata
    var containerMetadataForm = SwiftContainerMetadataForm()

    /// State for Swift container metadata form
    var containerMetadataFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Form for configuring Swift container web access
    var containerWebAccessForm = SwiftContainerWebAccessForm()

    /// State for Swift container web access form
    var containerWebAccessFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Form for downloading Swift containers
    var containerDownloadForm = SwiftContainerDownloadForm()

    /// State for Swift container download form
    var containerDownloadFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Object Forms

    /// Form for editing Swift object metadata
    var objectMetadataForm = SwiftObjectMetadataForm()

    /// State for Swift object metadata form
    var objectMetadataFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Form for uploading Swift objects
    var objectUploadForm = SwiftObjectUploadForm()

    /// State for Swift object upload form
    var objectUploadFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Form for downloading Swift objects
    var objectDownloadForm = SwiftObjectDownloadForm()

    /// State for Swift object download form
    var objectDownloadFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Directory Forms

    /// Form for editing Swift directory metadata
    var directoryMetadataForm = SwiftDirectoryMetadataForm()

    /// State for Swift directory metadata form
    var directoryMetadataFormState: FormBuilderState = FormBuilderState(fields: [])

    /// Form for downloading Swift directories
    var directoryDownloadForm = SwiftDirectoryDownloadForm()

    /// State for Swift directory download form
    var directoryDownloadFormState: FormBuilderState = FormBuilderState(fields: [])
}

// MARK: - TUI Extension for Swift Form State Accessors

/// TUI extension providing computed property accessors for Swift module form state
///
/// These accessors retrieve form state from the SwiftModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Swift module from registry
    private var swiftModule: SwiftModule? {
        return ModuleRegistry.shared.module(for: "swift") as? SwiftModule
    }

    // MARK: - Background Operations Accessors

    /// Manager for tracking Swift background operations
    internal var swiftBackgroundOps: SwiftBackgroundOperationsManager {
        get { return swiftModule?.formState.backgroundOps ?? SwiftBackgroundOperationsManager() }
        set { swiftModule?.formState.backgroundOps = newValue }
    }

    /// Active upload status message for status bar display
    internal var activeUploadMessage: String? {
        get { return swiftModule?.formState.activeUploadMessage }
        set { swiftModule?.formState.activeUploadMessage = newValue }
    }

    /// Active upload task reference
    internal var activeUploadTask: Task<Void, Never>? {
        get { return swiftModule?.formState.activeUploadTask }
        set { swiftModule?.formState.activeUploadTask = newValue }
    }

    /// Active download status message for status bar display
    internal var activeDownloadMessage: String? {
        get { return swiftModule?.formState.activeDownloadMessage }
        set { swiftModule?.formState.activeDownloadMessage = newValue }
    }

    /// Active download task reference
    internal var activeDownloadTask: Task<Void, Never>? {
        get { return swiftModule?.formState.activeDownloadTask }
        set { swiftModule?.formState.activeDownloadTask = newValue }
    }

    // MARK: - Container Form Accessors

    /// Form for creating new Swift containers
    internal var swiftContainerCreateForm: SwiftContainerCreateForm {
        get { return swiftModule?.formState.containerCreateForm ?? SwiftContainerCreateForm() }
        set { swiftModule?.formState.containerCreateForm = newValue }
    }

    /// State for Swift container create form
    internal var swiftContainerCreateFormState: FormBuilderState {
        get { return swiftModule?.formState.containerCreateFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.containerCreateFormState = newValue }
    }

    /// Form for editing Swift container metadata
    internal var swiftContainerMetadataForm: SwiftContainerMetadataForm {
        get { return swiftModule?.formState.containerMetadataForm ?? SwiftContainerMetadataForm() }
        set { swiftModule?.formState.containerMetadataForm = newValue }
    }

    /// State for Swift container metadata form
    internal var swiftContainerMetadataFormState: FormBuilderState {
        get { return swiftModule?.formState.containerMetadataFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.containerMetadataFormState = newValue }
    }

    /// Form for configuring Swift container web access
    internal var swiftContainerWebAccessForm: SwiftContainerWebAccessForm {
        get { return swiftModule?.formState.containerWebAccessForm ?? SwiftContainerWebAccessForm() }
        set { swiftModule?.formState.containerWebAccessForm = newValue }
    }

    /// State for Swift container web access form
    internal var swiftContainerWebAccessFormState: FormBuilderState {
        get { return swiftModule?.formState.containerWebAccessFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.containerWebAccessFormState = newValue }
    }

    /// Form for downloading Swift containers
    internal var swiftContainerDownloadForm: SwiftContainerDownloadForm {
        get { return swiftModule?.formState.containerDownloadForm ?? SwiftContainerDownloadForm() }
        set { swiftModule?.formState.containerDownloadForm = newValue }
    }

    /// State for Swift container download form
    internal var swiftContainerDownloadFormState: FormBuilderState {
        get { return swiftModule?.formState.containerDownloadFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.containerDownloadFormState = newValue }
    }

    // MARK: - Object Form Accessors

    /// Form for editing Swift object metadata
    internal var swiftObjectMetadataForm: SwiftObjectMetadataForm {
        get { return swiftModule?.formState.objectMetadataForm ?? SwiftObjectMetadataForm() }
        set { swiftModule?.formState.objectMetadataForm = newValue }
    }

    /// State for Swift object metadata form
    internal var swiftObjectMetadataFormState: FormBuilderState {
        get { return swiftModule?.formState.objectMetadataFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.objectMetadataFormState = newValue }
    }

    /// Form for uploading Swift objects
    internal var swiftObjectUploadForm: SwiftObjectUploadForm {
        get { return swiftModule?.formState.objectUploadForm ?? SwiftObjectUploadForm() }
        set { swiftModule?.formState.objectUploadForm = newValue }
    }

    /// State for Swift object upload form
    internal var swiftObjectUploadFormState: FormBuilderState {
        get { return swiftModule?.formState.objectUploadFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.objectUploadFormState = newValue }
    }

    /// Form for downloading Swift objects
    internal var swiftObjectDownloadForm: SwiftObjectDownloadForm {
        get { return swiftModule?.formState.objectDownloadForm ?? SwiftObjectDownloadForm() }
        set { swiftModule?.formState.objectDownloadForm = newValue }
    }

    /// State for Swift object download form
    internal var swiftObjectDownloadFormState: FormBuilderState {
        get { return swiftModule?.formState.objectDownloadFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.objectDownloadFormState = newValue }
    }

    // MARK: - Directory Form Accessors

    /// Form for editing Swift directory metadata
    internal var swiftDirectoryMetadataForm: SwiftDirectoryMetadataForm {
        get { return swiftModule?.formState.directoryMetadataForm ?? SwiftDirectoryMetadataForm() }
        set { swiftModule?.formState.directoryMetadataForm = newValue }
    }

    /// State for Swift directory metadata form
    internal var swiftDirectoryMetadataFormState: FormBuilderState {
        get { return swiftModule?.formState.directoryMetadataFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.directoryMetadataFormState = newValue }
    }

    /// Form for downloading Swift directories
    internal var swiftDirectoryDownloadForm: SwiftDirectoryDownloadForm {
        get { return swiftModule?.formState.directoryDownloadForm ?? SwiftDirectoryDownloadForm() }
        set { swiftModule?.formState.directoryDownloadForm = newValue }
    }

    /// State for Swift directory download form
    internal var swiftDirectoryDownloadFormState: FormBuilderState {
        get { return swiftModule?.formState.directoryDownloadFormState ?? FormBuilderState(fields: []) }
        set { swiftModule?.formState.directoryDownloadFormState = newValue }
    }
}
