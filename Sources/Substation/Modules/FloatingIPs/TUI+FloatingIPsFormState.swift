// Sources/Substation/Modules/FloatingIPs/TUI+FloatingIPsFormState.swift
import Foundation

/// Container for Floating IPs module form state variables
///
/// This struct encapsulates all form state for the Floating IPs module,
/// reducing the number of properties stored directly in the TUI class.
struct FloatingIPsFormState {
    // MARK: - Floating IP Creation

    /// Form for creating new floating IPs
    var createForm = FloatingIPCreateForm()

    /// State for floating IP create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Render State

    /// Flag to track if floating IP view is currently rendering
    var isViewRendering: Bool = false
}

// MARK: - TUI Extension for Floating IPs Form State Accessors

/// TUI extension providing computed property accessors for Floating IPs module form state
///
/// These accessors retrieve form state from the FloatingIPsModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get FloatingIPs module from registry
    private var floatingIPsModule: FloatingIPsModule? {
        return ModuleRegistry.shared.module(for: "floatingips") as? FloatingIPsModule
    }

    // MARK: - Floating IP Creation Accessors

    /// Form for creating new floating IPs
    internal var floatingIPCreateForm: FloatingIPCreateForm {
        get { return floatingIPsModule?.formState.createForm ?? FloatingIPCreateForm() }
        set { floatingIPsModule?.formState.createForm = newValue }
    }

    /// State for floating IP create form
    internal var floatingIPCreateFormState: FormBuilderState {
        get { return floatingIPsModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { floatingIPsModule?.formState.createFormState = newValue }
    }

    // MARK: - Render State Accessors

    /// Flag to track if floating IP view is currently rendering
    internal var isFloatingIPViewRendering: Bool {
        get { return floatingIPsModule?.formState.isViewRendering ?? false }
        set { floatingIPsModule?.formState.isViewRendering = newValue }
    }
}
