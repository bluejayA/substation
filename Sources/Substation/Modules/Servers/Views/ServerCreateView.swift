import Foundation
import OSClient
import SwiftNCurses

/// ServerCreateView using FormBuilder component
/// This replaces the old manual form rendering with the unified FormBuilder
struct ServerCreateView {
    // Layout Constants
    private static let statusMessageTopPadding: Int32 = 2
    private static let statusMessageLeadingPadding: Int32 = 2
    private static let loadingErrorBoundsHeight: Int32 = 6
    private static let formTitle = "Create New Server"
    private static let creatingServerText = "Creating server..."
    private static let errorPrefix = "Error: "

    /// Main rendering function for the server create form
    @MainActor
    static func drawServerCreateForm(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: ServerCreateForm,
        formState: FormBuilderState
    ) async {
        let surface = SwiftNCurses.surface(from: screen)

        // Handle loading state
        if form.isLoading {
            let components: [any Component] = [
                Text(Self.formTitle).emphasis().bold(),
                Text(Self.creatingServerText).info()
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
            validationErrors: form.validate(),
            showValidationErrors: formState.showValidationErrors
        )

        // Render the form
        let bounds = Rect(x: startCol, y: startRow, width: width, height: height)
        surface.clear(rect: bounds)
        await SwiftNCurses.render(formBuilder.render(), on: surface, in: bounds)

        // If a selector field is active, render specialized view as overlay
        if let currentField = formState.getCurrentField() {
            switch currentField {
            case .selector(let selectorField) where selectorField.isActive:
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
            case .multiSelect(let multiSelectField) where multiSelectField.isActive:
                await renderMultiSelectOverlay(
                    screen: screen,
                    startRow: startRow,
                    startCol: startCol,
                    width: width,
                    height: height,
                    form: form,
                    field: multiSelectField,
                    selectorState: formState.getSelectorState(multiSelectField.id) ?? FormSelectorFieldState(items: multiSelectField.items)
                )
            default:
                break
            }
        }
    }

    // MARK: - Overlay Rendering

    @MainActor
    private static func renderSelectorOverlay(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: ServerCreateForm,
        field: FormFieldSelector,
        selectorState: FormSelectorFieldState
    ) async {
        // Use specialized views for specific fields based on field ID
        switch field.id {
        case ServerCreateFieldId.source.rawValue:
            // Use SourceSelectionView for boot source selection
            // IMPORTANT: Use field.items (sorted) instead of form.images (unsorted)
            // to ensure highlightedIndex matches the displayed item order
            let sortedImages = field.items.compactMap { $0 as? Image }
            let sortedVolumes = field.items.compactMap { $0 as? Volume }
            await SourceSelectionView.draw(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                images: form.bootSource == .image ? sortedImages : form.images,
                volumes: form.bootSource == .volume ? sortedVolumes : form.volumes,
                bootSource: form.bootSource,
                selectedImageId: form.selectedImageID,
                selectedVolumeId: form.selectedVolumeID,
                selectedIndex: selectorState.highlightedIndex,
                scrollOffset: selectorState.scrollOffset,
                searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery
            )

        case ServerCreateFieldId.flavor.rawValue:
            // Use FlavorSelectionView for flavor selection
            // Convert field items back to Flavor array
            let fieldFlavors = field.items.compactMap { $0 as? Flavor }
            await FlavorSelectionView.draw(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                flavors: fieldFlavors,
                workloadType: form.workloadType,
                flavorRecommendations: form.flavorRecommendations,
                selectedFlavorId: form.selectedFlavorID,
                selectedRecommendationIndex: form.selectedRecommendationIndex,
                selectedIndex: selectorState.highlightedIndex,
                mode: form.flavorSelectionMode,
                scrollOffset: selectorState.scrollOffset,
                searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery,
                selectedCategoryIndex: form.selectedCategoryIndex
            )

        default:
            // Fallback to generic FormSelectorRenderer for other fields
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

    @MainActor
    private static func renderMultiSelectOverlay(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        form: ServerCreateForm,
        field: FormFieldMultiSelect,
        selectorState: FormSelectorFieldState
    ) async {
        // Use specialized views for specific fields based on field ID
        switch field.id {
        case ServerCreateFieldId.network.rawValue:
            // Use NetworkSelectionView for network selection
            await NetworkSelectionView.drawNetworkSelection(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                networks: form.networks,
                selectedNetworkIds: form.selectedNetworks,
                highlightedIndex: selectorState.highlightedIndex,
                scrollOffset: selectorState.scrollOffset,
                searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery
            )

        case ServerCreateFieldId.securityGroup.rawValue:
            // Use SecurityGroupSelectionView for security group selection
            await SecurityGroupSelectionView.drawSecurityGroupSelection(
                screen: screen,
                startRow: startRow,
                startCol: startCol,
                width: width,
                height: height,
                securityGroups: form.securityGroups,
                selectedSecurityGroupIds: form.selectedSecurityGroups,
                highlightedIndex: selectorState.highlightedIndex,
                scrollOffset: selectorState.scrollOffset,
                searchQuery: selectorState.searchQuery.isEmpty ? nil : selectorState.searchQuery
            )

        default:
            // Fallback to generic FormSelectorRenderer for other multi-select fields
            if let selectorComponent = FormSelectorRenderer.renderMultiSelector(
                label: field.label,
                items: field.items,
                selectedItemIds: selectorState.selectedItemIds,
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
}
