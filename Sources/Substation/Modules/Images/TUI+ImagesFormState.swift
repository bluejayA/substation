// Sources/Substation/Modules/Images/TUI+ImagesFormState.swift
import Foundation

/// Container for Images module form state variables
///
/// This struct encapsulates all form state for the Images module,
/// reducing the number of properties stored directly in the TUI class.
struct ImagesFormState {
    // MARK: - Image Creation

    /// Form for creating new images
    var createForm = ImageCreateForm()

    /// State for image create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])
}

// MARK: - TUI Extension for Images Form State Accessors

/// TUI extension providing computed property accessors for Images module form state
///
/// These accessors retrieve form state from the ImagesModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Images module from registry
    private var imagesModule: ImagesModule? {
        return ModuleRegistry.shared.module(for: "images") as? ImagesModule
    }

    // MARK: - Image Creation Accessors

    /// Form for creating new images
    internal var imageCreateForm: ImageCreateForm {
        get { return imagesModule?.formState.createForm ?? ImageCreateForm() }
        set { imagesModule?.formState.createForm = newValue }
    }

    /// State for image create form
    internal var imageCreateFormState: FormBuilderState {
        get { return imagesModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { imagesModule?.formState.createFormState = newValue }
    }
}
