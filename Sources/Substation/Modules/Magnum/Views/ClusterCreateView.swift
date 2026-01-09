// Sources/Substation/Modules/Magnum/Views/ClusterCreateView.swift
import Foundation
import OSClient
import SwiftNCurses

/// ClusterCreateView using FormBuilder component
///
/// This view renders the cluster creation form using the unified
/// FormBuilder component for consistent UI across all create forms.
struct ClusterCreateView {
    // Layout Constants
    private static let statusMessageTopPadding: Int32 = 2
    private static let statusMessageLeadingPadding: Int32 = 2
    private static let loadingErrorBoundsHeight: Int32 = 6
    private static let formTitle = "Create Kubernetes Cluster"
    private static let creatingText = "Creating cluster..."
    private static let errorPrefix = "Error: "

    /// Main rendering function for the cluster create form
    ///
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - startRow: Starting row position
    ///   - startCol: Starting column position
    ///   - width: Available width
    ///   - height: Available height
    ///   - form: The cluster create form data
    ///   - formState: The form builder state
    @MainActor
    static func draw(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: ClusterCreateForm,
        formState: FormBuilderState
    ) async {
        let surface = SwiftNCurses.surface(from: screen)

        // Handle loading state
        if form.isLoading {
            let components: [any Component] = [
                Text(Self.formTitle).emphasis().bold(),
                Text(Self.creatingText).info()
                    .padding(EdgeInsets(top: Self.statusMessageTopPadding, leading: Self.statusMessageLeadingPadding, bottom: 0, trailing: 0))
            ]
            let loadingComponent = VStack(spacing: 0, children: components)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: Self.loadingErrorBoundsHeight)
            await SwiftNCurses.render(loadingComponent, on: surface, in: bounds)
            return
        }

        // Handle error state
        if let errorMessage = form.errorMessage {
            let components: [any Component] = [
                Text(Self.formTitle).emphasis().bold(),
                Text("\(Self.errorPrefix)\(errorMessage)").error()
                    .padding(EdgeInsets(top: Self.statusMessageTopPadding, leading: Self.statusMessageLeadingPadding, bottom: 0, trailing: 0))
            ]
            let errorComponent = VStack(spacing: 0, children: components)
            let bounds = Rect(x: startCol, y: startRow, width: width, height: Self.loadingErrorBoundsHeight)
            await SwiftNCurses.render(errorComponent, on: surface, in: bounds)
            return
        }

        // Build form fields
        let fields = form.buildFields(
            selectedFieldId: formState.getCurrentFieldId(),
            activeFieldId: formState.getActiveFieldId(),
            formState: formState
        )

        // Create FormBuilder
        let formBuilder = FormBuilder(
            title: Self.formTitle,
            fields: fields,
            selectedFieldId: formState.getCurrentFieldId(),
            validationErrors: form.validateForm(),
            showValidationErrors: formState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftNCurses.render(formBuilder.render(), on: surface, in: bounds)

        // If a selector field is active, render specialized view as overlay
        // Use the newly built fields array (not formState.getCurrentField()) to check isActive
        if let activeFieldId = formState.getActiveFieldId() {
            for field in fields {
                if case .selector(let selectorField) = field,
                   selectorField.id == activeFieldId {
                    await renderSelectorOverlay(
                        screen: screen,
                        startRow: startRow,
                        startCol: startCol,
                        width: width,
                        height: height,
                        form: form,
                        field: selectorField,
                        selectorState: formState.getSelectorState(selectorField.id) ?? FormSelectorFieldState(items: selectorField.items)
                    )
                    break
                }
            }
        }
    }

    // MARK: - Overlay Rendering

    /// Render selector overlay for active selector fields
    ///
    /// - Parameters:
    ///   - screen: The ncurses screen pointer
    ///   - startRow: Starting row position
    ///   - startCol: Starting column position
    ///   - width: Available width
    ///   - height: Available height
    ///   - form: The form data
    ///   - field: The selector field being rendered
    ///   - selectorState: The selector field state
    @MainActor
    private static func renderSelectorOverlay(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: ClusterCreateForm,
        field: FormFieldSelector,
        selectorState: FormSelectorFieldState
    ) async {
        // Use generic FormSelectorRenderer for all fields
        if let selectorComponent = FormSelectorRenderer.renderSelector(
            label: field.label,
            items: field.items,
            selectedItemId: selectorState.selectedItemId,
            highlightedIndex: selectorState.highlightedIndex,
            scrollOffset: selectorState.scrollOffset,
            searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
            columns: field.columns,
            maxHeight: Int(height)
        ) {
            let surface = SwiftNCurses.surface(from: screen)
            let overlayBounds = Rect(x: startCol, y: startRow, width: width, height: height)
            surface.clear(rect: overlayBounds)
            await SwiftNCurses.render(selectorComponent, on: surface, in: overlayBounds)
        }
    }
}
